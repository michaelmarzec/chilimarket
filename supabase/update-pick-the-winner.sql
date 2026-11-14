-- Chili Market update: "pick the winner" bets with any number of options.
-- Run once in Supabase → SQL Editor. Safe to re-run.
-- (Fresh installs don't need this: schema.sql already includes it.)

alter table public.lines add column if not exists options jsonb;
alter table public.lines alter column a_odds drop not null;
alter table public.lines alter column b_odds drop not null;
alter table public.lines drop constraint if exists lines_result_check;
alter table public.lines add constraint lines_result_check check (result is null or result ~ '^[a-z0-9]{1,8}$');
alter table public.bets drop constraint if exists bets_side_check;
alter table public.bets add constraint bets_side_check check (side ~ '^[a-z0-9]{1,8}$');

-- odds for a side: 'a'/'b' on two-sided lines, an option key ('o1', 'o2', …) on pick-the-winner lines
create or replace function public._side_odds(p_line text, p_side text) returns int
language sql stable security definer set search_path = public as $$
  select case
    when l.options is null then case p_side when 'a' then l.a_odds when 'b' then l.b_odds end
    else (select (o->>'odds')::int from jsonb_array_elements(l.options) o where o->>'key' = p_side limit 1)
  end
  from lines l where l.id = p_line
$$;

create or replace function public.place_bet(p_token uuid, p_line text, p_side text, p_stake int) returns json
language plpgsql security definer set search_path = public as $$
declare me players; ln lines; v_odds int;
begin
  select * into me from players where token = p_token for update;
  if me.id is null then raise exception 'bad_token'; end if;
  select * into ln from lines where id = p_line;
  if ln.id is null then raise exception 'no_line'; end if;
  if ln.locked or ln.result is not null then raise exception 'line_closed'; end if;
  v_odds := _side_odds(p_line, p_side);
  if v_odds is null then raise exception 'bad_side'; end if;
  if p_stake is null or p_stake <= 0 then raise exception 'bad_stake'; end if;
  if p_stake > me.bank then raise exception 'insufficient'; end if;

  update players set bank = bank - p_stake where id = me.id;
  insert into bets (player_id, line_id, side, stake, odds) values (me.id, p_line, p_side, p_stake, v_odds);
  return get_state(p_token);
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
        select id, course, sort, question, a_label, a_odds, b_label, b_odds, note, options, locked, result from lines
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

create or replace function public._admin_view() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'player_password_set', exists (select 1 from settings where key = 'player_password_hash'),
    'lines', coalesce((
      select json_agg(x order by x.sort, x.id) from (
        select l.*, coalesce((
          select json_object_agg(t.side, json_build_object('count', t.c, 'stake', t.s))
          from (select side, count(*) as c, sum(stake) as s from bets where line_id = l.id group by side) t
        ), '{}'::json) as tally
        from lines l
      ) x), '[]'::json),
    'players', coalesce((
      select json_agg(y order by y.username) from (
        select p.username, p.bank, count(b.id) as bets
        from players p left join bets b on b.player_id = p.id
        group by p.id
      ) y), '[]'::json)
  )
$$;

create or replace function public.admin_save_line(p_pw text, p_line json) returns json
language plpgsql security definer set search_path = public as $$
declare
  opts jsonb := case when json_typeof(p_line->'options') = 'array' then (p_line->'options')::jsonb end;
  a int := nullif(p_line->>'a_odds','')::int;
  b int := nullif(p_line->>'b_odds','')::int;
begin
  perform _check_admin(p_pw);
  if coalesce(trim(p_line->>'question'),'') = '' then raise exception 'bad_question'; end if;
  if opts is null then
    if a is null or b is null or not (a >= 100 or a <= -100) or not (b >= 100 or b <= -100) then raise exception 'bad_odds'; end if;
  else
    if jsonb_array_length(opts) < 2 then raise exception 'bad_options'; end if;
    if exists (select 1 from jsonb_array_elements(opts) o
               where coalesce(o->>'key','') !~ '^[a-z0-9]{1,8}$' or coalesce(trim(o->>'label'),'') = ''
                  or coalesce(o->>'odds','') !~ '^-?[0-9]+$'
                  or not ((o->>'odds')::int >= 100 or (o->>'odds')::int <= -100)) then
      raise exception 'bad_odds';
    end if;
    a := null; b := null;
  end if;
  insert into lines (id, course, sort, question, a_label, a_odds, b_label, b_odds, note, options)
  values (p_line->>'id', coalesce(nullif(p_line->>'course',''), 'Main Course'), coalesce(nullif(p_line->>'sort','')::int, 0),
          trim(p_line->>'question'), coalesce(nullif(p_line->>'a_label',''),'Yes'), a, coalesce(nullif(p_line->>'b_label',''),'No'), b,
          nullif(p_line->>'note',''), opts)
  on conflict (id) do update set
    course = excluded.course, sort = excluded.sort, question = excluded.question,
    a_label = excluded.a_label, a_odds = excluded.a_odds, b_label = excluded.b_label, b_odds = excluded.b_odds,
    note = excluded.note, options = excluded.options;
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
  if p_result <> 'void' and _side_odds(p_line, p_result) is null then raise exception 'bad_side'; end if;

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
insert into public.lines (id, course, sort, question, a_label, a_odds, b_label, b_odds, note, options) values
  ('winner',  'Futures', 1, 'Who will win the 2026 Chili Cook Off?', 'Yes', null, 'No', null, 'Jackie + Harry won 41 of 47 rehearsals. The other 6 were rained out.', '[{"key": "o1", "label": "Jackie + Harry", "odds": 250}, {"key": "o2", "label": "Abigail & Cole", "odds": 400}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 500}, {"key": "o4", "label": "Dryer + Marz", "odds": 600}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 800}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 900}, {"key": "o7", "label": "Sarah + Will", "odds": 1000}, {"key": "o8", "label": "Ian + Griffin", "odds": 1200}, {"key": "o9", "label": "Jaime + Luke", "odds": 1400}, {"key": "o10", "label": "Hunter + Andrew", "odds": 1600}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 2500}]'::jsonb),
  ('dogpick', 'Futures', 2, 'Whose chili will Chase and George choose?', 'Yes', null, 'No', null, 'George picked the trash can in 9 rehearsals.', '[{"key": "o1", "label": "Jackie + Harry", "odds": 900}, {"key": "o2", "label": "Abigail & Cole", "odds": 700}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 800}, {"key": "o4", "label": "Dryer + Marz", "odds": 1000}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 600}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 900}, {"key": "o7", "label": "Sarah + Will", "odds": 1100}, {"key": "o8", "label": "Ian + Griffin", "odds": 1000}, {"key": "o9", "label": "Jaime + Luke", "odds": 1200}, {"key": "o10", "label": "Hunter + Andrew", "odds": 1300}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 1500}]'::jsonb)
on conflict (id) do nothing;

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
