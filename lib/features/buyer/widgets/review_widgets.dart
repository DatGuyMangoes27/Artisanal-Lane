import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';

class ReviewDraft {
  final int rating;
  final String reviewText;

  const ReviewDraft({required this.rating, required this.reviewText});
}

Future<ReviewDraft?> showReviewComposerSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  int initialRating = 5,
  String initialReviewText = '',
}) {
  return showModalBottomSheet<ReviewDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReviewComposerSheet(
      title: title,
      subtitle: subtitle,
      initialRating: initialRating,
      initialReviewText: initialReviewText,
    ),
  );
}

class ReviewSummaryCard extends StatelessWidget {
  final ReviewSummary summary;
  final String emptyLabel;

  const ReviewSummaryCard({
    super.key,
    required this.summary,
    this.emptyLabel = 'No reviews yet',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.bone,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              summary.hasReviews
                  ? summary.averageRating.toStringAsFixed(1)
                  : '0.0',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRatingDisplay(rating: summary.averageRating, starSize: 18),
                const SizedBox(height: 8),
                Text(
                  summary.hasReviews ? summary.countLabel : emptyLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuyerReviewCard extends StatelessWidget {
  final String? avatarUrl;
  final String authorName;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;

  const BuyerReviewCard({
    super.key,
    this.avatarUrl,
    required this.authorName,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.bone,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        authorName.substring(0, 1).toUpperCase(),
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
                      authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(createdAt.toLocal()),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              StarRatingDisplay(rating: rating.toDouble(), starSize: 16),
            ],
          ),
          if (reviewText != null && reviewText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reviewText!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double starSize;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.starSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index + 1;
        final icon = rounded >= threshold
            ? Icons.star_rounded
            : rounded > index && rounded < threshold
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(icon, size: starSize, color: AppTheme.ochre);
      }),
    );
  }
}

class EmptyReviewsCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const EmptyReviewsCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.reviews_outlined,
            size: 34,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
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

class _ReviewComposerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final int initialRating;
  final String initialReviewText;

  const _ReviewComposerSheet({
    required this.title,
    required this.subtitle,
    required this.initialRating,
    required this.initialReviewText,
  });

  @override
  State<_ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<_ReviewComposerSheet> {
  late final TextEditingController _controller;
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _controller = TextEditingController(text: widget.initialReviewText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your rating',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _rating = starValue),
                    icon: Icon(
                      starValue <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppTheme.ochre,
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                'Share a few details',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'What stood out about the item, service, or packaging?',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: AppTheme.terracotta),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      ReviewDraft(
                        rating: _rating,
                        reviewText: _controller.text.trim(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save Review',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
