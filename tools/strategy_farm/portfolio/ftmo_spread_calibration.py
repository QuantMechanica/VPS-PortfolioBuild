#!/usr/bin/env python3
"""Build a hash-bound FTMO-vs-Darwinex M1 spread calibration.

MetaTrader's HCC container is proprietary.  This tool therefore consumes the
official ``CopyRates(PERIOD_M1)`` spread projection, while hash-binding both
that projection and the HCC files from which the terminal produced it.  Rows
from the two venues must cover the exact same minute timestamps.  Missing
minutes, missing session buckets, cross-symbol substitution, and unbound HCC
sources are refusals rather than extrapolation opportunities.

The calibrated charge is the non-negative upper-tail spread delta in price
units.  By default the 90th percentile is used, which is stricter than the
OWNER-required upper quartile and never credits FTMO for a narrower spread.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_timebox_eval import (
        TimeboxEvaluationError,
        load_json,
        loads_strict,
        sha256_file,
        write_json_atomic,
    )
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_timebox_eval import (  # type: ignore
        TimeboxEvaluationError,
        load_json,
        loads_strict,
        sha256_file,
        write_json_atomic,
    )


SPEC_SCHEMA = "qm.ftmo-spread-calibration-spec/v1"
ARTIFACT_SCHEMA = "qm.ftmo-spread-calibration/v1"
M1_ROW_SCHEMA = "qm.m1-spread-row/v1"
EXTRACTION_METHOD = "MQL5_COPYRATES_PERIOD_M1_SPREAD"
DEFAULT_QUANTILES = (0.50, 0.75, 0.90, 0.95, 0.99)
MAX_ROWS = 5_000_000


class SpreadCalibrationError(ValueError):
    """The supplied spread evidence cannot support a calibration."""


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise SpreadCalibrationError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise SpreadCalibrationError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise SpreadCalibrationError(f"{label}: expected finite number")
    return number


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise SpreadCalibrationError(f"{label}: expected positive integer")
    return value


def _binding(path_value: Any, label: str) -> dict[str, Any]:
    if not isinstance(path_value, str) or not path_value.strip():
        raise SpreadCalibrationError(f"{label}: expected non-empty path")
    path = Path(path_value).expanduser().resolve()
    if not path.is_file():
        raise SpreadCalibrationError(f"{label}: required file is absent: {path}")
    return {
        "path": str(path),
        "size_bytes": path.stat().st_size,
        "sha256": sha256_file(path),
    }


def _parse_minute(value: Any, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise SpreadCalibrationError(f"{label}: expected explicit UTC ISO timestamp ending Z")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise SpreadCalibrationError(f"{label}: invalid timestamp") from exc
    if parsed.second or parsed.microsecond or parsed.utcoffset() != dt.timedelta(0):
        raise SpreadCalibrationError(f"{label}: timestamp must be an exact UTC minute")
    return parsed.astimezone(dt.UTC)


def _read_m1_rows(
    path: Path, *, symbol: str, venue: str, label: str
) -> dict[dt.datetime, int]:
    rows: dict[dt.datetime, int] = {}
    try:
        with path.open("rb") as handle:
            for line_number, raw in enumerate(handle, 1):
                if line_number > MAX_ROWS:
                    raise SpreadCalibrationError(f"{label}: row limit exceeded")
                if not raw.strip():
                    raise SpreadCalibrationError(f"{label}:{line_number}: blank row")
                try:
                    row = loads_strict(raw, f"{label}:{line_number}")
                except TimeboxEvaluationError as exc:
                    raise SpreadCalibrationError(str(exc)) from exc
                required = {"schema", "symbol", "venue", "time", "spread_points"}
                if not isinstance(row, Mapping) or set(row) != required:
                    raise SpreadCalibrationError(f"{label}:{line_number}: unexpected fields")
                if row["schema"] != M1_ROW_SCHEMA:
                    raise SpreadCalibrationError(f"{label}:{line_number}: wrong row schema")
                if row["symbol"] != symbol or row["venue"] != venue:
                    raise SpreadCalibrationError(f"{label}:{line_number}: symbol/venue mismatch")
                minute = _parse_minute(row["time"], f"{label}:{line_number}.time")
                spread = row["spread_points"]
                if isinstance(spread, bool) or not isinstance(spread, int) or spread < 0:
                    raise SpreadCalibrationError(
                        f"{label}:{line_number}.spread_points: expected non-negative integer"
                    )
                if minute in rows:
                    raise SpreadCalibrationError(f"{label}:{line_number}: duplicate minute")
                rows[minute] = spread
    except OSError as exc:
        raise SpreadCalibrationError(f"{label}: cannot read {path}: {exc}") from exc
    if not rows:
        raise SpreadCalibrationError(f"{label}: empty M1 spread projection")
    return rows


def _percentile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise SpreadCalibrationError("percentile requires values")
    ordered = sorted(values)
    position = probability * (len(ordered) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def _quantile_key(probability: float) -> str:
    return f"p{int(round(probability * 100)):02d}"


def _quantiles(values: Sequence[float], probabilities: Sequence[float]) -> dict[str, float]:
    return {
        _quantile_key(probability): round(_percentile(values, probability), 12)
        for probability in probabilities
    }


def _bucket_name(minute: dt.datetime, bucket_minutes: int) -> str:
    minute_of_day = minute.hour * 60 + minute.minute
    start = minute_of_day // bucket_minutes * bucket_minutes
    end = start + bucket_minutes - 1
    return (
        f"{start // 60:02d}:{start % 60:02d}-"
        f"{min(end, 1439) // 60:02d}:{min(end, 1439) % 60:02d}Z"
    )


def _validate_source(source: Any, *, expected_venue: str, label: str) -> dict[str, Any]:
    required = {
        "symbol",
        "venue",
        "point_size",
        "m1_spread_path",
        "source_hcc_paths",
        "extraction_method",
    }
    if not isinstance(source, Mapping) or set(source) != required:
        raise SpreadCalibrationError(f"{label}: unexpected fields")
    symbol = source["symbol"]
    if not isinstance(symbol, str) or not symbol.strip():
        raise SpreadCalibrationError(f"{label}.symbol: expected non-empty string")
    if source["venue"] != expected_venue:
        raise SpreadCalibrationError(f"{label}.venue: expected {expected_venue}")
    if source["extraction_method"] != EXTRACTION_METHOD:
        raise SpreadCalibrationError(f"{label}: unsupported extraction method")
    point_size = _finite(source["point_size"], f"{label}.point_size")
    if point_size <= 0.0:
        raise SpreadCalibrationError(f"{label}.point_size: expected positive")
    hcc_paths = source["source_hcc_paths"]
    if not isinstance(hcc_paths, list) or not hcc_paths:
        raise SpreadCalibrationError(f"{label}.source_hcc_paths: expected non-empty list")
    hcc_bindings = [_binding(value, f"{label}.source_hcc_paths[{index}]") for index, value in enumerate(hcc_paths)]
    if any(Path(item["path"]).suffix.lower() != ".hcc" for item in hcc_bindings):
        raise SpreadCalibrationError(f"{label}.source_hcc_paths: every source must be .hcc")
    projection = _binding(source["m1_spread_path"], f"{label}.m1_spread_path")
    return {
        "symbol": symbol.strip(),
        "venue": expected_venue,
        "point_size": point_size,
        "extraction_method": EXTRACTION_METHOD,
        "m1_spread": projection,
        "source_hcc": hcc_bindings,
    }


def _calibrate_pair(
    pair: Any,
    *,
    pair_index: int,
    bucket_minutes: int,
    conservative_quantile: float,
    minimum_matched_minutes: int,
    minimum_bucket_minutes: int,
) -> dict[str, Any]:
    label = f"pairs[{pair_index}]"
    if not isinstance(pair, Mapping) or set(pair) != {"evaluator_symbol", "ftmo", "dxz"}:
        raise SpreadCalibrationError(f"{label}: unexpected fields")
    evaluator_symbol = pair["evaluator_symbol"]
    if not isinstance(evaluator_symbol, str) or not evaluator_symbol.strip():
        raise SpreadCalibrationError(f"{label}.evaluator_symbol: expected non-empty string")
    ftmo = _validate_source(pair["ftmo"], expected_venue="FTMO", label=f"{label}.ftmo")
    dxz = _validate_source(pair["dxz"], expected_venue="DXZ", label=f"{label}.dxz")
    if ftmo["symbol"] == dxz["symbol"]:
        raise SpreadCalibrationError(f"{label}: venue symbols must remain explicit and distinct")

    ftmo_rows = _read_m1_rows(
        Path(ftmo["m1_spread"]["path"]),
        symbol=ftmo["symbol"],
        venue="FTMO",
        label=f"{label}.ftmo_m1",
    )
    dxz_rows = _read_m1_rows(
        Path(dxz["m1_spread"]["path"]),
        symbol=dxz["symbol"],
        venue="DXZ",
        label=f"{label}.dxz_m1",
    )
    if set(ftmo_rows) != set(dxz_rows):
        missing_ftmo = len(set(dxz_rows) - set(ftmo_rows))
        missing_dxz = len(set(ftmo_rows) - set(dxz_rows))
        raise SpreadCalibrationError(
            f"{label}: non-identical M1 coverage; missing_ftmo={missing_ftmo} "
            f"missing_dxz={missing_dxz}"
        )
    minutes = sorted(ftmo_rows)
    if len(minutes) < minimum_matched_minutes:
        raise SpreadCalibrationError(
            f"{label}: only {len(minutes)} matched minutes; minimum={minimum_matched_minutes}"
        )

    ftmo_prices = [ftmo_rows[minute] * ftmo["point_size"] for minute in minutes]
    dxz_prices = [dxz_rows[minute] * dxz["point_size"] for minute in minutes]
    deltas = [left - right for left, right in zip(ftmo_prices, dxz_prices)]
    by_bucket: dict[str, list[int]] = defaultdict(list)
    for index, minute in enumerate(minutes):
        by_bucket[_bucket_name(minute, bucket_minutes)].append(index)
    session_buckets: list[dict[str, Any]] = []
    for bucket, indices in sorted(by_bucket.items()):
        if len(indices) < minimum_bucket_minutes:
            raise SpreadCalibrationError(
                f"{label}: session bucket {bucket} has {len(indices)} matched minutes; "
                f"minimum={minimum_bucket_minutes}"
            )
        ftmo_bucket = [ftmo_prices[index] for index in indices]
        dxz_bucket = [dxz_prices[index] for index in indices]
        delta_bucket = [deltas[index] for index in indices]
        session_buckets.append(
            {
                "bucket_utc": bucket,
                "matched_minutes": len(indices),
                "ftmo_spread_price_quantiles": _quantiles(ftmo_bucket, DEFAULT_QUANTILES),
                "dxz_spread_price_quantiles": _quantiles(dxz_bucket, DEFAULT_QUANTILES),
                "delta_price_quantiles": _quantiles(delta_bucket, DEFAULT_QUANTILES),
                "conservative_delta_price_per_side": round(
                    max(0.0, _percentile(delta_bucket, conservative_quantile)), 12
                ),
            }
        )

    return {
        "evaluator_symbol": evaluator_symbol.strip(),
        "ftmo_symbol": ftmo["symbol"],
        "dxz_symbol": dxz["symbol"],
        "coverage": {
            "from_utc": minutes[0].isoformat().replace("+00:00", "Z"),
            "to_utc": minutes[-1].isoformat().replace("+00:00", "Z"),
            "matched_minutes": len(minutes),
            "timestamp_contract": "EXACT_IDENTICAL_M1_MINUTES",
        },
        "ftmo_point_size": ftmo["point_size"],
        "dxz_point_size": dxz["point_size"],
        "ftmo_spread_price_quantiles": _quantiles(ftmo_prices, DEFAULT_QUANTILES),
        "dxz_spread_price_quantiles": _quantiles(dxz_prices, DEFAULT_QUANTILES),
        "delta_price_quantiles": _quantiles(deltas, DEFAULT_QUANTILES),
        "conservative_delta_price_per_side": round(
            max(0.0, _percentile(deltas, conservative_quantile)), 12
        ),
        "session_buckets": session_buckets,
        "inputs": {"ftmo": ftmo, "dxz": dxz},
    }


def calibrate_spec(spec: Any) -> dict[str, Any]:
    required = {
        "schema",
        "session_bucket_minutes",
        "conservative_quantile",
        "minimum_matched_minutes",
        "minimum_bucket_minutes",
        "pairs",
    }
    if not isinstance(spec, Mapping) or set(spec) != required:
        raise SpreadCalibrationError("spec: unexpected fields")
    if spec["schema"] != SPEC_SCHEMA:
        raise SpreadCalibrationError("spec.schema: unsupported schema")
    bucket_minutes = _positive_int(spec["session_bucket_minutes"], "session_bucket_minutes")
    if 1_440 % bucket_minutes != 0:
        raise SpreadCalibrationError("session_bucket_minutes must divide 1440")
    conservative_quantile = _finite(spec["conservative_quantile"], "conservative_quantile")
    if not 0.75 <= conservative_quantile < 1.0:
        raise SpreadCalibrationError("conservative_quantile must be in [0.75, 1.0)")
    minimum_matched = _positive_int(spec["minimum_matched_minutes"], "minimum_matched_minutes")
    minimum_bucket = _positive_int(spec["minimum_bucket_minutes"], "minimum_bucket_minutes")
    pairs = spec["pairs"]
    if not isinstance(pairs, list) or not pairs:
        raise SpreadCalibrationError("pairs: expected non-empty list")
    calibrated = [
        _calibrate_pair(
            pair,
            pair_index=index,
            bucket_minutes=bucket_minutes,
            conservative_quantile=conservative_quantile,
            minimum_matched_minutes=minimum_matched,
            minimum_bucket_minutes=minimum_bucket,
        )
        for index, pair in enumerate(pairs)
    ]
    symbols = [row["evaluator_symbol"] for row in calibrated]
    if len(set(symbols)) != len(symbols):
        raise SpreadCalibrationError("pairs: duplicate evaluator_symbol")
    return {
        "schema": ARTIFACT_SCHEMA,
        "status": "PASS",
        "evidence_class": "DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1",
        "method": "MATCHED_M1_FTMO_MINUS_DXZ_SPREAD_PRICE_DELTA",
        "charge_contract": "NON_NEGATIVE_UPPER_TAIL_DELTA_CHARGED_PER_TRADE_SIDE",
        "conservative_quantile": conservative_quantile,
        "session_bucket_minutes": bucket_minutes,
        "minimum_matched_minutes": minimum_matched,
        "minimum_bucket_minutes": minimum_bucket,
        "pairs": calibrated,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    spec_path = args.spec.expanduser().resolve()
    try:
        spec = load_json(spec_path, "spec")
        artifact = calibrate_spec(spec)
        artifact["spec"] = _binding(str(spec_path), "spec")
        digest = write_json_atomic(args.output, artifact)
        print(json.dumps({"status": "PASS", "path": str(args.output.resolve()), "sha256": digest}))
        return 0
    except (SpreadCalibrationError, TimeboxEvaluationError) as exc:
        refusal: dict[str, Any] = {
            "schema": ARTIFACT_SCHEMA,
            "status": "REFUSED",
            "evidence_class": "DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1",
            "error": str(exc),
        }
        if spec_path.is_file():
            refusal["spec"] = _binding(str(spec_path), "spec")
        digest = write_json_atomic(args.output, refusal)
        print(
            json.dumps(
                {"status": "REFUSED", "path": str(args.output.resolve()), "sha256": digest, "error": str(exc)}
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
