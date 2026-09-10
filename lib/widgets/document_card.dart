import 'package:flutter/material.dart';
import '../models/document.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: AppTextStyles.bodySemiBold(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusText(),
                    style: AppTextStyles.caption(context).copyWith(
                      color: _statusColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildTrailing(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _statusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _statusIcon(),
        color: _statusColor(),
        size: 22,
      ),
    );
  }

  Widget _buildTrailing() {
    if (document.status == DocumentStatus.indexing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.plum,
        ),
      );
    }
    return const Icon(
      Icons.chevron_right,
      color: AppColors.inkLight,
      size: 20,
    );
  }

  String _statusText() {
    switch (document.status) {
      case DocumentStatus.indexing:
        return 'Indexing... ${document.chunkCount > 0 ? "${document.chunkCount} chunks" : ""}';
      case DocumentStatus.indexed:
        return '${document.pageCount} pages · ${document.chunkCount} chunks';
      case DocumentStatus.failed:
        return 'Indexing failed — tap to retry';
    }
  }

  Color _statusColor() {
    switch (document.status) {
      case DocumentStatus.indexing:
        return AppColors.plum;
      case DocumentStatus.indexed:
        return AppColors.moss;
      case DocumentStatus.failed:
        return Colors.redAccent;
    }
  }

  IconData _statusIcon() {
    switch (document.status) {
      case DocumentStatus.indexing:
        return Icons.hourglass_top_rounded;
      case DocumentStatus.indexed:
        return Icons.description_rounded;
      case DocumentStatus.failed:
        return Icons.error_outline_rounded;
    }
  }
}
