"""Shared utilities for the Q08 Davey sub-gates."""

from __future__ import annotations

import datetime as dt
import json
import math
import statistics
from pathlib import Path


def load_trades_from_log(log_path: Path, magic: int | None = None) -> list[dict]:
    """Extract per-trade rows from an EA JSON-lines log.

    Trades are detected from `ENTRY_ACCEPTED` + matching close events. For
    Q08 we need closing-deal net profit (post-commission, post-swap). The
    framework's OnTradeTransaction wrapper emits closing-deal data into
    the log under event=KS_DISTRIBUTION_DIVERGENCE only when divergence
    fires — so we instead scan EXIT_REASON / EQUITY_SNAPSHOT events plus
    parse PositionGetDouble outputs from the close path.

    Practical implementation: trades come from a downstream emitter that
    reads MT5 history deals after the Q10 backtest completes. This helper
    reads that emitter's per-trade JSON.
    """
    if not log_path.exists():
        return []
    trades: list[dict] = []
    with log_path.open(encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("event") not in ("TRADE_CLOSED", "DEAL_CLOSED"):
                continue
            if magic is not None and row.get("magic") not in (magic, str(magic)):
                continue
            trades.append(row.get("payload", row))
    return trades


def load_equity_stream(log_path: Path) -> list[dict]:
    """Extract EQUITY_SNAPSHOT events from an EA JSON-lines log."""
    if not log_path.exists():
        return []
    snaps: list[dict] = []
    with log_path.open(encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("event") != "EQUITY_SNAPSHOT":
                continue
            payload = row.get("payload", {})
            if isinstance(payload, str):
                try:
                    payload = json.loads(payload)
                except json.JSONDecodeError:
                    continue
            snaps.append(payload)
    return snaps


def trade_net_profits(trades: list[dict]) -> list[float]:
    """Per-trade net profit (profit + swap + commission)."""
    out: list[float] = []
    for t in trades:
        try:
            v = float(t.get("net", t.get("profit", 0)) or 0)
            out.append(v)
        except (TypeError, ValueError):
            continue
    return out


def profit_factor(profits: list[float]) -> float | None:
    """Sum(wins) / |Sum(losses)|; None if all trades zero or no losses."""
    wins = sum(p for p in profits if p > 0)
    losses = abs(sum(p for p in profits if p < 0))
    if losses == 0:
        return None if wins == 0 else float("inf")
    return wins / losses


def parse_ts(ts: str) -> dt.datetime | None:
    if not ts:
        return None
    try:
        s = ts.replace("Z", "+00:00")
        return dt.datetime.fromisoformat(s)
    except (ValueError, AttributeError):
        return None


def make_result(name: str, status: str, value, threshold, detail: str,
                evidence: dict | None = None) -> dict:
    """Standard Q08 sub-gate result shape."""
    return {
        "name": name,
        "status": status,
        "value": value,
        "threshold": threshold,
        "detail": detail,
        "evidence": evidence or {},
    }


def mean_std(values: list[float]) -> tuple[float, float]:
    if not values:
        return 0.0, 0.0
    mu = statistics.fmean(values)
    sd = statistics.pstdev(values) if len(values) > 1 else 0.0
    return mu, sd
