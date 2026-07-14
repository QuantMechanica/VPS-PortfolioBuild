"""Research-only prior-session filters for frozen NDX first-bar gap continuation."""

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
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_gap_response_screen as gap_screen  # type: ignore
    import ftmo_ndx_gap_impulse_nested_filter as prior_filters  # type: ignore


RESEARCH_YEARS = (2018, 2019, 2021, 2022, 2023)
FROZEN_PARAMETERS = {
    "mode": "continuation",
    "gap_atr": 1.0,
    "response_atr": 0.15,
    "stop_atr": 1.5,
    "target_r": 3.0,
}


def filter_metrics(trades: Sequence[base.Trade]) -> dict[str, Any]:
    pooled = base.summarize(trades)
    annual = {
        str(year): base.summarize([trade for trade in trades if trade.year == year])
        for year in RESEARCH_YEARS
    }
    positive_years = sum(row["net_r"] > 0.0 for row in annual.values())
    annual_pfs = [float(row["profit_factor"] or 0.0) for row in annual.values()]
    return {
        "pooled": pooled,
        "annual": annual,
        "positive_years": positive_years,
        "worst_annual_profit_factor": min(annual_pfs),
    }


def research_screen(frame, instrument: m15.Instrument) -> dict[str, Any]:
    trades = gap_screen.gap_response_trades(
        frame, instrument, **FROZEN_PARAMETERS, end_year=2023
    )
    features = prior_filters.daily_features(frame, instrument)
    rows: list[dict[str, Any]] = []
    for name in prior_filters.FILTERS:
        filtered = [
            trade for trade in trades if prior_filters.accepts(trade, features, name)
        ]
        rows.append({"name": name, "metrics": filter_metrics(filtered)})

    control = next(row for row in rows if row["name"] == "raw_control")
    control_pf = float(control["metrics"]["pooled"]["profit_factor"] or 0.0)
    survivors = [
        row
        for row in rows
        if row["name"] != "raw_control"
        and row["metrics"]["pooled"]["trades"] >= 180
        and float(row["metrics"]["pooled"]["profit_factor"] or 0.0) >= 1.15
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
    return {
        "schema_version": 1,
        "status": "RESEARCH_SURVIVOR_FOUND" if survivors else "NO_RESEARCH_SURVIVOR",
        "predeclaration": "artifacts/ftmo_ndx_gap_response_nested_filter_predeclaration_2026-07-12.json",
        "stage": "RESEARCH_2018_2023_ONLY",
        "validation_2024_opened": False,
        "holdout_2025_opened": False,
        "symbol": instrument.symbol,
        "frozen_base_parameters": FROZEN_PARAMETERS,
        "control": control,
        "evaluated_filters": rows,
        "survivor_count": len(survivors),
        "selected_filter": survivors[0] if survivors else None,
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
    frame = frame[frame["year"] <= 2023].reset_index(drop=True)
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    output = research_screen(frame, instrument)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "survivors": output["survivor_count"],
                "selected": (
                    output["selected_filter"]["name"] if output["selected_filter"] else None
                ),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
