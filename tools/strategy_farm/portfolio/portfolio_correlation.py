from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import itertools
import json
import math
from pathlib import Path
from typing import Any

try:
    import numpy as np
except ImportError:  # pragma: no cover - portfolio tooling requires numpy in production
    np = None  # type: ignore[assignment]

try:
    from .commission import describe_model, load_model
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        Trade,
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
        Trade,
        align,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )


COMMISSION_BASIS = "worst_case_dxz_ftmo"
CORRELATION_SCHEMA = "qm.portfolio-correlation/v2"
SPARSE_METHOD = "ZK_SBB_PRIMARY_WITH_COS_SUPPLEMENTARY_FLAG"
SPARSE_METHOD_STATUS = "OWNER_RATIFIED"
NUMERIC_THRESHOLD_STATUS = "WORKING_DEFAULT_OPEN_OWNER_ITEM"
OWNER_DECISION = "OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904"

OWNER_RATIFIED_MAX_ABS_CORRELATION = 0.50
WORKING_DEFAULT_BOOTSTRAP_REPLICATES = 4000
WORKING_DEFAULT_BOOTSTRAP_SEED = 20260903
WORKING_DEFAULT_COS_ALPHA = 0.05
WORKING_DEFAULT_COS_MIN_LIFT = 1.5
WORKING_DEFAULT_COS_MIN_EXPECTED = 5.0
WORKING_DEFAULT_COS_MIN_OCCUPANCY_DAYS = 30
WORKING_DEFAULT_SIGNED_REPORT_FLOOR = 20


