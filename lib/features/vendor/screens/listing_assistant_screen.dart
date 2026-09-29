import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../services/artisan_ai_service.dart';
import '../widgets/studio/compare_slider.dart';
import '../widgets/studio/look_card.dart';
import '../widgets/studio/photo_adjustments.dart';
import '../widgets/studio/tag_suggestions.dart';

class ListingAssistantResult {
  final String? title, description;
  final double? price;
  final Uint8List? photo;
  final List<String>? tags;
  const ListingAssistantResult({
    this.title,
    this.description,
    this.price,
    this.photo,
    this.tags,
  });
}

const _studioLooks = [
  ('warm', 'Warm studio', Color(0xFFE7CDB4)),
  ('linen', 'Natural linen', Color(0xFFEAE2D3)),
  ('ivory', 'Clean ivory', Color(0xFFF8F5EF)),
  ('earth', 'Deep earth', Color(0xFF5A3728)),
];

class ListingAssistantScreen extends ConsumerStatefulWidget {
  final String shopId, title, description;
  final File? photo;

  /// Optional context used only for on-device (non-AI) tag suggestions.
  final String? category;
  final List<String> existingTags;
  final List<String> candidateTags;

  const ListingAssistantScreen({
    super.key,
    required this.shopId,
    required this.title,
    required this.description,
    this.photo,
    this.category,
    this.existingTags = const [],
    this.candidateTags = const [],
  });
  @override
  ConsumerState<ListingAssistantScreen> createState() =>
      _ListingAssistantScreenState();
}

