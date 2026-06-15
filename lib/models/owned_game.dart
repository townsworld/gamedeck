class OwnedGame {
  const OwnedGame({
    required this.steamId,
    required this.appId,
    required this.name,
    required this.englishName,
    required this.chineseName,
    required this.iconUrl,
    required this.headerUrl,
    required this.capsuleUrl,
    required this.playtimeForeverMinutes,
    required this.lastPlayedAt,
    required this.lastSyncedAt,
  });

  final String steamId;
  final int appId;
  final String name;
  final String englishName;
  final String chineseName;
  final String iconUrl;
  final String headerUrl;
  final String capsuleUrl;
  final int playtimeForeverMinutes;
  final DateTime lastPlayedAt;
  final DateTime lastSyncedAt;

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

  String get searchText {
    return '$name $englishName $chineseName'.toLowerCase();
  }

  factory OwnedGame.fromJson(Map<String, Object?> json) {
    final appId = json['appId'] as int;
    final storedIconUrl = json['iconUrl'] as String? ?? '';
    return OwnedGame(
      steamId: json['steamId'] as String,
      appId: appId,
      name: json['name'] as String? ?? 'Unknown game',
      englishName: json['englishName'] as String? ?? '',
      chineseName: json['chineseName'] as String? ?? '',
      iconUrl: _upgradeIconUrl(appId, storedIconUrl),
      headerUrl:
          json['headerUrl'] as String? ?? _steamCdnUrl(appId, 'header.jpg'),
      capsuleUrl:
          json['capsuleUrl'] as String? ??
          _steamCdnUrl(appId, 'capsule_616x353.jpg'),
      playtimeForeverMinutes: json['playtimeForeverMinutes'] as int? ?? 0,
      lastPlayedAt:
          DateTime.tryParse(json['lastPlayedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSyncedAt:
          DateTime.tryParse(json['lastSyncedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'steamId': steamId,
      'appId': appId,
      'name': name,
      'englishName': englishName,
      'chineseName': chineseName,
      'iconUrl': iconUrl,
      'headerUrl': headerUrl,
      'capsuleUrl': capsuleUrl,
      'playtimeForeverMinutes': playtimeForeverMinutes,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
    };
  }
}

String _upgradeIconUrl(int appId, String storedIconUrl) {
  if (storedIconUrl.isEmpty ||
      storedIconUrl.contains('/steamcommunity/public/images/apps/')) {
    return _steamCdnUrl(appId, 'capsule_231x87.jpg');
  }
  return storedIconUrl;
}

String _steamCdnUrl(int appId, String fileName) {
  return 'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/$fileName';
}
