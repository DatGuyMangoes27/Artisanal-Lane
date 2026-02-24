import 'package:flutter/material.dart';
import '../app/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Mudcloth / Bogolan-inspired geometric pattern painter.
///
/// Draws repeating crosses, dots, and dashes reminiscent of
/// West/South African textile traditions. Used as decorative
/// overlays on banners, headers, and section backgrounds.
/// ═══════════════════════════════════════════════════════════════

class MudclothPatternPainter extends CustomPainter {
  final Color color;
  final double cellSize;

  MudclothPatternPainter({
    this.color = Colors.white,
    this.cellSize = 28,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * cellSize + cellSize / 2;
        final cy = row * cellSize + cellSize / 2;
        final pattern = (row + col) % 3;

        if (pattern == 0) {
          // Small cross
          final armLen = cellSize * 0.22;
          canvas.drawLine(
            Offset(cx - armLen, cy), Offset(cx + armLen, cy), paint);
          canvas.drawLine(
            Offset(cx, cy - armLen), Offset(cx, cy + armLen), paint);
        } else if (pattern == 1) {
          // Dot
          canvas.drawCircle(Offset(cx, cy), cellSize * 0.07, dotPaint);
        } else {
          // Diamond
          final d = cellSize * 0.18;
          final path = Path()
            ..moveTo(cx, cy - d)
            ..lineTo(cx + d, cy)
            ..lineTo(cx, cy + d)
            ..lineTo(cx - d, cy)
            ..close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MudclothPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cellSize != cellSize;
}

/// A simpler row of chevron/zigzag marks — like a woven border.
class ZigzagBorderPainter extends CustomPainter {
  final Color color;
  final double amplitude;
  final double wavelength;

  ZigzagBorderPainter({
    this.color = const Color(0xFFD4A020),
    this.amplitude = 4,
    this.wavelength = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    path.moveTo(0, midY);

    for (double x = 0; x < size.width; x += wavelength) {
      path.lineTo(x + wavelength / 2, midY - amplitude);
      path.lineTo(x + wavelength, midY + amplitude);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ZigzagBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── Convenience Widgets ────────────────────────────────────────

/// Mudcloth pattern overlay – position inside a Stack.
class MudclothOverlay extends StatelessWidget {
  final Color color;
  final double cellSize;

  const MudclothOverlay({
    super.key,
    this.color = const Color(0x12FFFFFF),
    this.cellSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: MudclothPatternPainter(color: color, cellSize: cellSize),
      ),
    );
  }
}

/// Zigzag woven divider that can sit between sections.
class WovenDivider extends StatelessWidget {
  final Color? color;
  final double height;

  const WovenDivider({super.key, this.color, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: ZigzagBorderPainter(
            color: (color ?? AppTheme.ochre).withValues(alpha: 0.3),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Decorative three-dot cluster, used as a small accent.
class TripleDot extends StatelessWidget {
  final Color? color;
  final double size;

  const TripleDot({super.key, this.color, this.size = 4});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.ochre;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(c, size),
        SizedBox(width: size * 1.5),
        _dot(c, size * 0.7),
        SizedBox(width: size * 1.5),
        _dot(c, size),
      ],
    );
  }

  Widget _dot(Color c, double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
