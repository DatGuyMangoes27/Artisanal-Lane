import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../models/shop_post.dart';

/// Human-friendly label and icon for each post format.
String composerFormatLabel(PostFormat format) => switch (format) {
  PostFormat.photo => 'Photo',
  PostFormat.video => 'Short video',
  PostFormat.carousel => 'Carousel',
  PostFormat.tutorial => 'Tutorial',
  PostFormat.poll => 'Poll',
};

IconData composerFormatIcon(PostFormat format) => switch (format) {
  PostFormat.photo => Icons.photo_outlined,
  PostFormat.video => Icons.videocam_outlined,
  PostFormat.carousel => Icons.view_carousel_outlined,
  PostFormat.tutorial => Icons.menu_book_outlined,
  PostFormat.poll => Icons.poll_outlined,
};

/// Format-driven media count rule. Returns a friendly error, or null when
/// [mediaCount] satisfies the format's rule. Poll's media rule ("at least
/// one image") is validated together with its other fields by
/// `composerPollError`, so it always returns null here.
String? composerMediaCountError(PostFormat format, int mediaCount) {
  switch (format) {
    case PostFormat.photo:
      return mediaCount == 1 ? null : 'Add exactly one photo for a photo post.';
    case PostFormat.video:
      return mediaCount == 1 ? null : 'Add exactly one video for a video post.';
    case PostFormat.carousel:
      return (mediaCount >= 2 && mediaCount <= 10)
          ? null
          : 'Add 2–10 photos for a carousel.';
    case PostFormat.tutorial:
      return (mediaCount >= 2 && mediaCount <= 10)
          ? null
          : 'Add 2–10 photos for a tutorial.';
    case PostFormat.poll:
      return null;
  }
}

/// Format picker chips at the top of the composer. [availableFormats] should
/// omit [PostFormat.video] unless the video feature flag is on.
class ComposerFormatPicker extends StatelessWidget {
  const ComposerFormatPicker({
    super.key,
    required this.value,
    required this.availableFormats,
    required this.onChanged,
    this.enabled = true,
  });

  final PostFormat value;
  final List<PostFormat> availableFormats;
  final ValueChanged<PostFormat> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in availableFormats)
              _FormatChip(
                key: Key('composer-format-${format.name}'),
                format: format,
                selected: value == format,
                onTap: enabled ? () => onChanged(format) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    super.key,
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final PostFormat format;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.terracotta.withValues(alpha: 0.12)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.terracotta : AppTheme.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              composerFormatIcon(format),
              size: 18,
              color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              composerFormatLabel(format),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.terracotta : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
