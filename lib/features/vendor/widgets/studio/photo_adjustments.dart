import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// Colour matrix used to preview and render brightness/warmth adjustments.
///
/// Kept as a pure function (no AI involved) so both the live preview
/// (`ColorFiltered`) and the exported bitmap use identical maths.
List<double> studioColorMatrix({double brightness = 0, double warmth = 0}) {
  final offset = brightness * 170;
  final warmthOffset = warmth * 120;
  return [
    1, 0, 0, 0, offset + warmthOffset, //
    0, 1, 0, 0, offset, //
    0, 0, 1, 0, offset - warmthOffset, //
    0, 0, 0, 1, 0,
  ];
}

/// On-device photo adjustment: rotation (straighten / 90° turns) plus
/// brightness & warmth. Never touches the original file — callers should
/// write the returned bytes to a new file. No network or AI calls.
Future<Uint8List> renderStudioPhoto(
  Uint8List source, {
  double rotationDegrees = 0,
  double brightness = 0,
  double warmth = 0,
}) async {
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final radians = rotationDegrees * math.pi / 180;
  final sinA = math.sin(radians).abs();
  final cosA = math.cos(radians).abs();
  final srcWidth = image.width.toDouble();
  final srcHeight = image.height.toDouble();
  final outWidth = (srcWidth * cosA + srcHeight * sinA).ceil();
  final outHeight = (srcWidth * sinA + srcHeight * cosA).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
  );
  canvas.translate(outWidth / 2, outHeight / 2);
  canvas.rotate(radians);
  canvas.translate(-srcWidth / 2, -srcHeight / 2);
  final paint = ui.Paint()
    ..colorFilter = ui.ColorFilter.matrix(
      studioColorMatrix(brightness: brightness, warmth: warmth),
    );
  canvas.drawImage(image, ui.Offset.zero, paint);
  final rendered = await recorder.endRecording().toImage(outWidth, outHeight);
  image.dispose();
  codec.dispose();
  final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  rendered.dispose();
  if (bytes == null) {
    throw StateError('Could not render the adjusted photo.');
  }
  return bytes.buffer.asUint8List();
}

/// Live, cheap preview of the same adjustment (no re-encoding): wraps
/// [child] with a matching [ColorFilter] and rotation transform.
class StudioPhotoPreview extends StatelessWidget {
  const StudioPhotoPreview({
    super.key,
    required this.child,
    this.rotationDegrees = 0,
    this.brightness = 0,
    this.warmth = 0,
  });

  final Widget child;
  final double rotationDegrees;
  final double brightness;
  final double warmth;

  @override
  Widget build(BuildContext context) {
    Widget result = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        studioColorMatrix(brightness: brightness, warmth: warmth),
      ),
      child: child,
    );
    if (rotationDegrees != 0) {
      result = Transform.rotate(
        angle: rotationDegrees * math.pi / 180,
        child: result,
      );
    }
    return result;
  }
}
