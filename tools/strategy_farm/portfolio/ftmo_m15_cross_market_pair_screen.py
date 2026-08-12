"""Sealed cross-market pair screen using the established joint-extreme engine."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_m15_expanded_market_screen as expanded
    from . import ftmo_m15_us_index_pair_reversion as pair_engine
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_expanded_market_screen as expanded  # type: ignore
    import ftmo_m15_us_index_pair_reversion as pair_engine  # type: ignore


PAIRS = (
    ("GDAXI.DWX", "UK100.DWX"),
    ("XAUUSD.DWX", "XAGUSD.DWX"),
    ("XTIUSD.DWX", "XNGUSD.DWX"),
)


def parameter_grid() -> Iterable[dict[str, Any]]:
    for mode, pair, lookback, divergence, stop_atr, target_r, hold_bars in itertools.product(
        ("reversion", "momentum"),
        PAIRS,
        (2, 4, 8),
        (0.25, 0.5, 0.75),
        (0.5, 1.0),
        (1.0, 2.0, 3.0),
        (2, 4, 8),
    ):
        yield {
            "mode": mode,
            "pair": pair,
            "lookback_bars": lookback,
            "divergence_atr": divergence,
            "portfolio_stop_atr": stop_atr,
            "target_r": target_r,
            "hold_bars": hold_bars,
        }


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_dev_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return bool(
        dev["trades"] >= 150
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.18
        and validation["trades"] >= 25
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.10
        and positive_dev_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return bool(
        holdout["trades"] >= 50
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def score(row: Mapping[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def load_inputs(root: Path):
    all_instruments = [*m15.default_instruments(root), *expanded.expanded_instruments(root)]
    needed = {symbol for pair in PAIRS for symbol in pair}
    instruments = {item.symbol: item for item in all_instruments if item.symbol in needed}
    if set(instruments) != needed:
        raise ValueError(f"missing instruments: {sorted(needed - set(instruments))}")
    frames = {symbol: m15.load_bars(instruments[symbol]) for symbol in sorted(needed)}
    return frames, instruments


def _trades(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
    parameters: Mapping[str, Any],
    *,
    end_year: int,
):
    return pair_engine.pair_reversion_trades(
        frames,
        instruments,
        pair=tuple(parameters["pair"]),
        lookback_bars=int(parameters["lookback_bars"]),
        divergence_atr=float(parameters["divergence_atr"]),
        portfolio_stop_atr=float(parameters["portfolio_stop_atr"]),
        target_r=float(parameters["target_r"]),
        hold_bars=int(parameters["hold_bars"]),
        end_year=end_year,
        mode=str(parameters["mode"]),
    )


def screen(frames: Mapping[str, Any], instruments: Mapping[str, m15.Instrument]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for parameters in parameter_grid():
        trades = _trades(frames, instruments, parameters, end_year=2023)
        rows.append({"parameters": parameters, "metrics": base.split_metrics(trades)})

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    winner = max(
        eligible,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        default=None,
    )
    selected: dict[str, Any] | None = None
    if winner is not None:
        trades = _trades(frames, instruments, winner["parameters"], end_year=2025)
        metrics = base.split_metrics(trades)
        selected = {
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
        "predeclaration": "artifacts/ftmo_m15_cross_market_pair_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "winner_count": 1,
            "holdout_opened": selected is not None,
            "same_bar_rule": "joint_adverse_extremes_stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
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
