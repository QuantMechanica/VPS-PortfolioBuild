"""Sealed M15 screen for US-index opening relative strength."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_ndx_gap_impulse_peer_breadth as peer
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_ndx_gap_impulse_peer_breadth as peer  # type: ignore


US_SYMBOLS = ("NDX.DWX", "SP500.DWX", "WS30.DWX")


def relative_panel(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
    *,
    window_bars: int,
) -> dict[str, dict[str, float]]:
    features = {
        symbol: peer.peer_features(
            frames[symbol], instruments[symbol], range_bars=window_bars
        )
        for symbol in US_SYMBOLS
    }
    dates = set.intersection(*(set(features[symbol]) for symbol in US_SYMBOLS))
    return {
        date: {
            symbol: float(features[symbol][date]["impulse_atr"])
            for symbol in US_SYMBOLS
        }
        for date in dates
    }


def relative_value(row: Mapping[str, float], target_symbol: str) -> float:
    peers = [float(row[symbol]) for symbol in US_SYMBOLS if symbol != target_symbol]
    return float(row[target_symbol]) - float(np.mean(peers))


def relative_strength_trades(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
    *,
    target_symbol: str,
    window_bars: int,
    mode: str,
    relative_atr: float,
    stop_atr: float,
    target_r: float,
    end_year: int,
    panel: Mapping[str, Mapping[str, float]] | None = None,
) -> list[base.Trade]:
    if target_symbol not in US_SYMBOLS:
        raise ValueError(f"unsupported target symbol: {target_symbol}")
    if mode not in {"convergence", "continuation"}:
        raise ValueError(f"unsupported mode: {mode}")
    if panel is None:
        panel = relative_panel(frames, instruments, window_bars=window_bars)
    frame = frames[target_symbol]
    instrument = instruments[target_symbol]
    opens = m15._values(frame, "open")
    atrs = m15._values(frame, "atr56")
    dates = m15._values(frame, "local_date")
    years = m15._values(frame, "year")
    trades: list[base.Trade] = []
    for indices in m15.session_days(frame, instrument):
        opening = m15.contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, window_bars
        )
        if opening is None or len(indices) <= window_bars:
            continue
        decision_index = opening[-1]
        if int(years[decision_index]) > end_year:
            continue
        date = str(dates[decision_index])
        row = panel.get(date)
        if row is None:
            continue
        signal = relative_value(row, target_symbol)
        if not np.isfinite(signal) or abs(signal) < relative_atr or signal == 0.0:
            continue
        side = 1 if signal > 0.0 else -1
        if mode == "convergence":
            side *= -1
        atr = float(atrs[decision_index])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        entry_index = indices[window_bars]
        trade = m15.make_trade(
            frame,
            entry_index=entry_index,
            path_indices=indices,
            side=side,
            entry_price=float(opens[entry_index]),
            stop_distance=stop_atr * atr,
            target_r=target_r,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_reason=f"us_index_relative_strength_{mode}",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def parameter_grid() -> Iterable[dict[str, Any]]:
    for values in itertools.product(
        US_SYMBOLS,
        (2, 4),
        ("convergence", "continuation"),
        (0.25, 0.5, 0.75),
        (0.5, 1.0),
        (1.0, 2.0, 3.0),
    ):
        yield dict(
            zip(
                ("target_symbol", "window_bars", "mode", "relative_atr", "stop_atr", "target_r"),
                values,
            )
        )


def screen(
    frames: Mapping[str, Any], instruments: Mapping[str, m15.Instrument]
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    panels = {
        window_bars: relative_panel(frames, instruments, window_bars=window_bars)
        for window_bars in (2, 4)
    }
    for parameters in parameter_grid():
        trades = relative_strength_trades(
            frames,
            instruments,
            **parameters,
            end_year=2023,
            panel=panels[parameters["window_bars"]],
        )
        rows.append({"parameters": parameters, "metrics": base.split_metrics(trades)})

    eligible = [row for row in rows if m15.preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    if eligible:
        winner = max(
            eligible,
            key=lambda row: (
                m15.preholdout_score(row),
                row["metrics"]["dev_2018_2022"]["trades"],
            ),
        )
        trades = relative_strength_trades(
            frames,
            instruments,
            **winner["parameters"],
            end_year=2025,
            panel=panels[winner["parameters"]["window_bars"]],
        )
        metrics = base.split_metrics(trades)
        selected.append(
            {
                "family": "us_index_opening_relative_strength",
                "parameters": winner["parameters"],
                "preholdout_score": m15.preholdout_score(winner),
                "metrics": metrics,
                "holdout_verdict": "PASS" if m15.holdout_pass(metrics) else "FAIL",
                "trades": [asdict(trade) for trade in trades],
            }
        )

    leaderboard = sorted(
        rows,
        key=lambda row: (
            m15.preholdout_score(row),
            row["metrics"]["dev_2018_2022"]["trades"],
        ),
        reverse=True,
    )[:20]
    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if selected and selected[0]["holdout_verdict"] == "PASS"
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "predeclaration": "artifacts/ftmo_m15_us_index_relative_strength_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "holdout_opened": bool(eligible),
            "entry_rule": "next_bar_open_after_synchronized_completed_window",
            "same_bar_rule": "stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "parameters": row["parameters"],
                "preholdout_score": m15.preholdout_score(row),
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


def load_inputs(root: Path):
    instruments = {
        instrument.symbol: instrument
        for instrument in m15.default_instruments(root)
        if instrument.symbol in US_SYMBOLS
    }
    frames = {
        symbol: m15.load_bars(instruments[symbol]) for symbol in US_SYMBOLS
    }
    return frames, instruments


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    frames, instruments = load_inputs(args.data_root)
    output = screen(frames, instruments)
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
