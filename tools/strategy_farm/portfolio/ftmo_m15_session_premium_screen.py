"""Sealed M15 screen for fixed intraday and weekday session premia."""

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
except ImportError:  # pragma: no cover
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


EVIDENCE_END_YEAR = 2025


def session_premium_trades(
    frame: pd.DataFrame,
    instrument: m15.Instrument,
    *,
    entry_offset_bars: int,
    hold_bars: int,
    stop_atr: float,
    target_r: float,
    direction: int,
    weekday: int,
) -> list[base.Trade]:
    opens = m15._values(frame, "open")
    highs = m15._values(frame, "high")
    lows = m15._values(frame, "low")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    weekdays = m15._values(frame, "weekday")
    utc_values = m15._values(frame, "utc")
    local_dates = m15._values(frame, "local_date")
    years = m15._values(frame, "year")
    trades: list[base.Trade] = []

    for indices in m15.session_days(frame, instrument):
        if entry_offset_bars < 0 or entry_offset_bars >= len(indices):
            continue
        entry_index = indices[entry_offset_bars]
        if weekday >= 0 and int(weekdays[entry_index]) != weekday:
            continue
        atr_index = entry_index - 1
        if atr_index < 0:
            continue
        atr = float(atrs[atr_index])
        entry = float(opens[entry_index])
        stop_distance = stop_atr * atr
        if not np.isfinite(atr) or atr <= 0.0 or entry <= 0.0 or stop_distance <= 0.0:
            continue
        stop = entry - direction * stop_distance
        target = entry + direction * stop_distance * target_r if target_r > 0.0 else 0.0
        cost_r = instrument.round_trip_cost_points / stop_distance
        end_position = min(len(indices) - 1, entry_offset_bars + hold_bars - 1)
        path = indices[entry_offset_bars : end_position + 1]
        result_r = 0.0
        reason = "time"
        for index in path:
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
            result_r = direction * (float(closes[path[-1]]) - entry) / stop_distance - cost_r

        timestamp = pd.Timestamp(utc_values[entry_index])
        trades.append(
            base.Trade(
                entry_time_utc=timestamp.isoformat(),
                local_date=str(local_dates[entry_index]),
                year=int(years[entry_index]),
                side=direction,
                r_multiple=float(result_r),
                exit_reason=f"session_premium:{reason}",
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
        and (dev["profit_factor"] or 0.0) >= 1.15
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
    for entry_offset, hold_bars, stop_atr, target_r, weekday, direction in itertools.product(
        (0, 4, 8, 16),
        (4, 16, 99),
        (1.0, 2.0),
        (0.0, 3.0),
        (-1, 0, 1, 2, 3, 4),
        (-1, 1),
    ):
        params = {
            "entry_offset_bars": entry_offset,
            "hold_bars": hold_bars,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "weekday": weekday,
            "direction": direction,
        }
        trades = session_premium_trades(frame, instrument, **params)
        family = (
            f"session_{'all' if weekday < 0 else 'weekday'}_"
            f"{'long' if direction > 0 else 'short'}"
        )
        rows.append(
            {
                "symbol": instrument.symbol,
                "family": family,
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )
    return rows


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    rows = [row for instrument in instruments for row in rows_for_instrument(instrument)]
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    families = sorted({row["family"] for row in rows})
    selected: list[dict[str, Any]] = []
    for family in families:
        candidates = [row for row in eligible if row["family"] == family]
        if not candidates:
            continue
        winner = max(candidates, key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]))
        selected.append(
            {
                "symbol": winner["symbol"],
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
            "timestamp_basis": "broker wall converted to UTC then exchange-local",
            "same_bar_rule": "stop_first",
            "daily_position_limit": 1,
            "overnight_positions": 0,
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
