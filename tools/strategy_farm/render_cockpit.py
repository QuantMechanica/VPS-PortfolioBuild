"""QM strategy_farm cockpit — single-page HTML view of the whole pipeline.

Renders D:/QM/strategy_farm/dashboards/cockpit.html on each invocation.
Designed to be called every 1-2 minutes via Windows Task Scheduler so
OWNER sees near-real-time state in a browser.

Sections:
  - Bottleneck banner (heuristic: where is throughput pinched?)
  - Pipeline view per EA (current_stage + attempts)
  - Backlog summary (cards / builds / reviews / backtests by status)
  - Work items table (per-(EA × symbol × phase) granularity)
  - MT5 fleet (active terminals + Codex/Node count)
  - Codex spawn status (active live logs + last activity)
  - Recent autonomous_wake decisions (last 10)
  - Recent commits (last 10)

Read-only. Control still goes through farmctl CLI commands listed at the
top of the page (copy-paste).
"""

from __future__ import annotations

import csv
import datetime as dt
import glob
import html
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
REPO = Path(r"C:\QM\repo")
DB = ROOT / "state" / "farm_state.sqlite"
DASH = ROOT / "dashboards"
COCKPIT = DASH / "cockpit.html"
LOG_DIR = ROOT / "logs"
WAKES_LOG = LOG_DIR / "autonomous_wakes.log"
CARDS_DRAFT = ROOT / "artifacts" / "cards_draft"
CARDS_APPROVED = ROOT / "artifacts" / "cards_approved"


def db_rows(query: str, params: tuple = ()) -> list[dict]:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in con.execute(query, params).fetchall()]
    finally:
        con.close()


def list_files(p: Path, pattern: str = "*.md") -> list[str]:
    if not p.is_dir():
        return []
    return sorted(f.name for f in p.glob(pattern))


def proc_counts() -> dict[str, int]:
    out = {"terminal64": 0, "codex": 0, "node": 0, "python": 0, "pwsh": 0, "claude": 0}
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-Process | Where-Object {$_.Name -match 'terminal64|codex|node|python|pwsh|claude'} | "
             "Group-Object Name | Select-Object Name, Count | ConvertTo-Json -Compress"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout or "[]")
            if isinstance(data, dict):
                data = [data]
            for entry in data:
                n = (entry.get("Name") or "").lower()
                c = int(entry.get("Count") or 0)
                if n in out:
                    out[n] = c
    except Exception:
        pass
    return out


def codex_spawns() -> list[dict]:
    """Active codex live logs (modified in last 5 min)."""
    out = []
    now = dt.datetime.now().timestamp()
    for log in LOG_DIR.glob("codex_build_*.live.log"):
        try:
            mtime = log.stat().st_mtime
            age_sec = now - mtime
            size_kb = log.stat().st_size // 1024
            task_id = log.stem.replace("codex_build_", "").replace(".live", "")
            out.append({
                "task_id": task_id,
                "size_kb": size_kb,
                "age_sec": int(age_sec),
                "active": age_sec < 300,  # within last 5 min = active
            })
        except OSError:
            pass
    out.sort(key=lambda x: x["age_sec"])
    return out


def recent_wakes(n: int = 15) -> list[str]:
    if not WAKES_LOG.exists():
        return []
    lines = WAKES_LOG.read_text(encoding="utf-8", errors="ignore").splitlines()
    return lines[-n:]


def recent_commits(n: int = 12) -> list[dict]:
    try:
        out = subprocess.run(
            ["git", "log", "--oneline", "-n", str(n), "agents/board-advisor", "--format=%h|%cr|%s"],
            cwd=str(REPO), capture_output=True, text=True, timeout=10,
        )
        commits = []
        for line in (out.stdout or "").splitlines():
            parts = line.split("|", 2)
            if len(parts) == 3:
                commits.append({"sha": parts[0], "rel": parts[1], "msg": parts[2]})
        return commits
    except Exception:
        return []


