"""Shared bounded scheduling policy for independent DL-089 programs.

The helpers in this module are deliberately pure apart from bounded
environment parsing.  Claimers and the matrix service consume the same policy
so rollback (``L=1`` plus an empty allow-list) cannot drift between surfaces.
"""

from __future__ import annotations

import hashlib
import json
import os
from collections import Counter, defaultdict
from typing import Any, Iterable, Mapping, Sequence


PROGRAM_SLOTS_ENV = "DL089_PROGRAM_SLOTS"
DEFAULT_PROGRAM_SLOTS = 4
MAX_PROGRAM_SLOTS = 10
LANES_PER_PROGRAM_ENV = "DL089_LANES_PER_PROGRAM"
DEFAULT_LANES_PER_PROGRAM = 1
MAX_LANES_PER_PROGRAM = 2
CELL_SLOTS_ENV = "DL089_CELL_SLOTS"
DEFAULT_CELL_SLOTS = 6
MAX_CELL_SLOTS = 10
SAME_PROGRAM_ALLOWLIST_ENV = "DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST"

TERMINAL_STATUSES = frozenset({"done", "failed"})


class SchedulingError(RuntimeError):
    """A declared DL-089 lane cannot be authenticated safely."""


def _bounded_env(name: str, default: int, maximum: int) -> int:
    raw = str(os.environ.get(name, default)).strip()
    try:
        value = int(raw)
    except ValueError:
        return default
    return max(1, min(value, maximum))


def program_slots() -> int:
    """Return the bounded program cap; setting the environment to 1 rolls back."""

    return _bounded_env(PROGRAM_SLOTS_ENV, DEFAULT_PROGRAM_SLOTS, MAX_PROGRAM_SLOTS)


def lanes_per_program() -> int:
    """Return the bounded arm-lane cap; ``1`` is the inert rollback value."""

    return _bounded_env(
        LANES_PER_PROGRAM_ENV,
        DEFAULT_LANES_PER_PROGRAM,
        MAX_LANES_PER_PROGRAM,
    )


def cell_slots() -> int:
    """Return the bounded fleet-wide active OPT_CENSUS cell ceiling."""

    return _bounded_env(CELL_SLOTS_ENV, DEFAULT_CELL_SLOTS, MAX_CELL_SLOTS)


def same_program_parallel_allowlist() -> frozenset[str]:
    """Parse exact program IDs; malformed/blank tokens never broaden scope."""

    raw = str(os.environ.get(SAME_PROGRAM_ALLOWLIST_ENV, ""))
    values = {
        token.strip()
        for chunk in raw.replace(";", ",").split(",")
        for token in chunk.split()
        if token.strip()
    }
    return frozenset(values)


def effective_limits(worker_count: int) -> tuple[int, int, int]:
    """Return ``(K_eff, L_eff, G_eff)`` coupled to enabled worker capacity."""

    workers = max(0, int(worker_count))
    if workers == 0:
        return (0, 0, 0)
    k_eff = min(program_slots(), workers)
    # Importing farmctl here would create a cycle.  The ratified general symbol
    # cap is three; L is additionally hard-bounded to two above.
    l_eff = min(lanes_per_program(), 3, workers)
    g_eff = min(cell_slots(), k_eff * l_eff, workers)
    return (k_eff, l_eff, g_eff)


def program_id(
    payload: Mapping[str, Any], *, ea_id: object = "", symbol: object = ""
) -> str:
    """Resolve a governed program identity with a deterministic legacy fallback."""

    declared = str(payload.get("program_id") or "").strip()
    if declared:
        return declared
    q12 = str(payload.get("q12_work_item_id") or "").strip()
    if q12:
        return f"q12:{q12}"
    return f"legacy:{ea_id}:{str(symbol or '').upper()}"


def lane_id(
    payload: Mapping[str, Any], *, ea_id: object = "", symbol: object = ""
) -> tuple[str, str]:
    """Resolve the authenticated scheduling lane ``(program_id, arm)``."""

    program = program_id(payload, ea_id=ea_id, symbol=symbol)
    arm = str(payload.get("arm") or "").strip()
    if not arm:
        arm = "legacy"
    return (program, arm)


def pruning_lock_filename(program: str, arm: str | None = None) -> str:
    """Return a path-safe lock name keyed by program+arm.

    ``arm=None`` retains the old name for callers handling a legacy row.  Every
    authenticated DL-089 row supplies an arm and therefore receives lane scope.
    """

    identity = program if arm is None else f"{program}\0{arm}"
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
    return f"DL089_CLAIM_PRUNING.{digest}.lock"


def _row_payload(row: Mapping[str, Any]) -> dict[str, Any]:
    value = row.get("payload")
    if isinstance(value, Mapping):
        return dict(value)
    try:
        value = json.loads(str(row.get("payload_json") or "{}"))
    except (TypeError, json.JSONDecodeError) as exc:
        raise SchedulingError(f"{row.get('id')}: payload_json invalid") from exc
    if not isinstance(value, dict):
        raise SchedulingError(f"{row.get('id')}: payload_json is not an object")
    return value


