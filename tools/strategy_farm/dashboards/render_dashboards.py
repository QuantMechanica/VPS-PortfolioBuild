"""Renders the strategy_farm project-progress + Strategy Archive HTML.

Reads D:/QM/strategy_farm/state/farm_state.sqlite + artifacts/.
Writes HTML to D:/QM/strategy_farm/dashboards/.
Stdlib-only — no Jinja2, no external deps.

Usage:
    python tools/strategy_farm/dashboards/render_dashboards.py
    python tools/strategy_farm/dashboards/render_dashboards.py --root D:/QM/strategy_farm
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import os
import re
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm.phase_ids import PHASE_ORDER, LEGACY_P_TO_Q as PHASE_QID, phase_label

PHASE_DISPLAY = PHASE_QID
PHASE_LABEL_FROM_KIND = {
    "backtest_p2": "P2",
    "backtest_p3": "P3",
    "backtest_p35": "P3.5",
    "backtest_p4": "P4",
    "backtest_p5": "P5",
    "backtest_p5b": "P5b",
    "backtest_p5c": "P5c",
    "backtest_p6": "P6",
    "backtest_p7": "P7",
    "backtest_p8": "P8",
}
MT5_FLEET_TOTAL = 10
MT5_FLEET_WARN_THRESHOLD = 7


# ── Helpers ──────────────────────────────────────────────────────


def utc_now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def e(s: Any) -> str:
    return html.escape(str(s)) if s is not None else ""


def sparkline(counts: list[int]) -> str:
    if not counts:
        return ""
    max_v = max(counts) if max(counts) > 0 else 1
    chars = " ▁▂▃▄▅▆▇█"
    return "".join(chars[min(len(chars) - 1, int(c / max_v * (len(chars) - 1)))] for c in counts)


def fmt_dollar(v: Any) -> str:
    if not isinstance(v, (int, float)):
        return "—"
    if abs(v) >= 1000:
        return f"${v:,.0f}"
    return f"${v:,.2f}"


def fmt_num(v: Any, digits: int = 2) -> str:
    if not isinstance(v, (int, float)):
        return "—"
    return f"{v:,.{digits}f}"


def fmt_pct(v: Any, digits: int = 2) -> str:
    if not isinstance(v, (int, float)):
        return "—"
    return f"{v:,.{digits}f}%"


def split_frontmatter(content: str) -> tuple[dict[str, Any], str]:
    """Tiny stdlib YAML-frontmatter splitter (no PyYAML)."""
    fm: dict[str, Any] = {}
    body = content
    if content.startswith("---\n"):
        end = content.find("\n---", 4)
        if end > 0:
            yaml_block = content[4:end]
            body = content[end + 4 :].lstrip("\n")
            for line in yaml_block.splitlines():
                if ":" in line and not line.lstrip().startswith("#") and not line.startswith("  "):
                    k, _, v = line.partition(":")
                    v = v.strip()
                    if v.startswith('"') and v.endswith('"'):
                        v = v[1:-1]
                    fm[k.strip()] = v
    return fm, body


# ── MT5 .htm report parser (UTF-16) ──────────────────────────────


import re as _re_mt5


def read_mt5_report(path: Path) -> str:
    """MT5 reports are UTF-16 LE encoded."""
    for enc in ("utf-16", "utf-16-le", "utf-8"):
        try:
            return path.read_text(encoding=enc, errors="ignore")
        except Exception:
            continue
    return ""


def strip_html(text: str) -> str:
    return _re_mt5.sub(r"\s+", " ", _re_mt5.sub(r"<[^>]+>", " ", text))


def extract_mt5_stats(html: str) -> dict[str, Any]:
    """Parse MT5 report.htm stats. Returns dict; missing keys = None."""
    text = strip_html(html)
    out: dict[str, Any] = {}
    pats = {
        "net_profit": r"Total Net Profit:\s*(-?[\d.,]+)",
        "profit_factor": r"Profit Factor:\s*(-?[\d.,]+)",
        "expected_payoff": r"Expected Payoff:\s*(-?[\d.,]+)",
        "sharpe": r"Sharpe Ratio:\s*(-?[\d.,]+)",
        "recovery": r"Recovery Factor:\s*(-?[\d.,]+)",
        "total_trades": r"Total Trades:\s*(\d+)",
    }
    for key, pat in pats.items():
        m = _re_mt5.search(pat, text)
        if m:
            try:
                out[key] = float(m.group(1).replace(",", "")) if "." in m.group(1) or "," in m.group(1) or key == "profit_factor" else int(m.group(1))
            except ValueError:
                out[key] = None
        else:
            out[key] = None
    # max DD: "Equity Drawdown Maximal: 4848.30 (5.12%)"
    m = _re_mt5.search(r"Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)", text)
    if m:
        try:
            out["max_dd_abs"] = float(m.group(1).replace(",", ""))
            out["max_dd_pct"] = float(m.group(2).replace(",", ""))
        except ValueError:
            pass
    return out


_TR_RE = _re_mt5.compile(r"<tr[^>]*>(.*?)</tr>", _re_mt5.DOTALL)
_TD_RE = _re_mt5.compile(r"<td[^>]*>(.*?)</td>", _re_mt5.DOTALL)
_TAG_RE = _re_mt5.compile(r"<[^>]+>")


def _num_de(s: str) -> float | None:
    """Parse MT5 European-format number: '27 472.57' or '-1 234,56' or '0.00'."""
    if not s:
        return None
    cleaned = s.replace("\xa0", " ").strip()
    # remove thousand-space separator
    cleaned = _re_mt5.sub(r"(?<=\d) (?=\d{3})", "", cleaned)
    # German decimal-comma → dot
    if "," in cleaned and "." not in cleaned:
        cleaned = cleaned.replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def extract_mt5_deals(html: str) -> list[tuple[str, float]]:
    """Pull (timestamp_str, balance_after_deal) rows from the MT5 Deals table.

    Strategy: enumerate <tr> rows, keep the ones with exactly 13 <td> cells
    whose first cell looks like a timestamp. Column 11 (0-indexed) is balance
    and column 10 is profit. Handles MT5's space-thousand separator
    ('100 000.00') which the previous regex-on-stripped-text couldn't.
    """
    out: list[tuple[str, float]] = []
    for tr in _TR_RE.findall(html):
        cells = _TD_RE.findall(tr)
        if len(cells) != 13:
            continue
        ts = _TAG_RE.sub("", cells[0]).strip()
        if not _re_mt5.match(r"\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}$", ts):
            continue
        bal_txt = _TAG_RE.sub("", cells[11]).strip()
        bal = _num_de(bal_txt)
        if bal is None:
            continue
        out.append((ts, bal))
    return out


def equity_svg(deals: list[tuple[str, float]], width: int = 320, height: int = 64,
               net_profit: float | None = None) -> str:
    """Render an inline SVG equity curve from balance progression.

    Returns SVG with: balance polyline (emerald if net+, red if net-),
    DD shading from rolling-max, baseline + endpoint marker. No axis labels
    in mini mode; pure visual.
    """
    if len(deals) < 2:
        return f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}"><text x="{width//2}" y="{height//2 + 4}" fill="#475569" font-size="10" text-anchor="middle" font-family="monospace">no equity data</text></svg>'

    balances = [d[1] for d in deals]
    bmin = min(balances)
    bmax = max(balances)
    span = (bmax - bmin) or 1.0
    n = len(balances)

    margin = 4
    inner_w = width - 2 * margin
    inner_h = height - 2 * margin

    points = []
    for i, b in enumerate(balances):
        x = margin + (i / max(1, n - 1)) * inner_w
        y = margin + inner_h - ((b - bmin) / span) * inner_h
        points.append((x, y))

    # rolling max for DD shading
    rmax: list[float] = []
    cur = balances[0]
    for b in balances:
        cur = max(cur, b)
        rmax.append(cur)

    # color by net result
    if net_profit is None:
        net_profit = balances[-1] - balances[0]
    line_color = "#10b981" if net_profit >= 0 else "#ef4444"
    fill_color = "rgba(16,185,129,0.10)" if net_profit >= 0 else "rgba(239,68,68,0.10)"
    dd_color = "rgba(239,68,68,0.18)"

    # build path
    line_d = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    # fill area down to baseline (y = margin + inner_h)
    base_y = margin + inner_h
    fill_d = f"M {points[0][0]:.1f},{base_y:.1f} L " + \
             " L ".join(f"{x:.1f},{y:.1f}" for x, y in points) + \
             f" L {points[-1][0]:.1f},{base_y:.1f} Z"
    # DD path (rolling max line) — only render if there's meaningful DD
    dd_d = ""
    for i, (b, m) in enumerate(zip(balances, rmax)):
        if m - b > span * 0.04:  # only show DD > 4% of range
            x = margin + (i / max(1, n - 1)) * inner_w
            y_b = margin + inner_h - ((b - bmin) / span) * inner_h
            y_m = margin + inner_h - ((m - bmin) / span) * inner_h
            dd_d += f'<line x1="{x:.1f}" y1="{y_m:.1f}" x2="{x:.1f}" y2="{y_b:.1f}" stroke="{dd_color}" stroke-width="1"/>'

    return f'''<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
<path d="{fill_d}" fill="{fill_color}" stroke="none"/>
{dd_d}
<path d="{line_d}" fill="none" stroke="{line_color}" stroke-width="1.5" stroke-linejoin="round"/>
<circle cx="{points[-1][0]:.1f}" cy="{points[-1][1]:.1f}" r="2.2" fill="{line_color}"/>
</svg>'''


# ── Data collection ──────────────────────────────────────────────


def collect_farm_state(root: Path) -> dict[str, Any]:
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return {"sources": [], "tasks": [], "events": [], "db_missing": True, "_root": root}

    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        sources = [dict(r) for r in conn.execute(
            "SELECT * FROM sources ORDER BY priority, created_at"
        )]
        tasks_raw = [dict(r) for r in conn.execute(
            "SELECT * FROM tasks ORDER BY created_at DESC"
        )]
        events_raw = [dict(r) for r in conn.execute(
            "SELECT * FROM events ORDER BY id DESC LIMIT 200"
        )]

    tasks = []
    for t in tasks_raw:
        try:
            t["payload"] = json.loads(t.get("payload_json") or "{}")
        except Exception:
            t["payload"] = {}
        tasks.append(t)

    events = []
    for ev in events_raw:
        try:
            ev["detail"] = json.loads(ev.get("detail_json") or "{}")
        except Exception:
            ev["detail"] = {}
        events.append(ev)

    return {"sources": sources, "tasks": tasks, "events": events, "db_missing": False, "_root": root}


def get_mt5_fleet_status() -> dict[str, Any]:
    scan_at = utc_now_iso()
    try:
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        result = subprocess.run(
            ["tasklist", "/V", "/FO", "CSV", "/FI", "IMAGENAME eq terminal64.exe"],
            capture_output=True, text=True, timeout=15, creationflags=creationflags,
        )
    except Exception as exc:
        return {"scanned_at": scan_at, "error": str(exc), "processes": [], "running_count": 0}

    lines = [l for l in result.stdout.splitlines() if "terminal64.exe" in l]
    procs = []
    for line in lines:
        try:
            cols = next(csv.reader([line]))
            if len(cols) >= 9:
                procs.append({
                    "pid": cols[1].strip('"'),
                    "status": cols[5].strip('"'),
                    "window_title": cols[8].strip('"'),
                })
        except Exception:
            pass

    return {"scanned_at": scan_at, "processes": procs, "running_count": len(procs)}


def _slug_for_ea(ea_id: str) -> str:
    """Best-effort display slug for an EA from its framework/EAs/ directory."""
    eas_dir = REPO_ROOT / "framework" / "EAs"
    try:
        for d in sorted(eas_dir.glob(f"{ea_id}_*")):
            if d.is_dir():
                return d.name[len(ea_id) + 1:] or ea_id
    except OSError:
        pass
    return ea_id


def _ea_from_work_items(ea_id: str, wi_rows: list, pass_verdicts: set[str]) -> dict:
    """Derive an EA candidate dict from work_items rows alone — for EAs with
    pipeline activity but no agent task. Closes the archive coverage gap so
    every EA in the DB gets a rendered detail page."""
    completed: set[str] = set()
    current_phase, current_idx = "G0", 0
    failed_at: str | None = None
    has_open = False
    last_updated = ""
    for r in wi_rows:
        phase = str(r["phase"] or "")
        if phase not in PHASE_ORDER:
            continue
        idx = PHASE_ORDER.index(phase)
        status = str(r["status"] or "").lower()
        verdict = str(r["verdict"] or "").upper()
        if status == "done" and verdict in pass_verdicts:
            completed.add(phase)
            if idx >= current_idx:
                current_phase, current_idx = phase, idx
        elif status in {"active", "pending", "claimed"}:
            has_open = True
            if idx > current_idx:
                current_phase, current_idx = phase, idx
        elif idx >= current_idx:
            failed_at = phase
        if (r["updated_at"] or "") > last_updated:
            last_updated = r["updated_at"] or ""
    dead = bool(failed_at) and not has_open and not completed
    return {
        "ea_id": ea_id,
        "slug": _slug_for_ea(ea_id),
        "completed_phases": sorted(
            completed, key=lambda p: PHASE_ORDER.index(p) if p in PHASE_ORDER else 99
        ),
        "current_phase": current_phase,
        "failed_at": failed_at if dead else None,
        "dead": dead,
        "live": False,
        "task_count": 0,
        "last_updated": last_updated,
        "latest_evidence": None,
    }


# Strategy-card directory states, in priority order (later wins if a card_id
# somehow exists in two folders — shouldn't happen, but be defensive).
CARD_STATE_DIRS: list[tuple[str, str]] = [
    ("rejected", "cards_rejected"),
    ("draft",    "cards_draft"),
    ("review",   "cards_review"),
    ("approved", "cards_approved"),
]

_CARD_FILENAME_RE = re.compile(r"^(QM5_\d+)_(.+)\.md$")


def _ea_from_strategy_card(card_path: Path, ea_id: str, slug: str,
                            card_state: str) -> dict:
    """Seed an EA dict from a strategy-card .md on disk — for cards that have
    not yet been built into EAs (no agent task, no work_items). Carries
    `card_state` so the renderer can show the appropriate pill and lane."""
    try:
        mtime = dt.datetime.fromtimestamp(card_path.stat().st_mtime, dt.UTC)
        last_updated = mtime.replace(microsecond=0).isoformat()
    except OSError:
        last_updated = ""
    dead = (card_state == "rejected")
    return {
        "ea_id": ea_id,
        "slug": slug,
        "completed_phases": [],
        "current_phase": "Q00",
        "failed_at": "Q00" if dead else None,
        "dead": dead,
        "live": False,
        "task_count": 0,
        "last_updated": last_updated,
        "latest_evidence": str(card_path),
        "card_state": card_state,
        "card_path": str(card_path),
    }


def derive_ea_candidates(tasks: list[dict], root: Path | None = None) -> list[dict]:
    """Group tasks by card_id (= ea_id) and derive EA-level state.

    EAs that have work_items but no agent task are seeded too, so the
    Strategy Archive and cockpit coverage panel never lose a live EA."""
    by_ea: dict[str, list[dict]] = defaultdict(list)
    for t in tasks:
        ea_id = t.get("card_id")
        if ea_id:
            by_ea[ea_id].append(t)

    eas = []
    for ea_id, ea_tasks in by_ea.items():
        ea_tasks.sort(key=lambda t: t.get("created_at", ""))

        completed: set[str] = set()
        current_phase = "G0"
        failed_at: str | None = None
        dead = False
        live = False
        slug = ea_id
        latest_evidence: str | None = None

        for t in ea_tasks:
            kind = t.get("kind", "")
            status = t.get("status", "")
            payload = t.get("payload", {})

            if kind == "build_ea":
                slug = payload.get("slug", slug) or slug
                if status == "done":
                    codex = payload.get("codex_result") or {}
                    if codex.get("smoke_result") in ("passed", "zero_trades"):
                        completed.add("G0")
                        current_phase = "P1"
                elif status in ("failed", "blocked"):
                    failed_at = "P1"
                    dead = True

            elif kind == "ea_review":
                if status == "done":
                    verdict_doc = payload.get("verdict") or {}
                    if verdict_doc.get("verdict") == "APPROVE_FOR_BACKTEST":
                        completed.add("P1")
                        current_phase = "P2"

            elif kind.startswith("backtest_"):
                phase = PHASE_LABEL_FROM_KIND.get(kind, kind.replace("backtest_", "").upper())
                if status == "active":
                    current_phase = phase
                elif status == "done":
                    cls = payload.get("classification") or {}
                    verdict = cls.get("verdict")
                    if verdict == "PASS":
                        completed.add(phase)
                        try:
                            idx = PHASE_ORDER.index(phase)
                            if idx < len(PHASE_ORDER) - 1:
                                current_phase = PHASE_ORDER[idx + 1]
                        except ValueError:
                            pass
                    elif verdict in ("STRATEGY_FAIL", "INFRA_FAIL"):
                        failed_at = phase
                        dead = True
                    # ZERO_TRADES = HR7, not a death sentence, stays in same phase
                    latest_evidence = cls.get("evidence_path") or latest_evidence
                elif status == "failed":
                    failed_at = phase
                    dead = True

        eas.append({
            "ea_id": ea_id,
            "slug": slug,
            "completed_phases": sorted(
                completed, key=lambda p: PHASE_ORDER.index(p) if p in PHASE_ORDER else 99
            ),
            "current_phase": current_phase,
            "failed_at": failed_at,
            "dead": dead,
            "live": live,
            "task_count": len(ea_tasks),
            "last_updated": ea_tasks[-1].get("updated_at", "") if ea_tasks else "",
            "latest_evidence": latest_evidence,
        })

    if root is not None:
        db = root / "state" / "farm_state.sqlite"
        if db.exists():
            pass_verdicts = {"PASS", "AUTO_PASS", "MODE_SELECTED", "MULTI_SEED_PASS"}
            try:
                with sqlite3.connect(db) as conn:
                    conn.row_factory = sqlite3.Row
                    rows = conn.execute(
                        "SELECT ea_id, phase, status, verdict, updated_at FROM work_items"
                    ).fetchall()
            except sqlite3.Error:
                rows = []
            wi_by_ea: dict[str, list] = defaultdict(list)
            for r in rows:
                if r["ea_id"]:
                    wi_by_ea[r["ea_id"]].append(r)
            by_id = {ea["ea_id"]: ea for ea in eas}
            # enrich task-derived EAs from their work_items
            for ea_id, ea in by_id.items():
                for r in wi_by_ea.get(ea_id, []):
                    phase = str(r["phase"] or "")
                    if phase not in PHASE_ORDER:
                        continue
                    phase_idx = PHASE_ORDER.index(phase)
                    current_idx = PHASE_ORDER.index(ea["current_phase"]) if ea["current_phase"] in PHASE_ORDER else -1
                    verdict = str(r["verdict"] or "").upper()
                    status = str(r["status"] or "").lower()
                    if status == "done" and verdict in pass_verdicts:
                        ea["completed_phases"] = sorted(
                            set(ea.get("completed_phases") or []) | {phase},
                            key=lambda p: PHASE_ORDER.index(p) if p in PHASE_ORDER else 99,
                        )
                        if phase_idx >= current_idx:
                            ea["current_phase"] = phase
                            ea["failed_at"] = None
                            ea["dead"] = False
                    elif status in {"active", "pending", "claimed"} and phase_idx > current_idx:
                        ea["current_phase"] = phase
                        ea["dead"] = False
                        ea["failed_at"] = None
                    if (r["updated_at"] or "") > (ea.get("last_updated") or ""):
                        ea["last_updated"] = r["updated_at"] or ea.get("last_updated") or ""
            # archive coverage: seed EAs that have work_items but no agent task
            for ea_id, ea_rows in wi_by_ea.items():
                if ea_id not in by_id:
                    eas.append(_ea_from_work_items(ea_id, ea_rows, pass_verdicts))
                    by_id[ea_id] = eas[-1]

        # archive coverage: seed every strategy card on disk that has no
        # agent task and no work_items yet — OWNER decision 2026-05-23:
        # "every strategy card is a strategy in the archive". Stays card-only
        # row until a build_ea task fires or work_items appear.
        artifacts_dir = root / "artifacts"
        if artifacts_dir.is_dir():
            for card_state, subdir in CARD_STATE_DIRS:
                dir_path = artifacts_dir / subdir
                if not dir_path.is_dir():
                    continue
                for card_path in dir_path.glob("QM5_*.md"):
                    m = _CARD_FILENAME_RE.match(card_path.name)
                    if not m:
                        continue
                    ea_id, slug = m.group(1), m.group(2)
                    if ea_id in by_id:
                        # Already represented by an agent task or work_items —
                        # promote slug + card_state onto the existing entry so
                        # the row shows where this card sits in the funnel.
                        existing = by_id[ea_id]
                        if not existing.get("slug") or existing["slug"] == ea_id:
                            existing["slug"] = slug
                        existing.setdefault("card_state", card_state)
                        existing.setdefault("card_path", str(card_path))
                        continue
                    eas.append(_ea_from_strategy_card(card_path, ea_id, slug, card_state))
                    by_id[ea_id] = eas[-1]

    eas.sort(key=lambda x: x.get("last_updated", ""), reverse=True)
    return eas


def throughput_last_7d(events: list[dict]) -> dict[str, list[int]]:
    today = dt.datetime.now(dt.UTC).date()
    days = [today - dt.timedelta(days=i) for i in range(6, -1, -1)]
    by_day: dict[dt.date, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for ev in events:
        ts = ev.get("ts", "")
        try:
            d = dt.datetime.fromisoformat(ts.replace("Z", "+00:00")).date()
        except Exception:
            continue
        if d in days:
            by_day[d][ev.get("entity_type", "?")] += 1
    return {
        "days": [d.strftime("%a") for d in days],
        "sources_per_day": [by_day[d].get("source", 0) for d in days],
        "tasks_per_day": [by_day[d].get("task", 0) for d in days],
        "events_per_day": [sum(by_day[d].values()) for d in days],
    }


# ── HTML head ────────────────────────────────────────────────────


def html_head(title: str, extra_css: str = "") -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{e(title)} · QuantMechanica V5</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="preconnect" href="https://api.fontshare.com" crossorigin>
<link href="https://api.fontshare.com/v2/css?f[]=general-sans@200,400,500,600,700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="style.css">
<style>
{extra_css}
</style>
</head>
<body>
"""


