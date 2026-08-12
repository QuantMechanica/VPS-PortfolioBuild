"""Sealed M15 screen for gap-confirmed opening impulse continuation."""

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


def gap_impulse_trades(
    frame,
    instrument: m15.Instrument,
    *,
    range_bars: int,
    gap_atr: float,
    impulse_atr: float,
    stop_atr: float,
    target_r: float,
) -> list[base.Trade]:
    days = m15.session_days(frame, instrument)
    opens = m15._values(frame, "open")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    trades: list[base.Trade] = []

    for position in range(1, len(days)):
        previous = days[position - 1]
        indices = days[position]
        opening = m15.contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, range_bars
        )
        if opening is None or len(indices) <= range_bars:
            continue
        atr = float(atrs[opening[-1]])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        session_open = float(opens[opening[0]])
        gap = session_open - float(closes[previous[-1]])
        impulse = float(closes[opening[-1]]) - session_open
        if abs(gap) < gap_atr * atr or abs(impulse) < impulse_atr * atr:
            continue
        if gap * impulse <= 0.0:
            continue
        side = 1 if gap > 0.0 else -1
        entry_index = indices[range_bars]
        trade = m15.make_trade(
            frame,
            entry_index=entry_index,
            path_indices=indices,
            side=side,
            entry_price=float(opens[entry_index]),
            stop_distance=stop_atr * atr,
            target_r=target_r,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_reason="gap_confirmed_opening_impulse",
        )
        if trade is not None:
            trades.append(trade)
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_metrics(trades: Iterable[base.Trade]) -> dict[str, Any]:
    return base.split_metrics([trade for trade in trades if trade.year <= 2023])


def parameter_grid() -> Iterable[dict[str, Any]]:
    for values in itertools.product(
        (2, 4, 8),
        (0.25, 0.5, 0.75),
        (0.25, 0.5, 0.75),
        (0.5, 1.0, 1.5),
        (1.0, 2.0, 3.0),
    ):
        yield dict(
            zip(
                ("range_bars", "gap_atr", "impulse_atr", "stop_atr", "target_r"),
                values,
            )
        )


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    frames: dict[str, Any] = {}
    for instrument in instruments:
        frame = m15.load_bars(instrument)
        frames[instrument.symbol] = frame
        print(json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}), flush=True)
        for parameters in parameter_grid():
            trades = gap_impulse_trades(frame, instrument, **parameters)
            rows.append(
                {
                    "symbol": instrument.symbol,
                    "parameters": parameters,
                    "metrics": preholdout_metrics(trades),
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
        trades = gap_impulse_trades(
            frames[instrument.symbol], instrument, **winner["parameters"]
        )
        metrics = base.split_metrics(trades)
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": "gap_confirmed_opening_impulse_continuation",
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
        "predeclaration": "artifacts/ftmo_m15_gap_impulse_alignment_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "entry_rule": "next_bar_open_after_completed_opening_window",
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
