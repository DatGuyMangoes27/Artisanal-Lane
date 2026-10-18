import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/creator_safety_providers.dart';

/// Report target types accepted by `creator_content_reports` that have no
/// [ContentReportTargetType] value. Submitted as raw `target_type` strings.
abstract final class ExtraReportTargets {
  static const shop = 'shop';
  static const productReview = 'product_review';
  static const shopReview = 'shop_review';
  static const message = 'message';
  static const all = {shop, productReview, shopReview, message};
}

/// Opens the report sheet for a post, comment or story (via [targetType]),
/// for a maker's shop profile (via [shopId]), or for a review or chat message
/// (via [rawTargetType], one of [ExtraReportTargets]). The backend accepts
/// target types that have no matching [ContentReportTargetType] value, so
/// those reports are submitted directly rather than through
/// [ContentReportRepository.submit].
Future<void> showContentReportSheet(
  BuildContext context, {
  ContentReportTargetType? targetType,
  String? shopId,
  String? rawTargetType,
  required String targetId,
}) {
  assert(
    targetType != null || shopId != null || rawTargetType != null,
    'Provide targetType, shopId or rawTargetType.',
  );
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => ContentReportSheet(
      targetType: targetType,
      shopId: shopId,
      rawTargetType: rawTargetType,
      targetId: targetId,
    ),
  );
}

class ContentReportSheet extends ConsumerStatefulWidget {
  const ContentReportSheet({
    super.key,
    this.targetType,
    this.shopId,
    this.rawTargetType,
    required this.targetId,
  }) : assert(
         targetType != null || shopId != null || rawTargetType != null,
         'Provide targetType, shopId or rawTargetType.',
       );

  /// The post/comment/story being reported. Null for other target types.
  final ContentReportTargetType? targetType;

  /// The shop id being reported. Non-null makes this a "Report this maker"
  /// sheet, submitted with target_type 'shop'.
  final String? shopId;

  /// A raw target type from [ExtraReportTargets] (reviews, chat messages).
  final String? rawTargetType;
  final String targetId;

  bool get isShopReport => shopId != null;

  /// The `target_type` sent for reports that bypass the repository.
  String get rawType => isShopReport ? ExtraReportTargets.shop : rawTargetType!;

  /// The id sent for reports that bypass the repository.
  String get rawId => shopId ?? targetId;

  String get title {
    if (isShopReport) return 'Report this maker';
    switch (rawTargetType) {
      case ExtraReportTargets.productReview:
      case ExtraReportTargets.shopReview:
        return 'Report review';
      case ExtraReportTargets.message:
        return 'Report message';
    }
    return 'Report content';
  }

  @override
  ConsumerState<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends ConsumerState<ContentReportSheet> {
  final _details = TextEditingController();
  late final String? _openingUserId;
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openingUserId = ref.read(currentUserIdProvider);
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_reason == null) {
      setState(() => _error = 'Choose a reason so our team can review this.');
      return;
    }
    final userId = _openingUserId;
    if (userId == null || ref.read(currentUserIdProvider) != userId) {
      setState(
        () =>
            _error = 'Your account changed. Close this report and start again.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (widget.targetType == null) {
        await _submitRawReport(
          expectedUserId: userId,
          targetType: widget.rawType,
          targetId: widget.rawId,
          reason: _reason!,
          details: _details.text,
        );
      } else {
        await ref
            .read(contentReportRepositoryProvider)
            .submit(
              expectedUserId: userId,
              targetType: widget.targetType!,
              targetId: widget.targetId,
              reason: _reason!,
              details: _details.text,
            );
      }
      if (!mounted || ref.read(currentUserIdProvider) != userId) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report sent for review.')));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We could not send this report. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Mirrors [ContentReportRepository.submit] for shop, review and message
  /// reports. The repository's own submit() only accepts
  /// [ContentReportTargetType] (post/comment/story), so this reuses its
  /// public Supabase client to insert the same shape of row directly.
  Future<void> _submitRawReport({
    required String expectedUserId,
    required String targetType,
    required String targetId,
    required String reason,
    required String details,
  }) async {
    if (!contentReportReasons.containsKey(reason)) {
      throw ArgumentError('Choose a report reason.');
    }
    if (!ExtraReportTargets.all.contains(targetType)) {
      throw ArgumentError('Unknown report target.');
    }
    if (targetId.trim().isEmpty || details.trim().runes.length > 1000) {
      throw ArgumentError('Report details must be 1,000 characters or fewer.');
    }
    final client = ref.read(contentReportRepositoryProvider).client;
    if (client.auth.currentUser?.id != expectedUserId) {
      throw StateError('Please sign in to report content.');
    }
    Future<bool> receiptExists() async {
      if (client.auth.currentUser?.id != expectedUserId) {
        throw StateError('Your account changed. Please start a new report.');
      }
      final receipt = await client
          .from('creator_content_reports')
          .select('id')
          .eq('reporter_id', expectedUserId)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .maybeSingle();
      if (client.auth.currentUser?.id != expectedUserId) {
        throw StateError('Your account changed. Please start a new report.');
      }
      return receipt != null;
    }

    if (await receiptExists()) return;
    try {
      await client.from('creator_content_reports').insert({
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'details': details.trim(),
      });
    } catch (_) {
      if (await receiptExists()) return;
      rethrow;
    }
    if (client.auth.currentUser?.id != expectedUserId) {
      throw StateError('Your account changed. Please start a new report.');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reports are private and reviewed by the Artisan Lane team within 24 hours. Sending one does not remove content automatically.',
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (value) {
              if (!_sending) setState(() => _reason = value);
            },
            child: Column(
              children: contentReportReasons.entries
                  .map(
                    (entry) => RadioListTile<String>(
                      value: entry.key,
                      enabled: !_sending,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextField(
            controller: _details,
            enabled: !_sending,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Extra detail (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Sending…' : 'Send report'),
            ),
          ),
        ],
      ),
    ),
  );
}
