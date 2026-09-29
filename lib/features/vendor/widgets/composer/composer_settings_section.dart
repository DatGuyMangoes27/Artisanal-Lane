import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';

/// "Allow comments" / "Hide like count" switches, grouped in one rounded
/// card per the design language's list grouping rule.
class ComposerSettingsSection extends StatelessWidget {
  const ComposerSettingsSection({
    super.key,
    required this.commentsEnabled,
    required this.hideLikeCount,
    required this.onCommentsChanged,
    required this.onHideLikeCountChanged,
    this.enabled = true,
  });

  final bool commentsEnabled;
  final bool hideLikeCount;
  final ValueChanged<bool> onCommentsChanged;
  final ValueChanged<bool> onHideLikeCountChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conversation',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                key: const Key('composer-allow-comments'),
                value: commentsEnabled,
                onChanged: enabled ? onCommentsChanged : null,
                activeThumbColor: AppTheme.terracotta,
                title: Text(
                  'Allow comments',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Followers can reply to this post',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile.adaptive(
                key: const Key('composer-hide-like-count'),
                value: hideLikeCount,
                onChanged: enabled ? onHideLikeCountChanged : null,
                activeThumbColor: AppTheme.terracotta,
                title: Text(
                  'Hide like count from others',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'You can still see how many people liked it',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
