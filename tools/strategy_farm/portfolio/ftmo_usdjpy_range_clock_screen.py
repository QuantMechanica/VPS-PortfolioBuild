"""Sealed USDJPY range-clock screen for independent FTMO return density.

The screen evaluates fixed broker-wall range windows on native T_Export M5
bars. All candidates are selected on 2018-2022 development and 2023
validation. Only the single locked winner is evaluated on 2024-2025.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore


DEV_YEARS = tuple(range(2018, 2023))
VALIDATION_YEAR = 2023
HOLDOUT_YEARS = (2024, 2025)
START_HOURS = (0, 6, 9, 12, 15, 18, 21)
DURATIONS_MINUTES = (60, 120, 180)
ATR_PERIOD = 14
STOP_ATR = 2.0
PENDING_MINUTES = 720
EXIT_HOUR_BROKER = 22
BUFFER_POINTS = 5
POINT = 0.001
BASE_COST_BPS = 2.0
STRESS_COST_BPS = 5.0


@dataclass(frozen=True)
class ClockConfig:
    start_hour_broker: int
    duration_minutes: int


def wilder_average(values: Sequence[float], period: int) -> np.ndarray:
    """Return Wilder's recursive average with a simple-period seed."""

    array = np.asarray(values, dtype=float)
    result = np.full(len(array), np.nan, dtype=float)
    if period <= 0 or len(array) < period:
        return result
    seed = array[:period]
    if not np.isfinite(seed).all():
        return result
    result[period - 1] = float(np.mean(seed))
    for index in range(period, len(array)):
        value = float(array[index])
        if not np.isfinite(value):
            continue
        result[index] = (result[index - 1] * (period - 1) + value) / period
    return result


