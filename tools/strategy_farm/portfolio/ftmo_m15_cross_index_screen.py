"""Sealed M15 cross-index relative-strength screen for the FTMO book.

The strategy observes only completed US cash-session bars, ranks NDX, SP500,
and WS30 by volatility-normalized opening move, then holds a long/short package.
Both legs carry independent hard stops and equal package risk. Selection uses
2018-2022 plus 2023; 2024-2025 is opened only for one winner per direction.
"""

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
    from . import ftmo_m15_causal_strategy_screen as m15
except ImportError:  # pragma: no cover - direct execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


SYMBOLS = ("NDX.DWX", "SP500.DWX", "WS30.DWX")
COST_POINTS = {"NDX.DWX": 4.0, "SP500.DWX": 1.0, "WS30.DWX": 4.0}
SESSION_START_MINUTE = 9 * 60 + 30
SESSION_END_MINUTE = 16 * 60
EVIDENCE_END_YEAR = 2025

_ARRAY_CACHE: dict[int, dict[str, np.ndarray]] = {}
_SESSION_DAY_CACHE: dict[int, list[list[int]]] = {}


def _values(panel: pd.DataFrame, column: str) -> np.ndarray:
    arrays = _ARRAY_CACHE.setdefault(id(panel), {})
    if column not in arrays:
        arrays[column] = panel[column].to_numpy()
    return arrays[column]


def load_panel(root: Path) -> pd.DataFrame:
    parts: list[pd.DataFrame] = []
    for symbol in SYMBOLS:
        instrument = m15.Instrument(
            symbol,
            root / f"{symbol}_M15.csv",
            "America/New_York",
            SESSION_START_MINUTE,
            SESSION_END_MINUTE,
            COST_POINTS[symbol],
        )
        frame = m15.load_bars(instrument)
        selected = frame[["utc", "local_date", "year", "weekday", "minute", "open", "high", "low", "close", "atr56"]].copy()
        selected = selected.rename(
            columns={
                column: f"{symbol}:{column}"
                for column in ("open", "high", "low", "close", "atr56")
            }
        )
        if not parts:
            parts.append(selected)
        else:
            parts.append(selected.drop(columns=["local_date", "year", "weekday", "minute"]))
    panel = parts[0]
    for part in parts[1:]:
        panel = panel.merge(part, on="utc", how="inner", validate="one_to_one")
    return panel.sort_values("utc").reset_index(drop=True)


def session_days(panel: pd.DataFrame) -> list[list[int]]:
    cached = _SESSION_DAY_CACHE.get(id(panel))
    if cached is not None:
        return cached
    weekdays = panel[panel["weekday"] < 5]
    minutes = _values(panel, "minute")
    days: list[list[int]] = []
    for _, group in weekdays.groupby("local_date", sort=True):
        indices = [
            int(index)
            for index in group.index
            if SESSION_START_MINUTE <= int(minutes[index]) < SESSION_END_MINUTE
        ]
        if indices and int(minutes[indices[0]]) == SESSION_START_MINUTE:
            days.append(indices)
    _SESSION_DAY_CACHE[id(panel)] = days
    return days


def simulate_leg(
    panel: pd.DataFrame,
    *,
    symbol: str,
    path: Sequence[int],
    entry_index: int,
    side: int,
    atr: float,
    stop_atr: float,
    target_r: float,
    price_arrays: dict[str, dict[str, np.ndarray]] | None = None,
) -> float:
    if price_arrays is None:
        prices = {
            "open": _values(panel, f"{symbol}:open"),
            "high": _values(panel, f"{symbol}:high"),
            "low": _values(panel, f"{symbol}:low"),
            "close": _values(panel, f"{symbol}:close"),
        }
    else:
        prices = price_arrays[symbol]
    opens = prices["open"]
    highs = prices["high"]
    lows = prices["low"]
    closes = prices["close"]
    entry = float(opens[entry_index])
    stop_distance = stop_atr * atr
    if entry <= 0.0 or stop_distance <= 0.0:
        return float("nan")
    stop = entry - side * stop_distance
    target = entry + side * stop_distance * target_r if target_r > 0.0 else 0.0
    cost_r = COST_POINTS[symbol] / stop_distance
    started = False
    for index in path:
        if index == entry_index:
            started = True
        if not started:
            continue
        high = float(highs[index])
        low = float(lows[index])
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = target_r > 0.0 and (high >= target if side > 0 else low <= target)
        if stop_hit:
            return -1.0 - cost_r
        if target_hit:
            return target_r - cost_r
    exit_price = float(closes[path[-1]])
    return side * (exit_price - entry) / stop_distance - cost_r


