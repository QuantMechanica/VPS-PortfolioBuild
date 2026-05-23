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
CARDS_DRAFT = ROOT / "artifacts" / "cards_draft"
CARDS_APPROVED = ROOT / "artifacts" / "cards_approved"
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"

PIPELINE_STAGES = ["Card", "Build", "Review", "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10", "Q11", "Live"]
PHASE_DISPLAY = {
    "P2": "Q02",
    "P3": "Q03",
    "P3.5": "Q04",
    "P4": "Q05",
    "P5": "Q06",
    "P5b": "Q07",
    "P5c": "Q08",
    "P6": "Q09",
    "P7": "Q10",
    "P8": "Q11",
}
PHASE_RANK = {
    "P2": 20,
    "P3": 30,
    "P3.5": 35,
    "P4": 40,
    "P5": 50,
    "P5b": 55,
    "P5c": 56,
    "P6": 60,
    "P7": 70,
    "P8": 80,
}
PHASE_TO_STAGE = {
    "P2": "Q02",
    "P3": "Q03",
    "P3.5": "Q04",
    "P4": "Q05",
    "P5": "Q06",
    "P5b": "Q07",
    "P5c": "Q08",
    "P6": "Q09",
    "P7": "Q10",
    "P8": "Q11",
}


def qid(phase: str | None) -> str:
    """Canonical Qxx display id for a legacy phase key (vault naming — Qxx only)."""
    p = str(phase or "")
    return PHASE_DISPLAY.get(p, p or "—")


def e(s) -> str:
    """HTML-escape with str() coercion; None -> "". Matches dashboards/render_dashboards.py:e()."""
    return html.escape(str(s)) if s is not None else ""


def _parse_codex_text(text: str) -> dict:
    """Extract usage from chatgpt.com codex analytics page text.

    DOM is German (e.g. '5 Stunden Nutzungsgrenze 96 % verbleibend
    Zuruecksetzungen 17.05.2026 2:23'). Codex reports REMAINING %, not used.
    We invert to %used so cockpit traffic-lighting stays consistent.
    """
    out = {}
    # 5h: tolerate both German ('5 Stunden') and English ('5-hour' / '5 hour')
    m = re.search(
        r"(?:5\s*Stunden|5[-\s]?hour|hourly)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verbleibend|remaining)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_pct"] = 100.0 - float(m.group(1))
    else:
        m = re.search(
            r"(?:5\s*Stunden|5[-\s]?hour|hourly)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
            text, re.IGNORECASE,
        )
        if m:
            out["hour_pct"] = float(m.group(1))
    # Weekly
    m = re.search(
        r"(?:W(?:o|ö)chentlich|weekly|week)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verbleibend|remaining)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_pct"] = 100.0 - float(m.group(1))
    else:
        m = re.search(
            r"(?:W(?:o|ö)chentlich|weekly|week)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
            text, re.IGNORECASE,
        )
        if m:
            out["week_pct"] = float(m.group(1))
    # Reset timestamps (e.g. '17.05.2026 2:23')
    m = re.search(
        r"5\s*Stunden\s*Nutzungsgrenze\s*\d+\s*%\s*verbleibend\s*Zur(?:u|ü)cksetzungen?\s*([\d.]+\s*[\d:]+)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_reset"] = m.group(1).strip()
    m = re.search(
        r"W(?:o|ö)chentlich(?:e)?\s*Nutzungsgrenze\s*\d+\s*%\s*verbleibend\s*Zur(?:u|ü)cksetzungen?\s*([\d.]+\s*[\d:]+)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_reset"] = m.group(1).strip()
    return out


def _parse_claude_text(text: str) -> dict:
    """Extract usage from claude.ai/settings/usage page text.

    DOM is German (e.g. 'Aktuelle Sitzung Zuruecksetzung in 3 Std. 2 Min.
    12 % verwendet Woechentliche Limits ... Alle Modelle ... 16 % verwendet').
    Claude reports USED %, no inversion needed.
    """
    out = {}
    # Plan label
    m = re.search(r"Plan-?Nutzungslimits\s+(Max\s*\([\d]+x\)|Max|Pro|Team|Enterprise|Free)", text, re.IGNORECASE)
    if m:
        out["plan"] = m.group(1).strip()
    # 5-hour: "Aktuelle Sitzung ... XX % verwendet" (German) or "Current session ... XX % used"
    m = re.search(
        r"(?:Aktuelle\s+Sitzung|Current\s+session)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_pct"] = float(m.group(1))
    # Weekly all models: "Alle Modelle ... XX % verwendet"
    m = re.search(
        r"(?:Alle\s+Modelle|All\s+models)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_pct"] = float(m.group(1))
    # Sonnet-only weekly (informational)
    m = re.search(
        r"(?:Nur\s+Sonnet|Sonnet\s+only)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["sonnet_pct"] = float(m.group(1))
    # 5h reset (e.g. "Zuruecksetzung in 3 Std. 2 Min.")
    m = re.search(
        r"(?:Aktuelle\s+Sitzung|Current\s+session)\s*Zur(?:u|ü)cksetzung\s+in\s+([^.\n]+?)\s*(\d+\s*%|\.)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_reset"] = m.group(1).strip().rstrip(",")
    # Weekly reset (e.g. "Zuruecksetzung Fr., 00:00")
    m = re.search(
        r"(?:Alle\s+Modelle|All\s+models)\s*Zur(?:u|ü)cksetzung\s+([^\d]+\d{1,2}:\d{2})",
        text, re.IGNORECASE,
    )
    if m:
        out["week_reset"] = m.group(1).strip()
    return out


def quota_snapshot() -> dict:
    """Read Tampermonkey-scraped quota snapshot from D:/QM/.../quota_snapshot.json.

    Browser userscripts (tools/strategy_farm/userscripts/*.user.js) scrape the
    authenticated chatgpt.com + claude.ai usage pages every 60s and POST to the
    local receiver (tools/strategy_farm/quota_receiver.py @ 127.0.0.1:9090).
    The receiver merges per source.

    Parsing happens here (Python side) on the rendered DOM text, so we can
    fix patterns without users having to reinstall Tampermonkey scripts.

    Returns per-source dicts: {fresh, age_sec, hour_pct, week_pct, plan,
    hour_reset, week_reset, meters, matches, url}.
    """
    out: dict = {}
    try:
        if not QUOTA_SNAPSHOT.exists():
            return out
        snap = json.loads(QUOTA_SNAPSHOT.read_text(encoding="utf-8"))
    except Exception:
        return out
    now = dt.datetime.now(dt.timezone.utc)
    for src in ("codex", "claude"):
        s = snap.get(src) or {}
        if not s:
            continue
        received_at = s.get("received_at") or s.get("scraped_at")
        age_sec = None
        if received_at:
            try:
                t = dt.datetime.fromisoformat(received_at.replace("Z", "+00:00"))
                age_sec = int((now - t).total_seconds())
            except Exception:
                age_sec = None
        data = s.get("data") or {}
        matches = data.get("matches") or {}
        text = data.get("full_text_head") or ""
        parsed = _parse_codex_text(text) if src == "codex" else _parse_claude_text(text)
        out[src] = {
            "fresh": age_sec is not None and age_sec <= 300,
            "age_sec": age_sec,
            "hour_pct": parsed.get("hour_pct"),
            "week_pct": parsed.get("week_pct"),
            "hour_reset": parsed.get("hour_reset"),
            "week_reset": parsed.get("week_reset"),
            "sonnet_pct": parsed.get("sonnet_pct"),
            "plan": parsed.get("plan") or matches.get("plan_label"),
            "meters": data.get("meters") or [],
            "matches": matches,
            "url": data.get("url"),
        }
    return out


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
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
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


def live_worker_terminals() -> set[str]:
    """{T1, T3, ...} for terminal_worker.py daemons currently alive.

    Cockpit uses this to filter mt5_active_work() down to claims that
    actually have a living worker behind them - prevents stale-claim
    lies after Factory_OFF or unclean crashes (DB row still says
    status=active but the daemon was killed).
    """
    out: set[str] = set()
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe' OR Name='python.exe'\" | "
             "Where-Object {$_.CommandLine -match 'terminal_worker'} | "
             "Select-Object -ExpandProperty CommandLine"],
            capture_output=True, text=True, timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                m = re.search(r"--terminal\s+(T\d+)", line, re.IGNORECASE)
                if m:
                    out.add(m.group(1).upper())
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

    out["agent_router"] = agent_router_snapshot()
    return out


