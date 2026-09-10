import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SourceViewerScreen extends ConsumerStatefulWidget {
  final String documentId;

  const SourceViewerScreen({super.key, required this.documentId});

  @override
  ConsumerState<SourceViewerScreen> createState() => _SourceViewerScreenState();
}

class _SourceViewerScreenState extends ConsumerState<SourceViewerScreen> {
  List<String> _pages = [];
  bool _isLoading = true;
  String? _error;
  final int _highlightPage = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final docs = ref.read(documentListProvider);
    final doc = docs.where((d) => d.id == widget.documentId).firstOrNull;

    if (doc == null || doc.filePath == null) {
      setState(() {
        _error = 'Document not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(doc.filePath!);
      if (!await file.exists()) {
        setState(() {
          _error = 'File not found on disk';
          _isLoading = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final pdfDoc = PdfDocument(inputBytes: bytes);

      final pages = <String>[];
      final extractor = PdfTextExtractor(pdfDoc);

      for (int i = 0; i < pdfDoc.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        pages.add(text.trim());
      }

      pdfDoc.dispose();

      setState(() {
        _pages = pages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentListProvider);
    final doc = docs.where((d) => d.id == widget.documentId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source', style: AppTextStyles.h1(context)),
            Text(
              doc?.name ?? 'Loading...',
              style: AppTextStyles.caption(context),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.plum),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(_error!, style: AppTextStyles.body(context)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final isHighlighted = index == _highlightPage;
                    final pageText = _pages[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppColors.ochreSurface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            top: BorderSide(
                              color: isHighlighted
                                  ? AppColors.ochre.withValues(alpha: 0.3)
                                  : AppColors.border,
                              width: isHighlighted ? 1.5 : 1,
                            ),
                            right: BorderSide(
                              color: isHighlighted
                                  ? AppColors.ochre.withValues(alpha: 0.3)
                                  : AppColors.border,
                              width: isHighlighted ? 1.5 : 1,
                            ),
                            bottom: BorderSide(
                              color: isHighlighted
                                  ? AppColors.ochre.withValues(alpha: 0.3)
                                  : AppColors.border,
                              width: isHighlighted ? 1.5 : 1,
                            ),
                            left: BorderSide(
                              color: isHighlighted
                                  ? AppColors.ochre
                                  : AppColors.border,
                              width: isHighlighted ? 3 : 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isHighlighted
                                        ? AppColors.ochre
                                        : AppColors.inkLight.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: AppTextStyles.caption(context).copyWith(
                                        color: isHighlighted
                                            ? Colors.white
                                            : AppColors.inkLight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isHighlighted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.ochre.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Cited',
                                      style: AppTextStyles.caption(context).copyWith(
                                        color: AppColors.ochre,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pageText.isEmpty ? '(No extractable text on this page)' : pageText,
                              style: AppTextStyles.body(context).copyWith(
                                color: isHighlighted
                                    ? AppColors.ink
                                    : AppColors.inkLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
