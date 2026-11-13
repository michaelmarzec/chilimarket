# Chili Market 🌶️

The official sportsbook of the Chili Cook Off. Guests log in on their phones, get 1,000 Zook Bucks, bet on the night's lines, and watch the Hot List. Mook runs the book from the Kitchen (`/admin.html`).

- **Player site:** `index.html`
- **Admin ("The Kitchen"):** `admin.html`: edit odds, close betting, settle lines, add players, give out Zook Bucks
- **Database:** Supabase (free tier), set up with the two files in `supabase/`
- **Hosting:** GitHub Pages at `chilimarket.bet`

No build step. It's plain HTML, CSS and JavaScript.

## Try it right now (demo mode)

With no Supabase keys in `js/config.js`, the site runs in **demo mode**: everything works, but bets only live in your own browser.

Open `index.html` in a browser (or run `python3 -m http.server` in this folder and go to http://localhost:8000).

- Demo player login: `mook` / `zook` (demo only)
- Demo admin: http://localhost:8000/admin.html, password `changeme` (demo only)

## Go live

### 1. Supabase (the shared database)
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and click **Run**.
3. New query again, paste `supabase/seed.sql` (the lines) and run it.
4. New query again, paste `supabase/players.example.sql`, replace every `REPLACE_ME` with real passwords (add a row per guest), and run it. **Don't commit real passwords**: the repo is public. You can also add players later in the Kitchen.
5. Go to **Project Settings → API** (or **API Keys**) and copy the **Project URL** and the **anon / publishable** key.
6. Paste both into `js/config.js`.

The anon key is designed to be public. **Never** put the `service_role` / secret key in this repo.

### 2. GitHub
1. Create a **public** repo on GitHub named `chilimarket` (free GitHub Pages needs public).
2. From this folder:
   ```bash
   git init
   git add .
   git commit -m "Chili Market"
   git branch -M main
   git remote add origin https://github.com/michaelmarzec/chilimarket.git
   git push -u origin main
   ```
3. Repo → **Settings → Pages** → Source: *Deploy from a branch*, branch `main`, folder `/ (root)`.
4. Under **Custom domain**, enter `chilimarket.bet` and save. (The `CNAME` file in this repo already says this.)

### 3. Cloudflare DNS for chilimarket.bet
Add these records, all set to **DNS only** (grey cloud):

| Type  | Name | Content |
|-------|------|---------|
| A     | @    | 185.199.108.153 |
| A     | @    | 185.199.109.153 |
| A     | @    | 185.199.110.153 |
| A     | @    | 185.199.111.153 |
| CNAME | www  | michaelmarzec.github.io |

When GitHub shows the domain as verified, tick **Enforce HTTPS**.

## Running the night

- **Players:** add or reset players in the Kitchen → Players. Passwords aren't case-sensitive.
- **Odds:** edit any line and tap **Save changes**. New bets get the new odds; bets already placed keep the odds they got.
- **Close betting** right before something happens so nobody bets on a sure thing.
- **Settle:** tap the winning side (two taps to confirm). Winners get stake + winnings back instantly. **Void** refunds everyone.
- **Mistake?** **Unsettle** takes the payouts back and reopens the bets as pending.
- **Prizes / bonuses:** Players → Give or take Zook Bucks.
- Phones refresh every 5 seconds (change `pollSeconds` in `js/config.js`).
- Change the admin password by re-running the admin part of `players.example.sql` in the SQL Editor.

### Odds cheat sheet
- `+250`: bet 100 to win 250 (underdog)
- `-250`: bet 250 to win 100 (favorite)
- The pepper "heat meter" on each line is based on how long the long shot is.

## Files

```
index.html          player site
admin.html          the Kitchen
css/styles.css      all styles
js/config.js        Supabase URL + anon key (edit this)
js/api.js           talks to Supabase, or runs the demo
js/app.js           player app
js/admin.js         admin app
js/pot.js           the bubbling bean background
js/demo-data.js     sample data for demo mode only
supabase/schema.sql tables + secure functions
supabase/seed.sql   the betting lines
supabase/players.example.sql  template for admin + player passwords (fill in, don't commit)
CNAME               custom domain for GitHub Pages
```
