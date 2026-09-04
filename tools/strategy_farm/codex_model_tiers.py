#!/usr/bin/env python3
"""Codex model-tier resolution, 5h message ledger and fallback contract.

Specification: ``docs/ops/MODEL_ROUTING_DOCTRINE_2026-09-04.md`` section 5 (CEO
doctrine under the standing authorization, OWNER 2026-09-04). Routing is an
operating rule, not a gate criterion: nothing in this module touches Qxx
thresholds, verdicts, T_Live or money.

Two halves, deliberately separated:

* ``resolve_tier`` / ``fallback_chain`` / ``select_dispatch`` are PURE reads.
  ``select_dispatch`` previews which model would serve a task; it writes
  nothing, so a routing preview (``evaluate_spawn`` inside ``route_once``) can
  never spend budget.
* ``commit_dispatch`` (and its thin wrapper ``record_dispatch``) is the ONLY
  place a message is booked. It re-counts the rolling 5h window under an
  exclusive ledger lock and REFUSES when the budget is spent, so two parallel
  spawners cannot both read the same pre-dispatch count and both dispatch
  (fix round 2026-09-04: the first implementation counted at selection time and
  booked at spawn time, which let five concurrent slots pass one budget of two).
  Every real spawn site therefore books BEFORE it launches and calls
  ``release_dispatch`` when the launch fails.

Rollback (doctrine section 5, last bullet): ``QM_CODEX_MODEL_TIERS=0`` disables
every tier behaviour - no tier resolution, no ledger read or write, no refusal -
leaving the single configured model (``model_matrix.codex.model``, today
``gpt-5.6-sol``) exactly as it was before 2026-09-04. Round 3 (CEO decision D2)
tightened that to the argv: under the rollback EVERY Codex spawn and render site
emits its exact pre-doctrine command line, so `codex_spawn_contract` grants no
flags at all and `mailbox_source_intake` restores its own previously hardcoded
pair. The ROUTER-side changes (decision-bound lane pinning, the payload
capability union) are defect fixes and ship unconditionally - see the
`agent_router` module docstring.

CEO decisions of round 3 (2026-09-04), all implemented here:

* **D1** - the effort-class -> tier remap (max->sol, high->terra, medium->luna)
  is OPT-IN behind ``model_matrix.codex.effort_class_tier_mapping_enabled``
  (default false). With the flag false an untiered task lands on ``default_tier``
  with its EXISTING effort class, i.e. today's command line unchanged; an
  explicit ``codex_model_tier``, ``scalpel: true`` and the
  ``strategy_mechanize_source`` task type still resolve to their tiers.
* **D4** - ledger I/O fails CLOSED. A read error, a write error and an
  unresolvable policy all REFUSE the dispatch (``codex_ledger_read_error`` /
  ``codex_ledger_write_error``) instead of re-granting the whole window, and a
  corrupt line counts as consumed budget while still being reported.
* **D5** - ``scalpel`` must be JSON ``true``; any other non-boolean value holds
  the task with reason ``invalid_scalpel_marker`` rather than silently resolving
  a weaker tier.
* **D6** - ``five_hour_window_minutes`` (60..1440) and ``window_safety_factor``
  (0.1..1.0) are validated fail-closed, so a unit slip cannot remove the cap.

CEO decisions of round 4 (2026-09-04), implemented here:

* **D8** - ``read_ledger`` catches decode errors raised while ITERATING the
  file, not only around ``open()``. One invalid UTF-8 byte used to raise
  ``UnicodeDecodeError`` out through ``select_dispatch`` and abort the whole
  ``route_once`` pass for every lane; it now refuses with
  ``codex_ledger_read_error`` (enforce) or is reported (observe).
* **D9** - ``model_matrix.codex.window_enforcement_mode`` with values
  ``observe`` (DEFAULT) and ``enforce``. Observe RECORDS every dispatch and
  reports ``would_refuse`` / ``would_downgrade`` / ``over_budget`` but refuses,
  holds and downgrades NOTHING, so an untiered task keeps ``gpt-5.6-sol``
  indefinitely and an Astra task still gets Astra. Enforce is round-3
  behaviour. An unreadable mode is a fail-closed config error.
* **D11** - a ledger lock that cannot be taken fails CLOSED in enforce mode
  (``codex_ledger_lock_error``, nothing appended) and is reported in observe.
* **D12** - a corrupt line counts only while the ledger FILE's mtime is inside
  the window; a record with an unreadable ``ts`` counts conservatively;
  ``validate_matrix`` rejects two tiers sharing a model id and any fallback on
  the scalpel tier; :func:`rotate_ledger` prunes records older than 2x the
  window at commit time, under the lock.
"""

from __future__ import annotations

import contextlib
import datetime as dt
import json
import math
import os
import time
import uuid
from pathlib import Path
from typing import Any, Iterator


TIERS_ENV = "QM_CODEX_MODEL_TIERS"
LEDGER_PATH_ENV = "QM_CODEX_MODEL_LEDGER_PATH"
DEFAULT_LEDGER_PATH = Path(r"D:\QM\reports\state\codex_model_window_ledger.jsonl")
DEFAULT_WINDOW_MINUTES = 300.0
DEFAULT_SAFETY_FACTOR = 0.8
DEFAULT_PLAN_TIER = "plus"
LEDGER_LOCK_TIMEOUT_SECONDS = 10.0

# CEO decision D9 (round 4, 2026-09-04): the 5h window has two modes. OBSERVE
# (the shipped default) RECORDS every dispatch and REPORTS what enforce mode
# would have done (`would_refuse` / `would_downgrade` / `over_budget`) without
# ever refusing, holding or downgrading - an untiered task keeps `gpt-5.6-sol`
# indefinitely and a scalpel task still gets Astra. ENFORCE is the round-3
# behaviour: refuse at the budget, hold Astra, fall back for the rest.
# Round-3 finding F3: with enforcement on from day one the farm silently
# acquired an 8-message/5h model-stability window and a hard ceiling built on
# model ids nobody had verified against the account.
ENFORCEMENT_MODE_FIELD = "window_enforcement_mode"
ENFORCEMENT_OBSERVE = "observe"
ENFORCEMENT_ENFORCE = "enforce"
DEFAULT_ENFORCEMENT_MODE = ENFORCEMENT_OBSERVE
ENFORCEMENT_MODES = frozenset({ENFORCEMENT_OBSERVE, ENFORCEMENT_ENFORCE})
# CEO decision D11 (round 4): a ledger lock that cannot be taken fails CLOSED in
# enforce mode. Round-3 finding F5: `_ledger_lock` yields `unavailable:...` and
# `commit_dispatch` counted-and-appended anyway, reopening the exact double-book
# race the lock was added to close.
LEDGER_LOCK_ERROR_REASON = "codex_ledger_lock_error"
# CEO decision D12 (round 4): the ledger is pruned at commit time under the same
# lock, so a torn line from 2020 cannot hold a model shut forever and the file
# cannot grow without bound (round-3 finding F4).
LEDGER_ROTATION_KEEP_FACTOR = 2.0
LEDGER_ROTATION_MIN_LINES = 500

