class ReviewSummary {
  final double averageRating;
  final int reviewCount;

  const ReviewSummary({this.averageRating = 0, this.reviewCount = 0});

  bool get hasReviews => reviewCount > 0;

  String get countLabel =>
      reviewCount == 1 ? '1 review' : '$reviewCount reviews';

  factory ReviewSummary.fromRatings(List<int> ratings) {
    if (ratings.isEmpty) {
      return const ReviewSummary();
    }

    final total = ratings.fold<int>(0, (sum, value) => sum + value);
    return ReviewSummary(
      averageRating: total / ratings.length,
      reviewCount: ratings.length,
    );
  }
}
