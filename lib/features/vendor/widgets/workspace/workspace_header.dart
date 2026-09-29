import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';

/// Shared creator-studio page header for the vendor workspace: eyebrow +
/// Playfair title + optional subtitle, with room for trailing actions.
/// Mirrors `CreatorCommerceHeader` used on the buyer side so the seller
/// screens read as the same app.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppTheme.terracotta,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small square icon-button used in a [WorkspaceHeader]'s trailing actions.
class WorkspaceHeaderAction extends StatelessWidget {
  const WorkspaceHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: badgeCount > 0 ? '$tooltip, $badgeCount unread' : tooltip,
      button: true,
      child: IconButton(
        tooltip: tooltip,
        color: AppTheme.terracotta,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onTap,
        icon: Badge.count(
          isLabelVisible: badgeCount > 0,
          count: badgeCount,
          child: icon,
        ),
      ),
    );
  }
}

/// Section heading used within workspace screens: Playfair title with an
/// optional trailing "See all" text action.
class WorkspaceSectionHeader extends StatelessWidget {
  const WorkspaceSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                actionLabel ?? 'See all',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.terracotta,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
