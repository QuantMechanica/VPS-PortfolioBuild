"""Sealed USD CPI surprise-drift screen on a conservative three-FX package."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m5_fx_session_screen as m5
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m5_fx_session_screen as m5  # type: ignore


SYMBOLS = ("EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX")
BASE_COST = {"EURUSD.DWX": 0.00015, "GBPUSD.DWX": 0.00018, "USDJPY.DWX": 0.0225}
ROLLOVER_STRESS = {
    "EURUSD.DWX": 0.0001103,
    "GBPUSD.DWX": 0.0000577,
    "USDJPY.DWX": 0.02241,
}
PREHOLDOUT_END_YEAR = 2023
HOLDOUT_END_YEAR = 2025


def parse_percent(raw: Any) -> float:
    text = str(raw or "").strip().replace("%", "").replace(",", "")
    if not text:
        raise ValueError("percentage value is empty")
    return float(text)


def correct_local_calendar_timestamp(raw: Any) -> pd.Timestamp:
    parsed = pd.Timestamp(str(raw))
    if parsed.tzinfo is not None:
        parsed = parsed.tz_localize(None)
    return (parsed + pd.Timedelta(days=1) - pd.Timedelta(hours=7)).tz_localize("UTC")


def load_events(path: Path) -> list[dict[str, Any]]:
    frame = pd.read_csv(path)
    required = {"DateTime_UTC", "Currency", "Impact", "Event", "Actual", "Forecast"}
    if not required.issubset(frame.columns):
        raise ValueError(f"{path}: missing columns {sorted(required - set(frame.columns))}")
    selected = frame[
        (frame["Currency"].astype(str).str.upper() == "USD")
        & (frame["Impact"].astype(str).str.upper() == "HIGH")
        & (frame["Event"].astype(str) == "CPI m/m")
        & frame["Actual"].notna()
        & frame["Forecast"].notna()
    ]
    events: list[dict[str, Any]] = []
    for row in selected.to_dict("records"):
        try:
            actual = parse_percent(row["Actual"])
            forecast = parse_percent(row["Forecast"])
        except ValueError:
            continue
        timestamp = correct_local_calendar_timestamp(row["DateTime_UTC"])
        events.append(
            {
                "timestamp": timestamp,
                "actual": actual,
                "forecast": forecast,
                "surprise": actual - forecast,
            }
        )
    events.sort(key=lambda row: row["timestamp"])
    if len({row["timestamp"] for row in events}) != len(events):
        raise ValueError("duplicate corrected USD CPI timestamps")
    return events


def load_panel(root: Path) -> pd.DataFrame:
    parts: list[pd.DataFrame] = []
    for symbol in SYMBOLS:
        frame = m5.load_bars(
            m5.Instrument(symbol, root / f"{symbol}_M5.csv", BASE_COST[symbol])
        )
        selected = frame[["utc", "open", "high", "low", "close", "atr288"]].copy()
        selected = selected.rename(
            columns={column: f"{symbol}:{column}" for column in selected if column != "utc"}
        )
        parts.append(selected)
    panel = parts[0]
    for part in parts[1:]:
        panel = panel.merge(part, on="utc", how="inner", validate="one_to_one")
    panel = panel.sort_values("utc").drop_duplicates("utc").set_index("utc")
    if not panel.index.is_monotonic_increasing or not panel.index.is_unique:
        raise ValueError("common FX panel index must be sorted and unique")
    return panel


def parameter_grid() -> list[dict[str, Any]]:
    return [
        {
            "minimum_surprise": minimum_surprise,
            "blackout_minutes": blackout_minutes,
            "stop_atr5": stop_atr5,
            "target_r": target_r,
            "hold_bars": hold_bars,
        }
        for minimum_surprise, blackout_minutes, stop_atr5, target_r, hold_bars in itertools.product(
            (0.05, 0.15),
            (120, 180),
            (8.0, 16.0, 24.0),
            (0.0, 1.0, 2.0),
            (48, 96, 288),
        )
    ]


def surprise_sides(surprise: float) -> dict[str, int]:
    usd_side = 1 if surprise > 0.0 else -1
    return {
        "EURUSD.DWX": -usd_side,
        "GBPUSD.DWX": -usd_side,
        "USDJPY.DWX": usd_side,
    }


def simulate_leg(
    panel: pd.DataFrame,
    *,
    symbol: str,
    entry_position: int,
    stop_atr5: float,
    target_r: float,
    hold_bars: int,
    side: int,
) -> float:
    if entry_position <= 0 or entry_position >= len(panel) or side not in (-1, 1):
        return float("nan")
    last_position = min(len(panel) - 1, entry_position + hold_bars - 1)
    rows = panel.iloc[entry_position : last_position + 1]
    entry = float(rows.iloc[0][f"{symbol}:open"])
    atr = float(panel.iloc[entry_position - 1][f"{symbol}:atr288"])
    stop_distance = stop_atr5 * atr
    if not np.isfinite(atr) or entry <= 0.0 or stop_distance <= 0.0:
        return float("nan")
    stop = entry - side * stop_distance
    target = entry + side * stop_distance * target_r
    total_cost = BASE_COST[symbol]
    if hold_bars >= 96:
        total_cost += ROLLOVER_STRESS[symbol]
    cost_r = total_cost / stop_distance
    for _, row in rows.iterrows():
        high = float(row[f"{symbol}:high"])
        low = float(row[f"{symbol}:low"])
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = target_r > 0.0 and (high >= target if side > 0 else low <= target)
        if stop_hit:
            return -1.0 - cost_r
        if target_hit:
            return target_r - cost_r
    exit_price = float(rows.iloc[-1][f"{symbol}:close"])
    return side * (exit_price - entry) / stop_distance - cost_r


def event_packages(
    panel: pd.DataFrame,
    events: Sequence[Mapping[str, Any]],
    *,
    minimum_surprise: float,
    blackout_minutes: int,
    stop_atr5: float,
    target_r: float,
    hold_bars: int,
    max_year: int,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    for event in events:
        timestamp = pd.Timestamp(event["timestamp"])
        if timestamp.year > max_year:
            continue
        surprise = float(event["surprise"])
        if abs(surprise) + 1e-12 < minimum_surprise or surprise == 0.0:
            continue
        entry_time = timestamp + pd.Timedelta(minutes=blackout_minutes)
        entry_position = int(panel.index.searchsorted(entry_time, side="left"))
        if entry_position <= 0 or entry_position >= len(panel):
            continue
        sides = surprise_sides(surprise)
        results = [
            simulate_leg(
                panel,
                symbol=symbol,
                entry_position=entry_position,
                stop_atr5=stop_atr5,
                target_r=target_r,
                hold_bars=hold_bars,
                side=sides[symbol],
            )
            for symbol in SYMBOLS
        ]
        if not all(np.isfinite(value) for value in results):
            continue
        actual_entry = panel.index[entry_position]
        local = actual_entry.tz_convert("America/New_York")
        trades.append(
            base.Trade(
                entry_time_utc=actual_entry.isoformat(),
                local_date=local.date().isoformat(),
                year=int(local.year),
                side=1 if surprise > 0.0 else -1,
                r_multiple=float(np.mean(results)),
                exit_reason=f"usd_cpi_surprise:{surprise:+.2f}",
            )
        )
    return trades


def positive_development_years(metrics: Mapping[str, Any]) -> int:
    return sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )


def preholdout_pass(metrics: Mapping[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    return (
        dev["trades"] >= 40
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.15
        and validation["trades"] >= 8
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_development_years(metrics) >= 4
    )


def holdout_pass(metrics: Mapping[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 15
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def score(metrics: Mapping[str, Any]) -> float:
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def screen(panel: pd.DataFrame, events: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for params in parameter_grid():
        trades = event_packages(panel, events, **params, max_year=PREHOLDOUT_END_YEAR)
        metrics = base.split_metrics(trades)
        rows.append({"parameters": params, "metrics": metrics})
    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    ranked = sorted(
        rows,
        key=lambda row: (score(row["metrics"]), row["metrics"]["dev_2018_2022"]["trades"]),
        reverse=True,
    )
    leaderboard = [
        {
            "parameters": row["parameters"],
            "preholdout_score": score(row["metrics"]),
            "dev_2018_2022": row["metrics"]["dev_2018_2022"],
            "validation_2023": row["metrics"]["validation_2023"],
            "positive_dev_years": positive_development_years(row["metrics"]),
            "preholdout_pass": preholdout_pass(row["metrics"]),
        }
        for row in ranked[:10]
    ]
    winner: dict[str, Any] | None = None
    if eligible:
        selected = max(
            eligible,
            key=lambda row: (
                score(row["metrics"]),
                row["metrics"]["dev_2018_2022"]["trades"],
            ),
        )
        trades = event_packages(
            panel,
            events,
            **selected["parameters"],
            max_year=HOLDOUT_END_YEAR,
        )
        metrics = base.split_metrics(trades)
        winner = {
            "parameters": selected["parameters"],
            "preholdout_score": score(selected["metrics"]),
            "metrics": metrics,
            "holdout_verdict": "PASS" if holdout_pass(metrics) else "FAIL",
            "trades": [asdict(trade) for trade in trades],
        }
    return {
        "schema_version": 1,
        "status": (
            "NO_PREHOLDOUT_SURVIVOR"
            if winner is None
            else "HOLDOUT_SURVIVOR_FOUND"
            if winner["holdout_verdict"] == "PASS"
            else "LOCKED_HOLDOUT_FAILED"
        ),
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "winner_count": 1,
        },
        "calendar_event_count": len(events),
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "winner": winner,
        "leaderboard": leaderboard,
        "deployment_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument(
        "--calendar",
        type=Path,
        default=Path(r"D:\QM\data\news_calendar\forex_factory_calendar_clean.csv"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(load_panel(args.data_root), load_events(args.calendar))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "events": output["calendar_event_count"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
