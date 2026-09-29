import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app/theme.dart';

/// Shimmering placeholder area. Wrap a layout of [SkeletonBox]es in one
/// [Skeleton] so they shimmer together.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bone.withValues(alpha: 0.55),
      highlightColor: Colors.white.withValues(alpha: 0.9),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