def arm_frontier(
    rows: Sequence[Mapping[str, Any]],
    sealed_ledger: Mapping[str, Any],
) -> dict[tuple[str, str], Mapping[str, Any]]:
    """Authenticate a complete annual matrix and return one head per arm.

    A head is the smallest non-terminal declared year.  Missing/duplicate rows,
    identity drift, malformed years, and a skipped predecessor followed by a
    non-terminal row fail closed instead of creating claim permission.
    """

    program = str(sealed_ledger.get("program_id") or "").strip()
    cells = sealed_ledger.get("cells")
    years_raw = sealed_ledger.get("years")
    if not program or not isinstance(cells, list) or not isinstance(years_raw, list):
        raise SchedulingError("sealed ledger is missing program/cells/years")
    try:
        years = [int(year) for year in years_raw]
    except (TypeError, ValueError) as exc:
        raise SchedulingError("sealed ledger years are malformed") from exc
    if not years or years != sorted(set(years)):
        raise SchedulingError("sealed ledger years are not unique ascending values")

    declared_by_id: dict[str, Mapping[str, Any]] = {}
    declared_arms: dict[str, list[int]] = defaultdict(list)
    for cell in cells:
        if not isinstance(cell, Mapping):
            raise SchedulingError("sealed ledger cell is not an object")
        work_item_id = str(cell.get("work_item_id") or "").strip()
        arm = str(cell.get("arm") or "").strip()
        try:
            year = int(cell.get("year"))
        except (TypeError, ValueError) as exc:
            raise SchedulingError(f"{work_item_id or '<cell>'}: malformed year") from exc
        if not work_item_id or not arm or year not in years:
            raise SchedulingError("sealed ledger cell identity is incomplete")
        if work_item_id in declared_by_id:
            raise SchedulingError(f"duplicate declared work_item_id: {work_item_id}")
        declared_by_id[work_item_id] = cell
        declared_arms[arm].append(year)
    for arm, arm_years in declared_arms.items():
        if arm_years != years:
            raise SchedulingError(
                f"declared arm {arm} is missing, duplicate, or out of year order"
            )

    by_id: dict[str, Mapping[str, Any]] = {}
    for row in rows:
        work_item_id = str(row.get("id") or "").strip()
        if work_item_id in by_id:
            raise SchedulingError(f"duplicate database row: {work_item_id}")
        by_id[work_item_id] = row
    missing = sorted(set(declared_by_id) - set(by_id))
    extras = sorted(set(by_id) - set(declared_by_id))
    if missing or extras:
        raise SchedulingError(f"matrix row coverage mismatch missing={missing} extras={extras}")

    ordered_rows: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for work_item_id, declared in declared_by_id.items():
        row = by_id[work_item_id]
        payload = _row_payload(row)
        for key in ("program_id", "cell_key", "arm", "year", "direction", "predicate_id"):
            expected = program if key == "program_id" else declared.get(key)
            if payload.get(key) != expected:
                raise SchedulingError(
                    f"{work_item_id}: declared identity mismatch for {key}"
                )
        if str(row.get("setfile_path") or "") != str(declared.get("setfile_path") or ""):
            raise SchedulingError(f"{work_item_id}: declared setfile mismatch")
        ordered_rows[str(declared["arm"])].append(row)

    result: dict[tuple[str, str], Mapping[str, Any]] = {}
    for arm, arm_rows in ordered_rows.items():
        arm_rows.sort(key=lambda row: int(_row_payload(row)["year"]))
        skipped_seen = False
        for row in arm_rows:
            status = str(row.get("status") or "").lower()
            verdict = str(row.get("verdict") or "").upper()
            if status in TERMINAL_STATUSES:
                skipped_seen = skipped_seen or verdict == "SKIPPED_EXCLUDED"
                continue
            if status not in {"pending", "active"}:
                raise SchedulingError(f"{row.get('id')}: unknown nonterminal status {status}")
            if skipped_seen:
                raise SchedulingError(
                    f"{row.get('id')}: later nonterminal row follows SKIPPED_EXCLUDED"
                )
            result[(program, arm)] = row
            break
    return result


def active_census_snapshot(rows: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    """Build the transaction-local active OPT_CENSUS capacity view."""

    active_rows: list[dict[str, Any]] = []
    programs: set[str] = set()
    lanes: set[tuple[str, str]] = set()
    program_lane_counts: Counter[str] = Counter()
    pairs: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        payload = _row_payload(row)
        lane = lane_id(payload, ea_id=row.get("ea_id"), symbol=row.get("symbol"))
        item = {**dict(row), "payload": payload, "lane_id": lane}
        active_rows.append(item)
        programs.add(lane[0])
        lanes.add(lane)
        program_lane_counts[lane[0]] += 1
        pairs[(str(row.get("ea_id")), str(row.get("symbol") or "").upper())].append(item)
    return {
        "total": len(active_rows),
        "programs": programs,
        "lanes": lanes,
        "program_lane_counts": program_lane_counts,
        "pairs": pairs,
        "rows": active_rows,
    }


def duplicate_pair_exception_allowed(
    *,
    candidate: Mapping[str, Any],
    candidate_payload: Mapping[str, Any],
    active_duplicates: Sequence[Mapping[str, Any]],
    l_eff: int,
    candidate_is_multisymbol: bool,
    allowlist: Iterable[str] | None = None,
) -> bool:
    """Authenticate the default-off, OPT_CENSUS-only duplicate-pair exception."""

    program, arm = lane_id(
        candidate_payload,
        ea_id=candidate.get("ea_id"),
        symbol=candidate.get("symbol"),
    )
    allowed = same_program_parallel_allowlist() if allowlist is None else frozenset(allowlist)
    if candidate_is_multisymbol or l_eff <= 1 or program not in allowed:
        return False
    if str(candidate.get("phase") or "").upper() != "OPT_CENSUS":
        return False
    if not active_duplicates or len(active_duplicates) >= min(l_eff, 2):
        return False
    seen = {(program, arm)}
    for row in active_duplicates:
        if str(row.get("phase") or "").upper() != "OPT_CENSUS":
            return False
        payload = row.get("payload")
        if not isinstance(payload, Mapping):
            payload = _row_payload(row)
        lane = lane_id(payload, ea_id=row.get("ea_id"), symbol=row.get("symbol"))
        if lane[0] != program or lane in seen:
            return False
        seen.add(lane)
    return True
