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

enum NotificationsFilter { all, unread }

class NotificationsScreen extends ConsumerStatefulWidget {
  final String? emptyMessage;

  const NotificationsScreen({super.key, this.emptyMessage});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationsFilter _filter = NotificationsFilter.all;

  // Optimistic local state so the list reacts instantly; the stream is
  // refreshed after each write so every unread badge catches up too.
  final Set<String> _dismissedIds = {};
  final Set<String> _readIds = {};

  // Bumped when a failed clear puts a notification back, so it gets a fresh
  // Dismissible instead of the one that was already swiped away.
  int _restoreGeneration = 0;

  List<AppNotification> _visible(List<AppNotification> items) {
    final now = DateTime.now();
    return [
      for (final item in items)
        if (!item.isDismissed && !_dismissedIds.contains(item.id))
          _readIds.contains(item.id) && item.isUnread
              ? item.copyWith(readAt: now)
              : item,
    ];
  }

  void _refreshStream() => ref.invalidate(notificationsStreamProvider);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(AppNotification notification) async {
    // Marking read is best effort: a failed write must not stop the
    // notification from opening what it points to.
    if (notification.isUnread) {
      setState(() => _readIds.add(notification.id));
      try {
        await ref
            .read(supabaseServiceProvider)
            .markNotificationRead(notification.id);
        _refreshStream();
      } catch (_) {}
    }
    final route = routeForPushNotification(notification.data);
    if (route != null && mounted) {
      context.push(route);
    }
  }

  Future<void> _markAllRead(List<AppNotification> visible) async {
    final userId = ref.read(currentUserIdProvider);
    final unreadIds = [
      for (final item in visible)
        if (item.isUnread) item.id,
    ];
    if (userId == null || unreadIds.isEmpty) return;
    setState(() => _readIds.addAll(unreadIds));
    try {
      await ref.read(supabaseServiceProvider).markAllNotificationsRead(userId);
      _refreshStream();
    } catch (_) {
      if (mounted) setState(() => _readIds.removeAll(unreadIds));
      _showError("Couldn't mark your notifications as read. Please try again.");
    }
  }

  Future<void> _clearAll(List<AppNotification> visible) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || visible.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'They will be removed from your notifications. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = [for (final item in visible) item.id];
    setState(() => _dismissedIds.addAll(ids));
    try {
      await ref.read(supabaseServiceProvider).dismissAllNotifications(userId);
      _refreshStream();
    } catch (_) {
      if (mounted) setState(() => _dismissedIds.removeAll(ids));
      _showError("Couldn't clear your notifications. Please try again.");
    }
  }

  Future<void> _dismissOne(AppNotification notification) async {
    setState(() => _dismissedIds.add(notification.id));
    try {
      await ref
          .read(supabaseServiceProvider)
          .dismissNotification(notification.id);
      _refreshStream();
    } catch (_) {
      if (mounted) {
        setState(() {
          _dismissedIds.remove(notification.id);
          _restoreGeneration++;
        });
      }
      _showError("Couldn't clear that notification. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsStreamProvider);
    final visible = _visible(notifications.value ?? const []);
    final unreadCount = visible.where((item) => item.isUnread).length;

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
        actions: [
          if (visible.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.textPrimary,
              ),
              onPressed: () => _clearAll(visible),
            ),
        ],
      ),
      body: SafeArea(
        child: notifications.when(
          data: (_) {
            if (visible.isEmpty) {
              return _EmptyNotifications(message: widget.emptyMessage);
            }
            final shown = _filter == NotificationsFilter.unread
                ? visible.where((item) => item.isUnread).toList()
                : visible;
            return Column(
              children: [
                _NotificationsToolbar(
                  filter: _filter,
                  unreadCount: unreadCount,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onMarkAllRead: unreadCount == 0
                      ? null
                      : () => _markAllRead(visible),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const _AllCaughtUp()
                      : _NotificationsList(
                          items: shown,
                          onOpen: _open,
                          onDismiss: _dismissOne,
                          keySuffix: _restoreGeneration,
                        ),
                ),
              ],
            );
          },
          loading: () => const _NotificationsSkeleton(),
          error: (error, _) => ErrorRetryView(
            error: error,
            title: "Couldn't load notifications",
            onRetry: _refreshStream,
          ),
        ),
      ),
    );
  }
}

class _NotificationsToolbar extends StatelessWidget {
  final NotificationsFilter filter;
  final int unreadCount;
  final ValueChanged<NotificationsFilter> onFilterChanged;
  final VoidCallback? onMarkAllRead;

  const _NotificationsToolbar({
    required this.filter,
    required this.unreadCount,
    required this.onFilterChanged,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          _FilterPill(
            key: const ValueKey('notifications-filter-all'),
            label: 'All',
            selected: filter == NotificationsFilter.all,
            onTap: () => onFilterChanged(NotificationsFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            key: const ValueKey('notifications-filter-unread'),
            label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
            selected: filter == NotificationsFilter.unread,
            onTap: () => onFilterChanged(NotificationsFilter.unread),
          ),
          const Spacer(),
          Flexible(
            child: TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                textStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text(
                'Mark all as read',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.terracotta : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? AppTheme.terracotta
                : AppTheme.sand.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<AppNotification> items;
  final ValueChanged<AppNotification> onOpen;
  final ValueChanged<AppNotification> onDismiss;
  final int keySuffix;

  const _NotificationsList({
    required this.items,
    required this.onOpen,
    required this.onDismiss,
    this.keySuffix = 0,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _groupByRecency(items);

    Widget tileFor(AppNotification notification) => Dismissible(
      key: ValueKey('notification-${notification.id}-$keySuffix'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(notification),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Clear',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      child: _NotificationTile(
        notification: notification,
        onTap: () => onOpen(notification),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          "You're all caught up. No unread notifications.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
      ),
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
