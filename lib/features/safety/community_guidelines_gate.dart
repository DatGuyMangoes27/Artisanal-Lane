import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../services/safety_service.dart';
import '../auth/providers/auth_providers.dart';
import 'community_guidelines_content.dart';
import 'community_guidelines_screen.dart';

/// Members known (this session) to have accepted the community guidelines.
class CommunityGuidelinesAcceptance extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void markAccepted(String userId) => state = {...state, userId};
}

final communityGuidelinesAcceptanceProvider =
    NotifierProvider<CommunityGuidelinesAcceptance, Set<String>>(
      CommunityGuidelinesAcceptance.new,
    );

/// Makes sure the signed-in member has agreed to the community guidelines
/// before they post, comment, review or message.
///
/// Returns true straight away when acceptance is already known (cached per
/// account for the session, then checked on the server once). Otherwise shows
/// a one-time sheet summarising the rules with an "I agree" button that
/// records acceptance through `accept_community_guidelines()`. Returns false
/// for guests or when the member closes the sheet without agreeing.
///
/// ```dart
/// if (!await ensureCommunityGuidelinesAccepted(context, ref)) return;
/// ```
Future<bool> ensureCommunityGuidelinesAccepted(
  BuildContext context,
  WidgetRef ref,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return false;
  if (ref.read(communityGuidelinesAcceptanceProvider).contains(userId)) {
    return true;
  }

  final SafetyService service;
  try {
    service = ref.read(safetyServiceProvider);
  } catch (_) {
    // No backend client (focused widget tests render screens without one):
    // nothing can be posted, so there is nothing to gate.
    return true;
  }

  void remember() {
    if (ref.read(currentUserIdProvider) == userId) {
      ref
          .read(communityGuidelinesAcceptanceProvider.notifier)
          .markAccepted(userId);
    }
  }

  try {
    if (await service.fetchCommunityGuidelinesAcceptedAt() != null) {
      remember();
      return true;
    }
  } catch (_) {
    // Unknown (offline or older backend): ask; agreeing retries the server.
  }

  if (!context.mounted || ref.read(currentUserIdProvider) != userId) {
    return false;
  }
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        CommunityGuidelinesSheet(onAgree: service.acceptCommunityGuidelines),
  );
  if (agreed == true && ref.read(currentUserIdProvider) == userId) {
    remember();
    return true;
  }
  return false;
}

/// Opens the full guidelines, through the app router when there is one.
void openCommunityGuidelines(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(communityGuidelinesRoute);
    return;
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const CommunityGuidelinesScreen()),
  );
}

/// The one-time acceptance sheet. Pops `true` once [onAgree] succeeds.
class CommunityGuidelinesSheet extends StatefulWidget {
  const CommunityGuidelinesSheet({super.key, required this.onAgree});

  final Future<Object?> Function() onAgree;

  @override
  State<CommunityGuidelinesSheet> createState() =>
      _CommunityGuidelinesSheetState();
}

class _CommunityGuidelinesSheetState extends State<CommunityGuidelinesSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _agree() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAgree();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              "Couldn't save your agreement. Check your connection and try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.poppins(
      fontSize: 13,
      height: 1.5,
      color: AppTheme.textSecondary,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our community guidelines',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Artisan Lane has no tolerance for objectionable content or '
              'abusive users. Before you post, comment, review or message, '
              'please agree to keep it kind:',
              style: body,
            ),
            const SizedBox(height: 12),
            for (final rule in communityGuidelinesSummary)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 10),
                      child: Icon(
                        Icons.block_rounded,
                        size: 16,
                        color: AppTheme.terracotta,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule,
                        style: body.copyWith(color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Anyone can report content or block people. Our team reviews '
              'reports within 24 hours, removes content that breaks these '
              'rules and removes the people who post it.',
              style: body,
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => openCommunityGuidelines(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Read the full community guidelines'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _agree,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving…' : 'I agree',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
