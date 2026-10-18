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

/// Splits a total rotation into whole quarter turns plus a small straighten
/// angle (the part that isn't a multiple of 90°).
({int quarterTurns, double straighten}) splitStudioRotation(double degrees) {
  final turns = (degrees / 90).round();
  return (quarterTurns: turns % 4, straighten: degrees - turns * 90);
}

/// How much a photo of [width]×[height] must be enlarged when rotated by
/// [degrees] so it still fills its original frame (no empty corners), the
/// way phone photo editors straighten.
double studioStraightenScale(double width, double height, double degrees) {
  if (degrees == 0 || width <= 0 || height <= 0) return 1;
  final radians = degrees.abs() * math.pi / 180;
  final c = math.cos(radians), s = math.sin(radians);
  return math.max((width * c + height * s) / width, (width * s + height * c) / height);
}

/// On-device photo adjustment: 90° turns, straighten (cropped to fill the
/// frame), brightness and warmth. Never touches the source bytes — callers
/// write the result to a new file. The longest side is capped at
/// [maxDimension] to keep uploads reasonable. No network or AI calls.
Future<Uint8List> renderStudioPhoto(
  Uint8List source, {
  double rotationDegrees = 0,
  double brightness = 0,
  double warmth = 0,
  int maxDimension = 2048,
}) async {
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rotation = splitStudioRotation(rotationDegrees);
  final srcWidth = image.width.toDouble();
  final srcHeight = image.height.toDouble();
  final swapped = rotation.quarterTurns.isOdd;
  final frameWidth = swapped ? srcHeight : srcWidth;
  final frameHeight = swapped ? srcWidth : srcHeight;
  final longest = math.max(frameWidth, frameHeight);
  final fit = longest > maxDimension ? maxDimension / longest : 1.0;
  final outWidth = math.max(1, (frameWidth * fit).round());
  final outHeight = math.max(1, (frameHeight * fit).round());
  final cover = studioStraightenScale(
    frameWidth,
    frameHeight,
    rotation.straighten,
  );

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
  );
  canvas.translate(outWidth / 2, outHeight / 2);
  canvas.scale(fit * cover);
  canvas.rotate(rotationDegrees * math.pi / 180);
  canvas.translate(-srcWidth / 2, -srcHeight / 2);
  final paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.high
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

/// Live, cheap preview of exactly what [renderStudioPhoto] exports: the
/// photo turned, straightened (enlarged to fill its frame) and colour
/// adjusted. [aspectRatio] is the source photo's width / height.
class StudioPhotoPreview extends StatelessWidget {
  const StudioPhotoPreview({
    super.key,
    required this.child,
    this.aspectRatio = 1,
    this.rotationDegrees = 0,
    this.brightness = 0,
    this.warmth = 0,
  });

  final Widget child;
  final double aspectRatio;
  final double rotationDegrees;
  final double brightness;
  final double warmth;

  @override
  Widget build(BuildContext context) {
    final rotation = splitStudioRotation(rotationDegrees);
    final swapped = rotation.quarterTurns.isOdd;
    final frameAspect = swapped ? 1 / aspectRatio : aspectRatio;
    final cover = studioStraightenScale(frameAspect, 1, rotation.straighten);
    Widget result = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        studioColorMatrix(brightness: brightness, warmth: warmth),
      ),
      child: child,
    );
    result = RotatedBox(quarterTurns: rotation.quarterTurns, child: result);
    if (rotation.straighten != 0) {
      result = Transform.scale(
        scale: cover,
        child: Transform.rotate(
          angle: rotation.straighten * math.pi / 180,
          child: result,
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: frameAspect,
        child: ClipRect(child: result),
      ),
    );
  }
}