class _ListingAssistantScreenState
    extends ConsumerState<ListingAssistantScreen> {
  late final _facts = TextEditingController(
    text: [
      widget.title,
      widget.description,
    ].where((s) => s.trim().isNotEmpty).join('\n\n'),
  );
  final _title = TextEditingController(),
      _description = TextEditingController();
  final _prompt = TextEditingController();
  final _materials = TextEditingController(),
      _labour = TextEditingController(),
      _overheads = TextEditingController(),
      _margin = TextEditingController(text: '35');
  File? _source;
  Uint8List? _generated;
  bool _busy = false,
      _consent = false,
      _checking = true,
      _listingEnabled = false,
      _imageEnabled = false;
  bool _hasCopy = false;
  String _style = _studioLooks.first.$1;
  String? _error, _account;
  Map<String, dynamic>? _request;
  final List<ListingAssistantResult> _applied = [];
  bool _wordingApplied = false, _photoApplied = false, _priceApplied = false;
  bool _tagsApplied = false, _editApplied = false;

  // On-device photo tools (crop is delegated to image_cropper; straighten,
  // 90° turns, brightness and warmth are applied locally and previewed with
  // a ColorFilter/Transform, never sent anywhere).
  int _quarterTurns = 0;
  double _straighten = 0;
  double _brightness = 0;
  double _warmth = 0;
  bool _savingEdit = false;

  final Set<String> _selectedSuggestedTags = {};

  @override
  void initState() {
    super.initState();
    _source = widget.photo;
    _account = ref.read(currentUserIdProvider);
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
        setState(() {
          _listingEnabled = caps['listing'] == true;
          _imageEnabled = caps['image'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'AI connection is not ready. Pricing works offline; retry when setup is complete.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _facts,
      _title,
      _description,
      _prompt,
      _materials,
      _labour,
      _overheads,
      _margin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _sameAccount =>
      ref.read(currentUserIdProvider) == _account && _account != null;

  double get _totalRotation => _quarterTurns * 90 + _straighten;
  bool get _hasEdits =>
      _quarterTurns != 0 ||
      _straighten != 0 ||
      _brightness != 0 ||
      _warmth != 0;

  void _resetEditValues() {
    _quarterTurns = 0;
    _straighten = 0;
    _brightness = 0;
    _warmth = 0;
    _editApplied = false;
  }

  Future<void> _pick() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        setState(() {
          _source = File(image.path);
          _generated = null;
          _error = null;
          _resetEditValues();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open photos. Check photo permissions and try again.',
        );
      }
    }
  }

  Future<void> _cropSourcePhoto() async {
    final file = _source;
    if (file == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop product photo',
            toolbarColor: AppTheme.terracotta,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.terracotta,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop product photo'),
        ],
      );
      if (cropped != null && mounted) {
        setState(() {
          _source = File(cropped.path);
          _generated = null;
          _resetEditValues();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the cropping tool. Try again.');
      }
    }
  }

  Future<void> _saveEditedPhoto() async {
    final file = _source;
    if (file == null || !_hasEdits) return;
    setState(() => _savingEdit = true);
    try {
      final bytes = await renderStudioPhoto(
        await file.readAsBytes(),
        rotationDegrees: _totalRotation,
        brightness: _brightness,
        warmth: _warmth,
      );
      if (!mounted) return;
      setState(() {
        _editApplied = true;
      });
      _apply(ListingAssistantResult(photo: bytes));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save the edited photo. Your original is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingEdit = false);
    }
  }

  Future<void> _generate(String operation) async {
    if (!_sameAccount) {
      setState(
        () => _error =
            'Your account changed. Close this screen and reopen your product.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_request == null) {
        if (!_consent) throw const ArtisanAiException('consent_required');
        if (operation == 'listing' && _facts.text.trim().length < 10) {
          throw const ArtisanAiException('provide_product_facts');
        }
        String? encoded;
        if (operation == 'image') {
          if (_source == null) throw const ArtisanAiException('invalid_image');
          if (await _source!.length() > 8 * 1024 * 1024) {
            throw const ArtisanAiException('image_too_large');
          }
          encoded = base64Encode(await _source!.readAsBytes());
        }
        _request = {
          'id': const Uuid().v4(),
          'shop_id': widget.shopId,
          'operation': operation,
          'facts': _facts.text.trim(),
          'consent': true,
          if (operation == 'image') ...{
            'style': _style,
            'image': encoded,
            'prompt': _prompt.text.trim(),
          },
        };
      }
      final service = ref.read(artisanAiServiceProvider);
      final result = await service.generate(_request!);
      final bytes = operation == 'image'
          ? await service.download(result['image_path'] as String)
          : null;
      if (!mounted || !_sameAccount) return;
      setState(() {
        if (operation == 'listing') {
          _title.text = result['title'] as String;
          _description.text = result['description'] as String;
          _hasCopy = true;
        } else {
          _generated = bytes;
        }
        _request = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ArtisanAiException
              ? error.message
              : 'We could not confirm the result. Check again; your original is safe.';
          // These errors explicitly mean no in-flight work remains.
          if (error is ArtisanAiException &&
              const [
                'failed',
                'generation_failed',
                'generation_refused',
                'generation_incomplete',
                'invalid_generation',
                'daily_limit_reached',
                'ai_not_enabled',
                'provide_product_facts',
                'image_too_large',
                'invalid_image',
                'unsupported_image',
                'consent_required',
              ].contains(error.code)) {
            _request = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(ListingAssistantResult result) {
    if (!_sameAccount) {
      setState(() => _error = 'Please reopen the editor after signing in.');
      return;
    }
    setState(() {
      _applied.add(result);
      if (result.title != null || result.description != null) {
        _wordingApplied = true;
      }
      if (result.photo != null) _photoApplied = true;
      if (result.price != null) _priceApplied = true;
      if (result.tags != null && result.tags!.isNotEmpty) {
        _tagsApplied = true;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _done() => Navigator.of(context).pop(_applied);

  void _enlarge(ImageProvider image, String label) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppTheme.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                title: Text(label),
                trailing: IconButton(
                  tooltip: 'Close photo',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool number = false,
    int? limit,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      enabled: !_busy && _request == null,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      maxLength: limit,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
  Widget _button(
    String label,
    VoidCallback? callback, {
    IconData icon = Icons.auto_awesome_outlined,
  }) => FilledButton.icon(
    onPressed: callback,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: const Color(0xFF536451),
    ),
  );
  Widget _content(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (_, value) {
      if (value != _account && mounted) {
        setState(() {
          _generated = null;
          _hasCopy = false;
          _title.clear();
          _description.clear();
          _request = null;
          _error = 'Account changed. Close and reopen the editor.';
          _listingEnabled = false;
          _imageEnabled = false;
        });
      }
    });
    final locked = _busy || _request != null;
    final canGenerate = !_busy && !_checking && _consent && _sameAccount;
    final price = suggestedListingPrice(
      materials:
          double.tryParse(_materials.text.replaceAll(',', '.')) ?? double.nan,
      labour: double.tryParse(_labour.text.replaceAll(',', '.')) ?? double.nan,
      overheads:
          double.tryParse(_overheads.text.replaceAll(',', '.')) ?? double.nan,
      margin: double.tryParse(_margin.text.replaceAll(',', '.')) ?? double.nan,
    );
    final suggestedTags = suggestListingTags(
      title: _title.text.trim().isNotEmpty ? _title.text : widget.title,
      category: widget.category,
      existingTags: widget.existingTags,
      candidateTags: widget.candidateTags,
    );
    return PopScope(
      canPop: !_busy,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppTheme.scaffoldBg,
            title: Text(
              'Make it listing-ready',
              style: GoogleFonts.playfairDisplay(fontSize: 21),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _applied.isEmpty ? null : _done,
                  child: Text(
                    _applied.isEmpty ? 'Done' : 'Done (${_applied.length})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Words'),
                Tab(text: 'Photos'),
                Tab(text: 'Pricing'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              if (_request != null && !_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _button(
                    'Check existing result',
                    () => _generate(_request!['operation'] as String),
                    icon: Icons.refresh,
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _content([
                      const Text(
                        'Your craft, in your words',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tell us what it is, what it is made from and what makes it special. Only include details you know are true.',
                      ),
                      const SizedBox(height: 20),
                      _field(
                        _facts,
                        'Confirmed product details',
                        lines: 4,
                        limit: 5000,
                      ),
                      _consentControl(),
                      if (!_checking && !_listingEnabled) _unavailable(),
                      _button(
                        _busy
                            ? 'Working on your listing…'
                            : 'Suggest title & description',
                        canGenerate && _listingEnabled && !locked
                            ? () => _generate('listing')
                            : null,
                      ),
                      if (_hasCopy) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Review your suggestion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check accuracy and edit the wording before using it. Nothing is saved automatically.',
                        ),
                        const SizedBox(height: 16),
                        _field(_title, 'Suggested title', limit: 150),
                        _field(
                          _description,
                          'Suggested description',
                          lines: 5,
                          limit: 4000,
                        ),
                        _button(
                          _wordingApplied
                              ? 'Wording applied ✓'
                              : 'Use this wording',
                          !locked &&
                                  _title.text.trim().isNotEmpty &&
                                  _description.text.trim().isNotEmpty
                              ? () => _apply(
                                  ListingAssistantResult(
                                    title: _title.text.trim(),
                                    description: _description.text.trim(),
                                  ),
                                )
                              : null,
                          icon: Icons.check,
                        ),
                        if (_wordingApplied)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Applied. Tap Done to bring it back to your listing.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                      ],
                      if (suggestedTags.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Suggestions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Local suggestions based on your title, category and existing tags — not AI. Tap to add or remove.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in suggestedTags)
                              FilterChip(
                                label: Text(tag),
                                selected: _selectedSuggestedTags.contains(tag),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _selectedSuggestedTags.add(tag);
                                  } else {
                                    _selectedSuggestedTags.remove(tag);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _button(
                          _tagsApplied ? 'Tags applied ✓' : 'Add selected tags',
                          _selectedSuggestedTags.isEmpty
                              ? null
                              : () => _apply(
                                  ListingAssistantResult(
                                    tags: _selectedSuggestedTags.toList(),
                                  ),
                                ),
                          icon: Icons.local_offer_outlined,
                        ),
                        if (_tagsApplied)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Applied. Tap Done to bring it back to your listing.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                      ],
                    ]),
                    _content([
                      const Text(
                        'A consistent shop aesthetic',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Refresh the background and lighting. Always check that the real product has not changed. Your original stays untouched.',
                      ),
                      const SizedBox(height: 16),
                      if (_source != null)
                        _photo(FileImage(_source!), 'Original'),
                      OutlinedButton.icon(
                        onPressed: locked ? null : _pick,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _source == null
                              ? 'Choose a product photo'
                              : 'Choose another photo',
                        ),
                      ),
                      if (_source != null) ...[
                        const SizedBox(height: 16),
                        _photoTools(locked),
                        const SizedBox(height: 16),
                        _compareSection(),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Choose a consistent store look',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 92,
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
                              enabled: !_checking && _imageEnabled && !locked,
                              onTap: () => setState(() {
                                _style = look.$1;
                                _generated = null;
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _prompt,
                        enabled: !_checking && _imageEnabled && !locked,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Describe the look you want',
                          helperText: !_checking && !_imageEnabled
                              ? "AI suggestions aren't available on your account yet."
                              : null,
                          filled: true,
                          fillColor: AppTheme.cardBg,
                          prefixIcon: const Icon(Icons.auto_awesome_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _consentControl(),
                      if (!_checking && !_imageEnabled) _unavailable(),
                      _button(
                        _busy ? 'Preparing your photo…' : 'Create styled photo',
                        canGenerate &&
                                _imageEnabled &&
                                !locked &&
                                _source != null
                            ? () => _generate('image')
                            : null,
                      ),
                      if (_generated != null) ...[
                        const SizedBox(height: 24),
                        _photo(
                          MemoryImage(_generated!),
                          'AI-styled result · tap to inspect',
                        ),
                        const Text(
                          'Compare colour, pattern, shape and detail with the original. Do not use an inaccurate result.',
                        ),
                        const SizedBox(height: 12),
                        _button(
                          _photoApplied
                              ? 'Photo applied ✓'
                              : 'Add result to listing',
                          locked
                              ? null
                              : () => _apply(
                                  ListingAssistantResult(photo: _generated),
                                ),
                          icon: Icons.add,
                        ),
                        if (_photoApplied)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Applied. Tap Done to bring it back to your listing.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                      ],
                    ]),
                    _content([
                      const Text(
                        'Price with confidence',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A transparent cost calculator, not an AI market valuation. Enter costs per item, including your time.',
                      ),
                      const SizedBox(height: 20),
                      _field(
                        _materials,
                        'Materials per item (R)',
                        number: true,
                      ),
                      _field(_labour, 'Labour per item (R)', number: true),
                      _field(
                        _overheads,
                        'Packaging & other costs (R)',
                        number: true,
                      ),
                      _field(_margin, 'Target gross margin (%)', number: true),
                      if (price != null) ...[
                        Text(
                          'R ${price.toStringAsFixed(2)}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 34,
                            color: const Color(0xFF536451),
                          ),
                        ),
                        const Text(
                          'This price covers your costs and target margin. It does not include any fees, delivery or taxes you have not entered — treat it as a starting point, not a guaranteed profit.',
                        ),
                        const SizedBox(height: 20),
                        _button(
                          _priceApplied ? 'Price applied ✓' : 'Use this price',
                          locked
                              ? null
                              : () => _apply(
                                  ListingAssistantResult(price: price),
                                ),
                          icon: Icons.check,
                        ),
                        if (_priceApplied)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Applied. Tap Done to bring it back to your listing.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                      ] else
                        const Text(
                          'Enter all costs (use 0 where appropriate) and a margin from 0 to below 100%.',
                        ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoTools(bool locked) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.sand.withValues(alpha: .4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adjust your photo',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Crop, straighten and adjust the light on this device. Your original photo is never overwritten.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked ? null : _cropSourcePhoto,
                icon: const Icon(Icons.crop, size: 18),
                label: const Text('Crop & straighten'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Rotate 90°',
              onPressed: locked
                  ? null
                  : () =>
                        setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
              icon: const Icon(Icons.rotate_90_degrees_ccw_outlined),
            ),
          ],
        ),
        _adjustSlider(
          'Straighten',
          _straighten,
          -15,
          15,
          locked ? null : (v) => setState(() => _straighten = v),
          display: '${_straighten.toStringAsFixed(0)}°',
        ),
        _adjustSlider(
          'Brightness',
          _brightness,
          -.25,
          .25,
          locked ? null : (v) => setState(() => _brightness = v),
        ),
        _adjustSlider(
          'Warmth',
          _warmth,
          -.25,
          .25,
          locked ? null : (v) => setState(() => _warmth = v),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _button(
                _editApplied
                    ? 'Edited photo saved ✓'
                    : _savingEdit
                    ? 'Saving…'
                    : 'Save edited photo',
                (locked || _savingEdit || !_hasEdits) ? null : _saveEditedPhoto,
                icon: Icons.save_alt_outlined,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Reset edits',
              onPressed: (locked || !_hasEdits)
                  ? null
                  : () => setState(_resetEditValues),
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _adjustSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged, {
    String? display,
  }) => Row(
    children: [
      SizedBox(
        width: 82,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(
        width: 44,
        child: Text(
          display ?? value.toStringAsFixed(2),
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    ],
  );

  Widget _compareSection() {
    final source = _source;
    if (source == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before & after',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        BeforeAfterCompare(
          before: Image.file(source, fit: BoxFit.cover),
          after: StudioPhotoPreview(
            rotationDegrees: _totalRotation,
            brightness: _brightness,
            warmth: _warmth,
            child: Image.file(source, fit: BoxFit.cover),
          ),
          beforeLabel: 'Original',
          afterLabel: 'Edited',
          onTapBefore: () => _enlarge(FileImage(source), 'Original'),
          onTapAfter: () => _enlarge(FileImage(source), 'Edited'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Drag the handle to compare, or tap either side to inspect closely.',
          style: TextStyle(fontSize: 11, color: AppTheme.textHint),
        ),
      ],
    );
  }

  Widget _consentControl() => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    value: _consent,
    onChanged: _busy || _request != null
        ? null
        : (v) => setState(() => _consent = v ?? false),
    title: const Text(
      'Send these details or this photo to OpenAI to generate a suggestion.',
      style: TextStyle(fontSize: 12),
    ),
    subtitle: const Text(
      'Only upload images you have permission to use. Review before publishing.',
      style: TextStyle(fontSize: 11),
    ),
  );
  Widget _unavailable() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            "AI suggestions aren't available on your account yet.",
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: _checking ? null : _check,
          child: const Text('Retry'),
        ),
      ],
    ),
  );
  Widget _photo(ImageProvider image, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Enlarge $label',
          child: GestureDetector(
            onTap: () => _enlarge(image, label),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