# Doctrine section 2: `scalpel: true` or the mechanization task type map to the
# scalpel tier, which is HELD rather than downgraded when its window is spent.
SCALPEL_TIER = "astra"
SCALPEL_TASK_TYPES = frozenset({"strategy_mechanize_source"})
SCALPEL_PAYLOAD_FIELD = "scalpel"
# Effort classes stay the EXISTING max/high/medium matrix; only the model id is
# new. max -> deep implementation, high -> standard, medium -> bulk.
EFFORT_TIERS: dict[str, str] = {"max": "sol", "high": "terra", "medium": "luna"}
TIER_REQUIRED_KEYS = frozenset({"model", "five_hour_messages", "default_reasoning_effort"})
MAX_CHAIN_DEPTH = 8
MATRIX_INCOMPLETE = "codex_model_matrix_incomplete"
WINDOW_EXHAUSTED_REASON = "codex_tier_window_exhausted"
UNKNOWN_TIER_REASON = "codex_model_tier_unknown"
UNUSABLE_TIER_REASON = "codex_model_tier_unusable"
# CEO decision D4 (round 3, 2026-09-04): ledger I/O fails CLOSED. A ledger that
# cannot be read used to report count=0, which re-granted the WHOLE 5h budget on
# every call; a ledger that could not be written was explicitly treated as "not
# a budget refusal". Both are now refusals with their own structured reason.
LEDGER_READ_ERROR_REASON = "codex_ledger_read_error"
LEDGER_WRITE_ERROR_REASON = "codex_ledger_write_error"
# CEO decision D5 (round 3, 2026-09-04): a `scalpel` marker that is not JSON
# `true` is INVALID and holds the task instead of silently resolving a weaker
# tier by effort class.
INVALID_SCALPEL_REASON = "invalid_scalpel_marker"
HOLD_CODE = "ROUTER_AWAITING_MODEL_WINDOW"
HOLD_CODE_INVALID_SCALPEL = "ROUTER_INVALID_SCALPEL_MARKER"

# CEO decision D1 (round 3, 2026-09-04): the effort-class -> tier remap is
# OPT-IN. With the flag false an untiered task keeps today's model
# (`default_tier`) and today's effort class, i.e. a byte-identical command line.
EFFORT_MAPPING_FIELD = "effort_class_tier_mapping_enabled"
# CEO decision D6 (round 3, 2026-09-04): the window arithmetic knobs are
# validated. `five_hour_window_minutes: 5` (a plausible "5 hours" unit slip)
# used to shrink the rolling window to five minutes and remove the cap.
WINDOW_MINUTES_MIN = 60.0
WINDOW_MINUTES_MAX = 1440.0
SAFETY_FACTOR_MIN = 0.1
SAFETY_FACTOR_MAX = 1.0

RECORD_KIND_DISPATCH = "dispatch"
RECORD_KIND_RELEASE = "release"


def tiers_enabled(env: dict[str, str] | None = None) -> bool:
    """False only for the explicit rollback values of ``QM_CODEX_MODEL_TIERS``."""
    source = os.environ if env is None else env
    raw = str(source.get(TIERS_ENV, "") or "").strip().lower()
    return raw not in {"0", "false", "off", "no"}


def ledger_path(
    codex_matrix: dict[str, Any] | None = None,
    env: dict[str, str] | None = None,
) -> Path:
    """Env override beats the policy field, which beats the D: default."""
    source = os.environ if env is None else env
    override = str(source.get(LEDGER_PATH_ENV, "") or "").strip()
    if override:
        return Path(override)
    configured = str((codex_matrix or {}).get("window_ledger_path") or "").strip()
    if configured:
        return Path(configured)
    return DEFAULT_LEDGER_PATH


def plan_tier(codex_matrix: dict[str, Any]) -> str:
    return str(codex_matrix.get("plan_tier") or DEFAULT_PLAN_TIER).strip().lower()


def safety_factor(codex_matrix: dict[str, Any]) -> float:
    """Interactive reserve (doctrine section 3.1): plan figure x 0.8.

    Out-of-range values never reach here in production - :func:`validate_matrix`
    rejects them fail-closed (CEO decision D6) - but the runtime guard stays so
    a hand-built matrix in a test or a probe cannot silently widen the budget.
    """
    try:
        value = float(codex_matrix.get("window_safety_factor", DEFAULT_SAFETY_FACTOR))
    except (TypeError, ValueError):
        return DEFAULT_SAFETY_FACTOR
    if not SAFETY_FACTOR_MIN <= value <= SAFETY_FACTOR_MAX:
        return DEFAULT_SAFETY_FACTOR
    return value


def window_minutes(codex_matrix: dict[str, Any]) -> float:
    """Rolling-window width in minutes, clamped to the validated 60..1440 band."""
    try:
        value = float(codex_matrix.get("five_hour_window_minutes", DEFAULT_WINDOW_MINUTES))
    except (TypeError, ValueError):
        return DEFAULT_WINDOW_MINUTES
    if not WINDOW_MINUTES_MIN <= value <= WINDOW_MINUTES_MAX:
        return DEFAULT_WINDOW_MINUTES
    return value


def effort_class_tier_mapping_enabled(codex_matrix: dict[str, Any]) -> bool:
    """CEO decision D1: is the effort-class -> tier remap switched on?

    Default FALSE. With the flag off, a task that names no ``codex_model_tier``
    resolves to ``default_tier`` (today ``sol`` / ``gpt-5.6-sol``) and keeps its
    existing max/high/medium effort, so the dispatched argv is byte-identical to
    the pre-doctrine one. Explicit tiers, ``scalpel: true`` and the
    ``strategy_mechanize_source`` task type still resolve to their tiers.
    """
    return bool((codex_matrix or {}).get(EFFORT_MAPPING_FIELD, False) is True)


def enforcement_mode(codex_matrix: dict[str, Any] | None) -> str:
    """CEO decision D9 (round 4): ``observe`` (default) or ``enforce``.

    An unreadable value resolves to the DEFAULT here; :func:`validate_matrix`
    rejects it fail-closed before the policy can load, so production never
    reaches this fallback with a typo'd mode.
    """
    raw = str((codex_matrix or {}).get(ENFORCEMENT_MODE_FIELD, "") or "").strip().lower()
    return raw if raw in ENFORCEMENT_MODES else DEFAULT_ENFORCEMENT_MODE


def _tier_value_error(name: str, cfg: dict[str, Any], allowed_efforts: set[str]) -> str | None:
    """Fix round 2026-09-04: presence of a key was never enough.

    ``{"model": ""}`` / ``{"model": None}`` / ``{"model": 7}`` passed the
    presence-only check and then failed OPEN twice downstream: the dispatcher
    emitted no ``-m`` at all (silent account default) and ``record_dispatch``
    skipped the ledger line, so that tier's 5h window was never counted.
    """
    model = cfg.get("model")
    if not isinstance(model, str) or not model.strip():
        return f"{MATRIX_INCOMPLETE}:tier_{name}_model_not_a_model_id"
    effort = cfg.get("default_reasoning_effort")
    if not isinstance(effort, str) or not effort.strip():
        return f"{MATRIX_INCOMPLETE}:tier_{name}_default_reasoning_effort_invalid"
    if allowed_efforts and effort.strip().lower() not in allowed_efforts:
        return f"{MATRIX_INCOMPLETE}:tier_{name}_default_reasoning_effort_unknown:{effort}"
    return None


def _fallback_cycle(name: str, tiers: dict[str, Any]) -> list[str] | None:
    """A cycle silently truncates the chain (`luna` disappeared); reject it."""
    seen: list[str] = []
    current: str | None = name
    while current:
        if current in seen:
            return seen + [current]
        seen.append(current)
        cfg = tiers.get(current)
        if not isinstance(cfg, dict):
            return None
        nxt = str(cfg.get("fallback_tier") or "").strip()
        current = nxt if nxt in tiers else None
    return None


