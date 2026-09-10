enum DocumentStatus { indexing, indexed, failed }

class DocumentModel {
  final String id;
  final String name;
  final String? filePath;
  final int pageCount;
  final int chunkCount;
  final DocumentStatus status;
  final DateTime createdAt;
  final DateTime? indexedAt;

  const DocumentModel({
    required this.id,
    required this.name,
    this.filePath,
    this.pageCount = 0,
    this.chunkCount = 0,
    this.status = DocumentStatus.indexing,
    required this.createdAt,
    this.indexedAt,
  });

  DocumentModel copyWith({
    String? name,
    int? pageCount,
    int? chunkCount,
    DocumentStatus? status,
    DateTime? indexedAt,
  }) {
    return DocumentModel(
      id: id,
      name: name ?? this.name,
      filePath: filePath,
      pageCount: pageCount ?? this.pageCount,
      chunkCount: chunkCount ?? this.chunkCount,
      status: status ?? this.status,
      createdAt: createdAt,
      indexedAt: indexedAt ?? this.indexedAt,
    );
  }
}
