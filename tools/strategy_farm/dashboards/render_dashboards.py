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
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
REPO_ROOT = Path(__file__).resolve().parents[3]

PHASE_ORDER = ["G0", "P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b", "P10"]
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


# ── Data collection ──────────────────────────────────────────────


def collect_farm_state(root: Path) -> dict[str, Any]:
    db = root / "state" / "farm_state.sqlite"
    if not db.exists():
        return {"sources": [], "tasks": [], "events": [], "db_missing": True}

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

    return {"sources": sources, "tasks": tasks, "events": events, "db_missing": False}


def get_mt5_fleet_status() -> dict[str, Any]:
    scan_at = utc_now_iso()
    try:
        result = subprocess.run(
            ["tasklist", "/V", "/FO", "CSV", "/FI", "IMAGENAME eq terminal64.exe"],
            capture_output=True, text=True, timeout=15,
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


def derive_ea_candidates(tasks: list[dict]) -> list[dict]:
    """Group tasks by card_id (= ea_id) and derive EA-level state."""
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
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Source+Code+Pro:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="style.css">
<style>
{ONE_PAGER_CSS}
{extra_css}
</style>
</head>
<body>
"""


ONE_PAGER_CSS = """
.wrap{max-width:1400px;margin:0 auto;padding:32px 36px 80px}
.dash-header{display:flex;align-items:flex-end;justify-content:space-between;margin-bottom:24px;border-bottom:.5px solid var(--qm-border);padding-bottom:18px}
.dash-header h1{font-size:34px;font-weight:600;letter-spacing:-1.2px;line-height:1.05;color:var(--qm-text)}
.dash-header h1 .em-text{color:var(--em)}
.dash-header .sub{color:var(--qm-text-muted);font-size:13px;margin-top:6px;font-family:var(--font-mono,'Source Code Pro',monospace)}

.hero{padding:30px 32px;background:linear-gradient(135deg,rgba(16,185,129,0.04) 0%,rgba(15,23,42,0.4) 100%);border:1px solid rgba(16,185,129,0.15);border-radius:18px;margin-bottom:24px;position:relative;overflow:hidden}
.hero::before{content:'';position:absolute;top:-30%;right:-10%;width:400px;height:400px;border-radius:50%;background:radial-gradient(circle,rgba(16,185,129,0.06) 0%,transparent 65%);filter:blur(80px);pointer-events:none}
.hero-row{display:flex;gap:48px;flex-wrap:wrap;position:relative;z-index:1}
.hero-portfolio,.hero-heureka{flex:1;min-width:300px}
.hero-label{font-size:11px;font-weight:600;color:var(--em);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:10px}
.hero-dots{display:flex;gap:10px;margin-bottom:10px}
.port-dot{width:26px;height:26px;border-radius:50%;border:1.5px solid var(--qm-border)}
.port-dot.filled{background:var(--em);border-color:var(--em);box-shadow:0 0 12px rgba(16,185,129,0.5)}
.hero-count{font-family:var(--font-mono,'Source Code Pro',monospace);font-size:16px;color:var(--qm-text-dim)}
.hero-count strong{font-size:28px;color:var(--em);font-weight:600}
.hero-active{font-size:14px;color:var(--qm-text-dim);font-family:var(--font-mono,'Source Code Pro',monospace);margin-top:16px;padding-top:16px;border-top:.5px solid var(--qm-border);position:relative;z-index:1}
.hero-active code{color:var(--em);font-weight:600}
.hero-active .slug{color:var(--qm-text-muted)}
.hero-active-empty{color:var(--qm-text-muted);font-style:italic}

.heureka-meter{margin-left:8px;font-family:var(--font-mono,'Source Code Pro',monospace);font-weight:600;letter-spacing:.5px;text-transform:none}
.heureka-meter-num{color:var(--em);font-size:13px}
.heureka-meter-tot{color:var(--qm-text-muted);font-size:11px}
.heureka-meter-pct{color:var(--qm-text-dim);font-size:11px;margin-left:6px}

.heureka-leader{margin-top:14px;padding-top:14px;border-top:.5px solid var(--qm-border);font-family:var(--font-mono,'Source Code Pro',monospace);font-size:12px;color:var(--qm-text-dim);display:flex;flex-direction:column;gap:6px}
.heureka-leader-row{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.heureka-leader-label{font-size:9px;text-transform:uppercase;letter-spacing:1.2px;color:var(--qm-text-muted);font-weight:600;min-width:50px}
.heureka-leader-ea{color:var(--em);font-weight:600;font-size:13px}
.heureka-leader-slug{color:var(--qm-text-muted);font-size:12px}
.heureka-leader-phase{color:var(--qm-live);font-size:14px;font-weight:600}
.heureka-leader-arrow{color:var(--qm-text-faint)}
.heureka-leader-next{color:var(--qm-text-dim);font-size:12px}
.heureka-leader-next strong{color:var(--em);font-weight:600}
.heureka-leader-empty{color:var(--qm-text-muted);font-style:italic;font-size:12px}

.phase-bar{display:flex;gap:5px;flex-wrap:wrap}
.phase-dot{width:38px;height:38px;border-radius:8px;border:1px solid var(--qm-border);display:flex;flex-direction:column;align-items:center;justify-content:center;background:rgba(15,23,42,0.5);transition:all .2s}
.phase-sym{font-size:13px;font-weight:600;color:var(--qm-text-subtle);line-height:1}
.phase-label{font-size:8px;color:var(--qm-text-subtle);letter-spacing:.4px;margin-top:2px;font-family:var(--font-mono,'Source Code Pro',monospace)}
.phase-dot.phase-done{background:var(--em-s);border-color:rgba(16,185,129,0.45)}
.phase-dot.phase-done .phase-sym{color:var(--em)}
.phase-dot.phase-done .phase-label{color:var(--em)}
.phase-dot.phase-current{background:rgba(6,182,212,0.15);border-color:rgba(6,182,212,0.5);animation:pulseGlow 2s ease-in-out infinite}
.phase-dot.phase-current .phase-sym,.phase-dot.phase-current .phase-label{color:var(--qm-live)}
.phase-dot.phase-failed{background:rgba(239,68,68,0.1);border-color:rgba(239,68,68,0.4)}
.phase-dot.phase-failed .phase-sym,.phase-dot.phase-failed .phase-label{color:var(--qm-fail)}
@keyframes pulseGlow{0%,100%{box-shadow:0 0 0 0 rgba(6,182,212,0.4)}50%{box-shadow:0 0 0 6px rgba(6,182,212,0)}}

.two-col{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-bottom:24px}
.card{padding:22px 24px;border-radius:14px;background:rgba(15,23,42,0.5);border:.5px solid var(--qm-border)}
.card-title{font-size:11px;font-weight:600;color:var(--qm-text-muted);text-transform:uppercase;letter-spacing:1.2px;margin-bottom:14px}

.fleet-pct{font-family:var(--font-mono,'Source Code Pro',monospace);font-size:32px;font-weight:600;color:var(--qm-text);letter-spacing:-1px;line-height:1}
.fleet-pct strong{color:var(--em);font-size:38px}
.fleet-card.fleet-idle .fleet-pct strong{color:var(--qm-fail)}
.fleet-card.fleet-partial .fleet-pct strong{color:#f59e0b}
.fleet-signal{font-size:11px;color:var(--qm-text-muted);margin:6px 0 16px;text-transform:uppercase;letter-spacing:.5px}
.fleet-card.fleet-idle .fleet-signal{color:var(--qm-fail);font-weight:600}
.fleet-card.fleet-partial .fleet-signal{color:#f59e0b}
.fleet-grid{display:grid;grid-template-columns:repeat(5,1fr);gap:8px}
.t-row{padding:12px 0;text-align:center;border-radius:8px;border:.5px solid var(--qm-border);background:rgba(15,23,42,0.4)}
.t-row.t-busy{border-color:rgba(16,185,129,0.4);background:rgba(16,185,129,0.06)}
.t-row.t-idle{border-color:rgba(148,163,184,0.15);opacity:0.6}
.t-name{display:block;font-family:var(--font-mono,'Source Code Pro',monospace);font-size:13px;font-weight:600;color:var(--qm-text)}
.t-row.t-busy .t-name{color:var(--em)}
.t-status{display:block;font-size:9px;color:var(--qm-text-muted);text-transform:uppercase;letter-spacing:.5px;margin-top:4px}

.tp-row{display:grid;grid-template-columns:160px 1fr 50px;align-items:center;padding:9px 0;border-bottom:.5px solid var(--qm-border-soft);font-family:var(--font-mono,'Source Code Pro',monospace)}
.tp-row:last-child{border-bottom:none}
.tp-label{font-size:12px;color:var(--qm-text-dim)}
.tp-spark{font-size:20px;color:var(--em);letter-spacing:3px}
.tp-total{font-size:14px;font-weight:600;color:var(--qm-text);text-align:right}
.tp-days{font-family:var(--font-mono,'Source Code Pro',monospace);font-size:9px;color:var(--qm-text-subtle);letter-spacing:2px;text-align:center;margin-top:6px;padding-left:160px;padding-right:50px}

.pipeline-section,.blockers-section,.events-section{margin-bottom:24px}
.section-title{font-size:13px;font-weight:600;color:var(--qm-text-muted);text-transform:uppercase;letter-spacing:1.4px;margin:0 0 14px}
.pipeline-table{width:100%;border-collapse:collapse;font-size:13px;background:rgba(15,23,42,0.4);border-radius:12px;overflow:hidden}
.pipeline-table thead th{text-align:left;font-size:10px;color:var(--qm-text-muted);text-transform:uppercase;letter-spacing:1px;padding:10px 14px;border-bottom:.5px solid var(--qm-border);font-weight:600;background:rgba(15,23,42,0.6)}
.pipeline-table tbody td{padding:13px 14px;border-bottom:.5px solid var(--qm-border-soft);vertical-align:middle}
.pipeline-table tbody tr:last-child td{border-bottom:none}
.td-ea code{font-family:var(--font-mono,'Source Code Pro',monospace);color:var(--em);font-weight:600;font-size:12px}
.td-slug{color:var(--qm-text-dim);font-size:12px}
.td-bar{width:320px}
.minibar-cell{display:inline-block;width:18px;height:14px;margin-right:2px;background:rgba(15,23,42,0.7);border:.5px solid var(--qm-border);border-radius:2px;vertical-align:middle}
.minibar-cell.mb-done{background:var(--em);border-color:var(--em);box-shadow:0 0 4px rgba(16,185,129,0.4)}
.minibar-cell.mb-current{background:var(--qm-live);border-color:var(--qm-live);animation:pulseGlow 2s ease-in-out infinite}
.minibar-cell.mb-failed{background:var(--qm-fail);border-color:var(--qm-fail)}
.td-phase strong{font-family:var(--font-mono,'Source Code Pro',monospace);color:var(--qm-text);font-size:13px}
.status-pill{display:inline-block;padding:3px 10px;border-radius:8px;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.5px}
.status-pill.st-flow{background:rgba(6,182,212,0.12);color:var(--qm-live);border:.5px solid rgba(6,182,212,0.3)}
.status-pill.st-live{background:rgba(16,185,129,0.15);color:var(--em);border:.5px solid rgba(16,185,129,0.4)}
.status-pill.st-dead{background:rgba(239,68,68,0.1);color:var(--qm-fail);border:.5px solid rgba(239,68,68,0.3)}

.blockers-list{list-style:none;padding:0;margin:0}
.blocker-item{padding:11px 16px;border-radius:8px;margin-bottom:8px;font-size:13px;color:var(--qm-text-dim);font-family:'Inter',sans-serif;border-left:3px solid;background:rgba(15,23,42,0.4)}
.blocker-high{border-left-color:var(--qm-fail);background:rgba(239,68,68,0.05)}
.blocker-med{border-left-color:#f59e0b;background:rgba(245,158,11,0.04)}
.blocker-low{border-left-color:var(--qm-text-muted);background:rgba(148,163,184,0.04)}
.blocker-item code{font-family:var(--font-mono,'Source Code Pro',monospace);color:var(--qm-text);background:rgba(15,23,42,0.6);padding:1px 6px;border-radius:3px;font-size:11px}

.events-table{width:100%;border-collapse:collapse;font-size:12px;background:rgba(15,23,42,0.4);border-radius:10px;overflow:hidden}
.events-table tbody td{padding:8px 14px;border-bottom:.5px solid var(--qm-border-soft);vertical-align:middle;font-family:var(--font-mono,'Source Code Pro',monospace)}
.events-table tbody tr:last-child td{border-bottom:none}
.ev-time{color:var(--qm-text-muted);width:120px}
.ev-type{color:var(--qm-text-dim);width:80px;text-transform:uppercase;font-size:10px;letter-spacing:.5px}
.ev-event{color:var(--em);width:140px;font-weight:500;font-size:11px}
.ev-detail{color:var(--qm-text-muted);font-size:11px}

.empty{padding:36px;text-align:center;color:var(--qm-text-muted);font-size:13px;background:rgba(15,23,42,0.3);border:.5px dashed var(--qm-border);border-radius:10px;font-style:italic}
.empty-good{color:var(--em);border-color:rgba(16,185,129,0.3);background:rgba(16,185,129,0.04);font-style:normal}

.footer-note{margin-top:36px;font-size:11px;color:var(--qm-text-muted);text-align:center;font-family:var(--font-mono,'Source Code Pro',monospace);line-height:1.6}
"""


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
            f'<span class="{cls}"><span class="phase-sym">{symbol}</span>'
            f'<span class="phase-label">{e(phase)}</span></span>'
        )
    return "".join(out)


def render_hero(state: dict) -> str:
    eas = derive_ea_candidates(state["tasks"])
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
          <strong class="heureka-leader-phase">{e(leader["current_phase"])}</strong>
          <span class="heureka-leader-arrow">→</span>
          <span class="heureka-leader-next">next: <strong>{e(next_gate)}</strong></span>
        </div>
      </div>"""
    else:
        heureka_completed = 0
        heureka_pct = 0
        phases_html = render_phase_dots([], None, None)
        heureka_leader_block = (
            '<div class="heureka-leader heureka-leader-empty">'
            'no EA in flight · pump research → G0 approve → Codex build'
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
    total = 5
    pct = int(running / total * 100) if total else 0

    if running >= 5:
        cls = "fleet-saturated"
        signal = "Saturated · mission on-track"
    elif running >= 3:
        cls = "fleet-partial"
        signal = "Partial — push backlog"
    else:
        cls = "fleet-idle"
        signal = "MT5 idle — mission-failure signal"

    rows = []
    for i in range(5):
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
    eas = derive_ea_candidates(state["tasks"])[:10]
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
    elif mt5["running_count"] < 5:
        blockers.append({
            "severity": "med",
            "text": f"{5 - mt5['running_count']}/5 MT5 terminals idle — push more backlog through."
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


def render_current(state: dict, mt5: dict) -> str:
    return html_head("Project Progress") + f"""
<div class="wrap">
  <div class="dash-header">
    <div>
      <h1>QuantMechanica <span class="em-text">V5</span></h1>
      <div class="sub">Project Progress · {e(utc_now_iso())}</div>
    </div>
    <div class="sub">Mission: 5 EAs portfolio · DXZ-compliant · FTMO-ready</div>
  </div>

  {render_hero(state)}

  <div class="two-col">
    {render_fleet(mt5)}
    {render_throughput(state)}
  </div>

  {render_pipeline_table(state)}
  {render_blockers(state, mt5)}
  {render_events(state)}

  <div class="footer-note">
    Generated by tools/strategy_farm/dashboards/render_dashboards.py<br>
    Data: D:/QM/strategy_farm/state/farm_state.sqlite + tasklist scan<br>
    Refresh: QM_StrategyFarm_Dashboard_Hourly (hourly) · QM_StrategyFarm_Cockpit_2min (2 min) · QM_StrategyFarm_Pump_5min (5 min)
  </div>
</div>
</body>
</html>
"""


# ── Strategy Archive ─────────────────────────────────────────────


ARCHIVE_CSS = """
.archive-hero{padding:56px 36px 40px;text-align:center;position:relative;overflow:hidden}
.archive-hero::before{content:'';position:absolute;top:-30%;left:50%;transform:translateX(-50%);width:600px;height:600px;border-radius:50%;background:radial-gradient(circle,rgba(16,185,129,0.05) 0%,transparent 65%);filter:blur(80px);pointer-events:none}
.archive-hero h1{font-size:clamp(34px,5vw,52px);font-weight:600;letter-spacing:-1.4px;line-height:1.05;margin-bottom:14px;position:relative;z-index:1}
.archive-hero h1 .em-text{color:var(--em)}
.archive-hero-sub{font-size:15px;color:var(--qm-text-dim);max-width:740px;margin:0 auto 32px;line-height:1.55;position:relative;z-index:1}
.lane-summary{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;margin-bottom:24px;position:relative;z-index:1}
.lane-tile{padding:18px 26px;border-radius:12px;background:rgba(15,23,42,0.55);border:.5px solid var(--qm-border);min-width:130px;text-align:center}
.lane-tile-num{font-family:var(--font-mono,'Source Code Pro',monospace);font-size:30px;font-weight:600;color:var(--em);line-height:1;letter-spacing:-1px}
.lane-tile.lane-dead .lane-tile-num{color:var(--qm-fail)}
.lane-tile.lane-flow .lane-tile-num{color:var(--qm-live)}
.lane-tile-label{font-size:11px;color:var(--qm-text-muted);margin-top:6px;letter-spacing:.5px;text-transform:uppercase}
.transparency-banner{max-width:1100px;margin:0 auto 36px;padding:16px 22px;border-radius:12px;background:rgba(16,185,129,0.04);border:.5px solid rgba(16,185,129,0.16);font-size:13px;color:var(--qm-text-dim);line-height:1.55}
.transparency-banner strong{color:var(--em)}
.ea-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px;max-width:1400px;margin:0 auto;padding:0 36px}
.ea-card{padding:22px;border-radius:12px;background:rgba(15,23,42,0.55);border:.5px solid var(--qm-border);transition:border-color .15s}
.ea-card:hover{border-color:var(--qm-border-strong,rgba(148,163,184,0.25))}
.ea-card-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}
.ea-card-id{font-family:var(--font-mono,'Source Code Pro',monospace);font-size:14px;color:var(--em);font-weight:600}
.ea-card-slug{font-size:13px;color:var(--qm-text-dim);margin-bottom:14px}
.ea-card-mini-bar{margin-bottom:10px}
.ea-card-mini-bar .minibar-cell{width:14px;height:11px}
.ea-card-phase{font-size:12px;color:var(--qm-text);margin-bottom:6px;font-family:var(--font-mono,'Source Code Pro',monospace)}
.ea-card-phase strong{color:var(--em);font-weight:600}
.ea-card-meta{font-size:10px;color:var(--qm-text-muted);font-family:var(--font-mono,'Source Code Pro',monospace);margin-top:10px;padding-top:10px;border-top:.5px solid var(--qm-border-soft)}
.ea-card-evidence{margin-top:6px;font-size:10px;color:var(--qm-text-muted);word-break:break-all}
.ea-card-evidence code{font-size:9px;background:rgba(15,23,42,0.6);padding:1px 4px;border-radius:3px}
.archive-footer{margin-top:48px;padding:0 36px 48px;font-size:11px;color:var(--qm-text-muted);text-align:center;font-family:var(--font-mono,'Source Code Pro',monospace);line-height:1.7}
"""


def render_strategies(state: dict) -> str:
    eas = derive_ea_candidates(state["tasks"])

    counts = Counter()
    for ea in eas:
        if ea["live"]:
            counts["live"] += 1
        elif ea["dead"]:
            counts["dead"] += 1
        else:
            counts["flow"] += 1

    if not eas:
        cards_html = '<div class="empty" style="max-width:1100px;margin:0 auto;">No EAs registered yet. Each Codex-built EA appears here with its full pipeline lineage.</div>'
    else:
        cards = []
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
                badge, badge_cls = "LIVE", "st-live"
            elif ea["dead"]:
                badge, badge_cls = "DEAD", "st-dead"
            else:
                badge, badge_cls = "IN FLOW", "st-flow"

            evidence_html = (
                f'<div class="ea-card-evidence">Evidence: <code>{e(ea["latest_evidence"])}</code></div>'
                if ea.get("latest_evidence") else ""
            )

            cards.append(f"""
<div class="ea-card">
  <div class="ea-card-head">
    <code class="ea-card-id">{e(ea["ea_id"])}</code>
    <span class="status-pill {badge_cls}">{badge}</span>
  </div>
  <div class="ea-card-slug">{e(ea["slug"])}</div>
  <div class="ea-card-mini-bar">{bar}</div>
  <div class="ea-card-phase">Current <strong>{e(ea["current_phase"])}</strong> · Done: {e(', '.join(ea["completed_phases"]) or '—')}</div>
  <div class="ea-card-meta">Updated {e(ea["last_updated"][:19])} · Tasks {ea["task_count"]}</div>
  {evidence_html}
</div>
""")
        cards_html = '<div class="ea-grid">' + "".join(cards) + '</div>'

    return html_head("Strategy Archive", ARCHIVE_CSS) + f"""
<div class="archive-hero">
  <h1>Strategy <span class="em-text">Archive</span></h1>
  <p class="archive-hero-sub">Every EA candidate that has entered the QuantMechanica V5 pipeline — live, in flow, or DEAD. Mechanical strategies only (Hard Rule 14, NO ML). Each EA traceable G0 → P10 with evidence trail.</p>
  <div class="lane-summary">
    <div class="lane-tile lane-live">
      <div class="lane-tile-num">{counts.get("live", 0)}</div>
      <div class="lane-tile-label">Live · T6</div>
    </div>
    <div class="lane-tile lane-flow">
      <div class="lane-tile-num">{counts.get("flow", 0)}</div>
      <div class="lane-tile-label">In Flow</div>
    </div>
    <div class="lane-tile lane-dead">
      <div class="lane-tile-num">{counts.get("dead", 0)}</div>
      <div class="lane-tile-label">Dead</div>
    </div>
  </div>
</div>

<div class="transparency-banner">
  <strong>Transparency:</strong> all EAs shown here are the actual production pipeline state. DEAD EAs are not hidden — failure data is part of the public record per Mission Baseline. Sources, mechanical rules (R1-R4), and pipeline verdicts will be linked from each card as the per-EA detail page lands in a future iteration.
</div>

{cards_html}

<div class="archive-footer">
  Generated by tools/strategy_farm/dashboards/render_dashboards.py<br>
  Strategy Archive will be published to quantmechanica.com/strategy via export_public_snapshot.ps1<br>
  Data: D:/QM/strategy_farm/state/farm_state.sqlite + artifacts/
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

    current_path = dashboards_dir / "current.html"
    strategies_path = dashboards_dir / "strategies.html"
    current_path.write_text(render_current(state, mt5), encoding="utf-8")
    strategies_path.write_text(render_strategies(state), encoding="utf-8")

    summary = {
        "rendered_at": utc_now_iso(),
        "current_html": str(current_path),
        "strategies_html": str(strategies_path),
        "style_css": str(dst_css),
        "ea_count": len(derive_ea_candidates(state["tasks"])),
        "source_count": len(state["sources"]),
        "task_count": len(state["tasks"]),
        "event_count": len(state["events"]),
        "mt5_running": mt5["running_count"],
    }
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