def validate_matrix(codex_matrix: dict[str, Any]) -> str | None:
    """Fail-closed structural check of the tier block; ``None`` when valid.

    Every error string starts with ``codex_model_matrix_incomplete`` so the
    existing fail-closed contract of ``quota_spawn_gate.load_policy`` is kept.
    """
    tiers = codex_matrix.get("tiers")
    if not isinstance(tiers, dict) or not tiers:
        return f"{MATRIX_INCOMPLETE}:tiers_missing"
    plan = plan_tier(codex_matrix)
    if not plan:
        return f"{MATRIX_INCOMPLETE}:plan_tier_missing"
    allowed_plans = [str(item).strip().lower() for item in codex_matrix.get("allowed_plan_tiers") or []]
    if allowed_plans and plan not in allowed_plans:
        return f"{MATRIX_INCOMPLETE}:plan_tier_unknown:{plan}"
    if not str(codex_matrix.get("explicit_tier_payload_field") or "").strip():
        return f"{MATRIX_INCOMPLETE}:explicit_tier_payload_field_missing"
    allowed_efforts = {
        str(item).strip().lower()
        for item in codex_matrix.get("allowed_reasoning_efforts") or []
        if str(item).strip()
    }
    # CEO decision D12 (round 4, 2026-09-04): two tiers may not share one model
    # id. Round-3 finding F7: `tiers.sol.model = "gpt-5.6-luna"` passed
    # validation, and `commit_dispatch` then booked sol against LUNA's shared
    # window count while checking it against SOL's budget - the structural
    # guarantee this fail-closed matrix exists to give, silently removed.
    model_owner: dict[str, str] = {}
    for name in sorted(tiers):
        cfg = tiers[name]
        if not isinstance(cfg, dict):
            return f"{MATRIX_INCOMPLETE}:tier_{name}_not_object"
        missing = sorted(TIER_REQUIRED_KEYS - set(cfg))
        if missing:
            return f"{MATRIX_INCOMPLETE}:tier_{name}_missing:{','.join(missing)}"
        value_error = _tier_value_error(name, cfg, allowed_efforts)
        if value_error is not None:
            return value_error
        budgets = cfg.get("five_hour_messages")
        if not isinstance(budgets, dict) or plan not in budgets:
            return f"{MATRIX_INCOMPLETE}:tier_{name}_budget_missing:{plan}"
        for plan_key, allowance in sorted(budgets.items()):
            if isinstance(allowance, bool):
                return f"{MATRIX_INCOMPLETE}:tier_{name}_budget_not_int:{plan_key}"
            try:
                parsed = int(allowance)
            except (TypeError, ValueError):
                return f"{MATRIX_INCOMPLETE}:tier_{name}_budget_not_int:{plan_key}"
            if parsed < 0:
                return f"{MATRIX_INCOMPLETE}:tier_{name}_budget_negative:{plan_key}"
        model_id = str(cfg.get("model")).strip().lower()
        if model_id in model_owner:
            return (
                f"{MATRIX_INCOMPLETE}:duplicate_model_id:{model_id}:"
                f"{model_owner[model_id]},{name}"
            )
        model_owner[model_id] = name
        for key in ("fallback_tier", "legacy_fallback_tier"):
            reference = cfg.get(key)
            if reference in (None, ""):
                continue
            # CEO decision D12: the scalpel tier carries NO fallback at all.
            # Round-3 finding F7: an `astra.fallback_tier` passed validation and
            # was inert only because `select_dispatch` hard-codes a single-entry
            # chain for the scalpel tier - `fallback_chain` and `commit_dispatch`
            # have no scalpel notion, so the hold-not-downgrade invariant lived
            # at ONE call site instead of in the data model.
            if name == SCALPEL_TIER:
                return f"{MATRIX_INCOMPLETE}:tier_{name}_{key}_forbidden:{reference}"
            if str(reference) not in tiers:
                return f"{MATRIX_INCOMPLETE}:tier_{name}_{key}_unknown:{reference}"
        cycle = _fallback_cycle(name, tiers)
        if cycle is not None:
            return f"{MATRIX_INCOMPLETE}:tier_{name}_fallback_cycle:{'>'.join(cycle)}"
    default_tier = str(codex_matrix.get("default_tier") or "").strip()
    if default_tier and default_tier not in tiers:
        return f"{MATRIX_INCOMPLETE}:default_tier_unknown:{default_tier}"
    # CEO decision D6 (round 3, 2026-09-04): the window arithmetic knobs are
    # part of the fail-closed matrix. A unit slip in either of them removes the
    # 5h cap without any error, which is exactly the class this gate exists for.
    if "five_hour_window_minutes" in codex_matrix:
        raw_minutes = codex_matrix.get("five_hour_window_minutes")
        if isinstance(raw_minutes, bool) or not isinstance(raw_minutes, (int, float)):
            return f"{MATRIX_INCOMPLETE}:five_hour_window_minutes_not_a_number:{raw_minutes}"
        if not WINDOW_MINUTES_MIN <= float(raw_minutes) <= WINDOW_MINUTES_MAX:
            return f"{MATRIX_INCOMPLETE}:five_hour_window_minutes_out_of_range:{raw_minutes}"
    if "window_safety_factor" in codex_matrix:
        raw_factor = codex_matrix.get("window_safety_factor")
        if isinstance(raw_factor, bool) or not isinstance(raw_factor, (int, float)):
            return f"{MATRIX_INCOMPLETE}:window_safety_factor_not_a_number:{raw_factor}"
        if not SAFETY_FACTOR_MIN <= float(raw_factor) <= SAFETY_FACTOR_MAX:
            return f"{MATRIX_INCOMPLETE}:window_safety_factor_out_of_range:{raw_factor}"
    # CEO decision D9 (round 4, 2026-09-04): an unreadable enforcement mode is a
    # fail-closed CONFIG error, not a silent fall back to the default - the mode
    # decides whether the 5h window refuses work at all.
    if ENFORCEMENT_MODE_FIELD in codex_matrix:
        raw_mode = codex_matrix.get(ENFORCEMENT_MODE_FIELD)
        if (
            not isinstance(raw_mode, str)
            or raw_mode.strip().lower() not in ENFORCEMENT_MODES
        ):
            return f"{MATRIX_INCOMPLETE}:{ENFORCEMENT_MODE_FIELD}_invalid:{raw_mode}"
    if EFFORT_MAPPING_FIELD in codex_matrix and not isinstance(
        codex_matrix.get(EFFORT_MAPPING_FIELD), bool
    ):
        # An OWNER-visible behaviour switch (D1) must never be truthy-by-accident.
        return f"{MATRIX_INCOMPLETE}:{EFFORT_MAPPING_FIELD}_not_a_bool:{codex_matrix.get(EFFORT_MAPPING_FIELD)}"
    for tier_name in sorted(set(EFFORT_TIERS.values()) | {SCALPEL_TIER}):
        if tier_name not in tiers:
            return f"{MATRIX_INCOMPLETE}:tier_{tier_name}_undeclared"
    return None


