"""Sealed M15 screen for causal first-bar gap fade and continuation."""

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


def gap_response_trades(
    frame,
    instrument: m15.Instrument,
    *,
    mode: str,
    gap_atr: float,
    response_atr: float,
    stop_atr: float,
    target_r: float,
    end_year: int,
) -> list[base.Trade]:
    if mode not in {"fade", "continuation"}:
        raise ValueError(f"unsupported mode: {mode}")
    days = m15.session_days(frame, instrument)
    opens = m15._values(frame, "open")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    years = m15._values(frame, "year")
    trades: list[base.Trade] = []

    for position in range(1, len(days)):
        previous = days[position - 1]
        indices = days[position]
        if len(indices) < 2 or int(years[indices[0]]) > end_year:
            continue
        prior_atr = float(atrs[previous[-1]])
        if not np.isfinite(prior_atr) or prior_atr <= 0.0:
            continue
        session_open = float(opens[indices[0]])
        gap = session_open - float(closes[previous[-1]])
        if abs(gap) < gap_atr * prior_atr or gap == 0.0:
            continue
        gap_side = 1 if gap > 0.0 else -1
        side = -gap_side if mode == "fade" else gap_side
        response = float(closes[indices[0]]) - session_open
        if side * response <= 0.0 or side * response < response_atr * prior_atr:
            continue
        entry_index = indices[1]
        trade = m15.make_trade(
            frame,
            entry_index=entry_index,
            path_indices=indices,
            side=side,
            entry_price=float(opens[entry_index]),
            stop_distance=stop_atr * prior_atr,
            target_r=target_r,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_reason=f"first_bar_gap_{mode}",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def parameter_grid() -> Iterable[dict[str, Any]]:
    for values in itertools.product(
        ("fade", "continuation"),
        (0.25, 0.5, 1.0),
        (0.0, 0.15, 0.3),
        (0.5, 1.0, 1.5),
        (1.0, 2.0, 3.0),
    ):
        yield dict(
            zip(
                ("mode", "gap_atr", "response_atr", "stop_atr", "target_r"),
                values,
            )
        )


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    frames: dict[str, Any] = {}
    for instrument in instruments:
        frame = m15.load_bars(instrument)
        frames[instrument.symbol] = frame
        print(
            json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}),
            flush=True,
        )
        for parameters in parameter_grid():
            trades = gap_response_trades(
                frame, instrument, **parameters, end_year=2023
            )
            rows.append(
                {
                    "symbol": instrument.symbol,
                    "parameters": parameters,
                    "metrics": base.split_metrics(trades),
                }
            )

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
        instrument = next(item for item in instruments if item.symbol == winner["symbol"])
        trades = gap_response_trades(
            frames[instrument.symbol],
            instrument,
            **winner["parameters"],
            end_year=2025,
        )
        metrics = base.split_metrics(trades)
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": "first_bar_gap_response",
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
        "predeclaration": "artifacts/ftmo_m15_gap_response_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "holdout_opened": bool(eligible),
            "entry_rule": "next_bar_open_after_completed_first_session_bar",
            "same_bar_rule": "stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "symbol": row["symbol"],
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
