import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Draggable before/after split view. Each side is independently tappable
/// (for the caller to open an enlarge/pinch-zoom viewer) via [onTapBefore]
/// and [onTapAfter]; dragging the handle only reveals more of one side.
class BeforeAfterCompare extends StatefulWidget {
  const BeforeAfterCompare({
    super.key,
    required this.before,
    required this.after,
    this.beforeLabel = 'Original',
    this.afterLabel = 'Edited',
    this.onTapBefore,
    this.onTapAfter,
    this.height = 220,
  });

  final Widget before;
  final Widget after;
  final String beforeLabel;
  final String afterLabel;
  final VoidCallback? onTapBefore;
  final VoidCallback? onTapAfter;
  final double height;

  @override
  State<BeforeAfterCompare> createState() => _BeforeAfterCompareState();
}

class _BeforeAfterCompareState extends State<BeforeAfterCompare> {
  double _split = 0.5;

  void _updateFromLocalX(double localX, double width) {
    if (width <= 0) return;
    setState(() => _split = (localX / width).clamp(0.02, 0.98));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: AppTheme.bone,
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) =>
                  _updateFromLocalX(details.localPosition.dx, width),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: widget.onTapBefore,
                    child: Semantics(
                      button: true,
                      label: 'Enlarge ${widget.beforeLabel}',
                      child: widget.before,
                    ),
                  ),
                  ClipRect(
                    clipper: _RightClip(_split),
                    child: GestureDetector(
                      onTap: widget.onTapAfter,
                      child: Semantics(
                        button: true,
                        label: 'Enlarge ${widget.afterLabel}',
                        child: widget.after,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * _split - 1).clamp(0, width - 2),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),
                  Positioned(
                    left: (width * _split - 16).clamp(0, width - 32),
                    top: (widget.height - 32) / 2,
                    child: Container(
                      key: const Key('compare-handle'),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.terracotta),
                      ),
                      child: const Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: AppTheme.terracotta,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _label(widget.beforeLabel),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _label(widget.afterLabel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.indigo.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _RightClip extends CustomClipper<Rect> {
  _RightClip(this.split);
  final double split;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    size.width * split,
    0,
    size.width * (1 - split),
    size.height,
  );
  @override
  bool shouldReclip(covariant _RightClip oldClipper) =>
      oldClipper.split != split;
}
