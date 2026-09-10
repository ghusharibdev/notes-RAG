import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentListProvider);
    final init = ref.watch(initProvider);
    final indexedCount =
        documents.where((d) => d.status == DocumentStatus.indexed).length;

    if (init.status == InitStatus.ready && !init.modelsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/onboarding');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Marginal',
                            style: AppTextStyles.display(context)),
                        const SizedBox(height: 4),
                        Text(
                          '$indexedCount document${indexedCount == 1 ? '' : 's'} indexed',
                          style: AppTextStyles.caption(context),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded, size: 22),
                    color: AppColors.inkLight,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: documents.isEmpty
                  ? const EmptyState(
                      icon: Icons.note_add_outlined,
                      title: 'No documents yet',
                      subtitle:
                          'Add your first PDF or note to start asking questions.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      itemCount: documents.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return DocumentCard(
                          document: doc,
                          onTap: doc.status == DocumentStatus.indexed
                              ? () => context.push('/chat/${doc.id}')
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickDocument(context, ref),
        backgroundColor: AppColors.plum,
        foregroundColor: AppColors.stone,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  Future<void> _pickDocument(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty) {
      final file = files.first;
      if (file.path != null) {
        await ref.read(documentListProvider.notifier).addDocument(file.path!);
      }
    }
  }
}
