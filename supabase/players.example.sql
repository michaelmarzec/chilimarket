-- Set the admin password and create players.
-- Paste this into Supabase → SQL Editor, replace every REPLACE_ME, and run it.
-- Do NOT save real passwords back into this file or commit them: the repo is public.
-- (For a local copy, save it as supabase/players.sql, which git ignores.)
-- Passwords are stored hashed and are not case-sensitive. Safe to re-run:
-- existing players get their password reset and keep their Zook Bucks.
-- If any REPLACE_ME is left, it stops and nothing is saved.

do $$
declare
  -- the Kitchen (admin.html) password
  admin_password text := 'REPLACE_ME';
  -- one row per guest: ['username', 'password'], with commas between rows
  guests text[][] := array[
    ['mook',  'REPLACE_ME'],
    ['steve', 'REPLACE_ME'],
    ['cole',  'REPLACE_ME']
  ];
  i int;
begin
  if admin_password ilike '%replace_me%' or trim(admin_password) = '' then
    raise exception 'Set a real admin password first.';
  end if;
  for i in 1 .. array_length(guests, 1) loop
    if guests[i][2] ilike '%replace_me%' or trim(guests[i][2]) = '' then
      raise exception 'The password for % is still REPLACE_ME.', guests[i][1];
    end if;
  end loop;

  insert into public.settings (key, value)
  values ('admin_hash', extensions.crypt(admin_password, extensions.gen_salt('bf')))
  on conflict (key) do update set value = excluded.value;

  for i in 1 .. array_length(guests, 1) loop
    insert into public.players (username, pass_hash, bank)
    values (lower(trim(guests[i][1])), extensions.crypt(lower(trim(guests[i][2])), extensions.gen_salt('bf')), 1000)
    on conflict (username) do update set pass_hash = excluded.pass_hash;
  end loop;
end $$;

select username, bank from public.players order by username;
