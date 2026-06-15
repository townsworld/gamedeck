import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/game_library_entry.dart';
import '../models/game_metadata.dart';
import '../models/game_store_assets.dart';
import '../models/owned_game.dart';
import '../models/steam_account.dart';
import '../services/local_store.dart';
import '../services/steam_api_client.dart';

class AppController extends ChangeNotifier {
  AppController({
    GameDeckLocalStore? localStore,
    SteamApiClient? steamApiClient,
  }) : _localStore = localStore ?? LocalStore(),
       _steamApiClient = steamApiClient ?? SteamApiClient();

  final GameDeckLocalStore _localStore;
  final SteamApiClient _steamApiClient;

  String _apiKey = '';
  List<SteamAccount> _accounts = [];
  List<OwnedGame> _games = [];
  Map<int, GameMetadata> _gameMetadata = {};
  bool _autoSyncSteamEnabled = false;
  DateTime? _lastAutoSteamSyncAt;
  final Queue<_MetadataRequest> _metadataQueue = Queue();
  final Set<int> _queuedMetadataAppIds = {};
  final Set<String> _syncingAccountIds = {};
  bool _isInitialized = false;
  bool _isBusy = false;
  bool _isProcessingMetadataQueue = false;
  String? _errorMessage;

  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  UnmodifiableListView<SteamAccount> get accounts =>
      UnmodifiableListView(_accounts);
  UnmodifiableListView<OwnedGame> get games => UnmodifiableListView(_games);
  int get uniqueGameCount => _games.map((game) => game.appId).toSet().length;
  int get cachedMetadataCount =>
      _gameMetadata.values.where((metadata) => metadata.hasImages).length;
  int get pendingMetadataCount => _metadataQueue.length;
  bool get isCachingMetadata => _isProcessingMetadataQueue;
  bool get autoSyncSteamEnabled => _autoSyncSteamEnabled;
  DateTime? get lastAutoSteamSyncAt => _lastAutoSteamSyncAt;
  bool get hasIncompleteMetadataCache =>
      uniqueGameCount > 0 && cachedMetadataCount < uniqueGameCount;

  bool isSyncingAccount(String steamId) => _syncingAccountIds.contains(steamId);

  Future<void> initialize() async {
    _apiKey = await _localStore.loadApiKey();
    _accounts = await _localStore.loadAccounts();
    _games = await _localStore.loadGames();
    _gameMetadata = await _localStore.loadGameMetadata();
    _autoSyncSteamEnabled = await _localStore.loadAutoSyncSteamEnabled();
    _lastAutoSteamSyncAt = await _localStore.loadLastAutoSteamSyncAt();
    _isInitialized = true;
    notifyListeners();
    Future<void>(_autoSyncSteamIfNeeded);
  }

  Future<void> saveApiKey(String apiKey) async {
    _apiKey = apiKey.trim();
    await _localStore.saveApiKey(_apiKey);
    notifyListeners();
  }

  Future<void> setAutoSyncSteamEnabled(bool enabled) async {
    _autoSyncSteamEnabled = enabled;
    await _localStore.saveAutoSyncSteamEnabled(enabled);
    notifyListeners();
    if (enabled) {
      await _autoSyncSteamIfNeeded();
    }
  }

  Future<void> addAccount(String input) async {
    await _runBusyAction(() async {
      _requireApiKey();
      final steamId = await _steamApiClient.resolveSteamId(
        apiKey: _apiKey,
        input: input,
      );
      if (_accounts.any((account) => account.steamId == steamId)) {
        throw const AppActionException('这个账号已经添加过了。');
      }

      final account = await _fetchAccountWithGames(steamId);
      _accounts = [..._accounts, account.account];
      _games = [
        ..._games.where((game) => game.steamId != steamId),
        ...account.games,
      ];
      await _persistLibrary();
    });
  }

  Future<void> syncAccount(String steamId) async {
    _requireApiKey();
    _syncingAccountIds.add(steamId);
    _errorMessage = null;
    notifyListeners();

    try {
      final synced = await _fetchAccountWithGames(steamId);
      _replaceAccount(synced.account);
      _games = [
        ..._games.where((game) => game.steamId != steamId),
        ...synced.games,
      ];
      await _persistLibrary();
    } on Object catch (error) {
      _replaceAccount(
        _accountById(steamId).copyWith(lastError: _messageFor(error)),
      );
      await _localStore.saveAccounts(_accounts);
    } finally {
      _syncingAccountIds.remove(steamId);
      notifyListeners();
    }
  }

