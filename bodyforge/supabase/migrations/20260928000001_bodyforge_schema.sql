-- BODYFORGE schema
-- Reference data (read-only for users) + user-owned tables protected by RLS.
-- Column names match the app's local SQLite schema 1:1 (lib/data/local/tables.dart)
-- so offline changes sync without translation.
--
-- Safe to run on a fresh project. It only CREATEs objects (IF NOT EXISTS where
-- possible) and never drops or truncates anything.

-- ─────────────────────────────────────────────────────────────────────────────
-- Safety guard: refuse to run on a project that already has same-named
-- objects BODYFORGE didn't create (e.g. another app's `profiles` table).
-- Nothing is changed if this check fails. Re-running on a BODYFORGE database
-- is fine: every object below is labelled with a 'BODYFORGE' comment.
-- ─────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  t text;
  clashes text[] := '{}';
begin
  foreach t in array array['exercises', 'skill_paths', 'skill_nodes', 'nutrition_items', 'challenges', 'achievements', 'profiles', 'goals', 'programs', 'program_days', 'workouts', 'workout_sets', 'personal_records', 'measurements', 'skill_progress', 'recovery_checks', 'challenge_progress', 'challenge_checkins', 'user_achievements', 'journey_progress', 'milestones', 'food_prices', 'sync_metadata'] loop
    if to_regclass('public.' || t) is not null
       and coalesce(obj_description(to_regclass('public.' || t), 'pg_class'), '') not like 'BODYFORGE%' then
      clashes := clashes || ('table public.' || t);
    end if;
  end loop;
  if to_regprocedure('public.delete_my_account()') is not null
     and coalesce(obj_description(to_regprocedure('public.delete_my_account()'), 'pg_proc'), '') not like 'BODYFORGE%' then
    clashes := clashes || 'function public.delete_my_account()'::text;
  end if;
  if array_length(clashes, 1) > 0 then
    raise exception 'BODYFORGE migration stopped: these already exist and were not created by BODYFORGE: %. Use a new, empty Supabase project for BODYFORGE.', array_to_string(clashes, ', ');
  end if;
end
$guard$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Server-side sync stamp. Clients pull "rows with synced_at > my cursor", so a
-- row pushed late with an old client timestamp is still picked up by others.
create or replace function public.bf_set_synced_at()
returns trigger
language plpgsql
as $$
begin
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

-- Last-write-wins guard: an update carrying an older updated_at than the row
-- already on the server is ignored (the newer row stays, and clients pull it).
create or replace function public.bf_last_write_wins()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at < old.updated_at then
    return null; -- skip this update
  end if;
  return new;
end;
$$;

-- Achievements keep the earliest unlock time when two devices unlocked the same one.
create or replace function public.bf_keep_earliest_unlock()
returns trigger
language plpgsql
as $$
begin
  new.unlocked_at := least(old.unlocked_at, new.unlocked_at);
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Reference data (seeded by supabase/seed.sql; users can only read)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.exercises (
  id text primary key,
  name text not null,
  area text not null,
  pattern text not null,
  focus text[] not null default '{}',
  difficulty smallint not null check (difficulty between 1 and 10),
  unit text not null check (unit in ('reps', 'seconds')),
  per_side boolean not null default false,
  space text not null check (space in ('small', 'medium', 'large')),
  impact boolean not null default false,
  floor_work boolean not null default true,
  knee_stress boolean not null default false,
  wrist_stress boolean not null default false,
  props text[] not null default '{}',
  seconds_per_rep numeric(4,1) not null default 3,
  family text,
  mobility boolean not null default false,
  warmup boolean not null default false,
  demo text not null,
  summary text not null default '',
  cues text[] not null default '{}',
  mistakes text[] not null default '{}'
);

create table if not exists public.skill_paths (
  id text primary key,
  name text not null,
  area text not null,
  goal_label text not null,
  rep_min smallint not null,
  rep_max smallint not null,
  hold_min smallint not null,
  hold_max smallint not null,
  sort smallint not null default 0
);

create table if not exists public.skill_nodes (
  id text primary key,                      -- '<path_id>:<position>'
  path_id text not null references public.skill_paths(id),
  position smallint not null,
  exercise_id text not null references public.exercises(id),
  alternatives text[] not null default '{}',
  milestone boolean not null default false,
  unique (path_id, position)
);

