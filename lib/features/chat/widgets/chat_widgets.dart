import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/ui/compact_count.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../../../widgets/skeleton.dart';
import '../../buyer/utils/help_support_contact.dart';

/// Asks before removing a conversation from the person's own inbox.
Future<bool> confirmDeleteConversation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this conversation?'),
      content: const Text(
        "It's removed from your messages. If they message you again, it will reappear.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ChatInboxList extends StatefulWidget {
  final List<ChatThread> threads;
  final bool showBuyerIdentity;
  final VoidCallback? onRefresh;
  final ValueChanged<ChatThread> onTap;
  final String emptyTitle;
  final String emptySubtitle;

  /// Show Artisan Lane (admin) conversations in their own section above
  /// customer conversations instead of mixing the two together.
  final bool groupAdminThreads;

  /// Hides a conversation for the current person only (swipe left or
  /// long-press). Null turns deleting off.
  final Future<void> Function(ChatThread thread)? onDelete;

  const ChatInboxList({
    super.key,
    required this.threads,
    required this.showBuyerIdentity,
    required this.onTap,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onRefresh,
    this.groupAdminThreads = false,
    this.onDelete,
  });

  @override
  State<ChatInboxList> createState() => _ChatInboxListState();
}

class _ChatInboxListState extends State<ChatInboxList> {
  /// Thread id -> the last activity time it was deleted at. Kept locally so
  /// the tile disappears immediately; a newer message changes the activity
  /// time, so the thread shows again even before the server list refreshes.
  final Map<String, DateTime> _deleted = {};

  /// Bumped when a failed delete puts a thread back, so it gets a fresh
  /// Dismissible instead of the one that was already swiped away.
  final Map<String, int> _restored = {};

  static DateTime _activityOf(ChatThread thread) =>
      thread.lastMessageAt ?? thread.createdAt;

  bool _isLocallyDeleted(ChatThread thread) =>
      _deleted[thread.id] == _activityOf(thread);

  Future<bool> _confirm(ChatThread thread) async {
    if (widget.onDelete == null) return false;
    return confirmDeleteConversation(context);
  }

