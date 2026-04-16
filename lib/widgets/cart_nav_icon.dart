import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/cart_item.dart';

int cartBadgeCount(List<CartItem> items) {
  return items.fold<int>(0, (sum, item) => sum + item.quantity);
}

class CartNavIcon extends StatelessWidget {
  final int count;
  final bool isActive;

  const CartNavIcon({super.key, required this.count, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final icon = isActive ? Icons.shopping_bag : Icons.shopping_bag_outlined;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: AppTheme.terracotta,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