def compute_pipeline() -> list[dict]:
    """Re-implement farmctl pipeline_view inline to avoid subprocess overhead."""
    rows = db_rows(
        "SELECT id, kind, status, payload_json, created_at, updated_at "
        "FROM tasks ORDER BY created_at"
    )
    eas: dict[str, dict] = {}
    for r in rows:
        payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
        ea_id = payload.get("ea_id")
        if not ea_id:
            continue
        entry = eas.setdefault(ea_id, {
            "ea_id": ea_id,
            "slug": payload.get("slug") or "",
            "current_stage": "card",
            "total_attempts": 0,
            "phases": {},
            "last_activity": r["updated_at"],
        })
        if not entry["slug"] and payload.get("slug"):
            entry["slug"] = payload["slug"]
        if r["updated_at"] > entry["last_activity"]:
            entry["last_activity"] = r["updated_at"]
        entry["total_attempts"] += int(payload.get("attempt_count", 0))
        kind = r["kind"]
        if kind == "build_ea":
            if r["status"] == "pending":
                entry["current_stage"] = "build_pending"
            elif r["status"] == "active":
                entry["current_stage"] = "building"
            elif r["status"] == "done":
                entry["current_stage"] = "built"
            elif r["status"] in ("failed", "blocked"):
                entry["current_stage"] = f"build_{r['status']}"
        elif kind == "ea_review":
            v = (payload.get("verdict") or {}).get("verdict", "?")
            if r["status"] == "done":
                if v == "APPROVE_FOR_BACKTEST":
                    entry["current_stage"] = "review_approved"
                else:
                    entry["current_stage"] = f"review_{v.lower()}"
        elif kind.startswith("backtest_"):
            phase = payload.get("phase") or kind.replace("backtest_", "").upper()
            classification = payload.get("classification") or {}
            entry["phases"][phase] = {
                "status": r["status"],
                "verdict": classification.get("verdict"),
                "surviving_symbols": classification.get("surviving_symbols", []),
            }
            if r["status"] == "pending":
                entry["current_stage"] = f"{phase}_pending"
            elif r["status"] == "active":
                entry["current_stage"] = f"{phase}_running"
            elif r["status"] == "done":
                entry["current_stage"] = f"{phase}_{(classification.get('verdict') or '?').lower()}"
    return sorted(eas.values(), key=lambda e: e["ea_id"])


def diagnose_bottleneck(pipeline: list[dict], procs: dict[str, int],
                        task_counts: dict[str, int], cards_draft: int,
                        cards_approved: int) -> tuple[str, str]:
    """Return (severity, message). Severity: 'ok', 'warn', 'block'."""
    pending_builds = task_counts.get("build_ea_pending", 0)
    active_codex = procs.get("codex", 0)
    pending_p2 = task_counts.get("backtest_p2_pending", 0)
    active_p2 = task_counts.get("backtest_p2_active", 0)
    mt5 = procs.get("terminal64", 0)
    done_builds_awaiting_review = sum(
        1 for e in pipeline if e["current_stage"] == "built"
    )

    if pending_builds > 0 and active_codex >= 1:
        if pending_builds >= 3:
            return "warn", (f"Codex serial build queue: {pending_builds} pending, 1 running. "
                            f"~5-15 min/build → backlog drains in {pending_builds*10}-{pending_builds*15} min. "
                            "Cannot parallelize Codex via subscription auth.")
        return "ok", f"Codex serial build queue: {pending_builds} pending, 1 active. Healthy."
    if pending_builds > 0 and active_codex == 0:
        return "block", (f"Codex queue stalled: {pending_builds} pending builds but no codex/node process. "
                         "Next pump cycle (≤5 min) should spawn. If still stalled after 10 min, check pump.")
    if done_builds_awaiting_review > 0:
        return "warn", (f"{done_builds_awaiting_review} built EA(s) awaiting Claude review. "
                        "Review fires only at hourly autonomous_wake. Add Claude review to pump for continuous.")
    if active_p2 > 0 and mt5 < 2:
        return "warn", (f"P2 backtest active but only {mt5} MT5 running — should be N where N=symbols. "
                        "Check dispatch_work_items spawn.")
    if pending_p2 == 0 and active_p2 == 0 and pending_builds == 0:
        if cards_approved == 0:
            return "warn", ("Pipeline idle: no approved cards, no pending builds, no active P2. "
                            "Research is the bottleneck — claim a source / run autonomous_wake.")
        return "ok", "Pipeline idle (between cycles). Next pump in ≤5 min."
    return "ok", "Pipeline flowing."


