"""Sealed M5 screen for causal London and New York FX session premia.

The MT5 export timestamps are Darwinex broker-wall epochs. They are converted
to UTC before exchange-local session mapping. Candidate selection uses
2018-2022 development plus 2023 validation. Only one locked winner per
prespecified session family is opened on the 2024-2025 holdout.
"""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Sequence

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
    round_trip_cost_points: float


@dataclass(frozen=True)
class SessionSpec:
    name: str
    timezone: str
    entry_minute: int
    exit_minute: int


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
    previous_close = frame["close"].shift(1)
    true_range = np.maximum(
        frame["high"] - frame["low"],
        np.maximum(abs(frame["high"] - previous_close), abs(frame["low"] - previous_close)),
    )
    # One completed rolling trading day of M5 ranges. The entry uses the prior value.
    frame["atr288"] = pd.Series(true_range).rolling(288, min_periods=288).mean()
    return frame


def session_days(frame: pd.DataFrame, spec: SessionSpec) -> list[list[int]]:
    key = (id(frame), spec.timezone, spec.entry_minute, spec.exit_minute)
    if key in _SESSION_CACHE:
        return _SESSION_CACHE[key]

    local = frame["utc"].dt.tz_convert(spec.timezone)
    minute = local.dt.hour * 60 + local.dt.minute
    eligible = pd.DataFrame(
        {
            "local_date": local.dt.date,
            "weekday": local.dt.weekday,
            "minute": minute,
        },
        index=frame.index,
    )
    eligible = eligible[
        (eligible["weekday"] < 5)
        & (eligible["minute"] >= spec.entry_minute)
        & (eligible["minute"] < spec.exit_minute)
    ]
    days: list[list[int]] = []
    for _, group in eligible.groupby("local_date", sort=True):
        indices = [int(index) for index in group.index]
        if not indices or int(eligible.at[indices[0], "minute"]) != spec.entry_minute:
            continue
        expected_last = spec.exit_minute - 5
        if int(eligible.at[indices[-1], "minute"]) != expected_last:
            continue
        days.append(indices)
    _SESSION_CACHE[key] = days
    return days


def fixed_session_trades(
    frame: pd.DataFrame,
    instrument: Instrument,
    spec: SessionSpec,
    *,
    stop_range_multiple: float,
    target_r: float,
    direction: int,
) -> list[base.Trade]:
    if direction not in (-1, 1):
        raise ValueError("direction must be -1 or 1")
    opens = _values(frame, "open")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    atrs = _values(frame, "atr288")
    utc_values = _values(frame, "utc")
    trades: list[base.Trade] = []

    for indices in session_days(frame, spec):
        entry_index = indices[0]
        atr_index = entry_index - 1
        if atr_index < 0:
            continue
        atr = float(atrs[atr_index])
        entry = float(opens[entry_index])
        stop_distance = stop_range_multiple * atr
        if not np.isfinite(atr) or atr <= 0.0 or entry <= 0.0 or stop_distance <= 0.0:
            continue
        stop = entry - direction * stop_distance
        target = entry + direction * stop_distance * target_r if target_r > 0.0 else 0.0
        cost_r = instrument.round_trip_cost_points / stop_distance
        result_r = 0.0
        reason = "time"
        for index in indices:
            high = float(highs[index])
            low = float(lows[index])
            stop_hit = low <= stop if direction > 0 else high >= stop
            target_hit = target_r > 0.0 and (high >= target if direction > 0 else low <= target)
            if stop_hit:
                result_r = -1.0 - cost_r
                reason = "stop_pessimistic" if target_hit else "stop"
                break
            if target_hit:
                result_r = target_r - cost_r
                reason = "target"
                break
        else:
            result_r = direction * (float(closes[indices[-1]]) - entry) / stop_distance - cost_r

        timestamp = pd.Timestamp(utc_values[entry_index])
        local = timestamp.tz_convert(spec.timezone)
        trades.append(
            base.Trade(
                entry_time_utc=timestamp.isoformat(),
                local_date=local.date().isoformat(),
                year=int(local.year),
                side=direction,
                r_multiple=float(result_r),
                exit_reason=f"{spec.name}:{reason}",
            )
        )
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def weekday_filter(trades: Sequence[base.Trade], weekday: int) -> list[base.Trade]:
    if weekday < 0:
        return list(trades)
    return [trade for trade in trades if pd.Timestamp(trade.local_date).weekday() == weekday]


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_years = sum(
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
        and positive_years == 5
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


def score(row: dict[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def rows_for_instrument(
    instrument: Instrument, specs: Sequence[SessionSpec]
) -> list[dict[str, Any]]:
    frame = load_bars(instrument)
    print(json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}), flush=True)
    rows: list[dict[str, Any]] = []
    for spec in specs:
        for stop_multiple, target_r, direction in itertools.product(
            (8.0, 16.0, 24.0),
            (0.0, 2.0, 3.0),
            (-1, 1),
        ):
            all_trades = fixed_session_trades(
                frame,
                instrument,
                spec,
                stop_range_multiple=stop_multiple,
                target_r=target_r,
                direction=direction,
            )
            for weekday in (-1, 0, 1, 2, 3, 4):
                trades = weekday_filter(all_trades, weekday)
                rows.append(
                    {
                        "symbol": instrument.symbol,
                        "family": spec.name,
                        "parameters": {
                            "timezone": spec.timezone,
                            "entry_minute": spec.entry_minute,
                            "exit_minute": spec.exit_minute,
                            "stop_range_multiple": stop_multiple,
                            "target_r": target_r,
                            "direction": direction,
                            "weekday": weekday,
                        },
                        "metrics": base.split_metrics(trades),
                        "trades": trades,
                    }
                )
    return rows


def screen(instruments: Sequence[Instrument], specs: Sequence[SessionSpec]) -> dict[str, Any]:
    rows = [row for instrument in instruments for row in rows_for_instrument(instrument, specs)]
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    for spec in specs:
        candidates = [row for row in eligible if row["family"] == spec.name]
        if not candidates:
            continue
        winner = max(candidates, key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]))
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": winner["family"],
                "parameters": winner["parameters"],
                "preholdout_score": score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": "PASS" if holdout_pass(winner["metrics"]) else "FAIL",
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )

    leaderboard: dict[str, list[dict[str, Any]]] = {}
    for spec in specs:
        leaders = sorted(
            (row for row in rows if row["family"] == spec.name),
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
            reverse=True,
        )[:5]
        leaderboard[spec.name] = [
            {
                "symbol": row["symbol"],
                "parameters": row["parameters"],
                "preholdout_score": score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
                "positive_dev_years": sum(
                    row["metrics"]["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
                    for year in range(2018, 2023)
                ),
            }
            for row in leaders
        ]

    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if any(row["holdout_verdict"] == "PASS" for row in selected)
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "timestamp_basis": "Darwinex broker wall converted to UTC then session-local",
            "same_bar_rule": "stop_first",
            "daily_position_limit": 1,
            "overnight_positions": 0,
            "cost_contract": "current FTMO commission plus conservative spread allowance",
            "search_burden": "one locked winner opened per five prespecified session families",
        },
        "costs": {instrument.symbol: instrument.round_trip_cost_points for instrument in instruments},
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": leaderboard,
        "selected_family_winners": selected,
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in selected),
    }


def default_instruments(root: Path) -> list[Instrument]:
    return [
        Instrument("EURUSD.DWX", root / "EURUSD.DWX_M5.csv", 0.00015),
        Instrument("GBPUSD.DWX", root / "GBPUSD.DWX_M5.csv", 0.00018),
        Instrument("USDJPY.DWX", root / "USDJPY.DWX_M5.csv", 0.0225),
        Instrument("GBPJPY.DWX", root / "GBPJPY.DWX_M5.csv", 0.0325),
    ]


def default_sessions() -> list[SessionSpec]:
    return [
        SessionSpec("london_open", "Europe/London", 8 * 60, 11 * 60),
        SessionSpec("london_midday", "Europe/London", 11 * 60, 15 * 60),
        SessionSpec("london_fix", "Europe/London", 15 * 60, 16 * 60),
        SessionSpec("new_york_data", "America/New_York", 8 * 60 + 30, 11 * 60),
        SessionSpec("new_york_pm", "America/New_York", 13 * 60 + 30, 16 * 60),
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
    artifact = screen(default_instruments(args.data_root), default_sessions())
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
