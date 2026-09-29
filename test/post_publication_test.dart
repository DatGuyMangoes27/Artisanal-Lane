import 'package:artisanal_lane/features/vendor/services/post_publication.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PostPublication submission({String caption = 'A handmade piece'}) =>
      PostPublication(
        id: 'post-1',
        shopId: 'shop-1',
        caption: caption,
        mediaUrls: ['https://example.com/photo.jpg'],
        productIds: ['product-1'],
      );
  ShopPost saved(Map<String, dynamic> values) => ShopPost.fromJson({
    ...values,
    'created_at': '2026-09-25T10:00:00Z',
    'updated_at': '2026-09-25T10:00:00Z',
  });

  test(
    'lost response retries one committed post without another insert',
    () async {
      ShopPost? row;
      var writes = 0;
      final request = submission();
      Future<void> insert(Map<String, dynamic> values) async {
        writes++;
        row = saved(values);
        throw StateError('Connection lost after commit');
      }

      await expectLater(
        request.publish(find: () async => row, insert: insert),
        throwsStateError,
      );
      expect(
        (await request.publish(find: () async => row, insert: insert)).id,
        'post-1',
      );
      expect(writes, 1);
    },
  );
  test('unconfirmed writes are not reported as success', () async {
    await expectLater(
      submission().publish(find: () async => null, insert: (_) async {}),
      throwsStateError,
    );
  });
  test('retry cannot overwrite a differently saved submission', () async {
    final row = saved(submission().values);
    await expectLater(
      submission(caption: 'Changed').publish(
        find: () async => row,
        insert: (_) async => fail('must not write'),
      ),
      throwsStateError,
    );
  });
  test('caller changes cannot mutate a submitted media list', () {
    final media = ['one'];
    final request = PostPublication(
      id: '1',
      shopId: '2',
      caption: 'caption',
      mediaUrls: media,
    );
    media.add('two');
    expect(request.mediaUrls, ['one']);
    expect(() => request.mediaUrls.add('three'), throwsUnsupportedError);
  });
  test('concurrent insert-ignore can confirm the same submission', () async {
    ShopPost? row;
    final request = submission();
    final result = await request.publish(
      find: () async => row,
      insert: (values) async {
        row = saved(values);
      },
    );
    expect(result.mediaUrls, request.mediaUrls);
    expect(result.productIds, request.productIds);
  });
}
