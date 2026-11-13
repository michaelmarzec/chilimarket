// Paste your Supabase project values here (Supabase dashboard → Project Settings → API).
// The anon / publishable key is meant to be public, so it's safe in a public repo.
// NEVER put the service_role / secret key here.
//
// While these are empty, the site runs in DEMO MODE: everything works,
// but bets only live in each person's browser.
window.CHILI_CONFIG = {
  supabaseUrl: "",      // e.g. "https://abcdefghijkl.supabase.co"
  supabaseAnonKey: "",  // e.g. "eyJhbGciOi..." or "sb_publishable_..."
  pollSeconds: 5,       // how often phones refresh odds, bets and the leaderboard
};
