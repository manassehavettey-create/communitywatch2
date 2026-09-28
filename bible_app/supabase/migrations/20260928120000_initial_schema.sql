-- Bible app: initial schema.
--
-- The device keeps a full local copy (SQLite via drift); these tables are
-- the sync target. Every user-owned table:
--   * is keyed by (user_id, id); ids are generated on the device
--   * stores device timestamps as epoch milliseconds (created_at,
--     updated_at, deleted_at) — updated_at decides last-write-wins
--   * has server_updated_at, stamped by the server on every accepted write,
--     which clients page through to pull changes
--   * soft-deletes via deleted_at so deletions sync
--   * has row-level security: users can only see and change their own rows
--
-- Bible text is NOT stored here; it ships inside the app.
-- Column names must match lib/data/db/tables.dart (a unit test checks).

-- ---------------------------------------------------------------------------
-- Shared trigger: last write wins + server change stamp
-- ---------------------------------------------------------------------------

create or replace function public.sync_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    -- An older edit arrived after a newer one: keep the newer row.
    return null;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reference data (readable by everyone, written only by migrations/seed)
-- ---------------------------------------------------------------------------

create table public.reading_plans (
  id text primary key,
  title text not null,
  subtitle text not null,
  description text not null,
  category text not null,
  minutes_per_day integer not null,
  total_days integer not null check (total_days > 0),
  days jsonb not null,
  sort_order integer not null default 0
);

create table public.prayer_categories (
  id text primary key,
  label text not null,
  sort_order integer not null default 0
);

alter table public.reading_plans enable row level security;
alter table public.prayer_categories enable row level security;
create policy "Plans are public" on public.reading_plans for select using (true);
create policy "Prayer categories are public" on public.prayer_categories for select using (true);
grant select on public.reading_plans, public.prayer_categories to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Profiles (one per auth user, created automatically)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "Read own profile" on public.profiles
  for select using (id = (select auth.uid()));
create policy "Update own profile" on public.profiles
  for update using (id = (select auth.uid())) with check (id = (select auth.uid()));
grant select, update on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Lets a signed-in user delete their own account and, by cascade, all of
-- their data (required by app stores).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- User data
-- ---------------------------------------------------------------------------

create table public.preferences (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  translation_id text,
  scripture_font text not null default 'literata',
  font_size double precision not null default 19,
  line_height double precision not null default 1.65,
  reader_theme text not null default 'auto',
  app_theme text not null default 'system',
  show_verse_numbers boolean not null default true,
  paragraph_mode boolean not null default true,
  supplied_italics boolean not null default true,
  last_chapter text,
  last_verse integer,
  last_read_at bigint,
  primary key (user_id, id)
);

create table public.bookmarks (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  start_ref text not null,
  end_ref text not null,
  start_key integer not null,
  end_key integer not null,
  translation_id text,
  primary key (user_id, id)
);

create table public.highlights (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  start_ref text not null,
  end_ref text not null,
  start_key integer not null,
  end_key integer not null,
  color text not null check (color in ('butter', 'coral', 'sage', 'sky', 'blush')),
  primary key (user_id, id)
);

create table public.notes (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  start_ref text not null,
  end_ref text not null,
  start_key integer not null,
  end_key integer not null,
  body text not null,
  primary key (user_id, id)
);

create table public.saved_verses (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  start_ref text not null,
  end_ref text not null,
  start_key integer not null,
  end_key integer not null,
  translation_id text not null,
  snapshot text not null,
  primary key (user_id, id)
);

create table public.plan_progress (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  plan_id text not null references public.reading_plans (id),
  status text not null check (status in ('active', 'paused', 'completed')),
  start_date text not null,
  paused_on text,
  paused_days integer not null default 0,
  completed_at bigint,
  primary key (user_id, id)
);

create table public.plan_day_completions (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  progress_id text not null,
  day integer not null check (day > 0),
  completed_at bigint not null,
  primary key (user_id, id)
);

-- id is the local calendar date, yyyy-mm-dd.
create table public.reading_activity (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (id ~ '^\d{4}-\d{2}-\d{2}$'),
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  chapters integer not null default 0,
  seconds integer not null default 0,
  primary key (user_id, id)
);

-- id is the chapter code, e.g. JHN.3.
create table public.chapter_reads (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  first_read_at bigint not null,
  last_read_at bigint not null,
  times_read integer not null default 1,
  primary key (user_id, id)
);

create table public.prayers (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  title text not null,
  body text not null default '',
  category text not null,
  scripture_ref text,
  status text not null default 'active' check (status in ('active', 'answered')),
  answered_at bigint,
  answer_note text,
  reminder_kind text not null default 'none' check (reminder_kind in ('none', 'once', 'daily')),
  reminder_value bigint,
  primary key (user_id, id)
);

create table public.journal_entries (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  title text not null,
  body text not null,
  entry_date bigint not null,
  scripture_ref text,
  primary key (user_id, id)
);

create table public.tags (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  name text not null,
  primary key (user_id, id)
);

create table public.journal_entry_tags (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  entry_id text not null,
  tag_id text not null,
  primary key (user_id, id)
);

-- Triggers, row-level security, grants and pull indexes for every user table.
do $$
declare
  t text;
begin
  foreach t in array array[
    'preferences', 'bookmarks', 'highlights', 'notes', 'saved_verses',
    'plan_progress', 'plan_day_completions', 'reading_activity', 'chapter_reads',
    'prayers', 'journal_entries', 'tags', 'journal_entry_tags'
  ]
  loop
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.sync_guard()',
      t || '_sync_guard', t);
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for all
         using (user_id = (select auth.uid()))
         with check (user_id = (select auth.uid()))',
      'Own rows only', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format(
      'create index %I on public.%I (user_id, server_updated_at, id)',
      t || '_pull_idx', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Streaks (computed from reading_activity; respects RLS of the caller)
-- ---------------------------------------------------------------------------

create view public.streaks
with (security_invoker = on)
as
with days as (
  select user_id, id::date as d
  from public.reading_activity
  where deleted_at is null
),
grouped as (
  select user_id, d, d - (row_number() over (partition by user_id order by d))::int as grp
  from days
),
runs as (
  select user_id, count(*) as len, max(d) as last_day
  from grouped
  group by user_id, grp
)
select
  user_id,
  sum(len)::int as total_days,
  max(len)::int as longest_streak,
  -- Server "today" is UTC; the app computes the exact local-time value.
  coalesce(max(len) filter (where last_day >= current_date - 1), 0)::int as current_streak,
  max(last_day) as last_read_day
from runs
group by user_id;

grant select on public.streaks to authenticated;
