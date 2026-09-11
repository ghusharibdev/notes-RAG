import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_message.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/message_bubble.dart';
import '../widgets/retrieval_trace.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String documentId;

  const ChatScreen({super.key, required this.documentId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isRetrieving = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(chatMessagesProvider(widget.documentId).notifier);
    if (notifier.isProcessing) return;

    _inputController.clear();

    setState(() => _isRetrieving = true);

    _scrollToBottom();

    await notifier.sendQuestion(text);

    setState(() => _isRetrieving = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.documentId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat', style: AppTextStyles.h1(context)),
            Text(
              messages.where((m) => m.role == MessageRole.user).isNotEmpty
                  ? '${messages.where((m) => m.role == MessageRole.user).length} questions asked'
                  : 'Ask anything about your document',
              style: AppTextStyles.caption(context),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !_isRetrieving
                ? _buildEmptyChat(context)
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                    children: [
                      for (final message in messages) ...[
                        if (message.isStreaming)
                          const RetrievalTrace(chunkPreviews: [
                            'Searching your notes...',
                            'Finding relevant passages...',
                            'Preparing answer...',
                          ])
                        else
                          MessageBubble(
                            message: message,
                            onCitationTap: (citation) {
                              context.push('/source/${widget.documentId}/${citation.page}');
                            },
                          ),
                      ],
                    ],
                  ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.plumSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 28,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(height: 16),
            Text('Ask a question', style: AppTextStyles.h2(context)),
            const SizedBox(height: 6),
            Text(
              'Type below to ask anything about this document.\nCitations will link back to specific passages.',
              style: AppTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.documentId));
    final isProcessing = messages.isNotEmpty && messages.last.isStreaming;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: BoxDecoration(
        color: AppColors.stone,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              style: AppTextStyles.inputText(context),
              decoration: const InputDecoration(
                hintText: 'Ask a question...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isProcessing ? AppColors.plumLight : AppColors.plum,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: isProcessing ? null : _sendMessage,
              icon: Icon(
                isProcessing ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                color: AppColors.stone,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
