-- BODYFORGE: set up the whole database with this short script (Supabase → SQL Editor → Run).
-- It downloads supabase/setup_remote.sql from GitHub at a pinned commit, checks it
-- wasn't changed (md5), and runs it in one transaction. Safe to run again.
create extension if not exists http with schema extensions;
do $$
declare r extensions.http_response;
begin
  r := extensions.http_get('https://raw.githubusercontent.com/manassehavettey-create/communitywatch2/d980a4a3e0294891f273716fc8e1f50897a7df1c/bodyforge/supabase/setup_remote.sql');
  if r.status <> 200 then raise exception 'Download failed (HTTP %). Wait a minute and run again.', r.status; end if;
  if md5(r.content) <> '17c86f3cf14c9b4dc98de609f1080daa' then raise exception 'Downloaded file is not the expected BODYFORGE script. Nothing was changed.'; end if;
  execute r.content;
end $$;
select (select count(*) from public.exercises) as exercises,
       (select count(*) from public.achievements) as achievements,
       'BODYFORGE database ready' as status;
