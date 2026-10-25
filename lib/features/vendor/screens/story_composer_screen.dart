import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../models/shop.dart';
import '../../auth/providers/auth_providers.dart';
import '../../buyer/providers/story_providers.dart';
import '../../buyer/widgets/story_media.dart';
import '../../safety/community_guidelines_gate.dart';
import '../../safety/content_filter.dart';
import '../widgets/seller_hub.dart' show kStoryPlacementNote;

class StoryComposerScreen extends ConsumerStatefulWidget {
  const StoryComposerScreen({super.key, required this.shop});
  final Shop shop;
  @override
  ConsumerState<StoryComposerScreen> createState() =>
      _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  final _caption = TextEditingController();
  XFile? _file;
  bool _video = false, _busy = false, _ready = false;
  String? _error;
  String? _requestId;
  bool _dirty = false;

  Future<void> _usePrivateTestPhoto() async {
    if (!isInternalProductEditorTestMode(ref.read(currentUserIdProvider)) ||
        widget.shop.isActive ||
        !widget.shop.isOffline ||
        _requestId != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final asset = await rootBundle.load('assets/preview/foldaway-tote.jpg');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/private-story-upload-test.jpg');
      await file.writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      if (mounted) {
        setState(() {
          _file = XFile(file.path);
          _video = false;
          _ready = false;
          _caption.text = 'Internal story upload check';
          _dirty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load the private test photo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(bool video, ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 60),
            )
          : await picker.pickImage(
              source: source,
              maxWidth: 2160,
              imageQuality: 90,
            );
      if (!mounted || file == null) return;
      if (await file.length() > 50 * 1024 * 1024) {
        throw StateError('Please choose a file smaller than 50 MB.');
      }
      if (!mounted) return;
      setState(() {
        _file = file;
        _video = video;
        _ready = false;
        _dirty = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open media. Check photo permissions and choose a file under 50 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final file = _file;
    if (file == null || !_ready || _busy) return;
    if (ref.read(currentUserIdProvider) != widget.shop.vendorId) {
      setState(
        () => _error =
            'Your account changed. Close this screen and sign in again.',
      );
      return;
    }
    final textError = validateUgcText([_caption.text]);
    if (textError != null) {
      setState(() => _error = textError);
      return;
    }
    if (!await ensureCommunityGuidelinesAccepted(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requestId ??= const Uuid().v4();
      await ref
          .read(storyRepositoryProvider)
          .publish(
            requestId: _requestId!,
            shopId: widget.shop.id,
            file: file,
            video: _video,
            caption: _caption.text,
          );
      if (!mounted) return;
      ref.invalidate(storiesProvider);
      _dirty = false;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Story shared. It shows at the top of the Feed for 24 hours.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              ugcErrorMessage(e) ??
              'We could not confirm publishing. Retry safely with the same photo and caption; this will not create a second story.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _busy) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Discard story?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                "If you leave now, your changes won't be saved.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textHint),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Discard'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _handleClose() async {
    if (_busy) return;
    if (await _confirmDiscard() && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _busy) return;
      if (await _confirmDiscard() && mounted) Navigator.pop(this.context);
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen preview ─────────────────────────────────
            Positioned.fill(
              child: _file != null
                  ? ColoredBox(
                      color: Colors.black,
                      child: StoryMedia(
                        key: ValueKey(_file!.path),
                        file: File(_file!.path),
                        video: _video,
                        paused: true,
                        onReady: (duration) {
                          if (!mounted) return;
                          setState(() {
                            _ready = duration <= const Duration(seconds: 60);
                            _error = _ready
                                ? null
                                : 'This video is longer than 60 seconds. Please trim it before choosing it.';
                          });
                        },
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1C1C1E),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'A moment from your workshop',
                            style: TextStyle(color: Colors.white70),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              kStoryPlacementNote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // ── Top bar ──────────────────────────────────────────────
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : _handleClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: Colors.black38,
                    ),
                  ),
                  const Spacer(),
                  if (isInternalProductEditorTestMode(
                        ref.watch(currentUserIdProvider),
                      ) &&
                      !widget.shop.isActive &&
                      widget.shop.isOffline)
                    TextButton.icon(
                      onPressed: _busy || _requestId != null
                          ? null
                          : _usePrivateTestPhoto,
                      icon: const Icon(
                        Icons.science_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'Test photo',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
            if (!widget.shop.isActive || widget.shop.isOffline)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Text(
                  'Your shop is not public — only you will see this story.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            // ── Caption overlay ──────────────────────────────────────
            if (_file != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 170,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _caption,
                    enabled: !_busy && _requestId == null,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    onChanged: (_) => _dirty = true,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'What are you making today?',
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 128,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.terracotta,
                    fontSize: 12,
                  ),
                ),
              ),
            // ── Bottom controls ──────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _controlButton(
                          icon: Icons.photo_outlined,
                          label: 'Gallery',
                          onTap: _busy || _requestId != null
                              ? null
                              : () => _pick(false, ImageSource.gallery),
                        ),
                        _controlButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'Camera',
                          onTap: _busy || _requestId != null
                              ? null
                              : () => _pick(false, ImageSource.camera),
                        ),
                        _controlButton(
                          icon: Icons.videocam_outlined,
                          label: 'Video',
                          onTap: _busy || _requestId != null
                              ? null
                              : () => _pick(true, ImageSource.gallery),
                        ),
                      ],
                    ),
                    if (_file != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        kStoryPlacementNote,
                        key: const ValueKey('story-placement-note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _busy || !_ready ? null : _publish,
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : _requestId != null
                              ? 'Retry same story'
                              : 'Share to story',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
