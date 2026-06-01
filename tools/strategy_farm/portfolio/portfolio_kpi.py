from __future__ import annotations

import datetime as dt
import math
from pathlib import Path
from typing import Mapping, Sequence

try:
    import numpy as np
except ModuleNotFoundError:  # pragma: no cover - depends on local Python env
    np = None  # type: ignore[assignment]

try:
    from .commission import CommissionModel
    from .portfolio_common import DEFAULT_COMMON_DIR, align, load_streams, to_daily_pnl
except ImportError:  # pragma: no cover - direct script execution
    from commission import CommissionModel  # type: ignore
    from portfolio_common import DEFAULT_COMMON_DIR, align, load_streams, to_daily_pnl  # type: ignore


Key = tuple[int, str]


def portfolio_equity(
    keys: Sequence[Key],
    weights: Mapping[Key, float] | Sequence[float],
    common_dir: Path = DEFAULT_COMMON_DIR,
    *,
    commission_model: CommissionModel | None = None,
) -> tuple[list[dt.date], list[float]]:
    requested_keys = _normalize_keys(keys)
    if not requested_keys:
        return [], []

    streams = load_streams(common_dir, candidates=requested_keys, commission_model=commission_model)
    missing = sorted(set(requested_keys) - set(streams))
    if missing:
        raise ValueError(f"missing q08 trade streams for keys: {missing!r}")

    series_by_key = {key: to_daily_pnl(streams[key]) for key in requested_keys}
    aligned_keys, dates, matrix = align(series_by_key)
    weight_vector = _weight_vector(aligned_keys, requested_keys, weights)
    daily_pnl = portfolio_daily_pnl(matrix, weight_vector)
    return dates, [_round_float(value) for value in cumulative_sum(daily_pnl)]


def portfolio_metrics(
    keys: Sequence[Key],
    weights: Mapping[Key, float] | Sequence[float],
    common_dir: Path = DEFAULT_COMMON_DIR,
    *,
    starting_capital: float = 10_000.0,
    commission_model: CommissionModel | None = None,
) -> dict[str, float | int | None]:
    dates, equity_curve = portfolio_equity(
        keys,
        weights,
        common_dir,
        commission_model=commission_model,
    )
    daily_pnl = equity_to_daily_pnl(equity_curve)
    return metrics_from_daily_pnl(
        daily_pnl,
        n_sleeves=len(keys),
        starting_capital=starting_capital,
        n_days=len(dates),
    )


def portfolio_daily_pnl(matrix: object, weight_vector: Sequence[float]) -> list[float]:
    if np is not None:
        pnl_matrix = np.asarray(matrix, dtype=float)
        if pnl_matrix.size == 0:
            return []
        return [float(value) for value in pnl_matrix @ np.asarray(weight_vector, dtype=float)]

    return [
        sum(float(value) * float(weight) for value, weight in zip(row, weight_vector))
        for row in matrix  # type: ignore[union-attr]
    ]


def equity_to_daily_pnl(equity_curve: Sequence[float]) -> list[float]:
    previous = 0.0
    daily: list[float] = []
    for value in equity_curve:
        current = float(value)
        daily.append(current - previous)
        previous = current
    return daily


def metrics_from_daily_pnl(
    daily_pnl: Sequence[float],
    *,
    n_sleeves: int,
    starting_capital: float = 10_000.0,
    n_days: int | None = None,
) -> dict[str, float | int | None]:
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be positive")

    daily = [float(value) for value in daily_pnl]
    equity_curve = cumulative_sum(daily)
    total_profit = float(equity_curve[-1]) if equity_curve else 0.0
    returns = [value / float(starting_capital) for value in daily]

    sharpe: float | None
    if len(returns) < 2:
        sharpe = None
    else:
        mean = sum(returns) / len(returns)
        variance = sum((value - mean) ** 2 for value in returns) / len(returns)
        std = math.sqrt(variance)
        sharpe = None if std == 0.0 else float(mean / std * math.sqrt(252.0))

    return {
        "max_drawdown_pct": _round_float(max_drawdown_pct(equity_curve, starting_capital)),
        "sharpe": None if sharpe is None else _round_float(sharpe),
        "total_net_of_cost_profit": _round_float(total_profit),
        "n_days": len(daily) if n_days is None else int(n_days),
        "n_sleeves": int(n_sleeves),
    }


def max_drawdown_pct(equity_curve: Sequence[float], starting_capital: float = 10_000.0) -> float:
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be positive")

    peak = float(starting_capital)
    max_dd = 0.0
    for cumulative_pnl in equity_curve:
        account_equity = float(starting_capital) + float(cumulative_pnl)
        if account_equity > peak:
            peak = account_equity
        if peak <= 0.0:
            continue
        max_dd = max(max_dd, (peak - account_equity) / peak * 100.0)
    return max_dd


def cumulative_sum(values: Sequence[float]) -> list[float]:
    total = 0.0
    output: list[float] = []
    for value in values:
        total += float(value)
        output.append(total)
    return output


def equal_weights(keys: Sequence[Key]) -> dict[Key, float]:
    if not keys:
        return {}
    weight = 1.0 / len(keys)
    return {key: weight for key in keys}


def _normalize_keys(keys: Sequence[Key]) -> list[Key]:
    return sorted((int(ea_id), str(symbol)) for ea_id, symbol in keys)


def _weight_vector(
    aligned_keys: Sequence[Key],
    requested_keys: Sequence[Key],
    weights: Mapping[Key, float] | Sequence[float],
) -> list[float]:
    if isinstance(weights, Mapping):
        weight_by_key = {
            (int(ea_id), str(symbol)): float(weight)
            for (ea_id, symbol), weight in weights.items()
        }
    else:
        if len(weights) != len(requested_keys):
            raise ValueError("weights length must match keys length")
        weight_by_key = {key: float(weight) for key, weight in zip(requested_keys, weights)}

    missing = sorted(set(aligned_keys) - set(weight_by_key))
    if missing:
        raise ValueError(f"missing weights for keys: {missing!r}")
    return [weight_by_key[key] for key in aligned_keys]


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded
