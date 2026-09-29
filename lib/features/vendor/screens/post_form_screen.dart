import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../services/creator_post_media.dart';
import '../services/pending_post_store.dart';
import '../services/post_publication.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/creator_parity.dart';
import '../../../models/shop_post.dart';
import '../widgets/post_product_picker.dart';
import '../widgets/composer/composer_ai_caption_button.dart';
import '../widgets/composer/composer_format_picker.dart';
import '../widgets/composer/composer_poll_editor.dart';
import '../widgets/composer/composer_preview_sheet.dart';
import '../widgets/composer/composer_schedule_section.dart';
import '../widgets/composer/composer_settings_section.dart';
import '../widgets/composer/composer_step_captions.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

enum _MediaKind { image, pendingImage, pendingVideo }

/// A single media tile in display order. Uploaded items carry a [url];
/// pending items carry a local [file] until they are uploaded in place,
/// so the artisan's chosen order survives the upload step.
class _MediaItem {
  _MediaItem.url(this.url)
    : id = _nextId++,
      kind = _MediaKind.image,
      file = null;
  _MediaItem.pendingImage(this.file)
    : id = _nextId++,
      kind = _MediaKind.pendingImage,
      url = null;
  _MediaItem.pendingVideo(this.file)
    : id = _nextId++,
      kind = _MediaKind.pendingVideo,
      url = null;

  static int _nextId = 0;
  final int id;
  _MediaKind kind;
  String? url;
  File? file;

  bool get isPending => kind != _MediaKind.image;
  bool get isVideo =>
      kind == _MediaKind.pendingVideo ||
      (kind == _MediaKind.image && isCreatorPostMediaMarker(url ?? ''));
}

class PostFormScreen extends ConsumerStatefulWidget {
  final String? postId;

  const PostFormScreen({super.key, this.postId});

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  final List<_MediaItem> _media = [];
  final Map<int, String> _uploadIds = {};
  final Map<int, TextEditingController> _stepCaptionControllers = {};
  late final String? _editorUserId;
  PostPublication? _submission;
  bool _submissionStarted = false;
  bool _accountChanged = false;
  List<String> _productIds = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isPublishing = false;
  bool _isInitialized = false;
  String? _initializationError;
  bool _dirty = false;

  // ── Composer settings ────────────────────────────────────────────
  PostFormat _format = PostFormat.photo;
  bool _commentsEnabled = true;
  bool _hideLikeCount = false;
  DateTime? _scheduledFor;
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  ComposerPollDuration _pollDuration = ComposerPollDuration.noEnd;

  // ── Edit-only: an existing poll can only be closed early, not rewritten ──
  PostPoll? _existingPoll;
  bool _closingPoll = false;

