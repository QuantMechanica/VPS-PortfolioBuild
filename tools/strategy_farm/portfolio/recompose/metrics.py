"""Section 7 marginal-contribution metric vector for a portfolio roster.

Deterministic (no RNG) assembly of the directive section 7 evidence set from the
frozen per-sleeve daily-PnL streams.  Reuses the existing primitives
(``book_builder_common`` grid + weighting + book metrics, ``portfolio_common``
Trade model) and ADDS the three metrics the audit flagged as missing:
effective number of independent bets, explicit downside correlation, and
holding-time aggregation.

Streams are RISK_FIXED $1000 on a 100k account (= 1.0 %/trade); the book weight
of a sleeve is its risk-percent, so ``book_daily = sum_k weight_k * sleeve_daily``
on a shared zero-filled day grid, exactly as ``book_builder_common`` does.  All
numbers are computed deterministically; missing inputs are explicit
(``EVIDENCE_MISSING`` / ``None``), never invented.
"""
from __future__ import annotations

import datetime as dt
import math
from typing import Any, Mapping, Sequence

try:  # package import
    from ..portfolio_common import Trade
    from ..book_builder_common import (
        book_metrics,
        matrix_on_grid,
        portfolio_daily,
        shared_day_grid,
    )
except ImportError:  # pragma: no cover - direct script execution
    from portfolio_common import Trade  # type: ignore
    from book_builder_common import (  # type: ignore
        book_metrics,
        matrix_on_grid,
        portfolio_daily,
        shared_day_grid,
    )

Key = tuple[int, str]

STARTING_CAPITAL = 100_000.0
SOURCE_RISK_PCT = 1.0  # streams are RISK_FIXED $1000 on 100k = 1.0 %/trade
TRADING_DAYS_PER_YEAR = 252.0


def _round(value: float | None, ndigits: int = 8) -> float | None:
    if value is None:
        return None
    if not math.isfinite(value):
        return None
    rounded = round(float(value), ndigits)
    return 0.0 if rounded == -0.0 else rounded


def _pearson(left: Sequence[float], right: Sequence[float]) -> float | None:
    """Deterministic population Pearson correlation; None when undefined."""
    n = len(left)
    if n < 2 or n != len(right):
        return None
    mean_l = sum(left) / n
    mean_r = sum(right) / n
    cov = sum((a - mean_l) * (b - mean_r) for a, b in zip(left, right))
    var_l = sum((a - mean_l) ** 2 for a in left)
    var_r = sum((b - mean_r) ** 2 for b in right)
    if var_l <= 0.0 or var_r <= 0.0:
        return None
    return cov / math.sqrt(var_l * var_r)


def _population_std(values: Sequence[float]) -> float:
    n = len(values)
    if n == 0:
        return 0.0
    mean = sum(values) / n
    return math.sqrt(sum((v - mean) ** 2 for v in values) / n)


def _bare_symbol(symbol: str) -> str:
    return str(symbol).upper().split(".", 1)[0]


def _entry_days(trades: Sequence[Trade]) -> set[dt.date]:
    days: set[dt.date] = set()
    for trade in trades:
        stamp = trade.entry_time if trade.entry_time is not None else trade.time
        days.add(dt.datetime.fromtimestamp(int(stamp), tz=dt.UTC).date())
    return days


def _entry_hours(trades: Sequence[Trade]) -> set[int]:
    hours: set[int] = set()
    for trade in trades:
        stamp = trade.entry_time if trade.entry_time is not None else trade.time
        hours.add(dt.datetime.fromtimestamp(int(stamp), tz=dt.UTC).hour)
    return hours


def _median(values: Sequence[float]) -> float | None:
    ordered = sorted(values)
    n = len(ordered)
    if n == 0:
        return None
    mid = n // 2
    if n % 2 == 1:
        return float(ordered[mid])
    return float((ordered[mid - 1] + ordered[mid]) / 2.0)


def _jaccard(a: set[Any], b: set[Any]) -> float | None:
    if not a and not b:
        return None
    union = a | b
    if not union:
        return None
    return len(a & b) / len(union)


def effective_number_of_bets(
    weights: Sequence[float], sleeve_daily: Sequence[Sequence[float]]
) -> float | None:
    """Diversification-ratio effective number of independent bets.

    ENB = (sum_i w_i * sigma_i)^2 / (w^T Sigma w), the squared diversification
    ratio.  Equals the sleeve count when sleeves are uncorrelated + equal-vol, and
    collapses toward 1 as sleeves become perfectly correlated.  Deterministic.
    ``sleeve_daily`` is column-per-sleeve daily PnL on a shared grid.
    """
    n = len(weights)
    if n == 0 or not sleeve_daily:
        return None
    n_days = len(sleeve_daily)
    columns = [[float(sleeve_daily[r][c]) for r in range(n_days)] for c in range(n)]
    sigmas = [_population_std(col) for col in columns]
    numerator = sum(abs(weights[i]) * sigmas[i] for i in range(n))
    if numerator <= 0.0:
        return None
    # w^T Sigma w = variance of the weighted daily book PnL.
    book = [sum(weights[c] * columns[c][r] for c in range(n)) for r in range(n_days)]
    var_book = _population_std(book) ** 2
    if var_book <= 0.0:
        return None
    return (numerator ** 2) / var_book