# ── Cockpit data collection (current.html) ───────────────────────


def _wi_payload(row: dict) -> dict:
    try:
        return json.loads(row.get("payload_json") or "{}")
    except Exception:
        return {}


def _ran_real_mt5(status: str, payload: dict, claimed_by: Any, evidence: Any) -> bool:
    """True only if this work_item actually launched an MT5 tester run.

    Preflight failures are rejected *before* MT5 starts (DEEP_AUDIT 2026-05-20)
    and must not be counted as backtests. A real run leaves a terminal claim,
    a run_smoke exit code, or MT5 report evidence behind.
    """
    if status not in ("done", "failed"):
        return False
    if payload.get("preflight_failure"):
        return False
    if claimed_by:
        return True
    if "run_smoke_exit_code" in payload:
        return True
    if evidence:
        return True
    return False


def _age_hours(iso: str) -> float:
    if not iso:
        return 0.0
    try:
        t = dt.datetime.fromisoformat(iso.replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.UTC)
        return max(0.0, (dt.datetime.now(dt.UTC) - t).total_seconds() / 3600)
    except Exception:
        return 0.0


_AGENT_SLA_H = {"TODO": 2, "BACKLOG": 4, "IN_PROGRESS": 4, "REVIEW": 12,
                "BLOCKED": 24, "OPS_FIX_REQUIRED": 12, "SELF_LEARNING": 24}
_OPEN_AGENT_STATES = ("BACKLOG", "TODO", "IN_PROGRESS", "REVIEW", "BLOCKED",
                      "OPS_FIX_REQUIRED", "SELF_LEARNING")
_PREFLIGHT_REASONS = ("ex5_missing", "setfile_missing", "ea_dir_missing",
                      "ea_dir_ambiguous")


def collect_cockpit_data(root: Path, eas: list[dict]) -> dict[str, Any]:
    """Single-pass DB read powering the operator cockpit (current.html)."""
    out: dict[str, Any] = {
        "db_missing": True,
        "phase_matrix": {},
        "pending_total": 0,
        "active_total": 0,
        "pending_list": [],
        "distinct_eas": 0,
        "p8_pass_eas": [],
        "p4plus_eas": [],
        "daily": {},
        "agent_tasks": [],
        "agent_open_count": 0,
        "build_failures": [],
        "build_fail_total": 0,
        "coverage": {},
        "bottleneck": "—",
        "next_action": "",
        "next_action_bad": False,
    }
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return out
    out["db_missing"] = False
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        wi = [dict(r) for r in conn.execute(
            "SELECT id,phase,ea_id,symbol,status,verdict,claimed_by,evidence_path,"
            "setfile_path,payload_json,created_at,updated_at FROM work_items")]
        atasks = [dict(r) for r in conn.execute(
            "SELECT id,task_type,state,priority,assigned_agent,artifact_path,"
            "verdict,payload_json,created_at,updated_at FROM agent_tasks "
            "ORDER BY priority, updated_at DESC")]

    today = dt.datetime.now(dt.UTC).date()
    yesterday = today - dt.timedelta(days=1)

    phase_matrix: dict[str, Counter] = defaultdict(Counter)
    wi_eas: set[str] = set()
    ea_pass_phases: dict[str, set[str]] = defaultdict(set)
    buckets: dict[str, list[dict]] = {"today": [], "yesterday": [], "d7": [], "d30": []}
    build_failures: list[dict] = []
    pending_list: list[dict] = []

    for w in wi:
        phase = w.get("phase") or "?"
        status = (w.get("status") or "").lower()
        verdict = (w.get("verdict") or "").upper()
        payload = _wi_payload(w)
        ea_id = w.get("ea_id") or "?"
        wi_eas.add(ea_id)

        m = phase_matrix[phase]
        m["total"] += 1
        if status == "pending":
            m["pending"] += 1
            out["pending_total"] += 1
            if len(pending_list) < 120:
                pending_list.append({"ea_id": ea_id, "symbol": w.get("symbol") or "?",
                                     "phase": phase})
        elif status == "active":
            m["active"] += 1
            out["active_total"] += 1
        elif status in ("done", "failed"):
            if verdict == "PASS":
                m["pass"] += 1
                if phase in PHASE_ORDER:
                    ea_pass_phases[ea_id].add(phase)
            elif verdict == "FAIL":
                m["fail"] += 1
            elif verdict == "INVALID":
                m["invalid"] += 1
            else:
                m["other"] += 1

        vr = str(payload.get("verdict_reason") or "")
        pf = payload.get("preflight_failure")
        if pf or vr in _PREFLIGHT_REASONS:
            reason = vr
            if not reason:
                if isinstance(pf, dict):
                    reason = str(pf.get("reason") or pf.get("verdict_reason") or "preflight_failure")
                elif isinstance(pf, str):
                    reason = pf
                else:
                    reason = "preflight_failure"
            build_failures.append({"ea_id": ea_id, "symbol": w.get("symbol") or "?",
                                   "phase": phase, "reason": reason})

        ran = _ran_real_mt5(status, payload, w.get("claimed_by"), w.get("evidence_path"))
        upd = (w.get("updated_at") or "")[:10]
        try:
            d = dt.date.fromisoformat(upd)
        except Exception:
            d = None
        if d and status in ("done", "failed"):
            rec = {"ea_id": ea_id, "ran": ran, "verdict": verdict}
            if d == today:
                buckets["today"].append(rec)
            if d == yesterday:
                buckets["yesterday"].append(rec)
            if d >= today - dt.timedelta(days=6):
                buckets["d7"].append(rec)
            if d >= today - dt.timedelta(days=29):
                buckets["d30"].append(rec)

    out["phase_matrix"] = {p: dict(c) for p, c in phase_matrix.items()}
    out["pending_list"] = pending_list
    out["distinct_eas"] = len(wi_eas)

    p4_idx = PHASE_ORDER.index("P4") if "P4" in PHASE_ORDER else 99
    for ea_id, phases in ea_pass_phases.items():
        if "P8" in phases:
            out["p8_pass_eas"].append(ea_id)
        if any(p in PHASE_ORDER and PHASE_ORDER.index(p) >= p4_idx for p in phases):
            out["p4plus_eas"].append(ea_id)

    for name, recs in buckets.items():
        completed = recs
        real = [r for r in recs if r["ran"]]
        out["daily"][name] = {
            "completed": len(completed),
            "real_mt5": len(real),
            "preflight": len(completed) - len(real),
            "eas": len({r["ea_id"] for r in real}),
            "pass": sum(1 for r in completed if r["verdict"] == "PASS"),
            "fail": sum(1 for r in completed if r["verdict"] == "FAIL"),
            "invalid": sum(1 for r in completed if r["verdict"] == "INVALID"),
        }

    # build-artifact failures grouped by reason
    bf_by_reason: dict[str, list[dict]] = defaultdict(list)
    for bf in build_failures:
        bf_by_reason[bf["reason"]].append(bf)
    out["build_fail_total"] = len(build_failures)
    out["build_failures"] = sorted(
        ({"reason": r, "count": len(items),
          "eas": sorted({i["ea_id"] for i in items})}
         for r, items in bf_by_reason.items()),
        key=lambda x: -x["count"],
    )

    # open agent tasks
    agent_open = []
    for t in atasks:
        state = str(t.get("state") or "")
        if state not in _OPEN_AGENT_STATES:
            continue
        try:
            payload = json.loads(t.get("payload_json") or "{}")
        except Exception:
            payload = {}
        age_h = _age_hours(t.get("updated_at") or "")
        agent_open.append({
            "id": str(t.get("id") or "")[:8],
            "type": t.get("task_type") or "?",
            "state": state,
            "agent": t.get("assigned_agent") or payload.get("target_agent_profile") or "—",
            "priority": t.get("priority"),
            "artifact": t.get("artifact_path") or payload.get("expected_artifact") or "",
            "age_h": round(age_h, 1),
            "sla_late": age_h > _AGENT_SLA_H.get(state, 24),
        })
    out["agent_tasks"] = agent_open
    out["agent_open_count"] = len(agent_open)

    # live-vs-archive coverage
    detail_eas = {ea["ea_id"] for ea in eas}
    out["coverage"] = {
        "distinct_eas_in_work_items": len(wi_eas),
        "rendered_ea_detail_pages": len(detail_eas),
        "db_eas_without_detail_page": sorted(wi_eas - detail_eas),
        "archive_pages_without_current_work_items": sorted(detail_eas - wi_eas),
    }

    # bottleneck = pipeline phase holding the most pending work
    pl_phases = [p for p in PHASE_ORDER if p in phase_matrix]
    bottleneck_phase = None
    bottleneck_pending = 0
    for p in pl_phases:
        pend = phase_matrix[p].get("pending", 0)
        if pend > bottleneck_pending:
            bottleneck_pending = pend
            bottleneck_phase = p
    out["bottleneck"] = (
        f"{phase_label(bottleneck_phase)} · {bottleneck_pending} pending"
        if bottleneck_phase else "queue drained"
    )
    return out


def derive_next_action(cockpit: dict, mt5: dict) -> tuple[str, bool]:
    """Return (recommended-action-text, is_bad) for the decision band."""
    running = mt5.get("running_count", 0)
    if running == 0:
        return ("MT5 fleet idle — restart QM_StrategyFarm terminal workers "
                "(mission-failure signal, Mission Baseline 2026-05-09).", True)
    if cockpit.get("build_fail_total", 0) >= 25:
        return (f"{cockpit['build_fail_total']} work items rejected on missing "
                f".ex5 / setfiles — route a build/registry cleanup task; these are "
                f"build defects, not strategy failures.", True)
    if cockpit.get("p8_pass_eas"):
        eas = ", ".join(cockpit["p8_pass_eas"][:3])
        return (f"{len(cockpit['p8_pass_eas'])} EA(s) at Q11 PASS ({eas}) — "
                f"review for the OWNER Q12 portfolio gate.", False)
    if running < MT5_FLEET_WARN_THRESHOLD:
        return (f"Only {running}/{MT5_FLEET_TOTAL} terminals running — push more "
                f"backlog so the factory bottleneck stays saturated.", True)
    if cockpit.get("pending_total", 0) > 0:
        return (f"Let T1–T10 drain {cockpit['pending_total']} pending work items; "
                f"current bottleneck: {cockpit['bottleneck']}.", False)
    return ("Pipeline queue drained — enqueue the next backlog batch.", False)


# ── Section renderers ────────────────────────────────────────────


def render_phase_dots(completed: list[str], current: str | None, failed_at: str | None) -> str:
    out = []
    for phase in PHASE_ORDER:
        cls = "phase-dot"
        symbol = "─"
        if phase in (completed or []):
            cls += " phase-done"
            symbol = "✓"
        elif phase == current:
            cls += " phase-current"
            symbol = "●"
        elif phase == failed_at:
            cls += " phase-failed"
            symbol = "✗"
        out.append(
            f'<span class="{cls}" title="{e(phase_label(phase, include_name=True))}"><span class="phase-sym">{symbol}</span>'
            f'<span class="phase-label">{e(phase_label(phase))}</span></span>'
        )
    return "".join(out)


def render_hero(state: dict) -> str:
    eas = derive_ea_candidates(state["tasks"], state.get("_root"))
    live_eas = [ea for ea in eas if ea["live"]]
    advancing = [ea for ea in eas if not ea["dead"] and not ea["live"]]
    target = 5

    leader = max(advancing, key=lambda x: len(x["completed_phases"])) if advancing else None
    completed_total = len(live_eas)
    progress_pct = int(completed_total / target * 100)

    portfolio_dots = "".join(
        f'<span class="port-dot {"filled" if i < completed_total else ""}"></span>'
        for i in range(target)
    )

    heureka_total = len(PHASE_ORDER)

    if leader:
        heureka_completed = len(leader["completed_phases"])
        heureka_pct = int(100 * heureka_completed / heureka_total) if heureka_total else 0
        # Compute next gate label from PHASE_ORDER
        current_idx = None
        try:
            current_idx = PHASE_ORDER.index(leader["current_phase"])
        except (ValueError, KeyError):
            current_idx = None
        next_gate = "live"
        if current_idx is not None and current_idx + 1 < heureka_total:
            next_gate = PHASE_ORDER[current_idx + 1]
        phases_html = render_phase_dots(leader["completed_phases"], leader["current_phase"], leader.get("failed_at"))
        heureka_leader_block = f"""
      <div class="heureka-leader">
        <div class="heureka-leader-row">
          <span class="heureka-leader-label">Active</span>
          <code class="heureka-leader-ea">{e(leader["ea_id"])}</code>
          <span class="heureka-leader-slug">{e(leader["slug"])}</span>
        </div>
        <div class="heureka-leader-row">
          <span class="heureka-leader-label">Current</span>
          <strong class="heureka-leader-phase">{e(phase_label(leader["current_phase"]))}</strong>
          <span class="heureka-leader-arrow">→</span>
          <span class="heureka-leader-next">next: <strong>{e(phase_label(next_gate) if next_gate != "live" else "live")}</strong></span>
        </div>
      </div>"""
    else:
        heureka_completed = 0
        heureka_pct = 0
        phases_html = render_phase_dots([], None, None)
        heureka_leader_block = (
            '<div class="heureka-leader heureka-leader-empty">'
            'no EA in flight · pump research → Q00 approve → Codex build'
            '</div>'
        )

    return f"""
<section class="hero">
  <div class="hero-row">
    <div class="hero-portfolio">
      <div class="hero-label">Portfolio · FTMO target 5 EAs</div>
      <div class="hero-dots">{portfolio_dots}</div>
      <div class="hero-count"><strong>{completed_total}</strong> / {target} live · {progress_pct}%</div>
    </div>
    <div class="hero-heureka">
      <div class="hero-label">Heureka · leader EA progress
        <span class="heureka-meter"><span class="heureka-meter-num">{heureka_completed}</span><span class="heureka-meter-tot">/{heureka_total}</span><span class="heureka-meter-pct">· {heureka_pct}%</span></span>
      </div>
      <div class="phase-bar">{phases_html}</div>
      {heureka_leader_block}
    </div>
  </div>
</section>
"""


def render_fleet(mt5: dict) -> str:
    running = mt5["running_count"]
    total = MT5_FLEET_TOTAL
    pct = int(running / total * 100) if total else 0

    if running >= total:
        cls = "fleet-saturated"
        signal = "Saturated · mission on-track"
    elif running >= MT5_FLEET_WARN_THRESHOLD:
        cls = "fleet-partial"
        signal = "Partial — push backlog"
    else:
        cls = "fleet-idle"
        signal = "MT5 idle — mission-failure signal"

    rows = []
    for i in range(total):
        if i < running:
            rows.append(f'<div class="t-row t-busy"><span class="t-name">T{i+1}</span><span class="t-status">running</span></div>')
        else:
            rows.append(f'<div class="t-row t-idle"><span class="t-name">T{i+1}</span><span class="t-status">idle</span></div>')

    return f"""
<section class="card fleet-card {cls}">
  <h3 class="card-title">MT5 Fleet</h3>
  <div class="fleet-pct"><strong>{running}/{total}</strong> · {pct}%</div>
  <div class="fleet-signal">{e(signal)}</div>
  <div class="fleet-grid">{"".join(rows)}</div>
</section>
"""


def render_throughput(state: dict) -> str:
    tp = throughput_last_7d(state["events"])
    return f"""
<section class="card throughput-card">
  <h3 class="card-title">Throughput · 7d</h3>
  <div class="tp-row">
    <span class="tp-label">Sources claimed</span>
    <span class="tp-spark">{sparkline(tp["sources_per_day"])}</span>
    <span class="tp-total">{sum(tp["sources_per_day"])}</span>
  </div>
  <div class="tp-row">
    <span class="tp-label">Task transitions</span>
    <span class="tp-spark">{sparkline(tp["tasks_per_day"])}</span>
    <span class="tp-total">{sum(tp["tasks_per_day"])}</span>
  </div>
  <div class="tp-row">
    <span class="tp-label">Total events</span>
    <span class="tp-spark">{sparkline(tp["events_per_day"])}</span>
    <span class="tp-total">{sum(tp["events_per_day"])}</span>
  </div>
  <div class="tp-days">{e(' '.join(tp['days']))}</div>
</section>
"""


def render_pipeline_table(state: dict) -> str:
    eas = derive_ea_candidates(state["tasks"], state.get("_root"))[:10]
    if not eas:
        return """
<section class="pipeline-section">
  <h2 class="section-title">Pipeline · top 10 EAs</h2>
  <div class="empty">No EA candidates yet. The first Codex build creates the first row here.</div>
</section>
"""

    rows = []
    for ea in eas:
        bar = ""
        for phase in PHASE_ORDER:
            cls = "minibar-cell"
            if phase in ea["completed_phases"]:
                cls += " mb-done"
            elif phase == ea["current_phase"]:
                cls += " mb-current"
            elif phase == ea["failed_at"]:
                cls += " mb-failed"
            bar += f'<span class="{cls}" title="{e(phase)}"></span>'

        if ea["live"]:
            label, status_cls = "LIVE", "st-live"
        elif ea["dead"]:
            label, status_cls = "DEAD", "st-dead"
        else:
            label, status_cls = "FLOW", "st-flow"

        rows.append(f"""
        <tr>
          <td class="td-ea"><code>{e(ea["ea_id"])}</code></td>
          <td class="td-slug">{e(ea["slug"])}</td>
          <td class="td-bar">{bar}</td>
          <td class="td-phase"><strong>{e(ea["current_phase"])}</strong></td>
          <td><span class="status-pill {status_cls}">{label}</span></td>
        </tr>
        """)

    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Pipeline · top 10 EAs by recency</h2>
  <table class="pipeline-table">
    <thead>
      <tr><th>EA</th><th>Slug</th><th>Progress G0..P10</th><th>Phase</th><th>Status</th></tr>
    </thead>
    <tbody>
      {"".join(rows)}
    </tbody>
  </table>
</section>
"""


def render_blockers(state: dict, mt5: dict) -> str:
    blockers = []
    for s in state["sources"]:
        if s.get("status") == "blocked":
            blockers.append({"severity": "high", "text": f'Source <code>{e(s.get("title",""))}</code> blocked'})

    for t in state["tasks"]:
        if t.get("status") == "blocked":
            payload = t.get("payload", {})
            reason = payload.get("blocked_reason") or "unspecified"
            blockers.append({
                "severity": "high",
                "text": f'Task <code>{e(t.get("kind",""))}</code> blocked: {e(reason)}'
            })
        elif t.get("status") == "failed":
            payload = t.get("payload", {})
            reason = payload.get("timeout_reason") or payload.get("failure_reason") or "unspecified"
            blockers.append({
                "severity": "med",
                "text": f'Task <code>{e(t.get("kind",""))}</code> failed: {e(reason)}'
            })

    if mt5["running_count"] == 0:
        blockers.append({
            "severity": "high",
            "text": "MT5 fleet completely idle — mission-failure signal (Mission Baseline 2026-05-09)."
        })
    elif mt5["running_count"] < MT5_FLEET_WARN_THRESHOLD:
        blockers.append({
            "severity": "med",
            "text": f"{MT5_FLEET_TOTAL - mt5['running_count']}/{MT5_FLEET_TOTAL} MT5 terminals idle — push more backlog through."
        })

    if not blockers:
        return (
            '<section class="blockers-section">'
            '<h2 class="section-title">Blockers · what is NOT moving</h2>'
            '<div class="empty empty-good">No blockers detected. Flow is healthy.</div>'
            '</section>'
        )

    items = "".join(f'<li class="blocker-item blocker-{b["severity"]}">{b["text"]}</li>' for b in blockers)
    return f"""
<section class="blockers-section">
  <h2 class="section-title">Blockers · what is NOT moving</h2>
  <ul class="blockers-list">{items}</ul>
</section>
"""


def render_events(state: dict) -> str:
    events = state["events"][:15]
    if not events:
        return (
            '<section class="events-section">'
            '<h2 class="section-title">Recent Events · last 15</h2>'
            '<div class="empty">No events recorded yet.</div>'
            '</section>'
        )

    rows = []
    for ev in events:
        ts = ev.get("ts", "")
        try:
            t = dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
            time_str = t.strftime("%m-%d %H:%M")
        except Exception:
            time_str = ts[:16] if ts else "?"

        detail = ev.get("detail", {})
        if isinstance(detail, dict):
            if "kind" in detail:
                detail_str = detail.get("kind", "") + (f' · card={detail.get("card_id","")}' if detail.get("card_id") else "")
            elif "to" in detail and "from" in detail:
                detail_str = f"{detail.get('from','?')} → {detail.get('to','?')}"
            else:
                detail_str = ", ".join(f"{k}={v}" for k, v in list(detail.items())[:3])
        else:
            detail_str = str(detail)

        rows.append(f"""
        <tr>
          <td class="ev-time">{e(time_str)}</td>
          <td class="ev-type">{e(ev.get("entity_type", ""))}</td>
          <td class="ev-event">{e(ev.get("event", ""))}</td>
          <td class="ev-detail">{e(detail_str)}</td>
        </tr>
        """)

    return f"""
<section class="events-section">
  <h2 class="section-title">Recent Events · last 15</h2>
  <table class="events-table"><tbody>{"".join(rows)}</tbody></table>
</section>
"""


def render_decision_band(cockpit: dict, mt5: dict) -> str:
    running = mt5.get("running_count", 0)
    p8 = len(cockpit.get("p8_pass_eas") or [])
    p4p = len(cockpit.get("p4plus_eas") or [])
    pending = cockpit.get("pending_total", 0)
    fleet_cls = "good" if running >= MT5_FLEET_WARN_THRESHOLD else ("warn" if running else "bad")
    p8_cls = "good" if p8 else "small"
    p8_val = str(p8) if p8 else "none"
    action, bad = derive_next_action(cockpit, mt5)
    return f"""
<section class="decision-band">
  <h2 class="section-title">Current Decision State</h2>
  <div class="decision-tiles">
    <div class="dt">
      <div class="dt-label">Q11 PASS candidates</div>
      <div class="dt-val {p8_cls}">{e(p8_val)}</div>
      <div class="dt-sub">{p4p} EA(s) survived P4+</div>
    </div>
    <div class="dt">
      <div class="dt-label">MT5 fleet running</div>
      <div class="dt-val {fleet_cls}">{running}/{MT5_FLEET_TOTAL}</div>
      <div class="dt-sub">{cockpit.get("active_total", 0)} work items active</div>
    </div>
    <div class="dt">
      <div class="dt-label">Pipeline backlog</div>
      <div class="dt-val {"warn" if pending else "good"}">{pending}</div>
      <div class="dt-sub">work items pending</div>
    </div>
    <div class="dt">
      <div class="dt-label">Active bottleneck</div>
      <div class="dt-val small">{e(cockpit.get("bottleneck", "—"))}</div>
      <div class="dt-sub">phase holding most pending work</div>
    </div>
  </div>
  <div class="next-action{" bad" if bad else ""}">
    <span class="na-label">Next action</span>
    <span>{e(action)}</span>
  </div>
