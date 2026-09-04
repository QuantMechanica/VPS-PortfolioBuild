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
        for key in ("fallback_tier", "legacy_fallback_tier"):
            reference = cfg.get(key)
            if reference in (None, ""):
                continue
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
    return records, {"corrupt_lines": corrupt, "read_error": None}


def iter_ledger(path: Path) -> Iterator[dict[str, Any]]:
    """Records only (integrity is reported through :func:`read_ledger`)."""
    records, _integrity = read_ledger(path)
    yield from records


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
        if stamp is None or stamp <= cutoff:
            continue
        if str(record.get("id") or "") in released:
            continue
        count += 1
    corrupt = int(integrity.get("corrupt_lines") or 0)
    integrity = dict(integrity)
    integrity["counted_corrupt_lines"] = corrupt
    return {"count": count + corrupt, "integrity": integrity}


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
) -> dict[str, Any]:
    """Atomically book ONE message against the first chain entry with room.

    This is the single fail-closed choke point of the 5h contract: count and
    append happen under the same lock, so a concurrent spawner cannot slip a
    second message through the same remaining slot. A refusal carries the
    structured ``codex_tier_window_exhausted`` detail.
    """
    if not tiers_enabled(env):
        return {"recorded": False, "reason": "codex_model_tiers_disabled"}
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
            "refusal": {
                "code": UNUSABLE_TIER_REASON if blocked else "model_unresolved",
                "chain": list(chain or []),
            },
        }
    target = Path(path)
    stamp = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    exhausted: list[dict[str, Any]] = []
    with _ledger_lock(target) as lock_status:
        # CEO decision D4: an unreadable ledger is a REFUSAL, not a fresh
        # budget. `read_ledger` reported count=0 with a side-band `read_error`,
        # so every dispatch was re-granted the whole window while
        # `D:/QM/reports/state` was unavailable - a documented incident class.
        _records, preflight = read_ledger(target)
        if preflight.get("read_error"):
            return {
                "recorded": False,
                "reason": LEDGER_READ_ERROR_REASON,
                "path": str(target),
                "refusal": {
                    "code": LEDGER_READ_ERROR_REASON,
                    "path": str(target),
                    "read_error": preflight.get("read_error"),
                    "chain": list(chain or []),
                },
            }
        for entry in usable:
            model = str(entry["model"])
            budget = entry.get("budget")
            scan = scan_window(model, now=stamp, path=target, minutes=minutes)
            window = {
                "tier": entry.get("tier"),
                "model": model,
                "count": scan["count"],
                "budget": budget,
                "window_minutes": minutes,
                "ledger_integrity": scan["integrity"],
            }
            if budget is not None and scan["count"] >= int(budget):
                exhausted.append(window)
                continue
            record = {
                "ts": stamp.isoformat(),
                "task_id": str(task_id or ""),
                "tier": str(entry.get("tier") or ""),
                "model": model,
                "kind": RECORD_KIND_DISPATCH,
                "id": uuid.uuid4().hex,
            }
            write_error = _append_record(target, record)
            if write_error is not None:
                return {
                    "recorded": False,
                    "reason": write_error,
                    "path": str(target),
                    "record": record,
                }
            return {
                "recorded": True,
                "path": str(target),
                "record": record,
                "record_id": record["id"],
                "model": model,
                "tier": record["tier"],
                "window": window,
                "lock": lock_status,
                "ledger_integrity": scan["integrity"],
                "downgraded_from": (
                    str(usable[0].get("tier") or "") if entry is not usable[0] else None
                ),
            }
    first = exhausted[0]
    return {
        "recorded": False,
        "reason": WINDOW_EXHAUSTED_REASON,
        "path": str(target),
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
    target = Path(path) if path is not None else ledger_path(codex_matrix, env)
    stamp = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    chain = [requested] if requested == SCALPEL_TIER else fallback_chain(requested, tiers)
    detail = chain_entries(codex_matrix, chain)
    # CEO decision D4: fail CLOSED on an unreadable ledger instead of previewing
    # a full, uncounted budget.
    _records, preflight = read_ledger(target)
    if preflight.get("read_error"):
        return {
            "model": str(requested_cfg.get("model") or ""),
            "reasoning_effort": selected_effort,
            "model_tier": requested,
            "model_tier_source": resolution["source"],
            "model_tier_reason": f"{resolution['reason']};{LEDGER_READ_ERROR_REASON}",
            "model_tier_chain": chain,
            "model_tier_chain_detail": detail,
            "model_tier_ledger_integrity": preflight,
            "model_tier_refusal": {
                "code": LEDGER_READ_ERROR_REASON,
                "tier": requested,
                "model": str(requested_cfg.get("model") or ""),
                "path": str(target),
                "read_error": preflight.get("read_error"),
                "plan_tier": plan,
                "window_minutes": minutes,
            },
        }
    integrity: dict[str, Any] | None = None
    exhausted: list[dict[str, Any]] = []
    for entry in detail:
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
        scan = scan_window(model, now=stamp, path=target, minutes=minutes)
        if integrity is None or scan["integrity"]["corrupt_lines"]:
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
        if budget is None or scan["count"] < int(budget):
            selected: dict[str, Any] = {
                "model": model,
                "reasoning_effort": selected_effort,
                "model_tier": entry["tier"],
                "model_tier_source": resolution["source"],
                "model_tier_reason": resolution["reason"],
                "model_window": window,
                "model_tier_chain": chain,
                "model_tier_chain_detail": detail,
            }
            if entry["tier"] != requested:
                selected["model_tier_downgraded_from"] = requested
                selected["model_tier_reason"] = f"{resolution['reason']};downgraded_from:{requested}"
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
