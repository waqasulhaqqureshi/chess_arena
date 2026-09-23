/// Vs-CPU / simulated-online game state: board, clocks, CPU replies,
/// rating settlement and game-over flow.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repository/arena_repository.dart';
import '../data/time_controls.dart';
import '../engine/chess_ai.dart';
import '../engine/chess_rules.dart';
import '../engine/cpu_brain.dart';
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
  });

  bool get isCpuAvatar => opponentFlag == 'cpu';
}

class PromotionRequest {
  final int from;
  final int to;
  final bool white;
  const PromotionRequest(this.from, this.to, this.white);
}

class GameOverInfo {
  final String title; // 'You win!' / 'Draw' / 'CPU wins'
  final String reason; // 'Checkmate', 'Time', 'You resigned'...
  final double playerScore;
  final int ratingDelta;
  final int newRating;
  final int coinsEarned;
  final bool rated;
  const GameOverInfo({
    required this.title,
    required this.reason,
    required this.playerScore,
    required this.ratingDelta,
    required this.newRating,
    required this.coinsEarned,
    this.rated = true,
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

  double whiteMs = 0;
  double blackMs = 0;
  Timer? _timer;
  int _thinkToken = 0;
  int _coinsBefore = 0;

  GameController({
    required this.repo,
    required this.settings,
    required this.setup,
  }) {
    game = ChessGame.startingPosition();
    _coinsBefore = repo.coins;
    final tc = setup.timeControl;
    if (tc.isPerMove) {
      whiteMs = tc.moveSeconds * 1000.0;
      blackMs = tc.moveSeconds * 1000.0;
    } else {
      whiteMs = tc.seconds * 1000.0;
      blackMs = tc.seconds * 1000.0;
    }
    SoundService.configure(enabled: settings.sound);
    SoundService.gameStart();
    _startClock();
    if (!setup.playerIsWhite) {
      _cpuMove(); // CPU (white) opens.
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
    // Promotions can push counts above start — clamp at 0 missing.
    List<int> missing(Map<int, int> counts, bool white) {
      final out = <int>[];
      for (final t in [queen, rook, bishop, knight, pawn]) {
        var n = start[t]! - counts[t]!;
        // Extra queens etc. from promotion reduce "missing" pawns implicitly;
        // simplest robust approach: clamp per type at >= 0.
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
    // Positive = white ahead (pawn units).
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
      // Promotion choice.
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
    _clearSelection();
    _afterMoveClock(moverWhite);
    _moveSound(m, wasCapture);
    notifyListeners();
    if (_checkGameEnd()) return;
    await _cpuMove();
  }

  Future<void> _cpuMove() async {
    if (isGameOver) return;
    cpuThinking = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 350));
    if (isGameOver) {
      cpuThinking = false;
      return;
    }
    final token = ++_thinkToken;
    final cpuClockMs =
        game.whiteToMove ? whiteMs : blackMs; // CPU side to move
    final res = await CpuBrain.think(
      game,
      setup.difficulty,
      clockMs: cpuClockMs,
      incrementMs: setup.timeControl.increment * 1000,
    );
    if (token != _thinkToken || isGameOver) return; // stale (undo/dispose)
    cpuThinking = false;
    if (res == null || res.move == null) {
      _checkGameEnd();
      notifyListeners();
      return;
    }
    final moverWhite = game.whiteToMove;
    final wasCapture = game.board[res.move!.to] != 0 ||
        (game.board[res.move!.from].abs() == pawn &&
            res.move!.to == game.ep);
    final san = game.playMove(res.move!);
    if (san == null) {
      // Should never happen (engine only returns legal moves) — resync.
      _checkGameEnd();
      notifyListeners();
      return;
    }
    lastMove = res.move!;
    _afterMoveClock(moverWhite);
    _moveSound(res.move!, wasCapture);
    notifyListeners();
    _checkGameEnd();
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
      // Reset the mover's clock for their next turn.
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
    // Bare-king opponent cannot win on time → draw (simplified).
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

  /// Take back the last round (your move + CPU reply).
  void takeback() {
    if (isGameOver || cpuThinking) return;
    if (game.moveHistory.isEmpty) return;
    _thinkToken++;
    if (isPlayerTurn) {
      if (game.moveHistory.length >= 2) {
        game.undoFullRound();
      } else {
        game.undo();
      }
    } else {
      game.undo();
    }
    lastMove =
        game.moveHistory.isEmpty ? null : game.moveHistory.last;
    _clearSelection();
    SoundService.click();
  }

  String _titleFor(double score) {
    if (score == 1) return 'You win!';
    if (score == 0.5) return 'Draw';
    return setup.isCpuAvatar ? 'CPU wins' : 'Opponent wins';
  }

  /// True once the human has played at least one move.
  bool get playerHasMoved {
    for (var i = 0; i < game.moveHistory.length; i++) {
      if ((i % 2 == 0) == setup.playerIsWhite) return true;
    }
    return false;
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
    String shortReason,
  ) async {
    if (isGameOver) return;
    _timer?.cancel();
    cpuThinking = false;
    // Abort (unrated): resigning/flagging/exiting before your first move
    // records nothing — no rating, form, coins or mission progress.
    final abort = !playerHasMoved && playerScore == 0.0;
    if (playerScore == 1) {
      SoundService.win();
    } else {
      SoundService.gameEnd();
    }
    var delta = 0;
    var earned = 0;
    if (!abort) {
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
      earned = repo.coins - _coinsBefore;
    }
    gameOverInfo = GameOverInfo(
      title: abort ? 'Game aborted' : _titleFor(playerScore),
      reason: abort ? 'Not rated · no moves played' : reason,
      playerScore: playerScore,
      ratingDelta: delta,
      newRating: repo.rating,
      coinsEarned: earned,
      rated: !abort,
    );
    notifyListeners();
    // Fullscreen ad hook (no-op until ads are integrated).
    await AdsService.showGameEndAd();
    debugPrint('[Game] over: $shortReason (score=$playerScore)');
  }

  @override
  void dispose() {
    _thinkToken++;
    _timer?.cancel();
    super.dispose();
  }
}
');
  }

  @override
  void dispose() {
    _thinkToken++;
    _timer?.cancel();
    super.dispose();
  }
}
