from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
from pathlib import Path
from typing import Any, Sequence

try:
    from .commission import describe_model, load_model
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
        to_monthly_pnl,
        align,
    )
    from .portfolio_correlation import COMMISSION_BASIS, correlation_matrix, _pearson
    from .portfolio_kpi import equal_weights, inverse_vol_weights, portfolio_metrics
    from .portfolio_manifest import DEFAULT_STARTING_CAPITAL
except ImportError:  # pragma: no cover - direct script execution
    from commission import describe_model, load_model  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
        to_monthly_pnl,
        align,
    )
    from portfolio_correlation import COMMISSION_BASIS, correlation_matrix, _pearson  # type: ignore
    from portfolio_kpi import equal_weights, inverse_vol_weights, portfolio_metrics  # type: ignore
    from portfolio_manifest import DEFAULT_STARTING_CAPITAL  # type: ignore


Key = tuple[int, str]

# --------------------------------------------------------------------------- #
# C1 (2026-07-26) — Q09 hard-gate correlation criterion.
# Ratified in decisions/2026-07-26_q09_hard_gate_dl083_port.md ("The rule"), which
# ports the DL-083 thresholds (decisions/2026-07-20_DL-083_marginal_eval_threshold_
# calibration.md) into this hard admission gate on a STRICTER-OF-TWO correlation basis.
#
# LEGACY, RETIRED 2026-07-26 (provenance, NOT silently deleted): the gate used to admit
# iff the candidate's full-sample Pearson to the book was <= 0.30 (`corr_ok`). That single
# threshold is replaced by the zoned rule in classify_admission() below. DEFAULT_MAX_CORR
# is retained only because --max-corr is part of the public CLI/output schema and is still
# echoed into the artifact for continuity; it NO LONGER gates admission.
DEFAULT_MAX_CORR = 0.30

# DL-083 thresholds (evidence bundle: threshold_calibration_20260720). corr_eff is the
# stricter (max) of the full-sample and high-vol-regime candidate-vs-book correlations:
#   corr_eff >= CORR_REJECT_MIN                         -> REJECT (redundant / crisis-correlated)
#   corr_eff <  CORR_ADMIT_MAX  + positive marginal     -> ADMIT  (strong diversifier zone)
#   otherwise (gray zone)  ->  delta-Sharpe >= SHARPE_DELTA_ADMIT decides ADMIT/REJECT
# "Positive marginal contribution" is the module's existing DL-079 `diversifies` signal
# (improves book Sharpe, OR improves book MaxDD without degrading Sharpe) — the book-level
# risk-adjusted "does it help" test. The DL-083 numbers were calibrated on candidate-vs-
# rest-book correlation; see _regime_correlation for the regime basis this gate applies them on.
CORR_REJECT_MIN = 0.40
CORR_ADMIT_MAX = 0.15
SHARPE_DELTA_ADMIT = 0.020

# High-volatility regime definition (bound to the C1 decision record — material changes here
# need a new dated decision). The regime is the set of top-quartile days by the BOOK
# COMPOSITE's rolling realized volatility:
#  - REGIME_VOL_WINDOW = 20 trading days: the canonical short-horizon realized-vol lookback
#    (~one calendar month). Long enough that a single outlier day does not define the regime,
#    short enough to resolve a genuine volatility regime rather than smear it across the sample.
#  - REGIME_TOP_QUANTILE = 0.75: "top-quartile" per the decision (days at/above the 75th
#    percentile of the rolling-vol series).
#  - MIN_REGIME_DAYS = 20: minimum number of measurable regime days for a trustworthy
#    regime-conditional Pearson. 20 matches the module's own small-sample floor
#    (_standalone_sharpe requires >= 20 daily points); below it the regime-conditional
#    correlation is too noisy to bind, so the regime basis is recorded UNKNOWN and the
#    full-sample correlation binds alone (verdict reason carries `regime_unknown`).
REGIME_VOL_WINDOW = 20
REGIME_TOP_QUANTILE = 0.75
MIN_REGIME_DAYS = 20

DEFAULT_MIN_OVERLAP_DAYS = 60
DEFAULT_ADMISSION_COMMON_DIR = Path(r"D:\QM\reports\portfolio\sleeve_streams")
DEFAULT_EXIT_SURGERY_BUILD_EVIDENCE = Path(
    r"D:\QM\strategy_farm\artifacts\ops\exit_surgery_v2_build_fab16f34_2026-07-03.json"
)
DEFAULT_LINEAGE_ARTIFACTS = (DEFAULT_EXIT_SURGERY_BUILD_EVIDENCE,)
# Low-frequency fallback: structural edges trade a few times a year, so two sleeves
# almost never share >=60 active days. When daily overlap is insufficient, retry the
# diversification test on calendar-month buckets, correlating over the window where both
# sleeves were live (0-filled) — the textbook returns-correlation basis. NB: do NOT gate on
# *co-active* months: genuine cross-asset diversifiers trade in different months by nature,
# so a co-active guard perversely certifies redundant same-instrument pairs (many shared
# months) while rejecting the diversifying ones. Gate on shared live-span instead.
DEFAULT_MIN_SHARED_SPAN_MONTHS = 24
DEFAULT_MIN_ACTIVE_MONTHS = 6


def corr_eff_value(
    corr_full: float | None,
    corr_regime: float | None,
    regime_known: bool,
) -> float | None:
    """Stricter-of-two effective correlation = max(full-sample, known high-vol regime).

    Returns None when neither basis is measurable. When the regime basis is UNKNOWN the
    full-sample correlation binds alone (decisions/2026-07-26_q09_hard_gate_dl083_port.md).
    """
    measured = [corr_full]
    if regime_known:
        measured.append(corr_regime)
    values = [float(v) for v in measured if v is not None]
    return max(values) if values else None


