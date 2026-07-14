"""Causal M15 strategy-family screen for independent FTMO return density.

All source timestamps are Darwinex broker-wall epochs and are converted to UTC
before session mapping. Candidate selection uses 2018-2022 development plus
2023 validation. Only one locked winner per family is opened on 2024-2025.
Intrabar ambiguities are resolved pessimistically, including dual OCO touches.
"""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore


EVIDENCE_END_YEAR = 2025

_ARRAY_CACHE: dict[int, dict[str, np.ndarray]] = {}
_SESSION_CACHE: dict[tuple[int, str, int, int], list[list[int]]] = {}


@dataclass(frozen=True)
class Instrument:
    symbol: str
    path: Path
    timezone: str
    session_start_minute: int
    session_end_minute: int
    round_trip_cost_points: float


def _values(frame: pd.DataFrame, column: str) -> np.ndarray:
    arrays = _ARRAY_CACHE.setdefault(id(frame), {})
    if column not in arrays:
        arrays[column] = frame[column].to_numpy()
    return arrays[column]


def load_bars(instrument: Instrument) -> pd.DataFrame:
    frame = pd.read_csv(instrument.path).sort_values("time").reset_index(drop=True)
    required = {"time", "open", "high", "low", "close"}
    if not required.issubset(frame.columns):
        missing = sorted(required - set(frame.columns))
        raise ValueError(f"{instrument.path}: missing columns {missing}")
    frame["utc"] = base.broker_wall_seconds_to_utc(frame["time"])
    frame["local"] = frame["utc"].dt.tz_convert(instrument.timezone)
    frame["local_date"] = frame["local"].dt.date
    frame["year"] = frame["local"].dt.year
    frame["weekday"] = frame["local"].dt.weekday
    frame["minute"] = frame["local"].dt.hour * 60 + frame["local"].dt.minute
    previous_close = frame["close"].shift(1)
    true_range = np.maximum(
        frame["high"] - frame["low"],
        np.maximum(abs(frame["high"] - previous_close), abs(frame["low"] - previous_close)),
    )
    frame["atr56"] = pd.Series(true_range).rolling(56, min_periods=56).mean()
    return frame


def session_days(frame: pd.DataFrame, instrument: Instrument) -> list[list[int]]:
    cache_key = (
        id(frame),
        instrument.timezone,
        instrument.session_start_minute,
        instrument.session_end_minute,
    )
    if cache_key in _SESSION_CACHE:
        return _SESSION_CACHE[cache_key]
    weekdays = frame[frame["weekday"] < 5]
    minute = _values(frame, "minute")
    days: list[list[int]] = []
    for _, group in weekdays.groupby("local_date", sort=True):
        indices = [
            int(index)
            for index in group.index
            if instrument.session_start_minute <= int(minute[index])
            < instrument.session_end_minute
        ]
        if indices and int(minute[indices[0]]) == instrument.session_start_minute:
            days.append(indices)
    _SESSION_CACHE[cache_key] = days
    return days


def contiguous_opening_indices(
    frame: pd.DataFrame,
    indices: Sequence[int],
    start_minute: int,
    count: int,
) -> list[int] | None:
    if count <= 0 or len(indices) < count:
        return None
    minutes = _values(frame, "minute")
    opening = list(indices[:count])
    expected = [start_minute + 15 * offset for offset in range(count)]
    actual = [int(minutes[index]) for index in opening]
    return opening if actual == expected else None


def make_trade(
    frame: pd.DataFrame,
    *,
    entry_index: int,
    path_indices: Sequence[int],
    side: int,
    entry_price: float,
    stop_distance: float,
    target_r: float,
    round_trip_cost_points: float,
    entry_reason: str,
) -> base.Trade | None:
    if side not in (-1, 1) or entry_price <= 0.0 or stop_distance <= 0.0 or target_r <= 0.0:
        return None
    if entry_index not in path_indices:
        return None
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    utc_values = _values(frame, "utc")
    local_dates = _values(frame, "local_date")
    years = _values(frame, "year")
    stop = entry_price - side * stop_distance
    target = entry_price + side * stop_distance * target_r
    cost_r = round_trip_cost_points / stop_distance
    reason = "time"
    result_r = 0.0
    started = False
    for index in path_indices:
        if index == entry_index:
            started = True
        if not started:
            continue
        high = float(highs[index])
        low = float(lows[index])
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = high >= target if side > 0 else low <= target
        if stop_hit:
            result_r = -1.0 - cost_r
            reason = "stop_pessimistic" if target_hit else "stop"
            break
        if target_hit:
            result_r = target_r - cost_r
            reason = "target"
            break
    else:
        exit_price = float(closes[path_indices[-1]])
        result_r = side * (exit_price - entry_price) / stop_distance - cost_r

    utc = utc_values[entry_index]
    local_date = local_dates[entry_index]
    return base.Trade(
        entry_time_utc=utc.isoformat(),
        local_date=str(local_date),
        year=int(years[entry_index]),
        side=side,
        r_multiple=float(result_r),
        exit_reason=f"{entry_reason}:{reason}",
    )


