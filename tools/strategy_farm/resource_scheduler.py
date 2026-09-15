#!/usr/bin/env python
"""Resource-aware admission scheduler (OWNER directive 3, 2026-09-15 §12, §13, §44G).

Pure, deterministic decision logic for the factory's claim path.  The design
objective (directive §12) is: "A single 44-GB-class job must not head-of-line
block multiple terminals when many smaller useful jobs can run ... fill available
capacity with the highest-value combination of runnable jobs.  Heavy jobs may run
alone, in quieter windows, with reduced worker concurrency, while smaller jobs
fill remaining capacity."

This module owns ONLY the decision math; the worker
(``terminal_worker.py``) owns all I/O (RAM probe, DB survey, drain state).  Every
function here is pure over its arguments so the fixtures in
``tests/test_resource_scheduler.py`` reproduce the exact scenarios the slice
enumerates.

Kill switch: ``QM_RESOURCE_SCHEDULER`` unset or ``0`` -> ``is_enabled()`` returns
False and the worker's existing behaviour runs unchanged (the worker guards every
call site on ``is_enabled()``).

Knobs live in ``config/factory_scheduler.v1.json``; ``load_config`` fails open to
the built-in defaults, whose values reproduce today's behaviour when the kill
switch is off.
"""
from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ENV_KILL_SWITCH = "QM_RESOURCE_SCHEDULER"
CONFIG_SCHEMA = "qm.factory-scheduler/v1"
DEFAULT_CONFIG_PATH = str(
    Path(__file__).resolve().parent / "config" / "factory_scheduler.v1.json"
)

# Built-in defaults; overridden by config/factory_scheduler.v1.json.  Chosen so
# that with the kill switch OFF nothing changes, and with it ON the head-of-line
# block is broken conservatively.
DEFAULT_CONFIG: dict[str, Any] = {
    "schema": CONFIG_SCHEMA,
    # A candidate is "heavy" (may need the exclusive pre-drain) at/above this
    # reservation.  Matches terminal_worker's DRAIN_WINDOW_MIN_RESERVATION_GB.
    "heavy_reservation_gb": 24.0,
    # RAM that must remain free AFTER a candidate's reservation for it to "fit".
    # Matches terminal_worker RAM_MIN_FREE_GB.
    "fit_post_reservation_floor_gb": 14.0,
    # "Quiet window": a heavy candidate may open a pre-drain only when fewer than
    # this many cells are active fleet-wide (directive: heavy jobs run in quieter
    # windows / with reduced concurrency).
    "quiet_window_max_active_cells": 2,
    # How many head-window candidates the worker surveys for a fitting smaller
    # job.  Widens the legacy top-3 preflight (directive §12).
    "head_window_candidates": 12,
    # Starvation guard: a heavy candidate continuously suppressed for this long
    # is allowed to open a pre-drain regardless of fill, so heavy work never
    # starves.  Bounded; logged by the worker.
    "heavy_starvation_max_wait_minutes": 45.0,
    # Value ranking weight: value = priority + frontier_weight * frontier_gate.
    # Frontier weighting keeps the highest-leverage band (directive: advancing
    # the largest frontier band is the highest-leverage compute) preferred among
    # equally-fitting candidates.  Facts-only ranking; never a verdict.
    "frontier_weight": 0.0,
}


def is_enabled(env: dict[str, str] | None = None) -> bool:
    """Kill switch. Default OFF: QM_RESOURCE_SCHEDULER must be a truthy non-'0'."""
    src = env if env is not None else os.environ
    raw = str(src.get(ENV_KILL_SWITCH, "0")).strip().lower()
    return raw not in ("", "0", "false", "off", "no")


