import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'gradient_fab.dart';

class UnreadMessagesFab extends StatelessWidget {
  final int count;
  final String route;

  const UnreadMessagesFab({
    super.key,
    required this.count,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return GradientFab(
      icon: Icons.forum_rounded,
      badgeCount: count,
      onTap: () => context.go(route),
    );
  }
}
