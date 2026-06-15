class GameStoreAssets {
  const GameStoreAssets({
    required this.appId,
    required this.chineseName,
    required this.englishName,
    required this.headerImageUrl,
    required this.capsuleImageUrl,
    required this.imageUrls,
    required this.isFree,
    required this.priceInitialFormatted,
    required this.priceFinalFormatted,
    required this.discountPercent,
    required this.reviewScoreDesc,
    required this.reviewPercent,
    required this.reviewCount,
    required this.heyboxScore,
    required this.heyboxScoreDesc,
    required this.heyboxFollowCount,
    required this.heyboxUserCount,
    required this.heyboxTags,
    required this.heyboxPriceCurrent,
    required this.heyboxPriceInitial,
    required this.heyboxDiscountPercent,
    required this.heyboxLowestPrice,
    required this.heyboxLowestDiscount,
    required this.heyboxPromoDeadline,
    required this.releaseDate,
    required this.developers,
    required this.publishers,
    required this.genres,
    required this.categories,
    required this.supportsWindows,
    required this.supportsMac,
    required this.supportsLinux,
    required this.achievementCount,
    required this.recommendationCount,
    required this.shortDescription,
    required this.metacriticScore,
  });

  final int appId;
  final String chineseName;
  final String englishName;
  final String headerImageUrl;
  final String capsuleImageUrl;
  final List<String> imageUrls;
  final bool isFree;
  final String priceInitialFormatted;
  final String priceFinalFormatted;
  final int discountPercent;
  final String reviewScoreDesc;
  final int reviewPercent;
  final int reviewCount;
  final String heyboxScore;
  final String heyboxScoreDesc;
  final int heyboxFollowCount;
  final int heyboxUserCount;
  final List<String> heyboxTags;
  final String heyboxPriceCurrent;
  final String heyboxPriceInitial;
  final int heyboxDiscountPercent;
  final String heyboxLowestPrice;
  final int heyboxLowestDiscount;
  final String heyboxPromoDeadline;
  final String releaseDate;
  final List<String> developers;
  final List<String> publishers;
  final List<String> genres;
  final List<String> categories;
  final bool supportsWindows;
  final bool supportsMac;
  final bool supportsLinux;
  final int achievementCount;
  final int recommendationCount;
  final String shortDescription;
  final int? metacriticScore;
}
