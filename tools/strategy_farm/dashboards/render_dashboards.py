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
            last_key: str | None = None
            for line in yaml_block.splitlines():
                stripped = line.strip()
                if line.startswith("  ") and stripped.startswith("- ") and last_key:
                    # block-style list item under the previous key (concepts:, indicators:, …)
                    item = stripped[2:].strip()
                    if item.startswith('"') and item.endswith('"'):
                        item = item[1:-1]
                    cur = fm.get(last_key)
                    if isinstance(cur, list):
                        cur.append(item)
                    elif cur in ("", None):
                        fm[last_key] = [item]
                    else:
                        fm[last_key] = [cur, item]
                elif ":" in line and not stripped.startswith("#") and not line.startswith("  "):
                    k, _, v = line.partition(":")
                    v = v.strip()
                    if v.startswith('"') and v.endswith('"'):
                        v = v[1:-1]
                    fm[k.strip()] = v
                    last_key = k.strip()
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

    Returns SVG with: balance polyline (profit-green if net+, loss-red if net-),
    DD shading from rolling-max, baseline + endpoint marker. No axis labels
    in mini mode; pure visual.
    """
    if len(deals) < 2:
        return f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}"><text x="{width//2}" y="{height//2 + 4}" fill="#9a938a" font-size="10" text-anchor="middle" font-family="monospace">no equity data</text></svg>'

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
    line_color = "#1a8f4c" if net_profit >= 0 else "#d13438"
    fill_color = "rgba(26,143,76,0.10)" if net_profit >= 0 else "rgba(209,52,56,0.10)"
    dd_color = "rgba(209,52,56,0.18)"

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


# ── Render-stamp badge (shared across every surface) ─────────────

# Populated once per process in main(); every surface reads it so the
# "RENDERED HH:MM:SS" badge is consistent across strategies.html, the
# per-EA detail pages, and portfolio.html.
RENDER_STAMP: dict[str, Any] = {"hms": "--:--:--", "epoch": 0, "iso": ""}


def set_render_stamp() -> None:
    now_local = dt.datetime.now()
    RENDER_STAMP["hms"] = now_local.strftime("%H:%M:%S")
    RENDER_STAMP["epoch"] = int(now_local.timestamp())
    RENDER_STAMP["iso"] = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


RENDER_BADGE_CSS = """
.render-badge{display:inline-flex;align-items:center;gap:7px;font-family:var(--font-mono);font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;padding:5px 12px;border:1px solid var(--border-2);background:var(--surface-1);color:var(--text-3);white-space:nowrap}
.render-badge .rb-dot{width:7px;height:7px;background:var(--signal);flex:0 0 auto}
.render-badge .rb-lbl{color:var(--text-3)}
.render-badge .rb-time{color:var(--text);font-weight:700}
.render-badge .rb-sep{color:var(--text-4)}
.render-badge .rb-age{color:var(--text-3);letter-spacing:0.06em}
.render-badge.rb-warn{border-color:var(--warn)}
.render-badge.rb-warn .rb-dot{background:var(--warn)}
.render-badge.rb-warn .rb-age{color:var(--warn)}
.render-badge.rb-stale{border-color:var(--fail)}
.render-badge.rb-stale .rb-dot{background:var(--fail)}
.render-badge.rb-stale .rb-age{color:var(--fail)}
.render-badge-bar{position:fixed;top:12px;right:16px;z-index:60}
@media(max-width:640px){.render-badge-bar{position:static;margin:10px 0 0}}
"""

RENDER_BADGE_JS = """<script>
(function(){
  document.querySelectorAll('.render-badge[data-epoch]').forEach(function(b){
    var t=parseInt(b.getAttribute('data-epoch'),10)||0;
    var age=b.querySelector('.rb-age');
    function upd(){
      var s=(Date.now()/1000)-t, h=s/3600, txt;
      if(t<=0){txt='';}
      else if(s<90){txt='just now';}
      else if(s<3600){txt=Math.round(s/60)+'m ago';}
      else{txt=Math.floor(h)+'h '+Math.round((h-Math.floor(h))*60)+'m ago';}
      if(age){age.textContent=txt;}
      b.classList.remove('rb-warn','rb-stale');
      if(h>6){b.classList.add('rb-stale');}
      else if(h>2){b.classList.add('rb-warn');}
    }
    upd();setInterval(upd,30000);
  });
})();
</script>"""


def render_badge_html() -> str:
    """Static badge markup. Age text + colour are filled in by RENDER_BADGE_JS."""
    hms = RENDER_STAMP.get("hms") or "--:--:--"
    epoch = int(RENDER_STAMP.get("epoch") or 0)
    return (
        f'<span class="render-badge" data-epoch="{epoch}">'
        f'<span class="rb-dot"></span><span class="rb-lbl">Rendered</span>'
        f'<span class="rb-time">{e(hms)}</span>'
        f'<span class="rb-sep">·</span><span class="rb-age"></span></span>'
    )


def inject_render_badge(page_html: str) -> str:
    """Insert a fixed-position render badge + its JS into a full page string.

    Used for the per-EA detail pages, which are produced by render_ea_detail()
    as complete documents. strategies.html embeds the badge inline instead.
    """
    bar = f'<div class="render-badge-bar">{render_badge_html()}</div>{RENDER_BADGE_JS}'
    if "<body>\n" in page_html:
        return page_html.replace("<body>\n", "<body>\n" + bar + "\n", 1)
    return page_html


def _iso_from_mtime(path: Path) -> str:
    """UTC ISO string for a file's mtime — used to seed the render watermark
    from an already-rendered page when no state row exists yet."""
    try:
        return dt.datetime.fromtimestamp(path.stat().st_mtime, dt.UTC).replace(
            microsecond=0).isoformat()
    except OSError:
        return ""


def _format_upgrade_file(path: Path) -> bool:
    """Cheaply bring an existing, content-current detail page up to the current
    format (meta refresh + render badge) WITHOUT re-running the expensive
    collect_ea_detail() pass. Idempotent; returns True if the file was touched.

    Used during the one-time format migration so pages whose underlying data has
    not changed still gain the badge without a full re-render.
    """
    try:
        txt = path.read_text(encoding="utf-8")
    except OSError:
        return False
    if "render-badge" in txt:
        return False  # already current format
    changed = False
    if 'http-equiv="refresh"' not in txt:
        txt = txt.replace(
            '<meta charset="UTF-8">',
            '<meta charset="UTF-8">\n<meta http-equiv="refresh" content="600">', 1)
        changed = True
    if "<style>" in txt and ".render-badge{" not in txt:
        txt = txt.replace("<style>", "<style>\n" + RENDER_BADGE_CSS, 1)
        changed = True
    if "<body>\n" in txt:
        bar = f'<div class="render-badge-bar">{render_badge_html()}</div>{RENDER_BADGE_JS}'
        txt = txt.replace("<body>\n", "<body>\n" + bar + "\n", 1)
        changed = True
    if changed:
        try:
            path.write_text(txt, encoding="utf-8")
        except OSError:
            return False
    return changed


# ── HTML head ────────────────────────────────────────────────────


def html_head(title: str, extra_css: str = "") -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="600">
<title>{e(title)} · QuantMechanica V5</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="preconnect" href="https://api.fontshare.com" crossorigin>
<link href="https://api.fontshare.com/v2/css?f[]=general-sans@200,400,500,600,700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="style.css">
<style>
{RENDER_BADGE_CSS}
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
.archive-table .progress-bar .pcell.p-done{background:var(--pass);border-color:var(--pass)}
.archive-table .progress-bar .pcell.p-current{background:var(--live);border-color:var(--live)}
.archive-table .progress-bar .pcell.p-failed{background:var(--fail);border-color:var(--fail)}
.archive-table .v-pass{color:var(--pass);font-weight:600}
.archive-table .net-pos{color:var(--profit);font-weight:600}
.archive-table .v-fail{color:var(--fail);font-weight:600}
.archive-table .net-neg{color:var(--loss);font-weight:600}
.archive-table .v-invalid{color:var(--promising)}
.archive-table .v-pending{color:var(--text-3)}
.archive-table .status-chip{font-size:10px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;display:inline-block}
.archive-table .status-chip.s-dead{color:var(--fail);background:transparent}
.archive-table .status-chip.s-flow{color:var(--live);background:transparent}
.archive-table .status-chip.s-live{color:var(--live);background:transparent}
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
.detail-status.s-live{color:var(--live);border-color:var(--live)}

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
.kpi-tile-val.pos{color:var(--profit)}
.kpi-tile-val.neg{color:var(--loss)}
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
.wi-table .v-pass{color:var(--pass);font-weight:600}
.wi-table .v-fail{color:var(--fail);font-weight:600}
.wi-table .v-invalid{color:var(--promising);font-weight:600}
.wi-table .v-pending{color:var(--text-3)}
.wi-table .net-pos{color:var(--profit)}
.wi-table .net-neg{color:var(--loss)}
.wi-table .fail-reason{font-family:var(--font-mono);font-size:10px;color:var(--text-3);margin-top:3px;letter-spacing:0.04em}
.wi-table .fail-reason.infra{color:var(--warn)}
.wi-table .fail-reason.strategy{color:var(--fail)}
.wi-table .report-link{font-family:var(--font-mono);font-size:10px;color:var(--live);text-decoration:none;letter-spacing:0.1em;text-transform:uppercase;font-weight:600}
.wi-table .report-link:hover{text-decoration:underline}
.wi-table .net-zero{color:var(--text-3)}
.wi-table .net-nodata,.fold-table .net-nodata{color:var(--text-3);opacity:.55}
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
.death-strip{max-width:1400px;margin:18px auto 0;padding:0 36px}
.death-strip-label{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.18em;margin-bottom:8px;text-align:center}
.death-strip-label .death-total{color:var(--fail);letter-spacing:0.06em}
.death-row{display:flex;justify-content:center;gap:8px;flex-wrap:wrap}
.death-cell{padding:8px 14px;background:var(--surface-1);border:1px solid var(--border);border-top:2px solid var(--fail);min-width:64px;text-align:center}
.death-cell .death-gate{font-family:var(--font-mono);font-size:9px;font-weight:600;color:var(--text-3);text-transform:uppercase;letter-spacing:0.14em}
.death-cell .death-n{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:17px;font-weight:500;color:var(--fail);margin-top:4px}
.cards-reservoir{max-width:1400px;margin:26px auto 0;padding:16px 20px;background:var(--surface-1);border:1px solid var(--border)}
.cards-reservoir summary{cursor:pointer;font-family:var(--font-mono);font-size:11px;color:var(--text-2);line-height:1.55;letter-spacing:0.04em}
.cards-reservoir summary strong{color:var(--text);letter-spacing:0.1em;text-transform:uppercase}
.cards-reservoir .archive-table-wrap{margin-top:12px}
"""


