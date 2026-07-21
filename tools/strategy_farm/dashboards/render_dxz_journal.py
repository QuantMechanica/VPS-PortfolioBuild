"""Render the DXZ (Darwinex Zero) Trading Journal — dxz_journal.html.

OWNER-directed analytics page for the live Final-24 book (account 4000090541,
went live 2026-07-19). Read-only against T_Live logs — never writes into
C:/QM/mt5/T_Live, never touches AutoTrading.

Data sources (every number below is evidence-backed; see paths):
  * Equity / daily book P&L — EQUITY_SNAPSHOT events across every per-EA log
    under C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Files\\QM\\QM5_*_ea-*.log, via the
    PROVEN loader in portfolio/portfolio_live_forward_from_logs.py (re-used
    here, not re-parsed — see collect_forward_equity_from_logs()).
  * Sleeve roster (ea_id, symbol, label, magic, risk_percent) — the sealed
    book manifest, portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json
    (status=DRAFT; sealed reference for the deployed 24-sleeve book — the
    same manifest render_dashboards.py's Strategy Archive "Live Book" section
    already reads).
  * Trade activity (symbol / sleeve distribution, recent trades) — the same
    per-EA JSON event logs' TM_OPEN / ENTRY_ACCEPTED / TM_CLOSE /
    TM_REMOVE_PENDING / ENTRY_REJECTED events, via the same log iterator
    (portfolio_live_forward_from_logs._iter_log_events — the shared loader).
  * Realized per-trade $ PnL — the broker deal history exported read-only by
    the AccountMonitor EA (framework/monitor/QM_AccountMonitor.mq5) to
    C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Files\\QM\\journal\\
    live_deals_normalized.csv (incremental re-export ~60s after new deals;
    first export deliberately contains the FULL account history since
    April 2026, i.e. pre-book blend trades before the Final-24 go-live).
    net_actual = profit + swap + commission + fee per deal; a closed trade's
    realized net = sum(net_actual) over ALL of its deals grouped by
    position_id, so entry commission is included. This CLOSES the former
    per-trade-$ honesty gap.

HONESTY RULES (Hard Rule: evidence over claims, no invented numbers):
  * The EVENT STREAM still cannot price trades: TM_CLOSE only fires on
    EA-initiated exits; server-side SL/TP fills close a position with NO
    TM_CLOSE event (see the docstring in portfolio_live_forward_from_logs.py).
    The trade-activity tables therefore remain COUNTS-only — realized $
    lives exclusively in the "Realized P&L (broker deal history)" section,
    sourced from the AccountMonitor deal CSV above.
  * If the deal CSV is missing, unreadable, or header-only, the Realized P&L
    section degrades to a labelled data gap — numbers are never fabricated.
  * type=BALANCE rows (deposits/adjustments) are excluded from trade stats;
    positions whose deals all carry magic 0 (manual/unknown) are bucketed as
    "unattributed", never guessed onto a sleeve.
  * Final-24 book window (>= BOOK_LIVE_SINCE) and pre-book blend history are
    shown as separate, labelled tables — never mixed into one number.

Usage:
    python tools/strategy_farm/dashboards/render_dxz_journal.py
    python tools/strategy_farm/dashboards/render_dxz_journal.py --root D:/QM/strategy_farm
"""
from __future__ import annotations

import argparse
import calendar as _cal
import csv
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm.dashboards.render_dashboards import (  # noqa: E402
    ARCHIVE_CSS, ARCHIVE2_CSS, ARCHIVE_V2_CSS, EA_DETAIL_CSS,
    RENDER_BADGE_CSS, RENDER_BADGE_JS, e, fmt_dollar, fmt_num, fmt_pct,
    html_head, render_badge_html, set_render_stamp,
)
from tools.strategy_farm.portfolio import portfolio_live_forward_from_logs as lf  # noqa: E402

DEFAULT_TLIVE_LOG_DIR = lf.DEFAULT_TLIVE_LOG_DIR
DEFAULT_MANIFEST = Path(
    r"D:\QM\reports\portfolio\portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json"
)
ACCOUNT_ID = "4000090541"
BOOK_LIVE_SINCE = "2026-07-19"  # Final-24 (24th sleeve) go-live date — OWNER-ratified
BOOK_LIVE_CUTOFF_UTC = BOOK_LIVE_SINCE + "T00:00:00Z"  # lexicographic-comparable with time_utc

# Broker deal history export (READ-ONLY source; written by the AccountMonitor
# EA, framework/monitor/QM_AccountMonitor.mq5 — this renderer never writes
# anything under C:/QM/mt5/T_Live).
DEFAULT_DEALS_CSV = Path(
    r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv"
)
# Header-check subset: columns this renderer actually consumes.
_DEALS_REQUIRED_COLS = {
    "deal_id", "position_id", "time_utc", "entry", "deal_magic",
    "logical_magic", "symbol", "net_actual", "magic", "type",
}
_CLOSING_ENTRIES = {"OUT", "OUT_BY", "INOUT"}

_OPEN_EVENTS = {"TM_OPEN", "ENTRY_ACCEPTED"}
_CLOSE_EVENTS = {"TM_CLOSE", "TM_REMOVE_PENDING"}
_REJECT_EVENTS = {"ENTRY_REJECTED"}


# ── data collection ──────────────────────────────────────────────


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}


def build_roster(manifest: dict[str, Any]) -> dict[int, dict[str, Any]]:
    """One row per ea_id (aggregated across its symbol(s)) from the sealed manifest."""
    roster: dict[int, dict[str, Any]] = {}
    for s in manifest.get("sleeves", []) or []:
        try:
            ea_id = int(s.get("ea_id"))
        except (TypeError, ValueError):
            continue
        symbol_norm = str(s.get("symbol") or "").replace(".DWX", "").upper()
        label = str(s.get("ea_label") or f"QM5_{ea_id}")
        prefix = f"QM5_{ea_id}_"
        slug = label[len(prefix):] if label.startswith(prefix) else label
        row = roster.setdefault(ea_id, {
            "ea_id": ea_id, "label": label, "slug": slug,
            "symbols": [], "risk_percent": 0.0, "in_manifest": True,
        })
        if symbol_norm and symbol_norm not in row["symbols"]:
            row["symbols"].append(symbol_norm)
        rp = s.get("risk_percent")
        if isinstance(rp, (int, float)):
            row["risk_percent"] += rp
    return roster


def latest_equity_snapshot_ts(log_dir: Path) -> str | None:
    """True wall-clock timestamp of the newest EQUITY_SNAPSHOT event.

    Kept separate from collect_forward_equity_from_logs()'s day_key bucketing
    because day_key pins to the last completed D1 bar (QM_CalendarPeriodKey)
    and freezes over a weekend — the bucket label can lag the real ts_utc by
    several calendar days even though the equity VALUE is current.
    """
    latest: str | None = None
    for rec in lf._iter_log_events(log_dir):
        if rec.get("event") != "EQUITY_SNAPSHOT":
            continue
        ts = rec.get("ts_utc")
        if ts and (latest is None or ts > latest):
            latest = ts
    return latest


