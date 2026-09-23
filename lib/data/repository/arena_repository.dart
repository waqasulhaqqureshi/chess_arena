/// Hybrid data facade: Hive first, Supabase sync when online.
///
/// All game screens read profile/rankings/coins through here so the future
/// online migration touches only this file + [SupabaseService].
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/utils/elo.dart';
import '../../services/matchmaking_service.dart';
import '../../services/sound_service.dart';
import '../local/database.dart';
import '../remote/supabase_service.dart';

String _todayYmd() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

class RankingEntry {
  final String name;
  final String flag; // emoji flag
  final int rating;
  final bool isPlayer;
  const RankingEntry({
    required this.name,
    required this.flag,
    required this.rating,
    this.isPlayer = false,
  });
}

class ArenaRepository extends ChangeNotifier {
  final Random _rng = Random();

  String name = '';
  int rating = 1200;
  int coins = 0;
  int games = 0, wins = 0, draws = 0, losses = 0;
  List<String> form = [];
  int streak = 0;
  int puzzlesSolved = 0;
  String flagCode = 'us';
  List<String> timeControls = ['blitz53'];

  /// Simulated "games in the last 24h" ticker (placeholder until online).
  int gamesLast24h = 224176;

  ArenaRepository() {
    _load();
    _tickGamesCounter();
  }

  void _load() {
    name = Database.profile('name', 'Guest');
    rating = Database.profile('rating', 1200);
    coins = Database.profile('coins', 550);
    games = Database.profile('games', 0);
    wins = Database.profile('wins', 0);
    draws = Database.profile('draws', 0);
    losses = Database.profile('losses', 0);
    form = Database.profileStrings('form');
    streak = Database.profile('streak', 0);
    puzzlesSolved = Database.profile('puzzlesSolved', 0);
    flagCode = Database.profile('flagCode', 'us');
    timeControls = Database.profileStrings('timeControls');
    if (timeControls.isEmpty) timeControls = ['blitz53'];
    gamesLast24h = 224000 + _rng.nextInt(1500);
  }

