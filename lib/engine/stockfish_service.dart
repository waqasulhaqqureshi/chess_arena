/// Stockfish integration via the community `stockfish` package
/// (bundles the native engine + FFI for Android/iOS — no hand-written
/// native code).
///
/// Safety: every entry point is wrapped; on platforms where the native
/// binary cannot load (e.g. desktop CI, web) the service reports
/// unavailable and callers fall back to the built-in Arena AI brain.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

import 'chess_rules.dart';

/// Parses a UCI move like `e2e4` / `e7e8q` into a legal [ChessMove].
ChessMove? parseUciMove(ChessGame g, String uci) {
  if (uci.length < 4) return null;
  int sq(int o) => (uci.codeUnitAt(o + 1) - 49) * 8 + (uci.codeUnitAt(o) - 97);
  if (sq(0) < 0 || sq(0) > 63 || sq(2) < 0 || sq(2) > 63) return null;
  const promo = {'n': knight, 'b': bishop, 'r': rook, 'q': queen};
  final p = uci.length > 4 ? (promo[uci[4]] ?? 0) : 0;
  for (final m in g.legalMoves()) {
    if (m.from == sq(0) && m.to == sq(2) && m.promotion == p) return m;
  }
  return null;
}

class StockfishService {
  StockfishService._();
  static final StockfishService instance = StockfishService._();

  Stockfish? _sf;
  bool _probed = false;
  bool _available = false;
  Future<void> _queue = Future.value();

  bool get available => _available;

  /// Starts the native engine once; never throws.
  Future<bool> ensureReady() async {
    if (_probed) return _available;
    _probed = true;
    try {
      final sf = Stockfish();
      _sf = sf;
      final deadline = DateTime.now().add(const Duration(milliseconds: 4000));
      while (sf.state.value != StockfishState.ready &&
          DateTime.now().isBefore(deadline)) {
        if (sf.state.value == StockfishState.disposed) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _available = sf.state.value == StockfishState.ready;
      debugPrint('[Stockfish] ready=$_available');
    } catch (e) {
      debugPrint('[Stockfish] unavailable on this platform: $e');
      _available = false;
    }
    return _available;
  }

  /// Queued UCI best-move query. Returns UCI string or null (caller
  /// falls back to the Arena brain).
  Future<String?> bestMoveUci(
    String fen, {
    required int skillLevel,
    required int movetimeMs,
  }) {
    final job = _queue.then<String?>(
      (_) => _search(fen, skillLevel, movetimeMs),
    );
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  Future<String?> _search(String fen, int skill, int movetimeMs) async {
    final sf = _sf;
    if (!_available || sf == null) return null;
    try {
      final got = Completer<String?>();
      late StreamSubscription<String> sub;
      sub = sf.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (!got.isCompleted) {
            got.complete(parts.length > 1 ? parts[1] : null);
          }
          sub.cancel();
        }
      });
      sf.stdin = 'setoption name Skill Level value ${skill.clamp(0, 20)}';
      sf.stdin = 'position fen $fen';
      sf.stdin = 'go movetime $movetimeMs';
      final res = await got.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          sf.stdin = 'stop';
          return null;
        },
      );
      await sub.cancel();
      return res;
    } catch (e) {
      debugPrint('[Stockfish] search failed, falling back: $e');
      _available = false;
      return null;
    }
  }
}
