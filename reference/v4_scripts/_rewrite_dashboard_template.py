#!/usr/bin/env python3
"""One-shot template rewrite for dashboard v2 per DASHBOARD_V2_DESIGN_SPEC.md.

Replaces the f-string HTML block in generate_dashboard.py (between the line
starting `    html = f\"\"\"<!DOCTYPE html>` and the terminating `</html>\"\"\"`)
with a `.replace(\"__JS_JSON__\", js_json)` of an ordinary triple-quoted template
defined at module level.
"""
from pathlib import Path
import re

GEN = Path(r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\6C3C6A11D1C3791DD4DBF45421BF8028\MQL5\Files\edge_validation\output\generate_dashboard.py")

src = GEN.read_text(encoding="utf-8")

# -- 1. Define the new template (ordinary string, no brace escaping needed) --
NEW_TEMPLATE = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>QuantMechanica - Portfolio Factory</title>
<style>
:root {
  --bg: #000000;
  --surface: #1a1a2e;
  --surface-2: #111122;
  --border: rgba(255,255,255,0.06);
  --text: #f5f5f7;
  --text-muted: #8a8a99;
  --emerald: #10b981;
  --amber: #d4a24b;
  --slate: #2a2a3e;
  --red: #ef4444;
  --num-font: "Source Code Pro", "SF Mono", Consolas, monospace;
  --ui-font: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: var(--bg); color: var(--text); font-family: var(--ui-font); padding: 24px; font-size: 14px; line-height: 1.45; }
.num { font-family: var(--num-font); font-variant-numeric: tabular-nums; }
[hidden] { display: none !important; }

header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 22px; border-bottom: 1px solid var(--border); padding-bottom: 14px; }
header h1 { font-size: 20px; font-weight: 600; letter-spacing: 0.3px; }
header h1 .accent { color: var(--emerald); }
header .sub { color: var(--text-muted); font-size: 12px; font-family: var(--num-font); }

.block { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 18px 20px; margin-bottom: 16px; }
.block-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; gap: 12px; }
.block-title { font-size: 10.5px; text-transform: uppercase; letter-spacing: 1.8px; color: var(--text-muted); font-weight: 600; }
.block-meta { font-size: 11px; color: var(--text-muted); font-family: var(--num-font); }

/* KPI band */
.kpi-band { display: grid; grid-template-columns: 1.5fr 1fr 1fr 1fr 1fr; gap: 12px; margin-bottom: 16px; }
.kpi { background: var(--surface); border: 1px solid var(--border); border-left: 3px solid var(--slate); border-radius: 10px; padding: 14px 16px; position: relative; min-height: 124px; display: flex; flex-direction: column; justify-content: space-between; }
.kpi.state-ok { border-left-color: var(--emerald); }
.kpi.state-alert { border-left-color: var(--red); }
.kpi .label { font-size: 10px; text-transform: uppercase; letter-spacing: 1.5px; color: var(--text-muted); font-weight: 600; }
.kpi .value { font-family: var(--num-font); font-size: 42px; font-weight: 500; color: var(--text); line-height: 1.05; margin-top: 4px; }
.kpi .value.state-text { font-size: 22px; font-weight: 600; letter-spacing: 0.5px; }
.kpi .value.state-text.ok { color: var(--emerald); }
.kpi .value.state-text.alert { color: var(--red); }
.kpi .value .denom { color: var(--text-muted); font-size: 22px; }
.kpi .sub { font-size: 11px; color: var(--text-muted); margin-top: 4px; min-height: 14px; }
.kpi .chip { position: absolute; top: 12px; right: 14px; font-family: var(--num-font); font-size: 11px; display: flex; align-items: center; gap: 3px; }
.kpi .chip.up { color: var(--emerald); }
.kpi .chip.down { color: var(--red); }
.kpi .chip.flat { color: var(--text-muted); }
.kpi .spark { width: 100%; height: 30px; margin-top: 8px; }

/* Delta strip */
.delta-strip { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
.delta-cell { background: var(--surface-2); border-radius: 6px; padding: 10px 12px; display: flex; align-items: center; gap: 10px; }
.delta-cell .name { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--text-muted); min-width: 86px; }
.delta-cell .delta { font-family: var(--num-font); font-size: 13px; font-weight: 500; min-width: 64px; white-space: nowrap; }
.delta-cell .spark { flex: 1; height: 20px; min-width: 40px; }
.delta-cell.breach .delta { color: var(--red); }
.up-c { color: var(--emerald); }
.down-c { color: var(--red); }
.flat-c { color: var(--text-muted); }