  void _tickGamesCounter() {
    // Cosmetic drift so the home card feels alive (placeholder).
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      gamesLast24h += _rng.nextInt(3);
      notifyListeners();
      return true;
    });
  }

  String get flagEmoji {
    const flags = {
      'us': '🇺🇸', 'gb': '🇬🇧', 'in': '🇮🇳', 'pk': '🇵🇰', 'pl': '🇵🇱',
      'de': '🇩🇪', 'fr': '🇫🇷', 'es': '🇪🇸', 'it': '🇮🇹', 'br': '🇧🇷',
      'ru': '🇷🇺', 'mx': '🇲🇽', 'no': '🇳🇴', 'ma': '🇲🇦', 'tr': '🇹🇷',
    };
    return flags[flagCode] ?? '🏳️';
  }

  Future<void> cycleFlag() async {
    const codes = [
      'us', 'gb', 'in', 'pk', 'pl', 'de', 'fr', 'es',
      'it', 'br', 'ru', 'mx', 'no', 'ma', 'tr',
    ];
    flagCode = codes[(codes.indexOf(flagCode) + 1) % codes.length];
    await Database.setProfile('flagCode', flagCode);
    notifyListeners();
  }

  Future<void> setFlagCode(String code) async {
    flagCode = code.toLowerCase();
    await Database.setProfile('flagCode', flagCode);
    notifyListeners();
  }

  Future<void> setTimeControls(List<String> ids) async {
    timeControls = ids.isEmpty ? ['blitz53'] : ids;
    await Database.setProfile('timeControls', timeControls);
    notifyListeners();
  }

  Future<void> addCoins(int n) async {
    coins += n;
    await Database.setProfile('coins', coins);
    notifyListeners();
    _syncProfile();
  }

  /// Returns false when funds are insufficient.
  Future<bool> spendCoins(int n) async {
    if (coins < n) return false;
    coins -= n;
    await Database.setProfile('coins', coins);
    notifyListeners();
    _syncProfile();
    return true;
  }

  /// Records a finished rated game. Returns the rating delta.
  Future<int> recordGameResult({
    required double score, // 1 / 0.5 / 0
    required int opponentRating,
    required String opponent,
    required String myColor,
    required List<String> sans,
    required String timeControl,
  }) async {
    final before = rating;
    rating = Elo.newRating(
      mine: rating,
      opponent: opponentRating,
      score: score,
      gamesPlayed: games,
    );
    games++;
    final tag = score == 1 ? 'w' : (score == 0.5 ? 'd' : 'l');
    if (tag == 'w') {
      wins++;
    } else if (tag == 'd') {
      draws++;
    } else {
      losses++;
    }
    form = [...form, tag];
    if (form.length > 5) form = form.sublist(form.length - 5);

    // Coins: win 20 (+streak bonus), draw 8, loss 2.
    final bonus = (tag == 'w') ? 20 + min(streak, 7) * 2 : (tag == 'd' ? 8 : 2);
    coins += bonus;

    await Database.setProfile('rating', rating);
    await Database.setProfile('games', games);
    await Database.setProfile('wins', wins);
    await Database.setProfile('draws', draws);
    await Database.setProfile('losses', losses);
    await Database.setProfile('form', form);
    await Database.setProfile('coins', coins);

    final record = <String, Object?>{
      'playerId': Database.profile('guestId', 0).toString(),
      'date': DateTime.now().toIso8601String(),
      'opponent': opponent,
      'opponentRating': opponentRating,
      'myColor': myColor,
      'result': tag,
      'ratingBefore': before,
      'ratingAfter': rating,
      'sans': sans,
      'timeControl': timeControl,
    };
    await Database.addGame(record);
    // Fire-and-forget cloud sync (no-op offline).
    SupabaseService.saveGame(record);
    _syncProfile();
    notifyListeners();
    return rating - before;
  }

  // ---- daily / missions ----

  bool get dailyGameDone =>
      Database.profile('lastDailyGame', '') == _todayYmd();

  Future<void> completeDailyGame() async {
    if (dailyGameDone) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final ymd =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final last = Database.profile('lastDailyGame', '');
    streak = (last == ymd) ? streak + 1 : 1;
    await Database.setProfile('streak', streak);
    await Database.setProfile('lastDailyGame', _todayYmd());
    await addCoins(10 + min(streak, 7) * 2);
    notifyListeners();
  }

  bool get dailyPuzzleDone =>
      Database.dailySolvedDate() == _todayYmd();

  Future<void> completeDailyPuzzle() async {
    if (dailyPuzzleDone) return;
    await Database.setDailySolvedDate(_todayYmd());
    puzzlesSolved++;
    await Database.setProfile('puzzlesSolved', puzzlesSolved);
    await addCoins(10);
    notifyListeners();
  }

  int get missionProgress => Database.profile('missionGamesPlayed', 0);
  bool get missionClaimed => Database.profile('missionClaimed', true);

  Future<void> bumpMissionProgress() async {
    await Database.setProfile('missionGamesPlayed', missionProgress + 1);
    if (Database.profile('missionClaimed', true)) {
      await Database.setProfile('missionClaimed', false);
    }
    notifyListeners();
  }

  /// Claims the "Play a game online" mission (+25). True if claimed.
  Future<bool> claimMission() async {
    if (missionClaimed || missionProgress < 1) return false;
    await Database.setProfile('missionClaimed', true);
    await Database.setProfile('missionGamesPlayed', 0);
    await addCoins(25);
    notifyListeners();
    return true;
  }

  /// Lightweight refresh signal (e.g. puzzle list after a solve).
  void refreshPuzzles() {
    puzzlesSolved = Database.profile('puzzlesSolved', puzzlesSolved);
    notifyListeners();
  }

  Future<void> rename(String n) async {
    name = n.trim().isEmpty ? name : n.trim();
    await Database.setProfile('name', name);
    notifyListeners();
    _syncProfile();
  }

  // ---- live-game snapshot (resume after app restart) ----

  void saveLiveGame(String json) => Database.setProfile('liveGame', json);

  String? get liveGameJson {
    final v = Database.profile('liveGame', '');
    return v.isEmpty ? null : v;
  }

  void clearLiveGame() => Database.setProfile('liveGame', '');

  // ---- rankings (remote first, seeded offline fallback) ----

  Future<List<RankingEntry>> rankings() async {
    final remote = await SupabaseService.fetchRankings();
    if (remote != null && remote.isNotEmpty) {
      return remote
          .map((r) => RankingEntry(
                name: '${r['name'] ?? '???'}',
                flag: '${r['flag'] ?? '🏳️'}',
                rating: (r['rating'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }
    return _seededRankings();
  }

  List<RankingEntry> _seededRankings() {
    final bots = [
      const RankingEntry(name: 'Bhola 12+Age', flag: '🇮🇳', rating: 2326),
      const RankingEntry(name: 'ilaya raja g', flag: '🇮🇳', rating: 2280),
      const RankingEntry(name: 'ucilianoo', flag: '🇵🇱', rating: 2203),
      const RankingEntry(name: 'marcoarango', flag: '🇲🇽', rating: 2105),
      const RankingEntry(name: 'Muhammad Riyas', flag: '🇮🇳', rating: 2088),
      const RankingEntry(name: 'JancoxJaran', flag: '🇵🇱', rating: 1977),
      const RankingEntry(name: 'Tachi Nerja', flag: '🇪🇸', rating: 1906),
      const RankingEntry(name: 'I WILL KILL U^', flag: '🇷🇺', rating: 1905),
      const RankingEntry(name: 'SsBuiltNinja', flag: '🇺🇸', rating: 1873),
      const RankingEntry(name: 'GM Carlsen', flag: '🇳🇴', rating: 1849),
      const RankingEntry(name: 'I-saint2', flag: '🇺🇸', rating: 1823),
      const RankingEntry(name: "SHANKAR'S", flag: '🇮🇳', rating: 1815),
      const RankingEntry(name: 'khallouk', flag: '🇲🇦', rating: 1814),
      const RankingEntry(name: 'Nightingale', flag: '🇬🇧', rating: 1750),
      const RankingEntry(name: 'pawnstormer', flag: '🇩🇪', rating: 1690),
      const RankingEntry(name: 'ChaiTimeBlitz', flag: '🇵🇰', rating: 1620),
      const RankingEntry(name: 'RookRoller', flag: '🇫🇷', rating: 1540),
      const RankingEntry(name: 'QuietKnight', flag: '🇮🇹', rating: 1420),
      const RankingEntry(name: 'blunderful', flag: '🇧🇷', rating: 1305),
      const RankingEntry(name: 'EnPassantEnjoyer', flag: '🇹🇷', rating: 1180),
      const RankingEntry(name: 'FianchettoFan', flag: '🇪🇸', rating: 990),
      const RankingEntry(name: 'HangMateHarry', flag: '🇺🇸', rating: 760),
    ];
    final all = [...bots];
    all.add(RankingEntry(
        name: '$name (You)', flag: flagEmoji, rating: rating, isPlayer: true));
    all.sort((a, b) => b.rating.compareTo(a.rating));
    return all;
  }

  /// Random guest identity for simulated online opponents.
  Map<String, Object?> randomSimulatedOpponent(int nearRating) {
    final id = MatchmakingService.simulatedHuman(nearRating);
    return {'name': id.name, 'flag': id.flagIso, 'rating': id.rating};
  }

  void _syncProfile() {
    if (!SupabaseService.isReady) return;
    SupabaseService.upsertProfile(
      id: Database.profile('guestId', 0).toString(),
      name: name,
      flag: flagEmoji,
      rating: rating,
      coins: coins,
    );
  }
}

/// Board/UI toggles backing the Settings dialog (persisted in Hive).
class SettingsController extends ChangeNotifier {
  bool get sound => Database.setting('sound', true);
  bool get showLastMove => Database.setting('showLastMove', true);
  bool get pieceAnimation => Database.setting('pieceAnimation', true);
  bool get showMoveHelp => Database.setting('showMoveHelp', true);
  bool get confirmMoves => Database.setting('confirmMoves', false);
  bool get autoQueen => Database.setting('autoQueen', true);
  bool get showChat => Database.setting('showChat', true);
  int get boardTheme => Database.setting('boardTheme', 0);
  bool get pieceImages => Database.setting('pieceImages', true);
  bool get useStockfish => Database.setting('useStockfish', true);

  Future<void> set(String key, bool value) async {
    await Database.setSetting(key, value);
    if (key == 'sound') {
      SoundService.configure(enabled: value);
    }
    notifyListeners();
  }

  Future<void> setInt(String key, int value) async {
    await Database.setSetting(key, value);
    notifyListeners();
  }
}
