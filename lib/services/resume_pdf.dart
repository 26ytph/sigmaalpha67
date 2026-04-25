import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// 履歷產生器：使用 Harshibar 風格的 LaTeX 模板（簡化版），
/// 全部以「純文字 + 細線分隔」呈現 — 不使用任何 FontAwesome 圖示
/// 與外框包字 (\myuline) 等裝飾。
///
/// 中文支援：LaTeX 用 xeCJK + Noto Sans TC（需要 xelatex 編譯）；
/// PDF 用 Google Fonts 的 Noto Sans TC 動態下載字型。
class ResumeBuilder {
  ResumeBuilder._();

  // —— 模組層字型快取（避免每次重新下載 / 解析） ——
  static Uint8List? _regularFontBytes;
  static Uint8List? _boldFontBytes;

  static Future<({Uint8List regular, Uint8List bold})> _loadFonts() async {
    if (_regularFontBytes == null || _boldFontBytes == null) {
      // 在主 isolate 取得字型數據（parsing 會在這裡發生一次，這在 mobile 會造成短暫卡頓）。
      // 由於 PdfGoogleFonts 目前沒有暴露直接獲取 raw bytes 而不解析的 API，
      // 我們先在主 isolate 解析一次以獲取 bytes，隨後傳遞給 worker 進行真正的 PDF 渲染。
      final regular = await PdfGoogleFonts.notoSansTCRegular();
      final bold = await PdfGoogleFonts.notoSansTCBold();

      // 提取字型 raw bytes。TtfFont 才有 .data 屬性。
      final regTtf = regular as pw.TtfFont;
      final boldTtf = bold as pw.TtfFont;

      _regularFontBytes = regTtf.data.buffer.asUint8List(
        regTtf.data.offsetInBytes,
        regTtf.data.lengthInBytes,
      );
      _boldFontBytes = boldTtf.data.buffer.asUint8List(
        boldTtf.data.offsetInBytes,
        boldTtf.data.lengthInBytes,
      );
    }
    return (regular: _regularFontBytes!, bold: _boldFontBytes!);
  }

  // ---------------------------------------------------------------------
  // LaTeX
  // ---------------------------------------------------------------------