DETAIL2_CSS = """
.availability{display:flex;align-items:baseline;gap:14px;flex-wrap:wrap;margin:0 0 18px;padding:13px 18px;background:var(--surface-1);border:1px solid var(--border);border-left:3px solid var(--text-3)}
.availability .av-label{font-family:var(--font-mono);font-size:11px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;white-space:nowrap}
.availability .av-body{font-family:var(--font-mono);font-size:11px;color:var(--text-3);line-height:1.6;letter-spacing:0.03em;flex:1;min-width:300px}
.availability.av-live{border-left-color:var(--live)} .availability.av-live .av-label{color:var(--live)}
.availability.av-cand{border-left-color:var(--live)} .availability.av-cand .av-label{color:var(--live)}
.availability.av-flow{border-left-color:var(--warn)} .availability.av-flow .av-label{color:var(--warn)}
.availability.av-failed{border-left-color:var(--fail)} .availability.av-failed .av-label{color:var(--fail)}
.concept-chips{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px}
.concept-chip{padding:4px 10px;border:1px solid var(--border-2);font-family:var(--font-mono);font-size:10px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--live)}
.rescue-detail-note{font-family:var(--font-mono);font-size:10px;color:var(--text-3);line-height:1.6;letter-spacing:0.04em;margin:6px 0 12px;max-width:900px}
.decision-header{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:16px 0 18px}
.dh-tile{padding:14px 16px;background:var(--surface-1);border:1px solid var(--border)}
.dh-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.2em;margin-bottom:8px}
.dh-val{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:18px;font-weight:500;color:var(--text);line-height:1.15;letter-spacing:-0.01em}
.dh-val.good{color:var(--pass)}
.dh-val.bad{color:var(--fail)}
.dh-val.flow{color:var(--live)}
.decision-summary{padding:20px 22px;background:var(--surface-1);border:1px solid var(--border);margin-bottom:24px}
.decision-summary.ds-bad{border-color:var(--fail);border-left-width:2px}
.decision-summary.ds-good{border-color:var(--pass);border-left-width:2px}
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
.rescue-detail-table .rescue-q09.pass{color:var(--pass)}
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
.att-table .v-pass{color:var(--pass);font-weight:600}
.att-table .v-fail{color:var(--fail);font-weight:600}
.att-table .v-invalid{color:var(--promising);font-weight:600}
.att-table .v-completed{color:var(--text-2);font-weight:600}
.att-table .att-reason{color:var(--text-3);font-size:9.5px;letter-spacing:0.02em}
.att-table .att-promo{display:inline-block;margin-left:6px;padding:1px 6px;font-size:8px;font-weight:700;letter-spacing:0.14em;color:var(--surface-1);background:var(--pass);text-transform:uppercase}
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
.fold-table .net-pos{color:var(--profit);font-weight:600}
.fold-table .net-neg{color:var(--loss);font-weight:600}
.fold-table .clean-yes{color:var(--pass)}
.fold-table .clean-no{color:var(--fail)}
.fold-table .regime{font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-3)}
"""


def _ea_status(ea: dict) -> tuple[str, str]:
    """Return (label, css-class-suffix) for an EA.

    Labels are EXTERNAL-facing (2026-06-11, OWNER: archive targets outside
    readers/future buyers): "IN VALIDATION" instead of internal "IN FLOW",
    "FAILED" instead of "DEAD". CSS class suffixes stay stable (filter JS)."""
    if ea.get("live"):
        return "LIVE", "s-live"
    if ea.get("dead"):
        return "FAILED", "s-dead"
    return "IN VALIDATION", "s-flow"


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

    # Headline numbers (best P&L / trades / worst DD) come from the normalized
    # ea_metrics layer, not the latest-per-cell work_item — the latest attempt is
    # frequently an INFRA_FAIL re-run or ablation perturbation that buries the real
    # PASS run. Ablation perturbations are excluded from "best" by design.
    mx: dict[str, dict[str, Any]] = {}
    try:
        with sqlite3.connect(db) as conn2:
            conn2.row_factory = sqlite3.Row
            mrows = conn2.execute(
                f"SELECT ea_id, phase, symbol, net_profit, trades, drawdown_money "
                f"FROM ea_metrics WHERE ea_id IN ({placeholders}) "
                f"AND COALESCE(is_ablation,0)=0",
                ea_ids,
            ).fetchall()
        agg: dict[str, dict[str, Any]] = defaultdict(
            lambda: {"best": None, "trades": [], "dds": []})
        for r in mrows:
            a = agg[r["ea_id"]]
            net = r["net_profit"]
            if isinstance(net, (int, float)):
                if a["best"] is None or net > a["best"][0]:
                    a["best"] = (net, r["phase"], r["symbol"])
            if isinstance(r["trades"], (int, float)):
                a["trades"].append(r["trades"])
            if isinstance(r["drawdown_money"], (int, float)):
                a["dds"].append(r["drawdown_money"])
        mx = agg
    except sqlite3.OperationalError:
        mx = {}  # ea_metrics not built yet → fall back to work_item stats below

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

        # Prefer the normalized ea_metrics aggregate; fall back to work_item stats.
        m_agg = mx.get(ea_id) or {}
        best = m_agg.get("best") or (max(nets, key=lambda x: x[0]) if nets else None)
        m_trades = m_agg.get("trades") or trades
        m_dds = m_agg.get("dds") or dds
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
            "trades_mean": (sum(m_trades) / len(m_trades)) if m_trades else None,
            "dd_worst": max(m_dds) if m_dds else None,
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


# ── Strategy Archive v2 — lean operator surface ──────────────────
#
# strategies.html is rebuilt hourly from the pipeline DB. v2 (2026-07-19)
# reshapes it into four operator sections: (a) LIVE BOOK, (b) FRONTIER,
# (c) RECENT VERDICTS, (d) ARCHIVE INDEX. Everything is derived from a single
# pass over work_items (collect_archive_v2) plus the T_Live preset filenames
# and the sealed portfolio manifest — it never depends on the per-EA detail
# pages being freshly rendered.

LIVE_PRESETS_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets")  # read-only
_BOOK_DATE = "2026-07-19"  # last DXZ book deploy — frontier "passes since" anchor
_OPEN_STATUSES = ("active", "pending", "claimed")
_FRONTIER_MIN = "Q07"

_QBASE_RE = re.compile(r"^(Q\d{2})")
_PRESET_RE = re.compile(r"^(\d+)_([A-Z0-9]+)_([A-Za-z0-9]+)_QM5_(\d+)_(.+)\.set$")


def _phase_base(phase: Any) -> str:
    """Collapse a stored phase key to its canonical base Qxx (never a raw P*).

    'Q09_PORTFOLIO' -> 'Q09'; 'P2' -> 'Q02'; 'Q05' -> 'Q05'.
    """
    if not phase:
        return ""
    s = str(phase)
    m = _QBASE_RE.match(s)
    if m:
        return m.group(1)
    return PHASE_QID.get(s, s)  # legacy P-key → Qxx (PHASE_QID = LEGACY_P_TO_Q)


def _verdict_family(v: str | None) -> str:
    if not v:
        return "other"
    u = v.upper()
    if u.startswith("PASS"):
        return "pass"
    if u == "INFRA_FAIL":
        return "infra"
    if u.startswith("FAIL"):
        return "fail"
    return "other"


_VCLS = {"pass": "v-pass", "fail": "v-fail", "infra": "v-infra", "other": "v-other"}


def _build_slug_map(repo_root: Path) -> dict[str, str]:
    """One directory scan: QM5_<id>_<slug> -> {'QM5_<id>': '<slug>'}."""
    out: dict[str, str] = {}
    d = repo_root / "framework" / "EAs"
    try:
        for entry in os.scandir(d):
            if entry.is_dir() and entry.name.startswith("QM5_"):
                parts = entry.name.split("_", 2)
                if len(parts) >= 3:
                    out[f"QM5_{parts[1]}"] = parts[2]
                elif len(parts) == 2:
                    out.setdefault(f"QM5_{parts[1]}", "")
    except OSError:
        pass
    return out


def _parse_live_presets(presets_dir: Path) -> list[dict[str, Any]]:
    """Parse the T_Live NN_Symbol_TF_QM5_<id>_<slug>.set preset filenames.

    READ-ONLY listing of the live terminal preset folder — never mutates it.
    """
    out: list[dict[str, Any]] = []
    try:
        names = sorted(os.listdir(presets_dir))
    except OSError:
        return out
    for fn in names:
        m = _PRESET_RE.match(fn)
        if not m:
            continue
        slot, sym, tf, eid, slug = m.groups()
        out.append({"slot": slot, "symbol": sym, "tf": tf,
                    "ea_id": int(eid), "slug": slug, "preset": fn})
    out.sort(key=lambda r: r["slot"])
    return out


def _load_book_manifest(root: Path) -> tuple[dict[str, Any] | None, Path | None]:
    """Newest sealed sunday-final portfolio manifest (weights/KPIs/composition)."""
    pdir = root.parent / "reports" / "portfolio"
    try:
        cands = sorted(pdir.glob("portfolio_manifest_sunday_final_*sleeve*.json"))
    except OSError:
        cands = []
    if not cands:
        return None, None
    p = cands[-1]
    try:
        return json.loads(p.read_text(encoding="utf-8")), p
    except Exception:
        return None, p


