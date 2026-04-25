import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

class ResumeBuilder {
  ResumeBuilder._();

  /// 把 Profile + Persona 套到 LaTeX article 模板，回傳 .tex 原始碼。
  /// 任何含中文的部分都會被 LaTeX 跳脫。
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

    final contactBits = <String>[
      if (p.contact.isNotEmpty) p.contact,
      if (p.location.isNotEmpty) p.location,
      if (p.school.isNotEmpty) p.school,
      if (p.age != null) '${p.age} 歲',
    ];

    final buf = StringBuffer()
      ..writeln(r'\documentclass[11pt]{article}')
      ..writeln(r'\usepackage{xeCJK}')
      ..writeln(r'\setCJKmainfont{Noto Sans TC}')
      ..writeln(r'\usepackage[margin=0.9in]{geometry}')
      ..writeln(r'\usepackage{enumitem}')
      ..writeln(r'\usepackage{titlesec}')
      ..writeln(r'\titleformat{\section}{\large\bfseries}{}{0em}{}[\titlerule]')
      ..writeln(r'\titlespacing*{\section}{0pt}{14pt}{6pt}')
      ..writeln(r'\setlist[itemize]{leftmargin=1.2em,itemsep=2pt,topsep=2pt}')
      ..writeln(r'\pagestyle{empty}')
      ..writeln(r'\begin{document}')
      ..writeln()
      ..writeln(r'\begin{center}')
      ..writeln('{\\LARGE \\textbf{${esc(p.name.isEmpty ? '尚未命名' : p.name)}}}\\\\[2pt]')
      ..writeln('\\small ${esc(contactBits.map(esc).join(r' $\cdot$ '))}')
      ..writeln(r'\end{center}');

    if (persona.text.isNotEmpty) {
      buf
        ..writeln(r'\section*{自介}')
        ..writeln(esc(persona.text));
    }

    if (p.educationItems.isNotEmpty) {
      buf
        ..writeln(r'\section*{學歷}')
        ..writeln(r'\begin{itemize}');
      for (final e in p.educationItems) {
        buf.writeln('  \\item ${esc(e)}');
      }
      buf.writeln(r'\end{itemize}');
    }

    if (p.experiences.isNotEmpty) {
      buf
        ..writeln(r'\section*{經歷}')
        ..writeln(r'\begin{itemize}');
      for (final e in p.experiences) {
        buf.writeln('  \\item ${esc(e)}');
      }
      buf.writeln(r'\end{itemize}');
    }

    if (persona.strengths.isNotEmpty) {
      buf
        ..writeln(r'\section*{技能}')
        ..writeln(esc(persona.strengths.join(r' $\cdot$ ')));
    }

    if (p.interests.isNotEmpty) {
      buf
        ..writeln(r'\section*{興趣}')
        ..writeln(esc(p.interests.join(r' $\cdot$ ')));
    }

    if (p.concerns.isNotEmpty) {
      buf
        ..writeln(r'\section*{目前的方向／困擾}')
        ..writeln(esc(p.concerns));
    }

    buf
      ..writeln()
      ..writeln(r'\end{document}');

    return buf.toString();
  }

  /// 把 Profile + Persona 直接渲染成 PDF（中文字型由 Google Fonts 動態下載）。
  static Future<Uint8List> buildPdf(UserProfile p, Persona persona) async {
    final regular = await PdfGoogleFonts.notoSansTCRegular();
    final bold = await PdfGoogleFonts.notoSansTCBold();

    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final contactBits = <String>[
      if (p.contact.isNotEmpty) p.contact,
      if (p.location.isNotEmpty) p.location,
      if (p.school.isNotEmpty) p.school,
      if (p.age != null) '${p.age} 歲',
    ];

    pw.Widget sectionHeading(String s) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
            ),
          ),
          child: pw.Text(
            s,
            style: pw.TextStyle(font: bold, fontSize: 14),
          ),
        );

    pw.Widget bulletList(List<String> items) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items
              .map(
                (e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(top: 5, right: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey700,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          e,
                          style: pw.TextStyle(fontSize: 11.5, lineSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
        theme: theme,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text(
                p.name.isEmpty ? '尚未命名' : p.name,
                style: pw.TextStyle(font: bold, fontSize: 26),
              ),
            ),
            pw.SizedBox(height: 4),
            if (contactBits.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  contactBits.join('  ·  '),
                  style: pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700),
                ),
              ),

            // 自介
            if (persona.text.isNotEmpty) ...[
              sectionHeading('自介'),
              pw.Text(
                persona.text,
                style: pw.TextStyle(fontSize: 11.5, lineSpacing: 3),
              ),
            ],

            // 學歷
            if (p.educationItems.isNotEmpty) ...[
              sectionHeading('學歷'),
              bulletList(p.educationItems),
            ],

            // 經歷
            if (p.experiences.isNotEmpty) ...[
              sectionHeading('經歷'),
              bulletList(p.experiences),
            ],

            // 技能
            if (persona.strengths.isNotEmpty) ...[
              sectionHeading('技能'),
              pw.Wrap(
                spacing: 6,
                runSpacing: 4,
                children: persona.strengths
                    .map(
                      (s) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFCE7F0),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(
                          s,
                          style: pw.TextStyle(
                              fontSize: 10.5,
                              color: PdfColor.fromInt(0xFFB1295F)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            // 興趣
            if (p.interests.isNotEmpty) ...[
              sectionHeading('興趣'),
              pw.Wrap(
                spacing: 6,
                runSpacing: 4,
                children: p.interests
                    .map(
                      (s) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                              color: PdfColors.grey400, width: 0.6),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(s, style: pw.TextStyle(fontSize: 10.5)),
                      ),
                    )
                    .toList(),
              ),
            ],

            // 目前方向／困擾
            if (p.concerns.isNotEmpty) ...[
              sectionHeading('目前方向 / 困擾'),
              pw.Text(
                p.concerns,
                style: pw.TextStyle(fontSize: 11.5, lineSpacing: 3),
              ),
            ],
          ],
        ),
      ),
    );

    return doc.save();
  }
}
