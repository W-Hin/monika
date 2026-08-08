import 'package:flutter/material.dart';

/// MONIKA's brand mark: a shield (attendance/policy integrity — matches
/// the app's IoT geofence + anomaly-flagging theme) with an "M" monogram
/// cut out as negative space. Single-color vector, so it reads correctly
/// on any background (white on a primary-colored circle, primary on a
/// white circle) without needing separate light/dark asset variants.
class MonikaLogoMark extends StatelessWidget {
  final double size;
  final Color color;

  const MonikaLogoMark({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShieldMPainter(color)),
    );
  }
}

class _ShieldMPainter extends CustomPainter {
  final Color color;
  const _ShieldMPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    final shield = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.867, h * 0.237)
      ..lineTo(w * 0.867, h * 0.487)
      ..cubicTo(w * 0.867, h * 0.670, w * 0.700, h * 0.808, w * 0.5, h * 0.840)
      ..cubicTo(w * 0.3, h * 0.808, w * 0.133, h * 0.670, w * 0.133, h * 0.487)
      ..lineTo(w * 0.133, h * 0.237)
      ..close();
    canvas.drawPath(shield, Paint()..color = color);

    final m = Path()
      ..moveTo(w * 0.3, h * 0.633)
      ..lineTo(w * 0.3, h * 0.320)
      ..lineTo(w * 0.407, h * 0.320)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.593, h * 0.320)
      ..lineTo(w * 0.7, h * 0.320)
      ..lineTo(w * 0.7, h * 0.633)
      ..lineTo(w * 0.593, h * 0.633)
      ..lineTo(w * 0.593, h * 0.440)
      ..lineTo(w * 0.513, h * 0.593)
      ..lineTo(w * 0.487, h * 0.593)
      ..lineTo(w * 0.407, h * 0.440)
      ..lineTo(w * 0.407, h * 0.633)
      ..close();
    canvas.drawPath(m, Paint()..blendMode = BlendMode.clear);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldMPainter oldDelegate) => oldDelegate.color != color;
}
