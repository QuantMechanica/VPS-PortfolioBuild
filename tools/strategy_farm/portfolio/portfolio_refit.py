from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .commission import describe_model, load_model
    from .portfolio_assemble import greedy_select
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
    from .portfolio_correlation import COMMISSION_BASIS, correlation_matrix
    from .portfolio_kpi import equal_weights, metrics_from_daily_pnl, portfolio_daily_pnl
except ImportError:  # pragma: no cover - direct script execution
    from commission import describe_model, load_model  # type: ignore
    from portfolio_assemble import greedy_select  # type: ignore
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
    from portfolio_correlation import COMMISSION_BASIS, correlation_matrix  # type: ignore
    from portfolio_kpi import equal_weights, metrics_from_daily_pnl, portfolio_daily_pnl  # type: ignore


Key = tuple[int, str]
DEFAULT_MAX_CORR = 0.30
DEFAULT_MIN_OVERLAP_DAYS = 60


def refit(
    common_dir: Path = DEFAULT_COMMON_DIR,
    *,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    max_corr: float = DEFAULT_MAX_CORR,
    max_dd_pct: float = 6.0,
    starting_capital: float = 10_000.0,
) -> dict[str, Any]:
    current_book = read_candidates(candidates_db)
    model = load_model()
    discovery_candidates = None if all_streams else current_book
    basis = "all_q08_streams_uncertified" if all_streams else "portfolio_candidates"

    streams = load_streams(
        common_dir,
        candidates=discovery_candidates,
        commission_model=model,
    )
    series_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    keys, dates, matrix = align(series_by_key)
    correlations, insufficient_overlap = correlation_matrix(keys, matrix, DEFAULT_MIN_OVERLAP_DAYS)

    selected_keys, selected_weights, after_kpis = _select_with_correlation(
        keys,
        matrix,
        correlations,
        max_corr=max_corr,
        max_dd_pct=max_dd_pct,
        starting_capital=starting_capital,
    )
    assembler_keys, _, assembler_kpis = greedy_select(
        keys,
        matrix,
        max_dd_pct=max_dd_pct,
        starting_capital=starting_capital,
    )

    available_current = [key for key in current_book if key in streams]
    before_weights = equal_weights(available_current)
    before_kpis = _metrics_for_keys(
        keys,
        matrix,
        available_current,
        before_weights,
        starting_capital=starting_capital,
        n_days=len(dates),
    )

    keep_keys = sorted(set(current_book) & set(selected_keys))
    add_keys = sorted(set(selected_keys) - set(current_book))
    retire_keys = sorted(set(current_book) - set(selected_keys))

    return {
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "advisory_only": True,
        "basis": basis,
        "generated_basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "commission_degraded": model.degraded,
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "max_corr": float(max_corr),
        "max_dd_pct_constraint": float(max_dd_pct),
        "min_overlap_days": DEFAULT_MIN_OVERLAP_DAYS,
        "starting_capital": float(starting_capital),
        "n_current_book": len(current_book),
        "n_current_book_with_streams": len(available_current),
        "n_series_considered": len(keys),
        "n_days": len(dates),
        "current_book": [key_label(key) for key in current_book],
        "considered_keys": [key_label(key) for key in keys],
        "assembler_selected_keys": [key_label(key) for key in assembler_keys],
        "assembler_kpis": assembler_kpis,
        "selected_keys": [key_label(key) for key in selected_keys],
        "keep": [key_label(key) for key in keep_keys],
        "add": [key_label(key) for key in add_keys],
        "retire": [
            _retire_entry(key, selected_keys, keys, correlations, max_corr)
            for key in retire_keys
        ],
        "reweight": _reweight_entries(keep_keys, before_weights, selected_weights),
        "before_weights": _label_weights(before_weights),
        "after_weights": _label_weights(selected_weights),
        "before_kpis": before_kpis,
        "after_kpis": after_kpis,
        "portfolio_kpis": {
            "before": before_kpis,
            "after": after_kpis,
        },
        "insufficient_overlap": insufficient_overlap,
    }


def write_report(report: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build an advisory periodic portfolio re-fit report.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument("--max-corr", type=float, default=DEFAULT_MAX_CORR)
    parser.add_argument("--max-dd-pct", type=float, default=6.0)
    parser.add_argument("--starting-capital", type=float, default=10_000.0)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "portfolio_refit_report.json",
        help="Advisory report JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = refit(
        args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        max_corr=args.max_corr,
        max_dd_pct=args.max_dd_pct,
        starting_capital=args.starting_capital,
    )
    write_report(report, args.out)
    print(
        f"wrote {args.out} "
        f"(keep={len(report['keep'])} add={len(report['add'])} retire={len(report['retire'])})"
    )
    return 0


