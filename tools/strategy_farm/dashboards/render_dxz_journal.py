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

HONESTY GAP (do not paper over — Hard Rule: evidence over claims, no
invented numbers): per-trade realized $ PnL is NOT available from the event
stream. TM_CLOSE only fires on EA-initiated exits; server-side SL/TP fills
close a position with NO TM_CLOSE event (see the docstring in
portfolio_live_forward_from_logs.py). The broker deal-history export
contract exists (D:\\QM\\reports\\portfolio\\dxz_live_blend_v1_template_*\\
live_deals_normalized.csv + deal_export_contract.json) but is currently an
EMPTY template (header row only, terminal_api_used_by_this_tool=false) — no
one has populated it yet. So this page reports real, evidence-backed
numbers only:
  - book-level daily win/loss ($ real, from EQUITY_SNAPSHOT deltas)
  - trade ACTIVITY counts per symbol/sleeve (opens/closes/rejects — real,
    from lifecycle events)
  - NOT a per-symbol/per-sleeve $ win-loss breakdown or win-rate — that
    would require fabricating numbers with no evidence trail. The gap is
    labelled inline rather than hidden.

Usage:
    python tools/strategy_farm/dashboards/render_dxz_journal.py
    python tools/strategy_farm/dashboards/render_dxz_journal.py --root D:/QM/strategy_farm
"""
from __future__ import annotations

import argparse
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
        color = "#10b981" if v >= 0 else "#ef4444"
        y = half - h if v >= 0 else half
        bars.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w}" height="{h:.1f}" fill="{color}">'
            f'<title>{e(d)}: {"+" if v >= 0 else ""}{v:,.2f}</title></rect>'
        )
    axis = f'<line x1="0" y1="{half:.1f}" x2="{width}" y2="{half:.1f}" stroke="rgba(148,163,184,0.32)" stroke-width="1"/>'
    return (
        f'<div class="daily-bars-wrap"><svg viewBox="0 0 {width} {height}" width="100%" '
        f'height="{height}" preserveAspectRatio="none" class="daily-bars">{axis}{"".join(bars)}</svg></div>'
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


def render_content(root: Path, log_dir: Path, manifest_path: Path) -> tuple[str, dict[str, Any]]:
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

    kpi_tiles = f'''
<div class="kpi-grid">
  <div class="kpi-tile"><div class="kpi-tile-label">Account</div>
    <div class="kpi-tile-val">{e(ACCOUNT_ID)}</div>
    <div class="kpi-tile-sub">DXZ Darwinex Zero &middot; Final-24 book</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Equity</div>
    <div class="kpi-tile-val">{fmt_dollar(equity_now)}</div>
    <div class="kpi-tile-sub">as of {e(_fmt_ts(equity_ts))} UTC (EQUITY_SNAPSHOT)</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Total Return</div>
    <div class="kpi-tile-val {'pos' if isinstance(total_return_pct,(int,float)) and total_return_pct>=0 else 'neg'}">{fmt_pct(total_return_pct)}</div>
    <div class="kpi-tile-sub">vs {fmt_dollar(starting_capital)} starting capital</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Equity-Log History Since</div>
    <div class="kpi-tile-val">{e(dates[0]) if dates else "—"}</div>
    <div class="kpi-tile-sub">{n_window_days} trading day{'s' if n_window_days != 1 else ''} of daily P&amp;L &middot; Final-24 (24 sleeves) confirmed {e(BOOK_LIVE_SINCE)}</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Worst Day</div>
    <div class="kpi-tile-val neg">{fmt_dollar(worst_day)}</div>
    <div class="kpi-tile-sub">{e(worst_day_date) if worst_day_date else "—"}</div></div>
  <div class="kpi-tile"><div class="kpi-tile-label">Current Risk Sum</div>
    <div class="kpi-tile-val">{fmt_pct(total_risk_pct, 2)}</div>
    <div class="kpi-tile-sub">&Sigma; RISK_PERCENT &middot; {n_manifest_sleeves} sleeves (sealed manifest, DRAFT)</div></div>
</div>
'''

    content = f"""
<div class="arch2-top">
  <div>
    <h1>DXZ <span class="em-text">Trading Journal</span></h1>
    <div class="arch2-sub">Darwinex Zero account {e(ACCOUNT_ID)} &middot; live Final-24 book, deployed {e(BOOK_LIVE_SINCE)}. Every number below is parsed from the T_Live per-EA event logs (EQUITY_SNAPSHOT / TM_OPEN / TM_CLOSE / ENTRY_ACCEPTED / ENTRY_REJECTED) read-only, or from the sealed book manifest. Regenerated hourly with the rest of the dashboard suite.</div>
  </div>