</section>
"""


def render_queue_health(cockpit: dict) -> str:
    pm = cockpit.get("phase_matrix") or {}
    phases = [p for p in PHASE_ORDER if p in pm]
    if not phases:
        return ('<section class="card"><h3 class="card-title">Pipeline Queue Health</h3>'
                '<div class="empty">No work items yet.</div></section>')
    rows = []
    for p in phases:
        m = pm[p]
        pend, act = m.get("pending", 0), m.get("active", 0)
        ps, fl, inv = m.get("pass", 0), m.get("fail", 0), m.get("invalid", 0)
        rows.append(
            f'<tr><td class="qh-phase">{e(phase_label(p))}</td>'
            f'<td class="{"" if pend else "cell-zero"}">{pend}</td>'
            f'<td class="{"cell-act" if act else "cell-zero"}">{act}</td>'
            f'<td class="{"cell-pass" if ps else "cell-zero"}">{ps}</td>'
            f'<td class="{"cell-fail" if fl else "cell-zero"}">{fl}</td>'
            f'<td class="{"cell-inv" if inv else "cell-zero"}">{inv}</td>'
            f'<td>{m.get("total", 0)}</td></tr>'
        )
    return (
        '<section class="card">'
        '<h3 class="card-title">Pipeline Queue Health · by phase</h3>'
        '<table class="qh-table"><thead><tr><th>Phase</th><th>Pending</th><th>Active</th>'
        '<th>PASS</th><th>FAIL</th><th>INVALID</th><th>Total</th></tr></thead>'
        f'<tbody>{"".join(rows)}</tbody></table></section>'
    )


def render_coverage(cockpit: dict) -> str:
    cov = cockpit.get("coverage") or {}
    db_n = cov.get("distinct_eas_in_work_items", 0)
    pages = cov.get("rendered_ea_detail_pages", 0)
    no_page = cov.get("db_eas_without_detail_page") or []
    no_wi = cov.get("archive_pages_without_current_work_items") or []
    gap = ""
    if no_page:
        gap = (f'<details class="cp-details"><summary>{len(no_page)} DB EA(s) with no rendered detail page'
               f'</summary><div class="attn-detail">{e(", ".join(no_page))}</div>'
               f'<div class="cp-subnote">Renderer action: include these ea_ids in derive_ea_candidates() '
               f'so a detail page is generated.</div></details>')
    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Live Pipeline vs Strategy Archive</h2>
  <div class="cov-grid">
    <div class="cov-tile"><div class="cov-num">{db_n}</div><div class="cov-label">Distinct EAs · live work_items</div></div>
    <div class="cov-tile"><div class="cov-num">{pages}</div><div class="cov-label">Rendered EA detail pages</div></div>
    <div class="cov-tile"><div class="cov-num {"warn" if no_page else ""}">{len(no_page)}</div><div class="cov-label">DB EAs w/o detail page</div></div>
    <div class="cov-tile"><div class="cov-num {"warn" if no_wi else ""}">{len(no_wi)}</div><div class="cov-label">Archive pages w/o work_items</div></div>
  </div>
  <div class="cov-note"><strong>Strategy Archive (<code>strategies.html</code>) is a broader history, not a live mirror.</strong>
  Only the {db_n} EAs above have current pipeline work items; the remaining detail pages are archive / legacy / research
  entries. The archive row count must not be read as live factory progress.</div>
  {gap}
</section>
"""


def render_daily_controlling(cockpit: dict) -> str:
    daily = cockpit.get("daily") or {}
    order = [("today", "Today"), ("yesterday", "Yesterday"),
             ("d7", "Last 7 days"), ("d30", "Last 30 days")]
    rows = []
    for key, label in order:
        d = daily.get(key) or {}
        rows.append(
            f'<tr><td>{e(label)}</td>'
            f'<td>{d.get("real_mt5", 0)}</td>'
            f'<td>{d.get("eas", 0)}</td>'
            f'<td class="{"cell-pass" if d.get("pass") else "cell-zero"}">{d.get("pass", 0)}</td>'
            f'<td class="{"cell-fail" if d.get("fail") else "cell-zero"}">{d.get("fail", 0)}</td>'
            f'<td class="{"cell-inv" if d.get("invalid") else "cell-zero"}">{d.get("invalid", 0)}</td>'
            f'<td class="cell-zero">{d.get("preflight", 0)}</td></tr>'
        )
    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Daily Controlling · factory throughput</h2>
  <table class="ctrl-table">
    <thead><tr><th>Window</th><th>Real MT5 runs</th><th>Distinct EAs</th>
    <th>PASS</th><th>FAIL</th><th>INVALID</th><th>Preflight-rejected</th></tr></thead>
    <tbody>{"".join(rows)}</tbody>
  </table>
  <div class="cp-subnote">"Real MT5 runs" counts only work items that actually launched a tester run
  (terminal claim / run_smoke exit / report evidence). "Preflight-rejected" items failed artifact checks
  before MT5 started — they are not backtests. Q10-style Python-only analysis gates are not separately
  flagged: the work_items schema has no execution_kind column (residual limitation, DEEP_AUDIT 2026-05-20).</div>
</section>
"""


def render_build_integrity(cockpit: dict) -> str:
    bf = cockpit.get("build_failures") or []
    total = cockpit.get("build_fail_total", 0)
    if not bf:
        return ('<section class="pipeline-section"><h2 class="section-title">Build Artifact Integrity</h2>'
                '<div class="empty empty-good">No preflight / build-artifact failures in the queue.</div></section>')
    rows = []
    for g in bf[:8]:
        eas = g["eas"]
        sample = ", ".join(eas[:8]) + (f"  +{len(eas) - 8} more" if len(eas) > 8 else "")
        rows.append(
            f'<div class="attn-group attn-med"><div class="attn-head">'
            f'<span class="attn-count">{g["count"]}×</span> {e(g["reason"])}</div>'
            f'<div class="attn-detail">{e(sample)}</div></div>'
        )
    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Build Artifact Integrity · {total} work items blocked</h2>
  {"".join(rows)}
  <div class="cp-subnote">These are build / registry defects (missing .ex5, missing or stale setfiles,
  ambiguous EA directory) — not strategy failures. Route as build cleanup tasks, never as strategy FAIL.</div>
</section>
"""


def render_agent_tasks(cockpit: dict) -> str:
    tasks = cockpit.get("agent_tasks") or []
    if not tasks:
        return ('<section class="pipeline-section"><h2 class="section-title">Agent Router · open tasks</h2>'
                '<div class="empty">No open agent_tasks.</div></section>')
    by_state = Counter(t["state"] for t in tasks)
    summary = " · ".join(f"{c} {s}" for s, c in by_state.most_common())
    rows = []
    for t in tasks:
        st = t["state"]
        st_cls = {"BLOCKED": "at-blocked", "IN_PROGRESS": "at-progress",
                  "REVIEW": "at-review"}.get(st, "at-other")
        sla_cls = "sla-late" if t["sla_late"] else "sla-ok"
        art = t["artifact"] or "—"
        art_disp = ("…" + art[-38:]) if len(art) > 40 else art
        rows.append(
            f'<tr><td>{e(t["id"])}</td><td>{e(t["type"])}</td>'
            f'<td><span class="at-state {st_cls}">{e(st)}</span></td>'
            f'<td>{e(str(t["agent"]))}</td><td>p{e(str(t["priority"]))}</td>'
            f'<td class="{sla_cls}">{t["age_h"]}h</td>'
            f'<td style="text-align:left;color:var(--qm-text-muted)">{e(art_disp)}</td></tr>'
        )
    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Agent Router · {len(tasks)} open tasks</h2>
  <table class="atask-table">
    <thead><tr><th>ID</th><th>Type</th><th>State</th><th>Agent</th>
    <th>Prio</th><th>Age</th><th>Artifact</th></tr></thead>
    <tbody>{"".join(rows)}</tbody>
  </table>
  <div class="cp-subnote">{e(summary)} — non-terminal router work, including blocked Claude tasks and
  active Codex / Gemini tasks. SLA age in red is past the per-state limit.</div>
</section>
"""


def render_needs_attention(cockpit: dict, mt5: dict) -> str:
    groups: list[tuple[str, str, str]] = []
    running = mt5.get("running_count", 0)
    if running == 0:
        groups.append(("high", "MT5 fleet completely idle",
                       f"0/{MT5_FLEET_TOTAL} terminals — mission-failure signal."))
    elif running < MT5_FLEET_WARN_THRESHOLD:
        groups.append(("med", f"{MT5_FLEET_TOTAL - running}/{MT5_FLEET_TOTAL} MT5 terminals idle",
                       "Push more backlog to keep the factory bottleneck saturated."))
    bf = cockpit.get("build_fail_total", 0)
    if bf:
        groups.append(("med", f"{bf} work items blocked on build artifacts",
                       "Missing .ex5 / setfiles — see Build Artifact Integrity above."))
    late = [t for t in cockpit.get("agent_tasks") or [] if t["sla_late"]]
    if late:
        groups.append(("med", f"{len(late)} agent task(s) past SLA",
                       ", ".join(f'{t["id"]} {t["type"]} ({t["age_h"]}h)' for t in late[:5])))
    for p, m in (cockpit.get("phase_matrix") or {}).items():
        inv, tot = m.get("invalid", 0), m.get("total", 1) or 1
        if inv >= 100 and inv / tot > 0.4:
            groups.append(("low", f"{phase_label(p)} INVALID rate {int(100 * inv / tot)}%",
                           f"{inv} of {tot} {phase_label(p)} work items INVALID — mostly preflight / infra, "
                           f"verify the root cause is not a real strategy failure."))
    if not groups:
        return ('<section class="pipeline-section"><h2 class="section-title">Needs Attention</h2>'
                '<div class="empty empty-good">Nothing flagged — flow is healthy.</div></section>')
    sev_rank = {"high": 0, "med": 1, "low": 2}
    groups.sort(key=lambda g: sev_rank[g[0]])
    items = "".join(
        f'<div class="attn-group attn-{sev}"><div class="attn-head">'
        f'<span class="attn-count">●</span> {e(head)}</div>'
        f'<div class="attn-detail">{e(detail)}</div></div>'
        for sev, head, detail in groups
    )
    return f"""
<section class="pipeline-section">
  <h2 class="section-title">Needs Attention · grouped by reason</h2>
  {items}
</section>
"""


# ── Strategy Archive ─────────────────────────────────────────────


ARCHIVE_CSS = """
.archive-hero{padding:48px 36px 32px;text-align:center;position:relative;border-bottom:1px solid var(--border)}
.archive-hero h1{font-size:clamp(30px,4.5vw,46px);font-weight:600;letter-spacing:-0.03em;line-height:1.05;margin-bottom:12px;position:relative;z-index:1}
.archive-hero h1 .em-text{color:var(--signal)}
.archive-hero-sub{font-family:var(--font-mono);font-size:12px;color:var(--text-3);max-width:740px;margin:0 auto 24px;line-height:1.6;letter-spacing:0.04em;position:relative;z-index:1}
.lane-summary{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;margin-bottom:0;position:relative;z-index:1}
.lane-tile{padding:14px 22px;background:var(--surface-1);border:1px solid var(--border);min-width:120px;text-align:center}
.lane-tile-num{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:26px;font-weight:500;color:var(--signal);line-height:1;letter-spacing:-0.03em}
.lane-tile.lane-dead .lane-tile-num{color:var(--fail)}
.lane-tile.lane-flow .lane-tile-num{color:var(--live)}
.lane-tile-label{font-family:var(--font-mono);font-size:10px;font-weight:600;color:var(--text-3);margin-top:6px;letter-spacing:0.16em;text-transform:uppercase}
.transparency-banner{max-width:1400px;margin:24px auto 18px;padding:14px 22px;background:var(--surface-1);border:1px solid var(--border);border-left:2px solid var(--signal);font-family:var(--font-mono);font-size:11px;color:var(--text-2);line-height:1.6;letter-spacing:0.04em}
.transparency-banner strong{color:var(--signal);font-weight:700;letter-spacing:0.14em;text-transform:uppercase}

.controls{max-width:1400px;margin:0 auto 14px;padding:0 36px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
.controls input[type=search],.controls select{background:var(--surface-2);border:1px solid var(--border-2);padding:8px 12px;font-size:12px;color:var(--text);font-family:var(--font-mono);outline:none;min-width:160px}
.controls input[type=search]:focus,.controls select:focus{border-color:var(--signal)}
.controls .ctl-label{font-family:var(--font-mono);font-size:10px;color:var(--text-3);text-transform:uppercase;letter-spacing:0.18em;font-weight:700;margin-right:-4px}
.controls .row-count{margin-left:auto;font-family:var(--font-mono);font-size:11px;color:var(--text-3);letter-spacing:0.08em;text-transform:uppercase}
.controls .row-count strong{color:var(--signal);font-weight:700}

.archive-table-wrap{max-width:1400px;margin:0 auto;padding:0 36px}
.archive-table{width:100%;border-collapse:collapse;font-size:12px;background:var(--surface-1);border:1px solid var(--border);font-family:var(--font-mono)}
.archive-table thead th{text-align:left;font-size:10px;color:var(--text-3);text-transform:uppercase;letter-spacing:0.16em;padding:11px 14px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);font-weight:700;background:var(--bg);cursor:pointer;user-select:none;position:sticky;top:0;z-index:2}
.archive-table thead th:last-child{border-right:none}
.archive-table thead th:hover{color:var(--text)}
.archive-table thead th.sort-asc::after{content:" \\25B2";color:var(--signal);font-size:9px}
.archive-table thead th.sort-desc::after{content:" \\25BC";color:var(--signal);font-size:9px}
.archive-table thead th.col-num{text-align:right}
.archive-table tbody tr{cursor:pointer}
.archive-table tbody tr:hover td{background:var(--surface-2)}
.archive-table tbody td{padding:10px 14px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);vertical-align:middle}
.archive-table tbody td:last-child{border-right:none}
.archive-table tbody td.col-num{text-align:right;font-variant-numeric:tabular-nums}
.archive-table tbody tr:last-child td{border-bottom:none}
.archive-table tr.row-hidden{display:none}
.archive-table .td-ea code{font-family:var(--font-mono);color:var(--text);font-weight:600;font-size:12px;letter-spacing:0.02em}
.archive-table .td-slug{color:var(--text-3)}
.archive-table .progress-bar{display:inline-flex;gap:2px;vertical-align:middle}
.archive-table .progress-bar .pcell{width:11px;height:9px;background:var(--surface-2);border:1px solid var(--border)}
.archive-table .progress-bar .pcell.p-done{background:var(--signal);border-color:var(--signal)}
.archive-table .progress-bar .pcell.p-current{background:var(--live);border-color:var(--live)}
.archive-table .progress-bar .pcell.p-failed{background:var(--fail);border-color:var(--fail)}
.archive-table .v-pass,.archive-table .net-pos{color:var(--signal);font-weight:600}
.archive-table .v-fail,.archive-table .net-neg{color:var(--fail);font-weight:600}
.archive-table .v-invalid{color:var(--promising)}
.archive-table .v-pending{color:var(--text-3)}
.archive-table .status-chip{font-size:10px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;display:inline-block}
.archive-table .status-chip.s-dead{color:var(--fail);background:transparent}
.archive-table .status-chip.s-flow{color:var(--live);background:transparent}
.archive-table .status-chip.s-live{color:var(--signal);background:transparent}
.archive-table .status-chip.s-prog{color:var(--promising);background:transparent}
.archive-table .status-chip.s-card{color:var(--text-3);background:transparent}
.archive-table tr.row-card-only{cursor:default;opacity:0.85}
.archive-table tr.row-card-only:hover{background:var(--surface-1)}
.achip.c-card .achip-num{color:var(--text-3)}

.archive-footer{margin:40px auto 48px;max-width:1400px;padding:0 36px;font-family:var(--font-mono);font-size:11px;color:var(--text-3);text-align:center;line-height:1.7;letter-spacing:0.06em}
"""


EA_DETAIL_CSS = """
.detail-wrap{max-width:1200px;margin:0 auto;padding:28px 36px 80px}
.detail-back{display:inline-flex;align-items:center;gap:6px;color:var(--text-3);font-family:var(--font-mono);font-size:11px;font-weight:600;letter-spacing:0.14em;text-transform:uppercase;text-decoration:none;margin-bottom:18px;padding:6px 12px;border:1px solid var(--border-2);background:transparent}
.detail-back:hover{border-color:var(--signal);color:var(--signal)}
.detail-head{display:flex;align-items:flex-end;justify-content:space-between;gap:24px;flex-wrap:wrap;margin-bottom:6px;border-bottom:1px solid var(--border);padding-bottom:14px}
.detail-head h1{font-size:30px;font-weight:600;letter-spacing:-0.03em;line-height:1.1;color:var(--text);margin:0}
.detail-head h1 code{font-family:var(--font-mono);color:var(--text);font-weight:600;letter-spacing:0.01em}
.detail-head h1 .detail-slug{font-family:var(--font-mono);font-size:14px;color:var(--text-3);font-weight:400;margin-left:12px;letter-spacing:0.06em}
.detail-status{padding:5px 12px;font-family:var(--font-mono);font-size:10px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;border:1px solid;background:transparent}
.detail-status.s-dead{color:var(--fail);border-color:var(--fail)}
.detail-status.s-flow{color:var(--live);border-color:var(--live)}
.detail-status.s-live{color:var(--signal);border-color:var(--signal)}

.detail-meta{font-family:var(--font-mono);font-size:11px;color:var(--text-3);margin:14px 0 28px;display:flex;gap:20px;flex-wrap:wrap;letter-spacing:0.04em}
.detail-meta span strong{color:var(--text);font-weight:600}

.detail-desc{padding:22px 24px;background:var(--surface-1);border:1px solid var(--border);margin-bottom:24px}
.detail-desc-title{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:14px}
.detail-desc-body{font-size:13px;color:var(--text);line-height:1.65}
.detail-desc-body p{margin:0 0 10px}
.detail-desc-body em{color:var(--text-3);font-style:italic}
.detail-desc-r{display:flex;gap:6px;margin-top:14px;flex-wrap:wrap}
.r-tag{padding:3px 9px;font-family:var(--font-mono);font-size:10px;letter-spacing:0.06em;background:transparent;border:1px solid var(--border-2);color:var(--text-3)}
.r-tag strong{color:var(--signal);font-weight:700;margin-right:6px;letter-spacing:0.12em;text-transform:uppercase}
.r-tag.r-unknown strong{color:var(--text-4)}
.r-tag.r-fail strong{color:var(--fail)}

.kpi-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:10px;margin-bottom:30px}
.kpi-tile{padding:14px 16px;background:var(--surface-1);border:1px solid var(--border)}
.kpi-tile-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:8px}
.kpi-tile-val{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:22px;font-weight:500;color:var(--text);letter-spacing:-0.02em;line-height:1.05}
.kpi-tile-val.pos{color:var(--signal)}
.kpi-tile-val.neg{color:var(--fail)}
.kpi-tile-sub{font-family:var(--font-mono);font-size:10px;color:var(--text-4);margin-top:6px;letter-spacing:0.06em}

.phase-section{margin-bottom:30px}
.phase-section h2{font-family:var(--font-mono);font-size:11px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin:0 0 12px;display:flex;align-items:center;gap:10px}
.phase-badge{padding:4px 11px;font-family:var(--font-mono);font-size:10px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;border:1px solid var(--signal);color:var(--signal);background:transparent}
.phase-badge.failed{border-color:var(--fail);color:var(--fail)}
.phase-badge.current{border-color:var(--live);color:var(--live)}
.phase-count{font-family:var(--font-mono);font-size:10px;color:var(--text-3);font-weight:600;text-transform:uppercase;letter-spacing:0.14em;margin-left:auto}