def opening_range_breakout(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_bars: int,
    active_bars: int,
    buffer_atr: float,
    max_range_atr: float,
    target_r: float,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    atrs = _values(frame, "atr56")
    for indices in session_days(frame, instrument):
        opening = contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, range_bars
        )
        if opening is None or len(indices) <= range_bars:
            continue
        atr = float(atrs[opening[-1]])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        range_high = float(max(highs[index] for index in opening))
        range_low = float(min(lows[index] for index in opening))
        range_width = range_high - range_low
        if range_width <= 0.0 or range_width > max_range_atr * atr:
            continue
        buffer = buffer_atr * atr
        long_entry = range_high + buffer
        short_entry = range_low - buffer
        pending = indices[range_bars : range_bars + active_bars]
        for trigger_index in pending:
            long_hit = float(highs[trigger_index]) >= long_entry
            short_hit = float(lows[trigger_index]) <= short_entry
            if not long_hit and not short_hit:
                continue
            # If both sides touch in one M15 bar, force the long-side stop.
            # Since short_entry is below range_low, the long stop also touched.
            side = 1 if long_hit else -1
            entry_price = long_entry if side > 0 else short_entry
            trade = make_trade(
                frame,
                entry_index=trigger_index,
                path_indices=indices,
                side=side,
                entry_price=entry_price,
                stop_distance=range_width + buffer,
                target_r=target_r,
                round_trip_cost_points=instrument.round_trip_cost_points,
                entry_reason="orb",
            )
            if trade is not None:
                trades.append(trade)
            break
    return trades