def collect_archive_v2(root: Path, slug_map: dict[str, str]) -> dict[str, Any]:
    """Single pass over work_items → everything strategies.html needs.

    Returns per-EA aggregates, per-(ea,symbol) latest verdicts, 7-day verdict
    counts by phase, top movers, and the qualification frontier.
    """
    now = dt.datetime.now(dt.UTC)
    today = now.date()
    win_start = (today - dt.timedelta(days=6)).isoformat()   # last 7 days (inclusive)
    win_end = (today + dt.timedelta(days=1)).isoformat()      # excludes future sentinels
    q07_idx = PHASE_ORDER.index(_FRONTIER_MIN)

    out: dict[str, Any] = {
        "ea": {}, "cell_latest": {}, "recent": {}, "movers": [],
        "frontier_open": [], "frontier_passes": [],
        "now_iso": now.replace(microsecond=0).isoformat(),
        "win_start": win_start, "book_date": _BOOK_DATE,
    }
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return out

    ea_agg: dict[str, dict] = {}
    cell_latest: dict[tuple[str, str], dict] = {}
    recent: dict[str, dict] = {}
    mover_pass: dict[str, dict] = {}
    open_map: dict[tuple, dict] = {}
    pass_map: dict[tuple, dict] = {}

    with sqlite3.connect(db) as conn:  # SELECT only — DB is read-only for this tool
        cur = conn.execute(
            "SELECT ea_id, phase, symbol, status, verdict, updated_at FROM work_items")
        for ea_id, phase, symbol, status, verdict, updated_at in cur:
            if not ea_id:
                continue
            upd = updated_at or ""
            future = upd >= win_end
            base = _phase_base(phase)
            bidx = PHASE_ORDER.index(base) if base in PHASE_ORDER else -1
            v = (verdict or "").upper()
            st = (status or "").lower()
            fam = _verdict_family(v)

            a = ea_agg.get(ea_id)
            if a is None:
                a = ea_agg[ea_id] = {"last_upd": "", "last_verdict": None,
                                     "hp_idx": -1, "hp": None, "adv_idx": -1,
                                     "adv": None, "n": 0, "n_pass": 0}
            a["n"] += 1
            if fam == "pass":
                a["n_pass"] += 1
            if bidx > a["adv_idx"]:
                a["adv_idx"], a["adv"] = bidx, base
            if fam == "pass" and bidx > a["hp_idx"]:
                a["hp_idx"], a["hp"] = bidx, base
            if not future and upd > a["last_upd"]:
                a["last_upd"], a["last_verdict"] = upd, (v or None)

            if symbol and not future:
                ck = (ea_id, symbol)
                cl = cell_latest.get(ck)
                if cl is None or upd > cl["upd"]:
                    cell_latest[ck] = {"upd": upd, "verdict": (v or None),
                                       "phase": base, "status": st}

            if win_start <= upd < win_end and st in ("done", "failed"):
                rb = recent.setdefault(base, {"pass": 0, "fail": 0, "infra": 0,
                                              "other": 0, "total": 0})
                rb[fam] += 1
                rb["total"] += 1
                if fam == "pass":
                    mp = mover_pass.setdefault(ea_id, {"n": 0, "top_idx": -1, "top": None})
                    mp["n"] += 1
                    if bidx > mp["top_idx"]:
                        mp["top_idx"], mp["top"] = bidx, base

            if bidx >= q07_idx and st in _OPEN_STATUSES:
                ok = (ea_id, symbol or "", base)
                cur_o = open_map.get(ok)
                if cur_o is None or upd > cur_o["upd"]:
                    open_map[ok] = {"ea_id": ea_id, "symbol": symbol or "",
                                    "phase": base, "status": st, "upd": upd}

            if fam == "pass" and bidx >= q07_idx and (_BOOK_DATE <= upd < win_end):
                pk = (ea_id, symbol or "", base)
                cur_p = pass_map.get(pk)
                if cur_p is None or upd > cur_p["upd"]:
                    pass_map[pk] = {"ea_id": ea_id, "symbol": symbol or "",
                                    "phase": base, "verdict": v, "upd": upd}

    out["ea"] = ea_agg
    out["cell_latest"] = cell_latest
    out["recent"] = recent
    out["movers"] = sorted(
        ({"ea_id": k, "n": m["n"], "top": m["top"]} for k, m in mover_pass.items()),
        key=lambda r: (-r["n"], r["ea_id"]))
    out["frontier_open"] = sorted(
        open_map.values(), key=lambda r: (-(PHASE_ORDER.index(r["phase"])
                                            if r["phase"] in PHASE_ORDER else -1), r["upd"]),
        reverse=False)
    out["frontier_open"].sort(key=lambda r: r["upd"], reverse=True)
    out["frontier_passes"] = sorted(pass_map.values(), key=lambda r: r["upd"], reverse=True)
    return out


def _idx_status(ea_id: str, a: dict, live_ids: set[str]) -> tuple[str, str, str]:
    """(label, status-chip css, filter-class) for one archive-index row."""
    if ea_id in live_ids:
        return "LIVE", "s-live", "live"
    hp = a.get("hp")
    if hp and hp in PHASE_ORDER and PHASE_ORDER.index(hp) >= PHASE_ORDER.index(_FRONTIER_MIN):
        return "SURVIVOR", "s-live", "survivor"
    lv = (a.get("last_verdict") or "").upper()
    if a.get("n_pass", 0) > 0 and lv.startswith("PASS"):
        return "PASS", "s-flow", "pass"
    if a.get("n_pass", 0) > 0:
        return "IN VALIDATION", "s-flow", "validation"
    if lv.startswith("FAIL") or lv == "INFRA_FAIL":
        return "FAILED", "s-dead", "failed"
    return "—", "s-card", "other"


ARCHIVE_V2_CSS = """
.arch2-top{max-width:1400px;margin:0 auto;padding:34px 36px 20px;display:flex;align-items:flex-end;justify-content:space-between;gap:24px;flex-wrap:wrap;border-bottom:1px solid var(--border)}
.arch2-top h1{font-size:clamp(24px,3.4vw,36px);font-weight:600;letter-spacing:-0.03em;line-height:1.05;margin:0 0 8px}
.arch2-top h1 .em-text{color:var(--signal)}
.arch2-sub{font-family:var(--font-mono);font-size:11.5px;color:var(--text-3);line-height:1.6;letter-spacing:0.03em;max-width:720px}
.arch2-chips{display:flex;gap:10px;flex-wrap:wrap;max-width:1400px;margin:16px auto 0;padding:0 36px}
.a2chip{padding:11px 16px;background:var(--surface-1);border:1px solid var(--border);min-width:96px;text-align:center}
.a2chip-num{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:21px;font-weight:500;line-height:1;letter-spacing:-0.02em;color:var(--text)}
.a2chip-label{font-family:var(--font-mono);font-size:9px;font-weight:600;color:var(--text-3);margin-top:6px;text-transform:uppercase;letter-spacing:0.16em}
.a2chip.c-live .a2chip-num{color:var(--live)}
.a2chip.c-surv .a2chip-num{color:var(--live)}
.a2chip.c-fail .a2chip-num{color:var(--fail)}
.arch2-sec{max-width:1400px;margin:34px auto 0;padding:0 36px}
.sec-head{display:flex;align-items:baseline;gap:14px;flex-wrap:wrap;margin-bottom:14px;border-bottom:1px solid var(--border);padding-bottom:10px}
.sec-kicker{font-family:var(--font-mono);font-size:9px;font-weight:700;letter-spacing:0.24em;text-transform:uppercase;color:var(--bg);background:var(--signal);padding:4px 10px}
.sec-head h2{font-family:var(--font-mono);font-size:14px;font-weight:700;letter-spacing:0.02em;color:var(--text);margin:0}
.sec-meta{margin-left:auto;font-family:var(--font-mono);font-size:11px;color:var(--text-3);letter-spacing:0.04em}
.sec-meta strong{color:var(--signal);font-weight:700}
.jrnl-link{color:inherit;text-decoration:none;border-bottom:1px dashed var(--border-3)}
.jrnl-link:hover{color:var(--signal);border-bottom-color:var(--signal)}
.sec-note{font-family:var(--font-mono);font-size:10.5px;color:var(--text-4);line-height:1.55;letter-spacing:0.03em;margin:0 0 12px}
.lb-slot{color:var(--text-4);font-variant-numeric:tabular-nums}
.wbar{display:inline-block;width:52px;height:6px;background:var(--surface-2);border:1px solid var(--border);vertical-align:middle;margin-right:8px}
.wbar-fill{display:block;height:100%;background:var(--signal)}
.v-infra{color:var(--warn);font-weight:600}
.v-other{color:var(--text-3)}
.rv-grid{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px}
.rv-cell{padding:10px 14px;background:var(--surface-1);border:1px solid var(--border);border-top:2px solid var(--signal);min-width:92px;text-align:center}
.rv-phase{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-2);letter-spacing:0.1em}
.rv-nums{font-family:var(--font-mono);font-size:16px;font-weight:500;margin:5px 0 3px;font-variant-numeric:tabular-nums}
.rv-nums .v-fail,.rv-nums .v-pass,.rv-nums .v-infra{font-weight:700}
.rv-tot{font-family:var(--font-mono);font-size:9px;color:var(--text-4);text-transform:uppercase;letter-spacing:0.1em}
.rv-legend{font-family:var(--font-mono);font-size:10px;color:var(--text-4);letter-spacing:0.04em;margin-bottom:10px}
.movers{display:flex;gap:8px;flex-wrap:wrap}
.mover{display:inline-flex;align-items:center;gap:8px;padding:7px 12px;background:var(--surface-1);border:1px solid var(--border-2);font-family:var(--font-mono);font-size:11px;text-decoration:none;color:var(--text-2)}
.mover:hover{border-color:var(--signal)}
.mover code{color:var(--text);font-weight:600}
.mover .mv-slug{color:var(--text-3)}
.mover .mv-n{color:var(--signal);font-weight:700}
.mover .mv-ph{color:var(--text-4)}
.arch2-empty{font-family:var(--font-mono);font-size:11px;color:var(--text-4);padding:12px 0;letter-spacing:0.04em}
.idx-controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:12px}
.idx-controls input[type=search],.idx-controls select{background:var(--surface-2);border:1px solid var(--border-2);padding:8px 12px;font-size:12px;color:var(--text);font-family:var(--font-mono);outline:none;min-width:170px}
.idx-controls input[type=search]:focus,.idx-controls select:focus{border-color:var(--signal)}
.idx-controls .row-count{margin-left:auto;font-family:var(--font-mono);font-size:11px;color:var(--text-3);letter-spacing:0.08em;text-transform:uppercase}
.idx-controls .row-count strong{color:var(--signal);font-weight:700}
.archive-table td.idx-link{color:var(--signal);text-align:center;font-weight:700}
.arch2-foot{margin:44px auto 56px;max-width:1400px;padding:0 36px;font-family:var(--font-mono);font-size:11px;color:var(--text-3);text-align:center;line-height:1.7;letter-spacing:0.05em}
"""


ARCHIVE_V2_JS = """<script>
(function(){
  var table=document.getElementById('idx-table');
  if(!table)return;
  var tbody=table.tBodies[0];
  var rows=Array.prototype.slice.call(tbody.rows);
  var fSearch=document.getElementById('idx-search');
  var fStatus=document.getElementById('idx-status');
  var rc=document.getElementById('idx-count');
  function apply(){
    var q=(fSearch.value||'').toLowerCase().trim();
    var f=fStatus.value;
    var vis=0;
    rows.forEach(function(r){
      var hide=false;
      if(q && (r.getAttribute('data-search')||'').indexOf(q)<0)hide=true;
      if(!hide && f){
        if(f==='haspass'){if(r.getAttribute('data-haspass')!=='1')hide=true;}
        else if(r.getAttribute('data-fclass')!==f)hide=true;
      }
      r.style.display=hide?'none':'';
      if(!hide)vis++;
    });
    if(rc)rc.textContent=vis;
  }
  if(fSearch)fSearch.addEventListener('input',apply);
  if(fStatus)fStatus.addEventListener('change',apply);
  var sortCol=null,sortDir=1;
  table.querySelectorAll('thead th[data-sc]').forEach(function(th){
    th.addEventListener('click',function(){
      var type=th.getAttribute('data-st')||'text';
      var idx=th.cellIndex;
      if(sortCol===idx)sortDir=-sortDir;else{sortCol=idx;sortDir=1;}
      table.querySelectorAll('thead th').forEach(function(t){t.classList.remove('sort-asc','sort-desc');});
      th.classList.add(sortDir===1?'sort-asc':'sort-desc');
      var sorted=rows.slice().sort(function(a,b){
        var ca=a.cells[idx],cb=b.cells[idx];
        if(type==='num'){
          var va=parseFloat(ca.getAttribute('data-sort')||'0')||0;
          var vb=parseFloat(cb.getAttribute('data-sort')||'0')||0;
          return (va-vb)*sortDir;
        }
        var sa=ca.textContent.trim().toLowerCase(),sb=cb.textContent.trim().toLowerCase();
        return (sa<sb?-1:sa>sb?1:0)*sortDir;
      });
      sorted.forEach(function(r){tbody.appendChild(r);});
    });
  });
})();
</script>"""


