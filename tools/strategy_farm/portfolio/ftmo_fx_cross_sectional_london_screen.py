"""Causal London-open FX cross-sectional momentum/reversion screen."""

from __future__ import annotations

import argparse
import bisect
import itertools
import json
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore


LONDON_TZ = "Europe/London"
ENTRY_MINUTE = 8 * 60
EXIT_MINUTE = 16 * 60
DEVELOPMENT_YEARS = tuple(range(2018, 2023))
VALIDATION_YEAR = 2023
HOLDOUT_YEARS = (2024, 2025)


@dataclass(frozen=True)
class Instrument:
    symbol: str
    path: Path
    round_trip_cost_points: float


@dataclass(frozen=True)
class Opportunity:
    symbol: str
    local_date: str
    year: int
    entry_time_utc: str
    entry_index: int
    path_indices: tuple[int, ...]
    signal: float


_ARRAY_CACHE: dict[int, dict[str, np.ndarray]] = {}


def _values(frame: pd.DataFrame, column: str) -> np.ndarray:
    cache = _ARRAY_CACHE.setdefault(id(frame), {})
    if column not in cache:
        cache[column] = frame[column].to_numpy()
    return cache[column]


def load_bars(instrument: Instrument) -> pd.DataFrame:
    frame = pd.read_csv(
        instrument.path,
        usecols=lambda name: name in {"time", "open", "high", "low", "close"},
    ).sort_values("time").reset_index(drop=True)
    required = {"time", "open", "high", "low", "close"}
    if not required.issubset(frame.columns):
        raise ValueError(f"{instrument.path}: missing columns {sorted(required - set(frame.columns))}")

    frame["utc"] = base.broker_wall_seconds_to_utc(frame["time"])
    local = frame["utc"].dt.tz_convert(LONDON_TZ)
    frame["local_date"] = local.dt.date
    frame["year"] = local.dt.year
    frame["weekday"] = local.dt.weekday
    frame["minute"] = local.dt.hour * 60 + local.dt.minute
    previous_close = frame["close"].shift(1)
    true_range = np.maximum(
        frame["high"] - frame["low"],
        np.maximum(abs(frame["high"] - previous_close), abs(frame["low"] - previous_close)),
    )
    frame["atr288_prior"] = pd.Series(true_range).rolling(288, min_periods=288).mean().shift(1)
    return frame


def complete_session_map(frame: pd.DataFrame) -> dict[date, tuple[int, ...]]:
    expected_minutes = list(range(ENTRY_MINUTE, EXIT_MINUTE, 5))
    eligible = frame.loc[
        (frame["weekday"] < 5)
        & (frame["minute"] >= ENTRY_MINUTE)
        & (frame["minute"] < EXIT_MINUTE)
    ]
    sessions: dict[date, tuple[int, ...]] = {}
    for local_date, group in eligible.groupby("local_date", sort=True):
        if group["minute"].astype(int).tolist() != expected_minutes:
            continue
        sessions[local_date] = tuple(int(index) for index in group.index)
    return sessions


def completed_daily_closes(frame: pd.DataFrame, minimum_bars: int = 200) -> dict[date, float]:
    daily = frame.groupby("local_date", sort=True).agg(
        bars=("close", "size"),
        day_close=("close", "last"),
    )
    return {
        local_date: float(day_close)
        for local_date, bars, day_close in daily.itertuples(name=None)
        if int(bars) >= minimum_bars
    }


def completed_return(
    daily_closes: Mapping[date, float],
    entry_date: date,
    lookback: int,
) -> float | None:
    if lookback <= 0:
        raise ValueError("lookback must be positive")
    dates = sorted(daily_closes)
    position = bisect.bisect_left(dates, entry_date)
    if position < lookback + 1:
        return None
    latest = float(daily_closes[dates[position - 1]])
    earlier = float(daily_closes[dates[position - lookback - 1]])
    if latest <= 0.0 or earlier <= 0.0:
        return None
    return latest / earlier - 1.0


def select_daily_leader(
    candidates: Sequence[Opportunity],
    expected_symbols: int,
) -> Opportunity | None:
    if len({row.symbol for row in candidates}) != expected_symbols:
        return None
    return sorted(candidates, key=lambda row: (-abs(row.signal), row.symbol))[0]