def main() -> int:
    DASH.mkdir(parents=True, exist_ok=True)

    pipeline = compute_pipeline()
    procs = proc_counts()

    # task counts
    raw_counts = db_rows(
        "SELECT kind, status, COUNT(*) AS c FROM tasks GROUP BY kind, status"
    )
    tc = {f"{r['kind']}_{r['status']}": r["c"] for r in raw_counts}

    source_counts = db_rows(
        "SELECT status, COUNT(*) AS c FROM sources GROUP BY status"
    )
    sc = {r["status"]: r["c"] for r in source_counts}

    wi_counts_raw = db_rows(
        "SELECT phase, status, verdict, COUNT(*) AS c FROM work_items GROUP BY phase, status, verdict"
    )

    wi_recent = db_rows(
        "SELECT ea_id, phase, symbol, status, verdict, attempt_count, claimed_by, updated_at "
        "FROM work_items ORDER BY updated_at DESC LIMIT 30"
    )

    cards_draft_count = len(list_files(CARDS_DRAFT))
    cards_approved_count = len(list_files(CARDS_APPROVED))

    codex_logs = codex_spawns()
    wakes = recent_wakes(15)
    commits = recent_commits(12)

    severity, bottleneck_msg = diagnose_bottleneck(
        pipeline, procs, tc, cards_draft_count, cards_approved_count
    )

    # === HTML — QM brand tokens (branding/brand_tokens.json) ===
    now_local = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # Status colors per brand: PASS=emerald, FAIL/blocked=fail, WARN=promising,
    # ACTIVE/running=live, DEAD/pending=dead.
    severity_color = {"ok": "#10b981", "warn": "#f59e0b", "block": "#ef4444"}[severity]
    severity_label = {"ok": "OK", "warn": "WARN", "block": "BLOCK"}[severity]

    def stage_color(stage: str) -> str:
        s = stage.lower()
        if "pass" in s or stage == "built" or "approved" in s:
            return "#10b981"  # emerald — pass
        if "fail" in s or "blocked" in stage:
            return "#ef4444"  # fail
        if "running" in s or "active" in s or "building" in s:
            return "#06b6d4"  # live — active work
        if "pending" in s:
            return "#f59e0b"  # promising — queued
        return "#6b7280"  # dead — idle

    pipeline_rows = "\n".join(
        f"<tr><td class='mono'><b>{html.escape(e['ea_id'])}</b></td>"
        f"<td>{html.escape((e['slug'] or '')[:36])}</td>"
        f"<td style='color:{stage_color(e['current_stage'])}'><b>{html.escape(e['current_stage'])}</b></td>"
        f"<td class='mono'>{e['total_attempts']}</td>"
        f"<td class='mono muted'>{html.escape(e['last_activity'][:19])}</td></tr>"
        for e in pipeline
    )

    work_items_rows = "\n".join(
        f"<tr><td class='mono'>{html.escape(r['ea_id'])}</td>"
        f"<td class='mono'>{html.escape(r['phase'])}</td>"
        f"<td class='mono'>{html.escape(r['symbol'])}</td>"
        f"<td style='color:{stage_color(r['status'])}'><b>{html.escape(r['status'])}</b></td>"
        f"<td class='mono' style='color:{stage_color(r['verdict'] or 'pending')}'><b>{html.escape(str(r['verdict'] or '-'))}</b></td>"
        f"<td class='mono'>{r['attempt_count']}</td>"
        f"<td class='mono'>{html.escape(str(r['claimed_by'] or '-'))}</td>"
        f"<td class='mono muted'>{html.escape((r['updated_at'] or '')[:19])}</td></tr>"
        for r in wi_recent
    )

    wi_summary_rows = "\n".join(
        f"<tr><td class='mono'>{html.escape(r['phase'])}</td>"
        f"<td style='color:{stage_color(r['status'])}'>{html.escape(r['status'])}</td>"
        f"<td style='color:{stage_color(r['verdict'] or 'pending')}'><b>{html.escape(str(r['verdict'] or '-'))}</b></td>"
        f"<td class='mono'>{r['c']}</td></tr>"
        for r in wi_counts_raw
    )

    task_count_rows = "\n".join(
        f"<tr><td class='mono'>{html.escape(k)}</td><td class='mono'>{v}</td></tr>"
        for k, v in sorted(tc.items())
    )
    source_count_rows = "\n".join(
        f"<tr><td>{html.escape(k)}</td><td class='mono'>{v}</td></tr>"
        for k, v in sorted(sc.items())
    )

    codex_rows_list = []
    for c in codex_logs[:10]:
        col = "#06b6d4" if c["active"] else "#6b7280"  # live vs dead
        lbl = "active" if c["active"] else "idle"
        codex_rows_list.append(
            f"<tr><td class='mono'>{html.escape(c['task_id'][:8])}</td>"
            f"<td class='mono'>{c['size_kb']} KB</td>"
            f"<td class='mono'>{c['age_sec']}s</td>"
            f"<td class='mono' style='color:{col}'><b>{lbl}</b></td></tr>"
        )
    codex_rows = "\n".join(codex_rows_list)

    wakes_html = "\n".join(
        f"<div class='log'>{html.escape(line[:280])}</div>"
        for line in wakes
    )

    commits_rows = "\n".join(
        f"<tr><td class='mono'>{html.escape(c['sha'])}</td>"
        f"<td class='mono muted'>{html.escape(c['rel'])}</td>"
        f"<td>{html.escape(c['msg'][:96])}</td></tr>"
        for c in commits
    )

    html_doc = f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<title>QuantMechanica · Strategy Farm Cockpit</title>