.wi-table{width:100%;border-collapse:collapse;font-size:11.5px;background:var(--surface-1);border:1px solid var(--border);font-family:var(--font-mono)}
.wi-table thead th{text-align:left;font-size:9px;color:var(--text-3);text-transform:uppercase;letter-spacing:0.18em;padding:10px 12px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);font-weight:700;background:var(--bg)}
.wi-table thead th:last-child{border-right:none}
.wi-table thead th.col-num{text-align:right}
.wi-table thead th.col-spark{width:200px}
.wi-table tbody td{padding:10px 12px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);vertical-align:middle}
.wi-table tbody td:last-child{border-right:none}
.wi-table tbody tr:last-child td{border-bottom:none}
.wi-table td.col-num{text-align:right;font-variant-numeric:tabular-nums}
.wi-table td.col-spark{padding:6px 12px}
.wi-table td.col-spark svg{display:block}
.wi-table .v-pass{color:var(--signal);font-weight:600}
.wi-table .v-fail{color:var(--fail);font-weight:600}
.wi-table .v-invalid{color:var(--promising);font-weight:600}
.wi-table .v-pending{color:var(--text-3)}
.wi-table .net-pos{color:var(--signal)}
.wi-table .net-neg{color:var(--fail)}
.wi-table .fail-reason{font-family:var(--font-mono);font-size:10px;color:var(--text-3);margin-top:3px;letter-spacing:0.04em}
.wi-table .fail-reason.infra{color:var(--warn)}
.wi-table .fail-reason.strategy{color:var(--fail)}
.wi-table .report-link{font-family:var(--font-mono);font-size:10px;color:var(--live);text-decoration:none;letter-spacing:0.1em;text-transform:uppercase;font-weight:600}
.wi-table .report-link:hover{text-decoration:underline}
.wi-table .net-zero{color:var(--text-3)}
"""


ARCHIVE2_CSS = """
.archive-chips{display:flex;justify-content:center;gap:10px;flex-wrap:wrap;max-width:1400px;margin:18px auto 4px;padding:0 36px}
.achip{padding:12px 18px;background:var(--surface-1);border:1px solid var(--border);min-width:108px;text-align:center}
.achip-num{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:22px;font-weight:500;line-height:1;letter-spacing:-0.02em;color:var(--text)}
.achip-label{font-family:var(--font-mono);font-size:9px;font-weight:600;color:var(--text-3);margin-top:6px;text-transform:uppercase;letter-spacing:0.18em}
.achip.c-p8 .achip-num{color:var(--signal)}
.achip.c-surv .achip-num{color:var(--live)}
.achip.c-dead .achip-num{color:var(--fail)}
.presets{max-width:1400px;margin:8px auto 0;padding:0 36px;display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.preset-label{font-family:var(--font-mono);font-size:10px;color:var(--text-3);text-transform:uppercase;letter-spacing:0.18em;font-weight:700;margin-right:4px}
.preset{padding:7px 14px;background:transparent;border:1px solid var(--border-2);font-family:var(--font-mono);font-size:10px;font-weight:600;letter-spacing:0.14em;text-transform:uppercase;color:var(--text-3);cursor:pointer}
.preset:hover{border-color:var(--signal);color:var(--text)}
.preset.active{background:var(--signal);border-color:var(--signal);color:var(--bg);font-weight:700}
/* row-dead dimming removed 2026-05-23 (OWNER call): dead EAs were
   backtested too and deserve same visibility as flow/active rows.
   Death signal carried by s-dead status color + Death-reason cell. */
.lane-pill{display:inline-block;padding:2px 6px;font-family:var(--font-mono);font-size:8px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;margin-left:6px;border:1px solid}
.lane-pill.lp-live{color:var(--live);border-color:var(--live)}
.lane-pill.lp-arch{color:var(--text-3);border-color:var(--border-2)}
.fail-prof{font-family:var(--font-mono);font-size:10px;color:var(--text-4);margin-top:4px;letter-spacing:0.06em}
.fail-prof.fp-reason{color:var(--text-4);max-width:280px;display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.gate-note{max-width:1400px;margin:10px auto 0;padding:0 36px;font-family:var(--font-mono);font-size:10px;color:var(--text-4);line-height:1.55;letter-spacing:0.04em}
.cov-gap-panel{max-width:1400px;margin:14px auto 0;padding:12px 20px;background:var(--surface-1);border:1px solid var(--warn);border-left-width:2px;font-family:var(--font-mono);font-size:11px;color:var(--text-2);line-height:1.55;letter-spacing:0.04em}
.cov-gap-panel strong{color:var(--warn);font-weight:700;letter-spacing:0.14em;text-transform:uppercase}
"""


DETAIL2_CSS = """
.decision-header{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:16px 0 18px}
.dh-tile{padding:14px 16px;background:var(--surface-1);border:1px solid var(--border)}
.dh-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:8px}
.dh-val{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:18px;font-weight:500;color:var(--text);line-height:1.15;letter-spacing:-0.01em}
.dh-val.good{color:var(--signal)}
.dh-val.bad{color:var(--fail)}
.dh-val.flow{color:var(--live)}
.decision-summary{padding:20px 22px;background:var(--surface-1);border:1px solid var(--border);margin-bottom:24px}
.decision-summary.ds-bad{border-color:var(--fail);border-left-width:2px}
.decision-summary.ds-good{border-color:var(--signal);border-left-width:2px}
.ds-verdict{font-size:15px;font-weight:600;color:var(--text);margin-bottom:14px;letter-spacing:-0.005em}
.ds-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px 28px}
.ds-item-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--signal);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:5px}
.ds-item-body{font-size:12.5px;color:var(--text-2);line-height:1.6}
.rescue-detail{margin:0 0 24px;padding:18px 20px;background:var(--surface-1);border:1px solid var(--border)}
.rescue-detail-title{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:12px}
.rescue-detail-table .rescue-tier,.rescue-detail-table .rescue-q09{font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;white-space:nowrap}
.rescue-detail-table .rescue-tier.soft{color:var(--warn)}
.rescue-detail-table .rescue-tier.hard{color:var(--fail)}
.rescue-detail-table .rescue-tier.other{color:var(--text-3)}
.rescue-detail-table .rescue-q09.pass{color:var(--signal)}
.rescue-detail-table .rescue-q09.wait{color:var(--promising)}
.rescue-detail-table .rescue-q09.fail{color:var(--fail)}
.rescue-detail-table .rescue-q09.other{color:var(--text-3)}
.facts-table{width:100%;border-collapse:collapse;font-family:var(--font-mono);font-size:11.5px;margin-top:14px}
.facts-table td{padding:7px 10px;border-bottom:1px solid var(--border);vertical-align:top}
.facts-table td:first-child{color:var(--text-3);width:140px;text-transform:uppercase;font-size:9px;letter-spacing:0.18em;font-weight:700}
.facts-table td:last-child{color:var(--text-2);word-break:break-word}
.facts-table tr:last-child td{border-bottom:none}
.src-attrib{font-family:var(--font-mono);font-size:11px;color:var(--text-3);margin-top:14px;line-height:1.5;letter-spacing:0.04em}
.src-attrib strong{color:var(--text-2);font-weight:700;text-transform:uppercase;letter-spacing:0.14em}
.acc-title{font-family:var(--font-mono);font-size:11px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin:0 0 12px}
.stage-acc{margin-bottom:8px;border:1px solid var(--border);background:var(--surface-1)}
.stage-acc>summary{cursor:pointer;padding:14px 18px;list-style:none;display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.stage-acc>summary::-webkit-details-marker{display:none}
.stage-acc>summary::before{content:'\\25B8';color:var(--signal);font-size:11px}
.stage-acc[open]>summary::before{content:'\\25BE'}
.stage-acc[open]>summary{border-bottom:1px solid var(--border)}
.sa-phase{font-family:var(--font-mono);font-weight:700;font-size:13px;color:var(--text);letter-spacing:0.04em}
.sa-legacy{font-family:var(--font-mono);font-size:10px;color:var(--text-3)}
.sa-name{font-family:var(--font-mono);font-size:10px;color:var(--text-3)}
.sa-verdicts{font-family:var(--font-mono);font-size:10px;color:var(--text-3);letter-spacing:0.06em}
.sa-kpi{margin-left:auto;font-family:var(--font-mono);font-size:10px;color:var(--text-2);letter-spacing:0.04em}
.sa-kpi strong{color:var(--signal);font-weight:700}
.sa-body{padding:14px 18px}
.fail-group-box{margin-bottom:14px}
.fail-group-box h4{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin:0 0 8px}
.fail-group-row{display:flex;gap:10px;align-items:baseline;padding:6px 0;font-family:var(--font-mono);font-size:11px;border-bottom:1px solid var(--border)}
.fail-group-row:last-child{border-bottom:none}
.fgr-count{color:var(--fail);font-weight:700;min-width:38px;font-variant-numeric:tabular-nums}
.fgr-count.infra{color:var(--warn)}
.fgr-reason{color:var(--text-2)}
.fgr-syms{color:var(--text-3);font-size:10px;margin-left:auto;text-align:right;letter-spacing:0.04em}
.raw-rows{margin-top:10px}
.raw-rows>summary{cursor:pointer;font-family:var(--font-mono);font-size:10px;font-weight:600;color:var(--text-3);padding:6px 0;list-style:none;letter-spacing:0.12em;text-transform:uppercase}
.raw-rows>summary::-webkit-details-marker{display:none}
.raw-rows>summary::before{content:'\\25B8 ';color:var(--signal)}
.raw-rows[open]>summary::before{content:'\\25BE '}
.attempt-toggle{display:inline-block;margin-left:8px;padding:1px 7px;font-family:var(--font-mono);font-size:9px;font-weight:600;letter-spacing:0.1em;color:var(--text-3);border:1px solid var(--border-2);cursor:pointer;user-select:none}
.attempt-toggle:hover{color:var(--text);border-color:var(--signal)}
.attempt-toggle.open{color:var(--signal);border-color:var(--signal)}
.attempt-row{background:var(--bg)}
.attempt-row td{padding:0!important;border:none!important}
.attempt-row.hidden{display:none}
.att-wrap{padding:6px 12px 12px 28px;font-family:var(--font-mono);font-size:10.5px}
.att-title{font-size:9px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.18em;margin:6px 0 6px}
.att-table{width:100%;border-collapse:collapse;background:transparent}
.att-table th{text-align:left;font-size:9px;color:var(--text-4);text-transform:uppercase;letter-spacing:0.14em;font-weight:700;padding:4px 8px;border-bottom:1px solid var(--border)}
.att-table th.col-num{text-align:right}
.att-table td{padding:4px 8px;border-bottom:1px solid var(--border);vertical-align:middle;color:var(--text-2)}
.att-table td.col-num{text-align:right;font-variant-numeric:tabular-nums}
.att-table tr:last-child td{border-bottom:none}
.att-table .v-pass{color:var(--signal);font-weight:600}
.att-table .v-fail{color:var(--fail);font-weight:600}
.att-table .v-invalid{color:var(--promising);font-weight:600}
.att-table .v-completed{color:var(--text-2);font-weight:600}
.att-table .att-reason{color:var(--text-3);font-size:9.5px;letter-spacing:0.02em}
.att-table .att-promo{display:inline-block;margin-left:6px;padding:1px 6px;font-size:8px;font-weight:700;letter-spacing:0.14em;color:var(--bg);background:var(--signal);text-transform:uppercase}
.wi-table .v-completed{color:var(--text-2);font-weight:600}
.wi-table td.symcell{white-space:nowrap}
.fold-block{margin-bottom:14px}
.fold-criterion{font-size:10px;color:var(--text-3);letter-spacing:0.04em;margin-bottom:6px;font-style:italic}
.fold-table{width:100%;border-collapse:collapse;background:transparent;font-family:var(--font-mono);font-size:10.5px}
.fold-table th{text-align:left;font-size:9px;color:var(--text-4);text-transform:uppercase;letter-spacing:0.14em;font-weight:700;padding:4px 8px;border-bottom:1px solid var(--border);background:var(--surface-1)}
.fold-table th.col-num{text-align:right}
.fold-table td{padding:4px 8px;border-bottom:1px solid var(--border);vertical-align:middle;color:var(--text-2)}
.fold-table td.col-num{text-align:right;font-variant-numeric:tabular-nums}
.fold-table tr:last-child td{border-bottom:none}
.fold-table .fold-id{font-weight:700;color:var(--text)}
.fold-table .net-pos{color:var(--signal);font-weight:600}
.fold-table .net-neg{color:var(--fail);font-weight:600}
.fold-table .clean-yes{color:var(--signal)}
.fold-table .clean-no{color:var(--fail)}
.fold-table .regime{font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-3)}
"""


def _ea_status(ea: dict) -> tuple[str, str]:
    """Return (label, css-class-suffix) for an EA."""
    if ea.get("live"):
        return "LIVE", "s-live"
    if ea.get("dead"):
        return "DEAD", "s-dead"
    return "IN FLOW", "s-flow"


_PASS_REASON_TOKENS = (
    "_pass", "passed", "satisfied", "recommendation",
    "trials_generated", "all_seeds", "hard gates",
)


def _is_pass_reason(reason: str) -> bool:
    """True if a verdict=INVALID row's reason text reads like a PASS marker.

    Q09 / Q10 / Q11 (legacy P6 / P7 / P8) frequently emit rows with
    verdict=INVALID but a reason string that confirms the gate criterion was
    met. We surface these as COMPLETED rather than fail-looking INVALID.
    """
    r = reason.lower()
    return any(tok in r for tok in _PASS_REASON_TOKENS)


# Map any "P3.5" / "P5b" / "P10" token in a pipeline-emitted reason string
# to its canonical Q-id. Long keys first so e.g. "P5b" wins over "P5".
_P_TO_Q_TOKENS = sorted(PHASE_QID.items(), key=lambda kv: -len(kv[0]))
_P_TOKEN_RE = _re_mt5.compile(
    r"\b(" + "|".join(_re_mt5.escape(k) for k, _ in _P_TO_Q_TOKENS) + r")\b"
)


def _parse_summary_stats(evidence_path: str | None) -> dict[str, Any]:
    """Read a work_item summary.json and pull the per-run stats and report path.

    Returns dict with keys: net_profit, trades, drawdown, profit_factor,
    sharpe, report_htm, deals. Any field may be None if the summary lacks it
    (e.g. TIMEOUT runs that never produced a report).
    """
    out: dict[str, Any] = {
        "net_profit": None, "trades": None, "drawdown": None,
        "profit_factor": None, "sharpe": None, "report_htm": None,
        "deals": [],
    }
    if not evidence_path:
        return out
    try:
        p = Path(evidence_path)
        if not (p.exists() and p.suffix == ".json"):
            return out
        sj = json.loads(p.read_text(encoding="utf-8", errors="ignore"))
        runs = sj.get("runs") or []
        if not runs:
            return out
        r0 = runs[0]
        for fld_dst, fld_src in (
            ("net_profit", "net_profit"),
            ("trades", "total_trades"),
            ("drawdown", "drawdown"),
            ("profit_factor", "profit_factor"),
        ):
            v = r0.get(fld_src)
            if v not in (None, ""):
                out[fld_dst] = v
        rp = r0.get("report_canonical_path") or r0.get("report_source_path")
        if rp and Path(rp).exists():
            out["report_htm"] = rp
            try:
                htm = read_mt5_report(Path(rp))
                if htm:
                    more = extract_mt5_stats(htm)
                    if more.get("sharpe") is not None:
                        out["sharpe"] = more["sharpe"]
                    out["deals"] = extract_mt5_deals(htm)
            except Exception:
                pass
    except Exception:
        pass
    return out


def qxx_text(s: str | None) -> str:
    """Rewrite any legacy P-keys in a free-text string to canonical Qxx.

    Operator surfaces must show Qxx only (OWNER hard rule). Pipeline-emitted
    reason strings still contain "P5c", "P7", etc. — this transform cleans
    them on display without changing the stored payload.
    """
    if not s:
        return s or ""
    return _P_TOKEN_RE.sub(lambda m: PHASE_QID.get(m.group(1), m.group(1)), s)


def _json_from_file(path_value: str | None) -> dict[str, Any]:
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


def _payload_from_row(row: dict[str, Any]) -> dict[str, Any]:
    try:
        data = json.loads(row.get("payload_json") or "{}")
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _q08_rescue_tier(verdict: str, payload: dict[str, Any]) -> str:
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
    return verdict or "—"


def _q08_rescue_reason(payload: dict[str, Any]) -> str:
    classification = payload.get("q08_verdict_classification") or payload.get("verdict_classification")
    if not isinstance(classification, dict):
        return str(payload.get("verdict_reason") or payload.get("reason") or "—")
    rank = {"EDGE_HARD": 0, "EDGE_SOFT": 1, "LOW_SAMPLE": 2}
    rows = [
        (rank.get(str(tier).upper(), 9), str(gate), str(tier))
        for gate, tier in classification.items()
        if str(tier).upper() not in {"PASS", ""}
    ]
    if not rows:
        return str(payload.get("verdict_reason") or "—")
    rows.sort()
    return ", ".join(f"{gate}:{tier}" for _, gate, tier in rows[:4])


def _q09_rescue_priority(row: dict[str, Any] | None) -> int:
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


def collect_q08_portfolio_rescue_for_ea(ea_id: str, root: Path) -> list[dict[str, Any]]:
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return []
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        q08_rows = [dict(r) for r in conn.execute(
            """
            SELECT * FROM work_items
            WHERE ea_id=? AND phase='Q08' AND status='done'
              AND verdict IN ('FAIL_SOFT','FAIL_HARD','FAIL','INVALID')
            ORDER BY updated_at DESC
            """,
            (ea_id,),
        )]
        q09_rows = [dict(r) for r in conn.execute(
            """
            SELECT * FROM work_items
            WHERE ea_id=? AND phase='Q09_PORTFOLIO'
            ORDER BY updated_at DESC
            """,
            (ea_id,),
        )]
        try:
            pc_rows = [dict(r) for r in conn.execute(
                """
                SELECT ea_id, symbol, state, evidence_path, updated_at
                FROM portfolio_candidates
                WHERE ea_id=?
                """,
                (ea_id,),
            )]
        except sqlite3.Error:
            pc_rows = []

    latest_q08: dict[str, dict[str, Any]] = {}
    for row in q08_rows:
        sym = str(row.get("symbol") or "?")
        latest_q08.setdefault(sym, row)
    latest_q09: dict[str, dict[str, Any]] = {}
    for row in q09_rows:
        sym = str(row.get("symbol") or "?")
        if sym not in latest_q09 or _q09_rescue_priority(row) < _q09_rescue_priority(latest_q09[sym]):
            latest_q09[sym] = row
    pc_by_symbol = {str(row.get("symbol") or "?"): row for row in pc_rows}

    out: list[dict[str, Any]] = []
    for symbol, q08 in latest_q08.items():
        q08_payload = {**_json_from_file(q08.get("evidence_path")), **_payload_from_row(q08)}
        q09 = latest_q09.get(symbol)
        q09_payload = _payload_from_row(q09) if q09 else {}
        q09_artifact = _json_from_file(q09.get("evidence_path") if q09 else None)
        sharpe_delta = None
        if isinstance(q09_artifact.get("sharpe_with"), (int, float)) and isinstance(q09_artifact.get("sharpe_without"), (int, float)):
            sharpe_delta = q09_artifact["sharpe_with"] - q09_artifact["sharpe_without"]
        maxdd_delta = None
        if isinstance(q09_artifact.get("maxdd_with"), (int, float)) and isinstance(q09_artifact.get("maxdd_without"), (int, float)):
            maxdd_delta = q09_artifact["maxdd_with"] - q09_artifact["maxdd_without"]
        out.append({
            "symbol": symbol,
            "q08_tier": _q08_rescue_tier(str(q08.get("verdict") or ""), q08_payload),
            "q08_reason": _q08_rescue_reason(q08_payload),
            "q08_trades": q08_payload.get("q08_n_trades") or q09_payload.get("q08_trade_count"),
            "q09_status": q09.get("status") if q09 else "",
            "q09_verdict": (q09.get("verdict") if q09 else None) or ("PENDING" if q09 else "—"),
            "portfolio_only": bool(q09_payload.get("portfolio_only") or symbol in pc_by_symbol),
            "candidate_state": (pc_by_symbol.get(symbol) or {}).get("state") or q09_payload.get("portfolio_candidate_state") or "",
            "corr": q09_artifact.get("max_corr_to_book"),
            "standalone_pf": q09_artifact.get("standalone_pf"),
            "sharpe_delta": sharpe_delta,
            "maxdd_delta": maxdd_delta,
            "q09_reason": q09_artifact.get("reason") or q09_payload.get("verdict_reason") or "",
            "evidence": q09.get("evidence_path") if q09 else q08.get("evidence_path"),
            "updated_at": q09.get("updated_at") if q09 else q08.get("updated_at"),
        })
    out.sort(key=lambda row: row.get("updated_at") or "", reverse=True)
    return out


def _progress_bar_html(ea: dict) -> str:
    """Inline progress bar: one cell per phase, color-coded done/current/failed."""
    cells = []
    completed = set(ea.get("completed_phases") or [])
    cur = ea.get("current_phase")
    failed = ea.get("failed_at")
    for ph in PHASE_ORDER:
        cls = "pcell"
        if ph in completed:
            cls += " p-done"
        elif ph == cur and not failed:
            cls += " p-current"
        elif ph == failed:
            cls += " p-failed"
        cells.append(f'<span class="{cls}" title="{e(phase_label(ph))}"></span>')
    return '<span class="progress-bar">' + "".join(cells) + '</span>'


def collect_ea_lead_kpis(root: Path, ea_ids: list[str]) -> dict[str, dict[str, Any]]:
    """For each EA, pull the lead KPIs across all work_items via one batch query.

    Returns: ea_id -> {best_net, best_phase, best_symbol, trades_mean, dd_worst,
                      n_symbols, n_pass, n_fail, latest_phase}
    """
    out: dict[str, dict[str, Any]] = {}
    if not ea_ids:
        return out
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return out
    placeholders = ",".join("?" for _ in ea_ids)
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        rows = list(conn.execute(
            f"SELECT ea_id, phase, symbol, status, verdict, payload_json, evidence_path, updated_at "
            f"FROM work_items WHERE ea_id IN ({placeholders}) "
            f"ORDER BY ea_id, phase, symbol, updated_at DESC",
            ea_ids,
        ))

    by_ea: dict[str, list[dict[str, Any]]] = defaultdict(list)
    seen_work_items: set[tuple[str, str, str]] = set()
    for r in rows:
        key = (r["ea_id"], r["phase"] or "?", r["symbol"] or "?")
        if key in seen_work_items:
            continue
        seen_work_items.add(key)
        try:
            p = json.loads(r["payload_json"] or "{}")
        except Exception:
            p = {}
        stats = p.get("recovered_stats") or {}
        # Detail pages already fall back to summary.json/report.htm when the
        # work_item payload lacks recovered_stats. Keep the archive row aligned
        # with the detail dashboard so "Best exploratory P&L" is not blank for
        # rows whose parser evidence lives only in summary.json.
        if not any(stats.get(k) not in (None, "", []) for k in ("net_profit", "total_trades", "max_dd", "drawdown")):
            parsed_stats = _parse_summary_stats(r["evidence_path"])
            stats = {
                "net_profit": parsed_stats.get("net_profit"),
                "total_trades": parsed_stats.get("trades"),
                "max_dd": parsed_stats.get("drawdown"),
            }
        item = {
            "phase": r["phase"],
            "status": r["status"],
            "symbol": r["symbol"],
            "verdict": r["verdict"],
            # 2026-05-23 OWNER call: surface stats for FAIL/INVALID runs too;
            # negative P&L is information the operator wants in the table.
            "net_profit": stats.get("net_profit"),
            "trades": stats.get("total_trades"),
            "drawdown": stats.get("max_dd") or stats.get("drawdown"),
            "updated_at": r["updated_at"],
        }
        by_ea[r["ea_id"]].append(item)

    for ea_id, items in by_ea.items():
        nets = [(i["net_profit"], i["phase"], i["symbol"]) for i in items if isinstance(i.get("net_profit"), (int, float))]
        trades = [i["trades"] for i in items if isinstance(i.get("trades"), (int, float))]
        dds = [i["drawdown"] for i in items if isinstance(i.get("drawdown"), (int, float))]
        verdicts = [i["verdict"] for i in items if i.get("verdict")]
        n_pass = sum(1 for v in verdicts if v == "PASS")
        n_fail = sum(1 for v in verdicts if v == "FAIL")
        pass_phases = {
            i["phase"]
            for i in items
            if i.get("status") == "done" and i.get("verdict") == "PASS" and i.get("phase") in PHASE_ORDER
        }
        # PT8 — phase keys are now Qxx; "P4" / "P8" are legacy. The "Q05+ survivor"
        # bar is set at Q05 (first stress gate); the "Q11 PASS" flag at Q11.
        p4plus_pass = any(PHASE_ORDER.index(p) >= PHASE_ORDER.index("Q05") for p in pass_phases)
        p8_pass = "Q11" in pass_phases
        highest_pass_phase = None
        if pass_phases:
            highest_pass_phase = max(pass_phases, key=lambda p: PHASE_ORDER.index(p))

        best = max(nets, key=lambda x: x[0]) if nets else None
        # latest phase any work_item touched
        try:
            latest_phase_idx = max(
                (PHASE_ORDER.index(i["phase"]) for i in items if i.get("phase") in PHASE_ORDER),
                default=-1,
            )
            latest_phase = PHASE_ORDER[latest_phase_idx] if latest_phase_idx >= 0 else None
        except Exception:
            latest_phase = None

        out[ea_id] = {
            "best_net": best[0] if best else None,
            "best_phase": best[1] if best else None,
            "best_symbol": best[2] if best else None,
            "trades_mean": (sum(trades) / len(trades)) if trades else None,
            "dd_worst": max(dds) if dds else None,
            "n_symbols": len({i["symbol"] for i in items if i.get("symbol")}),
            "n_pass": n_pass,
            "n_fail": n_fail,
            "highest_pass_phase": highest_pass_phase,
            "p4plus_pass": p4plus_pass,
            "p8_pass": p8_pass,
            "latest_phase": latest_phase,
            "work_item_count": len(items),
        }
    return out


def render_strategies(state: dict, root: Path) -> str:
    eas = derive_ea_candidates(state["tasks"], root)

    kpis = collect_ea_lead_kpis(root, [ea["ea_id"] for ea in eas])

    # archive coverage: which EAs have live work_items vs detail-page-only
    wi_eas: set[str] = set()
    _db = root / "state" / "farm_state.sqlite"
    if _db.exists():
        try:
            with sqlite3.connect(_db) as _conn:
                wi_eas = {r[0] for r in _conn.execute("SELECT DISTINCT ea_id FROM work_items")}
        except sqlite3.Error:
            wi_eas = set()
    detail_eas = {ea["ea_id"] for ea in eas}
    coverage_gap = sorted(wi_eas - detail_eas)
    cov_panel = ""
    if coverage_gap:
        cov_panel = (
            '<div class="cov-gap-panel"><strong>Archive coverage gap:</strong> '
            f'{len(coverage_gap)} EA(s) have live work_items but no rendered detail page — '
            f'{e(", ".join(coverage_gap))}. Renderer action: add to derive_ea_candidates().</div>'
        )

    # per-EA lane classification — drives summary chips, presets, default sort
    counts: Counter = Counter()
    lane_meta: dict[str, dict] = {}
    for ea in eas:
        label, _sc = _ea_status(ea)
        k = kpis.get(ea["ea_id"]) or {}
        has_wi = ea["ea_id"] in wi_eas
        card_state = ea.get("card_state")
        lanes = {"all", "live" if has_wi else "archive"}
        if card_state:
            lanes.add("card")
            lanes.add(f"card_{card_state}")
            counts[f"card_{card_state}"] += 1
        if not has_wi and card_state and ea.get("task_count", 0) == 0:
            # Card-only row (no agent task, no work_items): rank below dead so
            # the active funnel stays at the top by default.
            lanes.add("card_only")
            rank = 7
            counts["card_only"] += 1
        elif label == "DEAD":
            lanes.add("dead"); rank = 6; counts["dead"] += 1
        elif k.get("p8_pass"):
            lanes |= {"survivor", "active"}; rank = 0
            counts["p8"] += 1; counts["surv"] += 1
        elif k.get("p4plus_pass"):
            lanes |= {"survivor", "active"}; rank = 1
            counts["surv"] += 1
        elif label == "LIVE":
            lanes.add("active"); rank = 0; counts["live"] += 1
        elif has_wi and (k.get("n_pass") or 0) == 0:
            lanes.add("triage"); rank = 4; counts["triage"] += 1
        elif has_wi:
            lanes.add("active"); rank = 3; counts["active"] += 1
        else:
            lanes.add("notstarted"); rank = 5; counts["notstarted"] += 1
        lane_meta[ea["ea_id"]] = {"lanes": lanes, "rank": rank, "has_wi": has_wi}

    # default order: Q11 / Q05+ survivors first, dead last; recency within rank
    eas.sort(key=lambda x: x.get("last_updated") or "", reverse=True)
    eas.sort(key=lambda x: lane_meta[x["ea_id"]]["rank"])

    if not eas:
        body = '<div class="empty" style="max-width:1100px;margin:24px auto;text-align:center;color:var(--qm-text-muted);">No EAs registered yet.</div>'
    else:
        rows = []
        for ea in eas:
            label, status_cls = _ea_status(ea)
            k = kpis.get(ea["ea_id"], {})
            best_net = k.get("best_net")
            best_net_html = "—"
            best_sort = 0.0
            if isinstance(best_net, (int, float)):
                cls = "net-pos" if best_net > 0 else "net-neg"
                best_net_html = f'<span class="{cls}">{fmt_dollar(best_net)}</span>'
                best_sort = float(best_net)
            best_meta = ""
            if k.get("best_phase") and k.get("best_symbol"):
                best_meta = f'<div style="font-size:9px;color:var(--qm-text-muted);margin-top:2px">{e(phase_label(k["best_phase"]))} · {e(k["best_symbol"])}</div>'

            trades_mean = k.get("trades_mean")
            trades_html = f"{int(trades_mean)}" if isinstance(trades_mean, (int, float)) and trades_mean else "—"
            dd_worst = k.get("dd_worst")
            dd_html = fmt_dollar(dd_worst) if isinstance(dd_worst, (int, float)) else "—"
            dd_sort = float(dd_worst) if isinstance(dd_worst, (int, float)) else 0.0

            ts = (ea.get("last_updated") or "")[:19]
            try:
                ts_sort = dt.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
            except Exception:
                ts_sort = 0.0

            cur_phase_key = ea.get("current_phase", "—")
            cur_phase = e(phase_label(cur_phase_key) if cur_phase_key != "—" else "—")
            robust_label = "Q11" if k.get("p8_pass") else ("Q05+" if k.get("p4plus_pass") else (phase_label(k.get("highest_pass_phase") or "") or "—"))
            robust_cls = "s-live" if k.get("p8_pass") else ("s-flow" if k.get("p4plus_pass") else "s-dead")
            n_sym = k.get("n_symbols") or 0
            sym_pass = f'{k.get("n_pass", 0)}/{k.get("n_fail", 0)+k.get("n_pass", 0)}' if k.get("n_pass") or k.get("n_fail") else "—"

            lm = lane_meta[ea["ea_id"]]
            row_cls = []
            if ea.get("dead"):
                row_cls.append("row-dead")  # data-attr only; no styling (OWNER call 2026-05-23)
            card_state = ea.get("card_state")
            is_card_only = "card_only" in lm["lanes"]
            if is_card_only:
                row_cls.append("row-card-only")
            # lane-pill (live/archive) removed from cell HTML 2026-05-23 (OWNER call):
            # "live" was misleading — no EAs are actually T_Live traded; word implied
            # otherwise. Lane membership still carried via data-lanes for filtering.
            fail_prof = ""
            if ea.get("dead") and not is_card_only:
                # Death-reason: failed_at is the most informative field on the EA dict
                # (failure_reason / verdict_text are not populated upstream). Render the
                # phase where it died as a small faint secondary line below the status pill.
                fa = ea.get("failed_at")
                reason_title = f"died at {phase_label(fa)}" if fa else "died (phase unknown)"
                fail_prof = (
                    f'<div class="fail-prof fp-reason" title="{e(reason_title)}">'
                    f'died at {e(phase_label(fa)) if fa else "?"}</div>'
                )

            # Card-only rows: replace the status pill with a card-state pill,
            # drop the onclick (no detail page yet — clicking would 404), and
            # show "—" in KPI columns. Survivors / live EAs keep the original
            # status pill but may have a card-state secondary indicator.
            if is_card_only:
                card_pill_cls = {
                    "approved": "s-flow",
                    "review":   "s-prog",
                    "draft":    "s-card",
                    "rejected": "s-dead",
                }.get(card_state, "s-card")
                status_html = (
                    f'<span class="status-chip {card_pill_cls}">card · {e(card_state)}</span>'
                )
                onclick_attr = ""
            else:
                status_html = f'<span class="status-chip {status_cls}">{label}</span>{fail_prof}'
                onclick_attr = f' onclick="window.location=\'ea_{e(ea["ea_id"])}.html\'"'
            # Carry card_state into data-* for the filter chip strip below
            data_card_attr = f' data-card-state="{e(card_state)}"' if card_state else ""

            rows.append(f"""<tr class="{' '.join(row_cls)}" data-status="{status_cls}" data-phase="{cur_phase}" data-lanes="{' '.join(sorted(lm['lanes']))}"{data_card_attr} data-search="{e((ea['ea_id'] + ' ' + (ea.get('slug') or '')).lower())}"{onclick_attr}>
  <td class="td-ea"><code>{e(ea['ea_id'])}</code></td>
  <td class="td-slug">{e(ea.get('slug') or '')}</td>
  <td>{status_html}</td>
  <td>{_progress_bar_html(ea)}</td>
  <td>{cur_phase}</td>
  <td><span class="status-chip {robust_cls}">{e(robust_label)}</span></td>
  <td class="col-num" data-sort="{best_sort}">{best_net_html}{best_meta}</td>
  <td class="col-num">{trades_html}</td>
  <td class="col-num" data-sort="{dd_sort}">{dd_html}</td>
  <td class="col-num">{n_sym} <span style="color:var(--qm-text-muted);font-size:10px">({sym_pass} pass)</span></td>
  <td data-sort="{ts_sort}">{e(ts.replace('T', ' '))}</td>
