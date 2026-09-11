import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_rag_sqlite/flutter_gemma_rag_sqlite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class GemmaService {
  static const String _defaultAppToken = 'REDACTED_HF_TOKEN';

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

  String? _hfToken = _defaultAppToken;
  set hfToken(String? token) {
    _hfToken = (token != null && token.isNotEmpty) ? token : _defaultAppToken;
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
        huggingFaceToken: _hfToken,
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
        token: _hfToken,
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

  Future<List<double>> embedText(String text) async {
    if (!_initialized || !_embedderInstalled) return [];
    try {
      final embedder = await FlutterGemma.getActiveEmbedder();
      return await embedder.generateEmbedding(text);
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
  }) async {
    try {
      return await FlutterGemma.rag.searchSimilar(query: query, topK: topK);
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
  }) async {
    if (!_initialized || !_modelInstalled) {
      return 'Model not ready. Please complete model download on startup.';
    }

    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 512);
      final session = await model.createSession();
      final contextBlock = contextChunks.asMap().entries.map((e) {
        return '[Source ${e.key + 1}]: ${e.value}';
      }).join('\n\n');

      final prompt = '''Answer based on the context. Cite with [Source N].

Context:
$contextBlock

Question: $question

Answer:''';

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
      await _ensureRagInitialized();
      await FlutterGemma.rag.clear();
    } catch (_) {}
  }
}
