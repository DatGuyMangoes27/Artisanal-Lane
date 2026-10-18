import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme.dart';

/// Preference key remembering that the Listing Studio tip was dismissed.
const listingStudioTipDismissedKey = 'listing_studio_tip_dismissed_v1';

/// First-run "how this works" tip for Listing Studio. Stays hidden until the
/// saved preference has been read (so it never flashes for returning
/// sellers) and is remembered once dismissed.
class StudioTipCard extends StatefulWidget {
  const StudioTipCard({super.key});

  @override
  State<StudioTipCard> createState() => _StudioTipCardState();
}

class _StudioTipCardState extends State<StudioTipCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(listingStudioTipDismissedKey) ?? false;
      if (mounted && !dismissed) setState(() => _visible = true);
    } catch (_) {
      // If preferences can't be read, skip the tip rather than nag.
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(listingStudioTipDismissedKey, true);
    } catch (_) {
      // Worst case the tip shows once more next time.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      key: const Key('studio-tip'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppTheme.bone.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: .5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 20,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Listing Studio works',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a tool above, then tap the button at the bottom to '
                  'add the result to your listing. Nothing goes live until '
                  'you save the product.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Got it',
            onPressed: _dismiss,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
