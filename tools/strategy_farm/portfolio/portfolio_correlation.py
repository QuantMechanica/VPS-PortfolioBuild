from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any

try:
    from .commission import describe_model, load_model
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        align,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )
except ImportError:  # pragma: no cover - direct script execution
    from commission import describe_model, load_model  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        align,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )


COMMISSION_BASIS = "worst_case_dxz_ftmo"


def build_artifact(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    min_overlap_days: int = 60,
) -> dict[str, Any]:
    model = load_model()
    if all_streams:
        candidates = None
        basis = "all_q08_streams_uncertified"
    else:
        candidates = read_candidates(candidates_db)
        basis = "candidates"

    streams = load_streams(common_dir, candidates=candidates, commission_model=model)
    series_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    keys, dates, matrix = align(series_by_key)
    correlation, insufficient_overlap = correlation_matrix(keys, matrix, min_overlap_days)

    per_series = {}
    for key in keys:
        trades = streams[key]
        daily = series_by_key[key]
        per_series[key_label(key)] = {
            "trades": len(trades),
            "active_days": sum(1 for value in daily.values() if value != 0.0),
            "net_of_cost_total": _round_float(sum(trade.net_of_cost for trade in trades)),
        }

    return {
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "basis": basis,
        "generated_basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "commission_degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "min_overlap_days": min_overlap_days,
        "n_series": len(keys),
        "n_days": len(dates),
        "keys": [key_label(key) for key in keys],
        "dates": [day.isoformat() for day in dates],
        "correlation": correlation,
        "insufficient_overlap": insufficient_overlap,
        "per_series": per_series,
    }


def correlation_matrix(
    keys: list[tuple[int, str]],
    matrix: Any,
    min_overlap_days: int,
) -> tuple[list[list[float | None]], list[list[str]]]:
    n_series = len(keys)
    output: list[list[float | None]] = [[None for _ in range(n_series)] for _ in range(n_series)]
    insufficient: list[list[str]] = []

    for i in range(n_series):
        output[i][i] = 1.0
        for j in range(i + 1, n_series):
            left = [float(row[i]) for row in matrix]
            right = [float(row[j]) for row in matrix]
            active_values = [
                (left_value, right_value)
                for left_value, right_value in zip(left, right)
                if left_value != 0.0 and right_value != 0.0
            ]
            overlap = len(active_values)
            if overlap < min_overlap_days:
                insufficient.append([key_label(keys[i]), key_label(keys[j])])
                value = None
            else:
                active_left = [left_value for left_value, _ in active_values]
                active_right = [right_value for _, right_value in active_values]
                value = _pearson(active_left, active_right)
            output[i][j] = value
            output[j][i] = value

    return output, insufficient


def write_artifact(artifact: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Q11 EA-symbol daily-PnL correlation artifact.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "correlation.json",
        help="Artifact JSON path.",
    )
    parser.add_argument("--min-overlap-days", type=int, default=60)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    artifact = build_artifact(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        min_overlap_days=args.min_overlap_days,
    )
    write_artifact(artifact, args.out)
    print(f"wrote {args.out} ({artifact['n_series']} series, {artifact['n_days']} days)")
    return 0


def _pearson(left: list[float], right: list[float]) -> float | None:
    if len(left) < 2 or len(right) < 2:
        return None
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    left_diffs = [value - left_mean for value in left]
    right_diffs = [value - right_mean for value in right]
    left_norm = math.sqrt(sum(value * value for value in left_diffs))
    right_norm = math.sqrt(sum(value * value for value in right_diffs))
    if left_norm == 0.0 or right_norm == 0.0:
        return None
    corr = sum(
        left_value * right_value for left_value, right_value in zip(left_diffs, right_diffs)
    ) / (left_norm * right_norm)
    return _round_float(corr)


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
