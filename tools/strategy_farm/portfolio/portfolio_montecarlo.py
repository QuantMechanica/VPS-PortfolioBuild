from __future__ import annotations

import argparse
import json
import math
import random
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


COMMISSION_BASIS = "worst_case_dxz_ftmo"
DEFAULT_STARTING_CAPITAL = 10_000.0


def build_artifact(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    selected_keys: list[tuple[int, str]] | None = None,
    weights: list[float] | None = None,
    runs: int = 1000,
    block_days: int = 20,
    seed: int = 0,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
) -> dict[str, Any]:
    if runs < 1:
        raise ValueError("runs must be >= 1")
    if block_days < 1:
        raise ValueError("block_days must be >= 1")
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be > 0")

    requested_weights = _weights_by_key(selected_keys, weights)
    if selected_keys is not None:
        candidates = selected_keys
        basis = "specified_keys"
    elif all_streams:
        candidates = None
        basis = "all_q08_streams_uncertified"
    else:
        candidates = read_candidates(candidates_db)
        basis = "candidates"

    model = load_model()
    streams = load_streams(common_dir, candidates=candidates, commission_model=model)
    series_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    keys, dates, matrix = align(series_by_key)

    if selected_keys is not None:
        missing = sorted(set(selected_keys) - set(keys))
        if missing:
            labels = ", ".join(key_label(key) for key in missing)
            raise ValueError(f"selected stream(s) not found: {labels}")

    weight_vector = _weight_vector(keys, requested_weights)
    portfolio_pnl = combined_daily_pnl(matrix, weight_vector)
    observed = equity_stats(portfolio_pnl, starting_capital)
    simulation = simulate(
        portfolio_pnl,
        runs=runs,
        block_days=block_days,
        seed=seed,
        starting_capital=starting_capital,
    )

    return {
        "basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "runs": runs,
        "block_days": block_days,
        "seed": seed,
        "starting_capital": _round_float(starting_capital),
        "n_series": len(keys),
        "n_days": len(dates),
        "keys": [key_label(key) for key in keys],
        "weights": [_round_float(value) for value in weight_vector],
        "observed": observed,
        "block_bootstrap": simulation["block_bootstrap"],
        "trade_order_shuffle": simulation["trade_order_shuffle"],
    }


def combined_daily_pnl(matrix: Any, weights: Sequence[float]) -> list[float]:
    if len(weights) == 0:
        return []

    combined: list[float] = []
    for row in matrix:
        combined.append(
            sum(float(row[col]) * float(weight) for col, weight in enumerate(weights))
        )
    return combined


def equity_stats(daily_pnl: Sequence[float], starting_capital: float) -> dict[str, float]:
    if len(daily_pnl) == 0:
        return {
            "terminal_equity": _round_float(starting_capital),
            "max_drawdown_pct": 0.0,
        }

    equity = starting_capital
    peak = starting_capital
    max_drawdown = 0.0
    for value in daily_pnl:
        equity += float(value)
        peak = max(peak, equity)
        if peak > 0.0:
            max_drawdown = max(max_drawdown, (peak - equity) / peak * 100.0)
    return {
        "terminal_equity": _round_float(equity),
        "max_drawdown_pct": _round_float(max_drawdown),
    }


def simulate(
    daily_pnl: Sequence[float],
    *,
    runs: int,
    block_days: int,
    seed: int,
    starting_capital: float,
) -> dict[str, dict[str, dict[str, float]]]:
    rng = random.Random(seed)
    pnl = [float(value) for value in daily_pnl]
    block_terminal: list[float] = []
    block_dd: list[float] = []
    shuffle_terminal: list[float] = []
    shuffle_dd: list[float] = []

    for _ in range(runs):
        block_run = _block_bootstrap(pnl, block_days, rng)
        block_stats = equity_stats(block_run, starting_capital)
        block_terminal.append(block_stats["terminal_equity"])
        block_dd.append(block_stats["max_drawdown_pct"])

        shuffle_run = pnl[:]
        rng.shuffle(shuffle_run)
        shuffle_stats = equity_stats(shuffle_run, starting_capital)
        shuffle_terminal.append(shuffle_stats["terminal_equity"])
        shuffle_dd.append(shuffle_stats["max_drawdown_pct"])

    return {
        "block_bootstrap": {
            "terminal_equity": distribution(block_terminal),
            "max_drawdown_pct": distribution(block_dd),
        },
        "trade_order_shuffle": {
            "terminal_equity": distribution(shuffle_terminal),
            "max_drawdown_pct": distribution(shuffle_dd),
        },
    }


