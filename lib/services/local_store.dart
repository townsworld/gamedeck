import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_metadata.dart';
import '../models/owned_game.dart';
import '../models/steam_account.dart';

abstract class GameDeckLocalStore {
  Future<String> loadApiKey();

  Future<void> saveApiKey(String apiKey);

  Future<List<SteamAccount>> loadAccounts();

  Future<void> saveAccounts(List<SteamAccount> accounts);

  Future<List<OwnedGame>> loadGames();

  Future<void> saveGames(List<OwnedGame> games);

  Future<Map<int, GameMetadata>> loadGameMetadata();

  Future<void> saveGameMetadata(Map<int, GameMetadata> metadata);

  Future<bool> loadAutoSyncSteamEnabled();

  Future<void> saveAutoSyncSteamEnabled(bool enabled);

  Future<DateTime?> loadLastAutoSteamSyncAt();

  Future<void> saveLastAutoSteamSyncAt(DateTime value);

  Future<void> clearCachedData();
}

class LocalStore implements GameDeckLocalStore {
  LocalStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync();

  static const _apiKeyKey = 'steam_api_key';
  static const _accountsKey = 'steam_accounts';
  static const _gamesKey = 'owned_games';
  static const _gameMetadataKey = 'game_metadata';
  static const _autoSyncSteamEnabledKey = 'auto_sync_steam_enabled';
  static const _lastAutoSteamSyncAtKey = 'last_auto_steam_sync_at';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;

  @override
  Future<String> loadApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey) ?? '';
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: _apiKeyKey);
      return;
    }
    await _secureStorage.write(key: _apiKeyKey, value: trimmed);
  }

  @override
  Future<List<SteamAccount>> loadAccounts() async {
    final raw = await _preferences.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return [];
    }
    return [
      for (final item in decoded)
        if (item is Map) SteamAccount.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> saveAccounts(List<SteamAccount> accounts) async {
    await _preferences.setString(
      _accountsKey,
      jsonEncode([for (final account in accounts) account.toJson()]),
    );
  }

  @override
  Future<List<OwnedGame>> loadGames() async {
    final raw = await _preferences.getString(_gamesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return [];
    }
    return [
      for (final item in decoded)
        if (item is Map) OwnedGame.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> saveGames(List<OwnedGame> games) async {
    await _preferences.setString(
      _gamesKey,
      jsonEncode([for (final game in games) game.toJson()]),
    );
  }

  @override
  Future<Map<int, GameMetadata>> loadGameMetadata() async {
    final raw = await _preferences.getString(_gameMetadataKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return {};
    }
    final metadata = <int, GameMetadata>{};
    for (final item in decoded) {
      if (item is Map) {
        final entry = GameMetadata.fromJson(Map<String, Object?>.from(item));
        metadata[entry.appId] = entry;
      }
    }
    return metadata;
  }

  @override
  Future<void> saveGameMetadata(Map<int, GameMetadata> metadata) async {
    await _preferences.setString(
      _gameMetadataKey,
      jsonEncode([for (final entry in metadata.values) entry.toJson()]),
    );
  }

  @override
  Future<bool> loadAutoSyncSteamEnabled() async {
    return await _preferences.getBool(_autoSyncSteamEnabledKey) ?? false;
  }

  @override
  Future<void> saveAutoSyncSteamEnabled(bool enabled) async {
    await _preferences.setBool(_autoSyncSteamEnabledKey, enabled);
  }

  @override
  Future<DateTime?> loadLastAutoSteamSyncAt() async {
    final raw = await _preferences.getString(_lastAutoSteamSyncAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> saveLastAutoSteamSyncAt(DateTime value) async {
    await _preferences.setString(
      _lastAutoSteamSyncAtKey,
      value.toIso8601String(),
    );
  }

  @override
  Future<void> clearCachedData() async {
    await _preferences.remove(_accountsKey);
    await _preferences.remove(_gamesKey);
    await _preferences.remove(_gameMetadataKey);
  }
}