def _select_with_correlation(
    keys: Sequence[Key],
    matrix: object,
    correlations: list[list[float | None]],
    *,
    max_corr: float,
    max_dd_pct: float,
    starting_capital: float,
) -> tuple[list[Key], dict[Key, float], dict[str, float | int | None]]:
    all_keys = list(keys)
    n_days = _matrix_n_days(matrix)
    selected: list[Key] = []
    current_score = float("-inf")
    current_metrics = metrics_from_daily_pnl(
        [],
        n_sleeves=0,
        starting_capital=starting_capital,
        n_days=n_days,
    )

    while True:
        best_candidate: Key | None = None
        best_metrics: dict[str, float | int | None] | None = None
        best_score = current_score

        for candidate in all_keys:
            if candidate in selected:
                continue
            if selected and _max_corr_to_rest(candidate, selected, all_keys, correlations)[0] > max_corr:
                continue

            trial = sorted([*selected, candidate])
            weights = equal_weights(trial)
            metrics = _metrics_for_keys(
                all_keys,
                matrix,
                trial,
                weights,
                starting_capital=starting_capital,
            )
            if float(metrics["max_drawdown_pct"]) > max_dd_pct:
                continue

            score = _sharpe_score(metrics["sharpe"])
            if score > best_score:
                best_candidate = candidate
                best_metrics = metrics
                best_score = score

        if best_candidate is None or best_metrics is None:
            break
        selected = sorted([*selected, best_candidate])
        current_metrics = best_metrics
        current_score = best_score

    selected_weights = equal_weights(selected)
    return selected, selected_weights, current_metrics


def _metrics_for_keys(
    all_keys: Sequence[Key],
    matrix: object,
    selected_keys: Sequence[Key],
    weights: Mapping[Key, float],
    *,
    starting_capital: float,
    n_days: int | None = None,
) -> dict[str, float | int | None]:
    if not selected_keys:
        return metrics_from_daily_pnl(
            [],
            n_sleeves=0,
            starting_capital=starting_capital,
            n_days=_matrix_n_days(matrix) if n_days is None else n_days,
        )
    key_index = {key: index for index, key in enumerate(all_keys)}
    columns = [key_index[key] for key in selected_keys]
    weight_vector = [weights[key] for key in selected_keys]
    selected_matrix = _select_columns(matrix, columns)
    daily_pnl = portfolio_daily_pnl(selected_matrix, weight_vector)
    return metrics_from_daily_pnl(
        daily_pnl,
        n_sleeves=len(selected_keys),
        starting_capital=starting_capital,
        n_days=n_days,
    )


def _retire_entry(
    key: Key,
    selected_keys: Sequence[Key],
    all_keys: Sequence[Key],
    correlations: list[list[float | None]],
    max_corr: float,
) -> dict[str, Any]:
    max_value, correlated_key = _max_corr_to_rest(key, selected_keys, all_keys, correlations)
    reason = "max-corr-to-rest" if max_value > max_corr else "worsens portfolio"
    return {
        "key": key_label(key),
        "reason": reason,
        "max_corr_to_rest": None if max_value == float("-inf") else _round_float(max_value),
        "correlated_with": None if correlated_key is None else key_label(correlated_key),
    }


def _max_corr_to_rest(
    key: Key,
    rest: Sequence[Key],
    all_keys: Sequence[Key],
    correlations: list[list[float | None]],
) -> tuple[float, Key | None]:
    if key not in all_keys:
        return float("-inf"), None
    key_idx = all_keys.index(key)
    max_value = float("-inf")
    max_key: Key | None = None
    for other in rest:
        if other == key or other not in all_keys:
            continue
        other_idx = all_keys.index(other)
        value = correlations[key_idx][other_idx]
        if value is None:
            continue
        if float(value) > max_value:
            max_value = float(value)
            max_key = other
    return max_value, max_key


def _reweight_entries(
    keep_keys: Sequence[Key],
    before_weights: Mapping[Key, float],
    after_weights: Mapping[Key, float],
) -> list[dict[str, Any]]:
    entries = []
    for key in keep_keys:
        before = float(before_weights.get(key, 0.0))
        after = float(after_weights.get(key, 0.0))
        delta = after - before
        if abs(delta) <= 1e-12:
            continue
        entries.append(
            {
                "key": key_label(key),
                "before": _round_float(before),
                "after": _round_float(after),
                "delta": _round_float(delta),
            }
        )
    return entries


def _label_weights(weights: Mapping[Key, float]) -> dict[str, float]:
    return {key_label(key): _round_float(weight) for key, weight in sorted(weights.items())}


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
