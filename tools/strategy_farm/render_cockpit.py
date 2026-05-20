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
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"

PIPELINE_STAGES = ["Card", "Build", "Review", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "Live"]
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
    "P3.5": "P3",
    "P5b": "P5",
    "P5c": "P5",
}


def claude_token_usage() -> dict:
    """Sum input/output/cache tokens across all claude streams in 5h window.

    Claude's rate_limit_event only has allowed/blocked status, no usage
    percentage. To estimate budget consumption: aggregate `usage` blocks
    from every assistant message in autonomous_wake_*.jsonl AND
    claude_*.live.log files modified in the last 5 hours.

    Returns: {events, input, output, cache_create, cache_read, total,
    billable} where billable = input+output+cache_create (cache_read is
    Anthropic-discounted ~10x).
    """
    now = dt.datetime.now().timestamp()
    five_hr_start = now - 5 * 3600
    totals = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0, "events": 0}
    streams = (
        list(LOG_DIR.glob("autonomous_wake_*.jsonl"))
        + list(LOG_DIR.glob("claude_research_*.live.log"))
        + list(LOG_DIR.glob("claude_review_*.live.log"))
        + list(LOG_DIR.glob("claude_g0_*.live.log"))
    )
    for f in streams:
        try:
            if f.stat().st_mtime < five_hr_start:
                continue
            for line in f.read_text(encoding="utf-8", errors="ignore").splitlines():
                if '"type":"assistant"' not in line or '"usage"' not in line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                usage = (o.get("message") or {}).get("usage") or {}
                if not usage:
                    continue
                totals["input"]        += int(usage.get("input_tokens") or 0)
                totals["output"]       += int(usage.get("output_tokens") or 0)
                totals["cache_read"]   += int(usage.get("cache_read_input_tokens") or 0)
                totals["cache_create"] += int(usage.get("cache_creation_input_tokens") or 0)
                totals["events"]       += 1
        except Exception:
            continue
    totals["total"] = totals["input"] + totals["output"] + totals["cache_read"] + totals["cache_create"]
    totals["billable"] = totals["input"] + totals["output"] + totals["cache_create"]
    return totals


def claude_quota() -> dict:
    """Parse latest rate_limit_event from claude jsonl streams.

    Reads the newest claude jsonl (autonomous_wake, claude_research,
    claude_review, claude_g0) and extracts the most recent rate_limit_event.
    Returns: {status, resetsAt (epoch), reset_in_min, rateLimitType,
    isUsingOverage, source_log}.
    """
    out = {"status": "unknown", "source_log": None}
    candidates = sorted(
        list(LOG_DIR.glob("autonomous_wake_*.jsonl"))
        + list(LOG_DIR.glob("claude_research_*.live.log"))
        + list(LOG_DIR.glob("claude_review_*.live.log"))
        + list(LOG_DIR.glob("claude_g0_*.live.log")),
        key=lambda p: p.stat().st_mtime if p.exists() else 0,
        reverse=True,
    )
    for p in candidates[:5]:
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
            # Scan lines reverse — pick the LAST rate_limit_event
            for line in reversed(text.splitlines()):
                if "rate_limit_event" not in line:
                    continue
                # Extract the embedded JSON
                idx = line.find("{")
                if idx < 0:
                    continue
                try:
                    obj = json.loads(line[idx:])
                except Exception:
                    continue
                rl = obj.get("rate_limit_info") or {}
                if not rl:
                    continue
                resets_at = rl.get("resetsAt")
                reset_in = None
                if isinstance(resets_at, (int, float)):
                    delta = int(resets_at) - int(dt.datetime.now().timestamp())
                    reset_in = max(0, delta) // 60
                out = {
                    "status": rl.get("status", "?"),
                    "resetsAt": resets_at,
                    "reset_in_min": reset_in,
                    "rateLimitType": rl.get("rateLimitType", "?"),
                    "isUsingOverage": rl.get("isUsingOverage", False),
                    "overageStatus": rl.get("overageStatus", "?"),
                    "source_log": p.name,
                    "event_age_sec": int(dt.datetime.now().timestamp() - p.stat().st_mtime),
                }
                return out
        except Exception:
            continue
    return out


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


