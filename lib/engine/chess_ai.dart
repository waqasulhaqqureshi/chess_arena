/// CPU chess brain: negamax + alpha-beta + quiescence + ELO-scaled difficulty.
///
/// Pure Dart (no Flutter). The UI calls [CpuBrain.think] via a background
/// isolate (see engine/cpu_brain.dart) so the UI never janks.
library;

import 'dart:math';

import 'chess_rules.dart';

// ---------------------------------------------------------------------------
// Evaluation
// ---------------------------------------------------------------------------

const Map<int, int> _pieceValues = {
  pawn: 100,
  knight: 320,
  bishop: 330,
  rook: 500,
  queen: 900,
  king: 0,
};

// Simplified Evaluation Function tables (white perspective, a8..h1 order).
const List<int> _pstPawn = [
  0, 0, 0, 0, 0, 0, 0, 0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _pstKnight = [
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _pstBishop = [
  -20, -10, -10, -10, -10, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _pstRook = [
  0, 0, 0, 0, 0, 0, 0, 0,
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _pstQueen = [
  -20, -10, -10, -5, -5, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _pstKing = [
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];

const Map<int, List<int>> _pst = {
  pawn: _pstPawn,
  knight: _pstKnight,
  bishop: _pstBishop,
  rook: _pstRook,
  queen: _pstQueen,
  king: _pstKing,
};

int _pstIndex(int sq, bool white) {
  final f = fileOf(sq), r = rankOf(sq);
  return white ? (7 - r) * 8 + f : r * 8 + f;
}

/// Static evaluation in centipawns, WHITE perspective.
int evaluate(ChessGame g) {
  var score = 0;
  for (var sq = 0; sq < 64; sq++) {
    final p = g.board[sq];
    if (p == 0) continue;
    final white = p > 0;
    final v = _pieceValues[p.abs()]! + _pst[p.abs()]![_pstIndex(sq, white)];
    score += white ? v : -v;
  }
  return score;
}

// ---------------------------------------------------------------------------
// Difficulty
// ---------------------------------------------------------------------------

/// CPU strength preset. [targetElo] is the *displayed* opponent rating.
class CpuDifficulty {
  final String name;
  final int targetElo;
  final int depth;
  final double blunderChance; // 0..1 → random legal move
  final int noiseCp; // evaluation noise for variety + mistakes
  final int timeBudgetMs;
  final int quiescenceDepth;

  const CpuDifficulty({
    required this.name,
    required this.targetElo,
    required this.depth,
    required this.blunderChance,
    required this.noiseCp,
    required this.timeBudgetMs,
    required this.quiescenceDepth,
  });

  static const easy = CpuDifficulty(
    name: 'Easy',
    targetElo: 600,
    depth: 1,
    blunderChance: 0.25,
    noiseCp: 140,
    timeBudgetMs: 250,
    quiescenceDepth: 2,
  );
  static const medium = CpuDifficulty(
    name: 'Medium',
    targetElo: 1100,
    depth: 2,
    blunderChance: 0.08,
    noiseCp: 45,
    timeBudgetMs: 600,
    quiescenceDepth: 4,
  );
  static const hard = CpuDifficulty(
    name: 'Hard',
    targetElo: 1600,
    depth: 3,
    blunderChance: 0.02,
    noiseCp: 12,
    timeBudgetMs: 1400,
    quiescenceDepth: 6,
  );

  /// Builds a difficulty matching [elo] (used by simulated online opponents).
  /// ELO range ~400..2100 maps to depth 1..3 + blunder/noise scaling.
  factory CpuDifficulty.forElo(int elo) {
    final e = elo.clamp(400, 2100);
    final depth = e < 700 ? 1 : (e < 1250 ? 2 : 3);
    final blunder = ((1350 - e) / 2200).clamp(0.0, 0.30);
    final noise = ((1500 - e) / 7).clamp(0.0, 150.0).round();
    final q = e < 700 ? 2 : (e < 1250 ? 4 : 6);
    final budget = e < 700 ? 250 : (e < 1250 ? 600 : 1400);
    final name = e < 700
        ? 'Easy'
        : (e < 1000 ? 'Medium' : (e < 1500 ? 'Hard' : 'Expert'));
    return CpuDifficulty(
      name: name,
      targetElo: e,
      depth: depth,
      blunderChance: blunder,
      noiseCp: noise,
      timeBudgetMs: budget,
      quiescenceDepth: q,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'targetElo': targetElo,
        'depth': depth,
        'blunderChance': blunderChance,
        'noiseCp': noiseCp,
        'timeBudgetMs': timeBudgetMs,
        'quiescenceDepth': quiescenceDepth,
      };

  factory CpuDifficulty.fromJson(Map<String, Object?> j) => CpuDifficulty(
        name: j['name']! as String,
        targetElo: (j['targetElo']! as num).toInt(),
        depth: (j['depth']! as num).toInt(),
        blunderChance: (j['blunderChance']! as num).toDouble(),
        noiseCp: (j['noiseCp']! as num).toInt(),
        timeBudgetMs: (j['timeBudgetMs']! as num).toInt(),
        quiescenceDepth: (j['quiescenceDepth']! as num).toInt(),
      );
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

const int mateScore = 100000;
const int _infinity = 1000000;

class _Timeout implements Exception {}

class _Searcher {
  final CpuDifficulty diff;
  final Random rng;
  final Stopwatch sw = Stopwatch();
  int nodes = 0;

  _Searcher(this.diff, int seed) : rng = Random(seed);

  void _poll() {
    nodes++;
    if ((nodes & 1023) == 0 && sw.elapsedMilliseconds > diff.timeBudgetMs) {
      throw _Timeout();
    }
    if (nodes > 400000) throw _Timeout(); // hard node cap
  }

  int _scoreFromSideToMove(ChessGame g) =>
      g.whiteToMove ? evaluate(g) : -evaluate(g);

  /// Orders moves in-place: captures (MVV-LVA) and promotions first.
  void _order(ChessGame g, List<ChessMove> moves) {
    int mv(ChessMove m) {
      var s = 0;
      final victim = g.board[m.to].abs();
      if (victim != 0) {
        s = 10000 + _pieceValues[victim]! - _pieceValues[g.board[m.from].abs()]!;
      } else if (g.board[m.from].abs() == pawn && m.to == g.ep) {
        s = 10000 + _pieceValues[pawn]!;
      }
      if (m.promotion != 0) s += 9000 + _pieceValues[m.promotion]!;
      return s;
    }

    moves.sort((a, b) => mv(b).compareTo(mv(a)));
  }

  bool _isCapture(ChessGame g, ChessMove m) =>
      g.board[m.to] != 0 ||
      (g.board[m.from].abs() == pawn && m.to == g.ep) ||
      m.promotion != 0;

  int _quiescence(ChessGame g, int alpha, int beta, int qdepth) {
    _poll();
    final inChk = g.inCheck();
    if (!inChk) {
      final standPat = _scoreFromSideToMove(g);
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;
      if (qdepth <= 0) return alpha;
    }
    var moves = g.legalMoves();
    if (!inChk) {
      moves = moves.where((m) => _isCapture(g, m)).toList();
      if (moves.isEmpty) return alpha;
    } else if (moves.isEmpty) {
      return -mateScore - qdepth; // mated
    }
    _order(g, moves);
    for (final m in moves) {
      final t = g.doSearchMove(m);
      final s = -_quiescence(g, -beta, -alpha, qdepth - 1);
      g.undoSearchMove(t);
      if (s >= beta) return beta;
      if (s > alpha) alpha = s;
    }
    return alpha;
  }

  int _search(ChessGame g, int depth, int alpha, int beta, int ply) {
    _poll();
    if (g.halfmove >= 100 || g.hasInsufficientMaterial) return 0;
    if (depth <= 0) return _quiescence(g, alpha, beta, diff.quiescenceDepth);
    final moves = g.legalMoves();
    if (moves.isEmpty) {
      return g.inCheck() ? -(mateScore - ply) : 0;
    }
    _order(g, moves);
    for (final m in moves) {
      final t = g.doSearchMove(m);
      final s = -_search(g, depth - 1, -beta, -alpha, ply + 1);
      g.undoSearchMove(t);
      if (s >= beta) return beta;
      if (s > alpha) alpha = s;
    }
    return alpha;
  }

  /// Returns [from, to, promotion, scoreCp(side-to-move), depth, nodes].
  Map<String, Object?> thinkRoot(ChessGame g) {
    sw.start();
    final moves = g.legalMoves();
    if (moves.isEmpty) {
      return {'none': true, 'nodes': nodes};
    }
    _order(g, moves);
    // Instant reply with a single legal move.
    if (moves.length == 1) {
      final m = moves.single;
      return {
        'from': m.from,
        'to': m.to,
        'promotion': m.promotion,
        'score': 0,
        'depth': diff.depth,
        'nodes': nodes,
      };
    }
    // Blunder: play a fully random move (human-like mistake).
    if (rng.nextDouble() < diff.blunderChance) {
      final m = moves[rng.nextInt(moves.length)];
      return {
        'from': m.from,
        'to': m.to,
        'promotion': m.promotion == 0 ? 0 : queen,
        'score': 0,
        'depth': 0,
        'nodes': nodes,
        'blunder': true,
      };
    }
    var best = moves.first;
    var bestScore = -_infinity;
    var alpha = -_infinity;
    try {
      for (final m in moves) {
        final t = g.doSearchMove(m);
        var s = -_search(g, diff.depth - 1, -_infinity, -alpha, 1);
        g.undoSearchMove(t);
        // Variety noise (also models inaccuracy at low ELO).
        if (diff.noiseCp > 0) {
          s += rng.nextInt(diff.noiseCp * 2 + 1) - diff.noiseCp;
        }
        if (s > bestScore) {
          bestScore = s;
          best = m;
        }
        if (s > alpha) alpha = s;
      }
    } on _Timeout {
      // Keep best-so-far on timeout.
    }
    return {
      'from': best.from,
      'to': best.to,
      'promotion': best.promotion,
      'score': bestScore,
      'depth': diff.depth,
      'nodes': nodes,
    };
  }
}

/// Synchronous entry point (also used by tests).
Map<String, Object?> thinkSync(String fen, CpuDifficulty diff, {int? seed}) {
  final g = ChessGame.fromFen(fen);
  final s = _Searcher(diff, seed ?? Random().nextInt(1 << 30));
  return s.thinkRoot(g);
}

/// Top-level isolate entry for `compute()`.
/// args: {'fen': String, 'diff': Map, 'seed': int}
Map<String, Object?> cpuThinkEntry(Map<String, Object?> args) {
  final fen = args['fen']! as String;
  final diff =
      CpuDifficulty.fromJson((args['diff']! as Map).cast<String, Object?>());
  final seed = (args['seed']! as num).toInt();
  return thinkSync(fen, diff, seed: seed);
}
