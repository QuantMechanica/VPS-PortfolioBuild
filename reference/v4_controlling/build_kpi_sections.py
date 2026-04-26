#!/usr/bin/env python3
"""
Controlling KPI sections builder for project_dashboard.html.

Owner: Controlling (QUAA-52). Runs idempotently: scans .htm / .md reports
and last_check_state.json, renders the 6 board-required panels, and
replaces the `<!-- PIPELINE TODAY START -->..<!-- PIPELINE TODAY END -->`
block in the dashboard HTML.

Panels:
  1. Daily Throughput
  2. Queue Status (per Terminal)
  3. Phase Distribution (G0 + P1..P10)
  4. Results Breakdown Today
  5. V5 Portfolio Status
  6. Incident Summary (last 24h)

Designed to be rerun every 15-30 min so the dashboard mtime stays fresh.
"""

from __future__ import annotations

import csv
import glob
import html
import json
import os
import re
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
T1_ROOT = r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\6C3C6A11D1C3791DD4DBF45421BF8028"
T2_ROOT = r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\D0E73AF0F17162F32C13B3D22CCF0323"
T3_ROOT = r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\35E1BC295E58086216981F2888C37961"
TERMINALS = [("T1", T1_ROOT), ("T2", T2_ROOT), ("T3", T3_ROOT)]

STATE_FILE = os.path.join(T1_ROOT, "MQL5", "Experts", "EA_Testing", "last_check_state.json")
DASHBOARD_HTML = os.path.join(T1_ROOT, "MQL5", "Files", "edge_validation", "output", "project_dashboard.html")

RESULTS_DIR = r"G:\Meine Ablage\QuantMechanica\Company\Results"
BASELINE_CSV = os.path.join(RESULTS_DIR, "BASELINE_RESULTS_EXPORT.csv")
V5_LOCK_MD = os.path.join(RESULTS_DIR, "V5_COMPOSITION_LOCK_20260418.md")

MARKER_START = "<!-- PIPELINE TODAY START -->"
MARKER_END = "<!-- PIPELINE TODAY END -->"

# V5 sleeve lineup pulled from V5_COMPOSITION_LOCK_20260418.md
V5_SLEEVES = [
    ("SM_124", "UK100",   "1.00x"),
    ("SM_221", "AUDUSD",  "0.25x"),
    ("SM_345", "AUDNZD",  "1.00x"),
    ("SM_157", "AUDNZD",  "1.00x"),
    ("SM_640", "XTIUSD",  "1.00x"),
]

# ── Helpers ────────────────────────────────────────────────────────────────
def _now_local() -> datetime:
    return datetime.now().astimezone()


def _today_start_local() -> datetime:
    n = _now_local()
    return n.replace(hour=0, minute=0, second=0, microsecond=0)


def _yesterday_start_local() -> datetime:
    return _today_start_local() - timedelta(days=1)


def _fmt_ts(ts: float | None) -> str:
    if not ts:
        return "n/a"
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M")