def render_strategies(state: dict, root: Path) -> str:
    slug_map = _build_slug_map(REPO_ROOT)
    data = collect_archive_v2(root, slug_map)
    ea_agg = data["ea"]
    cell_latest = data["cell_latest"]

    # ── LIVE BOOK — 24 deployed sleeves ──────────────────────────
    presets = _parse_live_presets(LIVE_PRESETS_DIR)
    manifest, mani_path = _load_book_manifest(root)
    wmap: dict[tuple, dict] = {}
    kpis_book: dict[str, Any] = {}
    if manifest:
        for s in manifest.get("sleeves", []):
            base = str(s.get("symbol", "")).replace(".DWX", "")
            wmap[(s.get("ea_id"), base)] = s
        kpis_book = manifest.get("kpis", {}) or {}

    def _book_cell(ea_str: str, full_sym: str) -> dict | None:
        """Latest verdict for a book sleeve: exact (ea, symbol) first, then fall
        back to the EA's overall latest (basket EAs store a logical symbol, not
        the display symbol, so an exact match legitimately misses)."""
        cl = cell_latest.get((ea_str, full_sym))
        if cl:
            return cl
        a = ea_agg.get(ea_str)
        if a and a.get("last_verdict"):
            return {"verdict": a["last_verdict"], "phase": a.get("adv") or a.get("hp") or "",
                    "status": "", "ea_level": True}
        return None

    book_rows: list[dict] = []
    live_ids: set[str] = set()
    if presets:
        for p in presets:
            s = wmap.get((p["ea_id"], p["symbol"])) or {}
            ea_str = f"QM5_{p['ea_id']}"
            live_ids.add(ea_str)
            full_sym = s.get("symbol") or (p["symbol"] + ".DWX")
            book_rows.append({
                "slot": p["slot"], "ea": ea_str,
                "slug": p["slug"] or slug_map.get(ea_str, ""),
                "symbol": p["symbol"], "tf": p["tf"],
                "weight": s.get("weight"), "trades": s.get("trades"),
                "cl": _book_cell(ea_str, full_sym),
            })
    elif manifest:  # fallback if T_Live presets unreadable
        for s in manifest.get("sleeves", []):
            base = str(s.get("symbol", "")).replace(".DWX", "")
            ea_str = f"QM5_{s.get('ea_id')}"
            live_ids.add(ea_str)
            book_rows.append({
                "slot": "", "ea": ea_str, "slug": slug_map.get(ea_str, ""),
                "symbol": base, "tf": "", "weight": s.get("weight"),
                "trades": s.get("trades"),
                "cl": _book_cell(ea_str, s.get("symbol") or (base + ".DWX")),
            })

    maxw = max((r["weight"] or 0.0) for r in book_rows) if book_rows else 1.0
    maxw = maxw or 1.0
    lb_rows_html = ""
    for r in book_rows:
        cl = r["cl"]
        ea_note = (' <span class="v-other" style="font-size:9px" title="EA-level latest '
                   '(no per-symbol work item — basket/logical symbol)">ea</span>'
                   ) if (cl and cl.get("ea_level")) else ''
        if cl and cl.get("verdict"):
            vf = _verdict_family(cl["verdict"])
            phase_txt = f'{e(phase_label(cl["phase"]))} · ' if cl.get("phase") else ''
            vhtml = (f'<span class="{_VCLS[vf]}">{phase_txt}'
                     f'{e(qxx_text(cl["verdict"]))}</span>{ea_note}')
        elif cl and cl.get("status") in _OPEN_STATUSES:
            vhtml = (f'<span class="v-pending">{e(phase_label(cl["phase"]))} · '
                     f'{e(cl["status"])}</span>')
        else:
            vhtml = '<span class="v-pending">— no work item —</span>'
        wpct = (r["weight"] / maxw * 100) if r["weight"] else 0
        lb_rows_html += (
            f'<tr onclick="window.location=\'ea_{e(r["ea"])}.html\'">'
            f'<td class="lb-slot">{e(r["slot"])}</td>'
            f'<td class="td-ea"><code>{e(r["ea"])}</code></td>'
            f'<td class="td-slug">{e(r["slug"])}</td>'
            f'<td>{e(r["symbol"])}</td>'
            f'<td>{e(r["tf"])}</td>'
            f'<td class="col-num"><span class="wbar"><span class="wbar-fill" style="width:{wpct:.0f}%"></span></span>{fmt_num(r["weight"], 3)}</td>'
            f'<td>{vhtml}</td>'
            f'<td class="col-num">{r["trades"] if r["trades"] else "—"}</td>'
            f'</tr>'
        )
    if not lb_rows_html:
        lb_rows_html = '<tr><td colspan="8" class="arch2-empty">Live-book source unavailable.</td></tr>'

    book_meta = ""
    if kpis_book or manifest:
        sharpe = kpis_book.get("sharpe")
        dd = kpis_book.get("max_drawdown_pct")
        risk = (manifest or {}).get("total_risk_pct")
        net = kpis_book.get("total_net_of_cost_profit")
        # DXZ equity value links to the (forthcoming) journal page per OWNER.
        equity_html = (f'<a class="jrnl-link" href="dxz_journal.html">Net-of-cost '
                       f'<strong>{fmt_dollar(net)}</strong></a> · ') if isinstance(net, (int, float)) else ''
        book_meta = (f'{equity_html}Sharpe <strong>{fmt_num(sharpe, 3)}</strong> · MaxDD '
                     f'<strong>{fmt_pct(dd)}</strong> · risk {fmt_num(risk, 2)} · '
                     f'{len(book_rows)} sleeves (sealed basis)')

    # ── FRONTIER — open Q07–Q10 + passes since the book ──────────
    fo_html = ""
    for r in data["frontier_open"]:
        ea = r["ea_id"]
        fo_html += (
            f'<tr onclick="window.location=\'ea_{e(ea)}.html\'">'
            f'<td class="td-ea"><code>{e(ea)}</code></td>'
            f'<td class="td-slug">{e(slug_map.get(ea, ""))}</td>'
            f'<td>{e(r["symbol"])}</td>'
            f'<td>{e(phase_label(r["phase"]))}</td>'
            f'<td><span class="v-pending">{e(r["status"])}</span></td>'
            f'<td>{e((r["upd"] or "")[:19].replace("T", " "))}</td>'
            f'</tr>'
        )
    if not fo_html:
        fo_html = '<tr><td colspan="6" class="arch2-empty">No open Q07–Q10 work items.</td></tr>'

    fp_html = ""
    for r in data["frontier_passes"]:
        ea = r["ea_id"]
        fp_html += (
            f'<tr onclick="window.location=\'ea_{e(ea)}.html\'">'
            f'<td class="td-ea"><code>{e(ea)}</code></td>'
            f'<td class="td-slug">{e(slug_map.get(ea, ""))}</td>'
            f'<td>{e(r["symbol"])}</td>'
            f'<td>{e(phase_label(r["phase"]))}</td>'
            f'<td><span class="v-pass">{e(qxx_text(r["verdict"]))}</span></td>'
            f'<td>{e((r["upd"] or "")[:19].replace("T", " "))}</td>'
            f'</tr>'
        )
    if not fp_html:
        fp_html = (f'<tr><td colspan="6" class="arch2-empty">No Q07+ passes since '
                   f'{e(data["book_date"])}.</td></tr>')

    # ── RECENT VERDICTS — last 7 days by phase + top movers ──────
    recent = data["recent"]
    rv_cells = ""
    rv_tot = {"pass": 0, "fail": 0, "infra": 0, "total": 0}
    for base in PHASE_ORDER:
        rb = recent.get(base)
        if not rb:
            continue
        rv_tot["pass"] += rb["pass"]
        rv_tot["fail"] += rb["fail"]
        rv_tot["infra"] += rb["infra"]
        rv_tot["total"] += rb["total"]
        rv_cells += (
            f'<div class="rv-cell"><div class="rv-phase">{e(phase_label(base))}</div>'
            f'<div class="rv-nums"><span class="v-pass">{rb["pass"]}</span>/'
            f'<span class="v-fail">{rb["fail"]}</span>/'
            f'<span class="v-infra">{rb["infra"]}</span></div>'
            f'<div class="rv-tot">{rb["total"]} runs</div></div>'
        )
    if not rv_cells:
        rv_cells = '<div class="arch2-empty">No graded work items in the last 7 days.</div>'

    movers_html = ""
    for m in data["movers"][:8]:
        ea = m["ea_id"]
        movers_html += (
            f'<a class="mover" href="ea_{e(ea)}.html"><code>{e(ea)}</code>'
            f'<span class="mv-slug">{e(slug_map.get(ea, ""))}</span>'
            f'<span class="mv-n">+{m["n"]}</span>'
            f'<span class="mv-ph">{e(phase_label(m["top"]))}</span></a>'
        )
    if not movers_html:
        movers_html = '<div class="arch2-empty">No PASS verdicts in the last 7 days.</div>'

    # ── ARCHIVE INDEX — every pipeline EA, one compact table ─────
    n_total = len(ea_agg)
    n_surv = n_fail = n_pass = 0
    ea_sorted = sorted(ea_agg.items(), key=lambda kv: kv[1]["last_upd"], reverse=True)
    idx_rows = ""
    for ea_id, a in ea_sorted:
        slug = slug_map.get(ea_id, "")
        label, scls, fcls = _idx_status(ea_id, a, live_ids)
        if fcls == "survivor":
            n_surv += 1
        elif fcls == "failed":
            n_fail += 1
        if a.get("n_pass", 0) > 0:
            n_pass += 1
        hp = a.get("hp")
        best = phase_label(hp) if hp else "—"
        lv = a.get("last_verdict") or ""
        lvcls = _VCLS.get(_verdict_family(lv), "v-other")
        lv_disp = qxx_text(lv) if lv else "—"
        upd = a.get("last_upd") or ""
        upd_disp = upd[:19].replace("T", " ") if upd else "—"
        try:
            ep = int(dt.datetime.fromisoformat(upd.replace("Z", "+00:00")).timestamp()) if upd else 0
        except Exception:
            ep = 0
        haspass = "1" if a.get("n_pass", 0) > 0 else "0"
        idx_rows += (
            f'<tr data-fclass="{fcls}" data-haspass="{haspass}" '
            f'data-search="{e((ea_id + " " + slug).lower())}" '
            f'onclick="window.location=\'ea_{e(ea_id)}.html\'">'
            f'<td class="td-ea"><code>{e(ea_id)}</code></td>'
            f'<td class="td-slug">{e(slug)}</td>'
            f'<td><span class="status-chip {scls}">{e(label)}</span></td>'
            f'<td>{e(best)}</td>'
            f'<td><span class="{lvcls}">{e(lv_disp)}</span></td>'
            f'<td data-sort="{ep}">{e(upd_disp)}</td>'
            f'<td class="idx-link">&rarr;</td>'
            f'</tr>'
        )

    badge = render_badge_html()
    css = ARCHIVE_CSS + ARCHIVE2_CSS + ARCHIVE_V2_CSS

    content = f"""
<div class="arch2-top">
  <div>
    <h1>Strategy <span class="em-text">Archive</span> · Operator</h1>
    <div class="arch2-sub">Live book, qualification frontier, recent verdicts, and the full EA archive — regenerated hourly from the pipeline database. Every number is parsed from native MetaTrader 5 reports; failed strategies stay published.</div>
  </div>
  {badge}
</div>

<div class="arch2-chips">
  <div class="a2chip c-live"><div class="a2chip-num">{len(book_rows)}</div><div class="a2chip-label">Live sleeves</div></div>
  <div class="a2chip"><div class="a2chip-num">{n_total}</div><div class="a2chip-label">EAs in archive</div></div>
  <div class="a2chip c-surv"><div class="a2chip-num">{n_surv}</div><div class="a2chip-label">Q07+ survivors</div></div>
  <div class="a2chip"><div class="a2chip-num">{n_pass}</div><div class="a2chip-label">With a PASS</div></div>
  <div class="a2chip c-fail"><div class="a2chip-num">{n_fail}</div><div class="a2chip-label">Failed</div></div>
</div>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Live Book</span><h2><a class="jrnl-link" href="dxz_journal.html">DXZ · deployed sleeves</a></h2><span class="sec-meta">{book_meta}</span></div>
  <p class="sec-note">Composition + timeframe from the T_Live preset filenames (NN_Symbol_TF_EA); weights &amp; KPIs from the sealed sunday-final portfolio manifest. "Last verdict" is the most recent pipeline work item for that (EA, symbol).</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>#</th><th>EA</th><th>Slug</th><th>Symbol</th><th>TF</th><th class="col-num">Weight</th><th>Last verdict</th><th class="col-num">Trades (bt)</th></tr></thead>
    <tbody>{lb_rows_html}</tbody>
  </table>
  </div>
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Frontier</span><h2>Qualification frontier</h2><span class="sec-meta">Q07–Q10 open work &amp; passes since {e(data["book_date"])}</span></div>
  <p class="sec-note">Open (non-terminal) high-gate work items still in flight.</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>EA</th><th>Slug</th><th>Symbol</th><th>Phase</th><th>Status</th><th>Updated</th></tr></thead>
    <tbody>{fo_html}</tbody>
  </table>
  </div>
  <p class="sec-note" style="margin-top:16px">Q07+ PASS verdicts recorded since the last book ({e(data["book_date"])}).</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>EA</th><th>Slug</th><th>Symbol</th><th>Phase</th><th>Verdict</th><th>Updated</th></tr></thead>
    <tbody>{fp_html}</tbody>
  </table>
  </div>
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Recent</span><h2>Verdicts · last 7 days</h2><span class="sec-meta"><span class="v-pass">{rv_tot["pass"]}</span> pass / <span class="v-fail">{rv_tot["fail"]}</span> fail / <span class="v-infra">{rv_tot["infra"]}</span> infra · {rv_tot["total"]} graded</span></div>
  <div class="rv-legend">Each cell: <span class="v-pass">PASS</span> / <span class="v-fail">FAIL</span> / <span class="v-infra">INFRA</span> counts per gate (since {e(data["win_start"])}).</div>
  <div class="rv-grid">{rv_cells}</div>
  <p class="sec-note" style="margin-top:6px">Top movers — EAs with the most PASS verdicts this week (badge shows highest gate passed):</p>
  <div class="movers">{movers_html}</div>
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Archive</span><h2>Full EA index</h2><span class="sec-meta">{n_total} EAs · click any row for the full evidence trail</span></div>
  <div class="idx-controls">
    <input type="search" id="idx-search" placeholder="search ea id or slug…">
    <select id="idx-status">
      <option value="">All status</option>
      <option value="live">Live book</option>
      <option value="survivor">Q07+ survivors</option>
      <option value="haspass">Has a PASS</option>
      <option value="failed">Failed</option>
    </select>
    <span class="row-count"><strong id="idx-count">{n_total}</strong> of {n_total} EAs</span>
  </div>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table" id="idx-table">
    <thead><tr>
      <th data-sc="ea" data-st="text">EA</th>
      <th data-sc="slug" data-st="text">Slug</th>
      <th data-sc="status" data-st="text">Status</th>
      <th data-sc="best" data-st="text">Best gate</th>
      <th data-sc="verdict" data-st="text">Last verdict</th>
      <th data-sc="updated" data-st="num">Last activity</th>
      <th></th>
    </tr></thead>
    <tbody>{idx_rows}</tbody>
  </table>
  </div>
</section>

<div class="arch2-foot">
  QuantMechanica V5 · Strategy Archive v2 · regenerated hourly from the live pipeline database ·
  every metric parsed from native MetaTrader 5 backtest reports — no hand-edited results.
</div>
{ARCHIVE_V2_JS}
{RENDER_BADGE_JS}
</body>
</html>
"""
    return html_head("Strategy Archive", css) + content



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
            # Normalized metric layer (ea_metrics): the headline scalars and
            # phase-specific detail (folds/seeds/sub-gates) parsed ONCE from each
            # work_item's evidence file. work_items itself stores no numbers, and
            # payload.recovered_stats is empty for most rows — so without this the
            # per-row tables fall back to "no parsed evidence / $0.00 / —" even for
            # genuine survivors (e.g. QM5_10440: +$49,991 net / PF 1.22 / WF all PASS).
            metrics_by_wid: dict[str, dict[str, Any]] = {}
            try:
                metrics_by_wid = {
                    r["work_item_id"]: dict(r)
                    for r in conn.execute(
                        "SELECT * FROM ea_metrics WHERE ea_id = ?", (ea_id,)
                    )
                }
            except sqlite3.OperationalError:
                # ea_metrics not built yet — degrade to legacy recovered_stats path.
                metrics_by_wid = {}
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
            m = metrics_by_wid.get(w.get("id")) or {}
            attempts_by_key[key].append({
                "created_at": w.get("created_at") or w.get("updated_at"),
                "updated_at": w.get("updated_at"),
                "status": w.get("status"),
                "verdict": w.get("verdict"),
                "reason": str(reason) if reason else "",
                "net_profit": m.get("net_profit") if m.get("net_profit") is not None else rs.get("net_profit"),
                "trades": m.get("trades") if m.get("trades") is not None else rs.get("total_trades"),
                "drawdown": m.get("drawdown_money") if m.get("drawdown_money") is not None else (rs.get("max_dd") or rs.get("drawdown")),
                "is_ablation": bool(m.get("is_ablation")),
                "evidence": w.get("evidence_path"),
                "setfile": w.get("setfile_path"),
            })
        # Order each bucket chronologically (oldest → newest)
        for k in attempts_by_key:
            attempts_by_key[k].sort(key=lambda a: a.get("created_at") or "")

        # Headline row per (phase, symbol): pick the most REPRESENTATIVE attempt,
        # not merely the latest. The latest attempt is frequently an INFRA_FAIL
        # re-run or an ablation perturbation (net≈0) that hid genuine PASS numbers
        # (this is why QM5_10440/NDX Q02 showed $0 while a +$49,991 PASS run sat
        # one attempt back). Rank: non-ablation > has-graded-metrics > PASS-verdict
        # > net_profit. The full chronological history stays in the timeline below.
        def _headline_score(w: dict[str, Any]) -> tuple:
            mm = metrics_by_wid.get(w.get("id")) or {}
            net = mm.get("net_profit")
            pf = mm.get("profit_factor")
            graded = 1 if (net is not None or pf is not None) else 0
            nonabl = 0 if mm.get("is_ablation") else 1
            passish = 1 if (w.get("verdict") in ("PASS", "PASS_SOFT", "PASS_LOWFREQ", "MULTI_SEED_PASS")) else 0
            rankval = net if net is not None else (pf if pf is not None else float("-inf"))
            return (nonabl, graded, passish, rankval, w.get("updated_at") or "")

        best_by_key: dict[tuple[str, str], dict[str, Any]] = {}
        for w in rows:
            key = (w.get("phase") or "?", w.get("symbol") or "?")
            cur = best_by_key.get(key)
            if cur is None or _headline_score(w) > _headline_score(cur):
                best_by_key[key] = w

        items: list[dict[str, Any]] = []
        for key, w in best_by_key.items():
            try:
                payload = json.loads(w.get("payload_json") or "{}")
            except Exception:
                payload = {}
            rs = payload.get("recovered_stats") or {}
            m = metrics_by_wid.get(w.get("id")) or {}

            def _pick(metric_key: str, rs_val: Any) -> Any:
                """Prefer the normalized ea_metrics value; fall back to recovered_stats."""
                mv = m.get(metric_key)
                return mv if mv is not None else rs_val

            item = {
                "phase": w.get("phase") or "?",
                "symbol": w.get("symbol") or "?",
                "verdict": w.get("verdict"),
                "status": w.get("status"),
                "updated_at": w.get("updated_at"),
                "setfile": w.get("setfile_path"),
                "evidence": w.get("evidence_path"),
                "net_profit": _pick("net_profit", rs.get("net_profit")),
                "trades": _pick("trades", rs.get("total_trades")),
                "drawdown": _pick("drawdown_money", rs.get("max_dd") or rs.get("drawdown")),
                "drawdown_pct": m.get("drawdown_pct"),
                "profit_factor": _pick("profit_factor", rs.get("profit_factor")),
                "sharpe": m.get("sharpe"),
                "is_ablation": bool(m.get("is_ablation")),
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
            # Q04 walk-forward (current pipeline). Schema differs from legacy P4:
            # each fold has id / dev_* / oos_* / pf_net (net-of-commission OOS
            # profit factor) / trades. This is THE walk-forward view — a fold with
            # pf_net < 1 (or 0.0) is the EA failing out-of-sample, which is the
            # usual Q04 death. Normalise to the fold-table fields. (The old code
            # keyed on "P4", which never matches live Qxx rows → WF was invisible.)
            if w.get("phase") == "Q04":
                ev = w.get("evidence_path")
                if ev:
                    try:
                        ep = Path(ev)
                        if ep.exists() and ep.suffix == ".json":
                            ej = json.loads(ep.read_text(encoding="utf-8", errors="ignore"))
                            raw_folds = ej.get("folds") or []
                            norm = []
                            for f in raw_folds:
                                norm.append({
                                    "fold_id": f.get("id"),
                                    "dev_start": f.get("dev_start"),
                                    "dev_end": f.get("dev_end"),
                                    "oos_start": f.get("oos_start"),
                                    "oos_end": f.get("oos_end"),
                                    "oos_trades": f.get("trades"),
                                    "pf_net": f.get("pf_net"),
                                    "fold_status": f.get("status")
                                    or ("ok" if f.get("exit_code") == 0 else "fail"),
                                })
                            if norm:
                                item["folds"] = norm
                                item["fold_kind"] = "q04_wf"
                                item["fold_criterion"] = qxx_text(str(ej.get("reason") or ""))
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
                "n_infra": verdicts.count("INFRA_FAIL"),
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


# Q02/Q03 are "did it run + enough trades" gates — a PASS there means the EA
# executed, NOT that it has an edge. Q04+ are the robustness gates where a PASS is
# a real (cost-aware, walk-forward / stress / crisis) survival signal. The swim-lane
# colours these differently so a smoke-pass is never mistaken for an edge-pass.
SMOKE_GATES = {"Q02", "Q03"}

SWIMLANE_CSS = """
.swimlane-wrap{margin:20px 0 6px}
.swimlane-title{font-family:var(--font-mono);font-size:11px;font-weight:700;color:var(--text-3);letter-spacing:0.18em;text-transform:uppercase;margin:0 0 12px}
.swimlane{border-collapse:separate;border-spacing:3px;width:100%;table-layout:fixed}
.swimlane th{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-3);letter-spacing:0.05em;padding:2px 0;text-align:center}
.swimlane th.sym-h{text-align:left;width:128px;letter-spacing:0.1em}
.swimlane td.sym{font-family:var(--font-mono);font-size:12px;color:var(--text);font-weight:600;white-space:nowrap;padding-right:10px}
.sl-cell{height:30px;text-align:center;font-family:var(--font-mono);font-size:13px;font-weight:700;border:1px solid var(--border);line-height:30px;cursor:default}
.sl-edge{background:rgba(26,143,76,0.14);color:var(--pass);border-color:rgba(26,143,76,0.45)}
.sl-smoke{background:rgba(114,107,96,0.12);color:var(--text-2);border-color:var(--border-2)}
.sl-loss{background:rgba(184,114,10,0.12);color:var(--warn);border-color:rgba(184,114,10,0.40)}
.sl-fail{background:rgba(209,52,56,0.12);color:var(--fail);border-color:rgba(209,52,56,0.45)}
.sl-infra{background:rgba(184,114,10,0.08);color:var(--warn);border-color:rgba(184,114,10,0.32)}
.sl-regress{background:rgba(114,107,96,0.08);color:var(--text-3);border-style:dashed}
.sl-none{background:transparent;border-color:transparent}
.sl-legend{display:flex;gap:16px;flex-wrap:wrap;margin-top:12px;font-family:var(--font-mono);font-size:10px;color:var(--text-3);letter-spacing:0.04em}
.sl-legend span{display:inline-flex;align-items:center;gap:6px}
.sl-sw{width:12px;height:12px;display:inline-block;border:1px solid var(--border-2)}
"""


def _render_symbol_swimlane(detail: dict) -> str:
    """One row per symbol across all gates Q0x — the per-symbol funnel made
    legible: you see at a glance where each symbol died (loser at Q02, OOS-fail
    at Q04, infra at Q08, …) and smoke-pass vs edge-pass are visually distinct."""
    items = detail.get("work_items") or []
    symbols = sorted({i["symbol"] for i in items if i.get("symbol") and i["symbol"] != "?"})
    present_idx = sorted({PHASE_ORDER.index(i["phase"]) for i in items if i.get("phase") in PHASE_ORDER})
    if not symbols or not present_idx:
        return ""
    cell = {(i["phase"], i["symbol"]): i for i in items}
    gates = [PHASE_ORDER[x] for x in range(present_idx[0], present_idx[-1] + 1)]
    head = "".join(f'<th>{e(phase_label(g))}</th>' for g in gates)

    rows = []
    for sym in symbols:
        # Trajectory model: the furthest gate this symbol reached is its frontier.
        # Gates BEFORE the frontier that it ever-passed are shown as passed (the
        # symbol provably advanced past them — a later infra re-run there is just
        # noise). The frontier gate shows the real current state (pass/fail/infra).
        reached = [PHASE_ORDER.index(g) for g in gates if (g, sym) in cell]
        frontier = max(reached) if reached else -1
        tds = []
        for g in gates:
            it = cell.get((g, sym))
            if not it:
                tds.append('<td class="sl-cell sl-none"></td>')
                continue
            gi = PHASE_ORDER.index(g)
            is_frontier = (gi == frontier)
            verd = it.get("verdict") or ""
            ever = it.get("n_ever_pass") or 0
            np_ = it.get("net_profit")
            pf = it.get("profit_factor")
            title = f'{phase_label(g)} {sym}: {verd or "—"}'
            if verd not in ("INFRA_FAIL", "INVALID"):
                if isinstance(pf, (int, float)):
                    title += f' · PF {pf:.2f}'
                if isinstance(np_, (int, float)):
                    title += f' · net {fmt_dollar(np_)}'
            if verd == "PASS" or (ever and not is_frontier):
                # passed this gate (current PASS, or provably advanced past it)
                if g in SMOKE_GATES:
                    if verd == "PASS" and isinstance(np_, (int, float)) and np_ <= 0:
                        cls, glyph = "sl-loss", "≈"
                        title += " · ran but not profitable"
                    else:
                        cls, glyph = "sl-smoke", "✓"
                        title += " · smoke pass (ran)"
                else:
                    cls, glyph = "sl-edge", "✓"
                    title += " · edge pass"
                if verd != "PASS":
                    title += " (later re-run noisy; symbol advanced)"
            elif ever:  # frontier gate, ever-passed but latest re-run FAIL/infra
                cls, glyph = "sl-regress", "↺"
                title += f" · {ever} earlier PASS, latest re-run not clean"
            elif verd == "FAIL":
                cls, glyph = "sl-fail", "✗"
            elif verd in ("INFRA_FAIL", "INVALID"):
                cls, glyph = "sl-infra", "⚠"
                title += " · infra / no evidence"
            elif verd == "COMPLETED":
                cls, glyph = "sl-edge", "✓"
            else:
                cls, glyph = "sl-smoke", "·"
            tds.append(f'<td class="sl-cell {cls}" title="{e(title)}">{glyph}</td>')
        rows.append(f'<tr><td class="sym">{e(sym)}</td>{"".join(tds)}</tr>')

    legend = (
        '<div class="sl-legend">'
        '<span><i class="sl-sw sl-edge"></i> edge pass (Q04+ robust)</span>'
        '<span><i class="sl-sw sl-smoke"></i> smoke pass (ran)</span>'
        '<span><i class="sl-sw sl-loss"></i> ran, not profitable</span>'
        '<span><i class="sl-sw sl-fail"></i> fail</span>'
        '<span><i class="sl-sw sl-infra"></i> infra / no evidence</span>'
        '<span><i class="sl-sw sl-regress"></i> passed then regressed</span>'
        '</div>'
    )
    return (
        '<div class="swimlane-wrap">'
        '<div class="swimlane-title">Per-symbol funnel · where each symbol stands at each gate</div>'
        f'<table class="swimlane"><thead><tr><th class="sym-h">Symbol</th>{head}</tr></thead>'
        f'<tbody>{"".join(rows)}</tbody></table>{legend}</div>'
    )


def render_ea_detail(ea: dict, detail: dict, state: dict) -> str:
    ea_id = detail["ea_id"]
    slug = detail.get("slug", ea_id)
    label, status_cls = _ea_status(ea)

    work_items = detail.get("work_items", [])
    items_by_phase: dict[str, list[dict]] = defaultdict(list)
    for w in work_items:
        items_by_phase[w["phase"]].append(w)
    present_phases = [p for p in PHASE_ORDER if p in items_by_phase]
    # A phase counts as "passed" if ANY symbol ever passed it — not just if the
    # LATEST re-run is PASS. Otherwise the header ("Highest real PASS Q06")
    # contradicts the expandable tables, which show "ever PASS 5/7" at Q07 where
    # a later re-run happened to FAIL. ever-pass is the same signal the cascade
    # used to promote the EA forward, so it is the honest "how far did it get".
    pass_phases = [p for p in present_phases
                   if any(x.get("verdict") == "PASS" or (x.get("n_ever_pass") or 0) > 0
                          for x in items_by_phase[p])]
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
            ("r1_track_record", "R1 Source (info)"),
            ("r2_mechanical", "R2 Mechanical"),
            ("r3_data_available", "R3 Data"),
            ("r4_ml_forbidden", "R4 No-ML"),
        ):
            v = fm.get(key, "UNKNOWN")
            # OWNER 2026-07-23: R1 reputation is informational. A durable
            # source_id means even legacy UNKNOWN/FAIL labels are non-blocking
            # and must not be rendered as a red gate failure.
            r1_lineaged = key == "r1_track_record" and bool(str(fm.get("source_id") or "").strip())
            cls = "" if r1_lineaged else (
                "r-unknown" if v == "UNKNOWN" else ("r-fail" if "FAIL" in str(v) else "")
            )
            r_tags_html.append(f'<span class="r-tag {cls}"><strong>{e(label_short)}</strong> {e(v)}</span>')
        reasoning = fm.get("g0_approval_reasoning", "")
        # Concept / indicator chips from card frontmatter wiki-links — the
        # fastest external answer to "what kind of strategy is this?"
        def _wikilink_names(values) -> list[str]:
            names = []
            for v in values or []:
                m = re.search(r"\[\[(?:[^\]/]*/)?([^\]]+)\]\]", str(v))
                names.append((m.group(1) if m else str(v)).strip())
            return [n for n in names if n]
        concept_chips = _wikilink_names(fm.get("concepts")) + _wikilink_names(fm.get("indicators"))
        chips_html = ""
        if concept_chips:
            chips_html = ('<div class="concept-chips">'
                          + "".join(f'<span class="concept-chip">{e(c)}</span>' for c in concept_chips[:10])
                          + '</div>')
        facts = [
            ("Strategy family", slug),
            ("Intake review (Q00)", fm.get("g0_status", "—")),
            ("Expected trades/yr/symbol", fm.get("expected_trades_per_year_per_symbol", "—")),
            ("Markets tested", ", ".join(detail.get("symbols") or []) or "—"),
        ]
        facts_rows = "".join(f"<tr><td>{e(k)}</td><td>{e(v)}</td></tr>" for k, v in facts)
        # External page: cite the human-readable source, never filesystem paths.
        citation = fm.get("source_citation")
        if citation:
            src_html = f'<div class="src-attrib"><strong>Source:</strong> {e(citation)}</div>'
        elif fm.get("sources") or fm.get("source_id"):
            _src = fm.get("sources") or fm.get("source_id")
            _src_txt = ", ".join(_wikilink_names(_src)) if isinstance(_src, list) else str(_src)
            src_html = f'<div class="src-attrib"><strong>Source:</strong> {e(_src_txt)}</div>'
        else:
            src_html = '<div class="src-attrib"><strong>Source:</strong> internal research (no external source).</div>'
        para_html = "".join(f"<p>{e(p)}</p>" for p in paras) or \
            "<p><em>No prose description in the strategy card.</em></p>"
        desc_html = f"""
<div class="detail-desc">
  <div class="detail-desc-title">What this strategy does</div>
  <div class="detail-desc-body">
    {chips_html}
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

    # KPI tiles — use the most-advanced phase WITH GRADED EVIDENCE. A phase whose
    # rows are all pending/INFRA renders a wall of "—" tiles (observed on
    # QM5_10692: Q08 present but ungraded buried the rich Q02-Q07 evidence).
    kpis_by_phase = detail.get("kpis_by_phase") or {}

    def _has_graded_evidence(k: dict) -> bool:
        if (k.get("n_pass") or 0) + (k.get("n_fail") or 0) > 0:
            return True
        return isinstance(k.get("net_profit_best"), (int, float))

    advanced = None
    for ph in reversed(PHASE_ORDER):
        if ph in kpis_by_phase and _has_graded_evidence(kpis_by_phase[ph]):
            advanced = ph
            break
    if advanced is None:
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
    <div class="kpi-tile-label">Evidence stage</div>
    <div class="kpi-tile-val">{e(phase_label(advanced))}</div>
    <div class="kpi-tile-sub">{k['n_pass']} PASS · {k['n_fail']} FAIL · {k.get('n_invalid', 0)} INVALID{f" · {k['n_infra']} infra re-runs" if k.get('n_infra') else ""} · highest gate with graded results</div>
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
        # ever-pass at phase level: a phase header saying "no PASS" while the
        # expandable rows show "ever PASS 7/52" (a later re-run FAILed) reads as a
        # contradiction. Surface the historical passes that actually cascaded.
        n_ever_pass_phase = sum(x.get("n_ever_pass") or 0 for x in items)
        ever_note = ""
        if not n_pass and n_ever_pass_phase:
            ever_note = (f' <span style="color:var(--text-3)">'
                         f'({n_ever_pass_phase} ever-passed → cascaded; latest re-run FAIL)</span>')
        if nets:
            kpi_html = (f'best net <strong>{e(fmt_dollar(max(nets)))}</strong>'
                        f'{pass_qualifier}')
        elif n_pass:
            kpi_html = f'<strong>{n_pass} PASS</strong>{pass_qualifier}'
        elif n_ever_pass_phase:
            kpi_html = f'<strong>no current PASS</strong>{ever_note}'
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
            # Numeric-cell convention (REVISED 2026-06-07, OWNER): missing data
            # must read as "no evidence" (—), NOT as a real 0. The prior
            # $0.00/0/0.00 convention made an infra-fail or unparsed-report row
            # look like a genuine zero-trade result — e.g. "PASS · 0 trades ·
            # PF 0.00", which is nonsense and exactly what confused the operator.
            # A number is shown ONLY when it actually exists; otherwise "—".
            NODATA = '<span class="net-nodata" title="no parsed evidence for this run">—</span>'
            # A failed / invalid run's parsed numbers are not trustworthy: the
            # German-locale + infra failures wrote total_trades=0 / net=0 into the
            # summary because the *parse* failed, not because the EA traded zero.
            # Showing those 0s next to a verdict produced "PASS · 0 trades · PF 0"
            # nonsense. Gate every metric on the verdict: only a real graded run
            # (not INFRA_FAIL / INVALID) may show numbers; otherwise "—".
            metrics_ok = verd not in ("INFRA_FAIL", "INVALID", "—") and w.get("status") != "failed"
            np_ = w.get("net_profit")
            if metrics_ok and isinstance(np_, (int, float)):
                np_html = f'<span class="{"net-pos" if np_ > 0 else "net-neg"}">{fmt_dollar(np_)}</span>'
            else:
                np_html = NODATA
            tr_html = str(int(w["trades"])) if metrics_ok and isinstance(w.get("trades"), (int, float)) else NODATA
            dd_html = fmt_dollar(w.get("drawdown")) if metrics_ok and isinstance(w.get("drawdown"), (int, float)) else NODATA
            pf_v = w.get("profit_factor")
            pf_html = f"{pf_v:.2f}" if metrics_ok and isinstance(pf_v, (int, float)) else NODATA
            sh_v = w.get("sharpe")
            sh_html = f"{sh_v:.2f}" if metrics_ok and isinstance(sh_v, (int, float)) else NODATA
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
                    ever_chip = (f'<span style="color:var(--pass);margin-left:6px">'
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
                if folds_for_row and w.get("fold_kind") == "q04_wf":
                    # Q04 walk-forward: per-fold out-of-sample PROFIT FACTOR (net of
                    # commission). PF_net < 1.0 = the EA loses money out-of-sample
                    # in that fold → the gate fails. This is the answer to "how does
                    # walk-forward show": one row per OOS window, pass/fail by PF.
                    fold_rows = []
                    for f in folds_for_row:
                        fid = f.get("fold_id") or "?"
                        dev = f"{(f.get('dev_start') or '?')[:10]} → {(f.get('dev_end') or '?')[:10]}"
                        oos = f"{(f.get('oos_start') or '?')[:10]} → {(f.get('oos_end') or '?')[:10]}"
                        pf = f.get("pf_net")
                        if isinstance(pf, (int, float)):
                            pf_cls = "net-pos" if pf >= 1.0 else "net-neg"
                            pf_html = f'<span class="{pf_cls}">{pf:.2f}</span>'
                        else:
                            pf_html = '<span class="net-nodata">—</span>'
                        trd = f.get("oos_trades")
                        trd_html = str(int(trd)) if isinstance(trd, (int, float)) else '<span class="net-nodata">—</span>'
                        ok = isinstance(pf, (int, float)) and pf >= 1.0
                        ok_html = (f'<span class="clean-yes">✓</span>' if ok
                                   else f'<span class="clean-no">✗</span>')
                        fold_rows.append(
                            f'<tr><td class="fold-id">{e(fid)}</td>'
                            f'<td>{e(dev)}</td>'
                            f'<td>{e(oos)}</td>'
                            f'<td class="col-num">{trd_html}</td>'
                            f'<td class="col-num">{pf_html}</td>'
                            f'<td>{ok_html}</td></tr>'
                        )
                    crit = w.get("fold_criterion") or ""
                    crit_html = (f'<div class="fold-criterion">{e(crit)}</div>'
                                 if crit else "")
                    fold_block_html = (
                        f'<div class="fold-block">'
                        f'<div class="att-title">Walk-forward · {e(w["symbol"])} · {len(folds_for_row)} OOS folds '
                        f'(PF net-of-commission; ✓ = PF ≥ 1.0)</div>'
                        f'{crit_html}'
                        f'<table class="fold-table"><thead><tr>'
                        f'<th>Fold</th><th>DEV window</th><th>OOS window</th>'
                        f'<th class="col-num">OOS Trades</th>'
                        f'<th class="col-num">OOS PF (net)</th>'
                        f'<th>Pass</th>'
                        f'</tr></thead><tbody>{"".join(fold_rows)}</tbody></table>'
                        f'</div>'
                    )
                elif folds_for_row:
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
    # Availability strip — the archive's external promise (OWNER 2026-06-11:
    # visitors should profit from the research and later download/license the
    # EAs). Honest by construction: nothing is offered before Q14.
    pc_states = {str(r.get("candidate_state") or "") for r in (detail.get("q08_portfolio_rescue") or [])}
    if ea.get("live"):
        avail_cls, avail_label = "av-live", "LIVE — trading on our own account"
        avail_body = ("This strategy survived the full evidence pipeline and is trading live. "
                      "Licensing/download options are planned for validated strategies.")
    elif ea.get("dead"):
        fa = ea.get("failed_at")
        avail_cls, avail_label = "av-failed", "NOT AVAILABLE — failed validation"
        avail_body = (f"This strategy did not survive the evidence gates"
                      f"{f' (failed at {phase_label(fa)})' if fa else ''}. "
                      "We publish failures so you can see what does NOT work — that is the point of the archive.")
    elif "first_sleeve" in pc_states or any("Q12" in s for s in pc_states):
        avail_cls, avail_label = "av-cand", "PORTFOLIO CANDIDATE — final review"
        avail_body = ("This strategy passed portfolio admission and is in final human review (Q12-Q14). "
                      "If it goes live, licensing/download options will appear here.")
    else:
        avail_cls, avail_label = "av-flow", "IN VALIDATION — not yet available"
        avail_body = ("Still inside the 15-gate evidence pipeline (Q00-Q14: walk-forward, Monte-Carlo, "
                      "stress, cost-cushion, portfolio fit). Strategies that survive every gate "
                      "become available for download/licensing here.")
    availability_html = (
        f'<div class="availability {avail_cls}"><span class="av-label">{e(avail_label)}</span>'
        f'<span class="av-body">{e(avail_body)}</span></div>'
    )

    swimlane_html = _render_symbol_swimlane(detail)
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
  <div class="rescue-detail-title">Portfolio admission · Q08 standalone &rarr; Q09 portfolio</div>
  <div class="rescue-detail-note">A strategy that narrowly fails standalone admission (Q08) can still earn a
  portfolio slot (Q09) if it is weakly correlated to the existing book and improves portfolio Sharpe/drawdown —
  diversification is the win mechanism.</div>
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
    return html_head(f"{ea_id} · {slug}", ARCHIVE_CSS + EA_DETAIL_CSS + DETAIL2_CSS + SWIMLANE_CSS) + f"""
