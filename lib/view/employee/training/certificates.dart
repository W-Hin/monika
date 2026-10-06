import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../controller/certificate_controller.dart';
import '../../../model/models.dart';
import '../../../utility/certificate_pdf_builder.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';

/// Every certificate the signed-in employee has earned.
class MyCertificatesScreen extends StatefulWidget {
  const MyCertificatesScreen({super.key});

  @override
  State<MyCertificatesScreen> createState() => _MyCertificatesScreenState();
}

class _MyCertificatesScreenState extends State<MyCertificatesScreen> {
  @override
  void initState() {
    super.initState();
    certificateController.loadMine();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const SimpleAppBar(title: 'My Certificates'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: certificateController,
          builder: (context, _) {
            final certs = certificateController.mine;
            if (certificateController.loading && certs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (certs.isEmpty) {
              return EmptyState(
                icon: Icons.workspace_premium_outlined,
                title: certificateController.errorMessage != null ? 'Could not load certificates' : 'No certificates yet',
                subtitle: 'Complete a training programme to earn your first certificate.',
              );
            }
            return RefreshIndicator(
              onRefresh: certificateController.loadMine,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: certs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final cert = certs[i];
                  return AppCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CertificateScreen(certificate: cert)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: c.riskLowBg, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.workspace_premium_rounded, color: c.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cert.programTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(
                                '${cert.certificateNo} · ${DateFormat('d MMM yyyy').format(cert.issuedAt)}',
                                style: TextStyle(fontSize: 11.5, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (cert.score != null)
                          Text('${cert.score!.toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.primary)),
                        Icon(Icons.chevron_right_rounded, color: c.textMuted),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One certificate, as it looks on paper, with a PDF download.
class CertificateScreen extends StatefulWidget {
  final TrainingCertificate certificate;
  const CertificateScreen({super.key, required this.certificate});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  bool _exporting = false;

  Future<void> _download() async {
    setState(() => _exporting = true);
    try {
      final cert = widget.certificate;
      final bytes = await CertificatePdfBuilder.build(cert);
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'Certificate_${cert.certificateNo}.pdf', mimeType: 'application/pdf')],
        subject: 'Certificate ${cert.certificateNo} — ${cert.programTitle}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the PDF: $e')));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Certificate'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            CertificateView(certificate: widget.certificate),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Download PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _download, isLoading: _exporting),
          ],
        ),
      ),
    );
  }
}

/// The certificate itself, laid out like the PDF.
class CertificateView extends StatelessWidget {
  final TrainingCertificate certificate;
  const CertificateView({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cert = certificate;
    final details = [
      '${cert.categoryLabel} programme',
      if (cert.score != null) 'Score ${cert.score!.toStringAsFixed(0)}%',
      'Issued ${DateFormat('d MMM yyyy').format(cert.issuedAt)}',
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.primary, width: 2.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          border: Border.all(color: c.primary.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('lib/img/monika_logo_mark.png', width: 22, height: 22),
                const SizedBox(width: 8),
                const Text('MONIKA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 18),
            Text('CERTIFICATE OF COMPLETION',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.primaryDark, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Text('This certifies that', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 6),
            Text(cert.employeeName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Container(width: 160, height: 1.2, color: c.primary, margin: const EdgeInsets.symmetric(vertical: 10)),
            Text('has successfully completed', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 6),
            Text(cert.programTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(details, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
            const SizedBox(height: 18),
            Text('Certificate No. ${cert.certificateNo}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}
