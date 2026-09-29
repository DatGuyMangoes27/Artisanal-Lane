enum ShopMessageTapOutcome { promptSignIn, openChat }

const String shopShareBaseUrl = 'https://artisanlanesa.co.za/shops';

String buildShopShareText({required String shopId, required String shopName}) {
  final shopUrl = '$shopShareBaseUrl/${Uri.encodeComponent(shopId)}';
  return 'Check out $shopName on Artisan Lane!\n$shopUrl';
}

/// Posts have no public page, so a shared post links to its maker's shop.
String buildPostShareText({
  required String shopId,
  required String? shopName,
  required String caption,
}) {
  final shopUrl = '$shopShareBaseUrl/${Uri.encodeComponent(shopId)}';
  final maker = shopName?.trim().isNotEmpty == true
      ? shopName!.trim()
      : 'this maker';
  var excerpt = caption.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (excerpt.length > 140) {
    excerpt = '${excerpt.substring(0, 139).trimRight()}…';
  }
  return excerpt.isEmpty
      ? 'See $maker on Artisan Lane!\n$shopUrl'
      : '"$excerpt" — $maker on Artisan Lane\n$shopUrl';
}

String followerCountLabel(int count) =>
    count == 1 ? '1 follower' : '$count followers';

String? shopCollectionMetaLabel(int? productCount) {
  if (productCount == null) return null;
  return '$productCount pieces';
}

String buyerShopMessageRoute(String threadId) {
  return '/profile/messages/$threadId';
}

bool requiresSignInToMessageShop(String? userId) {
  return userId == null || userId.isEmpty;
}

Future<ShopMessageTapOutcome> handleShopMessageTap({
  required String? userId,
  required Future<void> Function() promptSignIn,
  required Future<String> Function(String userId) createOrGetThreadId,
  required Future<void> Function(String route) openChat,
}) async {
  if (requiresSignInToMessageShop(userId)) {
    await promptSignIn();
    return ShopMessageTapOutcome.promptSignIn;
  }

  final threadId = await createOrGetThreadId(userId!);
  await openChat(buyerShopMessageRoute(threadId));
  return ShopMessageTapOutcome.openChat;
}
