/// Vs-CPU / simulated-online game state: board, clocks, CPU replies,
/// chat simulation, live-game snapshots, rating settlement, game-over flow.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/repository/arena_repository.dart';
import '../data/time_controls.dart';
import '../engine/chess_ai.dart';
import '../engine/chess_rules.dart';
import '../engine/cpu_brain.dart';
import '../engine/stockfish_service.dart';
import '../services/ads_service.dart';
import '../services/sound_service.dart';

String formatClock(double ms) {
  if (ms < 0) ms = 0;
  final totalSecs = ms / 1000.0;
  final m = totalSecs ~/ 60;
  final s = (totalSecs % 60).floor();
  if (ms < 10000 && m == 0) {
    final tenths = ((ms % 1000) / 100).floor();
    return '$m:${s.toString().padLeft(2, '0')}.$tenths';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

class GameSetup {
  /// True for "Find opponent" (simulated rated game), false for casual CPU.
  final bool rated;

  /// False → friendly untimed game (video-style CPU play, no clocks).
  final bool timed;
  final String opponentName;
  final String opponentFlag; // emoji flag or 'cpu'
  final int opponentRating;
  final CpuDifficulty difficulty;
  final bool playerIsWhite;
  final TimeControl timeControl;

  const GameSetup({
    required this.rated,
    required this.opponentName,
    required this.opponentFlag,
    required this.opponentRating,
    required this.difficulty,
    required this.playerIsWhite,
    required this.timeControl,
    this.timed = true,
  });

  bool get isCpuAvatar => opponentFlag == 'cpu';

  Map<String, Object?> toJson() => {
        'rated': rated,
        'timed': timed,
        'opponentName': opponentName,
        'opponentFlag': opponentFlag,
        'opponentRating': opponentRating,
        'difficulty': difficulty.toJson(),
        'playerIsWhite': playerIsWhite,
        'tc': timeControl.id,
      };

  factory GameSetup.fromJson(Map<String, Object?> j) => GameSetup(
        rated: j['rated'] == true,
        timed: j['timed'] != false,
        opponentName: '${j['opponentName']}',
        opponentFlag: '${j['opponentFlag']}',
        opponentRating: (j['opponentRating'] as num?)?.toInt() ?? 1200,
        difficulty: CpuDifficulty.fromJson(
            (j['difficulty'] as Map).cast<String, Object?>()),
        playerIsWhite: j['playerIsWhite'] == true,
        timeControl: timeControlById('${j['tc']}'),
      );
}

class PromotionRequest {
  final int from;
  final int to;
  final bool white;
  const PromotionRequest(this.from, this.to, this.white);
}

class ChatMsg {
  final bool mine;
  final String text;
  const ChatMsg({required this.mine, required this.text});
}

class GameOverInfo {
  final String title; // 'You win!' / 'Draw' / 'CPU wins'
  final String reason; // 'Checkmate', 'Time', 'You resigned'...
  final double playerScore;
  final int ratingDelta;
  final int newRating;
  final int coinsEarned;
  final bool rated;
  final int movesPlayed;
  const GameOverInfo({
    required this.title,
    required this.reason,
    required this.playerScore,
    required this.ratingDelta,
    required this.newRating,
    required this.coinsEarned,
    this.rated = true,
    this.movesPlayed = 0,
  });
}

class GameController extends ChangeNotifier {
  final ArenaRepository repo;
  final SettingsController settings;
  final GameSetup setup;

  late ChessGame game;
  int? selected;
  List<ChessMove> selectedMoves = [];
  int? pendingFrom;
  int? pendingTo;
  ChessMove? lastMove;
  PromotionRequest? promotionRequest;

  bool cpuThinking = false;
  GameOverInfo? gameOverInfo;
  bool get isGameOver => gameOverInfo != null;

  // Chat simulation (video parity: unread badge + quick replies).
  final List<ChatMsg> chat = [];
  int unread = 0;
  bool cpuDrawOffer = false;
  bool cpuDrawOffered = false;
  int takebacksUsed = 0;

  double whiteMs = 0;
  double blackMs = 0;
  int? idleAbortRemaining; // seconds; non-null while the no-show countdown runs
  Timer? _timer;
  int _thinkToken = 0;
  int _coinsBefore = 0;
  final Random _rng = Random();
  final Stopwatch _live = Stopwatch();
  final List<List<int>> _moveLog = [];

  GameController({
    required this.repo,
    required this.settings,
    required this.setup,
  }) {
    game = ChessGame.startingPosition();
    _initCommon();
    if (!setup.playerIsWhite) {
      _cpuMove(); // CPU (white) opens.
    }
  }

  /// Rebuilds a game from a persisted snapshot (app restarted mid-game).
  GameController.resume({
    required this.repo,
    required this.settings,
    required Map<String, Object?> snapshot,
  }) : setup = GameSetup.fromJson(
            (snapshot['setup'] as Map).cast<String, Object?>()) {
    game = ChessGame.startingPosition();
    for (final m in (snapshot['moves'] as List? ?? const [])) {
      final t = (m as List).map((e) => (e as num).toInt()).toList();
      if (t.length >= 2) {
        game.playMove(ChessMove(t[0], t[1], t.length > 2 ? t[2] : 0));
        _moveLog.add(t);
      }
    }
    lastMove = game.moveHistory.isEmpty ? null : game.moveHistory.last;
    whiteMs = ((snapshot['whiteMs'] as num?) ?? 0).toDouble();
    blackMs = ((snapshot['blackMs'] as num?) ?? 0).toDouble();
    takebacksUsed = (snapshot['takebacks'] as num?)?.toInt() ?? 0;
    _initCommon(saveSnapshot: false);
    if (game.whiteToMove != setup.playerIsWhite) _cpuMove();
  }

  void _initCommon({bool saveSnapshot = true}) {
    _coinsBefore = repo.coins;
    final tc = setup.timeControl;
    if (whiteMs <= 0 && blackMs <= 0) {
      if (tc.isPerMove) {
        whiteMs = tc.moveSeconds * 1000.0;
        blackMs = tc.moveSeconds * 1000.0;
      } else {
        whiteMs = tc.seconds * 1000.0;
        blackMs = tc.seconds * 1000.0;
      }
    }
    SoundService.configure(enabled: settings.sound);
    SoundService.gameStart();
    _live.start();
    if (setup.timed) _startClock();
    if (saveSnapshot) _saveLive();
    // Opponent says hello (rated games feel alive).
    if (setup.rated) {
      _scheduleOppChat('glhf 🙂', 2200);
    }
  }

  bool get isPlayerTurn =>
      !isGameOver && game.whiteToMove == setup.playerIsWhite;

  String statusText() {
    if (isGameOver) return gameOverInfo!.title;
    if (cpuThinking) return 'Opponent thinking…';
    if (isPlayerTurn) {
      return game.inCheck() ? 'Check! Your move' : 'Your move';
    }
    return 'Waiting…';
  }

  int? kingInCheckSquare() {
    if (!game.inCheck()) return null;
    final want = game.whiteToMove ? king : -king;
    for (var i = 0; i < 64; i++) {
      if (game.board[i] == want) return i;
    }
    return null;
  }

  /// Captured pieces for the strip: [whiteCaptured(black pieces), blackCaptured].
  (List<int>, List<int>) capturedPieces() {
    const start = {
      pawn: 8, knight: 2, bishop: 2, rook: 2, queen: 1,
    };
    final whiteCounts = {pawn: 0, knight: 0, bishop: 0, rook: 0, queen: 0};
    final blackCounts = {pawn: 0, knight: 0, bishop: 0, rook: 0, queen: 0};
    for (final p in game.board) {
      if (p > 0 && p != king) {
        whiteCounts[p] = whiteCounts[p]! + 1;
      } else if (p < 0 && p != -king) {
        blackCounts[-p] = blackCounts[-p]! + 1;
      }
    }
    List<int> missing(Map<int, int> counts, bool white) {
      final out = <int>[];
      for (final t in [queen, rook, bishop, knight, pawn]) {
        var n = start[t]! - counts[t]!;
        if (n < 0) n = 0;
        for (var i = 0; i < n; i++) {
          out.add(white ? t : -t);
        }
      }
      return out;
    }

    return (missing(blackCounts, false), missing(whiteCounts, true));
  }

  int materialDiff() {
    const vals = {pawn: 1, knight: 3, bishop: 3, rook: 5, queen: 9};
    var d = 0;
    for (final p in game.board) {
      if (p == 0 || p.abs() == king) continue;
      d += p > 0 ? vals[p]! : -vals[-p]!;
    }
    return d;
  }

  // ------------------------------------------------------------------ input

  Future<void> tapSquare(int sq) async {
    if (isGameOver || cpuThinking || !isPlayerTurn) return;
    final myWhite = setup.playerIsWhite;
    final piece = game.board[sq];

    if (selected == null) {
      if (piece != 0 && (piece > 0) == myWhite) {
        _select(sq);
      }
      return;
    }
    if (sq == selected) {
      _clearSelection();
      return;
    }
    if (piece != 0 && (piece > 0) == myWhite) {
      _select(sq); // re-select
      return;
    }
    final cands = selectedMoves.where((m) => m.to == sq).toList();
    if (cands.isEmpty) {
      SoundService.illegal();
      _clearSelection();
      return;
    }
    if (cands.length > 1) {
      if (settings.autoQueen) {
        final q = cands.firstWhere(
          (m) => m.promotion == queen,
          orElse: () => cands.first,
        );
        await _commitPlayerMove(q);
      } else {
        promotionRequest = PromotionRequest(selected!, sq, myWhite);
        notifyListeners();
      }
      return;
    }
    if (settings.confirmMoves &&
        !(pendingFrom == selected && pendingTo == sq)) {
      pendingFrom = selected;
      pendingTo = sq;
      notifyListeners();
      return;
    }
    await _commitPlayerMove(cands.first);
  }

  Future<void> answerPromotion(int? pieceType) async {
    final req = promotionRequest;
    promotionRequest = null;
    if (req == null) {
      notifyListeners();
      return;
    }
    if (pieceType == null) {
      _clearSelection();
      return;
    }
    final cands = selectedMoves
        .where((m) => m.to == req.to && m.promotion == pieceType)
        .toList();
    if (cands.isEmpty) {
      _clearSelection();
      return;
    }
    await _commitPlayerMove(cands.first);
  }

  void _select(int sq) {
    selected = sq;
    selectedMoves = settings.showMoveHelp ? game.legalMovesFrom(sq) : [];
    pendingFrom = null;
    pendingTo = null;
    SoundService.click();
    notifyListeners();
  }

  void _clearSelection() {
    selected = null;
    selectedMoves = [];
    pendingFrom = null;
    pendingTo = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ moves

  Future<void> _commitPlayerMove(ChessMove m) async {
    final moverWhite = game.whiteToMove;
    final wasCapture = game.board[m.to] != 0 ||
        (game.board[m.from].abs() == pawn && m.to == game.ep);
    final san = game.playMove(m);
    if (san == null) {
      SoundService.illegal();
      _clearSelection();
      return;
    }
    lastMove = m;
    _moveLog.add([m.from, m.to, m.promotion]);
    _clearSelection();
    _afterMoveClock(moverWhite);
    _moveSound(m, wasCapture);
    _saveLive();
    notifyListeners();
    if (_checkGameEnd()) return;
    await _cpuMove();
  }

  /// UCI Skill Level 0..20 scaled from the displayed opponent ELO.
  int _stockfishSkill() =>
      ((setup.difficulty.targetElo - 400) / 85).round().clamp(0, 20);

  /// Stockfish time budget: strength-scaled, never burns a low clock.
  int _stockfishTime(double cpuClockMs) {
    if (setup.timed && cpuClockMs < 10000) return 200;
    final e = setup.difficulty.targetElo;
    return e < 900 ? 300 : (e < 1400 ? 600 : (e < 1800 ? 900 : 1200));
  }

  /// Human-feeling reply cadence: base by strength + randomness, faster
  /// when the CPU clock is low.
  int _paceMs() {
    if (!setup.timed) {
      return 600 + _rng.nextInt(1400); // relaxed friendly game
    }
    final cpuClock = game.whiteToMove ? whiteMs : blackMs;
    if (cpuClock < 10000) return 150 + _rng.nextInt(350);
    final base = setup.difficulty.targetElo < 900
        ? 700
        : (setup.difficulty.targetElo < 1400 ? 900 : 1100);
    return base ~/ 2 + _rng.nextInt(base);
  }

  Future<void> _cpuMove() async {
    if (isGameOver) return;
    cpuThinking = true;
    notifyListeners();
    final sw = Stopwatch()..start();
    final token = ++_thinkToken;
    final cpuClockMs =
        game.whiteToMove ? whiteMs : blackMs; // CPU side to move

    // Engine routing: Stockfish (native, via community package) when the
    // toggle is on AND the binary loads on this platform; otherwise the
    // built-in Arena brain.
    ChessMove? chosen;
    if (settings.useStockfish) {
      final sf = StockfishService.instance;
      if (await sf.ensureReady()) {
        final uci = await sf.bestMoveUci(
          game.toFen(),
          skillLevel: _stockfishSkill(),
          movetimeMs: _stockfishTime(cpuClockMs),
        );
        if (uci != null) chosen = parseUciMove(game, uci);
      }
    }
    if (chosen == null) {
      final res = await CpuBrain.think(
        game,
        setup.difficulty,
        clockMs: cpuClockMs,
        incrementMs: setup.timeControl.increment * 1000,
      );
      chosen = res?.move;
    }
    if (token != _thinkToken || isGameOver) return; // stale (undo/dispose)
    // Let the reply breathe like a human would.
    final wait = _paceMs() - sw.elapsedMilliseconds;
    if (wait > 0) {
      await Future.delayed(Duration(milliseconds: wait));
    }
    if (token != _thinkToken || isGameOver) return;
    cpuThinking = false;
    if (chosen == null) {
      _checkGameEnd();
      notifyListeners();
      return;
    }
    final moverWhite = game.whiteToMove;
    final wasCapture = game.board[chosen.to] != 0 ||
        (game.board[chosen.from].abs() == pawn && chosen.to == game.ep);
    final san = game.playMove(chosen);
    if (san == null) {
      _checkGameEnd();
      notifyListeners();
      return;
    }
    lastMove = chosen;
    _moveLog.add([chosen.from, chosen.to, chosen.promotion]);
    _afterMoveClock(moverWhite);
    _moveSound(res.move!, wasCapture);
    _saveLive();
    _maybeCpuOfferDraw();
    notifyListeners();
    _checkGameEnd();
  }

  /// CPU offers a draw in a dead-drawn late position (once per game).
  void _maybeCpuOfferDraw() {
    if (cpuDrawOffered || !setup.rated) return;
    if (game.moveHistory.length < 60) return;
    final cpuWhite = !setup.playerIsWhite;
    final s = cpuWhite ? evaluate(game) : -evaluate(game);
    if (s.abs() < 15) {
      cpuDrawOffered = true;
      cpuDrawOffer = true;
      _scheduleOppChat('I think this is a draw 🤝', 800);
    }
  }

  Future<void> answerCpuDraw(bool accept) async {
    cpuDrawOffer = false;
    if (accept) {
      await _finish(0.5, 'Draw · Agreement', 'Draw agreed');
    } else {
      SoundService.click();
    }
    notifyListeners();
  }

  void _moveSound(ChessMove m, bool wasCapture) {
    if (game.phase == GamePhase.checkmate) {
      SoundService.gameEnd();
    } else if (game.inCheck()) {
      SoundService.check();
    } else if (m.promotion != 0) {
      SoundService.promote();
    } else if (wasCapture) {
      SoundService.capture();
    } else {
      SoundService.move();
    }
  }

  // ------------------------------------------------------------------ clocks

  void _startClock() {
    _timer?.cancel();
    var last = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (isGameOver) return;
      final now = DateTime.now();
      final dt = now.difference(last).inMilliseconds.toDouble();
      last = now;
      // No-show protection: zero moves after 20 s → abort, not a loss.
      if (game.moveHistory.isEmpty) {
        final elapsed = _live.elapsedMilliseconds;
        final remain = 20000 - elapsed;
        // Overlay appears only in the final 12 s (video parity).
        idleAbortRemaining =
            (remain > 0 && remain <= 12000) ? (remain / 1000).ceil() : null;
        if (remain <= 0) {
          _finish(0.0, 'Aborted · no moves played', 'No-show abort',
              abort: true);
          return;
        }
      } else if (idleAbortRemaining != null) {
        idleAbortRemaining = null;
      }
      if (game.whiteToMove) {
        whiteMs -= dt;
        if (whiteMs <= 0) {
          whiteMs = 0;
          _onFlag('w');
        }
      } else {
        blackMs -= dt;
        if (blackMs <= 0) {
          blackMs = 0;
          _onFlag('b');
        }
      }
      notifyListeners();
    });
  }

  void _afterMoveClock(bool moverWasWhite) {
    final tc = setup.timeControl;
    if (tc.isPerMove) {
      if (moverWasWhite) {
        whiteMs = tc.moveSeconds * 1000.0;
      } else {
        blackMs = tc.moveSeconds * 1000.0;
      }
    } else if (tc.increment > 0) {
      if (moverWasWhite) {
        whiteMs += tc.increment * 1000.0;
      } else {
        blackMs += tc.increment * 1000.0;
      }
    }
  }

  void _onFlag(String side) {
    if (isGameOver) return;
    final playerWhite = setup.playerIsWhite;
    final playerFlagged =
        (side == 'w' && playerWhite) || (side == 'b' && !playerWhite);
    final opponentBareKing = _isBareKing(side == 'w' ? false : true);
    if (playerFlagged) {
      if (opponentBareKing) {
        _finish(0.5, 'Draw · Flag, bare king', 'Time vs bare king');
      } else {
        _finish(0.0, 'Time · You flagged', 'You ran out of time');
      }
    } else {
      _finish(1.0, 'Time · Opponent flagged', 'Opponent ran out of time');
    }
  }

  bool _isBareKing(bool white) {
    for (final p in game.board) {
      if (p == 0) continue;
      if (white && p > 0 && p != king) return false;
      if (!white && p < 0 && p != -king) return false;
    }
    return true;
  }

  // ------------------------------------------------------------------ chat

  void markChatRead() {
    unread = 0;
    notifyListeners();
  }

  void _scheduleOppChat(String text, int delayMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (isGameOver && text.contains('gl')) return;
      chat.add(ChatMsg(mine: false, text: text));
      unread++;
      notifyListeners();
    });
  }

  /// Player quick-reply; the opponent answers in character.
  void sendChat(String text) {
    chat.add(ChatMsg(mine: true, text: text));
    notifyListeners();
    final lower = text.toLowerCase();
    String? reply;
    if (lower.contains('hi') || lower.contains('hello') || lower == 'gl') {
      reply = 'hey! good luck 🙂';
    } else if (lower.contains('nice')) {
      reply = 'thanks, you too!';
    } else if (lower.contains('gg')) {
      reply = 'gg wp!';
    } else if (lower.contains('draw')) {
      reply = 'let’s play on for now 😄';
    } else if (lower.contains('thank')) {
      reply = 'anytime!';
    }
    if (reply != null) {
      _scheduleOppChat(reply, 1200 + _rng.nextInt(1600));
    }
  }

  // ------------------------------------------------------------------ end

  bool _checkGameEnd() {
    if (isGameOver) return true;
    if (!game.isGameOver) return false;
    final playerWhite = setup.playerIsWhite;
    final w = game.winner;
    if (w == null) {
      _finish(0.5, game.resultText(), 'Draw');
    } else if ((w == 'w') == playerWhite) {
      _finish(1.0, game.resultText(), 'You delivered mate');
    } else {
      _finish(0.0, game.resultText(), 'Mated');
    }
    return true;
  }

  Future<void> resign() async {
    if (isGameOver) return;
    _thinkToken++; // invalidate any in-flight search
    cpuThinking = false;
    await _finish(0.0, 'You resigned', 'Resignation');
  }

  /// True once the human has played at least one move.
  bool get playerHasMoved {
    for (var i = 0; i < game.moveHistory.length; i++) {
      if ((i % 2 == 0) == setup.playerIsWhite) return true;
    }
    return false;
  }

  bool get cpuHasMoved {
    for (var i = 0; i < game.moveHistory.length; i++) {
      if ((i % 2 == 0) != setup.playerIsWhite) return true;
    }
    return false;
  }

  /// Rated games allow 2 takebacks (fairness); casual is unlimited.
  bool get canTakeback => !isGameOver &&
      !cpuThinking &&
      game.moveHistory.isNotEmpty &&
      (!setup.rated || takebacksUsed < 2);

  /// Take back the last round (your move + CPU reply).
  void takeback() {
    if (!canTakeback) return;
    _thinkToken++;
    if (setup.rated) takebacksUsed++;
    if (isPlayerTurn) {
      if (game.moveHistory.length >= 2) {
        game.undoFullRound();
        if (_moveLog.length >= 2) {
          _moveLog..removeLast()..removeLast();
        }
      } else {
        game.undo();
        if (_moveLog.isNotEmpty) _moveLog.removeLast();
      }
    } else {
      game.undo();
      if (_moveLog.isNotEmpty) _moveLog.removeLast();
    }
    lastMove =
        game.moveHistory.isEmpty ? null : game.moveHistory.last;
    _clearSelection();
    _saveLive();
    SoundService.click();
  }

  String _titleFor(double score) {
    if (score == 1) return 'You win!';
    if (score == 0.5) return 'Draw';
    return setup.isCpuAvatar ? 'CPU wins' : 'Opponent wins';
  }

  /// Offers a draw. Returns 'accepted', 'declined' or 'na'.
  /// The CPU accepts when not clearly winning (never before move 10).
  Future<String> offerDraw() async {
    if (isGameOver || cpuThinking || !isPlayerTurn) return 'na';
    if (game.moveHistory.length < 20) {
      SoundService.click();
      return 'declined';
    }
    final cpuWhite = !setup.playerIsWhite;
    final s = cpuWhite ? evaluate(game) : -evaluate(game);
    if (s < 80) {
      await _finish(0.5, 'Draw · Agreement', 'Draw agreed');
      return 'accepted';
    }
    SoundService.click();
    return 'declined';
  }

  Future<void> _finish(
    double playerScore,
    String reason,
    String shortReason, {
    bool abort = false,
  }) async {
    if (isGameOver) return;
    _timer?.cancel();
    cpuThinking = false;
    repo.clearLiveGame(); // snapshot only matters mid-game
    // Abort (unrated): leaving before any move records nothing.
    if (!abort) abort = game.moveHistory.isEmpty && playerScore == 0.0;
    if (playerScore == 1) {
      SoundService.win();
    } else {
      SoundService.gameEnd();
    }
    _scheduleOppChat('gg wp!', 900);
    var delta = 0;
    var earned = 0;
    if (!abort && setup.rated) {
      // Rated (simulated online): full settlement.
      delta = await repo.recordGameResult(
        score: playerScore,
        opponentRating: setup.opponentRating,
        opponent: setup.opponentName,
        myColor: setup.playerIsWhite ? 'w' : 'b',
        sans: List<String>.from(game.sanHistory),
        timeControl: setup.timeControl.id,
      );
      await repo.completeDailyGame();
      await repo.bumpMissionProgress();
    } else if (!abort) {
      // Casual completed game: small coins, daily counts, no rating.
      final bonus = playerScore == 1 ? 10 : (playerScore == 0.5 ? 4 : 1);
      await repo.addCoins(bonus);
      await repo.completeDailyGame();
    }
    earned = repo.coins - _coinsBefore;
    gameOverInfo = GameOverInfo(
      title: abort ? 'Game aborted' : _titleFor(playerScore),
      reason: abort ? 'Not rated · no moves played' : reason,
      playerScore: playerScore,
      ratingDelta: delta,
      newRating: repo.rating,
      coinsEarned: earned,
      rated: !abort && setup.rated,
      movesPlayed: game.moveHistory.length,
    );
    notifyListeners();
    // Fullscreen ad hook (no-op until ads are integrated).
    await AdsService.showGameEndAd();
    debugPrint('[Game] over: $shortReason (score=$playerScore)');
  }

  // ---------------------------------------------------------- persistence

  void _saveLive() {
    if (isGameOver) return;
    repo.saveLiveGame(jsonEncode({
      'setup': setup.toJson(),
      'moves': _moveLog,
      'whiteMs': whiteMs.round(),
      'blackMs': blackMs.round(),
      'takebacks': takebacksUsed,
    }));
  }

  @override
  void dispose() {
    _thinkToken++;
    _timer?.cancel();
    super.dispose();
  }
}
