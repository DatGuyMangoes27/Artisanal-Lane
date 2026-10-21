import '../../../models/product.dart';

/// Who the gift is for, picked in the first step of the Gift Concierge.
enum GiftRecipient { her, him, kids, home, anyone }

extension GiftRecipientLabel on GiftRecipient {
  String get label => switch (this) {
    GiftRecipient.her => 'Her',
    GiftRecipient.him => 'Him',
    GiftRecipient.kids => 'Kids',
    GiftRecipient.home => 'Home',
    GiftRecipient.anyone => 'Anyone',
  };
}

/// The occasion, picked in the second step.
enum GiftOccasion { birthday, thankYou, wedding, justBecause }

extension GiftOccasionLabel on GiftOccasion {
  String get label => switch (this) {
    GiftOccasion.birthday => 'Birthday',
    GiftOccasion.thankYou => 'Thank you',
    GiftOccasion.wedding => 'Wedding',
    GiftOccasion.justBecause => 'Just because',
  };
}

/// The budget band, picked in the third step.
enum GiftBudget { under250, between250And500, between500And1000, any }

extension GiftBudgetLabel on GiftBudget {
  String get label => switch (this) {
    GiftBudget.under250 => 'Under R250',
    GiftBudget.between250And500 => 'R250–R500',
    GiftBudget.between500And1000 => 'R500–R1000',
    GiftBudget.any => 'Any',
  };

  bool matches(double price) => switch (this) {
    GiftBudget.under250 => price < 250,
    GiftBudget.between250And500 => price >= 250 && price <= 500,
    GiftBudget.between500And1000 => price > 500 && price <= 1000,
    GiftBudget.any => true,
  };

  /// Whether [price] is cheaper than this band (rather than dearer).
  bool isBelow(double price) => switch (this) {
    GiftBudget.under250 => false,
    GiftBudget.between250And500 => price < 250,
    GiftBudget.between500And1000 => price <= 500,
    GiftBudget.any => false,
  };

  /// How far (in rands) [price] sits outside this band; 0 when it fits.
  /// Used only to order "close matches" that miss the budget.
  double distanceFrom(double price) {
    if (matches(price)) return 0;
    return switch (this) {
      GiftBudget.under250 => price - 250 + 0.01,
      GiftBudget.between250And500 => price < 250 ? 250 - price : price - 500,
      GiftBudget.between500And1000 =>
        price <= 500 ? 500 - price + 0.01 : price - 1000,
      GiftBudget.any => 0,
    };
  }
}

/// The price a buyer actually sees and pays for [product] right now, using
/// the same rules as the product page: the made-to-order price when the
/// piece is currently sold made to order, otherwise the default variant's
/// price, otherwise the base price. The gift finder filters and displays
/// with this so the budget check and the card price can never disagree.
double giftPrice(Product product) {
  if (product.isMadeToOrderAvailable) return product.effectiveMtoPrice;
  return product.defaultVariant?.price ?? product.price;
}

/// "Was" price to strike through next to [giftPrice], or null when the piece
/// is not on sale at that price.
double? giftCompareAtPrice(Product product) {
  if (product.isMadeToOrderAvailable) return null;
  final variant = product.defaultVariant;
  final compareAt = variant != null
      ? variant.compareAtPrice
      : product.compareAtPrice;
  return compareAt != null && compareAt > giftPrice(product) ? compareAt : null;
}

/// Small keyword map used to score how well a product fits a recipient.
/// Deliberately simple and transparent rather than a "smart" model.
const Map<GiftRecipient, List<String>> _recipientKeywords =
    <GiftRecipient, List<String>>{
      GiftRecipient.her: [
        'jewel',
        'earring',
        'necklace',
        'bracelet',
        'scarf',
        'bag',
        'beauty',
        'skincare',
        'floral',
        'ceramic',
        'wrap',
        'perfume',
        'fragrance',
      ],
      GiftRecipient.him: [
        'leather',
        'wallet',
        'wood',
        'cufflink',
        'grooming',
        'beard',
        'belt',
        'watch',
        'tool',
        'whisky',
        'cologne',
      ],
      GiftRecipient.kids: [
        'toy',
        'kid',
        'plush',
        'puzzle',
        'children',
        'child',
        'baby',
        'game',
        'doll',
      ],
      GiftRecipient.home: [
        'home',
        'candle',
        'decor',
        'vase',
        'ceramic',
        'kitchen',
        'table',
        'cushion',
        'plant',
        'basket',
        'mug',
        'bowl',
      ],
      GiftRecipient.anyone: [],
    };

const Map<GiftOccasion, List<String>> _occasionKeywords =
    <GiftOccasion, List<String>>{
      GiftOccasion.birthday: ['birthday', 'celebration', 'party'],
      GiftOccasion.thankYou: ['thank', 'gratitude', 'card', 'note'],
      GiftOccasion.wedding: ['wedding', 'couple', 'engagement', 'bridal'],
      GiftOccasion.justBecause: [],
    };

/// Number of keyword hits between [product] and the recipient/occasion
/// keyword lists. Exposed separately so tests can check affinity directly.
int giftAffinityScore({
  required Product product,
  required GiftRecipient recipient,
  required GiftOccasion occasion,
}) {
  final keywords = <String>{
    ..._recipientKeywords[recipient]!,
    ..._occasionKeywords[occasion]!,
  };
  if (keywords.isEmpty) return 0;
  final haystack = <String>[
    product.title,
    product.categoryName ?? '',
    product.subcategoryName ?? '',
    ...product.tags,
  ].join(' ').toLowerCase();
  return keywords.where(haystack.contains).length;
}

/// A deliberately transparent, local ranking for the Gift Concierge results:
/// budget is a hard filter on [giftPrice], keyword affinity ranks recipient/occasion fit,
/// in-stock pieces come first, and verified makers are boosted as a
/// tie-breaker.
List<Product> rankGiftConciergeProducts({
  required List<Product> products,
  required GiftRecipient recipient,
  required GiftOccasion occasion,
  required GiftBudget budget,
}) {
  final candidates = products
      .where(
        (product) => product.isPublished && budget.matches(giftPrice(product)),
      )
      .toList(growable: false);

  final scored = candidates.map((product) {
    final affinity = giftAffinityScore(
      product: product,
      recipient: recipient,
      occasion: occasion,
    );
    return (product: product, affinity: affinity);
  }).toList();

  scored.sort((a, b) {
    final byAffinity = b.affinity.compareTo(a.affinity);
    if (byAffinity != 0) return byAffinity;
    final byStock = (b.product.isInStock ? 1 : 0).compareTo(
      a.product.isInStock ? 1 : 0,
    );
    if (byStock != 0) return byStock;
    final byVerified = (b.product.shopIsVerified ? 1 : 0).compareTo(
      a.product.shopIsVerified ? 1 : 0,
    );
    if (byVerified != 0) return byVerified;
    return b.product.createdAt.compareTo(a.product.createdAt);
  });

  return scored.map((entry) => entry.product).toList(growable: false);
}