def agent_router_snapshot() -> dict:
    """Read-only view of the autonomous Claude/Gemini/Codex router."""
    empty = {
        "open_count": 0,
        "agents": [],
        "task_counts": [],
        "recent_tasks": [],
        "available": False,
    }
    try:
        agents = db_rows(
            "SELECT agent_id, enabled, max_parallel, capabilities_json "
            "FROM agent_registry ORDER BY agent_id"
        )
        task_counts = db_rows(
            """
            SELECT task_type, state, COALESCE(assigned_agent, '') AS assigned_agent, COUNT(*) AS c
            FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW', 'BLOCKED', 'OPS_FIX_REQUIRED')
            GROUP BY task_type, state, assigned_agent
            ORDER BY state, task_type, assigned_agent
            """
        )
        recent_rows = db_rows(
            """
            SELECT id, task_type, state, assigned_agent, artifact_path, verdict, payload_json, updated_at
            FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW', 'BLOCKED', 'OPS_FIX_REQUIRED')
            ORDER BY priority ASC, updated_at DESC
            LIMIT 8
            """
        )
    except sqlite3.Error:
        return empty

    now_utc = dt.datetime.now(dt.timezone.utc)

    def age_hours(value: str) -> float:
        if not value:
            return 0.0
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return max(0.0, (now_utc - parsed.astimezone(dt.timezone.utc)).total_seconds() / 3600)
        except ValueError:
            return 0.0

    sla_hours = {
        "TODO": 2,
        "BACKLOG": 4,
        "IN_PROGRESS": 4,
        "REVIEW": 12,
        "BLOCKED": 24,
        "OPS_FIX_REQUIRED": 12,
    }
    recent_tasks = []
    for row in recent_rows:
        try:
            payload = json.loads(row.get("payload_json") or "{}")
        except json.JSONDecodeError:
            payload = {}
        age_h = age_hours(row.get("updated_at") or "")
        limit_h = sla_hours.get(str(row.get("state") or ""), 24)
        recent_tasks.append({
            "id": str(row.get("id") or "")[:8],
            "type": row.get("task_type") or "?",
            "state": row.get("state") or "?",
            "agent": row.get("assigned_agent") or payload.get("target_agent_profile") or "?",
            "artifact": row.get("artifact_path") or payload.get("expected_artifact") or "",
            "verdict": row.get("verdict") or "",
            "age_h": round(age_h, 1),
            "sla": "late" if age_h > limit_h else "ok",
        })

    return {
        "open_count": sum(int(row.get("c") or 0) for row in task_counts),
        "agents": agents,
        "task_counts": task_counts,
        "recent_tasks": recent_tasks,
        "available": True,
    }


def pipeline_backlog_snapshot() -> dict:
    """Read-only backlog counters for the cockpit."""
    out = {
        "sources": {"pending": 0, "cards_ready": 0, "done": 0},
        "pass_by_phase": [],
        "pass_total": 0,
        "p4plus_pass_total": 0,
        "p8_pass_total": 0,
        "portfolio_candidates_total": 0,
        "p4_pending_implementation": 0,
        "work_active_by_phase": [],
        "work_active_total": 0,
        "top_sources": [],
        "estimated_todo": 0,
    }
    try:
        for r in db_rows("SELECT status, COUNT(*) AS c FROM sources GROUP BY status"):
            out["sources"][r["status"]] = r["c"]
        out["pass_by_phase"] = db_rows(
            """
            SELECT phase, COUNT(DISTINCT ea_id) AS c, COUNT(*) AS c_items
            FROM work_items
            WHERE verdict='PASS'
            GROUP BY phase
            ORDER BY CASE phase
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 35
              WHEN 'P4' THEN 40 WHEN 'P5' THEN 50 WHEN 'P5b' THEN 55
              WHEN 'P5c' THEN 56 WHEN 'P6' THEN 60 WHEN 'P7' THEN 70
              WHEN 'P8' THEN 80 ELSE 0 END
            """
        )
        pass_total = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS'"
        )
        out["pass_total"] = pass_total[0]["c"] if pass_total else 0
        p4plus = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items "
            "WHERE verdict='PASS' AND phase IN ('P4','P5','P5b','P5c','P6','P7','P8')"
        )
        out["p4plus_pass_total"] = p4plus[0]["c"] if p4plus else 0
        p8 = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS' AND phase='P8'"
        )
        out["p8_pass_total"] = p8[0]["c"] if p8 else 0
        try:
            pc = db_rows("SELECT COUNT(DISTINCT ea_id) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'")
            out["portfolio_candidates_total"] = pc[0]["c"] if pc else 0
        except sqlite3.Error:
            out["portfolio_candidates_total"] = 0
        p4_pending = db_rows(
            "SELECT COUNT(*) AS c FROM work_items WHERE phase='P4' AND verdict='PENDING_IMPLEMENTATION'"
        )
        out["p4_pending_implementation"] = p4_pending[0]["c"] if p4_pending else 0
        out["work_active_by_phase"] = db_rows(
            "SELECT phase, COUNT(*) AS c FROM work_items "
            """
            WHERE status IN ('active','pending','claimed') GROUP BY phase
            ORDER BY CASE phase
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 35
              WHEN 'P4' THEN 40 WHEN 'P5' THEN 50 WHEN 'P5b' THEN 55
              WHEN 'P5c' THEN 56 WHEN 'P6' THEN 60 WHEN 'P7' THEN 70
              WHEN 'P8' THEN 80 ELSE 0 END
            """
        )
        out["work_active_total"] = sum(r["c"] for r in out["work_active_by_phase"])
        out["top_sources"] = db_rows(
            "SELECT priority, title FROM sources "
            "WHERE status='pending' ORDER BY priority DESC LIMIT 5"
        )
        out["estimated_todo"] = out["sources"].get("pending", 0) * 3
    except Exception as exc:
        out["error"] = str(exc)
    return out


def compute_heureka_leader(pipeline: list[dict]) -> dict | None:
    """Pick the most-advanced still-alive EA as the Heureka leader.

    Rank by current_stage position in PIPELINE_STAGES, skipping failed/blocked.
    Returns dict with ea_id, slug, current_stage, completed_count, next_stage,
    pct (0-100), failed flag.
    """
    if not pipeline:
        return None
    stage_idx = {s: i for i, s in enumerate(PIPELINE_STAGES)}
    # Map current_stage prefix → which Stage it belongs to
    def stage_for(entry: dict) -> tuple[int, bool]:
        st = entry.get("stage") or "Card"
        if st in stage_idx:
            return stage_idx[st], entry.get("stage_status") == "failed"
        return 0, False
    alive = [e for e in pipeline if "failed" not in (e.get("stage_status") or "")
             and "blocked" not in (e.get("stage_status") or "")]
    if not alive:
        # fall back to anything
        candidates = pipeline
    else:
        candidates = alive
    leader = max(candidates, key=lambda e: stage_for(e)[0])
    cur_idx, failed = stage_for(leader)
    next_stage = PIPELINE_STAGES[cur_idx + 1] if cur_idx + 1 < len(PIPELINE_STAGES) else "live"
    pct = int(100 * cur_idx / max(1, len(PIPELINE_STAGES) - 1))
    return {
        "ea_id": leader["ea_id"],
        "slug": leader.get("slug", ""),
        "current_stage": leader.get("stage", "Card"),
        "current_stage_idx": cur_idx,
        "completed_count": cur_idx,
        "total_stages": len(PIPELINE_STAGES),
        "next_stage": next_stage,
        "pct": pct,
        "failed": failed,
        "stage_status": leader.get("stage_status", ""),
    }


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
                    entry["stage"] = "Q02"
                    entry["stage_status"] = "pending"
                else:
                    entry["stage_status"] = "failed"
            else:
                entry["stage_status"] = "active"
        elif kind.startswith("backtest_"):
            phase = (payload.get("phase") or kind.replace("backtest_", "").upper())
            classification = payload.get("classification") or {}
            v = classification.get("verdict", "")
            entry["stage"] = qid(phase)
            if st == "pending":
                entry["stage_status"] = "pending"
            elif st == "active":
                entry["stage_status"] = "active"
            elif st == "done":
                if v == "PASS":
                    entry["stage_status"] = "done"
                else:
                    entry["stage_status"] = "failed"
    # Overlay live work_item state. The task table is useful for build/review,
    # but cascade phases P3.5..P8 advance as work_items; without this overlay
    # the cockpit can under-report a P8 winner as still sitting at P2/Review.
    work_rows = db_rows(
        """
        SELECT ea_id, phase, status, verdict, updated_at
        FROM work_items
        WHERE ea_id IS NOT NULL
        """
    )
    for r in work_rows:
        ea_id = r.get("ea_id")
        phase = r.get("phase")
        if not ea_id or phase not in PHASE_RANK:
            continue
        entry = eas.setdefault(ea_id, {
            "ea_id": ea_id,
            "slug": "",
            "stage": "Card",
            "stage_status": "pending",
            "last_activity": r.get("updated_at") or "",
        })
        if (r.get("updated_at") or "") > (entry.get("last_activity") or ""):
            entry["last_activity"] = r.get("updated_at") or entry.get("last_activity") or ""

        current_phase = entry.get("_best_phase")
        current_rank = PHASE_RANK.get(current_phase or "", -1)
        row_rank = PHASE_RANK[phase]
        verdict = str(r.get("verdict") or "").upper()
        status = str(r.get("status") or "").lower()
        is_progress = status in {"pending", "active", "claimed"} or verdict == "PASS"
        if not is_progress:
            continue
        if row_rank >= current_rank:
            entry["_best_phase"] = phase
            entry["stage"] = PHASE_TO_STAGE.get(phase, phase)
            if verdict == "PASS":
                entry["stage_status"] = "done"
            elif status == "active":
                entry["stage_status"] = "active"
            elif status in {"pending", "claimed"}:
                entry["stage_status"] = "pending"

    for entry in eas.values():
        entry.pop("_best_phase", None)
    return sorted(eas.values(), key=lambda e: e["ea_id"])


