import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../vendor/providers/vendor_providers.dart';

/// The Feed header's create entry point, shown as a labelled pill next to
/// For you / Following:
/// - makers with a shop see "New post", which opens the post composer
///   directly;
/// - everyone else signed in sees "Sell", which explains selling on
///   Artisan Lane and leads into the shop application.
/// Hidden for guests, and while we don't yet know whether the account has a
/// shop (so the label never flips from "Sell" to "New post" under a thumb).
class CreatorComposeButton extends ConsumerWidget {
  const CreatorComposeButton({super.key, required this.onFinished});
  final Future<void> Function() onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) {
      return const SizedBox.shrink();
    }
    final shopAsync = ref.watch(vendorShopProvider);
    if (shopAsync.isLoading && !shopAsync.hasValue) {
      return const SizedBox.shrink();
    }
    final hasShop = shopAsync.value != null;

    return _CreatePill(
      key: const Key('feed-create-button'),
      icon: hasShop ? Icons.add_rounded : Icons.storefront_outlined,
      label: hasShop ? 'New post' : 'Sell',
      tooltip: hasShop ? 'New post' : 'Sell on Artisan Lane',
      onTap: () async {
        HapticFeedback.lightImpact();
        if (hasShop) {
          await context.push('/create/post');
        } else {
          final apply = await showStartSellingSheet(context);
          if (!context.mounted || apply != true) return;
          await context.push('/vendor/apply');
        }
        if (context.mounted) await onFinished();
      },
    );
  }
}

class _CreatePill extends StatelessWidget {
  const _CreatePill({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: AppTheme.terracotta.withValues(alpha: .08),
        shape: const StadiumBorder(
          side: BorderSide(color: AppTheme.terracotta, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppTheme.terracotta),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.terracotta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Sell on Artisan Lane" sheet for signed-in buyers without a shop.
/// Resolves to true when they choose to apply.
Future<bool?> showStartSellingSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.terracotta, AppTheme.baobab],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sell on Artisan Lane',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make something by hand? Open your own shop and share the '
            'story behind your work with buyers across South Africa.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _SellPoint(
            icon: Icons.photo_library_outlined,
            text: 'List your pieces and post updates to this feed',
          ),
          const _SellPoint(
            icon: Icons.lock_outline_rounded,
            text: 'Get paid securely when buyers order',
          ),
          const _SellPoint(
            icon: Icons.fact_check_outlined,
            text: 'Quick application, reviewed by our team',
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('start-selling-apply'),
              onPressed: () => Navigator.pop(sheetContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Apply to open a shop',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text(
              'Not now',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SellPoint extends StatelessWidget {
  const _SellPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.bone,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppTheme.terracotta),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
