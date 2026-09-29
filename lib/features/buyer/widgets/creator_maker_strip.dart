import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../models/shop_post.dart';

/// The demo's maker strip, backed by the actual makers in the loaded feed.
/// These open shops, not fictional expiring stories.
class CreatorMakerStrip extends StatelessWidget {
  const CreatorMakerStrip({super.key, required this.posts});
  final List<ShopPost> posts;

  @override
  Widget build(BuildContext context) {
    final makers = <String, ShopPost>{};
    for (final post in posts) {
      makers.putIfAbsent(post.shopId, () => post);
    }
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: makers.values.take(12).map((post) {
          final name = post.shopName?.trim().isNotEmpty == true
              ? post.shopName!
              : 'Maker';
          return SizedBox(
            width: 78,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/home/shop/${post.shopId}'),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.ochre,
                          AppTheme.terracotta,
                          AppTheme.baobab,
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppTheme.bone,
                      foregroundImage: post.shopLogoUrl?.isNotEmpty == true
                          ? CachedNetworkImageProvider(post.shopLogoUrl!)
                          : null,
                      child: Text(name.characters.first),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
