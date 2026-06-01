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
    if weighting != "equal":
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


def greedy_select(
    keys: Sequence[Key],
    matrix: object,
    *,
    max_dd_pct: float = 6.0,
    weighting: str = "equal",
    starting_capital: float = 10_000.0,
) -> tuple[list[Key], dict[Key, float], dict[str, float | int | None]]:
    if weighting != "equal":
        raise ValueError(f"unsupported weighting mode {weighting!r}")

    all_keys = list(keys)
    pnl_matrix = matrix
    n_days = _matrix_n_days(pnl_matrix)
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
            trial = sorted([*selected, candidate])
            weights = equal_weights(trial)
            daily_pnl = _daily_pnl_for_keys(all_keys, pnl_matrix, trial, weights)
            metrics = metrics_from_daily_pnl(
                daily_pnl,
                n_sleeves=len(trial),
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
    parser.add_argument("--weighting", choices=("equal",), default="equal")
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
