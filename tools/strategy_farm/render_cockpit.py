"""QM strategy_farm cockpit — visual "what's happening NOW" dashboard.

Renders D:/QM/strategy_farm/dashboards/cockpit.html every 2 min.
Layout designed for OWNER's three primary questions (OWNER rework call 2026-07-07):
  1. Is real money OK?          → LIVE MONEY row (DXZ book pulse + FTMO trial pulse)
  2. What must I (OWNER) decide? → OWNER DECISIONS (curated feed + Q12 pool;
                                    agent work queues are NOT owner decisions)
  3. Is the factory running?     → AGENT STATUS + health pill (CRITICAL only
                                    when the factory itself is down)

Visual hierarchy:
  TOPBAR  — health pill; message names the failing factory check when not NOMINAL
  MONEY   — DXZ live book / FTMO trial / next OWNER gate / mission target
  DECIDE  — OWNER DECISIONS (left) + AGENT STATUS incl. T1-T10 fleet (right)
  COMPANY — frontier tiles, per-phase pipeline progress, funnel, daily controlling

Removed 2026-07-07 (OWNER): Recent Events tail (all-red noise), Q08 Portfolio
Rescue table, Heureka leader + Next Actions (stale task-table derivations that
contradicted the Q12 frontier).

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
REPORTS_STATE = Path(r"D:\QM\reports\state")
LIVE_BOOK_PULSE = REPORTS_STATE / "live_book_pulse.json"
FTMO_TRIAL_PULSE = REPORTS_STATE / "ftmo_trial_pulse.json"
OWNER_DECISIONS_FILE = REPORTS_STATE / "owner_decisions.json"

PHASE_DISPLAY = {
    "Q01": "Q01",
    "Q02": "Q02",
    "Q03": "Q03",
    "Q04": "Q04",
    "Q05": "Q05",
    "Q06": "Q06",
    "Q07": "Q07",
    "Q08": "Q08",
    "Q09": "Q09",
    "Q10": "Q10",
    "Q11": "Q11",
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
        # quota_pull.py (headless API pull) writes a structured block with USED %
        # already extracted — prefer it over the legacy DOM text-parse path.
        structured = data.get("structured") or {}
        text = data.get("full_text_head") or ""
        parsed = _parse_codex_text(text) if src == "codex" else _parse_claude_text(text)

        def _pick(key):
            v = structured.get(key)
            return v if v is not None else parsed.get(key)

        out[src] = {
            "fresh": age_sec is not None and age_sec <= 300,
            "age_sec": age_sec,
            "hour_pct": _pick("hour_pct"),
            "week_pct": _pick("week_pct"),
            "hour_reset": _pick("hour_reset"),
            "week_reset": _pick("week_reset"),
            "sonnet_pct": _pick("sonnet_pct"),
            "plan": structured.get("plan") or parsed.get("plan") or matches.get("plan_label"),
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


def _json_from_path(path_value: str | None) -> dict:
    if not path_value:
        return {}
    try:
        path = Path(path_value)
        if not path.exists():
            return {}
        data = json.loads(path.read_text(encoding="utf-8-sig", errors="ignore"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _json_payload(row: dict) -> dict:
    try:
        data = json.loads(row.get("payload_json") or "{}")
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _num(value, digits: int = 2) -> str:
    if isinstance(value, (int, float)):
        return f"{value:,.{digits}f}"
    return "--"


def _q08_tier(verdict: str, payload: dict) -> str:
    verdict = str(verdict or "").upper()
    if verdict in {"FAIL_SOFT", "FAIL_HARD", "INVALID"}:
        return verdict
    classification = payload.get("q08_verdict_classification") or payload.get("verdict_classification")
    if isinstance(classification, dict):
        vals = {str(v).upper() for v in classification.values()}
        if "EDGE_HARD" in vals:
            return "FAIL_HARD"
        if vals & {"EDGE_SOFT", "LOW_SAMPLE"}:
            return "FAIL_SOFT"
    return verdict or "--"


def _q08_reason(payload: dict) -> str:
    classification = payload.get("q08_verdict_classification") or payload.get("verdict_classification")
    if not isinstance(classification, dict):
        return str(payload.get("verdict_reason") or payload.get("reason") or "--")
    ranked = {"EDGE_HARD": 0, "EDGE_SOFT": 1, "LOW_SAMPLE": 2}
    items = [
        (ranked.get(str(tier).upper(), 9), str(gate), str(tier))
        for gate, tier in classification.items()
        if str(tier).upper() not in {"PASS", ""}
    ]
    if not items:
        return str(payload.get("verdict_reason") or "--")
    items.sort()
    return ", ".join(f"{gate}:{tier}" for _, gate, tier in items[:3])


def _q09_priority(row: dict | None) -> int:
    if not row:
        return 99
    verdict = str(row.get("verdict") or "").upper()
    status = str(row.get("status") or "").lower()
    if verdict == "PASS_PORTFOLIO":
        return 0
    if verdict == "FAIL_PORTFOLIO":
        return 1
    if verdict == "NEED_MORE_DATA":
        return 2
    if status == "pending":
        return 3
    return 9


def q08_portfolio_rescue_snapshot(limit: int = 8) -> dict:
    """Read-only Q08 portfolio-rescue state for the cockpit."""
    out = {
        "soft": 0,
        "hard": 0,
        "need_more_data": 0,
        "pending": 0,
        "pass_portfolio": 0,
        "fail_portfolio": 0,
        "candidates": 0,
        "rows": [],
    }
    try:
        q08_rows = db_rows(
            """
            SELECT ea_id, symbol, verdict, payload_json, evidence_path, updated_at
            FROM work_items
            WHERE phase='Q08' AND status='done'
              AND verdict IN ('FAIL_SOFT','FAIL_HARD','FAIL','INVALID')
            ORDER BY updated_at DESC
            """
        )
        q09_rows = db_rows(
            """
            SELECT ea_id, symbol, status, verdict, payload_json, evidence_path, updated_at
            FROM work_items
            WHERE phase='Q09_PORTFOLIO'
            ORDER BY updated_at DESC
            """
        )
    except sqlite3.Error:
        return out
    try:
        pc_rows = db_rows(
            """
            SELECT ea_id, symbol, state, evidence_path, updated_at
            FROM portfolio_candidates
            WHERE state='Q12_REVIEW_READY'
            ORDER BY updated_at DESC
            """
        )
    except sqlite3.Error:
        pc_rows = []

    latest_q08: dict[tuple[str, str], dict] = {}
    for row in q08_rows:
        key = (str(row.get("ea_id") or ""), str(row.get("symbol") or ""))
        if key not in latest_q08:
            latest_q08[key] = row

    latest_q09: dict[tuple[str, str], dict] = {}
    for row in q09_rows:
        key = (str(row.get("ea_id") or ""), str(row.get("symbol") or ""))
        if key not in latest_q09 or _q09_priority(row) < _q09_priority(latest_q09[key]):
            latest_q09[key] = row
        verdict = str(row.get("verdict") or "").upper()
        status = str(row.get("status") or "").lower()
        if status == "pending":
            out["pending"] += 1
        elif verdict == "NEED_MORE_DATA":
            out["need_more_data"] += 1
        elif verdict == "PASS_PORTFOLIO":
            out["pass_portfolio"] += 1
        elif verdict == "FAIL_PORTFOLIO":
            out["fail_portfolio"] += 1

    candidates = {(str(r.get("ea_id") or ""), str(r.get("symbol") or "")): r for r in pc_rows}
    out["candidates"] = len(candidates)

    display_rows = []
    for key, q08 in latest_q08.items():
        payload = {**_json_from_path(q08.get("evidence_path")), **_json_payload(q08)}
        tier = _q08_tier(str(q08.get("verdict") or ""), payload)
        if tier == "FAIL_SOFT":
            out["soft"] += 1
        elif tier == "FAIL_HARD":
            out["hard"] += 1
        q09 = latest_q09.get(key)
        q09_payload = _json_payload(q09) if q09 else {}
        q09_artifact = _json_from_path(q09.get("evidence_path") if q09 else None)
        display_rows.append({
            "ea_id": key[0],
            "symbol": key[1],
            "tier": tier,
            "reason": _q08_reason(payload),
            "q08_trades": payload.get("q08_n_trades") or q09_payload.get("q08_trade_count"),
            "q09_verdict": (q09.get("verdict") if q09 else None) or ("PENDING" if q09 else "--"),
            "portfolio_only": bool(q09_payload.get("portfolio_only") or key in candidates),
            "candidate_state": (candidates.get(key) or {}).get("state") or q09_payload.get("portfolio_candidate_state") or "",
            "corr": q09_artifact.get("max_corr_to_book"),
            "sharpe_delta": (
                q09_artifact.get("sharpe_with") - q09_artifact.get("sharpe_without")
                if isinstance(q09_artifact.get("sharpe_with"), (int, float))
                and isinstance(q09_artifact.get("sharpe_without"), (int, float))
                else None
            ),
            "maxdd_delta": (
                q09_artifact.get("maxdd_with") - q09_artifact.get("maxdd_without")
                if isinstance(q09_artifact.get("maxdd_with"), (int, float))
                and isinstance(q09_artifact.get("maxdd_without"), (int, float))
                else None
            ),
            "pf": q09_artifact.get("standalone_pf"),
            "updated_at": q09.get("updated_at") if q09 else q08.get("updated_at"),
        })
    display_rows.sort(key=lambda r: (r.get("portfolio_only") is not True, r.get("updated_at") or ""), reverse=False)
    out["rows"] = sorted(display_rows, key=lambda r: r.get("updated_at") or "", reverse=True)[:limit]
    return out


def _age_minutes(iso_ts: str | None) -> int | None:
    if not iso_ts:
        return None
    try:
        t = dt.datetime.fromisoformat(str(iso_ts).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.timezone.utc)
        return max(0, int((dt.datetime.now(dt.timezone.utc) - t).total_seconds() // 60))
    except Exception:
        return None


def live_money_snapshot() -> dict:
    """Read-only DXZ live-book + FTMO trial pulse state for the LIVE MONEY row.

    Sources are the pulse artifacts (evidence chain: T_Live terminal logs →
    live_book_pulse.py, FTMO terminal → ftmo_trial_pulse), never manifests
    (manifest DRAFT/NONE is default output, OWNER rule 2026-07-01).
    """
    out: dict = {"dxz": None, "ftmo": None}
    try:
        lb = json.loads(LIVE_BOOK_PULSE.read_text(encoding="utf-8"))
        hb = lb.get("heartbeat") or {}
        tj = lb.get("terminal_journals") or {}
        at = tj.get("autotrading_transitions") or []
        be = (lb.get("ea_logs") or {}).get("book_equity") or {}
        out["dxz"] = {
            "verdict": str(lb.get("verdict") or "?").upper(),
            "alarms": len(lb.get("alarms") or []),
            "sleeves": tj.get("loaded_sleeve_count"),
            "equity": be.get("equity"),
            "day_pnl": be.get("day_pnl"),
            "positions": hb.get("current_position_count"),
            "autotrading": str((at[-1] or {}).get("state") or "?") if at else "?",
            "account": str(tj.get("account_id") or ""),
            "age_min": _age_minutes(lb.get("generated_at_utc")),
        }
    except Exception:
        pass
    try:
        ft = json.loads(FTMO_TRIAL_PULSE.read_text(encoding="utf-8"))
        out["ftmo"] = {
            "verdict": str(ft.get("verdict") or "?").upper(),
            "alarms": len(ft.get("alarms") or []) + len(ft.get("warns") or []),
            "equity": ft.get("equity"),
            "day_pnl": ft.get("day_pnl"),
            "day_loss_pct": ft.get("day_loss_pct"),
            "total_dd_pct": ft.get("total_dd_pct"),
            "magics_seen": ft.get("magics_seen"),
            "expected_magics": ft.get("expected_magics"),
            "terminal_up": bool(ft.get("terminal_up")),
            "age_min": _age_minutes(ft.get("checked_at_utc")),
        }
    except Exception:
        pass
    return out


def q12_review_ready_count() -> int:
    try:
        rows = db_rows(
            "SELECT COUNT(*) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'"
        )
        return int(rows[0]["c"]) if rows else 0
    except Exception:
        return 0


def owner_decision_rows(q12_count: int) -> list[dict]:
    """Genuine OWNER decisions only (OWNER call 2026-07-07).

    Sources, in order:
      1. Curated feed D:/QM/reports/state/owner_decisions.json (maintained by
         Claude; supports a literal "{q12_count}" placeholder).
      2. BLOCKED agent_tasks whose unblock condition names OWNER.
    Agent work queues (Claude reviews, ops-blocked tasks, router SLAs) are
    agent status — they never belong in this panel.
    """
    rows: list[dict] = []
    try:
        data = json.loads(OWNER_DECISIONS_FILE.read_text(encoding="utf-8"))
        for item in data.get("items") or []:
            detail = str(item.get("detail") or "").replace("{q12_count}", str(q12_count))
            rows.append({
                "cat": str(item.get("cat") or "DECISION")[:16],
                "title": str(item.get("title") or "?")[:52],
                "detail": detail[:74],
                "due": str(item.get("due") or ""),
                "alert": str(item.get("severity") or "").lower() == "alert",
            })
    except Exception:
        pass
    if not any(r["cat"] == "ADMISSION" for r in rows) and q12_count:
        rows.append({
            "cat": "ADMISSION",
            "title": f"{q12_count} candidates Q12_REVIEW_READY",
            "detail": "portfolio admission is an OWNER gate",
            "due": "",
            "alert": False,
        })
    try:
        blocked = db_rows(
            "SELECT id, task_type, verdict, updated_at FROM agent_tasks "
            "WHERE state='BLOCKED' AND verdict LIKE '%OWNER%' "
            "ORDER BY updated_at DESC LIMIT 6"
        )
    except Exception:
        blocked = []
    # A superseded/obsolete BLOCKED row is a closed matter that merely
    # mentions OWNER in its epitaph — not an open OWNER decision.
    blocked = [
        b for b in blocked
        if not re.search(r"supersed|obsolete", str(b.get("verdict") or ""), re.IGNORECASE)
    ][:3]
    for b in blocked:
        rows.append({
            "cat": "UNBLOCK",
            "title": f"{str(b.get('task_type') or 'task')} {str(b.get('id') or '')[:8]}",
            "detail": str(b.get("verdict") or "")[:74],
            "due": "",
            "alert": False,
        })
    return rows


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
    out["work_items_pending"] = sum(int(r.get("c") or 0) for r in wi if r.get("status") == "pending")
    out["work_items_active"] = sum(int(r.get("c") or 0) for r in wi if r.get("status") == "active")

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
              WHEN 'Q01' THEN 10 WHEN 'Q02' THEN 20 WHEN 'Q03' THEN 30
              WHEN 'Q04' THEN 40 WHEN 'Q05' THEN 50 WHEN 'Q06' THEN 60
              WHEN 'Q07' THEN 70 WHEN 'Q08' THEN 80 WHEN 'Q09' THEN 90
              WHEN 'Q10' THEN 100 WHEN 'Q11' THEN 110
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 40
              WHEN 'P4' THEN 50 WHEN 'P5' THEN 60 WHEN 'P5b' THEN 70
              WHEN 'P5c' THEN 80 WHEN 'P6' THEN 90 WHEN 'P7' THEN 100
              WHEN 'P8' THEN 110 ELSE 0 END
            """
        )
        pass_total = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS'"
        )
        out["pass_total"] = pass_total[0]["c"] if pass_total else 0
        p4plus = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items "
            "WHERE verdict='PASS' AND phase IN ('Q05','Q06','Q07','Q08','Q09','Q10','Q11','P4','P5','P5b','P5c','P6','P7','P8')"
        )
        out["p4plus_pass_total"] = p4plus[0]["c"] if p4plus else 0
        p8 = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS' AND phase IN ('Q11','P8')"
        )
        out["p8_pass_total"] = p8[0]["c"] if p8 else 0
        try:
            pc = db_rows("SELECT COUNT(DISTINCT ea_id) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'")
            out["portfolio_candidates_total"] = pc[0]["c"] if pc else 0
        except sqlite3.Error:
            out["portfolio_candidates_total"] = 0
        p4_pending = db_rows(
            "SELECT COUNT(*) AS c FROM work_items WHERE phase IN ('Q05','P4') AND verdict='PENDING_IMPLEMENTATION'"
        )
        out["p4_pending_implementation"] = p4_pending[0]["c"] if p4_pending else 0
        out["work_active_by_phase"] = db_rows(
            "SELECT phase, COUNT(*) AS c FROM work_items "
            """
            WHERE status IN ('active','pending','claimed') GROUP BY phase
            ORDER BY CASE phase
              WHEN 'Q01' THEN 10 WHEN 'Q02' THEN 20 WHEN 'Q03' THEN 30
              WHEN 'Q04' THEN 40 WHEN 'Q05' THEN 50 WHEN 'Q06' THEN 60
              WHEN 'Q07' THEN 70 WHEN 'Q08' THEN 80 WHEN 'Q09' THEN 90
              WHEN 'Q10' THEN 100 WHEN 'Q11' THEN 110
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 40
              WHEN 'P4' THEN 50 WHEN 'P5' THEN 60 WHEN 'P5b' THEN 70
              WHEN 'P5c' THEN 80 WHEN 'P6' THEN 90 WHEN 'P7' THEN 100
              WHEN 'P8' THEN 110 ELSE 0 END
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


def diagnose_bottleneck(procs: dict, q: dict, claude_workers: list, codex_workers: list) -> tuple[str, str]:
    mt5_backpressure = q.get("work_items_pending", 0) >= 1000 or q.get("work_items_active", 0) >= 10
    if q["builds_pending"] > 0 and len(codex_workers) == 0 and mt5_backpressure:
        return "ok", (
            f"{q['builds_pending']} build(s) queued; coding intentionally paused while MT5 drains "
            f"{q.get('work_items_pending', 0)} pending / {q.get('work_items_active', 0)} active work_items."
        )
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
    backlog = pipeline_backlog_snapshot()
    q08_rescue = q08_portfolio_rescue_snapshot()
    qsnap = quota_snapshot()
    money = live_money_snapshot()
    q12_count = q12_review_ready_count()

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
                WHERE phase IN ('Q02','P2') AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_q02_pass"] = r["c"]
            for r in con.execute("""
                SELECT DATE(updated_at) day, COUNT(*) c FROM work_items
                WHERE phase IN ('Q03','P3') AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_q03_pass"] = r["c"]
            con.close()
        except Exception:
            pass
        return days
    trend = _trend_data()

    def _daily_controlling_data() -> dict:
        mt5_phases = {
            "P2", "P3", "P4", "P5", "P5b", "P5c", "P6", "P8",
            "Q02", "Q03", "Q04", "Q05", "Q06", "Q08", "Q10", "Q11",
        }
        analysis_phases = {"P3.5", "P7", "Q07"}
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
                "zero_trade_like": 0,
                "invalid": 0,
                "waiting_input": 0,
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
            reason = str(payload.get("verdict_reason") or "")
            zero_trade_like = "MIN_TRADES_NOT_MET" in reason or "zero" in reason.lower()
            is_mt5 = phase in mt5_phases
            is_analysis = phase in analysis_phases
            for key, days in windows.items():
                if not in_window(day, key, days):
                    continue
                bucket = stats[key]
                if status in {"done", "failed"}:
                    bucket["done_items"] += 1
                    if is_mt5:
                        bucket["mt5_items"] += 1
                        if row.get("ea_id"):
                            bucket["mt5_eas"].add(row["ea_id"])
                    elif is_analysis:
                        bucket["analysis_items"] += 1
                        if row.get("ea_id"):
                            bucket["analysis_eas"].add(row["ea_id"])
                if verdict in {"FAIL", "INVALID"}:
                    bucket["fail_invalid"] += 1
                if zero_trade_like:
                    bucket["zero_trade_like"] += 1
                if verdict == "INVALID":
                    bucket["invalid"] += 1
                if verdict == "WAITING_INPUT":
                    bucket["waiting_input"] += 1
            if status in {"done", "failed"}:
                key = f"{PHASE_DISPLAY.get(phase, phase)} {verdict or status}"
                by_phase[key] = by_phase.get(key, {"count": 0})
                by_phase[key]["count"] += 1
            terminal = payload.get("terminal") or row.get("claimed_by")
            if terminal and is_mt5:
                by_terminal[str(terminal)] = by_terminal.get(str(terminal), 0) + 1
            if zero_trade_like:
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
    _fail_checks = [c for c in _checks if (c.get("status") or "").upper() == "FAIL"]
    _factory_fail_checks = [c for c in _fail_checks if c.get("name") in _FACTORY_DOWN_CHECKS]
    _factory_fail = bool(_factory_fail_checks)
    _any_fail = bool(_fail_checks)
    if _factory_fail:
        pill_label = "CRITICAL"; pill_class = "crit"
        # Topbar must explain the CRITICAL, not narrate the build queue —
        # a red pill next to "coding intentionally paused" is incoherent
        # (OWNER 2026-07-07).
        msg = " // ".join(
            f"{c.get('name')}: {str(c.get('detail'))[:90]}" for c in _factory_fail_checks[:2]
        )
    elif _any_fail and pill_class == "":
        pill_label = "WARN"; pill_class = "warn"
        msg = f"{_fail_checks[0].get('name')}: {str(_fail_checks[0].get('detail'))[:80]} // {msg}"
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

    # ---------- 2. LIVE MONEY ROW (OWNER rework 2026-07-07) ----------
    decisions = owner_decision_rows(q12_count)

    dxz = money.get("dxz") or {}
    ftmo = money.get("ftmo") or {}

    def _tile_cls(verdict: str, alarms: int, warn: bool = False) -> str:
        if not verdict or verdict == "?":
            return ""
        if verdict != "OK" or alarms:
            return "alert"
        return "warn" if warn else "ok"

    if dxz:
        _sleeves = dxz.get("sleeves")
        _eq = dxz.get("equity")
        dxz_val = (
            f"${_eq:,.0f}" if isinstance(_eq, (int, float))
            else (f"{_sleeves} SLEEVES" if _sleeves is not None else "PULSE?")
        )
        dxz_cls = _tile_cls(dxz.get("verdict", "?"), dxz.get("alarms", 0))
        _at = str(dxz.get("autotrading") or "?").upper()
        _pos = dxz.get("positions")
        _age = dxz.get("age_min")
        _dp = dxz.get("day_pnl")
        _slv = f"{_sleeves} sleeves // " if _sleeves is not None else ""
        _dpf = (
            f"day {'+' if isinstance(_dp, (int, float)) and _dp >= 0 else ''}{_dp:,.0f} // "
            if isinstance(_dp, (int, float)) else ""
        )
        dxz_sub = (
            f"acct {dxz.get('account') or '?'} // {_slv}AT {_at} // "
            f"{_dpf}{_pos if _pos is not None else '?'} open pos // "
            f"verdict {dxz.get('verdict', '?')} // pulse {_age}m ago" if _age is not None else
            f"acct {dxz.get('account') or '?'} // {_slv}AT {_at} // verdict {dxz.get('verdict', '?')}"
        )
    else:
        dxz_val, dxz_cls, dxz_sub = "NO PULSE", "alert", "live_book_pulse.json unreadable"

    if ftmo:
        _eq = ftmo.get("equity")
        ftmo_val = f"${_eq:,.0f}" if isinstance(_eq, (int, float)) else "PULSE?"
        _dl = ftmo.get("day_loss_pct")
        _dd = ftmo.get("total_dd_pct")
        _soft_warn = (isinstance(_dl, (int, float)) and _dl >= 3.5) or (
            isinstance(_dd, (int, float)) and _dd >= 6.0)
        ftmo_cls = _tile_cls(ftmo.get("verdict", "?"), ftmo.get("alarms", 0), warn=_soft_warn)
        _dp = ftmo.get("day_pnl")
        _age = ftmo.get("age_min")
        ftmo_sub = (
            f"day {'+' if isinstance(_dp, (int, float)) and _dp >= 0 else ''}{_dp:,.0f}"
            f" ({_dl:.1f}% of 5) // total DD {_dd:.1f}% of 10 // "
            f"{ftmo.get('magics_seen')}/{ftmo.get('expected_magics')} magics // "
            f"verdict {ftmo.get('verdict', '?')}"
            + (f" // {_age}m ago" if _age is not None else "")
            if isinstance(_dp, (int, float)) and isinstance(_dl, (int, float))
            and isinstance(_dd, (int, float))
            else f"verdict {ftmo.get('verdict', '?')}"
        )
    else:
        ftmo_val, ftmo_cls, ftmo_sub = "NO PULSE", "alert", "ftmo_trial_pulse.json unreadable"

    if decisions:
        gate_val = decisions[0].get("due") or decisions[0].get("cat") or "—"
        gate_sub = f"{decisions[0].get('title', '')} // {len(decisions)} decision(s) open"
    else:
        gate_val, gate_sub = "NONE", "no OWNER decisions pending"

    money_html = f'''
  <div class="frontier">
    <div class="frontier-tile">
      <div class="f-lbl">DXZ Live Book // Darwinex Zero</div>
      <div class="f-val {dxz_cls}">{e(dxz_val)}</div>
      <div class="f-sub">{e(dxz_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">FTMO Trial // 100K</div>
      <div class="f-val {ftmo_cls}">{e(ftmo_val)}</div>
      <div class="f-sub">{e(ftmo_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Next OWNER Gate</div>
      <div class="f-val hot">{e(gate_val)}</div>
      <div class="f-sub">{e(gate_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Mission Target</div>
      <div class="f-val">+20% P.A.</div>
      <div class="f-sub">DXZ &euro;100k mandate // DD guard 5% / 20% // no ML // evidence over claims</div>
    </div>
  </div>
'''

    # ---------- 3. OWNER DECISIONS ----------
    # Only genuine OWNER decisions (OWNER call 2026-07-07: "was muss ich da
    # alles entscheiden?" — the old panel listed Claude review tasks and
    # zombie BLOCKED rows, none of which OWNER can act on).
    review_pending = db_rows(
        "SELECT b.id, b.payload_json FROM tasks b "
        "WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' "
        "AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%') "
        "LIMIT 8"
    )
    attention_rows: list[str] = []
    for d in decisions[:8]:
        row_cls = "attention-row alert" if d.get("alert") else "attention-row"
        due = d.get("due") or ""
        attention_rows.append(
            f'<div class="{row_cls}">'
            f'<span class="glyph">▸</span>'
            f'<span class="cat">{e(d.get("cat", "DECISION"))}</span>'
            f'<span class="ent">{e(d.get("title", ""))}<span class="slug">{e(d.get("detail", ""))}</span></span>'
            f'<span class="status">{e(("DUE " + due) if due else "OWNER")}</span>'
            f'</div>'
        )
    if not attention_rows:
        attention_rows.append(
            '<div class="attention-row">'
            '<span class="glyph">·</span>'
            '<span class="cat">CLEAR</span>'
            '<span class="ent">no OWNER decisions pending<span class="slug">agents are working autonomously</span></span>'
            '<span class="status">OK</span>'
            '</div>'
        )
    attention_html_inner = "\n".join(attention_rows)
    attention_aux = f"{len(decisions):02d} Decisions Open"

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

    # Full limits readout per agent (OWNER "Update?" standard: 5h + weekly % + resets).
    # Source: quota_pull.py headless API snapshot via quota_snapshot().
    def _limits_html(src: str) -> str:
        s = qsnap.get(src, {}) if qsnap else {}

        def _pct_span(label: str, val, reset) -> str:
            if not isinstance(val, (int, float)):
                return f'<span class="k">{label}</span> <span class="v">—</span>'
            cls = "lim-crit" if val >= 90 else ("lim-warn" if val >= 70 else "lim-ok")
            r = f' <span class="lim-reset">&rarr;{e(str(reset))}</span>' if reset else ""
            return f'<span class="k">{label}</span> <span class="v {cls}">{int(val)}%</span>{r}'

        parts = [
            _pct_span("5H", s.get("hour_pct"), s.get("hour_reset")),
            _pct_span("WK", s.get("week_pct"), s.get("week_reset")),
        ]
        if src == "claude" and isinstance(s.get("sonnet_pct"), (int, float)):
            parts.append(_pct_span("WK-SONNET", s.get("sonnet_pct"), None))
        stale = not s.get("fresh")
        age = s.get("age_sec")
        if stale and isinstance(age, int):
            parts.append(f'<span class="lim-stale">stale {age // 60}m</span>')
        return '<span class="sep">&middot;</span>'.join(parts)

    claude_limits_html = _limits_html("claude")
    codex_limits_html = _limits_html("codex")

    # Total backtests pending across all phases (combine builds + p2 + p3 + work_items pending)
    mt5_pend = (
        q.get("backtest_p2_pending", 0)
        + q.get("backtest_p3_pending", 0)
        + len(q.get("pending_backtests_list", []) or [])
        + q.get("work_items_pending", 0)
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

    # Watchdog pulse: last self-heal action + interactive-session state. Answers
    # OWNER's recurring "ist die Factory eigentlich gelaufen?" without log-digging.
    # Heartbeat records (action="heartbeat") are emitted after every run; the last
    # heartbeat ts determines freshness.  The last operational record (non-heartbeat)
    # carries the meaningful action + session state.
    # STALE rule: if the last heartbeat is >30 min old, the watchdog itself has stopped
    # cycling — override the display with "WATCHDOG-STALE since <ts>" (wd-crit).
    watchdog_str = "no watchdog telemetry"
    watchdog_cls = "wd-warn"
    try:
        wd_log = Path(r"D:\QM\reports\state\factory_watchdog.jsonl")
        if wd_log.exists():
            tail = wd_log.read_text(encoding="utf-8", errors="ignore").strip().splitlines()
            if tail:
                # Parse lines in reverse to find the last heartbeat and last operational record
                last_hb_ts = None
                last_op: dict = {}
                for raw in reversed(tail):
                    try:
                        rec = json.loads(raw)
                    except Exception:
                        continue
                    if rec.get("action") == "heartbeat":
                        if last_hb_ts is None:
                            last_hb_ts = str(rec.get("ts") or "")
                    else:
                        if not last_op:
                            last_op = rec
                    if last_hb_ts and last_op:
                        break

                # Freshness: use the last heartbeat if available, else last operational ts
                freshness_ts = last_hb_ts or str(last_op.get("ts") or "")
                age_min = None
                try:
                    t = dt.datetime.fromisoformat(freshness_ts.replace("Z", "+00:00"))
                    age_min = int((dt.datetime.now(dt.timezone.utc) - t).total_seconds() // 60)
                except Exception:
                    pass

                if age_min is not None and age_min > 30:
                    # Watchdog stopped cycling — show explicit STALE label
                    watchdog_str = f"WATCHDOG-STALE since {freshness_ts} // {age_min}m ago"
                    watchdog_cls = "wd-crit"
                elif last_op:
                    act = str(last_op.get("action") or "?")
                    sess = "SESSION LOST" if last_op.get("session_lost") else "session ok"
                    age_txt = f" // {age_min}m ago" if age_min is not None else ""
                    watchdog_str = (f"{act} // {last_op.get('workers', '?')}/"
                                    f"{last_op.get('expect', '?')} workers // {sess}{age_txt}")
                    if last_op.get("session_lost") or act in ("heal_failed", "session_lost_no_autologon"):
                        watchdog_cls = "wd-crit"
                    elif act.startswith("healed"):
                        watchdog_cls = "wd-warn"
                    else:
                        watchdog_cls = "wd-ok"
    except Exception:
        pass

    # ---------- 5. PIPELINE FUNNEL ----------
    # Stage counts:
    # SRC      — sources pending  (input reservoir)
    # CARDS    — cards_ready / approved (write-ready EAs)
    # BUILT    — build_ea active+pending+done not yet reviewed (EAs being built)
    # BACKTEST Q02  — work_items at Q02 (plus legacy P2 rows)
    # ROBUST Q05-Q07 — work_items at Q05-Q07 (plus legacy rows)
    # PORTFOLIO Q11 — work_items PASS at Q11 (plus legacy P8 rows)
    src_pending = backlog["sources"].get("pending", 0)
    src_done = backlog["sources"].get("done", 0)
    cards_ready = backlog["sources"].get("cards_ready", 0)
    cards_cum_approved = q.get("cards_approved", 0)
    # Builds: pending + active + waiting review
    built_count = q.get("builds_pending", 0) + q.get("builds_active", 0) + review_q_count
    # Backtest Q02 — count Q02 and any legacy P2 rows.
    q02_total = 0
    for r in db_rows("SELECT status, verdict, COUNT(*) AS c FROM work_items WHERE phase IN ('Q02','P2') GROUP BY status, verdict"):
        q02_total += int(r.get("c") or 0)
    # ROBUST Q05-Q07: operator surfaces show Qxx only.
    robust_rows = db_rows(
        "SELECT phase, COUNT(DISTINCT ea_id) AS c FROM work_items "
        "WHERE verdict='PASS' AND phase IN ('Q05','Q06','Q07','P4','P5','P5b') GROUP BY phase"
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
    q02_spark = sparkline_str(_last7("_q02_pass")) if trend else "▁▁▁▁▁▁▁"
    q03_spark = sparkline_str(_last7("_q03_pass")) if trend else "▁▁▁▁▁▁▁"
    q11_spark = "▁▁▁▁▁▁▁"

    # Funnel drop-off labels
    review_drop = ""
    if cards_cum_approved:
        review_drop = f"▼ {int(100 - 100 * built_count / max(1, cards_cum_approved))}% TO REVIEW"
    q02_drop = ""
    if q02_total:
        q02_drop = f"▼ {int(100 - 100 * robust_count / max(1, q02_total))}% TO Q05"

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
        f'<div class="stg-num">{q02_total}</div>'
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
        p2_empty=" empty" if q02_total == 0 else "",
        robust_empty=" empty" if robust_count == 0 else "",
        portfolio_empty=" empty" if portfolio_count == 0 else "",
    )

    # Q08 Portfolio Rescue table removed 2026-07-07 (OWNER call) — the
    # snapshot counts still feed the COMPANY FRONTIER Q08-cohort tile.

    # ---------- 5b. PIPELINE PROGRESS (per-Q breakdown — OWNER call) ----------
    # Cards total: filesystem count of cards_approved/
    cards_dir = ROOT / "artifacts" / "cards_approved"
    cards_total = (sum(1 for p in cards_dir.iterdir()
                       if p.is_file() and p.suffix == ".md")
                   if cards_dir.exists() else 0)

    # EAs built: registry rows where the on-disk EA dir exists
    ea_registry_path = ROOT.parent.parent.parent / "QM" / "repo" / "framework" / "registry" / "ea_id_registry.csv"
    if not ea_registry_path.exists():
        # Try the canonical repo path
        ea_registry_path = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
    ea_dir_root = Path(r"C:\QM\repo\framework\EAs")
    eas_built = 0
    if ea_dir_root.exists():
        for d in ea_dir_root.iterdir():
            if d.is_dir() and d.name.startswith("QM5_"):
                # Counted as "built" only if the .ex5 exists
                if any(p.suffix == ".ex5" for p in d.iterdir()):
                    eas_built += 1
    eas_to_build = max(0, cards_total - eas_built)

    # Backtest queue totals
    bt_done = 0
    bt_open = 0
    for r in db_rows(
        "SELECT status, COUNT(*) AS c FROM work_items GROUP BY status"
    ):
        if r.get("status") == "done":
            bt_done += int(r.get("c") or 0)
        elif r.get("status") in ("pending", "active"):
            bt_open += int(r.get("c") or 0)

    # Per-phase progress: distinct (ea_id, symbol) pairs that reached each Qxx
    # with a PASS verdict (or — for phases that don't write per-symbol PASS
    # rows — distinct ea_id count). Reads Qxx-keyed rows directly; legacy
    # P-keys map via phase_ids.LEGACY_P_TO_Q for any orphan rows.
    Q_DISPLAY_ORDER = ["Q01", "Q02", "Q03", "Q04", "Q05", "Q06", "Q07",
                       "Q08", "Q09", "Q10", "Q11", "Q12", "Q13"]
    q_counts: dict[str, int] = {q: 0 for q in Q_DISPLAY_ORDER}
    # Q01 = EAs built (registry intersection w/ disk)
    q_counts["Q01"] = eas_built
    # Q02..Q10 = distinct (ea_id, symbol) PASS pairs at each Qxx
    for r in db_rows(
        "SELECT phase, COUNT(DISTINCT ea_id || '|' || symbol) AS c "
        "FROM work_items WHERE verdict='PASS' GROUP BY phase"
    ):
        phase_raw = r.get("phase") or ""
        # Map legacy P-keys to Qxx for display
        _legacy = {"P2": "Q02", "P3": "Q03", "P3.5": "Q04", "P4": "Q05",
                   "P5": "Q06", "P5b": "Q07", "P5c": "Q08",
                   "P6": "Q09", "P7": "Q10", "P8": "Q11"}
        qid = phase_raw if phase_raw in q_counts else _legacy.get(phase_raw)
        if qid and qid in q_counts:
            q_counts[qid] += int(r.get("c") or 0)
    # Q11..Q13 are OWNER-only phases (no work_items yet) — leave at 0 until
    # the agent_tasks table tracks them. Future iteration.

    # Build the progress HTML — top-line counters + per-Q chip strip.
    progress_html = f"""
  <!-- 5b. PIPELINE PROGRESS -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Pipeline Progress // Per-Phase Count</span>
      <span class="section-aux">Cards &rarr; EAs &rarr; Backtests &rarr; Q-Survivors</span>
    </div>
    <div class="prog-counters">
      <div class="prog-counter"><div class="prog-lbl">Strategy Cards</div><div class="prog-val">{cards_total:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">EAs Built</div><div class="prog-val">{eas_built:,}<span class="prog-of"> / {cards_total:,}</span></div></div>
      <div class="prog-counter"><div class="prog-lbl">EAs To Build</div><div class="prog-val">{eas_to_build:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">Backtests Done</div><div class="prog-val">{bt_done:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">Backtests Open</div><div class="prog-val">{bt_open:,}</div></div>
    </div>
    <div class="prog-strip">
      {''.join(
          f'<div class="prog-chip{" empty" if q_counts[q] == 0 else ""}">'
          f'<div class="prog-chip-q">{q}</div>'
          f'<div class="prog-chip-n">{q_counts[q]:,}</div>'
          f'</div>'
          for q in Q_DISPLAY_ORDER
      )}
    </div>
    <div class="prog-foot">
      Q01 = EAs with .ex5 on disk &middot; Q02..Q10 = distinct (EA, symbol) PASS pairs &middot;
      Q11..Q13 = OWNER phases (live count pending)
    </div>
  </div>
"""

    # Recent Events telemetry tail removed 2026-07-07 (OWNER call — all-red
    # zero-trade noise with no decision value).

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
    anom_today_total = (
        cw["today"]["zero_trade_like"]
        + cw["today"]["invalid"]
        + cw["today"]["waiting_input"]
    )
    anom_yesterday_total = (
        cw["yesterday"]["zero_trade_like"]
        + cw["yesterday"]["invalid"]
        + cw["yesterday"]["waiting_input"]
    )
    anom_30d_total = anom["zero_trade_like"] + anom["invalid"] + anom["waiting_input"]

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
.agent-limits {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 11px; letter-spacing: 0.02em; color: var(--text-3);
  padding: 0 20px 12px 116px; margin-top: -8px;
  border-bottom: 1px solid var(--border);
}
.agent-limits .k { color: var(--text-3); font-size: 10px; letter-spacing: 0.12em; }
.agent-limits .v { font-weight: 700; }
.agent-limits .lim-ok { color: var(--signal); }
.agent-limits .lim-warn { color: var(--warn); }
.agent-limits .lim-crit { color: var(--fail); }
.agent-limits .lim-reset { color: var(--text-3); font-size: 10px; }
.agent-limits .lim-stale { color: var(--warn); font-size: 10px; letter-spacing: 0.1em; text-transform: uppercase; }
.agent-limits .sep { margin: 0 8px; color: var(--border); }
.watchdog-row {
  display: grid; grid-template-columns: 80px 1fr; gap: 16px;
  padding: 12px 20px; align-items: baseline;
  border-top: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px;
}
.watchdog-row .wlbl {
  font-weight: 700; letter-spacing: 0.2em; font-size: 10px;
  text-transform: uppercase; color: var(--text-3);
}
.watchdog-row .wval { color: var(--text-2); }
.watchdog-row.wd-ok .wval { color: var(--signal); }
.watchdog-row.wd-warn .wval { color: var(--warn); }
.watchdog-row.wd-crit .wval { color: var(--fail); font-weight: 700; }
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

/* PIPELINE PROGRESS — top-line counters + per-Q chip strip (OWNER call) */
.prog-counters {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 12px;
  background: var(--surface-1); border: 1px solid var(--border);
  padding: 16px 20px;
  margin-bottom: 12px;
}
.prog-counter {
  padding: 6px 14px;
  border-right: 1px solid var(--border);
}
.prog-counter:last-child { border-right: none; }
.prog-counter .prog-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text-3); text-transform: uppercase;
  margin-bottom: 6px;
}
.prog-counter .prog-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 26px; font-weight: 500; line-height: 1;
  color: var(--text); letter-spacing: -0.02em;
}
.prog-counter .prog-of {
  font-size: 14px; color: var(--text-3); font-weight: 400;
}
.prog-strip {
  display: grid;
  grid-template-columns: repeat(13, 1fr);
  gap: 6px;
  background: var(--surface-1); border: 1px solid var(--border);
  padding: 14px 20px;
}
.prog-chip {
  padding: 10px 8px;
  text-align: center;
  background: var(--surface-2);
  border: 1px solid var(--border);
}
.prog-chip.empty .prog-chip-n { color: var(--text-4); }
.prog-chip-q {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 700; letter-spacing: 0.14em;
  color: var(--text-3); text-transform: uppercase;
  margin-bottom: 4px;
}
.prog-chip-n {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 18px; font-weight: 500; line-height: 1;
  color: var(--signal); letter-spacing: -0.02em;
}
.prog-foot {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; color: var(--text-4); letter-spacing: 0.06em;
  padding: 8px 4px 0;
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

/* COMPANY FRONTIER */
.frontier {
  grid-column: span 12;
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 1px;
  background: var(--border); border: 1px solid var(--border);
}
.frontier-tile { background: var(--surface-1); padding: 16px 20px; }
.frontier-tile .f-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 10px;
}
.frontier-tile .f-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 22px; font-weight: 500; color: var(--text); line-height: 1.05;
}
.frontier-tile .f-val.hot { color: var(--live); }
.frontier-tile .f-val.ok { color: var(--signal); }
.frontier-tile .f-val.warn { color: var(--warn); }
.frontier-tile .f-val.alert { color: var(--fail); }
.frontier-tile .f-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-3); margin-top: 7px;
  letter-spacing: 0.05em; line-height: 1.5;
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

    # ---------- COMPANY FRONTIER (OWNER 2026-06-11: cockpit = company progress) ----------
    # The four numbers that say how far the COMPANY is, not how busy the factory is:
    # furthest candidate, Q08 cohort shape, inventory conversion, 30d throughput.
    try:
        pc_rows = db_rows("SELECT ea_id, symbol, state FROM portfolio_candidates ORDER BY updated_at DESC")
    except Exception:
        pc_rows = []
    q12_ready = [r for r in pc_rows if "Q12" in str(r.get("state") or "").upper()]
    if q12_ready:
        frontier_val = f"{len(q12_ready)} @ Q12"
        frontier_sub = " // ".join(
            f"{r['ea_id']} {str(r.get('symbol') or '').replace('.DWX', '')}" for r in q12_ready[:3]
        ) + " // waiting OWNER review"
    elif pc_rows:
        frontier_val = f"{len(pc_rows)} candidates"
        frontier_sub = "portfolio candidates pre-Q12"
    else:
        frontier_val = "Q08"
        frontier_sub = "no portfolio candidate yet — frontier is the Q08 cost-cushion gate"
    frontier_html = f'''
  <div class="frontier">
    <div class="frontier-tile">
      <div class="f-lbl">Frontier // Furthest Candidate</div>
      <div class="f-val hot">{e(frontier_val)}</div>
      <div class="f-sub">{e(frontier_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Q08 Cohort</div>
      <div class="f-val">{q08_rescue.get("pass_portfolio", 0)}<span style="color:var(--text-3)">/{q08_rescue.get("soft", 0) + q08_rescue.get("hard", 0)}</span></div>
      <div class="f-sub">portfolio-pass / standalone-fails ({q08_rescue.get("soft", 0)} soft // {q08_rescue.get("hard", 0)} hard)</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Inventory Conversion</div>
      <div class="f-val">{eas_built:,}<span style="color:var(--text-3)">/{cards_total:,}</span></div>
      <div class="f-sub">EAs built / cards approved // {bt_done:,} backtests graded</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Throughput // 30D</div>
      <div class="f-val">{mt5_30d:,}</div>
      <div class="f-sub">MT5 items done // {q02_pass_30d:,} Q02 PASS cumulative</div>
    </div>
  </div>
'''

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

  <!-- 2. LIVE MONEY -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Live Money // Real Accounts</span>
      <span class="section-aux">DXZ Book // FTMO Trial // Pulse Evidence</span>
    </div>
    {money_html}
  </div>

  <!-- 3. OWNER DECISIONS + AGENT STATUS -->
  <div class="col-left">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Owner Decisions</span>
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
          <span class="v">{claude_closed_today}</span><span class="k">CLOSED</span>
        </span>
      </div>
      <div class="agent-limits">{claude_limits_html}</div>
      <div class="agent-row">
        <span class="name">CODEX</span>
        <span class="agent-readout">
          <span class="v">{codex_act}</span><span class="k">ACT</span><span class="sep">&middot;</span>
          <span class="v">{q.get("builds_pending", 0)}</span><span class="k">QUE</span><span class="sep">&middot;</span>
          <span class="v">{codex_closed_today}</span><span class="k">CLOSED</span>
        </span>
      </div>
      <div class="agent-limits">{codex_limits_html}</div>
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
      <div class="watchdog-row {watchdog_cls}">
        <span class="wlbl">WATCHDOG</span>
        <span class="wval">{e(watchdog_str)}</span>
      </div>
    </div>
  </div>

  <!-- 4. COMPANY FRONTIER -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Company Frontier // Pipeline Edge</span>
      <span class="section-aux">Furthest Candidate // Q08 Cohort // Conversion // Throughput</span>
    </div>
    {frontier_html}
  </div>

  {progress_html}

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

  <!-- 6. DAILY CONTROLLING -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Daily Controlling // Throughput &amp; Test Exceptions</span>
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
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val">{anom_today_total}</div>
          <div class="s-sub">{cw["today"]["zero_trade_like"]} min-trade // {cw["today"]["invalid"]} invalid // {cw["today"]["waiting_input"]} waiting</div>
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
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val dim">{anom_yesterday_total}</div>
          <div class="s-sub">{cw["yesterday"]["zero_trade_like"]} min-trade // {cw["yesterday"]["invalid"]} invalid // {cw["yesterday"]["waiting_input"]} waiting</div>
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
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val">{anom_30d_total}</div>
          <div class="s-sub">{anom["zero_trade_like"]} min-trade // {anom["invalid"]} invalid // {anom["waiting_input"]} waiting</div>
        </div>
      </div>
    </div>
  </div>

  <!-- 8. BOTTOM BAR -->
  <div class="botbar">
    <div><span class="key">Next Refresh</span><span class="val">30S</span></div>
    <div class="center"><span class="key">Renderer</span><span class="val">v6.0 // STEEL-EMERALD</span></div>
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
