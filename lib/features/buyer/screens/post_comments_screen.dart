import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/compact_count.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/post_interaction.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../auth/providers/auth_providers.dart';
import '../../vendor/providers/vendor_providers.dart';
import '../providers/blocking_providers.dart';
import '../providers/post_social_providers.dart';
import '../providers/creator_safety_providers.dart';
import '../widgets/content_report_sheet.dart';
import '../../safety/community_guidelines_gate.dart';
import '../../safety/content_filter.dart';

/// Shows the comments for [postId] as a draggable sheet floating over the
/// feed, preserving the feed's scroll position underneath.
Future<void> showPostCommentsSheet(
  BuildContext context, {
  required String postId,
  required String shopId,
  bool commentsEnabled = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.scaffoldBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Comments',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PostCommentsScreen(
                  postId: postId,
                  shopId: shopId,
                  commentsEnabled: commentsEnabled,
                  embedded: true,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PostCommentsScreen extends ConsumerStatefulWidget {
  const PostCommentsScreen({
    super.key,
    required this.postId,
    required this.shopId,
    this.commentsEnabled = true,
    this.embedded = false,
    this.scrollController,
  });
  final String postId, shopId;

  /// Whether the maker still allows new comments on this post. When false,
  /// the composer is replaced by a friendly notice (the server also rejects
  /// inserts, but this avoids the round trip and the confusing failure).
  final bool commentsEnabled;

  /// True when rendered inside [showPostCommentsSheet] rather than as a
  /// pushed page: skips the Scaffold/AppBar chrome.
  final bool embedded;
  final ScrollController? scrollController;
  @override
  ConsumerState<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends ConsumerState<PostCommentsScreen> {
  final _text = TextEditingController();
  final _comments = <PostComment>[];
  final _countedRequestIds = <String>{};
  late final ScrollController _scroll;
  bool _ownsScrollController = false;
  bool _loading = true, _more = true, _sending = false;
  Object? _error;
  Object? _loadMoreError;
  String? _editingId, _requestId, _lastAttemptedText, _saveError;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _scroll = widget.scrollController ?? ScrollController();
    _ownsScrollController = widget.scrollController == null;
    _scroll.addListener(_onScroll);
    ref.listenManual(currentUserIdProvider, (old, next) {
      if (old != next && mounted) {
        _text.clear();
        _editingId = null;
        _requestId = null;
        _lastAttemptedText = null;
        _saveError = null;
        _sending = false;
        _load(reset: true);
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    if (_ownsScrollController) _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_loadMoreError == null &&
        _scroll.position.extentAfter < 400 &&
        !_loading &&
        _more &&
        _error == null) {
      _load();
    }
  }

  String _displayName() {
    try {
      final meta = ref
          .read(supabaseClientProvider)
          .auth
          .currentUser
          ?.userMetadata;
      final name = meta?['full_name'] ?? meta?['name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (_) {
      // Focused widget tests can render this screen without an app client.
    }
    return 'You';
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _comments.clear();
        _more = true;
      } else {
        _loadMoreError = null;
      }
    });
    try {
      final next = await ref
          .read(postSocialRepositoryProvider)
          .comments(
            widget.postId,
            before: reset || _comments.isEmpty ? null : _comments.last,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _comments.map((c) => c.id).toSet();
        _comments.addAll(next.where((c) => !ids.contains(c.id)));
        _more = next.length == 30;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          if (_comments.isEmpty) {
            _error = error;
          } else {
            _loadMoreError = error;
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final trimmed = _text.text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.runes.length > 1000) {
      setState(
        () => _saveError = 'Please shorten your comment to 1,000 characters.',
      );
      return;
    }
    final user = ref.read(currentUserIdProvider);
    if (user == null) return;
    if (containsBlockedTerms(trimmed)) {
      setState(() => _saveError = blockedTermsFriendlyMessage);
      return;
    }
    if (!await ensureCommunityGuidelinesAccepted(context, ref)) return;
    if (!mounted || _sending || ref.read(currentUserIdProvider) != user) return;
    final editing = _editingId;
    setState(() {
      _sending = true;
      _saveError = null;
    });
    if (editing != null) {
      try {
        await ref
            .read(postSocialRepositoryProvider)
            .editComment(editing, trimmed);
        if (!mounted || ref.read(currentUserIdProvider) != user) return;
        final idx = _comments.indexWhere((c) => c.id == editing);
        if (idx != -1) {
          setState(
            () => _comments[idx] = _comments[idx].copyWith(
              body: trimmed,
              edited: true,
            ),
          );
        }
        _text.clear();
        _editingId = null;
      } catch (error) {
        if (mounted && ref.read(currentUserIdProvider) == user) {
          setState(
            () => _saveError =
                ugcErrorMessage(error) ??
                "Couldn't save your edit. Tap save to retry.",
          );
        }
      } finally {
        if (mounted && ref.read(currentUserIdProvider) == user) {
          setState(() => _sending = false);
        }
      }
      return;
    }

    final reuseId = _requestId != null && _lastAttemptedText == trimmed;
    final requestId = reuseId ? _requestId! : const Uuid().v4();
    _requestId = requestId;
    _lastAttemptedText = trimmed;
    final existingIndex = _comments.indexWhere((c) => c.id == requestId);
    setState(() {
      if (existingIndex == -1) {
        _comments.insert(
          0,
          PostComment(
            id: requestId,
            userId: user,
            body: trimmed,
            author: _displayName(),
            createdAt: DateTime.now(),
            pending: true,
          ),
        );
      } else {
        _comments[existingIndex] = _comments[existingIndex].copyWith(
          pending: true,
          failed: false,
        );
      }
    });
    try {
      await ref
          .read(postSocialRepositoryProvider)
          .addComment(widget.postId, trimmed, requestId);
      if (!mounted || ref.read(currentUserIdProvider) != user) return;
      final idx = _comments.indexWhere((c) => c.id == requestId);
      if (idx != -1) {
        setState(
          () => _comments[idx] = _comments[idx].copyWith(
            pending: false,
            failed: false,
          ),
        );
      }
      if (_countedRequestIds.add(requestId)) {
        ref
            .read(postEngagementProvider(widget.postId).notifier)
            .bumpComments(1);
      }
      _text.clear();
      _requestId = null;
      _lastAttemptedText = null;
    } catch (error) {
      if (mounted && ref.read(currentUserIdProvider) == user) {
        final idx = _comments.indexWhere((c) => c.id == requestId);
        if (idx != -1) {
          setState(
            () => _comments[idx] = _comments[idx].copyWith(
              pending: false,
              failed: true,
            ),
          );
        }
        setState(
          () => _saveError = isPermissionRejection(error)
              ? blockedCommentMessage
              : ugcErrorMessage(error) ?? "Couldn't post. Tap to retry.",
        );
      }
    } finally {
      if (mounted && ref.read(currentUserIdProvider) == user) {
        setState(() => _sending = false);
      }
    }
  }

  void _discardDraft() {
    setState(() {
      _text.clear();
      _requestId = null;
      _lastAttemptedText = null;
      _saveError = null;
      _editingId = null;
    });
  }

  void _retryFailed(PostComment comment) {
    setState(() {
      _editingId = null;
      _text.text = comment.body;
      _requestId = comment.id;
      _lastAttemptedText = comment.body;
      _saveError = null;
    });
    _send();
  }

  Future<void> _delete(PostComment comment) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes the comment from the conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final user = ref.read(currentUserIdProvider);
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;
    setState(() => _comments.removeAt(index));
    ref.read(postEngagementProvider(widget.postId).notifier).bumpComments(-1);
    try {
      await ref.read(postSocialRepositoryProvider).deleteComment(comment.id);
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == user) {
        setState(
          () => _comments.insert(index.clamp(0, _comments.length), comment),
        );
        ref
            .read(postEngagementProvider(widget.postId).notifier)
            .bumpComments(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete this comment.")),
        );
      }
    }
  }

  Widget _commentRow(BuildContext context, PostComment comment) {
    final user = ref.watch(currentUserIdProvider);
    final ownShop = user == null ? null : ref.watch(vendorShopProvider).value;
    final canDelete = user == comment.userId || ownShop?.id == widget.shopId;
    final canEdit = user == comment.userId;
    final isOthers = user != null && user != comment.userId;
    final canReport = creatorSafetyEnabled && isOthers;
    final canBlock = isOthers;
    return InkWell(
      onTap: comment.failed ? () => _retryFailed(comment) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.sand,
              child: Text(
                comment.author.isEmpty
                    ? 'M'
                    : comment.author.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: comment.pending ? 0.6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.author,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          comment.failed
                              ? "Couldn't post · tap to retry"
                              : comment.pending
                              ? 'Sending…'
                              : comment.edited
                              ? '${formatRelativeTime(comment.createdAt)} · edited'
                              : formatRelativeTime(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: comment.failed
                                ? AppTheme.terracotta
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.body),
                  ],
                ),
              ),
            ),
            if (canDelete || canEdit || canReport || canBlock)
              PopupMenuButton<String>(
                tooltip: 'Comment options',
                enabled: !_sending,
                onSelected: (action) {
                  if (action == 'delete') {
                    _delete(comment);
                  } else if (action == 'block') {
                    confirmBlockUser(
                      ref,
                      context,
                      userId: comment.userId,
                      name: comment.author,
                    );
                  } else if (action == 'report') {
                    showContentReportSheet(
                      context,
                      targetType: ContentReportTargetType.comment,
                      targetId: comment.id,
                    );
                  } else {
                    setState(() {
                      _editingId = comment.id;
                      _text.text = comment.body;
                      _saveError = null;
                    });
                  }
                },
                itemBuilder: (_) => [
                  if (canEdit)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (canReport)
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Report comment'),
                    ),
                  if (canBlock)
                    PopupMenuItem(
                      value: 'block',
                      child: Text('Block ${comment.author}'),
                    ),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserIdProvider);
    final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
    final body = SafeArea(
      top: !widget.embedded,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: _error != null && _comments.isEmpty
                  ? ErrorRetryView(
                      error: _error,
                      title: "Comments couldn't load",
                      onRetry: () => _load(reset: true),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (!_loading &&
                              !_comments.any(
                                (c) => !blocked.contains(c.userId),
                              ))
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Text(
                                'Start the conversation. Ask about the craft or share what you love.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ..._comments
                              .where((c) => !blocked.contains(c.userId))
                              .map((comment) => _commentRow(context, comment)),
                          if (_loadMoreError != null)
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _load(),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text(
                                  'Couldn\'t load more · retry',
                                ),
                              ),
                            )
                          else if (_loading && _comments.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else if (_loading && _comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
            ),
            if (!widget.commentsEnabled)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Comments are turned off for this post.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else if (user == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => showSignInPromptSheet(
                    context,
                    title: 'Join the conversation',
                    message:
                        'Sign in to comment and support your favourite makers.',
                  ),
                  child: const Text('Sign in to comment'),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .65,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        if (_editingId != null)
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Editing your comment'),
                              ),
                              TextButton(
                                onPressed: _sending ? null : _discardDraft,
                                child: const Text('Cancel edit'),
                              ),
                            ],
                          ),
                        TextField(
                          controller: _text,
                          readOnly: _sending,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Leave a thoughtful comment…',
                            suffixIcon: IconButton(
                              tooltip: _editingId == null
                                  ? 'Send comment'
                                  : 'Save comment',
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_upward_rounded),
                            ),
                          ),
                        ),
                        if (_saveError != null && !_sending)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _saveError!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: _discardDraft,
                                child: const Text('Discard'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(title: const Text('Conversation')),
      body: body,
    );
  }
}
