// One API for the site. Talks to Supabase when js/config.js has keys,
// otherwise runs an in-browser demo with the same behavior.
(function () {
  const cfg = window.CHILI_CONFIG || {};
  const LIVE = !!(cfg.supabaseUrl && cfg.supabaseAnonKey);

  const MESSAGES = {
    bad_login: "That username and password don't match. Check the card Mook gave you.",
    bad_token: "You've been logged out. Log in again.",
    bad_admin: "Wrong admin password.",
    no_line: "That bet doesn't exist anymore.",
    line_closed: "Betting on that one just closed.",
    bad_side: "Pick a side first.",
    bad_stake: "Enter how many Zook Bucks to bet.",
    insufficient: "Not enough Zook Bucks for that bet.",
    already_settled: "That line is already settled. Unsettle it first.",
    not_settled: "That line isn't settled yet.",
    bad_odds: "Odds must be +100 or more, or -100 or less.",
    bad_player: "Usernames need letters or numbers, and a password.",
    no_player: "No player with that username.",
  };
  function friendly(msg) {
    for (const k in MESSAGES) if (String(msg).includes(k)) return MESSAGES[k];
    if (/Failed to fetch|NetworkError|Load failed/i.test(msg)) return "Can't reach the sportsbook. Check your signal and try again.";
    return msg;
  }

  const winAmt = (stake, odds) => Math.floor(odds > 0 ? (stake * odds) / 100 : (stake * 100) / Math.abs(odds));

  // ---------------- live (Supabase RPC over REST) ----------------
  async function rpc(fn, args) {
    let res, data;
    try {
      res = await fetch(`${cfg.supabaseUrl.replace(/\/$/, "")}/rest/v1/rpc/${fn}`, {
        method: "POST",
        headers: { apikey: cfg.supabaseAnonKey, "Content-Type": "application/json" },
        body: JSON.stringify(args || {}),
      });
      data = await res.json().catch(() => null);
    } catch (e) {
      throw new Error(friendly(e.message));
    }
    if (!res.ok) throw new Error(friendly((data && (data.message || data.hint || data.error)) || `Error ${res.status}`));
    return data;
  }

  const live = {
    login: (u, p) => rpc("login", { p_username: u, p_password: p }),
    getState: (t) => rpc("get_state", { p_token: t }),
    placeBet: (t, line, side, stake) => rpc("place_bet", { p_token: t, p_line: line, p_side: side, p_stake: stake }),
    adminState: (pw) => rpc("admin_state", { p_pw: pw }),
    adminSaveLine: (pw, line) => rpc("admin_save_line", { p_pw: pw, p_line: line }),
    adminSetLock: (pw, id, locked) => rpc("admin_set_lock", { p_pw: pw, p_line: id, p_locked: locked }),
    adminSettle: (pw, id, result) => rpc("admin_settle", { p_pw: pw, p_line: id, p_result: result }),
    adminUnsettle: (pw, id) => rpc("admin_unsettle", { p_pw: pw, p_line: id }),
    adminDeleteLine: (pw, id) => rpc("admin_delete_line", { p_pw: pw, p_line: id }),
    adminSavePlayer: (pw, u, p, bank) => rpc("admin_save_player", { p_pw: pw, p_username: u, p_password: p, p_bank: bank }),
    adminAdjustBank: (pw, u, delta) => rpc("admin_adjust_bank", { p_pw: pw, p_username: u, p_delta: delta }),
  };

  // ---------------- demo (in this browser only) ----------------
  const KEY = "chilimarket-demo-v1";
  function load() {
    try { const s = JSON.parse(localStorage.getItem(KEY)); if (s && s.players) return s; } catch (e) {}
    const d = window.CHILI_DEMO;
    const s = {
      adminPassword: d.adminPassword,
      players: d.players.map((p) => ({ ...p, token: "demo-" + p.username })),
      lines: d.lines.map((l) => ({ ...l, locked: false, result: null })),
      bets: [], nextId: 1,
    };
    // one pre-settled line so the stamps are visible
    const steve = s.lines.find((l) => l.id === "steve");
    if (steve) { steve.result = "a"; steve.locked = true; }
    return s;
  }
  let db = load();
  function save() { try { localStorage.setItem(KEY, JSON.stringify(db)); } catch (e) {} }
  const fail = (code) => { throw new Error(friendly(code)); };
  const wait = (v) => new Promise((r) => setTimeout(() => r(v), 120));
  const clean = (u) => String(u || "").trim().toLowerCase();
  const sortedLines = () => [...db.lines].sort((a, b) => a.sort - b.sort || a.id.localeCompare(b.id));
  const playerBy = (t) => db.players.find((p) => p.token === t) || fail("bad_token");
  const checkAdmin = (pw) => { if (pw !== db.adminPassword) fail("bad_admin"); };
  const checkOdds = (o) => { if (!(o >= 100 || o <= -100)) fail("bad_odds"); };

  function state(p) {
    const leaders = db.players.map((pl) => {
      const mine = db.bets.filter((b) => b.username === pl.username);
      return { username: pl.username, bankroll: pl.bank + mine.filter((b) => b.status === "open").reduce((s, b) => s + b.stake, 0), bets: mine.length };
    }).sort((a, b) => b.bankroll - a.bankroll || a.username.localeCompare(b.username));
    return {
      me: { username: p.username, bank: p.bank },
      lines: sortedLines(),
      bets: db.bets.filter((b) => b.username === p.username).slice().reverse(),
      leaders,
    };
  }
  function adminView() {
    return {
      lines: sortedLines().map((l) => {
        const bs = db.bets.filter((b) => b.line_id === l.id);
        const t = (side) => ({ count: bs.filter((b) => b.side === side).length, stake: bs.filter((b) => b.side === side).reduce((s, b) => s + b.stake, 0) });
        return { ...l, tally: { a: t("a"), b: t("b") } };
      }),
      players: db.players.map((p) => ({ username: p.username, bank: p.bank, bets: db.bets.filter((b) => b.username === p.username).length }))
        .sort((a, b) => a.username.localeCompare(b.username)),
    };
  }

  const demo = {
    async login(u, p) {
      db = load();
      const pl = db.players.find((x) => x.username === clean(u));
      if (!pl || pl.password !== clean(p)) fail("bad_login");
      return wait({ token: pl.token, username: pl.username });
    },
    async getState(t) { db = load(); return wait(state(playerBy(t))); },
    async placeBet(t, id, side, stake) {
      db = load();
      const p = playerBy(t), l = db.lines.find((x) => x.id === id) || fail("no_line");
      if (l.locked || l.result) fail("line_closed");
      if (side !== "a" && side !== "b") fail("bad_side");
      if (!(stake > 0)) fail("bad_stake");
      if (stake > p.bank) fail("insufficient");
      p.bank -= stake;
      db.bets.push({ id: db.nextId++, username: p.username, line_id: id, side, stake, odds: side === "a" ? l.a_odds : l.b_odds, status: "open", payout: null });
      save(); return wait(state(p));
    },
    async adminState(pw) { db = load(); checkAdmin(pw); return wait(adminView()); },
    async adminSaveLine(pw, line) {
      db = load(); checkAdmin(pw); checkOdds(line.a_odds); checkOdds(line.b_odds);
      const i = db.lines.findIndex((l) => l.id === line.id);
      if (i >= 0) db.lines[i] = { ...db.lines[i], ...line };
      else db.lines.push({ locked: false, result: null, ...line });
      save(); return wait(adminView());
    },
    async adminSetLock(pw, id, locked) {
      db = load(); checkAdmin(pw); const l = db.lines.find((x) => x.id === id) || fail("no_line");
      l.locked = !!locked; save(); return wait(adminView());
    },
    async adminSettle(pw, id, result) {
      db = load(); checkAdmin(pw); const l = db.lines.find((x) => x.id === id) || fail("no_line");
      if (l.result) fail("already_settled");
      db.bets.filter((b) => b.line_id === id && b.status === "open").forEach((b) => {
        b.status = result === "void" ? "void" : b.side === result ? "won" : "lost";
        b.payout = b.status === "void" ? b.stake : b.status === "won" ? b.stake + winAmt(b.stake, b.odds) : 0;
        db.players.find((p) => p.username === b.username).bank += b.payout;
      });
      l.result = result; l.locked = true; save(); return wait(adminView());
    },
    async adminUnsettle(pw, id) {
      db = load(); checkAdmin(pw); const l = db.lines.find((x) => x.id === id) || fail("no_line");
      if (!l.result) fail("not_settled");
      db.bets.filter((b) => b.line_id === id && b.status !== "open").forEach((b) => {
        db.players.find((p) => p.username === b.username).bank -= b.payout || 0;
        b.status = "open"; b.payout = null;
      });
      l.result = null; save(); return wait(adminView());
    },
    async adminDeleteLine(pw, id) {
      db = load(); checkAdmin(pw);
      db.bets.filter((b) => b.line_id === id && b.status === "open").forEach((b) => { db.players.find((p) => p.username === b.username).bank += b.stake; });
      db.bets = db.bets.filter((b) => b.line_id !== id); db.lines = db.lines.filter((l) => l.id !== id);
      save(); return wait(adminView());
    },
    async adminSavePlayer(pw, u, p, bank) {
      db = load(); checkAdmin(pw); const name = clean(u);
      if (!/^[a-z0-9_.-]+$/.test(name) || !clean(p)) fail("bad_player");
      const ex = db.players.find((x) => x.username === name);
      if (ex) { ex.password = clean(p); if (bank != null) ex.bank = bank; }
      else db.players.push({ username: name, password: clean(p), bank: bank ?? 1000, token: "demo-" + name });
      save(); return wait(adminView());
    },
    async adminAdjustBank(pw, u, delta) {
      db = load(); checkAdmin(pw); const p = db.players.find((x) => x.username === clean(u)) || fail("no_player");
      p.bank += delta; save(); return wait(adminView());
    },
    reset() { try { localStorage.removeItem(KEY); } catch (e) {} db = load(); },
  };

  window.ChiliAPI = { LIVE, winAmt, ...(LIVE ? live : demo), resetDemo: demo.reset };
})();
