#!/usr/bin/env python3
"""Evaluate sparse-D1 correlation, occupancy, and closing-tail evidence.

This is a read-only evidence tool.  It implements the OWNER-adopted V4 method
shape, applies only the ratified V2 |r| < 0.50 and SP-C3 limits, and abstains
when interval mark-to-market or pending-order evidence is incomplete.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np


SPEC_SCHEMA = "qm.ftmo-v4-tail-certification-spec/v1"
OUTPUT_SCHEMA = "qm.ftmo-v4-tail-certification/v1"
OWNER_V2_MAX_ABS_CORRELATION = 0.50
OWNER_V2_ACCOUNT_WEIGHT_BUDGET = 10.0
MAX_ROWS = 5_000_000


class CertificationError(ValueError):
    """Evidence or policy input cannot support a reproducible evaluation."""


def _reject_constant(token: str) -> None:
    raise CertificationError(f"non-finite JSON constant: {token}")


def _no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise CertificationError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def _loads(raw: bytes, label: str) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8-sig"), object_pairs_hook=_no_duplicates,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CertificationError(f"{label}: invalid UTF-8/JSON: {exc}") from exc


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise CertificationError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _binding(value: Any, label: str) -> tuple[Path, dict[str, Any]]:
    if not isinstance(value, str) or not value.strip():
        raise CertificationError(f"{label}: expected non-empty path")
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise CertificationError(f"{label}: file absent: {path}")
    return path, {"path": str(path), "size_bytes": path.stat().st_size, "sha256": _sha256(path)}


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise CertificationError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise CertificationError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise CertificationError(f"{label}: expected finite number")
    return number


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise CertificationError(f"{label}: expected positive integer")
    return value


@dataclass(frozen=True)
class Trade:
    opened: dt.datetime
    closed: dt.datetime
    net: float
    side: str | None
    notional: float | None


@dataclass(frozen=True)
class Sleeve:
    sleeve_id: str
    symbol: str
    weight: float
    trades: tuple[Trade, ...]
    stream_binding: dict[str, Any]
    q08_tail_binding: dict[str, Any]
    q08_tail_status: str
    q08_tail_detail: str


def _load_json(path: Path, label: str) -> Any:
    try:
        return _loads(path.read_bytes(), label)
    except OSError as exc:
        raise CertificationError(f"{label}: cannot read {path}: {exc}") from exc


def _load_sleeve(value: Any, index: int) -> Sleeve:
    label = f"sleeves[{index}]"
    required = {"sleeve_id", "symbol", "weight", "trade_stream_path", "q08_tail_path"}
    if not isinstance(value, Mapping) or set(value) != required:
        raise CertificationError(f"{label}: unexpected fields")
    sleeve_id, symbol = value["sleeve_id"], value["symbol"]
    if not isinstance(sleeve_id, str) or not sleeve_id.strip():
        raise CertificationError(f"{label}.sleeve_id: expected non-empty string")
    if not isinstance(symbol, str) or not symbol.strip():
        raise CertificationError(f"{label}.symbol: expected non-empty string")
    weight = _finite(value["weight"], f"{label}.weight")
    if weight <= 0:
        raise CertificationError(f"{label}.weight: expected positive")
    stream_path, stream_binding = _binding(value["trade_stream_path"], f"{label}.trade_stream_path")
    tail_path, tail_binding = _binding(value["q08_tail_path"], f"{label}.q08_tail_path")

    trades: list[Trade] = []
    try:
        with stream_path.open("rb") as handle:
            for number, raw in enumerate(handle, 1):
                if number > MAX_ROWS:
                    raise CertificationError(f"{label}.stream: row limit exceeded")
                if not raw.strip():
                    raise CertificationError(f"{label}.stream:{number}: blank row")
                row = _loads(raw, f"{label}.stream:{number}")
                if not isinstance(row, Mapping) or row.get("event") != "TRADE_CLOSED":
                    raise CertificationError(f"{label}.stream:{number}: expected TRADE_CLOSED")
                try:
                    opened = dt.datetime.fromtimestamp(int(row["entry_time"]), tz=dt.UTC)
                    closed = dt.datetime.fromtimestamp(int(row["time"]), tz=dt.UTC)
                except (KeyError, TypeError, ValueError, OSError) as exc:
                    raise CertificationError(f"{label}.stream:{number}: invalid timestamps") from exc
                if closed < opened:
                    raise CertificationError(f"{label}.stream:{number}: closes before entry")
                side = row.get("side")
                if side not in {"BUY", "SELL", None}:
                    raise CertificationError(f"{label}.stream:{number}: invalid side")
                notional = None if row.get("notional") is None else _finite(
                    row["notional"], f"{label}.stream:{number}.notional"
                )
                trades.append(
                    Trade(opened, closed, _finite(row.get("net"), f"{label}.stream:{number}.net"), side, notional)
                )
    except OSError as exc:
        raise CertificationError(f"{label}.stream: cannot read {stream_path}: {exc}") from exc
    if not trades:
        raise CertificationError(f"{label}.stream: no trades")

    tail = _load_json(tail_path, f"{label}.q08_tail")
    if not isinstance(tail, Mapping):
        raise CertificationError(f"{label}.q08_tail: expected object")
    return Sleeve(
        sleeve_id.strip(), symbol.strip(), weight,
        tuple(sorted(trades, key=lambda item: (item.closed, item.opened))),
        stream_binding, tail_binding, str(tail.get("status")), str(tail.get("detail")),
    )


def _daily_pnl(sleeve: Sleeve) -> dict[dt.date, float]:
    daily: dict[dt.date, float] = defaultdict(float)
    for trade in sleeve.trades:
        daily[trade.closed.date()] += sleeve.weight * trade.net
    return dict(daily)


def _business_days(first: dt.date, last: dt.date) -> list[dt.date]:
    days: list[dt.date] = []
    day = first
    while day <= last:
        if day.weekday() < 5:
            days.append(day)
        day += dt.timedelta(days=1)
    return days


def _pearson(left: np.ndarray, right: np.ndarray) -> float | None:
    if left.size < 2:
        return None
    left_centered = left - left.mean()
    right_centered = right - right.mean()
    denom = float(np.sqrt(np.dot(left_centered, left_centered) * np.dot(right_centered, right_centered)))
    if denom == 0.0:
        return None
    return float(np.dot(left_centered, right_centered) / denom)


def _auto_block_length(values: np.ndarray) -> int:
    """Politis-White style stationary-bootstrap selector (reported, not a gate)."""
    n = values.size
    if n < 4 or float(np.var(values)) == 0.0:
        return 1
    centered = values - values.mean()
    b_max = max(1, min(int(math.ceil(3.0 * math.sqrt(n))), max(1, n // 3)))
    kn = max(5, int(math.sqrt(max(1.0, math.log10(n)))))
    m_max = min(n - 1, int(math.ceil(math.sqrt(n))) + kn)
    acv = np.array([float(np.dot(centered[k:], centered[: n - k]) / n) for k in range(m_max + 1)])
    if acv[0] == 0.0:
        return 1
    threshold = 2.0 * math.sqrt(math.log10(n) / n)
    opt_m: int | None = None
    for lag in range(1, max(2, m_max - kn + 2)):
        stop = min(m_max + 1, lag + kn)
        if np.all(np.abs(acv[lag:stop] / acv[0]) < threshold):
            opt_m = lag
            break
    m = min(m_max, 2 * max(1, opt_m if opt_m is not None else m_max))
    long_run = acv[0]
    g = 0.0
    for lag in range(1, m + 1):
        ratio = lag / m
        weight = 1.0 if ratio <= 0.5 else 2.0 * (1.0 - ratio)
        long_run += 2.0 * weight * acv[lag]
        g += 2.0 * weight * lag * acv[lag]
    denominator = 2.0 * long_run * long_run
    if denominator <= 0.0 or g == 0.0:
        return 1
    selected = ((2.0 * g * g / denominator) ** (1.0 / 3.0)) * (n ** (1.0 / 3.0))
    return max(1, min(b_max, int(round(selected))))


def _stationary_bootstrap_ci(
    left: np.ndarray, right: np.ndarray, *, block_length: int,
    replicates: int, alpha: float, seed: int,
) -> tuple[float | None, float | None, int]:
    n = left.size
    rng = np.random.default_rng(seed)
    indices = np.empty((replicates, n), dtype=np.int32)
    indices[:, 0] = rng.integers(0, n, size=replicates)
    restart_probability = 1.0 / block_length
    for column in range(1, n):
        restart = rng.random(replicates) < restart_probability
        continuation = (indices[:, column - 1] + 1) % n
        fresh = rng.integers(0, n, size=replicates)
        indices[:, column] = np.where(restart, fresh, continuation)
    x = left[indices]
    y = right[indices]
    x -= x.mean(axis=1, keepdims=True)
    y -= y.mean(axis=1, keepdims=True)
    denom = np.sqrt(np.sum(x * x, axis=1) * np.sum(y * y, axis=1))
    valid = denom > 0.0
    if int(valid.sum()) < max(100, int(replicates * 0.95)):
        return None, None, int(valid.sum())
    values = np.sum(x[valid] * y[valid], axis=1) / denom[valid]
    low, high = np.quantile(values, [alpha / 2.0, 1.0 - alpha / 2.0])
    return float(low), float(high), int(valid.sum())


def _occupancy(sleeve: Sleeve) -> set[dt.date]:
    occupied: set[dt.date] = set()
    for trade in sleeve.trades:
        day = trade.opened.date()
        while day <= trade.closed.date():
            occupied.add(day)
            day += dt.timedelta(days=1)
    return occupied


def _signed_occupancy(sleeve: Sleeve) -> dict[dt.date, int]:
    totals: dict[dt.date, float] = defaultdict(float)
    for trade in sleeve.trades:
        if trade.side not in {"BUY", "SELL"}:
            continue
        sign = 1.0 if trade.side == "BUY" else -1.0
        size = 1.0 if trade.notional is None else trade.notional
        day = trade.opened.date()
        while day <= trade.closed.date():
            totals[day] += sign * size
            day += dt.timedelta(days=1)
    return {day: 1 if value > 0 else -1 if value < 0 else 0 for day, value in totals.items()}


def _cooccupancy(left: Sleeve, right: Sleeve, ring_days: list[dt.date]) -> dict[str, Any]:
    left_days, right_days = _occupancy(left), _occupancy(right)
    a = np.array([1.0 if day in left_days else 0.0 for day in ring_days])
    b = np.array([1.0 if day in right_days else 0.0 for day in ring_days])
    observed = int(np.dot(a, b))
    n_left, n_right, n = int(a.sum()), int(b.sum()), len(ring_days)
    expected = n_left * n_right / n
    null = np.rint(np.fft.irfft(np.fft.rfft(a) * np.conj(np.fft.rfft(b)), n=n)).astype(np.int64)
    p_upper = float(np.mean(null >= observed))
    signed = None
    signed_n = 0
    if left.symbol == right.symbol:
        left_sign, right_sign = _signed_occupancy(left), _signed_occupancy(right)
        shared = [day for day in left_days & right_days if left_sign.get(day, 0) and right_sign.get(day, 0)]
        signed_n = len(shared)
        if shared:
            agreement = sum(1 for day in shared if left_sign[day] == right_sign[day])
            signed = (2 * agreement - signed_n) / signed_n
    return {
        "ring_days": n, "left_occupancy_days": n_left, "right_occupancy_days": n_right,
        "co_occupied_days": observed, "expected_co_occupied_days": round(expected, 6),
        "lift": None if expected == 0 else round(observed / expected, 6),
        "p_upper_exact_all_circular_shifts": round(p_upper, 8),
        "signed_concordance": None if signed is None else round(signed, 6),
        "signed_concordance_days": signed_n,
        "flag_b": "UNRESOLVED_OWNER_NUMERIC_THRESHOLDS_ADVISORY_ONLY",
    }


def _pair_result(
    left: Sleeve, right: Sleeve, *, replicates: int, alpha: float, seed: int,
    ring_days: list[dt.date],
) -> dict[str, Any]:
    left_pnl, right_pnl = _daily_pnl(left), _daily_pnl(right)
    first = max(min(left_pnl), min(right_pnl))
    last = min(max(left_pnl), max(right_pnl))
    if last < first:
        return {
            "left": left.sleeve_id, "right": right.sleeve_id,
            "layer_a": {"verdict": "ABSTAIN", "reason": "NO_COMMON_SUPPORT"},
            "layer_b": _cooccupancy(left, right, ring_days),
        }
    days = _business_days(first, last)
    x = np.array([left_pnl.get(day, 0.0) for day in days], dtype=np.float64)
    y = np.array([right_pnl.get(day, 0.0) for day in days], dtype=np.float64)
    point = _pearson(x, y)
    coactive = sum(1 for day in days if left_pnl.get(day, 0.0) != 0.0 and right_pnl.get(day, 0.0) != 0.0)
    if point is None:
        layer_a = {"verdict": "ABSTAIN", "reason": "UNDEFINED_PEARSON", "sample_business_days": len(days)}
    else:
        block = max(_auto_block_length(x), _auto_block_length(y), _auto_block_length(x * y))
        pair_seed = seed ^ int(hashlib.sha256(f"{left.sleeve_id}|{right.sleeve_id}".encode()).hexdigest()[:8], 16)
        low, high, valid = _stationary_bootstrap_ci(
            x, y, block_length=block, replicates=replicates, alpha=alpha, seed=pair_seed,
        )
        certify = low is not None and high is not None and low > -OWNER_V2_MAX_ABS_CORRELATION and high < OWNER_V2_MAX_ABS_CORRELATION
        layer_a = {
            "verdict": "CERTIFIED" if certify else "ABSTAIN",
            "point_correlation": round(point, 8),
            "ci_low": None if low is None else round(low, 8),
            "ci_high": None if high is None else round(high, 8),
            "abs_ci_upper": None if low is None or high is None else round(max(abs(low), abs(high)), 8),
            "owner_v2_max_abs_correlation_exclusive": OWNER_V2_MAX_ABS_CORRELATION,
            "sample_business_days": len(days), "coactive_exit_days": coactive,
            "block_length": block, "replicates_requested": replicates,
            "replicates_valid": valid, "alpha": alpha,
            "common_support_first": first.isoformat(), "common_support_last": last.isoformat(),
        }
    return {
        "left": left.sleeve_id, "right": right.sleeve_id,
        "layer_a": layer_a, "layer_b": _cooccupancy(left, right, ring_days),
    }


def _weekly(daily: Mapping[dt.date, float]) -> dict[dt.date, float]:
    result: dict[dt.date, float] = defaultdict(float)
    for day, value in daily.items():
        result[day - dt.timedelta(days=day.weekday())] += value
    return dict(result)


def evaluate(spec: Any) -> dict[str, Any]:
    required = {
        "schema", "account_initial_balance", "currency", "bootstrap", "sleeves",
        "v2_owner_receipt_path", "v4_standard_path", "tail_policy_path", "interval_export_path",
    }
    if not isinstance(spec, Mapping) or set(spec) != required:
        raise CertificationError("spec: unexpected fields")
    if spec["schema"] != SPEC_SCHEMA:
        raise CertificationError("spec.schema: unsupported schema")
    initial = _finite(spec["account_initial_balance"], "account_initial_balance")
    if initial <= 0:
        raise CertificationError("account_initial_balance must be positive")
    currency = spec["currency"]
    if not isinstance(currency, str) or len(currency) != 3 or not currency.isupper():
        raise CertificationError("currency: expected three uppercase letters")
    bootstrap = spec["bootstrap"]
    if not isinstance(bootstrap, Mapping) or set(bootstrap) != {"replicates", "seed", "alpha"}:
        raise CertificationError("bootstrap: unexpected fields")
    replicates = _positive_int(bootstrap["replicates"], "bootstrap.replicates")
    if replicates < 100:
        raise CertificationError("bootstrap.replicates must be at least 100")
    seed = bootstrap["seed"]
    if isinstance(seed, bool) or not isinstance(seed, int):
        raise CertificationError("bootstrap.seed must be integer")
    alpha = _finite(bootstrap["alpha"], "bootstrap.alpha")
    if not 0.0 < alpha < 0.5:
        raise CertificationError("bootstrap.alpha must be in (0,0.5)")

    receipt_path, receipt_binding = _binding(spec["v2_owner_receipt_path"], "v2_owner_receipt_path")
    standard_path, standard_binding = _binding(spec["v4_standard_path"], "v4_standard_path")
    policy_path, policy_binding = _binding(spec["tail_policy_path"], "tail_policy_path")
    interval_path, interval_binding = _binding(spec["interval_export_path"], "interval_export_path")
    receipt_text = receipt_path.read_text(encoding="utf-8")
    if "max_pairwise_correlation = 0.50" not in receipt_text or "account_weight_budget = 10.0" not in receipt_text:
        raise CertificationError("V2 OWNER receipt does not contain the ratified constants")
    if "V4 (c)" not in receipt_text:
        raise CertificationError("V4 method receipt missing")
    policy = _load_json(policy_path, "tail_policy")
    if not isinstance(policy, Mapping) or policy.get("status") != "OWNER_RATIFIED":
        raise CertificationError("tail policy is not OWNER_RATIFIED")
    interval = _load_json(interval_path, "interval_export")
    if not isinstance(interval, Mapping) or interval.get("schema") != "qm.interval-equity-export/v1":
        raise CertificationError("interval export schema mismatch")

    values = spec["sleeves"]
    if not isinstance(values, list) or len(values) < 2:
        raise CertificationError("sleeves: expected at least two")
    sleeves = tuple(_load_sleeve(value, index) for index, value in enumerate(values))
    if len({sleeve.sleeve_id for sleeve in sleeves}) != len(sleeves):
        raise CertificationError("sleeves: duplicate sleeve_id")
    weight_sum = sum(sleeve.weight for sleeve in sleeves)
    if weight_sum > OWNER_V2_ACCOUNT_WEIGHT_BUDGET:
        raise CertificationError("weights exceed OWNER-ratified V2 account budget")

    all_occupancy = set().union(*(_occupancy(sleeve) for sleeve in sleeves))
    ring_first, ring_last = min(all_occupancy), max(all_occupancy)
    ring_days = [ring_first + dt.timedelta(days=index) for index in range((ring_last - ring_first).days + 1)]
    pairs = []
    for left_index, left in enumerate(sleeves):
        for right in sleeves[left_index + 1 :]:
            pairs.append(
                _pair_result(
                    left, right, replicates=replicates, alpha=alpha,
                    seed=seed, ring_days=ring_days,
                )
            )

    joint_daily: dict[dt.date, float] = defaultdict(float)
    per_sleeve_daily = {sleeve.sleeve_id: _daily_pnl(sleeve) for sleeve in sleeves}
    for daily in per_sleeve_daily.values():
        for day, value in daily.items():
            joint_daily[day] += value
    joint_weekly = _weekly(joint_daily)
    worst_day, worst_day_value = min(joint_daily.items(), key=lambda item: item[1])
    worst_week, worst_week_value = min(joint_weekly.items(), key=lambda item: item[1])

    tail = policy.get("tail")
    if not isinstance(tail, Mapping):
        raise CertificationError("tail policy tail section missing")
    close_only_daily_cap = initial * _finite(tail.get("venue_daily_loss_limit_pct"), "tail.daily") / 100.0 * _finite(
        tail.get("maximum_fraction_of_daily_limit"), "tail.maximum_fraction"
    )
    total_limit = initial * 0.10
    worst_fraction = _finite(tail.get("per_sleeve_worst_fraction"), "tail.per_sleeve_worst_fraction")
    divisor = _positive_int(tail.get("joint_sleeve_divisor"), "tail.joint_sleeve_divisor")
    required_cluster_sleeves = math.ceil(len(sleeves) / divisor)
    worst_sets: dict[str, set[dt.date]] = {}
    for sleeve in sleeves:
        daily = per_sleeve_daily[sleeve.sleeve_id]
        losses = sorted((value, day) for day, value in daily.items() if value < 0.0)
        count = max(1, math.ceil(len(losses) * worst_fraction)) if losses else 0
        worst_sets[sleeve.sleeve_id] = {day for _, day in losses[:count]}
    clustered = []
    for day in sorted(joint_daily):
        members = [key for key, days in worst_sets.items() if day in days]
        if len(members) >= required_cluster_sleeves:
            clustered.append({"day": day.isoformat(), "sleeves": members, "joint_close_net": round(joint_daily[day], 2)})

    candidate_results = []
    for sleeve in sleeves:
        related = [pair for pair in pairs if sleeve.sleeve_id in {pair["left"], pair["right"]}]
        layer_a = "CERTIFIED" if all(pair["layer_a"]["verdict"] == "CERTIFIED" for pair in related) else "ABSTAIN"
        reasons = []
        if layer_a != "CERTIFIED":
            reasons.append("ONE_OR_MORE_V4_LAYER_A_PAIRS_ABSTAIN")
        if interval.get("ftmo_readiness", {}).get("daily_loss") != "EVALUABLE":
            reasons.append("MISSING_INTERVAL_MIN_EQUITY")
        if interval.get("ftmo_readiness", {}).get("flat_at_target") != "EVALUABLE":
            reasons.append("MISSING_PENDING_OR_ENDPOINT_EQUITY")
        if sleeve.q08_tail_detail == "no_portfolio_peers_trivial_pass":
            reasons.append("Q08_8_3_TRIVIAL_NO_PEERS_NOT_BOOK_TAIL_EVIDENCE")
        candidate_results.append(
            {
                "sleeve_id": sleeve.sleeve_id, "symbol": sleeve.symbol,
                "verdict": "ABSTAIN" if reasons else "CERTIFIED",
                "layer_a_pairwise_verdict": layer_a, "reasons": reasons,
                "trades": len(sleeve.trades), "stream": sleeve.stream_binding,
                "q08_8_3": {
                    "status": sleeve.q08_tail_status, "detail": sleeve.q08_tail_detail,
                    "binding": sleeve.q08_tail_binding,
                },
            }
        )

    close_only_breach = -worst_day_value > close_only_daily_cap
    portfolio_reasons = []
    if any(item["verdict"] != "CERTIFIED" for item in candidate_results):
        portfolio_reasons.append("ONE_OR_MORE_CANDIDATES_ABSTAIN")
    if close_only_breach:
        portfolio_reasons.append("CLOSE_ONLY_WORST_DAY_EXCEEDS_SP_C3_CAP")
    portfolio_reasons.extend([
        "NO_SYNCHRONIZED_INTERVAL_MIN_EQUITY",
        "NO_PENDING_ORDER_CENSUS",
        "LAYER_B_NUMERIC_FLAG_THRESHOLDS_NOT_OWNER_RATIFIED",
    ])
    return {
        "schema": OUTPUT_SCHEMA, "status": "ABSTAIN", "currency": currency,
        "authority": {
            "v2_max_abs_correlation_exclusive": OWNER_V2_MAX_ABS_CORRELATION,
            "v2_account_weight_budget": OWNER_V2_ACCOUNT_WEIGHT_BUDGET,
            "v4_method": "OWNER_RATIFIED_OPTION_C",
            "layer_b_numeric_thresholds": "WORKING_DEFAULT_OPEN_OWNER_ITEM_NOT_DECISIVE",
            "sp_c3_policy_status": policy.get("status"),
        },
        "inputs": {
            "v2_owner_receipt": receipt_binding, "v4_standard": standard_binding,
            "tail_policy": policy_binding, "interval_export": interval_binding,
        },
        "bootstrap": {
            "method": "STATIONARY_BLOCK_BOOTSTRAP_POLITIS_WHITE_STYLE_AUTO_BLOCK",
            "replicates": replicates, "seed": seed, "alpha": alpha,
        },
        "weights": {"sum": weight_sum, "per_sleeve": {s.sleeve_id: s.weight for s in sleeves}},
        "ring": {"first": ring_first.isoformat(), "last": ring_last.isoformat(), "calendar_days": len(ring_days)},
        "candidates": candidate_results, "pairs": pairs,
        "tail": {
            "basis": "WEIGHTED_CLOSE_DAY_NET_ONLY_NOT_OPEN_EQUITY",
            "daily_observations": len(joint_daily), "weekly_observations": len(joint_weekly),
            "worst_day": worst_day.isoformat(), "worst_day_net": round(worst_day_value, 2),
            "worst_week_start": worst_week.isoformat(), "worst_week_net": round(worst_week_value, 2),
            "sp_c3_close_only_daily_loss_cap": round(close_only_daily_cap, 2),
            "close_only_daily_cap_breached": close_only_breach,
            "ftmo_total_loss_limit_reference": round(total_limit, 2),
            "cluster_rule": {
                "per_sleeve_worst_fraction": worst_fraction,
                "joint_sleeve_divisor": divisor,
                "required_cluster_sleeves": required_cluster_sleeves,
                "clustered_days": clustered,
            },
            "certification": "ABSTAIN_MISSING_OPEN_EQUITY_AND_INTERVAL_MINIMA",
        },
        "portfolio": {"verdict": "ABSTAIN", "reasons": portfolio_reasons},
    }


def _write_atomic(path: Path, value: Any) -> str:
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")
    handle, temporary = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=target.parent)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return hashlib.sha256(payload).hexdigest()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        spec_path, spec_binding = _binding(str(args.spec), "spec")
        result = evaluate(_load_json(spec_path, "spec"))
        result["inputs"]["spec"] = spec_binding
        digest = _write_atomic(args.output, result)
        print(json.dumps({"status": result["status"], "path": str(args.output.resolve()), "sha256": digest}))
        return 0
    except CertificationError as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