<div class="detail-wrap">
  <a class="detail-back" href="strategies.html">← back to Strategy Archive</a>
  <div class="detail-head">
    <h1><code>{e(ea_id)}</code><span class="detail-slug">{e(slug)}</span></h1>
    <span class="detail-status {status_cls}">{label}</span>
  </div>
  <div class="detail-meta">
    <span>Current <strong>{e(phase_label(cur_phase) if cur_phase != '—' else '—')}</strong></span>
    <span>Done <strong>{e(', '.join(sorted({phase_label(p) for p in (ea.get('completed_phases') or [])}, key=lambda q: PHASE_ORDER.index(q) if q in PHASE_ORDER else 99)) or '—')}</strong></span>
    <span>Updated {e(ev_ts)}</span>
    <span>Markets tested <strong>{len(detail.get('symbols') or [])}</strong></span>
  </div>
  {decision_header}
  {availability_html}
  {rescue_html}
  {desc_html}
  {kpis_html}
  {swimlane_html}
  <h2 class="acc-title">Pipeline-Stage Evidence · Q01 → Q11 ascending</h2>
  {''.join(phases_html_chunks)}
  {files_html}
  <div class="archive-footer">
    QuantMechanica V5 · every number on this page is parsed from native MetaTrader 5 backtest reports —
    no hand-edited results. "Full MT5 ↗" opens the original report (equity curve, trade markers, monthly distribution).
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
.portfolio-badge.good{border-color:var(--pass);color:var(--pass)}
.portfolio-badge.warn{border-color:var(--warn);color:var(--warn)}
.portfolio-status{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 20px}
.portfolio-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:28px}
.portfolio-kpi{padding:16px 18px;background:var(--surface-1);border:1px solid var(--border)}
.portfolio-kpi-label{font-family:var(--font-mono);font-size:9px;font-weight:700;color:var(--text-3);letter-spacing:0.2em;text-transform:uppercase;margin-bottom:9px}
.portfolio-kpi-val{font-family:var(--font-mono);font-variant-numeric:tabular-nums;font-size:26px;font-weight:500;color:var(--text);letter-spacing:-0.02em;line-height:1}
.portfolio-kpi-val.good{color:var(--pass)}
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
.heatmap-table td.corr-good{background:color-mix(in srgb,var(--pass) 32%,var(--surface-1));color:var(--text)}
.heatmap-table td.corr-mid{background:var(--surface-2);color:var(--text-2)}
.heatmap-table td.corr-warn{background:color-mix(in srgb,var(--warn) 42%,var(--surface-1));color:var(--text)}
.heatmap-table td.corr-null{background:var(--surface-2);color:var(--text-4)}
.heatmap-table td.corr-self{background:var(--bg);color:var(--text-4)}
.portfolio-svg{width:100%;height:auto;background:var(--surface-1);border:1px solid var(--border)}
.portfolio-table{width:100%;border-collapse:collapse;background:var(--surface-1);border:1px solid var(--border);font-family:var(--font-mono);font-size:11px}
.portfolio-table th{text-align:left;padding:10px 12px;background:var(--bg);border-bottom:1px solid var(--border);border-right:1px solid var(--border);font-size:9px;font-weight:700;color:var(--text-3);letter-spacing:0.18em;text-transform:uppercase}
.portfolio-table td{padding:10px 12px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);color:var(--text-2);vertical-align:middle}
.portfolio-table th:last-child,.portfolio-table td:last-child{border-right:none}
.portfolio-table tr:last-child td{border-bottom:none}
.portfolio-table .num{text-align:right;font-variant-numeric:tabular-nums;color:var(--text)}
.portfolio-table .good{color:var(--pass)}
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
    parser.add_argument("--full", action="store_true",
                        help="Re-render every EA detail page (ignore the incremental watermark).")
    args = parser.parse_args()

    set_render_stamp()  # one RENDERED-badge timestamp for the whole run

    root = Path(args.root).resolve()
    dashboards_dir = root / "dashboards"
    dashboards_dir.mkdir(parents=True, exist_ok=True)

    # Refresh the normalized metric layer before rendering so the Strategy Archive
    # surfaces (strategies.html + ea_<id>.html) read current numbers. Incremental
    # (mtime-gated) so it is cheap; a failure here must never block rendering.
    try:
        from tools.strategy_farm import ea_metrics as _ea_metrics
        db_for_metrics = root / "state" / "farm_state.sqlite"
        if db_for_metrics.exists():
            with sqlite3.connect(db_for_metrics) as _mcon:
                _mres = _ea_metrics.build(_mcon, full=False)
            print(f"ea_metrics refreshed: {_mres.get('upserts')} upserts, "
                  f"{_mres.get('skipped')} unchanged", file=sys.stderr)
    except Exception as _exc:  # noqa: BLE001 — never block the render
        print(f"WARN: ea_metrics refresh skipped: {_exc!r}", file=sys.stderr)

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

    # DXZ Trading Journal — OWNER-directed live-book analytics (2026-07-20).
    # Read-only against T_Live logs; must never block the rest of the render.
    try:
        from tools.strategy_farm.dashboards import render_dxz_journal as _dxz
        dxz_path = dashboards_dir / "dxz_journal.html"
        dxz_path.write_text(_dxz.render_dxz_journal(root), encoding="utf-8")
    except Exception as _exc:  # noqa: BLE001 — never block the render
        print(f"WARN: dxz_journal render skipped: {_exc!r}", file=sys.stderr)

    # Per-EA detail pages — INCREMENTAL (2026-07-19). Historically all ~2500
    # pages were re-rendered every hour against a 300MB DB and blew the task
    # time limit, so pages went stale for weeks. Now we only re-render an EA
    # whose work_items MAX(updated_at) is newer than the last render watermark
    # (persisted in state/dashboard_render_state.json). A schema bump or --full
    # forces a full pass so a format change (e.g. the render badge) propagates.
    #
    # Skip TRUE card-only EAs (a card on disk, no work_items, no agent task) —
    # they have no detail page. EAs with work_items always get one so the
    # clickable archive-index rows never 404.
    DASH_STATE_SCHEMA = "archive_v2"
    eas = derive_ea_candidates(state["tasks"], root)
    db_path = root / "state" / "farm_state.sqlite"
    wi_eas: set[str] = set()
    wi_watermark: dict[str, str] = {}
    if db_path.exists():
        try:
            with sqlite3.connect(db_path) as _conn:
                for _eid, _mx in _conn.execute(
                        "SELECT ea_id, MAX(updated_at) FROM work_items "
                        "WHERE ea_id IS NOT NULL GROUP BY ea_id"):
                    wi_eas.add(_eid)
                    wi_watermark[_eid] = _mx or ""
        except sqlite3.Error:
            wi_eas = set()

    state_path = root / "state" / "dashboard_render_state.json"
    prev_state: dict[str, Any] = {}
    try:
        if state_path.exists():
            prev_state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(f"WARN: could not read {state_path.name}: {exc!r}", file=sys.stderr)
    prev_times: dict[str, str] = (prev_state.get("ea_render_times")
                                  if isinstance(prev_state.get("ea_render_times"), dict) else {}) or {}
    orig_schema = prev_state.get("schema")
    migrating = orig_schema != DASH_STATE_SCHEMA  # one-time badge/meta format-migration epoch

    global_wm = max([v for v in wi_watermark.values() if v] or [""])
    counts = {"rendered": 0, "upgraded": 0, "skipped": 0, "failed": 0, "set": 0}
    new_times: dict[str, str] = {}
    skipped_card_only = 0

    def _persist(schema: Any) -> None:
        try:
            state_path.write_text(json.dumps({
                "schema": schema,
                "last_render_utc": RENDER_STAMP.get("iso"),
                "last_mode": "full" if args.full else ("migration" if migrating else "incremental"),
                "global_watermark": global_wm,
                "detail_rendered": counts["rendered"],
                "detail_upgraded": counts["upgraded"],
                "detail_skipped": counts["skipped"],
                "detail_set": counts["set"],
                "ea_render_times": {**prev_times, **new_times},
            }, indent=0, sort_keys=True), encoding="utf-8")
        except Exception as exc:  # noqa: BLE001
            print(f"WARN: could not write {state_path.name}: {exc!r}", file=sys.stderr)

    for ea in eas:
        ea_id = ea["ea_id"]
        has_wi = ea_id in wi_eas
        if (ea.get("card_state") and ea.get("task_count", 0) == 0 and not has_wi):
            skipped_card_only += 1
            continue
        counts["set"] += 1
        out_path = dashboards_dir / f"ea_{ea_id}.html"
        exists = out_path.exists()
        # Per-EA source watermark: work_items MAX(updated_at) (task-only EAs use
        # the merged last_updated). Seed the prior watermark from the page mtime on
        # a fresh state file so we do not force-rebuild content already current on
        # disk — only genuinely stale or format-outdated pages get work.
        src_wm = wi_watermark.get(ea_id) or ea.get("last_updated") or ""
        prev_wm = prev_times.get(ea_id)
        if prev_wm is None and exists:
            prev_wm = _iso_from_mtime(out_path)
        changed = (bool(args.full) or prev_wm is None or not exists
                   or (src_wm[:19] > (prev_wm or "")[:19]))
        if changed:
            try:
                d = collect_ea_detail(ea_id, root)
                page = render_ea_detail(ea, d, state)
                out_path.write_text(inject_render_badge(page), encoding="utf-8")
                counts["rendered"] += 1
                new_times[ea_id] = src_wm
            except Exception as exc:  # noqa: BLE001 — one bad EA must not kill the run
                counts["failed"] += 1
                print(f"WARN: ea_{ea_id}.html failed: {exc!r}", file=sys.stderr)
                if prev_wm:
                    new_times[ea_id] = prev_wm
        elif migrating:
            # Content current, but the page predates the badge/meta format — cheap
            # in-place upgrade (no expensive detail rebuild).
            if _format_upgrade_file(out_path):
                counts["upgraded"] += 1
            else:
                counts["skipped"] += 1
            new_times[ea_id] = src_wm
        else:
            counts["skipped"] += 1
            new_times[ea_id] = prev_wm or src_wm
        # Periodic checkpoint: a task-limit kill mid-migration must never wedge
        # convergence. Schema stays pre-migration until the whole loop finishes.
        if counts["set"] % 300 == 0:
            _persist(orig_schema if migrating else DASH_STATE_SCHEMA)

    # Final write flips schema to current → subsequent runs are pure incremental.
    _persist(DASH_STATE_SCHEMA)
    detail_rendered = counts["rendered"]
    detail_upgraded = counts["upgraded"]
    detail_skipped = counts["skipped"]
    detail_failed = counts["failed"]
    detail_set = counts["set"]

    summary = {
        "rendered_at": utc_now_iso(),
        "strategies_html": str(strategies_path),
        "portfolio_html": str(portfolio_path),
        "style_css": str(dst_css),
        "render_mode": "full" if args.full else ("migration" if migrating else "incremental"),
        "ea_detail_set": detail_set,
        "ea_detail_rendered": detail_rendered,
        "ea_detail_upgraded": detail_upgraded,
        "ea_detail_skipped": detail_skipped,
        "ea_detail_failed": detail_failed,
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
