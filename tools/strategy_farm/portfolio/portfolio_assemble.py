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
        align,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )
    from .portfolio_correlation import COMMISSION_BASIS
    from .portfolio_kpi import (
        Key,
        equal_weights,
        metrics_from_daily_pnl,
        portfolio_daily_pnl,
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
    from portfolio_correlation import COMMISSION_BASIS  # type: ignore
    from portfolio_kpi import (  # type: ignore
        Key,
        equal_weights,
        metrics_from_daily_pnl,
        portfolio_daily_pnl,
    )


def assemble_portfolio(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    max_dd_pct: float = 6.0,
    weighting: str = "equal",
    starting_capital: float = 10_000.0,
) -> dict[str, Any]:
    if weighting not in SUPPORTED_WEIGHTINGS:
        raise ValueError(f"unsupported weighting mode {weighting!r}")

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
    selected_keys, selected_weights, metrics = greedy_select(
        keys,
        matrix,
        max_dd_pct=max_dd_pct,
        weighting=weighting,
        starting_capital=starting_capital,
    )

    return {
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "basis": basis,
        "generated_basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "commission_degraded": model.degraded,
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "max_dd_pct_constraint": float(max_dd_pct),
        "weighting": weighting,
        "starting_capital": float(starting_capital),
        "n_series_considered": len(keys),
        "n_days": len(dates),
        "selected_keys": [key_label(key) for key in selected_keys],
        "weights": {key_label(key): _round_float(selected_weights[key]) for key in selected_keys},
        "kpis": metrics,
    }


SUPPORTED_WEIGHTINGS = ("equal", "inverse_vol")


def _column(matrix: object, col: int) -> list[float]:
    """Extract one sleeve's daily-PnL column as a plain list (numpy-optional)."""
    if hasattr(matrix, "shape"):
        return [float(v) for v in matrix[:, col]]  # type: ignore[index]
    return [float(row[col]) for row in matrix]  # type: ignore[union-attr]


def _std(values: Sequence[float]) -> float:
    n = len(values)
    if n < 2:
        return 0.0
    mean = sum(values) / n
    var = sum((v - mean) ** 2 for v in values) / n
    return var ** 0.5


def weights_for(
    trial: Sequence[Key],
    all_keys: Sequence[Key],
    matrix: object,
    weighting: str,
) -> dict[Key, float]:
    """Equal-capital or inverse-volatility (risk-parity) weights over `trial`.

    Inverse-vol is required for the diversification math to work: the FAIL_SOFT
    sleeves sit on very different RISK_FIXED lot sizes, so naive equal weight lets
    the highest-$ sleeve dominate the combined drawdown. 1/sigma weighting balances
    each sleeve's risk contribution. Degenerate (zero-variance) sleeves fall back to
    equal weight so the book is never empty.
    """
    if weighting == "equal":
        return equal_weights(trial)
    if weighting != "inverse_vol":
        raise ValueError(f"unsupported weighting mode {weighting!r}")
    index = {key: i for i, key in enumerate(all_keys)}
    inv: dict[Key, float] = {}
    for key in trial:
        sigma = _std(_column(matrix, index[key]))
        inv[key] = (1.0 / sigma) if sigma > 0 else 0.0
    total = sum(inv.values())
    if total <= 0:  # all degenerate -> equal weight fallback
        return equal_weights(trial)
    return {key: value / total for key, value in inv.items()}


def _book_metrics(
    trial: Sequence[Key],
    all_keys: Sequence[Key],
    matrix: object,
    weighting: str,
    starting_capital: float,
) -> tuple[dict[Key, float], dict[str, float | int | None]]:
    weights = weights_for(trial, all_keys, matrix, weighting)
    daily_pnl = _daily_pnl_for_keys(all_keys, matrix, sorted(trial), weights)
    metrics = metrics_from_daily_pnl(
        daily_pnl, n_sleeves=len(trial), starting_capital=starting_capital
    )
    return weights, metrics


def greedy_select(
    keys: Sequence[Key],
    matrix: object,
    *,
    max_dd_pct: float = 6.0,
    weighting: str = "equal",
    starting_capital: float = 10_000.0,
) -> tuple[list[Key], dict[Key, float], dict[str, float | int | None]]:
    if weighting not in SUPPORTED_WEIGHTINGS:
        raise ValueError(f"unsupported weighting mode {weighting!r}")

    all_keys = list(keys)
    n_days = _matrix_n_days(matrix)
    selected: list[Key] = []
    current_score = float("-inf")
    current_metrics = metrics_from_daily_pnl(
        [], n_sleeves=0, starting_capital=starting_capital, n_days=n_days
    )

    # Phase 1 - forward greedy that RESPECTS the cap: add the sleeve maximizing
    # combined Sharpe while keeping combined DD <= cap. Yields the best book that
    # is feasible under the cap (this is the path the unit tests exercise).
    while True:
        best_candidate: Key | None = None
        best_metrics: dict[str, float | int | None] | None = None
        best_score = current_score

        for candidate in all_keys:
            if candidate in selected:
                continue
            _, metrics = _book_metrics(
                [*selected, candidate], all_keys, matrix, weighting, starting_capital
            )
            if float(metrics["max_drawdown_pct"]) > max_dd_pct:
                continue
            score = _sharpe_score(metrics["sharpe"])
            if score > best_score:
                best_candidate, best_metrics, best_score = candidate, metrics, score

        if best_candidate is None or best_metrics is None:
            break
        selected = sorted([*selected, best_candidate])
        current_metrics = best_metrics
        current_score = best_score

    if selected:
        weights = weights_for(selected, all_keys, matrix, weighting)
        current_metrics["cap_met"] = True
        current_metrics["weighting"] = weighting
        return selected, weights, current_metrics

    # Phase 2 - FALLBACK: no book fits under the cap (every sleeve's standalone DD
    # already exceeds it, as with the FAIL_SOFT pool). Instead of returning an empty
    # portfolio, build the minimum-drawdown book: seed with the lowest-DD sleeve and
    # keep adding the sleeve that most REDUCES combined DD (the diversification
    # benefit). Flag cap_met=False so the caller knows it grazes/exceeds the target.
    book, weights, metrics = _min_dd_book(all_keys, matrix, weighting, starting_capital)
    metrics["cap_met"] = float(metrics["max_drawdown_pct"]) <= max_dd_pct
    metrics["weighting"] = weighting
    return book, weights, metrics


def _min_dd_book(
    all_keys: Sequence[Key],
    matrix: object,
    weighting: str,
    starting_capital: float,
) -> tuple[list[Key], dict[Key, float], dict[str, float | int | None]]:
    if not all_keys:
        empty = metrics_from_daily_pnl([], n_sleeves=0, starting_capital=starting_capital)
        return [], {}, empty

    # seed with the lowest standalone-DD sleeve
    seed = min(
        all_keys,
        key=lambda k: float(
            _book_metrics([k], all_keys, matrix, weighting, starting_capital)[1][
                "max_drawdown_pct"
            ]
        ),
    )
    selected = [seed]
    _, current_metrics = _book_metrics(
        selected, all_keys, matrix, weighting, starting_capital
    )
    current_dd = float(current_metrics["max_drawdown_pct"])

    while True:
        best_candidate: Key | None = None
        best_metrics: dict[str, float | int | None] | None = None
        best_dd = current_dd
        for candidate in all_keys:
            if candidate in selected:
                continue
            _, metrics = _book_metrics(
                [*selected, candidate], all_keys, matrix, weighting, starting_capital
            )
            dd = float(metrics["max_drawdown_pct"])
            if dd < best_dd:  # only accept additions that REDUCE combined DD
                best_candidate, best_metrics, best_dd = candidate, metrics, dd
        if best_candidate is None or best_metrics is None:
            break
        selected = sorted([*selected, best_candidate])
        current_metrics = best_metrics
        current_dd = best_dd

    weights = weights_for(selected, all_keys, matrix, weighting)
    return selected, weights, current_metrics


def write_manifest(manifest: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Q11 greedy portfolio manifest artifact.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument("--max-dd-pct", type=float, default=6.0)
    parser.add_argument("--weighting", choices=("equal", "inverse_vol"), default="equal")
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "portfolio_manifest_dev.json",
        help="Manifest JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    manifest = assemble_portfolio(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        max_dd_pct=args.max_dd_pct,
        weighting=args.weighting,
    )
    write_manifest(manifest, args.out)
    print(
        f"wrote {args.out} "
        f"({len(manifest['selected_keys'])}/{manifest['n_series_considered']} selected)"
    )
    return 0


def _daily_pnl_for_keys(
    all_keys: Sequence[Key],
    matrix: object,
    selected_keys: Sequence[Key],
    weights: dict[Key, float],
) -> list[float]:
    if not selected_keys:
        return []
    key_index = {key: index for index, key in enumerate(all_keys)}
    columns = [key_index[key] for key in selected_keys]
    weight_vector = [weights[key] for key in selected_keys]
    selected_matrix = _select_columns(matrix, columns)
    return portfolio_daily_pnl(selected_matrix, weight_vector)


def _select_columns(matrix: object, columns: Sequence[int]) -> object:
    if hasattr(matrix, "__getitem__") and hasattr(matrix, "shape"):
        return matrix[:, list(columns)]  # type: ignore[index]
    return [
        [float(row[column]) for column in columns]
        for row in matrix  # type: ignore[union-attr]
    ]


def _matrix_n_days(matrix: object) -> int:
    if hasattr(matrix, "shape"):
        return int(matrix.shape[0])  # type: ignore[attr-defined]
    return len(matrix)  # type: ignore[arg-type]


def _sharpe_score(value: float | int | None) -> float:
    return float("-inf") if value is None else float(value)


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