def build_opportunities(
    frames: Mapping[str, pd.DataFrame],
    *,
    lookback: int,
    through_year: int,
) -> list[Opportunity]:
    by_date: dict[str, list[Opportunity]] = {}
    for symbol, frame in frames.items():
        daily_closes = completed_daily_closes(frame)
        sessions = complete_session_map(frame)
        atrs = _values(frame, "atr288_prior")
        utc_values = _values(frame, "utc")
        for local_date, path_indices in sessions.items():
            if local_date.year > through_year:
                continue
            signal = completed_return(daily_closes, local_date, lookback)
            entry_index = path_indices[0]
            atr = float(atrs[entry_index])
            if signal is None or signal == 0.0 or not np.isfinite(atr) or atr <= 0.0:
                continue
            opportunity = Opportunity(
                symbol=symbol,
                local_date=local_date.isoformat(),
                year=local_date.year,
                entry_time_utc=pd.Timestamp(utc_values[entry_index]).isoformat(),
                entry_index=entry_index,
                path_indices=path_indices,
                signal=float(signal),
            )
            by_date.setdefault(opportunity.local_date, []).append(opportunity)

    output: list[Opportunity] = []
    for local_date in sorted(by_date):
        leader = select_daily_leader(by_date[local_date], len(frames))
        if leader is not None:
            output.append(leader)
    return output


def simulate_opportunity(
    opportunity: Opportunity,
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    direction: str,
    stop_atr_multiple: float,
    target_r: float,
) -> base.Trade | None:
    if direction not in {"momentum", "mean_reversion"}:
        raise ValueError(f"unknown direction: {direction}")
    if stop_atr_multiple <= 0.0 or target_r <= 0.0:
        raise ValueError("stop and target must be positive")

    opens = _values(frame, "open")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    atrs = _values(frame, "atr288_prior")
    entry = float(opens[opportunity.entry_index])
    stop_distance = stop_atr_multiple * float(atrs[opportunity.entry_index])
    if entry <= 0.0 or not np.isfinite(stop_distance) or stop_distance <= 0.0:
        return None

    signal_side = 1 if opportunity.signal > 0.0 else -1
    side = signal_side if direction == "momentum" else -signal_side
    stop = entry - side * stop_distance
    target = entry + side * stop_distance * target_r
    cost_r = instrument.round_trip_cost_points / stop_distance
    result_r = 0.0
    exit_reason = "time"
    for index in opportunity.path_indices:
        high = float(highs[index])
        low = float(lows[index])
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = high >= target if side > 0 else low <= target
        if stop_hit:
            result_r = -1.0 - cost_r
            exit_reason = "stop_pessimistic" if target_hit else "stop"
            break
        if target_hit:
            result_r = target_r - cost_r
            exit_reason = "target"
            break
    else:
        result_r = side * (float(closes[opportunity.path_indices[-1]]) - entry) / stop_distance - cost_r

    return base.Trade(
        entry_time_utc=opportunity.entry_time_utc,
        local_date=opportunity.local_date,
        year=opportunity.year,
        side=side,
        r_multiple=float(result_r),
        exit_reason=f"fx_cross_sectional_{direction}:{exit_reason}",
    )


