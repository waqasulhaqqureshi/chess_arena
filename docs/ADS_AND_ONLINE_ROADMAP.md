# Ads + Online Roadmap

## Post-game ads (goal.mp4 shows a fullscreen ad after every game)

**Now (v1):** `AdsService.showGameEndAd()` is a logged no-op; the game-over
dialog and game screen show clearly-labeled placeholders. No ad SDK is
bundled, so builds stay lean and policy-safe.

**To integrate (`google_mobile_ads`):**

1. `flutter pub add google_mobile_ads`
2. Android: add your AdMob App ID to
   `android/app/src/main/AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`).
   iOS: add `GADApplicationIdentifier` to `ios/Runner/Info.plist`.
3. In `AdsService`:
   - `MobileAds.instance.initialize()` at boot (guard with `AppConfig.adsEnabled`).
   - Preload an `InterstitialAd` when a game starts; `show()` it in
     `showGameEndAd()`; reload after dismissal.
   - Replace `showBannerPlaceholder` with a real `BannerAd` (`adUnitId` from
     `--dart-define`).
4. Run with `--dart-define=ADS_ENABLED=true` and test-device IDs first —
   never click live ads on dev builds.

Files to touch: `lib/services/ads_service.dart` only (+ platform manifests).
Call sites (`GameController._finish`, `game_screen.dart`) already exist.

## Real online play (matchmaking, friends, watch, accounts)

Planned on top of the current seams (no rewrites of engine/UI state):

1. **Auth** — Supabase anonymous → permanent accounts; `profiles.id` becomes
   `auth.uid()`. Guest data migrates on first link.
2. **Presence + matchmaking queue** — `match_queue` table (player, rating,
   time_controls, since) + a Postgres function matching rating windows;
   `HomeScreen._findOpponent` swaps its simulated delay for a realtime
   subscription (the `GameSetup`/`GameController` flow is unchanged —
   `CpuDifficulty` is replaced by a `RemoteOpponent` move stream).
3. **Live games** — `game_rooms` + Realtime Broadcast for moves/clocks;
   clocks stay authoritative via server timestamps; `WatchScreen` subscribes
   to featured rooms.
4. **Friends** — `friendships` table; `FriendsScreen` search/challenge.
5. **Puzzles/leaderboards at scale** — move puzzle rewards server-side
   (anti-cheat), add seasons to `profiles`.

## Gemini key (`acesstoken.txt`)

The bundled Gemini API key is **not needed for v1** (all art is code-drawn
or synthesized offline). Keep it for future features (AI game review,
puzzle explanations, avatar generation). If used, call it from a Supabase
Edge Function — never embed the key in the client.