def codex_quota() -> dict:
    """Estimate codex token burn from recent codex_build live logs.

    Each codex build emits a final `tokens used\\nN,NNN` line. Aggregate
    over codex_build_*.live.log files modified in the last 5 hours (the
    Codex ChatGPT subscription window). Returns: {total_tokens_5h,
    builds_5h, builds_24h, avg_tokens_per_build}.
    """
    out = {"total_tokens_5h": 0, "builds_5h": 0, "builds_24h": 0, "avg_tokens_per_build": 0}
    now = dt.datetime.now().timestamp()
    five_hr = now - 5 * 3600
    one_day = now - 24 * 3600
    builds_5h_tokens: list[int] = []
    builds_24h = 0
    for log in LOG_DIR.glob("codex_build_*.live.log"):
        try:
            mtime = log.stat().st_mtime
            if mtime < one_day:
                continue
            builds_24h += 1
            if mtime < five_hr:
                continue
            text = log.read_text(encoding="utf-8", errors="ignore")
            # Find "tokens used\nN" pattern
            m = re.search(r"tokens\s+used\s*\n\s*([\d,]+)", text)
            if m:
                n = int(m.group(1).replace(",", ""))
                builds_5h_tokens.append(n)
        except Exception:
            continue
    if builds_5h_tokens:
        out["total_tokens_5h"] = sum(builds_5h_tokens)
        out["builds_5h"] = len(builds_5h_tokens)
        out["avg_tokens_per_build"] = sum(builds_5h_tokens) // len(builds_5h_tokens)
    out["builds_24h"] = builds_24h
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


