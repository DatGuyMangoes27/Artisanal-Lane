import 'package:flutter/widgets.dart';

/// Where the share sheet is anchored. iPads, and iPhones on recent iOS,
/// refuse to open the share sheet without a non-empty rectangle inside the
/// app's view ("Could not open the share sheet right now"). Uses the widget
/// that was tapped, or the whole screen when that isn't laid out.
Rect shareOriginFor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromLTWH(0, 0, size.width, size.height / 2);
}
