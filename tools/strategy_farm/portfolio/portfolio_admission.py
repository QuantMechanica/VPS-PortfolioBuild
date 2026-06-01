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
        align,
    )
    from .portfolio_correlation import COMMISSION_BASIS, correlation_matrix
    from .portfolio_kpi import equal_weights, portfolio_metrics
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
        align,
    )
    from portfolio_correlation import COMMISSION_BASIS, correlation_matrix  # type: ignore
    from portfolio_kpi import equal_weights, portfolio_metrics  # type: ignore


Key = tuple[int, str]
DEFAULT_MAX_CORR = 0.30
DEFAULT_MIN_OVERLAP_DAYS = 60


def current_book(candidates_db: Path = DEFAULT_CANDIDATES_DB) -> list[Key]:
    """Return admitted portfolio candidates; an empty result means first-sleeve discovery."""
    return read_candidates(candidates_db)


def evaluate_candidate(
    candidate_key: Key,
    book_keys: Sequence[Key],
    common_dir: Path = DEFAULT_COMMON_DIR,
    *,
    max_corr: float = DEFAULT_MAX_CORR,
    starting_capital: float = 10_000.0,
) -> dict[str, Any]:
    candidate = _normalize_key(candidate_key)
    book = sorted({_normalize_key(key) for key in book_keys if _normalize_key(key) != candidate})

    if not book:
        standalone_pf = _load_standalone_pf(candidate, common_dir)
        return {
            "admit": True,
            "reason": "first_sleeve",
            "standalone_pf": standalone_pf,
            "max_corr_to_book": None,
            "corr_insufficient": False,
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

    without_metrics = portfolio_metrics(
        book,
        equal_weights(book),
        common_dir,
        starting_capital=starting_capital,
    )
    with_keys = sorted(set(book + [candidate]))
    with_metrics = portfolio_metrics(
        with_keys,
        equal_weights(with_keys),
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
    diversifies = sharpe_improved or maxdd_improved

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
    starting_capital: float = 10_000.0,
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
    parser.add_argument("--starting-capital", type=float, default=10_000.0)
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
    insufficient = False
    for book_key in book:
        book_idx = aligned_keys.index(book_key)
        value = correlations[candidate_idx][book_idx]
        if value is None:
            insufficient = True
        else:
            corr_values.append(float(value))
    max_corr = max(corr_values) if corr_values else None
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
