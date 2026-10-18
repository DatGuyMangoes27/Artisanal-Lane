import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../services/artisan_ai_service.dart';

/// "Polish with AI" action under the caption field.
///
/// Renders nothing at all unless [artisanAiCapabilitiesProvider] confirms AI
/// listing text is enabled for this account — no disabled teaser, no
/// "not available" note, and nothing while the check is still running.
class ComposerAiCaptionButton extends ConsumerStatefulWidget {
  const ComposerAiCaptionButton({
    super.key,
    required this.shopId,
    required this.captionController,
  });

  final String shopId;
  final TextEditingController captionController;

  @override
  ConsumerState<ComposerAiCaptionButton> createState() =>
      _ComposerAiCaptionButtonState();
}

class _ComposerAiCaptionButtonState
    extends ConsumerState<ComposerAiCaptionButton> {
  bool _polishing = false;
  String? _error;

  Future<void> _polish() async {
    if (_polishing) return;
    final facts = widget.captionController.text.trim();
    if (facts.isEmpty) {
      setState(
        () => _error = 'Write a starting caption first, then polish it.',
      );
      return;
    }
    setState(() {
      _polishing = true;
      _error = null;
    });
    try {
      final service = ref.read(artisanAiServiceProvider);
      final result = await service.generate({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'shop_id': widget.shopId,
        'operation': 'listing',
        'facts': facts,
        'consent': true,
      });
      final polished =
          result['description'] as String? ?? result['title'] as String?;
      if (polished != null && polished.trim().isNotEmpty && mounted) {
        widget.captionController.text = polished.trim();
      }
    } on ArtisanAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not polish your caption right now.');
      }
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!watchArtisanAiCapabilities(ref).listing) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            key: const Key('composer-polish-ai'),
            onPressed: _polishing ? null : _polish,
            icon: _polishing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(
              _polishing ? 'Polishing…' : 'Polish with AI',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terracotta,
              side: const BorderSide(color: AppTheme.terracotta),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
            ),
          ),
      ],
    );
  }
}
