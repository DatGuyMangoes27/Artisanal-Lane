import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme.dart';
import '../../services/artisan_ai_service.dart';
import 'look_card.dart';
import 'studio_photo_source.dart';
import 'studio_ui.dart';

// These tools are only ever built when artisanAiCapabilitiesProvider has
// confirmed the matching capability, so they never show "not available"
// states of their own. Errors here are about a real request that failed.

/// Codes that mean the server holds no in-flight work for the request, so a
/// fresh request (new id) is safe.
const _finishedCodes = {
  'failed',
  'generation_failed',
  'generation_refused',
  'generation_incomplete',
  'invalid_generation',
  'daily_limit_reached',
  'ai_not_enabled',
  'not_configured',
  'provide_product_facts',
  'image_too_large',
  'request_too_large',
  'invalid_image',
  'unsupported_image',
  'consent_required',
  'sign_in_required',
  'shop_not_owned',
};

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.what,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String what;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    activeColor: AppTheme.terracotta,
    onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
    title: Text(
      'Send $what to OpenAI to create a suggestion',
      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
    ),
    subtitle: Text(
      'Only share what you have permission to use. Check the result before '
      'publishing.',
      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
    ),
  );
}

/// AI listing text: confirmed product facts in, suggested title and
/// description out, editable before use.
class StudioAiWritingTool extends ConsumerStatefulWidget {
  const StudioAiWritingTool({
    super.key,
    required this.shopId,
    required this.initialFacts,
    required this.onUseWording,
  });

  final String shopId;
  final String initialFacts;
  final void Function(String title, String description) onUseWording;

  @override
  ConsumerState<StudioAiWritingTool> createState() =>
      _StudioAiWritingToolState();
}

class _StudioAiWritingToolState extends ConsumerState<StudioAiWritingTool> {
  late final _facts = TextEditingController(text: widget.initialFacts);
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _consent = false, _busy = false, _hasCopy = false;
  Map<String, dynamic>? _request;
  String? _error;

