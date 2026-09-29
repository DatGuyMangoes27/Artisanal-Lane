import 'package:flutter_test/flutter_test.dart';
import 'package:artisanal_lane/models/shop_story.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);
  ShopStory story(String id, String shop, int hours) => ShopStory(
    id: id,
    shopId: shop,
    mediaPath: 'user/$id.jpg',
    mediaType: 'image',
    caption: '',
    createdAt: now.subtract(Duration(hours: hours)),
    expiresAt: now
        .subtract(Duration(hours: hours))
        .add(const Duration(hours: 24)),
    shopName: shop,
  );
  test('story expires at the exact 24-hour boundary', () {
    expect(story('a', 'maker', 23).isLiveAt(now), isTrue);
    expect(story('b', 'maker', 24).isLiveAt(now), isFalse);
    expect(story('c', 'maker', -1).isLiveAt(now), isFalse);
  });
  test('groups by maker, chronological within maker, unseen makers first', () {
    final groups = groupLiveStories(
      [
        story('a', 'one', 1),
        story('b', 'two', 3),
        story('c', 'two', 2),
        story('d', 'three', 25),
      ],
      {'a'},
      now,
    );
    expect(groups.length, 2);
    expect(groups.first.map((s) => s.id), ['b', 'c']);
    expect(groups.last.single.id, 'a');
  });
  test('a newly published story tolerates small device clock drift', () {
    final fresh = ShopStory(
      id: 'fresh',
      shopId: 'maker',
      mediaPath: 'owner/fresh.jpg',
      mediaType: 'image',
      caption: '',
      createdAt: now.add(const Duration(seconds: 3)),
      expiresAt: now.add(const Duration(hours: 24)),
      shopName: 'Maker',
    );
    expect(fresh.isLiveAt(now), isTrue);
    expect(groupLiveStories([fresh], {}, now).length, 1);
  });
  test('seen state cannot keep expired stories visible', () {
    expect(groupLiveStories([story('old', 'one', 24)], {'old'}, now), isEmpty);
  });
}
