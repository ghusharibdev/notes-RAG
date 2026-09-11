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
  static const int _chunkSize = 500;
  static const int _chunkOverlap = 100;

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

      final pages = await _extractTextByPage(file);
      if (pages.isEmpty) {
        await _storage.saveDocument(doc.copyWith(status: DocumentStatus.failed));
        return;
      }

      int indexedCount = 0;

      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final pageText = pages[pageIndex];
        if (pageText.isEmpty) continue;

        final chunks = _chunkText(pageText);
        for (int chunkIdx = 0; chunkIdx < chunks.length; chunkIdx++) {
          final chunkId = '${docId}_chunk_$indexedCount';
          final embedding = await _gemma.embedText(chunks[chunkIdx]);

          if (embedding.isNotEmpty) {
            await _gemma.addDocumentToVectorStore(
              id: chunkId,
              content: chunks[chunkIdx],
              embedding: embedding,
              metadata: '{"documentId":"$docId","page":$pageIndex}',
            );
            indexedCount++;
          }
        }
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

  List<String> _chunkText(String text) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    for (int i = 0; i < words.length; i += _chunkSize - _chunkOverlap) {
      final end = min(i + _chunkSize, words.length);
      final chunk = words.sublist(i, end).join(' ').trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
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
    await _storage.saveDocument(doc.copyWith(
      status: DocumentStatus.indexing,
      chunkCount: 0,
    ));
    await indexDocument(docId);
  }
}
