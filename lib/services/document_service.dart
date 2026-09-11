import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/document.dart';
import 'storage_service.dart';
import 'gemma_service.dart';

class DocumentService {
  final StorageService _storage;
  final GemmaService _gemma;

  // The embedder (MiniLM-L12-v2) truncates input at ~256 wordpiece tokens
  // (~180 plain words). Chunks must stay well under that or their middle gets
  // silently cut off before embedding, which is what made retrieval miss
  // whole sections (e.g. the skills list on a resume).
  static const int _chunkSizeWords = 140;
  static const int _chunkOverlapWords = 30;

  /// Bump whenever chunking/indexing logic changes in a way that requires
  /// re-indexing existing documents. In [indexDocument] we persist this
  /// version, and the provider re-indexes everything below it on startup.
  static const int chunkerVersion = 2;

  DocumentService(this._storage, this._gemma);

  List<DocumentModel> get documents => _storage.getAllDocuments();

  Future<DocumentModel> addDocument(String filePath) async {
    final id = const Uuid().v4();
    final name = p.basename(filePath);

    final appDir = await getApplicationDocumentsDirectory();
    final sourceFile = File(filePath);
    final destPath = '${appDir.path}/$id-$name';
    await sourceFile.copy(destPath);

    final doc = DocumentModel(
      id: id,
      name: name,
      filePath: destPath,
      createdAt: DateTime.now(),
    );

    await _storage.saveDocument(doc);
    return doc;
  }

  Future<void> indexDocument(String docId) async {
    final doc = _storage.getDocument(docId);
    if (doc == null || doc.filePath == null) return;

    await _storage.saveDocument(doc.copyWith(status: DocumentStatus.indexing));

    try {
      final file = File(doc.filePath!);
      if (!await file.exists()) {
        await _storage.saveDocument(doc.copyWith(status: DocumentStatus.failed));
        return;
      }

      // Any chunks from a previous (failed/partial) indexing attempt must go
      // first, otherwise retried docs keep surfacing stale duplicates.
      await _gemma.deleteDocumentChunks(docId, chunkCount: doc.chunkCount);

      final pages = await _extractTextByPage(file);
      if (pages.every((pageText) => pageText.trim().isEmpty)) {
        await _storage.saveDocument(doc.copyWith(status: DocumentStatus.failed));
        return;
      }

      final safeName = doc.name.replaceAll('"', "'");
      int indexedCount = 0;

      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final pageText = pages[pageIndex].trim();
        if (pageText.isEmpty) continue;

        final chunks = _chunkText(pageText);
        for (int chunkIdx = 0; chunkIdx < chunks.length; chunkIdx++) {
          final embedding =
              await _gemma.embedText(chunks[chunkIdx], taskType: EmbeddingTaskType.document);

          if (embedding.isNotEmpty) {
            await _gemma.addDocumentToVectorStore(
              id: '${docId}_chunk_$indexedCount',
              content: chunks[chunkIdx],
              embedding: embedding,
              metadata:
                  '{"documentId":"$docId","page":$pageIndex,"docName":"$safeName"}',
            );
            indexedCount++;
          }
        }
      }

      if (indexedCount == 0) {
        // Nothing got embedded — most commonly the embedder isn't ready.
        // Reporting success here would leave a doc that silently answers
        // "no context" forever, so fail visibly instead.
        await _storage.saveDocument(doc.copyWith(status: DocumentStatus.failed));
        return;
      }

      await _storage.saveDocument(doc.copyWith(
        status: DocumentStatus.indexed,
        chunkCount: indexedCount,
        pageCount: _getPageCount(doc.filePath!),
        indexedAt: DateTime.now(),
      ));
    } catch (e) {
      await _storage.saveDocument(doc.copyWith(status: DocumentStatus.failed));
    }
  }

  Future<List<String>> _extractTextByPage(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final pages = <String>[];
    final extractor = PdfTextExtractor(document);

    for (int i = 0; i < document.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      pages.add(text);
    }

    document.dispose();
    return pages;
  }

  int _getPageCount(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final count = document.pages.count;
      document.dispose();
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Splits [text] into overlapping chunks of [_chunkSizeWords] words.
  ///
  /// Words are used (not characters) as a conservative proxy for tokens:
  /// 140 words is ~190 wordpiece tokens, safely under the embedder's ~256
  /// token truncation limit for prose. The overlap keeps sentences that
  /// straddle a boundary findable from both sides.
  List<String> _chunkText(String text) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    int i = 0;
    while (i < words.length) {
      final end = min(i + _chunkSizeWords, words.length);
      final chunk = words.sublist(i, end).join(' ').trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      if (end >= words.length) break;
      i += _chunkSizeWords - _chunkOverlapWords;
    }

    return chunks;
  }

  Future<void> deleteDocument(String docId) async {
    final doc = _storage.getDocument(docId);
    if (doc == null) return;

    if (doc.filePath != null) {
      final file = File(doc.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _gemma.deleteDocumentChunks(docId, chunkCount: doc.chunkCount);
    await _storage.deleteDocument(docId);
  }

  Future<void> retryIndexing(String docId) async {
    final doc = _storage.getDocument(docId);
    if (doc == null) return;
    // Keep the stored chunkCount so indexDocument can delete the old chunks
    // before writing new ones (prevents stale leftovers from a previous run).
    await _storage.saveDocument(doc.copyWith(status: DocumentStatus.indexing));
    await indexDocument(docId);
  }

  /// Re-indexes indexed documents when the chunking logic changed since the
  /// last run. Docs indexed before the current [chunkerVersion] were built
  /// with oversized chunks that broke retrieval, so they must be rebuilt.
  /// Skipped when models aren't ready yet — retried on next launch.
  Future<void> reindexAllIfStale() async {
    if (_storage.chunkerVersion >= chunkerVersion) return;
    if (!_gemma.isInitialized || !_gemma.isEmbedderInstalled) return;

    var reindexed = 0;
    for (final doc in documents) {
      if (doc.status == DocumentStatus.indexed) {
        await retryIndexing(doc.id);
        reindexed++;
      }
    }
    // Persist only after a fully successful pass, so a crash mid-way retries
    // everything next launch instead of leaving half the library stale.
    if (reindexed > 0) {
      await _storage.setChunkerVersion(chunkerVersion);
    }
  }
}