  String? _validationError;

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    _editorUserId = ref.read(currentUserIdProvider);
    ref.listenManual(currentUserIdProvider, (previous, next) {
      if (next != _editorUserId && mounted) {
        setState(() => _accountChanged = true);
      }
    });
    _captionController.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
    _pollQuestionController.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
    if (_isEditing) {
      _loadPost();
    } else {
      _restoreSubmission();
    }
  }

  List<PostFormat> get _availableFormats => [
    PostFormat.photo,
    PostFormat.carousel,
    PostFormat.tutorial,
    PostFormat.poll,
    if (creatorVideoPostsEnabled) PostFormat.video,
  ];

  int _maxMediaForFormat(PostFormat format) => switch (format) {
    PostFormat.photo => 1,
    PostFormat.video => 1,
    PostFormat.carousel || PostFormat.tutorial || PostFormat.poll => 10,
  };

  TextEditingController _stepCaptionFor(_MediaItem item) {
    return _stepCaptionControllers.putIfAbsent(item.id, () {
      final controller = TextEditingController();
      controller.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
      return controller;
    });
  }

  void _syncPollOptionCount(int count) {
    count = count.clamp(composerPollMinOptions, composerPollMaxOptions);
    while (_pollOptionControllers.length < count) {
      final controller = TextEditingController();
      controller.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
      _pollOptionControllers.add(controller);
    }
    while (_pollOptionControllers.length > count) {
      _pollOptionControllers.removeLast().dispose();
    }
  }

  Future<void> _restoreSubmission() async {
    try {
      final user = _requireEditorAccount();
      final store = PendingPostStore(await SharedPreferences.getInstance());
      _requireEditorAccount();
      final pending = store.read(user);
      if (pending != null) {
        _submission = pending;
        _submissionStarted = true;
        _captionController.text = pending.caption;
        _media.addAll(pending.mediaUrls.map(_MediaItem.url));
        _productIds = List.of(pending.productIds ?? const []);
        _format = pending.format;
        _commentsEnabled = pending.commentsEnabled;
        _hideLikeCount = pending.hideLikeCount;
        _scheduledFor = pending.scheduledFor;
        for (var i = 0; i < _media.length; i++) {
          _stepCaptionFor(_media[i]).text = i < pending.stepCaptions.length
              ? pending.stepCaptions[i]
              : '';
        }
        final poll = pending.poll;
        if (poll != null) {
          _pollQuestionController.text = poll.question;
          _syncPollOptionCount(poll.options.length);
          for (var i = 0; i < poll.options.length; i++) {
            _pollOptionControllers[i].text = poll.options[i];
          }
        }
      }
      setState(() => _isInitialized = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _initializationError =
              'Your pending post could not be restored. Please reopen this editor.',
        );
      }
    }
  }

  Future<void> _loadPost() async {
    setState(() => _initializationError = null);
    try {
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw StateError('Shop unavailable');
      final row = await ref
          .read(supabaseClientProvider)
          .from('shop_posts')
          .select(
            creatorCommerceEnabled
                ? 'caption, media_urls, product_ids, comments_enabled, hide_like_count, scheduled_for, format, step_captions'
                : 'caption, media_urls, comments_enabled, hide_like_count, scheduled_for, format, step_captions',
          )
          .eq('id', widget.postId!)
          .eq('shop_id', shop.id)
          .single();
      if (!mounted) return;
      final stepCaptions = (row['step_captions'] as List? ?? [])
          .whereType<String>()
          .toList();
      setState(() {
        _captionController.text = row['caption'] as String? ?? '';
        _productIds = (row['product_ids'] as List? ?? [])
            .whereType<String>()
            .toList();
        _media.clear();
        _media.addAll(
          (row['media_urls'] as List? ?? []).whereType<String>().map(
            _MediaItem.url,
          ),
        );
        _commentsEnabled = row['comments_enabled'] as bool? ?? true;
        _hideLikeCount = row['hide_like_count'] as bool? ?? false;
        _scheduledFor = row['scheduled_for'] is String
            ? DateTime.tryParse(row['scheduled_for'] as String)
            : null;
        _format = parsePostFormat(row['format']);
        for (var i = 0; i < _media.length; i++) {
          _stepCaptionFor(_media[i]).text = i < stepCaptions.length
              ? stepCaptions[i]
              : '';
        }
        _isInitialized = true;
        _dirty = false;
      });
      if (_format == PostFormat.poll) {
        final poll = await ref
            .read(supabaseServiceProvider)
            .getPostPoll(widget.postId!);
        if (mounted) setState(() => _existingPoll = poll);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _initializationError = 'This post could not be loaded.');
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pollQuestionController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    for (final c in _stepCaptionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalImages => _media.length;

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.terracotta,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Use your camera',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickSingle(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.baobab.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.baobab,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Pick from your photos',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMultiple();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSingle(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null &&
          mounted &&
          _totalImages < _maxMediaForFormat(_format)) {
        setState(() {
          _media.add(_MediaItem.pendingImage(File(image.path)));
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickMultiple() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty && mounted) {
        final remaining = (_maxMediaForFormat(_format) - _totalImages).clamp(
          0,
          _maxMediaForFormat(_format),
        );
        setState(() {
          _media.addAll(
            images
                .take(remaining)
                .map((x) => _MediaItem.pendingImage(File(x.path))),
          );
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      final file = File(picked.path);
      if (await file.length() > creatorPostVideoMaxBytes) {
        throw StateError('Post videos must be 50 MB or smaller.');
      }
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
        if (controller.value.duration > creatorPostVideoMaxDuration) {
          throw StateError('Post videos must be 60 seconds or shorter.');
        }
      } finally {
        await controller.dispose();
      }
      if (mounted && _totalImages < _maxMediaForFormat(_format)) {
        setState(() {
          _media.add(_MediaItem.pendingVideo(file));
          _dirty = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(error, fallback: '$error')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadPendingImages() async {
    final service = ref.read(supabaseServiceProvider);
    for (final item in _media) {
      if (item.kind != _MediaKind.pendingImage) continue;
      final file = item.file!;
      _requireEditorAccount();
      if (await file.length() > 5 * 1024 * 1024) {
        throw StateError('Post photos must be 5 MB or smaller.');
      }
      final userId = _requireEditorAccount();
      final url = await service.uploadShopImage(
        userId,
        file,
        folder: 'posts',
        objectId: _uploadIds.putIfAbsent(item.id, () => const Uuid().v4()),
      );
      _requireEditorAccount();
      // Update the item in place so the artisan's chosen order is kept.
      item
        ..kind = _MediaKind.image
        ..url = url
        ..file = null;
    }
  }

  Future<void> _uploadPendingVideos() async {
    if (!creatorVideoPostsEnabled) return;
    final userId = _requireEditorAccount();
    final media = CreatorPostMediaRepository(ref.read(supabaseClientProvider));
    for (final item in _media) {
      if (item.kind != _MediaKind.pendingVideo) continue;
      final file = item.file!;
      final marker = await media.uploadVideo(
        ownerId: userId,
        file: file,
        uploadId: _uploadIds.putIfAbsent(item.id, media.newUploadId),
      );
      _requireEditorAccount();
      item
        ..kind = _MediaKind.image
        ..url = marker
        ..file = null;
    }
  }

  String _requireEditorAccount() {
    if (!mounted ||
        _accountChanged ||
        _editorUserId == null ||
        ref.read(currentUserIdProvider) != _editorUserId) {
      throw StateError(
        'Your account changed. Close this editor and sign in again.',
      );
    }
    return _editorUserId;
  }

  /// Format-driven validation. Returns a friendly message, or null when the
  /// current selection is publishable.
  String? _formatValidationError() {
    switch (_format) {
      case PostFormat.photo:
      case PostFormat.carousel:
        return composerMediaCountError(_format, _media.length);
      case PostFormat.video:
        if (_media.length == 1 && !_media.first.isVideo) {
          return 'Add exactly one video for a video post.';
        }
        return composerMediaCountError(_format, _media.length);
      case PostFormat.tutorial:
        final countError = composerMediaCountError(_format, _media.length);
        if (countError != null) return countError;
        for (final item in _media) {
          final caption = _stepCaptionFor(item).text.trim();
          if (caption.isEmpty) {
            return 'Add a caption for every tutorial step.';
          }
          if (caption.length > 200) {
            return 'Keep each step caption under 200 characters.';
          }
        }
        return null;
      case PostFormat.poll:
        if (_isEditing) return null; // editing only allows closing early
        return composerPollError(
          question: _pollQuestionController.text,
          options: _pollOptionControllers.map((c) => c.text).toList(),
          imageCount: _media.length,
        );
    }
  }

  List<String> get _stepCaptionsInOrder =>
      _media.map((item) => _stepCaptionFor(item).text.trim()).toList();

  PollDraft? _buildPollDraft() {
    if (_format != PostFormat.poll || _isEditing) return null;
    final options = _pollOptionControllers
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    return PollDraft(
      question: _pollQuestionController.text.trim(),
      options: options,
      closesAt: _pollDuration.duration == null
          ? null
          : DateTime.now().add(_pollDuration.duration!),
    );
  }

  Future<void> _save() async {
    if (_isLoading) return;
    final formatError = _formatValidationError();
    final scheduleError = composerScheduleError(_scheduledFor);
    final error = formatError ?? scheduleError;
    if (error != null) {
      setState(() => _validationError = error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _validationError = null);

    setState(() => _isLoading = true);
    try {
      _requireEditorAccount();
      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      _requireEditorAccount();
      if (shop == null) throw Exception('No shop found');
      if (_submission != null && _submission!.shopId != shop.id) {
        throw StateError(
          'This pending post belongs to a different shop. Contact support before continuing.',
        );
      }
      if (ref.read(currentUserIdProvider) == null) {
        throw StateError('Please sign in again.');
      }
      if (!mounted) return;
      // Keep the exact caption, tags and attachments for an uncertain retry.
      // Validate local sizes before locking so an oversized file can be removed.
      for (final item in _media) {
        if (item.kind == _MediaKind.pendingImage &&
            await item.file!.length() > 5 * 1024 * 1024) {
          throw StateError(
            'Post photos must be 5 MB or smaller. Remove the large photo.',
          );
        }
      }
      _requireEditorAccount();
      setState(() => _submissionStarted = true);
      FocusManager.instance.primaryFocus?.unfocus();
      final hasPendingImages = _media.any(
        (m) => m.kind == _MediaKind.pendingImage,
      );
      final hasPendingVideos = _media.any(
        (m) => m.kind == _MediaKind.pendingVideo,
      );
      if (hasPendingImages) {
        setState(() => _isUploading = true);
        await _uploadPendingImages();
        if (!mounted) return;
        setState(() => _isUploading = false);
      }
      if (hasPendingVideos) {
        setState(() => _isUploading = true);
        await _uploadPendingVideos();
        if (!mounted) return;
        setState(() => _isUploading = false);
      }

      final mediaUrls = _media.map((m) => m.url!).toList();

      setState(() => _isPublishing = true);
      if (_isEditing) {
        _requireEditorAccount();
        await service.updateShopPost(widget.postId!, {
          'caption': _captionController.text.trim(),
          'media_urls': mediaUrls,
          if (creatorCommerceEnabled) 'product_ids': _productIds,
          'comments_enabled': _commentsEnabled,
          'hide_like_count': _hideLikeCount,
          'scheduled_for': _scheduledFor?.toUtc().toIso8601String(),
          'format': _format.name,
          'step_captions': _stepCaptionsInOrder,
        });
      } else {
        _requireEditorAccount();
        _submission ??= PostPublication(
          id: const Uuid().v4(),
          shopId: shop.id,
          caption: _captionController.text.trim(),
          mediaUrls: mediaUrls,
          productIds: creatorCommerceEnabled ? _productIds : null,
          commentsEnabled: _commentsEnabled,
          hideLikeCount: _hideLikeCount,
          scheduledFor: _scheduledFor,
          format: _format,
          stepCaptions: _stepCaptionsInOrder,
          poll: _buildPollDraft(),
        );
        final store = PendingPostStore(await SharedPreferences.getInstance());
        final user = _requireEditorAccount();
        await store.save(user, _submission!);
        _requireEditorAccount();
        await service.publishShopPost(_submission!);
        await store.clear(user, _submission!.id);
      }

      ref.invalidate(vendorPostsProvider);
      if (mounted) {
        _dirty = false;
        HapticFeedback.mediumImpact();
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        final scheduled = _scheduledFor;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Post updated'
                  : (scheduled != null
                        ? 'Scheduled for ${composerFormatScheduleLabel(scheduled)}'
                        : 'Posted'),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.baobab,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (_submission == null) setState(() => _submissionStarted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _submissionStarted
                  ? "Couldn't finish posting. Your post is saved — tap Post to try again."
                  : friendlyErrorMessage(e),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
          _isPublishing = false;
        });
      }
    }
  }

  Future<void> _closePollEarly() async {
    final poll = _existingPoll;
    if (poll == null || widget.postId == null || _closingPoll) return;
    setState(() => _closingPoll = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final closed = PostPoll(
        postId: widget.postId!,
        question: poll.question,
        options: poll.options,
        closesAt: DateTime.now(),
      );
      await service.savePostPoll(closed);
      if (mounted) {
        setState(() => _existingPoll = closed);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Poll closed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _closingPoll = false);
    }
  }

  void _openPreview() {
    final shopAsync = ref.read(vendorShopProvider);
    final shopName = shopAsync.value?.name ?? 'Your shop';
    final shopLogoUrl = shopAsync.value?.logoUrl;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ComposerPreviewSheet(
          shopName: shopName,
          shopLogoUrl: shopLogoUrl,
          media: _media
              .map(
                (item) => item.file != null
                    ? ComposerPreviewMedia.file(item.file!)
                    : ComposerPreviewMedia.url(item.url),
              )
              .toList(),
          caption: _captionController.text.trim(),
          format: _format,
          stepCaptions: _stepCaptionsInOrder,
          commentsEnabled: _commentsEnabled,
          hideLikeCount: _hideLikeCount,
          scheduledFor: _scheduledFor,
          poll: _format == PostFormat.poll
              ? ComposerPreviewPoll(
                  question: _isEditing
                      ? (_existingPoll?.question ?? '')
                      : _pollQuestionController.text.trim(),
                  options: _isEditing
                      ? (_existingPoll?.options ?? const [])
                      : _pollOptionControllers
                            .map((c) => c.text.trim())
                            .where((o) => o.isNotEmpty)
                            .toList(),
                )
              : null,
          onEdit: () => Navigator.of(context).pop(),
          onShare: () {
            Navigator.of(context).pop();
            _save();
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _isLoading) return true;
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
              Text(
                'Discard post?',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "If you leave now, your changes won't be saved.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textHint,
                ),
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
    if (_isLoading) return;
    if (await _confirmDiscard() && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_accountChanged) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account changed')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Close this editor and reopen it from your account. Your previous account’s post will not be submitted.',
            ),
          ),
        ),
      );
    }
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit post' : 'New post')),
        body: _initializationError == null
            ? const Center(child: CircularProgressIndicator())
            : ErrorRetryView(
                error: _initializationError,
                title: "Couldn't load this",
                onRetry: _isEditing ? _loadPost : _restoreSubmission,
              ),
      );
    }

    final totalImages = _totalImages;
    final canPublish = !_isLoading && _media.isNotEmpty;
    final shop = ref.watch(vendorShopProvider).value;
    final showAddPhoto =
        _format != PostFormat.video &&
        totalImages < _maxMediaForFormat(_format);
    final showAddVideo =
        _format == PostFormat.video &&
        creatorVideoPostsEnabled &&
        totalImages < _maxMediaForFormat(_format);
    final scheduleForEditableInEdit =
        !_isEditing ||
        (_scheduledFor != null && _scheduledFor!.isAfter(DateTime.now()));

    return PopScope(
      canPop: !_isLoading && !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isLoading) return;
        if (await _confirmDiscard() && mounted) this.context.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Close',
            onPressed: _isLoading ? null : _handleClose,
          ),
          title: Text(
            _isEditing ? 'Edit Post' : 'New Post',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              key: const Key('composer-open-preview'),
              tooltip: 'Preview',
              icon: const Icon(Icons.visibility_outlined, size: 22),
              onPressed: _media.isEmpty ? null : _openPreview,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: canPublish ? _save : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _submissionStarted
                            ? 'Retry'
                            : (_isEditing
                                  ? 'Save'
                                  : (_scheduledFor != null
                                        ? 'Schedule'
                                        : 'Share')),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isLoading,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_submissionStarted)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Your post is saved but not published yet. Tap Post to finish it before making changes.",
                      ),
                    ),
                  IgnorePointer(
                    ignoring: _submissionStarted,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Format ───────────────────────────────────
                        ComposerFormatPicker(
                          value: _format,
                          availableFormats: _availableFormats,
                          enabled: !_isEditing,
                          onChanged: (format) => setState(() {
                            _format = format;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 24),

                        // ── Photos section ──────────────────────────────
                        Text(
                          'Photos',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalImages/${_maxMediaForFormat(_format)} added · drag to reorder',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            buildDefaultDragHandles: false,
                            itemCount: _media.length + 1,
                            onReorderItem: (oldIndex, newIndex) {
                              if (oldIndex >= _media.length) return;
                              setState(() {
                                // newIndex is already adjusted for the
                                // removed item; keep it before the add tile.
                                final item = _media.removeAt(oldIndex);
                                _media.insert(
                                  newIndex.clamp(0, _media.length),
                                  item,
                                );
                                _dirty = true;
                              });
                            },
                            itemBuilder: (context, index) {
                              if (index == _media.length) {
                                return Row(
                                  key: const ValueKey('add-tiles'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showAddPhoto)
                                      GestureDetector(
                                        onTap: _showImageSourcePicker,
                                        child: Container(
                                          width: 110,
                                          height: 110,
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardBg,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.sand,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.baobab
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.add_a_photo_rounded,
                                                  color: AppTheme.baobab,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Add Photo',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.baobab,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (showAddVideo)
                                      GestureDetector(
                                        onTap: _pickVideo,
                                        child: Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            color: AppTheme.indigo.withValues(
                                              alpha: .08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: const _VideoTile(add: true),
                                        ),
                                      ),
                                  ],
                                );
                              }
                              final item = _media[index];
                              return _ImageTile(
                                key: ValueKey('media-${item.id}'),
                                index: index,
                                onRemove: () => setState(() {
                                  _stepCaptionControllers
                                      .remove(item.id)
                                      ?.dispose();
                                  _media.removeAt(index);
                                  _dirty = true;
                                }),
                                isPending: item.isPending,
                                child: item.isVideo
                                    ? _VideoTile(pending: item.isPending)
                                    : item.kind == _MediaKind.pendingImage
                                    ? Image.file(item.file!, fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: item.url!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.broken_image,
                                          color: AppTheme.textHint,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ),
                        if (_isUploading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.baobab,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Uploading photos...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.baobab,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_validationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _validationError!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // ── Tutorial step captions ─────────────────────
                        if (_format == PostFormat.tutorial &&
                            _media.isNotEmpty) ...[
                          ComposerStepCaptions(
                            thumbnails: _media
                                .map<Widget>(
                                  (item) => item.kind == _MediaKind.pendingImage
                                      ? Image.file(
                                          item.file!,
                                          fit: BoxFit.cover,
                                        )
                                      : item.isVideo
                                      ? const _VideoTile()
                                      : CachedNetworkImage(
                                          imageUrl: item.url ?? '',
                                          fit: BoxFit.cover,
                                        ),
                                )
                                .toList(),
                            controllers: _media
                                .map((item) => _stepCaptionFor(item))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Poll ────────────────────────────────────────
                        if (_format == PostFormat.poll) ...[
                          if (_isEditing)
                            _ExistingPollView(
                              poll: _existingPoll,
                              closing: _closingPoll,
                              onCloseEarly: _closePollEarly,
                            )
                          else
                            ComposerPollEditor(
                              questionController: _pollQuestionController,
                              optionControllers: _pollOptionControllers,
                              selectedDuration: _pollDuration,
                              onDurationChanged: (d) =>
                                  setState(() => _pollDuration = d),
                              onAddOption: () => setState(
                                () => _syncPollOptionCount(
                                  _pollOptionControllers.length + 1,
                                ),
                              ),
                              onRemoveOption: (index) => setState(() {
                                _pollOptionControllers
                                    .removeAt(index)
                                    .dispose();
                              }),
                            ),
                          const SizedBox(height: 24),
                        ],

                        if (creatorCommerceEnabled) ...[
                          PostProductPicker(
                            ids: _productIds,
                            onChanged: (ids) {
                              if (mounted) {
                                setState(() {
                                  _productIds = ids;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                        // ── Caption ───────────────────────────────────
                        Text(
                          'Caption',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Optional',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          readOnly: _submissionStarted,
                          controller: _captionController,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Share an update with your followers...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (shop != null)
                          ComposerAiCaptionButton(
                            shopId: shop.id,
                            captionController: _captionController,
                          ),
                        const SizedBox(height: 28),

                        // ── Conversation settings ──────────────────────
                        ComposerSettingsSection(
                          commentsEnabled: _commentsEnabled,
                          hideLikeCount: _hideLikeCount,
                          onCommentsChanged: (v) => setState(() {
                            _commentsEnabled = v;
                            _dirty = true;
                          }),
                          onHideLikeCountChanged: (v) => setState(() {
                            _hideLikeCount = v;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 24),

                        // ── Schedule ────────────────────────────────────
                        if (scheduleForEditableInEdit)
                          ComposerScheduleSection(
                            scheduledFor: _scheduledFor,
                            errorText: composerScheduleError(_scheduledFor),
                            onChanged: (value) => setState(() {
                              _scheduledFor = value;
                              _dirty = true;
                            }),
                          ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),

                  GradientButton(
                    label: _submissionStarted
                        ? 'Retry this post'
                        : (_isEditing
                              ? 'Update Post'
                              : (_scheduledFor != null
                                    ? 'Schedule Post'
                                    : 'Publish Post')),
                    isLoading: _isLoading,
                    onPressed: canPublish ? _save : null,
                  ),
                ],
              ),
            ),
            if (_isPublishing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'Posting…',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExistingPollView extends StatelessWidget {
  const _ExistingPollView({
    required this.poll,
    required this.closing,
    required this.onCloseEarly,
  });

  final PostPoll? poll;
  final bool closing;
  final VoidCallback onCloseEarly;

  @override
  Widget build(BuildContext context) {
    if (poll == null) return const SizedBox.shrink();
    final isClosed = poll!.isClosed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.sand.withValues(alpha: .6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                poll!.question,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final option in poll!.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(option, style: GoogleFonts.poppins(fontSize: 13)),
                ),
              const SizedBox(height: 8),
              Text(
                isClosed ? 'This poll is closed.' : 'This poll is still open.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isClosed ? AppTheme.textHint : AppTheme.baobab,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isClosed) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('composer-close-poll'),
                    onPressed: closing ? null : onCloseEarly,
                    child: Text(closing ? 'Closing…' : 'Close poll now'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final bool isPending;
  final int index;

  const _ImageTile({
    super.key,
    required this.child,
    required this.onRemove,
    required this.index,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Container(
        width: 110,
        height: 110,
        margin: const EdgeInsets.only(right: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.expand(child: child),
            ),
            if (isPending)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'New',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({this.pending = false, this.add = false});
  final bool pending;
  final bool add;
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.indigo,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            add ? Icons.video_call_outlined : Icons.play_circle_fill_rounded,
            color: add ? AppTheme.baobab : Colors.white,
            size: 32,
          ),
          const SizedBox(height: 5),
          Text(
            add ? 'Add video' : (pending ? 'Video ready' : 'Private video'),
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: add ? AppTheme.baobab : Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