  Future<void> syncAllAccounts() async {
    if (_accounts.isEmpty) {
      return;
    }
    await _runBusyAction(() async {
      _requireApiKey();
      await _syncAllAccountsInternal();
    });
  }

  Future<void> refreshAllData() async {
    if (_accounts.isEmpty) {
      return;
    }
    await _runBusyAction(() async {
      _requireApiKey();
      await _syncAllAccountsInternal();
      refreshAllMetadata();
    });
  }

  void refreshAllMetadata() {
    _refreshAllMetadata(_MetadataRefreshType.full);
  }

  void refreshHeyboxMetadata() {
    _refreshAllMetadata(_MetadataRefreshType.heybox);
  }

  Future<GameMetadata> refreshGameMetadata(int appId) {
    return _fetchGameMetadata(
      appId,
      force: true,
      type: _MetadataRefreshType.full,
    );
  }

  Future<GameMetadata> refreshGameSteamMetadata(int appId) {
    return _fetchGameMetadata(
      appId,
      force: true,
      type: _MetadataRefreshType.steamStore,
    );
  }

  Future<GameMetadata> refreshGameHeyboxMetadata(int appId) {
    return _fetchGameMetadata(
      appId,
      force: true,
      type: _MetadataRefreshType.heybox,
    );
  }

  void _refreshAllMetadata(_MetadataRefreshType type) {
    final appIds = _games.map((game) => game.appId).toSet();
    _enqueueMetadataRefresh(appIds, force: true, type: type);
  }

  Future<void> _syncAllAccountsInternal() async {
    final failures = <String>[];
    for (final account in List<SteamAccount>.from(_accounts)) {
      try {
        final synced = await _fetchAccountWithGames(account.steamId);
        _replaceAccount(synced.account, notify: false);
        _games = [
          ..._games.where((game) => game.steamId != account.steamId),
          ...synced.games,
        ];
      } on Object catch (error) {
        failures.add('${account.personaName}: ${_messageFor(error)}');
        _replaceAccount(
          account.copyWith(lastError: _messageFor(error)),
          notify: false,
        );
      }
    }
    await _persistLibrary();
    if (failures.isNotEmpty) {
      throw AppActionException('部分账号同步失败：${failures.join('；')}');
    }
  }