<meta http-equiv="refresh" content="30">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Source+Code+Pro:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root {{
  --qm-bg: #020617;
  --qm-surface-0: #060b18;
  --qm-surface-1: #0f172a;
  --qm-surface-2: #1e293b;
  --qm-glass: rgba(15,23,42,0.6);
  --qm-border: rgba(148,163,184,0.08);
  --qm-border-strong: rgba(148,163,184,0.18);
  --qm-border-bright: rgba(148,163,184,0.32);
  --qm-text: #f8fafc;
  --qm-text-dim: #cbd5e1;
  --qm-text-muted: #94a3b8;
  --qm-text-subtle: #64748b;
  --qm-text-faint: #475569;
  --em: #10b981;
  --em-l: #34d399;
  --em-d: #059669;
  --em-s: rgba(16,185,129,0.12);
  --em-glow: rgba(16,185,129,0.25);
  --pass: #10b981;
  --promising: #f59e0b;
  --fail: #ef4444;
  --dead: #6b7280;
  --live: #06b6d4;
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'Source Code Pro', 'SF Mono', Menlo, Consolas, monospace;
}}

* {{ box-sizing: border-box; }}
html, body {{ margin: 0; padding: 0; }}
body {{
  font-family: var(--font-sans);
  background: var(--qm-bg);
  color: var(--qm-text);
  padding: 24px 32px;
  font-feature-settings: 'tnum' on, 'lnum' on;
  line-height: 1.5;
}}

h1 {{
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.01em;
  color: var(--qm-text);
  margin: 0 0 4px 0;
}}
h1 .subtitle {{
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 400;
  color: var(--qm-text-muted);
  letter-spacing: 0;
  margin-left: 12px;
}}
h2 {{
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--qm-text-muted);
  margin: 28px 0 10px 0;
}}

.banner {{
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  margin: 16px 0 24px 0;
  border-radius: 8px;
  border: 1px solid var(--qm-border-strong);
  background: var(--qm-glass);
  backdrop-filter: blur(8px);
}}
.banner-tag {{
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 3px;
  letter-spacing: 0.06em;
  color: var(--qm-bg);
  background: {severity_color};
  box-shadow: 0 0 12px {severity_color};
}}
.banner-msg {{ flex: 1; color: var(--qm-text-dim); font-size: 13px; }}

.metrics {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 12px;
  margin-bottom: 24px;
}}
.metric {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
  border-radius: 6px;
  padding: 10px 14px;
}}
.metric-value {{
  font-family: var(--font-mono);
  font-size: 22px;
  font-weight: 600;
  color: var(--qm-text);
  letter-spacing: -0.01em;
  line-height: 1.1;
}}
.metric-value.accent {{ color: var(--em); }}
.metric-label {{
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--qm-text-muted);
  margin-top: 4px;
}}

.grid {{
  display: grid;
  grid-template-columns: 2fr 1fr 1fr;
  gap: 16px;
}}
.card {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
  border-radius: 8px;
  padding: 14px 16px;
  overflow: hidden;
}}
.card h2 {{ margin-top: 0; }}

table {{
  border-collapse: collapse;
  width: 100%;
  font-size: 12px;
}}
th {{
  background: transparent;
  color: var(--qm-text-muted);
  text-align: left;
  padding: 6px 10px 8px 0;
  font-weight: 500;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  border-bottom: 1px solid var(--qm-border-strong);
}}
td {{
  padding: 5px 10px 5px 0;
  border-bottom: 1px solid var(--qm-border);
  color: var(--qm-text-dim);
}}
tr:last-child td {{ border-bottom: none; }}
tr:hover td {{ background: var(--em-s); }}
.mono {{ font-family: var(--font-mono); font-variant-numeric: tabular-nums; }}
.muted {{ color: var(--qm-text-muted); font-size: 11px; }}
.subtle {{ color: var(--qm-text-subtle); font-size: 10px; }}

.log {{
  font-family: var(--font-mono);
  font-size: 10.5px;
  padding: 4px 8px;
  border-left: 2px solid var(--em-d);
  margin-bottom: 2px;
  color: var(--qm-text-dim);
  background: var(--qm-surface-0);
  overflow-x: auto;
  white-space: nowrap;
}}

