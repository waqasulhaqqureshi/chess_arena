# Supabase Setup (hybrid mode)

The app is **local-first**: without credentials it runs 100% offline on Hive.
Provide a project URL + anon key and it upgrades itself to hybrid mode —
rankings go live, profiles/games sync to the cloud (all calls are guarded;
any failure silently falls back to local).

## 1. About your token

`acesstoken.txt` holds a **`sbp_...` personal access token**. That token is
for the Supabase **Management API** (`api.supabase.com`) — it cannot be used
directly by the Flutter app. The app needs, from
**Dashboard → Project Settings → API**:

- `SUPABASE_URL` — e.g. `https://xyzcompany.supabase.co`
- `SUPABASE_ANON_KEY` — the `anon` / `public` key (JWT starting with `eyJ…`)

Keep the `sbp_...` token for admin work only (creating projects, running SQL
via API). Never ship it inside the app.

## 2. Create the tables

Open **Dashboard → SQL Editor**, paste `supabase/schema.sql`, and run it.
It creates:

- `profiles (id, name, flag, rating, coins, updated_at)` — leaderboard source
- `games (...)` — finished-game archive for future replays/stats

The schema ships with **open test policies** (`USING (true)`) so the v1 app
works instantly. Tighten before any public release:

```sql
-- example: lock writes to the owning guest id once auth lands
drop policy if exists "open_all_test" on profiles;
create policy "owner_write" on profiles
  for all using (auth.uid()::text = id) with check (auth.uid()::text = id);
```

## 3. Run hybrid mode

```bash
flutter run --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Startup log tells you the mode:

- `[Boot] Supabase: online (hybrid mode)` ✅
- `[Boot] Supabase: offline (local-only mode)` — flags missing
- `[Boot] Supabase: error (local-only mode)` — reachable but misconfigured

The Profile tab also shows a live `Supabase: Online / Local only` chip.

## 4. What syncs (v1)

| Direction | Data | Code |
|---|---|---|
| ↓ pull | Top-50 leaderboard (`name, flag, rating`) | `SupabaseService.fetchRankings` ← `ArenaRepository.rankings()` |
| ↑ push | Profile upsert after rating/coin changes | `ArenaRepository._syncProfile` |
| ↑ push | Finished game records | `SupabaseService.saveGame` |

All pushes are fire-and-forget; offline queues + realtime matchmaking are
roadmap items (see `ADS_AND_ONLINE_ROADMAP.md`).

## 5. Troubleshooting

- **Rankings still show the offline board** → check the boot log; most
  likely the anon key/URL is wrong or the `profiles` table doesn't exist yet.
- **401/permission errors** → schema policies (step 2) weren't applied.
- **Works on Wi-Fi but not mobile data** → Supabase project paused (free
  tier auto-pauses) — resume it in the dashboard.
