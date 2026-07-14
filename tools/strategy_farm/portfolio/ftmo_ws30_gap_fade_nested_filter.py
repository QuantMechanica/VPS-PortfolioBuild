"""Research-only nested filters for the frozen WS30 gap-fade near-miss."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
    from . import ftmo_m15_gap_response_screen as gap_screen
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    import ftmo_m15_gap_response_screen as gap_screen  # type: ignore


RESEARCH_YEARS = (2018, 2019, 2020, 2021, 2022, 2023)
FILTERS = (
    "raw_control",
    "sma20_align",
    "momentum5_align",
    "prior_session_align",
    "majority_2_of_3_align",
    "low_volatility",
    "momentum5_align_low_volatility",
)


def daily_features(frame, instrument: m15.Instrument) -> dict[str, dict[str, float]]:
    days = m15.session_days(frame, instrument)
    opens = m15._values(frame, "open")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    local_dates = m15._values(frame, "local_date")
    session_opens = [float(opens[indices[0]]) for indices in days]
    session_closes = [float(closes[indices[-1]]) for indices in days]
    session_atrs = [float(atrs[indices[-1]]) for indices in days]
    output: dict[str, dict[str, float]] = {}
    for position in range(1, len(days)):
        prior = position - 1
        date = str(local_dates[days[position][0]])
        prior_close = session_closes[prior]
        sma20 = (
            float(np.mean(session_closes[prior - 19 : prior + 1]))
            if prior >= 19
            else np.nan
        )
        momentum5 = (
            prior_close - session_closes[prior - 5] if prior >= 5 else np.nan
        )
        atr20_median = (
            float(np.median(session_atrs[prior - 19 : prior + 1]))
            if prior >= 19
            else np.nan
        )
        output[date] = {
            "sma20_delta": prior_close - sma20 if np.isfinite(sma20) else np.nan,
            "momentum5": momentum5,
            "prior_session_move": prior_close - session_opens[prior],
            "prior_atr": session_atrs[prior],
            "atr20_median": atr20_median,
        }
    return output


def _aligns(value: float, side: int) -> bool:
    return np.isfinite(value) and value * side > 0.0


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
    flags = {
        "sma20_align": _aligns(float(row["sma20_delta"]), trade.side),
        "momentum5_align": _aligns(float(row["momentum5"]), trade.side),
        "prior_session_align": _aligns(float(row["prior_session_move"]), trade.side),
    }
    low_volatility = (
        np.isfinite(float(row["prior_atr"]))
        and np.isfinite(float(row["atr20_median"]))
        and float(row["prior_atr"]) <= float(row["atr20_median"])
    )
    if name == "majority_2_of_3_align":
        return sum(flags.values()) >= 2
    if name == "low_volatility":
        return low_volatility
    if name == "momentum5_align_low_volatility":
        return flags["momentum5_align"] and low_volatility
    return flags[name]


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
    parameters = {
        "mode": "fade",
        "gap_atr": 1.0,
        "response_atr": 0.0,
        "stop_atr": 1.5,
        "target_r": 3.0,
    }
    trades = gap_screen.gap_response_trades(
        frame, instrument, **parameters, end_year=2023
    )
    features = daily_features(frame, instrument)
    rows: list[dict[str, Any]] = []
    for name in FILTERS:
        filtered = [trade for trade in trades if accepts(trade, features, name)]
        rows.append({"name": name, "metrics": filter_metrics(filtered)})

    control = next(row for row in rows if row["name"] == "raw_control")
    control_pf = float(control["metrics"]["pooled"]["profit_factor"] or 0.0)
    survivors = [
        row
        for row in rows
        if row["name"] != "raw_control"
        and row["metrics"]["pooled"]["trades"] >= 200
        and float(row["metrics"]["pooled"]["profit_factor"] or 0.0) >= 1.15
        and float(row["metrics"]["pooled"]["profit_factor"] or 0.0) > control_pf
        and row["metrics"]["positive_years"] >= 5
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
        "predeclaration": "artifacts/ftmo_ws30_gap_fade_nested_filter_predeclaration_2026-07-12.json",
        "stage": "RESEARCH_2018_2023_ONLY",
        "validation_2024_opened": False,
        "holdout_2025_opened": False,
        "symbol": instrument.symbol,
        "frozen_base_parameters": parameters,
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
        item for item in m15.default_instruments(args.data_root) if item.symbol == "WS30.DWX"
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