  Future<void> _delete(ChatThread thread) async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    setState(() => _deleted[thread.id] = _activityOf(thread));
    try {
      await onDelete(thread);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleted.remove(thread.id);
        _restored.update(thread.id, (n) => n + 1, ifAbsent: () => 1);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't delete the conversation. Please try again.",
            ),
          ),
        );
    }
  }

  Future<void> _showOptions(ChatThread thread) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error,
          ),
          title: Text(
            'Delete conversation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppTheme.error,
            ),
          ),
          onTap: () => Navigator.of(context).pop('delete'),
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;
    if (await _confirm(thread)) await _delete(thread);
  }

  @override
  Widget build(BuildContext context) {
    final threads = widget.threads
        .where((thread) => !_isLocallyDeleted(thread))
        .toList();

    if (threads.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.terracotta,
        onRefresh: () async => widget.onRefresh?.call(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            _EmptyInbox(
              title: widget.emptyTitle,
              subtitle: widget.emptySubtitle,
            ),
          ],
        ),
      );
    }

    final adminThreads = widget.groupAdminThreads
        ? threads.where((thread) => thread.kind.isAdminVendor).toList()
        : const <ChatThread>[];
    final customerThreads = widget.groupAdminThreads
        ? threads.where((thread) => !thread.kind.isAdminVendor).toList()
        : threads;
    final showSections = adminThreads.isNotEmpty;
    final canDelete = widget.onDelete != null;

    Widget tileFor(ChatThread thread) {
      final tile = _InboxTile(
        thread: thread,
        showBuyerIdentity: widget.showBuyerIdentity,
        onTap: () => widget.onTap(thread),
        onLongPress: canDelete ? () => _showOptions(thread) : null,
      );
      if (!canDelete) return tile;
      return Dismissible(
        key: ValueKey('chat-thread-${thread.id}-${_restored[thread.id] ?? 0}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirm(thread),
        onDismissed: (_) => _delete(thread),
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
                'Delete',
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
        child: tile,
      );
    }

    return RefreshIndicator(
      color: AppTheme.terracotta,
      onRefresh: () async => widget.onRefresh?.call(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (showSections) ...[
            const _InboxSectionHeader(label: 'Artisan Lane'),
            const SizedBox(height: 12),
            for (final thread in adminThreads) ...[
              tileFor(thread),
              const SizedBox(height: 12),
            ],
            if (customerThreads.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _InboxSectionHeader(label: 'Customers'),
              const SizedBox(height: 12),
            ],
          ],
          for (var i = 0; i < customerThreads.length; i++) ...[
            tileFor(customerThreads[i]),
            if (i < customerThreads.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _InboxSectionHeader extends StatelessWidget {
  final String label;

  const _InboxSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: AppTheme.textHint,
      ),
    );
  }
}

class ChatThreadScaffold extends StatelessWidget {
  final AsyncValue<List<ChatMessage>> messagesAsync;
  final String currentUserId;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String avatarFallback;
  final Widget composer;
  final String? Function(String senderId)? senderLabelResolver;

  /// Optional app bar actions (for example a ⋯ menu).
  final List<Widget>? actions;

  /// Called when someone else's message is long-pressed (for example to
  /// report it). Null disables the long-press menu.
  final void Function(ChatMessage message)? onMessageLongPress;

  const ChatThreadScaffold({
    super.key,
    required this.messagesAsync,
    required this.currentUserId,
    required this.title,
    required this.avatarFallback,
    required this.composer,
    this.subtitle,
    this.avatarUrl,
    this.senderLabelResolver,
    this.actions,
    this.onMessageLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        actions: actions,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.bone,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      avatarFallback.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.playfairDisplay(
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _ChatSafetyNotice(canReport: onMessageLongPress != null),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyThreadState();
                }

                // Reverse-chronological list; a day separator is inserted
                // above the first message (in chronological order) of a
                // new calendar day.
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final arrayIndex = messages.length - 1 - index;
                    final message = messages[arrayIndex];
                    final isMine = message.isSentBy(currentUserId);
                    // messages is chronological ascending; the message just
                    // before this one in time (if any) is at arrayIndex - 1.
                    final isFirstOfDay =
                        arrayIndex == 0 ||
                        !_isSameDay(
                          messages[arrayIndex - 1].createdAt,
                          message.createdAt,
                        );
                    Widget messageBubble = _MessageBubble(
                      message: message,
                      isMine: isMine,
                      senderLabel: isMine
                          ? null
                          : senderLabelResolver?.call(message.senderId),
                    );
                    final onLongPress = onMessageLongPress;
                    if (!isMine && onLongPress != null) {
                      messageBubble = Semantics(
                        onLongPressHint: 'Message options',
                        child: GestureDetector(
                          key: ValueKey('chat-message-${message.id}'),
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => onLongPress(message),
                          child: messageBubble,
                        ),
                      );
                    }
                    final bubble = Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: messageBubble,
                    );
                    if (!isFirstOfDay) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: bubble,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          _DaySeparator(date: message.createdAt),
                          const SizedBox(height: 10),
                          bubble,
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const _ChatThreadSkeleton(),
              error: (error, _) =>
                  ErrorRetryView(error: error, title: "Couldn't load messages"),
            ),
          ),
          composer,
        ],
      ),
    );
  }
}

