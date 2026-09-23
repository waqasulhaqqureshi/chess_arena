/// Isolate-backed CPU thinking so search never blocks the UI.
///
/// Falls back to synchronous search if isolates are unavailable.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chess_ai.dart';
import 'chess_rules.dart';

class CpuResult {
  final ChessMove? move;
  final int scoreCp; // side-to-move perspective
  final int depth;
  final int nodes;
  final bool wasBlunder;

  const CpuResult({
    required this.move,
    required this.scoreCp,
    required this.depth,
    required this.nodes,
    this.wasBlunder = false,
  });

  factory CpuResult.fromMap(Map<String, Object?> m) {
    if (m['none'] == true) {
      return const CpuResult(move: null, scoreCp: 0, depth: 0, nodes: 0);
    }
    return CpuResult(
      move: ChessMove(
        (m['from']! as num).toInt(),
        (m['to']! as num).toInt(),
        (m['promotion']! as num).toInt(),
      ),
      scoreCp: (m['score']! as num).toInt(),
      depth: (m['depth']! as num).toInt(),
      nodes: (m['nodes']! as num).toInt(),
      wasBlunder: m['blunder'] == true,
    );
  }
}

class CpuBrain {
  /// Computes the CPU reply for [game]'s side to move.
  static Future<CpuResult?> think(ChessGame game, CpuDifficulty diff) async {
    final args = <String, Object?>{
      'fen': game.toFen(),
      'diff': diff.toJson(),
      'seed': Random().nextInt(1 << 30),
    };
    try {
      final res = await compute(cpuThinkEntry, args);
      return CpuResult.fromMap(res);
    } catch (_) {
      // Isolate unavailable (some embedders) — think on the UI thread.
      try {
        return CpuResult.fromMap(thinkSync(game.toFen(), diff));
      } catch (_) {
        return null;
      }
    }
  }
}
