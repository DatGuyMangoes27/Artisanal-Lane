import 'package:flutter/foundation.dart';

/// Internal-only concept flags.
///
/// Enable the creator-commerce preview on a private build with:
/// `--dart-define=CREATOR_COMMERCE_PREVIEW=true`
const bool creatorCommercePreviewEnabled = bool.fromEnvironment(
  'CREATOR_COMMERCE_PREVIEW',
  defaultValue: false,
);

/// Integrated marketplace journeys, distinct from the standalone showcase.
const bool creatorCommerceEnabled = bool.fromEnvironment(
  'CREATOR_COMMERCE_ENABLED',
  defaultValue: false,
);

/// Content reporting remains unavailable until its migration is deployed.
const bool creatorSafetyEnabled = bool.fromEnvironment(
  'CREATOR_SAFETY_ENABLED',
  defaultValue: false,
);

/// Private creator-post videos remain disabled until the Storage migration and
/// release approval have both been completed.
const bool creatorVideoPostsEnabled = bool.fromEnvironment(
  'CREATOR_VIDEO_POSTS_ENABLED',
  defaultValue: false,
);

/// Private device-validation account. This is not an entitlement override:
/// it only enables the local, non-saving product-editor test surface below.
const String internalProductEditorTestUserId =
    'e64a24e3-9ead-40ec-815f-0e412efe233b';

bool canUseInternalProductEditorTestMode({
  required bool creatorCommerceFeatureEnabled,
  required String? userId,
  bool releaseBuild = kReleaseMode,
}) {
  return !releaseBuild &&
      creatorCommerceFeatureEnabled &&
      userId == internalProductEditorTestUserId;
}

bool isInternalProductEditorTestMode(String? userId) {
  return canUseInternalProductEditorTestMode(
    creatorCommerceFeatureEnabled: creatorCommerceEnabled,
    userId: userId,
  );
}
