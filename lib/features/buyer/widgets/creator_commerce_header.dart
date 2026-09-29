import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../providers/buyer_providers.dart';
import '../providers/feed_notifications_badge.dart';

/// Shared creator-commerce chrome for Feed and Shop.
/// Cart remains the existing route; this replaces its fifth primary-nav slot.
class CreatorCommerceHeader extends ConsumerWidget {
  const CreatorCommerceHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cartCount,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final int cartCount;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final unreadMessages = signedIn
        ? ref.watch(buyerUnreadThreadsCountProvider)
        : 0;
    final unreadNotifications = signedIn
        ? ref.watch(feedUnreadNotificationsCountProvider)
        : 0;
    final actions = <Widget>[
      if (signedIn) ...[
        _HeaderAction(
          tooltip: 'Notifications',
          semanticsLabel: unreadNotifications == 0
              ? 'Notifications'
              : 'Notifications, $unreadNotifications unread',
          onPressed: () => context.push('/profile/notifications'),
          icon: Badge.count(
            isLabelVisible: unreadNotifications > 0,
            count: unreadNotifications,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        _HeaderAction(
          tooltip: 'Messages',
          semanticsLabel: unreadMessages == 0
              ? 'Messages'
              : 'Messages, $unreadMessages unread',
          onPressed: () => context.push('/profile/messages'),
          icon: Badge.count(
            isLabelVisible: unreadMessages > 0,
            count: unreadMessages,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ),
      ],
      _HeaderAction(
        tooltip: 'Cart',
        semanticsLabel: cartCount == 0 ? 'Cart' : 'Cart, $cartCount items',
        onPressed: () => context.push('/cart'),
        icon: Badge.count(
          isLabelVisible: cartCount > 0,
          count: cartCount,
          child: const Icon(Icons.shopping_bag_outlined),
        ),
      ),
    ];
    final eyebrowText = Text(
      eyebrow.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: AppTheme.terracotta,
      ),
    );
    final titleText = Text(
      title,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.playfairDisplay(
        fontSize: compact ? 25 : 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );

    if (compact) {
      // Fits a fixed-height app bar: title beside the actions.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [eyebrowText, titleText],
              ),
            ),
            ...actions,
          ],
        ),
      );
    }

    // Brand on the left, actions on the right, like Instagram; the title
    // below gets the full width.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: eyebrowText),
              ...actions,
            ],
          ),
          titleText,
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.semanticsLabel,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final String semanticsLabel;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        tooltip: tooltip,
        color: AppTheme.terracotta,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
