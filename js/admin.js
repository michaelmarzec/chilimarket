// The Kitchen: admin controls for Chili Market
(function () {
  const API = window.ChiliAPI;
  const $ = (s, el = document) => el.querySelector(s);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmt = (n) => Math.round(n).toLocaleString();
  const fmtOdds = (o) => (o > 0 ? `+${o}` : `${o}`);
  const KEY = "chilimarket-admin";
  let pw = null, data = null, tab = "lines";

  document.querySelectorAll(".wobble").forEach((el) => { el.innerHTML = [...el.dataset.word].map((ch, i) => `<span style="--i:${i}">${ch}</span>`).join(""); });
  if (!API.LIVE) $("#demoFlag").hidden = false;

  let tt;
  function toast(m, bad) { const t = $("#toast"); t.textContent = m; t.classList.toggle("bad", !!bad); t.hidden = false; clearTimeout(tt); tt = setTimeout(() => (t.hidden = true), 2200); }

  async function open(p) {
    data = await API.adminState(p); pw = p;
    try { sessionStorage.setItem(KEY, p); } catch (e) {}
    $("#gate").hidden = true; $("#kitchen").hidden = false; render();
  }
  $("#gateForm").addEventListener("submit", async (e) => {
    e.preventDefault(); $("#gateErr").textContent = "";
    try { await open($("#apw").value); } catch (err) { $("#gateErr").textContent = err.message; }
  });
  $("#lock").addEventListener("click", () => { pw = null; try { sessionStorage.removeItem(KEY); } catch (e) {} $("#kitchen").hidden = true; $("#gate").hidden = false; });
  document.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", async () => {
    tab = t.dataset.tab;
    try { data = await API.adminState(pw); } catch (e) {}
    render(); scrollTo(0, 0);
  }));

  // run an action, re-render on success
  async function act(fn, ok) {
    try { data = await fn(); render(); if (ok) toast(ok); return true; }
    catch (err) { toast(err.message, true); return false; }
  }
  // two-tap confirm for anything that moves money or deletes
  function armed(btn) {
    if (btn.classList.contains("armed")) { btn.classList.remove("armed"); return true; }
    const label = btn.textContent; btn.classList.add("armed"); btn.textContent = "Tap again";
    setTimeout(() => { btn.classList.remove("armed"); btn.textContent = label; }, 3000);
    return false;
  }

  function render() {
    document.querySelectorAll(".tab").forEach((t) => t.setAttribute("aria-selected", t.dataset.tab === tab));
    ["lines", "new", "players"].forEach((k) => ($("#tab-" + k).hidden = k !== tab));
    renderLines(); renderNew(); renderPlayers();
  }

  const courses = () => [...new Set(["Futures", "Main Course", "Over / Unders", "Side Dishes", ...data.lines.map((l) => l.course)])];
  const isMulti = (l) => Array.isArray(l.options);
  const labelOf = (l, s) => (isMulti(l) ? ((l.options.find((o) => o.key === s) || {}).label || "?") : l[s + "_label"]);
  const sidesOf = (l) => (isMulti(l) ? l.options.map((o) => o.key) : ["a", "b"]);
  const optionsText = (l) => (l.options || []).map((o) => `${o.label}, ${fmtOdds(o.odds)}`).join("\n");
  let newKind = "two";

  function lineFields(l, prefix, multi) {
    const id = (f) => `${prefix}-${f}`;
    const sides = multi
      ? `<div class="field"><label for="${id("opts")}">Options: one per line, name then odds (e.g. Jackie + Harry, +250)</label>
           <textarea id="${id("opts")}" data-f="options_text" rows="${Math.max(4, (l.options || []).length + 1)}" autocapitalize="words">${esc(optionsText(l))}</textarea></div>`
      : `<div class="row2col">
        <div class="field"><label for="${id("al")}">Side A</label><input id="${id("al")}" data-f="a_label" value="${esc(l.a_label)}"></div>
        <div class="field"><label for="${id("ao")}">A odds</label><input id="${id("ao")}" data-f="a_odds" inputmode="numeric" value="${l.a_odds ?? ""}"></div>
        <div class="field"><label for="${id("bl")}">Side B</label><input id="${id("bl")}" data-f="b_label" value="${esc(l.b_label)}"></div>
        <div class="field"><label for="${id("bo")}">B odds</label><input id="${id("bo")}" data-f="b_odds" inputmode="numeric" value="${l.b_odds ?? ""}"></div>
      </div>`;
    return `
      <div class="field"><label for="${id("q")}">Question</label><input id="${id("q")}" data-f="question" value="${esc(l.question)}"></div>
      ${sides}
      <div class="field"><label for="${id("n")}">Rehearsal data note</label><input id="${id("n")}" data-f="note" value="${esc(l.note)}"></div>
      <div class="row3col">
        <div class="field"><label for="${id("c")}">Section</label><input id="${id("c")}" data-f="course" list="courses" value="${esc(l.course)}"></div>
        <div class="field"><label for="${id("s")}">Order</label><input id="${id("s")}" data-f="sort" inputmode="numeric" value="${l.sort ?? ""}"></div>
      </div>`;
  }
  const toOdds = (v) => parseInt(String(v).replace("+", "").replace(/\s/g, ""), 10);
  // "Name, +250" per line. Keeps each option's key when its name stays the same, so placed bets stay attached.
  function parseOptions(text, existing) {
    const used = new Set(), old = existing || [];
    let n = Math.max(0, ...old.map((o) => parseInt(String(o.key).slice(1), 10) || 0));
    const rows = String(text || "").split("\n").map((r) => r.trim()).filter(Boolean);
    return rows.map((r) => {
      const m = r.match(/^(.*?)[\s,]+([+-]?\s*\d+)$/);
      if (!m || !m[1].trim()) throw new Error(`"${r}" needs a name and odds, like: Jackie + Harry, +250`);
      const label = m[1].replace(/,\s*$/, "").trim(), odds = toOdds(m[2]);
      if (!(odds >= 100 || odds <= -100)) throw new Error(`Odds for "${label}" must be +100 or more, or -100 or less.`);
      const match = old.find((o) => o.label.toLowerCase() === label.toLowerCase() && !used.has(o.key));
      const key = match ? match.key : "o" + ++n;
      used.add(key);
      return { key, label, odds };
    });
  }
  function readFields(el, base, multi) {
    const out = { ...base };
    el.querySelectorAll("[data-f]").forEach((i) => { out[i.dataset.f] = i.value.trim(); });
    if (multi) {
      out.options = parseOptions(out.options_text, base.options);
      delete out.options_text; out.a_odds = null; out.b_odds = null;
    } else {
      out.a_odds = toOdds(out.a_odds); out.b_odds = toOdds(out.b_odds); out.options = null;
    }
    out.sort = parseInt(out.sort, 10) || 0;
    return out;
  }
  const pick = (l) => ({ id: l.id, course: l.course, sort: l.sort, question: l.question, a_label: l.a_label, a_odds: l.a_odds, b_label: l.b_label, b_odds: l.b_odds, note: l.note, options: l.options || null });

  function renderLines() {
    const el = $("#tab-lines");
    el.innerHTML = `<datalist id="courses">${courses().map((c) => `<option value="${esc(c)}">`).join("")}</datalist>` +
      `<div class="btns" style="margin-top:14px"><button class="abtn" id="refresh" type="button">Refresh bets</button></div>` +
      data.lines.map((l) => {
        const multi = isMulti(l);
        const status = l.result === "void" ? "Voided" : l.result ? `Settled: ${esc(labelOf(l, l.result))}` : l.locked ? "Betting closed" : "Open for bets";
        const t = l.tally || {}, tt = (s) => t[s] || { count: 0, stake: 0 };
        const tally = sidesOf(l).map((s) => `${esc(labelOf(l, s))}: ${tt(s).count} bets · ${fmt(tt(s).stake)} ZB`).join(multi ? "<br>" : " &nbsp;|&nbsp; ");
        const settleBtns = sidesOf(l).map((s) => `<button class="abtn go" data-act="settle-${esc(s)}" type="button">${esc(labelOf(l, s))} wins</button>`).join("");
        return `<article class="admin-card" data-id="${esc(l.id)}">
          <div class="status">${multi ? "Pick the winner · " : ""}${status}</div>
          ${lineFields(l, "l-" + l.id, multi)}
          <div class="tally">${tally}</div>
          <div class="btns">
            <button class="abtn go" data-act="save" type="button">Save changes</button>
            ${l.result ? "" : `<button class="abtn warn" data-act="lock" type="button">${l.locked ? "Reopen betting" : "Close betting"}</button>`}
          </div>
          <div class="btns">
            ${l.result
              ? `<button class="abtn warn" data-act="unsettle" type="button">Unsettle</button>`
              : `${settleBtns}<button class="abtn" data-act="settle-void" type="button">Void (refund)</button>`}
            <button class="abtn bad" data-act="delete" type="button">Delete</button>
          </div>
        </article>`;
      }).join("");
    $("#refresh").addEventListener("click", () => act(() => API.adminState(pw), "Refreshed"));
    el.querySelectorAll(".admin-card").forEach((card) => {
      const id = card.dataset.id, l = data.lines.find((x) => x.id === id);
      card.querySelectorAll("[data-act]").forEach((b) => b.addEventListener("click", () => {
        const a = b.dataset.act;
        if (a === "save") {
          let line; try { line = readFields(card, pick(l), isMulti(l)); } catch (err) { return toast(err.message, true); }
          return act(() => API.adminSaveLine(pw, line), "Saved");
        }
        if (a === "lock") return act(() => API.adminSetLock(pw, id, !l.locked), l.locked ? "Betting reopened" : "Betting closed");
        if (!armed(b)) return;
        if (a.startsWith("settle-")) {
          const r = a.slice(7);
          return act(() => API.adminSettle(pw, id, r), r === "void" ? "Voided and refunded" : `Paid out: ${labelOf(l, r)}`).then((ok) => ok && burst(innerWidth / 2, innerHeight / 3, 50));
        }
        if (a === "unsettle") return act(() => API.adminUnsettle(pw, id), "Unsettled. Payouts taken back.");
        if (a === "delete") return act(() => API.adminDeleteLine(pw, id), "Deleted. Open bets refunded.");
      }));
    });
  }

  function renderNew() {
    const multi = newKind === "multi";
    const blank = { course: multi ? "Futures" : "Main Course", sort: (Math.max(0, ...data.lines.map((l) => l.sort)) || 0) + 10, question: "", a_label: "Yes", a_odds: "", b_label: "No", b_odds: "", note: "", options: [] };
    const el = $("#tab-new");
    el.innerHTML = `<div class="course"><h2>New line</h2></div>
      <article class="admin-card" id="newCard">
        <div class="field"><label for="newType">Type of bet</label>
          <select id="newType"><option value="two"${multi ? "" : " selected"}>Two sides (Yes/No, Over/Under)</option><option value="multi"${multi ? " selected" : ""}>Pick the winner (any number of options)</option></select></div>
        ${lineFields(blank, "new", multi)}
        <p class="err" id="newErr"></p>
        <div class="btns"><button class="abtn go" id="addLine" type="button">Add to the menu</button></div>
        <div class="tally">Odds: +250 means bet 100 to win 250. -250 means bet 250 to win 100.</div>
      </article>`;
    $("#newType").addEventListener("change", (e) => { newKind = e.target.value; renderNew(); });
    $("#addLine").addEventListener("click", async () => {
      let line; try { line = readFields($("#newCard"), { options: [] }, multi); } catch (err) { $("#newErr").textContent = err.message; return; }
      if (!line.question) { $("#newErr").textContent = "Write the question first."; return; }
      if (multi && line.options.length < 2) { $("#newErr").textContent = "Add at least two options, one per line."; return; }
      line.id = line.question.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 30) + "-" + Math.random().toString(36).slice(2, 6);
      if (await act(() => API.adminSaveLine(pw, line), "Added to the menu")) { tab = "lines"; render(); }
    });
  }

  function renderPlayers() {
    const el = $("#tab-players");
    el.innerHTML = `<div class="course"><h2>Players</h2><span>${data.players.length} spoons</span></div>
      <div class="admin-grid">
      <article class="admin-card">
        <div class="status">Shared player password: ${data.player_password_set ? "set" : "NOT SET (nobody can log in yet)"}</div>
        <div class="field"><label for="spw">Everyone logs in with any name plus this password</label><input id="spw" autocapitalize="none" autocorrect="off" spellcheck="false" placeholder="e.g. beans"></div>
        <div class="btns"><button class="abtn go" id="savePw" type="button">${data.player_password_set ? "Change password" : "Set password"}</button></div>
      </article>
      <article class="admin-card">
        <div class="status">Give or take Zook Bucks</div>
        <div class="row2col">
          <div class="field"><label for="au">Player</label><select id="au">${data.players.map((p) => `<option>${esc(p.username)}</option>`).join("")}</select></div>
          <div class="field"><label for="ad">Amount (use - to take)</label><input id="ad" inputmode="numeric" placeholder="500"></div>
        </div>
        <div class="btns"><button class="abtn go" id="adjust" type="button">Apply</button></div>
      </article>
      <article class="admin-card">
        <div class="status">Players (Zook Bucks in hand). Remove typo accounts here.</div>
        <div class="plist">${data.players.map((p) => `<div class="prow"><span>${esc(p.username)}<br><span class="num">${fmt(p.bank)} · ${p.bets} bets</span></span><button class="abtn bad" data-del="${esc(p.username)}" type="button">Remove</button></div>`).join("")}</div>
      </article></div>`;
    $("#savePw").addEventListener("click", () => {
      const v = $("#spw").value.trim();
      if (!v) return toast("Type a password first", true);
      act(() => API.adminSetPlayerPassword(pw, v), "Player password saved");
    });
    el.querySelectorAll("[data-del]").forEach((b) => b.addEventListener("click", () => {
      if (!armed(b)) return;
      act(() => API.adminDeletePlayer(pw, b.dataset.del), `Removed ${b.dataset.del} and their bets`);
    }));
    $("#adjust").addEventListener("click", () => {
      const d = parseInt($("#ad").value, 10);
      if (!d) return toast("Enter an amount", true);
      act(() => API.adminAdjustBank(pw, $("#au").value, d), `${d > 0 ? "Gave" : "Took"} ${fmt(Math.abs(d))} ZB`);
    });
  }

  let saved = null; try { saved = sessionStorage.getItem(KEY); } catch (e) {}
  if (saved) open(saved).catch(() => {});
})();
