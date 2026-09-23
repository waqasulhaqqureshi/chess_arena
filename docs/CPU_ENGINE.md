# CPU Engine

Pure-Dart engine in `lib/engine/`. No platform channels, no native binaries —
runs on Android / iOS / web / desktop identically.

## Rules (`chess_rules.dart`)

- 8×8 mailbox board, `sq = rank*8+file` (rank 0 = white home rank).
- Full legal move generation: pins/check evasion by make-test-unmake,
  castling (rights + transit attacks), en passant, promotion (all 4 pieces).
- End detection: checkmate, stalemate, fifty-move, threefold repetition
  (position-count map), insufficient material (K v K, K+minor v K).
- FEN parse/emit, SAN with disambiguation + `+`/`#`, snapshot undo stack.
- `perft(depth)` helper backs the test suite.

## Search (`chess_ai.dart`)

- Negamax + alpha-beta, MVV-LVA + promotion move ordering.
- Quiescence search on captures/promotions (stand-pat + check evasions),
  depth-capped per difficulty.
- Static eval (white perspective, centipawns): material
  (100/320/330/500/900) + Simplified-Evaluation-Function piece-square tables.
- Time budget + 400k node cap; timeout keeps best-so-far (no hangs on Bullet).

## Difficulty ↔ ELO mapping

| Preset | ELO | Depth | Quiescence | Blunder | Noise | Budget |
|---|---|---|---|---|---|---|
| Easy | ~600 | 1 | 2 | 25% | ±140 cp | 250 ms |
| Medium | ~1100 | 2 | 4 | 8% | ±45 cp | 600 ms |
| Hard | ~1600 | 3 | 6 | 2% | ±12 cp | 1400 ms |

`CpuDifficulty.forElo(elo)` interpolates the same knobs continuously
(~400–2100) so **Find Opponent** (currently simulated) and Daily Challenge
scale with your rating: depth 1 → 2 → 3, blunder 30% → 0%, noise ±150 → 0.

- *Blunder* = plays a uniformly random legal move (human-like mistake).
- *Noise* = random jitter added to each root score (variety + inaccuracy).
- Single-reply positions return instantly.

## Threading (`cpu_brain.dart`)

`CpuBrain.think` runs `cpuThinkEntry` via `compute()` (FEN + difficulty JSON
are isolate-safe) with a synchronous fallback. `GameController` invalidates
stale searches with a monotonic `_thinkToken` (takeback / resign / dispose).

## Future upgrades

1. Iterative deepening + aspiration windows (better time use).
2. Transposition table (needs fixed-size typed store for isolates).
3. Opening book (a few hundred weighted lines as a bundled JSON).
4. Stockfish (UCI over platform channel / `stockfish` plugin) as an
   "Expert+" tier — `GameController` only depends on the `CpuResult`
   shape, so the swap is contained in `cpu_brain.dart`.
