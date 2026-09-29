import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/creator_safety_providers.dart';

/// Standalone admin surface. Routing is intentionally left to the app shell.
class ModerationReportsScreen extends ConsumerWidget {
  const ModerationReportsScreen({super.key});

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> report,
  ) async {
    final notes = TextEditingController();
    final reviewerId = ref.read(currentUserIdProvider);
    if (reviewerId == null) {
      notes.dispose();
      return;
    }
    try {
      final outcome = await showDialog<bool?>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close report'),
          content: TextField(
            controller: notes,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Review note (optional)',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dismiss report'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Mark resolved'),
            ),
          ],
        ),
      );
      if (outcome == null || !context.mounted) return;
      if (ref.read(currentUserIdProvider) != reviewerId) return;
      await ref
          .read(contentReportRepositoryProvider)
          .resolve(
            report['id'] as String,
            dismissed: outcome,
            notes: notes.text,
          );
      if (context.mounted && ref.read(currentUserIdProvider) == reviewerId) {
        ref.invalidate(contentReportQueueProvider);
      }
    } catch (_) {
      if (context.mounted && ref.read(currentUserIdProvider) == reviewerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this report.')),
        );
      }
    } finally {
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Admin access is required.')),
      );
    }
    final queue = ref.watch(contentReportQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Content reports')),
      body: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(contentReportQueueProvider),
            child: const Text('Retry loading reports'),
          ),
        ),
        data: (reports) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(contentReportQueueProvider),
          child: reports.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('No open reports.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final report = reports[index];
                    final reason =
                        contentReportReasons[report['reason'] as String? ??
                            'other'] ??
                        'Something else';
                    return ListTile(
                      title: Text(reason),
                      subtitle: Text(
                        '${report['target_type']} · ${report['target_id']}\n'
                        'Reported content: ${report['target_text_snapshot']}\n'
                        'Owner: ${report['target_owner_id'] ?? 'Unavailable'} · Shop: ${report['target_shop_id'] ?? 'Unavailable'}\n'
                        '${(report['details'] as String?)?.isEmpty ?? true ? 'No extra detail.' : report['details']}',
                      ),
                      isThreeLine: false,
                      trailing: TextButton(
                        onPressed: () => _review(context, ref, report),
                        child: const Text('Review'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
