import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the branded, letterhead-style PDF export for HR Analytics report
/// tiles — visual structure mirrors the "MONIKA — Report Layout Mockups"
/// artifact (letterhead, headline stat, metrics row, tables, footer note)
/// so an exported PDF reads as unmistakably MONIKA, not a generic export.
///
/// Currently fed illustrative/dummy data per report (see
/// `AnalyticsController.pdfBytesFor`) rather than live query results — this
/// is deliberately scoped to "visualize the template first" per the request
/// that added it; wiring each section to real per-department/per-employee
/// breakdowns is a follow-up once the layout itself is approved.
class PdfReportBuilder {
  PdfReportBuilder._();

  static const _textPrimary = PdfColor.fromInt(0xFF15211B);
  static const _textSecondary = PdfColor.fromInt(0xFF5B6B63);
  static const _textMuted = PdfColor.fromInt(0xFF93A39B);
  static const _border = PdfColor.fromInt(0xFFE3E8E5);
  static const _surfaceMuted = PdfColor.fromInt(0xFFF1F4F2);

  static pw.Font? _regular;
  static pw.Font? _medium;
  static pw.Font? _bold;
  static pw.Font? _extraBold;
  static pw.MemoryImage? _logo;

  static Future<void> _ensureLoaded() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    _medium ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Medium.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    _extraBold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-ExtraBold.ttf'));
    if (_logo == null) {
      final bytes = await rootBundle.load('lib/img/monika_logo_mark.png');
      _logo = pw.MemoryImage(bytes.buffer.asUint8List());
    }
  }

  static Future<Uint8List> build({
    required String doctype,
    required String title,
    required String subtitle,
    required String headlineValue,
    required String headlineLabel,
    List<(String, String)> metrics = const [],
    required List<PdfReportSection> sections,
    required String generatedBy,
  }) async {
    await _ensureLoaded();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: _regular, bold: _bold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(width: 22, height: 22, child: pw.Image(_logo!)),
                pw.SizedBox(width: 8),
                pw.Text('MONIKA', style: pw.TextStyle(font: _extraBold, fontSize: 12, letterSpacing: 0.5)),
                pw.Spacer(),
                pw.Text(
                  doctype.toUpperCase(),
                  style: pw.TextStyle(font: _bold, fontSize: 9, color: _textMuted, letterSpacing: 0.5),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: _border, thickness: 1),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.SizedBox(height: 10),
            pw.Divider(color: _border, thickness: 1),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(generatedBy, style: pw.TextStyle(font: _regular, fontSize: 8.5, color: _textMuted)),
                pw.Text('MONIKA HR Management System', style: pw.TextStyle(font: _regular, fontSize: 8.5, color: _textMuted)),
              ],
            ),
          ],
        ),
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(font: _extraBold, fontSize: 16, color: _textPrimary)),
          pw.SizedBox(height: 3),
          pw.Text(subtitle, style: pw.TextStyle(font: _regular, fontSize: 10, color: _textSecondary)),
          pw.SizedBox(height: 18),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(headlineValue, style: pw.TextStyle(font: _extraBold, fontSize: 28, color: _textPrimary)),
              pw.SizedBox(width: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(headlineLabel, style: pw.TextStyle(font: _medium, fontSize: 10, color: _textSecondary)),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          if (metrics.isNotEmpty) ...[
            pw.Row(
              children: metrics
                  .map(
                    (m) => pw.Expanded(
                      child: pw.Container(
                        margin: const pw.EdgeInsets.only(right: 8),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: pw.BoxDecoration(color: _surfaceMuted, borderRadius: pw.BorderRadius.circular(6)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(m.$1.toUpperCase(), style: pw.TextStyle(font: _bold, fontSize: 7.5, color: _textMuted, letterSpacing: 0.4)),
                            pw.SizedBox(height: 3),
                            pw.Text(m.$2, style: pw.TextStyle(font: _bold, fontSize: 12.5, color: _textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 18),
          ],

          for (final section in sections) ...[
            pw.Text(
              section.label.toUpperCase(),
              style: pw.TextStyle(font: _bold, fontSize: 9.5, color: _textSecondary, letterSpacing: 0.4),
            ),
            pw.SizedBox(height: 8),
            section.build(PdfTableStyles(regular: _regular!, bold: _bold!, textMuted: _textMuted, textPrimary: _textPrimary)),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// A simple header/rows table, styled to match the mockup's `<table>`.
  /// A column index in both [numericColumns] and [centerColumns] is
  /// undefined behaviour — callers should pick one alignment per column.
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    List<int> numericColumns = const [],
    List<int> centerColumns = const [],
    required PdfTableStyles s,
  }) {
    final alignments = {
      for (final i in numericColumns) i: pw.Alignment.centerRight,
      for (final i in centerColumns) i: pw.Alignment.center,
    };
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(font: s.bold, fontSize: 8, color: s.textMuted, letterSpacing: 0.3),
      headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1))),
      cellStyle: pw.TextStyle(font: s.regular, fontSize: 9, color: s.textPrimary),
      cellHeight: 22,
      headerCellDecoration: const pw.BoxDecoration(),
      cellAlignments: alignments,
      headerAlignments: alignments,
      border: null,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5))),
    );
  }
}

class PdfTableStyles {
  final pw.Font regular, bold;
  final PdfColor textPrimary, textMuted;
  const PdfTableStyles({
    required this.regular,
    required this.bold,
    required this.textMuted,
    required this.textPrimary,
  });
}

/// One "SECTION LABEL" + content block within the report body.
class PdfReportSection {
  final String label;
  final pw.Widget Function(PdfTableStyles styles) build;
  const PdfReportSection({required this.label, required this.build});

  /// Convenience factory for the common case: a section that's just a table.
  factory PdfReportSection.table({
    required String label,
    required List<String> headers,
    required List<List<String>> rows,
    List<int> numericColumns = const [],
    List<int> centerColumns = const [],
  }) {
    return PdfReportSection(
      label: label,
      build: (s) => PdfReportBuilder.table(headers: headers, rows: rows, numericColumns: numericColumns, centerColumns: centerColumns, s: s),
    );
  }

  /// A repeating "department heading, then a table of its own employees"
  /// group — for reports where HR wants to see individuals within each
  /// department, not just a department-level aggregate row.
  factory PdfReportSection.groupedByDepartment({
    required String label,
    required List<String> headers,
    required List<PdfDeptGroup> groups,
    List<int> numericColumns = const [],
    List<int> centerColumns = const [],
  }) {
    return PdfReportSection(
      label: label,
      build: (s) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final g in groups) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: g.department, style: pw.TextStyle(font: s.bold, fontSize: 9.5, color: s.textPrimary)),
                    if (g.summary != null)
                      pw.TextSpan(text: '  —  ${g.summary}', style: pw.TextStyle(font: s.regular, fontSize: 8.5, color: s.textMuted)),
                  ],
                ),
              ),
            ),
            PdfReportBuilder.table(headers: headers, rows: g.employeeRows, numericColumns: numericColumns, centerColumns: centerColumns, s: s),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One department's employees within a [PdfReportSection.groupedByDepartment]
/// section — [employeeRows] use the same column order as that section's
/// [PdfReportSection.groupedByDepartment.headers], first column the name.
class PdfDeptGroup {
  final String department;
  final List<List<String>> employeeRows;
  final String? summary;
  const PdfDeptGroup({required this.department, required this.employeeRows, this.summary});
}