/* Phase funnel */
.phase-row { display: grid; grid-template-columns: 210px 1fr 64px; gap: 12px; align-items: center; padding: 7px 0; border-bottom: 1px solid var(--border); }
.phase-row:last-child { border-bottom: none; }
.phase-label { font-size: 12px; color: var(--text); display: flex; align-items: baseline; gap: 8px; }
.phase-label .code { font-family: var(--num-font); font-weight: 600; min-width: 42px; }
.phase-label .nm { color: var(--text-muted); font-size: 11px; }
.phase-bar { position: relative; height: 22px; background: var(--slate); border-radius: 4px; overflow: hidden; display: flex; }
.phase-seg { height: 100%; display: flex; align-items: center; padding: 0 6px; font-family: var(--num-font); font-size: 11px; font-weight: 600; white-space: nowrap; }
.phase-seg.passed { background: var(--emerald); color: #000; }
.phase-seg.testing { background: var(--amber); color: #000; }
.phase-seg.remaining { background: transparent; color: var(--text-muted); }
.phase-percent { font-family: var(--num-font); font-size: 13px; text-align: right; color: var(--text); }

/* Heatmap */
.heatmap { display: flex; flex-direction: column; gap: 2px; }
.hm-row { display: grid; grid-auto-flow: column; align-items: center; gap: 2px; }
.hm-label { padding-right: 8px; color: var(--text-muted); font-family: var(--num-font); font-size: 11px; min-width: 54px; }
.hm-days { display: grid; grid-auto-flow: column; gap: 2px; align-items: center; }
.hm-cell { height: 18px; border-radius: 2px; background: var(--surface-2); }
.hm-cell.today { outline: 1px solid var(--emerald); outline-offset: -1px; }
.hm-cell.yday { outline: 1px solid rgba(255,255,255,0.12); outline-offset: -1px; }
.hm-axis { display: grid; grid-auto-flow: column; gap: 2px; margin-top: 6px; padding-left: 62px; }
.hm-axis .d { font-family: var(--num-font); font-size: 9px; color: var(--text-muted); text-align: center; }

/* Terminal strip */
.term-row { display: grid; grid-template-columns: 14px 180px 1fr 120px 90px; gap: 12px; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--border); font-size: 13px; }
.term-row:last-child { border-bottom: none; }
.dot { width: 9px; height: 9px; border-radius: 50%; }
.dot.healthy { background: var(--emerald); }
.dot.idle { background: var(--amber); }
.dot.stalled { background: var(--red); box-shadow: 0 0 7px var(--red); }
.term-label { font-weight: 500; }
.term-label .role { color: var(--text-muted); font-weight: 400; }
.term-job { font-family: var(--num-font); color: var(--text); }
.term-job .muted { color: var(--text-muted); }
.term-time { font-family: var(--num-font); color: var(--text-muted); text-align: right; }
.term-queue { font-family: var(--num-font); color: var(--text-muted); text-align: right; }

/* V5 construction */
.v5-row { display: grid; grid-template-columns: 42px 200px 110px 100px 1fr; gap: 10px; align-items: center; padding: 8px 0; border-bottom: 1px solid var(--border); font-size: 13px; }
.v5-row:last-child { border-bottom: none; }
.v5-idx { font-family: var(--num-font); color: var(--text-muted); }
.v5-ea { font-family: var(--num-font); }
.v5-phase { color: var(--text-muted); font-size: 12px; font-family: var(--num-font); }
.pill { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: 10.5px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
.pill.PASS { background: var(--emerald); color: #000; }
.pill.PROMISING { background: var(--amber); color: #000; }
.pill.FAIL, .pill.BLOCKED { background: var(--red); color: #fff; }
.pill.PENDING { background: var(--slate); color: var(--text-muted); border: 1px solid var(--border); }
.v5-note { color: var(--text-muted); font-size: 12px; }

/* Attention */
.attn-row { display: grid; grid-template-columns: 14px 1fr; gap: 10px; padding: 10px 0; border-bottom: 1px solid var(--border); }
.attn-row:last-child { border-bottom: none; }
.attn-dot { width: 9px; height: 9px; border-radius: 50%; background: var(--red); margin-top: 6px; }
.attn-title { font-weight: 500; }
.attn-ctx { font-size: 12px; color: var(--text-muted); margin-top: 2px; }

/* Responsive */
@media (max-width: 1100px) {
  .kpi-band { grid-template-columns: repeat(2, 1fr); }
  .kpi.anchor { grid-column: span 2; }
  .delta-strip { grid-template-columns: repeat(2, 1fr); }
}
</style>
</head>
<body>

<header>
  <h1>Quant<span class="accent">Mechanica</span> &mdash; Portfolio Factory</h1>
  <div class="sub">Strategy-mining pipeline &middot; updated <span id="ts">&mdash;</span></div>
</header>

<section id="kpi-band" class="kpi-band"></section>

<div class="block" id="delta-block">
  <div class="block-head">
    <div class="block-title">Today vs 7-day average</div>
  </div>
  <div class="delta-strip" id="delta-strip"></div>
</div>

<div class="block" id="funnel-block">
  <div class="block-head">
    <div class="block-title">Phase Funnel</div>
    <div class="block-meta">baseline = phase-entry queue</div>
  </div>
  <div id="phase-funnel"></div>
</div>

<div class="block" id="heatmap-block">
  <div class="block-head">
    <div class="block-title">Daily Trend &mdash; last 14 days</div>
    <div class="block-meta">row = phase &middot; column = day &middot; colour = pass-rate</div>
  </div>
  <div id="heatmap" class="heatmap"></div>
  <div id="heatmap-axis" class="hm-axis"></div>
</div>

<div class="block" id="terminals-block">
  <div class="block-head">
    <div class="block-title">Terminal Activity</div>
  </div>
  <div id="terminals"></div>
</div>

<div class="block" id="v5-block" hidden>
  <div class="block-head">
    <div class="block-title">V5 Construction</div>
    <div class="block-meta" id="v5-meta"></div>
  </div>
  <div id="v5-slots"></div>
</div>

<div class="block" id="attn-block" hidden>
  <div class="block-head">
    <div class="block-title">Attention</div>
  </div>
  <div id="attn-list"></div>
</div>

<script>
const DATA = __JS_JSON__;

// ----- utils --------------------------------------------------------------
function escapeHtml(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
function fmtNum(n, digits) {
  if (n == null || isNaN(n)) return "\u2014";
  return Number(n).toFixed(digits == null ? 0 : digits);
}
function fmtSignedPct(n, digits) {
  if (n == null || isNaN(n)) return "\u00b1 0%";
  const v = Number(n).toFixed(digits == null ? 1 : digits);
  return (n > 0 ? "+" : "") + v + "%";
}
function fmtSignedInt(n) {
  if (n == null || isNaN(n)) return "0";
  const v = Math.round(Number(n));
  return (v > 0 ? "+" : "") + v;
}
function arrowSym(a) { return a === "up" ? "\u25b2" : a === "down" ? "\u25bc" : "\u2014"; }
function arrowClass(a, upIsGood) {
  if (a === "flat") return "flat-c";
  if (upIsGood !== false) return a === "up" ? "up-c" : "down-c";
  return a === "up" ? "down-c" : "up-c";
}
function fmtTimeSince(sec) {
  if (!sec || sec <= 0) return "\u2014";
  if (sec < 60) return sec + "s ago";
  if (sec < 3600) return Math.floor(sec / 60) + "m ago";
  if (sec < 86400) return (sec / 3600).toFixed(1) + "h ago";
  return Math.floor(sec / 86400) + "d ago";
}

// ----- sparkline ----------------------------------------------------------
function sparkSvg(values, opts) {
  opts = opts || {};
  const w = opts.width || 120;
  const h = opts.height || 30;
  const stroke = opts.stroke || "#10b981";
  const fill = opts.fill || "none";
  if (!values || values.length === 0) {
    return '<svg class="spark" viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none"></svg>';
  }
  const vals = values.map(v => (v == null || isNaN(v)) ? 0 : Number(v));
  const min = Math.min.apply(null, vals);
  const max = Math.max.apply(null, vals);
  const range = max - min || 1;
  const n = vals.length;
  const step = n === 1 ? 0 : w / (n - 1);
  const pts = vals.map((v, i) => {
    const x = step * i;
    const y = h - ((v - min) / range) * (h - 4) - 2;
    return x.toFixed(1) + "," + y.toFixed(1);
  }).join(" ");
  const lastX = step * (n - 1);
  const lastY = h - ((vals[n - 1] - min) / range) * (h - 4) - 2;
  return '<svg class="spark" viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none">' +
    '<polyline points="' + pts + '" fill="' + fill + '" stroke="' + stroke + '" stroke-width="1.4" vector-effect="non-scaling-stroke"/>' +
    '<circle cx="' + lastX.toFixed(1) + '" cy="' + lastY.toFixed(1) + '" r="1.8" fill="' + stroke + '"/>' +
    '</svg>';
}

// ----- header -------------------------------------------------------------
(function renderHeader() {
  const ts = DATA.brand && DATA.brand.subtitle_timestamp ? DATA.brand.subtitle_timestamp : (DATA.summary && DATA.summary.updated) || "";
  document.getElementById("ts").textContent = ts;
})();

// ----- KPI band -----------------------------------------------------------
(function renderKpis() {
  const k = DATA.kpis || {};
  const band = document.getElementById("kpi-band");
  const tiles = [];

  // 1. V5 Deploy Readiness (anchor)
  const dr = k.deploy_readiness_v5 || {};
  const drReady = dr.state === "READY";
  tiles.push(
    '<div class="kpi anchor ' + (drReady ? "state-ok" : "state-alert") + '">' +
      '<div>' +
        '<div class="label">V5 Deploy Readiness</div>' +
        '<div class="value state-text ' + (drReady ? "ok" : "alert") + '">' + (drReady ? "READY" : "NOT READY") + '</div>' +
      '</div>' +
      '<div class="sub">' +
        (drReady
          ? "All sleeves & gates resolved"
          : (dr.blocker_count || 0) + " blocker" + (dr.blocker_count === 1 ? "" : "s") +
            (dr.blocker_headline ? " &middot; " + escapeHtml(dr.blocker_headline) : "")) +
      '</div>' +
    '</div>'
  );

  // 2. Pipeline Health
  const ph = k.pipeline_health || { value: 0, denominator: 1, sparkline_7d: [] };
  const phDelta = ph.delta_vs_yesterday || 0;
  tiles.push(
    '<div class="kpi">' +
      '<div>' +
        '<div class="label">Pipeline Health</div>' +
        '<div class="value num">' + ph.value + '<span class="denom"> / ' + ph.denominator + '</span></div>' +
      '</div>' +
      (phDelta !== 0
        ? '<div class="chip ' + (phDelta > 0 ? "up" : "down") + '">' + arrowSym(phDelta > 0 ? "up" : "down") + ' ' + fmtSignedInt(phDelta) + '</div>'
        : "") +
      sparkSvg(ph.sparkline_7d) +
    '</div>'
  );

  // 3. Today throughput
  const tt = k.todays_throughput_per_hour || { value: 0, hourly_sparkline_today: [], delta_vs_7d_avg_pct: 0 };
  const ttDelta = tt.delta_vs_7d_avg_pct || 0;
  const ttArrow = ttDelta > 0 ? "up" : (ttDelta < 0 ? "down" : "flat");
  tiles.push(
    '<div class="kpi">' +
      '<div>' +
        '<div class="label">Throughput (today)</div>' +
        '<div class="value num">' + fmtNum(tt.value, 1) + '<span class="denom"> /h</span></div>' +
      '</div>' +
      '<div class="chip ' + ttArrow + '">' + arrowSym(ttArrow) + ' ' + fmtSignedPct(ttDelta) + '</div>' +
      sparkSvg(tt.hourly_sparkline_today) +
    '</div>'
  );

  // 4. Portfolio V4 PF
  const pf = k.portfolio_v4_pf || { value: 0, equity_sparkline_7d: [], delta_vs_yesterday: 0 };
  const pfDelta = pf.delta_vs_yesterday || 0;
  const pfArrow = pfDelta > 0 ? "up" : (pfDelta < 0 ? "down" : "flat");
  tiles.push(
    '<div class="kpi">' +
      '<div>' +
        '<div class="label">Portfolio V4 PF</div>' +
        '<div class="value num">' + fmtNum(pf.value, 2) + '</div>' +
      '</div>' +
      (pfDelta !== 0
        ? '<div class="chip ' + pfArrow + '">' + arrowSym(pfArrow) + ' ' + fmtNum(Math.abs(pfDelta), 2) + '</div>'
        : "") +
      sparkSvg(pf.equity_sparkline_7d) +
    '</div>'
  );

  // 5. Open blockers
  const ob = k.open_blockers || { value: 0, delta_vs_yesterday: 0 };
  const obDelta = ob.delta_vs_yesterday || 0;
  const obAlert = ob.value > 0;
  tiles.push(
    '<div class="kpi ' + (obAlert ? "state-alert" : "") + '">' +
      '<div>' +
        '<div class="label">Open Blockers</div>' +
        '<div class="value num">' + ob.value + '</div>' +
      '</div>' +
      (obDelta !== 0
        ? '<div class="chip ' + (obDelta > 0 ? "down" : "up") + '">' + arrowSym(obDelta > 0 ? "up" : "down") + ' ' + fmtSignedInt(obDelta) + '</div>'
        : "") +
      '<div class="sub">' + (obAlert ? "action required" : "clear") + '</div>' +
    '</div>'
  );

  band.innerHTML = tiles.join("");
})();

// ----- Delta strip --------------------------------------------------------
(function renderDeltaStrip() {
  const ds = DATA.delta_strip || {};
  const host = document.getElementById("delta-strip");
  const cells = [];
  const cfg = [
    { key: "throughput", label: "Throughput", fmt: (c) => fmtSignedPct(c.value_pct), stroke: "#10b981" },
    { key: "pass_rate", label: "Pass-rate", fmt: (c) => fmtSignedInt(c.value_pp) + " pp", stroke: "#10b981" },
    { key: "errors", label: "Errors", fmt: (c) => (c.value_abs > 0 ? "+" : "") + (c.value_abs || 0), stroke: "#ef4444" },
    { key: "avg_backtest_dur", label: "Avg BT dur", fmt: (c) => fmtSignedInt(c.value_sec) + "s", stroke: "#d4a24b" },
  ];
  cfg.forEach(spec => {
    const c = ds[spec.key] || { arrow: "flat", is_breach: false, sparkline: [] };
    const ac = arrowClass(c.arrow, spec.key !== "errors" && spec.key !== "avg_backtest_dur");
    cells.push(
      '<div class="delta-cell ' + (c.is_breach ? "breach" : "") + '">' +
        '<div class="name">' + spec.label + '</div>' +
        '<div class="delta ' + ac + '">' + arrowSym(c.arrow) + ' ' + spec.fmt(c) + '</div>' +
        sparkSvg(c.sparkline, { width: 50, height: 18, stroke: c.is_breach ? "#ef4444" : spec.stroke }) +
      '</div>'
    );
  });
  host.innerHTML = cells.join("");
})();

// ----- Phase funnel -------------------------------------------------------
(function renderPhaseFunnel() {
  const phases = DATA.phase_funnel || DATA.phase_progress || [];
  const host = document.getElementById("phase-funnel");
  if (!phases.length) { document.getElementById("funnel-block").hidden = true; return; }
  const rows = phases.map(p => {
    const total = Math.max(1, Number(p.total) || 0);
    const passed = Math.max(0, Number(p.passed) || 0);
    const tested = Math.max(passed, Number(p.tested) || 0);
    const remaining = Math.max(0, Number(p.remaining != null ? p.remaining : total - tested));
    const testingOnly = Math.max(0, tested - passed);
    const pctPassed = (passed / total) * 100;
    const pctTesting = (testingOnly / total) * 100;
    const pctRemaining = 100 - pctPassed - pctTesting;
    const pctLabel = (p.percent != null ? Number(p.percent) : pctPassed).toFixed(1);
    const segs = [
      pctPassed > 0 ? '<div class="phase-seg passed" style="width:' + pctPassed.toFixed(2) + '%">' + (pctPassed >= 6 ? passed : "") + '</div>' : "",
      pctTesting > 0 ? '<div class="phase-seg testing" style="width:' + pctTesting.toFixed(2) + '%">' + (pctTesting >= 6 ? testingOnly : "") + '</div>' : "",
      pctRemaining > 0 ? '<div class="phase-seg remaining" style="width:' + pctRemaining.toFixed(2) + '%">' + (pctRemaining >= 6 ? remaining : "") + '</div>' : "",
    ].join("");
    const offBarBits = [];
    if (pctPassed > 0 && pctPassed < 6) offBarBits.push('<span class="up-c">' + passed + '</span>');
    if (pctTesting > 0 && pctTesting < 6) offBarBits.push('<span style="color:var(--amber)">' + testingOnly + '</span>');
    if (pctRemaining > 0 && pctRemaining < 6) offBarBits.push('<span class="flat-c">' + remaining + '</span>');
    const offBar = offBarBits.length ? ' <span class="num" style="color:var(--text-muted);font-size:11px">(' + offBarBits.join(" &middot; ") + ')</span>' : "";
    const title = "total=" + total + " tested=" + tested + " passed=" + passed + " remaining=" + remaining;
    return (
      '<div class="phase-row" title="' + escapeHtml(title) + '">' +
        '<div class="phase-label"><span class="code">' + escapeHtml(p.phase) + '</span><span class="nm">' + escapeHtml(p.name || "") + '</span></div>' +
        '<div class="phase-bar">' + segs + '</div>' +
        '<div class="phase-percent">' + pctLabel + '%' + offBar + '</div>' +
      '</div>'
    );
  });
  host.innerHTML = rows.join("");
})();

// ----- Daily heatmap ------------------------------------------------------
(function renderHeatmap() {
  const hm = DATA.daily_heatmap || { days: [], phases: [], cells: [] };
  const host = document.getElementById("heatmap");
  if (!hm.days.length || !hm.phases.length) { document.getElementById("heatmap-block").hidden = true; return; }
  const lastDay = hm.days[hm.days.length - 1];
  const prevDay = hm.days.length > 1 ? hm.days[hm.days.length - 2] : null;
  const cellMap = {};
  hm.cells.forEach(c => { cellMap[c.phase + "|" + c.day] = c; });
  const rows = hm.phases.map(phase => {
    const cellsHtml = hm.days.map(day => {
      const c = cellMap[phase + "|" + day];
      if (!c || !c.has_data) {
        return '<div class="hm-cell' + (day === lastDay ? " today" : day === prevDay ? " yday" : "") + '" title="' + escapeHtml(day + " / " + phase + " - no data") + '"></div>';
      }
      const rate = Math.max(0, Math.min(1, Number(c.pass_rate) || 0));
      const bg = "rgba(16, 185, 129, " + (0.12 + rate * 0.78).toFixed(2) + ")";
      const cls = "hm-cell" + (day === lastDay ? " today" : day === prevDay ? " yday" : "");
      const t = day + " / " + phase + " - tests=" + c.tests + " pass=" + c.pass + " fail=" + c.fail + " marg=" + c.marg + " pass-rate=" + (rate * 100).toFixed(1) + "%";
      return '<div class="' + cls + '" style="background:' + bg + '" title="' + escapeHtml(t) + '"></div>';
    }).join("");
    const cols = "54px repeat(" + hm.days.length + ", minmax(14px, 1fr))";
    return '<div class="hm-row" style="grid-template-columns:' + cols + '"><div class="hm-label">' + escapeHtml(phase) + '</div>' + cellsHtml + '</div>';
  });
  host.innerHTML = rows.join("");
  // axis
  const axis = document.getElementById("heatmap-axis");
  axis.style.gridTemplateColumns = "repeat(" + hm.days.length + ", minmax(14px, 1fr))";
  axis.innerHTML = hm.days.map((d, i) => {
    const short = d.slice(5);
    const emph = (d === lastDay) ? ' style="color:var(--emerald);font-weight:600"' : "";
    const everyN = hm.days.length > 10 ? 2 : 1;
    return '<div class="d"' + emph + '>' + ((i % everyN === 0 || d === lastDay) ? short : "") + '</div>';
  }).join("");
})();

// ----- Terminals ----------------------------------------------------------
(function renderTerminals() {
  const terms = DATA.terminals || [];
  const host = document.getElementById("terminals");
  if (!terms.length) { document.getElementById("terminals-block").hidden = true; return; }
  host.innerHTML = terms.map(t => {
    const dotCls = "dot " + (t.status || "idle");
    const job = (t.current_ea && t.current_ea !== "n/a")
      ? escapeHtml(t.current_ea) + ' <span class="muted">' + escapeHtml(t.current_symbol || "") + ' &middot; ' + escapeHtml(t.current_phase || "") + '</span>'
      : '<span class="muted">idle</span>';
    return (
      '<div class="term-row">' +
        '<div class="' + dotCls + '"></div>' +
        '<div class="term-label">' + escapeHtml(t.id) + ' <span class="role">&middot; ' + escapeHtml(t.role || "") + '</span></div>' +
        '<div class="term-job">' + job + '</div>' +
        '<div class="term-time">' + fmtTimeSince(t.time_since_result_sec) + '</div>' +
        '<div class="term-queue">queue: ' + (t.queue_depth || 0) + '</div>' +
      '</div>'
    );
  }).join("");
})();

// ----- V5 Construction ----------------------------------------------------
(function renderV5() {
  const v5 = DATA.v5_construction || { active: false, slots: [] };
  if (!v5.active || !v5.slots || !v5.slots.length) return;
  document.getElementById("v5-block").hidden = false;
  document.getElementById("v5-meta").textContent = v5.slots.length + " slot" + (v5.slots.length === 1 ? "" : "s");
  document.getElementById("v5-slots").innerHTML = v5.slots.map(s => {
    const state = (s.state || "PENDING").toUpperCase();
    return (
      '<div class="v5-row">' +
        '<div class="v5-idx">#' + (s.index || "") + '</div>' +
        '<div class="v5-ea">' + escapeHtml(s.ea || "") + ' <span style="color:var(--text-muted)">' + escapeHtml(s.symbol || "") + '</span></div>' +
        '<div class="v5-phase">' + escapeHtml(s.phase || "") + '</div>' +
        '<div><span class="pill ' + state + '">' + state + '</span></div>' +
        '<div class="v5-note">' + escapeHtml(s.note || "") + '</div>' +
      '</div>'
    );
  }).join("");
})();

// ----- Attention ----------------------------------------------------------
(function renderAttention() {
  const items = DATA.attention_items || [];
  if (!items.length) return;
  document.getElementById("attn-block").hidden = false;
  document.getElementById("attn-list").innerHTML = items.slice(0, 5).map(it => (
    '<div class="attn-row">' +
      '<div class="attn-dot"></div>' +
      '<div>' +
        '<div class="attn-title">' + escapeHtml(it.title || "") + '</div>' +
        (it.context ? '<div class="attn-ctx">' + escapeHtml(it.context) + '</div>' : "") +
      '</div>' +
    '</div>'
  )).join("");
})();
</script>
</body>
</html>'''

# -- 2. Locate the f-string block to replace -----------------------------------
start_marker = '    html = f"""<!DOCTYPE html>'
end_marker = '</html>"""'
start_idx = src.find(start_marker)
if start_idx < 0:
    raise SystemExit("ERROR: start marker not found")
# find end_marker AFTER start_idx
end_idx = src.find(end_marker, start_idx)
if end_idx < 0:
    raise SystemExit("ERROR: end marker not found")
end_idx += len(end_marker)

# -- 3. Build new replacement ---------------------------------------------------
replacement = '    html = _V2_DASHBOARD_TEMPLATE.replace("__JS_JSON__", js_json)'

new_src = src[:start_idx] + replacement + src[end_idx:]

# -- 4. Inject the template constant near top of module (after imports) --------
# Insert just before `# -- Paths` section (TERMINAL_ROOT line)
inject_anchor = 'TERMINAL_ROOT = r"C:\\Users\\fabia'
anchor_idx = new_src.find(inject_anchor)
if anchor_idx < 0:
    # Fallback: after `from collections` import line
    anchor_idx = new_src.find("from collections import")
    if anchor_idx >= 0:
        anchor_idx = new_src.find("\n", anchor_idx) + 1
if anchor_idx < 0:
    raise SystemExit("ERROR: cannot find injection anchor for template constant")

# Go to start of the line containing the anchor
line_start = new_src.rfind("\n", 0, anchor_idx) + 1

# Only inject if not already present
if "_V2_DASHBOARD_TEMPLATE" not in new_src[:line_start]:
    template_literal = "_V2_DASHBOARD_TEMPLATE = r'''" + NEW_TEMPLATE + "'''\n\n"
    new_src = new_src[:line_start] + template_literal + new_src[line_start:]

# -- 5. Write back --------------------------------------------------------------
GEN.write_text(new_src, encoding="utf-8")
print("OK: rewrote", GEN)
print("size:", len(new_src), "bytes")
