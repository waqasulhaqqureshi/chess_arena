/// Tactical puzzle mode: play the side to move, mate in one.
///
/// Any mating move solves the puzzle; anything else flashes "Wrong move!"
/// and is taken back (mirrors goal.mp4).
library;

import 'package:flutter/foundation.dart';

import '../data/local/database.dart';
import '../data/repository/arena_repository.dart';
import '../engine/chess_rules.dart';
import '../engine/puzzles.dart';
import '../services/sound_service.dart';

int _uciSquare(String uci, int offset) {
  final f = uci.codeUnitAt(offset) - 97;
  final r = uci.codeUnitAt(offset + 1) - 49;
  return r * 8 + f;
}

int _promoFromChar(String c) {
  switch (c) {
    case 'n':
      return knight;
    case 'b':
      return bishop;
    case 'r':
      return rook;
    case 'q':
    default:
      return queen;
  }
}

class PuzzleController extends ChangeNotifier {
  final ArenaRepository repo;
  final SettingsController settings;
  bool isDaily;

  late Puzzle puzzle;
  late ChessGame game;
  int? selected;
  List<ChessMove> selectedMoves = [];
  ChessMove? lastMove;
  bool solved = false;
  bool wrongFlash = false;
  int? hintFrom;
  int? hintTo;
  bool usedSolution = false;
  int attempts = 0;
  int _actionToken = 0;

  PuzzleController({
    required this.repo,
    required this.settings,
    required Puzzle initial,
    this.isDaily = false,
  }) {
    loadPuzzle(initial, keepDaily: isDaily);
  }

  bool get orientationWhite => puzzle.whiteToMove;
  bool get alreadySolved =>
      Database.solvedPuzzles().contains(puzzle.id);

  void loadPuzzle(Puzzle p, {bool keepDaily = false}) {
    _actionToken++;
    if (!keepDaily) isDaily = false;
    puzzle = p;
    game = ChessGame.fromFen(p.fen);
    selected = null;
    selectedMoves = [];
    lastMove = null;
    solved = false;
    wrongFlash = false;
    hintFrom = null;
    hintTo = null;
    usedSolution = false;
    attempts = 0;
    SoundService.configure(enabled: settings.sound);
    notifyListeners();
  }

  Future<void> tapSquare(int sq) async {
    if (solved || wrongFlash) return;
    final myWhite = puzzle.whiteToMove;
    final piece = game.board[sq];
    if (selected == null) {
      if (piece != 0 && (piece > 0) == myWhite) {
        selected = sq;
        selectedMoves =
            settings.showMoveHelp ? game.legalMovesFrom(sq) : [];
        SoundService.click();
        notifyListeners();
      }
      return;
    }
    if (sq == selected) {
      selected = null;
      selectedMoves = [];
      notifyListeners();
      return;
    }
    if (piece != 0 && (piece > 0) == myWhite) {
      selected = sq;
      selectedMoves =
          settings.showMoveHelp ? game.legalMovesFrom(sq) : [];
      SoundService.click();
      notifyListeners();
      return;
    }
    final cands = selectedMoves.where((m) => m.to == sq).toList();
    if (cands.isEmpty) {
      SoundService.illegal();
      selected = null;
      selectedMoves = [];
      notifyListeners();
      return;
    }
    // Auto-queen for smooth puzzle flow (rook also mates in #6 — either fine).
    final move = cands.length > 1
        ? cands.firstWhere((m) => m.promotion == queen,
            orElse: () => cands.first)
        : cands.first;
    await _attempt(move);
  }

  Future<void> _attempt(ChessMove m) async {
    attempts++;
    final moverWhite = game.whiteToMove;
    final san = game.playMove(m);
    if (san == null) {
      SoundService.illegal();
      return;
    }
    lastMove = m;
    selected = null;
    selectedMoves = [];
    final mated = game.phase == GamePhase.checkmate &&
        game.winner == (moverWhite ? 'w' : 'b');
    if (mated) {
      solved = true;
      SoundService.win();
      await _grantReward();
      notifyListeners();
      return;
    }
    // Wrong — flash and take back.
    wrongFlash = true;
    SoundService.illegal();
    notifyListeners();
    final token = ++_actionToken;
    await Future.delayed(const Duration(milliseconds: 750));
    if (token != _actionToken) return;
    game.undo();
    lastMove = null;
    wrongFlash = false;
    notifyListeners();
  }

  Future<bool> showHint() async {
    if (solved || hintFrom != null) return true;
    final ok = await repo.spendCoins(10);
    if (!ok) return false;
    hintFrom = _uciSquare(puzzle.solutionUci, 0);
    hintTo = _uciSquare(puzzle.solutionUci, 2);
    SoundService.click();
    notifyListeners();
    return true;
  }

  /// Plays the canonical solution (costs 20 coins, no coin reward after).
  Future<bool> showSolution() async {
    if (solved) return true;
    final ok = await repo.spendCoins(20);
    if (!ok) return false;
    usedSolution = true;
    final from = _uciSquare(puzzle.solutionUci, 0);
    final to = _uciSquare(puzzle.solutionUci, 2);
    var promo = 0;
    if (puzzle.solutionUci.length > 4) {
      promo = _promoFromChar(puzzle.solutionUci[4]);
    }
    await _attempt(ChessMove(from, to, promo));
    return true;
  }

  Future<void> _grantReward() async {
    final already = Database.solvedPuzzles().contains(puzzle.id);
    await Database.markPuzzleSolved(puzzle.id);
    if (!already && !usedSolution) {
      await repo.addCoins(10);
      repo.puzzlesSolved++;
      await Database.setProfile('puzzlesSolved', repo.puzzlesSolved);
    }
    if (isDaily) {
      await repo.completeDailyPuzzle();
    }
    repo.refreshPuzzles();
  }
}
