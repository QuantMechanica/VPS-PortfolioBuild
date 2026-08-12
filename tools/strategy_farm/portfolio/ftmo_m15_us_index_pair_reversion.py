"""Sealed M15 screen for market-neutral US-index pair reversion."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


US_SYMBOLS = ("NDX.DWX", "SP500.DWX", "WS30.DWX")
PAIRS = tuple(itertools.combinations(US_SYMBOLS, 2))


def synchronized_sessions(
    frame_a: Any,
    instrument_a: m15.Instrument,
    frame_b: Any,
    instrument_b: m15.Instrument,
) -> list[tuple[list[int], list[int]]]:
    sessions_a = {
        str(m15._values(frame_a, "local_date")[indices[0]]): indices
        for indices in m15.session_days(frame_a, instrument_a)
    }
    sessions_b = {
        str(m15._values(frame_b, "local_date")[indices[0]]): indices
        for indices in m15.session_days(frame_b, instrument_b)
    }
    utc_a = m15._values(frame_a, "utc")
    utc_b = m15._values(frame_b, "utc")
    synchronized: list[tuple[list[int], list[int]]] = []
    for date in sorted(set(sessions_a) & set(sessions_b)):
        map_a = {utc_a[index]: index for index in sessions_a[date]}
        map_b = {utc_b[index]: index for index in sessions_b[date]}
        common = sorted(set(map_a) & set(map_b))
        if common:
            synchronized.append(
                ([int(map_a[timestamp]) for timestamp in common], [int(map_b[timestamp]) for timestamp in common])
            )
    return synchronized


def simulate_pair_trade(
    frame_a: Any,
    frame_b: Any,
    *,
    path_a: Sequence[int],
    path_b: Sequence[int],
    side_a: int,
    atr_a: float,
    atr_b: float,
    portfolio_stop_atr: float,
    target_r: float,
    cost_points_a: float,
    cost_points_b: float,
    reason: str,
) -> base.Trade | None:
    if (
        side_a not in (-1, 1)
        or len(path_a) == 0
        or len(path_a) != len(path_b)
        or atr_a <= 0.0
        or atr_b <= 0.0
        or portfolio_stop_atr <= 0.0
        or target_r <= 0.0
    ):
        return None
    side_b = -side_a
    opens_a = m15._values(frame_a, "open")
    highs_a = m15._values(frame_a, "high")
    lows_a = m15._values(frame_a, "low")
    closes_a = m15._values(frame_a, "close")
    opens_b = m15._values(frame_b, "open")
    highs_b = m15._values(frame_b, "high")
    lows_b = m15._values(frame_b, "low")
    closes_b = m15._values(frame_b, "close")
    entry_a = float(opens_a[path_a[0]])
    entry_b = float(opens_b[path_b[0]])
    if entry_a <= 0.0 or entry_b <= 0.0:
        return None

    cost_atr = 0.5 * (cost_points_a / atr_a + cost_points_b / atr_b)
    stop_gross = -portfolio_stop_atr
    target_gross = portfolio_stop_atr * target_r
    exit_reason = "time"
    gross_result = 0.0
    for index_a, index_b in zip(path_a, path_b):
        adverse_a = float(lows_a[index_a] if side_a > 0 else highs_a[index_a])
        favorable_a = float(highs_a[index_a] if side_a > 0 else lows_a[index_a])
        adverse_b = float(lows_b[index_b] if side_b > 0 else highs_b[index_b])
        favorable_b = float(highs_b[index_b] if side_b > 0 else lows_b[index_b])
        adverse = 0.5 * (
            side_a * (adverse_a - entry_a) / atr_a
            + side_b * (adverse_b - entry_b) / atr_b
        )
        favorable = 0.5 * (
            side_a * (favorable_a - entry_a) / atr_a
            + side_b * (favorable_b - entry_b) / atr_b
        )
        if adverse <= stop_gross:
            gross_result = stop_gross
            exit_reason = "stop_pessimistic" if favorable >= target_gross else "stop"
            break
        if favorable >= target_gross:
            gross_result = target_gross
            exit_reason = "target"
            break
    else:
        gross_result = 0.5 * (
            side_a * (float(closes_a[path_a[-1]]) - entry_a) / atr_a
            + side_b * (float(closes_b[path_b[-1]]) - entry_b) / atr_b
        )

    result_r = (gross_result - cost_atr) / portfolio_stop_atr
    entry_index = path_a[0]
    return base.Trade(
        entry_time_utc=m15._values(frame_a, "utc")[entry_index].isoformat(),
        local_date=str(m15._values(frame_a, "local_date")[entry_index]),
        year=int(m15._values(frame_a, "year")[entry_index]),
        side=side_a,
        r_multiple=float(result_r),
        exit_reason=f"{reason}:{exit_reason}",
    )


def pair_reversion_trades(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
    *,
    pair: tuple[str, str],
    lookback_bars: int,
    divergence_atr: float,
    portfolio_stop_atr: float,
    target_r: float,
    hold_bars: int,
    end_year: int,
    mode: str = "reversion",
) -> list[base.Trade]:
    if mode not in {"reversion", "momentum"}:
        raise ValueError(f"unsupported pair mode: {mode}")
    symbol_a, symbol_b = pair
    frame_a, frame_b = frames[symbol_a], frames[symbol_b]
    instrument_a, instrument_b = instruments[symbol_a], instruments[symbol_b]
    sessions = synchronized_sessions(frame_a, instrument_a, frame_b, instrument_b)
    opens_a = m15._values(frame_a, "open")
    closes_a = m15._values(frame_a, "close")
    atrs_a = m15._values(frame_a, "atr56")
    opens_b = m15._values(frame_b, "open")
    closes_b = m15._values(frame_b, "close")
    atrs_b = m15._values(frame_b, "atr56")
    years = m15._values(frame_a, "year")
    trades: list[base.Trade] = []
    for indices_a, indices_b in sessions:
        if len(indices_a) <= lookback_bars or len(indices_b) <= lookback_bars:
            continue
        decision_a = indices_a[lookback_bars - 1]
        decision_b = indices_b[lookback_bars - 1]
        entry_position = lookback_bars
        if int(years[decision_a]) > end_year:
            continue
        atr_a = float(atrs_a[decision_a])
        atr_b = float(atrs_b[decision_b])
        if not np.isfinite(atr_a) or not np.isfinite(atr_b) or atr_a <= 0.0 or atr_b <= 0.0:
            continue
        move_a = (float(closes_a[decision_a]) - float(opens_a[indices_a[0]])) / atr_a
        move_b = (float(closes_b[decision_b]) - float(opens_b[indices_b[0]])) / atr_b
        divergence = move_a - move_b
        if not np.isfinite(divergence) or abs(divergence) < divergence_atr:
            continue
        side_a = -1 if divergence > 0.0 else 1
        if mode == "momentum":
            side_a *= -1
        last_position = min(len(indices_a), entry_position + hold_bars)
        trade = simulate_pair_trade(
            frame_a,
            frame_b,
            path_a=indices_a[entry_position:last_position],
            path_b=indices_b[entry_position:last_position],
            side_a=side_a,
            atr_a=atr_a,
            atr_b=atr_b,
            portfolio_stop_atr=portfolio_stop_atr,
            target_r=target_r,
            cost_points_a=instrument_a.round_trip_cost_points,
            cost_points_b=instrument_b.round_trip_cost_points,
            reason=f"pair_{mode}_{symbol_a}_{symbol_b}",
        )
        if trade is not None:
            trades.append(trade)
    return trades


def parameter_grid() -> Iterable[dict[str, Any]]:
    for values in itertools.product(
        PAIRS,
        (2, 4, 8),
        (0.25, 0.5, 0.75),
        (0.5, 1.0),
        (1.0, 2.0, 3.0),
        (2, 4, 8),
    ):
        yield dict(
            zip(
                ("pair", "lookback_bars", "divergence_atr", "portfolio_stop_atr", "target_r", "hold_bars"),
                values,
            )
        )


def screen(
    frames: Mapping[str, Any],
    instruments: Mapping[str, m15.Instrument],
    *,
    mode: str = "reversion",
) -> dict[str, Any]:
    if mode not in {"reversion", "momentum"}:
        raise ValueError(f"unsupported pair mode: {mode}")
    family = (
        "us_index_pair_relative_value_reversion"
        if mode == "reversion"
        else "us_index_pair_relative_momentum"
    )
    predeclaration = (
        "artifacts/ftmo_m15_us_index_pair_reversion_predeclaration_2026-07-12.json"
        if mode == "reversion"
        else "artifacts/ftmo_m15_us_index_pair_momentum_predeclaration_2026-07-12.json"
    )
    rows: list[dict[str, Any]] = []
    for parameters in parameter_grid():
        trades = pair_reversion_trades(
            frames, instruments, **parameters, end_year=2023, mode=mode
        )
        rows.append({"parameters": parameters, "metrics": base.split_metrics(trades)})

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
        trades = pair_reversion_trades(
            frames, instruments, **winner["parameters"], end_year=2025, mode=mode
        )
        metrics = base.split_metrics(trades)
        selected.append(
            {
                "family": family,
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
        "predeclaration": predeclaration,
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "holdout_opened": bool(eligible),
            "entry_rule": "next_synchronized_bar_open_after_completed_divergence_window",
            "same_bar_rule": "joint_adverse_extremes_stop_first",
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
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


def load_inputs(root: Path):
    instruments = {
        instrument.symbol: instrument
        for instrument in m15.default_instruments(root)
        if instrument.symbol in US_SYMBOLS
    }
    frames = {symbol: m15.load_bars(instruments[symbol]) for symbol in US_SYMBOLS}
    return frames, instruments


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


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
