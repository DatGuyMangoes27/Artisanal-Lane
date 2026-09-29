import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/creator_safety_providers.dart';

/// Opens the report sheet for a post, comment or story (via [targetType]),
/// or for a maker's shop profile (via [shopId]) — the backend accepts a
/// 'shop' target_type that has no matching [ContentReportTargetType] value,
/// so shop reports are submitted directly rather than through
/// [ContentReportRepository.submit].
Future<void> showContentReportSheet(
  BuildContext context, {
  ContentReportTargetType? targetType,
  String? shopId,
  required String targetId,
}) {
  assert(
    targetType != null || shopId != null,
    'Provide either targetType or shopId.',
  );
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => ContentReportSheet(
      targetType: targetType,
      shopId: shopId,
      targetId: targetId,
    ),
  );
}

class ContentReportSheet extends ConsumerStatefulWidget {
  const ContentReportSheet({
    super.key,
    this.targetType,
    this.shopId,
    required this.targetId,
  }) : assert(
         targetType != null || shopId != null,
         'Provide either targetType or shopId.',
       );

  /// The post/comment/story being reported. Null for a shop report.
  final ContentReportTargetType? targetType;

  /// The shop id being reported. Non-null makes this a "Report this maker"
  /// sheet, submitted with target_type 'shop'.
  final String? shopId;
  final String targetId;

  bool get isShopReport => shopId != null;

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
      if (widget.isShopReport) {
        await _submitShopReport(
          expectedUserId: userId,
          shopId: widget.shopId!,
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

  /// Mirrors [ContentReportRepository.submit] for a shop-profile report.
  /// The repository's own submit() only accepts [ContentReportTargetType]
  /// (post/comment/story), which has no 'shop' value, so this reuses its
  /// public Supabase client to insert the same shape of row directly.
  Future<void> _submitShopReport({
    required String expectedUserId,
    required String shopId,
    required String reason,
    required String details,
  }) async {
    if (!contentReportReasons.containsKey(reason)) {
      throw ArgumentError('Choose a report reason.');
    }
    if (shopId.trim().isEmpty || details.trim().runes.length > 1000) {
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
          .eq('target_type', 'shop')
          .eq('target_id', shopId)
          .maybeSingle();
      if (client.auth.currentUser?.id != expectedUserId) {
        throw StateError('Your account changed. Please start a new report.');
      }
      return receipt != null;
    }

    if (await receiptExists()) return;
    try {
      await client.from('creator_content_reports').insert({
        'target_type': 'shop',
        'target_id': shopId,
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
            widget.isShopReport ? 'Report this maker' : 'Report content',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reports are private and reviewed by Artisan Lane. Sending one does not remove content automatically.',
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
