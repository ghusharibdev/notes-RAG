import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gemma = ref.watch(gemmaServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Text('Settings', style: AppTextStyles.h1(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        children: [
          _buildSectionHeader(context, 'Model'),
          _buildSettingsTile(
            context,
            icon: Icons.memory_rounded,
            title: 'Generation model',
            subtitle: gemma.isModelInstalled
                ? 'Gemma 3 270M (installed)'
                : 'Not installed',
            onTap: gemma.isModelInstalled
                ? null
                : () => ref.read(initProvider.notifier).downloadModels(),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.compare_arrows_rounded,
            title: 'Embedding model',
            subtitle: gemma.isEmbedderInstalled
                ? 'EmbeddingGemma (installed)'
                : 'Not installed',
            onTap: null,
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Data'),
          _buildSettingsTile(
            context,
            icon: Icons.storage_rounded,
            title: 'Local storage',
            subtitle: 'Vector store (SQLite)',
            onTap: null,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Clear all data',
            subtitle: 'Remove all documents, chat history, and embeddings',
            onTap: () => _showClearDialog(context, ref),
            titleColor: Colors.redAccent,
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Privacy'),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Your data never leaves this device',
            onTap: null,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About Marginal',
            subtitle: 'Version 0.1.0 -- On-device RAG',
            onTap: null,
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Marginal -- On-device RAG',
              style: AppTextStyles.caption(context),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'No data ever leaves your device.',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.moss,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.caption(context).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.plumSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.plum, size: 20),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodySemiBold(context).copyWith(color: titleColor),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.caption(context)),
        trailing: onTap != null
            ? const Icon(Icons.chevron_right_rounded, color: AppColors.inkLight, size: 20)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear all data?', style: AppTextStyles.h2(context)),
        content: Text(
          'This will permanently delete all documents, chat history, and embeddings. This cannot be undone.',
          style: AppTextStyles.body(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.inkLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final gemma = ref.read(gemmaServiceProvider);
              await gemma.clearAllData();
              final storage = ref.read(storageServiceProvider);
              await storage.clearAll();
              ref.read(documentListProvider.notifier).refresh();
            },
            child: Text(
              'Clear',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