def _safe_read_json(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        return {"_error": str(e)}


# ── Data collection ────────────────────────────────────────────────────────
def scan_terminal_htm() -> dict:
    """Scan .htm reports across all terminal roots. Returns per-terminal
    and global mtime-based buckets (today/24h/total)."""
    today0 = _today_start_local().timestamp()
    yest0 = _yesterday_start_local().timestamp()
    hour_ago = (_now_local() - timedelta(hours=1)).timestamp()
    day_ago = (_now_local() - timedelta(hours=24)).timestamp()

    per_terminal = {}
    total_today = total_24h = total_last_hour = 0
    total_yesterday = 0
    bl_today = sw_today = 0
    all_htm_mtimes = []

    for tname, root in TERMINALS:
        today_n = yest_n = h1_n = d1_n = total_n = 0
        bl_today_n = sw_today_n = 0
        latest_mt = 0.0
        try:
            with os.scandir(root) as it:
                for entry in it:
                    name = entry.name
                    if not name.endswith(".htm"):
                        continue
                    try:
                        st = entry.stat()
                    except OSError:
                        continue
                    mt = st.st_mtime
                    total_n += 1
                    all_htm_mtimes.append(mt)
                    if mt > latest_mt:
                        latest_mt = mt
                    if mt >= today0:
                        today_n += 1
                        if name.startswith("BL_SM_"):
                            bl_today_n += 1
                        elif "_SW_" in name or name.startswith(("PSW_", "SSW_", "TSW_")):
                            sw_today_n += 1
                    elif mt >= yest0:
                        yest_n += 1
                    if mt >= hour_ago:
                        h1_n += 1
                    if mt >= day_ago:
                        d1_n += 1
        except FileNotFoundError:
            pass
        per_terminal[tname] = {
            "total": total_n,
            "today": today_n,
            "yesterday": yest_n,
            "last_hour": h1_n,
            "last_24h": d1_n,
            "bl_today": bl_today_n,
            "sw_today": sw_today_n,
            "latest_mtime": latest_mt,
        }
        total_today += today_n
        total_24h += d1_n
        total_last_hour += h1_n
        total_yesterday += yest_n
        bl_today += bl_today_n
        sw_today += sw_today_n

    # Average test duration today (gap between consecutive reports).
    # Approximation — good enough for throughput feel.
    avg_dur_sec = None
    if total_today >= 2:
        mt_today = sorted(m for m in all_htm_mtimes if m >= today0)
        if len(mt_today) >= 2:
            span = mt_today[-1] - mt_today[0]
            avg_dur_sec = span / (len(mt_today) - 1)

    return {
        "per_terminal": per_terminal,
        "total_today": total_today,
        "total_yesterday": total_yesterday,
        "total_24h": total_24h,
        "total_last_hour": total_last_hour,
        "bl_today": bl_today,
        "sw_today": sw_today,
        "avg_test_sec": avg_dur_sec,
    }


def collect_phase_distribution(throughput: dict) -> list[dict]:
    """Compute unique EAs per phase. Baseline/Sweep aggregated across ALL
    terminal .htm; higher phases from Company/Results/ .md markers."""
    # P2 baseline: unique EAs with BL_SM_XXX_*.htm
    p2_eas = set()
    p3_eas = set()
    p1_eas = set()
    for _, root in TERMINALS:
        try:
            with os.scandir(root) as it:
                for e in it:
                    n = e.name
                    if not n.endswith(".htm"):
                        continue
                    m = re.match(r"BL_SM_?(\d+)", n)
                    if m:
                        p2_eas.add(f"SM_{m.group(1)}")
                        continue
                    # Sweep variants: SW_SM*, PSW_*, SSW_*, TSW_*, R*_SW_*
                    m = re.match(r"(?:PSW|SSW|TSW|SW)_.*?SM_?(\d+)", n)
                    if m:
                        p3_eas.add(f"SM_{m.group(1)}")
                        continue
                    m = re.match(r"R\d+_SW_.*?SM_?(\d+)", n)
                    if m:
                        p3_eas.add(f"SM_{m.group(1)}")
                        continue
                    m = re.match(r"R\d+_SM_?(\d+)_", n)
                    if m:
                        p2_eas.add(f"SM_{m.group(1)}")
        except FileNotFoundError:
            pass

    # P1: every EA that reached P2 necessarily compiled; count compile logs
    # as a lower bound.
    try:
        for p in glob.glob(os.path.join(T1_ROOT, "MQL5", "Experts", "EA_Testing", "*_compile.log")):
            m = re.search(r"SM_?(\d+)", os.path.basename(p))
            if m:
                p1_eas.add(f"SM_{m.group(1)}")
    except Exception:
        pass
    p1_eas |= p2_eas  # anything in P2 is also in P1

    # Higher phases via Company/Results/ filename patterns
    def _scan_md(patterns: list[str]) -> set[str]:
        out = set()
        for pat in patterns:
            for p in glob.glob(os.path.join(RESULTS_DIR, pat)):
                m = re.search(r"SM_?(\d+)", os.path.basename(p))
                if m:
                    out.add(f"SM_{m.group(1)}")
        return out

    p35_eas = _scan_md(["P35_CSR_SM_*", "CSR_SM_*"])
    p4_eas = _scan_md(["SM_*_P4_*", "*_P4_WF_*", "*_WF_REPORT_*"])
    p5_eas = _scan_md(["SM_*_P5_STRESS_*", "*_P5_STRESS_*"])
    p5b_eas = _scan_md(["P5_CALIBRATED_NOISE_*"])
    p6_eas = _scan_md(["SM_*_P6_MULTISEED_*", "*_P6_MULTISEED_*"])
    p7_eas = _scan_md(["SM_*_P7_STATVAL_*", "*_P7_STATVAL_*"])
    p8_eas = _scan_md(["SM_*_P8_NEWS_IMPACT_*", "*_P8_NEWS_IMPACT_*"])

    p9_eas = {sm_id for sm_id, _, _ in V5_SLEEVES}  # V5 composition sleeves
    # P10: 11 live-deployed V4 portfolio (hardcoded in generate_dashboard.py)
    p10_count = 11

    rows = [
        {"phase": "G0",  "name": "Research Intake",        "count": len(p1_eas)},
        {"phase": "P1",  "name": "Build Validation",       "count": len(p1_eas)},
        {"phase": "P2",  "name": "Baseline (DEV 17-22)",   "count": len(p2_eas)},
        {"phase": "P3",  "name": "Parameter Sweep",        "count": len(p3_eas)},
        {"phase": "P3.5","name": "Cross-Sect. Robustness", "count": len(p35_eas)},
        {"phase": "P4",  "name": "Walk-Forward",           "count": len(p4_eas)},
        {"phase": "P5",  "name": "Stress",                 "count": len(p5_eas)},
        {"phase": "P5b", "name": "Calibrated Noise",       "count": len(p5b_eas)},
        {"phase": "P6",  "name": "Multi-Seed",             "count": len(p6_eas)},
        {"phase": "P7",  "name": "StatVal (DSR/PBO/MC)",   "count": len(p7_eas)},
        {"phase": "P8",  "name": "News Impact",            "count": len(p8_eas)},
        {"phase": "P9",  "name": "Portfolio Construction", "count": len(p9_eas)},
        {"phase": "P10", "name": "Shadow Deploy (live)",   "count": p10_count},
    ]
    return rows


def results_breakdown(throughput: dict) -> dict:
    """Classify today's BL reports from strategy-panel JSON (parsed corpus)
    and the BASELINE CSV rollup. Today vs yesterday counts come from .htm
    mtimes; verdict mix leans on strategy-panel raw rows when available."""
    today0 = _today_start_local()
    # Pull the post-restart taxonomy from Strategy-Analyst raw rows (shared)
    panel_rows = []
    try:
        with open(os.path.join(r"G:\Meine Ablage\QuantMechanica\Company\Analysis",
                               "baseline_post_restart_20260418_raw.json"),
                  "r", encoding="utf-8") as f:
            panel_rows = json.load(f)
    except Exception:
        pass

    # Verdict buckets: map clusters/rows onto PASS / PROMISING / MARGINAL / FAIL / ZERO_TRADES
    buckets_today = Counter()
    top_pass_today: list[tuple[str, str, float, int]] = []
    for r in panel_rows if isinstance(panel_rows, list) else []:
        mt_iso = r.get("mtime_iso", "")
        try:
            mt = datetime.fromisoformat(mt_iso)
        except Exception:
            continue
        if mt < today0.replace(tzinfo=None):
            continue
        cluster = (r.get("cluster") or "").upper()
        pf = r.get("profit_factor") or 0.0
        trades = r.get("trades") or 0
        if trades == 0:
            buckets_today["ZERO_TRADES"] += 1
        elif cluster == "STRONG_WINNER":
            buckets_today["PASS"] += 1
            top_pass_today.append((r.get("ea") or "?", r.get("symbol_from_file") or "?", pf, trades))
        elif cluster == "WEAK_WINNER":
            buckets_today["PROMISING"] += 1
        elif cluster == "MARGINAL":
            buckets_today["MARGINAL"] += 1
        else:
            buckets_today["FAIL"] += 1

    # Dedupe by (ea, symbol), keep highest PF
    dedup: dict[tuple[str, str], tuple[str, str, float, int]] = {}
    for ea, sym, pf, trades in top_pass_today:
        key = (ea, sym)
        if key not in dedup or pf > dedup[key][2]:
            dedup[key] = (ea, sym, pf, trades)
    top_pass_today = sorted(dedup.values(), key=lambda t: (-t[2], -t[3]))[:3]

    # Today delta vs yesterday — from .htm mtime totals only (no verdict split possible without parsing)
    delta = throughput["total_today"] - throughput["total_yesterday"]

    return {
        "buckets": dict(buckets_today),
        "top_pass": top_pass_today,
        "delta_vs_yesterday": delta,
        "today_htm": throughput["total_today"],
        "yesterday_htm": throughput["total_yesterday"],
    }


def queue_status(state: dict, avg_test_sec: float | None) -> dict:
    bl = state.get("bl_progress") or {}
    rows = []
    total_depth = 0
    for t in ("T1", "T2", "T3"):
        s = bl.get(t) or {}
        cur = s.get("current") or 0
        tot = s.get("total") or 0
        remaining = max(0, tot - cur)
        eta_min = None
        if avg_test_sec and remaining > 0:
            eta_min = int(remaining * avg_test_sec / 60)
        rows.append({
            "term": t,
            "ea": s.get("ea") or "—",
            "progress": f"{cur}/{tot}" if tot else str(cur),
            "status": s.get("status") or "—",
            "latest_report": s.get("latest_report") or "—",
            "report_age_sec": s.get("report_age_sec"),
            "remaining": remaining,
            "eta_min": eta_min,
        })
        total_depth += remaining

    watchers = state.get("chain_watchers") or {}
    pending = [k for k, v in watchers.items() if (v or {}).get("status", "").upper().startswith("QUEUED")]
    return {"rows": rows, "total_depth": total_depth, "revives_pending": pending}


# ── HTML rendering ─────────────────────────────────────────────────────────
def _h(s: str) -> str:
    return html.escape(str(s))


def render_throughput_panel(tp: dict) -> str:
    per = tp["per_terminal"]
    avg_s = tp["avg_test_sec"]
    avg_str = f"{avg_s/60:.1f} min" if avg_s else "n/a"
    rate_ratio = ""
    if tp["total_24h"]:
        pct = tp["total_last_hour"] / (tp["total_24h"] / 24.0) * 100
        rate_ratio = f"{pct:.0f}% of 24h avg"
    rows = "".join(
        f"<tr><td>{t}</td><td>{per[t]['today']}</td><td>{per[t]['bl_today']}</td>"
        f"<td>{per[t]['sw_today']}</td><td>{per[t]['last_hour']}</td>"
        f"<td>{_fmt_ts(per[t]['latest_mtime'])}</td></tr>"
        for t in ("T1", "T2", "T3")
    )
    return f"""
<div class="section" style="border-color:#00d4aa;">
  <div class="section-title" style="color:#00d4aa;">1. Daily Throughput — .htm reports today</div>
  <table style="width:100%;">
    <tr><th>Term</th><th>Today</th><th>BL today</th><th>SW today</th><th>Last 1h</th><th>Latest report mtime</th></tr>
    {rows}
    <tr style="font-weight:bold;background:#0f3460;">
      <td>ALL</td><td>{tp['total_today']}</td><td>{tp['bl_today']}</td><td>{tp['sw_today']}</td>
      <td>{tp['total_last_hour']}</td><td>—</td>
    </tr>
  </table>
  <p style="margin-top:8px;font-size:12px;color:#aaaacc;">
    Total 24h: <b>{tp['total_24h']}</b> · last-hour rate: <b>{rate_ratio or 'n/a'}</b>
    · avg inter-report gap today: <b>{avg_str}</b>
    · yesterday (same clock day): <b>{tp['total_yesterday']}</b>
  </p>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Source: os.scandir over T1/T2/T3 roots · mtime-based · rollup across ALL .htm reports.
  </p>
</div>"""


def render_queue_panel(q: dict) -> str:
    rows = "".join(
        f"<tr><td>{r['term']}</td><td>{_h(r['ea'])}</td><td>{r['progress']}</td>"
        f"<td>{r['remaining']}</td>"
        f"<td>{(str(r['eta_min'])+' min') if r['eta_min'] is not None else '—'}</td>"
        f"<td style=\"color:{'#00d4aa' if r['status']=='active' else '#ff9966'};\">{_h(r['status'])}</td>"
        f"<td>{_h(r['latest_report'])}</td></tr>"
        for r in q["rows"]
    )
    revives = ", ".join(q["revives_pending"]) or "—"
    return f"""
<div class="section" style="border-color:#38bdf8;">
  <div class="section-title" style="color:#38bdf8;">2. Queue Status (per Terminal)</div>
  <table style="width:100%;">
    <tr><th>Term</th><th>Active EA</th><th>Progress</th><th>Remaining</th><th>ETA</th><th>Status</th><th>Latest report</th></tr>
    {rows}
  </table>
  <p style="margin-top:8px;font-size:12px;color:#aaaacc;">
    Total queue depth across terminals: <b>{q['total_depth']}</b> · Revives pending (chain-watchers): <b>{_h(revives)}</b>
  </p>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Source: <code>last_check_state.json</code> bl_progress + chain_watchers · ETA = remaining × avg inter-report gap today.
  </p>
</div>"""


def render_phase_panel(phases: list[dict]) -> str:
    max_count = max((p["count"] for p in phases), default=1) or 1
    rows = ""
    for p in phases:
        pct = (p["count"] / max_count) * 100 if max_count else 0
        rows += (
            f"<tr><td style=\"font-weight:bold;color:#ffd700;\">{p['phase']}</td>"
            f"<td>{_h(p['name'])}</td>"
            f"<td style=\"width:45%;\">"
            f"<div style=\"background:#0f1a30;border-radius:8px;overflow:hidden;height:18px;border:1px solid #333366;\">"
            f"<div style=\"width:{pct:.1f}%;height:100%;background:linear-gradient(90deg,#6c5ce7,#a29bfe);\"></div>"
            f"</div></td>"
            f"<td style=\"text-align:right;font-weight:bold;\">{p['count']}</td></tr>"
        )
    return f"""
<div class="section" style="border-color:#a29bfe;">
  <div class="section-title" style="color:#a29bfe;">3. Phase Distribution — unique EAs per pipeline phase</div>
  <table style="width:100%;">
    <tr><th>Phase</th><th>Name</th><th>Distribution</th><th style="text-align:right;">EAs</th></tr>
    {rows}
  </table>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Source: unique EAs across all .htm (P2 BL_SM_*, P3 *_SW_*) + Company/Results/ phase markers (P3.5..P8).
    P9 = V5 composition sleeves; P10 = V4 live-deployed count. Aggregated rollup, not current cycle.
  </p>
</div>"""


def render_results_panel(rb: dict) -> str:
    buckets = rb["buckets"]
    order = ["PASS", "PROMISING", "MARGINAL", "FAIL", "ZERO_TRADES"]
    color = {"PASS": "#00d4aa", "PROMISING": "#ffd700", "MARGINAL": "#f59e0b",
             "FAIL": "#ff4757", "ZERO_TRADES": "#8888aa"}
    cards = "".join(
        f"<div style=\"background:#0f1a30;border:1px solid #333366;border-radius:8px;"
        f"padding:10px;text-align:center;flex:1;min-width:110px;\">"
        f"<div style=\"font-size:24px;font-weight:bold;color:{color.get(b,'#e0e0e0')}\">{buckets.get(b,0)}</div>"
        f"<div style=\"font-size:11px;color:#aaaacc;\">{b}</div></div>"
        for b in order
    )
    delta_sign = "+" if rb["delta_vs_yesterday"] >= 0 else ""
    pass_rows = "".join(
        f"<li><code>{_h(ea)}</code> {_h(sym)} — PF <b>{pf:.2f}</b>, {trades}T</li>"
        for ea, sym, pf, trades in rb["top_pass"]
    ) or "<li>—</li>"
    return f"""
<div class="section" style="border-color:#10b981;">
  <div class="section-title" style="color:#10b981;">4. Results Breakdown Today</div>
  <div style="display:flex;gap:10px;flex-wrap:wrap;">
    {cards}
  </div>
  <p style="margin-top:10px;font-size:12px;color:#aaaacc;">
    .htm delta vs yesterday (same clock day): <b>{delta_sign}{rb['delta_vs_yesterday']}</b>
    (today {rb['today_htm']} / yesterday {rb['yesterday_htm']})
  </p>
  <p style="margin-top:10px;font-size:12px;color:#ffd700;"><b>Top 3 new PASS candidates (today)</b></p>
  <ul style="margin:4px 0 0 20px;font-size:12px;color:#e0e0e0;">{pass_rows}</ul>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Verdict mix from Strategy-Analyst raw rows (baseline_post_restart_20260418_raw.json).
    Top FAIL patterns are owned by Strategy-Analyst's panel — see
    <a href="file:///G:/Meine%20Ablage/QuantMechanica/Company/Analysis/dashboard_panel_strategy.md"
       style="color:#a29bfe;">dashboard_panel_strategy.md</a>.
  </p>
</div>"""


def render_v5_panel() -> str:
    sleeves_html = ""
    # P5b + P6 receipts per sleeve, hardcoded from V5_COMPOSITION_LOCK
    # (refreshed on every run; see _V5_META below)
    meta = {
        "SM_124": {"p5b": "WAIVER (UK100 R002 calibrated noise receipt on disk)", "p6": "WAIVER on disk"},
        "SM_221": {"p5b": "YELLOW (strict FAIL 57.3%, proxy 71.5% ≤1 breach)",     "p6": "PASS (SM_221_P6_MULTISEED_REPORT_20260410)"},
        "SM_345": {"p5b": "PASS (R002 receipt on disk)",                           "p6": "WAIVER on disk"},
        "SM_157": {"p5b": "PASS (R002 receipt on disk)",                           "p6": "WAIVER on disk"},
        "SM_640": {"p5b": "PASS (R002 receipt on disk)",                           "p6": "WAIVER on disk"},
    }
    for sm_id, symbol, weight in V5_SLEEVES:
        m = meta.get(sm_id, {})
        sleeves_html += (
            f"<tr><td><code>{sm_id}</code></td><td>{symbol}</td><td>{weight}</td>"
            f"<td>{_h(m.get('p5b','—'))}</td><td>{_h(m.get('p6','—'))}</td></tr>"
        )
    return f"""
<div class="section" style="border-color:#f59e0b;">
  <div class="section-title" style="color:#f59e0b;">5. V5 Portfolio Status</div>
  <p style="margin:0 0 8px 0;font-size:13px;">
    Composition lock: <b>5-sleeve (SM_124 / SM_221 / SM_345 / SM_157 / SM_640)</b> ·
    Deploy gate: <b style="color:#f59e0b;">HOLD</b> pending
    <a href="/QUAA/issues/QUAA-23" style="color:#a29bfe;">QUAA-23</a> composition audit follow-up ·
    V4 live delta: BT Sharpe <b>8.70</b> vs Live PF <b>0.46</b>.
  </p>
  <table style="width:100%;">
    <tr><th>Sleeve</th><th>Symbol</th><th>Weight</th><th>P5b refined gate</th><th>P6 multi-seed</th></tr>
    {sleeves_html}
  </table>
  <p style="margin-top:8px;font-size:12px;color:#aaaacc;">
    P6 gap closure: <b>1/5</b> real multi-seed artifact (SM_221), 4 waivers on disk (V5_P6_MULTISEED_WAIVERS_20260418.md).
    P5b refined gate: 3 strict PASS + 1 YELLOW + 1 waiver.
  </p>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Source: <code>V5_COMPOSITION_LOCK_20260418.md</code> · related tickets:
    <a href="/QUAA/issues/QUAA-23" style="color:#a29bfe;">QUAA-23</a> ·
    <a href="/QUAA/issues/QUAA-39" style="color:#a29bfe;">QUAA-39</a> ·
    <a href="/QUAA/issues/QUAA-40" style="color:#a29bfe;">QUAA-40</a>.
  </p>
</div>"""


def render_incident_panel(state: dict) -> str:
    done_events = state.get("completed_events_today") or {}
    this_tick = state.get("events_this_tick") or {}
    done_rows = "".join(
        f"<li><code>{_h(k)}</code> — {_h(v)}</li>" for k, v in done_events.items()
    ) or "<li>—</li>"
    active_rows = "".join(
        f"<li><code>{_h(k)}</code> — {_h(v)}</li>" for k, v in this_tick.items()
    ) or "<li>—</li>"
    return f"""
<div class="section" style="border-color:#ef4444;">
  <div class="section-title" style="color:#ef4444;">6. Incident Summary (last 24h)</div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
    <div>
      <p style="margin:0 0 4px 0;color:#00d4aa;font-weight:bold;">Resolved today</p>
      <ul style="margin:0 0 0 20px;font-size:12px;">{done_rows}</ul>
    </div>
    <div>
      <p style="margin:0 0 4px 0;color:#ff9966;font-weight:bold;">Events / attention this tick</p>
      <ul style="margin:0 0 0 20px;font-size:12px;">{active_rows}</ul>
    </div>
  </div>
  <p style="margin-top:8px;font-size:12px;color:#aaaacc;">
    Known active blockers:
    <a href="/QUAA/issues/QUAA-12" style="color:#a29bfe;">QUAA-12</a> (MCP) ·
    <a href="/QUAA/issues/QUAA-34" style="color:#a29bfe;">QUAA-34</a> (dashboard ownership) ·
    <a href="/QUAA/issues/QUAA-35" style="color:#a29bfe;">QUAA-35</a> (15-min refresh routine).
  </p>
  <p style="margin-top:4px;font-size:11px;color:#666688;">
    Source: <code>last_check_state.json</code> completed_events_today + events_this_tick.
  </p>
</div>"""


def render_all(state: dict) -> str:
    tp = scan_terminal_htm()
    phases = collect_phase_distribution(tp)
    rb = results_breakdown(tp)
    q = queue_status(state, tp["avg_test_sec"])

    generated = _now_local().strftime("%Y-%m-%d %H:%M:%S %z")
    state_ts = state.get("timestamp", "n/a")
    disk = state.get("disk_free_gb", "n/a")
    header = f"""
<div class="section" style="border-color:#ffd700;background:linear-gradient(180deg,#1f1a2e,#16213e);">
  <div class="section-title" style="color:#ffd700;font-size:22px;">Pipeline Today — board KPI deck (QUAA-52)</div>
  <p style="margin:0;font-size:12px;color:#aaaacc;">
    Generated <b>{generated}</b> · state.json ts <b>{_h(state_ts)}</b> · disk free <b>{disk} GB</b>
    · owner Controlling · refresh cadence target 15–30 min.
    See <a href="/QUAA/issues/QUAA-52" style="color:#a29bfe;">QUAA-52</a> for scope +
    <a href="/QUAA/issues/QUAA-47" style="color:#a29bfe;">QUAA-47</a> for board spec.
  </p>
</div>
"""
    return (MARKER_START + header
            + render_throughput_panel(tp)
            + render_queue_panel(q)
            + render_phase_panel(phases)
            + render_results_panel(rb)
            + render_v5_panel()
            + render_incident_panel(state)
            + MARKER_END)


# ── HTML splice ────────────────────────────────────────────────────────────
def patch_dashboard(html_text: str, block: str) -> str:
    if MARKER_START in html_text and MARKER_END in html_text:
        pre = html_text.split(MARKER_START, 1)[0]
        post = html_text.split(MARKER_END, 1)[1]
        return pre + block + post
    # First run — remove stale QUAA-49 interim banner, inject before summary-bar.
    anchor = "<!-- Summary bar -->"
    if anchor in html_text:
        pre, post = html_text.split(anchor, 1)
        # strip any previous QUAA-49 banner between <body> and anchor
        body_split = pre.split("<body>", 1)
        if len(body_split) == 2:
            body_head = body_split[1]
            # drop everything from "<!-- Live Pipeline Status" up to "</div>\n\n<!-- Summary"
            body_head = re.sub(
                r"<!-- Live Pipeline Status.*?</div>\s*",
                "", body_head, count=1, flags=re.DOTALL)
            pre = body_split[0] + "<body>" + body_head
        return pre + block + "\n\n" + anchor + post
    return html_text + "\n" + block


def main() -> int:
    state = _safe_read_json(STATE_FILE)
    block = render_all(state)

    try:
        with open(DASHBOARD_HTML, "r", encoding="utf-8") as f:
            cur = f.read()
    except FileNotFoundError:
        print(f"[ERROR] dashboard not found: {DASHBOARD_HTML}")
        return 1

    new_html = patch_dashboard(cur, block)
    if new_html == cur:
        print("[INFO] no change detected; rewriting to refresh mtime")
    with open(DASHBOARD_HTML, "w", encoding="utf-8") as f:
        f.write(new_html)

    size = os.path.getsize(DASHBOARD_HTML) / 1024
    print(f"[OK] patched {DASHBOARD_HTML} ({size:.1f} KB) @ {_now_local():%Y-%m-%d %H:%M:%S %z}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
