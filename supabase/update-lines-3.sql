-- Chili Market update 3: remove "Will Cole offend anyone?", add "Is Chase perfect?" as the last line.
-- Run once in Supabase → SQL Editor. Safe to re-run.

-- Huge odds (+100,000,000) can pay out more than the old number type could hold, so widen it.
alter table public.players alter column bank type bigint;
alter table public.bets alter column payout type bigint;
drop function if exists public._win(int, int);
create function public._win(p_stake int, p_odds int) returns bigint
language sql immutable as $$
  select floor(case when p_odds > 0 then p_stake::numeric * p_odds / 100 else p_stake::numeric * 100 / abs(p_odds) end)::bigint
$$;
revoke execute on function public._win(int, int) from public, anon, authenticated;

-- Remove "Will Cole offend anyone?" (the over/under on how many stays). Open bets on it are refunded first.
update public.players p set bank = p.bank + s.total
from (select player_id, sum(stake) as total from public.bets where line_id = 'cole' and status = 'open' group by player_id) s
where p.id = s.player_id;
delete from public.lines where id = 'cole';

-- New last line
insert into public.lines (id, course, sort, question, a_label, a_odds, b_label, b_odds)
values ('chase', 'Side Dishes', 310, 'Is Chase perfect?', 'Yes', -10000000, 'No', 100000000)
on conflict (id) do nothing;

-- check: every line with its number (BAC should be 6, sports 11)
select row_number() over (order by sort, id) as line, id, question from public.lines order by sort, id;
