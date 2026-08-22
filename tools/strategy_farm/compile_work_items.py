"""Governed COMPILE_EA enqueue, candidate guards, and worker execution."""

from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import uuid
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

try:
    from include_mirror import running_terminal_names
except ModuleNotFoundError:
    from tools.strategy_farm.include_mirror import running_terminal_names


COMPILE_WORK_ITEM_KIND = "compile"
COMPILE_EA_PHASE = "COMPILE_EA"
COMPILE_CONTRACT_VERSION = "qm.compile-ea-work-item/v1"
COMPILE_ACTIVATION_HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"
COMPILE_ACTIVATION_HOLD_REASON = (
    "COMPILE_EA rows require the reviewed worker version on the full terminal fleet; "
    "release only through the governed release-on-restart ceremony"
)
R11_REVIVAL_CONTRACT_VERSION = "qm.r11-compile-ea-revival/v1"
R11_REVIVAL_AUTHORITY_TASK_ID = "83be33f3-a45d-453b-bb70-79d10a7841e9"
R11_REVIVAL_REASON = "R11_FALSE_INVALID_EX5_MISSING"
R11_INCIDENT_HANDLER = "R11_pending_unclaimable_work_item"
R11_INCIDENT_REASON = "ex5_missing"
COMPILE_RECHECK_RETRY_CONTRACT_VERSION = "qm.compile-ea-candidate-recheck-retry/v1"
COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID = "1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8"
COMPILE_RECHECK_FAILURE_CLASS = "CANDIDATE_RECHECK_REFUSED"
COMPILE_BINDING_RETRY_CONTRACT_VERSION = "qm.compile-ea-build-binding-retry/v1"
COMPILE_BINDING_FAILURE_CLASS = "BUILD_CHECK_FAILED"
VALID_TIMEFRAMES = (
    # Kept exactly aligned with gen_setfile.ps1's ValidateSet: a candidate
    # must be generatable, not merely a valid MetaTrader period literal.
    "MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
    "M30", "M15", "M10", "M5", "M2", "M1",
)
_TF_ALTERNATION = "|".join(VALID_TIMEFRAMES)
_EA_LABEL_RE = re.compile(r"^(QM5_([0-9]+)_([A-Za-z0-9][A-Za-z0-9_-]*))$")
_BOUND_HASH_RE = re.compile(r"^[0-9a-fA-F]{64}$")

# DL-089 Wave 1 live-book requalification: an explicit, named force-rebuild
# allowlist for the 16 EAs still stuck behind the default "no existing .ex5"
# classifier guard. Overwriting the old .ex5 is the entire point of a
# requalification rebuild for these EAs specifically - this is NOT a general
# .ex5-overwrite path; every other candidate keeps the default guards.
DL089_FORCE_REBUILD_OWNER_REFERENCE = "OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION"
DL089_FORCE_REBUILD_EA_IDS = frozenset({
    "1556", "1567", "10919", "10939", "11132", "11165", "11421", "11708",
    "12567", "12778", "12969", "12989", "13117", "13128", "13213", "13301",
})
FORCE_REBUILD_WAIVABLE_REASONS = frozenset({
    "EX5_ALREADY_PRESENT", "WORK_ITEMS_EXIST", "BOUND_SETFILE_HASH_EXISTS",
    "BUILD_TASK_EXISTS",
})
MAE_HOOK_FORCE_REBUILD_OWNER_REFERENCE = (
    "OWNER_TASK_8fe2a461_2026-08-22_MAE_HOOK_EMERGENCY_REBUILD"
)
MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID = "8fe2a461-f70e-489f-ab54-a9ea7d15914c"
MAE_HOOK_FORCE_REBUILD_EA_IDS = frozenset({
    "12947", "12948", "12949", "12950", "12951", "12952",
})


