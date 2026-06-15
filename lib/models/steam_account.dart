class SteamAccount {
  const SteamAccount({
    required this.steamId,
    required this.personaName,
    required this.avatarUrl,
    required this.profileUrl,
    required this.visibilityState,
    required this.gameCount,
    required this.totalPlaytimeMinutes,
    required this.lastSyncedAt,
    this.lastError,
  });

  final String steamId;
  final String personaName;
  final String avatarUrl;
  final String profileUrl;
  final int visibilityState;
  final int gameCount;
  final int totalPlaytimeMinutes;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isPublic => visibilityState == 3;

  SteamAccount copyWith({
    String? personaName,
    String? avatarUrl,
    String? profileUrl,
    int? visibilityState,
    int? gameCount,
    int? totalPlaytimeMinutes,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SteamAccount(
      steamId: steamId,
      personaName: personaName ?? this.personaName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileUrl: profileUrl ?? this.profileUrl,
      visibilityState: visibilityState ?? this.visibilityState,
      gameCount: gameCount ?? this.gameCount,
      totalPlaytimeMinutes: totalPlaytimeMinutes ?? this.totalPlaytimeMinutes,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  factory SteamAccount.fromJson(Map<String, Object?> json) {
    return SteamAccount(
      steamId: json['steamId'] as String,
      personaName: json['personaName'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      profileUrl: json['profileUrl'] as String? ?? '',
      visibilityState: json['visibilityState'] as int? ?? 0,
      gameCount: json['gameCount'] as int? ?? 0,
      totalPlaytimeMinutes: json['totalPlaytimeMinutes'] as int? ?? 0,
      lastSyncedAt: _dateFromJson(json['lastSyncedAt']),
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'steamId': steamId,
      'personaName': personaName,
      'avatarUrl': avatarUrl,
      'profileUrl': profileUrl,
      'visibilityState': visibilityState,
      'gameCount': gameCount,
      'totalPlaytimeMinutes': totalPlaytimeMinutes,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastError': lastError,
    };
  }
}

DateTime? _dateFromJson(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
