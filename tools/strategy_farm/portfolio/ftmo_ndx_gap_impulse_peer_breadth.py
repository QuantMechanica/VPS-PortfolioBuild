"""Staged peer-breadth filters for the frozen NDX gap-impulse candidate."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_m15_gap_impulse_alignment_screen as gap_screen
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_gap_impulse_alignment_screen as gap_screen  # type: ignore


RESEARCH_YEARS = (2018, 2019, 2021, 2022, 2023)
VALIDATION_YEAR = 2024
HOLDOUT_YEAR = 2025
BASE_PARAMETERS = {
    "range_bars": 4,
    "gap_atr": 0.25,
    "impulse_atr": 0.75,
    "stop_atr": 1.5,
    "target_r": 3.0,
}
FILTERS = (
    "raw_control",
    "sp500_impulse_025_align",
    "ws30_impulse_025_align",
    "any_peer_impulse_025_align",
    "both_peer_impulse_025_align",
    "both_peer_gap_010_align",
    "peer_majority_3_of_4_010_align",
)
PREDECLARATION = (
    "artifacts/ftmo_ndx_gap_impulse_peer_breadth_predeclaration_2026-07-12.json"
)


def peer_features(
    frame,
    instrument: m15.Instrument,
    *,
    range_bars: int = 4,
) -> dict[str, dict[str, float]]:
    """Return causal peer gap/impulse features available at NDX decision time."""
    days = m15.session_days(frame, instrument)
    opens = m15._values(frame, "open")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    local_dates = m15._values(frame, "local_date")
    output: dict[str, dict[str, float]] = {}
    for position in range(1, len(days)):
        previous = days[position - 1]
        indices = days[position]
        opening = m15.contiguous_opening_indices(
            frame, indices, instrument.session_start_minute, range_bars
        )
        if opening is None:
            continue
        atr = float(atrs[opening[-1]])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        session_open = float(opens[opening[0]])
        output[str(local_dates[opening[0]])] = {
            "gap_atr": (session_open - float(closes[previous[-1]])) / atr,
            "impulse_atr": (float(closes[opening[-1]]) - session_open) / atr,
        }
    return output


def feature_panel(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
) -> dict[str, dict[str, float]]:
    peers = {
        symbol: peer_features(frames[symbol], instruments[symbol])
        for symbol in ("SP500.DWX", "WS30.DWX")
    }
    dates = set(peers["SP500.DWX"]) & set(peers["WS30.DWX"])
    return {
        date: {
            "sp500_gap_atr": peers["SP500.DWX"][date]["gap_atr"],
            "sp500_impulse_atr": peers["SP500.DWX"][date]["impulse_atr"],
            "ws30_gap_atr": peers["WS30.DWX"][date]["gap_atr"],
            "ws30_impulse_atr": peers["WS30.DWX"][date]["impulse_atr"],
        }
        for date in dates
    }


def _aligned(value: float, side: int, threshold: float) -> bool:
    return np.isfinite(value) and float(value) * side >= threshold


def accepts(
    trade: base.Trade,
    features: Mapping[str, Mapping[str, float]],
    name: str,
) -> bool:
    if name not in FILTERS:
        raise ValueError(f"unknown filter: {name}")
    if name == "raw_control":
        return True
    row = features.get(trade.local_date)
    if row is None:
        return False
    impulse = (
        _aligned(float(row["sp500_impulse_atr"]), trade.side, 0.25),
        _aligned(float(row["ws30_impulse_atr"]), trade.side, 0.25),
    )
    gaps = (
        _aligned(float(row["sp500_gap_atr"]), trade.side, 0.10),
        _aligned(float(row["ws30_gap_atr"]), trade.side, 0.10),
    )
    if name == "sp500_impulse_025_align":
        return impulse[0]
    if name == "ws30_impulse_025_align":
        return impulse[1]
    if name == "any_peer_impulse_025_align":
        return any(impulse)
    if name == "both_peer_impulse_025_align":
        return all(impulse)
    if name == "both_peer_gap_010_align":
        return all(gaps)
    components = (
        _aligned(float(row["sp500_gap_atr"]), trade.side, 0.10),
        _aligned(float(row["sp500_impulse_atr"]), trade.side, 0.10),
        _aligned(float(row["ws30_gap_atr"]), trade.side, 0.10),
        _aligned(float(row["ws30_impulse_atr"]), trade.side, 0.10),
    )
    return sum(components) >= 3


def period_metrics(trades: Sequence[base.Trade], years: Sequence[int]) -> dict[str, Any]:
    annual = {
        str(year): base.summarize([trade for trade in trades if trade.year == year])
        for year in years
    }
    annual_pfs = [float(row["profit_factor"] or 0.0) for row in annual.values()]
    return {
        "pooled": base.summarize(trades),
        "annual": annual,
        "positive_years": sum(row["net_r"] > 0.0 for row in annual.values()),
        "worst_annual_profit_factor": min(annual_pfs) if annual_pfs else 0.0,
    }


def research_screen(
    ndx_frame,
    ndx_instrument: m15.Instrument,
    features: Mapping[str, Mapping[str, float]],
) -> dict[str, Any]:
    trades = [
        trade
        for trade in gap_screen.gap_impulse_trades(
            ndx_frame, ndx_instrument, **BASE_PARAMETERS
        )
        if trade.year in RESEARCH_YEARS
    ]
    rows: list[dict[str, Any]] = []
    selected_trades: dict[str, list[base.Trade]] = {}
    for name in FILTERS:
        filtered = [trade for trade in trades if accepts(trade, features, name)]
        selected_trades[name] = filtered
        rows.append({"name": name, "metrics": period_metrics(filtered, RESEARCH_YEARS)})
    control = rows[0]
    control_pf = float(control["metrics"]["pooled"]["profit_factor"] or 0.0)
    survivors = [
        row
        for row in rows[1:]
        if row["metrics"]["pooled"]["trades"] >= 200
        and float(row["metrics"]["pooled"]["profit_factor"] or 0.0) > control_pf
        and row["metrics"]["positive_years"] >= 4
        and row["metrics"]["worst_annual_profit_factor"] >= 0.90
    ]
    survivors.sort(
        key=lambda row: (
            row["metrics"]["worst_annual_profit_factor"],
            float(row["metrics"]["pooled"]["profit_factor"] or 0.0),
            row["metrics"]["pooled"]["trades"],
        ),
        reverse=True,
    )
    selected = survivors[0] if survivors else None
    selected_output = None
    if selected is not None:
        selected_output = {
            **selected,
            "trades": [asdict(trade) for trade in selected_trades[selected["name"]]],
        }
    return {
        "schema_version": 1,
        "status": "RESEARCH_SURVIVOR_FOUND" if selected else "NO_RESEARCH_SURVIVOR",
        "predeclaration": PREDECLARATION,
        "stage": "RESEARCH_2018_2023_ONLY",
        "validation_2024_opened": False,
        "holdout_2025_opened": False,
        "frozen_base_parameters": BASE_PARAMETERS,
        "control": control,
        "evaluated_filters": rows,
        "survivor_count": len(survivors),
        "selected_filter": selected_output,
    }


def validation_pass(metrics: Mapping[str, Any]) -> bool:
    return (
        metrics["trades"] >= 40
        and metrics["net_r"] > 0.0
        and float(metrics["profit_factor"] or 0.0) >= 1.10
    )


def evaluate_year(
    ndx_frame,
    ndx_instrument: m15.Instrument,
    features: Mapping[str, Mapping[str, float]],
    *,
    name: str,
    year: int,
) -> tuple[dict[str, Any], list[base.Trade]]:
    trades = [
        trade
        for trade in gap_screen.gap_impulse_trades(
            ndx_frame, ndx_instrument, **BASE_PARAMETERS
        )
        if trade.year == year and accepts(trade, features, name)
    ]
    return base.summarize(trades), trades


def load_inputs(root: Path, max_year: int):
    wanted = {"NDX.DWX", "SP500.DWX", "WS30.DWX"}
    instruments = {
        instrument.symbol: instrument
        for instrument in m15.default_instruments(root)
        if instrument.symbol in wanted
    }
    if set(instruments) != wanted:
        raise ValueError(f"missing instruments: {sorted(wanted - set(instruments))}")
    frames = {}
    for symbol, instrument in instruments.items():
        frame = m15.load_bars(instrument)
        frames[symbol] = frame[frame["year"] <= max_year].reset_index(drop=True)
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    return frames, instruments


def _load_validation_receipt(path: Path, selected_filter: str) -> dict[str, Any]:
    receipt = json.loads(path.read_text(encoding="utf-8"))
    if receipt.get("status") != "VALIDATION_PASS":
        raise ValueError("holdout requires a VALIDATION_PASS receipt")
    if receipt.get("selected_filter") != selected_filter:
        raise ValueError("validation receipt filter does not match")
    if receipt.get("year") != VALIDATION_YEAR:
        raise ValueError("validation receipt year does not match")
    return receipt


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--stage", choices=("research", "validation", "holdout"), default="research"
    )
    parser.add_argument("--selected-filter", choices=FILTERS[1:])
    parser.add_argument("--validation-receipt", type=Path)
    args = parser.parse_args(argv)

    if args.stage != "research" and not args.selected_filter:
        parser.error("--selected-filter is required after research")
    if args.stage == "holdout" and args.validation_receipt is None:
        parser.error("--validation-receipt is required for holdout")

    max_year = {
        "research": max(RESEARCH_YEARS),
        "validation": VALIDATION_YEAR,
        "holdout": HOLDOUT_YEAR,
    }[args.stage]
    frames, instruments = load_inputs(args.data_root, max_year)
    features = feature_panel(frames, instruments)
    if args.stage == "research":
        output = research_screen(frames["NDX.DWX"], instruments["NDX.DWX"], features)
    else:
        if args.stage == "holdout":
            _load_validation_receipt(args.validation_receipt, args.selected_filter)
        year = VALIDATION_YEAR if args.stage == "validation" else HOLDOUT_YEAR
        metrics, trades = evaluate_year(
            frames["NDX.DWX"],
            instruments["NDX.DWX"],
            features,
            name=args.selected_filter,
            year=year,
        )
        passed = validation_pass(metrics)
        output = {
            "schema_version": 1,
            "status": (
                "VALIDATION_PASS" if args.stage == "validation" and passed
                else "VALIDATION_FAIL" if args.stage == "validation"
                else "HOLDOUT_PASS" if passed
                else "HOLDOUT_FAIL"
            ),
            "predeclaration": PREDECLARATION,
            "stage": args.stage.upper(),
            "selected_filter": args.selected_filter,
            "year": year,
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
