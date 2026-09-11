import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/gemma_service.dart';
import 'services/document_service.dart';
import 'services/rag_service.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final gemmaService = GemmaService();
  final documentService = DocumentService(storageService, gemmaService);
  final ragService = RagService(gemmaService);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        gemmaServiceProvider.overrideWithValue(gemmaService),
        documentServiceProvider.overrideWithValue(documentService),
        ragServiceProvider.overrideWithValue(ragService),
      ],
      child: const MarginalApp(),
    ),
  );
}

class MarginalApp extends StatelessWidget {
  const MarginalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Marginal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
