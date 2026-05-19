#!/usr/bin/env python3
"""P8 news driver: validates calendar schema and evaluates seven policy modes."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_bool_like,
    parse_float,
    parse_int,
    row_symbol,
    update_result_with_evidence_path,
    write_phase_artifacts,
)

REQUIRED_CALENDAR_COLUMNS = [
    "timestamp_utc",
    "currency",
    "impact",
    "event",
    "actual",
    "forecast",
    "previous",
]
CALENDAR_ALIASES = {
    "timestamp_utc": ("timestamp_utc", "datetime", "DateTime_UTC", "Date"),
    "currency": ("currency", "Currency"),
    "impact": ("impact", "Impact"),
    "event": ("event", "event_name", "Event"),
    "actual": ("actual", "Actual"),
    "forecast": ("forecast", "Forecast"),
    "previous": ("previous", "Previous"),
}
FALLBACK_SYMBOL = "ALL_SYMBOLS"

MODE_ALIASES = {
    "OFF": "OFF",
    "PAUSE": "PAUSE",
    "SKIP_DAY": "SKIP_DAY",
    "FTMO_PAUSE": "FTMO_PAUSE",
    "FTMO": "FTMO_PAUSE",
    "5ERS_PAUSE": "5ers_PAUSE",
    "5ERS": "5ers_PAUSE",
    "NO_NEWS": "no_news",
    "NO-NEWS": "no_news",
    "NEWS_ONLY": "news_only",
    "NEWS-ONLY": "news_only",
}

MODE_PROFILES = {
    "full": ["OFF", "PAUSE", "SKIP_DAY", "FTMO_PAUSE", "5ers_PAUSE", "no_news", "news_only"],
    "ftmo": ["FTMO_PAUSE", "PAUSE", "SKIP_DAY", "OFF"],
    "5ers": ["5ers_PAUSE", "PAUSE", "SKIP_DAY", "OFF"],
    "dxz": ["PAUSE", "SKIP_DAY", "OFF"],
    "no-news": ["no_news", "OFF"],
    "news-only": ["news_only", "PAUSE", "OFF"],
}


def normalize_mode(raw_mode: str) -> str:
    text = (raw_mode or "").strip().upper()
    return MODE_ALIASES.get(text, "")


def is_row_eligible(row: dict[str, str]) -> bool:
    return parse_float(row.get("pf"), 0.0) >= 1.0 and parse_int(row.get("trades"), 0) > 0


def validate_calendar(path: Path) -> dict[str, object]:
    rows = load_csv_rows(path)
    if not rows:
        raise ValueError(f"Calendar CSV has no rows: {path}")
    first = rows[0]
    missing_cols = [
        col for col in REQUIRED_CALENDAR_COLUMNS
        if not any(alias in first for alias in CALENDAR_ALIASES[col])
    ]
    if missing_cols:
        raise ValueError(f"Calendar CSV missing required columns: {', '.join(missing_cols)}")

    bad_ts = 0
    impact_bad = 0
    seen = set()
    duplicates = 0
    for row in rows:
        ts = str(next((row.get(alias) for alias in CALENDAR_ALIASES["timestamp_utc"] if row.get(alias)), "")).strip()
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            if dt.utcoffset() is not None and dt.utcoffset().total_seconds() != 0:
                bad_ts += 1
        except ValueError:
            bad_ts += 1

        impact = str(next((row.get(alias) for alias in CALENDAR_ALIASES["impact"] if row.get(alias)), "")).strip().lower()
        if impact not in {"low", "medium", "high"}:
            impact_bad += 1

        currency = str(next((row.get(alias) for alias in CALENDAR_ALIASES["currency"] if row.get(alias)), "")).strip().upper()
        event = str(next((row.get(alias) for alias in CALENDAR_ALIASES["event"] if row.get(alias)), "")).strip()
        key = (ts, currency, event)
        if key in seen:
            duplicates += 1
        else:
            seen.add(key)

    if bad_ts > 0:
        raise ValueError(f"Calendar CSV has {bad_ts} invalid/non-UTC timestamp_utc rows")
    if impact_bad > 0:
        raise ValueError(f"Calendar CSV has {impact_bad} rows with invalid impact level")

    return {
        "rows": len(rows),
        "duplicate_event_rows": duplicates,
    }


def summarize_symbol_modes(rows: list[dict[str, str]]) -> dict[str, object]:
    eligible = [r for r in rows if is_row_eligible(r)]
    if eligible:
        eligible.sort(
            key=lambda r: (
                parse_float(r.get("pf"), 0.0),
                parse_float(r.get("sharpe"), 0.0),
                -parse_float(r.get("drawdown_pct"), 999.0),
            ),
            reverse=True,
        )
        recommended = str(eligible[0].get("mode", "OFF"))
        verdict = "MODE_SELECTED"
    else:
        recommended = "OFF" if any(str(r.get("mode", "")) == "OFF" for r in rows) else "REVIEW_REQUIRED"
        verdict = "NO_ELIGIBLE_MODE"
    return {
        "eligible_mode_count": len(eligible),
        "recommended_mode": recommended,
        "verdict": verdict,
    }


def parse_mode_profiles(mode_arg: str, custom_modes_arg: str) -> dict[str, list[str]]:
    raw = (mode_arg or "all").strip().lower()
    if raw == "all":
        selected = dict(MODE_PROFILES)
    else:
        names = [x.strip() for x in raw.split(",") if x.strip()]
        selected = {}
        for name in names:
            if name not in MODE_PROFILES and name != "custom":
                raise ValueError(f"Unsupported mode profile: {name}")
            if name in MODE_PROFILES:
                selected[name] = list(MODE_PROFILES[name])

    if "custom" in raw or raw == "all":
        custom_modes: list[str] = []
        for chunk in (custom_modes_arg or "").split(","):
            normalized = normalize_mode(chunk)
            if normalized and normalized not in custom_modes:
                custom_modes.append(normalized)
        if not custom_modes:
            custom_modes = ["OFF"]
        selected["custom"] = custom_modes
    return selected


def write_summary_csv(path: Path, rows: list[dict[str, object]]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["profile", "symbol", "recommended_mode", "verdict", "eligible_mode_count", "selected_modes"],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser(description="P8 news driver with calendar validation and policy profiles")
    add_common_args(parser)
    parser.add_argument("--news-matrix", required=True)
    parser.add_argument("--calendar-csv", default="D:/QM/data/news_calendar/news_calendar.csv")
    parser.add_argument("--mode", default="all", help="Profile(s): all|full|ftmo|5ers|dxz|no-news|news-only|custom")
    parser.add_argument("--custom-modes", default="", help="Comma-separated normalized/alias modes for custom profile")
    args = parser.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P8")
    calendar_stats = validate_calendar(Path(args.calendar_csv))
    selected_profiles = parse_mode_profiles(args.mode, args.custom_modes)

    matrix_rows = load_csv_rows(Path(args.news_matrix))
    normalized_rows: list[dict[str, str]] = []
    for raw in matrix_rows:
        mode = normalize_mode(raw.get("mode", ""))
        if not mode:
            continue
        row = dict(raw)
        row["mode"] = mode
        normalized_rows.append(row)

    by_symbol: dict[str, list[dict[str, str]]] = {}
    for row in normalized_rows:
        symbol = row_symbol(row).strip() or FALLBACK_SYMBOL
        by_symbol.setdefault(symbol, []).append(row)

    summary_rows: list[dict[str, object]] = []
    mode_results: dict[str, object] = {}
    any_failure = False
    for profile, allowed_modes in selected_profiles.items():
        allowed = set(allowed_modes)
        symbol_results = []
        recommended_mode_by_symbol: dict[str, str] = {}
        profile_failure = False
        for symbol in sorted(by_symbol.keys()):
            rows = [r for r in by_symbol[symbol] if r["mode"] in allowed]
            summary = summarize_symbol_modes(rows)
            if summary["verdict"] != "MODE_SELECTED":
                profile_failure = True
            recommended_mode_by_symbol[symbol] = str(summary["recommended_mode"])
            symbol_results.append(
                {
                    "symbol": symbol,
                    "recommended_mode": summary["recommended_mode"],
                    "verdict": summary["verdict"],
                    "eligible_mode_count": summary["eligible_mode_count"],
                }
            )
            summary_rows.append(
                {
                    "profile": profile,
                    "symbol": symbol,
                    "recommended_mode": summary["recommended_mode"],
                    "verdict": summary["verdict"],
                    "eligible_mode_count": summary["eligible_mode_count"],
                    "selected_modes": ",".join(allowed_modes),
                }
            )
        mode_results[profile] = {
            "selected_modes": allowed_modes,
            "recommended_mode_by_symbol": recommended_mode_by_symbol,
            "symbol_results": symbol_results,
            "verdict": "MODE_SELECTED" if not profile_failure else "NO_ELIGIBLE_MODE",
        }
        any_failure = any_failure or profile_failure

    summary_csv = out_dir / "P8_summary.csv"
    write_summary_csv(summary_csv, summary_rows)

    result = build_result(
        phase="P8",
        ea_id=args.ea,
        verdict="NO_ELIGIBLE_MODE" if any_failure else "MODE_SELECTED",
        criterion="P8 seven-profile news mode recommendation with validated UTC calendar schema",
        evidence_path="",
        details={
            "calendar_csv": str(Path(args.calendar_csv)),
            "calendar_stats": calendar_stats,
            "mode_results": mode_results,
            "summary_csv": str(summary_csv),
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P8", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
