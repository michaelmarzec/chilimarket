-- Chili Market update: 9 new lines, name-line odds between +150 and +300, and line numbers.
-- Run once in Supabase → SQL Editor. Safe to re-run. Line numbers come from each line's Order (10, 20, 30…).

insert into public.lines (id, course, sort, question, a_label, a_odds, b_label, b_odds, note, options) values
  ('latest', 'Futures', 30, 'Who arrives last?', 'Yes', null, 'No', null, 'Cawner arrived during cleanup in 19 rehearsals.', '[{"key": "o1", "label": "Jackie + Harry", "odds": 275}, {"key": "o2", "label": "Abigail & Cole", "odds": 250}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 240}, {"key": "o4", "label": "Dryer + Marz", "odds": 300}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 225}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 215}, {"key": "o7", "label": "Sarah + Will", "odds": 200}, {"key": "o8", "label": "Ian + Griffin", "odds": 165}, {"key": "o9", "label": "Jaime + Luke", "odds": 190}, {"key": "o10", "label": "Hunter + Andrew", "odds": 175}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 150}]'::jsonb),
  ('bac', 'Main Course', 60, 'Who will blow the highest BAC?', 'Yes', null, 'No', null, 'Breathalyzer calibrated on Steve.', '[{"key": "o1", "label": "Jackie + Harry", "odds": 275}, {"key": "o2", "label": "Abigail & Cole", "odds": 175}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 250}, {"key": "o4", "label": "Dryer + Marz", "odds": 300}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 150}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 225}, {"key": "o7", "label": "Sarah + Will", "odds": 240}, {"key": "o8", "label": "Ian + Griffin", "odds": 165}, {"key": "o9", "label": "Jaime + Luke", "odds": 200}, {"key": "o10", "label": "Hunter + Andrew", "odds": 190}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 215}]'::jsonb),
  ('cake', 'Main Course', 100, 'Will Dryer drop a cake?', 'Yes', 175, 'No', -210, 'The cake hit the floor in 14 rehearsals. Five-second rule invoked all 14 times.', null),
  ('sports', 'Main Course', 110, 'Who loves sports the most?', 'Yes', null, 'No', null, 'The book did a lot of research on this one.', '[{"key": "o1", "label": "Michael Marzec", "odds": 175}, {"key": "o2", "label": "Sydney Sweeney", "odds": 150}, {"key": "o3", "label": "Stephen Miller", "odds": 300}, {"key": "o4", "label": "Lorde", "odds": 250}]'::jsonb),
  ('lmfao', 'Main Course', 120, 'Will LMFAO be the most-played artist?', 'Yes', 200, 'No', -250, 'Party Rock Anthem played 112 times in rehearsal 31.', null),
  ('broken', 'Over / Unders', 170, 'Household items broken: 2.5', 'Over', -130, 'Under', 110, 'A lamp, two glasses and a dog bed per rehearsal, on average.', null),
  ('buzzballz', 'Over / Unders', 180, 'BuzzBallz consumed: 4.5', 'Over', -150, 'Under', 125, 'Rehearsal average: 7.2. Mostly one guy.', null),
  ('dogaccident', 'Side Dishes', 260, 'Will a dog have an accident in the house?', 'Yes', 120, 'No', -140, 'George went on the rug in 22 rehearsals. Chase was framed.', null),
  ('screens', 'Side Dishes', 270, 'Will another monitor or TV break?', 'Yes', 250, 'No', -300, 'The projector is nervous.', null)
on conflict (id) do nothing;

-- every line's number = its position in this order
update public.lines set sort = 10, course = 'Futures' where id = 'winner';
update public.lines set sort = 20, course = 'Futures' where id = 'dogpick';
update public.lines set sort = 30, course = 'Futures' where id = 'latest';
update public.lines set sort = 40, course = 'Main Course' where id = 'murder';
update public.lines set sort = 50, course = 'Main Course' where id = 'preg';
update public.lines set sort = 60, course = 'Main Course' where id = 'bac';
update public.lines set sort = 70, course = 'Main Course' where id = 'guests';
update public.lines set sort = 80, course = 'Main Course' where id = 'vomit';
update public.lines set sort = 90, course = 'Main Course' where id = 'hoop';
update public.lines set sort = 100, course = 'Main Course' where id = 'cake';
update public.lines set sort = 110, course = 'Main Course' where id = 'sports';
update public.lines set sort = 120, course = 'Main Course' where id = 'lmfao';
update public.lines set sort = 130, course = 'Over / Unders' where id = 'sharla';
update public.lines set sort = 140, course = 'Over / Unders' where id = 'sacks';
update public.lines set sort = 150, course = 'Over / Unders' where id = 'colecount';
update public.lines set sort = 160, course = 'Over / Unders' where id = 'lick';
update public.lines set sort = 170, course = 'Over / Unders' where id = 'broken';
update public.lines set sort = 180, course = 'Over / Unders' where id = 'buzzballz';
update public.lines set sort = 190, course = 'Side Dishes' where id = 'hjcomp';
update public.lines set sort = 200, course = 'Side Dishes' where id = 'hj19';
update public.lines set sort = 210, course = 'Side Dishes' where id = 'cole';
update public.lines set sort = 220, course = 'Side Dishes' where id = 'cawner';
update public.lines set sort = 230, course = 'Side Dishes' where id = 'conor';
update public.lines set sort = 240, course = 'Side Dishes' where id = 'steve';
update public.lines set sort = 250, course = 'Side Dishes' where id = 'dogs';
update public.lines set sort = 260, course = 'Side Dishes' where id = 'dogaccident';
update public.lines set sort = 270, course = 'Side Dishes' where id = 'screens';

-- all-names lines: odds between +150 and +300 (bets already placed keep their odds)
update public.lines set options = '[{"key": "o1", "label": "Jackie + Harry", "odds": 150}, {"key": "o2", "label": "Abigail & Cole", "odds": 175}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 190}, {"key": "o4", "label": "Dryer + Marz", "odds": 200}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 210}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 225}, {"key": "o7", "label": "Sarah + Will", "odds": 240}, {"key": "o8", "label": "Ian + Griffin", "odds": 250}, {"key": "o9", "label": "Jaime + Luke", "odds": 260}, {"key": "o10", "label": "Hunter + Andrew", "odds": 275}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 300}]'::jsonb where id = 'winner';
update public.lines set options = '[{"key": "o1", "label": "Jackie + Harry", "odds": 200}, {"key": "o2", "label": "Abigail & Cole", "odds": 150}, {"key": "o3", "label": "Katie + Hannah (+Jack)", "odds": 175}, {"key": "o4", "label": "Dryer + Marz", "odds": 225}, {"key": "o5", "label": "Colorado Steve + McKenzie", "odds": 165}, {"key": "o6", "label": "Emma + Meghan + Cort", "odds": 210}, {"key": "o7", "label": "Sarah + Will", "odds": 240}, {"key": "o8", "label": "Ian + Griffin", "odds": 250}, {"key": "o9", "label": "Jaime + Luke", "odds": 260}, {"key": "o10", "label": "Hunter + Andrew", "odds": 275}, {"key": "o11", "label": "Cawner Laugh + Sam Terwilllignslijsfoieger", "odds": 300}]'::jsonb where id = 'dogpick';

select row_number() over (order by sort, id) as line, id, question from public.lines order by sort, id;
