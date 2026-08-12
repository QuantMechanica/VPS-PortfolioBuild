"""Staged variance-scaled follow-up to the opening-compression screen."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from dataclasses import asdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_m15_compression_breakout_screen as raw
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_compression_breakout_screen as raw  # type: ignore


PREDECLARATION = (
    "artifacts/ftmo_m15_scaled_compression_breakout_predeclaration_2026-07-12.json"
)
VALIDATION_YEAR = 2024
HOLDOUT_YEAR = 2025


def parameter_grid():
    for values in itertools.product(
        (4, 8),
        (4, 8),
        (0.75, 1.0, 1.25),
        (0.05, 0.15),
        (0.75, 1.25),
        (2.0, 3.0),
    ):
        yield dict(
            zip(
                (
                    "range_bars",
                    "active_bars",
                    "max_scaled_range",
                    "breakout_buffer_atr",
                    "stop_atr",
                    "target_r",
                ),
                values,
            )
        )


def scaled_trades(frame, instrument: m15.Instrument, **parameters):
    params = dict(parameters)
    range_bars = int(params["range_bars"])
    max_scaled_range = float(params.pop("max_scaled_range"))
    return raw.compression_breakout_trades(
        frame,
        instrument,
        max_range_atr=max_scaled_range * math.sqrt(range_bars),
        **params,
    )


def load_frames(root: Path, max_year: int):
    instruments = {item.symbol: item for item in m15.default_instruments(root)}
    frames = {}
    for symbol, instrument in instruments.items():
        frame = m15.load_bars(instrument)
        frames[symbol] = frame[frame["year"] <= max_year].reset_index(drop=True)
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    return frames, instruments


def research_screen(frames, instruments: Mapping[str, m15.Instrument]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    trade_sets: dict[tuple[str, tuple[tuple[str, Any], ...]], list[base.Trade]] = {}
    for symbol, instrument in instruments.items():
        frame = frames[symbol]
        print(json.dumps({"stage": "loaded", "symbol": symbol, "bars": len(frame)}), flush=True)
        for parameters in parameter_grid():
            trades = scaled_trades(frame, instrument, **parameters)
            metrics = base.split_metrics(trades)
            key = (symbol, tuple(parameters.items()))
            trade_sets[key] = trades
            rows.append({"symbol": symbol, "parameters": parameters, "metrics": metrics})

    eligible = [row for row in rows if m15.preholdout_pass(row["metrics"])]
    eligible.sort(
        key=lambda row: (
            m15.preholdout_score(row),
            row["metrics"]["dev_2018_2022"]["trades"],
        ),
        reverse=True,
    )
    selected = None
    if eligible:
        winner = eligible[0]
        key = (winner["symbol"], tuple(winner["parameters"].items()))
        selected = {
            "symbol": winner["symbol"],
            "parameters": winner["parameters"],
            "preholdout_score": m15.preholdout_score(winner),
            "metrics": winner["metrics"],
            "trades": [asdict(trade) for trade in trade_sets[key]],
        }

    leaders = sorted(
        rows,
        key=lambda row: (
            m15.preholdout_score(row),
            row["metrics"]["dev_2018_2022"]["trades"],
        ),
        reverse=True,
    )[:20]
    return {
        "schema_version": 1,
        "status": "RESEARCH_SURVIVOR_FOUND" if selected else "NO_RESEARCH_SURVIVOR",
        "predeclaration": PREDECLARATION,
        "stage": "RESEARCH_2018_2023_ONLY",
        "validation_2024_opened": False,
        "holdout_2025_opened": False,
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "leaderboard": [
            {
                "symbol": row["symbol"],
                "parameters": row["parameters"],
                "preholdout_score": m15.preholdout_score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
            }
            for row in leaders
        ],
        "selected_candidate": selected,
        "deployment_allowed": False,
    }


def stage_pass(metrics: Mapping[str, Any]) -> bool:
    return (
        metrics["trades"] >= 25
        and metrics["net_r"] > 0.0
        and float(metrics["profit_factor"] or 0.0) >= 1.10
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load_research_receipt(path: Path) -> tuple[dict[str, Any], str]:
    receipt = json.loads(path.read_text(encoding="utf-8"))
    if receipt.get("status") != "RESEARCH_SURVIVOR_FOUND":
        raise ValueError("validation requires a RESEARCH_SURVIVOR_FOUND receipt")
    selected = receipt.get("selected_candidate")
    if not isinstance(selected, dict) or not selected.get("symbol") or not selected.get("parameters"):
        raise ValueError("research receipt has no frozen selected candidate")
    return selected, _sha256(path)


def load_validation_receipt(path: Path) -> tuple[dict[str, Any], str]:
    receipt = json.loads(path.read_text(encoding="utf-8"))
    if receipt.get("status") != "VALIDATION_PASS" or receipt.get("year") != VALIDATION_YEAR:
        raise ValueError("holdout requires a matching 2024 VALIDATION_PASS receipt")
    selected = receipt.get("selected_candidate")
    if not isinstance(selected, dict) or not selected.get("symbol") or not selected.get("parameters"):
        raise ValueError("validation receipt has no frozen selected candidate")
    return selected, _sha256(path)


def evaluate_stage(
    frames,
    instruments: Mapping[str, m15.Instrument],
    selected: Mapping[str, Any],
    year: int,
):
    symbol = str(selected["symbol"])
    if symbol not in instruments:
        raise ValueError(f"unknown frozen symbol: {symbol}")
    trades = [
        trade
        for trade in scaled_trades(
            frames[symbol], instruments[symbol], **dict(selected["parameters"])
        )
        if trade.year == year
    ]
    return base.summarize(trades), trades


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--stage", choices=("research", "validation", "holdout"), default="research"
    )
    parser.add_argument("--research-receipt", type=Path)
    parser.add_argument("--validation-receipt", type=Path)
    args = parser.parse_args(argv)

    if args.stage == "validation" and args.research_receipt is None:
        parser.error("--research-receipt is required for validation")
    if args.stage == "holdout" and args.validation_receipt is None:
        parser.error("--validation-receipt is required for holdout")

    max_year = {"research": 2023, "validation": 2024, "holdout": 2025}[args.stage]
    frames, instruments = load_frames(args.data_root, max_year)
    if args.stage == "research":
        output = research_screen(frames, instruments)
    else:
        if args.stage == "validation":
            selected, receipt_hash = load_research_receipt(args.research_receipt)
            receipt_path = args.research_receipt
            year = VALIDATION_YEAR
        else:
            selected, receipt_hash = load_validation_receipt(args.validation_receipt)
            receipt_path = args.validation_receipt
            year = HOLDOUT_YEAR
        metrics, trades = evaluate_stage(frames, instruments, selected, year)
        passed = stage_pass(metrics)
        label = "VALIDATION" if args.stage == "validation" else "HOLDOUT"
        output = {
            "schema_version": 1,
            "status": f"{label}_{'PASS' if passed else 'FAIL'}",
            "predeclaration": PREDECLARATION,
            "stage": label,
            "year": year,
            "input_receipt": str(receipt_path),
            "input_receipt_sha256": receipt_hash,
            "selected_candidate": {
                "symbol": selected["symbol"],
                "parameters": selected["parameters"],
            },
            "metrics": metrics,
            "trades": [asdict(trade) for trade in trades],
            "deployment_allowed": False,
        }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), "status": output["status"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
