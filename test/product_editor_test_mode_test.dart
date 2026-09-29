import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internal product-editor test mode', () {
    test(
      'is never available in a release build, even for the test account',
      () {
        expect(
          canUseInternalProductEditorTestMode(
            creatorCommerceFeatureEnabled: true,
            userId: internalProductEditorTestUserId,
            releaseBuild: true,
          ),
          isFalse,
        );
      },
    );
    test('requires both the creator-commerce build flag and exact account', () {
      expect(
        canUseInternalProductEditorTestMode(
          creatorCommerceFeatureEnabled: true,
          userId: internalProductEditorTestUserId,
        ),
        isTrue,
      );
      expect(
        canUseInternalProductEditorTestMode(
          creatorCommerceFeatureEnabled: false,
          userId: internalProductEditorTestUserId,
        ),
        isFalse,
      );
      expect(
        canUseInternalProductEditorTestMode(
          creatorCommerceFeatureEnabled: true,
          userId: 'another-account',
        ),
        isFalse,
      );
      expect(
        canUseInternalProductEditorTestMode(
          creatorCommerceFeatureEnabled: true,
          userId: null,
        ),
        isFalse,
      );
    });
  });
}
