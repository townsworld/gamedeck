class GameMetadata {
  const GameMetadata({
    required this.schemaVersion,
    required this.appId,
    required this.chineseName,
    required this.englishName,
    required this.headerImageUrl,
    required this.capsuleImageUrl,
    required this.screenshotUrls,
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
    required this.lastFetchedAt,
    this.lastFailedAt,
    this.lastError,
  });

  final int schemaVersion;
  final int appId;
  final String chineseName;
  final String englishName;
  final String headerImageUrl;
  final String capsuleImageUrl;
  final List<String> screenshotUrls;
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
  final DateTime lastFetchedAt;
  final DateTime? lastFailedAt;
  final String? lastError;

  bool get hasImages {
    return headerImageUrl.isNotEmpty ||
        capsuleImageUrl.isNotEmpty ||
        screenshotUrls.isNotEmpty;
  }

  List<String> get imageUrls {
    return <String>{
      if (headerImageUrl.isNotEmpty) headerImageUrl,
      if (capsuleImageUrl.isNotEmpty) capsuleImageUrl,
      ...screenshotUrls,
    }.toList();
  }

  bool get hasPrice {
    return isFree ||
        priceFinalFormatted.isNotEmpty ||
        heyboxPriceCurrent.isNotEmpty;
  }

  String get priceLabel {
    if (isFree) {
      return '免费';
    }
    if (priceFinalFormatted.isNotEmpty) {
      return priceFinalFormatted;
    }
    return heyboxPriceCurrent;
  }

  bool get hasReview {
    return reviewScoreDesc.isNotEmpty ||
        reviewCount > 0 ||
        heyboxScore.isNotEmpty;
  }

  bool get hasStoreInfo {
    return hasPrice ||
        hasReview ||
        releaseDate.isNotEmpty ||
        developers.isNotEmpty ||
        publishers.isNotEmpty ||
        genres.isNotEmpty ||
        categories.isNotEmpty ||
        shortDescription.isNotEmpty ||
        heyboxScore.isNotEmpty ||
        heyboxTags.isNotEmpty ||
        heyboxLowestPrice.isNotEmpty ||
        recommendationCount > 0 ||
        achievementCount > 0 ||
        metacriticScore != null;
  }

  GameMetadata copyWithFailure(String error) {
    return GameMetadata(
      appId: appId,
      schemaVersion: schemaVersion,
      chineseName: chineseName,
      englishName: englishName,
      headerImageUrl: headerImageUrl,
      capsuleImageUrl: capsuleImageUrl,
      screenshotUrls: screenshotUrls,
      isFree: isFree,
      priceInitialFormatted: priceInitialFormatted,
      priceFinalFormatted: priceFinalFormatted,
      discountPercent: discountPercent,
      reviewScoreDesc: reviewScoreDesc,
      reviewPercent: reviewPercent,
      reviewCount: reviewCount,
      heyboxScore: heyboxScore,
      heyboxScoreDesc: heyboxScoreDesc,
      heyboxFollowCount: heyboxFollowCount,
      heyboxUserCount: heyboxUserCount,
      heyboxTags: heyboxTags,
      heyboxPriceCurrent: heyboxPriceCurrent,
      heyboxPriceInitial: heyboxPriceInitial,
      heyboxDiscountPercent: heyboxDiscountPercent,
      heyboxLowestPrice: heyboxLowestPrice,
      heyboxLowestDiscount: heyboxLowestDiscount,
      heyboxPromoDeadline: heyboxPromoDeadline,
      releaseDate: releaseDate,
      developers: developers,
      publishers: publishers,
      genres: genres,
      categories: categories,
      supportsWindows: supportsWindows,
      supportsMac: supportsMac,
      supportsLinux: supportsLinux,
      achievementCount: achievementCount,
      recommendationCount: recommendationCount,
      shortDescription: shortDescription,
      metacriticScore: metacriticScore,
      lastFetchedAt: lastFetchedAt,
      lastFailedAt: DateTime.now(),
      lastError: error,
    );
  }

  factory GameMetadata.empty(int appId) {
    return GameMetadata(
      appId: appId,
      schemaVersion: 0,
      chineseName: '',
      englishName: '',
      headerImageUrl: '',
      capsuleImageUrl: '',
      screenshotUrls: const [],
      isFree: false,
      priceInitialFormatted: '',
      priceFinalFormatted: '',
      discountPercent: 0,
      reviewScoreDesc: '',
      reviewPercent: 0,
      reviewCount: 0,
      heyboxScore: '',
      heyboxScoreDesc: '',
      heyboxFollowCount: 0,
      heyboxUserCount: 0,
      heyboxTags: const [],
      heyboxPriceCurrent: '',
      heyboxPriceInitial: '',
      heyboxDiscountPercent: 0,
      heyboxLowestPrice: '',
      heyboxLowestDiscount: 0,
      heyboxPromoDeadline: '',
      releaseDate: '',
      developers: const [],
      publishers: const [],
      genres: const [],
      categories: const [],
      supportsWindows: false,
      supportsMac: false,
      supportsLinux: false,
      achievementCount: 0,
      recommendationCount: 0,
      shortDescription: '',
      metacriticScore: null,
      lastFetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory GameMetadata.fromJson(Map<String, Object?> json) {
    return GameMetadata(
      appId: json['appId'] as int,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      chineseName: json['chineseName'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      headerImageUrl: json['headerImageUrl'] as String? ?? '',
      capsuleImageUrl: json['capsuleImageUrl'] as String? ?? '',
      screenshotUrls: _stringList(json['screenshotUrls']),
      isFree: json['isFree'] as bool? ?? false,
      priceInitialFormatted: json['priceInitialFormatted'] as String? ?? '',
      priceFinalFormatted: json['priceFinalFormatted'] as String? ?? '',
      discountPercent: json['discountPercent'] as int? ?? 0,
      reviewScoreDesc: json['reviewScoreDesc'] as String? ?? '',
      reviewPercent: json['reviewPercent'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      heyboxScore: json['heyboxScore'] as String? ?? '',
      heyboxScoreDesc: json['heyboxScoreDesc'] as String? ?? '',
      heyboxFollowCount: json['heyboxFollowCount'] as int? ?? 0,
      heyboxUserCount: json['heyboxUserCount'] as int? ?? 0,
      heyboxTags: _stringList(json['heyboxTags']),
      heyboxPriceCurrent: json['heyboxPriceCurrent'] as String? ?? '',
      heyboxPriceInitial: json['heyboxPriceInitial'] as String? ?? '',
      heyboxDiscountPercent: json['heyboxDiscountPercent'] as int? ?? 0,
      heyboxLowestPrice: json['heyboxLowestPrice'] as String? ?? '',
      heyboxLowestDiscount: json['heyboxLowestDiscount'] as int? ?? 0,
      heyboxPromoDeadline: json['heyboxPromoDeadline'] as String? ?? '',
      releaseDate: json['releaseDate'] as String? ?? '',
      developers: _stringList(json['developers']),
      publishers: _stringList(json['publishers']),
      genres: _stringList(json['genres']),
      categories: _stringList(json['categories']),
      supportsWindows: json['supportsWindows'] as bool? ?? false,
      supportsMac: json['supportsMac'] as bool? ?? false,
      supportsLinux: json['supportsLinux'] as bool? ?? false,
      achievementCount: json['achievementCount'] as int? ?? 0,
      recommendationCount: json['recommendationCount'] as int? ?? 0,
      shortDescription: json['shortDescription'] as String? ?? '',
      metacriticScore: json['metacriticScore'] as int?,
      lastFetchedAt:
          DateTime.tryParse(json['lastFetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastFailedAt: DateTime.tryParse(json['lastFailedAt'] as String? ?? ''),
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'appId': appId,
      'schemaVersion': schemaVersion,
      'chineseName': chineseName,
      'englishName': englishName,
      'headerImageUrl': headerImageUrl,
      'capsuleImageUrl': capsuleImageUrl,
      'screenshotUrls': screenshotUrls,
      'isFree': isFree,
      'priceInitialFormatted': priceInitialFormatted,
      'priceFinalFormatted': priceFinalFormatted,
      'discountPercent': discountPercent,
      'reviewScoreDesc': reviewScoreDesc,
      'reviewPercent': reviewPercent,
      'reviewCount': reviewCount,
      'heyboxScore': heyboxScore,
      'heyboxScoreDesc': heyboxScoreDesc,
      'heyboxFollowCount': heyboxFollowCount,
      'heyboxUserCount': heyboxUserCount,
      'heyboxTags': heyboxTags,
      'heyboxPriceCurrent': heyboxPriceCurrent,
      'heyboxPriceInitial': heyboxPriceInitial,
      'heyboxDiscountPercent': heyboxDiscountPercent,
      'heyboxLowestPrice': heyboxLowestPrice,
      'heyboxLowestDiscount': heyboxLowestDiscount,
      'heyboxPromoDeadline': heyboxPromoDeadline,
      'releaseDate': releaseDate,
      'developers': developers,
      'publishers': publishers,
      'genres': genres,
      'categories': categories,
      'supportsWindows': supportsWindows,
      'supportsMac': supportsMac,
      'supportsLinux': supportsLinux,
      'achievementCount': achievementCount,
      'recommendationCount': recommendationCount,
      'shortDescription': shortDescription,
      'metacriticScore': metacriticScore,
      'lastFetchedAt': lastFetchedAt.toIso8601String(),
      'lastFailedAt': lastFailedAt?.toIso8601String(),
      'lastError': lastError,
    };
  }
}

List<String> _stringList(Object? value) {
  return [
    for (final item in value as List<Object?>? ?? const [])
      if (item is String) item,
  ];
}
