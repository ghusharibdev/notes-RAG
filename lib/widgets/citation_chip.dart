import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CitationChip extends StatelessWidget {
  final String documentName;
  final int page;
  final VoidCallback? onTap;

  const CitationChip({
    super.key,
    required this.documentName,
    required this.page,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.ochreSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$documentName, p.$page',
          style: AppTextStyles.caption(context).copyWith(
            color: AppColors.ochre,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