def classify_admission(
    corr_full: float | None,
    corr_regime: float | None,
    regime_known: bool,
    delta_sharpe: float | None,
    marginal_positive: bool,
    *,
    corr_admit_max: float = CORR_ADMIT_MAX,
    corr_reject_min: float = CORR_REJECT_MIN,
    sharpe_delta_admit: float = SHARPE_DELTA_ADMIT,
) -> tuple[bool, str, str, float | None]:
    """The C1 / DL-083 hard-gate correlation criterion (pure, side-effect free).

    Returns ``(admit, reason_base, binding_basis, corr_eff)`` where ``reason_base`` is one of
    the module's existing verdict tokens (``admitted`` / ``no_diversification`` /
    ``correlation_above_max_corr`` / ``insufficient_overlap``) and ``binding_basis`` names the
    basis that produced ``corr_eff`` — ``corr_full`` / ``corr_regime`` / ``regime_unknown``
    (per the decision record; ``regime_unknown`` is reported whenever the regime basis could
    not be measured, even though the full-sample number is what bound).

    Zones (corr_eff = stricter-of-two, DL-083 numbers):
      * corr_eff >= corr_reject_min (0.40)                        -> REJECT (correlation_above_max_corr)
      * corr_eff <  corr_admit_max (0.15) AND marginal_positive   -> ADMIT  (strong diversifier zone)
      * gray zone: delta_sharpe >= sharpe_delta_admit (0.020)     -> ADMIT, else REJECT (no_diversification)

    ``marginal_positive`` is the DL-079 ``diversifies`` signal (positive marginal contribution
    to the book's risk-adjusted performance). It only unlocks the strong zone; the gray zone is
    decided by delta-Sharpe alone, as the decision record specifies.
    """
    measured: list[tuple[str, float]] = []
    if corr_full is not None:
        measured.append(("corr_full", float(corr_full)))
    if regime_known and corr_regime is not None:
        measured.append(("corr_regime", float(corr_regime)))
    if not measured:
        return False, "insufficient_overlap", ("corr_full" if regime_known else "regime_unknown"), None

    binding_basis, corr_eff = max(measured, key=lambda item: item[1])
    if not regime_known:
        # Full-sample bound, but the regime basis is unmeasured — flag it in the reason.
        binding_basis = "regime_unknown"

    if corr_eff >= corr_reject_min:
        return False, "correlation_above_max_corr", binding_basis, corr_eff
    if corr_eff < corr_admit_max and marginal_positive:
        return True, "admitted", binding_basis, corr_eff
    if delta_sharpe is not None and delta_sharpe >= sharpe_delta_admit:
        return True, "admitted", binding_basis, corr_eff
    return False, "no_diversification", binding_basis, corr_eff


def _pstddev(values: Sequence[float]) -> float:
    k = len(values)
    if k == 0:
        return 0.0
    mean = sum(values) / k
    return math.sqrt(sum((v - mean) ** 2 for v in values) / k)


def _high_vol_regime_indices(
    composite_daily: Sequence[float],
    window: int,
    top_quantile: float,
) -> list[int]:
    """Row indices of top-quantile days by the book composite's rolling realized volatility.

    Rolling population stddev over a trailing ``window`` of composite daily PnL; the regime is
    every day whose rolling vol is at/above the ``top_quantile`` percentile of the rolling-vol
    series (and strictly positive). Days before the window fills have no rolling vol and are
    excluded. Percentile index convention matches marginal_contribution_eval's high-vol subset.
    """
    n = len(composite_daily)
    if n < window:
        return []
    rolling: list[tuple[int, float]] = []
    for t in range(window - 1, n):
        rolling.append((t, _pstddev(composite_daily[t - window + 1 : t + 1])))
    vols = sorted(v for _, v in rolling)
    if not vols:
        return []
    threshold = vols[int(top_quantile * (len(vols) - 1))]
    return [t for t, v in rolling if v >= threshold and v > 0.0]


def _regime_correlation(
    candidate: Key,
    book: Sequence[Key],
    aligned_keys: Sequence[Key],
    matrix: Any,
    book_weights: dict[Key, float],
    *,
    window: int = REGIME_VOL_WINDOW,
    top_quantile: float = REGIME_TOP_QUANTILE,
    min_regime_days: int = MIN_REGIME_DAYS,
) -> tuple[float | None, int, bool]:
    """High-volatility-regime correlation of the candidate to the book.

    The regime = top-quartile days of the BOOK COMPOSITE's rolling volatility (the composite is
    the inverse-vol-weighted book daily PnL — the book's own production weighting). Correlation
    is the max over book members of the candidate-vs-member Pearson restricted to those regime
    days (same worst-case book-pair basis as the full-sample gate, so stricter-of-two compares
    like with like). Returns ``(corr_regime, regime_days, regime_known)``; ``regime_known`` is
    False (basis UNKNOWN) when fewer than ``min_regime_days`` regime days exist or no member
    pair is measurable there.
    """
    n = len(matrix)
    if n == 0 or candidate not in aligned_keys:
        return None, 0, False
    col = {key: idx for idx, key in enumerate(aligned_keys)}
    book_cols = [(col[m], float(book_weights.get(m, 0.0))) for m in book if m in col]
    composite = [sum(float(matrix[t][c]) * w for c, w in book_cols) for t in range(n)]
    regime_idx = _high_vol_regime_indices(composite, window, top_quantile)
    if len(regime_idx) < min_regime_days:
        return None, len(regime_idx), False
    cand_col = col[candidate]
    cand_vec = [float(matrix[t][cand_col]) for t in regime_idx]
    corr_values: list[float] = []
    for m in book:
        if m not in col:
            continue
        member_vec = [float(matrix[t][col[m]]) for t in regime_idx]
        value = _pearson(cand_vec, member_vec)
        if value is not None:
            corr_values.append(float(value))
    if not corr_values:
        return None, len(regime_idx), False
    return max(corr_values), len(regime_idx), True