def collect_activity(log_dir: Path) -> tuple[dict[str, dict], dict[int, dict], list[dict]]:
    """Aggregate trade-lifecycle events by symbol and by sleeve (ea_id).

    Re-uses lf._iter_log_events — the SAME shared JSON-log loader
    portfolio_live_forward_from_logs.py uses for the equity curve — rather
    than re-parsing the raw per-EA log files a second time.
    """
    per_symbol: dict[str, dict] = {}
    per_ea: dict[int, dict] = {}
    recent: list[dict] = []
    for rec in lf._iter_log_events(log_dir):
        event = str(rec.get("event") or "")
        if event not in _OPEN_EVENTS and event not in _CLOSE_EVENTS and event not in _REJECT_EVENTS:
            continue
        payload = rec.get("payload") or {}
        ok = payload.get("ok")
        if event in _OPEN_EVENTS and ok is False:
            continue  # rejected/failed open attempt — not a real fill
        symbol = str(rec.get("symbol") or payload.get("symbol") or "").upper() or None
        ea_id_raw = rec.get("ea_id")
        try:
            ea_id = int(ea_id_raw) if ea_id_raw is not None else None
        except (TypeError, ValueError):
            ea_id = None
        ts = rec.get("ts_utc")
        kind = "opens" if event in _OPEN_EVENTS else ("closes" if event in _CLOSE_EVENTS else "rejects")
        if symbol:
            b = per_symbol.setdefault(symbol, {"opens": 0, "closes": 0, "rejects": 0, "last_ts": None})
            b[kind] += 1
            if ts and (b["last_ts"] is None or ts > b["last_ts"]):
                b["last_ts"] = ts
        if ea_id is not None:
            b = per_ea.setdefault(ea_id, {
                "opens": 0, "closes": 0, "rejects": 0, "last_ts": None,
                "symbols": set(), "slug": rec.get("slug"),
            })
            b[kind] += 1
            if symbol:
                b["symbols"].add(symbol)
            if ts and (b["last_ts"] is None or ts > b["last_ts"]):
                b["last_ts"] = ts
        recent.append({
            "ts_utc": ts, "ts_broker": rec.get("ts_broker"), "event": event,
            "symbol": symbol, "ea_id": ea_id, "magic": rec.get("magic"),
            "direction": payload.get("type"),
            "reason": payload.get("reason") or payload.get("entry_result"),
            "ticket": payload.get("ticket"),
        })
    recent.sort(key=lambda r: r.get("ts_utc") or "", reverse=True)
    return per_symbol, per_ea, recent


# ── broker deal history (AccountMonitor export) ──────────────────


def _to_int(raw: Any) -> int | None:
    try:
        return int(str(raw).strip())
    except (TypeError, ValueError):
        return None


def _to_float(raw: Any) -> float | None:
    try:
        return float(str(raw).strip())
    except (TypeError, ValueError):
        return None


