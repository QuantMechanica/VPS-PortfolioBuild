#!/usr/bin/env python3
"""Read-only loaders + headline builder for the Continuous Book Evolution surfaces.

OWNER-DEC-CBE-20260915 replaced the "Way to 25" objective headline on the
generated operator surfaces (Morning Briefing, Heartbeat) with a Continuous Book
Evolution headline sourced from a set of read-model JSON files under
``D:/QM/reports/state``.  This module is the single, deterministic place that:

  * reads each read-model with a fail-soft ``EVIDENCE_MISSING`` fallback (a
    missing/unreadable/absent file is NOT an error -- the headline degrades
    gracefully), and
  * flattens the four headline facets (DXZ, FTMO, Research, Factory) into short
    text lines that both the plain-text and HTML/Markdown renderers reuse.

It never writes anything, never opens the farm DB, and never invents values: an
absent value is reported literally as ``EVIDENCE_MISSING``.

Shared read-model contract (see the slice brief).  Consumers tolerate absence:

  * ``book_evolution_dxz.json``      schema ``qm.book-evolution-venue/v1``
  * ``book_evolution_ftmo.json``     schema ``qm.book-evolution-venue/v1``
  * ``ftmo_challenge_readiness.json``schema ``qm.ftmo-challenge-readiness/v1``
  * ``research_state.json``          schema ``qm.research-state/v1``
  * ``factory_bottleneck.json``      schema ``qm.factory-bottleneck/v1``
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

DEFAULT_STATE_DIR = Path(r"D:/QM/reports/state")

MISSING = "EVIDENCE_MISSING"

# Read-model file names keyed by a short logical name.
READ_MODELS = {
    "dxz": "book_evolution_dxz.json",
    "ftmo_book": "book_evolution_ftmo.json",
    "ftmo_readiness": "ftmo_challenge_readiness.json",
    "research": "research_state.json",
    "factory": "factory_bottleneck.json",
}


def load_read_model(name: str, state_dir: Path | str = DEFAULT_STATE_DIR) -> dict[str, Any] | None:
    """Return a read-model dict, or ``None`` when absent/unreadable.

    Fail-soft by design: a missing file, a permission error, invalid JSON or a
    non-object top level all resolve to ``None`` so callers can substitute
    ``EVIDENCE_MISSING`` without a traceback.
    """
    filename = READ_MODELS.get(name, name)
    path = Path(state_dir) / filename
    try:
        with path.open(encoding="utf-8-sig") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def _get(obj: Any, *keys: str, default: Any = None) -> Any:
    """Nested ``.get`` that tolerates missing/None intermediate dicts."""
    cur = obj
    for key in keys:
        if not isinstance(cur, dict):
            return default
        cur = cur.get(key)
    return default if cur is None else cur


def _facet(name: str, label: str, detail: str, **extra: Any) -> dict[str, Any]:
    """Assemble a facet dict with both a prefixed ``text`` and a bare ``detail``.

    ``text`` (``"<Label>: <detail>"``) is self-labeling for un-labeled contexts
    (plain-text briefing); ``detail`` omits the prefix for contexts that render
    their own bold label (heartbeat bullets, HTML rows) to avoid a double prefix.
    """
    return {
        "facet": name,
        "label": label,
        "detail": detail,
        "text": f"{label}: {detail}",
        **extra,
    }


def _dxz_line(state_dir: Path | str) -> dict[str, Any]:
    model = load_read_model("dxz", state_dir)
    if model is None:
        return _facet("dxz", "DXZ", MISSING, available=False)
    sleeves = _get(model, "incumbent", "sleeve_count", default=MISSING)
    outcome = _get(model, "proposal", "outcome", default=MISSING)
    next_recomp = model.get("next_recomposition_utc") or MISSING
    return _facet(
        "dxz", "DXZ",
        f"{sleeves} incumbent sleeves · proposal {outcome} · "
        f"next recomposition {next_recomp}",
        available=True,
        sleeve_count=sleeves,
        proposal_outcome=outcome,
        next_recomposition_utc=next_recomp,
    )


def _ftmo_line(state_dir: Path | str) -> dict[str, Any]:
    # Prefer the challenge-readiness read-model for the recommendation enum and
    # validation-day count; fall back to the FTMO book-evolution model's mirror.
    readiness = load_read_model("ftmo_readiness", state_dir)
    book = load_read_model("ftmo_book", state_dir)
    if readiness is None and book is None:
        return _facet("ftmo", "FTMO", MISSING, available=False)
    recommendation = (
        (readiness or {}).get("recommendation")
        or _get(book, "proposal", "outcome")
        or MISSING
    )
    validation_days = (
        _get(readiness, "demo_cycle", "validation_days")
        if readiness is not None
        else _get(book, "demo_cycle", "validation_days")
    )
    if validation_days is None:
        validation_days = MISSING
    return _facet(
        "ftmo", "FTMO",
        f"{recommendation} · validation day {validation_days}",
        available=True,
        recommendation=recommendation,
        validation_days=validation_days,
    )


def _research_line(state_dir: Path | str) -> dict[str, Any]:
    model = load_read_model("research", state_dir)
    if model is None:
        return _facet("research", "Research", MISSING, available=False)
    campaigns = model.get("kimi_campaigns") or []
    active = [
        c for c in campaigns
        if isinstance(c, dict) and str(c.get("status") or "").lower() in {"active", "running", "in_progress"}
    ]
    programmes = model.get("programmes") or []
    active_programmes = [
        p for p in programmes
        if isinstance(p, dict) and str(p.get("status") or "").lower() in {"active", "running", "in_progress"}
    ]
    return _facet(
        "research", "Research",
        f"{len(active)} active campaigns · {len(active_programmes)} active programmes",
        available=True,
        active_campaigns=len(active),
        active_programmes=len(active_programmes),
    )


def _factory_line(state_dir: Path | str) -> dict[str, Any]:
    model = load_read_model("factory", state_dir)
    if model is None:
        return _facet("factory", "Factory", MISSING, available=False)
    bottlenecks = model.get("bottlenecks") or []
    top = bottlenecks[0] if bottlenecks and isinstance(bottlenecks[0], dict) else None
    if top is None:
        name = MISSING
    else:
        name = top.get("name") or MISSING
    return _facet(
        "factory", "Factory",
        f"top bottleneck {name}",
        available=True,
        top_bottleneck=name,
    )


def book_evolution_headline(state_dir: Path | str = DEFAULT_STATE_DIR) -> dict[str, Any]:
    """Return the four Continuous Book Evolution headline facets.

    Every facet is always present; a facet whose read-model is absent carries
    ``available: False`` and an ``EVIDENCE_MISSING`` text so the caller can render
    it without any conditional logic.
    """
    return {
        "schema": "qm.book-evolution-headline/v1",
        "dxz": _dxz_line(state_dir),
        "ftmo": _ftmo_line(state_dir),
        "research": _research_line(state_dir),
        "factory": _factory_line(state_dir),
    }


def headline_lines(state_dir: Path | str = DEFAULT_STATE_DIR) -> list[str]:
    """Flatten the headline into the four ordered text lines used by surfaces."""
    head = book_evolution_headline(state_dir)
    return [head[facet]["text"] for facet in ("dxz", "ftmo", "research", "factory")]


__all__ = [
    "DEFAULT_STATE_DIR",
    "MISSING",
    "READ_MODELS",
    "load_read_model",
    "book_evolution_headline",
    "headline_lines",
]
