"""Sealed baseline M15 screen for UK100, silver, crude oil, and natural gas."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Callable, Sequence

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


def expanded_instruments(root: Path) -> list[m15.Instrument]:
    return [
        m15.Instrument("UK100.DWX", root / "UK100.DWX_M15.csv", "Europe/London", 8 * 60, 16 * 60 + 30, 4.0),
        m15.Instrument("XAGUSD.DWX", root / "XAGUSD.DWX_M15.csv", "America/New_York", 8 * 60 + 30, 17 * 60, 0.03),
        m15.Instrument("XTIUSD.DWX", root / "XTIUSD.DWX_M15.csv", "America/New_York", 9 * 60, 14 * 60 + 30, 0.05),
        m15.Instrument("XNGUSD.DWX", root / "XNGUSD.DWX_M15.csv", "America/New_York", 9 * 60, 14 * 60 + 30, 0.02),
    ]


def _definitions() -> list[tuple[str, Callable[..., list[base.Trade]], dict[str, Any]]]:
    rows: list[tuple[str, Callable[..., list[base.Trade]], dict[str, Any]]] = []
    for values in itertools.product(
        (1, 2, 4), (4, 8), (0.05, 0.10), (1.5, 2.5), (2.0, 3.0, 5.0)
    ):
        params = dict(zip(("range_bars", "active_bars", "buffer_atr", "max_range_atr", "target_r"), values))
        family = "m15_orb_convex" if params["target_r"] >= 3.0 else "m15_orb_balanced"
        rows.append((family, m15.opening_range_breakout, params))
    for values in itertools.product(
        (2, 4), (0.5, 1.0), (0.5, 1.0), (2.0, 3.0, 5.0), (False, True)
    ):
        params = dict(zip(("range_bars", "impulse_atr", "stop_atr", "target_r", "continuation"), values))
        family = "m15_impulse_cont" if params["continuation"] else "m15_impulse_fade"
        rows.append((family, m15.opening_impulse, params))
    for values in itertools.product(
        (0.25, 0.5, 1.0), (0.5, 1.0), (2.0, 3.0), (False, True)
    ):
        params = dict(zip(("gap_atr", "stop_atr", "target_r", "continuation"), values))
        family = "m15_gap_cont" if params["continuation"] else "m15_gap_fade"
        rows.append((family, m15.session_gap, params))
    return rows


def screen(instruments: Sequence[m15.Instrument]) -> dict[str, Any]:
    definitions = _definitions()
    rows: list[dict[str, Any]] = []
    frames: dict[str, Any] = {}
    for instrument in instruments:
        frame = m15.load_bars(instrument)
        frames[instrument.symbol] = frame
        print(json.dumps({"stage": "loaded", "symbol": instrument.symbol, "bars": len(frame)}), flush=True)
        for family, generator, parameters in definitions:
            trades = [
                trade
                for trade in generator(frame, instrument, **parameters)
                if trade.year <= 2023
            ]
            rows.append(
                {
                    "symbol": instrument.symbol,
                    "family": family,
                    "parameters": parameters,
                    "metrics": base.split_metrics(trades),
                }
            )

    eligible = [row for row in rows if m15.preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in eligible}):
        winner = max(
            (row for row in eligible if row["family"] == family),
            key=lambda row: (
                m15.preholdout_score(row),
                row["metrics"]["dev_2018_2022"]["trades"],
            ),
        )
        instrument = next(item for item in instruments if item.symbol == winner["symbol"])
        definition = next(
            item
            for item in definitions
            if item[0] == family and item[2] == winner["parameters"]
        )
        trades = definition[1](
            frames[instrument.symbol], instrument, **winner["parameters"]
        )
        metrics = base.split_metrics([trade for trade in trades if trade.year <= 2025])
        selected.append(
            {
                "symbol": winner["symbol"],
                "family": family,
                "parameters": winner["parameters"],
                "preholdout_score": m15.preholdout_score(winner),
                "metrics": metrics,
                "holdout_verdict": "PASS" if m15.holdout_pass(metrics) else "FAIL",
                "trades": [asdict(trade) for trade in trades if trade.year <= 2025],
            }
        )

    leaderboard: dict[str, list[dict[str, Any]]] = {}
    for family in sorted({row["family"] for row in rows}):
        leaders = sorted(
            (row for row in rows if row["family"] == family),
            key=lambda row: (
                m15.preholdout_score(row),
                row["metrics"]["dev_2018_2022"]["trades"],
            ),
            reverse=True,
        )[:5]
        leaderboard[family] = [
            {
                "symbol": row["symbol"],
                "parameters": row["parameters"],
                "preholdout_score": m15.preholdout_score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
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
        "predeclaration": "artifacts/ftmo_m15_expanded_market_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "same_bar_rule": "stop_first",
            "native_mt5_required_for_survivor": True,
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
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(expanded_instruments(args.data_root))
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