def _pairwise_correlations(
    keys: Sequence[Key], columns: Sequence[Sequence[float]]
) -> tuple[list[dict[str, Any]], float | None]:
    entries: list[dict[str, Any]] = []
    abs_values: list[float] = []
    n = len(keys)
    for i in range(n):
        for j in range(i + 1, n):
            r = _pearson(columns[i], columns[j])
            entries.append({
                "a": f"{keys[i][0]}:{keys[i][1]}",
                "b": f"{keys[j][0]}:{keys[j][1]}",
                "correlation": _round(r),
            })
            if r is not None:
                abs_values.append(abs(r))
    mean_abs = (sum(abs_values) / len(abs_values)) if abs_values else None
    return entries, _round(mean_abs)


def _downside_correlations(
    keys: Sequence[Key],
    columns: Sequence[Sequence[float]],
    book_daily: Sequence[float],
) -> tuple[list[dict[str, Any]], float | None]:
    """Correlation conditioned on book-down days (an explicit downside correlation)."""
    down_idx = [r for r, pnl in enumerate(book_daily) if pnl < 0.0]
    entries: list[dict[str, Any]] = []
    abs_values: list[float] = []
    n = len(keys)
    if len(down_idx) < 2:
        return entries, None
    for i in range(n):
        for j in range(i + 1, n):
            left = [columns[i][r] for r in down_idx]
            right = [columns[j][r] for r in down_idx]
            r = _pearson(left, right)
            entries.append({
                "a": f"{keys[i][0]}:{keys[i][1]}",
                "b": f"{keys[j][0]}:{keys[j][1]}",
                "downside_correlation": _round(r),
            })
            if r is not None:
                abs_values.append(abs(r))
    mean_abs = (sum(abs_values) / len(abs_values)) if abs_values else None
    return entries, _round(mean_abs)


def _trade_overlap(
    keys: Sequence[Key], trades_by_key: Mapping[Key, Sequence[Trade]] | None
) -> tuple[list[dict[str, Any]], float | None]:
    if not trades_by_key:
        return [], None
    entry_days = {k: _entry_days(trades_by_key.get(k, [])) for k in keys}
    entries: list[dict[str, Any]] = []
    values: list[float] = []
    n = len(keys)
    for i in range(n):
        for j in range(i + 1, n):
            jac = _jaccard(entry_days[keys[i]], entry_days[keys[j]])
            entries.append({
                "a": f"{keys[i][0]}:{keys[i][1]}",
                "b": f"{keys[j][0]}:{keys[j][1]}",
                "entry_day_jaccard": _round(jac),
            })
            if jac is not None:
                values.append(jac)
    mean_val = (sum(values) / len(values)) if values else None
    return entries, _round(mean_val)


def _session_overlap(
    keys: Sequence[Key], trades_by_key: Mapping[Key, Sequence[Trade]] | None
) -> float | None:
    if not trades_by_key:
        return None
    hours = {k: _entry_hours(trades_by_key.get(k, [])) for k in keys}
    values: list[float] = []
    n = len(keys)
    for i in range(n):
        for j in range(i + 1, n):
            jac = _jaccard(hours[keys[i]], hours[keys[j]])
            if jac is not None:
                values.append(jac)
    return _round((sum(values) / len(values)) if values else None)


def _holding_hours(trades: Sequence[Trade]) -> list[float]:
    durations: list[float] = []
    for trade in trades:
        if trade.entry_time is None:
            continue
        delta = int(trade.time) - int(trade.entry_time)
        if delta >= 0:
            durations.append(delta / 3600.0)
    return durations


def book_by_date(
    keys: Sequence[Key],
    weights: Mapping[Key, float],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
) -> dict[dt.date, float]:
    """Weighted book daily PnL keyed by date over the roster's common window.

    Deterministic; used by ``materiality`` to align two rosters on their common
    dates for the difference series.
    """
    ordered = sorted((int(e), str(s)) for e, s in keys)
    if not ordered or any(not daily_by_key.get(k) for k in ordered):
        return {}
    start = max(min(daily_by_key[k]) for k in ordered)
    end = min(max(daily_by_key[k]) for k in ordered)
    grid = shared_day_grid(daily_by_key, ordered, start, end)
    grid_keys, matrix = matrix_on_grid(daily_by_key, ordered, grid)
    weight_map = {k: float(weights[k]) for k in grid_keys}
    book = portfolio_daily(grid_keys, matrix, weight_map)
    return dict(zip(grid, book))


