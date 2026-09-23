/// Optional Supabase backend (hybrid mode).
///
/// - Offline by default: every method is a safe no-op returning null/false
///   when credentials are missing or the network fails.
/// - Enable with --dart-define SUPABASE_URL / SUPABASE_ANON_KEY (see
///   docs/SUPABASE_SETUP.md and supabase/schema.sql).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

class SupabaseService {
  static bool _ready = false;
  static String _status = 'offline';

  static bool get isReady => _ready;
  static String get status => _status; // offline | online | error

  static SupabaseClient? get client =>
      _ready ? Supabase.instance.client : null;

  static Future<void> init() async {
    if (!AppConfig.supabaseEnabled) {
      _ready = false;
      _status = 'offline';
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // `anonKey` is deprecated in supabase_flutter 2.17 → publishableKey.
        publishableKey: AppConfig.supabaseAnonKey,
      );
      // Connection probe (table created by supabase/schema.sql).
      await Supabase.instance.client
          .from('profiles')
          .select('id')
          .limit(1);
      _ready = true;
      _status = 'online';
    } catch (_) {
      _ready = false;
      _status = 'error';
    }
  }

  /// Global leaderboard rows: {name, flag, rating}.
  static Future<List<Map<String, dynamic>>?> fetchRankings({
    int limit = 50,
  }) async {
    final c = client;
    if (c == null) return null;
    try {
      final rows = await c
          .from('profiles')
          .select('name, flag, rating')
          .order('rating', ascending: false)
          .limit(limit);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> upsertProfile({
    required String id,
    required String name,
    required String flag,
    required int rating,
    required int coins,
  }) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from('profiles').upsert({
        'id': id,
        'name': name,
        'flag': flag,
        'rating': rating,
        'coins': coins,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveGame(Map<String, Object?> record) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from('games').insert({
        'player_id': record['playerId'],
        'opponent': record['opponent'],
        'opponent_rating': record['opponentRating'],
        'my_color': record['myColor'],
        'result': record['result'],
        'rating_before': record['ratingBefore'],
        'rating_after': record['ratingAfter'],
        'moves': (record['sans'] as List?)?.join(' '),
        'time_control': record['timeControl'],
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
