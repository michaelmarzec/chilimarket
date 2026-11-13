// Sample data for DEMO MODE only (when js/config.js has no Supabase keys).
// These are throwaway demo logins that only work in each visitor's own browser.
// They are NOT the real passwords. Real players and the admin password live in
// Supabase only (see supabase/players.example.sql).
window.CHILI_DEMO = {
  adminPassword: "changeme",
  players: [
    { username: "mook",   password: "zook",       bank: 1000 },
    { username: "steve",  password: "beans",      bank: 1000 },
    { username: "cole",   password: "sorry",      bank: 1840 },
    { username: "jackie", password: "19straight", bank: 1310 },
    { username: "harry",  password: "19straight", bank: 1205 },
    { username: "sharla", password: "commish",    bank: 990 },
    { username: "cawner", password: "santa",      bank: 720 },
    { username: "conor",  password: "marzec",     bank: 410 },
  ],
  lines: [
    { id:"murder",   course:"Main Course",  sort:10,  question:"Will there be another murder mystery?", a_label:"Yes", a_odds:400,  b_label:"No", b_odds:-600, note:"Santa died in 47 of 47 rehearsals." },
    { id:"preg",     course:"Main Course",  sort:20,  question:"Will there be a pregnancy reveal?", a_label:"Yes", a_odds:5000, b_label:"No", b_odds:-10000, note:"Line set by the intern. Do not ask follow-ups." },
    { id:"guests",   course:"Main Course",  sort:30,  question:"Any surprise guests?", a_label:"Yes", a_odds:-150, b_label:"No", b_odds:120, note:"A guy named Gary showed up in 31 rehearsals. Nobody invited Gary." },
    { id:"vomit",    course:"Main Course",  sort:40,  question:"Will someone throw up in the bathroom again?", a_label:"Yes", a_odds:150, b_label:"No", b_odds:-180, note:"Bathroom occupied 9+ minutes in 38 rehearsals." },
    { id:"hoop",     course:"Main Course",  sort:50,  question:"Will Mook get down from the basketball hoop without help?", a_label:"Yes", a_odds:220, b_label:"No", b_odds:-260, note:"Fire department on speed dial in 12 rehearsals." },
    { id:"sharla",   course:"Over / Unders", sort:110, question:"Sharla Lee cameos: 2.5", a_label:"Over", a_odds:110, b_label:"Under", b_odds:-130, note:"Average of 2.4. The Sharla wig shed heavily." },
    { id:"sacks",    course:"Over / Unders", sort:120, question:"Photos of sacks: 3.5", a_label:"Over", a_odds:-200, b_label:"Under", b_odds:160, note:"Rehearsal footage under legal review." },
    { id:"colecount",course:"Over / Unders", sort:130, question:"People Cole offends: 4.5", a_label:"Over", a_odds:-140, b_label:"Under", b_odds:115, note:"Average of 6.3 people per rehearsal." },
    { id:"lick",     course:"Over / Unders", sort:140, question:"Seconds until first dog lick: 4.5", a_label:"Over", a_odds:130, b_label:"Under", b_odds:-150, note:"Chase averaged 1.2 seconds. George averaged a nap." },
    { id:"hjcomp",   course:"Side Dishes",  sort:210, question:"Will Harry + Jackie compete?", a_label:"Yes", a_odds:-1000, b_label:"No", b_odds:600, note:"They showed up to all 47. Uninvited to 12." },
    { id:"hj19",     course:"Side Dishes",  sort:220, question:"Will Harry + Jackie win best presentation for the 19th straight year?", a_label:"Yes", a_odds:-250, b_label:"No", b_odds:200, note:"Dynasty status. The book is sweating." },
    { id:"cole",     course:"Side Dishes",  sort:230, question:"Will Cole offend anyone?", a_label:"Yes", a_odds:-5000, b_label:"No", b_odds:1500, note:"Cole offended the actor playing Cole." },
    { id:"cawner",   course:"Side Dishes",  sort:240, question:"Will Cawner sit on Santa's lap?", a_label:"Yes", a_odds:250, b_label:"No", b_odds:-300, note:"Santa was dead for most rehearsals, which complicated this." },
    { id:"conor",    course:"Side Dishes",  sort:250, question:"Will Conor Law sit on Marzec's lap?", a_label:"Yes", a_odds:300, b_label:"No", b_odds:-400, note:"Lap availability confirmed." },
    { id:"steve",    course:"Side Dishes",  sort:260, question:"Will Steve eat beans?", a_label:"Yes", a_odds:-800, b_label:"No", b_odds:500, note:"Steve, you'd never refuse beans. Again." },
    { id:"dogs",     course:"Side Dishes",  sort:270, question:"Will Chase and George pick the same chili?", a_label:"Yes", a_odds:180, b_label:"No", b_odds:-220, note:"They agreed once. It was on a sock." },
  ],
};
