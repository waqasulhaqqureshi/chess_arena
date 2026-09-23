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

## Draw awareness + clock-aware budgets (v2)

- **Repetition**: `ChessGame` exposes `positionKey` / `positionCount` and
  tracks the active search path (`trackSearchKeys`). Any node repeating a
  position twice before scores 0 (`searchRepeatsDraw`), and the root drops
  moves that instantly complete a threefold — unless the CPU is losing
  (static eval < −300 cp), in which case it happily takes the draw.
- **Time fairness**: `CpuBrain.think(..., clockMs:, incrementMs:)` scales
  the budget to `clock/25 + increment` (min 80 ms), so Hard can't flag
  itself in Bullet with 0.5 s left.
- **Endgame squeeze (v3)**: `evaluate()` adds king-edge + king-proximity
  terms when one side has a lone king vs mating material, so the CPU
  drives mates home instead of shuffling.
- **Human pacing (v3)**: the controller delays applying the computed reply
  by 0.6–2.2 s (scaled by ELO; <0.5 s when the CPU clock is low), so
  opponents feel human instead of instant.
- **CPU draw offers (v3)**: after move 30 in rated games, |eval| < 15 cp
  triggers a once-per-game draw offer (chat line + accept/decline dialog).

## Stockfish (v5) — integrated via community package

`stockfish ^1.8.1` (verified publisher) bundles the native engine + FFI
for **Android & iOS**, so no hand-written C++/CMake is needed.

- `lib/engine/stockfish_service.dart` owns the single engine instance,
  serializes queries, and maps opponent ELO → UCI `Skill Level 0..20` +
  `go movetime` (200 ms when its clock is low).
- **Graceful degradation**: `ensureReady()` probes the binary once (4 s
  cap). If it cannot load (desktop/web/CI) or a search fails, the service
  reports unavailable and `GameController` falls back to the Arena brain —
  the app never crashes on an unsupported platform.
- Toggle: Settings → "Stockfish engine (Android/iOS)" (default on).
- License note: Stockfish is GPL-3.0; shipping the app publicly inherits
  its copyleft obligations — fine for this project, just be aware.

The Arena brain keeps its own upgrades as the universal fallback:

1. **Embedded opening book** (`_book` in `chess_ai.dart`): instant,
   correct opening moves at ≥1000 ELO for the first ~3 moves each side.
2. **Iterative deepening**: the root search now completes depth 1..N and
   keeps the last finished depth on timeout — safe at any budget.
3. **Expert tier**: `CpuDifficulty.forElo(≥1800)` → depth 4, 2.2 s budget.

## v6: launch-strength evaluation

`evaluate()` now also scores bishop pair (+30), doubled (−12) and isolated
(−10) pawns, and passed pawns (+4..+70 by rank), so the fallback brain
plays real plans when Stockfish isn't available. The book covers 19 main
lines for both colors; Expert searches to depth 5 (2.6 s, iterative
deepening keeps it safe).

## v4 upgrades

- **Piece images**: `PieceWidget` renders the MIT `chess_interface`
  package's fillable `modern_minimalist` PNGs and tints them white/black with
  `ColorFilter`/`BlendMode.srcIn` (white sprite + filter = black piece).
  `errorBuilder` falls back to `chess_vectors_flutter`.
- **Avatars**: `random_avatar` Multiavatar identicons (offline, seeded by
  player name); flags picked with `country_pickers`.

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
