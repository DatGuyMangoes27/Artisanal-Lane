String buyerShopMessageRoute(String threadId) {
  return '/profile/messages/$threadId';
}

bool requiresSignInToMessageShop(String? userId) {
  return userId == null || userId.isEmpty;
}
