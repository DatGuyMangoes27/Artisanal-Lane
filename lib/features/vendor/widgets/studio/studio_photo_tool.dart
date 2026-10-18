import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme.dart';
import '../../../../widgets/skeleton.dart';
import 'compare_slider.dart';
import 'photo_adjustments.dart';
import 'studio_photo_source.dart';
import 'studio_ui.dart';

/// Reads a photo's width / height. Replaceable in widget tests, where real
/// image decoding can't run inside the fake-async test zone.
@visibleForTesting
Future<double> Function(Uint8List bytes) studioPhotoAspectReader =
    _decodeAspect;

/// Renders the final edited photo. Replaceable in widget tests for the same
/// reason; [renderStudioPhoto] itself is covered by plain unit tests.
@visibleForTesting
Future<Uint8List> Function(
  Uint8List bytes, {
  required double rotationDegrees,
  required double brightness,
  required double warmth,
})
studioPhotoRenderer = _render;

Future<double> _decodeAspect(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final aspect = frame.image.width / math.max(1, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return aspect;
}

Future<Uint8List> _render(
  Uint8List bytes, {
  required double rotationDegrees,
  required double brightness,
  required double warmth,
}) => renderStudioPhoto(
  bytes,
  rotationDegrees: rotationDegrees,
  brightness: brightness,
  warmth: warmth,
);

/// An edited photo ready to go back to the listing. [sourceId] names the
/// listing photo it replaces (null = add as a new photo).
class StudioEditedPhoto {
  const StudioEditedPhoto({required this.bytes, required this.sourceId});
  final Uint8List bytes;
  final String? sourceId;
}

/// Photo touch-up: 90° turns, straighten, brightness and warmth, with a
/// live before/after. Everything runs on the device.
class StudioPhotoTool extends StatefulWidget {
  const StudioPhotoTool({
    super.key,
    required this.photos,
    required this.onSave,
    this.initialIndex = 0,
    this.onSelectionChanged,
  });

  final List<StudioPhotoSource> photos;
  final int initialIndex;
  final ValueChanged<StudioEditedPhoto> onSave;

  /// Tells the parent which photo is selected (shared with other photo tools).
  final ValueChanged<StudioPhotoSource?>? onSelectionChanged;

  @override
  State<StudioPhotoTool> createState() => _StudioPhotoToolState();
}

class _StudioPhotoToolState extends State<StudioPhotoTool> {
  late final List<StudioPhotoSource> _photos = [...widget.photos];
  late int _selected = _photos.isEmpty
      ? -1
      : widget.initialIndex.clamp(0, _photos.length - 1);
  Uint8List? _bytes;
  double _aspect = 1;
  bool _loading = false;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;
  int _loadToken = 0;

  int _quarterTurns = 0;
  double _straighten = 0;
  double _brightness = 0;
  double _warmth = 0;

  double get _rotation => _quarterTurns * 90 + _straighten;
  bool get _hasEdits =>
      _quarterTurns != 0 ||
      _straighten != 0 ||
      _brightness != 0 ||
      _warmth != 0;

  StudioPhotoSource? get _source =>
      _selected >= 0 && _selected < _photos.length ? _photos[_selected] : null;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  void _reset() {
    _quarterTurns = 0;
    _straighten = 0;
    _brightness = 0;
    _warmth = 0;
  }

  Future<void> _load({bool initial = false}) async {
    final source = _source;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectionChanged?.call(source);
    });
    if (source == null) return;
    final token = ++_loadToken;
    void begin() {
      _loading = true;
      _loadFailed = false;
      _bytes = null;
      _error = null;
    }

    if (initial) {
      begin();
    } else {
      setState(begin);
    }
    try {
      final bytes = await source.loadBytes();
      final aspect = await studioPhotoAspectReader(bytes);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _bytes = bytes;
        _aspect = aspect;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _select(int index) {
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = index;
      _reset();
    });
    _load();
  }

  Future<void> _pickFromPhone() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      setState(() {
        _photos.add(StudioPhotoSource.file(null, File(image.path)));
        _selected = _photos.length - 1;
        _reset();
      });
      _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open your photos. Check photo access in your phone settings.',
        );
      }
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || !_hasEdits || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final edited = await studioPhotoRenderer(
        bytes,
        rotationDegrees: _rotation,
        brightness: _brightness,
        warmth: _warmth,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onSave(StudioEditedPhoto(bytes: edited, sourceId: _source?.id));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save the edited photo. Your original is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _enlarge({required bool edited}) {
    final bytes = _bytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppTheme.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                title: Text(
                  edited ? 'Edited' : 'Original',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Close photo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: _preview(bytes, edited: edited),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(Uint8List bytes, {required bool edited}) => StudioPhotoPreview(
    aspectRatio: _aspect,
    rotationDegrees: edited ? _rotation : 0,
    brightness: edited ? _brightness : 0,
    warmth: edited ? _warmth : 0,
    child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
  );

  @override
  Widget build(BuildContext context) {
    return StudioToolLayout(
      actionBar: StudioActionBar(
        label: _saving
            ? 'Saving…'
            : _hasEdits
            ? 'Save photo to listing'
            : 'Make an adjustment to save',
        icon: _hasEdits ? Icons.check_rounded : null,
        isLoading: _saving,
        onPressed: _hasEdits && _bytes != null && !_saving ? _save : null,
      ),
      children: [
        const StudioIntro(
          title: 'Photo touch-up',
          body:
              'Rotate, straighten and brighten a photo. The edited version '
              'replaces the original in your listing.',
        ),
        if (_photos.isEmpty)
          _emptyState()
        else ...[
          if (_photos.length > 1) ...[
            const StudioLabel('Choose a photo'),
            const SizedBox(height: 8),
            _thumbnails(),
            const SizedBox(height: 16),
          ],
          _compare(),
          const SizedBox(height: 16),
          _controls(),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _saving ? null : _pickFromPhone,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Touch up a different photo from my phone'),
            ),
          ),
        ],
        if (_error != null) StudioError(_error!),
      ],
    );
  }

  Widget _emptyState() => StudioCard(
    key: const Key('studio-photo-empty'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.bone,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.photo_outlined,
            color: AppTheme.terracotta,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add a photo to touch up',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const StudioNote(
          'Choose a product photo from your phone. The edited version is '
          'added to your listing.',
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pickFromPhone,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('Choose a photo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _thumbnails() => SizedBox(
    height: 68,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _photos.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final selected = index == _selected;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Photo ${index + 1}',
          child: GestureDetector(
            onTap: () => _select(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppTheme.terracotta : AppTheme.sand,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image(
                  image: _photos[index].thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppTheme.bone),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _compare() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(constraints.maxWidth, 340.0);
        final bytes = _bytes;
        if (_loading || (bytes == null && !_loadFailed)) {
          return Skeleton(
            child: SkeletonBox(
              key: const Key('studio-photo-loading'),
              height: height,
              radius: 18,
            ),
          );
        }
        if (bytes == null) {
          return StudioCard(
            child: SizedBox(
              height: height * .6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  const StudioNote("Couldn't open this photo."),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeforeAfterCompare(
              height: height,
              before: _preview(bytes, edited: false),
              after: _preview(bytes, edited: true),
              beforeLabel: 'Before',
              afterLabel: 'After',
              onTapBefore: () => _enlarge(edited: false),
              onTapAfter: () => _enlarge(edited: true),
            ),
            const SizedBox(height: 6),
            const StudioNote(
              'Drag the handle to compare. Tap a side to look closer.',
            ),
          ],
        );
      },
    );
  }

  Widget _controls() {
    final enabled = _bytes != null && !_saving;
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: StudioLabel('Adjust')),
              TextButton.icon(
                onPressed: enabled && _hasEdits
                    ? () => setState(_reset)
                    : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: enabled
                  ? () => setState(
                      () => _quarterTurns = (_quarterTurns + 1) % 4,
                    )
                  : null,
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined, size: 18),
              label: const Text('Rotate 90°'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _slider(
            'Straighten',
            _straighten,
            -15,
            15,
            '${_straighten.round()}°',
            enabled ? (v) => setState(() => _straighten = v) : null,
            divisions: 60,
          ),
          _slider(
            'Brightness',
            _brightness,
            -.25,
            .25,
            _signedPercent(_brightness),
            enabled ? (v) => setState(() => _brightness = v) : null,
          ),
          _slider(
            'Warmth',
            _warmth,
            -.25,
            .25,
            _signedPercent(_warmth),
            enabled ? (v) => setState(() => _warmth = v) : null,
          ),
        ],
      ),
    );
  }

  String _signedPercent(double value) {
    final percent = (value * 400).round();
    return percent > 0 ? '+$percent' : '$percent';
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double>? onChanged, {
    int? divisions,
  }) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              display,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.terracotta,
          inactiveColor: AppTheme.sand.withValues(alpha: .6),
          semanticFormatterCallback: (_) => '$label $display',
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
