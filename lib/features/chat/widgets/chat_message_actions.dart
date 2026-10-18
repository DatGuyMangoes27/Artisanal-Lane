import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../models/models.dart';
import '../../buyer/widgets/content_report_sheet.dart';

/// Whether received messages in this conversation can be reported (the
/// scaffold only offers it on other people's messages). Artisan Lane support
/// conversations are not member content.
bool canReportInChatThread({
  required String? currentUserId,
  required bool isSupportThread,
  bool safetyEnabled = creatorSafetyEnabled,
}) =>
    safetyEnabled &&
    !isSupportThread &&
    currentUserId != null &&
    currentUserId.isNotEmpty;

/// Long-press menu for a received chat message: copy its text or report it.
Future<void> showChatMessageActions(BuildContext context, ChatMessage message) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasText)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text('Copy text', style: GoogleFonts.poppins()),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.body!));
                Navigator.pop(sheetContext);
              },
            ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppTheme.error),
            title: Text(
              'Report message',
              style: GoogleFonts.poppins(color: AppTheme.error),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              showContentReportSheet(
                context,
                rawTargetType: ExtraReportTargets.message,
                targetId: message.id,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
