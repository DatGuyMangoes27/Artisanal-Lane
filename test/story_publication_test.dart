import 'package:artisanal_lane/features/buyer/utils/story_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const publication = StoryPublication(
    id: 'request',
    shopId: 'shop',
    mediaPath: 'owner/request.jpg',
    mediaType: 'image',
    caption: 'My workshop',
  );
  test(
    'lost commit response retries without a second upload or story',
    () async {
      Map<String, dynamic>? saved;
      var uploads = 0, inserts = 0;
      Future<void> publish() => publication.ensurePublished(
        find: () async => saved,
        upload: () async {
          uploads++;
        },
        insert: (row) async {
          inserts++;
          saved = Map.of(row);
          throw StateError('response lost');
        },
      );
      await expectLater(publish(), throwsStateError);
      await publish();
      expect(uploads, 1);
      expect(inserts, 1);
      expect(saved, publication.row);
    },
  );
  test('failed upload retains identity for a safe retry', () async {
    Map<String, dynamic>? saved;
    var uploads = 0;
    Future<void> publish() => publication.ensurePublished(
      find: () async => saved,
      upload: () async {
        uploads++;
        if (uploads == 1) throw StateError('offline');
      },
      insert: (row) async {
        saved = Map.of(row);
      },
    );
    await expectLater(publish(), throwsStateError);
    await publish();
    expect(saved?['media_path'], 'owner/request.jpg');
    expect(uploads, 2);
  });
  test('changed caption or owner cannot reuse a committed request', () async {
    for (final field in ['caption', 'shop_id', 'media_path', 'media_type']) {
      await expectLater(
        publication.ensurePublished(
          find: () async => {...publication.row, field: 'different'},
          upload: () async => fail('must not upload'),
          insert: (_) async => fail('must not insert'),
        ),
        throwsStateError,
      );
    }
  });
  test('unconfirmed row is not reported as published', () async {
    await expectLater(
      publication.ensurePublished(
        find: () async => null,
        upload: () async {},
        insert: (_) async {},
      ),
      throwsStateError,
    );
  });
}
