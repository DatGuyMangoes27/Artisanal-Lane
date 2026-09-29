import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../services/artisan_ai_service.dart';

/// "Polish with AI" action under the caption field. Availability is checked
/// the same way the listing assistant does (capabilities().listing), and AI
/// generation is never faked: when the account can't use it yet, the button
/// is disabled with the same friendly copy used elsewhere in the app.
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
  bool _checking = true;
  bool _available = false;
  bool _polishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final caps = await ref.read(artisanAiServiceProvider).capabilities();
      if (mounted) {
        setState(() => _available = caps['listing'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => _available = false);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _polish() async {
    if (!_available || _polishing) return;
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
    final disabled = _checking || !_available || _polishing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            key: const Key('composer-polish-ai'),
            onPressed: disabled ? null : _polish,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terracotta,
              side: BorderSide(
                color: disabled ? AppTheme.sand : AppTheme.terracotta,
              ),
            ),
          ),
        ),
        if (!_checking && !_available)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "AI suggestions aren't available on your account yet.",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textHint,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error),
            ),
          ),
      ],
    );
  }
}