def load_native_bars(path: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    frame = pd.read_csv(path).sort_values("time").drop_duplicates("time", keep="last")
    required = {"time", "open", "high", "low", "close"}
    if not required.issubset(frame.columns):
        raise ValueError(f"{path}: missing columns {sorted(required - set(frame.columns))}")
    frame["broker"] = pd.to_datetime(frame["time"], unit="s", utc=True).dt.tz_localize(None)
    frame["utc"] = base.broker_wall_seconds_to_utc(frame["time"])
    frame = frame.set_index("broker", drop=False).sort_index()

    m30 = frame.resample("30min", closed="left", label="left").agg(
        open=("open", "first"),
        high=("high", "max"),
        low=("low", "min"),
        close=("close", "last"),
        bars=("close", "count"),
    )
    m30 = m30[m30["bars"] > 0].copy()
    previous_close = m30["close"].shift(1)
    true_range = pd.Series(
        np.maximum(
        m30["high"] - m30["low"],
        np.maximum(abs(m30["high"] - previous_close), abs(m30["low"] - previous_close)),
        ),
        index=m30.index,
        dtype=float,
    )
    true_range.iloc[0] = float(m30.iloc[0]["high"] - m30.iloc[0]["low"])
    m30["atr14"] = wilder_average(true_range.to_numpy(dtype=float), ATR_PERIOD)
    return frame, m30


def _exact_slice(frame: pd.DataFrame, start: pd.Timestamp, end: pd.Timestamp) -> pd.DataFrame | None:
    expected = pd.date_range(start, end - pd.Timedelta(minutes=5), freq="5min")
    if len(expected) == 0:
        return None
    rows = _slice_half_open(frame, start, end)
    return rows if rows.index.equals(expected) else None


def _slice_half_open(
    frame: pd.DataFrame, start: pd.Timestamp, end: pd.Timestamp
) -> pd.DataFrame:
    left = int(frame.index.searchsorted(start, side="left"))
    right = int(frame.index.searchsorted(end, side="left"))
    return frame.iloc[left:right]


def _exit_price(frame: pd.DataFrame, exit_time: pd.Timestamp) -> float | None:
    if exit_time in frame.index:
        value = float(frame.loc[exit_time, "open"])
        return value if value > 0.0 else None
    prior_index = int(frame.index.searchsorted(exit_time, side="left")) - 1
    if prior_index < 0:
        return None
    prior = frame.iloc[prior_index]
    if exit_time - frame.index[prior_index] > pd.Timedelta(minutes=10):
        return None
    value = float(prior["close"])
    return value if value > 0.0 else None


def _side_result(
    holding: pd.DataFrame,
    *,
    side: int,
    entry: float,
    stop_distance: float,
    exit_price: float,
    cost_bps: float,
) -> tuple[float, str]:
    stop = entry - side * stop_distance
    for row in holding.itertuples():
        stop_hit = float(row.low) <= stop if side > 0 else float(row.high) >= stop
        if stop_hit:
            gross_r = -1.0
            reason = "stop"
            break
    else:
        gross_r = side * (exit_price - entry) / stop_distance
        reason = "time"
    cost_r = (cost_bps / 10_000.0) * entry / stop_distance
    return float(gross_r - cost_r), reason


def simulate_config(
    frame: pd.DataFrame,
    m30: pd.DataFrame,
    config: ClockConfig,
    *,
    start_year: int,
    end_year: int,
    cost_bps: float,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    first_date = dt.date(start_year - 1, 12, 31)
    last_date = dt.date(end_year, 12, 31)
    for session_date in pd.date_range(first_date, last_date, freq="D"):
        range_start = session_date + pd.Timedelta(hours=config.start_hour_broker)
        range_close = range_start + pd.Timedelta(minutes=config.duration_minutes)
        if range_close.weekday() == 4:  # frozen strategy disables Friday sessions
            continue
        range_rows = _exact_slice(frame, range_start, range_close)
        if range_rows is None:
            continue
        atr_stamp = range_close - pd.Timedelta(minutes=30)
        if atr_stamp not in m30.index:
            continue
        atr = float(m30.loc[atr_stamp, "atr14"])
        if not np.isfinite(atr) or atr <= 0.0:
            continue

        exit_time = range_close.normalize() + pd.Timedelta(hours=EXIT_HOUR_BROKER)
        if exit_time <= range_close:
            exit_time += pd.Timedelta(days=1)
        pending_end = min(
            range_close + pd.Timedelta(minutes=PENDING_MINUTES),
            exit_time,
        )
        pending = _slice_half_open(frame, range_close, pending_end)
        if pending.empty or pending.index[0] != range_close:
            continue

        range_high = float(range_rows["high"].max())
        range_low = float(range_rows["low"].min())
        long_entry = range_high + BUFFER_POINTS * POINT
        short_entry = range_low - BUFFER_POINTS * POINT
        stop_distance = STOP_ATR * atr
        if long_entry <= short_entry or stop_distance <= 0.0:
            continue

        trigger_time: pd.Timestamp | None = None
        trigger_sides: tuple[int, ...] = ()
        for row in pending.itertuples():
            long_hit = float(row.high) >= long_entry
            short_hit = float(row.low) <= short_entry
            if long_hit or short_hit:
                trigger_time = pd.Timestamp(row.Index)
                trigger_sides = (1, -1) if long_hit and short_hit else ((1,) if long_hit else (-1,))
                break
        if trigger_time is None:
            continue

        trade_year = int(trigger_time.year)
        if not start_year <= trade_year <= end_year:
            continue
        holding = _slice_half_open(frame, trigger_time, exit_time)
        exit_price = _exit_price(frame, exit_time)
        if holding.empty or exit_price is None:
            continue
        outcomes = [
            (
                *_side_result(
                    holding,
                    side=side,
                    entry=long_entry if side > 0 else short_entry,
                    stop_distance=stop_distance,
                    exit_price=exit_price,
                    cost_bps=cost_bps,
                ),
                side,
            )
            for side in trigger_sides
        ]
        result_r, reason, side = min(outcomes, key=lambda item: item[0])
        utc = frame.loc[trigger_time, "utc"]
        trades.append(
            base.Trade(
                entry_time_utc=pd.Timestamp(utc).isoformat(),
                local_date=str(trigger_time.date()),
                year=trade_year,
                side=int(side),
                r_multiple=float(result_r),
                exit_reason=("dual_pessimistic:" if len(trigger_sides) == 2 else "") + reason,
            )
        )
    return trades


def metrics_for_years(trades: Sequence[base.Trade], years: Sequence[int]) -> dict[str, Any]:
    selected = [trade for trade in trades if trade.year in years]
    return base.summarize(selected)


def preholdout_metrics(trades: Sequence[base.Trade]) -> dict[str, Any]:
    return {
        "development": metrics_for_years(trades, DEV_YEARS),
        "validation_2023": metrics_for_years(trades, (VALIDATION_YEAR,)),
        "annual": {
            str(year): metrics_for_years(trades, (year,))
            for year in (*DEV_YEARS, VALIDATION_YEAR)
        },
    }


def pf(metrics: dict[str, Any]) -> float:
    return float(metrics.get("profit_factor") or 0.0)


def preholdout_pass(base_metrics: dict[str, Any], stress_metrics: dict[str, Any]) -> bool:
    development = base_metrics["development"]
    validation = base_metrics["validation_2023"]
    positive_years = sum(
        base_metrics["annual"][str(year)]["net_r"] > 0.0 for year in DEV_YEARS
    )
    return bool(
        development["trades"] >= 250
        and validation["trades"] >= 40
        and development["net_r"] > 0.0
        and validation["net_r"] > 0.0
        and pf(development) >= 1.12
        and pf(validation) >= 1.05
        and positive_years >= 4
        and stress_metrics["development"]["net_r"] > 0.0
        and stress_metrics["validation_2023"]["net_r"] > 0.0
    )


def score(metrics: dict[str, Any]) -> float:
    return min(pf(metrics["development"]), pf(metrics["validation_2023"]))


def holdout_metrics(trades: Sequence[base.Trade]) -> dict[str, Any]:
    return {
        "pooled": metrics_for_years(trades, HOLDOUT_YEARS),
        "annual": {
            str(year): metrics_for_years(trades, (year,)) for year in HOLDOUT_YEARS
        },
    }


def holdout_pass(base_metrics: dict[str, Any], stress_metrics: dict[str, Any]) -> bool:
    return bool(
        base_metrics["pooled"]["trades"] >= 60
        and base_metrics["pooled"]["net_r"] > 0.0
        and pf(base_metrics["pooled"]) >= 1.10
        and all(base_metrics["annual"][str(year)]["net_r"] > 0.0 for year in HOLDOUT_YEARS)
        and stress_metrics["pooled"]["net_r"] > 0.0
        and all(stress_metrics["annual"][str(year)]["net_r"] > 0.0 for year in HOLDOUT_YEARS)
    )


def screen(path: Path) -> dict[str, Any]:
    frame, m30 = load_native_bars(path)
    rows: list[dict[str, Any]] = []
    for start_hour in START_HOURS:
        for duration in DURATIONS_MINUTES:
            config = ClockConfig(start_hour, duration)
            base_trades = simulate_config(
                frame, m30, config, start_year=2018, end_year=2023, cost_bps=BASE_COST_BPS
            )
            stress_trades = simulate_config(
                frame, m30, config, start_year=2018, end_year=2023, cost_bps=STRESS_COST_BPS
            )
            base_metrics = preholdout_metrics(base_trades)
            stress_metrics = preholdout_metrics(stress_trades)
            rows.append(
                {
                    "parameters": dataclasses.asdict(config),
                    "base_cost_metrics": base_metrics,
                    "stress_cost_metrics": stress_metrics,
                    "preholdout_pass": preholdout_pass(base_metrics, stress_metrics),
                    "preholdout_score": score(base_metrics),
                }
            )

    by_key = {
        (row["parameters"]["start_hour_broker"], row["parameters"]["duration_minutes"]): row
        for row in rows
    }
    for row in rows:
        start = int(row["parameters"]["start_hour_broker"])
        duration = int(row["parameters"]["duration_minutes"])
        neighbor_durations = [value for value in (duration - 60, duration + 60) if value in DURATIONS_MINUTES]
        neighbors = [by_key[(start, value)] for value in neighbor_durations]
        row["neighbor_robust"] = bool(neighbors) and all(
            neighbor["base_cost_metrics"]["development"]["net_r"] > 0.0
            and neighbor["base_cost_metrics"]["validation_2023"]["net_r"] > 0.0
            and neighbor["stress_cost_metrics"]["development"]["net_r"] > 0.0
            and neighbor["stress_cost_metrics"]["validation_2023"]["net_r"] > 0.0
            for neighbor in neighbors
        )

    eligible = [row for row in rows if row["preholdout_pass"] and row["neighbor_robust"]]
    winner = max(eligible, key=lambda row: row["preholdout_score"], default=None)
    selected = None
    if winner is not None:
        config = ClockConfig(**winner["parameters"])
        base_trades = simulate_config(
            frame, m30, config, start_year=2024, end_year=2025, cost_bps=BASE_COST_BPS
        )
        stress_trades = simulate_config(
            frame, m30, config, start_year=2024, end_year=2025, cost_bps=STRESS_COST_BPS
        )
        base_holdout = holdout_metrics(base_trades)
        stress_holdout = holdout_metrics(stress_trades)
        selected = {
            "parameters": winner["parameters"],
            "preholdout_score": winner["preholdout_score"],
            "base_cost_preholdout": winner["base_cost_metrics"],
            "stress_cost_preholdout": winner["stress_cost_metrics"],
            "base_cost_holdout": base_holdout,
            "stress_cost_holdout": stress_holdout,
            "holdout_verdict": "PASS" if holdout_pass(base_holdout, stress_holdout) else "FAIL",
            "holdout_trades": [dataclasses.asdict(trade) for trade in base_trades],
        }

    leaderboard = sorted(
        rows,
        key=lambda row: (row["preholdout_pass"] and row["neighbor_robust"], row["preholdout_score"]),
        reverse=True,
    )[:10]
    survivor = selected is not None and selected["holdout_verdict"] == "PASS"
    return {
        "schema_version": 1,
        "status": "HOLDOUT_SURVIVOR_FOUND" if survivor else "NO_HOLDOUT_SURVIVOR",
        "selection_contract": {
            "development": list(DEV_YEARS),
            "validation": VALIDATION_YEAR,
            "sealed_holdout": list(HOLDOUT_YEARS),
            "selection_uses_holdout": False,
            "candidate_count": len(rows),
            "single_locked_winner": True,
            "dual_touch": "choose_worse_executable_side",
            "base_round_trip_cost_bps": BASE_COST_BPS,
            "stress_round_trip_cost_bps": STRESS_COST_BPS,
            "excluded_existing_clock": "03:00 broker start",
        },
        "source": str(path),
        "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "source_rows": int(len(frame)),
        "source_broker_time_range": {
            "first": pd.Timestamp(frame.index.min()).isoformat(),
            "last": pd.Timestamp(frame.index.max()).isoformat(),
        },
        "evaluated_configurations": len(rows),
        "eligible_preholdout_count": len(eligible),
        "preholdout_leaderboard": leaderboard,
        "selected_winner": selected,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bars",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files\USDJPY.DWX_M5.csv"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = screen(args.bars)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), "status": artifact["status"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
