import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';

enum ContentReportTargetType { post, comment, story }

const contentReportReasons = <String, String>{
  'spam': 'Spam or scam',
  'harassment': 'Harassment or bullying',
  'hate_or_abuse': 'Hate or abuse',
  'sexual_content': 'Sexual content',
  'intellectual_property': 'Intellectual property',
  'other': 'Something else',
};

final contentReportRepositoryProvider = Provider<ContentReportRepository>(
  (ref) => ContentReportRepository(ref.watch(supabaseClientProvider)),
);
final contentReportQueueProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      if (ref.watch(currentUserIdProvider) == null) return [];
      return ref.watch(contentReportRepositoryProvider).adminQueue();
    });

class ContentReportRepository {
  ContentReportRepository(this.client);
  final SupabaseClient client;

  Future<void> submit({
    required String expectedUserId,
    required ContentReportTargetType targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    if (!contentReportReasons.containsKey(reason)) {
      throw ArgumentError('Choose a report reason.');
    }
    if (targetId.trim().isEmpty || details.trim().runes.length > 1000) {
      throw ArgumentError('Report details must be 1,000 characters or fewer.');
    }
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
          .eq('target_type', targetType.name)
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
        'target_type': targetType.name,
        'target_id': targetId,
        'reason': reason,
        'details': details.trim(),
      });
    } catch (_) {
      // A committed insert may lose its response. A receipt proves success;
      // otherwise preserve the original error for a genuine retry.
      if (await receiptExists()) return;
      rethrow;
    }
    if (client.auth.currentUser?.id != expectedUserId) {
      throw StateError('Your account changed. Please start a new report.');
    }
  }

  Future<List<Map<String, dynamic>>> adminQueue() async {
    return (await client
            .from('creator_content_reports')
            .select()
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(100))
        .cast<Map<String, dynamic>>();
  }

  Future<void> resolve(
    String id, {
    required bool dismissed,
    String notes = '',
  }) async {
    if (notes.trim().runes.length > 1000) {
      throw ArgumentError(
        'Resolution notes must be 1,000 characters or fewer.',
      );
    }
    await client
        .from('creator_content_reports')
        .update({
          'status': dismissed ? 'dismissed' : 'resolved',
          'resolution_notes': notes.trim(),
        })
        .eq('id', id)
        .select('id')
        .single();
  }
}
