import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/shop_story.dart';
import '../../../widgets/skeleton.dart';
import '../../auth/providers/auth_providers.dart';
import '../../vendor/providers/vendor_providers.dart';
import '../../vendor/screens/story_composer_screen.dart';
import '../providers/story_providers.dart';
import '../screens/story_viewer_screen.dart';

class CreatorStoryRail extends ConsumerStatefulWidget {
  const CreatorStoryRail({super.key});
  @override
  ConsumerState<CreatorStoryRail> createState() => _CreatorStoryRailState();
}

class _CreatorStoryRailState extends ConsumerState<CreatorStoryRail>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) ref.invalidate(storiesProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(storiesProvider);
      ref.invalidate(seenStoriesProvider);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storiesProvider);
    final seen = {
      ...ref.watch(seenStoriesProvider).value ?? <String>{},
      ...ref.watch(locallySeenStoriesProvider),
    };
    final user = ref.watch(currentUserIdProvider);
    final shop = user == null ? null : ref.watch(vendorShopProvider).value;
    return data.when(
      loading: () => SizedBox(
        height: 112,
        child: Skeleton(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemCount: 5,
            itemBuilder: (_, _) => const SizedBox(
              width: 72,
              child: Column(
                children: [
                  SkeletonBox(width: 68, height: 68, circle: true),
                  SizedBox(height: 7),
                  SkeletonBox(width: 48, height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                friendlyErrorMessage(
                  error,
                  fallback: 'Stories are unavailable right now.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(storiesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (stories) {
        final groups = groupLiveStories(stories, seen, DateTime.now());
        if (groups.isEmpty && shop == null) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemCount: groups.length + (shop == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (shop != null && index == 0) {
                return _Bubble(
                  label: 'Your story',
                  add: true,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoryComposerScreen(shop: shop),
                      ),
                    );
                  },
                );
              }
              final groupIndex = index - (shop == null ? 0 : 1);
              final group = groups[groupIndex];
              return _Bubble(
                label: group.first.shopName,
                url: group.first.logoUrl,
                unseen: group.any((s) => !seen.contains(s.id)),
                onTap: () {
                  final first = group.indexWhere((s) => !seen.contains(s.id));
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(
                        groups: groups,
                        initialGroupIndex: groupIndex,
                        initialStoryIndex: first < 0 ? 0 : first,
                        ownShopId: shop?.id,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.onTap,
    this.url,
    this.unseen = false,
    this.add = false,
  });
  final String label;
  final String? url;
  final bool unseen, add;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: add
        ? 'Add your 24-hour story'
        : '$label story${unseen ? ', unseen' : ''}',
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: unseen ? AppTheme.terracotta : AppTheme.sand,
                  width: unseen ? 2.5 : 1,
                ),
              ),
              child: ClipOval(
                child: url != null
                    ? CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _fallback() => ColoredBox(
    color: AppTheme.cardBg,
    child: Center(
      child: add
          ? const Icon(Icons.add, color: AppTheme.terracotta)
          : Text(
              label.isEmpty ? '' : label.characters.first,
              style: const TextStyle(fontSize: 24, color: AppTheme.terracotta),
            ),
    ),
  );
}
