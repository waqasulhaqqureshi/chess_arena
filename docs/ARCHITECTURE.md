# Architecture

## Layers

```
┌────────────────────────────────────────────────────┐
│ UI  screens · dialogs · widgets (Provider watch)   │
├────────────────────────────────────────────────────┤
│ Game  GameController · PuzzleController (per-game  │
│       ChangeNotifiers: selection, clocks, AI loop) │
├────────────────────────────────────────────────────┤
│ Data  ArenaRepository · SettingsController (app    │
│       scope) → Database (Hive) + SupabaseService   │
├────────────────────────────────────────────────────┤
│ Engine  chess_rules · chess_ai · puzzles (pure     │
│         Dart, zero Flutter imports — unit tested)  │
└────────────────────────────────────────────────────┘
```

- **UI never touches Hive or Supabase directly** — everything flows through
  `ArenaRepository` / `SettingsController`, so the online migration is
  contained.
- **Engine is framework-free**: `flutter test test/engine_test.dart` verifies
  move generation (perft), rules, puzzles, AI legality and ELO math.

## Key flows

### Vs-CPU / simulated-online game

1. `HomeScreen` builds a `GameSetup` (Play CPU dialog or Find Opponent
   matchmaking → `CpuDifficulty.forElo(playerRating ± 200)`).
2. `GameScreen` creates a `GameController`: clock init → optional CPU opener.
3. Player taps → `tapSquare` (selection → legal dots → promotion/confirm
   handling) → `playMove` → clock update → `_cpuMove()`.
4. CPU: 350 ms breathing room → `CpuBrain.think` on an isolate (`compute`
   with `cpuThinkEntry`, sync fallback) → guarded by `_thinkToken` so
   stale results (after takeback/dispose) are dropped.
5. End (mate/stalemate/draw/flag/resign) → `_finish`: rating via `Elo`,
   coins, daily/mission progress, game record saved to Hive + queued to
   Supabase, `AdsService.showGameEndAd()` hook, `GameOverInfo` → dialog.

### Clocks

- Classic (`seconds` + `increment`): one countdown per side on a 100 ms
  ticker; increment is added to the mover after each move.
- Per-move (`moveSeconds`: Chill 60 s, Tempo 20 s): mover's clock resets
  after each move; expiry flags that side. Bare-king-on-time → draw.

### Puzzles

- 12 hand-verified mate-in-1s (`engine/puzzles.dart`); daily rotates by
  day-of-year. Controller accepts **any** mating move (robust to alternate
  solutions); wrong moves flash and auto-take-back. Hint (−10 🪙) highlights
  the solution squares; Solution (−20 🪙) auto-plays it (no reward).

### Persistence (Hive boxes)

| Box | Contents |
|---|---|
| `chess_arena_profile` | guest id/name, rating, coins, W/D/L, form, streak, missions, timeControls, flag |
| `chess_arena_settings` | 7 board/UI toggles |
| `chess_arena_games` | last 100 game records (result, ratings, SAN, time control) |
| `chess_arena_puzzles` | solved ids, daily solved date |

Plain Maps only — no codegen adapters.

## Conventions

- Files start with a `///` doc comment and end with `library;`-style
  section banners for long files.
- New screens: add to `lib/ui/screens/`, reuse `ArenaCard` / `ArenaButton` /
  `showArenaSnack` from `ui/widgets/app_widgets.dart`.
- `debugPrint` for service logs; user-facing errors via snackbar, never crash.
- Hot paths (game screen) use `Selector` snapshots (`_BoardView`,
  `_ClockView`, `_InfoView`) + `RepaintBoundary` so the clock ticker never
  rebuilds the board; keep new per-tick widgets out of `watch` subtrees.
- **Live-game snapshots (v3)**: `GameController` persists setup + move log
  + clocks to Hive after every move (`repo.saveLiveGame`); `HomeScreen`
  offers Resume on launch; snapshot cleared at game end. `GameSetup` and
  `CpuDifficulty` are fully JSON-serializable for this.
- **Chat simulation (v3)**: scripted opponent lines live in
  `GameController` (`sendChat`, `unread`); UI badge on the game top bar.
- **Matchmaking (v6)**: `MatchmakingService.tryOnline` (Supabase lobby,
  null until online update) → `simulatedHuman` fallback with realistic
  identity (name pool + ISO flag + rating near player ± form boost).
  Flags render via `country_pickers` (`flagWidget` in `piece_widget.dart`);
  avatars via `random_avatar` identicons seeded by the name.
