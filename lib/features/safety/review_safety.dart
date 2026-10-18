import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/constants/feature_flags.dart';
import '../../widgets/sign_in_prompt_sheet.dart';
import '../auth/providers/auth_providers.dart';
import '../buyer/providers/blocking_providers.dart';
import '../buyer/widgets/content_report_sheet.dart';
import 'content_filter.dart';

/// Drops reviews written by accounts the viewer has blocked.
List<T> withoutBlockedAuthors<T>(
  List<T> reviews,
  Set<String> blockedUserIds,
  String Function(T review) authorId,
) {
  if (blockedUserIds.isEmpty) return reviews;
  return reviews
      .where((review) => !blockedUserIds.contains(authorId(review)))
      .toList();
}

/// Review-composer loop shared by product and shop reviews: re-opens the
/// composer with the member's text when it contains blocked language, so
/// nothing they wrote is lost. Returns null when the composer is dismissed.
Future<D?> composeCleanReview<D>(
  BuildContext context, {
  required String initialText,
  required Future<D?> Function(String initialText) openComposer,
  required String Function(D draft) textOf,
}) async {
  var text = initialText;
  while (true) {
    final draft = await openComposer(text);
    if (draft == null) return null;
    if (!containsBlockedTerms(textOf(draft))) return draft;
    text = textOf(draft);
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          blockedTermsFriendlyMessage,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// "Report" and "Block" links shown under someone else's review.
/// Hidden when creator safety is off and on the viewer's own review.
class ReviewSafetyActions extends ConsumerWidget {
  const ReviewSafetyActions({
    super.key,
    required this.reviewId,
    required this.authorId,
    required this.authorName,
    required this.isProductReview,
  });

  final String reviewId;
  final String authorId;
  final String authorName;
  final bool isProductReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!creatorSafetyEnabled) return const SizedBox.shrink();
    final userId = ref.watch(currentUserIdProvider);
    if (userId != null && userId == authorId) return const SizedBox.shrink();
    final style = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondary,
    );
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: AppTheme.textSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 4,
        children: [
          TextButton.icon(
            key: ValueKey('report-review-$reviewId'),
            style: buttonStyle,
            onPressed: () async {
              if (ref.read(currentUserIdProvider) == null) {
                await showSignInPromptSheet(
                  context,
                  title: 'Sign in to report',
                  message: 'Reports are private and reviewed by our team.',
                );
                return;
              }
              if (!context.mounted) return;
              await showContentReportSheet(
                context,
                rawTargetType: isProductReview
                    ? ExtraReportTargets.productReview
                    : ExtraReportTargets.shopReview,
                targetId: reviewId,
              );
            },
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: Text('Report', style: style),
          ),
          TextButton.icon(
            key: ValueKey('block-reviewer-$reviewId'),
            style: buttonStyle,
            onPressed: () => confirmBlockUser(
              ref,
              context,
              userId: authorId,
              name: authorName,
            ),
            icon: const Icon(Icons.block_outlined, size: 16),
            label: Text('Block', style: style),
          ),
        ],
      ),
    );
  }
}
