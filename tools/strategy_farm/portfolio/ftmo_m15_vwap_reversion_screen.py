"""Sealed M15 screen for causal session-VWAP mean reversion."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable, Sequence

import numpy as np

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


EVIDENCE_END_YEAR = 2025


def vwap_reversion_trades(
    frame,
    instrument: m15.Instrument,
    *,
    warmup_bars: int,
    active_bars: int,
    deviation_atr: float,
    stop_to_target_ratio: float,
) -> list[base.Trade]:
    opens = m15._values(frame, "open")
    highs = m15._values(frame, "high")
    lows = m15._values(frame, "low")
    closes = m15._values(frame, "close")
    volumes = m15._values(frame, "tickvol")
    atrs = m15._values(frame, "atr56")
    trades: list[base.Trade] = []

    for indices in m15.session_days(frame, instrument):
        opening = m15.contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, warmup_bars
        )
        if opening is None or len(indices) <= warmup_bars + 1:
            continue
        cumulative_value = 0.0
        cumulative_volume = 0.0
        vwap_by_position: list[float] = []
        for index in indices:
            volume = max(0.0, float(volumes[index]))
            typical = (float(highs[index]) + float(lows[index]) + float(closes[index])) / 3.0
            cumulative_value += typical * volume
            cumulative_volume += volume
            vwap_by_position.append(
                cumulative_value / cumulative_volume if cumulative_volume > 0.0 else np.nan
            )

        search_end = min(len(indices) - 1, warmup_bars + active_bars)
        for signal_position in range(warmup_bars - 1, search_end):
            signal_index = indices[signal_position]
            entry_index = indices[signal_position + 1]
            atr = float(atrs[signal_index])
            vwap = float(vwap_by_position[signal_position])
            close = float(closes[signal_index])
            if not np.isfinite(atr) or atr <= 0.0 or not np.isfinite(vwap):
                continue
            if close > vwap + deviation_atr * atr:
                side = -1
            elif close < vwap - deviation_atr * atr:
                side = 1
            else:
                continue
            entry = float(opens[entry_index])
            target_distance = side * (vwap - entry)
            if target_distance <= 0.0:
                continue
            stop_distance = target_distance * stop_to_target_ratio
            if stop_distance < 0.20 * atr or stop_distance > 3.0 * atr:
                continue
            trade = m15.make_trade(
                frame,
                entry_index=entry_index,
                path_indices=indices,
                side=side,
                entry_price=entry,
                stop_distance=stop_distance,
                target_r=target_distance / stop_distance,
                round_trip_cost_points=instrument.round_trip_cost_points,
                entry_reason="session_vwap_reversion",
            )
            if trade is not None:
                trades.append(trade)
            break
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_metrics(trades: Iterable[base.Trade]) -> dict[str, Any]:
    return base.split_metrics([trade for trade in trades if trade.year <= 2023])


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


def score(row: dict[str, Any]) -> float:
    return min(
        float(row["metrics"]["dev_2018_2022"]["profit_factor"] or 0.0),
        float(row["metrics"]["validation_2023"]["profit_factor"] or 0.0),
    )


def parameter_grid() -> Iterable[dict[str, Any]]:
    for values in itertools.product(
        (4, 8, 12), (4, 8, 16), (0.5, 0.75, 1.0), (1.0, 1.5, 2.0)
    ):
        yield dict(
            zip(
                (
                    "warmup_bars",
                    "active_bars",
                    "deviation_atr",
                    "stop_to_target_ratio",
                ),
                values,
            )
        )


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    frames: dict[str, Any] = {}
    for instrument in instruments:
        frame = m15.load_bars(instrument)
        if "tickvol" not in frame.columns:
            raise ValueError(f"{instrument.path}: missing tickvol")
        frames[instrument.symbol] = frame
        print(json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}), flush=True)
        for parameters in parameter_grid():
            trades = vwap_reversion_trades(frame, instrument, **parameters)
            rows.append(
                {
                    "symbol": instrument.symbol,
                    "parameters": parameters,
                    "metrics": preholdout_metrics(trades),
                }
            )

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    if eligible:
        winner = max(
            eligible,
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        )
        instrument = next(item for item in instruments if item.symbol == winner["symbol"])
        trades = vwap_reversion_trades(
            frames[instrument.symbol], instrument, **winner["parameters"]
        )
        metrics = base.split_metrics(trades)
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": "session_vwap_reversion",
                "parameters": winner["parameters"],
                "preholdout_score": score(winner),
                "metrics": metrics,
                "holdout_verdict": "PASS" if holdout_pass(metrics) else "FAIL",
                "trades": [asdict(trade) for trade in trades],
            }
        )

    leaderboard = sorted(
        rows,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        reverse=True,
    )[:20]
    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if selected and selected[0]["holdout_verdict"] == "PASS"
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "predeclaration": "artifacts/ftmo_m15_vwap_reversion_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "entry_rule": "next_bar_open_after_completed_deviation_signal",
            "target_rule": "signal_time_causal_session_vwap",
            "same_bar_rule": "stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "symbol": row["symbol"],
                "parameters": row["parameters"],
                "preholdout_score": score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
            }
            for row in leaderboard
        ],
        "selected_family_winners": selected,
        "holdout_pass_count": sum(
            row["holdout_verdict"] == "PASS" for row in selected
        ),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(m15.default_instruments(args.data_root))
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
