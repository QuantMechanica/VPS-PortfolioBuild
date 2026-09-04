from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import itertools
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any

try:
    import numpy as np
except ModuleNotFoundError:  # pragma: no cover - depends on local Python env
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


# ---------------------------------------------------------------------------
# Sparse-D1 two-layer orthogonality standard (Q15 supplement).
#
# Adopted standard: docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md
# (OWNER receipt decisions/2026-09-04_owner_receipts_briefing_2_4.md, decision
# OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904).  It supplements -- never replaces -- the
# Q15 |r| < 0.5 hard rule and the family/tail concentration caps.
#
# Layer A (ZK-SBB, primary certifier): zeros-kept daily-return Pearson on the
#   exogenous Mon-Fri business-day grid over the COMMON-SUPPORT intersection
#   window, with a stationary block-bootstrap 95% CI (Politis & Romano 1994; block
#   length auto-selected per Politis & White 2004 / Patton-Politis-White 2009).
#   CERTIFY_A iff the whole CI lies inside |r| < 0.50; else ABSTAIN (never a
#   fabricated number).  A |r|_upper inside the caution band of 0.50 is PROVISIONAL
#   (treated as not-certified) rather than CERTIFY_A.
# Layer B (COS, supplementary flag): trade-level open-position co-occupancy with
#   the exact circular-shift null (all T rotations via FFT) and Benjamini-Hochberg
#   1995 FDR, plus the notional-weighted signed concordance Psi as a FLAG only.
#
# The Q15 hard rule (|r| < 0.50) is the SINGLE external gate constant.  Every other
# numeric knob is a WORKING_DEFAULT_OPEN_OWNER_ITEM: a proposed default (source
# cited) that stays open until OWNER ratifies it on the first SHA-frozen
# Q14-terminal cohort (standard sec 4, sec 8; thresholds are ROT).
# ---------------------------------------------------------------------------

# Q15 hard rule, |r| < 0.50 -- the only external gate constant, NOT a working
# default.  Mirrors build_book_ftmo.py:70 WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION
# and Vault Q15 (standard sec 2.1).
Q15_HARD_RULE_MAX_ABS_R = 0.50