def resolve_tier(
    codex_matrix: dict[str, Any],
    payload: dict[str, Any] | None,
    task_type: str,
    effort: str | None,
) -> dict[str, Any]:
    """Doctrine section 2 precedence, as a pure function.

    explicit ``codex_model_tier`` > ``scalpel``/mechanization > effort class.
    An unknown tier fails closed with a structured ``error`` instead of
    silently falling back to a model OWNER did not choose.
    """
    tiers = codex_matrix.get("tiers") or {}
    task_payload = payload or {}
    field = str(codex_matrix.get("explicit_tier_payload_field") or "codex_model_tier")
    explicit = str(task_payload.get(field) or "").strip().lower()
    if explicit:
        if explicit not in tiers:
            return {
                "tier": None,
                "source": "explicit_payload",
                "reason": f"explicit_payload:{field}",
                "error": {
                    "code": UNKNOWN_TIER_REASON,
                    "requested": explicit,
                    "payload_field": field,
                    "allowed": sorted(tiers),
                },
            }
        return {
            "tier": explicit,
            "source": "explicit_payload",
            "reason": f"explicit_payload:{field}:{explicit}",
            "error": None,
        }
    normalized_type = str(task_type or "").strip().lower()
    # CEO decision D5 (round 3, 2026-09-04): the scalpel marker must be JSON
    # `true`. `"true"` / `"True"` / `1` / `"yes"` used to fall through to the
    # effort class with no hold, no error and no downgrade marker - i.e. Astra
    # work executed silently on a weaker model, the one outcome the doctrine
    # forbids. Identity comparisons on purpose: `1 == True` in Python.
    raw_scalpel = task_payload.get(SCALPEL_PAYLOAD_FIELD)
    if SCALPEL_PAYLOAD_FIELD in task_payload and not (
        raw_scalpel is True or raw_scalpel is False or raw_scalpel is None
    ):
        return {
            "tier": None,
            "source": "scalpel",
            "reason": f"{INVALID_SCALPEL_REASON}:{type(raw_scalpel).__name__}",
            "error": {
                "code": INVALID_SCALPEL_REASON,
                "requested": SCALPEL_TIER,
                "payload_field": SCALPEL_PAYLOAD_FIELD,
                "raw": raw_scalpel if isinstance(raw_scalpel, (str, int, float, bool)) else str(raw_scalpel),
                "expected": "JSON true",
            },
        }
    if raw_scalpel is True or normalized_type in SCALPEL_TASK_TYPES:
        if SCALPEL_TIER not in tiers:
            return {
                "tier": None,
                "source": "scalpel",
                "reason": "scalpel_class",
                "error": {
                    "code": UNKNOWN_TIER_REASON,
                    "requested": SCALPEL_TIER,
                    "payload_field": SCALPEL_PAYLOAD_FIELD,
                    "allowed": sorted(tiers),
                },
            }
        return {
            "tier": SCALPEL_TIER,
            "source": "scalpel",
            "reason": "scalpel_class_hold_never_downgrade",
            "error": None,
        }
    normalized_effort = str(effort or "").strip().lower()
    tier = EFFORT_TIERS.get(normalized_effort)
    # CEO decision D1 (round 3, 2026-09-04): the effort-class remap is OPT-IN.
    # With `effort_class_tier_mapping_enabled` false an untiered task falls
    # through to `default_tier`, keeping today's model AND today's effort - so
    # build_ea / ops_issue / research_strategy / mechanical / recycled rows
    # produce the pre-doctrine command line unchanged.
    mapping_enabled = effort_class_tier_mapping_enabled(codex_matrix)
    if mapping_enabled and tier is not None and tier in tiers:
        return {
            "tier": tier,
            "source": "effort_class",
            "reason": f"effort_class:{normalized_effort}",
            "error": None,
        }
    # No effort class resolved (mapping off, unset, or an effort outside the
    # max/high/medium matrix). `default_tier` is the configured landing place
    # for exactly this case - it is a REAL fallback, not decoration: without it
    # an unclassified task would fail closed and never dispatch at all.
    configured_default = str(codex_matrix.get("default_tier") or "").strip().lower()
    if configured_default and configured_default in tiers:
        suffix = "" if mapping_enabled else ";effort_class_mapping_disabled"
        return {
            "tier": configured_default,
            "source": "default_tier",
            "reason": (
                f"default_tier:{configured_default}:effort_{normalized_effort or 'unset'}{suffix}"
            ),
            "error": None,
        }
    return {
        "tier": None,
        "source": "effort_class",
        "reason": f"effort_class:{normalized_effort or 'unset'}",
        "error": {
            "code": UNKNOWN_TIER_REASON,
            "requested": tier or normalized_effort,
            "effort": normalized_effort,
            "default_tier": configured_default,
            "allowed": sorted(tiers),
        },
    }


def fallback_chain(tier: str, tiers: dict[str, Any]) -> list[str]:
    """Primary chain (sol->terra->luna) first, legacy columns second.

    Doctrine section 3.2: "Non-scalpel classes fall back one tier down
    (Sol->Terra->Luna, legacy columns as second fallback)."
    """
    if tier not in tiers:
        return []
    primary: list[str] = []
    current: str | None = tier
    while current and current in tiers and current not in primary and len(primary) < MAX_CHAIN_DEPTH:
        primary.append(current)
        nxt = str(tiers[current].get("fallback_tier") or "").strip()
        current = nxt or None
    chain = list(primary)
    for name in primary:
        legacy = str(tiers[name].get("legacy_fallback_tier") or "").strip()
        if legacy and legacy in tiers and legacy not in chain:
            chain.append(legacy)
    return chain


def window_budget(
    tier_cfg: dict[str, Any],
    plan: str,
    factor: float = DEFAULT_SAFETY_FACTOR,
) -> int | None:
    """floor(plan-tier low-end allowance x safety factor); ``None`` if unknown.

    ``None`` means UNRESOLVED, not unlimited: ``select_dispatch`` marks such a
    tier unusable and skips it rather than granting an uncounted window.
    """
    budgets = tier_cfg.get("five_hour_messages")
    if not isinstance(budgets, dict) or plan not in budgets:
        return None
    allowance = budgets[plan]
    if isinstance(allowance, bool):
        return None
    try:
        allowance = int(allowance)
    except (TypeError, ValueError):
        return None
    if allowance < 0:
        return None
    return max(0, int(math.floor(allowance * float(factor))))