def compute_roster_metrics(
    keys: Sequence[Key],
    weights: Mapping[Key, float],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
    *,
    trades_by_key: Mapping[Key, Sequence[Trade]] | None = None,
    starting_capital: float = STARTING_CAPITAL,
) -> dict[str, Any]:
    """Deterministic section 7 metric vector for a roster.

    ``keys`` must all have non-empty daily streams in ``daily_by_key``.  ``weights``
    are per-sleeve risk-percents (book convention).  A roster of one pair is valid;
    correlation-family metrics degrade to ``None`` when undefined (single sleeve,
    no shared history), never invented.
    """
    ordered = sorted((int(e), str(s)) for e, s in keys)
    if not ordered:
        return {"status": "EMPTY_ROSTER", "n_sleeves": 0}
    missing = [k for k in ordered if not daily_by_key.get(k)]
    if missing:
        raise ValueError(f"roster metrics require non-empty streams; missing: {missing!r}")

    start = max(min(daily_by_key[k]) for k in ordered)
    end = min(max(daily_by_key[k]) for k in ordered)
    grid = shared_day_grid(daily_by_key, ordered, start, end)
    grid_keys, matrix = matrix_on_grid(daily_by_key, ordered, grid)
    weight_vec = [float(weights[k]) for k in grid_keys]
    book_daily = portfolio_daily(grid_keys, matrix, {k: float(weights[k]) for k in grid_keys})

    base = book_metrics(book_daily, len(grid_keys), starting_capital)
    n_days = len(book_daily)
    years = max(n_days / TRADING_DAYS_PER_YEAR, 1.0 / TRADING_DAYS_PER_YEAR)

    daily_pct = [v / starting_capital * 100.0 for v in book_daily]
    vol_annual_pct = _population_std(daily_pct) * math.sqrt(TRADING_DAYS_PER_YEAR)
    ordered_pct = sorted(daily_pct)
    tail_cut = max(1, int(math.ceil(0.05 * len(ordered_pct)))) if ordered_pct else 0
    tail_slice = ordered_pct[:tail_cut]
    tail_loss_pct = (sum(tail_slice) / len(tail_slice)) if tail_slice else None

    columns = [[matrix[r][c] for r in range(n_days)] for c in range(len(grid_keys))]
    pair_entries, mean_abs_corr = _pairwise_correlations(grid_keys, columns)
    down_entries, mean_abs_down = _downside_correlations(grid_keys, columns, book_daily)
    enb = effective_number_of_bets(weight_vec, matrix)
    overlap_entries, mean_overlap = _trade_overlap(grid_keys, trades_by_key)
    session_overlap = _session_overlap(grid_keys, trades_by_key)

    symbols = sorted({_bare_symbol(s) for _e, s in grid_keys})
    symbol_exposure: dict[str, float] = {}
    for k in grid_keys:
        sym = _bare_symbol(k[1])
        symbol_exposure[sym] = symbol_exposure.get(sym, 0.0) + float(weights[k])
    symbol_exposure = {k: _round(v) for k, v in sorted(symbol_exposure.items())}

    total_trades = 0
    holding_all: list[float] = []
    total_cost = 0.0
    have_trades = trades_by_key is not None
    if have_trades:
        # ``Trade.commission_cost`` is the modelled round-trip transaction cost.
        # Swap is not carried on the Trade model, so it is reported as
        # EVIDENCE_MISSING rather than invented as zero.
        for k in grid_keys:
            tr = trades_by_key.get(k, [])
            total_trades += len(tr)
            holding_all.extend(_holding_hours(tr))
            for t in tr:
                total_cost += float(t.commission_cost)

    metrics: dict[str, Any] = {
        "schema": "qm.recompose-roster-metrics/v1",
        "n_sleeves": len(grid_keys),
        "n_days": n_days,
        "years": _round(years, 6),
        "window": {"start": grid[0].isoformat(), "end": grid[-1].isoformat()},
        "total_risk_pct": _round(sum(weight_vec)),
        "expected_return_annual_pct": base.get("annual_return_pct"),
        "volatility_annual_pct": _round(vol_annual_pct),
        "max_drawdown_pct": base.get("max_drawdown_pct"),
        "worst_day_pct": base.get("worst_day_pct"),
        "tail_loss_es5_pct": _round(tail_loss_pct),
        "sharpe": base.get("sharpe"),
        "return_to_maxdd": base.get("return_to_maxdd"),
        "total_net_of_cost_profit": base.get("total_net_of_cost_profit"),
        "mean_abs_pairwise_correlation": mean_abs_corr,
        "mean_abs_downside_correlation": mean_abs_down,
        "effective_number_of_bets": _round(enb),
        "mean_trade_overlap_jaccard": mean_overlap if have_trades else "EVIDENCE_MISSING",
        "session_overlap_jaccard": session_overlap if have_trades else "EVIDENCE_MISSING",
        "symbols": symbols,
        "symbol_exposure_risk_pct": symbol_exposure,
        "trade_frequency_per_year": _round(total_trades / years) if have_trades else "EVIDENCE_MISSING",
        "median_holding_hours": _round(_median(holding_all)) if have_trades else "EVIDENCE_MISSING",
        "transaction_cost_total": _round(total_cost) if have_trades else "EVIDENCE_MISSING",
        "swap_cost_total": "EVIDENCE_MISSING",
        "pairwise_correlation_panel": pair_entries,
        "downside_correlation_panel": down_entries,
        "trade_overlap_panel": overlap_entries if have_trades else [],
        "book_daily_pnl": [_round(v, 6) for v in book_daily],
    }
    return metrics