def load_deals(path: Path) -> dict[str, Any]:
    """Parse the AccountMonitor broker deal-history export.

    Returns {"ok", "reason", "deals", "mtime_utc", "last_deal_utc"}.
    ok=False (with a human-readable reason) on missing / unreadable /
    header-mismatched / header-only files — the caller then renders the
    labelled honesty-gap text instead of numbers. Never fabricates.
    """
    result: dict[str, Any] = {
        "ok": False, "reason": None, "deals": [],
        "mtime_utc": None, "last_deal_utc": None,
    }
    try:
        stat = path.stat()
    except OSError:
        result["reason"] = f"deal export not found ({path})"
        return result
    result["mtime_utc"] = dt.datetime.fromtimestamp(
        stat.st_mtime, tz=dt.timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")
    deals: list[dict[str, Any]] = []
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            missing = _DEALS_REQUIRED_COLS - set(reader.fieldnames or [])
            if missing:
                result["reason"] = (
                    "deal export header mismatch — missing column(s): "
                    + ", ".join(sorted(missing))
                )
                return result
            for row in reader:
                # magic resolution: prefer logical_magic when non-empty,
                # else deal_magic, else the raw magic column.
                magic = None
                for col in ("logical_magic", "deal_magic", "magic"):
                    val = _to_int(row.get(col))
                    if val:  # non-empty AND non-zero
                        magic = val
                        break
                deals.append({
                    "deal_id": _to_int(row.get("deal_id")),
                    "position_id": _to_int(row.get("position_id")) or 0,
                    "time_utc": str(row.get("time_utc") or "").strip(),
                    "entry": str(row.get("entry") or "").strip().upper(),
                    "symbol": str(row.get("symbol") or "").strip().upper(),
                    "net_actual": _to_float(row.get("net_actual")) or 0.0,
                    "magic": magic,  # None => magic 0 / unattributed
                    "type": str(row.get("type") or "").strip().upper(),
                    "comment": str(row.get("comment") or "").strip(),
                })
    except (OSError, UnicodeDecodeError, csv.Error) as exc:
        result["reason"] = f"deal export unreadable ({exc.__class__.__name__}: {exc})"
        return result
    if not deals:
        result["reason"] = "deal export contains only the header row — no deals exported yet"
        return result
    result["ok"] = True
    result["deals"] = deals
    result["last_deal_utc"] = max((d["time_utc"] for d in deals if d["time_utc"]), default=None)
    return result


def build_closed_trades(deals: list[dict[str, Any]]) -> tuple[list[dict], list[dict], list[dict]]:
    """Group non-BALANCE deals by position_id into realized trades.

    Returns (closed_trades, open_positions, cash_rows):
      * closed_trades — positions with >=1 OUT/OUT_BY/INOUT deal; realized
        net = sum(net_actual) over ALL the position's deals (entry commission
        included). Sleeve attribution = first non-zero magic across the
        position's deals in time order (server-side closes often carry
        magic 0; the IN deal recovers the sleeve). All-zero => unattributed.
      * open_positions — positions with only IN deals (no realized PnL yet).
      * cash_rows — non-BALANCE rows without a position (position_id 0, e.g.
        DIVIDEND adjustments) — excluded from trade stats, surfaced as a note.
    """
    positions: dict[int, list[dict]] = {}
    cash_rows: list[dict] = []
    for d in deals:
        if d["type"] == "BALANCE":
            continue  # deposits / balance adjustments — never trade stats
        if d["position_id"] <= 0:
            cash_rows.append(d)
            continue
        positions.setdefault(d["position_id"], []).append(d)

    closed: list[dict] = []
    open_pos: list[dict] = []
    for pid, rows in positions.items():
        rows.sort(key=lambda r: (r["time_utc"], r["deal_id"] or 0))
        symbol = next((r["symbol"] for r in rows if r["symbol"]), "")
        magic = next((r["magic"] for r in rows if r["magic"]), None)
        ea_id = magic // 10000 if magic else None
        closing = [r for r in rows if r["entry"] in _CLOSING_ENTRIES]
        rec = {
            "position_id": pid, "symbol": symbol, "magic": magic, "ea_id": ea_id,
            "n_deals": len(rows), "open_ts": rows[0]["time_utc"],
            "net": round(sum(r["net_actual"] for r in rows), 2),
        }
        if closing:
            rec["close_ts"] = max(r["time_utc"] for r in closing)
            closed.append(rec)
        else:
            open_pos.append(rec)
    closed.sort(key=lambda t: t["close_ts"])
    open_pos.sort(key=lambda t: t["open_ts"])
    return closed, open_pos, cash_rows


def trade_stats(trades: list[dict]) -> dict[str, Any]:
    """Win/loss aggregate over closed trades — every figure from CSV sums only."""
    wins = [t["net"] for t in trades if t["net"] > 0]
    losses = [t["net"] for t in trades if t["net"] < 0]
    n = len(trades)
    nets = [t["net"] for t in trades]
    return {
        "closed": n, "wins": len(wins), "losses": len(losses),
        "win_rate": (len(wins) / n * 100.0) if n else None,
        "net": sum(nets) if nets else None,
        "avg_win": (sum(wins) / len(wins)) if wins else None,
        "avg_loss": (sum(losses) / len(losses)) if losses else None,
        "best": max(nets) if nets else None,
        "worst": min(nets) if nets else None,
    }


# ── rendering helpers ────────────────────────────────────────────


def daily_bars_svg(bar_dates: list[str], bar_pnl: list[float], height: int = 170) -> str:
    if not bar_pnl:
        return '<p class="sec-note">No daily P&amp;L samples in this window yet.</p>'
    n = len(bar_pnl)
    bar_w, gap = (10, 3) if n <= 60 else (5, 2)
    width = max(1, n * (bar_w + gap) + gap)
    half = height / 2
    max_abs = max(abs(v) for v in bar_pnl) or 1.0
    bars: list[str] = []
    for i, (d, v) in enumerate(zip(bar_dates, bar_pnl)):
        x = gap + i * (bar_w + gap)
        h = max(1.5, abs(v) / max_abs * (half - 10))
        color = "#1a8f4c" if v >= 0 else "#d13438"
        y = half - h if v >= 0 else half
        bars.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w}" height="{h:.1f}" fill="{color}">'
            f'<title>{e(d)}: {"+" if v >= 0 else ""}{v:,.2f}</title></rect>'
        )
    axis = f'<line x1="0" y1="{half:.1f}" x2="{width}" y2="{half:.1f}" stroke="rgba(114,107,96,0.35)" stroke-width="1"/>'
    svg = (
        f'<svg viewBox="0 0 {width} {height}" width="100%" height="{height}" '
        f'preserveAspectRatio="none" class="daily-bars">{axis}{"".join(bars)}</svg>'
    )
    # Axis labels as positioned HTML: the SVG uses preserveAspectRatio="none"
    # (bars stretch to full width), so in-SVG <text> would distort — label around it.
    yaxis = (
        '<div class="daily-yaxis">'
        f'<span class="net-pos">+{max_abs:,.0f}</span>'
        '<span class="daily-zero">$0</span>'
        f'<span class="net-neg">−{max_abs:,.0f}</span></div>'
    )
    idxs = sorted({0, n // 2, n - 1})
    xspans = "".join(f'<span>{e(str(bar_dates[i])[:10])}</span>' for i in idxs if 0 <= i < n)
    xaxis = f'<div class="daily-xaxis">{xspans}</div>'
    return (
        f'<div class="daily-chart">{yaxis}'
        f'<div class="daily-plot"><div class="daily-bars-wrap">{svg}</div>{xaxis}</div></div>'
    )


def equity_growth_svg(points: list[tuple[str, float]], height: int = 240) -> str:
    """Cumulative realized-P&L growth curve (marketing headline chart).

    points = [(date_iso, cumulative_net), ...] in chronological order. Uses real
    close dates (never the day_key bucket), so it does not freeze over a weekend.
    """
    if len(points) < 2:
        return '<p class="sec-note">Not enough closed trades yet for a growth curve.</p>'
    vals = [v for _, v in points]
    hi = max(vals + [0.0])
    lo = min(vals + [0.0])
    span = (hi - lo) or 1.0
    n = len(points)
    W, H = 1000, height
    pad_l = pad_r = 6
    pad_t, pad_b = 14, 14
    plot_w = W - pad_l - pad_r
    plot_h = H - pad_t - pad_b

    def _x(i: int) -> float:
        return pad_l + (i / (n - 1)) * plot_w

    def _y(v: float) -> float:
        return pad_t + (hi - v) / span * plot_h

    line_pts = " ".join(f"{_x(i):.1f},{_y(v):.1f}" for i, (_, v) in enumerate(points))
    zero_y = _y(0.0)
    area_pts = f"{_x(0):.1f},{zero_y:.1f} " + line_pts + f" {_x(n - 1):.1f},{zero_y:.1f}"
    up = vals[-1] >= 0
    stroke = "#1a8f4c" if up else "#d13438"
    fill = "rgba(26,143,76,0.15)" if up else "rgba(209,52,56,0.15)"
    grid = "".join(
        f'<line x1="{pad_l}" y1="{_y(hi - span * f):.1f}" x2="{W - pad_r}" '
        f'y2="{_y(hi - span * f):.1f}" stroke="rgba(114,107,96,0.10)" stroke-width="1"/>'
        for f in (0.25, 0.5, 0.75)
    )
    zero_line = (
        f'<line x1="{pad_l}" y1="{zero_y:.1f}" x2="{W - pad_r}" y2="{zero_y:.1f}" '
        f'stroke="rgba(114,107,96,0.35)" stroke-width="1" stroke-dasharray="4 3"/>'
    )
    last_x, last_y = _x(n - 1), _y(vals[-1])
    dot = f'<circle cx="{last_x:.1f}" cy="{last_y:.1f}" r="3.5" fill="{stroke}"/>'
    svg = (
        f'<svg viewBox="0 0 {W} {H}" width="100%" height="{H}" preserveAspectRatio="none" class="eq-svg">'
        f'{grid}<polygon points="{area_pts}" fill="{fill}"/>{zero_line}'
        f'<polyline points="{line_pts}" fill="none" stroke="{stroke}" stroke-width="2.5" '
        f'vector-effect="non-scaling-stroke" stroke-linejoin="round"/>{dot}</svg>'
    )
    yhi = ("+" if hi >= 0 else "−") + f"{abs(hi):,.0f}"
    ylo = ("+" if lo >= 0 else "−") + f"{abs(lo):,.0f}"
    yaxis = (
        f'<div class="eq-yaxis"><span class="net-pos">{yhi}</span>'
        f'<span class="daily-zero">$0</span><span class="net-neg">{ylo}</span></div>'
    )
    xaxis = f'<div class="eq-xaxis"><span>{e(points[0][0])}</span><span>{e(points[-1][0])}</span></div>'
    return (
        f'<div class="eq-chart">{yaxis}'
        f'<div class="eq-plot"><div class="eq-wrap">{svg}</div>{xaxis}</div></div>'
    )


def monthly_pnl_calendar_html(closed_trades: list[dict], year: int, month: int,
                              today_iso: str | None = None) -> str:
    """Trading-journal style month grid: realized net P&L per calendar day
    (broker deal history, bucketed by close date). Real dates — unlike the
    equity day_key chart it never freezes over a weekend."""
    byday: dict[str, list] = {}
    for t in closed_trades:
        d = (t.get("close_ts") or "")[:10]
        if len(d) != 10:
            continue
        b = byday.setdefault(d, [0, 0.0])
        b[0] += 1
        b[1] += t["net"]
    ym = f"{year:04d}-{month:02d}"
    month_days = [(d, v) for d, v in byday.items() if d.startswith(ym)]
    month_net = sum(v[1] for _, v in month_days)
    n_green = sum(1 for _, v in month_days if v[1] > 0)
    n_red = sum(1 for _, v in month_days if v[1] < 0)
    n_flat = sum(1 for _, v in month_days if v[0] > 0 and v[1] == 0)
    max_abs = max((abs(v[1]) for _, v in month_days), default=1.0) or 1.0

    def _day_cell(dobj) -> str:
        diso = dobj.isoformat()
        if dobj.month != month or dobj.year != year:
            return f'<td class="cal-day cal-out"><div class="cal-date">{dobj.day}</div></td>'
        classes = ["cal-day"]
        if dobj.weekday() >= 5:
            classes.append("cal-weekend")
        if today_iso is not None and diso == today_iso:
            classes.append("cal-today")
        rec = byday.get(diso)
        style, body = "", ""
        if rec and rec[0] > 0:
            net = rec[1]
            pcls = "chart-pos" if net > 0 else ("chart-neg" if net < 0 else "")
            if net != 0:
                base = "26,143,76" if net > 0 else "209,52,56"
                alpha = 0.12 + 0.42 * min(1.0, abs(net) / max_abs)
                style = f' style="background:rgba({base},{alpha:.2f})"'
            sign = "+" if net > 0 else ("−" if net < 0 else "")
            body = (
                f'<div class="cal-pnl {pcls}">{sign}{abs(net):,.0f}</div>'
                f'<div class="cal-n">{rec[0]} trade{"s" if rec[0] != 1 else ""}</div>'
            )
        else:
            classes.append("cal-empty")
        return (f'<td class="{" ".join(classes)}"{style}>'
                f'<div class="cal-date">{dobj.day}</div>{body}</td>')

    rows = ""
    for wk in _cal.Calendar(firstweekday=0).monthdatescalendar(year, month):
        wk_net = sum(byday.get(d.isoformat(), [0, 0.0])[1]
                     for d in wk if d.month == month and d.year == year)
        wk_n = sum(1 for d in wk if d.month == month and d.year == year
                   and byday.get(d.isoformat(), [0])[0] > 0)
        wcls = "chart-pos" if wk_net > 0 else ("chart-neg" if wk_net < 0 else "")
        wsign = "+" if wk_net > 0 else ("−" if wk_net < 0 else "")
        wk_cell = (
            f'<td class="cal-wk"><div class="cal-wk-pnl {wcls}">{wsign}{abs(wk_net):,.0f}</div>'
            f'<div class="cal-wk-n">{wk_n} day{"s" if wk_n != 1 else ""}</div></td>'
        )
        rows += f'<tr>{"".join(_day_cell(d) for d in wk)}{wk_cell}</tr>'

    dow = "".join(f"<th>{d}</th>" for d in ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))
    ncls = "net-pos" if month_net > 0 else ("net-neg" if month_net < 0 else "")
    msign = "+" if month_net > 0 else ("−" if month_net < 0 else "")
    return (
        '<section class="arch2-sec">'
        '<div class="sec-head"><span class="sec-kicker">Calendar</span>'
        f'<h2>Daily P&amp;L &middot; {_cal.month_name[month]} {year}</h2>'
        f'<span class="sec-meta">month net <span class="{ncls}">{msign}{fmt_dollar(abs(month_net))}</span> '
        f'&middot; <span class="v-pass">{n_green} green</span> / <span class="v-fail">{n_red} red</span>'
        f'{f" / {n_flat} flat" if n_flat else ""}</span></div>'
        '<p class="sec-note">Realized net P&amp;L per calendar day from the broker deal history '
        '(each closed position bucketed by its close date, UTC). Green = net-up day, red = net-down; '
        'cell shade scales with day magnitude; weekend days are dimmed. Real-date view — it does not '
        'freeze over a weekend the way the equity day-bucket chart can.</p>'
        f'<div class="cal-wrap"><table class="cal"><thead><tr>{dow}<th class="cal-wk-h">Week</th></tr></thead>'
        f'<tbody>{rows}</tbody></table></div></section>'
    )


def _fmt_ts(ts: str | None) -> str:
    if not ts:
        return "—"
    return str(ts)[:16].replace("T", " ")


def _fmt_direction(raw: str | None) -> str:
    if not raw:
        return "—"
    txt = str(raw)
    if txt.startswith("QM_"):
        txt = txt[3:]
    return txt.replace("_", " ")


def _pnl_cell(v: Any) -> str:
    if not isinstance(v, (int, float)):
        return '<td class="col-num">—</td>'
    # P&L uses the dedicated profit/loss classes (Direction C), not
    # PASS/FAIL status colors — same hues, decoupled semantics.
    cls = "net-pos" if v > 0 else ("net-neg" if v < 0 else "")
    inner = f'<span class="{cls}">{fmt_dollar(v)}</span>' if cls else fmt_dollar(v)
    return f'<td class="col-num">{inner}</td>'


def _stats_cells(s: dict[str, Any]) -> str:
    return (
        f'<td class="col-num">{s["closed"]}</td>'
        f'<td class="col-num">{s["wins"]}</td>'
        f'<td class="col-num">{s["losses"]}</td>'
        f'<td class="col-num">{fmt_pct(s["win_rate"], 1)}</td>'
        f'{_pnl_cell(s["net"])}'
        f'{_pnl_cell(s["avg_win"])}'
        f'{_pnl_cell(s["avg_loss"])}'
        f'{_pnl_cell(s["best"])}'
        f'{_pnl_cell(s["worst"])}'
    )


_PNL_STAT_HEADERS = (
    '<th class="col-num">Closed</th><th class="col-num">Wins</th>'
    '<th class="col-num">Losses</th><th class="col-num">Win rate</th>'
    '<th class="col-num">Net $</th><th class="col-num">Avg win $</th>'
    '<th class="col-num">Avg loss $</th><th class="col-num">Best $</th>'
    '<th class="col-num">Worst $</th>'
)


def symbol_pnl_table(trades: list[dict]) -> str:
    groups: dict[str, list[dict]] = {}
    for t in trades:
        groups.setdefault(t["symbol"] or "(no symbol)", []).append(t)
    rows_html = ""
    for sym in sorted(groups):
        rows_html += (
            f'<tr><td><code>{e(sym)}</code></td>{_stats_cells(trade_stats(groups[sym]))}</tr>'
        )
    if not rows_html:
        rows_html = '<tr><td colspan="10" class="arch2-empty">No closed trades in this window.</td></tr>'
    elif len(groups) > 1:
        rows_html += f'<tr class="pnl-total"><td>ALL</td>{_stats_cells(trade_stats(trades))}</tr>'
    return (
        '<div class="archive-table-wrap" style="padding:0"><table class="archive-table">'
        f'<thead><tr><th>Symbol</th>{_PNL_STAT_HEADERS}</tr></thead>'
        f'<tbody>{rows_html}</tbody></table></div>'
    )


def sleeve_pnl_table(trades: list[dict], roster: dict[int, dict[str, Any]]) -> str:
    groups: dict[Any, list[dict]] = {}
    for t in trades:
        groups.setdefault(t["ea_id"], []).append(t)
    attributed = sorted(k for k in groups if k is not None)
    rows_html = ""
    for ea_id in attributed:
        g = groups[ea_id]
        r = roster.get(ea_id)
        slug = (r or {}).get("slug") or "(not in sealed manifest)"
        symbols = sorted({t["symbol"] for t in g if t["symbol"]})
        rows_html += (
            f'<tr onclick="window.location=\'ea_QM5_{e(ea_id)}.html\'">'
            f'<td class="td-ea"><code>QM5_{e(ea_id)}</code></td>'
            f'<td class="td-slug">{e(slug)}</td>'
            f'<td>{e(", ".join(symbols) or "—")}</td>'
            f'{_stats_cells(trade_stats(g))}</tr>'
        )
    if None in groups:
        g = groups[None]
        symbols = sorted({t["symbol"] for t in g if t["symbol"]})
        rows_html += (
            '<tr><td class="td-ea"><code>unattributed</code></td>'
            '<td class="td-slug">magic 0 on all deals — manual/unknown, not guessed</td>'
            f'<td>{e(", ".join(symbols) or "—")}</td>'
            f'{_stats_cells(trade_stats(g))}</tr>'
        )
    if not rows_html:
        rows_html = '<tr><td colspan="12" class="arch2-empty">No closed trades in this window.</td></tr>'
    elif len(groups) > 1:
        rows_html += (
            f'<tr class="pnl-total"><td class="td-ea">ALL</td><td class="td-slug"></td><td>—</td>'
            f'{_stats_cells(trade_stats(trades))}</tr>'
        )
    return (
        '<div class="archive-table-wrap" style="padding:0"><table class="archive-table">'
        f'<thead><tr><th>EA</th><th>Slug</th><th>Symbol(s)</th>{_PNL_STAT_HEADERS}</tr></thead>'
        f'<tbody>{rows_html}</tbody></table></div>'
    )


def render_content(root: Path, log_dir: Path, manifest_path: Path,
                   deals_csv: Path = DEFAULT_DEALS_CSV) -> tuple[str, dict[str, Any]]:
    manifest = load_manifest(manifest_path)
    roster = build_roster(manifest)
    starting_capital = float(manifest.get("starting_capital") or 100_000.0)
    total_risk_pct = manifest.get("total_risk_pct")
    n_manifest_sleeves = manifest.get("n_sleeves") or len(manifest.get("sleeves", []) or [])

    forward = lf.collect_forward_equity_from_logs(log_dir, manifest)
    dates: list[str] = forward["dates"]
    equity_curve: list[float] = forward["equity_curve"]
    daily_pnl: list[float] = forward["daily_pnl"]
    equity_now = equity_curve[-1] if equity_curve else None
    equity_ts = latest_equity_snapshot_ts(log_dir) or (dates[-1] if dates else None)
    total_return_pct = (
        (equity_now - starting_capital) / starting_capital * 100.0
        if isinstance(equity_now, (int, float)) and starting_capital else None
    )

    # daily_pnl[i] is the change dates[i] -> dates[i+1], so pair it with dates[1:].
    # NOTE (honest data-gap, not a bug we hide): the EA's day_key is driven by
    # QM_CalendarPeriodKey (the last completed D1 bar), which pins over a
    # weekend with no new daily bar. Empirically every EQUITY_SNAPSHOT with
    # ts_utc in 2026-07-19/20 still carries day_key=20260717 (Friday) — so a
    # hard "show only day_key >= 2026-07-19" filter would show ZERO bars even
    # though the account has live snapshots through 07-20. We therefore show
    # the FULL available day_key-bucketed history instead of filtering to the
    # Final-24 go-live date, and label the split explicitly below.
    bar_dates = dates[1:]
    bar_pnl = daily_pnl
    win_days = sum(1 for v in bar_pnl if v > 0)
    loss_days = sum(1 for v in bar_pnl if v < 0)
    flat_days = len(bar_pnl) - win_days - loss_days
    worst_day = min(bar_pnl) if bar_pnl else None
    worst_day_date = bar_dates[bar_pnl.index(worst_day)] if bar_pnl and worst_day is not None else None
    best_day = max(bar_pnl) if bar_pnl else None
    best_day_date = bar_dates[bar_pnl.index(best_day)] if bar_pnl and best_day is not None else None

    per_symbol, per_ea, recent = collect_activity(log_dir)

    # ── Realized P&L from the AccountMonitor broker deal export ──
    deals_info = load_deals(deals_csv)
    deals_ok = bool(deals_info["ok"])
    closed_trades, open_positions, cash_rows = (
        build_closed_trades(deals_info["deals"]) if deals_ok else ([], [], [])
    )
    if deals_ok:
        book_trades = [t for t in closed_trades if t["close_ts"] >= BOOK_LIVE_CUTOFF_UTC]
        pre_trades = [t for t in closed_trades if t["close_ts"] < BOOK_LIVE_CUTOFF_UTC]
        freshness = (
            f'last deal {e(_fmt_ts(deals_info["last_deal_utc"]))} UTC &middot; '
            f'CSV mtime {e(_fmt_ts(deals_info["mtime_utc"]))} UTC'
        )
        open_note = ""
        if open_positions:
            open_syms = ", ".join(sorted({p["symbol"] for p in open_positions if p["symbol"]}))
            open_note = (
                f' <strong>{len(open_positions)} open position'
                f'{"s" if len(open_positions) != 1 else ""}</strong> (IN deals only, '
                f'no realized P&amp;L yet: {e(open_syms) or "—"}) counted separately '
                f'and excluded from win/loss.'
            )
        cash_note = ""
        if cash_rows:
            cash_total = sum(r["net_actual"] for r in cash_rows)
            cash_kinds = ", ".join(sorted({r["type"] for r in cash_rows}))
            cash_note = (
                f' {len(cash_rows)} non-position cash row'
                f'{"s" if len(cash_rows) != 1 else ""} ({e(cash_kinds)}) totalling '
                f'{fmt_dollar(cash_total)} excluded from trade stats (account-level '
                f'cash flow, not a trade).'
            )
        realized_section = f'''
<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Realized</span><h2>Realized P&amp;L (broker deal history)</h2>
    <span class="sec-meta">{freshness}</span></div>
  <p class="sec-note">Source: broker deal history exported read-only by the AccountMonitor EA (framework/monitor/QM_AccountMonitor.mq5) to <code>{e(str(deals_csv))}</code> — the former per-trade-$ honesty gap is closed. A closed trade = all deals of one position_id with &ge;1 OUT/OUT_BY/INOUT deal; realized net = &Sigma; net_actual (profit+swap+commission+fee) over ALL its deals, so entry commission is included. Trades are assigned to a window by CLOSE time; BALANCE rows are excluded.{open_note}{cash_note}</p>

  <h3 class="pnl-subhead">Final-24 book — trades closed since {e(BOOK_LIVE_SINCE)} <span class="pnl-subhead-meta">{len(book_trades)} closed trade{"s" if len(book_trades) != 1 else ""}</span></h3>
  <h4 class="pnl-tablehead">By symbol</h4>
  {symbol_pnl_table(book_trades)}
  <h4 class="pnl-tablehead">By strategy (sleeve) &middot; click a row for the EA's evidence trail</h4>
  {sleeve_pnl_table(book_trades, roster)}

  <h3 class="pnl-subhead">Pre-book blend history — trades closed before {e(BOOK_LIVE_SINCE)} (account live since April 2026) <span class="pnl-subhead-meta">{len(pre_trades)} closed trade{"s" if len(pre_trades) != 1 else ""}</span></h3>
  <p class="sec-note">Same account, earlier blend of sleeves BEFORE the Final-24 book was confirmed — kept separate so book performance is never mixed with pre-book history.</p>
  <h4 class="pnl-tablehead">By symbol</h4>
  {symbol_pnl_table(pre_trades)}
  <h4 class="pnl-tablehead">By strategy (sleeve)</h4>
  {sleeve_pnl_table(pre_trades, roster)}
</section>
'''
        activity_gap_note = (
            'Realized $ per trade now lives in the <strong>Realized P&amp;L (broker deal '
            'history)</strong> section above, from the AccountMonitor deal export. The tables '
            'below remain ACTIVITY counts from the live event logs: TM_CLOSE only fires on '
            'EA-initiated exits, so server-side SL/TP fills are under-counted in the '
            '"Closes" column — do not read it as a trade count.'
        )
    else:
        realized_section = f'''
<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Realized</span><h2>Realized P&amp;L (broker deal history)</h2>
    <span class="sec-meta">{('CSV mtime ' + e(_fmt_ts(deals_info["mtime_utc"])) + ' UTC') if deals_info["mtime_utc"] else "no export found"}</span></div>
  <p class="sec-note"><strong>Honest data gap:</strong> the AccountMonitor deal export is not usable right now — {e(deals_info["reason"] or "unknown reason")}. Expected at <code>{e(str(deals_csv))}</code> (written by framework/monitor/QM_AccountMonitor.mq5). Until it is readable this page shows no per-trade $ numbers — fabricating them would violate the evidence-over-claims rule.</p>
</section>
'''
        activity_gap_note = (
            '<strong>Honest data gap:</strong> per-symbol realized $ PnL is not available right '
            f'now — the AccountMonitor deal export is unusable ({e(deals_info["reason"] or "unknown reason")}). '
            'Server-side SL/TP fills close silently (no TM_CLOSE event), so until the export is '
            'readable this table shows trade ACTIVITY counts (opens/closes/rejects from the live '
            'event logs), not win/loss dollars — fabricating a $ split would violate the '
            'evidence-over-claims rule.'
        )

    # union of manifest roster + any ea_id seen live but not in the (possibly
    # stale DRAFT) manifest snapshot — never silently drop real activity.
    all_ea_ids = sorted(set(roster) | set(per_ea))
    sleeve_rows_html = ""
    for ea_id in all_ea_ids:
        r = roster.get(ea_id) or {
            "ea_id": ea_id, "label": f"QM5_{ea_id}",
            "slug": (per_ea.get(ea_id) or {}).get("slug") or "(not in sealed manifest)",
            "symbols": [], "risk_percent": None, "in_manifest": False,
        }
        act = per_ea.get(ea_id, {"opens": 0, "closes": 0, "rejects": 0, "last_ts": None, "symbols": set()})
        symbols = sorted(set(r.get("symbols") or []) | act.get("symbols", set()))
        manifest_tag = "" if r.get("in_manifest") else ' <span class="risk-tag" title="Loaded live but not in the DRAFT sealed manifest snapshot">not in manifest</span>'
        sleeve_rows_html += (
            f'<tr onclick="window.location=\'ea_QM5_{e(ea_id)}.html\'">'
            f'<td class="td-ea"><code>QM5_{e(ea_id)}</code></td>'
            f'<td class="td-slug">{e(r.get("slug", ""))}{manifest_tag}</td>'
            f'<td>{e(", ".join(symbols) or "—")}</td>'
            f'<td class="col-num">{fmt_pct(r.get("risk_percent"), 3) if isinstance(r.get("risk_percent"), (int, float)) else "—"}</td>'
            f'<td class="col-num">{act["opens"]}</td>'
            f'<td class="col-num">{act["closes"]}</td>'
            f'<td class="col-num">{act["rejects"]}</td>'
            f'<td>{_fmt_ts(act.get("last_ts"))}</td>'
            f'</tr>'
        )
    if not sleeve_rows_html:
        sleeve_rows_html = '<tr><td colspan="8" class="arch2-empty">No sleeve activity or manifest data available.</td></tr>'

    # symbol distribution: union of manifest-declared symbols + observed symbols
    manifest_symbols: dict[str, dict] = {}
    for r in roster.values():
        for sym in r.get("symbols") or []:
            m = manifest_symbols.setdefault(sym, {"sleeves": 0, "risk_percent": 0.0})
            m["sleeves"] += 1
            if isinstance(r.get("risk_percent"), (int, float)) and r.get("symbols"):
                m["risk_percent"] += r["risk_percent"] / max(1, len(r["symbols"]))
    all_symbols = sorted(set(manifest_symbols) | set(per_symbol))
    symbol_rows_html = ""
    for sym in all_symbols:
        act = per_symbol.get(sym, {"opens": 0, "closes": 0, "rejects": 0, "last_ts": None})
        m = manifest_symbols.get(sym, {"sleeves": 0, "risk_percent": 0.0})
        symbol_rows_html += (
            f'<tr><td><code>{e(sym)}</code></td>'
            f'<td class="col-num">{m["sleeves"] or "—"}</td>'
            f'<td class="col-num">{fmt_pct(m["risk_percent"], 3) if m["risk_percent"] else "—"}</td>'
            f'<td class="col-num">{act["opens"]}</td>'
            f'<td class="col-num">{act["closes"]}</td>'
            f'<td class="col-num">{act["rejects"]}</td>'
            f'<td>{_fmt_ts(act.get("last_ts"))}</td>'
            f'</tr>'
        )
    if not symbol_rows_html:
        symbol_rows_html = '<tr><td colspan="7" class="arch2-empty">No symbol data available.</td></tr>'

    # recent trades (last 50 lifecycle events, newest first)
    recent_rows_html = ""
    for rrow in recent[:50]:
        ea_id = rrow.get("ea_id")
        r = roster.get(ea_id) if ea_id is not None else None
        slug = (r or {}).get("slug") or ""
        ea_link = f'ea_QM5_{ea_id}.html' if ea_id is not None else "#"
        kind_lbl = {"TM_OPEN": "OPENED", "ENTRY_ACCEPTED": "OPENED",
                    "TM_CLOSE": "CLOSED", "TM_REMOVE_PENDING": "PENDING REMOVED",
                    "ENTRY_REJECTED": "REJECTED"}.get(rrow["event"], rrow["event"])
        kind_cls = "v-pass" if kind_lbl == "OPENED" else ("v-fail" if kind_lbl in ("REJECTED",) else "v-pending")
        recent_rows_html += (
            f'<tr onclick="window.location=\'{e(ea_link)}\'">'
            f'<td>{_fmt_ts(rrow.get("ts_utc"))}</td>'
            f'<td><code>{e(rrow.get("symbol") or "—")}</code></td>'
            f'<td class="td-ea"><code>QM5_{e(ea_id) if ea_id is not None else "?"}</code>'
            f'<span class="td-slug"> {e(slug)}</span></td>'
            f'<td>{e(_fmt_direction(rrow.get("direction")))}</td>'
            f'<td><span class="{kind_cls}">{e(kind_lbl)}</span></td>'
            f'<td class="td-slug">{e(rrow.get("reason") or "—")}</td>'
            f'</tr>'
        )
    if not recent_rows_html:
        recent_rows_html = '<tr><td colspan="6" class="arch2-empty">No trade-lifecycle events recorded yet.</td></tr>'

    n_window_days = len(bar_dates)
    n_history_days = len(dates)
    stats = {
        "equity_now": equity_now, "equity_ts": equity_ts,
        "total_return_pct": total_return_pct, "worst_day": worst_day,
        "n_window_days": n_window_days, "starting_capital": starting_capital,
    }

    daily_chart = daily_bars_svg(bar_dates, bar_pnl)

    # ── Marketing headline: cumulative realized-P&L growth curve + fund KPIs ──
    _closed_sorted = sorted(closed_trades, key=lambda t: t.get("close_ts") or "")
    cum: list[tuple[str, float]] = []
    _running = 0.0
    for t in _closed_sorted:
        _running += t["net"]
        cts = (t.get("close_ts") or "")[:10]
        if cts:
            cum.append((cts, round(_running, 2)))
    growth_chart = equity_growth_svg(cum) if cum else '<p class="sec-note">No realized closed trades yet.</p>'

    realized_stats = trade_stats(closed_trades)
    n_closed = realized_stats["closed"]
    realized_net = realized_stats["net"] or 0.0
    gross_win = sum(t["net"] for t in closed_trades if t["net"] > 0)
    gross_loss = -sum(t["net"] for t in closed_trades if t["net"] < 0)
    profit_factor = (gross_win / gross_loss) if gross_loss > 0 else None
    peak, max_dd = None, 0.0
    for _, v in cum:
        peak = v if peak is None else max(peak, v)
        max_dd = min(max_dd, v - peak)

    now_utc = dt.datetime.now(dt.timezone.utc)
    today_iso = now_utc.date().isoformat()
    calendar_html = (monthly_pnl_calendar_html(closed_trades, now_utc.year, now_utc.month, today_iso)
                     if closed_trades else "")

    _fresh = []
    if equity_ts:
        _fresh.append(f'equity {e(_fmt_ts(equity_ts))}')
    if deals_ok and deals_info.get("last_deal_utc"):
        _fresh.append(f'last trade {e(_fmt_ts(deals_info["last_deal_utc"]))}')
    freshness_line = (" &middot; ".join(_fresh) + " UTC") if _fresh else "—"

    def _pn(v: Any) -> str:
        return 'pos' if isinstance(v, (int, float)) and v >= 0 else 'neg'

    kpi_tiles = f'''
<div class="kpi-grid">
  <div class="kpi-tile kpi-hero"><div class="kpi-tile-label">Equity</div>
    <div class="kpi-tile-val">{fmt_dollar(equity_now)}</div>
    <div class="kpi-tile-sub">account {e(ACCOUNT_ID)} &middot; as of {e(_fmt_ts(equity_ts))} UTC</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Total Return</div>
    <div class="kpi-tile-val {_pn(total_return_pct)}">{fmt_pct(total_return_pct)}</div>
    <div class="kpi-tile-sub">vs {fmt_dollar(starting_capital)} start</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Realized P&amp;L</div>
    <div class="kpi-tile-val {_pn(realized_net)}">{fmt_dollar(realized_net)}</div>
    <div class="kpi-tile-sub">{n_closed} closed trade{'s' if n_closed != 1 else ''}</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Win Rate</div>
    <div class="kpi-tile-val">{fmt_pct(realized_stats["win_rate"], 1)}</div>
    <div class="kpi-tile-sub">{realized_stats["wins"]}W / {realized_stats["losses"]}L</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Profit Factor</div>
    <div class="kpi-tile-val {'pos' if isinstance(profit_factor,(int,float)) and profit_factor>=1 else 'neg'}">{fmt_num(profit_factor, 2) if profit_factor is not None else "—"}</div>
    <div class="kpi-tile-sub">gross win / gross loss</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Max Drawdown</div>
    <div class="kpi-tile-val neg">{fmt_dollar(max_dd) if cum else "—"}</div>
    <div class="kpi-tile-sub">peak-to-trough, realized curve</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Best / Worst Day</div>
    <div class="kpi-tile-val kpi-bw"><span class="net-pos">{fmt_dollar(best_day)}</span> <span class="kpi-slash">/</span> <span class="net-neg">{fmt_dollar(worst_day)}</span></div>
    <div class="kpi-tile-sub">{win_days}W / {loss_days}L days</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Risk Deployed</div>
    <div class="kpi-tile-val">{fmt_pct(total_risk_pct, 2)}</div>
    <div class="kpi-tile-sub">&Sigma; RISK_PERCENT &middot; {n_manifest_sleeves} sleeves</div></div>
</div>
'''

    content = f"""
<div class="arch2-top">
  <div>
    <h1>DXZ <span class="em-text">Trading Journal</span></h1>
    <div class="arch2-sub">Darwinex Zero account {e(ACCOUNT_ID)} &middot; live Final-24 book, deployed {e(BOOK_LIVE_SINCE)}. Every figure is parsed read-only from the T_Live per-EA event logs and the AccountMonitor broker deal export — no number is invented.</div>
  </div>
  <div class="arch2-fresh"><span class="arch2-fresh-lbl">Data as of</span><span class="arch2-fresh-val">{freshness_line}</span></div>
</div>

{kpi_tiles}

<section class="arch2-sec eq-sec">
  <div class="sec-head"><span class="sec-kicker">Track record</span><h2>Cumulative realized P&amp;L</h2>
    <span class="sec-meta">{n_closed} closed trades &middot; {e(cum[0][0]) if cum else "—"} &rarr; {e(cum[-1][0]) if cum else "—"}</span></div>
  <p class="sec-note">Running sum of realized net P&amp;L (profit + swap + commission + fee) per closed trade, in close-date order — the account's live growth curve. Account live since April 2026; Final-24 book confirmed {e(BOOK_LIVE_SINCE)}.</p>
  {growth_chart}
</section>

{calendar_html}

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Daily</span><h2>Win / Loss by day</h2>
    <span class="sec-meta"><span class="v-pass">{win_days} win</span> / <span class="v-fail">{loss_days} loss</span> / {flat_days} flat &middot; best {fmt_dollar(best_day)} ({e(best_day_date) if best_day_date else "—"})</span></div>
  <p class="sec-note">Book-level daily P&amp;L = day-over-day change of account EQUITY_SNAPSHOT (account-level, deployed sum of all sleeves at flat RISK_PERCENT), aggregated across all {n_manifest_sleeves} per-EA T_Live logs. Green = up day, red = down day. {n_window_days} trading-day buckets shown, {e(dates[0]) if dates else "—"} &rarr; {e(dates[-1]) if dates else "—"}. Final-24 (24th sleeve) was confirmed live {e(BOOK_LIVE_SINCE)} — earlier days reflect the same account with fewer sleeves. <strong>Data-gap note:</strong> the bucket date is the EA's last-completed-D1-bar key (QM_CalendarPeriodKey), which pins over a weekend/holiday with no new daily bar — the true latest snapshot is {e(_fmt_ts(equity_ts))} UTC (see the Equity tile) even though its bucket is dated {e(dates[-1]) if dates else "—"}.</p>
  {daily_chart}
</section>

{realized_section}

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Distribution</span><h2>Trade activity by symbol</h2>
    <span class="sec-meta">{len(all_symbols)} symbols traded across the book</span></div>
  <p class="sec-note">{activity_gap_note}</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>Symbol</th><th class="col-num">Sleeves</th><th class="col-num">Risk %</th><th class="col-num">Opens</th><th class="col-num">Closes</th><th class="col-num">Rejects</th><th>Last activity (UTC)</th></tr></thead>
    <tbody>{symbol_rows_html}</tbody>
  </table>
  </div>
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Distribution</span><h2>Trade activity by strategy (sleeve)</h2>
    <span class="sec-meta">{len(all_ea_ids)} sleeves &middot; click a row for the EA's full evidence trail</span></div>
  <p class="sec-note">Same activity-count caveat as above applies per sleeve. "Rejects" = broker-rejected entry attempts (e.g. AutoTrading disabled, invalid stops) — a real operational signal even without $ PnL.</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>EA</th><th>Slug</th><th>Symbol(s)</th><th class="col-num">Risk %</th><th class="col-num">Opens</th><th class="col-num">Closes</th><th class="col-num">Rejects</th><th>Last activity (UTC)</th></tr></thead>
    <tbody>{sleeve_rows_html}</tbody>
  </table>
  </div>
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Recent</span><h2>Recent trade-lifecycle events</h2>
    <span class="sec-meta">last {min(50, len(recent))} of {len(recent)} events</span></div>
  <p class="sec-note">Opens/closes/rejects from the live per-EA logs, newest first. No $ PnL column here — event-stream only; realized $ lives in the Realized P&amp;L section (broker deal history).</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>Time (UTC)</th><th>Symbol</th><th>Sleeve</th><th>Direction</th><th>Event</th><th>Reason</th></tr></thead>
    <tbody>{recent_rows_html}</tbody>
  </table>
  </div>
</section>

<div class="arch2-foot">
  QuantMechanica V5 &middot; DXZ Trading Journal &middot; regenerated hourly &middot;
  equity from T_Live EQUITY_SNAPSHOT logs, roster from the sealed book manifest, activity counts from T_Live lifecycle events, realized $ from the AccountMonitor broker deal export — read-only, no invented numbers.
  <br><a class="jrnl-link" href="strategies.html">&larr; back to Strategy Archive</a>
</div>
"""
    return content, stats


EXTRA_CSS = """
.arch2-top{max-width:1400px;margin:36px auto 8px;padding:0 36px;display:flex;justify-content:space-between;align-items:flex-end;gap:20px;flex-wrap:wrap}
.arch2-top h1{font-size:clamp(26px,4vw,38px);font-weight:600;letter-spacing:-0.03em;margin:0 0 8px}
.arch2-top h1 .em-text{color:var(--signal)}
.arch2-sub{font-family:var(--font-mono);font-size:11.5px;color:var(--text-3);max-width:900px;line-height:1.6;letter-spacing:0.02em}
.kpi-grid{max-width:1400px;margin:20px auto;padding:0 36px;display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:10px}
.arch2-sec{max-width:1400px;margin:0 auto 26px;padding:0 36px}
.arch2-empty{color:var(--text-4);font-style:italic;padding:16px !important;text-align:center}
.sec-meta{font-family:var(--font-mono);font-size:11px;color:var(--text-3);letter-spacing:0.04em;margin-left:auto}
.risk-tag{font-family:var(--font-mono);font-size:9px;color:var(--warn);border:1px solid var(--warn);padding:1px 5px;letter-spacing:0.06em;text-transform:uppercase}
.daily-bars-wrap{background:var(--chart-surface);border:1px solid var(--border-3);padding:12px}
.daily-bars{display:block}
.pnl-subhead{font-size:15px;font-weight:600;letter-spacing:-0.01em;margin:22px 0 4px;display:flex;align-items:baseline;gap:10px;flex-wrap:wrap}
.pnl-subhead-meta{font-family:var(--font-mono);font-size:11px;font-weight:400;color:var(--text-3);letter-spacing:0.04em}
.pnl-tablehead{font-family:var(--font-mono);font-size:10.5px;font-weight:500;color:var(--text-3);text-transform:uppercase;letter-spacing:0.08em;margin:12px 0 6px}
.pnl-total td{border-top:1px solid var(--border);font-weight:600}
.arch2-foot{max-width:1400px;margin:40px auto 48px;padding:0 36px;font-family:var(--font-mono);font-size:11px;color:var(--text-3);text-align:center;line-height:1.8;letter-spacing:0.06em}
.arch2-fresh{font-family:var(--font-mono);font-size:11px;color:var(--text-3);text-align:right;line-height:1.5;border-left:2px solid var(--signal);padding:3px 0 3px 14px}
.arch2-fresh-lbl{display:block;font-size:9px;text-transform:uppercase;letter-spacing:0.18em;color:var(--text-4)}
.arch2-fresh-val{color:var(--text-2)}
.kpi-hero{border-left:2px solid var(--signal)}
.kpi-hero .kpi-tile-val{color:var(--signal)}
.kpi-bw{font-size:16px}
.kpi-slash{color:var(--text-4)}
.eq-sec .sec-note{margin-bottom:14px}
.eq-chart{display:flex;gap:10px;align-items:stretch}
.eq-yaxis{display:flex;flex-direction:column;justify-content:space-between;font-family:var(--font-mono);font-size:10px;text-align:right;min-width:58px;padding:2px 0;color:var(--text-3)}
.eq-plot{flex:1;min-width:0}
.eq-wrap{background:var(--chart-surface);border:1px solid var(--border-3);padding:10px 6px}
.eq-svg{display:block}
.eq-xaxis{display:flex;justify-content:space-between;font-family:var(--font-mono);font-size:10px;color:var(--text-3);margin-top:5px;padding:0 4px}
.daily-chart{display:flex;gap:8px;align-items:stretch}
.daily-yaxis{display:flex;flex-direction:column;justify-content:space-between;font-family:var(--font-mono);font-size:9.5px;text-align:right;min-width:54px;padding:2px 0}
.daily-yaxis .daily-zero{color:var(--text-4)}
.daily-plot{flex:1;min-width:0}
.daily-xaxis{display:flex;justify-content:space-between;font-family:var(--font-mono);font-size:9.5px;color:var(--text-3);margin-top:5px;padding:0 2px}
.cal-wrap{overflow-x:auto;background:var(--chart-surface);border:1px solid var(--border-3);padding:12px}
.cal{width:100%;border-collapse:separate;border-spacing:5px;table-layout:fixed;min-width:760px}
.cal th{font-family:var(--font-mono);font-size:10px;font-weight:600;color:var(--chart-ink-3);text-transform:uppercase;letter-spacing:0.1em;padding:2px 6px;text-align:left}
.cal th.cal-wk-h{color:var(--chart-ink-3);opacity:0.65}
.cal-day{vertical-align:top;height:78px;border:1px solid rgba(0,0,0,0.09);background:var(--chart-surface);padding:6px 8px}
.cal-day.cal-out{background:transparent;border-color:transparent}
.cal-day.cal-out .cal-date{opacity:0.3}
.cal-day.cal-weekend{background:rgba(0,0,0,0.025)}
.cal-day.cal-today{outline:2px solid var(--chart-accent);outline-offset:-1px}
.cal-date{font-family:var(--font-mono);font-size:11px;color:var(--chart-ink-3);font-weight:500}
.cal-pnl{font-size:15px;font-weight:600;letter-spacing:-0.01em;margin-top:9px}
.cal-n{font-family:var(--font-mono);font-size:9.5px;color:var(--chart-ink-3);margin-top:2px}
.cal-wk{vertical-align:top;height:78px;background:rgba(0,0,0,0.045);border:1px solid rgba(0,0,0,0.09);padding:6px 8px;text-align:right}
.cal-wk-pnl{font-family:var(--font-mono);font-size:12px;font-weight:600}
.cal-wk-n{font-family:var(--font-mono);font-size:9px;color:var(--chart-ink-3);margin-top:5px}
"""


def render_dxz_journal(root: Path, log_dir: Path = DEFAULT_TLIVE_LOG_DIR,
                        manifest_path: Path = DEFAULT_MANIFEST,
                        deals_csv: Path = DEFAULT_DEALS_CSV) -> str:
    content, _stats = render_content(root, log_dir, manifest_path, deals_csv)
    css = ARCHIVE_CSS + ARCHIVE2_CSS + ARCHIVE_V2_CSS + EA_DETAIL_CSS + EXTRA_CSS
    bar = f'<div class="render-badge-bar">{render_badge_html()}</div>{RENDER_BADGE_JS}'
    return html_head("DXZ Trading Journal", css) + bar + content + "</body>\n</html>\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    parser.add_argument("--log-dir", default=str(DEFAULT_TLIVE_LOG_DIR))
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--deals-csv", default=str(DEFAULT_DEALS_CSV),
                        help="AccountMonitor broker deal-history export (read-only)")
    parser.add_argument("--out", default=None)
    args = parser.parse_args(argv)

    set_render_stamp()
    root = Path(args.root).resolve()
    out = Path(args.out) if args.out else root / "dashboards" / "dxz_journal.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    html_txt = render_dxz_journal(root, Path(args.log_dir), Path(args.manifest),
                                  Path(args.deals_csv))
    out.write_text(html_txt, encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
