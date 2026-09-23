/// Engine verification suite. Run locally with: flutter test
///
/// Perft numbers are the standard chess-programming benchmarks:
/// startpos d1=20 d2=400 d3=8902; kiwipete d1=48 d2=2039;
/// pos3 (ep) d1=14 d2=191; pos4 (promo/castle) d1=6 d2=264.
library;

import 'package:chess_arena/core/utils/elo.dart';
import 'package:chess_arena/data/time_controls.dart';
import 'package:chess_arena/engine/chess_ai.dart';
import 'package:chess_arena/engine/chess_rules.dart';
import 'package:chess_arena/engine/puzzles.dart';
import 'package:chess_arena/engine/stockfish_service.dart';
import 'package:chess_arena/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ChessMove _uci(ChessGame g, String uci) {
  int sq(int o) =>
      (uci.codeUnitAt(o + 1) - 49) * 8 + (uci.codeUnitAt(o) - 97);
  const promo = {'n': knight, 'b': bishop, 'r': rook, 'q': queen};
  final p = uci.length > 4 ? promo[uci[4]]! : 0;
  return g
      .findMoves(sq(0), sq(2))
      .firstWhere((m) => m.promotion == p);
}

/// Colour-mirrors a FEN board part (rank order reversed + case flipped).
/// A colour-mirrored position must evaluate to the exact negation.
String _mirrorBoard(String board) {
  String flip(String c) {
    final code = c.codeUnitAt(0);
    if (code >= 48 && code <= 57) return c; // digits untouched
    return c == c.toLowerCase() ? c.toUpperCase() : c.toLowerCase();
  }

  return board
      .split('/')
      .reversed
      .map((rank) => rank.split('').map(flip).join())
      .join('/');
}