def current_book(candidates_db: Path = DEFAULT_CANDIDATES_DB) -> list[Key]:
    """Return admitted portfolio candidates; an empty result means first-sleeve discovery."""
    return read_candidates(candidates_db)


QUARANTINE_PATH = Path(r"D:\QM\reports\state\plausibility_quarantine.json")


def load_quarantine(path: Path = QUARANTINE_PATH) -> set[Key]:
    """Plausibility-scan artifact keys (ea_id:SYMBOL) to exclude from admission.
    See tools/strategy_farm/plausibility_scan.py — catches mirage streams (no real
    stop / zero loss / absurd PF) that survive Q04's net-of-cost walk-forward."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return set()
    out: set[Key] = set()
    for label in data.get("quarantine", []):
        ea, _, sym = str(label).partition(":")
        if not (ea and sym):
            continue
        try:
            out.add((int(ea), sym))
        except ValueError:
            continue
    return out


def evaluate_candidate(
    candidate_key: Key,
    book_keys: Sequence[Key],
    common_dir: Path = DEFAULT_ADMISSION_COMMON_DIR,
    *,
    max_corr: float = DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    lineage_payload: dict[str, Any] | None = None,
    lineage_artifacts: Sequence[Path] | None = None,
) -> dict[str, Any]:
    candidate = _normalize_key(candidate_key)

    # Plausibility guard: never admit a quarantined artifact (no real stop / zero loss /
    # absurd PF), even as a first sleeve. Q04's net-of-cost walk-forward lets these through
    # because the defect is consistent across folds; the portfolio is the last line.
    if candidate in load_quarantine():
        return {
            "admit": False,
            "reason": "quarantined_artifact",
            "standalone_pf": None,
            "max_corr_to_book": None,
            "corr_insufficient": False,
            "corr_basis": "n/a",
            "corr_full": None,
            "corr_regime": None,
            "corr_eff": None,
            "corr_binding_basis": "n/a",
            "regime_days": 0,
            "regime_unknown": False,
            "sharpe_with": None,
            "sharpe_without": None,
            "maxdd_with": None,
            "maxdd_without": None,
            "diversifies": False,
        }

    book = sorted({_normalize_key(key) for key in book_keys if _normalize_key(key) != candidate})

    if not book:
        standalone_pf = _load_standalone_pf(candidate, common_dir)
        return {
            "admit": True,
            "reason": "first_sleeve",
            "standalone_pf": standalone_pf,
            "max_corr_to_book": None,
            "corr_insufficient": False,
            "corr_basis": "n/a",
            "corr_full": None,
            "corr_regime": None,
            "corr_eff": None,
            "corr_binding_basis": "n/a",
            "regime_days": 0,
            "regime_unknown": False,
            "sharpe_with": None,
            "sharpe_without": None,
            "maxdd_with": None,
            "maxdd_without": None,
            "diversifies": True,
        }

    requested_keys = sorted(set(book + [candidate]))
    model = load_model()
    streams = load_streams(common_dir, candidates=requested_keys, commission_model=model)
    missing = sorted(set(requested_keys) - set(streams))
    if missing:
        raise ValueError(f"missing q08 trade streams for keys: {missing!r}")

    series_by_key = {key: to_daily_pnl(streams[key]) for key in requested_keys}
    aligned_keys, _, matrix = align(series_by_key)
    correlations, _ = correlation_matrix(aligned_keys, matrix, DEFAULT_MIN_OVERLAP_DAYS)
    # Full-sample candidate-vs-book correlation (worst-case max over measurable book pairs),
    # daily basis with the monthly fallback for sparse structural sleeves. This is the
    # `corr_full` leg of the C1 stricter-of-two rule and remains reported as max_corr_to_book.
    corr_full, corr_insufficient = _candidate_corr(
        candidate,
        book,
        aligned_keys,
        correlations,
    )
    corr_basis = "daily"
    if corr_insufficient:
        # Sparse low-frequency sleeves never overlap enough on a daily basis. Retry the
        # diversification test on calendar-month buckets before giving up (the daily
        # gate alone would reject every structural edge as insufficient_overlap).
        monthly_max, monthly_insufficient = _monthly_candidate_corr(candidate, book, streams)
        if not monthly_insufficient:
            corr_full, corr_insufficient = monthly_max, monthly_insufficient
            corr_basis = "monthly"
    max_corr_to_book = corr_full

    # Risk-parity (inverse-vol) weighting — the SAME basis the production book is built on
    # (book_monitor / build_real_portfolio). Equal weighting lets a dense, high-trade-count
    # sleeve dominate the daily variance, so a genuinely diversifying low-vol sleeve looks
    # non-diversifying (e.g. 10692:NDX drops book DD 10.27%->8.71% under risk-parity but
    # *raises* it under equal weight). Gating diversification on a weighting the book never
    # uses rejected real diversifiers; inverse-vol aligns the test with how the book trades.
    book_weights = inverse_vol_weights(book, common_dir)
    without_metrics = portfolio_metrics(
        book,
        book_weights,
        common_dir,
        starting_capital=starting_capital,
    )
    with_keys = sorted(set(book + [candidate]))
    with_metrics = portfolio_metrics(
        with_keys,
        inverse_vol_weights(with_keys, common_dir),
        common_dir,
        starting_capital=starting_capital,
    )

    sharpe_without = without_metrics["sharpe"]
    sharpe_with = with_metrics["sharpe"]
    maxdd_without = without_metrics["max_drawdown_pct"]
    maxdd_with = with_metrics["max_drawdown_pct"]
    sharpe_improved = (
        isinstance(sharpe_with, float)
        and isinstance(sharpe_without, float)
        and sharpe_with > sharpe_without
    )
    maxdd_improved = (
        isinstance(maxdd_with, float)
        and isinstance(maxdd_without, float)
        and maxdd_with < maxdd_without
    )
    # DL-079 (OWNER-ratified 2026-06-28): Sharpe-protective diversification.
    # The book is a high-Sharpe risk-parity portfolio whose MaxDD already sits FAR under the
    # FTMO cap, so MaxDD headroom is abundant and a marginal MaxDD "improvement" is not worth
    # a Sharpe cost. On the canonical $100k base the book MaxDD is sub-1%, where the with/without
    # MaxDD delta is dominated by which single day the peak lands on (noise) and can flip sign.
    # The OLD rule `sharpe_improved or maxdd_improved` admitted Sharpe-DILUTIVE sleeves (e.g.
    # 10115/10911 GDAXI: PF~1.0-1.1, they cut book Sharpe 2.00->1.89) on such a noise-floor MaxDD
    # gain. Fix: a candidate diversifies iff it improves Sharpe, OR improves MaxDD WITHOUT
    # degrading Sharpe. Sharpe is scale-invariant (capital-base independent) and is the reliable
    # signal while DD is non-binding. (If DD ever approaches the cap, revisit to allow a DD-for-
    # Sharpe trade in that DD-constrained regime.)
    SHARPE_DEGRADE_EPS = 1e-3
    sharpe_degraded = (
        isinstance(sharpe_with, float)
        and isinstance(sharpe_without, float)
        and sharpe_with < sharpe_without - SHARPE_DEGRADE_EPS
    )
    # `diversifies` is the DL-079 signal; under C1 it is the "positive marginal contribution"
    # that unlocks the strong-admit zone (corr_eff < 0.15). It is retained in the output for
    # continuity and consumed by classify_admission below.
    diversifies = sharpe_improved or (maxdd_improved and not sharpe_degraded)
    delta_sharpe = (
        sharpe_with - sharpe_without
        if isinstance(sharpe_with, float) and isinstance(sharpe_without, float)
        else None
    )

    # ------------------------------------------------------------------ #
    # C1 (2026-07-26) hard gate — DL-083 stricter-of-two correlation rule.
    # decisions/2026-07-26_q09_hard_gate_dl083_port.md. The legacy single-threshold gate
    # (`max_corr_to_book <= 0.30 and diversifies`) is replaced by the zoned classifier:
    # corr_eff = max(full-sample, high-vol-regime); >=0.40 REJECT, <0.15+diversifies ADMIT,
    # gray zone by delta-Sharpe >= 0.020. Insufficient full-sample overlap short-circuits to
    # `insufficient_overlap` (existing behaviour); only then is the regime NOT even computed,
    # so a sparse sleeve is never admitted through a degenerate daily-regime correlation.
    if corr_insufficient:
        corr_regime = None
        regime_days = 0
        regime_known = False
        corr_eff = None
        corr_binding_basis = "n/a"
        admit = False
        reason_base = "insufficient_overlap"
        reason = "insufficient_overlap"
    else:
        if corr_basis == "daily":
            corr_regime, regime_days, regime_known = _regime_correlation(
                candidate,
                book,
                aligned_keys,
                matrix,
                book_weights,
            )
        else:
            # Full-sample correlation itself needed the monthly fallback (daily overlap too
            # sparse) — a DAILY high-vol regime is not a meaningful construct for such
            # structural low-frequency sleeves, so the regime basis is UNKNOWN and the
            # (monthly) full-sample binds alone. Prevents a degenerate daily-regime label.
            corr_regime, regime_days, regime_known = None, 0, False
        admit, reason_base, corr_binding_basis, corr_eff = classify_admission(
            corr_full,
            corr_regime,
            regime_known,
            delta_sharpe,
            diversifies,
        )
        # Reason strings must name the binding basis (decision record): `<verdict>:<basis>`,
        # basis in {corr_full, corr_regime, regime_unknown}. Base verdict vocabulary preserved.
        reason = f"{reason_base}:{corr_binding_basis}"
    regime_unknown = (not regime_known) and not corr_insufficient

    # Challenger-swap evaluation (OWNER directive 2026-07-03, EXTENDED 2026-07-15):
    # EVERY non-admit reason now gets a swap check — OWNER: "wenn Q09 ablehnt, muss es
    # immer auch schaun, ob nicht ein Sleeve getauscht wird". Target incumbent depends
    # on the reject reason:
    #  - correlation_above_max_corr -> the MOST-CORRELATED incumbent (it's the crowd).
    #  - no_diversification (decorrelated but adds no Sharpe/DD) -> the WEAKEST incumbent
    #    by standalone Sharpe; the candidate may still beat a mediocre sleeve on REPLACE
    #    even though it does not improve on ADD. The full-portfolio swap metric is the
    #    real judge (challenger_superior needs the swapped book to actually improve).
    #  - lineage rejections -> the lineage incumbent (controlled variant replacement).
    # NEVER auto-swap — live deployment stays OWNER+manifest (surfaced as CHALLENGER_SUPERIOR).
    challenger_swap: dict | None = None
    lineage_incumbent = _lineage_incumbent_in_book(
        candidate,
        book,
        lineage_payload=lineage_payload,
        lineage_artifacts=lineage_artifacts,
    )
    # Dispatch on the base verdict token (reason now carries a `:<basis>` suffix).
    if reason_base == "correlation_above_max_corr":
        challenger_swap = _evaluate_challenger_swap(
            candidate, book, aligned_keys, correlations,
            common_dir, without_metrics, starting_capital,
            streams=streams,
        )
    elif not admit and lineage_incumbent is not None:
        challenger_swap = _evaluate_challenger_swap(
            candidate, book, aligned_keys, correlations,
            common_dir, without_metrics, starting_capital,
            streams=streams,
            incumbent_hint=lineage_incumbent,
        )
        challenger_swap["trigger"] = f"lineage_rejection:{reason_base}"
    elif not admit:
        # Any other reject (chiefly no_diversification, insufficient_overlap): test the
        # candidate against the WEAKEST incumbent by standalone Sharpe.
        weakest = _find_weakest_incumbent(book, streams)
        if weakest is not None:
            challenger_swap = _evaluate_challenger_swap(
                candidate, book, aligned_keys, correlations,
                common_dir, without_metrics, starting_capital,
                streams=streams,
                incumbent_hint=weakest,
            )
            challenger_swap["trigger"] = f"weakest_incumbent_swap:{reason_base}"

    if challenger_swap and challenger_swap.get("challenger_superior"):
        reason = "CHALLENGER_SUPERIOR"
        # admit stays False — OWNER must approve any swap at Q12

    return {
        "admit": admit,
        "reason": reason,
        "standalone_pf": _profit_factor(streams[candidate]),
        "max_corr_to_book": max_corr_to_book,
        "corr_insufficient": corr_insufficient,
        "corr_basis": corr_basis,
        "corr_full": corr_full,
        "corr_regime": corr_regime,
        "corr_eff": corr_eff,
        "corr_binding_basis": corr_binding_basis,
        "regime_days": regime_days,
        "regime_unknown": regime_unknown,
        "sharpe_with": sharpe_with,
        "sharpe_without": sharpe_without,
        "maxdd_with": maxdd_with,
        "maxdd_without": maxdd_without,
        "diversifies": diversifies,
        "challenger_swap": challenger_swap,
    }


def build_artifact(
    candidate_key: Key,
    *,
    common_dir: Path = DEFAULT_ADMISSION_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    max_corr: float = DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    lineage_payload: dict[str, Any] | None = None,
    lineage_artifacts: Sequence[Path] | None = None,
) -> dict[str, Any]:
    candidate = _normalize_key(candidate_key)
    if all_streams:
        discovery_model = load_model()
        streams = load_streams(common_dir, commission_model=discovery_model)
        book_keys = sorted(key for key in streams if key != candidate)
        basis = "all_q08_streams_uncertified"
    else:
        book_keys = current_book(candidates_db)
        basis = "portfolio_candidates"

    verdict = evaluate_candidate(
        candidate,
        book_keys,
        common_dir,
        max_corr=max_corr,
        starting_capital=starting_capital,
        lineage_payload=lineage_payload,
        lineage_artifacts=lineage_artifacts,
    )

    model = load_model()
    load_streams(
        common_dir,
        candidates=sorted(set(book_keys + [candidate])),
        commission_model=model,
    )
    artifact = {
        **verdict,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "candidate": key_label(candidate),
        "book": [key_label(key) for key in sorted(book_keys)],
        "basis": basis,
        "max_corr": max_corr,  # legacy CLI/schema field; no longer gates (see DEFAULT_MAX_CORR).
        "min_overlap_days": DEFAULT_MIN_OVERLAP_DAYS,
        # C1 (2026-07-26) DL-083 gate parameters — self-describing evidence.
        "corr_reject_min": CORR_REJECT_MIN,
        "corr_admit_max": CORR_ADMIT_MAX,
        "sharpe_delta_admit": SHARPE_DELTA_ADMIT,
        "regime_vol_window": REGIME_VOL_WINDOW,
        "regime_top_quantile": REGIME_TOP_QUANTILE,
        "min_regime_days": MIN_REGIME_DAYS,
        "gate_decision_ref": "decisions/2026-07-26_q09_hard_gate_dl083_port.md",
        "starting_capital": float(starting_capital),
        "commission_basis": COMMISSION_BASIS,
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "commission_model": describe_model(model),
    }
    return artifact


def write_artifact(artifact: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate portfolio-relative EA-symbol admission.")
    parser.add_argument("--candidate", required=True, type=_parse_key, help="Candidate as ea_id:SYMBOL.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_ADMISSION_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument("--max-corr", type=float, default=DEFAULT_MAX_CORR)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument("--lineage-payload-json", help="Optional work-item payload JSON carrying challenger_of.")
    parser.add_argument("--lineage-payload-file", type=Path, help="Optional JSON file carrying challenger_of.")
    parser.add_argument(
        "--lineage-artifact",
        type=Path,
        action="append",
        dest="lineage_artifacts",
        help="Optional challenger-build evidence JSON. Repeatable.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Artifact JSON path. Defaults to portfolio_admission_<ea>_<sym>.json.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    lineage_payload = load_lineage_payload(args.lineage_payload_json, args.lineage_payload_file)
    artifact = build_artifact(
        args.candidate,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        max_corr=args.max_corr,
        starting_capital=args.starting_capital,
        lineage_payload=lineage_payload,
        lineage_artifacts=args.lineage_artifacts,
    )
    out_path = args.out
    if out_path is None:
        ea_id, symbol = args.candidate
        out_path = DEFAULT_ARTIFACT_DIR / f"portfolio_admission_{ea_id}_{symbol}.json"
    write_artifact(artifact, out_path)
    print(f"wrote {out_path} admit={artifact['admit']} reason={artifact['reason']}")
    return 0


def _candidate_corr(
    candidate: Key,
    book: Sequence[Key],
    aligned_keys: Sequence[Key],
    correlations: list[list[float | None]],
) -> tuple[float | None, bool]:
    candidate_idx = aligned_keys.index(candidate)
    corr_values: list[float] = []
    for book_key in book:
        book_idx = aligned_keys.index(book_key)
        value = correlations[candidate_idx][book_idx]
        if value is not None:
            corr_values.append(float(value))
    max_corr = max(corr_values) if corr_values else None
    # insufficient ONLY when not a single book pair is measurable. A pair with < the daily
    # overlap threshold is time-disjoint (diversifying by construction), not a reason to veto
    # the whole candidate; max over the measurable pairs is the real worst-case correlation.
    # (Old semantics — "any unmeasurable pair -> whole candidate insufficient" — perversely
    # rejected every low-freq diversifier the moment the book held one sparse sleeve.)
    insufficient = not corr_values
    return max_corr, insufficient


def _months_between(lo: str, hi: str) -> list[str]:
    """Inclusive 'YYYY-MM' calendar range."""
    year, month = int(lo[:4]), int(lo[5:7])
    end_year, end_month = int(hi[:4]), int(hi[5:7])
    out: list[str] = []
    while (year, month) <= (end_year, end_month):
        out.append(f"{year:04d}-{month:02d}")
        month += 1
        if month > 12:
            month = 1
            year += 1
    return out


def _monthly_candidate_corr(
    candidate: Key,
    book: Sequence[Key],
    streams: dict[Key, Sequence[Any]],
) -> tuple[float | None, bool]:
    """Monthly-bucket fallback for the candidate-vs-book correlation.

    For each book member, Pearson-correlate the candidate over the calendar window where
    BOTH sleeves were live — from the later of their first active months to the earlier of
    their last — with no-trade months filled as 0 return (a flat month is genuine zero PnL,
    not missing data). A pair is trusted only when that shared window spans at least
    DEFAULT_MIN_SHARED_SPAN_MONTHS and each sleeve is active in at least
    DEFAULT_MIN_ACTIVE_MONTHS of it (so the correlation is not an all-zeros artifact).
    Conservative: any unmeasurable book pair marks the whole candidate insufficient.
    """
    monthly = {key: to_monthly_pnl(streams[key]) for key in [candidate, *book]}
    candidate_series = monthly[candidate]
    candidate_active = sorted(m for m, v in candidate_series.items() if v != 0.0)
    if not candidate_active:
        return None, True

    corr_values: list[float] = []
    for book_key in book:
        book_series = monthly[book_key]
        book_active = sorted(m for m, v in book_series.items() if v != 0.0)
        if not book_active:
            continue
        lo = max(candidate_active[0], book_active[0])
        hi = min(candidate_active[-1], book_active[-1])
        if lo > hi:
            continue  # time-disjoint from this sleeve => diversifying, not a risk
        window = _months_between(lo, hi)
        if len(window) < DEFAULT_MIN_SHARED_SPAN_MONTHS:
            continue
        cand_vec = [float(candidate_series.get(m, 0.0)) for m in window]
        book_vec = [float(book_series.get(m, 0.0)) for m in window]
        cand_active_n = sum(1 for v in cand_vec if v != 0.0)
        book_active_n = sum(1 for v in book_vec if v != 0.0)
        if cand_active_n < DEFAULT_MIN_ACTIVE_MONTHS or book_active_n < DEFAULT_MIN_ACTIVE_MONTHS:
            continue
        value = _pearson(cand_vec, book_vec)
        if value is not None:
            corr_values.append(float(value))

    max_corr = max(corr_values) if corr_values else None
    # insufficient ONLY when NOT ONE book pair was measurable (candidate shares no assessable
    # live-span with any sleeve). A pair skipped above is time-disjoint or too sparse to
    # co-move => diversifying by construction; it must not veto the whole candidate. The max
    # over measurable pairs is the true worst-case correlation. (Old semantics vetoed the
    # whole candidate on any single unmeasurable pair, which rejected real low-freq
    # diversifiers as soon as the book held one sparse sleeve — e.g. 10569 XAU, corr 0.22.)
    insufficient = not corr_values
    return max_corr, insufficient


def _load_standalone_pf(candidate: Key, common_dir: Path) -> float | None:
    model = load_model()
    streams = load_streams(common_dir, candidates=[candidate], commission_model=model)
    if candidate not in streams:
        return None
    return _profit_factor(streams[candidate])


def _profit_factor(trades: Sequence[Any]) -> float | None:
    gross_profit = sum(max(0.0, float(trade.net_of_cost)) for trade in trades)
    gross_loss = abs(sum(min(0.0, float(trade.net_of_cost)) for trade in trades))
    if gross_loss == 0.0:
        return None
    return _round_float(gross_profit / gross_loss)


def _standalone_sharpe(trades: Sequence[Any]) -> float | None:
    """Annualized Sharpe of a sleeve's daily net-of-cost PnL (weakest-incumbent proxy)."""
    daily = to_daily_pnl(trades)
    vals = list(daily.values())
    if len(vals) < 20:
        return None
    mean = sum(vals) / len(vals)
    var = sum((v - mean) ** 2 for v in vals) / (len(vals) - 1)
    if var <= 0:
        return None
    return mean / (var ** 0.5) * (252 ** 0.5)


