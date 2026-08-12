"""One-shot 2025 holdout for frozen NDX majority-filtered gap continuation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Sequence

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_m15_gap_response_screen as gap_screen
    from . import ftmo_ndx_gap_impulse_nested_filter as prior_filters
    from . import ftmo_ndx_gap_response_nested_filter as nested
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_gap_response_screen as gap_screen  # type: ignore
    import ftmo_ndx_gap_impulse_nested_filter as prior_filters  # type: ignore
    import ftmo_ndx_gap_response_nested_filter as nested  # type: ignore


HOLDOUT_YEAR = 2025
FROZEN_FILTER = "majority_2_of_3_align"


def holdout_pass(metrics: dict[str, Any]) -> bool:
    return (
        int(metrics["trades"]) >= 40
        and float(metrics["profit_factor"] or 0.0) >= 1.10
        and float(metrics["net_r"]) > 0.0
    )


def evaluate(frame, instrument: m15.Instrument) -> dict[str, Any]:
    trades = gap_screen.gap_response_trades(
        frame, instrument, **nested.FROZEN_PARAMETERS, end_year=HOLDOUT_YEAR
    )
    features = prior_filters.daily_features(frame, instrument)
    holdout_trades = [
        trade
        for trade in trades
        if trade.year == HOLDOUT_YEAR
        and prior_filters.accepts(trade, features, FROZEN_FILTER)
    ]
    metrics = base.summarize(holdout_trades)
    passed = holdout_pass(metrics)
    return {
        "schema_version": 1,
        "status": "HOLDOUT_2025_PASS" if passed else "HOLDOUT_2025_FAIL",
        "predeclaration": "artifacts/ftmo_ndx_gap_response_nested_filter_predeclaration_2026-07-12.json",
        "research_selection": "artifacts/ftmo_ndx_gap_response_nested_filter_research_2026-07-12.json",
        "validation_2024": "artifacts/ftmo_ndx_gap_response_validation_2024_2026-07-12.json",
        "symbol": instrument.symbol,
        "frozen_parameters": nested.FROZEN_PARAMETERS,
        "frozen_filter": FROZEN_FILTER,
        "holdout_year": HOLDOUT_YEAR,
        "holdout_gate": "trades>=40, PF>=1.10, net R>0",
        "metrics": metrics,
        "research_survivor": passed,
        "native_mt5_required": passed,
        "portfolio_admission_allowed": False,
        "deployment_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    instrument = next(
        item for item in m15.default_instruments(args.data_root) if item.symbol == "NDX.DWX"
    )
    frame = m15.load_bars(instrument)
    frame = frame[frame["year"] <= HOLDOUT_YEAR].reset_index(drop=True)
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    output = evaluate(frame, instrument)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), **output}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