.cmd-list {{ display: flex; flex-direction: column; gap: 4px; }}
.cmd {{
  font-family: var(--font-mono);
  font-size: 11px;
  background: var(--qm-surface-0);
  border: 1px solid var(--qm-border);
  border-radius: 4px;
  padding: 6px 10px;
  color: var(--qm-text-dim);
  user-select: all;
}}
.cmd:hover {{ border-color: var(--em); box-shadow: 0 0 8px var(--em-glow); }}

a {{ color: var(--em-l); text-decoration: none; }}
a:hover {{ color: var(--em); text-shadow: 0 0 8px var(--em-glow); }}

.footer {{
  margin-top: 32px;
  padding-top: 16px;
  border-top: 1px solid var(--qm-border);
  text-align: center;
  font-size: 10px;
  color: var(--qm-text-subtle);
  font-family: var(--font-mono);
  letter-spacing: 0.04em;
}}
</style></head>
<body>

<h1>QuantMechanica Strategy Farm<span class="subtitle">cockpit · {now_local} · refresh 30s</span></h1>

<div class="banner">
  <span class="banner-tag">{severity_label}</span>
  <span class="banner-msg">{html.escape(bottleneck_msg)}</span>
</div>

<div class="metrics">
  <div class="metric"><div class="metric-value accent">{procs['terminal64']}</div><div class="metric-label">MT5 active</div></div>
  <div class="metric"><div class="metric-value">{procs['codex']}</div><div class="metric-label">Codex</div></div>
  <div class="metric"><div class="metric-value">{procs['claude']}</div><div class="metric-label">Claude</div></div>
  <div class="metric"><div class="metric-value">{procs['python']}</div><div class="metric-label">Python</div></div>
  <div class="metric"><div class="metric-value">{procs['pwsh']}</div><div class="metric-label">pwsh</div></div>
  <div class="metric"><div class="metric-value">{cards_draft_count}</div><div class="metric-label">Cards draft</div></div>
  <div class="metric"><div class="metric-value">{cards_approved_count}</div><div class="metric-label">Cards approved</div></div>
  <div class="metric"><div class="metric-value accent">{len(pipeline)}</div><div class="metric-label">EAs in pipeline</div></div>
</div>

<div class="grid">

<div class="card">
<h2>EA Pipeline</h2>
<table>
<tr><th>EA</th><th>Slug</th><th>Stage</th><th>Att.</th><th>Last</th></tr>
{pipeline_rows}
</table>
</div>

<div class="card">
<h2>Task Counts</h2>
<table>
<tr><th>Kind / Status</th><th>Count</th></tr>
{task_count_rows}
</table>
<h2 style="margin-top:16px">Sources</h2>
<table>
<tr><th>Status</th><th>Count</th></tr>
{source_count_rows}
</table>
</div>

<div class="card">
<h2>Work Items Summary</h2>
<table>
<tr><th>Phase</th><th>Status</th><th>Verdict</th><th>#</th></tr>
{wi_summary_rows}
</table>
</div>

</div>

<h2>Work Items — Recent 30</h2>
<div class="card">
<table>
<tr><th>EA</th><th>Phase</th><th>Symbol</th><th>Status</th><th>Verdict</th><th>Att.</th><th>Term</th><th>Updated</th></tr>
{work_items_rows}
</table>
</div>

<div class="grid">

<div class="card">
<h2>Codex Spawn Activity</h2>
<table>
<tr><th>Task ID</th><th>Log size</th><th>Last write</th><th>Status</th></tr>
{codex_rows}
</table>
</div>

<div class="card">
<h2>Autonomous Wakes (last 15)</h2>
{wakes_html}
</div>

<div class="card">
<h2>Recent Commits</h2>
<table>
<tr><th>SHA</th><th>Age</th><th>Subject</th></tr>
{commits_rows}
</table>
</div>

</div>

<h2>Control · CLI</h2>
<div class="card">
<div class="cmd-list">
  <span class="cmd">python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py pump</span>
  <span class="cmd">python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py pipeline</span>
  <span class="cmd">python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py work-items</span>
  <span class="cmd">schtasks /Run /TN QM_StrategyFarm_AutonomousWake_Hourly</span>
  <span class="cmd">schtasks /Run /TN QM_StrategyFarm_Pump_5min</span>
  <span class="cmd">Get-Process terminal64,codex,node,python,pwsh,claude</span>
</div>
</div>

<div class="footer">QuantMechanica V5 · strategy_farm cockpit · rendered {now_local} · re-render 2 min · browser refresh 30 s</div>

</body></html>
"""
    COCKPIT.write_text(html_doc, encoding="utf-8")
    print(f"cockpit written: {COCKPIT}")
    print(f"open in browser: file:///{COCKPIT.as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
