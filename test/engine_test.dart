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
    test('opening book plays sensible first moves (Expert path)', () {
      final g = ChessGame.startingPosition();
      final d = CpuDifficulty.forElo(1900);
      expect(d.depth, 4); // Expert tier exists (stockfish alternative)
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
}