  @override
  void dispose() {
    _facts.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_request == null) {
        if (_facts.text.trim().length < 10) {
          throw const ArtisanAiException('provide_product_facts');
        }
        _request = {
          'id': const Uuid().v4(),
          'shop_id': widget.shopId,
          'operation': 'listing',
          'facts': _facts.text.trim(),
          'consent': true,
        };
      }
      final result = await ref
          .read(artisanAiServiceProvider)
          .generate(_request!);
      if (!mounted) return;
      setState(() {
        _title.text = (result['title'] as String? ?? '').trim();
        _description.text = (result['description'] as String? ?? '').trim();
        _hasCopy = true;
        _request = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ArtisanAiException
            ? error.message
            : 'We could not confirm the result. Check again; your listing is unchanged.';
        if (error is ArtisanAiException && _finishedCodes.contains(error.code)) {
          _request = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _request != null;
    final ready =
        _hasCopy &&
        _title.text.trim().isNotEmpty &&
        _description.text.trim().isNotEmpty &&
        !locked;
    return StudioToolLayout(
      actionBar: StudioActionBar(
        label: 'Use this wording',
        icon: Icons.check_rounded,
        onPressed: ready
            ? () => widget.onUseWording(
                _title.text.trim(),
                _description.text.trim(),
              )
            : null,
      ),
      children: [
        const StudioIntro(
          title: 'AI listing text',
          body:
              'Turn your product details into a suggested title and '
              'description you can edit.',
        ),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _facts,
                enabled: !locked,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                keyboardType: TextInputType.multiline,
                decoration: studioInputDecoration(
                  'What is it, what is it made from, what makes it special?',
                  helper: 'Only include details you know are true.',
                ),
              ),
              _ConsentTile(
                value: _consent,
                what: 'these details',
                onChanged: locked ? null : (v) => setState(() => _consent = v),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                key: const Key('studio-ai-write'),
                onPressed: _consent && !_busy
                    ? _generate
                    : null,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _request != null
                            ? Icons.refresh_rounded
                            : Icons.auto_awesome_outlined,
                        size: 18,
                      ),
                label: Text(
                  _busy
                      ? 'Writing…'
                      : _request != null
                      ? 'Check for my result'
                      : 'Write a suggestion',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              if (_error != null) StudioError(_error!),
            ],
          ),
        ),
        if (_hasCopy) ...[
          const SizedBox(height: 14),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StudioLabel('Review your suggestion'),
                const SizedBox(height: 4),
                const StudioNote(
                  'Check it is accurate and edit anything before using it.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  maxLength: 150,
                  onChanged: (_) => setState(() {}),
                  decoration: studioInputDecoration('Suggested title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 4000,
                  onChanged: (_) => setState(() {}),
                  decoration: studioInputDecoration('Suggested description'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

const _studioLooks = [
  ('warm', 'Warm studio', Color(0xFFE7CDB4)),
  ('linen', 'Natural linen', Color(0xFFEAE2D3)),
  ('ivory', 'Clean ivory', Color(0xFFF8F5EF)),
  ('earth', 'Deep earth', Color(0xFF5A3728)),
];

/// AI-styled photo: the selected listing photo restyled on a consistent
/// background. The result is added as a new photo; the original stays.
class StudioAiPhotoTool extends ConsumerStatefulWidget {
  const StudioAiPhotoTool({
    super.key,
    required this.shopId,
    required this.facts,
    required this.source,
    required this.onUsePhoto,
  });

  final String shopId;
  final String facts;
  final StudioPhotoSource? source;
  final ValueChanged<Uint8List> onUsePhoto;

  @override
  ConsumerState<StudioAiPhotoTool> createState() => _StudioAiPhotoToolState();
}

class _StudioAiPhotoToolState extends ConsumerState<StudioAiPhotoTool> {
  final _prompt = TextEditingController();
  String _style = _studioLooks.first.$1;
  bool _consent = false, _busy = false;
  Uint8List? _result;
  Map<String, dynamic>? _request;
  String? _error;

  @override
  void didUpdateWidget(covariant StudioAiPhotoTool oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source?.id != widget.source?.id && _request == null) {
      _result = null;
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final source = widget.source;
    if (source == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_request == null) {
        final bytes = await source.loadBytes();
        if (bytes.length > 8 * 1024 * 1024) {
          throw const ArtisanAiException('image_too_large');
        }
        _request = {
          'id': const Uuid().v4(),
          'shop_id': widget.shopId,
          'operation': 'image',
          'facts': widget.facts,
          'consent': true,
          'style': _style,
          'image': base64Encode(bytes),
          'prompt': _prompt.text.trim(),
        };
      }
      final service = ref.read(artisanAiServiceProvider);
      final result = await service.generate(_request!);
      final bytes = await service.download(result['image_path'] as String);
      if (!mounted) return;
      setState(() {
        _result = bytes;
        _request = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ArtisanAiException
            ? error.message
            : 'We could not confirm the result. Check again; your photos are unchanged.';
        if (error is ArtisanAiException && _finishedCodes.contains(error.code)) {
          _request = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final locked = _busy || _request != null;
    return StudioToolLayout(
      actionBar: StudioActionBar(
        label: 'Add styled photo to listing',
        icon: Icons.add_rounded,
        onPressed: _result != null && !locked
            ? () {
                HapticFeedback.mediumImpact();
                widget.onUsePhoto(_result!);
              }
            : null,
      ),
      children: [
        const StudioIntro(
          title: 'AI styled photo',
          body:
              'Place your product on a consistent background. It is added as '
              'a new photo; your original stays.',
        ),
        if (source == null)
          const StudioCard(
            child: StudioNote(
              'Add a product photo first, then come back to style it.',
            ),
          )
        else ...[
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
                        image: source.thumbnail,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 56,
                          height: 56,
                          child: ColoredBox(color: AppTheme.bone),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: StudioNote(
                        'Using the photo selected in Photo touch-up.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const StudioLabel('Choose a look'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _studioLooks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final look = _studioLooks[index];
                      return StudioLookCard(
                        label: look.$2,
                        swatch: look.$3,
                        selected: _style == look.$1,
                        enabled: !locked,
                        onTap: () => setState(() {
                          _style = look.$1;
                          _result = null;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _prompt,
                  enabled: !locked,
                  minLines: 2,
                  maxLines: 3,
                  decoration: studioInputDecoration(
                    'Anything else about the look? (optional)',
                  ),
                ),
                _ConsentTile(
                  value: _consent,
                  what: 'this photo',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _consent = v),
                ),
                FilledButton.icon(
                  key: const Key('studio-ai-photo'),
                  onPressed: _consent && !_busy ? _generate : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(
                    _busy
                        ? 'Styling your photo…'
                        : _request != null
                        ? 'Check for my result'
                        : 'Create styled photo',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                if (_error != null) StudioError(_error!),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            StudioCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StudioLabel('Your styled photo'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(
                        color: AppTheme.bone,
                        child: Image.memory(_result!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const StudioNote(
                    'Compare colour, pattern, shape and detail with your '
                    'product. Don\'t use a result that isn\'t accurate.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
