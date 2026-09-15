"""FTMO Demo account + sleeve metrics from the demo terminal journal (read-only).

Directive 2026-09-15 section 16 (OWNER-DEC-CBE-20260915): measure the Demo at
account and sleeve level. This parses the normalized deal journal exported by
the existing telemetry (`live_deals_normalized.csv`) and computes the metrics the
journal deterministically supports. Everything it cannot derive from the journal
is reported as NOT_APPLICABLE / EVIDENCE_MISSING with the exporter that would
supply it - never invented.

Read-only: opens the CSV, nothing else. No MT5 start, no trade, no DB write.
"""
from __future__ import annotations

import csv
import datetime as dt
from pathlib import Path
from typing import Any

DEFAULT_JOURNAL = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\journal\live_deals_normalized.csv"
)
INITIAL_BALANCE = 100_000.0

# Metrics the raw deal journal cannot supply; each names the exporter needed.
_EXPORTER_GAPS = {
    "intratrade_equity": "tick/interval mark-to-market export (ftmo_trial_collector high-frequency equity)",
    "spread_cost": "per-symbol spread export from MT5 Market Watch specification",
    "slippage_proxy": "requested-vs-fill price export (order send/fill telemetry)",
    "open_risk_timeseries": "per-bar open-position risk snapshot exporter",
    "session_behaviour": "session-tagged deal export (broker-time session bucketing)",
    "news_behaviour": "calendar-joined deal export (news-window tagging)",
    "gap_exposure": "weekend/overnight gap export (bar-open vs prior-close)",
}


def _f(v: Any, default: float = 0.0) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def load_journal(path: Path = DEFAULT_JOURNAL) -> list[dict[str, str]] | None:
    p = Path(path)
    if not p.is_file():
        return None
    with p.open(encoding="utf-8", errors="replace", newline="") as fh:
        return list(csv.DictReader(fh))


def _parse_ts(v: str) -> dt.datetime | None:
    if not v:
        return None
    try:
        return dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    except ValueError:
        return None


def split_cycles(rows: list[dict[str, str]]) -> list[list[dict[str, str]]]:
    """Split on each BALANCE deposit (account reset) into cycles."""
    cycles: list[list[dict[str, str]]] = []
    current: list[dict[str, str]] = []
    for r in rows:
        if str(r.get("type", "")).upper() == "BALANCE":
            if current:
                cycles.append(current)
            current = []
            continue
        current.append(r)
    if current:
        cycles.append(current)
    return cycles


def compute_cycle_metrics(cycle_rows: list[dict[str, str]], initial: float = INITIAL_BALANCE) -> dict[str, Any]:
    """Deterministic per-cycle account metrics from OUT legs (realized)."""
    out_legs = [r for r in cycle_rows if str(r.get("entry", "")).upper() == "OUT"]
    in_legs = [r for r in cycle_rows if str(r.get("entry", "")).upper() == "IN"]
    if not out_legs:
        return {
            "closed_trades": 0,
            "net_usd": 0.0,
            "net_pct": 0.0,
            "note": "no closed trades in cycle",
        }

    def _ts_key(r):
        return _parse_ts(r.get("time_utc", "")) or dt.datetime.min.replace(tzinfo=dt.timezone.utc)

    out_legs_sorted = sorted(out_legs, key=_ts_key)

    equity = initial
    peak = initial
    max_dd = 0.0
    daily_pnl: dict[str, float] = {}
    entry_days: set[str] = set()
    swap_total = 0.0
    comm_total = 0.0
    per_symbol: dict[str, float] = {}
    net_total = 0.0
    losing_streak = 0
    losing_streak_max = 0
    holding_secs: list[float] = []
    in_by_pos = {r.get("position_id"): r for r in in_legs}

    for r in out_legs_sorted:
        net = _f(r.get("net_actual"), _f(r.get("profit")))
        net_total += net
        equity += net
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)  # negative
        swap_total += _f(r.get("swap"))
        comm_total += _f(r.get("commission")) + _f(r.get("fee"))
        sym = r.get("symbol") or "UNKNOWN"
        per_symbol[sym] = per_symbol.get(sym, 0.0) + net
        ts = _parse_ts(r.get("time_utc", ""))
        if ts:
            day = ts.date().isoformat()
            daily_pnl[day] = daily_pnl.get(day, 0.0) + net
        if net < 0:
            losing_streak += 1
            losing_streak_max = max(losing_streak_max, losing_streak)
        else:
            losing_streak = 0
        # holding time from IN leg of the same position
        in_leg = in_by_pos.get(r.get("position_id"))
        if in_leg:
            t0, t1 = _parse_ts(in_leg.get("time_utc", "")), ts
            if t0 and t1 and t1 >= t0:
                holding_secs.append((t1 - t0).total_seconds())

    for r in in_legs:
        ts = _parse_ts(r.get("time_utc", ""))
        if ts:
            entry_days.add(ts.date().isoformat())

    worst_day = min(daily_pnl.values()) if daily_pnl else 0.0
    holding_med = (
        round(sorted(holding_secs)[len(holding_secs) // 2] / 3600.0, 3) if holding_secs else None
    )
    return {
        "closed_trades": len(out_legs),
        "entry_trading_days": len(entry_days),
        "net_usd": round(net_total, 2),
        "net_pct": round(100.0 * net_total / initial, 4),
        "worst_day_usd": round(worst_day, 2),
        "worst_day_pct": round(100.0 * worst_day / initial, 4),
        "realized_max_dd_usd": round(max_dd, 2),
        "realized_max_dd_pct": round(100.0 * max_dd / initial, 4),
        "losing_streak_max": losing_streak_max,
        "swap_total_usd": round(swap_total, 2),
        "commission_total_usd": round(comm_total, 2),
        "median_holding_hours": holding_med,
        "per_symbol_net_usd": {k: round(v, 2) for k, v in sorted(per_symbol.items())},
        "target_progress_pct": round(100.0 * net_total / initial / 10.0 * 100.0, 2),
    }


def compute_demo_metrics(rows: list[dict[str, str]] | None, initial: float = INITIAL_BALANCE) -> dict[str, Any]:
    """Account + per-cycle metrics, or EVIDENCE_MISSING when the journal is absent."""
    if not rows:
        return {
            "status": "EVIDENCE_MISSING",
            "reason": "demo journal not readable",
            "exporter_needed": "ftmo_trial_collector -> live_deals_normalized.csv (already installed); "
            "confirm the terminal telemetry EA is writing the journal",
        }
    cycles = split_cycles(rows)
    cycle_metrics = [compute_cycle_metrics(c, initial) for c in cycles]
    latest = cycle_metrics[-1] if cycle_metrics else {}
    return {
        "status": "OK",
        "cycle_count": len(cycles),
        "cycles": cycle_metrics,
        "latest_cycle": latest,
        "exporter_gaps": _EXPORTER_GAPS,
    }


def build(journal_path: Path = DEFAULT_JOURNAL, initial: float = INITIAL_BALANCE) -> dict[str, Any]:
    return compute_demo_metrics(load_journal(journal_path), initial)
