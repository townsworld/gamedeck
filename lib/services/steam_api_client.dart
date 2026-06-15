import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/game_store_assets.dart';
import '../models/owned_game.dart';
import '../models/steam_account.dart';

class SteamApiClient {
  SteamApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final _steamIdPattern = RegExp(r'^\d{17}$');
  static const _apiHost = 'api.steampowered.com';
  static const _storeHost = 'store.steampowered.com';
  static const _heyboxApiHost = 'api.xiaoheihe.cn';
  static const _heyboxOrigin = 'https://www.xiaoheihe.cn';
  static const _requestTimeout = Duration(seconds: 12);

  final http.Client _httpClient;

  Future<String> resolveSteamId({
    required String apiKey,
    required String input,
  }) async {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      throw const SteamApiException('请输入 SteamID64 或个人主页 URL。');
    }

    final directSteamId = _extractSteamId(normalized);
    if (directSteamId != null) {
      return directSteamId;
    }

    final vanity = _extractVanityName(normalized);
    if (vanity == null || vanity.isEmpty) {
      throw const SteamApiException('无法识别该 Steam 账号地址。');
    }

    final payload = await _getJson(
      Uri.https(_apiHost, '/ISteamUser/ResolveVanityURL/v1/', {
        'key': apiKey,
        'vanityurl': vanity,
      }),
    );
    final response = _mapFrom(payload['response']);
    if (response['success'] != 1) {
      throw const SteamApiException('没有找到这个 Steam 个人主页。');
    }

