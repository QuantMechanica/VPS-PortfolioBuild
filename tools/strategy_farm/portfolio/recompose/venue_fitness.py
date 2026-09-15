"""Venue fitness registry (section 57): DXZ and FTMO objectives are SEPARATE.

The two production books are *not the same optimization problem* (directive section 5).
This registry dispatches to the venue objective:

* ``dxz``  -> ``dxz_fitness.compute_dxz_fitness`` (portfolio return/maxDD/diversification),
* ``ftmo`` -> ``tools/strategy_farm/ftmo/ftmo_fitness.py:compute_ftmo_fitness`` (challenge
  first-passage / survival), imported LAZILY.  Slice F1 builds that module in parallel;
  until it lands, the FTMO objective degrades to ``NOT_EVALUATED`` (never invented, never
  substituted with the DXZ objective).

A registered override may be injected for testing (``register_venue_fitness``); this is how
the "venue fitness remains separate" property is exercised without the F1 module present.
"""
from __future__ import annotations

import importlib
from pathlib import Path
from typing import Any, Callable, Mapping

try:  # package import
    from .dxz_fitness import compute_dxz_fitness
except ImportError:  # pragma: no cover - direct script execution
    from dxz_fitness import compute_dxz_fitness  # type: ignore

FitnessFn = Callable[..., dict[str, Any]]

_OVERRIDES: dict[str, FitnessFn] = {}


def register_venue_fitness(venue: str, fn: FitnessFn | None) -> None:
    """Inject (or with ``None`` clear) a venue fitness function. Test hook only."""
    venue = str(venue).lower()
    if fn is None:
        _OVERRIDES.pop(venue, None)
    else:
        _OVERRIDES[venue] = fn


def _not_evaluated(reason: str, venue: str) -> dict[str, Any]:
    return {"venue": venue, "objective": "NOT_EVALUATED", "reason": reason}


def _load_ftmo_fitness() -> FitnessFn | None:
    """Lazy import of the F1-owned FTMO fitness module; None when absent."""
    try:  # normal package layout: tools/strategy_farm on sys.path
        module = importlib.import_module("ftmo.ftmo_fitness")
    except Exception:  # noqa: BLE001 - any import failure degrades gracefully
        try:
            import sys

            farm_root = Path(__file__).resolve().parents[2]
            if str(farm_root) not in sys.path:
                sys.path.insert(0, str(farm_root))
            module = importlib.import_module("ftmo.ftmo_fitness")
        except Exception:  # noqa: BLE001
            return None
    fn = getattr(module, "compute_ftmo_fitness", None)
    return fn if callable(fn) else None


def compute_venue_fitness(
    venue: str,
    metrics: Mapping[str, Any],
    *,
    snapshot: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Dispatch to the venue objective. Returns NOT_EVALUATED when unavailable."""
    venue = str(venue).lower()
    if venue in _OVERRIDES:
        return _OVERRIDES[venue](metrics, snapshot=snapshot) if _accepts_snapshot(
            _OVERRIDES[venue]
        ) else _OVERRIDES[venue](metrics)

    if venue == "dxz":
        return compute_dxz_fitness(metrics)

    if venue == "ftmo":
        fn = _load_ftmo_fitness()
        if fn is None:
            return _not_evaluated("ftmo_fitness_module_absent (slice F1 not landed)", venue)
        try:
            # F1 contract: compute_ftmo_fitness(snapshot: dict) -> dict
            payload = dict(snapshot) if isinstance(snapshot, Mapping) else {}
            payload.setdefault("metrics", dict(metrics))
            return fn(payload)
        except Exception as exc:  # noqa: BLE001 - never let F1 errors abort DXZ evaluation
            return _not_evaluated(f"ftmo_fitness_error: {type(exc).__name__}: {exc}", venue)

    return _not_evaluated(f"unknown_venue:{venue}", venue)


def _accepts_snapshot(fn: FitnessFn) -> bool:
    try:
        import inspect

        return "snapshot" in inspect.signature(fn).parameters
    except (ValueError, TypeError):  # pragma: no cover
        return False
