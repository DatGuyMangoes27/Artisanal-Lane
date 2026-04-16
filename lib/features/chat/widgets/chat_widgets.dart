import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';

class ChatInboxList extends StatelessWidget {
  final List<ChatThread> threads;
  final bool showBuyerIdentity;
  final VoidCallback? onRefresh;
  final ValueChanged<ChatThread> onTap;
  final String emptyTitle;
  final String emptySubtitle;

  const ChatInboxList({
    super.key,
    required this.threads,
    required this.showBuyerIdentity,
    required this.onTap,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.terracotta,
        onRefresh: () async => onRefresh?.call(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            _EmptyInbox(title: emptyTitle, subtitle: emptySubtitle),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.terracotta,
      onRefresh: () async => onRefresh?.call(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _InboxTile(
          thread: threads[index],
          showBuyerIdentity: showBuyerIdentity,
          onTap: () => onTap(threads[index]),
        ),
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
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
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
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyThreadState();
                }

                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMine = message.isSentBy(currentUserId);
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _MessageBubble(
                        message: message,
                        isMine: isMine,
                        senderLabel: isMine
                            ? null
                            : senderLabelResolver?.call(message.senderId),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.terracotta),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load messages.\n$error',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                  ),
                ),
              ),
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

  const _InboxTile({
    required this.thread,
    required this.showBuyerIdentity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = showBuyerIdentity ? thread.buyerAvatarUrl : thread.shopLogoUrl;
    final title = showBuyerIdentity
        ? (thread.buyerDisplayName ?? 'Buyer')
        : (thread.shopName ?? 'Artisan');
    final subtitle = showBuyerIdentity
        ? (thread.shopName ?? 'Shop conversation')
        : 'Shop conversation';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
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
                          _formatInboxTimestamp(thread.lastMessageAt ?? thread.createdAt),
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
          borderRadius: BorderRadius.circular(18),
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
            if (attachment != null && message.hasText) const SizedBox(height: 10),
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

String _formatInboxTimestamp(DateTime value) {
  final now = DateTime.now();
  if (now.year == value.year &&
      now.month == value.month &&
      now.day == value.day) {
    return DateFormat('HH:mm').format(value.toLocal());
  }
  if (now.difference(value).inDays < 7) {
    return DateFormat('EEE').format(value.toLocal());
  }
  return DateFormat('d MMM').format(value.toLocal());
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