</tr>""")

        body = f"""
<div class="archive-table-wrap">
<table class="archive-table" id="ea-table">
  <thead>
    <tr>
      <th data-sort-col="ea" data-sort-type="text">EA</th>
      <th data-sort-col="slug" data-sort-type="text">Slug</th>
      <th data-sort-col="status" data-sort-type="text">Status</th>
      <th>Progress · Q00→Q14</th>
      <th data-sort-col="phase" data-sort-type="text">Current</th>
      <th data-sort-col="robust" data-sort-type="text">Most advanced gate</th>
      <th data-sort-col="net" data-sort-type="num" class="col-num">Best exploratory P&amp;L</th>
      <th data-sort-col="trades" data-sort-type="num" class="col-num">Trades</th>
      <th data-sort-col="dd" data-sort-type="num" class="col-num">Worst DD</th>
      <th data-sort-col="sym" data-sort-type="num" class="col-num">Symbols</th>
      <th data-sort-col="updated" data-sort-type="num">Updated</th>
    </tr>
  </thead>
  <tbody>
{''.join(rows)}
  </tbody>
</table>
</div>
"""

    return html_head("Strategy Archive", ARCHIVE_CSS + ARCHIVE2_CSS) + f"""
<div class="archive-hero">
  <h1>Strategy <span class="em-text">Archive</span></h1>
  <p class="archive-hero-sub">Every EA candidate that has entered the QuantMechanica V5 pipeline. Mechanical strategies only (Hard Rule 14, NO ML). Each row traceable Q00 → Q14 with evidence trail — click for full per-phase × symbol drill-down.</p>
  <div class="archive-chips">
    <div class="achip c-p8"><div class="achip-num">{counts.get("p8", 0)}</div><div class="achip-label">Q11 PASS</div></div>
    <div class="achip c-surv"><div class="achip-num">{counts.get("surv", 0)}</div><div class="achip-label">Q05+ survivors</div></div>
    <div class="achip"><div class="achip-num">{counts.get("active", 0)}</div><div class="achip-label">Active now</div></div>
    <div class="achip"><div class="achip-num">{counts.get("triage", 0)}</div><div class="achip-label">Needs EA triage</div></div>
    <div class="achip"><div class="achip-num">{counts.get("notstarted", 0)}</div><div class="achip-label">Not started</div></div>
    <div class="achip c-dead"><div class="achip-num">{counts.get("dead", 0)}</div><div class="achip-label">Dead</div></div>
    <div class="achip c-card"><div class="achip-num">{counts.get("card_only", 0)}</div><div class="achip-label">Card · not built</div></div>
  </div>
</div>

<div class="transparency-banner">
  <strong>Transparency:</strong> all EAs are the actual pipeline state — DEAD strategies are dimmed but NOT hidden. Q11-PASS and Q05+ survivors are sorted to the top; click any row for strategy card, per-phase × per-symbol backtest evidence, and native MT5 reports.
</div>

<div class="controls">
  <span class="ctl-label">Filter</span>
  <select id="f-status">
    <option value="">All status</option>
    <option value="s-live">Live</option>
    <option value="s-flow">In Flow</option>
    <option value="s-dead">Dead</option>
  </select>
  <select id="f-phase">
    <option value="">All phases</option>
    {''.join(f'<option value="{phase_label(p)}">{phase_label(p)}</option>' for p in PHASE_ORDER)}
  </select>
  <input type="search" id="f-search" placeholder="search ea id or slug…">
  <span class="row-count"><strong id="rc-visible">{len(eas)}</strong> of {len(eas)} EAs</span>
</div>

<div class="presets">
  <span class="preset-label">View</span>
  <span class="preset active" data-preset="all">All</span>
  <span class="preset" data-preset="active">Active now</span>
  <span class="preset" data-preset="survivor">Q05+ survivors</span>
  <span class="preset" data-preset="triage">Needs EA triage</span>
  <span class="preset" data-preset="dead">Dead</span>
  <span class="preset" data-preset="live">Live pipeline only</span>
  <span class="preset" data-preset="archive">Archive only</span>
  <span class="preset" data-preset="card">Cards · all</span>
  <span class="preset" data-preset="card_approved">Cards · approved</span>
  <span class="preset" data-preset="card_review">Cards · review</span>
  <span class="preset" data-preset="card_draft">Cards · draft</span>
  <span class="preset" data-preset="card_rejected">Cards · rejected</span>
  <span class="preset" data-preset="card_only">Cards · not built</span>
</div>
<div class="gate-note">"Best exploratory P&amp;L" is the single best result across any phase (often a Q02 discovery run) — it is NOT gate proof. "Most advanced gate" is the highest real PASS the EA reached. "Needs EA triage" is an EA-level archive lane, not the same as cockpit "Test Exceptions", which are daily work-item outcomes such as min-trade/zero-trade, invalid report, or waiting-input rows.</div>
{cov_panel}

{body}

<div class="archive-footer">
  Generated by tools/strategy_farm/dashboards/render_dashboards.py · click any row for full drill-down.<br>
  Data: D:/QM/strategy_farm/state/farm_state.sqlite + reports/work_items/ + artifacts/cards_approved/
</div>

