"""Sealed US macro-surprise drift screen on a conservative three-FX basket."""

from __future__ import annotations

import argparse
import itertools
import json
from collections import defaultdict
from dataclasses import asdict
from datetime import time
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_us_cpi_surprise_drift as cpi
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_us_cpi_surprise_drift as cpi  # type: ignore


EVENT_SPECS: dict[str, dict[str, Any]] = {
    "CPI m/m": {"group": "inflation", "usd_sign": 1, "surprise_scale": 0.1},
    "Core CPI m/m": {"group": "inflation", "usd_sign": 1, "surprise_scale": 0.1},
    "Core PCE Price Index m/m": {
        "group": "inflation",
        "usd_sign": 1,
        "surprise_scale": 0.1,
    },
    "Non-Farm Employment Change": {
        "group": "labor",
        "usd_sign": 1,
        "surprise_scale": 50.0,
    },
    "Unemployment Rate": {"group": "labor", "usd_sign": -1, "surprise_scale": 0.1},
    "Retail Sales m/m": {
        "group": "consumption",
        "usd_sign": 1,
        "surprise_scale": 0.5,
    },
    "Core Retail Sales m/m": {
        "group": "consumption",
        "usd_sign": 1,
        "surprise_scale": 0.5,
    },
    "Advance GDP q/q": {"group": "growth", "usd_sign": 1, "surprise_scale": 0.5},
}
PREHOLDOUT_END_YEAR = 2023
HOLDOUT_END_YEAR = 2025


def parse_calendar_number(raw: Any) -> float:
    text = str(raw or "").strip().replace(",", "").replace("−", "-")
    if not text:
        raise ValueError("calendar value is empty")
    multiplier = 1.0
    suffix = text[-1].upper()
    if suffix == "%":
        text = text[:-1]
    elif suffix == "K":
        text = text[:-1]
    elif suffix == "M":
        text = text[:-1]
        multiplier = 1_000.0
    elif suffix == "B":
        text = text[:-1]
        multiplier = 1_000_000.0
    if not text:
        raise ValueError("calendar value has no numeric payload")
    return float(text) * multiplier


def normalize_release_timestamp(raw: Any) -> pd.Timestamp:
    parsed = pd.Timestamp(str(raw))
    if parsed.tzinfo is not None:
        parsed = parsed.tz_localize(None)
    release_date = parsed.date()
    if parsed.hour >= 18:
        release_date = (parsed + pd.Timedelta(days=1)).date()
    local_release = pd.Timestamp.combine(release_date, time(8, 30)).tz_localize(
        "America/New_York",
        ambiguous="raise",
        nonexistent="raise",
    )
    return local_release.tz_convert("UTC")


def raw_timestamp_is_canonical(raw: Any, normalized: pd.Timestamp) -> bool:
    parsed = pd.Timestamp(str(raw))
    if parsed.tzinfo is not None:
        parsed = parsed.tz_localize(None)
    return parsed == normalized.tz_localize(None)


def load_event_packages(path: Path) -> list[dict[str, Any]]:
    frame = pd.read_csv(path)
    required = {"DateTime_UTC", "Currency", "Event", "Actual", "Forecast"}
    if not required.issubset(frame.columns):
        raise ValueError(f"{path}: missing columns {sorted(required - set(frame.columns))}")
    selected = frame[
        (frame["Currency"].astype(str).str.upper() == "USD")
        & frame["Event"].astype(str).isin(EVENT_SPECS)
        & frame["Actual"].notna()
        & frame["Forecast"].notna()
    ]
    normalized_components: dict[tuple[pd.Timestamp, str], dict[str, Any]] = {}
    for row in selected.to_dict("records"):
        event_name = str(row["Event"])
        spec = EVENT_SPECS[event_name]
        try:
            actual = parse_calendar_number(row["Actual"])
            forecast = parse_calendar_number(row["Forecast"])
        except ValueError:
            continue
        timestamp = normalize_release_timestamp(row["DateTime_UTC"])
        key = (timestamp, event_name)
        score = (
            int(spec["usd_sign"])
            * (actual - forecast)
            / float(spec["surprise_scale"])
        )
        component = {
            "event": event_name,
            "group": str(spec["group"]),
            "actual": actual,
            "forecast": forecast,
            "score": float(score),
            "raw_timestamp": str(row["DateTime_UTC"]),
            "raw_timestamp_is_canonical": raw_timestamp_is_canonical(
                row["DateTime_UTC"], timestamp
            ),
        }
        previous = normalized_components.get(key)
        if previous is None:
            normalized_components[key] = component
        elif component["raw_timestamp_is_canonical"] and not previous[
            "raw_timestamp_is_canonical"
        ]:
            normalized_components[key] = component
        elif component["raw_timestamp_is_canonical"] == previous[
            "raw_timestamp_is_canonical"
        ]:
            raise ValueError(f"ambiguous normalized event: {timestamp} {event_name}")

    grouped: dict[pd.Timestamp, list[dict[str, Any]]] = defaultdict(list)
    for (timestamp, _), component in normalized_components.items():
        grouped[timestamp].append(component)

    packages: list[dict[str, Any]] = []
    for timestamp, components in sorted(grouped.items()):
        if timestamp.minute != 30 or timestamp.hour not in (12, 13):
            raise ValueError(f"invalid normalized release time: {timestamp}")
        group_scores: dict[str, float] = defaultdict(float)
        for component in components:
            group_scores[str(component["group"])] += float(component["score"])
        packages.append(
            {
                "timestamp": timestamp,
                "score": float(sum(group_scores.values())),
                "group_scores": dict(sorted(group_scores.items())),
                "components": sorted(components, key=lambda row: str(row["event"])),
            }
        )
    return packages