def _find_weakest_incumbent(
    book: Sequence[Key],
    streams: "dict[Key, Sequence[Any]] | None",
) -> "Key | None":
    """Return the book member with the LOWEST standalone Sharpe — the swap target for a
    no_diversification reject (OWNER 2026-07-15). The full-portfolio swap metric in
    _evaluate_challenger_swap is the real judge; this only picks which incumbent to test."""
    if not streams:
        return None
    scored = []
    for k in book:
        if k not in streams:
            continue
        sh = _standalone_sharpe(streams[k])
        if sh is not None:
            scored.append((sh, k))
    if not scored:
        return None
    scored.sort(key=lambda x: x[0])
    return scored[0][1]


def _find_most_correlated_incumbent(
    candidate: Key,
    book: Sequence[Key],
    aligned_keys: Sequence[Key],
    correlations: list[list[float | None]],
) -> tuple["Key | None", "float | None"]:
    """Return (incumbent, corr) — the book member most correlated to the challenger."""
    if candidate not in aligned_keys:
        return None, None
    candidate_idx = aligned_keys.index(candidate)
    best_key: Key | None = None
    best_corr: float | None = None
    for book_key in book:
        if book_key not in aligned_keys:
            continue
        book_idx = aligned_keys.index(book_key)
        value = correlations[candidate_idx][book_idx]
        if value is not None:
            v = float(value)
            if best_corr is None or v > best_corr:
                best_corr = v
                best_key = book_key
    return best_key, best_corr


