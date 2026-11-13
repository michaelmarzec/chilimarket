-- Chili Market database
-- Run this whole file once in Supabase → SQL Editor → New query → Run.
-- Then run seed.sql. Safe to re-run: it replaces the functions and keeps your data.
--
-- Security model: the tables are locked (row level security on, no policies),
-- so the public anon key can't read or write them directly. Phones only talk to
-- the functions below, which check the player token or the admin password.

create extension if not exists pgcrypto with schema extensions;

-- ---------- tables ----------
create table if not exists public.settings (
  key   text primary key,
  value text not null
);

create table if not exists public.players (
  id         uuid primary key default gen_random_uuid(),
  username   text unique not null check (username = lower(username) and username ~ '^[a-z0-9_.-]+$'),
  pass_hash  text not null,
  bank       integer not null default 1000,
  token      uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.lines (
  id       text primary key,
  course   text not null default 'Main Course',
  sort     integer not null default 0,
  question text not null,
  a_label  text not null default 'Yes',
  a_odds   integer not null check (a_odds >= 100 or a_odds <= -100),
  b_label  text not null default 'No',
  b_odds   integer not null check (b_odds >= 100 or b_odds <= -100),
  note     text,
  locked   boolean not null default false,
  result   text check (result in ('a','b','void'))
);

create table if not exists public.bets (
  id         bigint generated always as identity primary key,
  player_id  uuid not null references public.players(id) on delete cascade,
  line_id    text not null references public.lines(id) on delete cascade,
  side       text not null check (side in ('a','b')),
  stake      integer not null check (stake > 0),
  odds       integer not null,
  status     text not null default 'open' check (status in ('open','won','lost','void')),
  payout     integer,
  created_at timestamptz not null default now()
);
create index if not exists bets_player_idx on public.bets(player_id);
create index if not exists bets_line_idx on public.bets(line_id);

alter table public.settings enable row level security;
alter table public.players  enable row level security;
alter table public.lines    enable row level security;
alter table public.bets     enable row level security;
revoke all on public.settings, public.players, public.lines, public.bets from anon, authenticated;

-- ---------- helpers (not callable from the site) ----------
create or replace function public._win(p_stake int, p_odds int) returns int
language sql immutable as $$
  select floor(case when p_odds > 0 then p_stake * p_odds / 100.0 else p_stake * 100.0 / abs(p_odds) end)::int
$$;

create or replace function public._check_admin(p_pw text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists (select 1 from settings where key = 'admin_hash' and value = crypt(coalesce(p_pw,''), value)) then
    raise exception 'bad_admin';
  end if;
end $$;

create or replace function public._admin_view() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
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

-- ---------- player functions ----------
create or replace function public.login(p_username text, p_password text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare p players;
begin
  select * into p from players where username = lower(trim(p_username));
  if p.id is null or p.pass_hash <> crypt(lower(trim(coalesce(p_password,''))), p.pass_hash) then
    raise exception 'bad_login';
  end if;
  return json_build_object('token', p.token, 'username', p.username);
end $$;

create or replace function public.get_state(p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
declare me players;
begin
  select * into me from players where token = p_token;
  if me.id is null then raise exception 'bad_token'; end if;
  return json_build_object(
    'me', json_build_object('username', me.username, 'bank', me.bank),
    'lines', coalesce((
      select json_agg(l order by l.sort, l.id) from (
        select id, course, sort, question, a_label, a_odds, b_label, b_odds, note, locked, result from lines
      ) l), '[]'::json),
    'bets', coalesce((
      select json_agg(b order by b.id desc) from (
        select id, line_id, side, stake, odds, status, payout from bets where player_id = me.id
      ) b), '[]'::json),
    'leaders', coalesce((
      select json_agg(x order by x.bankroll desc, x.username) from (
        select p.username,
               p.bank + coalesce(sum(b.stake) filter (where b.status = 'open'), 0) as bankroll,
               count(b.id) as bets
        from players p left join bets b on b.player_id = p.id
        group by p.id
      ) x), '[]'::json)
  );
end $$;

create or replace function public.place_bet(p_token uuid, p_line text, p_side text, p_stake int) returns json
language plpgsql security definer set search_path = public as $$
declare me players; ln lines;
begin
  select * into me from players where token = p_token for update;
  if me.id is null then raise exception 'bad_token'; end if;
  select * into ln from lines where id = p_line;
  if ln.id is null then raise exception 'no_line'; end if;
  if ln.locked or ln.result is not null then raise exception 'line_closed'; end if;
  if p_side is null or p_side not in ('a','b') then raise exception 'bad_side'; end if;
  if p_stake is null or p_stake <= 0 then raise exception 'bad_stake'; end if;
  if p_stake > me.bank then raise exception 'insufficient'; end if;

  update players set bank = bank - p_stake where id = me.id;
  insert into bets (player_id, line_id, side, stake, odds)
  values (me.id, p_line, p_side, p_stake, case when p_side = 'a' then ln.a_odds else ln.b_odds end);
  return get_state(p_token);
end $$;

-- ---------- admin functions ----------
create or replace function public.admin_state(p_pw text) returns json
language plpgsql security definer set search_path = public as $$
begin perform _check_admin(p_pw); return _admin_view(); end $$;

create or replace function public.admin_save_line(p_pw text, p_line json) returns json
language plpgsql security definer set search_path = public as $$
declare a int := (p_line->>'a_odds')::int; b int := (p_line->>'b_odds')::int;
begin
  perform _check_admin(p_pw);
  if a is null or b is null or not (a >= 100 or a <= -100) or not (b >= 100 or b <= -100) then raise exception 'bad_odds'; end if;
  insert into lines (id, course, sort, question, a_label, a_odds, b_label, b_odds, note)
  values (p_line->>'id', coalesce(nullif(p_line->>'course',''), 'Main Course'), coalesce((p_line->>'sort')::int, 0),
          p_line->>'question', coalesce(nullif(p_line->>'a_label',''),'Yes'), a, coalesce(nullif(p_line->>'b_label',''),'No'), b, nullif(p_line->>'note',''))
  on conflict (id) do update set
    course = excluded.course, sort = excluded.sort, question = excluded.question,
    a_label = excluded.a_label, a_odds = excluded.a_odds, b_label = excluded.b_label, b_odds = excluded.b_odds, note = excluded.note;
  return _admin_view();
end $$;

create or replace function public.admin_set_lock(p_pw text, p_line text, p_locked boolean) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform _check_admin(p_pw);
  update lines set locked = p_locked where id = p_line;
  if not found then raise exception 'no_line'; end if;
  return _admin_view();
end $$;

create or replace function public.admin_settle(p_pw text, p_line text, p_result text) returns json
language plpgsql security definer set search_path = public as $$
declare ln lines;
begin
  perform _check_admin(p_pw);
  select * into ln from lines where id = p_line for update;
  if ln.id is null then raise exception 'no_line'; end if;
  if ln.result is not null then raise exception 'already_settled'; end if;
  if p_result not in ('a','b','void') then raise exception 'bad_side'; end if;

  with upd as (
    update bets set
      status = case when p_result = 'void' then 'void' when side = p_result then 'won' else 'lost' end,
      payout = case when p_result = 'void' then stake when side = p_result then stake + _win(stake, odds) else 0 end
    where line_id = p_line and status = 'open'
    returning player_id, payout
  )
  update players p set bank = p.bank + s.total
  from (select player_id, sum(payout) as total from upd group by player_id) s
  where p.id = s.player_id;

  update lines set result = p_result, locked = true where id = p_line;
  return _admin_view();
end $$;

create or replace function public.admin_unsettle(p_pw text, p_line text) returns json
language plpgsql security definer set search_path = public as $$
declare ln lines;
begin
  perform _check_admin(p_pw);
  select * into ln from lines where id = p_line for update;
  if ln.id is null then raise exception 'no_line'; end if;
  if ln.result is null then raise exception 'not_settled'; end if;

  update players p set bank = p.bank - s.total
  from (select player_id, sum(coalesce(payout,0)) as total from bets where line_id = p_line and status <> 'open' group by player_id) s
  where p.id = s.player_id;
  update bets set status = 'open', payout = null where line_id = p_line;
  update lines set result = null where id = p_line;
  return _admin_view();
end $$;

create or replace function public.admin_delete_line(p_pw text, p_line text) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform _check_admin(p_pw);
  -- refund anything still open before the bets disappear
  update players p set bank = p.bank + s.total
  from (select player_id, sum(stake) as total from bets where line_id = p_line and status = 'open' group by player_id) s
  where p.id = s.player_id;
  delete from lines where id = p_line;
  return _admin_view();
end $$;

create or replace function public.admin_save_player(p_pw text, p_username text, p_password text, p_bank int default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(trim(p_username)); pw text := lower(trim(coalesce(p_password,'')));
begin
  perform _check_admin(p_pw);
  if u is null or u !~ '^[a-z0-9_.-]+$' or pw = '' then raise exception 'bad_player'; end if;
  insert into players (username, pass_hash, bank)
  values (u, crypt(pw, gen_salt('bf')), coalesce(p_bank, 1000))
  on conflict (username) do update set
    pass_hash = excluded.pass_hash,
    bank = coalesce(p_bank, players.bank);
  return _admin_view();
end $$;

create or replace function public.admin_adjust_bank(p_pw text, p_username text, p_delta int) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform _check_admin(p_pw);
  update players set bank = bank + p_delta where username = lower(trim(p_username));
  if not found then raise exception 'no_player'; end if;
  return _admin_view();
end $$;

create or replace function public.admin_set_password(p_pw text, p_new text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_admin(p_pw);
  update settings set value = crypt(p_new, gen_salt('bf')) where key = 'admin_hash';
  return json_build_object('ok', true);
end $$;

-- ---------- name + shared password login ----------
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

-- ---------- who can call what ----------
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