<script>
(function(){{
  const table = document.getElementById('ea-table');
  if (!table) return;
  const tbody = table.tBodies[0];
  const rows = Array.from(tbody.rows);
  const filterStatus = document.getElementById('f-status');
  const filterPhase  = document.getElementById('f-phase');
  const searchBox    = document.getElementById('f-search');
  const rcVisible    = document.getElementById('rc-visible');

  let activePreset = 'all';
  function applyFilters(){{
    const s = filterStatus.value;
    const p = filterPhase.value;
    const q = (searchBox.value || '').toLowerCase().trim();
    let visible = 0;
    rows.forEach(r => {{
      const rs = r.getAttribute('data-status') || '';
      const rp = r.getAttribute('data-phase') || '';
      const rq = r.getAttribute('data-search') || '';
      const rl = (r.getAttribute('data-lanes') || '').split(' ');
      const hide = (s && rs !== s) || (p && rp !== p) || (q && !rq.includes(q))
                   || (activePreset !== 'all' && rl.indexOf(activePreset) < 0);
      r.classList.toggle('row-hidden', hide);
      if (!hide) visible++;
    }});
    rcVisible.textContent = visible;
  }}

  document.querySelectorAll('.preset').forEach(btn => {{
    btn.addEventListener('click', () => {{
      document.querySelectorAll('.preset').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activePreset = btn.getAttribute('data-preset') || 'all';
      applyFilters();
    }});
  }});

  filterStatus.addEventListener('change', applyFilters);
  filterPhase.addEventListener('change', applyFilters);
  searchBox.addEventListener('input', applyFilters);

  // sortable columns
  let sortCol = null, sortDir = 1;
  table.querySelectorAll('thead th[data-sort-col]').forEach(th => {{
    th.addEventListener('click', () => {{
      const type = th.getAttribute('data-sort-type');
      const col = th.getAttribute('data-sort-col');
      if (sortCol === col) sortDir = -sortDir;
      else {{ sortCol = col; sortDir = 1; }}
      table.querySelectorAll('thead th').forEach(t => t.classList.remove('sort-asc','sort-desc'));
      th.classList.add(sortDir === 1 ? 'sort-asc' : 'sort-desc');
      const cellIdx = th.cellIndex;  // real column index, incl. non-sortable cols
      const sorted = rows.slice().sort((a, b) => {{
        const ca = a.cells[cellIdx], cb = b.cells[cellIdx];
        let va, vb;
        if (type === 'num') {{
          va = parseFloat(ca.getAttribute('data-sort') || ca.textContent.replace(/[$,]/g,'')) || 0;
          vb = parseFloat(cb.getAttribute('data-sort') || cb.textContent.replace(/[$,]/g,'')) || 0;
          return (va - vb) * sortDir;
        }} else {{
          va = ca.textContent.trim().toLowerCase();
          vb = cb.textContent.trim().toLowerCase();
          if (va < vb) return -1 * sortDir;
          if (va > vb) return 1 * sortDir;
          return 0;
        }}
      }});
      sorted.forEach(r => tbody.appendChild(r));
    }});
  }});
}})();
</script>
</body>
</html>
"""


# ── EA Detail Page ───────────────────────────────────────────────


def collect_ea_detail(ea_id: str, root: Path) -> dict[str, Any]:
    """Pull everything we know about one EA: work_items × summary.jsons,
    card .md frontmatter+body, EA source/binary, set-files."""
    detail: dict[str, Any] = {
        "ea_id": ea_id,
        "slug": ea_id,
        "card": None,
        "card_path": None,
        "ea_dir": None,
        "ea_mq5": None,
        "ea_ex5": None,
        "set_files": [],
        "work_items": [],
        "q08_portfolio_rescue": [],
        "kpis_by_phase": {},
        "symbols": [],
    }
    db = root / "state" / "farm_state.sqlite"
    if db.exists():
        with sqlite3.connect(db) as conn:
            conn.row_factory = sqlite3.Row
            rows = [dict(r) for r in conn.execute(
                "SELECT * FROM work_items WHERE ea_id = ? ORDER BY phase, symbol, updated_at DESC",
                (ea_id,)
            )]
        # Collect ALL chronological attempts per (phase, symbol) — needed for
        # the expandable timeline (OWNER call 2026-05-23: latest-only display
        # hid that NDX Q02 had 30+ historical PASS attempts, making the
        # promotion to Q03+ look unjustified).
        attempts_by_key: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for w in rows:
            key = (w.get("phase") or "?", w.get("symbol") or "?")
            try:
                pl = json.loads(w.get("payload_json") or "{}")
            except Exception:
                pl = {}
            rs = pl.get("recovered_stats") or {}
            reason = (pl.get("blocked_reason") or pl.get("verdict_reason")
                      or pl.get("reason") or "")
            attempts_by_key[key].append({
                "created_at": w.get("created_at") or w.get("updated_at"),
                "updated_at": w.get("updated_at"),
                "status": w.get("status"),
                "verdict": w.get("verdict"),
                "reason": str(reason) if reason else "",
                "net_profit": rs.get("net_profit"),
                "trades": rs.get("total_trades"),
                "drawdown": rs.get("max_dd") or rs.get("drawdown"),
                "evidence": w.get("evidence_path"),
                "setfile": w.get("setfile_path"),
            })
        # Order each bucket chronologically (oldest → newest)
        for k in attempts_by_key:
            attempts_by_key[k].sort(key=lambda a: a.get("created_at") or "")

        # Keep the latest record per (phase, symbol) for the summary row
        seen: set[tuple[str, str]] = set()
        items: list[dict[str, Any]] = []
        for w in rows:
            key = (w.get("phase") or "?", w.get("symbol") or "?")
            if key in seen:
                continue
            seen.add(key)
            try:
                payload = json.loads(w.get("payload_json") or "{}")
            except Exception:
                payload = {}
            rs = payload.get("recovered_stats") or {}
            item = {
                "phase": w.get("phase") or "?",
                "symbol": w.get("symbol") or "?",
                "verdict": w.get("verdict"),
                "status": w.get("status"),
                "updated_at": w.get("updated_at"),
                "setfile": w.get("setfile_path"),
                "evidence": w.get("evidence_path"),
                "net_profit": rs.get("net_profit"),
                "trades": rs.get("total_trades"),
                "drawdown": rs.get("max_dd") or rs.get("drawdown"),
                "profit_factor": rs.get("profit_factor"),
                "sharpe": None,
                "report_htm": None,
                "deals": [],
                "fail_reason": None,
                "fail_class": None,
            }
            # Q05 (legacy P4) walk-forward fold table — parsed from evidence JSON
            # so the operator sees per-fold OOS net / DD% / regime instead of just
            # a single PASS verdict (OWNER call 2026-05-23).
            if w.get("phase") == "P4":
                ev = w.get("evidence_path")
                if ev:
                    try:
                        ep = Path(ev)
                        if ep.exists():
                            ej = json.loads(ep.read_text(encoding="utf-8", errors="ignore"))
                            folds = (ej.get("details") or {}).get("folds") or []
                            if folds:
                                item["folds"] = folds
                                item["fold_criterion"] = ej.get("criterion") or ""
                    except Exception:
                        pass
            # Q06 / Q07 / Q08 evidence — stress / calibrated-noise / crisis-slice
            # (OWNER call 2026-05-23). Each phase has its own JSON / CSV shape.
            if w.get("phase") == "P5":
                # Stress metrics file is per-EA, shared across symbols. Find this
                # symbol's row in the symbols list.
                stress_path = root / "reports" / "pipeline" / ea_id / "P5" / "p5_stress_metrics.json"
                if not stress_path.exists():
                    stress_path = Path("D:/QM/reports/pipeline") / ea_id / "P5" / "p5_stress_metrics.json"
                if stress_path.exists():
                    try:
                        sj = json.loads(stress_path.read_text(encoding="utf-8", errors="ignore"))
                        for s in (sj.get("symbols") or []):
                            if s.get("symbol") == w.get("symbol"):
                                item["stress"] = s
                                break
                    except Exception:
                        pass
            if w.get("phase") == "P5b":
                trials_path = Path("D:/QM/reports/pipeline") / ea_id / "P5b" / "p5b_trials.csv"
                if trials_path.exists():
                    try:
                        import csv as _csv
                        trials = []
                        with trials_path.open("r", encoding="utf-8", errors="ignore") as fh:
                            for row in _csv.DictReader(fh):
                                if row.get("symbol") == w.get("symbol"):
                                    trials.append(row)
                        if trials:
                            item["trials"] = trials
                    except Exception:
                        pass
            if w.get("phase") == "P5c":
                ev = w.get("evidence_path")
                if ev:
                    try:
                        ep = Path(ev)
                        if ep.exists() and ep.suffix == ".json":
                            cj = json.loads(ep.read_text(encoding="utf-8", errors="ignore"))
                            rows = (cj.get("details") or {}).get("rows") or []
                            failures = (cj.get("details") or {}).get("failures") or []
                            if rows:
                                item["crisis_slices"] = rows
                                item["crisis_failures"] = failures
                                item["crisis_criterion"] = cj.get("criterion") or ""
                    except Exception:
                        pass
            verd = w.get("verdict") or ""
            reason = (
                payload.get("blocked_reason")
                or payload.get("verdict_reason")
                or payload.get("reason")
                or ""
            )
            # Q09 / Q10 / Q11 (legacy P6 / P7 / P8) frequently write verdict=INVALID
            # with a reason text that reads like a PASS ("p6_all_seeds_pass",
            # "P7 hard gates satisfied", "P8 ... recommendation"). Relabel those
            # as COMPLETED so the page stops looking broken at Q09+ (OWNER call).
            if verd == "INVALID" and reason and _is_pass_reason(str(reason)):
                item["verdict"] = "COMPLETED"
                item["completion_note"] = str(reason)[:120]
            elif verd in ("FAIL", "INVALID"):
                if reason:
                    item["fail_reason"] = str(reason)
                    item["fail_class"] = (
                        "infra" if any(k in str(reason) for k in ("METATESTER", "REPORT_MISSING", "TIMEOUT", "INCOMPLETE"))
                        else "strategy"
                    )
            item["attempts"] = attempts_by_key.get(key, [])
            item["n_attempts"] = len(item["attempts"])
            item["n_ever_pass"] = sum(1 for a in item["attempts"] if a.get("verdict") == "PASS")
            # Distinct setfile count distinguishes parameter trials (different
            # setfile each row) from re-runs (same setfile repeated). Q03 sweep
            # = many distinct setfiles by design; Q02 may mix a baseline re-run
            # with synth variants.
            _sf_distinct = {a.get("setfile") for a in item["attempts"] if a.get("setfile")}
            item["n_setfiles"] = len(_sf_distinct)

            # Enrich from latest summary.json + raw report.htm
            latest_stats = _parse_summary_stats(w.get("evidence_path"))
            for fld in ("net_profit", "trades", "drawdown", "profit_factor",
                        "sharpe", "report_htm", "deals"):
                if item.get(fld) in (None, "", []) and latest_stats.get(fld) not in (None, "", []):
                    item[fld] = latest_stats[fld]

            # Fallback (OWNER call 2026-05-23): if the latest attempt produced no
            # stats (e.g. infra TIMEOUT / METATESTER_HUNG never wrote report.htm),
            # fall back to the most recent earlier attempt that actually has
            # parsable data. Q02 NDX is the motivating case — the EA *did* run
            # successfully many times, the headline row should not look empty
            # just because the most recent re-run hit an MT5 timeout.
            if item.get("net_profit") in (None, ""):
                for a in reversed(attempts_by_key.get(key, [])):
                    if not a.get("evidence"):
                        continue
                    fb = _parse_summary_stats(a.get("evidence"))
                    if fb.get("net_profit") not in (None, ""):
                        for fld in ("net_profit", "trades", "drawdown",
                                    "profit_factor", "sharpe", "report_htm",
                                    "deals"):
                            if item.get(fld) in (None, "", []) and fb.get(fld) not in (None, "", []):
                                item[fld] = fb[fld]
                        item["stats_fallback_from"] = (a.get("created_at") or "")[:19].replace("T", " ")
                        item["stats_fallback_verdict"] = a.get("verdict")
                        break
            items.append(item)
        detail["work_items"] = items
        detail["symbols"] = sorted({i["symbol"] for i in items if i["symbol"] and i["symbol"] != "?"})

        # KPI aggregates per phase
        by_phase: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for i in items:
            by_phase[i["phase"]].append(i)
        for phase, ph_items in by_phase.items():
            nets = [i["net_profit"] for i in ph_items if isinstance(i.get("net_profit"), (int, float))]
            trs = [i["trades"] for i in ph_items if isinstance(i.get("trades"), (int, float))]
            dds = [i["drawdown"] for i in ph_items if isinstance(i.get("drawdown"), (int, float))]
            pfs = [i["profit_factor"] for i in ph_items if isinstance(i.get("profit_factor"), (int, float))]
            verdicts = [i["verdict"] for i in ph_items if i.get("verdict")]
            detail["kpis_by_phase"][phase] = {
                "n_symbols": len(ph_items),
                "n_pass": verdicts.count("PASS"),
                "n_fail": verdicts.count("FAIL"),
                "n_invalid": verdicts.count("INVALID"),
                "net_profit_mean": (sum(nets) / len(nets)) if nets else None,
                "net_profit_best": max(nets) if nets else None,
                "net_profit_worst": min(nets) if nets else None,
                "trades_mean": (sum(trs) / len(trs)) if trs else None,
                "drawdown_worst": max(dds) if dds else None,
                "profit_factor_mean": (sum(pfs) / len(pfs)) if pfs else None,
            }
        detail["q08_portfolio_rescue"] = collect_q08_portfolio_rescue_for_ea(ea_id, root)

    # Card .md
    cards_dir = root / "artifacts" / "cards_approved"
    if cards_dir.exists():
        for cf in cards_dir.glob(f"{ea_id}_*.md"):
            detail["card_path"] = str(cf)
            try:
                content = cf.read_text(encoding="utf-8", errors="replace")
                fm, body = split_frontmatter(content)
                slug = cf.stem[len(ea_id) + 1:] if cf.stem.startswith(ea_id + "_") else cf.stem
                detail["card"] = {"frontmatter": fm, "body": body, "slug": slug}
                detail["slug"] = slug
            except Exception:
                pass
            break

    # Source/binary + set files
    framework_eas = REPO_ROOT / "framework" / "EAs"
    if framework_eas.exists():
        for d in framework_eas.iterdir():
            if d.is_dir() and d.name.startswith(ea_id + "_"):
                detail["ea_dir"] = str(d)
                detail["slug"] = d.name[len(ea_id) + 1:]
                mq5 = d / f"{d.name}.mq5"
                ex5 = d / f"{d.name}.ex5"
                if mq5.exists():
                    detail["ea_mq5"] = str(mq5)
                if ex5.exists():
                    detail["ea_ex5"] = str(ex5)
                sets_dir = d / "sets"
                if sets_dir.exists():
                    detail["set_files"] = sorted(str(p) for p in sets_dir.glob("*.set"))
                break
    return detail


def _detail_decision(ea: dict, highest_pass: str | None, most_advanced: str | None,
                     next_gate: str) -> dict:
    """Operator decision summary for an EA detail page."""
    nxt = phase_label(next_gate) if next_gate and next_gate != "—" else "—"
    if ea.get("dead"):
        fa = ea.get("failed_at") or most_advanced or "?"
        return {
            "verdict": f"DEAD — failed at {phase_label(fa)}",
            "cls": "ds-bad",
            "why": "A strategy or infrastructure failure was recorded at this gate. The row is kept "
                   "visible for evidence transparency, not hidden.",
            "risk": "If the failure class is infra / zero-trade rather than strategy logic, the kill "
                    "may be premature — check the grouped failure profile below.",
            "next": "Triage the failure class: strategy-fail kills the EA; infra or zero-trade routes "
                    "to zero-trade recovery and a requeue.",
        }
    if highest_pass == "P8":
        return {
            "verdict": "Q11 real PASS reached",
            "cls": "ds-good",
            "why": "The EA cleared the hardest automated gate (real MT5 news replay) — a genuine "
                   "portfolio candidate.",
            "risk": "Q11 PASS is necessary, not sufficient: correlation with existing candidates and "
                    "live symbol routability still gate Q12.",
            "next": "OWNER / Board Q12 portfolio review.",
        }
    if highest_pass:
        return {
            "verdict": f"Advancing — highest real PASS at {phase_label(highest_pass)}",
            "cls": "",
            "why": "The EA has real PASS evidence but has not yet reached the Q11 gate.",
            "risk": "Higher gates (crisis slices, multi-seed, news replay) are progressively harsher; "
                    "most EAs die above Q05.",
            "next": f"Next gate: {nxt}.",
        }
    return {
        "verdict": "No real PASS yet",
        "cls": "",
        "why": "The EA has work items but no PASS verdict — still in early discovery, or stuck.",
        "risk": "If every row is INVALID the cause is most likely infra / build artifacts, not the "
                "strategy itself.",
        "next": f"Next gate: {nxt}.",
    }


def render_ea_detail(ea: dict, detail: dict, state: dict) -> str:
    ea_id = detail["ea_id"]
    slug = detail.get("slug", ea_id)
    label, status_cls = _ea_status(ea)

    work_items = detail.get("work_items", [])
    items_by_phase: dict[str, list[dict]] = defaultdict(list)
    for w in work_items:
        items_by_phase[w["phase"]].append(w)
    present_phases = [p for p in PHASE_ORDER if p in items_by_phase]
    pass_phases = [p for p in present_phases
                   if any(x.get("verdict") == "PASS" for x in items_by_phase[p])]
    highest_pass = pass_phases[-1] if pass_phases else None
    most_advanced = present_phases[-1] if present_phases else None
    cur_phase = ea.get("current_phase") or "—"
    next_gate = "—"
    if cur_phase in PHASE_ORDER:
        ci = PHASE_ORDER.index(cur_phase)
        if ci + 1 < len(PHASE_ORDER):
            next_gate = PHASE_ORDER[ci + 1]
    decision = _detail_decision(ea, highest_pass, most_advanced, next_gate)

    # Card description block
    desc_html = ""
    card = detail.get("card") or {}
    fm = card.get("frontmatter") or {}
    body = (card.get("body") or "").strip()
    if card:
        # up to 3 substantive paragraphs from the card body (skip headings / tables)
        paras: list[str] = []
        for p in body.split("\n\n"):
            pc = p.strip()
            if pc and not pc.startswith("#") and not pc.startswith("|") and len(pc) > 35:
                paras.append(pc[:700])
            if len(paras) >= 3:
                break
        r_tags_html = []
        for key, label_short in (
            ("r1_track_record", "R1 Track Record"),
            ("r2_mechanical", "R2 Mechanical"),
            ("r3_data_available", "R3 Data"),
            ("r4_ml_forbidden", "R4 No-ML"),
        ):
            v = fm.get(key, "UNKNOWN")
            cls = "r-unknown" if v == "UNKNOWN" else ("r-fail" if "FAIL" in str(v) else "")
            r_tags_html.append(f'<span class="r-tag {cls}"><strong>{e(label_short)}</strong> {e(v)}</span>')
        reasoning = fm.get("g0_approval_reasoning", "")
        facts = [
            ("Strategy Card", detail.get("card_path") or "—"),
            ("Slug / family", slug),
            ("Q00 intake status", fm.get("g0_status", "—")),
            ("Expected trades/yr", fm.get("expected_trades_per_year_per_symbol", "—")),
            ("Symbols tested", ", ".join(detail.get("symbols") or []) or "—"),
        ]
        facts_rows = "".join(f"<tr><td>{e(k)}</td><td>{e(v)}</td></tr>" for k, v in facts)
        src = fm.get("sources") or fm.get("source_id")
        if src:
            src_html = (f'<div class="src-attrib"><strong>Source:</strong> {e(src)} — '
                        f'see Strategy Card body for the full citation.</div>')
        elif detail.get("card_path"):
            src_html = (f'<div class="src-attrib"><strong>Source:</strong> see Strategy Card body '
                        f'(<code>{e(detail.get("card_path"))}</code>); not separately indexed in frontmatter.</div>')
        else:
            src_html = '<div class="src-attrib"><strong>Source:</strong> not found in current artifacts.</div>'
        para_html = "".join(f"<p>{e(p)}</p>" for p in paras) or \
            "<p><em>No prose description in the strategy card.</em></p>"
        desc_html = f"""
<div class="detail-desc">
  <div class="detail-desc-title">Strategy Description</div>
  <div class="detail-desc-body">
    {para_html}
    {f'<p><em>Q00 intake approval:</em> {e(reasoning)}</p>' if reasoning else ''}
    <div class="detail-desc-r">{''.join(r_tags_html)}</div>
    <table class="facts-table"><tbody>{facts_rows}</tbody></table>
    {src_html}
  </div>
</div>
"""
    else:
        desc_html = ('<div class="detail-desc"><div class="detail-desc-title">Strategy Description</div>'
                     '<div class="detail-desc-body"><p><em>No strategy card found for this EA. '
                     'Source: not found in current artifacts.</em></p></div></div>')

    # KPI tiles — use the most-advanced phase available
    kpis_by_phase = detail.get("kpis_by_phase") or {}
    advanced = None
    for ph in reversed(PHASE_ORDER):
        if ph in kpis_by_phase:
            advanced = ph
            break

    kpis_html = ""
    if advanced and advanced in kpis_by_phase:
        k = kpis_by_phase[advanced]
        best = k.get("net_profit_best")
        worst = k.get("net_profit_worst")
        kpis_html = f"""
<div class="kpi-grid">
  <div class="kpi-tile">
    <div class="kpi-tile-label">Most-advanced phase</div>
    <div class="kpi-tile-val">{e(phase_label(advanced))}</div>
    <div class="kpi-tile-sub">{k['n_pass']} PASS · {k['n_fail']} FAIL · {k.get('n_invalid', 0)} INVALID</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Symbols Tested</div>
    <div class="kpi-tile-val">{k['n_symbols']}</div>
    <div class="kpi-tile-sub">across this phase</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Net P&amp;L Best</div>
    <div class="kpi-tile-val {'pos' if isinstance(best,(int,float)) and best > 0 else 'neg'}">{fmt_dollar(best)}</div>
    <div class="kpi-tile-sub">USD</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Net P&amp;L Worst</div>
    <div class="kpi-tile-val {'neg' if isinstance(worst,(int,float)) and worst < 0 else ''}">{fmt_dollar(worst)}</div>
    <div class="kpi-tile-sub">USD</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Trades Mean</div>
    <div class="kpi-tile-val">{int(k['trades_mean']) if isinstance(k.get('trades_mean'),(int,float)) else '—'}</div>
    <div class="kpi-tile-sub">per symbol</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Max DD Worst</div>
    <div class="kpi-tile-val neg">{fmt_dollar(k.get('drawdown_worst'))}</div>
    <div class="kpi-tile-sub">USD</div>
  </div>
  <div class="kpi-tile">
    <div class="kpi-tile-label">Profit Factor Mean</div>
    <div class="kpi-tile-val">{f"{k.get('profit_factor_mean'):.2f}" if isinstance(k.get('profit_factor_mean'),(int,float)) else '—'}</div>
    <div class="kpi-tile-sub">PF</div>
  </div>
