import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Private downloaded video is scoped to this widget's temporary directory.
class StoryMedia extends StatefulWidget {
  const StoryMedia({
    super.key,
    this.bytes,
    this.file,
    required this.video,
    required this.onReady,
    this.paused = false,
  });
  final Uint8List? bytes;
  final File? file;
  final bool video, paused;
  final ValueChanged<Duration> onReady;
  @override
  State<StoryMedia> createState() => _StoryMediaState();
}

class _StoryMediaState extends State<StoryMedia> {
  VideoPlayerController? _controller;
  Directory? _temp;
  bool _failed = false, _ready = false;
  @override
  void initState() {
    super.initState();
    if (widget.video) _loadVideo();
  }

  Future<void> _loadVideo() async {
    VideoPlayerController? controller;
    try {
      File? file = widget.file;
      if (file == null) {
        final root = await getTemporaryDirectory();
        _temp = await Directory('${root.path}/story-').createTemp();
        file = await File(
          '${_temp!.path}/clip.mp4',
        ).writeAsBytes(widget.bytes!);
      }
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        await _removeTemp();
        return;
      }
      _controller = controller;
      setState(() => _ready = true);
      if (!widget.paused) await controller.play();
      if (!mounted) return;
      widget.onReady(controller.value.duration);
    } catch (_) {
      await controller?.dispose();
      if (mounted) setState(() => _failed = true);
      await _removeTemp();
    }
  }

  Future<void> _removeTemp() async {
    final temp = _temp;
    _temp = null;
    if (temp != null) {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant StoryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      widget.paused ? _controller?.pause() : _controller?.play();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller == null) {
      _removeTemp();
    } else {
      controller.dispose().whenComplete(_removeTemp);
    }
    super.dispose();
  }

  Widget _error() => const Center(
    child: Text(
      'This media could not be opened.',
      style: TextStyle(color: Colors.white),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (_failed) return _error();
    if (widget.video) {
      if (!_ready) return const Center(child: CircularProgressIndicator());
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    Widget frame(BuildContext context, Widget child, int? frame, bool sync) {
      if (frame != null && !_ready) {
        _ready = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onReady(const Duration(seconds: 6));
        });
      }
      return child;
    }

    return Center(
      child: widget.file != null
          ? Image.file(
              widget.file!,
              fit: BoxFit.contain,
              frameBuilder: frame,
              errorBuilder: (_, _, _) => _error(),
            )
          : Image.memory(
              widget.bytes!,
              fit: BoxFit.contain,
              frameBuilder: frame,
              errorBuilder: (_, _, _) => _error(),
            ),
    );
  }
}