def pipeline_backlog_snapshot() -> dict:
    """Read-only backlog counters for the cockpit."""
    out = {
        "sources": {"pending": 0, "cards_ready": 0, "done": 0},
        "pass_by_phase": [],
        "pass_total": 0,
        "p4plus_pass_total": 0,
        "p8_pass_total": 0,
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
    backlog = pipeline_backlog_snapshot()
    heureka = compute_heureka_leader(pipeline)
    claude_q = claude_quota()
    claude_usage = claude_token_usage()
    codex_q = codex_quota()
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

    # --- Pipeline backlog ---
    def metric_tile(label: str, value: int, sub: str = "", accent: str = "var(--qm-text)") -> str:
        sub_html = f'<div class="backlog-sub">{html.escape(sub)}</div>' if sub else ""
        return (
            '<div class="backlog-metric">'
            f'<div class="backlog-label">{html.escape(label)}</div>'
            f'<div class="backlog-value mono" style="color:{accent}">{value}</div>'
            f'{sub_html}</div>'
        )

    def phase_chips(rows: list[dict], empty_label: str) -> str:
        if not rows:
            return f'<div class="backlog-empty">{empty_label}</div>'
        chips = []
        for r in rows:
            distinct = int(r.get("c") or 0)
            items = r.get("c_items")
            suffix = f' <span class="muted">({int(items)} runs)</span>' if items is not None else ""
            chips.append(
                f'<span class="backlog-chip"><b>{html.escape(str(r.get("phase") or "?"))}</b>'
                f'<span class="mono">{distinct}</span>{suffix}</span>'
            )
        return '<div class="backlog-chips">' + "".join(chips) + '</div>'

    sources = backlog["sources"]
    top_sources = backlog["top_sources"]
    if top_sources:
        top_sources_html = '<div class="backlog-list">' + "".join(
            f'<div class="backlog-source"><span class="mono prio">P{html.escape(str(s.get("priority") or 0))}</span>'
            f'<span>{html.escape(str(s.get("title") or "?")[:90])}</span></div>'
            for s in top_sources
        ) + '</div>'
    else:
        top_sources_html = '<div class="backlog-empty">no pending sources</div>'

    backlog_note = (
        f'<div class="backlog-error">{html.escape(backlog["error"])}</div>'
        if backlog.get("error") else ""
    )
    backlog_html = f'''
    <div class="backlog">
      <div class="backlog-grid">
        {metric_tile("Sources pending", sources.get("pending", 0), "awaiting extraction", "var(--promising)")}
        {metric_tile("Cards ready", sources.get("cards_ready", 0), "ready for EA build", "var(--em-l)")}
        {metric_tile("Sources done", sources.get("done", 0), "completed source intake", "var(--qm-text-dim)")}
        {metric_tile("Screening PASS", backlog["pass_total"], "distinct EAs with any PASS", "var(--em)")}
        {metric_tile("P4+ PASS", backlog["p4plus_pass_total"], "OOS-or-later candidates", "var(--live)")}
        {metric_tile("P8 PASS", backlog["p8_pass_total"], "portfolio-ready candidates", "var(--em-l)")}
        {metric_tile("P4 blocked", backlog["p4_pending_implementation"], "pending implementation rows", "var(--promising)")}
        {metric_tile("Work items now", backlog["work_active_total"], "active / pending / claimed", "var(--live)")}
      </div>
      <div class="backlog-detail">
        <div class="backlog-panel">
          <div class="backlog-panel-title">PASS by phase</div>
          {phase_chips(backlog["pass_by_phase"], "no PASS work_items")}
        </div>
        <div class="backlog-panel">
          <div class="backlog-panel-title">Active / pending work_items by phase</div>
          {phase_chips(backlog["work_active_by_phase"], "no active or pending work_items")}
        </div>
        <div class="backlog-panel">
          <div class="backlog-panel-title">Top pending sources</div>
          {top_sources_html}
        </div>
      </div>
      {backlog_note}
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

    # === Heureka tile HTML ===
    if heureka:
        # Render 11 stages with done/current/idle styling
        stages_chips = []
        for i, st in enumerate(PIPELINE_STAGES):
            cls = ""
            if i < heureka["current_stage_idx"]:
                cls = "done"
            elif i == heureka["current_stage_idx"]:
                cls = "current"
            stages_chips.append(f'<div class="heureka-stage {cls}">{st}</div>')
        stages_html_inner = "".join(stages_chips)
        leader_inner = (
            f'<span class="muted">Active</span> '
            f'<code>{html.escape(heureka["ea_id"])}</code> '
            f'<span class="slug">{html.escape(heureka["slug"][:36])}</span> '
            f'<span class="arrow">·</span> '
            f'<span>at <strong style="color:var(--live)">{html.escape(heureka["current_stage"])}</strong></span> '
            f'<span class="arrow">→</span> '
            f'<span class="next">next <strong>{html.escape(heureka["next_stage"])}</strong></span>'
        )
        heureka_html = f"""
<div class="heureka">
  <div class="heureka-head">
    <span class="heureka-title">Heureka · first live EA</span>
    <span class="heureka-meter">
      <span class="num">{heureka["completed_count"]}</span><span class="tot">/{heureka["total_stages"]}</span>
      <span class="pct">· {heureka["pct"]}%</span>
    </span>
  </div>
  <div class="heureka-stages">{stages_html_inner}</div>
  <div class="heureka-leader">{leader_inner}</div>
</div>"""
    else:
        heureka_html = (
            '<div class="heureka"><div class="heureka-head">'
            '<span class="heureka-title">Heureka · first live EA</span></div>'
            '<div class="heureka-leader heureka-leader-empty">'
            'no EA in flight · pump research → G0 approve → Codex build</div></div>'
        )

    # === Tokens panel HTML ===
    cq = claude_q
    cxq = codex_q
    claude_reset = f'{cq.get("reset_in_min", "?")} min' if cq.get("reset_in_min") is not None else "?"
    claude_status_class = "ok" if cq.get("status") == "allowed" else "fail"
    codex_tokens_k = f'{cxq["total_tokens_5h"]//1000}K' if cxq["total_tokens_5h"] else "0"
    cu = claude_usage
    billable_m = cu["billable"] / 1_000_000  # millions
    cache_read_m = cu["cache_read"] / 1_000_000
    # Heuristic budget thresholds — Anthropic doesn't publish exact 5h Pro/Max
    # limits, but observation: Claude Pro ~225K-450K billable / 5h, Max 5x
    # ~1-2M, Max 20x ~5-10M. OWNER has subscription Abo.
    # Color tiers based on billable absolute:
    if billable_m > 8.0:
        billable_class = "fail"
    elif billable_m > 3.0:
        billable_class = "warn"
    else:
        billable_class = "ok"
    # --- Real-quota overlay row (from Tampermonkey snapshot if fresh) ---
    def _pct_class(p):
        if p is None: return "ok"
        if p >= 85: return "fail"
        if p >= 60: return "warn"
        return "ok"
    def _snap_card(src_key: str, label: str) -> str:
        s = qsnap.get(src_key)
        if not s:
            return (
                f'<div class="token-card snap-stale">'
                f'<div class="token-label">{label} · live %</div>'
                f'<div class="token-value muted">—</div>'
                f'<div class="token-sub">install Tampermonkey scraper</div>'
                f'</div>'
            )
        hp, wp = s.get("hour_pct"), s.get("week_pct")
        age = s.get("age_sec")
        fresh = s.get("fresh")
        fresh_label = (
            f'{age}s ago' if (age is not None and age < 90)
            else (f'{age//60}m ago' if age is not None else 'no ts')
        )
        if hp is None and wp is None:
            body_val = '<span class="muted">no %</span>'
            sub = f'snapshot present · {fresh_label} · DOM scrape did not match'
        else:
            parts = []
            if hp is not None:
                parts.append(f'<span class="{_pct_class(hp)}">{hp:.0f}%</span><span class="muted"> /5h</span>')
            if wp is not None:
                parts.append(f'<span class="{_pct_class(wp)}">{wp:.0f}%</span><span class="muted"> /wk</span>')
            body_val = ' · '.join(parts)
            sub_bits = []
            if s.get("plan"):
                sub_bits.append(html.escape(s["plan"]))
            if s.get("hour_reset"):
                sub_bits.append(f'5h→{html.escape(str(s["hour_reset"]))}')
            if s.get("week_reset"):
                sub_bits.append(f'wk→{html.escape(str(s["week_reset"]))}')
            sub_bits.append(fresh_label + ('' if fresh else ' · stale'))
            sub = ' · '.join(sub_bits)
        return (
            f'<div class="token-card{"" if fresh else " snap-stale"}">'
            f'<div class="token-label">{label} · live %</div>'
            f'<div class="token-value">{body_val}</div>'
            f'<div class="token-sub">{sub}</div>'
            f'</div>'
        )
    snap_row = (
        '<div class="tokens snap-row">'
        + _snap_card("claude", "Claude")
        + _snap_card("codex", "Codex")
        + '</div>'
    )

    # 7-day trend chart — small inline SVG histogram per metric
    def _trend_bars(metric_key: str, label: str, color: str) -> str:
        # Build last-7-day series
        today_local = dt.date.today()
        days = [(today_local - dt.timedelta(days=i)).isoformat() for i in range(6, -1, -1)]
        values = [int((trend.get(d) or {}).get(metric_key, 0)) for d in days]
        max_v = max(values) if values else 0
        bars = []
        for i, (d, v) in enumerate(zip(days, values)):
            h = max(2, int(36 * v / max_v)) if max_v > 0 else 2
            day_label = d[-2:]  # last 2 chars of date "DD"
            bars.append(
                f'<div class="trend-bar-wrap" title="{html.escape(d)}: {v}">'
                f'<div class="trend-bar" style="height:{h}px;background:{color}"></div>'
                f'<div class="trend-bar-num">{v}</div>'
                f'<div class="trend-bar-day">{day_label}</div>'
                f'</div>'
            )
        total = sum(values)
        return (
            f'<div class="trend-card">'
            f'<div class="trend-label">{label}</div>'
            f'<div class="trend-row">{"".join(bars)}</div>'
            f'<div class="trend-foot">7-day total: <b>{total}</b></div>'
            f'</div>'
        )
    if trend:
        trend_html = (
            '<div class="trends">'
            + _trend_bars("approved", "Cards approved/day", "#10b981")
            + _trend_bars("_p2_pass", "P2 PASS/day", "#06b6d4")
            + _trend_bars("_p3_pass", "P3 PASS/day", "#34d399")
            + _trend_bars("build_blocked_by_codex_review", "Codex pre-review blocks/day", "#f59e0b")
            + '</div>'
        )
    else:
        trend_html = '<div class="trends-empty">no trend data yet</div>'

    # Health banner — reads state/health.json written by farmctl health.
    # If overall=FAIL → red banner with list of FAILing checks + action hints.
    # If WARN → yellow banner.  If OK → green compact "all clear" pill.
    if health.get("overall"):
        ov = health["overall"]
        summ = health.get("summary", {})
        checks = health.get("checks", [])
        checked_at = health.get("checked_at", "")
        if ov == "FAIL":
            fails = [c for c in checks if c.get("status") == "FAIL"]
            fail_lines = "".join(
                f'<div class="health-item"><span class="health-name">{html.escape(c["name"])}</span>: '
                f'<span class="health-detail">{html.escape(c["detail"][:160])}</span>'
                + (f' <span class="health-hint">→ {html.escape(c["action_hint"][:140])}</span>' if c.get("action_hint") else '')
                + '</div>'
                for c in fails
            )
            health_banner_html = (
                f'<div class="health-banner health-fail">'
                f'<div class="health-head">PIPELINE HEALTH · {summ.get("fail",0)} FAIL · {summ.get("warn",0)} WARN · {summ.get("ok",0)} OK'
                f'<span class="health-ts">{html.escape(checked_at)}</span></div>'
                f'{fail_lines}'
                f'</div>'
            )
        elif ov == "WARN":
            warns = [c for c in checks if c.get("status") == "WARN"]
            lines = "".join(
                f'<div class="health-item"><span class="health-name">{html.escape(c["name"])}</span>: '
                f'<span class="health-detail">{html.escape(c["detail"][:160])}</span></div>'
                for c in warns
            )
            health_banner_html = (
                f'<div class="health-banner health-warn">'
                f'<div class="health-head">PIPELINE HEALTH · {summ.get("warn",0)} WARN · {summ.get("ok",0)} OK'
                f'<span class="health-ts">{html.escape(checked_at)}</span></div>'
                f'{lines}'
                f'</div>'
            )
        else:
            health_banner_html = (
                f'<div class="health-banner health-ok">'
                f'PIPELINE HEALTH OK · all {summ.get("ok", 0)} invariants green '
                f'<span class="health-ts">{html.escape(checked_at)}</span>'
                f'</div>'
            )
    else:
        health_banner_html = (
            '<div class="health-banner health-warn">'
            'PIPELINE HEALTH: no snapshot · run <code>farmctl health</code> or wait for next 15-min cycle'
            '</div>'
        )

    tokens_html = f"""
{snap_row}
<div class="tokens">
  <div class="token-card">
    <div class="token-label">Claude · status</div>
    <div class="token-value {claude_status_class}">{html.escape(str(cq.get("status","?")).upper())}</div>
    <div class="token-sub">{html.escape(str(cq.get("rateLimitType","?")))} · resets in {claude_reset}</div>
  </div>
  <div class="token-card">
    <div class="token-label">Claude · 5h billable</div>
    <div class="token-value {billable_class}">{billable_m:.2f}M</div>
    <div class="token-sub">{cu['events']} events · cache_read {cache_read_m:.1f}M (≈free)</div>
  </div>
  <div class="token-card">
    <div class="token-label">Codex · 5h tokens</div>
    <div class="token-value ok">{codex_tokens_k}</div>
    <div class="token-sub">{cxq["builds_5h"]} builds · avg {cxq["avg_tokens_per_build"]//1000 if cxq['avg_tokens_per_build'] else 0}K each</div>
  </div>
  <div class="token-card">
    <div class="token-label">Codex · builds 24h</div>
    <div class="token-value">{cxq["builds_24h"]}</div>
    <div class="token-sub">incl. failed/blocked</div>
  </div>
</div>
<div class="token-detail">
  Claude 5h: input <code>{cu['input']:,}</code> · output <code>{cu['output']:,}</code> ·
  cache_create <code>{cu['cache_create']:,}</code> · cache_read <code>{cu['cache_read']:,}</code> ·
  TOTAL <code>{cu['total']:,}</code> tokens.
  Color: <span style="color:var(--em)">≤3M ok</span> ·
  <span style="color:var(--promising)">3-8M warn</span> ·
  <span style="color:var(--fail)">&gt;8M risk</span>
  (heuristic; resets at {dt.datetime.fromtimestamp(cq.get('resetsAt',0)).strftime('%H:%M') if cq.get('resetsAt') else '?'})
</div>"""

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

/* ===== PIPELINE BACKLOG ===== */
.backlog {{
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
  border-radius: 8px;
  padding: 12px 14px;
}}
.backlog-grid {{
  display: grid; grid-template-columns: repeat(6, 1fr);
  gap: 10px; margin-bottom: 12px;
}}
.backlog-metric {{
  background: var(--qm-surface-0);
  border: 1px solid var(--qm-border);
  border-radius: 6px; padding: 10px 12px;
}}
.backlog-label, .backlog-panel-title {{
  font-size: 9px; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.08em; color: var(--qm-text-muted);
}}
.backlog-value {{
  font-size: 24px; font-weight: 600; line-height: 1.1; margin-top: 5px;
}}
.backlog-sub {{
  font-family: var(--font-mono); font-size: 10px;
  color: var(--qm-text-subtle); margin-top: 3px;
}}
.backlog-detail {{
  display: grid; grid-template-columns: 1fr 1.2fr 1.4fr;
  gap: 10px;
}}
.backlog-panel {{
  border-top: 1px solid var(--qm-border);
  padding-top: 10px; min-width: 0;
}}
.backlog-panel-title {{ margin-bottom: 8px; }}
.backlog-chips {{ display: flex; flex-wrap: wrap; gap: 5px; }}
.backlog-chip {{
  display: inline-flex; align-items: center; gap: 7px;
  border: 1px solid var(--qm-border-strong);
  border-radius: 4px; padding: 3px 7px;
  background: var(--qm-surface-0);
  font-size: 10px; color: var(--qm-text-dim);
}}
.backlog-chip b {{ color: var(--qm-text); font-weight: 600; }}
.backlog-chip .mono {{ color: var(--em-l); }}
.backlog-list {{ display: flex; flex-direction: column; gap: 4px; }}
.backlog-source {{
  display: grid; grid-template-columns: 38px minmax(0, 1fr);
  gap: 8px; align-items: baseline;
  font-size: 11px; color: var(--qm-text-dim);
  border-bottom: 1px solid var(--qm-border);
  padding-bottom: 4px;
}}
.backlog-source:last-child {{ border-bottom: none; }}
.backlog-source span:last-child {{
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}}
.backlog-source .prio {{ color: var(--promising); font-size: 10px; }}
.backlog-empty {{
  font-style: italic; font-size: 11px; color: var(--qm-text-subtle);
}}
.backlog-error {{
  margin-top: 10px; padding: 7px 9px; border-radius: 4px;
  border: 1px solid rgba(239,68,68,0.3);
  background: rgba(239,68,68,0.06);
  color: var(--fail); font-family: var(--font-mono); font-size: 10px;
}}

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

/* === Heureka tile === */
.heureka {{
  background: linear-gradient(135deg, rgba(16,185,129,0.06) 0%, rgba(15,23,42,0.5) 100%);
  border: 1px solid rgba(16,185,129,0.2);
  border-radius: 14px;
  padding: 18px 22px;
  margin: 16px 0 14px 0;
  position: relative;
  overflow: hidden;
}}
.heureka::before {{
  content:''; position:absolute; top:-50%; right:-15%;
  width:300px; height:300px; border-radius:50%;
  background: radial-gradient(circle, var(--em-glow) 0%, transparent 65%);
  filter: blur(70px); pointer-events: none;
}}
.heureka-head {{
  display: flex; align-items: baseline; gap: 12px;
  margin-bottom: 12px; position: relative; z-index: 1;
}}
.heureka-title {{
  font-size: 10px; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.12em; color: var(--em);
}}
.heureka-meter {{
  font-family: var(--font-mono); font-weight: 600;
  letter-spacing: 0.5px;
}}
.heureka-meter .num {{ color: var(--em); font-size: 14px; }}
.heureka-meter .tot {{ color: var(--qm-text-muted); font-size: 11px; }}
.heureka-meter .pct {{ color: var(--qm-text-dim); font-size: 11px; margin-left: 6px; }}
.heureka-stages {{
  display: flex; gap: 4px; margin-bottom: 12px;
  position: relative; z-index: 1;
}}
.heureka-stage {{
  flex: 1; min-width: 40px; padding: 7px 4px;
  border: 1px solid var(--qm-border); border-radius: 6px;
  background: rgba(15,23,42,0.5);
  text-align: center; font-size: 9px; font-weight: 600;
  color: var(--qm-text-subtle); text-transform: uppercase;
  letter-spacing: 0.08em;
  font-family: var(--font-mono);
}}
.heureka-stage.done {{
  background: var(--em-s); border-color: rgba(16,185,129,0.45);
  color: var(--em);
}}
.heureka-stage.current {{
  background: rgba(6,182,212,0.12); border-color: rgba(6,182,212,0.5);
  color: var(--live); box-shadow: 0 0 8px rgba(6,182,212,0.3);
}}
.heureka-leader {{
  display: flex; align-items: center; gap: 14px; flex-wrap: wrap;
  font-family: var(--font-mono); font-size: 12px;
  color: var(--qm-text-dim); position: relative; z-index: 1;
  padding-top: 10px; border-top: 1px solid var(--qm-border);
}}
.heureka-leader code {{ color: var(--em); font-weight: 600; font-size: 13px; }}
.heureka-leader .slug {{ color: var(--qm-text-muted); }}
.heureka-leader .arrow {{ color: var(--qm-text-faint); }}
.heureka-leader .next strong {{ color: var(--em); }}
.heureka-leader-empty {{
  font-style: italic; color: var(--qm-text-muted); font-size: 12px;
}}

/* === Token panel === */
.tokens {{
  display: grid; grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 12px; margin-bottom: 18px;
}}
.token-card {{
  background: var(--qm-surface-1); border: 1px solid var(--qm-border);
  border-radius: 8px; padding: 10px 14px;
}}
.token-label {{
  font-size: 9px; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.1em; color: var(--qm-text-muted); margin-bottom: 6px;
}}
.token-value {{
  font-family: var(--font-mono); font-size: 18px; font-weight: 600;
  color: var(--qm-text); letter-spacing: -0.01em;
}}
.token-value.ok {{ color: var(--em); }}
.token-value.warn {{ color: var(--promising); }}
.token-value.fail {{ color: var(--fail); }}
.token-sub {{
  font-family: var(--font-mono); font-size: 10px;
  color: var(--qm-text-muted); margin-top: 4px;
}}
.token-detail {{
  font-family: var(--font-mono); font-size: 10.5px;
  color: var(--qm-text-muted); padding: 8px 14px;
  border: 1px dashed var(--qm-border);
  border-radius: 6px; margin-bottom: 18px;
}}
.token-detail code {{
  background: var(--qm-surface-0); padding: 1px 4px;
  border-radius: 3px; color: var(--qm-text-dim);
}}
.tokens.snap-row {{
  grid-template-columns: 1fr 1fr;
  margin-bottom: 10px;
}}
.tokens.snap-row .token-card {{
  border-color: var(--em);
  background: linear-gradient(180deg, var(--em-s) 0%, var(--qm-surface-1) 60%);
}}
.tokens.snap-row .token-card.snap-stale {{
  border-color: var(--qm-border);
  background: var(--qm-surface-1);
  opacity: 0.65;
}}
.tokens.snap-row .token-value {{ font-size: 22px; }}
.tokens.snap-row .token-value .ok {{ color: var(--em); }}
.tokens.snap-row .token-value .warn {{ color: var(--promising); }}
.tokens.snap-row .token-value .fail {{ color: var(--fail); }}
.tokens.snap-row .token-value .muted {{ color: var(--qm-text-muted); font-size: 12px; font-weight: 400; }}

/* === Pipeline health banner === */
.health-banner {{
  border-radius: 8px; padding: 10px 14px; margin: 0 0 14px 0;
  border: 1px solid var(--qm-border-strong); font-family: var(--font-mono);
  font-size: 11px;
}}
.health-banner.health-fail {{
  border-color: var(--fail); background: rgba(239,68,68,0.08);
}}
.health-banner.health-warn {{
  border-color: var(--promising); background: rgba(245,158,11,0.06);
}}
.health-banner.health-ok {{
  border-color: var(--em); background: rgba(16,185,129,0.06);
  color: var(--em-l);
}}
.health-head {{
  font-weight: 700; font-size: 11px; letter-spacing: 0.04em;
  text-transform: uppercase; margin-bottom: 6px;
  display: flex; justify-content: space-between; align-items: center;
}}
.health-fail .health-head {{ color: var(--fail); }}
.health-warn .health-head {{ color: var(--promising); }}
.health-ts {{ color: var(--qm-text-muted); font-weight: 400; }}
.health-item {{ padding: 3px 0; line-height: 1.55; }}
.health-name {{ color: var(--qm-text); font-weight: 600; }}
.health-detail {{ color: var(--qm-text-dim); }}
.health-hint {{ color: var(--qm-text-muted); font-style: italic; }}

/* === 7-day trend dashboard === */
.trends {{
  display: grid; grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 10px; margin: 0 0 18px 0;
}}
.trend-card {{
  background: var(--qm-surface-1); border: 1px solid var(--qm-border);
  border-radius: 8px; padding: 10px 12px;
}}
.trend-label {{
  font-size: 9px; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.08em; color: var(--qm-text-muted); margin-bottom: 8px;
}}
.trend-row {{
  display: flex; align-items: flex-end; gap: 4px; height: 56px;
}}
.trend-bar-wrap {{
  flex: 1; display: flex; flex-direction: column; align-items: center;
}}
.trend-bar {{
  width: 100%; border-radius: 2px 2px 0 0; min-height: 2px;
}}
.trend-bar-num {{
  font-family: var(--font-mono); font-size: 9px;
  color: var(--qm-text-muted); margin-top: 2px;
}}
.trend-bar-day {{
  font-family: var(--font-mono); font-size: 8px;
  color: var(--qm-text-subtle);
}}
.trend-foot {{
  font-family: var(--font-mono); font-size: 10px;
  color: var(--qm-text-muted); margin-top: 6px;
}}
.trends-empty {{ font-size: 10px; color: var(--qm-text-muted); margin-bottom: 18px; }}
</style></head>
<body>

<div class="top">
  <div class="brand">Quant<span class="accent">Mechanica</span></div>
  <div class="timestamp">{now_full}</div>
  <span class="sev-msg">{html.escape(msg)}</span>
  <span class="sev-tag">{sev_label}</span>
</div>

{health_banner_html}

{trend_html}

{heureka_html}

{tokens_html}

<div class="hero">
  {hero_claude}
  {hero_codex}
  {hero_mt5}
</div>

<div class="section-title">Pipeline flow</div>
{flow_html}

<div class="section-title">Queues</div>
{queue_html}

<div class="section-title">Pipeline backlog</div>
{backlog_html}

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
