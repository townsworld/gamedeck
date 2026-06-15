import 'owned_game.dart';
import 'steam_account.dart';

class GameLibraryEntry {
  const GameLibraryEntry({
    required this.appId,
    required this.name,
    required this.englishName,
    required this.chineseName,
    required this.iconUrl,
    required this.headerUrl,
    required this.capsuleUrl,
    required this.imageUrls,
    required this.priceLabel,
    required this.originalPriceLabel,
    required this.discountPercent,
    required this.reviewScoreDesc,
    required this.reviewPercent,
    required this.reviewCount,
    required this.heyboxScore,
    required this.heyboxPriceCurrent,
    required this.heyboxLowestPrice,
    required this.heyboxLowestDiscount,
    required this.ownedCopies,
  });

  final int appId;
  final String name;
  final String englishName;
  final String chineseName;
  final String iconUrl;
  final String headerUrl;
  final String capsuleUrl;
  final List<String> imageUrls;
  final String priceLabel;
  final String originalPriceLabel;
  final int discountPercent;
  final String reviewScoreDesc;
  final int reviewPercent;
  final int reviewCount;
  final String heyboxScore;
  final String heyboxPriceCurrent;
  final String heyboxLowestPrice;
  final int heyboxLowestDiscount;
  final List<GameOwnership> ownedCopies;

  String get displayName {
    if (chineseName.trim().isNotEmpty) {
      return chineseName;
    }
    return name;
  }

  String get secondaryName {
    if (englishName.trim().isEmpty || englishName == displayName) {
      return '';
    }
    return englishName;
  }

  int get ownerCount => ownedCopies.length;

  int get totalPlaytimeMinutes {
    return ownedCopies.fold(
      0,
      (total, ownership) => total + ownership.ownedGame.playtimeForeverMinutes,
    );
  }

  DateTime get lastPlayedAt {
    return ownedCopies
        .map((ownership) => ownership.ownedGame.lastPlayedAt)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }
}

class GameOwnership {
  const GameOwnership({required this.account, required this.ownedGame});

  final SteamAccount account;
  final OwnedGame ownedGame;
}

enum AccountFilter { all, multiOwned, singleOwned }

enum LibrarySort { lastPlayed, name, totalPlaytime, ownerCount, recentlySynced }