def cross_sectional_packages(
    panel: pd.DataFrame,
    *,
    signal_bars: int,
    min_dispersion_atr: float,
    stop_atr: float,
    target_r: float,
    hold_bars: int,
    momentum: bool,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    minutes = _values(panel, "minute")
    utc_values = _values(panel, "utc")
    local_dates = _values(panel, "local_date")
    years = _values(panel, "year")
    opens = {symbol: _values(panel, f"{symbol}:open") for symbol in SYMBOLS}
    closes = {symbol: _values(panel, f"{symbol}:close") for symbol in SYMBOLS}
    atr_values = {symbol: _values(panel, f"{symbol}:atr56") for symbol in SYMBOLS}
    price_arrays = {
        symbol: {
            "open": opens[symbol],
            "high": _values(panel, f"{symbol}:high"),
            "low": _values(panel, f"{symbol}:low"),
            "close": closes[symbol],
        }
        for symbol in SYMBOLS
    }
    for indices in session_days(panel):
        if signal_bars <= 0 or len(indices) <= signal_bars:
            continue
        expected_minutes = [SESSION_START_MINUTE + 15 * offset for offset in range(signal_bars + 1)]
        actual_minutes = [int(minutes[index]) for index in indices[: signal_bars + 1]]
        if actual_minutes != expected_minutes:
            continue
        signal_last = indices[signal_bars - 1]
        entry_index = indices[signal_bars]
        scores: dict[str, float] = {}
        atrs: dict[str, float] = {}
        for symbol in SYMBOLS:
            atr = float(atr_values[symbol][signal_last])
            start = float(opens[symbol][indices[0]])
            finish = float(closes[symbol][signal_last])
            if not np.isfinite(atr) or atr <= 0.0 or start <= 0.0:
                scores = {}
                break
            atrs[symbol] = atr
            scores[symbol] = (finish - start) / atr
        if len(scores) != len(SYMBOLS):
            continue
        strongest = max(scores, key=scores.get)
        weakest = min(scores, key=scores.get)
        dispersion = scores[strongest] - scores[weakest]
        if strongest == weakest or dispersion < min_dispersion_atr:
            continue
        long_symbol = strongest if momentum else weakest
        short_symbol = weakest if momentum else strongest
        path_end_position = min(len(indices) - 1, signal_bars + hold_bars - 1)
        path = indices[signal_bars : path_end_position + 1]
        long_r = simulate_leg(
            panel,
            symbol=long_symbol,
            path=path,
            entry_index=entry_index,
            side=1,
            atr=atrs[long_symbol],
            stop_atr=stop_atr,
            target_r=target_r,
            price_arrays=price_arrays,
        )
        short_r = simulate_leg(
            panel,
            symbol=short_symbol,
            path=path,
            entry_index=entry_index,
            side=-1,
            atr=atrs[short_symbol],
            stop_atr=stop_atr,
            target_r=target_r,
            price_arrays=price_arrays,
        )
        if not np.isfinite(long_r) or not np.isfinite(short_r):
            continue
        package_r = 0.5 * (long_r + short_r)
        trades.append(
            base.Trade(
                entry_time_utc=utc_values[entry_index].isoformat(),
                local_date=str(local_dates[entry_index]),
                year=int(years[entry_index]),
                side=1,
                r_multiple=float(package_r),
                exit_reason=(
                    f"{'momentum' if momentum else 'reversal'}:"
                    f"long={long_symbol}:short={short_symbol}"
                ),
            )
        )
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return (
        dev["trades"] >= 200
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.15
        and validation["trades"] >= 30
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 60
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


def screen(panel: pd.DataFrame) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for signal_bars, dispersion, stop_atr, target_r, hold_bars, momentum in itertools.product(
        (2, 4, 8),
        (0.10, 0.50),
        (0.50, 1.0),
        (0.0, 3.0),
        (8, 99),
        (False, True),
    ):
        params = {
            "signal_bars": signal_bars,
            "min_dispersion_atr": dispersion,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "hold_bars": hold_bars,
            "momentum": momentum,
        }
        trades = cross_sectional_packages(panel, **params)
        rows.append(
            {
                "family": "cross_index_momentum" if momentum else "cross_index_reversal",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    families = sorted({row["family"] for row in rows})
    for family in families:
        family_eligible = [row for row in eligible if row["family"] == family]
        if not family_eligible:
            continue
        winner = max(family_eligible, key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]))
        selected.append(
            {
                "family": family,
                "parameters": winner["parameters"],
                "preholdout_score": score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": "PASS" if holdout_pass(winner["metrics"]) else "FAIL",
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )

    leaderboard = {}
    for family in families:
        leaders = sorted(
            (row for row in rows if row["family"] == family),
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
            reverse=True,
        )[:5]
        leaderboard[family] = [
            {
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
            "universe": list(SYMBOLS),
            "timestamp_basis": "Darwinex broker wall converted to UTC then America/New_York",
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "risk": "equal 0.5 package risk per hard-stopped leg",
            "same_bar_rule": "stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": leaderboard,
        "selected_family_winners": selected,
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in selected),
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
    panel = load_panel(args.data_root)
    artifact = screen(panel)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "evaluated": artifact["evaluated_configurations"],
                "preholdout_pass": artifact["preholdout_pass_count"],
                "holdout_pass": artifact["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
