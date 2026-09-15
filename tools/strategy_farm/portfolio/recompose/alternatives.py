"""Candidate roster enumeration + deterministic weighting (section 7/58).

Builds the set of portfolio alternatives the recomposition compares against the
incumbent:

* the incumbent itself (baseline),
* incumbent + each challenger (ADD_SLEEVE),
* incumbent - each weakest incumbent sleeve (REMOVE_SLEEVE),
* incumbent - weakest + challenger (REPLACE_SLEEVE), bounded.

Weights come from the existing ``book_builder_common.capped_inverse_vol`` allocator
(capped inverse-daily-volatility on the sealed daily-PnL matrix) under a fixed total
risk budget and per-sleeve cap.  Deterministic: identical inputs -> identical rosters
and weights.  Challengers/weakest are ranked deterministically.
"""
from __future__ import annotations

import datetime as dt
import math
from typing import Any, Mapping, Sequence

try:  # package import
    from ..book_builder_common import (
        capped_inverse_vol,
        matrix_on_grid,
        shared_day_grid,
    )
except ImportError:  # pragma: no cover - direct script execution
    from book_builder_common import (  # type: ignore
        capped_inverse_vol,
        matrix_on_grid,
        shared_day_grid,
    )

Key = tuple[int, str]

DEFAULT_MAX_WEAKEST = 3
DEFAULT_SLEEVE_CAP = 1.5


def _std(values: Sequence[float]) -> float:
    n = len(values)
    if n == 0:
        return 0.0
    mean = sum(values) / n
    return math.sqrt(sum((v - mean) ** 2 for v in values) / n)


def _standalone_sharpe(daily: Mapping[dt.date, float]) -> float:
    values = list(daily.values())
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    std = _std(values)
    if std <= 0.0:
        return 0.0
    return mean / std * math.sqrt(252.0)


def weights_for(
    keys: Sequence[Key],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
    *,
    total_risk_budget: float,
    sleeve_cap: float = DEFAULT_SLEEVE_CAP,
) -> dict[Key, float]:
    """Capped inverse-volatility risk-percent weights for a roster (deterministic)."""
    ordered = sorted((int(e), str(s)) for e, s in keys)
    if not ordered:
        return {}
    start = max(min(daily_by_key[k]) for k in ordered)
    end = min(max(daily_by_key[k]) for k in ordered)
    grid = shared_day_grid(daily_by_key, ordered, start, end)
    grid_keys, matrix = matrix_on_grid(daily_by_key, ordered, grid)
    # Ensure the per-sleeve cap can absorb the whole budget for tiny rosters.
    effective_cap = max(sleeve_cap, total_risk_budget / len(grid_keys))
    return capped_inverse_vol(
        grid_keys, matrix, total=total_risk_budget, cap=effective_cap
    )


def rank_weakest(
    incumbent_keys: Sequence[Key],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
) -> list[Key]:
    """Incumbent sleeves ordered weakest-first by standalone Sharpe (deterministic)."""
    scored = [
        (k, _standalone_sharpe(daily_by_key.get(k, {})))
        for k in sorted((int(e), str(s)) for e, s in incumbent_keys)
    ]
    scored.sort(key=lambda item: (item[1], item[0]))
    return [k for k, _s in scored]


def enumerate_alternatives(
    incumbent_keys: Sequence[Key],
    qualified_keys: Sequence[Key],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
    *,
    total_risk_budget: float,
    sleeve_cap: float = DEFAULT_SLEEVE_CAP,
    max_weakest: int = DEFAULT_MAX_WEAKEST,
) -> list[dict[str, Any]]:
    """Enumerate incumbent + add/remove/replace alternatives with weights.

    Only keys with a non-empty stream in ``daily_by_key`` are usable; a challenger or
    incumbent without a stream is skipped for weighting (recorded by the caller).
    """
    incumbent = sorted(
        (int(e), str(s)) for e, s in incumbent_keys if daily_by_key.get((int(e), str(s)))
    )
    qualified = sorted(
        (int(e), str(s)) for e, s in qualified_keys if daily_by_key.get((int(e), str(s)))
    )
    incumbent_set = set(incumbent)
    challengers = [k for k in qualified if k not in incumbent_set]
    weakest = rank_weakest(incumbent, daily_by_key)[:max_weakest]

    alternatives: list[dict[str, Any]] = []

    def _emit(label: str, keys: list[Key], change: dict[str, Any]) -> None:
        keys = sorted(set(keys))
        if not keys:
            return
        weights = weights_for(
            keys, daily_by_key, total_risk_budget=total_risk_budget, sleeve_cap=sleeve_cap
        )
        alternatives.append({
            "label": label,
            "keys": [list(k) for k in keys],
            "weights": {f"{k[0]}:{k[1]}": round(v, 8) for k, v in sorted(weights.items())},
            "change": change,
        })

    _emit("incumbent", incumbent, {"outcome": "KEEP", "add": [], "remove": [], "replace": []})

    for ch in challengers:
        _emit(
            f"add:{ch[0]}:{ch[1]}",
            incumbent + [ch],
            {"outcome": "ADD_SLEEVE", "add": [list(ch)], "remove": [], "replace": []},
        )

    for w in weakest:
        _emit(
            f"remove:{w[0]}:{w[1]}",
            [k for k in incumbent if k != w],
            {"outcome": "REMOVE_SLEEVE", "add": [], "remove": [list(w)], "replace": []},
        )

    for w in weakest:
        for ch in challengers:
            _emit(
                f"replace:{w[0]}:{w[1]}->{ch[0]}:{ch[1]}",
                [k for k in incumbent if k != w] + [ch],
                {
                    "outcome": "REPLACE_SLEEVE",
                    "add": [list(ch)],
                    "remove": [list(w)],
                    "replace": [{"out": list(w), "in": list(ch)}],
                },
            )

    return alternatives