def dl089_force_rebuild_allowlist(repo_root: Path) -> frozenset[str]:
    """Return the numeric EA ids authorized for a COMPILE_EA force-rebuild.

    Fail-closed: an id only clears the bypass when the hardcoded
    DL089_FORCE_REBUILD_EA_IDS name AND a live owner_priority_tracks.json row
    bound to the exact DL-089 owner_reference both agree. Removing the
    registry row (e.g. an OWNER revocation) silently turns the bypass back
    off for that EA without a code change.
    """
    tracks_path = repo_root / "framework" / "registry" / "owner_priority_tracks.json"
    try:
        document = json.loads(tracks_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return frozenset()
    entries = document.get("entries") if isinstance(document, dict) else None
    if not isinstance(entries, list):
        return frozenset()
    authorized: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        if entry.get("owner_reference") != DL089_FORCE_REBUILD_OWNER_REFERENCE:
            continue
        ea_id = _numeric_ea_reference(entry.get("ea_id"))
        if ea_id and ea_id in DL089_FORCE_REBUILD_EA_IDS:
            authorized.add(ea_id)
    return frozenset(authorized)


def mae_hook_force_rebuild_allowlist(root: Path) -> frozenset[str]:
    """Honor only the exact routed OWNER emergency rebuild ticket.

    Existing binaries/set bindings remain a default refusal everywhere else.
    The ticket identity and its explicit six-EA goal are both required, so a
    copied/stale checkout cannot manufacture a general overwrite capability.
    """
    try:
        with _connect(root) as conn:
            row = conn.execute(
                "SELECT payload_json FROM agent_tasks WHERE id=?",
                (MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID,),
            ).fetchone()
    except (OSError, sqlite3.Error):
        return frozenset()
    if row is None:
        return frozenset()
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except json.JSONDecodeError:
        return frozenset()
    goal = str(payload.get("goal") or "")
    title = str(payload.get("title") or "")
    if "12947-12952" not in goal or "MAE-Hook" not in title:
        return frozenset()
    return MAE_HOOK_FORCE_REBUILD_EA_IDS


def force_rebuild_allowlist(root: Path, repo_root: Path) -> frozenset[str]:
    return dl089_force_rebuild_allowlist(repo_root) | mae_hook_force_rebuild_allowlist(root)


def force_rebuild_owner_reference(ea_id: str) -> str:
    if ea_id in MAE_HOOK_FORCE_REBUILD_EA_IDS:
        return MAE_HOOK_FORCE_REBUILD_OWNER_REFERENCE
    return DL089_FORCE_REBUILD_OWNER_REFERENCE


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _numeric_ea_reference(value: Any) -> str | None:
    match = re.match(r"^(?:QM5_)?([0-9]+)(?:_|$)", str(value or "").strip(), re.I)
    if not match or int(match.group(1)) <= 0:
        return None
    return str(int(match.group(1)))


def _label_parts(label: str) -> tuple[str, str, str] | None:
    match = _EA_LABEL_RE.fullmatch(str(label or "").strip())
    if not match:
        return None
    return match.group(1), str(int(match.group(2))), match.group(3)


def _connect(root: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(root / "state" / "farm_state.sqlite", timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _bound_setfile_hashes(ea_dir: Path) -> list[dict[str, str]]:
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return []
    bound: list[dict[str, str]] = []
    pattern = re.compile(r"^\s*;\s*build_hash\s*:\s*(\S+)", re.I | re.M)
    for setfile in sorted(sets_dir.glob("*.set")):
        match = pattern.search(
            setfile.read_text(encoding="utf-8-sig", errors="ignore")
        )
        if match and _BOUND_HASH_RE.fullmatch(match.group(1)):
            bound.append({"path": str(setfile), "build_hash": match.group(1).lower()})
    return bound


def _approved_card_path(root: Path, repo_root: Path, label: str) -> Path | None:
    candidates = [
        root / "artifacts" / "cards_approved" / f"{label}.md",
        repo_root / "artifacts" / "cards_approved" / f"{label}.md",
        repo_root / "strategy-seeds" / "cards" / "approved" / f"{label}.md",
        repo_root / "strategy-seeds" / "cards" / f"{label}.md",
    ]
    return next((path for path in candidates if path.is_file()), None)


def infer_timeframe(root: Path, repo_root: Path, ea_dir: Path) -> dict[str, Any]:
    """Infer a host timeframe without silently defaulting to H1."""
    label = ea_dir.name
    sets_dir = ea_dir / "sets"
    set_pattern = re.compile(r"_(" + _TF_ALTERNATION + r")_", re.I)
    set_values = sorted({
        match.group(1).upper()
        for path in (sets_dir.glob("*.set") if sets_dir.is_dir() else [])
        if (match := set_pattern.search(path.name))
    })
    if len(set_values) == 1:
        return {"timeframe": set_values[0], "source": "existing_setfiles", "candidates": set_values}

    card_path = _approved_card_path(root, repo_root, label)
    card_text = (
        card_path.read_text(encoding="utf-8-sig", errors="ignore")
        if card_path else ""
    )
    frontmatter = card_text.split("---", 2)[1] if card_text.startswith("---") and card_text.count("---") >= 2 else ""
    for key in ("period", "timeframe", "primary_timeframe", "host_timeframe"):
        match = re.search(
            rf"(?im)^\s*{key}\s*:\s*({_TF_ALTERNATION})\s*$",
            frontmatter,
        )
        if match:
            return {
                "timeframe": match.group(1).upper(),
                "source": f"card_frontmatter:{key}",
                "card_path": str(card_path),
                "candidates": [match.group(1).upper()],
            }

    label_values = [
        value.upper()
        for value in re.findall(
            r"(?:^|[-_])(" + _TF_ALTERNATION + r")(?=[-_]|$)",
            label,
            flags=re.I,
        )
    ]
    label_values = list(dict.fromkeys(label_values))
    if len(label_values) == 1:
        return {"timeframe": label_values[0], "source": "ea_label", "candidates": label_values}

    source = ea_dir / f"{label}.mq5"
    source_text = source.read_text(encoding="utf-8-sig", errors="ignore") if source.is_file() else ""
    source_values = sorted({
        value.upper()
        for value in re.findall(r"\bPERIOD_(" + _TF_ALTERNATION + r")\b", source_text, re.I)
    })
    if len(source_values) == 1:
        return {"timeframe": source_values[0], "source": "mq5_period_literal", "candidates": source_values}

    explicit_card_patterns = (
        r"(?im)^\s*-?\s*Timeframe\s*:\s*(`?)(" + _TF_ALTERNATION + r")\1\b",
        r"(?im)\b(" + _TF_ALTERNATION + r")\s+primary\b",
        r"(?im)\bEvaluate\s+on\b[^\n]{0,80}\b(" + _TF_ALTERNATION + r")\s+bar\b",
        r"(?im)\b(" + _TF_ALTERNATION + r")\s+timeframe\b",
    )
    for pattern in explicit_card_patterns:
        match = re.search(pattern, card_text)
        if match:
            value = match.group(match.lastindex or 1).upper()
            return {
                "timeframe": value,
                "source": "card_explicit_host_timeframe",
                "card_path": str(card_path),
                "candidates": [value],
            }

    card_values = sorted({
        value.upper()
        for value in re.findall(r"\b(" + _TF_ALTERNATION + r")\b", card_text, re.I)
    })
    if len(card_values) == 1:
        return {
            "timeframe": card_values[0],
            "source": "card_unique_timeframe",
            "card_path": str(card_path),
            "candidates": card_values,
        }
    return {
        "timeframe": None,
        "source": "unresolved",
        "card_path": str(card_path) if card_path else None,
        "candidates": {
            "setfiles": set_values,
            "label": label_values,
            "source": source_values,
            "card": card_values,
        },
    }


def _inventory(root: Path, repo_root: Path) -> dict[str, Any]:
    registry_rows = _read_csv(repo_root / "framework" / "registry" / "ea_id_registry.csv")
    magic_rows = _read_csv(repo_root / "framework" / "registry" / "magic_numbers.csv")
    registry_by_id: dict[str, list[dict[str, str]]] = defaultdict(list)
    active_magics: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in registry_rows:
        if (ea_id := _numeric_ea_reference(row.get("ea_id"))):
            registry_by_id[ea_id].append(row)
    for row in magic_rows:
        if (
            (ea_id := _numeric_ea_reference(row.get("ea_id")))
            and str(row.get("status") or "").strip().lower() == "active"
        ):
            active_magics[ea_id].append(row)
    with _connect(root) as conn:
        work_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
        open_compile: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in conn.execute(
            "SELECT id,ea_id,phase,status,verdict,evidence_path,payload_json "
            "FROM work_items"
        ):
            ea_id = _numeric_ea_reference(row["ea_id"])
            if not ea_id:
                continue
            item = dict(row)
            work_rows[ea_id].append(item)
            if row["phase"] == COMPILE_EA_PHASE and row["status"] in ("pending", "active"):
                open_compile[ea_id].append(item)
        build_ids = {
            ea_id
            for row in conn.execute(
                "SELECT DISTINCT card_id FROM tasks "
                "WHERE kind='build_ea' AND status IN ('pending','active','done')"
            )
            if (ea_id := _numeric_ea_reference(row[0]))
        }
    return {
        "registry_by_id": registry_by_id,
        "active_magics": active_magics,
        "work_rows": work_rows,
        "open_compile": open_compile,
        "build_ids": build_ids,
    }


def classify_candidate(
    root: Path,
    repo_root: Path,
    label: str,
    inventory: dict[str, Any],
    *,
    current_work_item_id: str | None = None,
    sanctioned_predecessor_ids: Iterable[str] = (),
    force_rebuild_ea_ids: frozenset[str] = frozenset(),
) -> dict[str, Any]:
    parts = _label_parts(label)
    if not parts:
        return {"ea_label": label, "eligible": False, "reason": "EA_LABEL_INVALID"}
    canonical_label, ea_id, _slug = parts
    open_rows = [
        row for row in inventory["open_compile"].get(ea_id, [])
        if str(row.get("id")) != str(current_work_item_id or "")
    ]
    if open_rows:
        return {
            "ea_label": canonical_label,
            "ea_id": f"QM5_{ea_id}",
            "eligible": False,
            "idempotent_open": True,
            "reason": "OPEN_COMPILE_EA_EXISTS",
            "work_item_ids": [row["id"] for row in open_rows],
        }
    ea_dir = repo_root / "framework" / "EAs" / canonical_label
    source = ea_dir / f"{canonical_label}.mq5"
    ex5 = ea_dir / f"{canonical_label}.ex5"
    reasons: list[str] = []
    if not ea_dir.is_dir():
        reasons.append("EA_DIRECTORY_MISSING")
    if not source.is_file():
        reasons.append("MQ5_SOURCE_MISSING")
    if ex5.exists():
        reasons.append("EX5_ALREADY_PRESENT")
    registry_rows = inventory["registry_by_id"].get(ea_id, [])
    if len(registry_rows) != 1:
        reasons.append("EA_ID_REGISTRY_IDENTITY_INVALID")
    elif str(registry_rows[0].get("status") or "").strip().lower() != "active":
        reasons.append("EA_ID_REGISTRY_NOT_ACTIVE")
    magic_rows = inventory["active_magics"].get(ea_id, [])
    symbols = sorted({
        str(row.get("symbol") or "").strip()
        for row in magic_rows
        if str(row.get("symbol") or "").strip()
    })
    if not magic_rows:
        reasons.append("ACTIVE_MAGIC_ROWS_MISSING")
    if not symbols:
        reasons.append("ACTIVE_MAGIC_SYMBOLS_MISSING")
    invalid_symbols = [
        symbol for symbol in symbols
        if not re.fullmatch(r"[A-Z0-9._]+\.DWX", symbol, re.I)
    ]
    if invalid_symbols:
        reasons.append("SETFILE_SYMBOL_UNSUPPORTED")
    sanctioned_ids = {
        str(value) for value in sanctioned_predecessor_ids if str(value or "")
    }
    ignored_ids = sanctioned_ids | {str(current_work_item_id or "")}
    other_work = [
        row for row in inventory["work_rows"].get(ea_id, [])
        if str(row.get("id")) not in ignored_ids
    ]
    if other_work:
        reasons.append("WORK_ITEMS_EXIST")
    if ea_id in inventory["build_ids"]:
        reasons.append("BUILD_TASK_EXISTS")
    bound_hashes = _bound_setfile_hashes(ea_dir) if ea_dir.is_dir() else []
    if bound_hashes:
        reasons.append("BOUND_SETFILE_HASH_EXISTS")
    timeframe = infer_timeframe(root, repo_root, ea_dir) if source.is_file() else {
        "timeframe": None,
        "source": "source_missing",
        "candidates": [],
    }
    if source.is_file() and not timeframe.get("timeframe"):
        reasons.append("TIMEFRAME_UNRESOLVED")

    force_rebuild_authorized = ea_id in force_rebuild_ea_ids
    force_rebuild_waived_reasons: list[str] = []
    if force_rebuild_authorized:
        force_rebuild_waived_reasons = sorted(
            reason for reason in reasons if reason in FORCE_REBUILD_WAIVABLE_REASONS
        )
        reasons = [
            reason for reason in reasons if reason not in FORCE_REBUILD_WAIVABLE_REASONS
        ]

    return {
        "ea_label": canonical_label,
        "ea_id": f"QM5_{ea_id}",
        "numeric_ea_id": ea_id,
        "ea_dir": str(ea_dir),
        "mq5_path": str(source),
        "mq5_sha256": sha256_file(source) if source.is_file() else None,
        "eligible": not reasons,
        "reason": "ELIGIBLE" if not reasons else reasons[0],
        "reasons": reasons,
        "symbols": symbols,
        "unsupported_symbols": invalid_symbols,
        "active_magic_row_count": len(magic_rows),
        "bound_setfile_hashes": bound_hashes,
        "timeframe": timeframe,
        "sanctioned_predecessor_ids": sorted(sanctioned_ids),
        "force_rebuild_authorized": force_rebuild_authorized,
        "force_rebuild_waived_reasons": force_rebuild_waived_reasons,
    }


def _json_object(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _work_row_by_id(
    inventory: dict[str, Any], ea_id: str, work_item_id: str
) -> dict[str, Any] | None:
    return next(
        (
            row
            for row in inventory["work_rows"].get(ea_id, [])
            if str(row.get("id")) == str(work_item_id)
        ),
        None,
    )


def _sanctioned_compile_predecessor_ids(
    payload: dict[str, Any],
    inventory: dict[str, Any],
    ea_id: str,
    *,
    seen: frozenset[str] = frozenset(),
) -> set[str]:
    """Return only incident-authorized immutable COMPILE_EA lineage.

    COMPILE_EA normally refuses an EA with *any* prior work. The R11 repair
    incident necessarily leaves one immutable failed COMPILE_EA predecessor,
    and the first post-revival canary left a second immutable failure before
    this check was corrected. Those two exact lineages are the only exception;
    malformed provenance fails closed and ordinary Q work is never ignored.
    """

    source_sha = str(payload.get("mq5_sha256") or "").lower()
    if not _BOUND_HASH_RE.fullmatch(source_sha):
        return set()

    if (
        payload.get("compile_retry_contract_version")
        == COMPILE_BINDING_RETRY_CONTRACT_VERSION
        and payload.get("compile_retry_authority_task_id")
        == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        and payload.get("append_only_retry") is True
    ):
        predecessor_id = str(payload.get("retry_of_work_item_id") or "")
        if not predecessor_id or predecessor_id in seen:
            return set()
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        if not predecessor:
            return set()
        predecessor_payload = _json_object(predecessor.get("payload_json"))
        compile_result = predecessor_payload.get("compile_result")
        failure_classes = (
            compile_result.get("failure_classes", [])
            if isinstance(compile_result, dict)
            else []
        )
        if not (
            predecessor.get("phase") == COMPILE_EA_PHASE
            and predecessor.get("status") == "failed"
            and predecessor.get("verdict") == "COMPILE_FAIL"
            and predecessor_payload.get("verdict_reason")
            == COMPILE_BINDING_FAILURE_CLASS
            and failure_classes == [COMPILE_BINDING_FAILURE_CLASS]
            and predecessor_payload.get("compile_retry_contract_version")
            == COMPILE_RECHECK_RETRY_CONTRACT_VERSION
            and predecessor_payload.get("compile_retry_authority_task_id")
            == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
            and predecessor_payload.get("append_only_retry") is True
            and str(predecessor_payload.get("mq5_sha256") or "").lower()
            == source_sha
        ):
            return set()
        earlier = _sanctioned_compile_predecessor_ids(
            predecessor_payload,
            inventory,
            ea_id,
            seen=seen | {predecessor_id},
        )
        if not earlier:
            return set()
        return {predecessor_id, *earlier}

    if (
        payload.get("compile_retry_contract_version")
        == COMPILE_RECHECK_RETRY_CONTRACT_VERSION
        and payload.get("compile_retry_authority_task_id")
        == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        and payload.get("append_only_retry") is True
    ):
        predecessor_id = str(payload.get("retry_of_work_item_id") or "")
        if not predecessor_id or predecessor_id in seen:
            return set()
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        if not predecessor:
            return set()
        predecessor_payload = _json_object(predecessor.get("payload_json"))
        compile_result = predecessor_payload.get("compile_result")
        failure_classes = (
            compile_result.get("failure_classes", [])
            if isinstance(compile_result, dict)
            else []
        )
        if not (
            predecessor.get("phase") == COMPILE_EA_PHASE
            and predecessor.get("status") == "failed"
            and predecessor.get("verdict") == "COMPILE_FAIL"
            and predecessor_payload.get("verdict_reason")
            == COMPILE_RECHECK_FAILURE_CLASS
            and failure_classes == [COMPILE_RECHECK_FAILURE_CLASS]
            and str(predecessor_payload.get("mq5_sha256") or "").lower()
            == source_sha
        ):
            return set()
        earlier = _sanctioned_compile_predecessor_ids(
            predecessor_payload,
            inventory,
            ea_id,
            seen=seen | {predecessor_id},
        )
        # A retry is valid only when its failed predecessor itself has the exact
        # R11 revival lineage. This prevents a forged retry marker from hiding
        # arbitrary historical work.
        if not earlier:
            return set()
        return {predecessor_id, *earlier}

    if not (
        payload.get("revival_contract_version") == R11_REVIVAL_CONTRACT_VERSION
        and payload.get("revival_authority_task_id") == R11_REVIVAL_AUTHORITY_TASK_ID
        and payload.get("revival_reason") == R11_REVIVAL_REASON
        and payload.get("append_only_revival") is True
        and str(payload.get("revival_source_mq5_sha256") or "").lower()
        == source_sha
    ):
        return set()
    predecessor_id = str(payload.get("revived_from_work_item_id") or "")
    if not predecessor_id or predecessor_id in seen:
        return set()
    predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
    if not predecessor:
        return set()
    predecessor_payload = _json_object(predecessor.get("payload_json"))
    if not (
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "INVALID"
        and predecessor_payload.get("repair_handler") == R11_INCIDENT_HANDLER
        and predecessor_payload.get("verdict_reason") == R11_INCIDENT_REASON
        and str(predecessor_payload.get("mq5_sha256") or "").lower()
        == source_sha
    ):
        return set()
    return {predecessor_id}


def load_labels(explicit: Iterable[str], from_file: str | None, repo_root: Path) -> tuple[list[str], dict[str, Any]]:
    labels = [str(value).strip() for value in explicit if str(value).strip()]
    metadata: dict[str, Any] = {"from_file": None, "from_file_sha256": None}
    if from_file:
        path = Path(from_file).expanduser()
        if not path.is_absolute():
            path = repo_root / path
        path = path.resolve()
        if not path.is_file():
            raise ValueError(f"compile label input does not exist: {path}")
        metadata.update({"from_file": str(path), "from_file_sha256": sha256_file(path)})
        if path.suffix.lower() == ".csv":
            with path.open(encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle)
                fields = reader.fieldnames or []
                column = next((key for key in ("ea_label", "label") if key in fields), None)
                if not column:
                    raise ValueError("compile CSV requires an ea_label or label column")
                labels.extend(str(row.get(column) or "").strip() for row in reader)
        else:
            labels.extend(
                line.strip()
                for line in path.read_text(encoding="utf-8-sig").splitlines()
                if line.strip() and not line.lstrip().startswith("#")
            )
    unique = list(dict.fromkeys(label for label in labels if label))
    unique.sort(key=lambda label: (
        int(_label_parts(label)[1]) if _label_parts(label) else 10**12,
        label,
    ))
    metadata["requested_count"] = len(unique)
    return unique, metadata


def enqueue_compile_eas(
    root: Path,
    repo_root: Path,
    explicit_labels: Iterable[str],
    *,
    from_file: str | None = None,
    apply: bool = False,
) -> dict[str, Any]:
    labels, input_metadata = load_labels(explicit_labels, from_file, repo_root)
    if not labels:
        return {"ok": False, "reason": "NO_EA_LABELS", "enqueued_count": 0}
    # Explicit labels are an intentionally narrow single/manual form.  A file
    # is the batch form and remains dry-run until --apply is present.
    apply_effective = bool(apply or not from_file)
    inventory = _inventory(root, repo_root)
    force_rebuild_ea_ids = force_rebuild_allowlist(root, repo_root)
    classified = [
        classify_candidate(
            root, repo_root, label, inventory,
            force_rebuild_ea_ids=force_rebuild_ea_ids,
        )
        for label in labels
    ]
    eligible = [row for row in classified if row.get("eligible")]
    idempotent = [row for row in classified if row.get("idempotent_open")]
    refused = [row for row in classified if not row.get("eligible") and not row.get("idempotent_open")]
    enqueued: list[dict[str, Any]] = []
    if apply_effective and eligible:
        now = utc_now()
        with _connect(root) as conn:
            conn.execute("BEGIN IMMEDIATE")
            for candidate in eligible:
                existing = conn.execute(
                    "SELECT id FROM work_items WHERE ea_id=? AND phase=? "
                    "AND status IN ('pending','active') ORDER BY created_at LIMIT 1",
                    (candidate["ea_id"], COMPILE_EA_PHASE),
                ).fetchone()
                if existing:
                    idempotent.append({
                        **candidate,
                        "eligible": False,
                        "idempotent_open": True,
                        "reason": "OPEN_COMPILE_EA_EXISTS",
                        "work_item_ids": [existing["id"]],
                    })
                    continue
                if not candidate.get("force_rebuild_authorized"):
                    any_work = conn.execute(
                        "SELECT id FROM work_items WHERE ea_id=? LIMIT 1",
                        (candidate["ea_id"],),
                    ).fetchone()
                    if any_work:
                        refused.append({
                            **candidate,
                            "eligible": False,
                            "reason": "WORK_ITEMS_EXIST_AT_APPLY",
                            "reasons": ["WORK_ITEMS_EXIST_AT_APPLY"],
                        })
                        continue
                work_item_id = str(uuid.uuid4())
                payload = {
                    "compile_contract_version": COMPILE_CONTRACT_VERSION,
                    "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
                    "compile_activation_hold_code": COMPILE_ACTIVATION_HOLD_CODE,
                    "ea_label": candidate["ea_label"],
                    "ea_dir": candidate["ea_dir"],
                    "mq5_path": candidate["mq5_path"],
                    "mq5_sha256": candidate["mq5_sha256"],
                    "symbols": candidate["symbols"],
                    "timeframe": candidate["timeframe"],
                    "risk_contract": {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0},
                    "utility_phase": True,
                    "no_gate_verdict": True,
                    "enqueued_at": now,
                }
                if candidate.get("force_rebuild_authorized"):
                    payload.update({
                        "force_rebuild": True,
                        "force_rebuild_owner_reference": force_rebuild_owner_reference(
                            str(candidate["numeric_ea_id"])
                        ),
                        "force_rebuild_waived_reasons": candidate.get(
                            "force_rebuild_waived_reasons", []
                        ),
                    })
                conn.execute(
                    "INSERT INTO work_items "
                    "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
                    "payload_json,created_at,updated_at) "
                    "VALUES (?,?,?,?,?,'','pending',0,?,?,?)",
                    (
                        work_item_id,
                        COMPILE_WORK_ITEM_KIND,
                        COMPILE_EA_PHASE,
                        candidate["ea_id"],
                        "",
                        json.dumps(payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.execute(
                    "INSERT INTO work_item_holds "
                    "(work_item_id,hold_code,reason,active,release_on_restart,"
                    "created_at,updated_at,released_at,release_note) "
                    "VALUES (?,?,?,1,1,?,?,NULL,NULL)",
                    (
                        work_item_id,
                        COMPILE_ACTIVATION_HOLD_CODE,
                        COMPILE_ACTIVATION_HOLD_REASON,
                        now,
                        now,
                    ),
                )
                enqueued.append({
                    "work_item_id": work_item_id,
                    "ea_id": candidate["ea_id"],
                    "ea_label": candidate["ea_label"],
                    "symbol_count": len(candidate["symbols"]),
                    "timeframe": candidate["timeframe"],
                    "status": "pending",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": [],
                    "activation_hold_code": COMPILE_ACTIVATION_HOLD_CODE,
                })
            conn.commit()
    return {
        "ok": not refused,
        "mode": "apply" if apply_effective else "dry_run",
        "batch_form": bool(from_file),
        "input_metadata": input_metadata,
        "requested_count": len(labels),
        "eligible_count": len(eligible),
        "enqueued_count": len(enqueued),
        "activation_held_count": len(enqueued),
        "idempotent_open_count": len(idempotent),
        "refused_count": len(refused),
        "enqueued": enqueued,
        "idempotent_open": idempotent,
        "refused": refused,
        "candidate_classification": classified if not apply_effective else None,
        "no_gate_verdict": True,
    }


def compile_batch_status(
    root: Path,
    repo_root: Path,
    explicit_labels: Iterable[str],
    *,
    from_file: str | None = None,
) -> dict[str, Any]:
    """Report the latest COMPILE_EA outcome per requested EA label."""
    labels, input_metadata = load_labels(explicit_labels, from_file, repo_root)
    if not labels:
        return {"ok": False, "reason": "NO_EA_LABELS", "results": []}
    results: list[dict[str, Any]] = []
    with _connect(root) as conn:
        for label in labels:
            parts = _label_parts(label)
            if not parts:
                results.append({
                    "ea_label": label,
                    "status": "NOT_FOUND",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": ["EA_LABEL_INVALID"],
                })
                continue
            ea_id = f"QM5_{parts[1]}"
            row = conn.execute(
                "SELECT w.*,h.hold_code,h.active AS hold_active "
                "FROM work_items w LEFT JOIN work_item_holds h ON h.work_item_id=w.id "
                "WHERE w.ea_id=? AND w.phase=? "
                "ORDER BY w.created_at DESC,w.id DESC LIMIT 1",
                (ea_id, COMPILE_EA_PHASE),
            ).fetchone()
            if row is None:
                results.append({
                    "ea_label": label,
                    "ea_id": ea_id,
                    "status": "NOT_ENQUEUED",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": [],
                })
                continue
            payload = json.loads(row["payload_json"] or "{}")
            compile_result = payload.get("compile_result") or {}
            status = str(row["status"] or "")
            verdict = str(row["verdict"] or "")
            results.append({
                "ea_label": label,
                "ea_id": ea_id,
                "work_item_id": row["id"],
                "status": status,
                "verdict": verdict or None,
                "compiled": status == "done" and verdict == "COMPILE_OK",
                "failed": status == "failed" or verdict == "COMPILE_FAIL",
                "failure_classes": list(compile_result.get("failure_classes") or []),
                "ex5_sha256": compile_result.get("ex5_sha256"),
                "setfile_count": compile_result.get("setfile_count", 0),
                "build_check_result": compile_result.get("build_check_result"),
                "evidence_path": row["evidence_path"],
                "activation_hold": (
                    row["hold_code"] if row["hold_active"] == 1 else None
                ),
            })
    counts = {
        "compiled": sum(1 for row in results if row["compiled"]),
        "failed": sum(1 for row in results if row["failed"]),
        "pending": sum(1 for row in results if row["status"] == "pending"),
        "active": sum(1 for row in results if row["status"] == "active"),
        "not_enqueued": sum(
            1 for row in results if row["status"] in {"NOT_ENQUEUED", "NOT_FOUND"}
        ),
        "activation_held": sum(1 for row in results if row.get("activation_hold")),
    }
    return {
        "ok": counts["not_enqueued"] == 0,
        "input_metadata": input_metadata,
        "requested_count": len(labels),
        "counts": counts,
        "results": results,
        "no_gate_verdict": True,
    }


def _atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temp.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def _output_value(output: str, key: str) -> str | None:
    match = re.search(rf"(?m)^\s*{re.escape(key)}=(.*)$", output)
    return match.group(1).strip() if match else None


def _output_bool(output: str, key: str) -> bool | None:
    value = _output_value(output, key)
    if value is None:
        return None
    normalized = value.strip().lower()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    return None


def _failure_classes(output: str, exit_code: int) -> list[str]:
    classes: list[str] = []
    reason = _output_value(output, "compile_one.reason_class")
    if reason and reason != "OK":
        classes.append(reason)
    for match in re.finditer(r"(?m)^ERROR:\s*([A-Z][A-Z0-9_]+)", output):
        classes.append(match.group(1))
    if exit_code != 0 and not classes:
        classes.append("BUILD_CHECK_FAILED")
    return list(dict.fromkeys(classes))


def _complete_work_item(
    root: Path,
    work_item_id: str,
    terminal: str,
    evidence_path: Path,
    evidence: dict[str, Any],
) -> None:
    success = bool(evidence.get("success"))
    status = "done" if success else "failed"
    verdict = "COMPILE_OK" if success else "COMPILE_FAIL"
    now = utc_now()
    with _connect(root) as conn:
        row = conn.execute(
            "SELECT payload_json,status,claimed_by FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if not row or row["status"] != "active" or str(row["claimed_by"]).upper() != terminal.upper():
            raise RuntimeError(
                f"COMPILE_EA ownership changed before completion: {work_item_id}"
            )
        payload = json.loads(row["payload_json"] or "{}")
        payload.update({
            "compile_completed_at": now,
            "compile_result": {
                "success": success,
                "failure_classes": evidence.get("failure_classes", []),
                "compile_result": evidence.get("compile_result"),
                "build_check_result": evidence.get("build_check_result"),
                "ex5_sha256": evidence.get("ex5_sha256"),
                "setfile_count": evidence.get("setfile_count", 0),
                "evidence_path": str(evidence_path),
                "no_gate_verdict": True,
            },
            "verdict_reason": (
                "COMPILE_ARTIFACT_READY"
                if success
                else ";".join(evidence.get("failure_classes") or ["COMPILE_FAILED"])
            ),
        })
        cur = conn.execute(
            "UPDATE work_items SET status=?,verdict=?,evidence_path=?,claimed_by=NULL,"
            "payload_json=?,updated_at=? WHERE id=? AND status='active' AND upper(claimed_by)=upper(?)",
            (
                status,
                verdict,
                str(evidence_path),
                json.dumps(payload, sort_keys=True),
                now,
                work_item_id,
                terminal,
            ),
        )
        if cur.rowcount != 1:
            conn.rollback()
            raise RuntimeError(f"COMPILE_EA completion CAS failed: {work_item_id}")
        conn.commit()


def run_compile_work_item(
    root: Path,
    repo_root: Path,
    item: sqlite3.Row | dict[str, Any],
    terminal: str,
) -> dict[str, Any]:
    """Run one already-claimed COMPILE_EA row without launching terminal64."""
    work_item_id = str(item["id"])
    report_dir = (
        Path(r"D:\QM\reports\work_items")
        / work_item_id
        / str(item["ea_id"])
        / COMPILE_EA_PHASE
    )
    evidence_path = report_dir / "compile_evidence.json"
    started_at = utc_now()
    evidence: dict[str, Any] = {
        "schema_version": "qm.compile-ea-evidence/v1",
        "work_item_id": work_item_id,
        "ea_id": str(item["ea_id"]),
        "phase": COMPILE_EA_PHASE,
        "terminal_claim": terminal,
        "started_at": started_at,
        "no_gate_verdict": True,
        "failure_classes": [],
        "setfile_generation": [],
    }
    try:
        inventory = _inventory(root, repo_root)
        payload = json.loads(item["payload_json"] or "{}")
        evidence["claim_admission_mode"] = payload.get("claim_admission_mode")
        evidence["claim_admission_commit_headroom_gb"] = payload.get(
            "claim_admission_commit_headroom_gb"
        )
        evidence["claim_admission_commit_reserved_gb"] = payload.get(
            "claim_admission_commit_reserved_gb"
        )
        evidence["claim_admission_effective_commit_headroom_gb"] = payload.get(
            "claim_admission_effective_commit_headroom_gb"
        )
        label = str(payload.get("ea_label") or "")
        parts = _label_parts(label)
        sanctioned_predecessors = (
            _sanctioned_compile_predecessor_ids(
                payload,
                inventory,
                parts[1],
            )
            if parts
            else set()
        )
        candidate = classify_candidate(
            root,
            repo_root,
            label,
            inventory,
            current_work_item_id=work_item_id,
            sanctioned_predecessor_ids=sanctioned_predecessors,
            force_rebuild_ea_ids=force_rebuild_allowlist(root, repo_root),
        )
        evidence["ea_label"] = label
        evidence["candidate_recheck"] = candidate
        if not candidate.get("eligible"):
            raise RuntimeError("CANDIDATE_RECHECK_REFUSED:" + ";".join(candidate.get("reasons") or [candidate.get("reason")]))
        if candidate.get("mq5_sha256") != payload.get("mq5_sha256"):
            raise RuntimeError("SOURCE_CHANGED_AFTER_ENQUEUE")
        running = running_terminal_names()
        evidence["running_terminals_at_worker_start"] = sorted(running)
        if terminal.upper() in running:
            raise RuntimeError("COMPILE_CLAIMED_TERMINAL_RUNNING")
        timeframe = str((candidate.get("timeframe") or {}).get("timeframe") or "")
        if not timeframe:
            raise RuntimeError("TIMEFRAME_UNRESOLVED")
        ea_dir = Path(candidate["ea_dir"])
        symbols = list(candidate["symbols"])
        env = os.environ.copy()
        env["QM_COMPILE_WORK_ITEM_ID"] = work_item_id
        env["QM_COMPILE_CLAIMED_TERMINAL"] = terminal.upper()
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        generator = repo_root / "framework" / "scripts" / "gen_setfile.ps1"
        for symbol in symbols:
            command = [
                "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", str(generator),
                "-EaSlug", label,
                "-Symbol", symbol,
                "-TF", timeframe,
                "-Env", "backtest",
                "-RiskFixed", "1000",
                "-RiskPercent", "0",
            ]
            generated = subprocess.run(
                command,
                cwd=repo_root,
                env=env,
                capture_output=True,
                text=True,
                timeout=300,
                creationflags=creationflags,
                check=False,
            )
            output = (generated.stdout or "") + (generated.stderr or "")
            setfile = ea_dir / "sets" / f"{label}_{symbol}_{timeframe}_backtest.set"
            generation = {
                "symbol": symbol,
                "exit_code": generated.returncode,
                "setfile_path": str(setfile),
                "setfile_exists": setfile.is_file(),
                "setfile_sha256": sha256_file(setfile) if setfile.is_file() else None,
                "output_tail": output[-4000:],
            }
            evidence["setfile_generation"].append(generation)
            if generated.returncode != 0 or not setfile.is_file():
                raise RuntimeError(f"SETFILE_GENERATION_FAILED:{symbol}")

        build_check = repo_root / "framework" / "scripts" / "build_check.ps1"
        build_command = [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(build_check),
            "-EALabel", label,
            "-Strict",
            "-CompileWorkItemId", work_item_id,
            "-ClaimedTerminal", terminal.upper(),
        ]
        checked = subprocess.run(
            build_command,
            cwd=repo_root,
            env=env,
            capture_output=True,
            text=True,
            timeout=1800,
            creationflags=creationflags,
            check=False,
        )
        build_output = (checked.stdout or "") + (checked.stderr or "")
        evidence.update({
            "build_check_exit_code": checked.returncode,
            "build_check_result": _output_value(build_output, "build_check.result"),
            "build_check_report": _output_value(build_output, "build_check.report"),
            "compile_result": _output_value(build_output, "compile_one.result"),
            "compile_reason_class": _output_value(build_output, "compile_one.reason_class"),
            "compile_errors": _output_value(build_output, "compile_one.errors"),
            "compile_warnings": _output_value(build_output, "compile_one.warnings"),
            "compile_log": _output_value(build_output, "compile_one.log"),
            "compile_summary": _output_value(build_output, "compile_one.summary"),
            "include_sync_targets": _output_value(build_output, "compile_one.include_sync_targets"),
            "include_sync_deferred_targets": _output_value(build_output, "compile_one.include_sync_deferred_targets"),
            "include_mirror_mutex": _output_value(build_output, "compile_one.include_mirror_mutex"),
            "include_mirror_atomic_replace": _output_bool(
                build_output,
                "compile_one.include_mirror_atomic_replace",
            ),
            "build_check_output_tail": build_output[-20000:],
        })
        ex5 = ea_dir / f"{label}.ex5"
        setfiles = sorted((ea_dir / "sets").glob("*.set"))
        evidence["ex5_path"] = str(ex5)
        evidence["ex5_sha256"] = sha256_file(ex5) if ex5.is_file() else None
        evidence["setfile_count"] = len(setfiles)
        evidence["failure_classes"] = _failure_classes(build_output, checked.returncode)
        evidence["success"] = bool(
            checked.returncode == 0
            and evidence["build_check_result"] == "PASS"
            and evidence["compile_result"] == "PASS"
            and evidence["ex5_sha256"]
            and evidence["setfile_count"] > 0
        )
        if not evidence["success"] and not evidence["failure_classes"]:
            evidence["failure_classes"] = ["COMPILE_ARTIFACT_CONTRACT_INCOMPLETE"]
    except subprocess.TimeoutExpired as exc:
        evidence.update({
            "success": False,
            "failure_classes": ["COMPILE_WORKER_TIMEOUT"],
            "exception": repr(exc),
        })
    except Exception as exc:
        detail = str(exc)
        failure_class = detail.split(":", 1)[0] if detail else "COMPILE_WORKER_EXCEPTION"
        evidence.update({
            "success": False,
            "failure_classes": [failure_class],
            "exception": repr(exc),
        })
    evidence["completed_at"] = utc_now()
    _atomic_write_json(evidence_path, evidence)
    _complete_work_item(root, work_item_id, terminal, evidence_path, evidence)
    return {
        "action": "compile_ea_finished",
        "item_id": work_item_id,
        "ea_id": str(item["ea_id"]),
        "ea_label": evidence.get("ea_label"),
        "success": evidence.get("success", False),
        "failure_classes": evidence.get("failure_classes", []),
        "compile_result": evidence.get("compile_result"),
        "build_check_result": evidence.get("build_check_result"),
        "ex5_sha256": evidence.get("ex5_sha256"),
        "setfile_count": evidence.get("setfile_count", 0),
        "evidence_path": str(evidence_path),
        "no_gate_verdict": True,
    }
