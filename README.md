# GameDeck

[简体中文](README.zh-CN.md)

GameDeck is a read-only Android app for managing multiple Steam libraries in one place. It focuses on account aggregation, game search, playtime insights, store metadata, Chinese game names, and local-first caching.

The app does not perform purchases, trades, account changes, or any Steam store operations.

## Features

- Add multiple Steam accounts by SteamID64 or profile URL.
- Browse a merged Steam library across all configured accounts.
- Search games by Chinese name, English name, and tags.
- Sort by last played time, total playtime, name, owner count, or sync time.
- View recent games, most-played games, duplicate ownership, and unplayed totals.
- Read Steam metadata including prices, discounts, reviews, screenshots, banners, release date, developers, publishers, genres, platforms, and achievements.
- Enrich games with Xiaoheihe metadata, including Chinese names, scores, prices, historical lows, tags, followers, and screenshots.
- Refresh Steam data, full metadata, or Xiaoheihe data separately from the sync center.
- Refresh individual game details from the game detail page.
- Store the Steam Web API key and cache data locally on the device.

## Screens

- **Accounts**: account list, library overview, recent games, most-played games, and sync center.
- **Library**: searchable and filterable merged game library.
- **Game Details**: store information, ratings, prices, screenshots, owner accounts, playtime, and quick external links.
- **Settings**: Steam Web API key, daily Steam auto-sync, and local cache cleanup.

## Data Sources

GameDeck combines data from:

- Steam Web API
  - Account profile
  - Owned games
  - Total playtime
  - Last played time
- Steam Store endpoints
  - Store metadata
  - Prices and discounts
  - Reviews
  - Screenshots and banners
- Xiaoheihe web API
  - Chinese names
  - Xiaoheihe score
  - Localized prices
  - Historical low price
  - Tags and screenshots

## Privacy

- The Steam Web API key is stored locally.
- Account and game cache data is stored locally.
- GameDeck is designed as a read-only client.
- No purchase, trade, wishlist, review, or account mutation operation is implemented.

## Requirements

- Flutter SDK
- Android SDK
- Android device or emulator
- Steam Web API key

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

Install on a connected Android device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Package

Android package name:

```text
com.towns.gamedeck
```

## Status

GameDeck is an early personal Android-first project. The current version focuses on local Steam library management and metadata aggregation.
