/// Hive local persistence (offline-first store).
///
/// Boxes store plain Maps (no codegen adapters needed):
/// - profile: guest identity, rating, coins, stats, streaks, missions
/// - settings: board/UI toggles (mirrors the in-game Settings dialog)
/// - games: recent game records (cap 100)
/// - puzzles: solved puzzle ids + daily progress
library;

import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/config/app_config.dart';

class Database {
  static late Box _profile;
  static late Box _settings;
  static late Box _games;
  static late Box _puzzles;
  static bool _open = false;

  static Future<void> init() async {
    if (_open) return;
    await Hive.initFlutter();
    _profile = await Hive.openBox('chess_arena_profile');
    _settings = await Hive.openBox('chess_arena_settings');
    _games = await Hive.openBox('chess_arena_games');
    _puzzles = await Hive.openBox('chess_arena_puzzles');
    _ensureDefaults();
    _open = true;
  }

  static void _ensureDefaults() {
    if (!_profile.containsKey('guestId')) {
      final id = 1000000 + Random().nextInt(9000000);
      _profile.putAll({
        'guestId': id,
        'name': 'Guest$id',
        'rating': AppConfig.startingRating,
        'coins': AppConfig.startingCoins,
        'games': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'form': <String>[], // last results: 'w' | 'd' | 'l'
        'streak': 0,
        'lastDailyGame': '',
        'missionGamesPlayed': 0,
        'missionClaimed': true,
        'timeControls': <String>['blitz53'],
        'flagCode': 'us',
        'puzzlesSolved': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
    const settingsDefaults = {
      'sound': true,
      'showLastMove': true,
      'pieceAnimation': true,
      'showMoveHelp': true,
      'confirmMoves': false,
      'autoQueen': true,
      'showChat': true,
    };
    for (final e in settingsDefaults.entries) {
      if (!_settings.containsKey(e.key)) _settings.put(e.key, e.value);
    }
    if (!_puzzles.containsKey('solved')) {
      _puzzles.put('solved', <int>[]);
    }
    if (!_puzzles.containsKey('dailySolvedDate')) {
      _puzzles.put('dailySolvedDate', '');
    }
  }

  // ---- profile ----
  static T profile<T>(String key, T fallback) {
    final v = _profile.get(key, defaultValue: fallback);
    return v is T ? v : fallback;
  }

  /// Hive deserializes lists as List<dynamic> — read string lists safely.
  static List<String> profileStrings(String key) {
    final v = _profile.get(key, defaultValue: <String>[]);
    if (v is List) return v.map((e) => '$e').toList();
    return <String>[];
  }

  static Future<void> setProfile(String key, Object? value) =>
      _profile.put(key, value);

  // ---- settings ----
  static T setting<T>(String key, T fallback) =>
      (_settings.get(key, defaultValue: fallback) as T?) ?? fallback;
  static Future<void> setSetting(String key, Object? value) =>
      _settings.put(key, value);

  // ---- games ----
  static Future<void> addGame(Map<String, Object?> record) async {
    await _games.add(record);
    if (_games.length > 100) {
      await _games.deleteAt(0);
    }
  }

  static List<Map<String, Object?>> recentGames({int limit = 20}) {
    final out = <Map<String, Object?>>[];
    for (var i = _games.length - 1; i >= 0 && out.length < limit; i--) {
      final v = _games.getAt(i);
      if (v is Map) out.add(v.cast<String, Object?>());
    }
    return out;
  }

  // ---- puzzles ----
  static List<int> solvedPuzzles() {
    final v = _puzzles.get('solved', defaultValue: <int>[]);
    if (v is List) return v.whereType<int>().toList();
    return <int>[];
  }

  static Future<void> markPuzzleSolved(int id) async {
    final s = solvedPuzzles();
    if (!s.contains(id)) {
      s.add(id);
      await _puzzles.put('solved', s);
    }
  }

  static String dailySolvedDate() =>
      _puzzles.get('dailySolvedDate', defaultValue: '') as String;
  static Future<void> setDailySolvedDate(String ymd) =>
      _puzzles.put('dailySolvedDate', ymd);
}
