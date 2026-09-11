import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_rag_sqlite/flutter_gemma_rag_sqlite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../config/secrets.dart';

/// Which prefix the embedder applies before vectorizing text.
///
/// Sentence-transformers models are trained with different prefixes for
/// queries and documents — using the wrong one measurably degrades retrieval.
enum EmbeddingTaskType { query, document }

class GemmaService {
  // Token resolution order: explicit setter > lib/config/secrets.dart (local,
  // skip-worktree-protected) > --dart-define=HF_TOKEN. Never hardcode here.
  static const String _hfTokenEnv = String.fromEnvironment('HF_TOKEN');

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
    _hfToken = (token != null && token.isNotEmpty) ? token : null;
  }

  /// Token resolution order: explicit setter > secrets.dart > --dart-define.
  String? get _effectiveHfToken {
    if (_hfToken != null) return _hfToken;
    if (localHfToken.isNotEmpty) return localHfToken;
    if (_hfTokenEnv.isNotEmpty) return _hfTokenEnv;
    return null;
  }

  String? _ragDbPath;
  bool _ragInitialized = false;

  Future<void> _ensureRagInitialized() async {
    if (_ragInitialized) return;
    if (_ragDbPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _ragDbPath = '${dir.path}/marginal_rag.db';
    }
    await FlutterGemma.rag.initialize(_ragDbPath!);
    _ragInitialized = true;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await FlutterGemma.initialize(
        inferenceEngines: kIsWeb ? const [] : const [LiteRtLmEngine()],
        embeddingBackends: kIsWeb ? const [] : const [LiteRtEmbeddingBackend()],
        vectorStore: kIsWeb ? WebSqliteVectorStore() : SqliteVectorStore(),
        huggingFaceToken: _effectiveHfToken,
      );

      final modelActive = FlutterGemma.hasActiveModel();
      final embedderActive = FlutterGemma.hasActiveEmbedder();

      if (modelActive && embedderActive) {
        await _ensureRagInitialized();
      }

      _initialized = true;
      _modelInstalled = modelActive;
      _embedderInstalled = embedderActive;
      _initError = null;
    } catch (e) {
      _initError = e.toString();
      _initialized = false;
    }
  }

  Future<void> checkModelStatus() async {
    if (!_initialized) return;
    try {
      _modelInstalled = FlutterGemma.hasActiveModel();
      _embedderInstalled = FlutterGemma.hasActiveEmbedder();
    } catch (_) {
      _modelInstalled = false;
      _embedderInstalled = false;
    }
  }

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (_initialized && _modelInstalled) return;
    if (!_initialized) await initialize();

    onProgress?.call(0);
    _downloadProgress = 0;

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.qwen3,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
        token: _effectiveHfToken,
      ).withProgress((p) {
        _downloadProgress = p / 100.0;
        onProgress?.call(_downloadProgress);
      }).install();

      _modelInstalled = true;
      _downloadProgress = 1.0;
      onProgress?.call(1.0);
    } catch (e) {
      _initError = 'Failed to download generation model: $e';
      throw Exception(_initError);
    }
  }

  Future<void> downloadEmbedder({
    void Function(double progress)? onModelProgress,
    void Function(double progress)? onTokenizerProgress,
  }) async {
    if (_initialized && _embedderInstalled) return;
    if (!_initialized) await initialize();

    try {
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(
            'https://huggingface.co/Bombek1/all-MiniLM-L12-v2-litert/resolve/main/sentence-transformers_all-MiniLM-L12-v2.tflite',
          )
          .withModelProgress((p) {
            onModelProgress?.call(p / 100.0);
          })
          .tokenizerFromNetwork(
            'https://huggingface.co/XLabs-AI/xflux_text_encoders/resolve/main/spiece.model',
          )
          .withTokenizerProgress((p) {
            onTokenizerProgress?.call(p / 100.0);
          })
          .install();

      _embedderInstalled = true;
      onModelProgress?.call(1.0);
      onTokenizerProgress?.call(1.0);

      if (_modelInstalled) {
        await _ensureRagInitialized();
      }
    } catch (e) {
      _initError = 'Failed to download embedding model: $e';
      throw Exception(_initError);
    }
  }

  Future<List<double>> embedText(
    String text, {
    EmbeddingTaskType taskType = EmbeddingTaskType.query,
  }) async {
    if (!_initialized || !_embedderInstalled) return [];
    try {
      final embedder = await FlutterGemma.getActiveEmbedder();
      return await embedder.generateEmbedding(
        text,
        taskType: taskType == EmbeddingTaskType.document
            ? TaskType.retrievalDocument
            : TaskType.retrievalQuery,
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> addDocumentToVectorStore({
    required String id,
    required String content,
    required List<double> embedding,
    String? metadata,
  }) async {
    await FlutterGemma.rag.addDocumentWithEmbedding(
      id: id,
      content: content,
      embedding: embedding,
      metadata: metadata,
    );
  }

  Future<List<RetrievalResult>> searchSimilar({
    required String query,
    int topK = 5,
    double threshold = 0.0,
  }) async {
    try {
      return await FlutterGemma.rag.searchSimilar(
        query: query,
        topK: topK,
        threshold: threshold,
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteDocumentChunks(String documentId, {int chunkCount = 0}) async {
    for (int i = 0; i < chunkCount; i++) {
      try {
        await FlutterGemma.rag.removeDocument(id: '${documentId}_chunk_$i');
      } catch (_) {}
    }
  }

  Future<String> generateResponse({
    required String question,
    required List<String> contextChunks,
    List<String> historyTurns = const [],
  }) async {
    if (!_initialized || !_modelInstalled) {
      return 'Model not ready. Please complete model download on startup.';
    }

    if (contextChunks.isEmpty) {
      return "I couldn't find anything related to that in this document. "
          'Try rephrasing, or check that the document finished indexing in the Library.';
    }

    try {
      // maxTokens here is the TOTAL context window (prompt + answer), not the
      // output length. 512 was too small: the RAG prompt alone (5 chunks +
      // question) overflowed it, so the model never even saw the question —
      // the cause of the "no context" answers. 2048 fits the context and
      // leaves room for the answer; maxOutputTokens caps the reply itself.
      final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      final session = await model.createSession(
        temperature: 0.15,
        topK: 1,
        maxOutputTokens: 320,
        systemInstruction:
            'You are a precise document Q&A assistant. Answer ONLY from the '
            'provided context. If the context does not contain the answer, say '
            "you could not find it in the document. Be concise and factual. "
            'When you use information from a source, cite it like [Source 1].',
      );

      final contextBlock = contextChunks.asMap().entries.map((e) {
        return '[Source ${e.key + 1}]: ${e.value}';
      }).join('\n\n');

      final historyBlock = historyTurns.isEmpty
          ? ''
          : 'Previous conversation:\n${historyTurns.join('\n')}\n\n';

      final prompt = '''${historyBlock}Context:
$contextBlock

Question: $question

Answer the question using only the context above. Cite sources as [Source N].''';

      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final raw = await session.getResponse();
      await session.close();

      return _cleanResponse(raw);
    } catch (e) {
      return 'Error generating response: $e';
    }
  }

  /// Strips reasoning-model artifacts from the raw completion.
  ///
  /// Qwen3 emits a `<think>...</think>` block before the answer. When
  /// generation is cut off before the closing tag, the whole visible "answer"
  /// would otherwise be reasoning trace with no content.
  String _cleanResponse(String raw) {
    var text = raw.trim();

    final closedThink = RegExp(r'<think>.*?</think>', dotAll: true);
    text = text.replaceAll(closedThink, '').trim();

    // Unclosed <think> means the model spent the whole budget reasoning —
    // drop the trace and surface whatever came after it, if anything.
    final openIdx = text.indexOf('<think>');
    if (openIdx != -1) {
      final closeIdx = text.indexOf('</think>');
      text = closeIdx == -1
          ? text.substring(0, openIdx).trim()
          : text.replaceAll('<think>', '').replaceAll('</think>', '').trim();
    }

    if (text.isEmpty) {
      return "I thought about this but couldn't produce an answer from the "
          'document. Try rephrasing your question.';
    }
    return text;
  }

  Future<void> clearAllData() async {
    try {
      await _ensureRagInitialized();
      await FlutterGemma.rag.clear();
    } catch (_) {}
  }
}