void main() {
  group('movegen (perft)', () {
    test('startpos d1..d3', () {
      final g = ChessGame.startingPosition();
      expect(g.perft(1), 20);
      expect(g.perft(2), 400);
      expect(g.perft(3), 8902);
    });
    test('kiwipete d1..d2', () {
      final g = ChessGame.fromFen(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      expect(g.perft(1), 48);
      expect(g.perft(2), 2039);
    });
    test('position 3 (en passant) d1..d2', () {
      final g = ChessGame.fromFen(
          '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect(g.perft(1), 14);
      expect(g.perft(2), 191);
    });
    test('position 4 (promotion/castling) d1..d2', () {
      final g = ChessGame.fromFen(
          'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
      expect(g.perft(1), 6);
      expect(g.perft(2), 264);
    });
  });

  group('rules', () {
    test('FEN roundtrip', () {
      const fen =
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1';
      expect(ChessGame.fromFen(fen).toFen(), fen);
    });
    test("fool's mate is checkmate for black", () {
      final g = ChessGame.startingPosition();
      for (final u in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        expect(g.playMove(_uci(g, u)), isNotNull);
      }
      expect(g.phase, GamePhase.checkmate);
      expect(g.winner, 'b');
      expect(g.sanHistory.last, 'Qh4#');
    });
    test('stalemate detection', () {
      final g = ChessGame.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(g.phase, GamePhase.stalemate);
      expect(g.winner, isNull);
    });
    test('castling SAN', () {
      final g = ChessGame.startingPosition();
      final sans = <String?>[];
      for (final u in ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5']) {
        sans.add(g.playMove(_uci(g, u)));
      }
      sans.add(g.playMove(_uci(g, 'e1g1')));
      expect(sans.last, 'O-O');
    });
    test('threefold repetition draws', () {
      final g = ChessGame.startingPosition();
      for (var i = 0; i < 3; i++) {
        for (final u in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
          g.playMove(_uci(g, u));
        }
      }
      expect(g.phase, GamePhase.draw);
    });
    test('undo restores position', () {
      final g = ChessGame.startingPosition();
      final before = g.toFen();
      g.playMove(_uci(g, 'e2e4'));
      expect(g.undo(), isTrue);
      expect(g.toFen(), before);
    });
  });

  group('puzzles', () {
    test('every bundled puzzle solution mates', () {
      for (final p in kPuzzles) {
        final g = ChessGame.fromFen(p.fen);
        final san = g.playMove(_uci(g, p.solutionUci));
        expect(san, isNotNull, reason: 'puzzle #${p.id} illegal');
        expect(g.phase, GamePhase.checkmate,
            reason: 'puzzle #${p.id} does not mate');
      }
    });
    test('puzzle pack integrity: kings, legality, canonical solution', () {
      for (final p in kPuzzles) {
        final g = ChessGame.fromFen(p.fen);
        expect(g.board.where((v) => v.abs() == king).length, 2,
            reason: 'puzzle #${p.id} must have exactly two kings');
        // The side that is NOT to move must not already be in check.
        expect(g.inCheck(!g.whiteToMove), isFalse,
            reason: 'puzzle #${p.id} starts with the wrong king in check');
        // The canonical solution must be one of the legal mating moves.
        final mates = <String>[];
        for (final m in g.legalMoves()) {
          final t = ChessGame.fromFen(p.fen);
          t.playMove(m);
          if (t.phase == GamePhase.checkmate) mates.add(m.toUci());
        }
        expect(mates, contains(p.solutionUci),
            reason: 'puzzle #${p.id} solution ${p.solutionUci} is not a mate '
                '(legal mating moves: $mates)');
      }
    });
  });

  group('AI', () {
    test('finds mate in 1', () {
      final g = ChessGame.fromFen(
          '7k/5ppp/8/8/8/8/8/R5K1 w - - 0 1');
      // Max ELO => zero blunder/noise => deterministic best play.
      final r = thinkSync(g.toFen(), CpuDifficulty.forElo(2100), seed: 1);
      final m = ChessMove((r['from']! as num).toInt(),
          (r['to']! as num).toInt(), (r['promotion']! as num).toInt());
      expect(g.playMove(m), isNotNull);
      expect(g.phase, GamePhase.checkmate);
    });
    test('returns a legal move from startpos (all levels)', () {
      for (final d in [
        CpuDifficulty.easy,
        CpuDifficulty.medium,
        CpuDifficulty.hard
      ]) {
        final g = ChessGame.startingPosition();
        final r = thinkSync(g.toFen(), d, seed: 7);
        final m = ChessMove((r['from']! as num).toInt(),
            (r['to']! as num).toInt(), (r['promotion']! as num).toInt());
        expect(g.playMove(m), isNotNull,
            reason: 'illegal move at ${d.name}');
      }
    });
  });

  group('elo', () {
    test('win vs equal opponent: +16 (K=32)', () {
      expect(
          Elo.newRating(
              mine: 1200, opponent: 1200, score: 1, gamesPlayed: 100),
          1216);
    });
    test('draw vs equal opponent: unchanged', () {
      expect(
          Elo.newRating(
              mine: 1200, opponent: 1200, score: 0.5, gamesPlayed: 100),
          1200);
    });
    test('beating a much stronger opponent gains a lot', () {
      final d = Elo.delta(
          mine: 1200, opponent: 1800, score: 1, gamesPlayed: 100);
      expect(d, greaterThan(25));
    });
  });

  group('draw awareness + budgets (v2)', () {
    test('repetition API counts occurrences', () {
      final g = ChessGame.startingPosition();
      for (var i = 0; i < 2; i++) {
        for (final u in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
          g.playMove(_uci(g, u));
        }
      }
      expect(g.positionCount(g.positionKey), 3); // start + 2 returns
      expect(g.searchRepeatsDraw(), isTrue);
    });
    test('tiny budget still returns a legal move (timeout path)', () {
      final g = ChessGame.startingPosition();
      final d = CpuDifficulty.hard.copyWith(timeBudgetMs: 30);
      expect(d.timeBudgetMs, 30);
      final r = thinkSync(g.toFen(), d, seed: 3);
      final m = ChessMove((r['from']! as num).toInt(),
          (r['to']! as num).toInt(), (r['promotion']! as num).toInt());
      expect(g.playMove(m), isNotNull);
    });
    test('endgame squeeze: lone king on the edge scores better for winner',
        () {
      // KQ vs K, black king centered vs cornered (same white material).
      final center =
          evaluate(ChessGame.fromFen('8/8/8/3k4/8/8/8/QK6 w - - 0 1'));
      final corner =
          evaluate(ChessGame.fromFen('k7/8/8/8/8/8/8/QK6 w - - 0 1'));
      expect(corner, greaterThan(center));
    });
    test('pawn structure: doubled pawns score worse than healthy', () {
      final healthy =
          evaluate(ChessGame.fromFen('k7/8/8/8/8/8/PP6/K7 w - - 0 1'));
      final doubled =
          evaluate(ChessGame.fromFen('k7/8/8/8/8/P7/P7/K7 w - - 0 1'));
      expect(healthy, greaterThan(doubled));
    });
    test('passed pawns are rewarded', () {
      final passed =
          evaluate(ChessGame.fromFen('k7/8/8/8/4P3/8/8/K7 w - - 0 1'));
      final blocked =
          evaluate(ChessGame.fromFen('k7/8/8/4p3/4P3/8/8/K7 w - - 0 1'));
      expect(passed, greaterThan(blocked));
    });
    test('uci parser maps engine moves onto legal moves', () {
      final g = ChessGame.startingPosition();
      final m = parseUciMove(g, 'e2e4');
      expect(m, isNotNull);
      expect(g.playMove(m!), isNotNull);
      expect(parseUciMove(g, 'e7e5'), isNotNull);
      expect(parseUciMove(g, 'zz99'), isNull); // garbage rejected
    });
    test('opening book plays sensible first moves (Expert path)', () {
      final g = ChessGame.startingPosition();
      final d = CpuDifficulty.forElo(1900);
      expect(d.depth, 5); // Expert tier exists (stockfish alternative)
      for (var i = 0; i < 4; i++) {
        final r = thinkSync(g.toFen(), d, seed: 7);
        final m = ChessMove((r['from']! as num).toInt(),
            (r['to']! as num).toInt(), (r['promotion']! as num).toInt());
        expect(g.playMove(m), isNotNull);
      }
      // Book or not, every reply must be legal and developing-ish.
      expect(g.moveHistory.length, 4);
    });
    test('setup snapshot round-trips (live-game resume)', () {
      final s = GameSetup(
        rated: true,
        timed: false,
        opponentName: 'CPU (Hard)',
        opponentFlag: 'cpu',
        opponentRating: 1600,
        difficulty: CpuDifficulty.hard,
        playerIsWhite: false,
        timeControl: timeControlById('blitz53'),
      );
      final back = GameSetup.fromJson(s.toJson());
      expect(back.timed, isFalse);
      expect(back.rated, isTrue);
      expect(back.difficulty.depth, 3);
      expect(back.timeControl.id, s.timeControl.id);
      expect(back.playerIsWhite, isFalse);
    });
  });

  group('evaluation (colour symmetry + black material)', () {
    test('mirror symmetry: colour-mirrored positions negate exactly', () {
      // Guards the p.abs() class of bug: black kings/pawns were once
      // compared against positive piece codes and silently ignored.
      const boards = [
        'k7/8/8/8/8/8/P7/K7',
        'k7/p7/8/8/8/8/8/K7',
        '8/8/8/3k4/8/8/8/QK6',
        'r3k2r/pp3ppp/2n5/8/8/2N5/PP3PPP/R3K2R',
        'k7/5p2/8/8/8/8/5P2/K7',
        'k7/pp6/8/8/8/8/PP6/K7',
      ];
      for (final b in boards) {
        final direct = evaluate(ChessGame.fromFen('$b w - - 0 1'));
        final mirrored =
            evaluate(ChessGame.fromFen('${_mirrorBoard(b)} w - - 0 1'));
        expect(direct, -mirrored, reason: 'asymmetric eval for $b');
      }
    });
    test('black doubled pawns are penalised', () {
      final healthy =
          evaluate(ChessGame.fromFen('k7/pp6/8/8/8/8/8/K7 w - - 0 1'));
      final doubled =
          evaluate(ChessGame.fromFen('k7/p7/p7/8/8/8/8/K7 w - - 0 1'));
      expect(doubled, greaterThan(healthy));
    });
    test('black passed pawn is rewarded (mirrored bonus table)', () {
      // e2 is two steps from promoting for black: the bonus must be the
      // highest one, not the lowest (rank mirroring bug).
      final nearPromo =
          evaluate(ChessGame.fromFen('k7/8/8/8/8/8/4p3/K7 w - - 0 1'));
      final homeRank =
          evaluate(ChessGame.fromFen('k7/4p3/8/8/8/8/8/K7 w - - 0 1'));
      expect(nearPromo, lessThan(homeRank));
    });
  });
}
