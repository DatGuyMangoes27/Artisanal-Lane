import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Replaces the message composer when the other person is blocked, or when the
/// server refused a send (for example because they blocked you).
class ChatBlockBar extends StatelessWidget {
  const ChatBlockBar.blocked({super.key, required this.onUnblock})
    : message = "You've blocked this person";

  const ChatBlockBar.cannotReply({super.key})
    : message = "You can't reply to this conversation",
      onUnblock = null;

  final String message;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.block_outlined,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            if (onUnblock != null)
              OutlinedButton(
                onPressed: onUnblock,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  side: const BorderSide(color: AppTheme.terracotta),
                  foregroundColor: AppTheme.terracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text('Unblock'),
              ),
          ],
        ),
      ),
    );
  }
}
