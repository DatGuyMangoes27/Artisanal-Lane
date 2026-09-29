import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/creator_parity.dart';
import '../../../../models/shop_story.dart';
import '../../../../widgets/sign_in_prompt_sheet.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/story_providers.dart';

/// The viewer's reaction control shown beside the "Send message" pill: a
/// heart button that expands into the five reaction emoji, Instagram-style.
/// Tapping an emoji sends/changes the reaction instantly; tapping the
/// selected one again removes it. Guests are sent to the sign-in sheet.
class StoryReactionBar extends ConsumerStatefulWidget {
  const StoryReactionBar({
    super.key,
    required this.story,
    required this.onExpandChanged,
  });

  final ShopStory story;

  /// Called with true while the emoji row is open so the caller can pause
  /// the story, and false once it closes.
  final ValueChanged<bool> onExpandChanged;

  @override
  ConsumerState<StoryReactionBar> createState() => _StoryReactionBarState();
}

class _StoryReactionBarState extends ConsumerState<StoryReactionBar> {
  bool _expanded = false;
  final List<_Float> _floats = [];
  int _floatId = 0;

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    widget.onExpandChanged(value);
  }

  @override
  void didUpdateWidget(covariant StoryReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.id != widget.story.id && _expanded) {
      // Story advanced while the row was open: close it without notifying
      // the (now stale) caller about a story that already moved on.
      _expanded = false;
      _floats.clear();
    }
  }

  Future<void> _handleTap(String emoji) async {
    if (ref.read(currentUserIdProvider) == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to react',
        message: 'Create an account or sign in to react to this story.',
      );
      return;
    }
    final storyId = widget.story.id;
    final current = ref.read(myStoryReactionProvider(storyId)).value;
    final next = current == emoji ? null : emoji;
    HapticFeedback.lightImpact();
    if (next != null) _spawnFloat(emoji);
    final ok = await ref
        .read(myStoryReactionProvider(storyId).notifier)
        .setReaction(next);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send your reaction. Please try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _setExpanded(false);
  }

  void _spawnFloat(String emoji) {
    final id = _floatId++;
    setState(() => _floats.add(_Float(id, emoji)));
  }

  void _removeFloat(int id) {
    if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.story.isLiveAt(DateTime.now())) return const SizedBox.shrink();
    final reaction = ref.watch(myStoryReactionProvider(widget.story.id)).value;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomLeft,
      children: [
        for (final float in _floats)
          _FloatingEmoji(
            key: ValueKey(float.id),
            emoji: float.emoji,
            onDone: () => _removeFloat(float.id),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          child: _expanded ? _emojiRow(reaction) : _heartButton(reaction),
        ),
      ],
    );
  }

  Widget _heartButton(String? reaction) => Semantics(
    button: true,
    label: reaction == null ? 'React to this story' : 'Change your reaction',
    child: InkWell(
      key: const ValueKey('story-reaction-heart'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => _setExpanded(true),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: reaction == null
            ? const Icon(Icons.favorite_border, color: Colors.white, size: 22)
            : Text(reaction, style: const TextStyle(fontSize: 20)),
      ),
    ),
  );

  Widget _emojiRow(String? reaction) => Container(
    key: const ValueKey('story-reaction-row'),
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final emoji in storyReactionEmojis)
          Semantics(
            button: true,
            selected: reaction == emoji,
            label: reaction == emoji
                ? 'Remove $emoji reaction'
                : 'React $emoji',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _handleTap(emoji),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: reaction == emoji ? 1.25 : 1.0,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          label: 'Close reactions',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _setExpanded(false),
            child: const SizedBox(
              width: 32,
              height: 44,
              child: Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Float {
  _Float(this.id, this.emoji);
  final int id;
  final String emoji;
}

/// A brief floating-and-fading emoji, self-removing when its animation ends.
class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({super.key, required this.emoji, required this.onDone});
  final String emoji;
  final VoidCallback onDone;

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji> {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOut,
    onEnd: widget.onDone,
    builder: (context, t, child) => Positioned(
      bottom: 44 + t * 70,
      left: 4,
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - t,
          child: Transform.scale(
            scale: 1 + t * 0.6,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    ),
  );
}
