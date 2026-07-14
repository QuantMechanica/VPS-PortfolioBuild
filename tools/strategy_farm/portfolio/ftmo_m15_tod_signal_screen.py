"""Sealed time-of-day M15 momentum/reversal screen for FTMO density.

Every signal is formed from completed bars before the entry open. Candidate
selection uses 2018-2022 development plus 2023 validation; one locked winner
per symbol and direction family is then evaluated on 2024-2025.
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


EVIDENCE_END_YEAR = 2025


def time_of_day_signal_trades(
    frame: pd.DataFrame,
    instrument: m15.Instrument,
    *,
    entry_offset_bars: int,
    signal_lookback_bars: int,
    signal_atr: float,
    continuation: bool,
    stop_atr: float,
    target_r: float,
    hold_bars: int,
) -> list[base.Trade]:
    """Trade a completed-bar return at a fixed exchange-local session offset."""

    opens = m15._values(frame, "open")
    highs = m15._values(frame, "high")
    lows = m15._values(frame, "low")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    utc_values = m15._values(frame, "utc")
    local_dates = m15._values(frame, "local_date")
    years = m15._values(frame, "year")
    trades: list[base.Trade] = []

    for indices in m15.session_days(frame, instrument):
        if entry_offset_bars < 0 or entry_offset_bars >= len(indices):
            continue
        entry_index = indices[entry_offset_bars]
        decision_index = entry_index - 1
        signal_start = decision_index - signal_lookback_bars
        if signal_start < 0:
            continue

        atr = float(atrs[decision_index])
        entry = float(opens[entry_index])
        signal = float(closes[decision_index] - closes[signal_start])
        if (
            not np.isfinite(atr)
            or atr <= 0.0
            or entry <= 0.0
            or abs(signal) < signal_atr * atr
            or signal == 0.0
        ):
            continue

        side = 1 if signal > 0.0 else -1
        if not continuation:
            side *= -1
        stop_distance = stop_atr * atr
        stop = entry - side * stop_distance
        target = entry + side * stop_distance * target_r if target_r > 0.0 else 0.0
        cost_r = instrument.round_trip_cost_points / stop_distance
        end_position = min(len(indices) - 1, entry_offset_bars + hold_bars - 1)
        path = indices[entry_offset_bars : end_position + 1]
        if not path:
            continue

        result_r = 0.0
        reason = "time"
        for index in path:
            high = float(highs[index])
            low = float(lows[index])
            stop_hit = low <= stop if side > 0 else high >= stop
            target_hit = target_r > 0.0 and (
                high >= target if side > 0 else low <= target
            )
            if stop_hit:
                result_r = -1.0 - cost_r
                reason = "stop_pessimistic" if target_hit else "stop"
                break
            if target_hit:
                result_r = target_r - cost_r
                reason = "target"
                break
        else:
            result_r = side * (float(closes[path[-1]]) - entry) / stop_distance - cost_r

        trades.append(
            base.Trade(
                entry_time_utc=pd.Timestamp(utc_values[entry_index]).isoformat(),
                local_date=str(local_dates[entry_index]),
                year=int(years[entry_index]),
                side=side,
                r_multiple=float(result_r),
                exit_reason=f"tod_{'cont' if continuation else 'fade'}:{reason}",
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
        dev["trades"] >= 150
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.12
        and validation["trades"] >= 25
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_years >= 4
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


def rows_for_instrument(instrument: m15.Instrument) -> list[dict[str, Any]]:
    frame = m15.load_bars(instrument)
    rows: list[dict[str, Any]] = []
    axes = itertools.product(
        (0, 4, 8, 12, 16),
        (4, 16, 32, 96),
        (0.25, 0.50, 1.0),
        (False, True),
        (0.5, 1.0, 1.5),
        (0.0, 2.0, 4.0),
        (4, 16),
    )
    for entry_offset, lookback, threshold, continuation, stop_atr, target_r, hold in axes:
        params = {
            "entry_offset_bars": entry_offset,
            "signal_lookback_bars": lookback,
            "signal_atr": threshold,
            "continuation": continuation,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "hold_bars": hold,
        }
        trades = time_of_day_signal_trades(frame, instrument, **params)
        rows.append(
            {
                "symbol": instrument.symbol,
                "family": "tod_continuation" if continuation else "tod_fade",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )
    print(
        json.dumps({"stage": "evaluated", "symbol": instrument.symbol, "rows": len(rows)}),
        flush=True,
    )
    return rows


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    rows = [row for instrument in instruments for row in rows_for_instrument(instrument)]
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    keys = sorted({(row["symbol"], row["family"]) for row in rows})
    for symbol, family in keys:
        candidates = [
            row
            for row in eligible
            if row["symbol"] == symbol and row["family"] == family
        ]
        if not candidates:
            continue
        winner = max(
            candidates,
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        )
        selected.append(
            {
                "symbol": symbol,
                "family": family,
                "parameters": winner["parameters"],
                "preholdout_score": score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": "PASS" if holdout_pass(winner["metrics"]) else "FAIL",
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )

    leaderboard: dict[str, list[dict[str, Any]]] = {}
    for symbol, family in keys:
        key = f"{symbol}:{family}"
        leaders = sorted(
            (row for row in rows if row["symbol"] == symbol and row["family"] == family),
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
            reverse=True,
        )[:5]
        leaderboard[key] = [
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
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "signal_information": "completed M15 bars strictly before entry open",
            "timestamp_basis": "broker wall converted to UTC then exchange-local",
            "same_bar_rule": "stop_first",
            "daily_position_limit": 1,
            "overnight_positions": 0,
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": leaderboard,
        "selected_symbol_family_winners": selected,
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
    artifact = screen(m15.default_instruments(args.data_root))
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