def opening_impulse(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_bars: int,
    impulse_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    atrs = _values(frame, "atr56")
    for indices in session_days(frame, instrument):
        opening = contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, range_bars
        )
        if opening is None or len(indices) <= range_bars:
            continue
        decision_index = indices[range_bars]
        atr = float(atrs[opening[-1]])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        impulse = float(closes[opening[-1]] - opens[opening[0]])
        if abs(impulse) < impulse_atr * atr:
            continue
        side = 1 if impulse > 0.0 else -1
        if not continuation:
            side *= -1
        entry = float(opens[decision_index])
        trade = make_trade(
            frame,
            entry_index=decision_index,
            path_indices=indices,
            side=side,
            entry_price=entry,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_reason="impulse_cont" if continuation else "impulse_fade",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def session_gap(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    gap_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    days = session_days(frame, instrument)
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    atrs = _values(frame, "atr56")
    for position in range(1, len(days)):
        previous = days[position - 1]
        indices = days[position]
        entry_index = indices[0]
        atr_index = entry_index - 1
        if atr_index < 0:
            continue
        atr = float(atrs[atr_index])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        gap = float(opens[entry_index] - closes[previous[-1]])
        if abs(gap) < gap_atr * atr:
            continue
        side = 1 if gap > 0.0 else -1
        if not continuation:
            side *= -1
        trade = make_trade(
            frame,
            entry_index=entry_index,
            path_indices=indices,
            side=side,
            entry_price=float(opens[entry_index]),
            stop_distance=stop_atr * atr,
            target_r=target_r,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_reason="gap_cont" if continuation else "gap_fade",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def evidence_horizon(trades: Iterable[base.Trade]) -> list[base.Trade]:
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_dev_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return (
        dev["trades"] >= 150
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.15
        and validation["trades"] >= 25
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_dev_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 50
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def preholdout_score(row: dict[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def rows_for_instrument(instrument: Instrument) -> list[dict[str, Any]]:
    frame = load_bars(instrument)
    rows: list[dict[str, Any]] = []
    print(json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}), flush=True)

    for range_bars, active_bars, buffer_atr, max_range_atr, target_r in itertools.product(
        (1, 2, 4),
        (4, 8),
        (0.05, 0.10),
        (1.5, 2.5),
        (2.0, 3.0, 5.0),
    ):
        params = {
            "range_bars": range_bars,
            "active_bars": active_bars,
            "buffer_atr": buffer_atr,
            "max_range_atr": max_range_atr,
            "target_r": target_r,
        }
        trades = evidence_horizon(opening_range_breakout(frame, instrument, **params))
        rows.append(
            {
                "symbol": instrument.symbol,
                "family": "m15_orb_convex" if target_r >= 3.0 else "m15_orb_balanced",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    for range_bars, impulse_atr, stop_atr, target_r, continuation in itertools.product(
        (2, 4),
        (0.5, 1.0),
        (0.5, 1.0),
        (2.0, 3.0, 5.0),
        (False, True),
    ):
        params = {
            "range_bars": range_bars,
            "impulse_atr": impulse_atr,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "continuation": continuation,
        }
        trades = evidence_horizon(opening_impulse(frame, instrument, **params))
        rows.append(
            {
                "symbol": instrument.symbol,
                "family": "m15_impulse_cont" if continuation else "m15_impulse_fade",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    for gap_atr, stop_atr, target_r, continuation in itertools.product(
        (0.25, 0.50, 1.0),
        (0.5, 1.0),
        (2.0, 3.0),
        (False, True),
    ):
        params = {
            "gap_atr": gap_atr,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "continuation": continuation,
        }
        trades = evidence_horizon(session_gap(frame, instrument, **params))
        rows.append(
            {
                "symbol": instrument.symbol,
                "family": "m15_gap_cont" if continuation else "m15_gap_fade",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )
    print(json.dumps({"stage": "evaluated", "symbol": instrument.symbol, "rows": len(rows)}), flush=True)
    return rows


def screen(instruments: Sequence[Instrument]) -> dict[str, Any]:
    rows = [row for instrument in instruments for row in rows_for_instrument(instrument)]
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    families = sorted({row["family"] for row in rows})
    selected: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in eligible}):
        winner = max(
            (row for row in eligible if row["family"] == family),
            key=lambda row: (preholdout_score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        )
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": family,
                "parameters": winner["parameters"],
                "preholdout_score": preholdout_score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": "PASS" if holdout_pass(winner["metrics"]) else "FAIL",
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )
    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if any(row["holdout_verdict"] == "PASS" for row in selected)
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "selection_contract": {
            "timestamp_basis": "Darwinex broker wall GMT+2/+3 converted to UTC",
            "bar_resolution": "M15 OHLC",
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "preholdout_gate": (
                "DEV trades>=150 PF>=1.15 net>0; VAL trades>=25 PF>=1.05 net>0; "
                ">=4 positive DEV years"
            ),
            "holdout_gate": "trades>=50 PF>=1.10 net>0 and both years positive",
            "same_bar_rule": "stop_first",
            "dual_oco_touch_rule": "pessimistic_stop",
            "daily_position_limit": 1,
            "overnight_positions": 0,
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_candidates": [
            {
                "symbol": row["symbol"],
                "family": row["family"],
                "parameters": row["parameters"],
                "preholdout_score": preholdout_score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
            }
            for row in eligible
        ],
        "preholdout_leaderboard": {
            family: [
                {
                    "symbol": row["symbol"],
                    "parameters": row["parameters"],
                    "preholdout_score": preholdout_score(row),
                    "positive_dev_years": sum(
                        row["metrics"]["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
                        for year in range(2018, 2023)
                    ),
                    "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                    "validation_2023": row["metrics"]["validation_2023"],
                }
                for row in sorted(
                    (candidate for candidate in rows if candidate["family"] == family),
                    key=lambda candidate: (
                        preholdout_score(candidate),
                        candidate["metrics"]["dev_2018_2022"]["trades"],
                    ),
                    reverse=True,
                )[:5]
            ]
            for family in families
        },
        "selected_family_winners": selected,
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in selected),
    }


def default_instruments(root: Path) -> list[Instrument]:
    return [
        Instrument("GDAXI.DWX", root / "GDAXI.DWX_M15.csv", "Europe/Berlin", 9 * 60, 17 * 60 + 30, 3.0),
        Instrument("NDX.DWX", root / "NDX.DWX_M15.csv", "America/New_York", 9 * 60 + 30, 16 * 60, 4.0),
        Instrument("SP500.DWX", root / "SP500.DWX_M15.csv", "America/New_York", 9 * 60 + 30, 16 * 60, 1.0),
        Instrument("WS30.DWX", root / "WS30.DWX_M15.csv", "America/New_York", 9 * 60 + 30, 16 * 60, 4.0),
        Instrument("XAUUSD.DWX", root / "XAUUSD.DWX_M15.csv", "America/New_York", 8 * 60 + 30, 17 * 60, 0.8),
    ]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = screen(default_instruments(args.data_root))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "evaluated": artifact["evaluated_configurations"],
                "preholdout_pass": artifact["preholdout_pass_count"],
                "family_winners": len(artifact["selected_family_winners"]),
                "holdout_pass": artifact["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
