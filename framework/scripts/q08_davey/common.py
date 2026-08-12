"""Shared utilities for the Q08 Davey sub-gates."""

from __future__ import annotations

import datetime as dt
import html
import json
import math
import re
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


def load_equity_stream(log_path: Path, *, symbol: str | None = None) -> list[dict]:
    """Extract one snapshot per emitter symbol/day from an EA JSON-lines log.

    Historical ``EQUITY_SNAPSHOT`` rows predate the explicit ``scope`` field,
    but their equity and P&L values already came from ``ACCOUNT_EQUITY``.  They
    are therefore normalized to account scope.  Tester-agent log filenames are
    per EA rather than per symbol, so callers evaluating one symbol must pass
    ``symbol`` to avoid consuming rows appended by another run of the same EA.
    """
    if not log_path.exists():
        return []
    snaps_by_emitter_day: dict[tuple[str, int], dict] = {}
    undated_snaps: list[dict] = []
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
            if not isinstance(payload, dict):
                continue

            normalized = dict(payload)
            if not isinstance(normalized.get("scope"), str) or not normalized["scope"]:
                normalized["scope"] = "account"

            payload_symbol = normalized.get("symbol")
            row_symbol = row.get("symbol")
            emitter_symbol = (
                payload_symbol if isinstance(payload_symbol, str) and payload_symbol
                else row_symbol if isinstance(row_symbol, str) and row_symbol
                else ""
            )
            if symbol is not None and emitter_symbol != symbol:
                continue
            if emitter_symbol and not normalized.get("symbol"):
                normalized["symbol"] = emitter_symbol

            try:
                day_key = int(normalized.get("day_key"))
            except (TypeError, ValueError):
                undated_snaps.append(normalized)
                continue

            if not emitter_symbol:
                undated_snaps.append(normalized)
                continue

            dedupe_key = (emitter_symbol, day_key)
            # Delete before replacement so result ordering follows the final
            # append occurrence as well as its value (last-write semantics).
            snaps_by_emitter_day.pop(dedupe_key, None)
            snaps_by_emitter_day[dedupe_key] = normalized
    return [*snaps_by_emitter_day.values(), *undated_snaps]


def _float_report(value) -> float | None:
    if value is None:
        return None
    text = str(value).strip().replace("\xa0", " ").replace(" ", "").replace(",", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def load_trades_from_mt5_report(report_path: Path) -> list[dict]:
    """Extract closing deals from MT5 Strategy Tester HTML reports.

    Q08's preferred source is the Common\Files TRADE_CLOSED stream. Older EAs
    and some tester exits can still produce a valid HTML report while skipping
    that stream, so this is the deterministic fallback.
    """
    report_path = Path(report_path)
    if not report_path.exists():
        return []
    raw = report_path.read_bytes()
    encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
    text = raw.decode(encoding, errors="ignore")
    match = re.search(r"<b>\s*Deals\s*</b>", text, flags=re.IGNORECASE)
    if not match:
        # G17 (2026-07-06): German-locale terminals title the deals table
        # "Trades" (verified on a real T2/T6 report, QM5_10440); English
        # reports have no standalone bold "Trades" section, so the fallback
        # is unambiguous. Without it the report-fallback path returned "no
        # trades" — evidence — on every German report.
        match = re.search(r"<b>\s*Trades\s*</b>", text, flags=re.IGNORECASE)
    if not match:
        return []
    section = text[match.start():]
    trades: list[dict] = []
    for row_html in re.findall(r"<tr[^>]*>(.*?)</tr>", section, flags=re.IGNORECASE | re.DOTALL):
        cells = []
        for cell_html in re.findall(r"<td[^>]*>(.*?)</td>", row_html, flags=re.IGNORECASE | re.DOTALL):
            cell = re.sub(r"<[^>]+>", "", cell_html)
            cells.append(html.unescape(cell).strip())
        if len(cells) < 11:
            continue
        if not cells[4].lower().startswith("out"):
            continue
        try:
            close_ts = dt.datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S").replace(tzinfo=dt.UTC)
        except ValueError:
            continue
        profit = _float_report(cells[10])
        if profit is None:
            continue
        commission = _float_report(cells[8]) or 0.0
        swap = _float_report(cells[9]) or 0.0
        trades.append({
            "event": "TRADE_CLOSED",
            "ts_utc": close_ts.isoformat(),
            "time": int(close_ts.timestamp()),
            "net": profit + commission + swap,
            "profit": profit,
            "swap": swap,
            "commission": commission,
        })
    return trades


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


def parse_ts(ts) -> dt.datetime | None:
    if ts is None or ts == "":
        return None
    if isinstance(ts, (int, float)):
        try:
            # MT5/FW trade emitters use epoch seconds; tolerate millis too.
            value = float(ts)
            if value > 10_000_000_000:
                value = value / 1000.0
            return dt.datetime.fromtimestamp(value, tz=dt.UTC)
        except (OSError, OverflowError, ValueError):
            return None
    try:
        s = str(ts).replace("Z", "+00:00")
        if s.isdigit():
            return parse_ts(int(s))
        return dt.datetime.fromisoformat(s)
    except (ValueError, AttributeError):
        return None


def trade_timestamp(trade: dict) -> dt.datetime | None:
    """Return a close timestamp from any trade-log schema currently emitted."""
    for key in ("ts_utc", "close_ts", "close_time", "time", "timestamp", "ts"):
        ts = parse_ts(trade.get(key))
        if ts is not None:
            return ts
    return None


def make_result(name: str, status: str, value, threshold, detail: str,
                evidence: dict | None = None) -> dict:
    """Standard Q08 sub-gate result shape."""
    normalized_status = str(status).upper()
    return {
        "name": name,
        "status": normalized_status,
        "passed": normalized_status == "PASS",
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
