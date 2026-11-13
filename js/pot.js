// The bubbling pot: beans drifting up behind the page, plus bean bursts on big moments.
(function () {
  const cv = document.getElementById("pot");
  if (!cv) { window.burst = () => {}; return; }
  const cx = cv.getContext("2d");
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let W, H;
  function size() {
    const dpr = Math.min(2, devicePixelRatio || 1);
    W = innerWidth; H = innerHeight;
    cv.width = W * dpr; cv.height = H * dpr; cx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (still) frame();
  }
  const COLS = ["#6b170b", "#8f2414", "#b51f0e", "#ffc31c", "#3dbb52", "#fff3dc"];
  const rnd = (a, b) => a + Math.random() * (b - a);
  const beans = Array.from({ length: 26 }, () => ({
    x: rnd(0, innerWidth), y: rnd(0, innerHeight), r: rnd(8, 18), rot: rnd(0, 6.3), vr: rnd(-0.01, 0.01), vy: rnd(0.15, 0.5),
    c: Math.random() < 0.8 ? COLS[Math.random() < 0.5 ? 0 : 1] : COLS[2], k: Math.random() < 0.85 ? "bean" : "bubble",
  }));
  let sparks = [];
  function drawBean(b, alpha) {
    cx.save(); cx.globalAlpha = alpha; cx.translate(b.x, b.y); cx.rotate(b.rot);
    if (b.k === "bubble") {
      cx.strokeStyle = "rgba(255,243,220,.35)"; cx.lineWidth = 2; cx.beginPath(); cx.arc(0, 0, b.r * 0.7, 0, 7); cx.stroke(); cx.restore(); return;
    }
    cx.fillStyle = b.c; cx.beginPath(); cx.ellipse(0, 0, b.r, b.r * 0.62, 0, 0, 7); cx.fill();
    cx.fillStyle = "#e8321b"; cx.beginPath(); cx.ellipse(0, b.r * 0.62, b.r * 0.32, b.r * 0.22, 0, 0, 7); cx.fill();
    cx.fillStyle = "rgba(255,243,220,.25)"; cx.beginPath(); cx.ellipse(-b.r * 0.35, -b.r * 0.2, b.r * 0.25, b.r * 0.1, -0.4, 0, 7); cx.fill();
    cx.restore();
  }
  let running = false;
  function frame() {
    cx.clearRect(0, 0, W, H);
    for (const b of beans) {
      if (!still) { b.y -= b.vy; b.rot += b.vr; b.x += Math.sin((b.y + b.r * 20) / 60) * 0.3; if (b.y < -30) { b.y = H + 30; b.x = rnd(0, W); } }
      drawBean(b, 0.55);
    }
    sparks = sparks.filter((s) => s.life > 0);
    for (const s of sparks) { s.x += s.vx; s.y += s.vy; s.vy += 0.35; s.rot += s.vr; s.life -= 0.012; drawBean(s, Math.min(1, s.life * 2)); }
    if (!still && !document.hidden) requestAnimationFrame(frame); else running = false;
  }
  function start() { if (!running && !still) { running = true; requestAnimationFrame(frame); } }
  window.burst = function (x, y, n) {
    if (still) return;
    for (let i = 0; i < n; i++) {
      const a = rnd(0, 6.3), s = rnd(3, 9);
      sparks.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 4, r: rnd(5, 11), rot: rnd(0, 6), vr: rnd(-0.2, 0.2), c: COLS[Math.floor(rnd(0, 6))], k: "bean", life: 1 });
    }
    start();
  };
  size(); addEventListener("resize", size);
  document.addEventListener("visibilitychange", start);
  start(); if (still) frame();
})();