</div>

{kpi_tiles}

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Daily</span><h2>Win / Loss by day</h2>
    <span class="sec-meta"><span class="v-pass">{win_days} win</span> / <span class="v-fail">{loss_days} loss</span> / {flat_days} flat &middot; best {fmt_dollar(best_day)} ({e(best_day_date) if best_day_date else "—"})</span></div>
  <p class="sec-note">Book-level daily P&amp;L = day-over-day change of account EQUITY_SNAPSHOT (account-level, deployed sum of all sleeves at flat RISK_PERCENT), aggregated across all {n_manifest_sleeves} per-EA T_Live logs. Green = up day, red = down day. {n_window_days} trading-day buckets shown, {e(dates[0]) if dates else "—"} &rarr; {e(dates[-1]) if dates else "—"}. Final-24 (24th sleeve) was confirmed live {e(BOOK_LIVE_SINCE)} — earlier days reflect the same account with fewer sleeves. <strong>Data-gap note:</strong> the bucket date is the EA's last-completed-D1-bar key (QM_CalendarPeriodKey), which pins over a weekend/holiday with no new daily bar — the true latest snapshot is {e(_fmt_ts(equity_ts))} UTC (see the Equity tile) even though its bucket is dated {e(dates[-1]) if dates else "—"}.</p>
  {daily_chart}
</section>

<section class="arch2-sec">
  <div class="sec-head"><span class="sec-kicker">Distribution</span><h2>Trade activity by symbol</h2>
    <span class="sec-meta">{len(all_symbols)} symbols traded across the book</span></div>
  <p class="sec-note"><strong>Honest data gap:</strong> per-symbol realized $ PnL is not attributable yet — server-side SL/TP fills close silently (no TM_CLOSE event), and the broker deal-history export (dxz_live_blend_v1_template.../live_deals_normalized.csv) is currently an empty template with zero populated deals. Until that export is populated this table shows trade ACTIVITY counts (opens/closes/rejects from the live event logs), not win/loss dollars — fabricating a $ split would violate the evidence-over-claims rule.</p>
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
  <p class="sec-note">Opens/closes/rejects from the live per-EA logs, newest first. No $ PnL column — see the data-gap note above.</p>
  <div class="archive-table-wrap" style="padding:0">
  <table class="archive-table">
    <thead><tr><th>Time (UTC)</th><th>Symbol</th><th>Sleeve</th><th>Direction</th><th>Event</th><th>Reason</th></tr></thead>
    <tbody>{recent_rows_html}</tbody>
  </table>
  </div>
</section>

<div class="arch2-foot">
  QuantMechanica V5 &middot; DXZ Trading Journal &middot; regenerated hourly &middot;
  equity from T_Live EQUITY_SNAPSHOT logs, roster from the sealed book manifest, activity counts from T_Live lifecycle events — read-only, no invented numbers.
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
.daily-bars-wrap{background:var(--surface-1);border:1px solid var(--border);padding:12px}
.daily-bars{display:block}
.arch2-foot{max-width:1400px;margin:40px auto 48px;padding:0 36px;font-family:var(--font-mono);font-size:11px;color:var(--text-3);text-align:center;line-height:1.8;letter-spacing:0.06em}
"""


def render_dxz_journal(root: Path, log_dir: Path = DEFAULT_TLIVE_LOG_DIR,
                        manifest_path: Path = DEFAULT_MANIFEST) -> str:
    content, _stats = render_content(root, log_dir, manifest_path)
    css = ARCHIVE_CSS + ARCHIVE2_CSS + ARCHIVE_V2_CSS + EA_DETAIL_CSS + EXTRA_CSS
    bar = f'<div class="render-badge-bar">{render_badge_html()}</div>{RENDER_BADGE_JS}'
    return html_head("DXZ Trading Journal", css) + bar + content + "</body>\n</html>\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    parser.add_argument("--log-dir", default=str(DEFAULT_TLIVE_LOG_DIR))
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--out", default=None)
    args = parser.parse_args(argv)

    set_render_stamp()
    root = Path(args.root).resolve()
    out = Path(args.out) if args.out else root / "dashboards" / "dxz_journal.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    html_txt = render_dxz_journal(root, Path(args.log_dir), Path(args.manifest))
    out.write_text(html_txt, encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
