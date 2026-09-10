import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'citation_chip.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(Citation)? onCitationTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: _estimatedHeight(context),
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: isUser ? AppColors.ink : AppColors.plum,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'Marginal',
                  style: AppTextStyles.caption(context).copyWith(
                    color: isUser ? AppColors.inkLight : AppColors.plum,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.content,
                  style: isUser
                      ? AppTextStyles.body(context)
                      : AppTextStyles.body(context).copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                ),
                if (!isUser && message.citations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: message.citations.map((c) {
                      return CitationChip(
                        documentName: c.documentName,
                        page: c.page,
                        onTap: () => onCitationTap?.call(c),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _estimatedHeight(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: message.content,
        style: AppTextStyles.body(context),
      ),
      maxLines: null,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 60);
    return textPainter.height + 24;
  }
}