create table if not exists public.nutrition_items (
  id text primary key,
  name text not null,
  aka text,
  category text not null,
  serving text not null,
  kcal integer not null,
  protein numeric(5,1) not null,
  carbs numeric(5,1) not null,
  fat numeric(5,1) not null,
  price_ghs numeric(7,2) not null,
  tips text[] not null default '{}'
);

create table if not exists public.challenges (
  id text primary key,
  title text not null,
  tagline text not null,
  description text not null,
  daily_prompt text not null,
  check_type text not null,
  days_required smallint not null default 7,
  daily_target smallint not null default 1,
  protein_target numeric(5,1) not null default 0,
  price_limit_ghs numeric(7,2) not null default 0,
  tips text[] not null default '{}'
);

create table if not exists public.achievements (
  id text primary key,
  title text not null,
  description text not null,
  tier text not null,
  icon text not null,
  target integer not null default 1
);

-- ─────────────────────────────────────────────────────────────────────────────
-- User-owned tables. Every one has: id, user_id, created_at, updated_at,
-- deleted_at (soft delete, so deletions sync) and synced_at (server stamp).
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  name text not null,
  age integer not null check (age between 16 and 100),
  sex text not null,
  height_cm double precision not null,
  weight_kg double precision not null,
  fitness_level text not null,
  experience text not null,
  days_per_week integer not null check (days_per_week between 1 and 7),
  session_minutes integer not null check (session_minutes between 5 and 90),
  environment text not null,
  limitations text not null default '{}',
  preferred_days text not null default '[]',
  workout_style text not null,
  push_ability text not null,
  squat_ability text not null,
  plank_ability text not null,
  journey_start date not null,
  constraint profiles_id_is_user check (id = user_id::text)
);

create table if not exists public.goals (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  goal text not null
);

create table if not exists public.programs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  name text not null,
  source text not null check (source in ('generated', 'custom')),
  goals text not null,
  days_per_week integer not null,
  minutes integer not null,
  focus text not null default '[]',
  active boolean not null default true,
  started_on date not null
);

create table if not exists public.program_days (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  program_id text not null,
  weekday integer not null check (weekday between 1 and 7),
  day_type text not null
);

create table if not exists public.workouts (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  program_id text,
  date date not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  day_type text not null,
  kind text not null,
  title text not null,
  plan text not null,
  rating text check (rating in ('tooEasy', 'good', 'hard', 'brutal')),
  duration_sec integer not null,
  total_reps integer not null default 0,
  journey_week integer,
  recovery_check_id text
);

create table if not exists public.workout_sets (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  workout_id text not null,
  exercise_id text not null,
  track_key text,
  block text not null,
  set_index integer not null,
  target integer not null,
  achieved integer not null,
  skipped boolean not null default false,
  completed_at timestamptz
);

create table if not exists public.personal_records (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  exercise_id text not null,
  metric text not null check (metric in ('maxReps', 'maxHold')),
  value integer not null,
  previous_value integer,
  workout_id text,
  achieved_on date not null
);

create table if not exists public.measurements (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  type text not null,
  label text,
  value double precision not null check (value > 0),
  measured_on date not null
);

create table if not exists public.skill_progress (
  id text primary key,                      -- '<user_id>:<track_key>'
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  track_key text not null,
  node_index integer not null,
  sets integer not null,
  amount integer not null,
  easy_streak integer not null default 0,
  hard_streak integer not null default 0,
  best_node integer
);

create table if not exists public.recovery_checks (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  date date not null,
  sleep text not null,
  soreness text not null,
  energy text not null,
  score integer not null,
  mode text not null
);

create table if not exists public.challenge_progress (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  challenge_id text not null,
  started_on date not null,
  completed_on date,
  abandoned boolean not null default false
);

create table if not exists public.challenge_checkins (
  id text primary key,                      -- '<progress_id>:<date>'
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  progress_id text not null,
  date date not null,
  value double precision not null,
  detail text
);

create table if not exists public.user_achievements (
  id text primary key,                      -- '<user_id>:<achievement_id>'
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  achievement_id text not null,
  unlocked_at timestamptz not null
);

create table if not exists public.journey_progress (
  id text primary key,                      -- = user_id
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  start_date date not null,
  current_week integer not null,
  counted_weeks integer not null,
  completed_on date,
  start_nodes text not null default '{}'
);

create table if not exists public.milestones (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  date date not null,
  type text not null,
  title text not null,
  track_key text,
  exercise_id text
);