</div>
"""

    # ── Pipeline-stage accordion — Q01 → Q11 ascending (OWNER call 2026-05-23):
    # reading order matches pipeline progression so the eye walks the EA's
    # actual journey gate-by-gate. The most-advanced gate auto-opens.
    phases_html_chunks: list[str] = []
    for phase in present_phases:
        items = items_by_phase[phase]
        items.sort(key=lambda x: (x.get("verdict") != "PASS", x.get("symbol") or ""))
        verds = Counter(x.get("verdict") or "—" for x in items)
        n_pass = verds.get("PASS", 0)
        verd_html = " · ".join(f"{c}× {v}" for v, c in verds.most_common())
        nets = [x["net_profit"] for x in items if isinstance(x.get("net_profit"), (int, float))]
        # Profitable-PASS sub-counter (OWNER call 2026-05-23): some gates (notably
        # Q03) PASS on sample-size only and let loss-making rows through. Surface
        # how many PASS rows are actually profitable so "4× PASS" is no longer
        # mistaken for "4× profitable".
        n_pass_profitable = sum(
            1 for x in items
            if x.get("verdict") == "PASS"
            and isinstance(x.get("net_profit"), (int, float))
            and x["net_profit"] > 0
        )
        pass_qualifier = ""
        if n_pass and n_pass_profitable < n_pass:
            pass_qualifier = (f' <span style="color:var(--text-3)">'
                              f'({n_pass_profitable}/{n_pass} profitable)</span>')
        if nets:
            kpi_html = (f'best net <strong>{e(fmt_dollar(max(nets)))}</strong>'
                        f'{pass_qualifier}')
        elif n_pass:
            kpi_html = f'<strong>{n_pass} PASS</strong>{pass_qualifier}'
        else:
            kpi_html = '<strong>no PASS</strong>'

        # grouped failure profile — counted, not repeated row-by-row
        fail_groups: dict[tuple, list[str]] = defaultdict(list)
        for x in items:
            if x.get("verdict") in ("FAIL", "INVALID"):
                reason = x.get("fail_reason") or "unspecified"
                short = str(reason).split(":")[0][:48]
                fail_groups[(x.get("fail_class") or "strategy", short)].append(x.get("symbol") or "?")
        fail_box = ""
        if fail_groups:
            frows = []
            for (fcls, reason), syms in sorted(fail_groups.items(), key=lambda kv: -len(kv[1])):
                u = sorted(set(syms))
                sample = ", ".join(u[:10]) + (f"  +{len(u) - 10}" if len(u) > 10 else "")
                frows.append(
                    f'<div class="fail-group-row">'
                    f'<span class="fgr-count {"infra" if fcls == "infra" else ""}">{len(syms)}×</span>'
                    f'<span class="fgr-reason">{e(qxx_text(reason))}</span>'
                    f'<span class="fgr-syms">{e(sample)}</span></div>'
                )
            fail_box = (f'<div class="fail-group-box"><h4>Failure profile · grouped</h4>'
                        f'{"".join(frows)}</div>')

        rows_html = []
        for w in items:
            verd = w.get("verdict") or "—"
            v_cls = {"PASS": "v-pass", "FAIL": "v-fail", "INVALID": "v-invalid",
                     "COMPLETED": "v-completed"}.get(verd, "v-pending")
            # Numeric-cell convention (OWNER call 2026-05-23):
            #   - If real number present (PASS or FAIL with parsed report): show it
            #   - If no data (INVALID infra-fail, no report.htm): show 0/$0.00
            #   "—" placeholders removed — they read as "no information" but the
            #   semantic is "no run happened → effectively zero outcomes".
            #   The verdict cell still shows INVALID so context is preserved.
            np_ = w.get("net_profit")
            if isinstance(np_, (int, float)):
                np_html = f'<span class="{"net-pos" if np_ > 0 else "net-neg"}">{fmt_dollar(np_)}</span>'
            else:
                np_html = '<span class="net-zero">$0.00</span>'
            tr_html = str(int(w["trades"])) if isinstance(w.get("trades"), (int, float)) else "0"
            dd_html = fmt_dollar(w.get("drawdown")) if isinstance(w.get("drawdown"), (int, float)) else "$0.00"
            pf_v = w.get("profit_factor")
            pf_html = f"{pf_v:.2f}" if isinstance(pf_v, (int, float)) else "0.00"
            sh_v = w.get("sharpe")
            sh_html = f"{sh_v:.2f}" if isinstance(sh_v, (int, float)) else "0.00"
            spark = equity_svg(w.get("deals") or [], width=180, height=44, net_profit=np_ if isinstance(np_, (int, float)) else None)
            report_link = ""
            if w.get("report_htm"):
                rp = w["report_htm"].replace("\\", "/")
                report_link = f'<a class="report-link" href="file:///{e(rp)}" target="_blank">Full MT5 ↗</a>'
            fr = ""
            if verd == "COMPLETED" and w.get("completion_note"):
                fr = f'<div class="fail-reason" style="color:var(--text-3)">{e(qxx_text(w["completion_note"]))}</div>'
            elif w.get("fail_reason"):
                fr = f'<div class="fail-reason {e(w.get("fail_class") or "")}">{e(qxx_text(w["fail_reason"][:110]))}</div>'
            if w.get("stats_fallback_from"):
                fr += (f'<div class="fail-reason" style="color:var(--text-3)">'
                       f'stats from earlier {e(w.get("stats_fallback_verdict") or "")} '
                       f'attempt {e(w["stats_fallback_from"])} '
                       f'(latest run had no data)</div>')

            # Expandable per-row drill-down (OWNER call 2026-05-23). Two
            # things may live inside:
            #   1. Q05 walk-forward fold table (parsed from P4 evidence JSON)
            #   2. Chronological attempt timeline (when > 1 DB row exists)
            # The row is expandable if either has content.
            n_att = w.get("n_attempts") or 1
            n_ever = w.get("n_ever_pass") or 0
            folds_for_row = w.get("folds") or []
            stress_for_row = w.get("stress") or None
            trials_for_row = w.get("trials") or []
            crisis_for_row = w.get("crisis_slices") or []
            has_extra = bool(folds_for_row or stress_for_row or trials_for_row or crisis_for_row)
            attempt_html = ""
            toggle_html = ""
            if n_att > 1 or has_extra:
                qid = phase_label(w.get("phase") or "?")
                row_uid = f"att-{e(qid)}-{e(w['symbol']).replace('.', '_')}"
                extras = []
                if folds_for_row:
                    extras.append(f"{len(folds_for_row)} folds")
                if stress_for_row:
                    extras.append("stress")
                if trials_for_row:
                    extras.append(f"{len(trials_for_row)} noise trials")
                if crisis_for_row:
                    extras.append(f"{len(crisis_for_row)} crisis slices")
                if n_att > 1:
                    n_sf = w.get("n_setfiles") or 1
                    # Choose the framing that matches the data:
                    #   • n_setfiles ≈ n_attempts → parameter sweep trials
                    #   • n_setfiles == 1        → genuine re-runs of one setfile
                    #   • mixed                  → both
                    if n_sf >= n_att:
                        kind = "parameter trials"
                    elif n_sf == 1:
                        kind = "re-runs (1 setfile)"
                    else:
                        kind = f"runs ({n_sf} setfiles)"
                    ever_chip = (f'<span style="color:var(--signal);margin-left:6px">'
                                 f'ever PASS {n_ever}/{n_att}</span>') if n_ever else ""
                    extras_chip = (f' + {" · ".join(extras)}' if extras else "")
                    toggle_label = f'{n_att} {kind}{extras_chip}{ever_chip}'
                else:
                    toggle_label = " · ".join(extras) or "1 run"
                toggle_html = (f'<span class="attempt-toggle" data-target="{row_uid}" '
                               f'onclick="toggleAttempts(this)">▸ {toggle_label}</span>')
                # Build the chronological mini-table
                att_rows = []
                first_pass_idx = next(
                    (i for i, a in enumerate(w.get("attempts") or [])
                     if a.get("verdict") == "PASS"), None)
                for i, a in enumerate(w.get("attempts") or []):
                    av = a.get("verdict") or "—"
                    a_reason_raw = a.get("reason") or ""
                    if av == "INVALID" and _is_pass_reason(a_reason_raw):
                        av = "COMPLETED"
                    a_cls = {"PASS": "v-pass", "FAIL": "v-fail",
                             "INVALID": "v-invalid",
                             "COMPLETED": "v-completed"}.get(av, "v-pending")
                    a_when = (a.get("created_at") or "")[:19].replace("T", " ")
                    a_net = a.get("net_profit")
                    a_net_html = (f'{fmt_dollar(a_net)}'
                                  if isinstance(a_net, (int, float)) else "—")
                    a_trades = (str(int(a["trades"]))
                                if isinstance(a.get("trades"), (int, float))
                                else "—")
                    a_dd = (fmt_dollar(a["drawdown"])
                            if isinstance(a.get("drawdown"), (int, float))
                            else "—")
                    a_reason = qxx_text((a.get("reason") or "")[:90])
                    promo = (' <span class="att-promo">promoted</span>'
                             if first_pass_idx is not None and i == first_pass_idx
                             else "")
                    sf_raw = a.get("setfile") or ""
                    sf_short = sf_raw.replace("\\", "/").rsplit("/", 1)[-1] if sf_raw else "—"
                    # Strip the verbose EA+symbol+TF prefix so only the
                    # discriminating part (e.g. "grid_049" or "synth_026" or
                    # "baseline") remains.
                    if sf_short.endswith("_backtest.set"):
                        sf_short = sf_short[:-len("_backtest.set")]
                    for pfx in (f"{ea_id}_", f"{detail.get('slug', '')}_"):
                        if pfx and sf_short.startswith(pfx):
                            sf_short = sf_short[len(pfx):]
                    # Drop slug + symbol + timeframe tokens, keep last segment
                    # like "grid_049" / "synth_026" / "baseline"
                    parts = sf_short.split("_")
                    if len(parts) >= 2 and parts[-2] in ("grid", "synth", "freq"):
                        sf_short = "_".join(parts[-2:])
                    elif not parts[-1].isdigit() and len(parts) > 1 and parts[-1] not in ("grid", "synth", "freq"):
                        sf_short = "baseline"
                    att_rows.append(
                        f'<tr><td>{e(a_when)}</td>'
                        f'<td class="{a_cls}">{e(av)}{promo}</td>'
                        f'<td>{e(sf_short)}</td>'
                        f'<td class="col-num">{e(a_trades)}</td>'
                        f'<td class="col-num">{e(a_net_html)}</td>'
                        f'<td class="col-num">{e(a_dd)}</td>'
                        f'<td class="att-reason">{e(a_reason)}</td></tr>'
                    )
                # Q05 fold table — rendered above the attempt timeline when
                # the latest run has parsed walk-forward folds.
                fold_block_html = ""
                if folds_for_row:
                    fold_rows = []
                    for f in folds_for_row:
                        fid = f.get("fold_id") or "?"
                        dev = f"{(f.get('dev_start') or '?')[:10]} → {(f.get('dev_end') or '?')[:10]}"
                        oos = f"{(f.get('oos_start') or '?')[:10]} → {(f.get('oos_end') or '?')[:10]}"
                        net = f.get("oos_net_profit")
                        if isinstance(net, (int, float)):
                            net_cls = "net-pos" if net > 0 else "net-neg"
                            net_html = f'<span class="{net_cls}">{fmt_dollar(net)}</span>'
                        else:
                            net_html = "—"
                        dd_pct = f.get("oos_drawdown_pct")
                        dd_html = (f"{dd_pct:.2f}%"
                                   if isinstance(dd_pct, (int, float)) else "—")
                        trd = f.get("oos_trades")
                        trd_html = str(int(trd)) if isinstance(trd, (int, float)) else "—"
                        clean = f.get("oos_clean")
                        clean_html = (f'<span class="clean-yes">✓</span>'
                                      if clean else f'<span class="clean-no">✗</span>')
                        regime = (f.get("regime") or "—").lower()
                        fold_rows.append(
                            f'<tr><td class="fold-id">{e(fid)}</td>'
                            f'<td>{e(dev)}</td>'
                            f'<td>{e(oos)}</td>'
                            f'<td class="col-num">{e(trd_html)}</td>'
                            f'<td class="col-num">{net_html}</td>'
                            f'<td class="col-num">{e(dd_html)}</td>'
                            f'<td>{clean_html}</td>'
                            f'<td class="regime">{e(regime)}</td></tr>'
                        )
                    crit = qxx_text(w.get("fold_criterion") or "")
                    crit_html = (f'<div class="fold-criterion">{e(crit)}</div>'
                                 if crit else "")
                    fold_block_html = (
                        f'<div class="fold-block">'
                        f'<div class="att-title">Walk-forward folds · {e(w["symbol"])} · {len(folds_for_row)} folds</div>'
                        f'{crit_html}'
                        f'<table class="fold-table"><thead><tr>'
                        f'<th>Fold</th><th>DEV window</th><th>OOS window</th>'
                        f'<th class="col-num">Trades</th>'
                        f'<th class="col-num">OOS Net</th>'
                        f'<th class="col-num">OOS DD%</th>'
                        f'<th>Clean</th><th>Regime</th>'
                        f'</tr></thead><tbody>{"".join(fold_rows)}</tbody></table>'
                        f'</div>'
                    )

                # Q06 stress metrics block (per-symbol stress KPIs)
                stress_block_html = ""
                if stress_for_row:
                    s = stress_for_row
                    sn = s.get("net_profit")
                    sn_cls = "net-pos" if isinstance(sn, (int, float)) and sn > 0 else "net-neg"
                    sn_html = (f'<span class="{sn_cls}">{fmt_dollar(sn)}</span>'
                               if isinstance(sn, (int, float)) else "—")
                    spf = s.get("pf")
                    spf_html = f"{spf:.2f}" if isinstance(spf, (int, float)) else "—"
                    stn = s.get("trade_count")
                    stn_html = str(int(stn)) if isinstance(stn, (int, float)) else "—"
                    stress_block_html = (
                        f'<div class="fold-block">'
                        f'<div class="att-title">Stress metrics · {e(w["symbol"])}</div>'
                        f'<table class="fold-table"><thead><tr>'
                        f'<th class="col-num">Trades</th>'
                        f'<th class="col-num">Net P&amp;L</th>'
                        f'<th class="col-num">PF</th>'
                        f'</tr></thead><tbody><tr>'
                        f'<td class="col-num">{e(stn_html)}</td>'
                        f'<td class="col-num">{sn_html}</td>'
                        f'<td class="col-num">{e(spf_html)}</td>'
                        f'</tr></tbody></table></div>'
                    )

                # Q07 calibrated-noise trials block
                trials_block_html = ""
                if trials_for_row:
                    trial_rows = []
                    for t in trials_for_row:
                        def _num(k, fmt="{:.4f}"):
                            try:
                                return fmt.format(float(t.get(k)))
                            except (TypeError, ValueError):
                                return "—"
                        trial_rows.append(
                            f'<tr><td class="fold-id">{e(str(t.get("trial") or "?"))}</td>'
                            f'<td class="col-num">{e(str(t.get("breach_count") or "—"))}</td>'
                            f'<td class="col-num">{e(_num("reject_rate"))}</td>'
                            f'<td class="col-num">{e(_num("remaining_cushion_pct"))}</td>'
                            f'<td class="col-num">{e(_num("recovery_fraction"))}</td></tr>'
                        )
                    trials_block_html = (
                        f'<div class="fold-block">'
                        f'<div class="att-title">Calibrated-noise trials · {e(w["symbol"])} · {len(trials_for_row)} trials</div>'
                        f'<table class="fold-table"><thead><tr>'
                        f'<th>Trial</th>'
                        f'<th class="col-num">Breaches</th>'
                        f'<th class="col-num">Reject rate</th>'
                        f'<th class="col-num">Cushion %</th>'
                        f'<th class="col-num">Recovery</th>'
                        f'</tr></thead><tbody>{"".join(trial_rows)}</tbody></table></div>'
                    )

                # Q08 crisis-slice block
                crisis_block_html = ""
                if crisis_for_row:
                    crisis_rows = []
                    for cs in crisis_for_row:
                        slc = cs.get("slice") or "?"
                        win = f"{(cs.get('start') or '?')[:10]} → {(cs.get('end') or '?')[:10]}"
                        result = (cs.get("result") or "?").upper()
                        r_cls = ("v-pass" if result == "PASS"
                                 else "v-fail" if result == "FAIL"
                                 else "v-invalid")
                        trd = cs.get("trade_count")
                        trd_html = str(int(trd)) if isinstance(trd, (int, float)) else "—"
                        net = cs.get("net_profit")
                        if isinstance(net, (int, float)) and net != 0:
                            net_cls = "net-pos" if net > 0 else "net-neg"
                            net_html = f'<span class="{net_cls}">{fmt_dollar(net)}</span>'
                        elif isinstance(net, (int, float)):
                            net_html = '<span class="net-zero">$0.00</span>'
                        else:
                            net_html = "—"
                        pf = cs.get("profit_factor")
                        pf_html = f"{pf:.2f}" if isinstance(pf, (int, float)) else "—"
                        crisis_rows.append(
                            f'<tr><td class="fold-id">{e(slc)}</td>'
                            f'<td>{e(win)}</td>'
                            f'<td class="{r_cls}">{e(result)}</td>'
                            f'<td class="col-num">{e(trd_html)}</td>'
                            f'<td class="col-num">{net_html}</td>'
                            f'<td class="col-num">{e(pf_html)}</td></tr>'
                        )
                    crit = qxx_text(w.get("crisis_criterion") or "")
                    crit_html = (f'<div class="fold-criterion">{e(crit)}</div>'
                                 if crit else "")
                    crisis_block_html = (
                        f'<div class="fold-block">'
                        f'<div class="att-title">Crisis-slice replay · {e(w["symbol"])} · {len(crisis_for_row)} slices</div>'
                        f'{crit_html}'
                        f'<table class="fold-table"><thead><tr>'
                        f'<th>Slice</th><th>Window</th><th>Result</th>'
                        f'<th class="col-num">Trades</th>'
                        f'<th class="col-num">Net P&amp;L</th>'
                        f'<th class="col-num">PF</th>'
                        f'</tr></thead><tbody>{"".join(crisis_rows)}</tbody></table></div>'
                    )

                # Chronological attempt timeline (only when > 1 attempt)
                attempt_block_html = ""
                if n_att > 1:
                    n_sf = w.get("n_setfiles") or 1
                    framing = (f'{n_sf} parameter trials' if n_sf >= n_att
                               else (f'{n_att} re-runs of 1 setfile' if n_sf == 1
                                     else f'{n_att} runs across {n_sf} setfiles'))
                    attempt_block_html = (
                        f'<div class="att-title">{e(qid)} · {e(w["symbol"])} '
                        f'· {e(framing)} (oldest first)</div>'
                        f'<table class="att-table"><thead><tr>'
                        f'<th>When (UTC)</th><th>Verdict</th>'
                        f'<th>Setfile</th>'
                        f'<th class="col-num">Trades</th>'
                        f'<th class="col-num">Net P&amp;L</th>'
                        f'<th class="col-num">Max DD</th><th>Reason</th>'
                        f'</tr></thead><tbody>{"".join(att_rows)}</tbody></table>'
                    )

                attempt_html = (
                    f'<tr class="attempt-row hidden" id="{row_uid}"><td colspan="9">'
                    f'<div class="att-wrap">'
                    f'{fold_block_html}'
                    f'{stress_block_html}'
                    f'{trials_block_html}'
                    f'{crisis_block_html}'
                    f'{attempt_block_html}'
                    f'</div></td></tr>'
                )

            rows_html.append(f"""<tr>
  <td class="symcell">{e(w['symbol'])}{toggle_html}</td>
  <td class="{v_cls}">{e(verd)}{fr}</td>
  <td class="col-spark">{spark}</td>
  <td class="col-num">{tr_html}</td>
  <td class="col-num">{np_html}</td>
  <td class="col-num">{dd_html}</td>
  <td class="col-num">{pf_html}</td>
  <td class="col-num">{sh_html}</td>
  <td>{report_link}</td>
</tr>{attempt_html}""")

        table_html = f"""<table class="wi-table">
    <thead><tr>
      <th>Symbol</th><th>Verdict</th><th class="col-spark">Equity</th>
      <th class="col-num">Trades</th><th class="col-num">Net P&amp;L</th>
      <th class="col-num">Max DD</th><th class="col-num">PF</th>
      <th class="col-num">Sharpe</th><th>Report</th>
    </tr></thead>
    <tbody>{''.join(rows_html)}</tbody>
  </table>"""
        if len(items) > 12:
            table_block = (f'<details class="raw-rows"><summary>Show all {len(items)} '
                           f'symbol rows</summary>{table_html}</details>')
        else:
            table_block = table_html

        is_open = " open" if phase == most_advanced else ""
        phases_html_chunks.append(
            f'<details class="stage-acc"{is_open}>'
            f'<summary><span class="sa-phase">{e(phase_label(phase))}</span>'
            f'<span class="sa-verdicts">{e(verd_html)}</span>'
            f'<span class="sa-kpi">{kpi_html}</span></summary>'
            f'<div class="sa-body">{fail_box}{table_block}</div></details>'
        )

    if not phases_html_chunks:
        phases_html_chunks.append('<div class="empty" style="text-align:center;padding:40px;color:var(--qm-text-muted);">No backtest work_items yet — EA still in Q00/Q01 stage.</div>')

    # Artefacts section removed 2026-05-23 (OWNER call): filepath dumps
    # (card .md, .mq5 source, .ex5, .set files) are not useful on the EA
    # detail page. The lookup is trivial via the EA-id slug and the repo
    # layout is conventional. Variable kept (empty) to preserve template.
    files_html = ""

    ev_ts = (ea.get("last_updated") or "")[:19].replace("T", " ") or "—"
    decision_header = f"""
<div class="decision-header">
  <div class="dh-tile"><div class="dh-label">Current phase</div>
    <div class="dh-val flow">{e(phase_label(cur_phase) if cur_phase != "—" else "—")}</div></div>
  <div class="dh-tile"><div class="dh-label">Highest real PASS</div>
    <div class="dh-val {"good" if highest_pass else ""}">{e(phase_label(highest_pass) if highest_pass else "none")}</div></div>
  <div class="dh-tile"><div class="dh-label">Next gate</div>
    <div class="dh-val">{e(phase_label(next_gate) if next_gate != "—" else "—")}</div></div>
  <div class="dh-tile"><div class="dh-label">Evidence updated</div>
    <div class="dh-val">{e(ev_ts)}</div></div>
</div>
<div class="decision-summary {decision["cls"]}">
  <div class="ds-verdict">{e(decision["verdict"])}</div>
  <div class="ds-grid">
    <div><div class="ds-item-label">Why it matters</div><div class="ds-item-body">{e(decision["why"])}</div></div>
    <div><div class="ds-item-label">Remaining risk</div><div class="ds-item-body">{e(decision["risk"])}</div></div>
    <div><div class="ds-item-label">Next action</div><div class="ds-item-body">{e(decision["next"])}</div></div>
    <div><div class="ds-item-label">Status</div><div class="ds-item-body">{e(label)} · {len(present_phases)} phase(s) with evidence · {len(detail.get('symbols') or [])} symbols tested</div></div>
  </div>
</div>
"""
    rescue_rows = detail.get("q08_portfolio_rescue") or []
    rescue_html = ""
    if rescue_rows:
        row_html = []
        for r in rescue_rows:
            tier = str(r.get("q08_tier") or "—")
            q09v = str(r.get("q09_verdict") or "—")
            tier_cls = "soft" if tier == "FAIL_SOFT" else ("hard" if tier == "FAIL_HARD" else "other")
            q09_cls = (
                "pass" if q09v == "PASS_PORTFOLIO"
                else "wait" if q09v in {"NEED_MORE_DATA", "PENDING"}
                else "fail" if q09v == "FAIL_PORTFOLIO"
                else "other"
            )
            dd_delta = r.get("maxdd_delta")
            dd_txt = fmt_num(dd_delta) if isinstance(dd_delta, (int, float)) else "—"
            if isinstance(dd_delta, (int, float)) and dd_delta < 0:
                dd_txt += " better"
            elif isinstance(dd_delta, (int, float)) and dd_delta > 0:
                dd_txt += " worse"
            row_html.append(
                f'<tr><td class="symcell">{e(r.get("symbol"))}</td>'
                f'<td><span class="rescue-tier {tier_cls}">{e(tier)}</span>'
                f'<div class="fail-reason">{e(qxx_text(str(r.get("q08_reason") or ""))[:150])}</div></td>'
                f'<td class="col-num">{e(r.get("q08_trades") if r.get("q08_trades") is not None else "—")}</td>'
                f'<td><span class="rescue-q09 {q09_cls}">{e(q09v)}</span>'
                f'<div class="fail-reason">{e(str(r.get("q09_reason") or ""))[:90]}</div></td>'
                f'<td class="col-num">{e(fmt_num(r.get("corr")) if isinstance(r.get("corr"), (int, float)) else "—")}</td>'
                f'<td class="col-num">{e(fmt_num(r.get("sharpe_delta")) if isinstance(r.get("sharpe_delta"), (int, float)) else "—")}</td>'
                f'<td class="col-num">{e(dd_txt)}</td>'
                f'<td class="col-num">{e(fmt_num(r.get("standalone_pf")) if isinstance(r.get("standalone_pf"), (int, float)) else "—")}</td>'
                f'<td>{e("portfolio-only" if r.get("portfolio_only") else (r.get("candidate_state") or "—"))}</td></tr>'
            )
        rescue_html = f"""
<div class="rescue-detail">
  <div class="rescue-detail-title">Q08 portfolio-rescue track</div>
  <table class="wi-table rescue-detail-table">
    <thead><tr>
      <th>Symbol</th><th>Standalone Q08 Result</th><th class="col-num">Trades</th>
      <th>Q09 Portfolio</th><th class="col-num">Corr</th>
      <th class="col-num">Sharpe Delta</th><th class="col-num">MaxDD Delta</th>
      <th class="col-num">PF</th><th>Flag</th>
    </tr></thead>
    <tbody>{"".join(row_html)}</tbody>
  </table>
</div>
"""
    return html_head(f"{ea_id} · {slug}", ARCHIVE_CSS + EA_DETAIL_CSS + DETAIL2_CSS) + f"""
<div class="detail-wrap">
  <a class="detail-back" href="strategies.html">← back to Strategy Archive</a>
  <div class="detail-head">
    <h1><code>{e(ea_id)}</code><span class="detail-slug">{e(slug)}</span></h1>
    <span class="detail-status {status_cls}">{label}</span>
  </div>
  <div class="detail-meta">
    <span>Current <strong>{e(phase_label(cur_phase) if cur_phase != '—' else '—')}</strong></span>
    <span>Done <strong>{e(', '.join(phase_label(p) for p in (ea.get('completed_phases') or [])) or '—')}</strong></span>
    <span>Updated {e(ev_ts)}</span>
    <span>Tasks <strong>{ea.get('task_count', 0)}</strong></span>
    <span>Symbols <strong>{len(detail.get('symbols') or [])}</strong></span>
  </div>
  {decision_header}
  {rescue_html}
  {desc_html}
  {kpis_html}
  <h2 class="acc-title">Pipeline-Stage Evidence · Q01 → Q11 ascending</h2>
  {''.join(phases_html_chunks)}
  {files_html}
  <div class="archive-footer">
    Generated by render_dashboards.py · per-row Equity curves parsed inline from native MT5 reports (UTF-16) ·
    "Full MT5 ↗" links open the native report with interactive equity, trade markers, monthly distribution.
  </div>
