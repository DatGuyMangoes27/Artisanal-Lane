import '../../../models/shop_post.dart';

/// Poll attached to a new post; inserted after the post itself is confirmed.
class PollDraft {
  PollDraft({
    required this.question,
    required List<String> options,
    this.closesAt,
  }) : options = List.unmodifiable(options);

  final String question;
  final List<String> options;
  final DateTime? closesAt;

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'closes_at': closesAt?.toUtc().toIso8601String(),
  };

  static PollDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    return PollDraft(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List? ?? []).cast<String>(),
      closesAt: json['closes_at'] is String
          ? DateTime.tryParse(json['closes_at'] as String)
          : null,
    );
  }
}

/// An immutable submission identity survives uncertain responses in the editor.
/// Retrying must never create a second post or overwrite an existing one.
class PostPublication {
  PostPublication({
    required this.id,
    required this.shopId,
    required this.caption,
    required List<String> mediaUrls,
    List<String>? productIds,
    this.commentsEnabled = true,
    this.hideLikeCount = false,
    this.scheduledFor,
    this.format = PostFormat.photo,
    List<String> stepCaptions = const [],
    this.poll,
  }) : mediaUrls = List.unmodifiable(mediaUrls),
       productIds = productIds == null ? null : List.unmodifiable(productIds),
       stepCaptions = List.unmodifiable(stepCaptions);

  final String id;
  final String shopId;
  final String caption;
  final List<String> mediaUrls;
  final List<String>? productIds;
  final bool commentsEnabled;
  final bool hideLikeCount;
  final DateTime? scheduledFor;
  final PostFormat format;
  final List<String> stepCaptions;
  final PollDraft? poll;

  /// The shop_posts row to insert.
  Map<String, dynamic> get values => {
    'id': id,
    'shop_id': shopId,
    'caption': caption,
    'media_urls': mediaUrls,
    'is_published': true,
    if (productIds != null) 'product_ids': productIds,
    'comments_enabled': commentsEnabled,
    'hide_like_count': hideLikeCount,
    'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
    'format': format.name,
    'step_captions': stepCaptions,
  };

  /// Everything needed to resume this exact submission after a restart.
  Map<String, dynamic> get stored => {...values, 'poll': poll?.toJson()};

  static PostPublication fromStored(Map<String, dynamic> values) =>
      PostPublication(
        id: values['id'] as String,
        shopId: values['shop_id'] as String,
        caption: values['caption'] as String,
        mediaUrls: (values['media_urls'] as List).cast<String>(),
        productIds: (values['product_ids'] as List?)?.cast<String>(),
        commentsEnabled: values['comments_enabled'] as bool? ?? true,
        hideLikeCount: values['hide_like_count'] as bool? ?? false,
        scheduledFor: values['scheduled_for'] is String
            ? DateTime.tryParse(values['scheduled_for'] as String)
            : null,
        format: parsePostFormat(values['format']),
        stepCaptions:
            (values['step_captions'] as List?)?.cast<String>() ?? const [],
        poll: PollDraft.fromJson(values['poll']),
      );

  Future<ShopPost> publish({
    required Future<ShopPost?> Function() find,
    required Future<void> Function(Map<String, dynamic>) insert,
    Future<void> Function(PollDraft poll)? attachPoll,
  }) async {
    var saved = await find();
    if (saved == null) {
      await insert(values);
      saved = await find();
    }
    if (saved == null) {
      throw StateError('Publication is not confirmed. Retry this post.');
    }
    if (saved.id != id ||
        saved.shopId != shopId ||
        saved.caption != caption ||
        !_same(saved.mediaUrls, mediaUrls) ||
        (productIds != null && !_same(saved.productIds, productIds!))) {
      throw StateError(
        'This submission has changed. Reopen the saved post before editing.',
      );
    }
    // Idempotent: the poll insert ignores an existing poll for this post.
    if (poll != null && attachPoll != null) await attachPoll(poll!);
    return saved;
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}
