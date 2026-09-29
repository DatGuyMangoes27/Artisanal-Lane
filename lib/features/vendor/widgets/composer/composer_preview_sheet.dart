import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../models/shop_post.dart';
import 'composer_schedule_section.dart';

/// A single preview media item: either a local file still being uploaded or
/// an already-hosted url.
class ComposerPreviewMedia {
  const ComposerPreviewMedia.file(this.file) : url = null;
  const ComposerPreviewMedia.url(this.url) : file = null;
  final File? file;
  final String? url;
}

class ComposerPreviewPoll {
  const ComposerPreviewPoll({required this.question, required this.options});
  final String question;
  final List<String> options;
}

/// Full-screen, read-only preview of how followers will see this post.
/// [CreatorFeedPostCard] can't be reused directly because it depends on
/// riverpod providers for live engagement data and network-only images;
/// this mirrors its layout with local state instead.
class ComposerPreviewSheet extends StatefulWidget {
  const ComposerPreviewSheet({
    super.key,
    required this.shopName,
    required this.shopLogoUrl,
    required this.media,
    required this.caption,
    required this.format,
    required this.stepCaptions,
    required this.commentsEnabled,
    required this.hideLikeCount,
    required this.scheduledFor,
    this.poll,
    required this.onEdit,
    required this.onShare,
  });

  final String shopName;
  final String? shopLogoUrl;
  final List<ComposerPreviewMedia> media;
  final String caption;
  final PostFormat format;
  final List<String> stepCaptions;
  final bool commentsEnabled;
  final bool hideLikeCount;
  final DateTime? scheduledFor;
  final ComposerPreviewPoll? poll;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  @override
  State<ComposerPreviewSheet> createState() => _ComposerPreviewSheetState();
}

class _ComposerPreviewSheetState extends State<ComposerPreviewSheet> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isScheduled = widget.scheduledFor != null;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        title: Text(
          'Preview',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          key: const Key('composer-preview-close'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            if (isScheduled)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppTheme.ochre,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scheduled for ${composerFormatScheduleLabel(widget.scheduledFor!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 7, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.clay),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: AppTheme.bone,
                          backgroundImage:
                              widget.shopLogoUrl?.trim().isNotEmpty == true
                              ? CachedNetworkImageProvider(widget.shopLogoUrl!)
                              : null,
                          child: widget.shopLogoUrl?.trim().isNotEmpty == true
                              ? null
                              : Text(
                                  widget.shopName.isEmpty
                                      ? '?'
                                      : widget.shopName[0].toUpperCase(),
                                  style: GoogleFonts.playfairDisplay(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.terracotta,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.shopName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.media.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 1.06,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _PreviewMedia(item: widget.media[_index]),
                          if (widget.media.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.media.length,
                                  (i) => GestureDetector(
                                    onTap: () => setState(() => _index = i),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: i == _index ? 16 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: i == _index ? 0.95 : 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.format == PostFormat.tutorial &&
                      _index < widget.stepCaptions.length &&
                      widget.stepCaptions[_index].trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Text(
                        widget.stepCaptions[_index],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          color: AppTheme.textPrimary,
                          size: 23,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.hideLikeCount ? 'Likes hidden' : '0 likes',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          widget.commentsEnabled
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.speaker_notes_off_outlined,
                          size: 22,
                          color: widget.commentsEnabled
                              ? AppTheme.textPrimary
                              : AppTheme.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.commentsEnabled
                              ? 'Comments on'
                              : 'Comments off',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  if (widget.caption.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${widget.shopName}  ',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                            ),
                            TextSpan(
                              text: widget.caption,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.poll != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _PreviewPoll(poll: widget.poll!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('composer-preview-edit'),
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('composer-preview-share'),
                    onPressed: widget.onShare,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                    ),
                    child: Text(isScheduled ? 'Schedule' : 'Share now'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMedia extends StatelessWidget {
  const _PreviewMedia({required this.item});
  final ComposerPreviewMedia item;

  @override
  Widget build(BuildContext context) {
    if (item.file != null) {
      return Image.file(item.file!, fit: BoxFit.cover);
    }
    final url = item.url;
    if (url == null || url.trim().isEmpty) {
      return Container(
        color: AppTheme.bone,
        alignment: Alignment.center,
        child: const Icon(Icons.photo_outlined, color: AppTheme.textHint),
      );
    }
    if (!url.startsWith('http')) {
      // A private video marker or other non-displayable reference.
      return Container(
        color: AppTheme.indigo,
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 48,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppTheme.bone),
      errorWidget: (_, __, ___) => Container(
        color: AppTheme.bone,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppTheme.textHint,
        ),
      ),
    );
  }
}

class _PreviewPoll extends StatelessWidget {
  const _PreviewPoll({required this.poll});
  final ComposerPreviewPoll poll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bone.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final option in poll.options)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.sand),
              ),
              child: Text(option, style: GoogleFonts.poppins(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