  static String buildLatex(UserProfile p, Persona persona) {
    String esc(String s) => s
        .replaceAll(r'\', r'\textbackslash{}')
        .replaceAll('&', r'\&')
        .replaceAll('%', r'\%')
        .replaceAll(r'$', r'\$')
        .replaceAll('#', r'\#')
        .replaceAll('_', r'\_')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('~', r'\textasciitilde{}')
        .replaceAll('^', r'\textasciicircum{}');

    // 標頭聯絡資訊（純文字，用 $|$ 分隔）
    final contactBits = <String>[
      if (p.email.isNotEmpty) p.email,
      if (p.phone.isNotEmpty) p.phone,
      if (p.location.isNotEmpty) p.location,
      if (p.age != null) '${p.age} 歲',
    ];

    final buf = StringBuffer();

    // —— Preamble（沿用 Harshibar 結構，但移除 fontawesome / FiraMono / contour） ——
    buf
      ..writeln('%-------------------------')
      ..writeln('% EmploYA Resume — Harshibar style (plain text, xelatex)')
      ..writeln('%-------------------------')
      ..writeln(r'\documentclass[letterpaper,11pt]{article}')
      ..writeln(r'\usepackage{latexsym}')
      ..writeln(r'\usepackage[empty]{fullpage}')
      ..writeln(r'\usepackage{titlesec}')
      ..writeln(r'\usepackage[usenames,dvipsnames]{color}')
      ..writeln(r'\usepackage{enumitem}')
      ..writeln(r'\usepackage[hidelinks]{hyperref}')
      ..writeln(r'\usepackage{fancyhdr}')
      ..writeln(r'\usepackage[english]{babel}')
      ..writeln(r'\usepackage{tabularx}')
      ..writeln(r'\usepackage{xeCJK}')
      ..writeln(r'\setCJKmainfont{Noto Sans TC}')
      ..writeln(r'\definecolor{light-grey}{gray}{0.83}')
      ..writeln(r'\definecolor{dark-grey}{gray}{0.3}')
      ..writeln(r'\definecolor{text-grey}{gray}{0.08}')
      ..writeln(r'\pagestyle{fancy}')
      ..writeln(r'\fancyhf{}')
      ..writeln(r'\fancyfoot{}')
      ..writeln(r'\renewcommand{\headrulewidth}{0pt}')
      ..writeln(r'\renewcommand{\footrulewidth}{0pt}')
      ..writeln(r'\addtolength{\oddsidemargin}{-0.5in}')
      ..writeln(r'\addtolength{\evensidemargin}{0in}')
      ..writeln(r'\addtolength{\textwidth}{1in}')
      ..writeln(r'\addtolength{\topmargin}{-.5in}')
      ..writeln(r'\addtolength{\textheight}{1.0in}')
      ..writeln(r'\urlstyle{same}')
      ..writeln(r'\raggedbottom')
      ..writeln(r'\raggedright')
      ..writeln(r'\setlength{\tabcolsep}{0in}')
      ..writeln()
      // sans-serif sections (與 Harshibar 完全一致)
      ..writeln(r'\titleformat{\section}{')
      ..writeln(r'    \bfseries \vspace{2pt} \raggedright \large')
      ..writeln(r'}{}{0em}{}[\color{light-grey}{\titlerule[2pt]}\vspace{-4pt}]')
      ..writeln()
      // —— 自訂 commands（純文字版 — 移除 \myuline / faIcons） ——
      ..writeln(r'\newcommand{\resumeItem}[1]{\item\small{{#1 \vspace{-1pt}}}}')
      ..writeln(r'\newcommand{\resumeSubheading}[4]{')
      ..writeln(r'  \vspace{-1pt}\item')
      ..writeln(r'    \begin{tabular*}{\textwidth}[t]{l@{\extracolsep{\fill}}r}')
      ..writeln(r'      \textbf{#1} & {\color{dark-grey}\small #2}\vspace{1pt}\\')
      ..writeln(r'      \textit{#3} & {\color{dark-grey}\small #4}\\')
      ..writeln(r'    \end{tabular*}\vspace{-4pt}}')
      ..writeln(r'\newcommand{\resumeProjectHeading}[2]{')
      ..writeln(r'  \item')
      ..writeln(r'    \begin{tabular*}{\textwidth}{l@{\extracolsep{\fill}}r}')
      ..writeln(r'      #1 & {\color{dark-grey}\small #2}\\')
      ..writeln(r'    \end{tabular*}\vspace{-4pt}}')
      ..writeln(r'\renewcommand\labelitemii{$\vcenter{\hbox{\tiny$\bullet$}}$}')
      ..writeln(r'\newcommand{\resumeSubHeadingListStart}{\begin{itemize}[leftmargin=0in, label={}]}')
      ..writeln(r'\newcommand{\resumeSubHeadingListEnd}{\end{itemize}}')
      ..writeln(r'\newcommand{\resumeItemListStart}{\begin{itemize}}')
      ..writeln(r'\newcommand{\resumeItemListEnd}{\end{itemize}\vspace{0pt}}')
      ..writeln(r'\color{text-grey}')
      ..writeln()
      ..writeln(r'\begin{document}')
      ..writeln();

    // —— Heading：純文字（無 icon） ——
    buf
      ..writeln('%----------HEADING----------')
      ..writeln(r'\begin{center}')
      ..writeln('    \\textbf{\\Huge ${esc(p.name.isEmpty ? '尚未命名' : p.name)}} \\\\\\vspace{5pt}');
    if (contactBits.isNotEmpty) {
      // 用 $|$ 分隔，純文字
      final separated =
          contactBits.map(esc).join(r' \hspace{1pt} $|$ \hspace{1pt} ');
      buf.writeln('    \\small $separated \\\\\\vspace{-3pt}');
    }
    buf
      ..writeln(r'\end{center}')
      ..writeln();

    // —— ABOUT ——（自介）
    if (persona.text.isNotEmpty) {
      buf
        ..writeln('%----------ABOUT----------')
        ..writeln(r'\section{ABOUT}')
        ..writeln(r'\small ${esc(persona.text)}'.replaceFirst(
            r'${esc(persona.text)}', esc(persona.text)))
        ..writeln();
    }

    // —— EDUCATION ——
    if (p.educationItems.isNotEmpty) {
      buf
        ..writeln('%----------EDUCATION----------')
        ..writeln(r'\section{EDUCATION}')
        ..writeln(r'  \resumeSubHeadingListStart');
      for (final e in p.educationItems) {
        // 把學校 / 科系-年級 / location 排版到 resumeSubheading 的四個欄位
        final school = esc(e.school.isEmpty ? '—' : e.school);
        final dept = esc(e.department);
        final grade = esc(e.grade);
        final loc = esc(p.location);
        final right2 = grade.isEmpty ? '' : grade;
        buf.writeln('    \\resumeSubheading');
        buf.writeln('      {$school}{$right2}');
        buf.writeln('      {$dept}{$loc}');
      }
      buf
        ..writeln(r'  \resumeSubHeadingListEnd')
        ..writeln();
    }

    // —— EXPERIENCE ——（個人經歷 — 用 resumeProjectHeading 簡單列出）
    if (p.experiences.isNotEmpty) {
      buf
        ..writeln('%----------EXPERIENCE----------')
        ..writeln(r'\section{EXPERIENCE}')
        ..writeln(r'  \resumeSubHeadingListStart');
      for (final e in p.experiences) {
        buf.writeln('    \\resumeProjectHeading');
        buf.writeln('      {\\textbf{${esc(e)}}}{}');
      }
      buf
        ..writeln(r'  \resumeSubHeadingListEnd')
        ..writeln();
    }

    // —— SKILLS ——（純文字，逗號分隔，無 chip）
    if (persona.strengths.isNotEmpty) {
      buf
        ..writeln('%----------SKILLS----------')
        ..writeln(r'\section{SKILLS}')
        ..writeln(r' \begin{itemize}[leftmargin=0in, label={}]')
        ..writeln(r'    \small{\item{')
        ..writeln('     ${esc(persona.strengths.join(', '))}')
        ..writeln(r'    }}')
        ..writeln(r' \end{itemize}')
        ..writeln();
    }

    // —— INTERESTS ——
    if (p.interests.isNotEmpty) {
      buf
        ..writeln('%----------INTERESTS----------')
        ..writeln(r'\section{INTERESTS}')
        ..writeln(r' \begin{itemize}[leftmargin=0in, label={}]')
        ..writeln(r'    \small{\item{')
        ..writeln('     ${esc(p.interests.join(', '))}')
        ..writeln(r'    }}')
        ..writeln(r' \end{itemize}')
        ..writeln();
    }

    // —— CURRENT FOCUS ——（目前方向 / 困擾）
    if (p.concerns.isNotEmpty) {
      buf
        ..writeln('%----------CURRENT FOCUS----------')
        ..writeln(r'\section{CURRENT FOCUS}')
        ..writeln('\\small ${esc(p.concerns)}')
        ..writeln();
    }

    buf
      ..writeln(r'\end{document}');
    return buf.toString();
  }

  // ---------------------------------------------------------------------
  // PDF
  //
  // Why this layout: CJK font subsetting inside `doc.save()` is pure-Dart
  // CPU work; on AOT-compiled Windows / Android it pins the UI thread
  // for several seconds (the freeze symptom). We:
  //   1. Fetch + cache the fonts on the main isolate (only `printing`
  //      can do this — it relies on plugin platform channels).
  //   2. Send the raw font bytes plus a plain-data payload into a
  //      worker isolate via `compute`, where the document is built and
  //      `doc.save()` runs without blocking the UI.
  // ---------------------------------------------------------------------

  static Future<Uint8List> buildPdf(UserProfile p, Persona persona) async {
    final fonts = await _loadFonts();
    final args = _PdfArgs(
      regularBytes: fonts.regular,
      boldBytes: fonts.bold,
      name: p.name,
      email: p.email,
      phone: p.phone,
      location: p.location,
      age: p.age,
      educationItems: p.educationItems
          .map((e) => _Edu(
                school: e.school,
                department: e.department,
                grade: e.grade,
              ))
          .toList(growable: false),
      experiences: List<String>.unmodifiable(p.experiences),
      interests: List<String>.unmodifiable(p.interests),
      concerns: p.concerns,
      personaText: persona.text,
      personaStrengths: List<String>.unmodifiable(persona.strengths),
    );
    return compute(_renderPdf, args);
  }
}

// —— Plain data classes — sendable across isolates ——

class _Edu {
  const _Edu({
    required this.school,
    required this.department,
    required this.grade,
  });
  final String school;
  final String department;
  final String grade;
}

class _PdfArgs {
  const _PdfArgs({
    required this.regularBytes,
    required this.boldBytes,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.age,
    required this.educationItems,
    required this.experiences,
    required this.interests,
    required this.concerns,
    required this.personaText,
    required this.personaStrengths,
  });

