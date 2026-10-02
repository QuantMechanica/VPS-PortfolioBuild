"""Pre-Q00 Internal Edge Discovery research package (slice C5).

This package implements the deterministic, read-only research substrate for the
OBSERVE -> DISCOVER -> HYPOTHESIZE -> MECHANIZE -> ATTACK -> PRE-REGISTER stages
described in ``docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`` (FINAL v1) and authorized
by ``decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md``.

Hard invariants honoured by every module here:

* It never writes a gate verdict, never mutates ``farm_state.sqlite``, adds no
  second SQLite DB, and touches no gate threshold or contract criterion (ROT).
  All new state is append-only JSONL ledgers plus rebuildable projections.
* It reads ``farm_state.sqlite`` read-only (``mode=ro`` + ``PRAGMA query_only``)
  via the existing ``work_item_clean_view`` TEMP view, and never re-walks the
  gzip evidence trees at runtime.
* The only runtime write the package performs is provisioning the research venv
  (``research_env.provision_venv``); the farm Python311 runtime is never touched.

The modules carry no dependency on pandas/scipy/sklearn so the projectors run on
the farm Python (stdlib ``csv`` + ``sqlite3`` only); the heavier DISCOVER ML work
runs under the separate uv-managed venv created by :mod:`research_env`.
"""

from __future__ import annotations

__all__ = [
    "observe_projector",
    "research_env",
    "search_history_ledger",
    "experiment_memory",
    "preregister",
    "mechanization_check",
]
