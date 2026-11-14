-- Chili Market update 2: no more notes, Jackie + Harry out of "arrives last" and "highest BAC",
-- renamed Harry + Jackie line, and three new lines (#28-30). Run once in Supabase → SQL Editor. Safe to re-run.

-- 1. Remove every note ("rehearsal data")
update public.lines set note = null;

-- 2. Rename
update public.lines set question = 'Will Harry + Jackie win best presentation AGAIN?' where id = 'hj19';

-- 3. Take Jackie + Harry out of "Who arrives last?" and "Who will blow the highest BAC?"
--    Any open bets on them there get their Zook Bucks back first.
update public.players p set bank = p.bank + s.total
from (
  select b.player_id, sum(b.stake) as total
  from public.bets b join public.lines l on l.id = b.line_id
  where l.id in ('latest', 'bac') and b.status = 'open'
    and b.side in (select o->>'key' from jsonb_array_elements(l.options) o where o->>'label' = 'Jackie + Harry')
  group by b.player_id
) s
where p.id = s.player_id;

delete from public.bets b using public.lines l
where l.id = b.line_id and l.id in ('latest', 'bac')
  and b.side in (select o->>'key' from jsonb_array_elements(l.options) o where o->>'label' = 'Jackie + Harry');

update public.lines
set options = (select jsonb_agg(o) from jsonb_array_elements(options) o where o->>'label' <> 'Jackie + Harry')
where id in ('latest', 'bac');

-- 4. New lines at the end (#28, #29, #30) so the earlier numbers don't move
insert into public.lines (id, course, sort, question, a_label, a_odds, b_label, b_odds) values
  ('magic',   'Side Dishes', 280, 'Will Will pull another magic trick à la the Breck ski house?', 'Yes', 150, 'No', -180),
  ('pokemon', 'Side Dishes', 290, 'Ian''s Pokémon collection: 1,000 cards', 'Over', -130, 'Under', 110),
  ('molly',   'Side Dishes', 300, 'Is Andrew''s chili just Molly chocolate?', 'Yes', 200, 'No', -250)
on conflict (id) do nothing;

-- check: every line with its number
select row_number() over (order by sort, id) as line, id, question from public.lines order by sort, id;
