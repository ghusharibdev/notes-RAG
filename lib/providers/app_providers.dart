import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../models/chat_message.dart';
import '../services/storage_service.dart';
import '../services/gemma_service.dart';
import '../services/document_service.dart';
import '../services/rag_service.dart';

// ─── Services ───

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final gemmaServiceProvider = Provider<GemmaService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final ragServiceProvider = Provider<RagService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

// ─── Initialization ───

enum InitStatus { waiting, loading, ready, error }

class InitState {
  final InitStatus status;
  final String? error;
  final bool modelsReady;
  final bool onboardingComplete;
  final double modelProgress;
  final double embedderProgress;

  const InitState({
    this.status = InitStatus.waiting,
    this.error,
    this.modelsReady = false,
    this.onboardingComplete = false,
    this.modelProgress = 0,
    this.embedderProgress = 0,
  });

  InitState copyWith({
    InitStatus? status,
    String? error,
    bool? modelsReady,
    bool? onboardingComplete,
    double? modelProgress,
    double? embedderProgress,
  }) {
    return InitState(
      status: status ?? this.status,
      error: error,
      modelsReady: modelsReady ?? this.modelsReady,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      modelProgress: modelProgress ?? this.modelProgress,
      embedderProgress: embedderProgress ?? this.embedderProgress,
    );
  }
}

class InitNotifier extends StateNotifier<InitState> {
  final GemmaService _gemma;
  final StorageService _storage;

  InitNotifier(this._gemma, this._storage) : super(const InitState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(status: InitStatus.loading);

    try {
      await _gemma.initialize();
      await _gemma.checkModelStatus();

      // Models may already be installed from a previous run
      final modelsReady = _gemma.isModelInstalled && _gemma.isEmbedderInstalled;
      
      state = state.copyWith(
        status: InitStatus.ready,
        modelsReady: modelsReady,
        onboardingComplete: _storage.isOnboardingComplete,
      );

      // If models are ready but onboarding hasn't been completed, mark it
      if (modelsReady && !_storage.isOnboardingComplete) {
        await _storage.setOnboardingComplete();
      }
    } catch (e) {
      state = state.copyWith(
        status: InitStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> downloadModels() async {
    state = state.copyWith(status: InitStatus.loading);

    try {
      await _gemma.downloadModel(onProgress: (p) {
        state = state.copyWith(modelProgress: p);
      });

      await _gemma.downloadEmbedder(onProgress: (p) {
        state = state.copyWith(embedderProgress: p);
      });

      await _gemma.checkModelStatus();
      await _storage.setOnboardingComplete();

      state = state.copyWith(
        status: InitStatus.ready,
        modelsReady: true,
        onboardingComplete: true,
        modelProgress: 1.0,
        embedderProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: InitStatus.error,
        error: e.toString(),
      );
    }
  }

  void completeOnboarding() {
    _storage.setOnboardingComplete();
    state = state.copyWith(onboardingComplete: true);
  }
}

final initProvider = StateNotifierProvider<InitNotifier, InitState>((ref) {
  final gemma = ref.watch(gemmaServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return InitNotifier(gemma, storage);
});

// ─── Documents ───

class DocumentListNotifier extends StateNotifier<List<DocumentModel>> {
  final DocumentService _docService;

  DocumentListNotifier(this._docService) : super([]) {
    _load();
  }

  void _load() {
    state = _docService.documents;
  }

  Future<void> addDocument(dynamic file) async {
    final doc = await _docService.addDocument(file);
    _load();

    // Auto-index in background
    _indexDocument(doc.id);
  }

  Future<void> _indexDocument(String id) async {
    await _docService.indexDocument(id);
    _load();
  }

  Future<void> deleteDocument(String id) async {
    await _docService.deleteDocument(id);
    _load();
  }

  Future<void> retryIndexing(String id) async {
    await _docService.retryIndexing(id);
    _load();
  }

  void refresh() => _load();
}

final documentListProvider =
    StateNotifierProvider<DocumentListNotifier, List<DocumentModel>>((ref) {
  final docService = ref.watch(documentServiceProvider);
  return DocumentListNotifier(docService);
});

// ─── Chat Messages ───

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final RagService _rag;

  ChatMessagesNotifier(this._rag) : super([]);

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        role: MessageRole.user,
        content: content,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void addRetrievalMessage(List<String> chunks) {
    state = [
      ...state,
      ChatMessage(
        id: 'retrieval-${DateTime.now().millisecondsSinceEpoch}',
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      ),
    ];
  }

  Future<void> sendQuestion(String question) async {
    if (_isProcessing) return;
    _isProcessing = true;

    addUserMessage(question);

    try {
      final result = await _rag.query(question);

      // Remove streaming indicator, add real answer
      state = [
        ...state.where((m) => !m.isStreaming),
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          role: MessageRole.assistant,
          content: result.answer,
          citations: result.citations,
          timestamp: DateTime.now(),
        ),
      ];
    } catch (e) {
      state = [
        ...state.where((m) => !m.isStreaming),
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          role: MessageRole.assistant,
          content: 'Sorry, I encountered an error: $e',
          timestamp: DateTime.now(),
        ),
      ];
    } finally {
      _isProcessing = false;
    }
  }

  void clearMessages() {
    state = [];
  }
}

final chatMessagesProvider =
    StateNotifierProvider.family<ChatMessagesNotifier, List<ChatMessage>, String>(
  (ref, docId) {
    final rag = ref.watch(ragServiceProvider);
    return ChatMessagesNotifier(rag);
  },
);
