"""Sealed high-convexity intraday screen for the FTMO 30-day objective.

The screen extends the existing causal intraday engine only along a predeclared
payoff axis: 3R, 5R, and 8R targets. Candidate selection uses 2018-2022 plus
the 2023 validation year. The 2024-2025 holdout is evaluated only for the
locked winner of each family.
"""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Sequence

try:
    from . import ftmo_intraday_candidate_screen as base
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore


TARGETS_R = (3.0, 5.0, 8.0)
EVIDENCE_END_YEAR = 2025


def evidence_horizon(trades: Sequence[base.Trade]) -> list[base.Trade]:
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_score(row: dict[str, Any]) -> float:
    metrics = row["metrics"]
    dev_pf = float(metrics["dev_2018_2022"]["profit_factor"] or 0.0)
    validation_pf = float(metrics["validation_2023"]["profit_factor"] or 0.0)
    return min(dev_pf, validation_pf)


def candidate_rows(instrument: base.Instrument) -> list[dict[str, Any]]:
    frame = base.load_bars(instrument)
    output: list[dict[str, Any]] = []

    for range_bars, buffer_atr, target_r, max_range_atr in itertools.product(
        (1, 2),
        (0.05, 0.10),
        TARGETS_R,
        (1.75, 2.50, 3.50),
    ):
        params = {
            "range_bars": range_bars,
            "buffer_atr": buffer_atr,
            "target_r": target_r,
            "max_range_atr": max_range_atr,
        }
        trades = evidence_horizon(base.opening_range_breakout(frame, instrument, **params))
        output.append(
            {
                "symbol": instrument.symbol,
                "family": "convex_opening_range_breakout",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    for buffer_atr, target_r, max_range_atr in itertools.product(
        (0.05, 0.10),
        TARGETS_R,
        (1.50, 2.50, 3.50),
    ):
        params = {
            "buffer_atr": buffer_atr,
            "target_r": target_r,
            "max_range_atr": max_range_atr,
        }
        trades = evidence_horizon(base.inside_day_breakout(frame, instrument, **params))
        output.append(
            {
                "symbol": instrument.symbol,
                "family": "convex_inside_day_breakout",
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    for entry_offset, impulse_atr, target_r, continuation in itertools.product(
        (2, 3),
        (0.50, 1.00),
        TARGETS_R,
        (False, True),
    ):
        params = {
            "entry_hour": instrument.open_hour + entry_offset,
            "impulse_atr": impulse_atr,
            "stop_atr": 1.0,
            "target_r": target_r,
            "continuation": continuation,
        }
        trades = evidence_horizon(base.opening_impulse(frame, instrument, **params))
        output.append(
            {
                "symbol": instrument.symbol,
                "family": (
                    "convex_opening_impulse_continuation"
                    if continuation
                    else "convex_opening_impulse_fade"
                ),
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )
    return output


def screen(instruments: Sequence[base.Instrument]) -> dict[str, Any]:
    rows = [row for instrument in instruments for row in candidate_rows(instrument)]
    eligible = [row for row in rows if base.preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in eligible}):
        winner = max(
            (row for row in eligible if row["family"] == family),
            key=preholdout_score,
        )
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": winner["family"],
                "parameters": winner["parameters"],
                "preholdout_score": preholdout_score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": (
                    "PASS" if base.holdout_pass(winner["metrics"]) else "FAIL"
                ),
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )

    preholdout = [
        {
            "symbol": row["symbol"],
            "family": row["family"],
            "parameters": row["parameters"],
            "preholdout_score": preholdout_score(row),
            "dev_2018_2022": row["metrics"]["dev_2018_2022"],
            "validation_2023": row["metrics"]["validation_2023"],
            "positive_dev_years": sum(
                row["metrics"]["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
                for year in range(2018, 2023)
            ),
        }
        for row in eligible
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
            "evidence_end_year": EVIDENCE_END_YEAR,
            "target_grid_r": list(TARGETS_R),
            "selection_uses_holdout": False,
            "preholdout_gate": (
                "DEV trades>=100 PF>=1.15; validation trades>=15 PF>=1.05 net>0; "
                ">=3 positive DEV years"
            ),
            "holdout_gate": "trades>=30 PF>=1.10 net>0 and both 2024/2025 positive",
            "collision_rule": "stop_first_if_stop_and_target_touch_same_H1_bar",
            "dual_pending_touch_rule": "count_as_pessimistic_stop",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_candidates": preholdout,
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
    artifact = screen(base.default_instruments(args.data_root))
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