  final Uint8List regularBytes;
  final Uint8List boldBytes;
  final String name;
  final String email;
  final String phone;
  final String location;
  final int? age;
  final List<_Edu> educationItems;
  final List<String> experiences;
  final List<String> interests;
  final String concerns;
  final String personaText;
  final List<String> personaStrengths;
}

// Top-level worker — no captures, runs in a worker isolate spawned by
// `compute`. Receives all data via [a].
Future<Uint8List> _renderPdf(_PdfArgs a) async {
  // 將字型 bytes 解析為 pw.Font。這在 worker isolate 中進行，不卡住 UI。
  final regular = pw.Font.ttf(a.regularBytes.buffer.asByteData());
  final bold = pw.Font.ttf(a.boldBytes.buffer.asByteData());

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    italic: regular,
    boldItalic: bold,
  );

  final contactBits = <String>[
    if (a.email.isNotEmpty) a.email,
    if (a.phone.isNotEmpty) a.phone,
    if (a.location.isNotEmpty) a.location,
    if (a.age != null) '${a.age} 歲',
  ];

  // —— Section heading：粗體 + 下方淡灰粗線（同 Harshibar 風） ——
  pw.Widget sectionHeading(String s) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              color: PdfColor.fromInt(0xFFD4D4D4),
              width: 1.6,
            ),
          ),
        ),
        child: pw.Text(
          s,
          style: pw.TextStyle(font: bold, fontSize: 13.5),
        ),
      );

  // —— 純文字段落（不用 bullet、不用底色） ——
  pw.Widget paragraph(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
        child: pw.Text(
          s,
          style: pw.TextStyle(
            fontSize: 11,
            lineSpacing: 3,
            color: const PdfColor.fromInt(0xFF222222),
          ),
        ),
      );

  // —— 經歷 / 學歷：用 LaTeX resumeSubheading 的左右排版（不再用圓點 + 圓底色） ——
  pw.Widget twoLineEntry({
    required String topLeft,
    String topRight = '',
    String bottomLeft = '',
    String bottomRight = '',
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  topLeft,
                  style: pw.TextStyle(font: bold, fontSize: 11.5),
                ),
              ),
              if (topRight.isNotEmpty)
                pw.Text(
                  topRight,
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    color: const PdfColor.fromInt(0xFF666666),
                  ),
                ),
            ],
          ),
          if (bottomLeft.isNotEmpty || bottomRight.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      bottomLeft,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: const PdfColor.fromInt(0xFF333333),
                      ),
                    ),
                  ),
                  if (bottomRight.isNotEmpty)
                    pw.Text(
                      bottomRight,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        color: const PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      theme: theme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // —— Heading ——
          pw.Center(
            child: pw.Text(
              a.name.isEmpty ? '尚未命名' : a.name,
              style: pw.TextStyle(font: bold, fontSize: 26),
            ),
          ),
          pw.SizedBox(height: 4),
          if (contactBits.isNotEmpty)
            pw.Center(
              child: pw.Text(
                contactBits.join('  |  '),
                style: pw.TextStyle(
                  fontSize: 10.5,
                  color: const PdfColor.fromInt(0xFF555555),
                ),
              ),
            ),
          pw.SizedBox(height: 8),

          // —— ABOUT —— 自介
          if (a.personaText.isNotEmpty) ...[
            sectionHeading('ABOUT'),
            paragraph(a.personaText),
          ],

          // —— EDUCATION ——
          if (a.educationItems.isNotEmpty) ...[
            sectionHeading('EDUCATION'),
            for (final e in a.educationItems)
              twoLineEntry(
                topLeft: e.school.isEmpty ? '—' : e.school,
                topRight: e.grade,
                bottomLeft: e.department,
                bottomRight: a.location,
              ),
          ],

          // —— EXPERIENCE ——
          if (a.experiences.isNotEmpty) ...[
            sectionHeading('EXPERIENCE'),
            for (final e in a.experiences) twoLineEntry(topLeft: e),
          ],

          // —— SKILLS —— 純文字，逗號分隔
          if (a.personaStrengths.isNotEmpty) ...[
            sectionHeading('SKILLS'),
            paragraph(a.personaStrengths.join('，')),
          ],

          // —— INTERESTS ——
          if (a.interests.isNotEmpty) ...[
            sectionHeading('INTERESTS'),
            paragraph(a.interests.join('，')),
          ],

          // —— CURRENT FOCUS ——
          if (a.concerns.isNotEmpty) ...[
            sectionHeading('CURRENT FOCUS'),
            paragraph(a.concerns),
          ],
        ],
      ),
    ),
  );

  return doc.save();
}