def distribution(values: list[float]) -> dict[str, float]:
    if not values:
        return {"p5": 0.0, "p50": 0.0, "p95": 0.0, "mean": 0.0}
    ordered = sorted(float(value) for value in values)
    return {
        "p5": _round_float(_percentile(ordered, 5.0)),
        "p50": _round_float(_percentile(ordered, 50.0)),
        "p95": _round_float(_percentile(ordered, 95.0)),
        "mean": _round_float(sum(ordered) / len(ordered)),
    }


def write_artifact(artifact: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Q11 portfolio Monte Carlo on combined daily PnL.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument(
        "--keys",
        default=None,
        help="Comma-separated EA-symbol labels, e.g. 10430:NDX.DWX,10430:SP500.DWX.",
    )
    parser.add_argument(
        "--weights",
        default=None,
        help="Comma-separated weights matching --keys. Omit for equal weights.",
    )
    parser.add_argument("--runs", type=int, default=1000)
    parser.add_argument("--block-days", type=int, default=20)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "portfolio_montecarlo_dev.json",
        help="Artifact JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    selected_keys = _parse_keys(args.keys)
    weights = _parse_weights(args.weights)
    artifact = build_artifact(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        selected_keys=selected_keys,
        weights=weights,
        runs=args.runs,
        block_days=args.block_days,
        seed=args.seed,
        starting_capital=args.starting_capital,
    )
    write_artifact(artifact, args.out)
    print(f"wrote {args.out} ({artifact['n_series']} series, {artifact['n_days']} days)")
    return 0


def _block_bootstrap(pnl: Sequence[float], block_days: int, rng: random.Random) -> list[float]:
    if len(pnl) == 0:
        return []

    sampled: list[float] = []
    while len(sampled) < len(pnl):
        start = rng.randrange(len(pnl))
        for offset in range(block_days):
            sampled.append(float(pnl[(start + offset) % len(pnl)]))
            if len(sampled) == len(pnl):
                break
    return sampled


def _weights_by_key(
    keys: list[tuple[int, str]] | None,
    weights: list[float] | None,
) -> dict[tuple[int, str], float] | None:
    if keys is None:
        if weights is not None:
            raise ValueError("--weights requires --keys")
        return None
    if weights is None:
        return None
    if len(keys) != len(weights):
        raise ValueError("--weights must contain one value per --keys entry")
    return dict(zip(keys, weights))


def _weight_vector(
    keys: list[tuple[int, str]],
    requested_weights: dict[tuple[int, str], float] | None,
) -> list[float]:
    if not keys:
        return []
    if requested_weights is None:
        return [1.0 / len(keys) for _ in keys]
    return [float(requested_weights[key]) for key in keys]


def _parse_keys(raw: str | None) -> list[tuple[int, str]] | None:
    if raw is None or raw.strip() == "":
        return None
    keys: list[tuple[int, str]] = []
    for token in raw.split(","):
        label = token.strip()
        ea_id, separator, symbol = label.partition(":")
        if not separator or not ea_id or not symbol:
            raise ValueError(f"invalid key label {label!r}; expected EA_ID:SYMBOL")
        keys.append((int(ea_id), symbol))
    return keys


def _parse_weights(raw: str | None) -> list[float] | None:
    if raw is None or raw.strip() == "":
        return None
    return [float(token.strip()) for token in raw.split(",")]


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


def _percentile(ordered_values: list[float], percentile: float) -> float:
    if len(ordered_values) == 1:
        return ordered_values[0]
    position = (percentile / 100.0) * (len(ordered_values) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered_values[lower]
    fraction = position - lower
    return ordered_values[lower] * (1.0 - fraction) + ordered_values[upper] * fraction


if __name__ == "__main__":
    raise SystemExit(main())
