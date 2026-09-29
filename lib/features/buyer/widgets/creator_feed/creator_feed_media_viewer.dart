import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../vendor/services/creator_post_media.dart';

/// A conservative extension check for storage URLs used by creator posts.
bool isCreatorFeedVideoUrl(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null || uri.path.isEmpty) return false;
  return RegExp(r'\.(mp4|mov|webm)$', caseSensitive: false).hasMatch(uri.path);
}

/// Creator videos are loaded inside the app, so only secure remote URLs qualify.
bool isCreatorFeedHttpsUrl(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}

/// Full-screen gallery over every media item on a post. Opens at
/// [initialIndex] and lets the viewer swipe to the rest; private video
/// markers are signed lazily, only as their page becomes current.
class CreatorFeedMediaViewer extends StatefulWidget {
  const CreatorFeedMediaViewer({
    super.key,
    required this.mediaUrls,
    this.initialIndex = 0,
  });

  /// Raw media entries: HTTPS urls, or `artisan-post://` markers for
  /// private videos that still need a signed URL.
  final List<String> mediaUrls;
  final int initialIndex;

  @override
  State<CreatorFeedMediaViewer> createState() => _CreatorFeedMediaViewerState();
}

class _CreatorFeedMediaViewerState extends State<CreatorFeedMediaViewer>
    with WidgetsBindingObserver {
  late final PageController _page;
  late int _index;
  StreamSubscription<AuthState>? _authSubscription;
  double _dragOffset = 0;
  bool _dismissing = false;
  bool _pagingEnabled = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.mediaUrls.length - 1);
    _page = PageController(initialPage: _index);
    WidgetsBinding.instance.addObserver(this);
    try {
      final initialUserId = Supabase.instance.client.auth.currentUser?.id;
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) {
            if (Supabase.instance.client.auth.currentUser?.id !=
                initialUserId) {
              if (mounted) Navigator.of(context).maybePop();
            }
          });
    } catch (_) {
      // Focused widget tests can render the viewer without an app client.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handled per-page by _MediaPage's own video controller.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset.abs() > 120 || velocity.abs() > 800) {
      setState(() => _dismissing = true);
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(
        alpha: _dismissing ? 0 : 1 - progress * .6,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PageView.builder(
                  controller: _page,
                  physics: _pagingEnabled
                      ? const PageScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: widget.mediaUrls.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _MediaPage(
                    raw: widget.mediaUrls[i],
                    isActive: i == _index,
                    onScaleChanged: (zoomed) =>
                        setState(() => _pagingEnabled = !zoomed),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.filledTonal(
                key: const Key('close-creator-feed-media'),
                tooltip: 'Close media',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .6),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (widget.mediaUrls.length > 1)
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.mediaUrls.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _index ? 0.95 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
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

class _MediaPage extends StatefulWidget {
  const _MediaPage({
    required this.raw,
    required this.isActive,
    required this.onScaleChanged,
  });
  final String raw;
  final bool isActive;
  final ValueChanged<bool> onScaleChanged;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _error;
  String? _resolvedUrl;
  var _initializing = false;
  final _zoom = TransformationController();

  bool get _isPrivate => isCreatorPostMediaMarker(widget.raw);
  bool get _isVideo => _isPrivate || isCreatorFeedVideoUrl(widget.raw);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zoom.addListener(_onZoomChanged);
    _resolvedUrl = _isPrivate ? null : widget.raw;
    if (widget.isActive) _activate();
  }

  @override
  void didUpdateWidget(covariant _MediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activate();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause().catchError((error) {
        if (mounted) setState(() => _error = error);
      });
    }
  }

  void _onZoomChanged() {
    widget.onScaleChanged(_zoom.value.getMaxScaleOnAxis() > 1.01);
  }

  Future<void> _activate() async {
    if (!_isVideo) return;
    if (_isPrivate && _resolvedUrl == null) {
      await _resolvePrivateUrl();
    }
    await _loadVideo();
  }

  Future<void> _resolvePrivateUrl() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final url = await CreatorPostMediaRepository(
        Supabase.instance.client,
      ).signedUrlFor(widget.raw);
      if (!mounted) return;
      if (url == null) throw StateError('Media unavailable');
      setState(() => _resolvedUrl = url);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _loadVideo() async {
    final url = _resolvedUrl;
    if (url == null || !isCreatorFeedHttpsUrl(url) || _initializing) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || !widget.isActive) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerChanged);
      await controller.play();
      setState(() => _controller = controller);
    } catch (error) {
      await controller?.dispose();
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.hasError) {
      setState(
        () => _error = controller.value.errorDescription ?? 'Playback failed',
      );
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: _isVideo ? _videoBody() : _imageBody());

  Widget _imageBody() {
    if (!isCreatorFeedHttpsUrl(widget.raw)) {
      return const _MediaError(message: 'This photo needs a secure link.');
    }
    return InteractiveViewer(
      transformationController: _zoom,
      minScale: 1,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: widget.raw,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Container(color: Colors.black),
        errorWidget: (_, __, ___) =>
            const _MediaError(message: 'This photo could not be loaded.'),
      ),
    );
  }

  Widget _videoBody() {
    if (_isPrivate && _resolvedUrl == null) {
      if (_error != null) {
        return _MediaError(onRetry: _resolvePrivateUrl);
      }
      return const CircularProgressIndicator(color: AppTheme.terracotta);
    }
    if (!isCreatorFeedHttpsUrl(_resolvedUrl)) {
      return const _MediaError(message: 'This video needs a secure link.');
    }
    if (_initializing) {
      return const CircularProgressIndicator(color: AppTheme.terracotta);
    }
    if (_error != null || _controller == null) {
      return _MediaError(onRetry: _loadVideo);
    }
    final controller = _controller!;
    return GestureDetector(
      key: const Key('creator-feed-video-player'),
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          if (controller.value.isPlaying) {
            await controller.pause();
          } else {
            await controller.play();
          }
        } catch (error) {
          if (mounted) setState(() => _error = error);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          if (!controller.value.isPlaying)
            const Icon(
              Icons.play_circle_fill_rounded,
              size: 66,
              color: Colors.white,
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppTheme.terracotta,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({
    this.message = 'This video could not be loaded.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.white70,
          size: 42,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('retry-creator-feed-video'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ],
    ),
  );
}
