import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_rag_sqlite/flutter_gemma_rag_sqlite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GemmaService {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _modelInstalled = false;
  bool get isModelInstalled => _modelInstalled;

  bool _embedderInstalled = false;
  bool get isEmbedderInstalled => _embedderInstalled;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  String? _initError;
  String? get initError => _initError;

  String? _hfToken;
  set hfToken(String? token) {
    _hfToken = token;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // If no token set and models not already installed, mark as needing token
    if (_hfToken == null || _hfToken!.isEmpty) {
      // Check if models are already installed from previous run (no token needed if sideloaded)
      final alreadyInstalled = FlutterGemma.hasActiveModel() && FlutterGemma.hasActiveEmbedder();

      if (alreadyInstalled) {
        await FlutterGemma.rag.initialize('marginal_rag.db');
        _initialized = true;
        _modelInstalled = true;
        _embedderInstalled = true;
        return;
      }

      // No token and no installed models
      _initError = 'Hugging Face token required. Please enter your token in Settings.';
      _initialized = false;
      return; // Just return, don't rethrow
    }

    try {
      await FlutterGemma.initialize(
        inferenceEngines: kIsWeb ? const [] : const [LiteRtLmEngine()],
        embeddingBackends: kIsWeb ? const [] : const [LiteRtEmbeddingBackend()],
        vectorStore: kIsWeb ? WebSqliteVectorStore() : SqliteVectorStore(),
        huggingFaceToken: _hfToken,
      );

      // Check if models are now active
      final modelActive = FlutterGemma.hasActiveModel();
      final embedderActive = FlutterGemma.hasActiveEmbedder();

      if (modelActive && embedderActive) {
        await FlutterGemma.rag.initialize('marginal_rag.db');
        _initialized = true;
        _modelInstalled = true;
        _embedderInstalled = true;
        _initError = null;
        return;
      }

      // Models not active after initialization
      _initialized = false;
      _initError = 'Failed to initialize models with provided token.';
      // Don't rethrow - just set the error and return
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        _initError = 'Invalid Hugging Face token. Please check your token and try again.';
      } else {
        _initError = e.toString();
      }
      _initialized = false;
      // Don't rethrow - just set the error and return
    }
  }

  Future<void> checkModelStatus() async {
    if (!_initialized) return;

    try {
      _modelInstalled = FlutterGemma.hasActiveModel();
      _embedderInstalled = FlutterGemma.hasActiveEmbedder();
    } catch (e) {
      _modelInstalled = false;
      _embedderInstalled = false;
    }
  }

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (_initialized && _modelInstalled) return; // Already installed

    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        rethrow;
      }
    }

    // Check if we have a token
    if (_hfToken == null || _hfToken!.isEmpty) {
      _initError = 'Hugging Face token required. Please enter your token in Settings first.';
      return; // Just return instead of rethrow
    }

    onProgress?.call(0);
    _downloadProgress = 0;

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(
        'https://huggingface.co/google/gemma-3-270m-it-litertlm/resolve/main/gemma-3-270m-it-qat.litertlm',
      ).install();

      await FlutterGemma.rag.initialize('marginal_rag.db');

      _modelInstalled = true;
      _downloadProgress = 1.0;
      onProgress?.call(1.0);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        _initError = 'Invalid Hugging Face token. Please check your token and try again.';
      } else {
        _initError = 'Failed to download generation model: $e';
      }
      return; // Just return instead of rethrow
    }
  }

  Future<void> downloadEmbedder({
    void Function(double progress)? onProgress,
  }) async {
    if (_initialized && _embedderInstalled) return; // Already installed

    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        rethrow;
      }
    }

    // Check if we have a token
    if (_hfToken == null || _hfToken!.isEmpty) {
      _initError = 'Hugging Face token required. Please enter your token in Settings first.';
      return; // Just return instead of rethrow
    }

    try {
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(
            'https://huggingface.co/google/embeddinggemma-300m-tflite/resolve/main/embeddinggemma-300m.tflite',
          )
          .tokenizerFromNetwork(
            'https://huggingface.co/google/embeddinggemma-300m-tflite/resolve/main/sentencepiece.model',
          )
          .install();

      _embedderInstalled = true;
      _downloadProgress = 1.0;
      onProgress?.call(1.0);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        _initError = 'Invalid Hugging Face token.';
      } else {
        _initError = 'Failed to download embedding model: $e';
      }
      return; // Just return instead of rethrow
    }
  }

  Future<List<double>> embedText(String text) async {
    if (!_initialized || !_embedderInstalled) return [];

    try {
      final embedder = await FlutterGemma.getActiveEmbedder();
      final vector = await embedder.generateEmbedding(text);
      return vector;
    } catch (e) {
      return [];
    }
  }

  Future<void> addDocumentToVectorStore({
    required String id,
    required String content,
    required List<double> embedding,
    String? metadata,
  }) async {
    try {
      await FlutterGemma.rag.addDocumentWithEmbedding(
        id: id,
        content: content,
        embedding: embedding,
        metadata: metadata,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RetrievalResult>> searchSimilar({
    required String query,
    int topK = 5,
  }) async {
    try {
      return await FlutterGemma.rag.searchSimilar(
        query: query,
        topK: topK,
      );
    } catch (e) {
      return []; // Return empty on error, don't crash
    }
  }

  Future<void> deleteDocumentChunks(String documentId) async {
    try {
      final allHits = await searchSimilar(query: documentId, topK: 1000);
      for (final hit in allHits) {
        if (hit.id.startsWith('${documentId}_chunk_')) {
          await FlutterGemma.rag.removeDocument(id: hit.id);
        }
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  Future<String> generateResponse({
    required String question,
    required List<String> contextChunks,
  }) async {
    if (!_initialized || !_modelInstalled) {
      if (_initError != null) {
        return 'Initialization error: $_initError\nPlease enter your Hugging Face token in Settings.';
      }
      return 'Model not initialized. Please download models first.';
    }

    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      final session = await model.createSession();

      final contextBlock = contextChunks.asMap().entries.map((e) {
        return '[Source ${e.key + 1}]: ${e.value}';
      }).join('\n\n');

      final prompt = '''You are Marginal, an on-device research assistant. 
Answer the question based ONLY on the provided context from the user's notes.
Always cite your sources by referencing [Source N].
If the context doesn't contain enough information, say so honestly.
Never claim to "understand" — frame answers as generated from retrieved passages.

Context from user's notes:
$contextBlock

Question: $question

Answer (cite sources):''';

      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await session.getResponse();
      await session.close();

      return response;
    } catch (e) {
      return 'Error generating response: $e';
    }
  }

  Future<void> clearAllData() async {
    try {
      await FlutterGemma.rag.clear();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
}