    final steamId = response['steamid'] as String?;
    if (steamId == null || !_steamIdPattern.hasMatch(steamId)) {
      throw const SteamApiException('Steam 返回了无效的账号 ID。');
    }
    return steamId;
  }

  Future<SteamAccount> fetchPlayerSummary({
    required String apiKey,
    required String steamId,
  }) async {
    final payload = await _getJson(
      Uri.https(_apiHost, '/ISteamUser/GetPlayerSummaries/v2/', {
        'key': apiKey,
        'steamids': steamId,
      }),
    );

    final response = _mapFrom(payload['response']);
    final players = response['players'] as List<Object?>? ?? [];
    if (players.isEmpty) {
      throw const SteamApiException('无法读取该账号资料，请检查 SteamID 或 API Key。');
    }

    final player = _mapFrom(players.first);
    return SteamAccount(
      steamId: steamId,
      personaName: player['personaname'] as String? ?? 'Unknown',
      avatarUrl: player['avatarfull'] as String? ?? '',
      profileUrl:
          player['profileurl'] as String? ??
          'https://steamcommunity.com/profiles/$steamId',
      visibilityState: player['communityvisibilitystate'] as int? ?? 0,
      gameCount: 0,
      totalPlaytimeMinutes: 0,
      lastSyncedAt: null,
    );
  }

  Future<List<OwnedGame>> fetchOwnedGames({
    required String apiKey,
    required String steamId,
  }) async {
    final syncedAt = DateTime.now();
    final englishGames = await _fetchOwnedGamesForLanguage(
      apiKey: apiKey,
      steamId: steamId,
      language: 'english',
    );
    final chineseGames = await _fetchOwnedGamesForLanguage(
      apiKey: apiKey,
      steamId: steamId,
      language: 'schinese',
    );
    final chineseByAppId = {
      for (final game in chineseGames) game['appid'] as int: game,
    };

    return [
      for (final game in englishGames)
        _ownedGameFromApi(
          steamId,
          game,
          _mapFrom(chineseByAppId[game['appid']]),
          syncedAt,
        ),
    ];
  }

  Future<GameStoreAssets> fetchGameStoreAssets(int appId) async {
    final chinese = await _fetchAppDetails(appId, language: 'schinese');
    final english = await _fetchAppDetails(appId, language: 'english');
    final reviews = await _fetchReviewSummary(appId);
    final heybox = await _fetchHeyboxDetails(appId);
    return _storeAssetsFromSources(
      appId: appId,
      chinese: chinese,
      english: english,
      reviews: reviews,
      heybox: heybox,
    );
  }

  Future<GameStoreAssets> fetchSteamStoreAssets(int appId) async {
    final chinese = await _fetchAppDetails(appId, language: 'schinese');
    final english = await _fetchAppDetails(appId, language: 'english');
    final reviews = await _fetchReviewSummary(appId);
    return _storeAssetsFromSources(
      appId: appId,
      chinese: chinese,
      english: english,
      reviews: reviews,
      heybox: const _HeyboxDetails.empty(),
    );
  }

  Future<GameStoreAssets> fetchHeyboxStoreAssets(int appId) async {
    final heybox = await _fetchHeyboxDetails(appId);
    return GameStoreAssets(
      appId: appId,
      chineseName: heybox.chineseName,
      englishName: heybox.englishName,
      headerImageUrl: _normalizeUrl(heybox.headerImageUrl),
      capsuleImageUrl: _normalizeUrl(heybox.iconUrl),
      imageUrls: heybox.imageUrls.map(_normalizeUrl).toList(),
      isFree: false,
      priceInitialFormatted: '',
      priceFinalFormatted: '',
      discountPercent: 0,
      reviewScoreDesc: '',
      reviewPercent: 0,
      reviewCount: 0,
      heyboxScore: heybox.score,
      heyboxScoreDesc: heybox.scoreDescription,
      heyboxFollowCount: heybox.followCount,
      heyboxUserCount: heybox.userCount,
      heyboxTags: heybox.tags,
      heyboxPriceCurrent: heybox.priceCurrent,
      heyboxPriceInitial: heybox.priceInitial,
      heyboxDiscountPercent: heybox.discountPercent,
      heyboxLowestPrice: heybox.lowestPrice,
      heyboxLowestDiscount: heybox.lowestDiscount,
      heyboxPromoDeadline: heybox.promoDeadline,
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
    );
  }

  GameStoreAssets _storeAssetsFromSources({
    required int appId,
    required Map<String, Object?> chinese,
    required Map<String, Object?> english,
    required _ReviewSummary reviews,
    required _HeyboxDetails heybox,
  }) {
    final chineseData = _successfulAppDetailsData(chinese, appId);
    final englishData = _successfulAppDetailsData(english, appId);
    final sourceData = chineseData.isNotEmpty ? chineseData : englishData;
    final priceOverview = _mapFrom(sourceData['price_overview']);
    final releaseDate = _mapFrom(sourceData['release_date']);
    final platforms = _mapFrom(sourceData['platforms']);
    final achievements = _mapFrom(sourceData['achievements']);
    final recommendations = _mapFrom(sourceData['recommendations']);
    final metacritic = _mapFrom(sourceData['metacritic']);

    final urls = <String>{
      ...heybox.imageUrls,
      ..._urlsFromAppDetails(chineseData),
      ..._urlsFromAppDetails(englishData),
    }.where((url) => url.trim().isNotEmpty).map(_normalizeUrl).toList();

    return GameStoreAssets(
      appId: appId,
      chineseName: _firstNonEmpty([
        heybox.chineseName,
        chineseData['name'] as String? ?? '',
      ]),
      englishName: _firstNonEmpty([
        englishData['name'] as String? ?? '',
        heybox.englishName,
      ]),
      headerImageUrl: _normalizeUrl(
        _firstNonEmpty([
          heybox.headerImageUrl,
          chineseData['header_image'] as String? ?? '',
          englishData['header_image'] as String? ?? '',
        ]),
      ),
      capsuleImageUrl: _normalizeUrl(
        _firstNonEmpty([
          heybox.iconUrl,
          chineseData['capsule_image'] as String? ?? '',
          englishData['capsule_image'] as String? ?? '',
        ]),
      ),
      imageUrls: urls,
      isFree: sourceData['is_free'] as bool? ?? false,
      priceInitialFormatted:
          priceOverview['initial_formatted'] as String? ?? '',
      priceFinalFormatted: priceOverview['final_formatted'] as String? ?? '',
      discountPercent: priceOverview['discount_percent'] as int? ?? 0,
      reviewScoreDesc: reviews.scoreDescription,
      reviewPercent: reviews.percentPositive,
      reviewCount: reviews.totalReviews,
      heyboxScore: heybox.score,
      heyboxScoreDesc: heybox.scoreDescription,
      heyboxFollowCount: heybox.followCount,
      heyboxUserCount: heybox.userCount,
      heyboxTags: heybox.tags,
      heyboxPriceCurrent: heybox.priceCurrent,
      heyboxPriceInitial: heybox.priceInitial,
      heyboxDiscountPercent: heybox.discountPercent,
      heyboxLowestPrice: heybox.lowestPrice,
      heyboxLowestDiscount: heybox.lowestDiscount,
      heyboxPromoDeadline: heybox.promoDeadline,
      releaseDate: releaseDate['date'] as String? ?? '',
      developers: _stringList(sourceData['developers']),
      publishers: _stringList(sourceData['publishers']),
      genres: _descriptionList(sourceData['genres']),
      categories: _descriptionList(sourceData['categories']),
      supportsWindows: platforms['windows'] as bool? ?? false,
      supportsMac: platforms['mac'] as bool? ?? false,
      supportsLinux: platforms['linux'] as bool? ?? false,
      achievementCount: achievements['total'] as int? ?? 0,
      recommendationCount: recommendations['total'] as int? ?? 0,
      shortDescription: sourceData['short_description'] as String? ?? '',
      metacriticScore: metacritic['score'] as int?,
    );
  }

  Future<List<Map<String, Object?>>> _fetchOwnedGamesForLanguage({
    required String apiKey,
    required String steamId,
    required String language,
  }) async {
    final payload = await _getJson(
      Uri.https(_apiHost, '/IPlayerService/GetOwnedGames/v1/', {
        'key': apiKey,
        'steamid': steamId,
        'include_appinfo': 'true',
        'include_played_free_games': 'true',
        'format': 'json',
        'language': language,
      }),
    );

    final response = _mapFrom(payload['response']);
    final games = response['games'] as List<Object?>? ?? [];
    return [for (final game in games) _mapFrom(game)];
  }

  Future<Map<String, Object?>> _fetchAppDetails(
    int appId, {
    required String language,
  }) async {
    return _getJson(
      Uri.https(_storeHost, '/api/appdetails', {
        'appids': '$appId',
        'l': language,
        'filters':
            'basic,price_overview,platforms,metacritic,categories,genres,screenshots,recommendations,achievements,release_date',
        'cc': 'cn',
      }),
    );
  }

  Future<_HeyboxDetails> _fetchHeyboxDetails(int appId) async {
    try {
      const path = '/game/get_game_detail/';
      final payload = await _getJson(
        Uri.https(_heyboxApiHost, path, {
          'os_type': 'web',
          'app': 'heybox',
          'client_type': 'web',
          'version': '999.0.4',
          'web_version': '2.5',
          'x_client_type': 'web',
          'x_app': 'heybox_website',
          'heybox_id': '',
          'x_os_type': 'Mac',
          'device_info': 'Chrome',
          'device_id': 'gamedeck_android',
          ..._heyboxSignature(path),
          'steam_appid': '$appId',
        }),
        headers: const {
          'Accept': '*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Origin': _heyboxOrigin,
          'Referer': '$_heyboxOrigin/',
          'User-Agent': 'Mozilla/5.0',
        },
        serviceName: '小黑盒',
      );
      if (payload['status'] != 'ok') {
        return const _HeyboxDetails.empty();
      }
      return _HeyboxDetails.fromJson(_mapFrom(payload['result']));
    } on Object {
      return const _HeyboxDetails.empty();
    }
  }

  Future<_ReviewSummary> _fetchReviewSummary(int appId) async {
    try {
      final payload = await _getJson(
        Uri.https(_storeHost, '/appreviews/$appId', {
          'json': '1',
          'language': 'all',
          'purchase_type': 'all',
          'num_per_page': '0',
        }),
      );
      final summary = _mapFrom(payload['query_summary']);
      final positive = summary['total_positive'] as int? ?? 0;
      final negative = summary['total_negative'] as int? ?? 0;
      final total = summary['total_reviews'] as int? ?? positive + negative;
      final percent = total <= 0 ? 0 : (positive * 100 / total).round();
      return _ReviewSummary(
        scoreDescription: summary['review_score_desc'] as String? ?? '',
        percentPositive: percent,
        totalReviews: total,
      );
    } on Object {
      return const _ReviewSummary(
        scoreDescription: '',
        percentPositive: 0,
        totalReviews: 0,
      );
    }
  }

  Future<Map<String, Object?>> _getJson(
    Uri uri, {
    Map<String, String> headers = const {},
    String serviceName = 'Steam',
  }) async {
    final response = await _httpClient
        .get(uri, headers: headers)
        .timeout(_requestTimeout);
    if (response.statusCode == 403) {
      throw SteamApiException('$serviceName 拒绝了请求，请稍后再试。');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SteamApiException('$serviceName 请求失败：HTTP ${response.statusCode}。');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw SteamApiException('$serviceName 返回的数据格式不正确。');
    }
    return Map<String, Object?>.from(decoded);
  }

  static Map<String, Object?> _mapFrom(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return {};
  }

  static OwnedGame _ownedGameFromApi(
    String steamId,
    Map<String, Object?> game,
    Map<String, Object?> chineseGame,
    DateTime syncedAt,
  ) {
    final appId = game['appid'] as int;
    final englishName = game['name'] as String? ?? 'App $appId';
    final chineseName = chineseGame['name'] as String? ?? '';
    return OwnedGame(
      steamId: steamId,
      appId: appId,
      name: chineseName.isEmpty ? englishName : chineseName,
      englishName: englishName,
      chineseName: chineseName,
      iconUrl: _steamCdnUrl(appId, 'capsule_231x87.jpg'),
      headerUrl: _steamCdnUrl(appId, 'header.jpg'),
      capsuleUrl: _steamCdnUrl(appId, 'capsule_616x353.jpg'),
      playtimeForeverMinutes: game['playtime_forever'] as int? ?? 0,
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
        (game['rtime_last_played'] as int? ?? 0) * 1000,
      ),
      lastSyncedAt: syncedAt,
    );
  }

  static Map<String, Object?> _successfulAppDetailsData(
    Map<String, Object?> payload,
    int appId,
  ) {
    final envelope = _mapFrom(payload['$appId']);
    if (envelope['success'] != true) {
      return {};
    }
    return _mapFrom(envelope['data']);
  }

  static List<String> _urlsFromAppDetails(Map<String, Object?> data) {
    final urls = <String>[];
    for (final key in ['header_image', 'capsule_image', 'capsule_imagev5']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        urls.add(value);
      }
    }

    final screenshots = data['screenshots'];
    if (screenshots is List<Object?>) {
      for (final screenshot in screenshots) {
        final item = _mapFrom(screenshot);
        final url =
            item['path_full'] as String? ?? item['path_thumbnail'] as String?;
        if (url != null && url.isNotEmpty) {
          urls.add(url);
        }
      }
    }
    return urls;
  }

  static Map<String, String> _heyboxSignature(String path) {
    final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final random = math.Random().nextDouble();
    final nonce = _md5('$time$random').toUpperCase();
    return {
      'hkey': _heyboxHkey(path, time, nonce),
      '_time': '$time',
      'nonce': nonce,
    };
  }

  static String _heyboxHkey(String path, int time, String nonce) {
    final normalizedPath =
        '/${path.split('/').where((segment) => segment.isNotEmpty).join('/')}/';
    const keyspace = 'AB45STUVWZEFGJ6CH01D237IXYPQRKLMN89';
    final signatureBase = _interleave([
      _mapChars('${time + 1}', keyspace, -2),
      _mapCharsFull(normalizedPath, keyspace),
      _mapCharsFull(nonce, keyspace),
    ]).substring(0, 20);
    final digest = _md5(signatureBase);
    final checksum =
        '${_mixColumns(digest.substring(digest.length - 6).codeUnits).reduce((a, b) => a + b) % 100}'
            .padLeft(2, '0');
    return '${_mapChars(digest.substring(0, 5), keyspace, -4)}$checksum';
  }

  static String _md5(String value) {
    return md5.convert(utf8.encode(value)).toString();
  }

  static String _interleave(List<String> parts) {
    final length = parts.fold(0, (max, item) => math.max(max, item.length));
    final buffer = StringBuffer();
    for (var index = 0; index < length; index += 1) {
      for (final part in parts) {
        if (index < part.length) {
          buffer.write(part[index]);
        }
      }
    }
    return buffer.toString();
  }

  static String _mapChars(String value, String keyspace, int end) {
    final source = keyspace.substring(0, keyspace.length + end);
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      buffer.write(source[codeUnit % source.length]);
    }
    return buffer.toString();
  }

  static String _mapCharsFull(String value, String keyspace) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      buffer.write(keyspace[codeUnit % keyspace.length]);
    }
    return buffer.toString();
  }

  static List<int> _mixColumns(List<int> values) {
    final mixed = List<int>.from(values);
    final result = [0, 0, 0, 0];
    result[0] =
        _mixG(values[0]) ^
        _mixY(values[1]) ^
        _mixDollar(values[2]) ^
        _mixQ(values[3]);
    result[1] =
        _mixQ(values[0]) ^
        _mixG(values[1]) ^
        _mixY(values[2]) ^
        _mixDollar(values[3]);
    result[2] =
        _mixDollar(values[0]) ^
        _mixQ(values[1]) ^
        _mixG(values[2]) ^
        _mixY(values[3]);
    result[3] =
        _mixY(values[0]) ^
        _mixDollar(values[1]) ^
        _mixQ(values[2]) ^
        _mixG(values[3]);
    mixed[0] = result[0];
    mixed[1] = result[1];
    mixed[2] = result[2];
    mixed[3] = result[3];
    return mixed;
  }

  static int _mixV(int value) {
    return value & 128 != 0 ? 255 & ((value << 1) ^ 27) : value << 1;
  }

  static int _mixQ(int value) => _mixV(value) ^ value;

  static int _mixDollar(int value) => _mixQ(_mixV(value));

  static int _mixY(int value) => _mixDollar(_mixQ(_mixV(value)));

  static int _mixG(int value) =>
      _mixY(value) ^ _mixDollar(value) ^ _mixQ(value);

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _stringFrom(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return '$value';
    }
    return '';
  }

  static int _intFrom(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    final parsed = int.tryParse(_stringFrom(value));
    return parsed ?? fallback;
  }

  static int _parseCompactNumber(Object? value) {
    final text = _stringFrom(value);
    if (text.isEmpty) {
      return 0;
    }
    final multiplier = text.contains('万') ? 10000 : 1;
    final number = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (number == null) {
      return 0;
    }
    return (number * multiplier).round();
  }

  static String _formatYuan(Object? value) {
    final text = _stringFrom(value);
    if (text.isEmpty) {
      return '';
    }
    if (text.startsWith('¥') ||
        text.startsWith('￥') ||
        text.toUpperCase().startsWith('HK') ||
        text.toUpperCase().contains('FREE') ||
        text.contains('免费')) {
      return text;
    }
    return '¥$text';
  }

  static List<String> _heyboxScreenshotUrls(Object? value) {
    final items = value as List<Object?>? ?? const [];
    return [
      for (final item in items)
        if (_urlFromAny(item) case final String url when url.isNotEmpty)
          _normalizeUrl(url),
    ];
  }

  static String _urlFromAny(Object? value) {
    if (value is String) {
      return value;
    }
    final map = _mapFrom(value);
    for (final key in [
      'url',
      'image',
      'img_url',
      'pic_url',
      'path_full',
      'path_thumbnail',
      'pc_url',
      'mobile_url',
    ]) {
      final direct = _stringFrom(map[key]);
      if (direct.isNotEmpty) {
        return direct;
      }
      final nested = _urlFromAny(map[key]);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return '';
  }

  static List<String> _heyboxTags(Object? value) {
    final tags = <String>{};
    final items = value as List<Object?>? ?? const [];
    for (final item in items) {
      final map = _mapFrom(item);
      final desc = _stringFrom(map['desc']);
      if (desc.isNotEmpty) {
        tags.add(desc);
      }
      final descList = map['desc_list'] as List<Object?>? ?? const [];
      for (final descItem in descList) {
        final text = _stringFrom(descItem);
        if (text.isNotEmpty) {
          tags.add(text);
        }
      }
      final detailList = map['detail_list'] as List<Object?>? ?? const [];
      for (final detail in detailList) {
        final detailMap = _mapFrom(detail);
        final name = _stringFrom(detailMap['name']);
        final detailDesc = _stringFrom(detailMap['desc']);
        if (name.isNotEmpty && detailDesc.isNotEmpty) {
          tags.add('$name：$detailDesc');
        }
      }
    }
    return tags.take(16).toList();
  }

  static String _normalizeUrl(String url) {
    if (url.startsWith('http://')) {
      return 'https://${url.substring(7)}';
    }
    return url;
  }

  static List<String> _stringList(Object? value) {
    return [
      for (final item in value as List<Object?>? ?? const [])
        if (item is String) item,
    ];
  }

  static List<String> _descriptionList(Object? value) {
    final items = value as List<Object?>? ?? const [];
    return [
      for (final item in items)
        if (_mapFrom(item)['description'] case final String description)
          description,
    ];
  }

  static String _steamCdnUrl(int appId, String fileName) {
    return 'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/$fileName';
  }

  static String? _extractSteamId(String input) {
    if (_steamIdPattern.hasMatch(input)) {
      return input;
    }

    final uri = Uri.tryParse(input);
    final segments = uri?.pathSegments ?? const <String>[];
    final profilesIndex = segments.indexOf('profiles');
    if (profilesIndex >= 0 && segments.length > profilesIndex + 1) {
      final candidate = segments[profilesIndex + 1];
      if (_steamIdPattern.hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static String? _extractVanityName(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments;
      final idIndex = segments.indexOf('id');
      if (idIndex >= 0 && segments.length > idIndex + 1) {
        return segments[idIndex + 1];
      }
      return null;
    }

    if (input.contains('/') || input.contains(' ')) {
      return null;
    }
    return input;
  }
}

class _ReviewSummary {
  const _ReviewSummary({
    required this.scoreDescription,
    required this.percentPositive,
    required this.totalReviews,
  });

  final String scoreDescription;
  final int percentPositive;
  final int totalReviews;
}

class _HeyboxDetails {
  const _HeyboxDetails({
    required this.chineseName,
    required this.englishName,
    required this.iconUrl,
    required this.headerImageUrl,
    required this.imageUrls,
    required this.score,
    required this.scoreDescription,
    required this.followCount,
    required this.userCount,
    required this.tags,
    required this.priceCurrent,
    required this.priceInitial,
    required this.discountPercent,
    required this.lowestPrice,
    required this.lowestDiscount,
    required this.promoDeadline,
  });

  const _HeyboxDetails.empty()
    : chineseName = '',
      englishName = '',
      iconUrl = '',
      headerImageUrl = '',
      imageUrls = const [],
      score = '',
      scoreDescription = '',
      followCount = 0,
      userCount = 0,
      tags = const [],
      priceCurrent = '',
      priceInitial = '',
      discountPercent = 0,
      lowestPrice = '',
      lowestDiscount = 0,
      promoDeadline = '';

  final String chineseName;
  final String englishName;
  final String iconUrl;
  final String headerImageUrl;
  final List<String> imageUrls;
  final String score;
  final String scoreDescription;
  final int followCount;
  final int userCount;
  final List<String> tags;
  final String priceCurrent;
  final String priceInitial;
  final int discountPercent;
  final String lowestPrice;
  final int lowestDiscount;
  final String promoDeadline;

  factory _HeyboxDetails.fromJson(Map<String, Object?> json) {
    final price = SteamApiClient._mapFrom(json['price']);
    final iconUrl = SteamApiClient._stringFrom(json['appicon']);
    final headerImageUrl = SteamApiClient._stringFrom(json['image']);
    return _HeyboxDetails(
      chineseName: SteamApiClient._stringFrom(json['name']),
      englishName: SteamApiClient._stringFrom(json['name_en']),
      iconUrl: iconUrl,
      headerImageUrl: headerImageUrl,
      imageUrls: <String>{
        headerImageUrl,
        iconUrl,
        ...SteamApiClient._heyboxScreenshotUrls(json['screenshots']),
        SteamApiClient._stringFrom(json['share_img']),
      }.where((url) => url.trim().isNotEmpty).toList(),
      score: SteamApiClient._stringFrom(json['score']),
      scoreDescription: SteamApiClient._stringFrom(json['score_desc']),
      followCount: SteamApiClient._intFrom(
        json['follow_num'],
        fallback: SteamApiClient._parseCompactNumber(json['follow_num_str']),
      ),
      userCount: SteamApiClient._intFrom(json['user_num']),
      tags: SteamApiClient._heyboxTags(json['common_tags']),
      priceCurrent: SteamApiClient._formatYuan(price['current']),
      priceInitial: SteamApiClient._formatYuan(price['initial']),
      discountPercent: SteamApiClient._intFrom(price['discount']),
      lowestPrice: SteamApiClient._formatYuan(price['lowest_price']),
      lowestDiscount: SteamApiClient._intFrom(price['lowest_discount']),
      promoDeadline: SteamApiClient._stringFrom(
        price['deadline_date'] ?? price['deadline_timestamp'],
      ),
    );
  }
}

class SteamApiException implements Exception {
  const SteamApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
