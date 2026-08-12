"""Causal cross-asset M15 lead screen for FTMO return density.

Only source bars completed before a later US-index entry may form a signal.
The full grid is judged on 2018-2022 development plus 2023 validation.  The
2024-2025 holdout is opened for at most one predeclared global winner.
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
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


BAR_NS = 15 * 60 * 1_000_000_000
MAX_SOURCE_COMPLETION_LAG_NS = 30 * 60 * 1_000_000_000


def _utc_nanoseconds(frame: pd.DataFrame) -> np.ndarray:
    cached = frame.attrs.get("utc_nanoseconds")
    if cached is None:
        cached = frame["utc"].dt.as_unit("ns").astype("int64").to_numpy()
        frame.attrs["utc_nanoseconds"] = cached
    return cached


def latest_completed_source_index(source_utc_ns: np.ndarray, entry_utc_ns: int) -> int | None:
    """Return the newest source bar known at entry, assuming M15 open stamps."""

    cutoff_open_ns = int(entry_utc_ns) - BAR_NS
    index = int(np.searchsorted(source_utc_ns, cutoff_open_ns, side="right") - 1)
    if index < 0:
        return None
    completion_lag = int(entry_utc_ns) - (int(source_utc_ns[index]) + BAR_NS)
    if completion_lag < 0 or completion_lag > MAX_SOURCE_COMPLETION_LAG_NS:
        return None
    return index


def cross_asset_trades(
    source: pd.DataFrame,
    target: pd.DataFrame,
    target_instrument: m15.Instrument,
    *,
    source_lookback_bars: int,
    target_entry_offset_bars: int,
    source_move_atr_threshold: float,
    continuation: bool,
    target_stop_atr: float,
    target_r_multiple: float,
    maximum_hold_bars: int,
    end_year: int,
) -> list[base.Trade]:
    if source_lookback_bars <= 0 or maximum_hold_bars <= 0:
        return []

    source_utc = _utc_nanoseconds(source)
    source_close = m15._values(source, "close")
    source_atr = m15._values(source, "atr56")
    target_utc = _utc_nanoseconds(target)
    target_open = m15._values(target, "open")
    target_atr = m15._values(target, "atr56")
    target_year = m15._values(target, "year")
    trades: list[base.Trade] = []

    for indices in m15.session_days(target, target_instrument):
        if target_entry_offset_bars < 0 or target_entry_offset_bars >= len(indices):
            continue
        entry_index = indices[target_entry_offset_bars]
        if int(target_year[entry_index]) > end_year or entry_index <= 0:
            continue

        source_index = latest_completed_source_index(source_utc, int(target_utc[entry_index]))
        if source_index is None or source_index < source_lookback_bars:
            continue
        source_start = source_index - source_lookback_bars
        source_span = int(source_utc[source_index]) - int(source_utc[source_start])
        if source_span < source_lookback_bars * BAR_NS or source_span > (source_lookback_bars + 2) * BAR_NS:
            continue

        signal_atr = float(source_atr[source_index])
        move = float(source_close[source_index] - source_close[source_start])
        stop_atr = float(target_atr[entry_index - 1])
        entry = float(target_open[entry_index])
        if (
            not np.isfinite(signal_atr)
            or signal_atr <= 0.0
            or not np.isfinite(stop_atr)
            or stop_atr <= 0.0
            or entry <= 0.0
            or move == 0.0
            or abs(move) < source_move_atr_threshold * signal_atr
        ):
            continue

        side = 1 if move > 0.0 else -1
        if not continuation:
            side *= -1
        path_end = min(len(indices), target_entry_offset_bars + maximum_hold_bars)
        path = indices[target_entry_offset_bars:path_end]
        trade = m15.make_trade(
            target,
            entry_index=entry_index,
            path_indices=path,
            side=side,
            entry_price=entry,
            stop_distance=target_stop_atr * stop_atr,
            target_r=target_r_multiple,
            round_trip_cost_points=target_instrument.round_trip_cost_points,
            entry_reason="cross_asset_cont" if continuation else "cross_asset_inverse",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_dev_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return bool(
        dev["trades"] >= 250
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.18
        and validation["trades"] >= 40
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.10
        and positive_dev_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return bool(
        holdout["trades"] >= 100
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


def _parameters() -> Sequence[dict[str, Any]]:
    return [
        {
            "source_lookback_bars": lookback,
            "target_entry_offset_bars": entry_offset,
            "source_move_atr_threshold": threshold,
            "continuation": continuation,
            "target_stop_atr": stop_atr,
            "target_r_multiple": target_r,
            "maximum_hold_bars": hold_bars,
        }
        for lookback, entry_offset, threshold, continuation, stop_atr, target_r, hold_bars in itertools.product(
            (8, 16, 32),
            (0, 2, 4),
            (0.5, 1.0),
            (False, True),
            (0.75, 1.25),
            (1.5, 3.0),
            (8, 16),
        )
    ]


def screen(data_root: Path) -> dict[str, Any]:
    instruments = {item.symbol: item for item in m15.default_instruments(data_root)}
    source_symbols = ("GDAXI.DWX", "XAUUSD.DWX")
    target_symbols = ("NDX.DWX", "SP500.DWX", "WS30.DWX")
    frames = {
        symbol: m15.load_bars(instruments[symbol])
        for symbol in (*source_symbols, *target_symbols)
    }
    parameter_grid = _parameters()
    rows: list[dict[str, Any]] = []

    for source_symbol, target_symbol in itertools.product(source_symbols, target_symbols):
        for parameters in parameter_grid:
            trades = cross_asset_trades(
                frames[source_symbol],
                frames[target_symbol],
                instruments[target_symbol],
                **parameters,
                end_year=2023,
            )
            rows.append(
                {
                    "source_symbol": source_symbol,
                    "target_symbol": target_symbol,
                    "parameters": parameters,
                    "metrics": base.split_metrics(trades),
                }
            )
        print(
            json.dumps(
                {
                    "stage": "evaluated_pair",
                    "source": source_symbol,
                    "target": target_symbol,
                    "configurations": len(parameter_grid),
                }
            ),
            flush=True,
        )

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    winner = max(
        eligible,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        default=None,
    )
    selected: dict[str, Any] | None = None
    if winner is not None:
        trades = cross_asset_trades(
            frames[winner["source_symbol"]],
            frames[winner["target_symbol"]],
            instruments[winner["target_symbol"]],
            **winner["parameters"],
            end_year=2025,
        )
        metrics = base.split_metrics(trades)
        selected = {
            "source_symbol": winner["source_symbol"],
            "target_symbol": winner["target_symbol"],
            "parameters": winner["parameters"],
            "preholdout_score": score(winner),
            "metrics": metrics,
            "holdout_verdict": "PASS" if holdout_pass(metrics) else "FAIL",
            "trades": [asdict(trade) for trade in trades],
        }

    leaders = sorted(
        rows,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        reverse=True,
    )[:20]
    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if selected is not None and selected["holdout_verdict"] == "PASS"
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "predeclaration": "artifacts/ftmo_m15_cross_asset_lead_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "winner_count": 1,
            "holdout_opened": selected is not None,
            "same_bar_rule": "stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "source_symbol": row["source_symbol"],
                "target_symbol": row["target_symbol"],
                "parameters": row["parameters"],
                "preholdout_score": score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
                "positive_development_years": sum(
                    row["metrics"]["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
                    for year in range(2018, 2023)
                ),
            }
            for row in leaders
        ],
        "selected_global_winner": selected,
        "holdout_pass_count": int(
            selected is not None and selected["holdout_verdict"] == "PASS"
        ),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(args.data_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
                "holdout_pass": output["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
