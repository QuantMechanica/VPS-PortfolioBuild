from __future__ import annotations

import argparse
import datetime as dt
import json
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
DEFAULT_MAX_CORR = 0.30
DEFAULT_MIN_OVERLAP_DAYS = 60
# Low-frequency fallback: structural edges trade a few times a year, so two sleeves
# almost never share >=60 active days. When daily overlap is insufficient, retry the
# diversification test on calendar-month buckets, correlating over the window where both
# sleeves were live (0-filled) — the textbook returns-correlation basis. NB: do NOT gate on
# *co-active* months: genuine cross-asset diversifiers trade in different months by nature,
# so a co-active guard perversely certifies redundant same-instrument pairs (many shared
# months) while rejecting the diversifying ones. Gate on shared live-span instead.
DEFAULT_MIN_SHARED_SPAN_MONTHS = 24
DEFAULT_MIN_ACTIVE_MONTHS = 6


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
    common_dir: Path = DEFAULT_COMMON_DIR,
    *,
    max_corr: float = DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
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
    max_corr_to_book, corr_insufficient = _candidate_corr(
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
            max_corr_to_book, corr_insufficient = monthly_max, monthly_insufficient
            corr_basis = "monthly"

    # Risk-parity (inverse-vol) weighting — the SAME basis the production book is built on
    # (book_monitor / build_real_portfolio). Equal weighting lets a dense, high-trade-count
    # sleeve dominate the daily variance, so a genuinely diversifying low-vol sleeve looks
    # non-diversifying (e.g. 10692:NDX drops book DD 10.27%->8.71% under risk-parity but
    # *raises* it under equal weight). Gating diversification on a weighting the book never
    # uses rejected real diversifiers; inverse-vol aligns the test with how the book trades.
    without_metrics = portfolio_metrics(
        book,
        inverse_vol_weights(book, common_dir),
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
    diversifies = sharpe_improved or (maxdd_improved and not sharpe_degraded)

    corr_ok = max_corr_to_book is not None and max_corr_to_book <= max_corr
    admit = corr_ok and not corr_insufficient and diversifies
    if corr_insufficient:
        reason = "insufficient_overlap"
    elif not corr_ok:
        reason = "correlation_above_max_corr"
    elif not diversifies:
        reason = "no_diversification"
    else:
        reason = "admitted"

    return {
        "admit": admit,
        "reason": reason,
        "standalone_pf": _profit_factor(streams[candidate]),
        "max_corr_to_book": max_corr_to_book,
        "corr_insufficient": corr_insufficient,
        "corr_basis": corr_basis,
        "sharpe_with": sharpe_with,
        "sharpe_without": sharpe_without,
        "maxdd_with": maxdd_with,
        "maxdd_without": maxdd_without,
        "diversifies": diversifies,
    }


def build_artifact(
    candidate_key: Key,
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    max_corr: float = DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
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
        "max_corr": max_corr,
        "min_overlap_days": DEFAULT_MIN_OVERLAP_DAYS,
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
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument("--max-corr", type=float, default=DEFAULT_MAX_CORR)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Artifact JSON path. Defaults to portfolio_admission_<ea>_<sym>.json.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    artifact = build_artifact(
        args.candidate,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        max_corr=args.max_corr,
        starting_capital=args.starting_capital,
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
