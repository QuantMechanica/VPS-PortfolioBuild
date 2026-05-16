"""QM strategy_farm cockpit — visual "what's happening NOW" dashboard.

Renders D:/QM/strategy_farm/dashboards/cockpit.html every 2 min.
Layout designed for OWNER's three primary questions:
  1. What is Claude doing?
  2. What is Codex doing?
  3. What's in the backtest queue?

Visual hierarchy:
  HERO   — three live-worker panels (Claude / Codex / MT5) with current task names
  FLOW   — horizontal pipeline showing EAs on each stage
  QUEUES — clear backlog cards per work type
  DETAIL — collapsible raw tables (Work Items / Wakes / Commits)

QM brand tokens from branding/brand_tokens.json.
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

PIPELINE_STAGES = ["Card", "Build", "Review", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "Live"]


# === Data collection ===

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


def proc_with_age() -> dict[str, list[dict]]:
    """Returns {name: [{Id, Age (sec)}, ...]} for each process name."""
    names = ("terminal64", "codex", "node", "python", "pwsh", "claude")
    out: dict[str, list[dict]] = {n: [] for n in names}
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-Process | Where-Object {$_.Name -match 'terminal64|codex|node|python|pwsh|claude'} | "
             "Select-Object Id, Name, @{N='AgeSec';E={[int]((Get-Date) - $_.StartTime).TotalSeconds}} | "
             "ConvertTo-Json -Compress"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout)
            if isinstance(data, dict):
                data = [data]
            for entry in data:
                n = (entry.get("Name") or "").lower()
                if n in out:
                    out[n].append({"id": entry.get("Id"), "age": entry.get("AgeSec") or 0})
    except Exception:
        pass
    return out


def fresh_log_files(pattern: str, max_age_sec: int = 600) -> list[dict]:
    """Live logs modified within max_age_sec, ordered by recency."""
    now = dt.datetime.now().timestamp()
    out = []
    for log in LOG_DIR.glob(pattern):
        try:
            mtime = log.stat().st_mtime
            age = now - mtime
            if age <= max_age_sec:
                out.append({
                    "path": log,
                    "name": log.stem,
                    "age": int(age),
                    "size_kb": log.stat().st_size // 1024,
                })
        except OSError:
            pass
    out.sort(key=lambda x: x["age"])
    return out


def last_lines(p: Path, n: int = 5) -> list[str]:
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        return lines[-n:]
    except Exception:
        return []


def codex_active_tasks() -> list[dict]:
    """Active codex builds: live log fresh + task_id mappable to EA."""
    logs = fresh_log_files("codex_build_*.live.log", max_age_sec=300)
    out = []
    if not logs:
        return out
    # Pull task → ea_id mapping
    rows = db_rows("SELECT id, payload_json FROM tasks WHERE kind='build_ea'")
    task_to_ea = {}
    for r in rows:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        task_to_ea[r["id"]] = (p.get("ea_id"), p.get("slug"))
    for log in logs[:5]:
        # log name = codex_build_<task_id>.live
        m = re.match(r"codex_build_(.+)\.live$", log["name"])
        if not m:
            continue
        tid = m.group(1)
        ea_id, slug = task_to_ea.get(tid, (None, None))
        out.append({
            "task_id": tid,
            "ea_id": ea_id or "?",
            "slug": slug or "",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    return out


def claude_active_tasks() -> list[dict]:
    """Active claude sessions: research / review live logs fresh."""
    out = []
    research_logs = fresh_log_files("claude_research_*.live.log", max_age_sec=600)
    review_logs = fresh_log_files("claude_review_*.live.log", max_age_sec=600)
    autowake_logs = fresh_log_files("autonomous_wake_*.log", max_age_sec=600)
    observe_logs = fresh_log_files("observe_wake_*.log", max_age_sec=600)
    for log in research_logs[:3]:
        m = re.match(r"claude_research_(.+)\.live$", log["name"])
        sid = m.group(1) if m else "?"
        out.append({
            "kind": "research",
            "subject": f"source {sid[:8]}",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in review_logs[:3]:
        m = re.match(r"claude_review_(.+)\.live$", log["name"])
        rid = m.group(1) if m else "?"
        # Try map review_task_id → ea_id
        rows = db_rows("SELECT payload_json FROM tasks WHERE id=?", (rid,))
        ea = "?"
        if rows:
            p = json.loads(rows[0]["payload_json"]) if rows[0]["payload_json"] else {}
            ea = p.get("ea_id") or "?"
        out.append({
            "kind": "review",
            "subject": f"{ea}",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in autowake_logs[:2]:
        out.append({
            "kind": "autonomous_wake",
            "subject": "decision tree",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in observe_logs[:1]:
        out.append({
            "kind": "observe_wake",
            "subject": "board-advisor",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    return out


def mt5_active_work() -> list[dict]:
    """Per-MT5-terminal current work (from work_items active)."""
    rows = db_rows(
        "SELECT ea_id, phase, symbol, claimed_by, payload_json, updated_at "
        "FROM work_items WHERE status='active' ORDER BY updated_at"
    )
    out = []
    for r in rows:
        out.append({
            "ea_id": r["ea_id"],
            "phase": r["phase"],
            "symbol": r["symbol"],
            "terminal": r.get("claimed_by") or "?",
            "since": (r.get("updated_at") or "")[:19],
        })
    return out


def queue_snapshot() -> dict:
    """All FIFO queues + counts."""
    out = {}
    tc = db_rows("SELECT kind, status, COUNT(*) AS c FROM tasks GROUP BY kind, status")
    bd = {f"{r['kind']}_{r['status']}": r["c"] for r in tc}
    out["builds_pending"] = bd.get("build_ea_pending", 0)
    out["builds_active"] = bd.get("build_ea_active", 0)
    out["builds_blocked"] = bd.get("build_ea_blocked", 0)
    out["reviews_pending"] = bd.get("ea_review_pending", 0)
    out["reviews_done"] = bd.get("ea_review_done", 0)
    out["backtest_p2_pending"] = bd.get("backtest_p2_pending", 0)
    out["backtest_p2_active"] = bd.get("backtest_p2_active", 0)
    out["backtest_p2_done"] = bd.get("backtest_p2_done", 0)
    out["backtest_p3_pending"] = bd.get("backtest_p3_pending", 0)
    out["backtest_p3_active"] = bd.get("backtest_p3_active", 0)
    out["backtest_p3_done"] = bd.get("backtest_p3_done", 0)

    # Work items per status
    wi = db_rows("SELECT phase, status, verdict, COUNT(*) AS c FROM work_items "
                 "GROUP BY phase, status, verdict")
    out["work_items"] = wi

    # Card backlog
    out["cards_draft"] = len(list_files(CARDS_DRAFT))
    out["cards_approved"] = len(list_files(CARDS_APPROVED))

    # Pending builds detail (FIFO)
    pending = db_rows(
        "SELECT payload_json, updated_at FROM tasks "
        "WHERE kind='build_ea' AND status='pending' ORDER BY updated_at ASC LIMIT 10"
    )
    pending_list = []
    for r in pending:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        pending_list.append({
            "ea_id": p.get("ea_id") or "?",
            "slug": p.get("slug") or "",
            "since": (r.get("updated_at") or "")[:19],
        })
    out["pending_builds_list"] = pending_list

    # Pending backtests detail
    pending_bt = db_rows(
        "SELECT kind, payload_json, updated_at FROM tasks "
        "WHERE kind LIKE 'backtest_%' AND status='pending' ORDER BY updated_at ASC LIMIT 10"
    )
    pending_bt_list = []
    for r in pending_bt:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        phase = (p.get("phase") or r["kind"].replace("backtest_", "").upper())
        pending_bt_list.append({
            "ea_id": p.get("ea_id") or "?",
            "phase": phase,
            "since": (r.get("updated_at") or "")[:19],
        })
    out["pending_backtests_list"] = pending_bt_list

    return out


def compute_pipeline() -> list[dict]:
    rows = db_rows(
        "SELECT id, kind, status, payload_json, updated_at "
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
            "stage": "Card",
            "stage_status": "pending",
            "last_activity": r["updated_at"],
        })
        if not entry["slug"] and payload.get("slug"):
            entry["slug"] = payload["slug"]
        if r["updated_at"] > entry["last_activity"]:
            entry["last_activity"] = r["updated_at"]
        kind = r["kind"]
        st = r["status"]
        if kind == "build_ea":
            entry["stage"] = "Build"
            if st == "pending":
                entry["stage_status"] = "pending"
            elif st == "active":
                entry["stage_status"] = "active"
            elif st == "done":
                entry["stage_status"] = "done"
                entry["stage"] = "Review"
                entry["stage_status"] = "pending"  # awaiting review
            elif st in ("blocked", "failed"):
                entry["stage_status"] = "failed"
        elif kind == "ea_review":
            verdict = (payload.get("verdict") or {}).get("verdict", "")
            entry["stage"] = "Review"
            if st == "done":
                if verdict == "APPROVE_FOR_BACKTEST":
                    entry["stage_status"] = "done"
                    entry["stage"] = "P2"
                    entry["stage_status"] = "pending"
                else:
                    entry["stage_status"] = "failed"
            else:
                entry["stage_status"] = "active"
        elif kind.startswith("backtest_"):
            phase = (payload.get("phase") or kind.replace("backtest_", "").upper())
            classification = payload.get("classification") or {}
            v = classification.get("verdict", "")
            entry["stage"] = phase
            if st == "pending":
                entry["stage_status"] = "pending"
            elif st == "active":
                entry["stage_status"] = "active"
            elif st == "done":
                if v == "PASS":
                    entry["stage_status"] = "done"
                else:
                    entry["stage_status"] = "failed"
    return sorted(eas.values(), key=lambda e: e["ea_id"])


def diagnose_bottleneck(procs: dict, q: dict, claude_workers: list, codex_workers: list) -> tuple[str, str]:
    if q["builds_pending"] > 3 and len(codex_workers) < 3:
        return "warn", (f"{q['builds_pending']} builds queued, only {len(codex_workers)} codex running. "
                        "Next pump (≤5 min) fills the budget to 3.")
    if q["builds_pending"] > 0 and len(codex_workers) == 0:
        return "block", f"{q['builds_pending']} builds pending and NO codex running — pump stalled?"
    awaiting_review = sum(1 for r in db_rows(
        "SELECT b.id FROM tasks b WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%')"
    ))
    if awaiting_review > 0 and not any(c["kind"] == "review" for c in claude_workers):
        return "warn", f"{awaiting_review} EA(s) built and awaiting Claude review. Next pump spawns review."
    if q["backtest_p2_pending"] > 0 and procs["terminal64"][0]["age"] < 60 if procs.get("terminal64") else procs.get("terminal64", []):
        # MT5 just started — wait
        return "ok", "MT5 backtest running."
    if q["backtest_p2_pending"] == 0 and q["backtest_p2_active"] == 0 and q["builds_pending"] == 0:
        if q["cards_approved"] == 0 and q["cards_draft"] == 0:
            return "warn", "Pipeline idle — no approved/drafted cards. Research is the input bottleneck."
        return "ok", "Pipeline idle between cycles. Next pump ≤5 min."
    return "ok", "Pipeline flowing."


def main() -> int:
    DASH.mkdir(parents=True, exist_ok=True)

    procs = proc_with_age()
    codex_workers = codex_active_tasks()
    claude_workers = claude_active_tasks()
    mt5_work = mt5_active_work()
    q = queue_snapshot()
    pipeline = compute_pipeline()

    severity, msg = diagnose_bottleneck(procs, q, claude_workers, codex_workers)

    # === HTML ===
    now_local = dt.datetime.now().strftime("%H:%M:%S")
    now_full = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    sev_color = {"ok": "#10b981", "warn": "#f59e0b", "block": "#ef4444"}[severity]
    sev_label = {"ok": "OK", "warn": "WARN", "block": "BLOCK"}[severity]

    def stage_color(stage_status: str) -> str:
        if stage_status == "done":
            return "#10b981"
        if stage_status == "failed":
            return "#ef4444"
        if stage_status == "active":
            return "#06b6d4"
        if stage_status == "pending":
            return "#f59e0b"
        return "#6b7280"

    def fmt_age(sec: int) -> str:
        if sec < 60:
            return f"{sec}s"
        if sec < 3600:
            return f"{sec // 60}m {sec % 60}s"
        return f"{sec // 3600}h {(sec % 3600) // 60}m"

    # --- Hero: 3 worker panels ---
    def worker_card(title: str, count: int, color: str, workers: list, what_key: str, sub_key: str = None) -> str:
        if count == 0:
            body = '<div class="worker-empty">no active work</div>'
        else:
            items = []
            for w in workers:
                subject = html.escape(str(w.get(what_key, "?")))
                sub = ""
                if sub_key and w.get(sub_key):
                    sub = f' <span class="muted">{html.escape(str(w[sub_key]))}</span>'
                age = fmt_age(w.get("age", 0))
                size = w.get("size_kb", 0)
                tail_html = ""
                if w.get("tail"):
                    tail_html = '<div class="tail">' + "".join(
                        f'<div>{html.escape(line[:160])}</div>' for line in w["tail"]
                    ) + '</div>'
                items.append(
                    f'<div class="worker-item">'
                    f'<div class="worker-row"><span class="worker-subject mono">{subject}</span>{sub}'
                    f'<span class="worker-meta mono">{age} · {size}K</span></div>'
                    f'{tail_html}</div>'
                )
            body = "\n".join(items)
        return f'''
        <div class="hero-card" style="border-color:{color}">
          <div class="hero-head">
            <span class="hero-title">{title}</span>
            <span class="hero-count mono" style="color:{color}">{count}</span>
          </div>
          <div class="hero-body">{body}</div>
        </div>'''

    claude_count = len(claude_workers)
    codex_count = len(codex_workers)
    mt5_count = len(mt5_work)

    hero_claude = worker_card("Claude", claude_count, "#34d399",
                              [{"subject": w["subject"], "kind": w["kind"],
                                "age": w["age"], "size_kb": w["size_kb"], "tail": w["tail"]}
                               for w in claude_workers],
                              "subject", "kind")
    hero_codex = worker_card("Codex", codex_count, "#10b981",
                             [{"subject": w["ea_id"], "kind": w["slug"][:24],
                               "age": w["age"], "size_kb": w["size_kb"], "tail": w["tail"]}
                              for w in codex_workers],
                             "subject", "kind")
    def _mt5_age(since: str) -> int:
        if not since:
            return 0
        try:
            s = since.rstrip("Z")[:19]
            dtv = dt.datetime.fromisoformat(s)
            return int((dt.datetime.utcnow() - dtv).total_seconds())
        except Exception:
            return 0

    hero_mt5 = worker_card("MT5", mt5_count, "#06b6d4",
                           [{"subject": f"{w['ea_id']} {w['phase']} · {w['symbol']}",
                             "kind": w["terminal"],
                             "age": _mt5_age(w.get("since", "")),
                             "size_kb": 0, "tail": []}
                            for w in mt5_work],
                           "subject", "kind")

    # --- Pipeline flow visual ---
    # Group EAs by current stage. Show as columns on a horizontal flow.
    stage_buckets: dict[str, list[dict]] = {s: [] for s in PIPELINE_STAGES}
    for e in pipeline:
        st = e["stage"]
        if st in stage_buckets:
            stage_buckets[st].append(e)
        else:
            # Unknown stage (e.g. P3.5) — bucket into Card
            stage_buckets["Card"].append(e)

    flow_cols = []
    for stage in PIPELINE_STAGES:
        bucket = stage_buckets[stage]
        if not bucket and stage in ("P4", "P5", "P6", "P7", "P8", "Live"):
            # Empty future stages — show as faded placeholders
            flow_cols.append(
                f'<div class="flow-col empty"><div class="flow-stage subtle">{stage}</div>'
                f'<div class="flow-count subtle">·</div></div>'
            )
            continue
        chips = []
        for e in bucket:
            col = stage_color(e["stage_status"])
            chips.append(
                f'<div class="ea-chip" style="border-color:{col};color:{col}" '
                f'title="{html.escape(e["ea_id"])} {html.escape(e["slug"])} · {e["stage_status"]}">'
                f'<span class="mono">{html.escape(e["ea_id"][-4:])}</span></div>'
            )
        flow_cols.append(
            f'<div class="flow-col"><div class="flow-stage">{stage}</div>'
            f'<div class="flow-count mono">{len(bucket)}</div>'
            f'<div class="flow-chips">{"".join(chips)}</div></div>'
        )
    flow_html = '<div class="flow-row">' + "".join(flow_cols) + '</div>'

    # --- Queue panels ---
    def queue_card(title: str, count: int, accent: str, items: list[str]) -> str:
        if count == 0:
            body = '<div class="q-empty">empty</div>'
        else:
            body = '<div class="q-list">' + "".join(items) + '</div>'
        return f'''
        <div class="q-card">
          <div class="q-head"><span class="q-title">{title}</span>
            <span class="q-count mono" style="color:{accent}">{count}</span></div>
          {body}
        </div>'''

    build_q_items = [
        f'<div class="q-item"><span class="mono">{html.escape(p["ea_id"])}</span> '
        f'<span class="muted">{html.escape(p["slug"][:24])}</span></div>'
        for p in q["pending_builds_list"]
    ]
    review_q_count = sum(1 for r in db_rows(
        "SELECT b.id FROM tasks b WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%')"
    ))
    review_q_eas = db_rows(
        "SELECT payload_json FROM tasks b WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%')"
    )
    review_q_items = [
        f'<div class="q-item"><span class="mono">{html.escape(json.loads(r["payload_json"]).get("ea_id","?"))}</span></div>'
        for r in review_q_eas[:8]
    ]
    bt_q_items = [
        f'<div class="q-item"><span class="mono">{html.escape(p["ea_id"])}</span> '
        f'<span class="muted">→ {html.escape(p["phase"])}</span></div>'
        for p in q["pending_backtests_list"]
    ]

    queue_html = f'''
    <div class="queue-row">
      {queue_card("Codex queue", q["builds_pending"], "#f59e0b", build_q_items)}
      {queue_card("Review queue", review_q_count, "#f59e0b", review_q_items)}
      {queue_card("Backtest queue", len(q["pending_backtests_list"]), "#f59e0b", bt_q_items)}
      {queue_card("Cards approved", q["cards_approved"], "#34d399",
                  [f'<div class="q-item muted">unbuild: {q["cards_approved"] - codex_count - q["builds_pending"]}</div>'])}
    </div>'''

    # --- Pipeline EA table (full list) ---
    pipeline_rows = "\n".join(
        f'<tr><td class="mono"><b>{html.escape(e["ea_id"])}</b></td>'
        f'<td>{html.escape(e["slug"][:36])}</td>'
        f'<td class="mono">{html.escape(e["stage"])}</td>'
        f'<td style="color:{stage_color(e["stage_status"])}"><b>{html.escape(e["stage_status"])}</b></td>'
        f'<td class="mono muted">{html.escape(e["last_activity"][:19])}</td></tr>'
        for e in pipeline
    )

    # --- Wakes (last 8 lines) ---
    wakes = []
    if WAKES_LOG.exists():
        wakes = WAKES_LOG.read_text(encoding="utf-8", errors="ignore").splitlines()[-8:]
    wakes_html = "\n".join(f'<div class="log">{html.escape(line[:300])}</div>' for line in wakes)

    # --- Commits ---
    try:
        out = subprocess.run(
            ["git", "log", "--oneline", "-n", "8", "agents/board-advisor", "--format=%h|%cr|%s"],
            cwd=str(REPO), capture_output=True, text=True, timeout=10,
        )
        commit_rows = []
        for line in (out.stdout or "").splitlines():
            parts = line.split("|", 2)
            if len(parts) == 3:
                commit_rows.append(
                    f'<tr><td class="mono">{html.escape(parts[0])}</td>'
                    f'<td class="mono muted">{html.escape(parts[1])}</td>'
                    f'<td>{html.escape(parts[2][:80])}</td></tr>'
                )
        commits_html = "\n".join(commit_rows)
    except Exception:
        commits_html = ""

    # === Final HTML ===
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
  --qm-text: #f8fafc;
  --qm-text-dim: #cbd5e1;
  --qm-text-muted: #94a3b8;
  --qm-text-subtle: #64748b;
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
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'Source Code Pro', 'SF Mono', Consolas, monospace;
}}
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; padding: 0; }}
body {{
  font-family: var(--font-sans);
  background: var(--qm-bg);
  color: var(--qm-text);
  padding: 20px 28px;
  font-feature-settings: 'tnum' on, 'lnum' on;
  line-height: 1.5;
}}

/* ===== TOP BAR ===== */
.top {{
  display: flex; align-items: center; gap: 16px;
  padding-bottom: 14px; margin-bottom: 18px;
  border-bottom: 1px solid var(--qm-border);
}}
.brand {{ font-size: 16px; font-weight: 600; letter-spacing: -0.01em; }}
.brand .accent {{ color: var(--em); }}
.timestamp {{ font-family: var(--font-mono); font-size: 11px; color: var(--qm-text-muted); }}
.sev-tag {{
  margin-left: auto;
  font-family: var(--font-mono); font-size: 10px; font-weight: 600;
  letter-spacing: 0.08em; padding: 4px 10px; border-radius: 4px;
  background: {sev_color}; color: var(--qm-bg);
  box-shadow: 0 0 12px {sev_color}44;
}}
.sev-msg {{ font-size: 12px; color: var(--qm-text-dim); flex: 0 1 auto; }}

/* ===== HERO ROW ===== */
.hero {{ display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 14px; margin-bottom: 22px; }}
.hero-card {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border-strong);
  border-radius: 10px;
  padding: 14px 16px;
  min-height: 200px;
}}
.hero-head {{ display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 12px; }}
.hero-title {{
  text-transform: uppercase; letter-spacing: 0.1em;
  font-size: 10px; font-weight: 600; color: var(--qm-text-muted);
}}
.hero-count {{
  font-size: 28px; font-weight: 600; line-height: 1; letter-spacing: -0.01em;
}}
.hero-body {{ font-size: 12px; }}
.worker-item {{
  padding: 8px 0;
  border-top: 1px solid var(--qm-border);
}}
.worker-item:first-child {{ border-top: none; padding-top: 0; }}
.worker-row {{ display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }}
.worker-subject {{ font-weight: 600; color: var(--qm-text); font-size: 12px; }}
.worker-meta {{ margin-left: auto; color: var(--qm-text-subtle); font-size: 10px; }}
.tail {{
  background: var(--qm-surface-0); border-radius: 4px;
  padding: 6px 8px; font-family: var(--font-mono); font-size: 10px;
  color: var(--qm-text-muted); white-space: nowrap; overflow-x: auto;
}}
.tail div {{ overflow: hidden; text-overflow: ellipsis; }}
.worker-empty {{
  color: var(--qm-text-subtle); font-size: 11px; padding: 24px 0;
  text-align: center; font-style: italic;
}}

/* ===== PIPELINE FLOW ===== */
.section-title {{
  text-transform: uppercase; letter-spacing: 0.1em;
  font-size: 10px; font-weight: 600; color: var(--qm-text-muted);
  margin: 24px 0 10px 0;
}}
.flow-row {{
  display: grid; grid-template-columns: repeat({len(PIPELINE_STAGES)}, 1fr);
  gap: 6px; background: var(--qm-surface-1);
  border: 1px solid var(--qm-border); border-radius: 8px;
  padding: 12px 10px;
}}
.flow-col {{
  text-align: center; padding: 4px 2px;
  border-right: 1px solid var(--qm-border);
}}
.flow-col:last-child {{ border-right: none; }}
.flow-col.empty {{ opacity: 0.45; }}
.flow-stage {{
  font-size: 10px; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.08em; color: var(--qm-text-muted); margin-bottom: 4px;
}}
.flow-count {{
  font-family: var(--font-mono); font-size: 18px; font-weight: 600;
  color: var(--qm-text); margin-bottom: 8px;
}}
.flow-chips {{ display: flex; flex-wrap: wrap; gap: 3px; justify-content: center; min-height: 28px; }}
.ea-chip {{
  font-family: var(--font-mono); font-size: 10px;
  padding: 2px 6px; border: 1px solid; border-radius: 3px;
  background: var(--qm-surface-0);
}}

/* ===== QUEUES ===== */
.queue-row {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }}
.q-card {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
  border-radius: 8px;
  padding: 12px 14px;
}}
.q-head {{ display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 8px; }}
.q-title {{
  text-transform: uppercase; letter-spacing: 0.08em;
  font-size: 10px; font-weight: 600; color: var(--qm-text-muted);
}}
.q-count {{ font-size: 24px; font-weight: 600; line-height: 1; }}
.q-list {{ display: flex; flex-direction: column; gap: 4px; }}
.q-item {{ font-size: 11px; padding: 3px 0; border-bottom: 1px solid var(--qm-border); }}
.q-item:last-child {{ border-bottom: none; }}
.q-empty {{ font-style: italic; font-size: 11px; color: var(--qm-text-subtle); padding: 8px 0; }}

/* ===== DETAIL ===== */
.detail-row {{ display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 14px; margin-top: 22px; }}
.detail-card {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
  border-radius: 8px;
  padding: 12px 14px;
}}
table {{ border-collapse: collapse; width: 100%; font-size: 11px; }}
th {{
  color: var(--qm-text-muted); text-align: left;
  padding: 4px 8px 6px 0; font-weight: 500; font-size: 9px;
  text-transform: uppercase; letter-spacing: 0.08em;
  border-bottom: 1px solid var(--qm-border-strong);
}}
td {{ padding: 4px 8px 4px 0; border-bottom: 1px solid var(--qm-border); color: var(--qm-text-dim); }}
tr:last-child td {{ border-bottom: none; }}

.mono {{ font-family: var(--font-mono); font-variant-numeric: tabular-nums; }}
.muted {{ color: var(--qm-text-muted); }}
.subtle {{ color: var(--qm-text-subtle); }}

.log {{
  font-family: var(--font-mono); font-size: 10px;
  padding: 3px 8px; border-left: 2px solid var(--em-d);
  background: var(--qm-surface-0); color: var(--qm-text-dim);
  overflow-x: auto; white-space: nowrap;
  margin-bottom: 2px;
}}

.footer {{
  margin-top: 28px; padding-top: 12px;
  border-top: 1px solid var(--qm-border); text-align: center;
  font-size: 10px; color: var(--qm-text-subtle);
  font-family: var(--font-mono); letter-spacing: 0.04em;
}}
</style></head>
<body>

<div class="top">
  <div class="brand">Quant<span class="accent">Mechanica</span></div>
  <div class="timestamp">{now_full}</div>
  <span class="sev-msg">{html.escape(msg)}</span>
  <span class="sev-tag">{sev_label}</span>
</div>

<div class="hero">
  {hero_claude}
  {hero_codex}
  {hero_mt5}
</div>

<div class="section-title">Pipeline flow</div>
{flow_html}

<div class="section-title">Queues</div>
{queue_html}

<div class="detail-row">

  <div class="detail-card">
    <div class="section-title" style="margin-top:0">EA states · all</div>
    <table>
      <tr><th>EA</th><th>Slug</th><th>Stage</th><th>Status</th><th>Updated</th></tr>
      {pipeline_rows}
    </table>
  </div>

  <div class="detail-card">
    <div class="section-title" style="margin-top:0">Wakes</div>
    {wakes_html}
  </div>

  <div class="detail-card">
    <div class="section-title" style="margin-top:0">Recent commits</div>
    <table>
      <tr><th>SHA</th><th>Age</th><th>Subject</th></tr>
      {commits_html}
    </table>
  </div>

</div>

<div class="footer">QuantMechanica V5 · strategy_farm cockpit · {now_local} · re-render 2 min · browser refresh 30 s</div>

</body></html>
"""
    COCKPIT.write_text(html_doc, encoding="utf-8")
    print(f"cockpit written: {COCKPIT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