def profitability_next_actions(pipeline: list[dict]) -> list[dict]:
    """Rank active EAs by progress and show the next deterministic action."""
    if not pipeline:
        return []
    stage_idx = {stage: idx for idx, stage in enumerate(PIPELINE_STAGES)}

    def next_action(entry: dict) -> str:
        stage = entry.get("stage") or "Card"
        status = entry.get("stage_status") or "pending"
        if status == "active":
            return f"Wait for active {stage} evidence"
        if status == "failed":
            return "Review failure; no promotion without new evidence"
        if stage == "Card":
            return "Build EA from approved card"
        if stage == "Build":
            return "Finish build and compile evidence"
        if stage == "Review":
            return "Complete EA review"
        idx = stage_idx.get(stage, 0)
        if idx + 1 < len(PIPELINE_STAGES):
            return f"Promote or enqueue {PIPELINE_STAGES[idx + 1]}"
        return "Manual live-readiness gate"

    ranked = sorted(
        pipeline,
        key=lambda e: (
            stage_idx.get(str(e.get("stage") or "Card"), 0),
            1 if e.get("stage_status") == "active" else 0,
            str(e.get("last_activity") or ""),
        ),
        reverse=True,
    )
    out = []
    for entry in ranked[:8]:
        out.append({
            "ea_id": entry.get("ea_id") or "?",
            "slug": entry.get("slug") or "",
            "stage": entry.get("stage") or "Card",
            "status": entry.get("stage_status") or "?",
            "updated": str(entry.get("last_activity") or "")[:19],
            "next_action": next_action(entry),
        })
    return out


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
    # Filter DB-claims down to those with a living worker (process exists).
    # Prevents lying when Factory_OFF + farmctl repair has not run: DB rows
    # may say status=active but the daemon was killed. OWNER call 2026-05-23.
    _live = live_worker_terminals()
    mt5_work = [w for w in mt5_work if str(w.get("terminal") or "").upper() in _live]
    q = queue_snapshot()
    pipeline = compute_pipeline()
    next_actions = profitability_next_actions(pipeline)
    backlog = pipeline_backlog_snapshot()
    heureka = compute_heureka_leader(pipeline)
    qsnap = quota_snapshot()

    # Pipeline health (written by `farmctl health`, scheduled every 15 min)
    health_file = ROOT / "state" / "health.json"
    health = {}
    try:
        if health_file.exists():
            health = json.loads(health_file.read_text(encoding="utf-8"))
    except Exception:
        health = {}

    # 7-day trend chart data — counts per day of key events
    def _trend_data() -> dict:
        try:
            con = sqlite3.connect(str(DB))
            con.row_factory = sqlite3.Row
            rows = list(con.execute("""
                SELECT DATE(ts) day, event, COUNT(*) c FROM events
                WHERE ts >= date('now', '-7 days')
                GROUP BY day, event
            """))
            con.close()
        except Exception:
            return {}
        days: dict[str, dict[str, int]] = {}
        for r in rows:
            days.setdefault(r["day"], {})[r["event"]] = r["c"]
        # P2-PASS counts per day from work_items (more reliable signal)
        try:
            con = sqlite3.connect(str(DB))
            con.row_factory = sqlite3.Row
            for r in con.execute("""
                SELECT DATE(updated_at) day, COUNT(*) c FROM work_items
                WHERE phase='P2' AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_p2_pass"] = r["c"]
            for r in con.execute("""
                SELECT DATE(updated_at) day, COUNT(*) c FROM work_items
                WHERE phase='P3' AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_p3_pass"] = r["c"]
            con.close()
        except Exception:
            pass
        return days
    trend = _trend_data()

    def _daily_controlling_data() -> dict:
        mt5_phases = {"P2", "P3", "P4", "P5", "P5b", "P5c", "P6", "P8"}
        analysis_phases = {"P3.5", "P7"}
        rows = db_rows(
            """
            SELECT phase, status, verdict, ea_id, symbol, payload_json, updated_at
            FROM work_items
            WHERE updated_at >= date('now', '-30 days')
            """
        )
        windows = {
            "today": 0,
            "yesterday": 1,
            "7d": 7,
            "30d": 30,
        }
        today = dt.date.today()
        stats = {
            key: {
                "mt5_items": 0,
                "mt5_eas": set(),
                "analysis_items": 0,
                "analysis_eas": set(),
                "done_items": 0,
                "fail_invalid": 0,
            }
            for key in windows
        }
        by_phase: dict[str, dict[str, int]] = {}
        by_terminal: dict[str, int] = {}
        anomalies = {"zero_trade_like": 0, "invalid": 0, "waiting_input": 0}

        def in_window(day: dt.date, key: str, days: int) -> bool:
            delta = (today - day).days
            if key == "today":
                return delta == 0
            if key == "yesterday":
                return delta == 1
            return 0 <= delta < days

        for row in rows:
            updated = str(row.get("updated_at") or "")[:10]
            try:
                day = dt.date.fromisoformat(updated)
            except Exception:
                continue
            phase = str(row.get("phase") or "")
            status = str(row.get("status") or "")
            verdict = str(row.get("verdict") or "")
            payload = {}
            if row.get("payload_json"):
                try:
                    payload = json.loads(row["payload_json"])
                except Exception:
                    payload = {}
            is_mt5 = phase in mt5_phases
            is_analysis = phase in analysis_phases
            for key, days in windows.items():
                if not in_window(day, key, days):
                    continue
                bucket = stats[key]
                if is_mt5:
                    bucket["mt5_items"] += 1
                    if row.get("ea_id"):
                        bucket["mt5_eas"].add(row["ea_id"])
                elif is_analysis:
                    bucket["analysis_items"] += 1
                    if row.get("ea_id"):
                        bucket["analysis_eas"].add(row["ea_id"])
                if status in {"done", "failed"}:
                    bucket["done_items"] += 1
                if verdict in {"FAIL", "INVALID"}:
                    bucket["fail_invalid"] += 1
            if status in {"done", "failed"}:
                key = f"{PHASE_DISPLAY.get(phase, phase)} {verdict or status}"
                by_phase[key] = by_phase.get(key, {"count": 0})
                by_phase[key]["count"] += 1
            terminal = payload.get("terminal") or row.get("claimed_by")
            if terminal and is_mt5:
                by_terminal[str(terminal)] = by_terminal.get(str(terminal), 0) + 1
            reason = str(payload.get("verdict_reason") or "")
            if "MIN_TRADES_NOT_MET" in reason or "zero" in reason.lower():
                anomalies["zero_trade_like"] += 1
            if verdict == "INVALID":
                anomalies["invalid"] += 1
            if verdict == "WAITING_INPUT":
                anomalies["waiting_input"] += 1

        for bucket in stats.values():
            bucket["mt5_eas"] = len(bucket["mt5_eas"])
            bucket["analysis_eas"] = len(bucket["analysis_eas"])
        return {
            "windows": stats,
            "by_phase": sorted(
                [{"label": k, "count": v["count"]} for k, v in by_phase.items()],
                key=lambda r: r["count"],
                reverse=True,
            )[:12],
            "by_terminal": sorted(
                [{"terminal": k, "count": v} for k, v in by_terminal.items()],
                key=lambda r: r["terminal"],
            ),
            "anomalies": anomalies,
        }

    controlling = _daily_controlling_data()

    severity, msg = diagnose_bottleneck(procs, q, claude_workers, codex_workers)

    # === HTML — STEEL / EMERALD ===
    now_utc_full = dt.datetime.now(dt.UTC).replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%SZ")
    now_local = dt.datetime.now().strftime("%H:%M:%S")
    # Top-bar health pill — map bottleneck severity to NOMINAL/WARN/CRITICAL.
    # OWNER call 2026-05-23: CRITICAL fires only when the Edge Lab itself is
    # down — never on output dryness ("no EA further along" = the actual work,
    # not a fault). Output-flow checks degrade the pill at most to WARN.
    _FACTORY_DOWN_CHECKS = {
        "mt5_worker_saturation",   # T1-T10 daemons dead
        "codex_auth_broken",       # cannot build EAs
        "disk_free_gb",            # storage blocker
        "pump_task_lastresult",    # orchestrator failing
        "ablation_grandchildren",  # state-integrity violation
        "active_row_age",          # rows stuck past phase timeout
    }
    pill_label = {"ok": "NOMINAL", "warn": "WARN", "block": "CRITICAL"}[severity]
    pill_class = {"ok": "", "warn": "warn", "block": "crit"}[severity]
    _checks = health.get("checks") or []
    _factory_fail = any(
        (c.get("status") or "").upper() == "FAIL"
        and c.get("name") in _FACTORY_DOWN_CHECKS
        for c in _checks
    )
    _any_fail = any((c.get("status") or "").upper() == "FAIL" for c in _checks)
    if _factory_fail:
        pill_label = "CRITICAL"; pill_class = "crit"
    elif _any_fail and pill_class == "":
        pill_label = "WARN"; pill_class = "warn"
    elif (health.get("overall") or "").upper() == "WARN" and pill_class == "":
        pill_label = "WARN"; pill_class = "warn"

    def sparkline_str(values: list[int]) -> str:
        """7-char unicode bar sparkline from a list of ints."""
        glyphs = "▁▂▃▄▅▆▇█"
        if not values:
            return "▁▁▁▁▁▁▁"
        max_v = max(values) or 1
        out = []
        for v in values:
            idx = int(round((v / max_v) * (len(glyphs) - 1)))
            out.append(glyphs[max(0, min(len(glyphs) - 1, idx))])
        return "".join(out)

    # ---------- 2. MISSION + HEUREKA ----------
    p8_pass = backlog.get("p8_pass_total", 0)
    portfolio_target = 5
    mission_pct = int(100 * p8_pass / portfolio_target) if portfolio_target else 0
    bar_filled = "█" * max(0, min(20, int(20 * p8_pass / portfolio_target))) if portfolio_target else ""
    bar_empty = "─" * (20 - len(bar_filled))
    if p8_pass == 0:
        mission_sub = "No EA has cleared Q11 portfolio gate"
        bar_html = f'<span class="empty">{bar_empty}</span>'
    else:
        mission_sub = f"{p8_pass} EA{'s' if p8_pass != 1 else ''} portfolio-ready"
        bar_html = f'<span>{bar_filled}</span><span class="empty">{bar_empty}</span>'

    # 14-chip Q-strip (Card / Build / Review / Q02..Q11 / Live)
    chip_labels = {
        "Card": "CRD", "Build": "BLD", "Review": "REV",
        "Q02": "Q02", "Q03": "Q03", "Q04": "Q04", "Q05": "Q05", "Q06": "Q06",
        "Q07": "Q07", "Q08": "Q08", "Q09": "Q09", "Q10": "Q10", "Q11": "Q11",
        "Live": "LIV",
    }
    if heureka:
        cur_idx = heureka["current_stage_idx"]
        chips_inner = []
        for i, st in enumerate(PIPELINE_STAGES):
            cls = ""
            if i < cur_idx:
                cls = "done"
            elif i == cur_idx:
                cls = "now"
            chips_inner.append(f'<span class="chip {cls}">{chip_labels.get(st, st)}</span>')
        heureka_chips_html = "".join(chips_inner)
        heureka_pct = heureka["pct"]
        heureka_done = heureka["completed_count"]
        heureka_total = heureka["total_stages"]
        next_stage = heureka["next_stage"]
        next_label = chip_labels.get(heureka["current_stage"], heureka["current_stage"])
        next_target = chip_labels.get(next_stage, next_stage)
        heureka_next_act = f"PROMOTE {next_label} → {next_target}"
        heureka_id = e(heureka["ea_id"])
        heureka_slug = e(heureka["slug"] or "—")
        heureka_aux = f'Furthest EA // {heureka_done} of {heureka_total}'
    else:
        heureka_chips_html = "".join(
            f'<span class="chip">{chip_labels[s]}</span>' for s in PIPELINE_STAGES
        )
        heureka_pct = 0
        heureka_done = 0
        heureka_total = len(PIPELINE_STAGES)
        heureka_next_act = "AWAIT FIRST EA"
        heureka_id = "—"
        heureka_slug = "no EA in flight"
        heureka_aux = "No leader yet"

    # ---------- 3. OWNER ATTENTION ----------
    router = q.get("agent_router") or {}
    attention_rows: list[str] = []

    # T_LIVE-level rows would surface from a future portfolio_candidates table;
    # for now we surface BLOCKED/OPS_FIX_REQUIRED/REVIEW agent_tasks + the
    # build→review pending queue (Claude must approve those).
    review_pending = db_rows(
        "SELECT b.id, b.payload_json FROM tasks b "
        "WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' "
        "AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%') "
        "LIMIT 8"
    )
    for row in review_pending[:4]:
        try:
            p = json.loads(row.get("payload_json") or "{}")
        except Exception:
            p = {}
        ea_id = p.get("ea_id") or "?"
        slug = (p.get("slug") or "")[:34]
        attention_rows.append(
            f'<div class="attention-row">'
            f'<span class="glyph">▸</span>'
            f'<span class="cat">REVIEW PENDING</span>'
            f'<span class="ent">{e(ea_id)}<span class="slug">{e(slug)}</span></span>'
            f'<span class="status">CLAUDE TASK</span>'
            f'</div>'
        )

    # BLOCKED / OPS_FIX_REQUIRED from agent_router
    for task in router.get("recent_tasks", []):
        state = str(task.get("state") or "").upper()
        if state not in ("BLOCKED", "OPS_FIX_REQUIRED"):
            continue
        agent = task.get("agent") or "?"
        ttype = (task.get("type") or "ops_issue")[:34]
        artifact = (task.get("artifact") or task.get("verdict") or "")[:36]
        age_h = task.get("age_h") or 0
        attention_rows.append(
            f'<div class="attention-row alert">'
            f'<span class="glyph">▸</span>'
            f'<span class="cat">{e(state)}</span>'
            f'<span class="ent">{e(agent)} / {e(ttype)}'
            f'<span class="slug">{e(artifact or "ops_issue")}</span></span>'
            f'<span class="status">{age_h:.1f}H SLA</span>'
            f'</div>'
        )

    # REVIEW-ready agent_tasks (Codex artefacts waiting Claude eyeballs)
    for task in router.get("recent_tasks", []):
        state = str(task.get("state") or "").upper()
        if state != "REVIEW":
            continue
        agent = task.get("agent") or "?"
        ttype = (task.get("type") or "ops_issue")[:34]
        age_h = task.get("age_h") or 0
        attention_rows.append(
            f'<div class="attention-row">'
            f'<span class="glyph">▸</span>'
            f'<span class="cat">REVIEW READY</span>'
            f'<span class="ent">{e(agent)} / {e(ttype)}'
            f'<span class="slug">agent_task</span></span>'
            f'<span class="status">{age_h:.1f}H // CLAUDE</span>'
            f'</div>'
        )

    if not attention_rows:
        attention_rows.append(
            '<div class="attention-row">'
            '<span class="glyph">·</span>'
            '<span class="cat">CLEAR</span>'
            '<span class="ent">no owner-attention items<span class="slug">all SLAs green</span></span>'
            '<span class="status">OK</span>'
            '</div>'
        )
    attention_html_inner = "\n".join(attention_rows[:8])
    attention_aux = f"{len(attention_rows):02d} Items Open"

    # ---------- 3. AGENT STATUS ----------
    claude_act = len(claude_workers)
    codex_act = len(codex_workers)
    mt5_act = len(mt5_work)
    review_q_count = len(review_pending)

    # Today's completed work_items counts as "DONE TODAY" for MT5
    cw_today = controlling["windows"]["today"]
    mt5_done_today = cw_today.get("mt5_items", 0)

    # Claude/Codex closed-today: agent_tasks transitioned in the last 24h
    try:
        claude_closed_today = (db_rows(
            "SELECT COUNT(*) AS c FROM agent_tasks "
            "WHERE assigned_agent='claude' AND state IN ('APPROVED','PASSED','FAILED','RECYCLE') "
            "AND DATE(updated_at) = DATE('now')"
        ) or [{"c": 0}])[0]["c"]
        codex_closed_today = (db_rows(
            "SELECT COUNT(*) AS c FROM agent_tasks "
            "WHERE assigned_agent='codex' AND state IN ('APPROVED','PASSED','FAILED','RECYCLE') "
            "AND DATE(updated_at) = DATE('now')"
        ) or [{"c": 0}])[0]["c"]
    except Exception:
        claude_closed_today = 0
        codex_closed_today = 0

    # Token % from live quota snapshot (Tampermonkey) when fresh, else "—"
    claude_tok_pct = qsnap.get("claude", {}).get("hour_pct") if qsnap else None
    codex_tok_pct = qsnap.get("codex", {}).get("hour_pct") if qsnap else None
    claude_tok_str = f"{int(claude_tok_pct)}%" if isinstance(claude_tok_pct, (int, float)) else "—"
    codex_tok_str = f"{int(codex_tok_pct)}%" if isinstance(codex_tok_pct, (int, float)) else "—"

    # Total backtests pending across all phases (combine builds + p2 + p3 + work_items pending)
    mt5_pend = (
        q.get("backtest_p2_pending", 0)
        + q.get("backtest_p3_pending", 0)
        + len(q.get("pending_backtests_list", []) or [])
    )
    # T1..T10 fleet — active when an mt5_work entry's terminal matches
    active_terms = {str(w.get("terminal") or "").upper() for w in mt5_work}
    term_cells = []
    for i in range(1, 11):
        tname = f"T{i}"
        is_active = any(tname in t or t == tname for t in active_terms)
        cls = "active" if is_active else "idle"
        dot = "■" if is_active else "□"
        term_cells.append(
            f'<div class="term {cls}"><div class="id">{tname}</div><div class="dot">{dot}</div></div>'
        )
    term_row_html = "".join(term_cells)
    fleet_label = f"T1–T10 Workers // {len(active_terms)} of 10 saturated"

    # ---------- 4. PROFITABILITY NEXT ACTIONS ----------
    def stage_state_class(status: str) -> tuple[str, str]:
        s = (status or "").lower()
        if s == "done":
            return ("state-done", "DONE")
        if s == "active":
            return ("state-act", "ACTIVE")
        if s == "failed":
            return ("state-fail", "FAIL")
        return ("state-pend", "PEND")

    action_rows_html: list[str] = []
    for row in next_actions:
        cls, label = stage_state_class(str(row.get("status") or ""))
        ea = e(str(row.get("ea_id") or "?"))
        slug = e(str(row.get("slug") or "")[:40])
        next_act = e(str(row.get("next_action") or "")[:80])
        # Lane heuristic from slug prefix
        lane = "MULTI"
        slug_lower = (row.get("slug") or "").lower()
        if "carry" in slug_lower:
            lane = "FX-CARRY"
        elif "fx" in slug_lower or "eur" in slug_lower or "usd" in slug_lower:
            lane = "FX"
        elif "h4" in slug_lower:
            lane = "H4"
        elif "h1" in slug_lower:
            lane = "H1"
        elif "idx" in slug_lower or "spx" in slug_lower or "ndx" in slug_lower:
            lane = "INDEX"
        # Decide top-level action verb
        st = (row.get("status") or "").lower()
        stage_name = (row.get("stage") or "")
        if st == "done":
            verb = "PROMOTE"
        elif st == "active":
            verb = "WAIT EVIDENCE"
        elif st == "failed":
            verb = "REVIEW FAIL"
        else:
            verb = "ENQUEUE" if stage_name not in ("Card",) else "BUILD"
        # Compute next gate hint (e.g. Q02 → Q03)
        try:
            idx = PIPELINE_STAGES.index(stage_name)
            nxt_g = PIPELINE_STAGES[idx + 1] if idx + 1 < len(PIPELINE_STAGES) else "live"
            next_gate = f"{chip_labels.get(stage_name, stage_name)} → {chip_labels.get(nxt_g, nxt_g)}"
        except ValueError:
            next_gate = chip_labels.get(stage_name, stage_name) or "—"
        action_rows_html.append(
            "<tr>"
            f'<td class="action">{e(verb)}</td>'
            f'<td class="ea-cell">{ea}</td>'
            f'<td class="slug-cell">{e(lane)}</td>'
            f'<td class="slug-cell">{slug}</td>'
            f'<td><span class="state {cls}">{label}</span></td>'
            f'<td class="gate">{e(next_gate)}</td>'
            f'<td class="note">{next_act}</td>'
            "</tr>"
        )
    if not action_rows_html:
        action_rows_html.append('<tr><td colspan="7" class="note">no pipeline candidates</td></tr>')
    profit_aux = f"{len(next_actions):02d} Rows // Sorted By Recency"

    # ---------- 5. PIPELINE FUNNEL ----------
    # Stage counts:
    # SRC      — sources pending  (input reservoir)
    # CARDS    — cards_ready / approved (write-ready EAs)
    # BUILT    — build_ea active+pending+done not yet reviewed (EAs being built)
    # BACKTEST Q02  — work_items at P2 (any status)
    # ROBUST Q05-Q07 — work_items at P4/P5/P5b (any status)
    # PORTFOLIO Q11 — work_items PASS at P8
    src_pending = backlog["sources"].get("pending", 0)
    src_done = backlog["sources"].get("done", 0)
    cards_ready = backlog["sources"].get("cards_ready", 0)
    cards_cum_approved = q.get("cards_approved", 0)
    # Builds: pending + active + waiting review
    built_count = q.get("builds_pending", 0) + q.get("builds_active", 0) + review_q_count
    # Backtest Q02 — count work_items at P2 (active+pending+done)
    p2_total = 0
    for r in db_rows("SELECT status, verdict, COUNT(*) AS c FROM work_items WHERE phase='P2' GROUP BY status, verdict"):
        p2_total += int(r.get("c") or 0)
    # ROBUST Q05-Q07: legacy P4 → Q05, P5 → Q06, P5b → Q07 (OWNER hard rule:
    # operator surfaces show Qxx only — never the legacy P-keys).
    robust_rows = db_rows(
        "SELECT phase, COUNT(DISTINCT ea_id) AS c FROM work_items "
        "WHERE verdict='PASS' AND phase IN ('P4','P5','P5b') GROUP BY phase"
    )
    robust_count = sum(int(r.get("c") or 0) for r in robust_rows)
    _p_to_q = {"P4": "Q05", "P5": "Q06", "P5b": "Q07"}
    robust_meta = " // ".join(
        f"{_p_to_q.get(r['phase'], r['phase'])}:{r['c']}" for r in robust_rows
    ) or "0 PASS"
    portfolio_count = backlog.get("p8_pass_total", 0)
    portfolio_meta = f"TARGET 5 // {portfolio_count}/5"

    # 7D sparklines from trend dict (keys per day)
    def _last7(metric_key: str) -> list[int]:
        today_d = dt.date.today()
        return [int((trend.get((today_d - dt.timedelta(days=i)).isoformat()) or {}).get(metric_key, 0))
                for i in range(6, -1, -1)]

    src_spark = sparkline_str(_last7("source_intake")) if trend else "▁▁▁▁▁▁▁"
    cards_spark = sparkline_str(_last7("approved")) if trend else "▁▁▁▁▁▁▁"
    build_spark = sparkline_str(_last7("build_ok") or _last7("build_done")) if trend else "▁▁▁▁▁▁▁"
    q02_spark = sparkline_str(_last7("_p2_pass")) if trend else "▁▁▁▁▁▁▁"
    q03_spark = sparkline_str(_last7("_p3_pass")) if trend else "▁▁▁▁▁▁▁"
    q11_spark = "▁▁▁▁▁▁▁"  # no P8-PASS observed yet; sparkline stays empty

    # Funnel drop-off labels
    review_drop = ""
    if cards_cum_approved:
        review_drop = f"▼ {int(100 - 100 * built_count / max(1, cards_cum_approved))}% TO REVIEW"
    q02_drop = ""
    if p2_total:
        q02_drop = f"▼ {int(100 - 100 * robust_count / max(1, p2_total))}% TO Q05"

    funnel_html_inner = (
        '<div class="funnel-stage{src_empty}">'
        '<div class="stg-lbl">SRC</div>'
        f'<div class="stg-num">{src_pending}</div>'
        f'<div class="stg-meta">{src_done} DONE // {src_pending} PEND</div>'
        '<span class="stg-spark-lbl">7D INTAKE</span>'
        f'<div class="stg-spark">{src_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{cards_empty}">'
        '<div class="stg-lbl">CARDS</div>'
        f'<div class="stg-num">{cards_ready}</div>'
        f'<div class="stg-meta">{cards_cum_approved} APPROVED CUM</div>'
        '<span class="stg-spark-lbl">7D APPROVED</span>'
        f'<div class="stg-spark">{cards_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{built_empty}">'
        '<div class="stg-lbl">BUILT</div>'
        f'<div class="stg-num">{built_count}</div>'
        f'<div class="stg-meta drop">{e(review_drop) or "—"}</div>'
        '<span class="stg-spark-lbl">7D BUILD</span>'
        f'<div class="stg-spark">{build_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{p2_empty}">'
        '<div class="stg-lbl">BACKTEST Q02</div>'
        f'<div class="stg-num">{p2_total}</div>'
        f'<div class="stg-meta drop">{e(q02_drop) or "—"}</div>'
        '<span class="stg-spark-lbl">7D Q02 PASS</span>'
        f'<div class="stg-spark">{q02_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{robust_empty}">'
        '<div class="stg-lbl">ROBUST Q05-Q07</div>'
        f'<div class="stg-num">{robust_count}</div>'
        f'<div class="stg-meta">{e(robust_meta)}</div>'
        '<span class="stg-spark-lbl">7D Q03 PASS</span>'
        f'<div class="stg-spark">{q03_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{portfolio_empty}">'
        '<div class="stg-lbl">PORTFOLIO Q11</div>'
        f'<div class="stg-num">{portfolio_count}</div>'
        f'<div class="stg-meta">{e(portfolio_meta)}</div>'
        '<span class="stg-spark-lbl">7D Q11 PASS</span>'
        f'<div class="stg-spark">{q11_spark}</div>'
        '</div>'
    )
    funnel_html_inner = funnel_html_inner.format(
        src_empty=" empty" if src_pending == 0 else "",
        cards_empty=" empty" if cards_ready == 0 else "",
        built_empty=" empty" if built_count == 0 else "",
        p2_empty=" empty" if p2_total == 0 else "",
        robust_empty=" empty" if robust_count == 0 else "",
        portfolio_empty=" empty" if portfolio_count == 0 else "",
    )

    # ---------- 6. RECENT EVENTS ----------
    try:
        events_rows = db_rows(
            "SELECT ts, entity_type, entity_id, event, detail_json "
            "FROM events ORDER BY ts DESC LIMIT 10"
        )
    except Exception:
        events_rows = []

    def event_class(event: str) -> tuple[str, str]:
        ev = (event or "").lower()
        if "pass" in ev or "ok" in ev or "approve" in ev:
            return ("pass", "✓")
        if "fail" in ev or "dead" in ev or "blocked" in ev:
            return ("fail", "✗")
        if "stagnation" in ev or "p_pass" in ev:
            return ("dead", "☠")
        return ("", "⚙")

    events_html_rows: list[str] = []
    for idx, r in enumerate(events_rows):
        try:
            t = dt.datetime.fromisoformat(str(r.get("ts") or "").replace("Z", "+00:00"))
            ts_str = t.strftime("%H:%M:%SZ")
        except Exception:
            ts_str = (str(r.get("ts") or "")[11:19] or "—") + "Z"
        kind, gly = event_class(r.get("event"))
        cls = kind or ""
        evt = (r.get("event") or "").replace("_", " ").upper()[:24]
        ent = r.get("entity_id") or "—"
        # Try to pull slug + symbol from detail_json
        slug = ""
        sym = "--"
        try:
            d = json.loads(r.get("detail_json") or "{}")
            slug = (d.get("slug") or d.get("source_title") or d.get("verdict") or "")[:40]
            sym = (d.get("symbol") or d.get("source") or sym)[:14]
            term = d.get("terminal")
            if term:
                slug = f"{slug} // {term}" if slug else term
        except Exception:
            pass
        cur_cls = "cur live" if idx == 0 else "cur dim"
        events_html_rows.append(
            f'<div class="events-row {cls}">'
            f'<span class="{cur_cls}">▮</span>'
            f'<span class="ts">{e(ts_str)}</span>'
            f'<span class="gly">{gly}</span>'
            f'<span class="evt">{e(evt)}</span>'
            f'<span class="ent">{e(str(ent))}</span>'
            f'<span class="slug">{e(slug)}</span>'
            f'<span class="sym">{e(sym)}</span>'
            f'</div>'
        )
    if not events_html_rows:
        events_html_rows.append(
            '<div class="events-row">'
            '<span class="cur dim">▮</span><span class="ts">—</span>'
            '<span class="gly">·</span><span class="evt">NO EVENTS</span>'
            '<span class="ent">—</span><span class="slug">events table empty</span>'
            '<span class="sym">--</span></div>'
        )

    # ---------- 7. DAILY CONTROLLING ----------
    cw = controlling["windows"]
    today_date = dt.date.today().isoformat()
    yesterday_date = (dt.date.today() - dt.timedelta(days=1)).isoformat()
    # 7-day avg
    mt5_7d_total = cw["7d"]["mt5_items"]
    mt5_7d_avg = mt5_7d_total // 7 if mt5_7d_total else 0
    analysis_7d_total = cw["7d"]["analysis_items"]
    analysis_7d_avg = analysis_7d_total // 7 if analysis_7d_total else 0
    fail_7d_total = cw["7d"]["fail_invalid"]
    fail_7d_avg = fail_7d_total // 7 if fail_7d_total else 0
    mt5_30d = cw["30d"]["mt5_items"]
    # Q02 PASS cum from controlling.by_phase if available
    q02_pass_30d = 0
    for r in controlling.get("by_phase") or []:
        if (r.get("label") or "").startswith("Q02 PASS"):
            q02_pass_30d += int(r.get("count") or 0)
    anom = controlling["anomalies"]
    anom_today_total = anom["zero_trade_like"] + anom["invalid"] + anom["waiting_input"]

    # ---------- 1. TOP BAR message ----------
    topbar_msg = e(msg)[:140]

    # ---------- BOTTOM BAR ----------
    try:
        sha_out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(REPO), capture_output=True, text=True, timeout=5,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        build_sha = (sha_out.stdout or "").strip() or "—"
    except Exception:
        build_sha = "—"

# ==== HTML assembly (STEEL/EMERALD brand · OWNER call 2026-05-23) ====

    # CSS lives outside the f-string to avoid brace-escaping.
    CSS = r"""
:root {
  --bg:            #020617;
  --surface-1:     #060b18;
  --surface-2:     #0f172a;
  --surface-3:     #1e293b;
  --text:          #f8fafc;
  --text-2:        #cbd5e1;
  --text-3:        #94a3b8;
  --text-4:        #64748b;
  --border:        rgba(148, 163, 184, 0.08);
  --border-2:      rgba(148, 163, 184, 0.18);
  --signal:        #10b981;
  --signal-bright: #34d399;
  --signal-dim:    #059669;
  --pass:          #10b981;
  --fail:          #ef4444;
  --warn:          #f97316;
  --info:          #cbd5e1;
  --promising:     #f59e0b;
  --dead:          #6b7280;
  --live:          #06b6d4;
}
* { box-sizing: border-box; margin: 0; padding: 0; border-radius: 0 !important; }
html, body {
  background: var(--bg);
  color: var(--text);
  font-family: 'General Sans', system-ui, sans-serif;
  font-size: 14px;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
body { padding: 32px; min-height: 100vh; }
.mono, .num, code, kbd {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
}
.page { display: grid; grid-template-columns: repeat(12, 1fr); gap: 24px; }

/* TOP BAR */
.topbar {
  grid-column: span 12;
  display: grid;
  grid-template-columns: auto 1fr auto auto;
  align-items: center;
  gap: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--border);
}
.brand {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-weight: 700; font-size: 14px;
  letter-spacing: 0.18em; color: var(--text); text-transform: uppercase;
}
.brand .slash { color: var(--text-4); margin: 0 10px; font-weight: 400; }
.brand .sub { color: var(--text-3); font-weight: 500; }
.topbar-msg {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; letter-spacing: 0.08em;
  color: var(--text-3); text-transform: uppercase;
}
.topbar-msg .tag { color: var(--warn); font-weight: 700; letter-spacing: 0.16em; margin-right: 10px; }
.topbar-msg .dot { color: var(--text-4); margin: 0 8px; }
.utc-clock {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 18px; font-weight: 500;
  color: var(--text); text-align: right; letter-spacing: 0.02em;
}
.utc-clock .lbl {
  display: block; font-size: 10px; font-weight: 400;
  letter-spacing: 0.22em; color: var(--text-3);
  margin-bottom: 4px; text-transform: uppercase;
}
.health-pill {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; font-weight: 700; letter-spacing: 0.22em;
  padding: 8px 14px; border: 1px solid var(--border-2);
  text-transform: uppercase; color: var(--text-3); background: transparent;
}
.health-pill.warn { color: var(--bg); background: var(--warn); border-color: var(--warn); }
.health-pill.crit { color: var(--bg); background: var(--fail); border-color: var(--fail);
                    animation: blink 1s steps(2) infinite; }
@keyframes blink { 50% { opacity: 0.35; } }

/* SECTION */
.section { grid-column: span 12; }
.col-left  { grid-column: span 7; min-width: 0; }
.col-right { grid-column: span 5; min-width: 0; }
.section-head {
  display: flex; align-items: center; gap: 12px;
  padding-bottom: 8px; margin-bottom: 14px;
  border-bottom: 1px solid var(--border);
}
.section-glyph { display: inline-block; width: 8px; height: 8px; background: var(--signal); flex-shrink: 0; }
.section-title {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 12px; font-weight: 600; letter-spacing: 0.12em;
  color: var(--text-3); text-transform: uppercase;
}
.section-aux {
  margin-left: auto;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; letter-spacing: 0.14em; color: var(--text-4); text-transform: uppercase;
}
.panel { background: var(--surface-1); border: 1px solid var(--border); box-shadow: 0 0 0 1px var(--border) inset; }

/* MISSION */
.mission {
  display: grid; grid-template-columns: 1fr 1px 1fr; gap: 28px;
  align-items: stretch; padding: 24px 28px; height: 100%;
  background: var(--surface-1); border: 1px solid var(--border);
}
.mission .divider { background: var(--border); width: 1px; }
.mission-tile { min-width: 0; display: flex; flex-direction: column; }
.mission-label {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; font-weight: 500; letter-spacing: 0.18em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 10px;
}
.mission-hero {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 72px; line-height: 0.9; font-weight: 500;
  color: var(--text); letter-spacing: -0.04em;
}
.mission-hero .denom { font-size: 28px; font-weight: 400; color: var(--text-3); margin-left: 4px; letter-spacing: 0; }
.mission-hero .pct { font-size: 20px; font-weight: 400; color: var(--text-3); margin-left: 14px; letter-spacing: 0; }
.mission-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; color: var(--text-3);
  letter-spacing: 0.12em; margin-top: 14px; text-transform: uppercase;
}
.mission-bar {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  color: var(--text-2); font-size: 13px; letter-spacing: 0;
  margin-top: 12px; word-break: break-all;
}
.mission-bar .empty { color: var(--text-4); }
.mission-tag {
  display: inline-block;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  margin-top: 12px; font-size: 10px; font-weight: 700; letter-spacing: 0.22em;
  text-transform: uppercase; color: var(--warn);
  border: 1px solid var(--warn); padding: 4px 8px; align-self: flex-start;
}

/* HEUREKA */
.heureka {
  background: var(--surface-1); border: 1px solid var(--border);
  padding: 22px 24px; height: 100%;
  display: flex; flex-direction: column; gap: 18px;
}
.heureka-id {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 28px; font-weight: 500; line-height: 1;
  color: var(--text); letter-spacing: -0.01em;
}
.heureka-slug {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; color: var(--text-3); letter-spacing: 0.14em;
  text-transform: uppercase; margin-top: 6px;
}
.heureka-chips { display: grid; grid-template-columns: repeat(14, 1fr); gap: 2px; }
.chip {
  text-align: center;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 600; letter-spacing: 0.08em;
  padding: 6px 0 5px;
  border: 1px solid var(--border); background: var(--surface-2); color: var(--text-4);
}
.chip.done { color: var(--pass); background: var(--surface-3); border-color: var(--border-2); }
.chip.now { color: var(--bg); background: var(--signal); border-color: var(--signal); font-weight: 700; }
.heureka-metric {
  display: grid; grid-template-columns: 1fr 1fr;
  border-top: 1px solid var(--border); padding-top: 16px; gap: 16px;
}
.heureka-metric .m-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 500; letter-spacing: 0.18em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 6px;
}
.heureka-metric .m-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 28px; font-weight: 500; color: var(--text); line-height: 1;
}
.heureka-metric .m-val .unit { font-size: 14px; color: var(--text-3); margin-left: 4px; }
.heureka-next {
  margin-top: auto; border-top: 1px solid var(--border); padding-top: 14px;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; letter-spacing: 0.08em; color: var(--text-2);
  display: flex; align-items: baseline; gap: 10px; text-transform: uppercase;
}
.heureka-next .arr { color: var(--signal); font-weight: 700; }
.heureka-next .lbl { font-size: 10px; letter-spacing: 0.22em; color: var(--text-3); }
.heureka-next .act { color: var(--text); font-weight: 600; letter-spacing: 0.06em; }

/* OWNER ATTENTION */
.attention { background: var(--surface-1); border: 1px solid var(--border); }
.attention-row {
  display: grid; grid-template-columns: 18px 150px 1fr 130px;
  gap: 14px; padding: 12px 18px; align-items: baseline;
  border-bottom: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
}
.attention-row:last-child { border-bottom: none; }
.attention-row .glyph { color: var(--text-3); font-weight: 700; }
.attention-row .cat {
  font-size: 10px; font-weight: 700; letter-spacing: 0.18em;
  text-transform: uppercase; color: var(--text-2);
}
.attention-row .ent { color: var(--text); font-weight: 500; }
.attention-row .ent .slug { color: var(--text-3); margin-left: 8px; font-weight: 400; }
.attention-row .status {
  font-size: 10px; letter-spacing: 0.16em; text-transform: uppercase;
  color: var(--text-3); text-align: right;
}
.attention-row.alert .glyph { color: var(--fail); }
.attention-row.alert .cat   { color: var(--fail); }
.attention-row.alert .ent   { color: var(--text); }
.attention-row.alert .status { color: var(--fail); }

/* AGENT STATUS */
.agent-status { background: var(--surface-1); border: 1px solid var(--border); }
.agent-row {
  display: grid; grid-template-columns: 80px 1fr;
  gap: 16px; padding: 14px 20px; align-items: baseline;
  border-bottom: 1px solid var(--border);
}
.agent-row .name {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 12px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text); text-transform: uppercase;
}
.agent-readout {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 12px; letter-spacing: 0.02em; color: var(--text-2);
}
.agent-readout .v { color: var(--text); font-weight: 600; }
.agent-readout .sep { color: var(--text-4); margin: 0 8px; }
.agent-readout .k {
  color: var(--text-3); font-size: 10px;
  letter-spacing: 0.18em; text-transform: uppercase; margin-left: 4px;
}
.agent-fleet { padding: 16px 20px 18px; border-bottom: none; }
.agent-fleet .flbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 12px;
}
.fleet-row { display: grid; grid-template-columns: repeat(10, 1fr); gap: 6px; }
.term {
  text-align: center; padding: 10px 0 8px;
  border: 1px solid var(--border); background: var(--surface-2);
}
.term .id {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 500; letter-spacing: 0.14em;
  color: var(--text-3); text-transform: uppercase;
}
.term .dot {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 14px; line-height: 1; margin-top: 5px;
}
.term.active .dot { color: var(--text); }
.term.idle   .dot { color: var(--text-3); }
.term.active .id  { color: var(--text-2); }

/* TABLE */
.qm-table {
  width: 100%; border-collapse: collapse;
  background: var(--surface-1); border: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
}
.qm-table th, .qm-table td {
  padding: 11px 16px;
  border-right: 1px solid var(--border);
  border-bottom: 1px solid var(--border);
  text-align: left; vertical-align: baseline;
}
.qm-table th:last-child, .qm-table td:last-child { border-right: none; }
.qm-table tr:last-child td { border-bottom: none; }
.qm-table th {
  font-size: 10px; font-weight: 700; letter-spacing: 0.2em;
  text-transform: uppercase; color: var(--text-3); background: var(--bg);
}
.qm-table td.num { text-align: right; font-variant-numeric: tabular-nums; }
.qm-table .ea-cell    { color: var(--text); font-weight: 600; }
.qm-table .slug-cell  { color: var(--text-3); }
.qm-table .gate       { color: var(--text-2); letter-spacing: 0.06em; }
.qm-table .note       { color: var(--text-3); font-size: 11px; }
.qm-table .state {
  font-size: 10px; font-weight: 700; letter-spacing: 0.16em; text-transform: uppercase;
}
.qm-table .state-done { color: var(--pass); }
.qm-table .state-act  { color: var(--text-2); }
.qm-table .state-pend { color: var(--text-3); }
.qm-table .state-fail { color: var(--fail); }
.qm-table .action {
  font-size: 10px; font-weight: 700; letter-spacing: 0.16em;
  text-transform: uppercase; color: var(--text-2);
}

/* PIPELINE FUNNEL */
.funnel {
  display: grid;
  grid-template-columns: 1fr 14px 1fr 14px 1fr 14px 1fr 14px 1fr 14px 1fr;
  align-items: stretch; gap: 0;
  background: var(--surface-1); border: 1px solid var(--border); padding: 20px;
}
.funnel-stage {
  border: 1px solid var(--border); background: var(--surface-2);
  padding: 14px 12px 12px; text-align: left; min-width: 0;
  display: flex; flex-direction: column; gap: 6px;
}
.funnel-stage .stg-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text-3); text-transform: uppercase;
}
.funnel-stage .stg-num {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 36px; font-weight: 500; line-height: 1;
  margin: 2px 0; color: var(--text); letter-spacing: -0.02em;
}
.funnel-stage.empty .stg-num { color: var(--text-3); }
.funnel-stage .stg-meta {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-3);
  letter-spacing: 0.04em; text-transform: uppercase;
}
.funnel-stage .stg-meta.drop { color: var(--text-2); }
.funnel-arrow {
  align-self: center; color: var(--text-4); text-align: center;
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 14px;
}
.funnel-stage .stg-spark-lbl {
  display: block;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-4); margin-top: 6px; text-transform: uppercase;
}
.funnel-stage .stg-spark {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 14px; line-height: 1; letter-spacing: 0.04em;
  color: var(--text-2); margin-top: 2px;
}
.funnel-stage.empty .stg-spark { color: var(--text-4); }

/* EVENTS */
.events {
  background: var(--surface-1); border: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
}
.events-row {
  display: grid;
  grid-template-columns: 22px 92px 24px 140px 120px 1fr 140px;
  gap: 12px; padding: 10px 18px;
  border-bottom: 1px solid var(--border); align-items: baseline;
}
.events-row:last-child { border-bottom: none; }
.events-row .cur {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  color: var(--signal); font-weight: 700;
}
.events-row .cur.live { animation: blink 1s steps(2) infinite; }
.events-row .cur.dim { color: transparent; }
.events-row .ts {
  color: var(--text-3); font-variant-numeric: tabular-nums; letter-spacing: 0.02em;
}
.events-row .gly { text-align: center; font-weight: 600; color: var(--text); }
.events-row.fail  .gly { color: var(--fail); }
.events-row.pass  .gly { color: var(--pass); }
.events-row.dead  .gly { color: var(--text-3); }
.events-row .evt {
  font-size: 10px; font-weight: 700; letter-spacing: 0.18em;
  text-transform: uppercase; color: var(--text-2);
}
.events-row.fail  .evt { color: var(--fail); }
.events-row.pass  .evt { color: var(--pass); }
.events-row.dead  .evt { color: var(--text-3); }
.events-row .ent { color: var(--text); font-weight: 600; }
.events-row .slug { color: var(--text-3); }
.events-row .sym {
  color: var(--text-2); text-align: right;
  font-size: 11px; letter-spacing: 0.04em;
}

/* DAILY CONTROLLING */
.control {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 0;
  background: var(--surface-1); border: 1px solid var(--border);
}
.control-col {
  padding: 18px 22px 20px; border-right: 1px solid var(--border);
  display: flex; flex-direction: column; gap: 16px;
}
.control-col:last-child { border-right: none; }
.control-col .col-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 700; letter-spacing: 0.24em;
  text-transform: uppercase; color: var(--text-3);
  border-bottom: 1px solid var(--border); padding-bottom: 8px;
}
.control-stat .s-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 500; letter-spacing: 0.18em;
  text-transform: uppercase; color: var(--text-3);
}
.control-stat .s-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 28px; font-weight: 500; line-height: 1;
  margin-top: 6px; color: var(--text); letter-spacing: -0.02em;
}
.control-stat .s-val.dim { color: var(--text-3); }
.control-stat .s-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; color: var(--text-3);
  letter-spacing: 0.04em; margin-top: 5px; text-transform: uppercase;
}

/* BOTTOM BAR */
.botbar {
  grid-column: span 12;
  display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 24px;
  padding-top: 16px; border-top: 1px solid var(--border); margin-top: 4px;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; letter-spacing: 0.2em;
  text-transform: uppercase; color: var(--text-3);
}
.botbar .center { text-align: center; }
.botbar .right  { text-align: right; }
.botbar .key    { color: var(--text-4); margin-right: 8px; }
.botbar .val    { color: var(--text-2); }
"""

    # === Final HTML ===
    html_doc = (
        '<!DOCTYPE html>\n'
        '<html lang="en"><head>\n'
        '<meta charset="utf-8">\n'
        '<title>QuantMechanica // COCKPIT</title>\n'
        '<meta http-equiv="refresh" content="30">\n'
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link rel="preconnect" href="https://api.fontshare.com" crossorigin>\n'
        '<link href="https://api.fontshare.com/v2/css?f[]=general-sans@200,400,500,600,700&display=swap" rel="stylesheet">\n'
        '<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">\n'
        '<style>' + CSS + '</style>\n'
        '</head>\n<body>\n'
        + f'''
<div class="page">

  <!-- 1. TOP BAR -->
  <div class="topbar">
    <div class="brand">QUANTMECHANICA<span class="slash">//</span><span class="sub">COCKPIT</span></div>
    <div class="topbar-msg">
      <span class="tag">{e(pill_label)}</span>
      {topbar_msg}
    </div>
    <div class="utc-clock">
      <span class="lbl">UTC // MISSION TIME</span>
      {e(now_utc_full)}
    </div>
    <div class="health-pill {pill_class}">{e(pill_label)}</div>
  </div>

  <!-- 2. MISSION + HEUREKA -->
  <div class="col-left">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Mission Progress // Heureka Portfolio</span>
      <span class="section-aux">Q11-PASS Cohort // Target {portfolio_target} EAs</span>
    </div>
    <div class="mission">
      <div class="mission-tile">
        <div class="mission-label">Q11-Pass Portfolio</div>
        <div class="mission-hero">{p8_pass}<span class="denom">/{portfolio_target}</span><span class="pct">{mission_pct}%</span></div>
        <div class="mission-bar">{bar_html}</div>
        <div class="mission-sub">{e(mission_sub)}</div>
      </div>
      <div class="divider"></div>
      <div class="mission-tile">
        <div class="mission-label">Portfolio // Annualised Return</div>
        <div class="mission-hero">+20.0<span class="pct">% p.a.</span></div>
        <div class="mission-sub">Target // OWNER mandate // DXZ &euro;100k</div>
        <span class="mission-tag">UNCALIB // NO LIVE EVIDENCE</span>
      </div>
    </div>
  </div>

  <div class="col-right">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Heureka Leader</span>
      <span class="section-aux">{e(heureka_aux)}</span>
    </div>
    <div class="heureka">
      <div>
        <div class="heureka-id">{heureka_id}</div>
        <div class="heureka-slug">{heureka_slug}</div>
      </div>
      <div class="heureka-chips">{heureka_chips_html}</div>
      <div class="heureka-metric">
        <div>
          <div class="m-lbl">Phase Progress</div>
          <div class="m-val">{heureka_done}<span class="unit">/{heureka_total}</span></div>
        </div>
        <div>
          <div class="m-lbl">Pipeline % Complete</div>
          <div class="m-val">{heureka_pct}<span class="unit">%</span></div>
        </div>
      </div>
      <div class="heureka-next">
        <span class="arr">&#9656;</span>
        <span class="lbl">NEXT</span>
        <span class="act">{e(heureka_next_act)}</span>
      </div>
    </div>
  </div>

  <!-- 3. OWNER ATTENTION + AGENT STATUS -->
  <div class="col-left">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Owner Attention</span>
      <span class="section-aux">{attention_aux}</span>
    </div>
    <div class="attention">
      {attention_html_inner}
    </div>
  </div>

  <div class="col-right">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Agent Status</span>
      <span class="section-aux">Claude // Codex // MT5</span>
    </div>
    <div class="agent-status">
      <div class="agent-row">
        <span class="name">CLAUDE</span>
        <span class="agent-readout">
          <span class="v">{claude_act}</span><span class="k">ACT</span><span class="sep">&middot;</span>
          <span class="v">{review_q_count}</span><span class="k">QUE</span><span class="sep">&middot;</span>
          <span class="v">{claude_closed_today}</span><span class="k">CLOSED</span><span class="sep">&middot;</span>
          <span class="k">TOK</span> <span class="v">{e(claude_tok_str)}</span>
        </span>
      </div>
      <div class="agent-row">
        <span class="name">CODEX</span>
        <span class="agent-readout">
          <span class="v">{codex_act}</span><span class="k">ACT</span><span class="sep">&middot;</span>
          <span class="v">{q.get("builds_pending", 0)}</span><span class="k">QUE</span><span class="sep">&middot;</span>
          <span class="v">{codex_closed_today}</span><span class="k">CLOSED</span><span class="sep">&middot;</span>
          <span class="k">TOK</span> <span class="v">{e(codex_tok_str)}</span>
        </span>
      </div>
      <div class="agent-row">
        <span class="name">MT5</span>
        <span class="agent-readout">
          <span class="v">{mt5_act}</span><span class="k">/10 RUN</span><span class="sep">&middot;</span>
          <span class="v">{mt5_pend}</span><span class="k">PEND</span><span class="sep">&middot;</span>
          <span class="v">{mt5_done_today}</span><span class="k">DONE TODAY</span>
        </span>
      </div>
      <div class="agent-fleet">
        <div class="flbl">{e(fleet_label)}</div>
        <div class="fleet-row">{term_row_html}</div>
      </div>
    </div>
  </div>

  <!-- 4. PROFITABILITY NEXT ACTIONS -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Profitability // Next Actions</span>
      <span class="section-aux">{profit_aux}</span>
    </div>
    <table class="qm-table">
      <tr>
        <th>Action</th><th>EA</th><th>Lane</th><th>Symbol / Slug</th>
        <th>State</th><th>Next Gate</th><th>Note</th>
      </tr>
      {"".join(action_rows_html)}
    </table>
  </div>

  <!-- 5. PIPELINE FUNNEL -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Pipeline Funnel // SRC &rarr; Portfolio</span>
      <span class="section-aux">Drop-Off Rates Per Stage</span>
    </div>
    <div class="funnel">
      {funnel_html_inner}
    </div>
  </div>

  <!-- 6. RECENT EVENTS -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Recent Events // Telemetry Tail</span>
      <span class="section-aux">Last 10 // UTC</span>
    </div>
    <div class="events">
      {"".join(events_html_rows)}
    </div>
  </div>

  <!-- 7. DAILY CONTROLLING -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Daily Controlling // Throughput &amp; Anomalies</span>
      <span class="section-aux">Today // Yesterday // 7D // 30D</span>
    </div>
    <div class="control">
      <div class="control-col">
        <div class="col-lbl">TODAY // {e(today_date)}</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val">{cw["today"]["mt5_items"]}</div>
          <div class="s-sub">{cw["today"]["mt5_eas"]} EAs touched</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates</div>
          <div class="s-val">{cw["today"]["analysis_items"]}</div>
          <div class="s-sub">{cw["today"]["analysis_eas"]} EAs reviewed</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Anomalies</div>
          <div class="s-val">{anom_today_total}</div>
          <div class="s-sub">zero-trade // invalid</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">YESTERDAY // {e(yesterday_date)}</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val dim">{cw["yesterday"]["mt5_items"]}</div>
          <div class="s-sub">{cw["yesterday"]["mt5_eas"]} EAs touched</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates</div>
          <div class="s-val dim">{cw["yesterday"]["analysis_items"]}</div>
          <div class="s-sub">{cw["yesterday"]["analysis_eas"]} EAs reviewed</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Anomalies</div>
          <div class="s-val dim">{cw["yesterday"]["fail_invalid"]}</div>
          <div class="s-sub">fail / invalid yesterday</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">7-DAY AVG // PER DAY</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items / day</div>
          <div class="s-val">{mt5_7d_avg}</div>
          <div class="s-sub">{mt5_7d_total} 7d total</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates / day</div>
          <div class="s-val">{analysis_7d_avg}</div>
          <div class="s-sub">{analysis_7d_total} 7d total</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Fail/Invalid / day</div>
          <div class="s-val">{fail_7d_avg}</div>
          <div class="s-sub">{fail_7d_total} 7d // pre-screen</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">30-DAY TOTAL</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val">{mt5_30d}</div>
          <div class="s-sub">{cw["30d"]["mt5_eas"]} distinct EAs</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Q02 PASS Cum</div>
          <div class="s-val">{q02_pass_30d}</div>
          <div class="s-sub">{int(100 * q02_pass_30d / max(1, mt5_30d))}% of {mt5_30d} backtests</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Anomalies</div>
          <div class="s-val">{cw["30d"]["fail_invalid"]}</div>
          <div class="s-sub">{anom["zero_trade_like"]} zero // {anom["invalid"]} invalid</div>
        </div>
      </div>
    </div>
  </div>

  <!-- 8. BOTTOM BAR -->
  <div class="botbar">
    <div><span class="key">Next Refresh</span><span class="val">30S</span></div>
    <div class="center"><span class="key">Renderer</span><span class="val">v5.0 // STEEL-EMERALD</span></div>
    <div class="right"><span class="key">Build</span><span class="val">SHA {e(build_sha)}</span></div>
  </div>

</div>
'''
        + '\n</body></html>\n'
    )
    COCKPIT.write_text(html_doc, encoding="utf-8")
    print(f"cockpit written: {COCKPIT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