class PendingChatAttachmentCard extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback onRemove;

  const PendingChatAttachmentCard({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isImage
                ? Icons.image_outlined
                : attachment.isVideo
                ? Icons.videocam_outlined
                : Icons.attach_file_rounded,
            color: AppTheme.terracotta,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (attachment.sizeBytes != null)
                  Text(
                    _formatFileSize(attachment.sizeBytes!),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.textHint,
          ),
        ],
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final ChatThread thread;
  final bool showBuyerIdentity;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _InboxTile({
    required this.thread,
    required this.showBuyerIdentity,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isAdminThread = thread.kind.isAdminThread;
    final avatarUrl = isAdminThread
        ? null
        : (showBuyerIdentity ? thread.buyerAvatarUrl : thread.shopLogoUrl);
    final title = isAdminThread
        ? 'Artisan Lane Support'
        : (showBuyerIdentity
              ? (thread.buyerDisplayName ?? 'Buyer')
              : (thread.shopName ?? 'Artisan'));
    final subtitle = isAdminThread
        ? (showBuyerIdentity
              ? 'Message from the Artisan Lane team'
              : 'From the Artisan Lane team')
        : (showBuyerIdentity
              ? (thread.shopName ?? 'Shop conversation')
              : 'Shop conversation');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.bone,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        title.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatRelativeTime(
                            thread.lastMessageAt ?? thread.createdAt,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: thread.unreadCount > 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (thread.unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: const BoxDecoration(
                              color: AppTheme.terracotta,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              thread.unreadCount > 9
                                  ? '9+'
                                  : '${thread.unreadCount}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final String? senderLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppTheme.terracotta : Colors.white;
    final textColor = isMine ? Colors.white : AppTheme.textPrimary;
    final attachment = message.attachment;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine
              ? null
              : Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderLabel != null && senderLabel!.trim().isNotEmpty) ...[
              Text(
                senderLabel!,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppTheme.terracotta,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (attachment != null)
              _AttachmentBubble(
                attachment: attachment,
                textColor: textColor,
                isMine: isMine,
              ),
            if (attachment != null && message.hasText)
              const SizedBox(height: 10),
            if (message.hasText)
              Text(
                message.body!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.5,
                  color: textColor,
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('HH:mm').format(message.createdAt.toLocal()),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentBubble extends StatelessWidget {
  final ChatAttachment attachment;
  final Color textColor;
  final bool isMine;

  const _AttachmentBubble({
    required this.attachment,
    required this.textColor,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isMine
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.bone;
    return InkWell(
      onTap: attachment.url == null
          ? null
          : () => launchUrl(
              Uri.parse(attachment.url!),
              mode: LaunchMode.externalApplication,
            ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: attachment.isImage && attachment.url != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: attachment.url!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: Colors.black.withValues(alpha: 0.05),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: AppTheme.terracotta,
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 160,
                        color: Colors.black.withValues(alpha: 0.05),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    attachment.isVideo
                        ? Icons.videocam_outlined
                        : Icons.attach_file_rounded,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (attachment.sizeBytes != null)
                          Text(
                            _formatFileSize(attachment.sizeBytes!),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isMine
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppTheme.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyInbox({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.bone,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.terracotta,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSafetyNotice extends StatelessWidget {
  const _ChatSafetyNotice({required this.canReport});

  /// True when long-pressing a message opens the report menu.
  final bool canReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8C77B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF8A6100)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Safety tip: Artisan Lane will never ask you to verify payment '
              'details or click a link to receive funds. '
              '${canReport ? 'Long-press a message to report it, or email' : 'Report suspicious messages to'} '
              '$helpSupportEmail.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.4,
                color: const Color(0xFF8A6100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThreadState extends StatelessWidget {
  const _EmptyThreadState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Say hello and start the conversation.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;

  const _DaySeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    final local = date.toLocal();
    if (_isSameDay(local, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(local, yesterday)) return 'Yesterday';
    if (now.difference(local).inDays < 7) {
      return DateFormat('EEEE').format(local);
    }
    return DateFormat('d MMMM yyyy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.bone.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ChatThreadSkeleton extends StatelessWidget {
  const _ChatThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 180, height: 44, radius: 18),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonBox(width: 140, height: 36, radius: 18),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 210, height: 60, radius: 18),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
