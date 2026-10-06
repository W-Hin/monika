import 'package:flutter/widgets.dart';

/// Where the share sheet should point from. On iPad the share sheet is a
/// popover and must have an anchor, or sharing throws; phones ignore it.
Rect shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
}
