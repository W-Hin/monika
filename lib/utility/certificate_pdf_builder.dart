import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../model/models.dart';

/// A4 landscape certificate of completion, matching the in-app certificate
/// (CertificateView). Same fonts and logo as PdfReportBuilder.
class CertificatePdfBuilder {
  CertificatePdfBuilder._();

  static const _green = PdfColor.fromInt(0xFF1DB954);
  static const _greenDark = PdfColor.fromInt(0xFF169C46);
  static const _greenLight = PdfColor.fromInt(0xFFE6F9EE);
  static const _textPrimary = PdfColor.fromInt(0xFF15211B);
  static const _textSecondary = PdfColor.fromInt(0xFF5B6B63);
  static const _textMuted = PdfColor.fromInt(0xFF93A39B);

  static Future<Uint8List> build(TrainingCertificate cert) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final medium = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Medium.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final extraBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-ExtraBold.ttf'));
    final logo = pw.MemoryImage((await rootBundle.load('lib/img/monika_logo_mark.png')).buffer.asUint8List());

    final issued = DateFormat('d MMMM yyyy').format(cert.issuedAt);
    final details = [
      '${cert.categoryLabel} programme',
      if (cert.score != null) 'Score ${cert.score!.toStringAsFixed(0)}%',
      'Issued $issued',
    ].join('   ·   ');

    final doc = pw.Document(title: 'Certificate ${cert.certificateNo}', author: 'MONIKA');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _green, width: 3)),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _greenLight, width: 1.5)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(width: 28, height: 28, child: pw.Image(logo)),
                    pw.SizedBox(width: 10),
                    pw.Text('MONIKA', style: pw.TextStyle(font: extraBold, fontSize: 16, letterSpacing: 1)),
                  ],
                ),
                pw.Spacer(),
                pw.Text('CERTIFICATE OF COMPLETION',
                    style: pw.TextStyle(font: extraBold, fontSize: 26, color: _greenDark, letterSpacing: 2)),
                pw.SizedBox(height: 22),
                pw.Text('This certifies that', style: pw.TextStyle(font: medium, fontSize: 13, color: _textSecondary)),
                pw.SizedBox(height: 10),
                pw.Text(cert.employeeName, style: pw.TextStyle(font: extraBold, fontSize: 32, color: _textPrimary)),
                pw.Container(width: 320, height: 1.2, color: _green, margin: const pw.EdgeInsets.only(top: 8, bottom: 16)),
                pw.Text('has successfully completed the training programme',
                    style: pw.TextStyle(font: medium, fontSize: 13, color: _textSecondary)),
                pw.SizedBox(height: 10),
                pw.Text(cert.programTitle,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 22, color: _textPrimary)),
                pw.SizedBox(height: 14),
                pw.Text(details, style: pw.TextStyle(font: medium, fontSize: 11.5, color: _textSecondary)),
                pw.Spacer(),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certificate No.', style: pw.TextStyle(font: medium, fontSize: 9, color: _textMuted)),
                        pw.SizedBox(height: 2),
                        pw.Text(cert.certificateNo, style: pw.TextStyle(font: bold, fontSize: 12, color: _textPrimary)),
                      ],
                    ),
                    pw.Spacer(),
                    pw.Text('Issued automatically by MONIKA on completion of the programme.',
                        style: pw.TextStyle(font: regular, fontSize: 9, color: _textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return doc.save();
  }
}