def load_config(path: str | Path | None = None) -> dict[str, Any]:
    """Load scheduler config, fail-open to DEFAULT_CONFIG on any error."""
    cfg = dict(DEFAULT_CONFIG)
    p = Path(path or DEFAULT_CONFIG_PATH)
    try:
        with open(p, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            for key in DEFAULT_CONFIG:
                if key in data and key != "schema":
                    cfg[key] = data[key]
    except (OSError, ValueError, TypeError):
        return dict(DEFAULT_CONFIG)
    return cfg


@dataclass(frozen=True)
class Candidate:
    """A claimable head-window row descriptor (facts only, built by the worker)."""

    item_id: str
    reservation_gb: float
    priority: float = 0.0
    frontier_gate: float = 0.0
    ea_id: str = ""

    def value(self, cfg: dict[str, Any]) -> float:
        return float(self.priority) + float(cfg.get("frontier_weight", 0.0)) * float(
            self.frontier_gate
        )

    def fits(self, free_ram_gb: float, cfg: dict[str, Any]) -> bool:
        floor = float(cfg.get("fit_post_reservation_floor_gb", 14.0))
        try:
            return float(free_ram_gb) - float(self.reservation_gb) >= floor
        except (TypeError, ValueError):
            return False

    def is_heavy(self, cfg: dict[str, Any]) -> bool:
        try:
            return float(self.reservation_gb) >= float(
                cfg.get("heavy_reservation_gb", 24.0)
            )
        except (TypeError, ValueError):
            return False


@dataclass
class AdmissionPlan:
    """Bin-packing result over the head window."""

    chosen: Candidate | None
    fitting_smaller: list[Candidate] = field(default_factory=list)
    skipped_no_fit: list[Candidate] = field(default_factory=list)
    reason: str = ""


def plan_head_window(
    candidates: list[Candidate],
    *,
    free_ram_gb: float,
    cfg: dict[str, Any],
) -> AdmissionPlan:
    """Choose the highest-value candidate that FITS the current headroom.

    Bin-packing selection over the claimable head window: a candidate that does
    not fit is recorded as skipped WITHOUT any drain being opened (directive
    §12).  Deterministic tie-break: higher value, then lower reservation, then
    item_id.
    """
    fitting = [c for c in candidates if c.fits(free_ram_gb, cfg)]
    not_fitting = [c for c in candidates if not c.fits(free_ram_gb, cfg)]
    if not fitting:
        return AdmissionPlan(
            chosen=None,
            fitting_smaller=[],
            skipped_no_fit=sorted(not_fitting, key=lambda c: c.item_id),
            reason="no_fitting_candidate",
        )
    chosen = sorted(
        fitting,
        key=lambda c: (-c.value(cfg), float(c.reservation_gb), c.item_id),
    )[0]
    smaller = sorted(
        [c for c in fitting if c.item_id != chosen.item_id],
        key=lambda c: c.item_id,
    )
    return AdmissionPlan(
        chosen=chosen,
        fitting_smaller=smaller,
        skipped_no_fit=sorted(not_fitting, key=lambda c: c.item_id),
        reason="fitting_candidate_selected",
    )


@dataclass
class PredrainDecision:
    """Whether a heavy candidate may open the exclusive pre-drain right now."""

    arm_allowed: bool
    reason: str
    tracking_out: dict[str, Any]


def predrain_decision(
    heavy: Candidate,
    *,
    window_candidates: list[Candidate],
    free_ram_gb: float,
    active_cells: int,
    tracking: dict[str, Any] | None,
    now_epoch: float,
    cfg: dict[str, Any],
) -> PredrainDecision:
    """Decide whether the heavy candidate may open the exclusive pre-drain.

    Rules (directive §12, slice 2b/2d):

      * A heavy candidate opens the exclusive pre-drain ONLY when no *fitting
        smaller* candidate exists in the head window AND the fleet is in a quiet
        window (fewer than ``quiet_window_max_active_cells`` active cells).
      * Otherwise it WAITS (the worker does not arm a pre-drain this pass), so
        the fitting smaller candidates keep the terminals busy.
      * Starvation guard: a heavy candidate continuously suppressed for at least
        ``heavy_starvation_max_wait_minutes`` is allowed to open a pre-drain
        regardless of fill (bounded, logged).

    ``tracking`` is the scheduler's small per-heavy-EA sidecar
    (``{ea_id: {"first_suppressed_epoch": float}}``) that the worker persists
    across passes; this function returns the updated copy.  Pure over inputs.
    """
    track = dict(tracking or {})
    ea_key = str(heavy.ea_id or heavy.item_id)

    # A fitting smaller candidate is any fitting head-window row that is NOT the
    # heavy row itself (by item_id) and is not itself heavy.
    fitting_smaller = [
        c
        for c in window_candidates
        if c.item_id != heavy.item_id
        and not c.is_heavy(cfg)
        and c.fits(free_ram_gb, cfg)
    ]
    quiet = int(active_cells) < int(cfg.get("quiet_window_max_active_cells", 2))

    # Starvation override first: if we have been suppressing this heavy row for
    # long enough, allow it regardless of fill/quiet.
    max_wait_s = float(cfg.get("heavy_starvation_max_wait_minutes", 45.0)) * 60.0
    prev = track.get(ea_key)
    first_suppressed = None
    if isinstance(prev, dict):
        try:
            first_suppressed = float(prev.get("first_suppressed_epoch"))
        except (TypeError, ValueError):
            first_suppressed = None

    would_suppress = bool(fitting_smaller) or not quiet

    if not would_suppress:
        # No reason to suppress: heavy may arm; clear any tracking.
        track.pop(ea_key, None)
        reason = "quiet_window_no_fitting_smaller"
        return PredrainDecision(arm_allowed=True, reason=reason, tracking_out=track)

    # would_suppress is True -> check starvation override.
    if first_suppressed is not None and math.isfinite(first_suppressed):
        waited = float(now_epoch) - first_suppressed
        if waited >= max_wait_s:
            track.pop(ea_key, None)
            return PredrainDecision(
                arm_allowed=True,
                reason=f"starvation_guard_override:waited_{int(waited)}s",
                tracking_out=track,
            )
    else:
        first_suppressed = float(now_epoch)

    track[ea_key] = {"first_suppressed_epoch": first_suppressed}
    if fitting_smaller:
        reason = f"suppressed_fitting_smaller_exists:{len(fitting_smaller)}"
    else:
        reason = f"suppressed_fleet_busy:active_cells={int(active_cells)}"
    return PredrainDecision(arm_allowed=False, reason=reason, tracking_out=track)


def prune_tracking(
    tracking: dict[str, Any] | None,
    *,
    live_heavy_ea_keys: set[str],
) -> dict[str, Any]:
    """Drop tracking entries for heavy rows no longer present (bounded state)."""
    track = dict(tracking or {})
    for key in list(track.keys()):
        if key not in live_heavy_ea_keys:
            track.pop(key, None)
    return track