create table if not exists public.food_prices (
  id text primary key,                      -- '<user_id>:<food_id>'
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at timestamptz not null default now(),
  food_id text not null,
  price double precision not null check (price >= 0)
);

-- One row per device: last successful sync, for support/debugging.
create table if not exists public.sync_metadata (
  id text primary key,                      -- '<user_id>:<install_id>'
  user_id uuid not null references auth.users(id) on delete cascade,
  device_label text,
  app_version text,
  last_synced_at timestamptz not null default now(),
  pending_changes integer not null default 0
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Triggers, indexes and Row Level Security for every user table
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  t text;
  user_tables text[] := array[
    'profiles', 'goals', 'programs', 'program_days', 'workouts', 'workout_sets',
    'personal_records', 'measurements', 'skill_progress', 'recovery_checks',
    'challenge_progress', 'challenge_checkins', 'user_achievements',
    'journey_progress', 'milestones', 'food_prices'
  ];
begin
  foreach t in array user_tables loop
    execute format('drop trigger if exists %I on public.%I', 'bf_synced_at_' || t, t);
    execute format(
      'create trigger %I before insert or update on public.%I for each row execute function public.bf_set_synced_at()',
      'bf_synced_at_' || t, t);

    execute format('drop trigger if exists %I on public.%I', 'bf_lww_' || t, t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.bf_last_write_wins()',
      'bf_lww_' || t, t);

    execute format('create index if not exists %I on public.%I (user_id, synced_at)', t || '_user_synced_idx', t);

    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists "Own rows: select" on public.%I', t);
    execute format('create policy "Own rows: select" on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "Own rows: insert" on public.%I', t);
    execute format('create policy "Own rows: insert" on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "Own rows: update" on public.%I', t);
    execute format('create policy "Own rows: update" on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "Own rows: delete" on public.%I', t);
    execute format('create policy "Own rows: delete" on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end;
$$;

drop trigger if exists bf_keep_earliest_unlock on public.user_achievements;
create trigger bf_keep_earliest_unlock
  before update on public.user_achievements
  for each row execute function public.bf_keep_earliest_unlock();

-- sync_metadata: own rows only.
alter table public.sync_metadata enable row level security;
drop policy if exists "Own rows: all" on public.sync_metadata;
create policy "Own rows: all" on public.sync_metadata for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Reference data: readable by everyone, writable by nobody through the API
-- (no insert/update/delete policies; only the SQL editor / seed can write).
do $$
declare
  t text;
  ref_tables text[] := array['exercises', 'skill_paths', 'skill_nodes', 'nutrition_items', 'challenges', 'achievements'];
begin
  foreach t in array ref_tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "Reference data: read" on public.%I', t);
    execute format('create policy "Reference data: read" on public.%I for select to anon, authenticated using (true)', t);
  end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Account deletion (Settings → Delete account). Runs with definer rights but
-- can only ever delete the caller: every user table cascades from auth.users.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Labels (used by the safety guard at the top when re-running)
-- ─────────────────────────────────────────────────────────────────────────────
comment on table public.exercises is 'BODYFORGE';
comment on table public.skill_paths is 'BODYFORGE';
comment on table public.skill_nodes is 'BODYFORGE';
comment on table public.nutrition_items is 'BODYFORGE';
comment on table public.challenges is 'BODYFORGE';
comment on table public.achievements is 'BODYFORGE';
comment on table public.profiles is 'BODYFORGE';
comment on table public.goals is 'BODYFORGE';
comment on table public.programs is 'BODYFORGE';
comment on table public.program_days is 'BODYFORGE';
comment on table public.workouts is 'BODYFORGE';
comment on table public.workout_sets is 'BODYFORGE';
comment on table public.personal_records is 'BODYFORGE';
comment on table public.measurements is 'BODYFORGE';
comment on table public.skill_progress is 'BODYFORGE';
comment on table public.recovery_checks is 'BODYFORGE';
comment on table public.challenge_progress is 'BODYFORGE';
comment on table public.challenge_checkins is 'BODYFORGE';
comment on table public.user_achievements is 'BODYFORGE';
comment on table public.journey_progress is 'BODYFORGE';
comment on table public.milestones is 'BODYFORGE';
comment on table public.food_prices is 'BODYFORGE';
comment on table public.sync_metadata is 'BODYFORGE';
comment on function public.delete_my_account() is 'BODYFORGE: deletes the signed-in user and (by cascade) all their data';
