import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../services/resume_pdf.dart';
import '../utils/theme.dart';

/// 履歷匯出畫面：
/// - 預覽 PDF（內含中文字型）
/// - 一鍵下載 PDF / 列印
/// - 切換到 LaTeX 原始碼，可一鍵複製
class ResumeExportScreen extends StatefulWidget {
  const ResumeExportScreen({
    super.key,
    required this.profile,
    required this.persona,
  });

  final UserProfile profile;
  final Persona persona;

  @override
  State<ResumeExportScreen> createState() => _ResumeExportScreenState();
}

class _ResumeExportScreenState extends State<ResumeExportScreen> {
  bool _showLatex = false;
  late final String _latex =
      ResumeBuilder.buildLatex(widget.profile, widget.persona);

  Future<Uint8List> _pdf(_) =>
      ResumeBuilder.buildPdf(widget.profile, widget.persona);

  Future<void> _download() async {
    final bytes = await ResumeBuilder.buildPdf(widget.profile, widget.persona);
    final filename =
        '${widget.profile.name.isEmpty ? "resume" : widget.profile.name}_resume.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<void> _print() async {
    await Printing.layoutPdf(onLayout: _pdf);
  }

  void _copyLatex() {
    Clipboard.setData(ClipboardData(text: _latex));
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已複製 LaTeX'),
        content: const Text('丟到 Overleaf 或本機 xelatex 編譯即可。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        middle: const Text('履歷匯出'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => setState(() => _showLatex = !_showLatex),
          child: Text(
            _showLatex ? 'PDF 預覽' : 'LaTeX 原碼',
            style: const TextStyle(
              color: AppColors.brandStart,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _showLatex ? _latexView() : _pdfView(),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pdfView() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: PdfPreview(
        build: _pdf,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        useActions: false,
        pdfPreviewPageDecoration: const BoxDecoration(color: AppColors.surface),
        loadingWidget: const Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 12),
              Text(
                '正在排版…（首次會下載中文字型）',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _latexView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppColors.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.doc_text,
                    size: 14, color: AppColors.brandStart),
                AppGaps.w6,
                const Text(
                  'LaTeX 原始碼',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.brandStart,
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: _copyLatex,
                  child: const Text(
                    '複製',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandStart,
                    ),
                  ),
                ),
              ],
            ),
            AppGaps.h8,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  _latex,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadii.md),
                onPressed: _print,
                child: const Text(
                  '列印 / 預覽',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            AppGaps.w8,
            Expanded(
              flex: 2,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.brandStart,
                borderRadius: BorderRadius.circular(AppRadii.md),
                onPressed: _download,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.cloud_download_fill,
                        size: 16, color: CupertinoColors.white),
                    AppGaps.w6,
                    Text(
                      '下載履歷 PDF',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
