import 'package:flutter_test/flutter_test.dart';
import 'package:gamedeck/main.dart';
import 'package:gamedeck/models/game_metadata.dart';
import 'package:gamedeck/models/owned_game.dart';
import 'package:gamedeck/models/steam_account.dart';
import 'package:gamedeck/services/local_store.dart';
import 'package:gamedeck/state/app_controller.dart';

void main() {
  testWidgets('renders app shell with primary tabs', (tester) async {
    final controller = AppController(localStore: _MemoryLocalStore());

    await tester.pumpWidget(GameDeckApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('GameDeck'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('游戏库'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('需要配置 Steam API Key'), findsOneWidget);
  });
}

class _MemoryLocalStore implements GameDeckLocalStore {
  String _apiKey = '';
  List<SteamAccount> _accounts = [];
  List<OwnedGame> _games = [];
  Map<int, GameMetadata> _metadata = {};
  bool _autoSyncSteamEnabled = false;
  DateTime? _lastAutoSteamSyncAt;

  @override
  Future<String> loadApiKey() async => _apiKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    _apiKey = apiKey;
  }

  @override
  Future<List<SteamAccount>> loadAccounts() async => _accounts;

  @override
  Future<void> saveAccounts(List<SteamAccount> accounts) async {
    _accounts = accounts;
  }

  @override
  Future<List<OwnedGame>> loadGames() async => _games;

  @override
  Future<void> saveGames(List<OwnedGame> games) async {
    _games = games;
  }

  @override
  Future<Map<int, GameMetadata>> loadGameMetadata() async => _metadata;

  @override
  Future<void> saveGameMetadata(Map<int, GameMetadata> metadata) async {
    _metadata = metadata;
  }

  @override
  Future<bool> loadAutoSyncSteamEnabled() async => _autoSyncSteamEnabled;

  @override
  Future<void> saveAutoSyncSteamEnabled(bool enabled) async {
    _autoSyncSteamEnabled = enabled;
  }

  @override
  Future<DateTime?> loadLastAutoSteamSyncAt() async => _lastAutoSteamSyncAt;

  @override
  Future<void> saveLastAutoSteamSyncAt(DateTime value) async {
    _lastAutoSteamSyncAt = value;
  }

  @override
  Future<void> clearCachedData() async {
    _accounts = [];
    _games = [];
    _metadata = {};
  }
}