def trades_for_configuration(
    opportunities: Sequence[Opportunity],
    frames: Mapping[str, pd.DataFrame],
    instruments: Mapping[str, Instrument],
    *,
    direction: str,
    stop_atr_multiple: float,
    target_r: float,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    for opportunity in opportunities:
        trade = simulate_opportunity(
            opportunity,
            frames[opportunity.symbol],
            instruments[opportunity.symbol],
            direction=direction,
            stop_atr_multiple=stop_atr_multiple,
            target_r=target_r,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def split_metrics(trades: Sequence[base.Trade]) -> dict[str, Any]:
    annual = {
        str(year): base.summarize([trade for trade in trades if trade.year == year])
        for year in range(2018, 2026)
    }
    return {
        "development_2018_2022": base.summarize(
            [trade for trade in trades if trade.year in DEVELOPMENT_YEARS]
        ),
        "validation_2023": base.summarize(
            [trade for trade in trades if trade.year == VALIDATION_YEAR]
        ),
        "holdout_2024_2025": base.summarize(
            [trade for trade in trades if trade.year in HOLDOUT_YEARS]
        ),
        "annual": annual,
    }


def preholdout_pass(metrics: Mapping[str, Any]) -> bool:
    development = metrics["development_2018_2022"]
    validation = metrics["validation_2023"]
    positive_years = sum(
        float(metrics["annual"][str(year)]["net_r"]) > 0.0 for year in DEVELOPMENT_YEARS
    )
    return bool(
        development["trades"] >= 750
        and development["profit_factor"] is not None
        and float(development["profit_factor"]) >= 1.12
        and float(development["net_r"]) > 0.0
        and positive_years >= 4
        and validation["trades"] >= 150
        and validation["profit_factor"] is not None
        and float(validation["profit_factor"]) >= 1.05
        and float(validation["net_r"]) > 0.0
    )


def holdout_pass(metrics: Mapping[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    return bool(
        holdout["trades"] >= 350
        and holdout["profit_factor"] is not None
        and float(holdout["profit_factor"]) >= 1.10
        and float(holdout["net_r"]) > 0.0
        and all(float(metrics["annual"][str(year)]["net_r"]) > 0.0 for year in HOLDOUT_YEARS)
    )


def parameter_key(row: Mapping[str, Any]) -> str:
    params = row["parameters"]
    return (
        f"lb{int(params['lookback'])}_"
        f"{params['direction']}_"
        f"sl{float(params['stop_atr_multiple']):g}_"
        f"tp{float(params['target_r']):g}"
    )


def common_score(row: Mapping[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["development_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def select_winner(rows: Sequence[Mapping[str, Any]]) -> Mapping[str, Any] | None:
    eligible = [row for row in rows if bool(row.get("passes_preholdout_gate"))]
    if not eligible:
        return None
    return sorted(
        eligible,
        key=lambda row: (
            -common_score(row),
            -float(row["metrics"]["development_2018_2022"]["profit_factor"]),
            -int(row["metrics"]["development_2018_2022"]["trades"]),
            parameter_key(row),
        ),
    )[0]


def run_screen(instrument_list: Sequence[Instrument]) -> dict[str, Any]:
    instruments = {instrument.symbol: instrument for instrument in instrument_list}
    if len(instruments) != len(instrument_list):
        raise ValueError("instrument symbols must be unique")
    frames = {symbol: load_bars(instrument) for symbol, instrument in instruments.items()}

    opportunities_by_lookback = {
        lookback: build_opportunities(frames, lookback=lookback, through_year=VALIDATION_YEAR)
        for lookback in (1, 3, 5)
    }
    rows: list[dict[str, Any]] = []
    for lookback, direction, stop_atr_multiple, target_r in itertools.product(
        (1, 3, 5),
        ("momentum", "mean_reversion"),
        (8.0, 16.0, 24.0),
        (1.0, 2.0, 3.0),
    ):
        trades = trades_for_configuration(
            opportunities_by_lookback[lookback],
            frames,
            instruments,
            direction=direction,
            stop_atr_multiple=stop_atr_multiple,
            target_r=target_r,
        )
        metrics = split_metrics(trades)
        rows.append(
            {
                "parameters": {
                    "lookback": lookback,
                    "direction": direction,
                    "stop_atr_multiple": stop_atr_multiple,
                    "target_r": target_r,
                },
                "metrics": metrics,
                "passes_preholdout_gate": preholdout_pass(metrics),
            }
        )

    rows = sorted(rows, key=lambda row: (-common_score(row), parameter_key(row)))
    winner = select_winner(rows)
    artifact: dict[str, Any] = {
        "schema_version": 1,
        "status": "NO_PREHOLDOUT_SURVIVOR",
        "deployment_allowed": False,
        "selection_contract": {
            "development": list(DEVELOPMENT_YEARS),
            "validation": VALIDATION_YEAR,
            "sealed_holdout": list(HOLDOUT_YEARS),
            "same_bar_rule": "stop_first",
            "configuration_count": len(rows),
            "one_trade_per_london_day": True,
        },
        "costs": {
            symbol: instrument.round_trip_cost_points for symbol, instrument in instruments.items()
        },
        "preholdout_rows": rows,
        "selected_parameters": None,
        "holdout_opened": False,
        "selected_metrics": None,
        "trades": None,
        "label": "RESEARCH_ONLY_NO_GO",
    }
    if winner is None:
        return artifact

    selected_parameters = dict(winner["parameters"])
    artifact["selected_parameters"] = selected_parameters
    artifact["holdout_opened"] = True
    lookback = int(selected_parameters["lookback"])
    all_opportunities = build_opportunities(frames, lookback=lookback, through_year=max(HOLDOUT_YEARS))
    all_trades = trades_for_configuration(
        all_opportunities,
        frames,
        instruments,
        direction=str(selected_parameters["direction"]),
        stop_atr_multiple=float(selected_parameters["stop_atr_multiple"]),
        target_r=float(selected_parameters["target_r"]),
    )
    selected_metrics = split_metrics(all_trades)
    artifact["selected_metrics"] = selected_metrics
    artifact["status"] = "HOLDOUT_SURVIVOR_FOUND" if holdout_pass(selected_metrics) else "HOLDOUT_FAIL"
    artifact["trades"] = [asdict(trade) for trade in all_trades]
    return artifact


def default_instruments(root: Path) -> list[Instrument]:
    return [
        Instrument("EURUSD.DWX", root / "EURUSD.DWX_M5.csv", 0.00015),
        Instrument("GBPUSD.DWX", root / "GBPUSD.DWX_M5.csv", 0.00018),
        Instrument("USDJPY.DWX", root / "USDJPY.DWX_M5.csv", 0.0225),
        Instrument("GBPJPY.DWX", root / "GBPJPY.DWX_M5.csv", 0.0325),
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
    artifact = run_screen(default_instruments(args.data_root))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "selected_parameters": artifact["selected_parameters"],
                "holdout_opened": artifact["holdout_opened"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
