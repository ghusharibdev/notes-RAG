import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RetrievalTrace extends StatefulWidget {
  final List<String> chunkPreviews;

  const RetrievalTrace({
    super.key,
    required this.chunkPreviews,
  });

  @override
  State<RetrievalTrace> createState() => _RetrievalTraceState();
}

class _RetrievalTraceState extends State<RetrievalTrace>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  final List<AnimationController> _itemControllers = [];
  final List<Animation<double>> _itemAnimations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    for (int i = 0; i < widget.chunkPreviews.length; i++) {
      final delay = i * 200;
      final itemController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _itemControllers.add(itemController);
      _itemAnimations.add(
        CurvedAnimation(parent: itemController, curve: Curves.easeOutCubic),
      );
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) itemController.forward();
      });
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.plumSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.plum.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.plum,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Retrieving from your notes...',
                  style: AppTextStyles.caption(context).copyWith(
                    color: AppColors.plum,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(widget.chunkPreviews.length, (i) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.3, 0),
                  end: Offset.zero,
                ).animate(_itemAnimations[i]),
                child: FadeTransition(
                  opacity: _itemAnimations[i],
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 36,
                          margin: const EdgeInsets.only(right: 10, top: 2),
                          decoration: BoxDecoration(
                            color: AppColors.plum.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.chunkPreviews[i],
                            style: AppTextStyles.caption(context).copyWith(
                              color: AppColors.inkLight,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
