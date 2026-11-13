-- Chili Market starting lines. Run after schema.sql.
-- Passwords are NOT in this file on purpose (the repo is public).
-- Set them with supabase/players.example.sql, pasted into the SQL Editor and never committed.

-- Lines. a = first side, b = second side. American odds (+250 / -250).
insert into public.lines (id, course, sort, question, a_label, a_odds, b_label, b_odds, note) values
  ('murder',    'Main Course',   10,  'Will there be another murder mystery?', 'Yes', 400, 'No', -600, 'Santa died in 47 of 47 rehearsals.'),
  ('preg',      'Main Course',   20,  'Will there be a pregnancy reveal?', 'Yes', 5000, 'No', -10000, 'Line set by the intern. Do not ask follow-ups.'),
  ('guests',    'Main Course',   30,  'Any surprise guests?', 'Yes', -150, 'No', 120, 'A guy named Gary showed up in 31 rehearsals. Nobody invited Gary.'),
  ('vomit',     'Main Course',   40,  'Will someone throw up in the bathroom again?', 'Yes', 150, 'No', -180, 'Bathroom occupied 9+ minutes in 38 rehearsals.'),
  ('hoop',      'Main Course',   50,  'Will Mook get down from the basketball hoop without help?', 'Yes', 220, 'No', -260, 'Fire department on speed dial in 12 rehearsals.'),
  ('sharla',    'Over / Unders', 110, 'Sharla Lee cameos: 2.5', 'Over', 110, 'Under', -130, 'Average of 2.4. The Sharla wig shed heavily.'),
  ('sacks',     'Over / Unders', 120, 'Photos of sacks: 3.5', 'Over', -200, 'Under', 160, 'Rehearsal footage under legal review.'),
  ('colecount', 'Over / Unders', 130, 'People Cole offends: 4.5', 'Over', -140, 'Under', 115, 'Average of 6.3 people per rehearsal.'),
  ('lick',      'Over / Unders', 140, 'Seconds until first dog lick: 4.5', 'Over', 130, 'Under', -150, 'Chase averaged 1.2 seconds. George averaged a nap.'),
  ('hjcomp',    'Side Dishes',   210, 'Will Harry + Jackie compete?', 'Yes', -1000, 'No', 600, 'They showed up to all 47. Uninvited to 12.'),
  ('hj19',      'Side Dishes',   220, 'Will Harry + Jackie win best presentation for the 19th straight year?', 'Yes', -250, 'No', 200, 'Dynasty status. The book is sweating.'),
  ('cole',      'Side Dishes',   230, 'Will Cole offend anyone?', 'Yes', -5000, 'No', 1500, 'Cole offended the actor playing Cole.'),
  ('cawner',    'Side Dishes',   240, 'Will Cawner sit on Santa''s lap?', 'Yes', 250, 'No', -300, 'Santa was dead for most rehearsals, which complicated this.'),
  ('conor',     'Side Dishes',   250, 'Will Conor Law sit on Marzec''s lap?', 'Yes', 300, 'No', -400, 'Lap availability confirmed.'),
  ('steve',     'Side Dishes',   260, 'Will Steve eat beans?', 'Yes', -800, 'No', 500, 'Steve, you''d never refuse beans. Again.'),
  ('dogs',      'Side Dishes',   270, 'Will Chase and George pick the same chili?', 'Yes', 180, 'No', -220, 'They agreed once. It was on a sock.')
on conflict (id) do nothing;