def _parse_time(value: Any) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def read_ledger(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """``(records, integrity)``. Corrupt lines are COUNTED, not swallowed.

    Fix round 2026-09-04: an interleaved partial JSONL line used to vanish from
    the window count with no signal anywhere. Up to five Codex processes append
    to this file, so a torn line is a real class - it is now reported through
    ``model_window.ledger_integrity`` into the spawn payload. (Appends are also
    serialised by ``_ledger_lock`` now, so a torn line means something outside
    this module wrote the file.)
    """
    records: list[dict[str, Any]] = []
    corrupt = 0
    try:
        handle = open(path, "r", encoding="utf-8")
    except FileNotFoundError:
        return records, {"corrupt_lines": 0, "read_error": None}
    except (OSError, ValueError) as exc:
        return records, {"corrupt_lines": 0, "read_error": f"{type(exc).__name__}"}
    with handle:
        # CEO decision D8 (round 4, 2026-09-04): the DECODE happens here, not in
        # `open()`. Round-3 finding F2: one invalid UTF-8 byte in the middle of
        # the ledger raised `UnicodeDecodeError` (a `ValueError` subclass) out of
        # `read_ledger`, through `select_dispatch` / `invocation_profile` /
        # `evaluate_spawn` and aborted the WHOLE `route_once` pass for every
        # lane, instead of refusing this one dispatch with the structured
        # `codex_ledger_read_error` D4 specifies.
        try:
            for line in handle:
                stripped = line.strip()
                if not stripped:
                    continue
                try:
                    record = json.loads(stripped)
                except (json.JSONDecodeError, ValueError):
                    corrupt += 1
                    continue
                if isinstance(record, dict):
                    records.append(record)
                else:
                    corrupt += 1
        except (OSError, ValueError) as exc:
            # Partial records travel with the error so OBSERVE mode can still
            # report a count; every ENFORCE-mode consumer checks `read_error`
            # first and refuses.
            return records, {"corrupt_lines": corrupt, "read_error": f"{type(exc).__name__}"}
    return records, {"corrupt_lines": corrupt, "read_error": None}


def iter_ledger(path: Path) -> Iterator[dict[str, Any]]:
    """Records only (integrity is reported through :func:`read_ledger`)."""
    records, _integrity = read_ledger(path)
    yield from records


def ledger_mtime(path: Path) -> dt.datetime | None:
    """UTC mtime of the ledger file, or ``None`` when it cannot be stat'ed."""
    try:
        return dt.datetime.fromtimestamp(Path(path).stat().st_mtime, dt.UTC)
    except (OSError, ValueError, OverflowError):
        return None


def scan_window(
    model: str,
    *,
    now: dt.datetime,
    path: Path,
    minutes: float = DEFAULT_WINDOW_MINUTES,
) -> dict[str, Any]:
    """Rolling window count of ``model`` plus the ledger integrity signal.

    A record exactly ``minutes`` old has left the window (strict cutoff).
    A record stamped in the FUTURE counts (fix round 2026-09-04): dropping it
    as clock skew re-granted the whole budget after a wall-clock jump, which is
    a documented class on this host - the conservative reading is that the
    message was really spent.

    CEO decision D4 (round 3): a CORRUPT line also counts as consumed budget.
    An unparseable line carries no model attribution, so the conservative
    reading charges it to every model rather than letting a torn write hand a
    message back. The count is surfaced as ``integrity.counted_corrupt_lines``.

    CEO decision D12 (round 4) bounds that rule in TIME. Round-3 finding F4: a
    corrupt line had no timestamp, so it was charged forever - two torn lines
    dated 2020 held `gpt-6-astra` permanently shut at count=2/budget=2 with no
    way back except manual file surgery. A corrupt line now counts only while
    the ledger FILE's mtime is inside the window (nothing can have been written
    to it more recently than that); outside the window it is still reported as
    ``integrity.corrupt_lines`` / ``corrupt_lines_outside_window``.

    D12 also makes a JSON-valid record with a missing or unparseable ``ts``
    count CONSERVATIVELY (as if inside the window) instead of being dropped -
    round-3 finding F6, the one fail-OPEN asymmetry left in the arithmetic.
    """
    cutoff = now - dt.timedelta(minutes=float(minutes))
    records, integrity = read_ledger(path)
    released = {
        str(record.get("release_of") or "")
        for record in records
        if str(record.get("kind") or "") == RECORD_KIND_RELEASE
    }
    released.discard("")
    count = 0
    for record in records:
        if str(record.get("kind") or RECORD_KIND_DISPATCH) != RECORD_KIND_DISPATCH:
            continue
        if str(record.get("model") or "") != str(model):
            continue
        stamp = _parse_time(record.get("ts"))
        # D12/F6: an unreadable `ts` counts (conservative), a readable one that
        # has left the window does not.
        if stamp is not None and stamp <= cutoff:
            continue
        if str(record.get("id") or "") in released:
            continue
        count += 1
    corrupt = int(integrity.get("corrupt_lines") or 0)
    mtime = ledger_mtime(path)
    corrupt_in_window = bool(corrupt) and (mtime is None or mtime > cutoff)
    counted_corrupt = corrupt if corrupt_in_window else 0
    integrity = dict(integrity)
    integrity["counted_corrupt_lines"] = counted_corrupt
    integrity["corrupt_lines_outside_window"] = corrupt - counted_corrupt
    integrity["ledger_mtime"] = mtime.isoformat() if mtime is not None else None
    return {"count": count + counted_corrupt, "integrity": integrity}


def window_count(
    model: str,
    *,
    now: dt.datetime,
    path: Path,
    minutes: float = DEFAULT_WINDOW_MINUTES,
) -> int:
    """Rolling count of dispatches of ``model`` inside the last ``minutes``."""
    return int(scan_window(model, now=now, path=path, minutes=minutes)["count"])


@contextlib.contextmanager
def _ledger_lock(path: Path, timeout: float = LEDGER_LOCK_TIMEOUT_SECONDS) -> Iterator[str]:
    """Exclusive advisory lock around count-then-append.

    Without it, two spawners read the same pre-dispatch count and both pass a
    budget that only admitted one. Lock failure is reported (``lock`` field),
    never raised - a dispatch path must not break on a lock file.
    """
    lock_path = Path(str(path) + ".lock")
    handle: int | None = None
    status = "unavailable"
    try:
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        handle = os.open(str(lock_path), os.O_CREAT | os.O_RDWR)
    except OSError as exc:
        status = f"unavailable:{type(exc).__name__}"
        handle = None
    if handle is not None:
        deadline = time.monotonic() + float(timeout)
        while True:
            try:
                os.lseek(handle, 0, os.SEEK_SET)
                if os.name == "nt":
                    import msvcrt  # noqa: PLC0415

                    msvcrt.locking(handle, msvcrt.LK_NBLCK, 1)
                else:  # pragma: no cover - the farm runs on Windows
                    import fcntl  # noqa: PLC0415

                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                status = "acquired"
                break
            except OSError:
                if time.monotonic() >= deadline:
                    status = "unavailable:timeout"
                    break
                time.sleep(0.05)
    try:
        yield status
    finally:
        if handle is not None:
            if status == "acquired":
                try:
                    os.lseek(handle, 0, os.SEEK_SET)
                    if os.name == "nt":
                        import msvcrt  # noqa: PLC0415

                        msvcrt.locking(handle, msvcrt.LK_UNLCK, 1)
                    else:  # pragma: no cover
                        import fcntl  # noqa: PLC0415

                        fcntl.flock(handle, fcntl.LOCK_UN)
                except OSError:
                    pass
            try:
                os.close(handle)
            except OSError:
                pass


def _append_record(path: Path, record: dict[str, Any]) -> str | None:
    """Append one JSONL line; returns an error reason or ``None``."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
    except OSError as exc:
        return f"{LEDGER_WRITE_ERROR_REASON}:{type(exc).__name__}"
    return None


def rotate_ledger(
    path: Path,
    *,
    now: dt.datetime,
    minutes: float = DEFAULT_WINDOW_MINUTES,
    keep_factor: float = LEDGER_ROTATION_KEEP_FACTOR,
    min_lines: int = LEDGER_ROTATION_MIN_LINES,
) -> dict[str, Any]:
    """Drop records older than ``keep_factor`` x the window (CEO decision D12).

    Round-3 finding F4: nothing in the repo ever pruned
    ``codex_model_window_ledger.jsonl``, so every dispatch re-read a file that
    grows without bound (up to 7 full reads per ``select_dispatch``) and a torn
    line stayed charged forever.

    BOUNDED on purpose: below ``min_lines`` the file is left alone, so the
    common case adds one ``stat``-sized read and no rewrite at all. Called from
    :func:`commit_dispatch` while the exclusive ledger lock is held - never
    concurrently with an append. Records whose ``ts`` cannot be read are KEPT,
    matching the conservative counting rule, so rotation can never hand back a
    message the window arithmetic is still charging for. Never raises.
    """
    target = Path(path)
    try:
        raw_lines = target.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return {"rotated": False, "reason": "ledger_absent"}
    except (OSError, ValueError) as exc:
        return {"rotated": False, "reason": f"{LEDGER_READ_ERROR_REASON}:{type(exc).__name__}"}
    if len(raw_lines) < int(min_lines):
        return {
            "rotated": False,
            "reason": "below_rotation_threshold",
            "lines": len(raw_lines),
            "min_lines": int(min_lines),
        }
    cutoff = now.astimezone(dt.UTC) - dt.timedelta(minutes=float(minutes) * float(keep_factor))
    kept: list[str] = []
    dropped = 0
    dropped_corrupt = 0
    for line in raw_lines:
        stripped = line.strip()
        if not stripped:
            continue
        try:
            record = json.loads(stripped)
        except (json.JSONDecodeError, ValueError):
            dropped += 1
            dropped_corrupt += 1
            continue
        if not isinstance(record, dict):
            dropped += 1
            dropped_corrupt += 1
            continue
        stamp = _parse_time(record.get("ts"))
        if stamp is not None and stamp <= cutoff:
            dropped += 1
            continue
        kept.append(stripped)
    if not dropped:
        return {"rotated": False, "reason": "nothing_expired", "lines": len(raw_lines)}
    tmp = Path(str(target) + ".rotate.tmp")
    try:
        with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
            for line in kept:
                handle.write(line + "\n")
        os.replace(tmp, target)
    except OSError as exc:
        with contextlib.suppress(OSError):
            tmp.unlink()
        return {"rotated": False, "reason": f"{LEDGER_WRITE_ERROR_REASON}:{type(exc).__name__}"}
    return {
        "rotated": True,
        "kept": len(kept),
        "dropped": dropped,
        "dropped_corrupt_lines": dropped_corrupt,
        "cutoff": cutoff.isoformat(),
    }


def chain_entries(
    codex_matrix: dict[str, Any],
    chain: list[str],
) -> list[dict[str, Any]]:
    """``[{tier, model, budget, unusable?}]`` for a resolved fallback chain."""
    tiers = codex_matrix.get("tiers") or {}
    plan = plan_tier(codex_matrix)
    factor = safety_factor(codex_matrix)
    entries: list[dict[str, Any]] = []
    for name in chain:
        cfg = tiers.get(name)
        if not isinstance(cfg, dict):
            entries.append({"tier": name, "model": "", "budget": None, "unusable": "tier_missing"})
            continue
        model = cfg.get("model")
        model = model.strip() if isinstance(model, str) else ""
        budget = window_budget(cfg, plan, factor)
        entry: dict[str, Any] = {"tier": name, "model": model, "budget": budget}
        if not model:
            # Fail closed: no model id means the dispatcher would emit no -m at
            # all (silent account default) and the ledger would never count it.
            entry["unusable"] = "model_id_missing"
        elif budget is None:
            entry["unusable"] = f"budget_unresolved:{plan}"
        entries.append(entry)
    return entries


def commit_dispatch(
    *,
    task_id: str,
    chain: list[dict[str, Any]],
    path: Path,
    now: dt.datetime | None = None,
    minutes: float = DEFAULT_WINDOW_MINUTES,
    env: dict[str, str] | None = None,
    mode: str = ENFORCEMENT_ENFORCE,
) -> dict[str, Any]:
    """Book ONE message against the fallback chain, under the ledger lock.

    ENFORCE mode is the fail-closed choke point of the 5h contract: count and
    append happen under the same lock, so a concurrent spawner cannot slip a
    second message through the same remaining slot, and a refusal carries the
    structured ``codex_tier_window_exhausted`` detail.

    OBSERVE mode (CEO decision D9, round 4, the shipped default) books the FIRST
    usable entry unconditionally - no refusal, no hold, no downgrade - and
    reports what enforce mode would have done through ``over_budget``,
    ``would_refuse`` and ``would_downgrade``. Config defects (no model id at
    all) still fail closed in BOTH modes: without a model id there is nothing to
    dispatch and nothing the ledger could count.

    ``mode`` defaults to ENFORCE because this is the strict primitive; the
    POLICY decides in production (:func:`record_dispatch` passes
    :func:`enforcement_mode` of the live matrix).
    """
    if not tiers_enabled(env):
        return {"recorded": False, "reason": "codex_model_tiers_disabled"}
    active_mode = mode if mode in ENFORCEMENT_MODES else DEFAULT_ENFORCEMENT_MODE
    observe = active_mode == ENFORCEMENT_OBSERVE
    usable = [
        entry
        for entry in (chain or [])
        if str(entry.get("model") or "").strip() and not entry.get("unusable")
    ]
    if not usable:
        blocked = [entry for entry in (chain or []) if entry.get("unusable")]
        return {
            "recorded": False,
            "reason": UNUSABLE_TIER_REASON if blocked else "model_unresolved",
            "enforcement_mode": active_mode,
            "refusal": {
                "code": UNUSABLE_TIER_REASON if blocked else "model_unresolved",
                "chain": list(chain or []),
            },
        }
    target = Path(path)
    stamp = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    exhausted: list[dict[str, Any]] = []
    with _ledger_lock(target) as lock_status:
        # CEO decision D11 (round 4): no lock, no booking. Round-3 finding F5:
        # the lock status was recorded in the result dict and then ignored, so
        # under contention (10s deadline) or a lock-file OSError two spawners
        # could read the same remaining slot and both append.
        if lock_status != "acquired" and not observe:
            return {
                "recorded": False,
                "reason": LEDGER_LOCK_ERROR_REASON,
                "path": str(target),
                "enforcement_mode": active_mode,
                "lock": lock_status,
                "refusal": {
                    "code": LEDGER_LOCK_ERROR_REASON,
                    "lock": lock_status,
                    "path": str(target),
                    "chain": list(chain or []),
                },
            }
        # CEO decision D12: prune under the same lock, before the count.
        if lock_status == "acquired":
            rotation = rotate_ledger(target, now=stamp, minutes=minutes)
        else:
            rotation = {"rotated": False, "reason": "ledger_lock_unavailable"}
        # CEO decision D4: an unreadable ledger is a REFUSAL in enforce mode,
        # not a fresh budget. D8/D9: in observe mode it is REPORTED and the
        # dispatch proceeds with an unknown count.
        _records, preflight = read_ledger(target)
        read_error = preflight.get("read_error")
        if read_error and not observe:
            return {
                "recorded": False,
                "reason": LEDGER_READ_ERROR_REASON,
                "path": str(target),
                "enforcement_mode": active_mode,
                "lock": lock_status,
                "refusal": {
                    "code": LEDGER_READ_ERROR_REASON,
                    "path": str(target),
                    "read_error": read_error,
                    "chain": list(chain or []),
                },
            }
        # Observe mode never walks down the chain: the requested tier is what
        # gets dispatched and recorded, so an untiered task keeps `gpt-5.6-sol`
        # indefinitely and a scalpel task keeps Astra.
        candidates = usable[:1] if observe else usable
        for entry in candidates:
            model = str(entry["model"])
            budget = entry.get("budget")
            if read_error:
                scan = {"count": None, "integrity": dict(preflight)}
            else:
                scan = scan_window(model, now=stamp, path=target, minutes=minutes)
            count = scan["count"]
            window = {
                "tier": entry.get("tier"),
                "model": model,
                "count": count,
                "budget": budget,
                "window_minutes": minutes,
                "ledger_integrity": scan["integrity"],
            }
            over_budget = (
                budget is not None and count is not None and int(count) >= int(budget)
            )
            if over_budget and not observe:
                exhausted.append(window)
                continue
            record = {
                "ts": stamp.isoformat(),
                "task_id": str(task_id or ""),
                "tier": str(entry.get("tier") or ""),
                "model": model,
                "kind": RECORD_KIND_DISPATCH,
                "id": uuid.uuid4().hex,
                "enforcement_mode": active_mode,
            }
            if over_budget:
                record["over_budget"] = True
            write_error = _append_record(target, record)
            if write_error is not None:
                return {
                    "recorded": False,
                    "reason": write_error,
                    "path": str(target),
                    "enforcement_mode": active_mode,
                    "record": record,
                }
            result: dict[str, Any] = {
                "recorded": True,
                "path": str(target),
                "record": record,
                "record_id": record["id"],
                "model": model,
                "tier": record["tier"],
                "window": window,
                "lock": lock_status,
                "enforcement_mode": active_mode,
                "rotation": rotation,
                "ledger_integrity": scan["integrity"],
                "downgraded_from": (
                    str(usable[0].get("tier") or "") if entry is not usable[0] else None
                ),
            }
            if observe:
                result["over_budget"] = bool(over_budget)
                if read_error:
                    result["would_refuse"] = {
                        "code": LEDGER_READ_ERROR_REASON,
                        "path": str(target),
                        "read_error": read_error,
                    }
                elif over_budget:
                    result["would_refuse"] = {
                        "code": WINDOW_EXHAUSTED_REASON,
                        "tier": entry.get("tier"),
                        "model": model,
                        "count": count,
                        "budget": budget,
                        "window_minutes": minutes,
                    }
                    fallback = _first_entry_with_room(
                        usable[1:], now=stamp, path=target, minutes=minutes
                    )
                    if fallback is not None:
                        result["would_downgrade"] = {
                            "from_tier": entry.get("tier"),
                            "to_tier": fallback.get("tier"),
                            "to_model": fallback.get("model"),
                        }
                if lock_status != "acquired":
                    result["would_refuse"] = {
                        "code": LEDGER_LOCK_ERROR_REASON,
                        "lock": lock_status,
                        "path": str(target),
                    }
            return result
    first = exhausted[0]
    return {
        "recorded": False,
        "reason": WINDOW_EXHAUSTED_REASON,
        "path": str(target),
        "enforcement_mode": active_mode,
        "refusal": {
            "code": WINDOW_EXHAUSTED_REASON,
            "tier": first.get("tier"),
            "model": first.get("model"),
            "count": first.get("count"),
            "budget": first.get("budget"),
            "window_minutes": minutes,
            "chain": exhausted,
        },
    }


def _first_entry_with_room(
    entries: list[dict[str, Any]],
    *,
    now: dt.datetime,
    path: Path,
    minutes: float,
) -> dict[str, Any] | None:
    """First chain entry whose window still has room (observe-mode reporting)."""
    for entry in entries:
        model = str(entry.get("model") or "").strip()
        if not model or entry.get("unusable"):
            continue
        budget = entry.get("budget")
        if budget is None:
            return entry
        if int(scan_window(model, now=now, path=path, minutes=minutes)["count"]) < int(budget):
            return entry
    return None


def release_dispatch(
    *,
    record_id: str,
    path: Path,
    task_id: str = "",
    model: str = "",
    now: dt.datetime | None = None,
    env: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Give one booked message back when the spawn it was booked for failed."""
    if not tiers_enabled(env):
        return {"released": False, "reason": "codex_model_tiers_disabled"}
    if not str(record_id or "").strip():
        return {"released": False, "reason": "record_id_missing"}
    stamp = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    record = {
        "ts": stamp.isoformat(),
        "task_id": str(task_id or ""),
        "model": str(model or ""),
        "kind": RECORD_KIND_RELEASE,
        "release_of": str(record_id),
    }
    write_error = _append_record(Path(path), record)
    if write_error is not None:
        return {"released": False, "reason": write_error, "record": record}
    return {"released": True, "record": record, "path": str(path)}


def record_dispatch(
    *,
    task_id: str,
    tier: str,
    model: str,
    path: Path | None = None,
    now: dt.datetime | None = None,
    codex_matrix: dict[str, Any] | None = None,
    env: dict[str, str] | None = None,
    chain: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Book one dispatch (atomically, budget-checked). No-op under rollback.

    ``chain`` lets the caller pass the full fallback chain so the commit can
    still land one tier lower if the preferred model was filled between the
    preview and the spawn; without it the single ``(tier, model)`` is used.
    """
    if not tiers_enabled(env):
        return {"recorded": False, "reason": "codex_model_tiers_disabled"}
    if not str(model or "").strip() and not chain:
        return {"recorded": False, "reason": "model_unresolved"}
    matrix = codex_matrix or {}
    target = Path(path) if path is not None else ledger_path(matrix, env)
    minutes = window_minutes(matrix) if matrix else DEFAULT_WINDOW_MINUTES
    entries = list(chain or [])
    if not entries:
        tiers = matrix.get("tiers") or {}
        cfg = tiers.get(str(tier))
        budget = (
            window_budget(cfg, plan_tier(matrix), safety_factor(matrix))
            if isinstance(cfg, dict)
            else None
        )
        entries = [{"tier": str(tier or ""), "model": str(model), "budget": budget}]
    return commit_dispatch(
        task_id=task_id,
        chain=entries,
        path=target,
        now=now,
        minutes=minutes,
        env=env,
        # CEO decision D9 (round 4): the live matrix decides observe vs enforce.
        mode=enforcement_mode(matrix),
    )


def select_dispatch(
    codex_matrix: dict[str, Any],
    payload: dict[str, Any] | None,
    task_type: str,
    effort: str | None,
    *,
    effort_explicit: bool = False,
    now: dt.datetime | None = None,
    path: Path | None = None,
    env: dict[str, str] | None = None,
) -> dict[str, Any]:
    """PREVIEW the tier -> model id + effort resolution against the 5h window.

    Read-only by design: nothing here books a message, so a routing preview
    cannot spend budget. The booking (and the authoritative refusal) happens in
    :func:`commit_dispatch` at the real spawn.

    Returns the tier fields merged into the quota-gate invocation:
    ``model``/``reasoning_effort`` plus ``model_tier``, ``model_window``,
    ``model_tier_chain_detail`` (what ``commit_dispatch`` may book) and, where
    applicable, ``model_tier_downgraded_from`` (a fallback was taken),
    ``model_tier_hold`` (Astra waits, never downgrades) or
    ``model_tier_refusal`` (the whole chain is exhausted).
    """
    tiers = codex_matrix.get("tiers") or {}
    resolution = resolve_tier(codex_matrix, payload, task_type, effort)
    if resolution["error"] is not None:
        blocked_resolution: dict[str, Any] = {
            "model_tier": None,
            "model_tier_source": resolution["source"],
            "model_tier_reason": resolution["reason"],
            "model_tier_error": resolution["error"],
        }
        if str(resolution["error"].get("code")) == INVALID_SCALPEL_REASON:
            # CEO decision D5: an unreadable scalpel marker HOLDS the row with
            # its own routing reason - `awaiting_model_window:astra` would
            # misreport a config defect as a spent budget.
            blocked_resolution["model_tier_hold"] = {
                "code": HOLD_CODE_INVALID_SCALPEL,
                "route_reason": INVALID_SCALPEL_REASON,
                "tier": SCALPEL_TIER,
                "payload_field": SCALPEL_PAYLOAD_FIELD,
                "raw": resolution["error"].get("raw"),
            }
        return blocked_resolution
    requested = str(resolution["tier"])
    requested_cfg = dict(tiers[requested])
    # Depth is a task property: a fallback lowers the MODEL, never the effort
    # (standing rule "quota pacing changes volume, not depth").
    # CEO decision D1: a row that lands on `default_tier` (no explicit tier, no
    # scalpel marker, effort-class mapping off) keeps its EXISTING effort class
    # so the rendered command line stays byte-identical to the pre-doctrine one.
    # Only an explicitly requested tier or the scalpel class replaces the effort
    # with that tier's default.
    if effort_explicit or resolution["source"] in {"effort_class", "default_tier"}:
        selected_effort = str(effort or requested_cfg.get("default_reasoning_effort") or "")
    else:
        selected_effort = str(requested_cfg.get("default_reasoning_effort") or effort or "")
    plan = plan_tier(codex_matrix)
    minutes = window_minutes(codex_matrix)
    factor = safety_factor(codex_matrix)
    # CEO decision D9 (round 4, 2026-09-04): observe reports, enforce blocks.
    active_mode = enforcement_mode(codex_matrix)
    observe = active_mode == ENFORCEMENT_OBSERVE
    target = Path(path) if path is not None else ledger_path(codex_matrix, env)
    stamp = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    chain = [requested] if requested == SCALPEL_TIER else fallback_chain(requested, tiers)
    detail = chain_entries(codex_matrix, chain)
    # CEO decision D4: fail CLOSED on an unreadable ledger instead of previewing
    # a full, uncounted budget.
    _records, preflight = read_ledger(target)
    read_error = preflight.get("read_error")
    if read_error and not observe:
        return {
            "model": str(requested_cfg.get("model") or ""),
            "reasoning_effort": selected_effort,
            "model_tier": requested,
            "model_tier_source": resolution["source"],
            "model_tier_reason": f"{resolution['reason']};{LEDGER_READ_ERROR_REASON}",
            "model_tier_chain": chain,
            "model_tier_chain_detail": detail,
            "model_tier_ledger_integrity": preflight,
            "model_tier_enforcement_mode": active_mode,
            "model_tier_refusal": {
                "code": LEDGER_READ_ERROR_REASON,
                "tier": requested,
                "model": str(requested_cfg.get("model") or ""),
                "path": str(target),
                "read_error": read_error,
                "plan_tier": plan,
                "window_minutes": minutes,
            },
        }
    integrity: dict[str, Any] | None = None
    exhausted: list[dict[str, Any]] = []
    for position, entry in enumerate(detail):
        if entry.get("unusable"):
            exhausted.append(
                {
                    "tier": entry["tier"],
                    "model": entry["model"],
                    "count": None,
                    "budget": entry["budget"],
                    "unusable": entry["unusable"],
                    "window_minutes": minutes,
                }
            )
            continue
        model = str(entry["model"])
        budget = entry["budget"]
        if read_error:
            scan = {"count": None, "integrity": dict(preflight)}
        else:
            scan = scan_window(model, now=stamp, path=target, minutes=minutes)
        if integrity is None or scan["integrity"].get("corrupt_lines"):
            integrity = scan["integrity"]
        window = {
            "model": model,
            "tier": entry["tier"],
            "plan_tier": plan,
            "count": scan["count"],
            "budget": budget,
            "window_minutes": minutes,
            "safety_factor": factor,
            "ledger_integrity": scan["integrity"],
        }
        has_room = budget is None or scan["count"] is None or scan["count"] < int(budget)
        # Observe mode takes the FIRST usable entry whether or not it has room:
        # nothing is refused, held or downgraded, only reported.
        if has_room or observe:
            selected: dict[str, Any] = {
                "model": model,
                "reasoning_effort": selected_effort,
                "model_tier": entry["tier"],
                "model_tier_source": resolution["source"],
                "model_tier_reason": resolution["reason"],
                "model_window": window,
                "model_tier_chain": chain,
                "model_tier_chain_detail": detail,
                "model_tier_enforcement_mode": active_mode,
            }
            if entry["tier"] != requested:
                selected["model_tier_downgraded_from"] = requested
                selected["model_tier_reason"] = f"{resolution['reason']};downgraded_from:{requested}"
            if observe and read_error:
                selected["model_tier_would_refuse"] = {
                    "code": LEDGER_READ_ERROR_REASON,
                    "tier": entry["tier"],
                    "model": model,
                    "path": str(target),
                    "read_error": read_error,
                }
                selected["model_tier_reason"] = (
                    f"{selected['model_tier_reason']};observe:{LEDGER_READ_ERROR_REASON}"
                )
            elif observe and not has_room:
                selected["model_tier_over_budget"] = True
                selected["model_tier_would_refuse"] = {
                    "code": WINDOW_EXHAUSTED_REASON,
                    "tier": entry["tier"],
                    "model": model,
                    "count": scan["count"],
                    "budget": budget,
                    "plan_tier": plan,
                    "window_minutes": minutes,
                }
                fallback = _first_entry_with_room(
                    detail[position + 1 :], now=stamp, path=target, minutes=minutes
                )
                if fallback is not None:
                    selected["model_tier_would_downgrade"] = {
                        "from_tier": entry["tier"],
                        "to_tier": fallback.get("tier"),
                        "to_model": fallback.get("model"),
                    }
                selected["model_tier_reason"] = (
                    f"{selected['model_tier_reason']};observe:{WINDOW_EXHAUSTED_REASON}"
                )
            if integrity and (integrity.get("corrupt_lines") or integrity.get("read_error")):
                selected["model_tier_ledger_integrity"] = integrity
            return selected
        exhausted.append(window)
    first = exhausted[0] if exhausted else {"model": "", "count": 0, "budget": 0}
    all_unusable = bool(exhausted) and all(item.get("unusable") for item in exhausted)
    refusal = {
        "code": UNUSABLE_TIER_REASON if all_unusable else WINDOW_EXHAUSTED_REASON,
        "tier": requested,
        "model": first.get("model"),
        "count": first.get("count"),
        "budget": first.get("budget"),
        "plan_tier": plan,
        "window_minutes": minutes,
        "chain": exhausted,
    }
    blocked: dict[str, Any] = {
        "model": str(requested_cfg.get("model") or ""),
        "reasoning_effort": selected_effort,
        "model_tier": requested,
        "model_tier_source": resolution["source"],
        "model_tier_reason": f"{resolution['reason']};{refusal['code']}",
        "model_window": first,
        "model_tier_chain": chain,
        "model_tier_chain_detail": detail,
        "model_tier_enforcement_mode": active_mode,
        "model_tier_refusal": refusal,
    }
    if integrity and (integrity.get("corrupt_lines") or integrity.get("read_error")):
        blocked["model_tier_ledger_integrity"] = integrity
    if requested == SCALPEL_TIER:
        # Doctrine section 2/3.2: the scalpel tier is HELD, mirroring the
        # `awaiting_human_lane:owner` pattern - never silently downgraded.
        blocked["model_tier_hold"] = {
            "code": HOLD_CODE,
            "tier": requested,
            "model": refusal["model"],
            "count": refusal["count"],
            "budget": refusal["budget"],
        }
    return blocked
