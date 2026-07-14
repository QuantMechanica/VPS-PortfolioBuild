"""Sealed M15 US-index breadth continuation with causal trailing exits."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_cross_index_screen as cross
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_cross_index_screen as cross  # type: ignore


PREHOLDOUT_END_YEAR = 2023
HOLDOUT_END_YEAR = 2025


def parameter_grid() -> Sequence[dict[str, Any]]:
    return [
        {
            "signal_bars": signal_bars,
            "min_breadth_atr": min_breadth_atr,
            "min_agreement": min_agreement,
            "initial_stop_atr": initial_stop_atr,
            "trail_distance_atr": trail_distance_atr,
            "trail_lookback_bars": trail_lookback_bars,
            "hold_bars": hold_bars,
        }
        for (
            signal_bars,
            min_breadth_atr,
            min_agreement,
            initial_stop_atr,
            trail_distance_atr,
            trail_lookback_bars,
            hold_bars,
        ) in itertools.product(
            (2, 4, 8),
            (0.10, 0.25, 0.50),
            (2, 3),
            (0.75, 1.0),
            (0.75, 1.0, 1.5),
            (2, 4),
            (8, 16, 24),
        )
    ]


def simulate_trailing_leg(
    panel: pd.DataFrame,
    *,
    symbol: str,
    path: Sequence[int],
    entry_index: int,
    side: int,
    atr: float,
    initial_stop_atr: float,
    trail_distance_atr: float,
    trail_lookback_bars: int,
    price_arrays: dict[str, dict[str, np.ndarray]] | None = None,
) -> float:
    if side not in (-1, 1) or not path or entry_index != path[0]:
        return float("nan")
    if atr <= 0.0 or initial_stop_atr <= 0.0 or trail_distance_atr <= 0.0:
        return float("nan")
    if trail_lookback_bars <= 0:
        return float("nan")
    if price_arrays is None:
        prices = {
            name: cross._values(panel, f"{symbol}:{name}")
            for name in ("open", "high", "low", "close")
        }
    else:
        prices = price_arrays[symbol]
    entry = float(prices["open"][entry_index])
    initial_risk = initial_stop_atr * atr
    if entry <= 0.0 or initial_risk <= 0.0:
        return float("nan")
    stop = entry - side * initial_risk
    cost_r = cross.COST_POINTS[symbol] / initial_risk
    completed: list[int] = []
    for index in path:
        bar_open = float(prices["open"][index])
        high = float(prices["high"][index])
        low = float(prices["low"][index])
        close = float(prices["close"][index])
        stop_hit = low <= stop if side > 0 else high >= stop
        if stop_hit:
            exit_price = min(stop, bar_open) if side > 0 else max(stop, bar_open)
            return side * (exit_price - entry) / initial_risk - cost_r

        completed.append(index)
        lookback = completed[-trail_lookback_bars:]
        if side > 0:
            candidate = max(float(prices["high"][row]) for row in lookback)
            candidate -= trail_distance_atr * atr
            stop = max(stop, min(candidate, close))
        else:
            candidate = min(float(prices["low"][row]) for row in lookback)
            candidate += trail_distance_atr * atr
            stop = min(stop, max(candidate, close))

    exit_price = float(prices["close"][path[-1]])
    return side * (exit_price - entry) / initial_risk - cost_r


def breadth_trailing_packages(
    panel: pd.DataFrame,
    *,
    signal_bars: int,
    min_breadth_atr: float,
    min_agreement: int,
    initial_stop_atr: float,
    trail_distance_atr: float,
    trail_lookback_bars: int,
    hold_bars: int,
    max_year: int,
) -> list[base.Trade]:
    minutes = cross._values(panel, "minute")
    utc_values = cross._values(panel, "utc")
    local_dates = cross._values(panel, "local_date")
    years = cross._values(panel, "year")
    opens = {
        symbol: cross._values(panel, f"{symbol}:open") for symbol in cross.SYMBOLS
    }
    closes = {
        symbol: cross._values(panel, f"{symbol}:close") for symbol in cross.SYMBOLS
    }
    atr_values = {
        symbol: cross._values(panel, f"{symbol}:atr56") for symbol in cross.SYMBOLS
    }
    price_arrays = {
        symbol: {
            name: cross._values(panel, f"{symbol}:{name}")
            for name in ("open", "high", "low", "close")
        }
        for symbol in cross.SYMBOLS
    }
    trades: list[base.Trade] = []
    for indices in cross.session_days(panel):
        if not indices or int(years[indices[0]]) > max_year:
            continue
        if signal_bars <= 0 or len(indices) <= signal_bars:
            continue
        expected = [
            cross.SESSION_START_MINUTE + 15 * offset
            for offset in range(signal_bars + 1)
        ]
        if [int(minutes[index]) for index in indices[: signal_bars + 1]] != expected:
            continue
        signal_last = indices[signal_bars - 1]
        entry_index = indices[signal_bars]
        scores: dict[str, float] = {}
        atrs: dict[str, float] = {}
        for symbol in cross.SYMBOLS:
            atr = float(atr_values[symbol][signal_last])
            session_open = float(opens[symbol][indices[0]])
            if not np.isfinite(atr) or atr <= 0.0 or session_open <= 0.0:
                scores = {}
                break
            atrs[symbol] = atr
            scores[symbol] = (
                float(closes[symbol][signal_last]) - session_open
            ) / atr
        if len(scores) != len(cross.SYMBOLS):
            continue
        breadth = float(np.mean(list(scores.values())))
        if breadth == 0.0 or abs(breadth) < min_breadth_atr:
            continue
        side = 1 if breadth > 0.0 else -1
        agreement = sum((value > 0.0) == (side > 0) for value in scores.values())
        if agreement < min_agreement:
            continue
        end_position = min(len(indices) - 1, signal_bars + hold_bars - 1)
        path = indices[signal_bars : end_position + 1]
        leg_results = [
            simulate_trailing_leg(
                panel,
                symbol=symbol,
                path=path,
                entry_index=entry_index,
                side=side,
                atr=atrs[symbol],
                initial_stop_atr=initial_stop_atr,
                trail_distance_atr=trail_distance_atr,
                trail_lookback_bars=trail_lookback_bars,
                price_arrays=price_arrays,
            )
            for symbol in cross.SYMBOLS
        ]
        if not all(np.isfinite(value) for value in leg_results):
            continue
        trades.append(
            base.Trade(
                entry_time_utc=pd.Timestamp(utc_values[entry_index]).isoformat(),
                local_date=str(local_dates[entry_index]),
                year=int(years[entry_index]),
                side=side,
                r_multiple=float(np.mean(leg_results)),
                exit_reason=f"breadth_trailing:agreement={agreement}",
            )
        )
    return trades


def positive_development_years(metrics: dict[str, Any]) -> int:
    return sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    return (
        dev["trades"] >= 200
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.15
        and validation["trades"] >= 35
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_development_years(metrics) >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 70
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def score(metrics: dict[str, Any]) -> float:
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def screen(panel: pd.DataFrame) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for params in parameter_grid():
        trades = breadth_trailing_packages(
            panel,
            **params,
            max_year=PREHOLDOUT_END_YEAR,
        )
        metrics = base.split_metrics(trades)
        rows.append({"parameters": params, "metrics": metrics})
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    ranked = sorted(
        rows,
        key=lambda row: (score(row["metrics"]), row["metrics"]["dev_2018_2022"]["trades"]),
        reverse=True,
    )
    leaderboard = [
        {
            "parameters": row["parameters"],
            "preholdout_score": score(row["metrics"]),
            "dev_2018_2022": row["metrics"]["dev_2018_2022"],
            "validation_2023": row["metrics"]["validation_2023"],
            "positive_dev_years": positive_development_years(row["metrics"]),
            "preholdout_pass": preholdout_pass(row["metrics"]),
        }
        for row in ranked[:10]
    ]
    winner: dict[str, Any] | None = None
    if eligible:
        selected = max(
            eligible,
            key=lambda row: (
                score(row["metrics"]),
                row["metrics"]["dev_2018_2022"]["trades"],
            ),
        )
        trades = breadth_trailing_packages(
            panel,
            **selected["parameters"],
            max_year=HOLDOUT_END_YEAR,
        )
        metrics = base.split_metrics(trades)
        winner = {
            "parameters": selected["parameters"],
            "preholdout_score": score(selected["metrics"]),
            "metrics": metrics,
            "holdout_verdict": "PASS" if holdout_pass(metrics) else "FAIL",
            "trades": [asdict(trade) for trade in trades],
        }
    return {
        "schema_version": 1,
        "status": (
            "NO_PREHOLDOUT_SURVIVOR"
            if winner is None
            else "HOLDOUT_SURVIVOR_FOUND"
            if winner["holdout_verdict"] == "PASS"
            else "LOCKED_HOLDOUT_FAILED"
        ),
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "winner_count": 1,
            "same_bar_rule": "pre_bar_trailing_stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "winner": winner,
        "leaderboard": leaderboard,
        "deployment_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(cross.load_panel(args.data_root))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