def _monthly_find_most_correlated_incumbent(
    candidate: Key,
    book: Sequence[Key],
    streams: dict[Key, Sequence[Any]],
) -> tuple["Key | None", "float | None"]:
    """Monthly-basis fallback for finding the most correlated book member.

    Used when daily overlap between the candidate and book members is insufficient
    to compute a daily Pearson correlation (e.g. low-frequency structural sleeves).
    Mirrors _monthly_candidate_corr but returns the most-correlated key, not max corr.
    """
    monthly = {key: to_monthly_pnl(streams[key]) for key in [candidate, *book] if key in streams}
    if candidate not in monthly:
        return None, None
    candidate_series = monthly[candidate]
    candidate_active = sorted(m for m, v in candidate_series.items() if v != 0.0)
    if not candidate_active:
        return None, None

    best_key: Key | None = None
    best_corr: float | None = None
    for book_key in book:
        if book_key not in monthly:
            continue
        book_series = monthly[book_key]
        book_active = sorted(m for m, v in book_series.items() if v != 0.0)
        if not book_active:
            continue
        lo = max(candidate_active[0], book_active[0])
        hi = min(candidate_active[-1], book_active[-1])
        if lo > hi:
            continue
        window = _months_between(lo, hi)
        if len(window) < DEFAULT_MIN_SHARED_SPAN_MONTHS:
            continue
        cand_vec = [float(candidate_series.get(m, 0.0)) for m in window]
        book_vec = [float(book_series.get(m, 0.0)) for m in window]
        cand_active_n = sum(1 for v in cand_vec if v != 0.0)
        book_active_n = sum(1 for v in book_vec if v != 0.0)
        if cand_active_n < DEFAULT_MIN_ACTIVE_MONTHS or book_active_n < DEFAULT_MIN_ACTIVE_MONTHS:
            continue
        value = _pearson(cand_vec, book_vec)
        if value is not None:
            v = float(value)
            if best_corr is None or v > best_corr:
                best_corr = v
                best_key = book_key

    return best_key, best_corr


