#!/usr/bin/env python3
"""Preregistered full-DEV stability screen for frozen v5 FX daily-London.

The implementation reuses the frozen sequence builder without changing it.  A
separate loader enforces the 2023 outcome fence, and this layer adds immutable
spread scenarios, the frozen news gate, conservative OHLC execution, exact
dealwise external commission, aggregation, and preregistered merit checks.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, replace
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP, localcontext
from pathlib import Path
from statistics import mean, median
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
TOOLS_ROOT = EA_ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

import audit_frozen_sequence_csv as frozen  # noqa: E402


ANALYSIS_ID = "QM5_20009_V5_FX_DAILY_LONDON_FULL_DEV_STABILITY_001"
CONTRACT_PATH = EA_ROOT / "docs" / "candidate-analysis" / "v5_fx_daily_london_full_dev_stability_contract.json"
CONTRACT_COMMIT = "b8da411fe71792a89731a7d8a043f56acc466e92"
EXPECTED_CONTRACT_SHA256 = "73286511c91ce2c6a7e5a53637bf37075aecd68117b104b8b10b0ad00170751b"
DEFAULT_DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
DEFAULT_NEWS_PATH = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
EXPECTED_NEWS_SHA256 = "8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d"
BROKER_FROM = datetime(2017, 10, 1)
BROKER_TO = datetime(2023, 1, 1)
NY_FROM = date(2017, 10, 1)
NY_TO = date(2022, 12, 31)
FULL_YEARS = tuple(range(2018, 2023))
SCENARIOS = (0, 4, 8)
CENTER_SCENARIO = 4
POINT = 0.00001
TICK_SIZE = 0.00001
RISK_USD = Decimal("1000")
CENT = Decimal("0.01")
NY_ZONE = ZoneInfo("America/New_York")

BOUND_SOURCES = {
    EA_ROOT / "tools" / "audit_frozen_sequence_csv.py": "dda7255c6dcad65a2c8fd9eaa739643661ee2c40c171c401092217157809835f",
    EA_ROOT / "tools" / "audit_mt5_report.py": "c9dc5106383073b50150f0edb091338181dc53470615839fb252f5bc96a46c03",
    EA_ROOT / "tools" / "adjudicate_dev.py": "9d3e9025c6c648afe0a393ee3b4356cd0f7ed05fa8e3728d473a70d52461d401",
    EA_ROOT / "docs" / "strategy_contract.md": "98a500ae4ecb9ed3733199fee137d2c357e4c4b00d9907feb9aae39e783fc688",
    EA_ROOT / "docs" / "research_protocol_v5.json": "b2b7c0861f23b8cf9400023aad66c3d7146a4f047049820f89d0fc8a65af8f54",
    EA_ROOT / "sets" / "QM5_20009_GBPUSD_DWX_M5_fx_center.set": "5e8d41c79a9782e4ae67986436847a152f3908c91470e9b3da61634c9b4f40bd",
    EA_ROOT / "sets" / "QM5_20009_EURUSD_DWX_M5_fx_center.set": "53b3c2a1138fe97d8427b3f93fdb25e2920d39cb2f9e18aa81ee4d2fa6736d4f",
}


class StabilityError(RuntimeError):
    """Fail-closed analysis error."""


@dataclass(frozen=True)
class SliceIdentity:
    path: str
    selected_sha256: str
    selected_rows: int
    first_selected_broker_time: str
    last_selected_broker_time: str
    first_excluded_timestamp: str
    future_ohlc_parsed: bool


@dataclass(frozen=True)
class MarketSlice:
    symbol: str
    bars: tuple[frozen.Bar, ...]
    identity: SliceIdentity


@dataclass(frozen=True)
class Trade:
    scenario_points: int
    symbol: str
    side: str
    ny_date: str
    entry_time_ny: str
    exit_time_ny: str
    entry: float
    stop: float
    target: float
    exit_price: float
    risk_price: float
    rr: float
    lots: float
    gross_r: float
    commission_usd: float
    adjusted_r: float
    exit_reason: str
    same_bar_sl_tp_conflict: bool
    touch_bar_exit: bool


@dataclass
class ScenarioSymbolResult:
    scenario_points: int
    symbol: str
    funnel: Counter[str]
    terminal: Counter[str]
    trades: list[Trade]
    integrity_issues: list[str]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stamp(value: datetime) -> str:
    return value.isoformat(sep=" ", timespec="seconds")


def epoch_of(value: datetime) -> int:
    return int((value - datetime(1970, 1, 1)).total_seconds())


def parse_selected_market(path: Path, symbol: str) -> MarketSlice:
    """Parse only the declared broker-time slice and no future OHLC field."""
    if not path.is_file():
        raise StabilityError(f"market file missing: {path}")
    lower = epoch_of(BROKER_FROM)
    upper = epoch_of(BROKER_TO)
    bars: list[frozen.Bar] = []
    digest = hashlib.sha256()
    prior_timestamp: int | None = None
    first_excluded: str | None = None
    with path.open("r", encoding="ascii", newline="") as handle:
        header = handle.readline().strip("\r\n")
        if header != "time,open,high,low,close,tickvol":
            raise StabilityError(f"unexpected market header in {path}: {header!r}")
        for row_number, raw_line in enumerate(handle, start=2):
            raw_timestamp, separator, _unparsed_tail = raw_line.partition(",")
            if not separator:
                raise StabilityError(f"row {row_number}: missing delimiter")
            try:
                timestamp = int(raw_timestamp)
            except ValueError as exc:
                raise StabilityError(f"row {row_number}: invalid timestamp") from exc
            if prior_timestamp is not None and timestamp <= prior_timestamp:
                raise StabilityError(f"row {row_number}: timestamps not strictly increasing")
            prior_timestamp = timestamp
            if timestamp >= upper:
                first_excluded = stamp(datetime(1970, 1, 1) + timedelta(seconds=timestamp))
                break
            if timestamp < lower:
                continue
            if timestamp % frozen.TIMEFRAME_SECONDS != 0:
                raise StabilityError(f"row {row_number}: selected timestamp not M5-aligned")
            parts = raw_line.strip("\r\n").split(",")
            if len(parts) != 6:
                raise StabilityError(f"row {row_number}: malformed selected row")
            try:
                open_, high, low, close = (float(value) for value in parts[1:5])
                tickvol = int(parts[5])
            except ValueError as exc:
                raise StabilityError(f"row {row_number}: non-numeric selected OHLC") from exc
            values = (open_, high, low, close)
            if (
                not all(math.isfinite(value) and value > 0 for value in values)
                or high < max(open_, low, close)
                or low > min(open_, high, close)
                or tickvol < 0
            ):
                raise StabilityError(f"row {row_number}: invalid selected OHLC")
            broker = datetime(1970, 1, 1) + timedelta(seconds=timestamp)
            ny_time = broker - timedelta(hours=7)
            bars.append(
                frozen.Bar(
                    timestamp=timestamp,
                    broker_time=broker,
                    ny_time=ny_time,
                    open=open_,
                    high=high,
                    low=low,
                    close=close,
                    spread_points=0,
                )
            )
            digest.update(
                f"{timestamp},{parts[1]},{parts[2]},{parts[3]},{parts[4]},{tickvol}\n".encode("ascii")
            )
    if not bars:
        raise StabilityError(f"selected market slice is empty: {path}")
    if first_excluded is None:
        raise StabilityError(f"cannot prove future fence; no >=2023 timestamp: {path}")
    return MarketSlice(
        symbol=symbol,
        bars=tuple(bars),
        identity=SliceIdentity(
            path=str(path.resolve()),
            selected_sha256=digest.hexdigest(),
            selected_rows=len(bars),
            first_selected_broker_time=stamp(bars[0].broker_time),
            last_selected_broker_time=stamp(bars[-1].broker_time),
            first_excluded_timestamp=first_excluded,
            future_ohlc_parsed=False,
        ),
    )


def dataset_for_spread(market: MarketSlice, spread_points: int) -> frozen.Dataset:
    bars = [replace(bar, spread_points=spread_points) for bar in market.bars]
    by_date: dict[date, list[int]] = defaultdict(list)
    by_week: dict[date, list[int]] = defaultdict(list)
    for index, bar in enumerate(bars):
        by_date[bar.ny_date].append(index)
        by_week[frozen._trading_week_key(bar)].append(index)
    return frozen.Dataset(
        bars=bars,
        by_ny_date=dict(by_date),
        by_trading_week=dict(by_week),
        source={"candidate_analysis_selected_slice": market.identity.selected_sha256},
    )


class BlackoutBook:
    def __init__(self, intervals: Mapping[str, Sequence[tuple[datetime, datetime]]]):
        self.rows: dict[str, list[tuple[datetime, datetime]]] = {}
        self.starts: dict[str, list[datetime]] = {}
        for symbol, source in intervals.items():
            merged: list[list[datetime]] = []
            for start, end in sorted(source):
                if merged and start <= merged[-1][1]:
                    if end > merged[-1][1]:
                        merged[-1][1] = end
                else:
                    merged.append([start, end])
            rows = [(row[0], row[1]) for row in merged]
            self.rows[symbol] = rows
            self.starts[symbol] = [row[0] for row in rows]

    def contains(self, symbol: str, value: datetime) -> bool:
        starts = self.starts.get(symbol, [])
        if not starts:
            return False
        index = bisect.bisect_right(starts, value) - 1
        return index >= 0 and self.rows[symbol][index][1] >= value

    def next_start_after(self, symbol: str, value: datetime) -> datetime | None:
        starts = self.starts.get(symbol, [])
        index = bisect.bisect_right(starts, value)
        return starts[index] if index < len(starts) else None


def load_news(path: Path) -> tuple[BlackoutBook, dict[str, Any]]:
    if sha256_file(path) != EXPECTED_NEWS_SHA256:
        raise StabilityError("news source differs from preregistered SHA256")
    relevant = {
        "GBPUSD.DWX": {"GBP", "USD"},
        "EURUSD.DWX": {"EUR", "USD"},
    }
    intervals: dict[str, list[tuple[datetime, datetime]]] = {symbol: [] for symbol in relevant}
    seen: dict[tuple[str, str, str], tuple[str, str]] = {}
    first: datetime | None = None
    last: datetime | None = None
    high_rows = 0
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"datetime", "currency", "event_name", "impact", "is_high_impact"}
        if not required.issubset(reader.fieldnames or []):
            raise StabilityError("news header missing required columns")
        for row_number, row in enumerate(reader, start=2):
            raw_time = (row.get("datetime") or "").strip()
            currency = (row.get("currency") or "").strip().upper()
            event = (row.get("event_name") or "").strip()
            impact = (row.get("impact") or "").strip().lower()
            high = (row.get("is_high_impact") or "").strip()
            if not raw_time or not currency or not event or high not in {"0", "1"}:
                raise StabilityError(f"malformed news row {row_number}")
            key = (raw_time, currency, event)
            material = (impact, high)
            if key in seen and seen[key] != material:
                raise StabilityError(f"conflicting duplicate news row: {key}")
            seen[key] = material
            try:
                utc = datetime.strptime(raw_time, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            except ValueError as exc:
                raise StabilityError(f"invalid news timestamp row {row_number}") from exc
            first = utc if first is None or utc < first else first
            last = utc if last is None or utc > last else last
            if high != "1":
                continue
            high_rows += 1
            ny = utc.astimezone(NY_ZONE).replace(tzinfo=None)
            for symbol, currencies in relevant.items():
                if currency in currencies:
                    intervals[symbol].append((ny - timedelta(minutes=30), ny + timedelta(minutes=30)))
    if first is None or last is None or first.date() > NY_FROM or last.date() < NY_TO:
        raise StabilityError("news calendar does not cover full DEV interval")
    book = BlackoutBook(intervals)
    return book, {
        "path": str(path.resolve()),
        "sha256": EXPECTED_NEWS_SHA256,
        "first_utc": first.isoformat(),
        "last_utc": last.isoformat(),
        "high_impact_rows": high_rows,
        "merged_intervals": {symbol: len(book.rows[symbol]) for symbol in sorted(book.rows)},
    }


def commission_side(volume: Decimal, deal_price: Decimal) -> Decimal:
    rate = max(Decimal("2.50"), Decimal("2.50") * deal_price)
    return (rate * volume).quantize(CENT, rounding=ROUND_HALF_UP)


def execute_outcome(
    dataset: frozen.Dataset,
    result: frozen.SequenceResult,
    touch_index: int,
    scenario_points: int,
    symbol: str,
) -> Trade | None:
    assert result.ny_date is not None
    risk = abs(result.entry - result.stop)
    if risk <= 0:
        return None
    side = "LONG" if result.direction > 0 else "SHORT"
    spread = scenario_points * POINT
    exit_price: float | None = None
    exit_time: datetime | None = None
    exit_reason = ""
    gross_r: float | None = None
    conflict = False
    touch_bar_exit = False
    for index in range(touch_index, len(dataset.bars)):
        bar = dataset.bars[index]
        if bar.ny_date != result.ny_date:
            break
        if bar.ny_minute >= frozen.HARD_FLAT_NY_MINUTE:
            exit_price = bar.open if result.direction > 0 else bar.open + spread
            gross_r = (
                (exit_price - result.entry) / risk
                if result.direction > 0
                else (result.entry - exit_price) / risk
            )
            exit_time = bar.ny_time
            exit_reason = "HARD_FLAT_16_NY"
            touch_bar_exit = index == touch_index
            break
        if result.direction > 0:
            stop_hit = bar.low <= result.stop
            target_hit = bar.high >= result.target
        else:
            stop_hit = bar.high + spread >= result.stop
            target_hit = bar.low + spread <= result.target
        if stop_hit:
            exit_price = result.stop
            gross_r = -1.0
            exit_time = bar.ny_time + timedelta(minutes=5)
            exit_reason = "SL"
            conflict = bool(target_hit)
            touch_bar_exit = index == touch_index
            break
        if target_hit:
            exit_price = result.target
            gross_r = result.rr
            exit_time = bar.ny_time + timedelta(minutes=5)
            exit_reason = "TP"
            touch_bar_exit = index == touch_index
            break
    if exit_price is None or exit_time is None or gross_r is None:
        return None
    volume = RISK_USD / (Decimal(str(risk)) * Decimal("100000"))
    commission = commission_side(volume, Decimal(str(result.entry))) + commission_side(
        volume, Decimal(str(exit_price))
    )
    adjusted_r = gross_r - float(commission / RISK_USD)
    return Trade(
        scenario_points=scenario_points,
        symbol=symbol,
        side=side,
        ny_date=result.ny_date.isoformat(),
        entry_time_ny=stamp(dataset.bars[touch_index].ny_time),
        exit_time_ny=stamp(exit_time),
        entry=result.entry,
        stop=result.stop,
        target=result.target,
        exit_price=exit_price,
        risk_price=risk,
        rr=result.rr,
        lots=float(volume),
        gross_r=gross_r,
        commission_usd=float(commission),
        adjusted_r=adjusted_r,
        exit_reason=exit_reason,
        same_bar_sl_tp_conflict=conflict,
        touch_bar_exit=touch_bar_exit,
    )


def evaluate_symbol_scenario(
    market: MarketSlice,
    scenario_points: int,
    blackouts: BlackoutBook,
) -> ScenarioSymbolResult:
    dataset = dataset_for_spread(market, scenario_points)
    config = frozen.AuditConfig(
        csv_path=Path(market.identity.path),
        symbol=market.symbol,
        mode="daily-london",
        from_ny_date=NY_FROM,
        to_ny_date=NY_TO,
        tick_size=TICK_SIZE,
        point=POINT,
        default_spread_points=scenario_points,
    )
    results, base = frozen._daily_results(dataset, config)
    funnel: Counter[str] = Counter(base)
    terminal: Counter[str] = Counter()
    trades: list[Trade] = []
    integrity: list[str] = []
    for result in results:
        funnel["sequence_results"] += 1
        funnel["consumed"] += int(result.consumed)
        funnel["ambiguous"] += int(result.ambiguous)
        funnel["pivot_confirmed"] += int(result.pivot_index is not None)
        funnel["mss"] += int(result.mss_index is not None)
        funnel["fvg"] += int(result.fvg_index is not None)
        funnel["ready"] += int(result.signal_valid)
        if not result.signal_valid:
            terminal[result.outcome] += 1
            continue
        assert result.fvg_index is not None and result.ny_date is not None
        arm_time = dataset.bars[result.fvg_index].ny_time + timedelta(minutes=5)
        if blackouts.contains(market.symbol, arm_time):
            funnel["news_arm_void"] += 1
            terminal["NEWS_ARM_VOID"] += 1
            continue
        funnel["news_arm_pass"] += 1
        eligibility_index = result.fvg_index + 1
        if eligibility_index >= len(dataset.bars):
            terminal["NO_SUBSEQUENT_ELIGIBILITY_BAR"] += 1
            continue
        session_end = datetime.combine(result.ny_date, time(5, 0))
        next_news = blackouts.next_start_after(market.symbol, arm_time)
        deadline = min(session_end, next_news) if next_news is not None else session_end
        eligibility = dataset.bars[eligibility_index]
        eligibility_close = eligibility.ny_time + timedelta(minutes=5)
        if (
            eligibility.ny_date != result.ny_date
            or eligibility.ny_time >= deadline
            or eligibility_close >= deadline
        ):
            terminal["INTENT_EXPIRED_BEFORE_ELIGIBILITY"] += 1
            continue
        spread = scenario_points * POINT
        fresh = (
            eligibility.open + spread > result.entry
            if result.direction > 0
            else eligibility.open < result.entry
        )
        if not fresh:
            funnel["eligibility_open_void"] += 1
            terminal["EDGE_ALREADY_TOUCHED_AT_ELIGIBILITY_OPEN"] += 1
            continue
        funnel["fresh_at_eligibility"] += 1
        touch_index: int | None = None
        for index in range(eligibility_index, len(dataset.bars)):
            bar = dataset.bars[index]
            bar_close = bar.ny_time + timedelta(minutes=5)
            if bar.ny_date != result.ny_date or bar.ny_time >= deadline or bar_close >= deadline:
                break
            touched = (
                bar.low + spread <= result.entry
                if result.direction > 0
                else bar.high >= result.entry
            )
            if touched:
                touch_index = index
                break
        if touch_index is None:
            funnel["intent_expired"] += 1
            terminal["INTENT_EXPIRED_SESSION_OR_NEWS"] += 1
            continue
        funnel["touched"] += 1
        trade = execute_outcome(dataset, result, touch_index, scenario_points, market.symbol)
        if trade is None:
            issue = f"{market.symbol} spread={scenario_points} {result.ny_date}: unresolved filled trade"
            integrity.append(issue)
            terminal["FILLED_UNRESOLVED"] += 1
            continue
        if date.fromisoformat(trade.ny_date) != datetime.fromisoformat(trade.exit_time_ny).date():
            issue = f"{market.symbol} spread={scenario_points} {trade.ny_date}: cross-NY-date exposure"
            integrity.append(issue)
            terminal["FILLED_CROSS_DATE"] += 1
            continue
        trades.append(trade)
        funnel["fills"] += 1
        funnel[f"exit_{trade.exit_reason.lower()}"] += 1
        funnel["same_bar_sl_tp_conflicts"] += int(trade.same_bar_sl_tp_conflict)
        funnel["touch_bar_exits"] += int(trade.touch_bar_exit)
        terminal[f"FILLED_{trade.exit_reason}"] += 1
    if sum(terminal.values()) != len(results):
        integrity.append(
            f"{market.symbol} spread={scenario_points}: terminal total {sum(terminal.values())} != {len(results)}"
        )
    return ScenarioSymbolResult(
        scenario_points=scenario_points,
        symbol=market.symbol,
        funnel=funnel,
        terminal=terminal,
        trades=trades,
        integrity_issues=integrity,
    )


def profit_factor(values: Sequence[float]) -> float | None:
    gains = sum(value for value in values if value > 0)
    losses = -sum(value for value in values if value < 0)
    return gains / losses if losses > 0 else None


def max_drawdown(values: Sequence[float]) -> float:
    equity = 0.0
    peak = 0.0
    worst = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        worst = max(worst, peak - equity)
    return worst


def metrics(trades: Sequence[Trade]) -> dict[str, Any]:
    ordered = sorted(trades, key=lambda trade: (trade.exit_time_ny, trade.symbol))
    gross = [trade.gross_r for trade in ordered]
    adjusted = [trade.adjusted_r for trade in ordered]
    winners = sorted((value for value in adjusted if value > 0), reverse=True)
    gross_profit = sum(winners)
    return {
        "fills": len(ordered),
        "gross_net_r": sum(gross),
        "gross_pf": profit_factor(gross),
        "commission_usd": sum(trade.commission_usd for trade in ordered),
        "adjusted_net_r": sum(adjusted),
        "adjusted_pf": profit_factor(adjusted),
        "adjusted_expectancy_r": mean(adjusted) if adjusted else None,
        "adjusted_median_r": median(adjusted) if adjusted else None,
        "adjusted_win_rate": sum(value > 0 for value in adjusted) / len(adjusted) if adjusted else None,
        "max_adjusted_drawdown_r": max_drawdown(adjusted),
        "top_one_adjusted_winner_share": winners[0] / gross_profit if gross_profit else None,
        "top_two_adjusted_winner_share": sum(winners[:2]) / gross_profit if gross_profit else None,
        "leave_best_out_adjusted_net_r": sum(adjusted) - max(adjusted) if adjusted else None,
        "same_bar_sl_tp_conflicts": sum(trade.same_bar_sl_tp_conflict for trade in ordered),
        "touch_bar_exits": sum(trade.touch_bar_exit for trade in ordered),
    }


def grouped_metrics(
    trades: Sequence[Trade], key_fn: Any, expected: Iterable[str] = ()
) -> dict[str, dict[str, Any]]:
    groups: dict[str, list[Trade]] = {key: [] for key in expected}
    for trade in trades:
        groups.setdefault(str(key_fn(trade)), []).append(trade)
    return {key: metrics(groups[key]) for key in sorted(groups)}


def dynamic_pf_floor(trade_count: int) -> float | None:
    if trade_count <= 0:
        return None
    with localcontext() as context:
        context.prec = 50
        n = Decimal(trade_count)
        u = Decimal("1.94") / n.sqrt()
        d = u / (Decimal(1) + u * u).sqrt()
        return float(max(Decimal("1.10"), (Decimal(1) + d) / (Decimal(1) - d)))


def scenario_performance(trades: Sequence[Trade]) -> dict[str, Any]:
    symbols = ("EURUSD.DWX", "GBPUSD.DWX")
    sides = ("LONG", "SHORT")
    years = tuple(str(year) for year in range(2017, 2023))
    return {
        "pooled": metrics(trades),
        "by_symbol": grouped_metrics(trades, lambda trade: trade.symbol, symbols),
        "by_side": grouped_metrics(trades, lambda trade: trade.side, sides),
        "by_year": grouped_metrics(trades, lambda trade: trade.ny_date[:4], years),
        "by_symbol_year": grouped_metrics(
            trades,
            lambda trade: f"{trade.symbol}:{trade.ny_date[:4]}",
            (f"{symbol}:{year}" for symbol in symbols for year in years),
        ),
        "by_symbol_side": grouped_metrics(
            trades,
            lambda trade: f"{trade.symbol}:{trade.side}",
            (f"{symbol}:{side}" for symbol in symbols for side in sides),
        ),
    }


def merit(performance: Mapping[str, Any], integrity_pass: bool) -> dict[str, Any]:
    center = performance[str(CENTER_SCENARIO)]
    stress = performance["8"]
    pooled = center["pooled"]
    by_symbol = center["by_symbol"]
    by_side = center["by_side"]
    by_year = center["by_year"]
    floor = dynamic_pf_floor(pooled["fills"])
    checks = {
        "integrity_pass": integrity_pass,
        "center_pooled_fills_min_60": pooled["fills"] >= 60,
        "center_each_symbol_fills_min_30": all(by_symbol[symbol]["fills"] >= 30 for symbol in by_symbol),
        "center_each_side_fills_min_20": all(by_side[side]["fills"] >= 20 for side in by_side),
        "center_pooled_adjusted_net_positive": pooled["adjusted_net_r"] > 0,
        "center_pooled_adjusted_pf_dynamic_floor": floor is not None
        and pooled["adjusted_pf"] is not None
        and pooled["adjusted_pf"] >= floor,
        "center_each_symbol_adjusted_net_positive": all(
            by_symbol[symbol]["adjusted_net_r"] > 0 for symbol in by_symbol
        ),
        "center_each_side_adjusted_net_positive": all(
            by_side[side]["adjusted_net_r"] > 0 for side in by_side
        ),
        "center_pooled_positive_full_years_min_3": sum(
            by_year[str(year)]["adjusted_net_r"] > 0 for year in FULL_YEARS
        )
        >= 3,
        "center_each_symbol_positive_full_years_min_2": all(
            sum(
                center["by_symbol_year"][f"{symbol}:{year}"]["adjusted_net_r"] > 0
                for year in FULL_YEARS
            )
            >= 2
            for symbol in by_symbol
        ),
        "center_pooled_max_adjusted_drawdown_r_max_25": pooled["max_adjusted_drawdown_r"] <= 25,
        "center_each_symbol_max_adjusted_drawdown_r_max_25": all(
            by_symbol[symbol]["max_adjusted_drawdown_r"] <= 25 for symbol in by_symbol
        ),
        "center_top_two_winner_share_max_0_5": pooled["top_two_adjusted_winner_share"] is not None
        and pooled["top_two_adjusted_winner_share"] <= 0.5,
        "center_leave_best_out_adjusted_net_positive": pooled["leave_best_out_adjusted_net_r"] is not None
        and pooled["leave_best_out_adjusted_net_r"] > 0,
        "spread8_pooled_adjusted_net_positive": stress["pooled"]["adjusted_net_r"] > 0,
        "spread8_pooled_adjusted_pf_min_1": stress["pooled"]["adjusted_pf"] is not None
        and stress["pooled"]["adjusted_pf"] >= 1.0,
        "spread8_each_symbol_adjusted_net_positive": all(
            stress["by_symbol"][symbol]["adjusted_net_r"] > 0 for symbol in stress["by_symbol"]
        ),
    }
    return {
        "decision": "MERIT" if all(checks.values()) else "NO_MERIT",
        "dynamic_pf_floor": floor,
        "adjusted_pf_ge_1_2_proxy": pooled["adjusted_pf"] is not None and pooled["adjusted_pf"] >= 1.2,
        "checks": checks,
        "failed": [name for name, passed in checks.items() if not passed],
    }


def eur_representativeness(center_trades: Sequence[Trade]) -> dict[str, Any]:
    eur = [trade for trade in center_trades if trade.symbol == "EURUSD.DWX"]
    prior = [trade for trade in eur if 2018 <= int(trade.ny_date[:4]) <= 2021]
    year_metrics = grouped_metrics(
        prior, lambda trade: trade.ny_date[:4], (str(year) for year in range(2018, 2022))
    )
    prior_metrics = metrics(prior)
    all_metrics = metrics(eur)
    positive_all = sum(trade.adjusted_r for trade in eur if trade.adjusted_r > 0)
    positive_2022 = sum(
        trade.adjusted_r for trade in eur if trade.ny_date.startswith("2022") and trade.adjusted_r > 0
    )
    share = positive_2022 / positive_all if positive_all > 0 else None
    checks = {
        "eur_2018_2021_adjusted_net_positive": prior_metrics["adjusted_net_r"] > 0,
        "eur_2018_2021_adjusted_pf_min_1_2": prior_metrics["adjusted_pf"] is not None
        and prior_metrics["adjusted_pf"] >= 1.2,
        "eur_positive_prior_full_years_min_2": sum(
            year_metrics[str(year)]["adjusted_net_r"] > 0 for year in range(2018, 2022)
        )
        >= 2,
        "eur_leave_2022_out_adjusted_net_positive": prior_metrics["adjusted_net_r"] > 0,
        "eur_2022_positive_profit_share_max_0_5": share is not None and share <= 0.5,
    }
    return {
        "decision": "REPRESENTATIVE" if all(checks.values()) else "NOT_REPRESENTATIVE",
        "checks": checks,
        "failed": [name for name, passed in checks.items() if not passed],
        "prior_2018_2021": prior_metrics,
        "year_2022": metrics([trade for trade in eur if trade.ny_date.startswith("2022")]),
        "all_eur": all_metrics,
        "prior_by_year": year_metrics,
        "year_2022_share_of_all_eur_adjusted_gross_profit": share,
    }


def verify_bound_sources() -> dict[str, str]:
    observed: dict[str, str] = {}
    for path, expected in BOUND_SOURCES.items():
        digest = sha256_file(path)
        if digest != expected:
            raise StabilityError(f"bound source drift: {path}")
        observed[str(path.relative_to(REPO_ROOT)).replace("\\", "/")] = digest
    return observed


def build_document(data_root: Path, news_path: Path) -> dict[str, Any]:
    if sha256_file(CONTRACT_PATH) != EXPECTED_CONTRACT_SHA256:
        raise StabilityError("candidate-analysis contract hash drift")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if contract.get("analysis_id") != ANALYSIS_ID:
        raise StabilityError("candidate-analysis id drift")
    source_hashes = verify_bound_sources()
    blackouts, news_identity = load_news(news_path)
    markets = [
        parse_selected_market(data_root / f"{symbol}_M5.csv", symbol)
        for symbol in ("GBPUSD.DWX", "EURUSD.DWX")
    ]
    results: list[ScenarioSymbolResult] = []
    for scenario in SCENARIOS:
        for market in markets:
            results.append(evaluate_symbol_scenario(market, scenario, blackouts))
    integrity_issues = [issue for result in results for issue in result.integrity_issues]
    performance: dict[str, Any] = {}
    all_trades_by_scenario: dict[int, list[Trade]] = {}
    for scenario in SCENARIOS:
        trades = sorted(
            (trade for result in results if result.scenario_points == scenario for trade in result.trades),
            key=lambda trade: (trade.exit_time_ny, trade.symbol),
        )
        all_trades_by_scenario[scenario] = trades
        performance[str(scenario)] = scenario_performance(trades)
    integrity_pass = not integrity_issues
    document = {
        "schema_version": 1,
        "analysis_id": ANALYSIS_ID,
        "status": "PASS" if integrity_pass else "FAIL",
        "admissibility": "FULL_DEV_DIAGNOSTIC_ONLY_NOT_OOS_NOT_PIPELINE_NOT_FTMO",
        "identity": {
            "contract_commit": CONTRACT_COMMIT,
            "contract_path": str(CONTRACT_PATH),
            "contract_sha256": EXPECTED_CONTRACT_SHA256,
            "tool_path": str(TOOL_PATH),
            "tool_sha256": sha256_file(TOOL_PATH),
            "bound_sources": source_hashes,
            "news": news_identity,
            "market": {market.symbol: vars(market.identity) for market in markets},
            "future_ohlc_parsed": False,
        },
        "integrity": {"status": "PASS" if integrity_pass else "FAIL", "issues": integrity_issues},
        "spread_scenarios": {
            "points": list(SCENARIOS),
            "center_points": CENTER_SCENARIO,
            "point_size": POINT,
            "selection": "FORBIDDEN",
        },
        "funnel": {
            str(scenario): {
                result.symbol: dict(sorted(result.funnel.items()))
                for result in results
                if result.scenario_points == scenario
            }
            for scenario in SCENARIOS
        },
        "terminal_states": {
            str(scenario): {
                result.symbol: dict(sorted(result.terminal.items()))
                for result in results
                if result.scenario_points == scenario
            }
            for scenario in SCENARIOS
        },
        "performance": performance,
        "merit": merit(performance, integrity_pass),
        "eur_2022_temporal_representativeness": eur_representativeness(
            all_trades_by_scenario[CENTER_SCENARIO]
        ),
        "trades": {
            str(scenario): [vars(trade) for trade in all_trades_by_scenario[scenario]]
            for scenario in SCENARIOS
        },
        "limitations": [
            "M5_OHLC_CONSERVATIVE_ORDERING_NOT_TICKS",
            "FIXED_SPREAD_SCENARIOS_NOT_HISTORICAL_VARIABLE_BID_ASK",
            "SLIPPAGE_AND_VOLUME_STEP_MARGIN_CAP_NOT_MODELLED",
            "FULL_DEV_ONLY_2022_ALREADY_KNOWN_NOT_OOS_OR_HOLDOUT",
            "NO_PARAMETER_OR_SYMBOL_OR_SIDE_SELECTION_ALLOWED",
        ],
    }
    return document


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--news", type=Path, default=DEFAULT_NEWS_PATH)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        document = build_document(args.data_root, args.news)
        payload = json.dumps(document, indent=2, sort_keys=True, allow_nan=False) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(payload, encoding="utf-8", newline="\n")
        else:
            sys.stdout.write(payload)
        return 0 if document["status"] == "PASS" else 2
    except (StabilityError, frozen.AuditError, OSError, csv.Error, ValueError, json.JSONDecodeError) as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
