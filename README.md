# ♞ Chess Arena

A mobile chess app matching **goal.mp4**: home lobby, Play CPU (Easy / Medium / Hard),
simulated **Find Opponent** with ELO-matched CPU strength, 12 tactical puzzles +
daily puzzle, rankings, time controls (Rapid / Chill / Blitz / Tempo / Bullet),
full game screen with clocks, and a game-end ad hook (coming soon).

**Status: v1 local-first.** Fully playable offline (Hive storage). Supabase hybrid
mode is wired behind `--dart-define` flags — see [Supabase setup](docs/SUPABASE_SETUP.md).

| Backend | Status |
|---|---|
| Local (Hive) | ✅ active — profile, rating, coins, streaks, games, puzzles, settings |
| Supabase | 🟡 ready, not configured — auto-activates when URL + anon key are provided |
| Online play / matchmaking | 🔜 roadmap ([details](docs/ADS_AND_ONLINE_ROADMAP.md)) |
| Ads (post-game interstitial + banner) | 🔜 stubbed via `AdsService` |

## Quick start

```bash
flutter pub get
flutter test        # engine perft + rules + AI + puzzles + ELO
flutter run
```

Hybrid/online mode (after creating the tables in `supabase/schema.sql`):

```bash
flutter run --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

> The `sbp_...` token in `acesstoken.txt` is a Supabase **management** token —
> the app needs the **project URL + anon key** from Dashboard → Settings → API.
> Never commit real secrets; use `--dart-define` (see `.env.example`).

## Feature map (goal.mp4 → code)

| Video screen | Implementation |
|---|---|
| Home: header, TODAY card, Play Online, grid | `lib/ui/screens/home_screen.dart` |
| Bottom tabs Play / Friends / Rankings / Profile | `lib/app.dart` + `secondary_screens.dart` |
| Rankings list + 🌍/flag filter | `rankings_screen.dart` |
| Game board + clocks + player bars | `game_screen.dart` + `game/game_controller.dart` |
| Play CPU dialog (difficulty + color) | `ui/dialogs/app_dialogs.dart` |
| Time controls sheet (multi-select) | `app_dialogs.dart` + `data/time_controls.dart` |
| Settings dialog (7 toggles, persisted) | `app_dialogs.dart` + `SettingsController` |
| Puzzle #N + Wrong/Good banner + Solution/Hint | `puzzle_screens.dart` + `game/puzzle_controller.dart` |
| Post-game ad | `services/ads_service.dart` (stub) + placeholder in game-over dialog |
| Find Opponent | simulated rated match vs ELO-matched CPU (`CpuDifficulty.forElo`) |

## Project layout

```
lib/
  main.dart / app.dart            # boot (Hive → Supabase → providers) + tab shell
  core/                           # theme, AppConfig flags, ELO math
  engine/                         # pure-Dart chess: rules, AI, puzzles, isolate brain
  data/                           # Hive store, time controls, repository, Supabase
  game/                           # GameController (clocks, CPU loop, settlement)
  services/                       # sounds (bundled WAVs), ads stub
  ui/                             # screens, dialogs, board/piece/player widgets
test/engine_test.dart             # perft + rules + AI + puzzles + ELO tests
supabase/schema.sql               # profiles / games tables for hybrid mode
docs/                             # architecture, engine, supabase, ads/online roadmap
assets/sounds/                    # synthesized move/capture/check/win/... effects
```

Docs: [ARCHITECTURE](docs/ARCHITECTURE.md) · [CPU_ENGINE](docs/CPU_ENGINE.md) ·
[SUPABASE_SETUP](docs/SUPABASE_SETUP.md) · [ADS_AND_ONLINE_ROADMAP](docs/ADS_AND_ONLINE_ROADMAP.md)

## Design decisions (v1)

- **Self-contained chess engine** (no `chess` package): full move-gen, FEN, SAN,
  all draw rules, verified by standard perft suites in `flutter test`.
- **CPU = minimax + alpha-beta + quiescence**, ELO-mapped (depth/blunder/noise),
  computed on a background isolate so the UI never janks.
- **Offline-first**: every feature works without network; Supabase is an
  additive sync layer, all guarded with try/catch fallbacks.
- **Vector pieces** via [`chess_vectors_flutter`](https://pub.dev/packages/chess_vectors_flutter)
  (Wikimedia-style set) + bespoke SVG icons (time controls, coin) rendered
  with [`flutter_svg`](https://pub.dev/packages/flutter_svg) — no emoji art.
- **Scoped rebuilds**: the 100 ms clock ticker only repaints the clock
  leaves (`Selector` snapshots); board/move-list rebuild solely on moves.
- **CPU safety**: repetition-aware search (no sleepy threefolds while
  winning), clock-scaled think budgets (never self-flags in Bullet),
  unrated aborts when resigning before your first move, and draw offers.
- **v3 (video parity round 2)**: casual CPU games are untimed; human-like
  CPU pacing; CPU offers draws in dead-drawn endgames; endgame king-squeeze
  eval (real mating urgency); 2-takeback cap in rated games; simulated
  opponent chat with unread badge; live-game snapshots → resume after app
  restart; 20 s no-show abort countdown; hamburger game menu (mute/draw/
  friend/resign); video-style confirm dialogs; rich game-over sheet with
  animated rating count; chat bottom sheet; puzzle thumbnails; 3 board
  themes; rebuilt Profile tab (Customize/Rules/Remove-Ads); 3D home tiles.
