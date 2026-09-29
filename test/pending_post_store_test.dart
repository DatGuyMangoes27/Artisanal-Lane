import 'package:artisanal_lane/features/vendor/services/pending_post_store.dart';
import 'package:artisanal_lane/features/vendor/services/post_publication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  PostPublication post(String id) => PostPublication(
    id: id,
    shopId: 'shop',
    caption: 'Handmade',
    mediaUrls: ['https://example.com/p.jpg'],
    productIds: ['p'],
  );
  test(
    'restores the exact submission across store instances, scoped to account',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingPostStore(prefs).save('a', post('submission-1'));
      final restored = PendingPostStore(prefs).read('a')!;
      expect(restored.values, post('submission-1').values);
      expect(PendingPostStore(prefs).read('b'), isNull);
    },
  );
  test(
    'confirmation never removes a newer or another account submission',
    () async {
      final store = PendingPostStore(await SharedPreferences.getInstance());
      await store.save('a', post('newer'));
      await store.save('b', post('other'));
      await store.clear('a', 'older');
      expect(store.read('a')!.id, 'newer');
      await store.clear('a', 'newer');
      expect(store.read('a'), isNull);
      expect(store.read('b')!.id, 'other');
    },
  );
  test(
    'corrupt pending data fails closed, never silently loses an uncertain post',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_post_submission_v1:a', 'broken json');
      expect(() => PendingPostStore(prefs).read('a'), throwsFormatException);
    },
  );
  test('another editor cannot replace an unconfirmed submission', () async {
    final store = PendingPostStore(await SharedPreferences.getInstance());
    await store.save('a', post('first'));
    await expectLater(store.save('a', post('second')), throwsStateError);
    expect(store.read('a')!.id, 'first');
  });
}
