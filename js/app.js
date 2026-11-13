// Chili Market player app
(function () {
  const API = window.ChiliAPI;
  const $ = (s) => document.querySelector(s);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmt = (n) => Math.round(n).toLocaleString();
  const fmtOdds = (o) => (o > 0 ? `+${o}` : `${o}`);
  const pep = '<svg class="pep"><use href="#pepper"/></svg>';
  const HEAT = ["Mild", "Medium", "Hot", "Volcanic", "Call a doctor"];
  const heatOf = (l) => { const o = Math.max(l.a_odds, l.b_odds); return Math.max(1, Math.min(5, Math.ceil(Math.log10(o / 100 + 1) * 3))); };
  const SESSION = "chilimarket-session";

  const st = { token: null, user: null, data: null, sel: null, tab: "menu", busy: false };

  // wobbly title
  document.querySelectorAll(".wobble").forEach((el) => {
    el.innerHTML = [...el.dataset.word].map((ch, i) => `<span style="--i:${i}">${ch}</span>`).join("");
  });
  if (!API.LIVE) $("#demoFlag").hidden = false;

  // ---------- session ----------
  function saveSession() { try { localStorage.setItem(SESSION, JSON.stringify({ token: st.token, user: st.user })); } catch (e) {} }
  function clearSession() { try { localStorage.removeItem(SESSION); } catch (e) {} }
  function restore() { try { return JSON.parse(localStorage.getItem(SESSION)); } catch (e) { return null; } }

  async function enter(token, user, celebrate) {
    st.token = token; st.user = user;
    st.data = await API.getState(token);
    saveSession();
    $("#loginView").hidden = true; $("#appView").hidden = false;
    $("#whoami").textContent = `Betting as ${user}`;
    if (celebrate) burst(innerWidth / 2, innerHeight / 2, 40);
    render(); startPolling();
  }
  function leave() {
    st.token = null; st.data = null; st.sel = null; clearSession(); stopPolling();
    $("#appView").hidden = true; $("#loginView").hidden = false; $("#p").value = "";
  }

  $("#loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const btn = $("#loginBtn"); btn.disabled = true; $("#err").textContent = "";
    try {
      const r = await API.login($("#u").value.trim(), $("#p").value.trim().toLowerCase());
      await enter(r.token, r.username, true);
      toast(r.created ? `Welcome, ${r.username}! Here's 1,000 Zook Bucks` : `Welcome back, ${r.username}`);
    } catch (err) { $("#err").textContent = err.message; }
    btn.disabled = false;
  });
  $("#logout").addEventListener("click", leave);

  // ---------- polling ----------
  let timer = null;
  async function refresh() {
    if (!st.token || st.busy || document.hidden) return;
    try { st.data = await API.getState(st.token); render(true); }
    catch (err) { if (/logged out/.test(err.message)) { leave(); $("#err").textContent = err.message; } }
  }
  function startPolling() { stopPolling(); timer = setInterval(refresh, (window.CHILI_CONFIG.pollSeconds || 5) * 1000); }
  function stopPolling() { clearInterval(timer); }
  document.addEventListener("visibilitychange", () => { if (!document.hidden) refresh(); });

  // ---------- render ----------
  document.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", () => { st.tab = t.dataset.tab; render(); scrollTo(0, 0); }));
  const lineById = (id) => st.data.lines.find((l) => l.id === id);

  function render(quiet) {
    const d = st.data; if (!d) return;
    $("#bank").textContent = fmt(d.me.bank);
    document.querySelectorAll(".tab").forEach((t) => t.setAttribute("aria-selected", t.dataset.tab === st.tab));
    ["menu", "bowl", "hot"].forEach((k) => ($("#tab-" + k).hidden = k !== st.tab));
    const c = $("#betCount"); c.hidden = !d.bets.length; c.textContent = d.bets.length;
    // drop a selection whose line just closed
    if (st.sel) { const l = lineById(st.sel.id); if (!l || l.locked || l.result) { st.sel = null; if (quiet) toast("That line just closed", true); } }
    renderMenu(); renderBowl(); renderHot(); renderLadle(quiet);
  }

  function renderMenu() {
    const courses = [];
    for (const l of st.data.lines) {
      let c = courses.find((x) => x.name === l.course);
      if (!c) courses.push((c = { name: l.course, lines: [] }));
      c.lines.push(l);
    }
    const tags = { "Main Course": "House specials", "Over / Unders": "Pick a side", "Side Dishes": "Guest props" };
    if (!courses.length) { $("#tab-menu").innerHTML = `<div class="empty">The kitchen is still cooking up lines. Check back in a minute.</div>`; return; }
    $("#tab-menu").innerHTML = courses.map((c) => `
      <div class="course"><h2>${esc(c.name)}</h2>${tags[c.name] ? `<span>${tags[c.name]}</span>` : ""}</div>
      <div class="bowls">${c.lines.map(card).join("")}</div>`).join("") + `<p class="foot">Heat = how long the long shot is</p>`;
    document.querySelectorAll(".bean-btn").forEach((b) => b.addEventListener("click", () => {
      const id = b.dataset.line, side = b.dataset.side;
      st.sel = st.sel && st.sel.id === id && st.sel.side === side ? null : { id, side };
      $("#stake").value = ""; render();
    }));
  }
  function card(l) {
    const h = heatOf(l), closed = l.locked || l.result;
    let sticker = "";
    if (l.result === "void") sticker = `<span class="sticker void">Voided</span>`;
    else if (l.result) sticker = `<span class="sticker">Served: ${esc(l[l.result + "_label"])}</span>`;
    else if (l.locked) sticker = `<span class="sticker locked">Betting closed</span>`;
    const btn = (side) => `<button class="bean-btn" data-line="${esc(l.id)}" data-side="${side}" ${closed ? "disabled" : ""}
      aria-pressed="${!!st.sel && st.sel.id === l.id && st.sel.side === side}"><span class="lab">${esc(l[side + "_label"])}</span><span class="odds">${fmtOdds(l[side + "_odds"])}</span></button>`;
    return `<article class="bowl-card${closed ? " closed" : ""}">${sticker}
      <div class="heat"><span class="peps">${Array.from({ length: 5 }, (_, i) => `<span class="${i < h ? "" : "off"}">${pep}</span>`).join("")}</span><span>${HEAT[h - 1]}</span></div>
      <div class="q">${esc(l.question)}</div>
      <div class="picks">${btn("a")}${btn("b")}</div>
      ${l.note ? `<div class="note"><b>REHEARSAL DATA</b>${esc(l.note)}</div>` : ""}
    </article>`;
  }

  function renderLadle(quiet) {
    const show = !!st.sel && st.tab === "menu";
    $("#ladle").hidden = !show; $("#appWrap").style.paddingBottom = show ? "320px" : "";
    if (!show) return;
    const l = lineById(st.sel.id);
    $("#slipPick").innerHTML = `${esc(l[st.sel.side + "_label"])} <span class="num">${fmtOdds(l[st.sel.side + "_odds"])}</span><small>${esc(l.question)}</small>`;
    updatePayout();
  }
  function stakeVal() { return parseInt($("#stake").value, 10) || 0; }
  function updatePayout() {
    if (!st.sel) return;
    const s = stakeVal(), l = lineById(st.sel.id), bank = st.data.me.bank;
    $("#toWin").textContent = fmt(API.winAmt(s, l[st.sel.side + "_odds"]));
    $("#place").disabled = s <= 0 || s > bank || st.busy;
    $("#place").textContent = s > bank ? "Not enough Zook Bucks" : st.busy ? "Ladling…" : "Ladle it in";
  }
  $("#stake").addEventListener("input", (e) => { e.target.value = e.target.value.replace(/\D/g, ""); updatePayout(); });
  $("#stake").addEventListener("keydown", (e) => { if (e.key === "Enter") e.target.blur(); });
  document.querySelectorAll(".spoon").forEach((b) => b.addEventListener("click", () => {
    const bank = st.data.me.bank;
    $("#stake").value = b.dataset.add === "all" ? bank : Math.min(bank, stakeVal() + +b.dataset.add);
    updatePayout();
  }));
  $("#clearSlip").addEventListener("click", () => { st.sel = null; render(); });
  $("#place").addEventListener("click", async () => {
    const s = stakeVal(); if (!st.sel || s <= 0 || st.busy) return;
    const allIn = s === st.data.me.bank, r = $("#place").getBoundingClientRect();
    st.busy = true; updatePayout();
    try {
      st.data = await API.placeBet(st.token, st.sel.id, st.sel.side, s);
      st.sel = null; burst(r.left + r.width / 2, r.top, 46);
      const bp = $("#bankPill"); bp.classList.remove("bump"); void bp.offsetWidth; bp.classList.add("bump");
      toast(allIn ? "ALL IN. RESPECT." : `Ladled! ${fmt(s)} ZB`);
    } catch (err) { toast(err.message, true); }
    st.busy = false; render();
  });

  function renderBowl() {
    const el = $("#tab-bowl"), bets = st.data.bets;
    if (!bets.length) { el.innerHTML = `<div class="course"><h2>My Bowl</h2></div><div class="empty">Your bowl is empty. Go to The Menu, tap a bean and ladle in some Zook Bucks.</div>`; return; }
    const open = bets.filter((b) => b.status === "open").length;
    el.innerHTML = `<div class="course"><h2>My Bowl</h2><span>${open} still cooking</span></div>` + bets.map((b) => {
      const l = lineById(b.line_id) || { question: "(line removed)", a_label: "A", b_label: "B" };
      const splat = b.status === "won" ? `<span class="splat won">Paid!</span>` : b.status === "lost" ? `<span class="splat lost">Burnt</span>` : b.status === "void" ? `<span class="splat void">Refund</span>` : "";
      const right = b.status === "won" ? `Risk<b>${fmt(b.stake)}</b>Collected<b>${fmt(b.payout)}</b>` : `Risk<b>${fmt(b.stake)}</b>To win<b>${fmt(API.winAmt(b.stake, b.odds))}</b>`;
      return `<div class="scoop"><div class="sq">${esc(l.question)}<div class="sd">${esc(l[b.side + "_label"])} · <span class="num">${fmtOdds(b.odds)}</span></div>${splat}</div>
        <div class="amt">${right}</div></div>`;
    }).join("");
  }

  function renderHot() {
    const rows = st.data.leaders, max = Math.max(1, ...rows.map((r) => r.bankroll));
    $("#tab-hot").innerHTML = `<div class="course"><h2>Hot List</h2><span>Biggest bankroll wins</span></div>
      <div class="hot">${rows.map((r, i) => `<div class="hot-row${r.username === st.user ? " me" : ""}"><div class="rank">${i + 1}</div>
        <div class="bar"><div class="fill" style="width:${Math.max(8, (r.bankroll / max) * 100)}%"></div><span>${esc(r.username)}${r.username === st.user ? " (you)" : ""}</span><b>${fmt(r.bankroll)}</b></div></div>`).join("")}</div>
      <p class="foot">Bankroll = Zook Bucks in hand + bets still cooking</p>`;
  }

  let tt;
  function toast(m, bad) { const t = $("#toast"); t.textContent = m; t.classList.toggle("bad", !!bad); t.hidden = false; clearTimeout(tt); tt = setTimeout(() => (t.hidden = true), 2000); }

  // keep the ladle above the iPhone keyboard
  if (window.visualViewport) {
    const vv = visualViewport, ld = $("#ladle");
    const fit = () => { const kb = Math.max(0, innerHeight - vv.height - vv.offsetTop); ld.style.transform = kb > 40 ? `translateY(${-kb}px)` : ""; };
    vv.addEventListener("resize", fit); vv.addEventListener("scroll", fit);
  }

  // auto log back in after a refresh
  const saved = restore();
  if (saved && saved.token) enter(saved.token, saved.user, false).catch(() => clearSession());
})();
