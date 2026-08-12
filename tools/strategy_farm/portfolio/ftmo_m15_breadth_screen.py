"""Sealed M15 screen for broad US-index opening moves.

The strategy observes completed cash-session bars for NDX, SP500, and WS30.
When at least two markets move together, it trades an equal-risk package in
the breadth direction or against it. Candidate selection uses 2018-2022 plus
2023; only one locked winner per direction is evaluated on 2024-2025.
"""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_cross_index_screen as cross
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_cross_index_screen as cross  # type: ignore


EVIDENCE_END_YEAR = 2025


def breadth_packages(
    panel: pd.DataFrame,
    *,
    signal_bars: int,
    min_breadth_atr: float,
    min_agreement: int,
    stop_atr: float,
    target_r: float,
    hold_bars: int,
    continuation: bool,
) -> list[base.Trade]:
    """Build one equal-risk package from a completed opening-breadth signal."""

    minutes = cross._values(panel, "minute")
    utc_values = cross._values(panel, "utc")
    local_dates = cross._values(panel, "local_date")
    years = cross._values(panel, "year")
    opens = {
        symbol: cross._values(panel, f"{symbol}:open") for symbol in cross.SYMBOLS
    }
    closes = {
        symbol: cross._values(panel, f"{symbol}:close") for symbol in cross.SYMBOLS
    }
    atr_values = {
        symbol: cross._values(panel, f"{symbol}:atr56") for symbol in cross.SYMBOLS
    }
    price_arrays = {
        symbol: {
            "open": opens[symbol],
            "high": cross._values(panel, f"{symbol}:high"),
            "low": cross._values(panel, f"{symbol}:low"),
            "close": closes[symbol],
        }
        for symbol in cross.SYMBOLS
    }
    trades: list[base.Trade] = []

    for indices in cross.session_days(panel):
        if signal_bars <= 0 or len(indices) <= signal_bars:
            continue
        expected = [
            cross.SESSION_START_MINUTE + 15 * offset
            for offset in range(signal_bars + 1)
        ]
        if [int(minutes[index]) for index in indices[: signal_bars + 1]] != expected:
            continue

        signal_last = indices[signal_bars - 1]
        entry_index = indices[signal_bars]
        scores: dict[str, float] = {}
        atrs: dict[str, float] = {}
        for symbol in cross.SYMBOLS:
            atr = float(atr_values[symbol][signal_last])
            session_open = float(opens[symbol][indices[0]])
            if not np.isfinite(atr) or atr <= 0.0 or session_open <= 0.0:
                scores = {}
                break
            atrs[symbol] = atr
            scores[symbol] = (
                float(closes[symbol][signal_last]) - session_open
            ) / atr
        if len(scores) != len(cross.SYMBOLS):
            continue

        breadth = float(np.mean(list(scores.values())))
        if breadth == 0.0 or abs(breadth) < min_breadth_atr:
            continue
        signal_side = 1 if breadth > 0.0 else -1
        agreement = sum(
            1 for value in scores.values() if (value > 0.0) == (signal_side > 0)
        )
        if agreement < min_agreement:
            continue
        side = signal_side if continuation else -signal_side

        end_position = min(len(indices) - 1, signal_bars + hold_bars - 1)
        path = indices[signal_bars : end_position + 1]
        leg_results = [
            cross.simulate_leg(
                panel,
                symbol=symbol,
                path=path,
                entry_index=entry_index,
                side=side,
                atr=atrs[symbol],
                stop_atr=stop_atr,
                target_r=target_r,
                price_arrays=price_arrays,
            )
            for symbol in cross.SYMBOLS
        ]
        if not all(np.isfinite(value) for value in leg_results):
            continue
        trades.append(
            base.Trade(
                entry_time_utc=pd.Timestamp(utc_values[entry_index]).isoformat(),
                local_date=str(local_dates[entry_index]),
                year=int(years[entry_index]),
                side=side,
                r_multiple=float(np.mean(leg_results)),
                exit_reason=(
                    f"breadth_{'continuation' if continuation else 'reversal'}:"
                    f"agreement={agreement}"
                ),
            )
        )
    return [trade for trade in trades if trade.year <= EVIDENCE_END_YEAR]


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return (
        dev["trades"] >= 200
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.12
        and validation["trades"] >= 35
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 70
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def score(row: dict[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def screen(panel: pd.DataFrame) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    axes = itertools.product(
        (2, 4, 8),
        (0.10, 0.25, 0.50),
        (2, 3),
        (0.50, 1.0, 1.5),
        (0.0, 2.0, 4.0),
        (8, 99),
        (False, True),
    )
    for signal_bars, breadth, agreement, stop, target, hold, continuation in axes:
        params = {
            "signal_bars": signal_bars,
            "min_breadth_atr": breadth,
            "min_agreement": agreement,
            "stop_atr": stop,
            "target_r": target,
            "hold_bars": hold,
            "continuation": continuation,
        }
        trades = breadth_packages(panel, **params)
        rows.append(
            {
                "family": (
                    "opening_breadth_continuation"
                    if continuation
                    else "opening_breadth_reversal"
                ),
                "parameters": params,
                "metrics": base.split_metrics(trades),
                "trades": trades,
            }
        )

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    selected: list[dict[str, Any]] = []
    families = sorted({row["family"] for row in rows})
    for family in families:
        candidates = [row for row in eligible if row["family"] == family]
        if not candidates:
            continue
        winner = max(
            candidates,
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        )
        selected.append(
            {
                "family": family,
                "parameters": winner["parameters"],
                "preholdout_score": score(winner),
                "metrics": winner["metrics"],
                "holdout_verdict": (
                    "PASS" if holdout_pass(winner["metrics"]) else "FAIL"
                ),
                "trades": [asdict(trade) for trade in winner["trades"]],
            }
        )

    leaderboard: dict[str, list[dict[str, Any]]] = {}
    for family in families:
        leaders = sorted(
            (row for row in rows if row["family"] == family),
            key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
            reverse=True,
        )[:5]
        leaderboard[family] = [
            {
                "parameters": row["parameters"],
                "preholdout_score": score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
                "positive_dev_years": sum(
                    row["metrics"]["annual"]
                    .get(str(year), {})
                    .get("net_r", 0.0)
                    > 0.0
                    for year in range(2018, 2023)
                ),
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
        "selection_contract": {
            "universe": list(cross.SYMBOLS),
            "risk": "equal one-third package risk per independently stopped leg",
            "signal_information": "completed US cash-session M15 bars only",
            "timestamp_basis": "Darwinex broker wall converted to UTC then America/New_York",
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "same_bar_rule": "stop_first",
            "daily_position_limit": "one three-leg package",
            "overnight_positions": False,
            "search_burden": "one locked winner opened per two prespecified direction families",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": leaderboard,
        "selected_family_winners": selected,
        "holdout_pass_count": sum(
            row["holdout_verdict"] == "PASS" for row in selected
        ),
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
    artifact = screen(cross.load_panel(args.data_root))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
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
