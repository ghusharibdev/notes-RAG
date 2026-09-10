import 'package:hive_flutter/hive_flutter.dart';
import '../models/document.dart';

class StorageService {
  static const String _documentsBox = 'documents';
  static const String _settingsBox = 'settings';
  static const String _onboardingKey = 'onboarding_complete';

  late Box<DocumentModel> _documents;
  late Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DocumentModelAdapter());
    _documents = await Hive.openBox<DocumentModel>(_documentsBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  List<DocumentModel> getAllDocuments() {
    return _documents.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  DocumentModel? getDocument(String id) {
    return _documents.get(id);
  }

  Future<void> saveDocument(DocumentModel doc) async {
    await _documents.put(doc.id, doc);
  }

  Future<void> deleteDocument(String id) async {
    await _documents.delete(id);
  }

  Future<void> clearAllDocuments() async {
    await _documents.clear();
  }

  bool get isOnboardingComplete {
    return _settings.get(_onboardingKey, defaultValue: false) as bool;
  }

  Future<void> setOnboardingComplete() async {
    await _settings.put(_onboardingKey, true);
  }

  Future<void> clearAll() async {
    await _documents.clear();
    await _settings.clear();
  }
}

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DocumentModel(
      id: fields[0] as String,
      name: fields[1] as String,
      filePath: fields[2] as String?,
      pageCount: fields[3] as int,
      chunkCount: fields[4] as int,
      status: DocumentStatus.values[fields[5] as int],
      createdAt: fields[6] as DateTime,
      indexedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.pageCount)
      ..writeByte(4)
      ..write(obj.chunkCount)
      ..writeByte(5)
      ..write(obj.status.index)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.indexedAt);
  }
}