def parameter_grid() -> list[dict[str, Any]]:
    return [
        {
            "minimum_abs_score": minimum_abs_score,
            "blackout_minutes": blackout_minutes,
            "stop_atr5": stop_atr5,
            "target_r": target_r,
            "hold_bars": hold_bars,
        }
        for minimum_abs_score, blackout_minutes, stop_atr5, target_r, hold_bars in itertools.product(
            (0.5, 1.0, 1.5),
            (60, 120, 180),
            (8.0, 12.0, 16.0, 24.0),
            (0.0, 1.0, 2.0),
            (48, 96, 288),
        )
    ]


def surprise_sides(score: float) -> dict[str, int]:
    usd_side = 1 if score > 0.0 else -1
    return {
        "EURUSD.DWX": -usd_side,
        "GBPUSD.DWX": -usd_side,
        "USDJPY.DWX": usd_side,
    }


def event_trades(
    panel: pd.DataFrame,
    packages: Sequence[Mapping[str, Any]],
    *,
    minimum_abs_score: float,
    blackout_minutes: int,
    stop_atr5: float,
    target_r: float,
    hold_bars: int,
    max_year: int,
) -> list[base.Trade]:
    trades: list[base.Trade] = []
    for package in packages:
        timestamp = pd.Timestamp(package["timestamp"])
        if timestamp.year > max_year:
            continue
        score = float(package["score"])
        if score == 0.0 or abs(score) + 1e-12 < minimum_abs_score:
            continue
        entry_time = timestamp + pd.Timedelta(minutes=blackout_minutes)
        entry_position = int(panel.index.searchsorted(entry_time, side="left"))
        if entry_position <= 0 or entry_position >= len(panel):
            continue
        sides = surprise_sides(score)
        results = [
            cpi.simulate_leg(
                panel,
                symbol=symbol,
                entry_position=entry_position,
                stop_atr5=stop_atr5,
                target_r=target_r,
                hold_bars=hold_bars,
                side=sides[symbol],
            )
            for symbol in cpi.SYMBOLS
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
                side=1 if score > 0.0 else -1,
                r_multiple=float(np.mean(results)),
                exit_reason=f"usd_macro_surprise:{score:+.3f}",
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
        dev["trades"] >= 100
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.15
        and validation["trades"] >= 18
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.05
        and positive_development_years(metrics) >= 4
    )


def holdout_pass(metrics: Mapping[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return (
        holdout["trades"] >= 35
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


def screen(panel: pd.DataFrame, packages: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for params in parameter_grid():
        trades = event_trades(
            panel,
            packages,
            **params,
            max_year=PREHOLDOUT_END_YEAR,
        )
        rows.append({"parameters": params, "metrics": base.split_metrics(trades)})
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
        trades = event_trades(
            panel,
            packages,
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
        "calendar_package_count": len(packages),
        "calendar_component_count": sum(len(row["components"]) for row in packages),
        "calendar_coverage": {
            "first": str(packages[0]["timestamp"]) if packages else None,
            "last": str(packages[-1]["timestamp"]) if packages else None,
            "partial_2025": True,
        },
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
    output = screen(cpi.load_panel(args.data_root), load_event_packages(args.calendar))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "packages": output["calendar_package_count"],
                "components": output["calendar_component_count"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