def load_lineage_payload(
    payload_json: str | None = None,
    payload_file: Path | None = None,
) -> dict[str, Any] | None:
    if payload_json:
        data = json.loads(payload_json)
        return data if isinstance(data, dict) else None
    if payload_file is not None:
        data = json.loads(payload_file.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    return None


def _lineage_incumbent_in_book(
    candidate: Key,
    book: Sequence[Key],
    *,
    lineage_payload: dict[str, Any] | None = None,
    lineage_artifacts: Sequence[Path] | None = None,
) -> Key | None:
    parent_ids = _lineage_parent_ids(
        candidate,
        lineage_payload=lineage_payload,
        lineage_artifacts=lineage_artifacts,
    )
    if not parent_ids:
        return None
    candidates = sorted(key for key in book if int(key[0]) in parent_ids)
    if not candidates:
        return None
    same_symbol = [key for key in candidates if key[1] == candidate[1]]
    return (same_symbol or candidates)[0]


def _lineage_parent_ids(
    candidate: Key,
    *,
    lineage_payload: dict[str, Any] | None,
    lineage_artifacts: Sequence[Path] | None,
) -> set[int]:
    parents: set[int] = set()
    if lineage_payload:
        for key in ("challenger_of", "parent_ea", "parent_eas"):
            if key in lineage_payload:
                parents.update(_extract_ea_ids(lineage_payload.get(key)))

    artifacts = tuple(DEFAULT_LINEAGE_ARTIFACTS if lineage_artifacts is None else lineage_artifacts)
    for artifact_path in artifacts:
        try:
            artifact = json.loads(Path(artifact_path).read_text(encoding="utf-8"))
        except Exception:
            continue
        for build in artifact.get("builds", []):
            if not isinstance(build, dict):
                continue
            if _extract_one_ea_id(build.get("new_ea")) != candidate[0]:
                continue
            target_symbol = str(build.get("target_symbol") or "").strip()
            if target_symbol and target_symbol != candidate[1]:
                continue
            parent = _extract_one_ea_id(build.get("parent_ea"))
            if parent is not None:
                parents.add(parent)
    return parents


def _extract_ea_ids(value: Any) -> set[int]:
    if isinstance(value, dict):
        values = value.values()
    elif isinstance(value, (list, tuple, set)):
        values = value
    else:
        values = (value,)
    out: set[int] = set()
    for item in values:
        ea_id = _extract_one_ea_id(item)
        if ea_id is not None:
            out.add(ea_id)
    return out


def _extract_one_ea_id(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    text = str(value).strip()
    match = re.search(r"QM5_(\d+)", text)
    if match:
        return int(match.group(1))
    if text.isdigit():
        return int(text)
    return None


def _evaluate_challenger_swap(
    candidate: Key,
    book: Sequence[Key],
    aligned_keys: Sequence[Key],
    correlations: list[list[float | None]],
    common_dir: Path,
    current_book_metrics: dict,
    starting_capital: float,
    *,
    streams: "dict[Key, Sequence[Any]] | None" = None,
    incumbent_hint: Key | None = None,
) -> dict:
    """Check if challenger replacing the most-correlated incumbent improves the book.

    Returns a comparison table. challenger_superior=True when the swap improves BOTH
    Sharpe and MaxDD, or Sharpe strongly (>= SHARPE_STRONG_DELTA above current).
    Result is informational — NEVER triggers an auto-swap.

    When daily overlap is insufficient (low-freq sleeves), falls back to monthly
    correlation to identify the most-correlated incumbent — the same basis that
    caused the rejection.
    """
    SHARPE_STRONG_DELTA = 0.05

    if incumbent_hint is not None and incumbent_hint in book:
        incumbent = incumbent_hint
        incumbent_corr = _correlation_for_pair(candidate, incumbent_hint, aligned_keys, correlations)
        if incumbent_corr is None and streams is not None:
            _, incumbent_corr = _monthly_find_most_correlated_incumbent(
                candidate, [incumbent_hint], streams
            )
    else:
        incumbent, incumbent_corr = _find_most_correlated_incumbent(
            candidate, book, aligned_keys, correlations
        )
    # Monthly fallback: when daily overlap is too sparse to compute Pearson (all daily
    # correlations are None), use monthly returns to identify the most-correlated
    # incumbent — the same basis that produced the rejection verdict.
    if incumbent is None and streams is not None:
        incumbent, incumbent_corr = _monthly_find_most_correlated_incumbent(
            candidate, book, streams
        )
    if incumbent is None:
        return {"error": "no_measurable_incumbent", "challenger_superior": False, "incumbent": None}

    swap_keys = sorted((set(book) - {incumbent}) | {candidate})
    try:
        swap_metrics = portfolio_metrics(
            swap_keys,
            inverse_vol_weights(swap_keys, common_dir),
            common_dir,
            starting_capital=starting_capital,
        )
    except Exception as exc:
        return {
            "error": f"swap_metrics_failed: {exc}",
            "challenger_superior": False,
            "incumbent": key_label(incumbent),
            "incumbent_corr_to_challenger": _round_float(incumbent_corr) if incumbent_corr is not None else None,
        }

    current_sharpe = current_book_metrics.get("sharpe")
    current_dd = current_book_metrics.get("max_drawdown_pct")
    swap_sharpe = swap_metrics.get("sharpe")
    swap_dd = swap_metrics.get("max_drawdown_pct")

    sharpe_improved = (
        isinstance(swap_sharpe, float) and isinstance(current_sharpe, float)
        and swap_sharpe > current_sharpe
    )
    dd_improved = (
        isinstance(swap_dd, float) and isinstance(current_dd, float)
        and swap_dd < current_dd
    )
    sharpe_strong = (
        isinstance(swap_sharpe, float) and isinstance(current_sharpe, float)
        and swap_sharpe >= current_sharpe + SHARPE_STRONG_DELTA
    )

    challenger_superior = (sharpe_improved and dd_improved) or sharpe_strong

    return {
        "incumbent": key_label(incumbent),
        "incumbent_corr_to_challenger": _round_float(incumbent_corr) if incumbent_corr is not None else None,
        "current_book_sharpe": current_sharpe,
        "current_book_maxdd": current_dd,
        "swap_book_sharpe": swap_sharpe,
        "swap_book_maxdd": swap_dd,
        "swap_book_keys": [key_label(k) for k in swap_keys],
        "sharpe_improved": sharpe_improved,
        "dd_improved": dd_improved,
        "sharpe_strong": sharpe_strong,
        "challenger_superior": challenger_superior,
        "note": "CHALLENGER_SUPERIOR flags OWNER Q12 review; live deployment stays OWNER+manifest protocol",
    }


def _correlation_for_pair(
    candidate: Key,
    incumbent: Key,
    aligned_keys: Sequence[Key],
    correlations: list[list[float | None]],
) -> float | None:
    if candidate not in aligned_keys or incumbent not in aligned_keys:
        return None
    value = correlations[aligned_keys.index(candidate)][aligned_keys.index(incumbent)]
    return None if value is None else float(value)


def _parse_key(value: str) -> Key:
    ea_id, separator, symbol = value.partition(":")
    if not separator or not ea_id or not symbol:
        raise argparse.ArgumentTypeError("candidate must be formatted as ea_id:SYMBOL")
    try:
        return int(ea_id), symbol
    except ValueError as exc:
        raise argparse.ArgumentTypeError("ea_id must be an integer") from exc


def _normalize_key(key: Key) -> Key:
    ea_id, symbol = key
    return int(ea_id), str(symbol)


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
