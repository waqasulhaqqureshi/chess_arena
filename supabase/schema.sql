-- Chess Arena — Supabase schema (v1 hybrid mode).
-- Run in Dashboard → SQL Editor. See docs/SUPABASE_SETUP.md.

-- ---------------------------------------------------------------- profiles
create table if not exists profiles (
  id text primary key,                 -- guest id (auth.uid() later)
  name text not null default 'Guest',
  flag text not null default '🏳️',
  rating integer not null default 1200,
  coins integer not null default 550,
  updated_at timestamptz not null default now()
);

create index if not exists profiles_rating_idx
  on profiles (rating desc);

-- ------------------------------------------------------------------- games
create table if not exists games (
  id bigint generated always as identity primary key,
  player_id text not null,
  opponent text not null default 'CPU',
  opponent_rating integer not null default 600,
  my_color text not null default 'w',  -- 'w' | 'b'
  result text not null default 'w',    -- 'w' | 'd' | 'l' (from player's view)
  rating_before integer not null default 1200,
  rating_after integer not null default 1200,
  moves text not null default '',      -- space-joined SAN
  time_control text not null default 'blitz53',
  created_at timestamptz not null default now()
);

create index if not exists games_player_idx on games (player_id);
create index if not exists games_created_idx on games (created_at desc);

-- ------------------------------------------------------- test RLS policies
-- OPEN policies for v1 testing (any anon client can read/write).
-- ⚠️ Tighten before public release — see docs/SUPABASE_SETUP.md §2.
alter table profiles enable row level security;
alter table games enable row level security;

drop policy if exists "open_all_test" on profiles;
create policy "open_all_test" on profiles
  for all using (true) with check (true);

drop policy if exists "open_all_test" on games;
create policy "open_all_test" on games
  for all using (true) with check (true);
