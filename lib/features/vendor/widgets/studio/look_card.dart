import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// One selectable "store look" card, matching the AI studio demo's look
/// chooser. When [enabled] is false (AI unavailable) the card is muted and
/// shows a lock glyph instead of being selectable.
class StudioLookCard extends StatelessWidget {
  const StudioLookCard({
    super.key,
    required this.label,
    required this.swatch,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final Color swatch;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: enabled ? label : '$label (unavailable)',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Container(
            width: 88,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.terracotta : AppTheme.sand,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 32,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: enabled
                      ? null
                      : const Icon(Icons.lock_outline, size: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
