-- Chili Market update: log in with just a name + one shared password.
-- Run once in Supabase → SQL Editor on a database set up with the older schema.sql.
-- Then set the shared player password in the Kitchen → Players.
-- (Fresh installs don't need this: schema.sql already includes it.)

-- Names: letters, numbers, spaces, . _ ' - (24 characters max), stored lowercase
alter table public.players drop constraint if exists players_username_check;
alter table public.players add constraint players_username_check
  check (username = lower(username) and username ~ '^[a-z0-9][a-z0-9 _.''-]{0,23}$');

create or replace function public._clean_name(p text) returns text
language sql immutable as $$ select lower(regexp_replace(trim(coalesce(p,'')), '\s+', ' ', 'g')) $$;

-- Log in: right shared password + any name. New name = new player with 1,000 Zook Bucks.
create or replace function public.login(p_username text, p_password text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare p players; u text := _clean_name(p_username); created boolean := false;
begin
  if not exists (select 1 from settings where key = 'player_password_hash'
                 and value = crypt(lower(trim(coalesce(p_password,''))), value)) then
    raise exception 'bad_login';
  end if;
  if u !~ '^[a-z0-9][a-z0-9 _.''-]{0,23}$' then raise exception 'bad_name'; end if;
  select * into p from players where username = u;
  if p.id is null then
    insert into players (username, pass_hash, bank) values (u, '', 1000) on conflict (username) do nothing;
    select * into p from players where username = u;
    created := true;
  end if;
  return json_build_object('token', p.token, 'username', p.username, 'created', created);
end $$;

create or replace function public.admin_set_player_password(p_pw text, p_new text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_admin(p_pw);
  if trim(coalesce(p_new,'')) = '' then raise exception 'bad_player'; end if;
  insert into settings (key, value) values ('player_password_hash', crypt(lower(trim(p_new)), gen_salt('bf')))
  on conflict (key) do update set value = excluded.value;
  return _admin_view();
end $$;

create or replace function public.admin_delete_player(p_pw text, p_username text) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform _check_admin(p_pw);
  delete from players where username = _clean_name(p_username);
  if not found then raise exception 'no_player'; end if;
  return _admin_view();
end $$;

create or replace function public.admin_adjust_bank(p_pw text, p_username text, p_delta int) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform _check_admin(p_pw);
  update players set bank = bank + p_delta where username = _clean_name(p_username);
  if not found then raise exception 'no_player'; end if;
  return _admin_view();
end $$;

-- _admin_view now also says whether a shared player password is set
create or replace function public._admin_view() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'player_password_set', exists (select 1 from settings where key = 'player_password_hash'),
    'lines', coalesce((
      select json_agg(x order by x.sort, x.id) from (
        select l.*, json_build_object(
          'a', json_build_object('count', count(b.id) filter (where b.side='a'), 'stake', coalesce(sum(b.stake) filter (where b.side='a'),0)),
          'b', json_build_object('count', count(b.id) filter (where b.side='b'), 'stake', coalesce(sum(b.stake) filter (where b.side='b'),0))
        ) as tally
        from lines l left join bets b on b.line_id = l.id
        group by l.id
      ) x), '[]'::json),
    'players', coalesce((
      select json_agg(y order by y.username) from (
        select p.username, p.bank, count(b.id) as bets
        from players p left join bets b on b.player_id = p.id
        group by p.id
      ) y), '[]'::json)
  )
$$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.login(text, text),
  public.get_state(uuid),
  public.place_bet(uuid, text, text, int),
  public.admin_state(text),
  public.admin_save_line(text, json),
  public.admin_set_lock(text, text, boolean),
  public.admin_settle(text, text, text),
  public.admin_unsettle(text, text),
  public.admin_delete_line(text, text),
  public.admin_save_player(text, text, text, int),
  public.admin_adjust_bank(text, text, int),
  public.admin_set_password(text, text),
  public.admin_set_player_password(text, text),
  public.admin_delete_player(text, text)
to anon, authenticated;