# WORKING_DEFAULT_OPEN_OWNER_ITEM constants (standard sec 4 table + sec 8 ledger).
# None is a gate threshold; each is a proposed default with its cited basis, open
# until ratified on the first SHA-frozen Q14-terminal cohort.
WORKING_DEFAULT_OPEN_OWNER_ITEM_ALPHA = 0.05
"""Layer-B FDR level.  Basis: Benjamini & Hochberg 1995 (standard sec 4)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_LAMBDA_STAR = 1.5
"""Layer-B co-activity lift floor (>=50% excess time-in-market).  Basis:
proposal-supplied (standard sec 4)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND = 0.05
"""Layer-A caution band: |r|_upper within this of 0.50 -> PROVISIONAL (re-measure).
Basis: proposal-supplied (standard sec 4)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_EXPECTED_OVERLAP = 5.0
"""Layer-B testability floor on E_ab (expected co-occupied days).  Basis:
proposal-measured power boundary (standard sec 4, sec 5, sec 6)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_OCCUPANCY_DAYS = 30
"""Layer-B testability floor on n_a, n_b (occupancy days).  Basis:
proposal-measured power boundary (standard sec 4, sec 6)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_SIGNED_MIN_CODAYS = 20
"""Signed Psi report floor: same-instrument co-occupied days O_ab.  Basis:
proposal-supplied (standard sec 2.2, sec 4, sec 6)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_B = 4000
"""Stationary-block-bootstrap replicate count.  Basis: proposal-supplied
(Politis & Romano 1994; standard sec 4)."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_SEED = 20260903
"""Reported bootstrap RNG seed (a reported constant, not a gate criterion;
standard sec 2.1).  Draws are seeded per pair so a pair's CI is independent of
pool ordering."""
WORKING_DEFAULT_OPEN_OWNER_ITEM_SATURATION_FRAC = 0.50
"""Layer-B saturation guard: a sleeve occupying >= this fraction of the ring makes
E_ab -> n_a and Lambda -> 1 mechanically -> UNTESTABLE_SATURATION, route to Layer A.
Basis: proposal-supplied (standard sec 2.2, sec 5 refutation #3)."""


def build_artifact(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    min_overlap_days: int = 60,
    include_sparse: bool = False,
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

    artifact = {
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
    if include_sparse:
        # Additive two-layer sparse-D1 orthogonality screen (standard sec 3 note:
        # Layer A IS the current tool's estimand done correctly, Layer B an additive
        # diagnostic).  Never overrides the scalar `correlation` matrix above.
        artifact["sparse_orthogonality"] = evaluate_sparse_orthogonality(
            streams, min_overlap_days=min_overlap_days
        )
    return artifact


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
    parser.add_argument(
        "--sparse",
        action="store_true",
        help="Also emit the two-layer sparse-D1 orthogonality screen (Layer A ZK-SBB "
        "+ Layer B COS) under the additive 'sparse_orthogonality' key.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    artifact = build_artifact(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        min_overlap_days=args.min_overlap_days,
        include_sparse=args.sparse,
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


# ===========================================================================
# Layer A -- ZK-SBB (zeros-kept daily-return Pearson + stationary block bootstrap)
# ===========================================================================


def _require_numpy() -> None:
    if np is None:  # pragma: no cover - numpy is present in the portfolio runtime
        raise RuntimeError(
            "the sparse-D1 orthogonality standard requires numpy "
            "(stationary block bootstrap + FFT circular-shift null)"
        )


def _business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    """Exogenous Mon-Fri business-day grid over [start, end] inclusive."""
    days: list[dt.date] = []
    day = start
    one = dt.timedelta(days=1)
    while day <= end:
        if day.weekday() < 5:
            days.append(day)
        day += one
    return days


def pair_daily_vectors(
    daily_a: dict[dt.date, float],
    daily_b: dict[dt.date, float],
) -> dict[str, Any] | None:
    """Zeros-kept daily returns on the common-support Mon-Fri grid.

    Window is the INTERSECTION [max(first_a, first_b) .. min(last_a, last_b)] of
    each stream's own [first, last] -- not the union.  Non-trade days are real
    zeros (kept).  Any actual trade day that falls on a weekend inside the window
    is folded in so no realized P&L is dropped.  Returns ``None`` when the streams
    have no common-support window.  (Standard sec 2.1; reference estimator
    docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_estimator.py.)
    """
    _require_numpy()
    if not daily_a or not daily_b:
        return None
    start = max(min(daily_a), min(daily_b))
    end = min(max(daily_a), max(daily_b))
    if start > end:
        return None
    grid = set(_business_days(start, end))
    extra = {
        day
        for day in set(daily_a) | set(daily_b)
        if start <= day <= end and day.weekday() >= 5
    }
    days = sorted(grid | extra)
    x = np.array([daily_a.get(day, 0.0) for day in days], dtype=float)
    y = np.array([daily_b.get(day, 0.0) for day in days], dtype=float)
    coactive = int(np.sum((x != 0.0) & (y != 0.0)))
    return {
        "days": days,
        "x": x,
        "y": y,
        "n": len(days),
        "start": start,
        "end": end,
        "coactive": coactive,
        "active_a": int(np.sum(x != 0.0)),
        "active_b": int(np.sum(y != 0.0)),
        "weekend_folded": len(extra),
    }


def _np_pearson(x: Any, y: Any) -> float:
    xd = x - x.mean()
    yd = y - y.mean()
    nx = math.sqrt(float((xd * xd).sum()))
    ny = math.sqrt(float((yd * yd).sum()))
    if nx == 0.0 or ny == 0.0:
        return float("nan")
    return float((xd * yd).sum() / (nx * ny))


def _flat_top_kernel(t: Any) -> Any:
    a = np.abs(t)
    out = np.zeros_like(a)
    out[a <= 0.5] = 1.0
    mid = (a > 0.5) & (a <= 1.0)
    out[mid] = 2.0 * (1.0 - a[mid])
    return out


def _autocov(z: Any, kmax: int) -> Any:
    z = z - z.mean()
    n = len(z)
    r = np.empty(kmax + 1)
    for k in range(kmax + 1):
        r[k] = np.dot(z[: n - k], z[k:]) / n
    return r


def opt_block_length_sb(z: Any) -> float:
    """Politis & White 2004 optimal stationary-bootstrap mean block length.

    Flat-top-kernel bandwidth with the Patton-Politis-White 2009 stationary-
    bootstrap variance constant.  (Standard sec 2.1; reference estimator.)
    """
    _require_numpy()
    z = np.asarray(z, dtype=float)
    n = len(z)
    if n < 8 or np.allclose(z, z[0]):
        return 1.0
    kmax = min(n - 1, int(np.ceil(10 * np.log10(n))) + 20)
    R = _autocov(z, kmax)
    if R[0] <= 0:
        return 1.0
    rho = R / R[0]
    c = 2.0
    thresh = c * np.sqrt(np.log10(n) / n)
    KN = max(5, int(np.ceil(np.sqrt(np.log10(n)))))
    mhat = 0
    for k in range(1, kmax - KN + 1):
        if np.all(np.abs(rho[k : k + KN]) < thresh):
            mhat = k - 1
            break
    else:
        mhat = kmax
    M = min(max(2 * mhat, 2), kmax)
    ks = np.arange(-M, M + 1)
    Rk = np.array([R[abs(k)] for k in ks])
    lam = _flat_top_kernel(ks / M)
    g = np.sum(lam * np.abs(ks) * Rk)
    Dsb = 2.0 * (np.sum(lam * Rk) ** 2)
    if Dsb <= 0 or g == 0:
        return 1.0
    b = ((2.0 * g * g) / Dsb) ** (1.0 / 3.0) * (n ** (1.0 / 3.0))
    return float(np.clip(b, 1.0, max(1.0, n / 3.0)))


def _stationary_indices(n: int, b: float, B: int, rng: Any) -> Any:
    """Vectorized stationary-bootstrap index matrix (B, n), mean block length b."""
    p = 1.0 / max(b, 1.0)
    starts = rng.integers(0, n, size=(B, n))
    restart = rng.random((B, n)) < p
    restart[:, 0] = True
    idx = np.empty((B, n), dtype=np.int64)
    idx[:, 0] = starts[:, 0]
    for t in range(1, n):
        prev_plus = (idx[:, t - 1] + 1) % n
        idx[:, t] = np.where(restart[:, t], starts[:, t], prev_plus)
    return idx


def bootstrap_corr_ci(x: Any, y: Any, b: float, rng: Any, B: int) -> dict[str, Any] | None:
    """Stationary block-bootstrap 95% CI of the Pearson correlation of (x, y).

    Resamples the PAIRED vector in geometric-length blocks (Politis & Romano
    1994), recomputes r on each replicate, returns the 2.5/97.5 percentiles and
    ``abs_upper = max(|lo|, |hi|)``.  ``None`` when too few replicates are valid.
    """
    _require_numpy()
    n = len(x)
    if n < 2:
        return None
    idx = _stationary_indices(n, b, B, rng)
    X = x[idx]
    Y = y[idx]
    Xd = X - X.mean(axis=1, keepdims=True)
    Yd = Y - Y.mean(axis=1, keepdims=True)
    nx = np.sqrt((Xd * Xd).sum(axis=1))
    ny = np.sqrt((Yd * Yd).sum(axis=1))
    good = (nx > 0) & (ny > 0)
    r = np.full(B, np.nan)
    r[good] = (Xd * Yd).sum(axis=1)[good] / (nx[good] * ny[good])
    r = r[np.isfinite(r)]
    if r.size < 50:
        return None
    lo, hi = np.percentile(r, [2.5, 97.5])
    return {
        "mean": float(r.mean()),
        "sd": float(r.std(ddof=1)),
        "lo": float(lo),
        "hi": float(hi),
        "abs_upper": float(max(abs(lo), abs(hi))),
        "n_valid": int(r.size),
    }


def circular_rotation_null(x: Any, y: Any, rng: Any, reps: int) -> dict[str, Any] | None:
    """Layer-A negative control: rotate y circularly by a random offset, destroying
    cross-dependence while preserving each series' marginal + autocorrelation +
    sparsity.  Reports the 97.5th percentile of |r| and the fraction reaching the
    Q15 rule -- the honest false-positive rate (standard sec 5 #5)."""
    _require_numpy()
    n = len(x)
    xd = x - x.mean()
    nx = math.sqrt(float((xd * xd).sum()))
    if nx == 0 or n < 2:
        return None
    offs = rng.integers(1, n, size=reps)
    rs = np.empty(reps)
    for i, k in enumerate(offs):
        yr = np.roll(y, int(k))
        yd = yr - yr.mean()
        ny = math.sqrt(float((yd * yd).sum()))
        rs[i] = float((xd * yd).sum() / (nx * ny)) if ny > 0 else 0.0
    return {
        "mean": float(rs.mean()),
        "sd": float(rs.std(ddof=1)),
        "p975_abs": float(np.percentile(np.abs(rs), 97.5)),
        "frac_ge_rule": float(np.mean(np.abs(rs) >= Q15_HARD_RULE_MAX_ABS_R)),
    }


def _pair_seed(base_seed: int, label_a: str, label_b: str) -> list[int]:
    """Deterministic per-pair RNG seed (order-independent): the CI of a pair does
    not depend on the pool ordering or which other pairs were evaluated."""
    tag = "|".join(sorted((label_a, label_b)))
    digest = hashlib.sha256(tag.encode("ascii", "replace")).digest()
    return [int(base_seed), int.from_bytes(digest[:8], "little")]


def _layer_a_verdict(
    ci: dict[str, Any] | None,
    *,
    caution_band: float,
    max_abs_r: float,
) -> tuple[str, str | None]:
    """CERTIFY_A / PROVISIONAL / ABSTAIN from the bootstrap CI (fail-closed)."""
    if ci is None:
        return "ABSTAIN", "bootstrap CI unavailable (degenerate or too few valid replicates)"
    abs_upper = ci["abs_upper"]
    if abs_upper >= max_abs_r:
        return "ABSTAIN", f"|r|_upper {abs_upper:.4f} reaches the |r| < {max_abs_r} rule"
    if abs_upper >= (max_abs_r - caution_band):
        return "PROVISIONAL", (
            f"|r|_upper {abs_upper:.4f} inside the {caution_band} caution band of "
            f"{max_abs_r}; re-measure on more Q14-terminal overlap"
        )
    return "CERTIFY_A", None


# ===========================================================================
# Layer B -- COS (trade-level open-position co-occupancy + circular-shift null)
# ===========================================================================


def occupancy_days(trades: list[Trade]) -> set[dt.date]:
    """Union over trades of every UTC calendar day from entry_day..exit_day
    inclusive.  Trades without an entry_time contribute only their exit day
    (never guessed).  (Standard sec 2.2.)"""
    days: set[dt.date] = set()
    for trade in trades:
        exit_day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
        if trade.entry_time is None:
            days.add(exit_day)
            continue
        entry_day = dt.datetime.fromtimestamp(trade.entry_time, tz=dt.UTC).date()
        d0, d1 = (entry_day, exit_day) if entry_day <= exit_day else (exit_day, entry_day)
        cur = d0
        one = dt.timedelta(days=1)
        while cur <= d1:
            days.add(cur)
            cur += one
    return days


def signed_daily_dir(trades: list[Trade]) -> dict[dt.date, int]:
    """Net notional-weighted direction per occupied day (BUY=+1, SELL=-1); trades
    without a BUY/SELL side contribute 0.  (Standard sec 2.2; reference probe.)"""
    acc: dict[dt.date, float] = defaultdict(float)
    one = dt.timedelta(days=1)
    for trade in trades:
        if trade.side not in ("BUY", "SELL") or trade.entry_time is None:
            continue
        weight = float(trade.notional) if trade.notional is not None else 1.0
        sign = 1.0 if trade.side == "BUY" else -1.0
        entry_day = dt.datetime.fromtimestamp(trade.entry_time, tz=dt.UTC).date()
        exit_day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
        d0, d1 = (entry_day, exit_day) if entry_day <= exit_day else (exit_day, entry_day)
        cur = d0
        while cur <= d1:
            acc[cur] += sign * weight
            cur += one
    return {day: (1 if value > 0 else (-1 if value < 0 else 0)) for day, value in acc.items()}


def _ring(all_days: set[dt.date]) -> list[dt.date]:
    lo, hi = min(all_days), max(all_days)
    out: list[dt.date] = []
    cur = lo
    one = dt.timedelta(days=1)
    while cur <= hi:
        out.append(cur)
        cur += one
    return out


def _occ_vector(day_set: set[dt.date], index: dict[dt.date, int], length: int) -> Any:
    v = np.zeros(length, dtype=np.float64)
    for day in day_set:
        v[index[day]] = 1.0
    return v


def circular_shift_null_counts(oa: Any, ob: Any) -> Any:
    """All T circular-shift co-occupancy counts O(delta) = sum_i oa[i]*ob[(i-delta)
    mod T], computed exactly by FFT circular cross-correlation (no Monte-Carlo
    error).  (Standard sec 2.2.)"""
    _require_numpy()
    T = len(oa)
    fa = np.fft.rfft(oa)
    fb = np.fft.rfft(ob)
    cc = np.fft.irfft(fa * np.conj(fb), n=T)
    return np.rint(cc).astype(np.int64)


def _bh_reject(pvalues: list[float], alpha: float) -> tuple[list[bool], list[float]]:
    """Benjamini-Hochberg 1995 step-up: reject set and adjusted p-values (q)."""
    m = len(pvalues)
    if m == 0:
        return [], []
    order = sorted(range(m), key=lambda k: pvalues[k])
    crit = 0
    for rank, k in enumerate(order, start=1):
        if pvalues[k] <= alpha * rank / m:
            crit = rank
    reject_set = set(order[:crit])
    reject = [k in reject_set for k in range(m)]
    # adjusted p-values (monotone from the largest rank down)
    adj = [1.0] * m
    running = 1.0
    for rank in range(m, 0, -1):
        k = order[rank - 1]
        running = min(running, pvalues[k] * m / rank)
        adj[k] = min(1.0, running)
    return reject, adj


# ===========================================================================
# Combined two-layer screen
# ===========================================================================


def evaluate_sparse_orthogonality(
    streams: dict[tuple[int, str], list[Trade]],
    *,
    min_overlap_days: int = 60,
    alpha: float = WORKING_DEFAULT_OPEN_OWNER_ITEM_ALPHA,
    lambda_star: float = WORKING_DEFAULT_OPEN_OWNER_ITEM_LAMBDA_STAR,
    caution_band: float = WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND,
    cos_min_expected_overlap: float = WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_EXPECTED_OVERLAP,
    cos_min_occupancy_days: int = WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_OCCUPANCY_DAYS,
    signed_min_codays: int = WORKING_DEFAULT_OPEN_OWNER_ITEM_SIGNED_MIN_CODAYS,
    bootstrap_B: int = WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_B,
    seed: int = WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_SEED,
    saturation_frac: float = WORKING_DEFAULT_OPEN_OWNER_ITEM_SATURATION_FRAC,
    max_abs_r: float = Q15_HARD_RULE_MAX_ABS_R,
) -> dict[str, Any]:
    """Two-layer sparse-D1 orthogonality screen over a pool of q08 Trade streams.

    Returns per-pair records exposing r, CI, combined status
    (CERTIFIED / ABSTAIN / FLAGGED), overlap days, block length, and the COS
    statistics (standard sec 2, sec 3).  Read-only: computes no book, weight,
    verdict, or state.
    """
    _require_numpy()
    keys = sorted(streams)
    daily_by_key = {key: to_daily_pnl(streams[key]) for key in keys}
    occ_by_key = {key: occupancy_days(streams[key]) for key in keys}
    signed_by_key = {key: signed_daily_dir(streams[key]) for key in keys}
    symbol_by_key = {key: str(key[1]).upper() for key in keys}

    # Layer B common calendar-day ring across the whole pool (standard sec 2.2).
    all_occ: set[dt.date] = set()
    for occ in occ_by_key.values():
        all_occ |= occ
    if all_occ:
        ring = _ring(all_occ)
    else:
        ring = []
    T = len(ring)
    ring_index = {day: i for i, day in enumerate(ring)}
    occ_vec = {key: _occ_vector(occ_by_key[key], ring_index, T) for key in keys} if T else {}

    pair_keys = list(itertools.combinations(keys, 2))
    records: list[dict[str, Any]] = []
    p_upper_list: list[float] = []

    for key_a, key_b in pair_keys:
        label_a, label_b = key_label(key_a), key_label(key_b)
        record: dict[str, Any] = {
            "pair": [label_a, label_b],
            "same_symbol": symbol_by_key[key_a] == symbol_by_key[key_b],
        }

        # ---- Layer A: zeros-kept common-support daily-return Pearson + CI ----
        pv = pair_daily_vectors(daily_by_key[key_a], daily_by_key[key_b])
        if pv is None:
            layer_a = {
                "r_hat": None,
                "ci_lo": None,
                "ci_hi": None,
                "abs_upper": None,
                "block_len": None,
                "block_len_x": None,
                "block_len_y": None,
                "block_len_xy": None,
                "bootstrap_B": bootstrap_B,
                "seed": seed,
                "n_valid": 0,
                "n_business_days": 0,
                "verdict": "ABSTAIN",
                "reason": "no common-support window (streams do not overlap in time)",
            }
            record["overlap_days"] = 0
            record["n_business_days"] = 0
            record["window"] = [None, None]
            record["active_days"] = [None, None]
        else:
            x, y = pv["x"], pv["y"]
            r_hat = _np_pearson(x, y)
            block_x = opt_block_length_sb(x)
            block_y = opt_block_length_sb(y)
            block_xy = opt_block_length_sb(x * y)
            block = max(block_x, block_y, block_xy)
            rng = np.random.default_rng(_pair_seed(seed, label_a, label_b))
            ci = bootstrap_corr_ci(x, y, block, rng, bootstrap_B)
            verdict, reason = _layer_a_verdict(
                ci, caution_band=caution_band, max_abs_r=max_abs_r
            )
            layer_a = {
                "r_hat": None if math.isnan(r_hat) else round(r_hat, 6),
                "ci_lo": round(ci["lo"], 6) if ci else None,
                "ci_hi": round(ci["hi"], 6) if ci else None,
                "abs_upper": round(ci["abs_upper"], 6) if ci else None,
                "block_len": round(block, 4),
                "block_len_x": round(block_x, 4),
                "block_len_y": round(block_y, 4),
                "block_len_xy": round(block_xy, 4),
                "bootstrap_B": bootstrap_B,
                "seed": seed,
                "n_valid": ci["n_valid"] if ci else 0,
                "n_business_days": pv["n"],
                "verdict": verdict,
                "reason": reason,
            }
            record["overlap_days"] = pv["coactive"]
            record["n_business_days"] = pv["n"]
            record["window"] = [pv["start"].isoformat(), pv["end"].isoformat()]
            record["active_days"] = [pv["active_a"], pv["active_b"]]
        record["layer_a"] = layer_a

        # ---- Layer B: co-occupancy lift + exact circular-shift null ----
        if T:
            oa, ob = occ_vec[key_a], occ_vec[key_b]
            n_a, n_b = int(oa.sum()), int(ob.sum())
            O_obs = int(np.dot(oa, ob))
            E = (n_a * n_b / T) if T else 0.0
            lam = (O_obs / E) if E > 0 else None
            null = circular_shift_null_counts(oa, ob)
            p_upper = float(np.mean(null >= O_obs))  # includes delta=0 => >= 1/T
            occ_frac_max = max(n_a, n_b) / T if T else 0.0
            saturated = occ_frac_max >= saturation_frac
            testable = (
                (E >= cos_min_expected_overlap)
                and (n_a >= cos_min_occupancy_days)
                and (n_b >= cos_min_occupancy_days)
                and not saturated
            )
            # signed concordance Psi (same-instrument only; O_ab >= floor)
            psi: float | None = None
            psi_n = 0
            if record["same_symbol"] and O_obs >= signed_min_codays:
                sa = signed_by_key[key_a]
                sb = signed_by_key[key_b]
                shared = [
                    day
                    for day in (occ_by_key[key_a] & occ_by_key[key_b])
                    if sa.get(day, 0) != 0 and sb.get(day, 0) != 0
                ]
                psi_n = len(shared)
                if psi_n > 0:
                    agree = sum(1 for day in shared if sa[day] == sb[day])
                    psi = (agree - (psi_n - agree)) / psi_n
            layer_b = {
                "n_a": n_a,
                "n_b": n_b,
                "ring_T": T,
                "co_occupied_days_O": O_obs,
                "expected_overlap_E": round(E, 4),
                "lambda": None if lam is None else round(lam, 4),
                "p_upper": round(p_upper, 6),
                "occupancy_frac_max": round(occ_frac_max, 4),
                "testable": bool(testable),
                "saturated": bool(saturated),
                "psi": None if psi is None else round(psi, 4),
                "psi_n": psi_n,
            }
            p_upper_list.append(p_upper)
        else:
            layer_b = {
                "n_a": 0,
                "n_b": 0,
                "ring_T": 0,
                "co_occupied_days_O": 0,
                "expected_overlap_E": 0.0,
                "lambda": None,
                "p_upper": 1.0,
                "occupancy_frac_max": 0.0,
                "testable": False,
                "saturated": False,
                "psi": None,
                "psi_n": 0,
            }
            p_upper_list.append(1.0)
        record["layer_b"] = layer_b
        records.append(record)

    # ---- Benjamini-Hochberg FDR across all pairs' p_upper (standard sec 2.2) ----
    bh_reject, bh_adj = _bh_reject(p_upper_list, alpha)
    for record, reject, adj in zip(records, bh_reject, bh_adj):
        lb = record["layer_b"]
        lb["bh_reject"] = bool(reject)
        lb["p_upper_bh"] = round(adj, 6)
        # Layer-B flag + status
        if lb["saturated"]:
            lb["status"] = "UNTESTABLE_SATURATION"
            lb["flag"] = False
        elif not lb["testable"]:
            lb["status"] = "UNTESTABLE"
            lb["flag"] = False
        else:
            signed_ok = (lb["psi"] is None) or (lb["psi"] > 0)
            flag = (
                bool(reject)
                and (lb["lambda"] is not None and lb["lambda"] > lambda_star)
                and signed_ok
            )
            lb["flag"] = flag
            lb["status"] = "FLAG_B" if flag else "NOT_FLAGGED"

        # ---- Combined fail-closed verdict (standard sec 2.3) ----
        la_verdict = record["layer_a"]["verdict"]
        sparse = record["overlap_days"] < min_overlap_days
        if la_verdict == "CERTIFY_A":
            if lb["flag"] and sparse:
                record["status"] = "FLAGGED"
                record["verdict_detail"] = "REVIEW"
            else:
                record["status"] = "CERTIFIED"
                record["verdict_detail"] = "CERTIFY_ORTHOGONAL"
        elif la_verdict == "PROVISIONAL":
            record["status"] = "ABSTAIN"
            record["verdict_detail"] = "ABSTAIN_CAUTION_BAND"
        else:  # ABSTAIN
            record["status"] = "ABSTAIN"
            record["verdict_detail"] = "ABSTAIN"

    counts = {"CERTIFIED": 0, "ABSTAIN": 0, "FLAGGED": 0}
    for record in records:
        counts[record["status"]] += 1

    return {
        "standard": "SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03",
        "standard_doc": "docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md",
        "authority": "OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904 "
        "(decisions/2026-09-04_owner_receipts_briefing_2_4.md)",
        "read_only": True,
        "q15_hard_rule_max_abs_r": max_abs_r,
        "working_defaults_open_owner_item": {
            "alpha": alpha,
            "lambda_star": lambda_star,
            "caution_band": caution_band,
            "cos_min_expected_overlap": cos_min_expected_overlap,
            "cos_min_occupancy_days": cos_min_occupancy_days,
            "signed_min_codays": signed_min_codays,
            "bootstrap_B": bootstrap_B,
            "bootstrap_seed": seed,
            "saturation_frac": saturation_frac,
        },
        "min_overlap_days": min_overlap_days,
        "ring_T_days": T,
        "ring_window": [ring[0].isoformat(), ring[-1].isoformat()] if ring else [None, None],
        "keys": [key_label(k) for k in keys],
        "n_pairs": len(records),
        "status_counts": counts,
        "pairs": records,
    }


if __name__ == "__main__":
    raise SystemExit(main())