</div>
<script>
function toggleAttempts(el) {{
  var id = el.getAttribute('data-target');
  var row = document.getElementById(id);
  if (!row) return;
  var open = row.classList.toggle('hidden') === false;
  el.classList.toggle('open', open);
  el.innerHTML = el.innerHTML.replace(/^[▸▾]/, open ? '▾' : '▸');
}}
</script>
</body>
</html>
"""


# ── Portfolio Dashboard ─────────────────────────────────────────


PORTFOLIO_CSS = """
.portfolio-wrap{max-width:1400px;margin:0 auto;padding:34px 36px 72px}
.portfolio-top{display:flex;justify-content:space-between;align-items:flex-start;gap:24px;flex-wrap:wrap;border-bottom:1px solid var(--border);padding-bottom:22px;margin-bottom:22px}
.portfolio-title h1{font-size:36px;font-weight:600;letter-spacing:-0.03em;line-height:1.05;margin:0 0 10px;color:var(--text)}
.portfolio-title h1 .em-text{color:var(--signal)}
.portfolio-sub{font-family:var(--font-mono);font-size:11px;color:var(--text-3);line-height:1.6;letter-spacing:0.06em;max-width:760px}
.portfolio-actions{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}
.portfolio-link,.portfolio-badge{display:inline-flex;align-items:center;padding:6px 10px;border:1px solid var(--border-2);background:transparent;color:var(--text-3);font-family:var(--font-mono);font-size:10px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;line-height:1.2}
.portfolio-link:hover{border-color:var(--signal);color:var(--signal)}
.portfolio-badge.good{border-color:var(--signal);color:var(--signal)}
.portfolio-badge.warn{border-color:var(--warn);color:var(--warn)}
.portfolio-status{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 20px}
.portfolio-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:28px}
.portfolio-kpi{padding:16px 18px;background:var(--surface-1);border:1px solid var(--border)}
.portfolio-kpi-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);letter-spacing:0.2em;text-transform:uppercase;margin-bottom:9px}
.portfolio-kpi-val{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:26px;font-weight:500;color:var(--text);letter-spacing:-0.02em;line-height:1}
.portfolio-kpi-val.good{color:var(--signal)}
.portfolio-kpi-val.warn{color:var(--warn)}
.portfolio-section{margin-top:26px}
.portfolio-section h2{font-family:var(--font-mono);font-size:11px;font-weight:700;color:var(--text-3);letter-spacing:0.2em;text-transform:uppercase;margin:0 0 12px}
.portfolio-panel{background:var(--surface-1);border:1px solid var(--border);padding:18px}
.portfolio-empty{padding:26px 18px;background:var(--surface-1);border:1px solid var(--border);color:var(--text-3);font-family:var(--font-mono);font-size:11px;letter-spacing:0.06em;line-height:1.6;text-align:center}
.heatmap-scroll{overflow:auto;border:1px solid var(--border);background:var(--surface-1)}
.heatmap-table{border-collapse:collapse;font-family:var(--font-mono);font-size:10px;min-width:760px;width:100%}
.heatmap-table th,.heatmap-table td{border:1px solid var(--border);padding:6px 7px;text-align:center;white-space:nowrap}
.heatmap-table th{background:var(--bg);color:var(--text-3);font-weight:700;letter-spacing:0.08em}
.heatmap-table th.row-head{text-align:left;position:sticky;left:0;z-index:2}
.heatmap-table thead th{position:sticky;top:0;z-index:3}
.heatmap-table td{font-variant-numeric:tabular-nums;color:var(--text)}
.heatmap-table td.corr-good{background:color-mix(in srgb,var(--signal) 38%,var(--surface-1));color:var(--bg)}
.heatmap-table td.corr-mid{background:var(--surface-2);color:var(--text-2)}
.heatmap-table td.corr-warn{background:color-mix(in srgb,var(--warn) 58%,var(--surface-1));color:var(--bg)}
.heatmap-table td.corr-null{background:var(--surface-2);color:var(--text-4)}
.heatmap-table td.corr-self{background:var(--bg);color:var(--text-4)}
.portfolio-svg{width:100%;height:auto;background:var(--surface-1);border:1px solid var(--border)}
.portfolio-table{width:100%;border-collapse:collapse;background:var(--surface-1);border:1px solid var(--border);font-family:var(--font-mono);font-size:11px}
.portfolio-table th{text-align:left;padding:10px 12px;background:var(--bg);border-bottom:1px solid var(--border);border-right:1px solid var(--border);font-size:9px;font-weight:700;color:var(--text-3);letter-spacing:0.18em;text-transform:uppercase}
.portfolio-table td{padding:10px 12px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);color:var(--text-2);vertical-align:middle}
.portfolio-table th:last-child,.portfolio-table td:last-child{border-right:none}
.portfolio-table tr:last-child td{border-bottom:none}
.portfolio-table .num{text-align:right;font-variant-numeric:tabular-nums;color:var(--text)}
.portfolio-table .good{color:var(--signal)}
.portfolio-table .warn{color:var(--warn)}
.portfolio-grid-2{display:grid;grid-template-columns:1.15fr .85fr;gap:16px;align-items:start}
.portfolio-foot{margin-top:34px;font-family:var(--font-mono);font-size:10px;color:var(--text-4);letter-spacing:0.06em;text-align:center;line-height:1.6}
@media(max-width:1000px){.portfolio-kpis{grid-template-columns:repeat(2,1fr)}.portfolio-grid-2{grid-template-columns:1fr}}
@media(max-width:720px){.portfolio-wrap{padding:26px 18px 56px}.portfolio-kpis{grid-template-columns:1fr}.portfolio-title h1{font-size:30px}.portfolio-actions{justify-content:flex-start}}
"""


def _load_portfolio_json(root: Path, filename: str) -> tuple[dict[str, Any] | None, str | None, Path]:
    path = root / "artifacts" / "portfolio" / filename
    if not path.exists():
        return None, "not generated yet", path
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return None, f"unreadable artifact: {exc}", path
    if not isinstance(data, dict):
        return None, "artifact is not a JSON object", path
    return data, None, path


def _placeholder(title: str, detail: str = "artifact not generated yet") -> str:
    return f'<div class="portfolio-empty"><strong>{e(title)}</strong><br>{e(detail)}</div>'


def _as_float(v: Any) -> float | None:
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return None
    return float(v)


def _portfolio_short_key(key: Any) -> str:
    s = str(key)
    if ":" not in s:
        return s
    ea_id, symbol = s.split(":", 1)
    return f"{ea_id}:{symbol.replace('.DWX', '')}"


def _portfolio_weights(manifest: dict[str, Any] | None) -> dict[str, float]:
    if not manifest or not isinstance(manifest.get("weights"), dict):
        return {}
    out: dict[str, float] = {}
    for k, v in manifest["weights"].items():
        fv = _as_float(v)
        if fv is not None:
            out[str(k)] = fv
    return out


def _portfolio_selected_keys(manifest: dict[str, Any] | None,
                             corr: dict[str, Any] | None) -> list[str]:
    raw = manifest.get("selected_keys") if manifest else None
    if isinstance(raw, list) and raw:
        return [str(k) for k in raw]
    raw = corr.get("keys") if corr else None
    if isinstance(raw, list):
        return [str(k) for k in raw]
    return []


def _portfolio_artifact_badges(errors: dict[str, str | None]) -> str:
    badges = []
    labels = {
        "manifest": "manifest",
        "correlation": "correlation",
        "montecarlo": "monte carlo",
    }
    for key, label in labels.items():
        err = errors.get(key)
        cls = "warn" if err else "good"
        text = f"{label}: {'missing' if err else 'ready'}"
        badges.append(f'<span class="portfolio-badge {cls}">{e(text)}</span>')
    return "".join(badges)


def _render_portfolio_header(manifest: dict[str, Any] | None,
                             errors: dict[str, str | None]) -> str:
    if not manifest:
        return _placeholder("Header KPIs", errors.get("manifest") or "portfolio manifest not generated yet")
    kpis = manifest.get("kpis") if isinstance(manifest.get("kpis"), dict) else {}
    sharpe = _as_float(kpis.get("sharpe"))
    max_dd = _as_float(kpis.get("max_drawdown_pct"))
    net_profit = _as_float(kpis.get("total_net_of_cost_profit"))
    sleeves = kpis.get("n_uncorrelated_sleeves", kpis.get("n_sleeves", len(manifest.get("selected_keys") or [])))
    degraded = bool(manifest.get("degraded") or manifest.get("commission_degraded"))
    basis = manifest.get("commission_basis") or "commission basis unknown"
    degraded_badge = '<span class="portfolio-badge warn">degraded</span>' if degraded else ""
    return f"""
<div class="portfolio-status">
  <span class="portfolio-badge">{e(basis)}</span>
  {degraded_badge}
  {_portfolio_artifact_badges(errors)}
</div>
<div class="portfolio-kpis">
  <div class="portfolio-kpi"><div class="portfolio-kpi-label">Portfolio Sharpe</div><div class="portfolio-kpi-val good">{e(fmt_num(sharpe, 2))}</div></div>
  <div class="portfolio-kpi"><div class="portfolio-kpi-label">Portfolio max DD</div><div class="portfolio-kpi-val warn">{e(fmt_pct(max_dd, 2))}</div></div>
  <div class="portfolio-kpi"><div class="portfolio-kpi-label">Net-of-cost profit</div><div class="portfolio-kpi-val good">{e(fmt_dollar(net_profit))}</div></div>
  <div class="portfolio-kpi"><div class="portfolio-kpi-label">Uncorrelated sleeves</div><div class="portfolio-kpi-val">{e(sleeves)}</div></div>
</div>
"""


def _corr_cell_class(v: float | None, is_self: bool) -> str:
    if is_self:
        return "corr-self"
    if v is None:
        return "corr-null"
    if v <= 0.30:
        return "corr-good"
    if v <= 0.65:
        return "corr-mid"
    return "corr-warn"


def _render_portfolio_heatmap(corr: dict[str, Any] | None,
                              manifest: dict[str, Any] | None,
                              error: str | None) -> str:
    if not corr:
        return _placeholder("Correlation heatmap", error or "correlation artifact not generated yet")
    all_keys = [str(k) for k in corr.get("keys") or []]
    matrix = corr.get("correlation_matrix") or corr.get("correlation")
    if not all_keys or not isinstance(matrix, list):
        return _placeholder("Correlation heatmap", "correlation matrix not present in artifact")
    selected = _portfolio_selected_keys(manifest, corr)
    index = {k: i for i, k in enumerate(all_keys)}
    keys = [k for k in selected if k in index]
    if not keys:
        keys = all_keys[:40]
    header = "".join(f'<th title="{e(k)}">{e(_portfolio_short_key(k))}</th>' for k in keys)
    rows = []
    for rk in keys:
        ri = index[rk]
        row = [f'<th class="row-head" title="{e(rk)}">{e(_portfolio_short_key(rk))}</th>']
        raw_row = matrix[ri] if ri < len(matrix) and isinstance(matrix[ri], list) else []
        for ck in keys:
            ci = index[ck]
            val = _as_float(raw_row[ci]) if ci < len(raw_row) else None
            cls = _corr_cell_class(val, rk == ck)
            text = "—" if val is None else f"{val:.2f}"
            row.append(f'<td class="{cls}" title="{e(rk)} vs {e(ck)}">{e(text)}</td>')
        rows.append(f"<tr>{''.join(row)}</tr>")
    return f"""
<div class="heatmap-scroll">
  <table class="heatmap-table">
    <thead><tr><th class="row-head">Sleeve</th>{header}</tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table>
</div>
"""


def _series_from_candidate(candidate: Any) -> list[float]:
    values: list[float] = []
    if isinstance(candidate, list):
        for item in candidate:
            if isinstance(item, dict):
                for key in ("equity", "balance", "value", "portfolio_equity", "combined_equity"):
                    fv = _as_float(item.get(key))
                    if fv is not None:
                        values.append(fv)
                        break
            else:
                fv = _as_float(item)
                if fv is not None:
                    values.append(fv)
    elif isinstance(candidate, dict):
        for item in candidate.values():
            fv = _as_float(item)
            if fv is not None:
                values.append(fv)
    return values


def _extract_portfolio_equity(manifest: dict[str, Any] | None) -> list[float]:
    if not manifest:
        return []
    for key in (
        "combined_equity",
        "combined_equity_curve",
        "equity_curve",
        "portfolio_equity",
        "portfolio_equity_curve",
    ):
        values = _series_from_candidate(manifest.get(key))
        if len(values) >= 2:
            return values
    return []


def _portfolio_equity_svg(series: list[float], width: int = 960, height: int = 240) -> str:
    if len(series) < 2:
        return f'''<svg class="portfolio-svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
<rect x="0" y="0" width="{width}" height="{height}" fill="var(--surface-1)"/>
<text x="{width // 2}" y="{height // 2}" fill="var(--text-4)" font-size="13" text-anchor="middle" font-family="JetBrains Mono, monospace">combined equity series not generated yet</text>
</svg>'''
    vmin = min(series)
    vmax = max(series)
    span = (vmax - vmin) or 1.0
    pad = 18
    inner_w = width - 2 * pad
    inner_h = height - 2 * pad
    points: list[tuple[float, float]] = []
    for i, v in enumerate(series):
        x = pad + (i / max(1, len(series) - 1)) * inner_w
        y = pad + inner_h - ((v - vmin) / span) * inner_h
        points.append((x, y))
    line_d = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    base_y = pad + inner_h
    fill_d = f"M {points[0][0]:.1f},{base_y:.1f} L " + " L ".join(
        f"{x:.1f},{y:.1f}" for x, y in points
    ) + f" L {points[-1][0]:.1f},{base_y:.1f} Z"
    return f'''<svg class="portfolio-svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
<rect x="0" y="0" width="{width}" height="{height}" fill="var(--surface-1)"/>
<line x1="{pad}" y1="{base_y:.1f}" x2="{width - pad}" y2="{base_y:.1f}" stroke="var(--border-2)" stroke-width="1"/>
<path d="{fill_d}" fill="var(--signal)" opacity="0.14" stroke="none"/>
<path d="{line_d}" fill="none" stroke="var(--signal)" stroke-width="2" stroke-linejoin="round"/>
<circle cx="{points[-1][0]:.1f}" cy="{points[-1][1]:.1f}" r="3" fill="var(--signal)"/>
<text x="{pad}" y="16" fill="var(--text-4)" font-size="10" font-family="JetBrains Mono, monospace">{e(fmt_dollar(vmax))}</text>
<text x="{pad}" y="{height - 6}" fill="var(--text-4)" font-size="10" font-family="JetBrains Mono, monospace">{e(fmt_dollar(vmin))}</text>
</svg>'''


def _render_portfolio_montecarlo(mc: dict[str, Any] | None, error: str | None) -> str:
    if not mc:
        return _placeholder("Monte Carlo band", error or "Monte Carlo artifact not generated yet")
    rows = []
    labels = {
        "block_bootstrap": "Block bootstrap",
        "trade_order_shuffle": "Trade-order shuffle",
    }
    metrics = {
        "max_drawdown_pct": "Max DD",
        "terminal_equity": "Terminal equity",
    }
    for mode_key, mode_label in labels.items():
        mode = mc.get(mode_key)
        if not isinstance(mode, dict):
            continue
        for metric_key, metric_label in metrics.items():
            vals = mode.get(metric_key)
            if not isinstance(vals, dict):
                continue
            is_pct = metric_key == "max_drawdown_pct"
            def fmt(v: Any) -> str:
                fv = _as_float(v)
                if fv is None:
                    return "—"
                return fmt_pct(fv, 2) if is_pct else fmt_dollar(fv)
            rows.append(
                f'<tr><td>{e(mode_label)}</td><td>{e(metric_label)}</td>'
                f'<td class="num">{e(fmt(vals.get("p5")))}</td>'
                f'<td class="num">{e(fmt(vals.get("p50")))}</td>'
                f'<td class="num">{e(fmt(vals.get("p95")))}</td></tr>'
            )
    if not rows:
        return _placeholder("Monte Carlo band", "p5/p50/p95 bands not present in artifact")
    return f"""
<table class="portfolio-table">
  <thead><tr><th>Method</th><th>Metric</th><th class="num">p5</th><th class="num">p50</th><th class="num">p95</th></tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>
"""


def _render_portfolio_sleeves(manifest: dict[str, Any] | None,
                              corr: dict[str, Any] | None,
                              manifest_error: str | None) -> str:
    keys = _portfolio_selected_keys(manifest, corr)
    if not manifest or not keys:
        return _placeholder("Per-sleeve table", manifest_error or "selected sleeve manifest not generated yet")
    per_series = corr.get("per_series") if corr and isinstance(corr.get("per_series"), dict) else {}
    weights = _portfolio_weights(manifest)
    rows = []
    for key in keys:
        stats = per_series.get(key) if isinstance(per_series.get(key), dict) else {}
        note = (
            stats.get("marginal_diversification_note")
            or stats.get("diversification_note")
            or stats.get("note")
            or "selected"
        )
        net = _as_float(stats.get("net_of_cost_total"))
        net_cls = "good" if isinstance(net, float) and net >= 0 else "warn" if isinstance(net, float) else ""
        trades = stats.get("trades", "—")
        active_days = stats.get("active_days", "—")
        weight = weights.get(key)
        rows.append(
            f'<tr><td title="{e(key)}">{e(_portfolio_short_key(key))}</td>'
            f'<td class="num">{e(fmt_pct(weight * 100, 2) if weight is not None else "—")}</td>'
            f'<td class="num">{e(trades)}</td>'
            f'<td class="num">{e(active_days)}</td>'
            f'<td class="num {net_cls}">{e(fmt_dollar(net))}</td>'
            f'<td>{e(note)}</td></tr>'
        )
    return f"""
<table class="portfolio-table">
  <thead><tr><th>Key</th><th class="num">Weight</th><th class="num">Trades</th><th class="num">Active days</th><th class="num">Net-of-cost</th><th>Diversification note</th></tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>
"""


def render_portfolio(root: Path) -> str:
    manifest, manifest_error, _manifest_path = _load_portfolio_json(root, "portfolio_manifest_dev.json")
    corr, corr_error, _corr_path = _load_portfolio_json(root, "correlation_dev.json")
    mc, mc_error, _mc_path = _load_portfolio_json(root, "portfolio_montecarlo_dev.json")
    errors = {
        "manifest": manifest_error,
        "correlation": corr_error,
        "montecarlo": mc_error,
    }
    generated = manifest.get("generated_at_utc") if manifest else "—"
    basis = (manifest.get("generated_basis") or manifest.get("basis")) if manifest else "not generated yet"
    equity = _extract_portfolio_equity(manifest)
    return html_head("Portfolio Dashboard", PORTFOLIO_CSS) + f"""
<div class="portfolio-wrap">
  <div class="portfolio-top">
    <div class="portfolio-title">
      <h1>Portfolio <span class="em-text">Dashboard</span></h1>
      <div class="portfolio-sub">Read-only Wave-2 portfolio artifacts. Generated {e(generated)} · basis {e(basis)}.</div>
    </div>
    <div class="portfolio-actions">
      <a class="portfolio-link" href="strategies.html">Strategy Archive</a>
    </div>
  </div>

  {_render_portfolio_header(manifest, errors)}

  <section class="portfolio-section">
    <h2>Correlation heatmap</h2>
    {_render_portfolio_heatmap(corr, manifest, corr_error)}
  </section>

  <section class="portfolio-section">
    <h2>Combined equity curve</h2>
    {_portfolio_equity_svg(equity)}
  </section>

  <div class="portfolio-grid-2">
    <section class="portfolio-section">
      <h2>Monte Carlo band</h2>
      {_render_portfolio_montecarlo(mc, mc_error)}
    </section>
    <section class="portfolio-section">
      <h2>Portfolio inputs</h2>
      <div class="portfolio-panel">
        <table class="portfolio-table">
          <tbody>
            <tr><td>Starting capital</td><td class="num">{e(fmt_dollar(_as_float(manifest.get("starting_capital")) if manifest else None))}</td></tr>
            <tr><td>Weighting</td><td class="num">{e(manifest.get("weighting", "—") if manifest else "—")}</td></tr>
            <tr><td>Series considered</td><td class="num">{e(manifest.get("n_series_considered", "—") if manifest else "—")}</td></tr>
            <tr><td>Days</td><td class="num">{e(manifest.get("n_days", "—") if manifest else "—")}</td></tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>

  <section class="portfolio-section">
    <h2>Per-sleeve table</h2>
    {_render_portfolio_sleeves(manifest, corr, manifest_error)}
  </section>

  <div class="portfolio-foot">
    Generated by tools/strategy_farm/dashboards/render_dashboards.py · data: D:/QM/strategy_farm/artifacts/portfolio/
  </div>
</div>
</body>
</html>
"""


# ── Main ─────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(description="Render strategy_farm dashboards")
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    args = parser.parse_args()

    root = Path(args.root).resolve()
    dashboards_dir = root / "dashboards"
    dashboards_dir.mkdir(parents=True, exist_ok=True)

    # Sync style.css from repo template into output dir if newer
    src_css = Path(__file__).parent / "style.css"
    dst_css = dashboards_dir / "style.css"
    if src_css.exists() and (not dst_css.exists() or src_css.stat().st_mtime > dst_css.stat().st_mtime):
        dst_css.write_bytes(src_css.read_bytes())

    state = collect_farm_state(root)
    mt5 = get_mt5_fleet_status()

    # current.html retired 2026-05-23 (OWNER decision); cockpit.html (render_cockpit.py) is the canonical live ops view.
    strategies_path = dashboards_dir / "strategies.html"
    strategies_path.write_text(render_strategies(state, root), encoding="utf-8")

    portfolio_path = dashboards_dir / "portfolio.html"
    portfolio_path.write_text(render_portfolio(root), encoding="utf-8")

    # Per-EA detail pages — skip TRUE card-only EAs (no work_items, no tasks,
    # only a card on disk). EAs with work_items DO need detail pages even
    # when they also have a card — the row in strategies.html is clickable
    # because work_items exist. Pre-PT12 the skip condition was just
    # (card_state AND task_count==0) which incorrectly suppressed pages for
    # EAs like QM5_1099 (8 Q02 attempts, no agent_task) → broken links.
    eas = derive_ea_candidates(state["tasks"], root)
    wi_eas: set[str] = set()
    db_path = root / "state" / "farm_state.sqlite"
    if db_path.exists():
        try:
            with sqlite3.connect(db_path) as _conn:
                wi_eas = {r[0] for r in _conn.execute("SELECT DISTINCT ea_id FROM work_items")}
        except sqlite3.Error:
            wi_eas = set()
    detail_count = 0
    skipped_card_only = 0
    for ea in eas:
        has_wi = ea["ea_id"] in wi_eas
        if (ea.get("card_state")
                and ea.get("task_count", 0) == 0
                and not has_wi):
            skipped_card_only += 1
            continue
        try:
            d = collect_ea_detail(ea["ea_id"], root)
            out_path = dashboards_dir / f"ea_{ea['ea_id']}.html"
            out_path.write_text(render_ea_detail(ea, d, state), encoding="utf-8")
            detail_count += 1
        except Exception as exc:
            print(f"WARN: ea_{ea['ea_id']}.html failed: {exc!r}", file=sys.stderr)

    summary = {
        "rendered_at": utc_now_iso(),
        "strategies_html": str(strategies_path),
        "portfolio_html": str(portfolio_path),
        "style_css": str(dst_css),
        "ea_detail_pages": detail_count,
        "ea_count": len(eas),
        "source_count": len(state["sources"]),
        "task_count": len(state["tasks"]),
        "event_count": len(state["events"]),
        "mt5_running": mt5["running_count"],
    }
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
