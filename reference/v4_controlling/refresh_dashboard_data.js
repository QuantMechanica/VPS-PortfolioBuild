#!/usr/bin/env node
/*
 * Controlling dashboard DATA refresher (QUAA-228 P0 follow-up).
 *
 * Reads live state sources and patches the `const DATA = {...}` block
 * embedded inside Dashboard/project_dashboard.html, then mirrors to the
 * G-drive root and MT5-terminal copies. Runs on every Controlling heartbeat
 * and MUST be idempotent — rerunning with no source changes should still
 * bump `dashboard_written_ts` so staleness checks can see the refresh.
 *
 * Scope (QUAA-228 P0): timestamps + bl_progress. Phase counters stay as
 * maintained elsewhere; this script does not fabricate numbers.
 */

const fs = require("fs");
const path = require("path");

const CANONICAL = "G:/Meine Ablage/QuantMechanica/Dashboard/project_dashboard.html";
const MIRROR_ROOT = "G:/Meine Ablage/QuantMechanica/project_dashboard.html";
const MIRROR_MT5 = "C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Files/edge_validation/output/project_dashboard.html";

const LAST_CHECK_STATE = "C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Experts/EA_Testing/last_check_state.json";

function readJsonStripBOM(p) {
  let s = fs.readFileSync(p, "utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1);
  return JSON.parse(s);
}

function isoNowUTC() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function nowCET() {
  const d = new Date();
  const cet = new Date(d.toLocaleString("en-US", { timeZone: "Europe/Berlin" }));
  const pad = n => String(n).padStart(2, "0");
  return `${cet.getFullYear()}-${pad(cet.getMonth() + 1)}-${pad(cet.getDate())} ${pad(cet.getHours())}:${pad(cet.getMinutes())}:${pad(cet.getSeconds())}`;
}

function extractDataBlock(html) {
  const start = html.indexOf("const DATA = {");
  if (start === -1) throw new Error("const DATA block not found");
  const openBrace = html.indexOf("{", start);
  let depth = 0;
  let i = openBrace;
  let inStr = null;
  let esc = false;
  for (; i < html.length; i++) {
    const c = html[i];
    if (inStr) {
      if (esc) { esc = false; continue; }
      if (c === "\\") { esc = true; continue; }
      if (c === inStr) { inStr = null; }
      continue;
    }
    if (c === '"' || c === "'") { inStr = c; continue; }
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) { i++; break; }
    }
  }
  return { start: openBrace, end: i, json: html.slice(openBrace, i) };
}

function patchData(data, lastCheckState) {
  const utcIso = isoNowUTC();
  const cet = nowCET();

  // brand + summary — visible subtitle timestamps the user reads.
  data.brand = data.brand || {};
  data.brand.subtitle_timestamp = utcIso;
  data.summary = data.summary || {};
  data.summary.updated = cet;

  // refresh block — CSS banner + cadence metadata.
  data.refresh = data.refresh || {};
  data.refresh.dashboard_written_ts = utcIso;
  data.refresh.cadence_min = data.refresh.cadence_min || 60;
  data.refresh.decoupled_from_tracker_health = true;
  data.refresh.note = "Dashboard refresh runs on Controlling heartbeat regardless of tracker state. Banner shows live pipeline state so STALE/PARTIAL/DEGRADED are visible even when refresh is current.";

  // last_check_state_snapshot — drive the health banner and Block E/bl_progress.
  const snap = data.last_check_state_snapshot || {};
  snap.source_path = LAST_CHECK_STATE;
  snap.timestamp = lastCheckState.timestamp || snap.timestamp || null;
  const blSrc = lastCheckState.bl_progress || {};
  const blOut = {};
  for (const tid of ["T1", "T2", "T3"]) {
    const r = blSrc[tid] || {};
    const current = Number(r.current) || 0;
    const total = Number(r.total) || 0;
    const reportAge = Number(r.report_age_sec);
    const out = {
      current,
      total,
      status: r.status || "unknown",
      report_age_sec: Number.isFinite(reportAge) ? Number(reportAge.toFixed(1)) : null,
    };
    if (r.pid != null) out.pid = r.pid;
    if (r.latest_report) out.latest_report = r.latest_report;
    blOut[tid] = out;
  }
  snap.bl_progress = blOut;
  const pending = lastCheckState.pending_tasks_open;
  snap.pending_tasks_open_count = pending && typeof pending === "object" ? Object.keys(pending).length : 0;
  snap.disk_free_gb = lastCheckState.disk_free_gb != null ? lastCheckState.disk_free_gb : snap.disk_free_gb;
  snap.writer_pid = lastCheckState.writer_pid != null ? lastCheckState.writer_pid : snap.writer_pid;
  snap.iteration = lastCheckState.iteration != null ? lastCheckState.iteration : snap.iteration;
  // Pass through event/blocker maps so Block D "Today at a Glance" can render
  // restart/resolution counts + blocker list without a second state-file read.
  snap.completed_events_today = lastCheckState.completed_events_today || {};
  snap.events_this_tick = lastCheckState.events_this_tick || {};
  snap.blocked = lastCheckState.blocked || {};
  data.last_check_state_snapshot = snap;
}

function writeAll(html) {
  fs.writeFileSync(CANONICAL, html);
  fs.writeFileSync(MIRROR_MT5, html);
  // Root mirror preserves QM_PROCESSES_LINK if it exists, else plain mirror.
  let rootExisting = "";
  try { rootExisting = fs.readFileSync(MIRROR_ROOT, "utf8"); } catch (_) {}
  const linkMatch = rootExisting.match(/<!-- QM_PROCESSES_LINK_START -->[\s\S]*?<!-- QM_PROCESSES_LINK_END -->/);
  if (linkMatch) {
    const idx = html.lastIndexOf("</body>");
    if (idx !== -1) {
      fs.writeFileSync(MIRROR_ROOT, html.slice(0, idx) + "\n" + linkMatch[0] + "\n" + html.slice(idx));
    } else {
      fs.writeFileSync(MIRROR_ROOT, html + "\n" + linkMatch[0] + "\n");
    }
  } else {
    fs.writeFileSync(MIRROR_ROOT, html);
  }
}

function main() {
  const html = fs.readFileSync(CANONICAL, "utf8");
  const { start, end, json } = extractDataBlock(html);
  const data = JSON.parse(json);
  const lcs = readJsonStripBOM(LAST_CHECK_STATE);
  patchData(data, lcs);
  const newJson = JSON.stringify(data, null, 2);
  const patched = html.slice(0, start) + newJson + html.slice(end);
  writeAll(patched);

  const stamp = data.refresh.dashboard_written_ts;
  console.log(JSON.stringify({
    ok: true,
    dashboard_written_ts: stamp,
    subtitle_timestamp: data.brand.subtitle_timestamp,
    summary_updated: data.summary.updated,
    last_check_state_snapshot_timestamp: data.last_check_state_snapshot.timestamp,
    bl_progress: data.last_check_state_snapshot.bl_progress,
  }, null, 2));
}

main();