def build_artifact(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    min_overlap_days: int = 60,
    max_abs_correlation: float = OWNER_RATIFIED_MAX_ABS_CORRELATION,
    bootstrap_replicates: int = WORKING_DEFAULT_BOOTSTRAP_REPLICATES,
    bootstrap_seed: int = WORKING_DEFAULT_BOOTSTRAP_SEED,
    cos_alpha: float = WORKING_DEFAULT_COS_ALPHA,
    cos_min_lift: float = WORKING_DEFAULT_COS_MIN_LIFT,
    cos_min_expected: float = WORKING_DEFAULT_COS_MIN_EXPECTED,
    cos_min_occupancy_days: int = WORKING_DEFAULT_COS_MIN_OCCUPANCY_DAYS,
    signed_report_floor: int = WORKING_DEFAULT_SIGNED_REPORT_FLOOR,
) -> dict[str, Any]:
    _validate_method_parameters(
        min_overlap_days=min_overlap_days,
        max_abs_correlation=max_abs_correlation,
        bootstrap_replicates=bootstrap_replicates,
        cos_alpha=cos_alpha,
        cos_min_lift=cos_min_lift,
        cos_min_expected=cos_min_expected,
        cos_min_occupancy_days=cos_min_occupancy_days,
        signed_report_floor=signed_report_floor,
    )
    if np is None:
        raise RuntimeError("numpy is required for the ratified ZK-SBB/COS method")
    correlation_limit_status = _ratification_status(
        max_abs_correlation, OWNER_RATIFIED_MAX_ABS_CORRELATION
    )
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
    del matrix  # the ratified method uses pair-local common support, never the union matrix

    occupancy = _occupancy_profiles(streams)
    pair_evidence: list[dict[str, Any]] = []
    for key_a, key_b in itertools.combinations(keys, 2):
        label_a = key_label(key_a)
        label_b = key_label(key_b)
        pair_seed = _pair_seed(bootstrap_seed, label_a, label_b)
        layer_a = _zk_sbb(
            series_by_key[key_a],
            series_by_key[key_b],
            max_abs_correlation=max_abs_correlation,
            correlation_limit_status=correlation_limit_status,
            bootstrap_replicates=bootstrap_replicates,
            seed=pair_seed,
        )
        layer_b = _cos_pair(
            key_a,
            key_b,
            occupancy,
            cos_min_expected=cos_min_expected,
            cos_min_occupancy_days=cos_min_occupancy_days,
            signed_report_floor=signed_report_floor,
        )
        pair_evidence.append(
            {
                "pair": [label_a, label_b],
                "co_active_exit_days": layer_a["co_active_exit_days"],
                "dense_path": layer_a["co_active_exit_days"] >= min_overlap_days,
                "layer_a": layer_a,
                "layer_b": layer_b,
            }
        )

    _apply_bh_and_verdicts(
        pair_evidence,
        alpha=cos_alpha,
        min_lift=cos_min_lift,
        min_overlap_days=min_overlap_days,
        max_abs_correlation=max_abs_correlation,
        correlation_limit_status=correlation_limit_status,
    )
    correlation, insufficient_overlap = _admission_matrix(keys, pair_evidence)

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
        "schema": CORRELATION_SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "basis": basis,
        "generated_basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "commission_degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "min_overlap_days": min_overlap_days,
        "method": SPARSE_METHOD,
        "method_status": SPARSE_METHOD_STATUS,
        "owner_decision": OWNER_DECISION,
        "numeric_threshold_status": NUMERIC_THRESHOLD_STATUS,
        "admission_ready": (
            correlation_limit_status == "OWNER_RATIFIED"
            and all(record["dense_path"] for record in pair_evidence)
        ),
        "dense_admission_ready": correlation_limit_status == "OWNER_RATIFIED",
        "sparse_admission_ready": False,
        "admission_hold_reason": (
            "CORRELATION_LIMIT_OVERRIDE_IS_NOT_OWNER_RATIFIED"
            if correlation_limit_status != "OWNER_RATIFIED"
            else (
                None
                if all(record["dense_path"] for record in pair_evidence)
                else "SPARSE_NUMERIC_THRESHOLDS_AWAIT_FIRST_SHA_FROZEN_Q14_COHORT"
            )
        ),
        "thresholds": {
            "dense_and_layer_a_max_abs_correlation": {
                "value": max_abs_correlation,
                "status": correlation_limit_status,
            },
            "dense_co_active_exit_days": {
                "value": min_overlap_days,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "bootstrap_replicates": {
                "value": bootstrap_replicates,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "bootstrap_seed": {
                "value": bootstrap_seed,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "cos_alpha_bh_fdr": {
                "value": cos_alpha,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "cos_min_lift": {
                "value": cos_min_lift,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "cos_min_expected_cooccupancy": {
                "value": cos_min_expected,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "cos_min_occupancy_days": {
                "value": cos_min_occupancy_days,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
            "signed_report_floor": {
                "value": signed_report_floor,
                "status": NUMERIC_THRESHOLD_STATUS,
            },
        },
        "n_series": len(keys),
        "n_days": len(dates),
        "keys": [key_label(key) for key in keys],
        "dates": [day.isoformat() for day in dates],
        "correlation": correlation,
        "insufficient_overlap": insufficient_overlap,
        "pair_evidence": pair_evidence,
        "per_series": per_series,
    }


def _validate_method_parameters(
    *,
    min_overlap_days: int,
    max_abs_correlation: float,
    bootstrap_replicates: int,
    cos_alpha: float,
    cos_min_lift: float,
    cos_min_expected: float,
    cos_min_occupancy_days: int,
    signed_report_floor: int,
) -> None:
    integer_values = {
        "min_overlap_days": min_overlap_days,
        "bootstrap_replicates": bootstrap_replicates,
        "cos_min_occupancy_days": cos_min_occupancy_days,
        "signed_report_floor": signed_report_floor,
    }
    for name, value in integer_values.items():
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            raise ValueError(f"{name} must be a positive integer")
    if bootstrap_replicates < 50:
        raise ValueError("bootstrap_replicates must be at least 50")
    if not 0.0 < float(max_abs_correlation) < 1.0:
        raise ValueError("max_abs_correlation must be between zero and one")
    if not 0.0 < float(cos_alpha) < 1.0:
        raise ValueError("cos_alpha must be between zero and one")
    if float(cos_min_lift) <= 1.0:
        raise ValueError("cos_min_lift must be greater than one")
    if float(cos_min_expected) <= 0.0:
        raise ValueError("cos_min_expected must be positive")


def _ratification_status(value: float, ratified_value: float) -> str:
    return (
        "OWNER_RATIFIED"
        if math.isclose(float(value), ratified_value, rel_tol=0.0, abs_tol=1e-12)
        else "UNRATIFIED_OVERRIDE"
    )


def _pair_seed(seed: int, label_a: str, label_b: str) -> int:
    raw = f"{int(seed)}\0{label_a}\0{label_b}".encode("utf-8")
    return int.from_bytes(hashlib.sha256(raw).digest()[:8], "big", signed=False)


def _business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    result: list[dt.date] = []
    day = start
    while day <= end:
        if day.weekday() < 5:
            result.append(day)
        day += dt.timedelta(days=1)
    return result


def _common_support_vectors(
    left: dict[dt.date, float], right: dict[dt.date, float]
) -> dict[str, Any] | None:
    if not left or not right:
        return None
    start = max(min(left), min(right))
    end = min(max(left), max(right))
    if start > end:
        return None
    days = set(_business_days(start, end))
    weekend_trade_days = {
        day
        for day in set(left) | set(right)
        if start <= day <= end and day.weekday() >= 5
    }
    ordered = sorted(days | weekend_trade_days)
    x = np.asarray([left.get(day, 0.0) for day in ordered], dtype=float)
    y = np.asarray([right.get(day, 0.0) for day in ordered], dtype=float)
    return {
        "start": start,
        "end": end,
        "days": ordered,
        "x": x,
        "y": y,
        "weekend_trade_days_folded": len(weekend_trade_days),
    }


def _pearson_array(left: Any, right: Any) -> float | None:
    if len(left) < 2 or len(right) < 2:
        return None
    left_diff = left - left.mean()
    right_diff = right - right.mean()
    left_norm = float(np.sqrt(np.sum(left_diff * left_diff)))
    right_norm = float(np.sqrt(np.sum(right_diff * right_diff)))
    if left_norm == 0.0 or right_norm == 0.0:
        return None
    value = float(np.sum(left_diff * right_diff) / (left_norm * right_norm))
    return _round_float(value)


def _autocovariance(values: Any, max_lag: int) -> Any:
    centered = values - values.mean()
    count = len(values)
    result = np.empty(max_lag + 1, dtype=float)
    for lag in range(max_lag + 1):
        result[lag] = float(np.dot(centered[: count - lag], centered[lag:]) / count)
    return result


def _flat_top_kernel(values: Any) -> Any:
    absolute = np.abs(values)
    output = np.zeros_like(absolute, dtype=float)
    output[absolute <= 0.5] = 1.0
    middle = (absolute > 0.5) & (absolute <= 1.0)
    output[middle] = 2.0 * (1.0 - absolute[middle])
    return output


def _optimal_stationary_block_length(values: Any) -> float:
    """Politis-White/PPW mean block length for the stationary bootstrap."""

    values = np.asarray(values, dtype=float)
    count = len(values)
    if count < 8 or np.allclose(values, values[0]):
        return 1.0
    max_lag = min(count - 1, int(math.ceil(10.0 * math.log10(count))) + 20)
    covariances = _autocovariance(values, max_lag)
    if covariances[0] <= 0.0:
        return 1.0
    correlations = covariances / covariances[0]
    threshold = 2.0 * math.sqrt(math.log10(count) / count)
    consecutive = max(5, int(math.ceil(math.sqrt(math.log10(count)))))
    selected_lag = max_lag
    for lag in range(1, max_lag - consecutive + 1):
        if np.all(np.abs(correlations[lag : lag + consecutive]) < threshold):
            selected_lag = lag - 1
            break
    bandwidth = min(max(2 * selected_lag, 2), max_lag)
    lags = np.arange(-bandwidth, bandwidth + 1)
    lag_covariances = np.asarray([covariances[abs(int(lag))] for lag in lags])
    kernel = _flat_top_kernel(lags / bandwidth)
    first_moment = float(np.sum(kernel * np.abs(lags) * lag_covariances))
    sb_variance = 2.0 * float(np.sum(kernel * lag_covariances)) ** 2
    if sb_variance <= 0.0 or first_moment == 0.0:
        return 1.0
    block = (
        ((2.0 * first_moment * first_moment) / sb_variance) ** (1.0 / 3.0)
        * (count ** (1.0 / 3.0))
    )
    return float(np.clip(block, 1.0, max(1.0, count / 3.0)))


def _stationary_indices(rng: Any, count: int, block_length: float, rows: int) -> Any:
    restart_probability = 1.0 / max(block_length, 1.0)
    starts = rng.integers(0, count, size=(rows, count))
    restart = rng.random((rows, count)) < restart_probability
    restart[:, 0] = True
    indices = np.empty((rows, count), dtype=np.int64)
    indices[:, 0] = starts[:, 0]
    for column in range(1, count):
        continuing = (indices[:, column - 1] + 1) % count
        indices[:, column] = np.where(
            restart[:, column], starts[:, column], continuing
        )
    return indices


def _bootstrap_correlation_ci(
    left: Any,
    right: Any,
    *,
    block_length: float,
    replicates: int,
    seed: int,
) -> dict[str, Any] | None:
    rng = np.random.default_rng(seed)
    values: list[float] = []
    remaining = replicates
    while remaining:
        batch = min(256, remaining)
        indices = _stationary_indices(rng, len(left), block_length, batch)
        x = left[indices]
        y = right[indices]
        x -= x.mean(axis=1, keepdims=True)
        y -= y.mean(axis=1, keepdims=True)
        x_norm = np.sqrt(np.sum(x * x, axis=1))
        y_norm = np.sqrt(np.sum(y * y, axis=1))
        valid = (x_norm > 0.0) & (y_norm > 0.0)
        if np.any(valid):
            correlations = np.sum(x[valid] * y[valid], axis=1) / (
                x_norm[valid] * y_norm[valid]
            )
            values.extend(float(value) for value in correlations if np.isfinite(value))
        remaining -= batch
    if len(values) < 50:
        return None
    sample = np.asarray(values, dtype=float)
    low, high = np.percentile(sample, [2.5, 97.5])
    return {
        "ci_low": float(low),
        "ci_high": float(high),
        "absolute_ci_upper": max(abs(float(low)), abs(float(high))),
        "valid_replicates": len(values),
    }


def _zk_sbb(
    left: dict[dt.date, float],
    right: dict[dt.date, float],
    *,
    max_abs_correlation: float,
    correlation_limit_status: str,
    bootstrap_replicates: int,
    seed: int,
) -> dict[str, Any]:
    vectors = _common_support_vectors(left, right)
    if vectors is None:
        return {
            "method": "ZEROS_KEPT_COMMON_SUPPORT_STATIONARY_BLOCK_BOOTSTRAP",
            "verdict": "UNTESTABLE",
            "reason": "NO_COMMON_SUPPORT",
            "correlation_limit": max_abs_correlation,
            "correlation_limit_status": correlation_limit_status,
            "r_hat": None,
            "ci_low": None,
            "ci_high": None,
            "absolute_ci_upper": None,
            "co_active_exit_days": 0,
            "n_calendar_observations": 0,
        }
    left_values = vectors["x"]
    right_values = vectors["y"]
    co_active = int(np.sum((left_values != 0.0) & (right_values != 0.0)))
    r_hat = _pearson_array(left_values, right_values)
    base = {
        "method": "ZEROS_KEPT_COMMON_SUPPORT_STATIONARY_BLOCK_BOOTSTRAP",
        "support_start": vectors["start"].isoformat(),
        "support_end": vectors["end"].isoformat(),
        "n_calendar_observations": len(vectors["days"]),
        "weekend_trade_days_folded": vectors["weekend_trade_days_folded"],
        "active_exit_days_left": int(np.sum(left_values != 0.0)),
        "active_exit_days_right": int(np.sum(right_values != 0.0)),
        "co_active_exit_days": co_active,
        "r_hat": r_hat,
        "bootstrap_replicates": bootstrap_replicates,
        "bootstrap_seed": seed,
        "numeric_threshold_status": NUMERIC_THRESHOLD_STATUS,
        "correlation_limit": max_abs_correlation,
        "correlation_limit_status": correlation_limit_status,
    }
    if r_hat is None:
        return {
            **base,
            "verdict": "UNTESTABLE",
            "reason": "ZERO_VARIANCE_OR_TOO_FEW_OBSERVATIONS",
            "block_length": None,
            "ci_low": None,
            "ci_high": None,
            "absolute_ci_upper": None,
        }
    block_components = {
        "left": _optimal_stationary_block_length(left_values),
        "right": _optimal_stationary_block_length(right_values),
        "cross_product": _optimal_stationary_block_length(left_values * right_values),
    }
    block_length = max(block_components.values())
    interval = _bootstrap_correlation_ci(
        left_values,
        right_values,
        block_length=block_length,
        replicates=bootstrap_replicates,
        seed=seed,
    )
    if interval is None:
        return {
            **base,
            "verdict": "UNTESTABLE",
            "reason": "BOOTSTRAP_DEGENERATE",
            "block_length": _round_float(block_length),
            "block_length_components": {
                key: _round_float(value) for key, value in block_components.items()
            },
            "ci_low": None,
            "ci_high": None,
            "absolute_ci_upper": None,
        }
    certified = correlation_limit_status == "OWNER_RATIFIED" and (
        interval["ci_low"] > -max_abs_correlation
        and interval["ci_high"] < max_abs_correlation
    )
    return {
        **base,
        "ci_low": _round_float(interval["ci_low"]),
        "ci_high": _round_float(interval["ci_high"]),
        "absolute_ci_upper": _round_float(interval["absolute_ci_upper"]),
        "valid_replicates": interval["valid_replicates"],
        "block_length": _round_float(block_length),
        "block_length_components": {
            key: _round_float(value) for key, value in block_components.items()
        },
        "verdict": "CERTIFY_A" if certified else "ABSTAIN",
        "reason": (
            "CI_STRICTLY_INSIDE_LIMIT"
            if certified
            else (
                "CORRELATION_LIMIT_UNRATIFIED"
                if correlation_limit_status != "OWNER_RATIFIED"
                else "CI_DOES_NOT_CLEAR_LIMIT"
            )
        ),
    }


def _side_sign(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        if float(value) > 0.0:
            return 1
        if float(value) < 0.0:
            return -1
        return None
    normalized = str(value).strip().upper()
    if normalized in {"BUY", "LONG", "1", "+1"}:
        return 1
    if normalized in {"SELL", "SHORT", "-1"}:
        return -1
    return None


def _occupancy_profiles(
    streams: dict[tuple[int, str], list[Trade]],
) -> dict[str, Any]:
    all_dates: list[dt.date] = []
    for trades in streams.values():
        for trade in trades:
            all_dates.append(dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date())
            if trade.entry_time is not None:
                all_dates.append(
                    dt.datetime.fromtimestamp(trade.entry_time, tz=dt.UTC).date()
                )
    if not all_dates:
        return {"ring_dates": [], "profiles": {}}
    start = min(all_dates)
    end = max(all_dates)
    ring_dates: list[dt.date] = []
    day = start
    while day <= end:
        ring_dates.append(day)
        day += dt.timedelta(days=1)
    date_index = {value: index for index, value in enumerate(ring_dates)}
    profiles: dict[tuple[int, str], dict[str, Any]] = {}
    for key, trades in streams.items():
        occupied = np.zeros(len(ring_dates), dtype=np.int8)
        direction = np.zeros(len(ring_dates), dtype=float)
        missing_entry = 0
        invalid_interval = 0
        missing_direction = 0
        for trade in trades:
            if trade.entry_time is None:
                missing_entry += 1
                continue
            entry = dt.datetime.fromtimestamp(trade.entry_time, tz=dt.UTC).date()
            exit_day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
            if entry > exit_day:
                invalid_interval += 1
                continue
            sign = _side_sign(getattr(trade, "side", None))
            notional = trade.notional
            direction_available = (
                sign is not None
                and notional is not None
                and math.isfinite(float(notional))
                and float(notional) > 0.0
            )
            if not direction_available:
                missing_direction += 1
            current = entry
            while current <= exit_day:
                position = date_index[current]
                occupied[position] = 1
                if direction_available:
                    direction[position] += sign * float(notional)
                current += dt.timedelta(days=1)
        profiles[key] = {
            "occupied": occupied,
            "direction": direction,
            "occupancy_days": int(np.sum(occupied)),
            "missing_entry_time_trades": missing_entry,
            "invalid_intervals": invalid_interval,
            "missing_direction_trades": missing_direction,
            "direction_complete": missing_direction == 0,
        }
    return {"ring_dates": ring_dates, "profiles": profiles}


def _cos_pair(
    key_a: tuple[int, str],
    key_b: tuple[int, str],
    occupancy: dict[str, Any],
    *,
    cos_min_expected: float,
    cos_min_occupancy_days: int,
    signed_report_floor: int,
) -> dict[str, Any]:
    ring_dates = occupancy["ring_dates"]
    profiles = occupancy["profiles"]
    left = profiles.get(key_a)
    right = profiles.get(key_b)
    base = {
        "method": "EXACT_CIRCULAR_SHIFT_COOCCUPANCY",
        "ring_start": ring_dates[0].isoformat() if ring_dates else None,
        "ring_end": ring_dates[-1].isoformat() if ring_dates else None,
        "ring_days": len(ring_dates),
        "numeric_threshold_status": NUMERIC_THRESHOLD_STATUS,
        "p_upper": None,
        "bh_adjusted_p": None,
        "bh_reject": False,
        "flag": False,
        "psi": None,
        "psi_status": "NOT_EVALUATED",
    }
    if left is None or right is None or not ring_dates:
        return {**base, "testability": "UNTESTABLE_INPUT", "reason": "STREAM_MISSING"}
    input_errors = {
        "left_missing_entry_time_trades": left["missing_entry_time_trades"],
        "right_missing_entry_time_trades": right["missing_entry_time_trades"],
        "left_invalid_intervals": left["invalid_intervals"],
        "right_invalid_intervals": right["invalid_intervals"],
    }
    if any(input_errors.values()):
        return {
            **base,
            **input_errors,
            "testability": "UNTESTABLE_INPUT",
            "reason": "ENTRY_TIME_OR_INTERVAL_INVALID",
        }
    left_occupied = left["occupied"]
    right_occupied = right["occupied"]
    ring_days = len(ring_dates)
    left_days = left["occupancy_days"]
    right_days = right["occupancy_days"]
    # Avoid int8 dot-product overflow for rings longer than 127 co-occupied days.
    observed = int(np.sum((left_occupied != 0) & (right_occupied != 0)))
    expected = (left_days * right_days / ring_days) if ring_days else 0.0
    lift = (observed / expected) if expected > 0.0 else None
    rotations = np.rint(
        np.fft.ifft(
            np.fft.fft(left_occupied.astype(float))
            * np.conjugate(np.fft.fft(right_occupied.astype(float)))
        ).real
    ).astype(int)
    p_upper = float(np.sum(rotations >= observed) / ring_days)
    saturated = (
        left_days == ring_days
        or right_days == ring_days
        or int(np.ptp(rotations)) == 0
    )
    if saturated:
        testability = "UNTESTABLE_SATURATION"
        reason = "EXACT_SHIFT_NULL_DEGENERATE"
    elif (
        left_days < cos_min_occupancy_days
        or right_days < cos_min_occupancy_days
        or expected < cos_min_expected
    ):
        testability = "UNTESTABLE_LOW_POWER"
        reason = "WORKING_DEFAULT_POWER_FLOOR_NOT_MET"
    else:
        testability = "TESTABLE"
        reason = "EXACT_SHIFT_NULL_AVAILABLE"

    psi: float | None = None
    psi_status = "CROSS_SYMBOL_NOT_APPLICABLE"
    if key_a[1] == key_b[1]:
        if observed < signed_report_floor:
            psi_status = "BELOW_WORKING_DEFAULT_REPORT_FLOOR"
        elif not left["direction_complete"] or not right["direction_complete"]:
            psi_status = "UNAVAILABLE_DIRECTION_INPUT"
        else:
            common = (left_occupied != 0) & (right_occupied != 0)
            left_sign = np.sign(left["direction"])
            right_sign = np.sign(right["direction"])
            same = int(np.sum(common & (left_sign != 0) & (left_sign == right_sign)))
            opposite = int(np.sum(common & (left_sign != 0) & (left_sign == -right_sign)))
            psi = _round_float((same - opposite) / observed) if observed else None
            psi_status = "AVAILABLE" if psi is not None else "NO_COOCCUPANCY"

    return {
        **base,
        **input_errors,
        "testability": testability,
        "reason": reason,
        "occupancy_days_left": left_days,
        "occupancy_days_right": right_days,
        "occupancy_fraction_left": _round_float(left_days / ring_days),
        "occupancy_fraction_right": _round_float(right_days / ring_days),
        "observed_cooccupancy": observed,
        "expected_cooccupancy": _round_float(expected),
        "lift": _round_float(lift) if lift is not None else None,
        "p_upper": _round_float(p_upper),
        "exact_rotations": ring_days,
        "psi": psi,
        "psi_status": psi_status,
    }


def _benjamini_hochberg(p_values: list[float], alpha: float) -> list[dict[str, Any]]:
    if not p_values:
        return []
    order = sorted(range(len(p_values)), key=lambda index: (p_values[index], index))
    count = len(order)
    adjusted = [1.0] * count
    running = 1.0
    for reverse_rank, index in enumerate(reversed(order), start=1):
        rank = count - reverse_rank + 1
        running = min(running, p_values[index] * count / rank)
        adjusted[index] = min(1.0, running)
    cutoff_rank = 0
    for rank, index in enumerate(order, start=1):
        if p_values[index] <= alpha * rank / count:
            cutoff_rank = rank
    rejected = set(order[:cutoff_rank])
    return [
        {
            "adjusted_p": _round_float(adjusted[index]),
            "reject": index in rejected,
        }
        for index in range(count)
    ]


def _apply_bh_and_verdicts(
    records: list[dict[str, Any]],
    *,
    alpha: float,
    min_lift: float,
    min_overlap_days: int,
    max_abs_correlation: float,
    correlation_limit_status: str,
) -> None:
    testable = [
        record
        for record in records
        if record["layer_b"]["testability"] == "TESTABLE"
    ]
    corrections = _benjamini_hochberg(
        [float(record["layer_b"]["p_upper"]) for record in testable], alpha
    )
    for record, correction in zip(testable, corrections):
        layer_b = record["layer_b"]
        layer_b["bh_adjusted_p"] = correction["adjusted_p"]
        layer_b["bh_reject"] = correction["reject"]
        signed_ok = layer_b["psi"] is None or float(layer_b["psi"]) > 0.0
        layer_b["flag"] = bool(
            correction["reject"]
            and layer_b["lift"] is not None
            and float(layer_b["lift"]) > min_lift
            and signed_ok
        )
        layer_b["verdict"] = "FLAG_B" if layer_b["flag"] else "CLEAR_B"
        layer_b["alpha"] = alpha
        layer_b["min_lift"] = min_lift
    for record in records:
        layer_a = record["layer_a"]
        layer_b = record["layer_b"]
        if "verdict" not in layer_b:
            layer_b["verdict"] = layer_b["testability"]
            layer_b["alpha"] = alpha
            layer_b["min_lift"] = min_lift
        dense = record["co_active_exit_days"] >= min_overlap_days
        r_hat = layer_a.get("r_hat")
        if dense:
            if correlation_limit_status != "OWNER_RATIFIED" or r_hat is None:
                method_verdict = "ABSTAIN"
            elif abs(float(r_hat)) < max_abs_correlation:
                method_verdict = "CERTIFY_ORTHOGONAL"
            else:
                method_verdict = "REVIEW"
            admission_verdict = method_verdict
            admission_reason = (
                "DENSE_PEARSON_DECISIVE"
                if correlation_limit_status == "OWNER_RATIFIED"
                else "CORRELATION_LIMIT_UNRATIFIED"
            )
        elif layer_a.get("verdict") != "CERTIFY_A":
            method_verdict = "ABSTAIN"
            admission_verdict = "ABSTAIN"
            admission_reason = "ZK_SBB_DID_NOT_CERTIFY"
        elif layer_b.get("flag") is True:
            method_verdict = "REVIEW"
            admission_verdict = "REVIEW"
            admission_reason = "COS_SUPPLEMENTARY_FLAG"
        elif layer_b.get("psi_status") == "UNAVAILABLE_DIRECTION_INPUT":
            method_verdict = "ABSTAIN"
            admission_verdict = "ABSTAIN"
            admission_reason = "SIGNED_REFINEMENT_INPUT_MISSING"
        else:
            method_verdict = "CERTIFY_ORTHOGONAL"
            admission_verdict = "ABSTAIN"
            admission_reason = "SPARSE_NUMERIC_THRESHOLDS_OPEN"
        record["method_verdict"] = method_verdict
        record["admission_verdict"] = admission_verdict
        record["admission_reason"] = admission_reason


def _admission_matrix(
    keys: list[tuple[int, str]], records: list[dict[str, Any]]
) -> tuple[list[list[float | None]], list[list[str]]]:
    count = len(keys)
    output: list[list[float | None]] = [
        [None for _ in range(count)] for _ in range(count)
    ]
    for index in range(count):
        output[index][index] = 1.0
    indexes = {key_label(key): index for index, key in enumerate(keys)}
    insufficient: list[list[str]] = []
    for record in records:
        label_a, label_b = record["pair"]
        left = indexes[label_a]
        right = indexes[label_b]
        if not record["dense_path"]:
            insufficient.append([label_a, label_b])
            continue
        value = record["layer_a"].get("r_hat")
        output[left][right] = value
        output[right][left] = value
    return output, insufficient


def correlation_matrix(
    keys: list[tuple[int, str]],
    matrix: Any,
    min_overlap_days: int,
) -> tuple[list[list[float | None]], list[list[str]]]:
    """Legacy dense-path helper retained for admission/refit callers.

    The governed v2 artifact is built by ``build_artifact`` using pair-local
    common support and structured ZK-SBB/COS evidence. This helper cannot infer
    per-stream birth/death dates from an already aligned matrix and therefore
    must not be used to issue sparse-method certifications.
    """
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
    parser.add_argument(
        "--max-abs-correlation",
        type=float,
        default=OWNER_RATIFIED_MAX_ABS_CORRELATION,
        help="OWNER-ratified Q15 absolute-correlation limit (default: 0.50).",
    )
    parser.add_argument(
        "--bootstrap-replicates",
        type=int,
        default=WORKING_DEFAULT_BOOTSTRAP_REPLICATES,
        help="Open calibration item: stationary-bootstrap replicate count.",
    )
    parser.add_argument(
        "--bootstrap-seed",
        type=int,
        default=WORKING_DEFAULT_BOOTSTRAP_SEED,
        help="Open calibration item: deterministic base seed.",
    )
    parser.add_argument(
        "--cos-alpha",
        type=float,
        default=WORKING_DEFAULT_COS_ALPHA,
        help="Open calibration item: COS Benjamini-Hochberg FDR alpha.",
    )
    parser.add_argument(
        "--cos-min-lift",
        type=float,
        default=WORKING_DEFAULT_COS_MIN_LIFT,
        help="Open calibration item: minimum excess co-occupancy lift.",
    )
    parser.add_argument(
        "--cos-min-expected",
        type=float,
        default=WORKING_DEFAULT_COS_MIN_EXPECTED,
        help="Open calibration item: expected co-occupancy power floor.",
    )
    parser.add_argument(
        "--cos-min-occupancy-days",
        type=int,
        default=WORKING_DEFAULT_COS_MIN_OCCUPANCY_DAYS,
        help="Open calibration item: per-sleeve occupancy-day power floor.",
    )
    parser.add_argument(
        "--signed-report-floor",
        type=int,
        default=WORKING_DEFAULT_SIGNED_REPORT_FLOOR,
        help="Open calibration item: same-symbol signed-refinement report floor.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    artifact = build_artifact(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        min_overlap_days=args.min_overlap_days,
        max_abs_correlation=args.max_abs_correlation,
        bootstrap_replicates=args.bootstrap_replicates,
        bootstrap_seed=args.bootstrap_seed,
        cos_alpha=args.cos_alpha,
        cos_min_lift=args.cos_min_lift,
        cos_min_expected=args.cos_min_expected,
        cos_min_occupancy_days=args.cos_min_occupancy_days,
        signed_report_floor=args.signed_report_floor,
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