  Future<void> _autoSyncSteamIfNeeded() async {
    if (!_autoSyncSteamEnabled || !hasApiKey || _accounts.isEmpty || _isBusy) {
      return;
    }
    final last = _lastAutoSteamSyncAt?.toLocal();
    final now = DateTime.now();
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return;
    }
    try {
      await syncAllAccounts();
      _lastAutoSteamSyncAt = DateTime.now();
      await _localStore.saveLastAutoSteamSyncAt(_lastAutoSteamSyncAt!);
      notifyListeners();
    } on Object {
      // 自动同步不打断启动流程，失败信息会记录在账号或全局错误中。
    }
  }

  Future<void> deleteAccount(String steamId) async {
    _accounts = [
      for (final account in _accounts)
        if (account.steamId != steamId) account,
    ];
    _games = [
      for (final game in _games)
        if (game.steamId != steamId) game,
    ];
    await _persistLibrary();
    notifyListeners();
  }

  Future<void> clearCachedData() async {
    _accounts = [];
    _games = [];
    _gameMetadata = {};
    await _localStore.clearCachedData();
    notifyListeners();
  }

  Future<GameMetadata> fetchGameMetadata(
    int appId, {
    bool force = false,
  }) async {
    return _fetchGameMetadata(
      appId,
      force: force,
      type: _MetadataRefreshType.full,
    );
  }

  Future<GameMetadata> _fetchGameMetadata(
    int appId, {
    required bool force,
    required _MetadataRefreshType type,
  }) async {
    final cached = _gameMetadata[appId];
    if (!force && cached != null && !_shouldRefreshMetadata(cached)) {
      return cached;
    }

    try {
      final assets = await switch (type) {
        _MetadataRefreshType.full => _steamApiClient.fetchGameStoreAssets(
          appId,
        ),
        _MetadataRefreshType.steamStore =>
          _steamApiClient.fetchSteamStoreAssets(appId),
        _MetadataRefreshType.heybox => _steamApiClient.fetchHeyboxStoreAssets(
          appId,
        ),
      };
      final metadata = _metadataFromAssets(assets, cached: cached, type: type);
      _gameMetadata = {..._gameMetadata, appId: metadata};
      await _localStore.saveGameMetadata(_gameMetadata);
      notifyListeners();
      return metadata;
    } on Object catch (error) {
      final failed = (cached ?? GameMetadata.empty(appId)).copyWithFailure(
        _messageFor(error),
      );
      _gameMetadata = {..._gameMetadata, appId: failed};
      await _localStore.saveGameMetadata(_gameMetadata);
      notifyListeners();
      return failed;
    }
  }

  void ensureGameMetadata(int appId) {
    final cached = _gameMetadata[appId];
    if (cached != null && !_shouldRefreshMetadata(cached)) {
      return;
    }
    _enqueueMetadataRefresh([appId]);
  }

  void _enqueueMetadataRefresh(
    Iterable<int> appIds, {
    bool force = false,
    _MetadataRefreshType type = _MetadataRefreshType.full,
  }) {
    for (final appId in appIds.toSet()) {
      if (_queuedMetadataAppIds.contains(appId)) {
        continue;
      }
      final cached = _gameMetadata[appId];
      if (!force && cached != null && !_shouldRefreshMetadata(cached)) {
        continue;
      }
      _metadataQueue.add(
        _MetadataRequest(appId: appId, force: force, type: type),
      );
      _queuedMetadataAppIds.add(appId);
    }
    _processMetadataQueue();
  }

  void resumeMetadataCache() {
    final missingAppIds = _games
        .map((game) => game.appId)
        .toSet()
        .where((appId) => !(_gameMetadata[appId]?.hasImages ?? false));
    _enqueueMetadataRefresh(missingAppIds, force: true);
  }

  List<GameLibraryEntry> libraryEntries({
    String query = '',
    String? steamId,
    AccountFilter accountFilter = AccountFilter.all,
    LibrarySort sort = LibrarySort.lastPlayed,
  }) {
    final accountsById = {
      for (final account in _accounts) account.steamId: account,
    };
    final normalizedQuery = query.trim().toLowerCase();
    final grouped = <int, List<GameOwnership>>{};

    for (final game in _games) {
      if (steamId != null && game.steamId != steamId) {
        continue;
      }
      if (normalizedQuery.isNotEmpty) {
        final metadata = _gameMetadata[game.appId];
        final metadataSearchText =
            '${metadata?.chineseName ?? ''} '
                    '${metadata?.englishName ?? ''} '
                    '${metadata == null ? '' : metadata.heyboxTags.join(' ')}'
                .toLowerCase();
        if (!game.searchText.contains(normalizedQuery) &&
            !metadataSearchText.contains(normalizedQuery)) {
          continue;
        }
      }
      final account = accountsById[game.steamId];
      if (account == null) {
        continue;
      }
      grouped
          .putIfAbsent(game.appId, () => [])
          .add(GameOwnership(account: account, ownedGame: game));
    }

    final entries =
        [
          for (final entry in grouped.entries)
            _libraryEntryFromOwnerships(entry.key, entry.value),
        ].where((entry) {
          return switch (accountFilter) {
            AccountFilter.all => true,
            AccountFilter.multiOwned => entry.ownerCount > 1,
            AccountFilter.singleOwned => entry.ownerCount == 1,
          };
        }).toList();

    entries.sort((left, right) {
      return switch (sort) {
        LibrarySort.lastPlayed => _compareLastPlayed(left, right),
        LibrarySort.name => left.name.compareTo(right.name),
        LibrarySort.totalPlaytime => right.totalPlaytimeMinutes.compareTo(
          left.totalPlaytimeMinutes,
        ),
        LibrarySort.ownerCount => right.ownerCount.compareTo(left.ownerCount),
        LibrarySort.recentlySynced => _latestSync(
          right,
        ).compareTo(_latestSync(left)),
      };
    });
    return entries;
  }

  static int _compareLastPlayed(GameLibraryEntry left, GameLibraryEntry right) {
    final lastPlayedCompare = right.lastPlayedAt.compareTo(left.lastPlayedAt);
    if (lastPlayedCompare != 0) {
      return lastPlayedCompare;
    }
    return right.totalPlaytimeMinutes.compareTo(left.totalPlaytimeMinutes);
  }

  SteamAccount _accountById(String steamId) {
    return _accounts.firstWhere((account) => account.steamId == steamId);
  }

  void _replaceAccount(SteamAccount updated, {bool notify = true}) {
    _accounts = [
      for (final account in _accounts)
        if (account.steamId == updated.steamId) updated else account,
    ];
    if (notify) {
      notifyListeners();
    }
  }

  Future<_SyncedAccount> _fetchAccountWithGames(String steamId) async {
    final summary = await _steamApiClient.fetchPlayerSummary(
      apiKey: _apiKey,
      steamId: steamId,
    );
    final games = await _steamApiClient.fetchOwnedGames(
      apiKey: _apiKey,
      steamId: steamId,
    );
    final totalPlaytime = games.fold(
      0,
      (total, game) => total + game.playtimeForeverMinutes,
    );

    return _SyncedAccount(
      account: summary.copyWith(
        gameCount: games.length,
        totalPlaytimeMinutes: totalPlaytime,
        lastSyncedAt: DateTime.now(),
        clearLastError: true,
      ),
      games: games,
    );
  }

  Future<void> _persistLibrary() async {
    await _localStore.saveAccounts(_accounts);
    await _localStore.saveGames(_games);
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } on Object catch (error) {
      _errorMessage = _messageFor(error);
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _requireApiKey() {
    if (!hasApiKey) {
      throw const AppActionException('需要先在设置里配置 Steam Web API Key。');
    }
  }

  GameLibraryEntry _libraryEntryFromOwnerships(
    int appId,
    List<GameOwnership> ownerships,
  ) {
    ownerships.sort(
      (left, right) => right.ownedGame.playtimeForeverMinutes.compareTo(
        left.ownedGame.playtimeForeverMinutes,
      ),
    );
    final firstWithHeader = ownerships.firstWhere(
      (ownership) => ownership.ownedGame.headerUrl.isNotEmpty,
      orElse: () => ownerships.first,
    );
    final firstWithCapsule = ownerships.firstWhere(
      (ownership) => ownership.ownedGame.capsuleUrl.isNotEmpty,
      orElse: () => ownerships.first,
    );
    final metadata = _gameMetadata[appId];
    final metadataChineseName = metadata?.chineseName ?? '';
    final metadataEnglishName = metadata?.englishName ?? '';
    final metadataHeaderUrl = metadata?.headerImageUrl ?? '';
    final metadataCapsuleUrl = metadata?.capsuleImageUrl ?? '';
    final fallbackName = ownerships.first.ownedGame.displayName;
    return GameLibraryEntry(
      appId: appId,
      name: metadataChineseName.isNotEmpty ? metadataChineseName : fallbackName,
      englishName: metadataEnglishName.isNotEmpty
          ? metadataEnglishName
          : ownerships.first.ownedGame.englishName,
      chineseName: metadataChineseName.isNotEmpty
          ? metadataChineseName
          : ownerships.first.ownedGame.chineseName,
      iconUrl: metadataHeaderUrl.isNotEmpty
          ? metadataHeaderUrl
          : firstWithHeader.ownedGame.headerUrl,
      headerUrl: metadataHeaderUrl.isNotEmpty
          ? metadataHeaderUrl
          : firstWithHeader.ownedGame.headerUrl,
      capsuleUrl: metadataCapsuleUrl.isNotEmpty
          ? metadataCapsuleUrl
          : firstWithCapsule.ownedGame.capsuleUrl,
      imageUrls: metadata?.imageUrls ?? const [],
      priceLabel: metadata?.priceLabel ?? '',
      originalPriceLabel: metadata?.priceInitialFormatted ?? '',
      discountPercent: metadata?.discountPercent ?? 0,
      reviewScoreDesc: metadata?.reviewScoreDesc ?? '',
      reviewPercent: metadata?.reviewPercent ?? 0,
      reviewCount: metadata?.reviewCount ?? 0,
      heyboxScore: metadata?.heyboxScore ?? '',
      heyboxPriceCurrent: metadata?.heyboxPriceCurrent ?? '',
      heyboxLowestPrice: metadata?.heyboxLowestPrice ?? '',
      heyboxLowestDiscount: metadata?.heyboxLowestDiscount ?? 0,
      ownedCopies: ownerships,
    );
  }

  static DateTime _latestSync(GameLibraryEntry entry) {
    return entry.ownedCopies
        .map((ownership) => ownership.ownedGame.lastSyncedAt)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }

  static String _messageFor(Object error) {
    if (error is SteamApiException) {
      return error.message;
    }
    if (error is AppActionException) {
      return error.message;
    }
    return '操作失败：$error';
  }

  Future<void> _processMetadataQueue() async {
    if (_isProcessingMetadataQueue) {
      return;
    }
    _isProcessingMetadataQueue = true;
    notifyListeners();
    try {
      while (_metadataQueue.isNotEmpty) {
        final request = _metadataQueue.removeFirst();
        _queuedMetadataAppIds.remove(request.appId);
        await _fetchGameMetadata(
          request.appId,
          force: request.force,
          type: request.type,
        );
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } finally {
      _isProcessingMetadataQueue = false;
      notifyListeners();
    }
  }

  static bool _shouldRefreshMetadata(GameMetadata metadata) {
    final now = DateTime.now();
    if (metadata.schemaVersion < 4) {
      return true;
    }
    final lastFailedAt = metadata.lastFailedAt;
    if (lastFailedAt != null && now.difference(lastFailedAt).inHours < 24) {
      return false;
    }
    if (metadata.lastFetchedAt.millisecondsSinceEpoch == 0) {
      return true;
    }
    if (!metadata.hasStoreInfo) {
      return true;
    }
    return now.difference(metadata.lastFetchedAt).inDays >= 30;
  }

  static GameMetadata _metadataFromAssets(
    GameStoreAssets assets, {
    required GameMetadata? cached,
    required _MetadataRefreshType type,
  }) {
    final keepHeybox = type == _MetadataRefreshType.steamStore;
    final keepSteam = type == _MetadataRefreshType.heybox;
    final keepCachedHeybox =
        keepHeybox ||
        (type == _MetadataRefreshType.heybox && !_hasHeyboxData(assets));
    final headerImageUrl = keepSteam
        ? _firstNonEmpty(assets.headerImageUrl, cached?.headerImageUrl ?? '')
        : assets.headerImageUrl;
    final capsuleImageUrl = keepSteam
        ? _firstNonEmpty(assets.capsuleImageUrl, cached?.capsuleImageUrl ?? '')
        : assets.capsuleImageUrl;
    return GameMetadata(
      schemaVersion: 4,
      appId: assets.appId,
      chineseName: _firstNonEmpty(
        assets.chineseName,
        cached?.chineseName ?? '',
      ),
      englishName: _firstNonEmpty(
        assets.englishName,
        cached?.englishName ?? '',
      ),
      headerImageUrl: headerImageUrl,
      capsuleImageUrl: capsuleImageUrl,
      screenshotUrls: _mergedScreenshotUrls(
        assets: assets,
        cached: cached,
        headerImageUrl: headerImageUrl,
        capsuleImageUrl: capsuleImageUrl,
        mergeWithCached: keepSteam,
      ),
      isFree: keepSteam ? cached?.isFree ?? false : assets.isFree,
      priceInitialFormatted: keepSteam
          ? cached?.priceInitialFormatted ?? ''
          : assets.priceInitialFormatted,
      priceFinalFormatted: keepSteam
          ? cached?.priceFinalFormatted ?? ''
          : assets.priceFinalFormatted,
      discountPercent: keepSteam
          ? cached?.discountPercent ?? 0
          : assets.discountPercent,
      reviewScoreDesc: keepSteam
          ? cached?.reviewScoreDesc ?? ''
          : assets.reviewScoreDesc,
      reviewPercent: keepSteam
          ? cached?.reviewPercent ?? 0
          : assets.reviewPercent,
      reviewCount: keepSteam ? cached?.reviewCount ?? 0 : assets.reviewCount,
      heyboxScore: keepCachedHeybox
          ? cached?.heyboxScore ?? ''
          : assets.heyboxScore,
      heyboxScoreDesc: keepCachedHeybox
          ? cached?.heyboxScoreDesc ?? ''
          : assets.heyboxScoreDesc,
      heyboxFollowCount: keepCachedHeybox
          ? cached?.heyboxFollowCount ?? 0
          : assets.heyboxFollowCount,
      heyboxUserCount: keepCachedHeybox
          ? cached?.heyboxUserCount ?? 0
          : assets.heyboxUserCount,
      heyboxTags: keepCachedHeybox
          ? cached?.heyboxTags ?? const []
          : assets.heyboxTags,
      heyboxPriceCurrent: keepCachedHeybox
          ? cached?.heyboxPriceCurrent ?? ''
          : assets.heyboxPriceCurrent,
      heyboxPriceInitial: keepCachedHeybox
          ? cached?.heyboxPriceInitial ?? ''
          : assets.heyboxPriceInitial,
      heyboxDiscountPercent: keepCachedHeybox
          ? cached?.heyboxDiscountPercent ?? 0
          : assets.heyboxDiscountPercent,
      heyboxLowestPrice: keepCachedHeybox
          ? cached?.heyboxLowestPrice ?? ''
          : assets.heyboxLowestPrice,
      heyboxLowestDiscount: keepCachedHeybox
          ? cached?.heyboxLowestDiscount ?? 0
          : assets.heyboxLowestDiscount,
      heyboxPromoDeadline: keepCachedHeybox
          ? cached?.heyboxPromoDeadline ?? ''
          : assets.heyboxPromoDeadline,
      releaseDate: keepSteam ? cached?.releaseDate ?? '' : assets.releaseDate,
      developers: keepSteam
          ? cached?.developers ?? const []
          : assets.developers,
      publishers: keepSteam
          ? cached?.publishers ?? const []
          : assets.publishers,
      genres: keepSteam ? cached?.genres ?? const [] : assets.genres,
      categories: keepSteam
          ? cached?.categories ?? const []
          : assets.categories,
      supportsWindows: keepSteam
          ? cached?.supportsWindows ?? false
          : assets.supportsWindows,
      supportsMac: keepSteam
          ? cached?.supportsMac ?? false
          : assets.supportsMac,
      supportsLinux: keepSteam
          ? cached?.supportsLinux ?? false
          : assets.supportsLinux,
      achievementCount: keepSteam
          ? cached?.achievementCount ?? 0
          : assets.achievementCount,
      recommendationCount: keepSteam
          ? cached?.recommendationCount ?? 0
          : assets.recommendationCount,
      shortDescription: keepSteam
          ? cached?.shortDescription ?? ''
          : assets.shortDescription,
      metacriticScore: keepSteam
          ? cached?.metacriticScore
          : assets.metacriticScore,
      lastFetchedAt: DateTime.now(),
    );
  }

  static String _firstNonEmpty(String preferred, String fallback) {
    return preferred.trim().isNotEmpty ? preferred : fallback;
  }

  static bool _hasHeyboxData(GameStoreAssets assets) {
    return assets.heyboxScore.isNotEmpty ||
        assets.heyboxPriceCurrent.isNotEmpty ||
        assets.heyboxLowestPrice.isNotEmpty ||
        assets.heyboxTags.isNotEmpty ||
        assets.chineseName.isNotEmpty ||
        assets.headerImageUrl.isNotEmpty ||
        assets.imageUrls.isNotEmpty;
  }

  static List<String> _mergedScreenshotUrls({
    required GameStoreAssets assets,
    required GameMetadata? cached,
    required String headerImageUrl,
    required String capsuleImageUrl,
    required bool mergeWithCached,
  }) {
    final urls = <String>{
      if (mergeWithCached) ...?cached?.screenshotUrls,
      ...assets.imageUrls,
    };
    urls.removeWhere(
      (url) =>
          url.trim().isEmpty || url == headerImageUrl || url == capsuleImageUrl,
    );
    return urls.toList();
  }
}

class AppActionException implements Exception {
  const AppActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _SyncedAccount {
  const _SyncedAccount({required this.account, required this.games});

  final SteamAccount account;
  final List<OwnedGame> games;
}

class _MetadataRequest {
  const _MetadataRequest({
    required this.appId,
    required this.force,
    required this.type,
  });

  final int appId;
  final bool force;
  final _MetadataRefreshType type;
}

enum _MetadataRefreshType { full, steamStore, heybox }
