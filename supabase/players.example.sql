-- Set the admin password and create players.
-- Paste this into Supabase → SQL Editor, replace every REPLACE_ME, and run it.
-- Do NOT save real passwords back into this file or commit them: the repo is public.
-- (For a local copy, save it as supabase/players.sql, which git ignores.)
-- Passwords are stored hashed and are not case-sensitive. Safe to re-run:
-- existing players get their password reset and keep their Zook Bucks.

drop table if exists pg_temp.setup;
create temp table setup (kind text, username text, password text);

insert into setup values
  -- the Kitchen (admin.html) password
  ('admin',  null,     'REPLACE_ME'),
  -- one row per guest: ('player', 'username', 'password'),
  ('player', 'mook',   'REPLACE_ME'),
  ('player', 'steve',  'REPLACE_ME'),
  ('player', 'cole',   'REPLACE_ME');

-- Stops here if a placeholder is left in, before anything is saved.
do $$ begin
  if exists (select 1 from setup where password ilike '%replace_me%' or trim(coalesce(password,'')) = '') then
    raise exception 'A REPLACE_ME password is still in there. Swap in real passwords and run it again.';
  end if;
end $$;

insert into public.settings (key, value)
select 'admin_hash', extensions.crypt(password, extensions.gen_salt('bf')) from setup where kind = 'admin'
on conflict (key) do update set value = excluded.value;

insert into public.players (username, pass_hash, bank)
select lower(trim(username)), extensions.crypt(lower(trim(password)), extensions.gen_salt('bf')), 1000
from setup where kind = 'player'
on conflict (username) do update set pass_hash = excluded.pass_hash;

drop table setup;
select username, bank from public.players order by username;
