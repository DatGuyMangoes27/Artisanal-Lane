import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/ui/compact_count.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../../../services/push_notifications_service.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  final String? emptyMessage;

  const NotificationsScreen({super.key, this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: notifications.when(
          data: (items) => items.isEmpty
              ? _EmptyNotifications(message: emptyMessage)
              : _NotificationsList(items: items),
          loading: () => const _NotificationsSkeleton(),
          error: (error, _) => ErrorRetryView(
            error: error,
            title: "Couldn't load notifications",
            onRetry: () => ref.invalidate(notificationsStreamProvider),
          ),
        ),
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  final List<AppNotification> items;

  const _NotificationsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = _groupByRecency(items);

    Widget tileFor(AppNotification notification) => _NotificationTile(
      notification: notification,
      onTap: () async {
        // Marking read is best effort: a failed write must not stop the
        // notification from opening what it points to.
        try {
          await ref
              .read(supabaseServiceProvider)
              .markNotificationRead(notification.id);
        } catch (_) {}
        final route = routeForPushNotification(notification.data);
        if (route != null && context.mounted) {
          context.push(route);
        }
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 8),
            child: Text(
              group.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppTheme.textHint,
              ),
            ),
          ),
          for (var i = 0; i < group.items.length; i++) ...[
            tileFor(group.items[i]),
            if (i < group.items.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _NotificationGroup {
  final String label;
  final List<AppNotification> items;
  const _NotificationGroup(this.label, this.items);
}

List<_NotificationGroup> _groupByRecency(List<AppNotification> items) {
  final now = DateTime.now();
  final today = <AppNotification>[];
  final thisWeek = <AppNotification>[];
  final earlier = <AppNotification>[];

  for (final item in items) {
    final local = item.createdAt.toLocal();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      today.add(item);
    } else if (now.difference(local).inDays < 7) {
      thisWeek.add(item);
    } else {
      earlier.add(item);
    }
  }

  return [
    if (today.isNotEmpty) _NotificationGroup('TODAY', today),
    if (thisWeek.isNotEmpty) _NotificationGroup('THIS WEEK', thisWeek),
    if (earlier.isNotEmpty) _NotificationGroup('EARLIER', earlier),
  ];
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.notificationType) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'order_update':
        return Icons.local_shipping_outlined;
      case 'dispute_update':
        return Icons.gavel_rounded;
      case 'admin_broadcast':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isUnread
          ? AppTheme.terracotta.withValues(alpha: 0.04)
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isUnread
                  ? AppTheme.terracotta.withValues(alpha: 0.2)
                  : AppTheme.sand.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: notification.isUnread
                      ? AppTheme.terracotta.withValues(alpha: 0.12)
                      : AppTheme.bone.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  color: notification.isUnread
                      ? AppTheme.terracotta
                      : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: notification.isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatRelativeTime(notification.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.isUnread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6, left: 10),
                  decoration: const BoxDecoration(
                    color: AppTheme.terracotta,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, __) => Skeleton(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 42, height: 42, circle: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 140, height: 14),
                    const SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final String? message;

  const _EmptyNotifications({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.bone.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppTheme.textHint,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Notifications Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message ??
                  "When makers you follow post new items or your orders are updated, you'll see notifications here.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
