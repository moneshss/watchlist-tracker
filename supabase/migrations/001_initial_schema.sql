-- ============================================================
-- IDEMPOTENT TEARDOWN (drop in reverse dependency order)
-- ============================================================
drop view  if exists public.watchlist_with_shows;

drop table if exists public.episode_progress  cascade;
drop table if exists public.season_progress   cascade;
drop table if exists public.watchlist_items   cascade;
drop table if exists public.shows             cascade;
drop table if exists public.profiles          cascade;

drop type if exists season_status    cascade;
drop type if exists watchlist_status cascade;

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop function if exists public.set_updated_at();


-- ============================================================
-- PROFILES (extends Supabase auth.users)
-- ============================================================
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================
-- SHOWS (cached TMDB metadata, shared across all users)
-- ============================================================
create table public.shows (
  tmdb_id            integer primary key,
  title              text not null,
  original_title     text,
  poster_path        text,
  backdrop_path      text,
  overview           text,
  status             text,                   -- 'Returning Series', 'Ended', 'Canceled', 'In Production'
  first_air_date     date,
  last_air_date      date,
  number_of_seasons  integer,
  number_of_episodes integer,
  episode_run_time   integer,                -- average runtime in minutes (derived)
  vote_average       numeric(4,2),           -- TMDB score (0-10)
  vote_count         integer,
  genres             jsonb default '[]',     -- [{id, name}, ...]
  networks           jsonb default '[]',     -- [{id, name, logo_path}, ...]
  watch_providers    jsonb default '{}',     -- keyed by region, from TMDB watch/providers
  seasons_data       jsonb default '[]',     -- [{season_number, name, episode_count, air_date, poster_path}, ...]
  homepage           text,
  last_synced_at     timestamptz not null default now()
);

create index idx_shows_title on public.shows using gin (to_tsvector('english', title));


-- ============================================================
-- WATCHLIST ITEMS (a user's relationship with a show)
-- ============================================================
create type watchlist_status as enum (
  'want_to_watch',
  'watching',
  'finished',
  'dropped',
  'on_hold'
);

create table public.watchlist_items (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  tmdb_id        integer not null references public.shows(tmdb_id) on delete cascade,
  status         watchlist_status not null default 'want_to_watch',
  note           text,                       -- "why did I add this?"
  priority       integer default 0,          -- lower = higher priority (Phase 2)
  overall_rating smallint                    -- 1-5, set after finishing show (Phase 2)
    check (overall_rating between 1 and 5),
  started_at     timestamptz,                -- Phase 2: when user started watching
  finished_at    timestamptz,                -- Phase 2: when user finished the show
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  unique (user_id, tmdb_id)
);

create index idx_watchlist_user   on public.watchlist_items(user_id);
create index idx_watchlist_status on public.watchlist_items(user_id, status);


-- ============================================================
-- SEASON PROGRESS
-- ============================================================
create type season_status as enum (
  'not_started',
  'watching',
  'finished'
);

create table public.season_progress (
  id                uuid primary key default gen_random_uuid(),
  watchlist_item_id uuid not null references public.watchlist_items(id) on delete cascade,
  season_number     integer not null,
  total_episodes    integer not null default 0,
  watched_episodes  integer not null default 0,
  status            season_status not null default 'not_started',
  rating            smallint                    -- Phase 2: 1-5
    check (rating between 1 and 5),
  notes             text,                       -- Phase 2
  started_at        timestamptz,                -- Phase 2
  finished_at       timestamptz,                -- Phase 2
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique (watchlist_item_id, season_number)
);

create index idx_season_progress_item on public.season_progress(watchlist_item_id);


-- ============================================================
-- EPISODE PROGRESS (Phase 2 — create table now, populate later)
-- ============================================================
create table public.episode_progress (
  id                 uuid primary key default gen_random_uuid(),
  season_progress_id uuid not null references public.season_progress(id) on delete cascade,
  episode_number     integer not null,
  episode_title      text,
  runtime_minutes    integer,
  watched            boolean not null default false,
  watched_at         timestamptz,
  notes              text,
  created_at         timestamptz not null default now(),

  unique (season_progress_id, episode_number)
);

create index idx_episode_progress_season on public.episode_progress(season_progress_id);


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- profiles: users can only read/update their own row
alter table public.profiles enable row level security;
create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- shows: any authenticated user can read; writes go through the service role
alter table public.shows enable row level security;
create policy "Authenticated users can read shows"
  on public.shows for select using (auth.role() = 'authenticated');

-- watchlist_items: users own their rows
alter table public.watchlist_items enable row level security;
create policy "Users can CRUD own watchlist items"
  on public.watchlist_items for all using (auth.uid() = user_id);

-- season_progress: gate via the parent watchlist_item
alter table public.season_progress enable row level security;
create policy "Users can CRUD own season progress"
  on public.season_progress for all
  using (
    exists (
      select 1 from public.watchlist_items wi
      where wi.id = season_progress.watchlist_item_id
        and wi.user_id = auth.uid()
    )
  );

-- episode_progress: gate via season_progress → watchlist_item
alter table public.episode_progress enable row level security;
create policy "Users can CRUD own episode progress"
  on public.episode_progress for all
  using (
    exists (
      select 1
      from public.season_progress sp
      join public.watchlist_items wi on wi.id = sp.watchlist_item_id
      where sp.id = episode_progress.season_progress_id
        and wi.user_id = auth.uid()
    )
  );


-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.watchlist_items
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.season_progress
  for each row execute function public.set_updated_at();


-- ============================================================
-- VIEWS
-- ============================================================
create or replace view public.watchlist_with_shows as
select
  wi.*,
  s.title,
  s.poster_path,
  s.status            as production_status,
  s.vote_average,
  s.number_of_seasons,
  s.number_of_episodes,
  s.episode_run_time,
  s.networks,
  s.first_air_date,
  s.genres
from public.watchlist_items wi
join public.shows s on s.tmdb_id = wi.tmdb_id;
