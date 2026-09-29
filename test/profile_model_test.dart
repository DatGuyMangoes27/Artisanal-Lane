import 'package:flutter_test/flutter_test.dart';
import 'package:artisanal_lane/models/profile.dart';

void main() {
  test(
    'Profile.fromJson tolerates rows limited to the public column set '
    '(id, display_name, avatar_url, role, created_at, updated_at)',
    () {
      final profile = Profile.fromJson({
        'id': 'user-1',
        'display_name': 'Jane Vendor',
        'avatar_url': null,
        'role': 'vendor',
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
      });

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Jane Vendor');
      expect(profile.role, 'vendor');
      expect(profile.email, isNull);
      expect(profile.phone, isNull);
      expect(profile.isVendor, isTrue);
    },
  );

  test('Profile.fromJson still reads private columns when present (own profile via RPC)', () {
    final profile = Profile.fromJson({
      'id': 'user-1',
      'display_name': 'Jane Buyer',
      'avatar_url': null,
      'role': 'buyer',
      'email': 'jane@example.com',
      'phone': '0821234567',
      'created_at': '2026-05-14T08:00:00.000Z',
      'updated_at': '2026-05-14T08:00:00.000Z',
    });

    expect(profile.email, 'jane@example.com');
    expect(profile.phone, '0821234567');
  });
}
