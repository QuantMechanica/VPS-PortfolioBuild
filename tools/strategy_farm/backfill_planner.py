#!/usr/bin/env python3
"""Frontier-first, earliest-gap-first rebaseline backfill planner.

Dry-run is the default.  The farm database is always inspected through a
``mode=ro`` SQLite URI.  ``--apply`` does not write SQLite directly: after two
explicit guards it invokes the governed ``farmctl enqueue-backtest`` command
recorded in the plan, bounded by ``--max-rows``.

The active runtime is still gate contract v3.  Consequently this planner uses
the gate chain emitted by ``rebaseline_census.py`` and records the contract
version on every row.  It does not activate the read-inert v4 draft.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import shlex
import sqlite3
import statistics
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

import rebaseline_census as census


DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_FARM_ROOT = Path("D:/QM/strategy_farm")
DEFAULT_OUT_DIR = Path("D:/QM/reports/rebaseline")
DEFAULT_MD_DIR = Path("docs/ops/rebaseline")
DEFAULT_CONTRACT_VERSION = "v3"
ACTIVE_SYMBOL_CAP = 3  # farmctl.CLAIM_SYMBOL_ACTIVE_CAP; checked at runtime too.

GATE_CHAIN = tuple(census.GATE_CHAIN)
GATE_INDEX = {gate: index for index, gate in enumerate(GATE_CHAIN)}
RUNTIME_PHASE = {**{gate: gate for gate in GATE_CHAIN}, "Q09": "Q09_NEWS"}
FARMCTL_BACKTEST_PHASES = {
    "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09_NEWS", "Q10"
}

TERMINAL_STATUSES = {"done", "failed"}
PASS_VERDICTS = set(census.PASS_ECON)
ECONOMIC_FAIL_VERDICTS = set(census.ECON_FAIL)
INFRA_VERDICTS = set(census.INFRA_CLS) | set(census.INVALID_CLS)
STALE_VERDICTS = set(census.STALE_CLS)
NA_VERDICTS = set(census.NA_CLS)
ENQUEUE_ACTIONS = {"RERUN_INFRA", "FILL_MISSING", "REBIND_STALE"}
ALL_ACTIONS = (
    "RERUN_INFRA", "FILL_MISSING", "REBIND_STALE", "SKIP_REUSABLE",
    "STOP_ECONOMIC_FAIL", "STOP_NOT_APPLICABLE", "UNKNOWN",
)

STDLIB_MISSING_SIGNATURES = (
    "file 'include\\trade\\trade.mqh' not found",
    'file "include\\trade\\trade.mqh" not found',
    "file 'include\\object.mqh' not found",
    'file "include\\object.mqh" not found',
)

PLAN_COLUMNS = [
    "rank", "record_type", "ea_id", "symbol", "action", "reason",
    "highest_observed_gate", "highest_contiguous_valid_gate",
    "earliest_missing_prerequisite", "target_gate", "runtime_phase",
    "frontier_ordinal", "remaining_gates", "age_days", "oldest_created_at",
    "gate_contract_version", "build_hash", "setfile_hash", "window_from",
    "window_to", "parent_evidence_id", "parent_evidence_sha256",
    "rerun_of_work_item_id", "source_status", "source_verdict",
    "source_evidence_path", "economic_run_key", "duplicate_of_rank",
    "estimated_factory_hours", "is_recovery_payload", "active_symbol_count",
    "active_symbol_cap", "enqueue_eligible", "binding_complete",
    "farmctl_command", "command_argv_json",
]


def open_ro(db_path: Path | str) -> sqlite3.Connection:
    """Open SQLite read-only and additionally enable query_only fail-closed."""
    path = Path(db_path).resolve().as_posix()
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=3000")
    connection.execute("PRAGMA query_only=ON")
    return connection


def _payload(row: dict[str, Any] | sqlite3.Row | None) -> dict[str, Any]:
    if row is None:
        return {}
    try:
        raw = row["payload_json"]
    except (KeyError, IndexError):
        return {}
    try:
        value = json.loads(raw or "{}")
    except (TypeError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def _parse_time(value: Any) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _sha256_file(path_value: Any, cache: dict[str, str] | None = None) -> str:
    if not path_value:
        return ""
    key = str(path_value)
    if cache is not None and key in cache:
        return cache[key]
    path = Path(key)
    digest = ""
    try:
        if path.is_file():
            hasher = hashlib.sha256()
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    hasher.update(chunk)
            digest = hasher.hexdigest()
    except OSError:
        digest = ""
    if cache is not None:
        cache[key] = digest
    return digest


def _first(payloads: Iterable[dict[str, Any]], keys: Iterable[str]) -> str:
    for payload in payloads:
        for key in keys:
            value = payload.get(key)
            if value is not None and str(value).strip():
                return str(value).strip().lower()
    return ""


def _binding_values(
    source: dict[str, Any] | None,
    parent: dict[str, Any] | None,
    file_hash_cache: dict[str, str],
) -> dict[str, str]:
    source_payload = _payload(source)
    parent_payload = _payload(parent)
    payloads = (source_payload, parent_payload)
    build_hash = _first(payloads, census.BUILD_HASH_KEYS)
    if not build_hash:
        build_hash = _sha256_file(
            _first(payloads, ("expected_ex5_path", "staged_ex5", "ex5_path")),
            file_hash_cache,
        )
    setfile_hash = _first(payloads, census.SETFILE_HASH_KEYS)
    setfile_path = (source or {}).get("setfile_path") if source else ""
    if not setfile_path and parent:
        setfile_path = parent.get("setfile_path", "")
    if not setfile_hash:
        setfile_hash = _sha256_file(setfile_path, file_hash_cache)

    window_from = _first(
        payloads,
        ("expected_from_date", "from_date", "from_year", "requested_from_year"),
    )
    window_to = _first(
        payloads,
        ("expected_to_date", "to_date", "to_year", "requested_to_year"),
    )
    return {
        "build_hash": build_hash,
        "setfile_hash": setfile_hash,
        "window_from": window_from,
        "window_to": window_to,
    }


def load_census_csv(path: Path | str) -> list[dict[str, Any]]:
    with Path(path).open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        row["n_rows"] = int(row.get("n_rows") or 0)
        row["frontier_infra"] = str(row.get("frontier_infra", "")).lower() in {
            "1", "true", "yes"
        }
    return rows


def recompute_census(connection: sqlite3.Connection, limit: int | None = None) -> list[dict[str, Any]]:
    return census.compute(connection, limit)["pair_rows"]


def _load_work_items(connection: sqlite3.Connection) -> list[dict[str, Any]]:
    columns = {str(row[1]) for row in connection.execute("PRAGMA table_info(work_items)")}
    required = {
        "id", "phase", "ea_id", "symbol", "setfile_path", "status", "verdict",
        "evidence_path", "claimed_by", "payload_json", "created_at", "updated_at",
    }
    missing = required - columns
    if missing:
        raise RuntimeError(f"work_items schema missing required columns: {sorted(missing)}")
    placeholders = ",".join("?" for _ in range(len(GATE_CHAIN) + 3))
    phases = (*GATE_CHAIN, "Q09_NEWS", "Q09_PORTFOLIO", "COMPILE_EA")
    query = (
        "SELECT id,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,"
        "claimed_by,payload_json,created_at,updated_at FROM work_items "
        f"WHERE phase IN ({placeholders})"
    )
    return [dict(row) for row in connection.execute(query, phases)]


def _load_review_tasks(connection: sqlite3.Connection) -> dict[str, dict[str, Any]]:
    exists = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='tasks'"
    ).fetchone()
    if not exists:
        return {}
    reviews: dict[str, dict[str, Any]] = {}
    for row in connection.execute(
        "SELECT id,status,payload_json,created_at,updated_at FROM tasks "
        "WHERE kind='ea_review' AND status='done' ORDER BY updated_at DESC"
    ):
        item = dict(row)
        payload = _payload(item)
        if (payload.get("verdict") or {}).get("verdict") != "APPROVE_FOR_BACKTEST":
            continue
        ea_id = str(payload.get("ea_id") or "")
        if ea_id and ea_id not in reviews:
            reviews[ea_id] = item
    return reviews


def phase_median_hours(rows: Iterable[dict[str, Any]]) -> dict[str, float]:
    durations: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        if str(row.get("status") or "").lower() not in TERMINAL_STATUSES:
            continue
        gate = census.canonical_gate(row.get("phase"))
        if not gate:
            continue
        created = _parse_time(row.get("created_at"))
        updated = _parse_time(row.get("updated_at"))
        if not created or not updated or updated < created:
            continue
        durations[gate].append((updated - created).total_seconds() / 3600.0)
    return {gate: round(statistics.median(values), 4) for gate, values in durations.items()}


def _latest(rows: Iterable[dict[str, Any]]) -> dict[str, Any] | None:
    values = list(rows)
    if not values:
        return None
    return max(
        values,
        key=lambda row: (
            _parse_time(row.get("updated_at")) or dt.datetime.min.replace(tzinfo=dt.timezone.utc),
            str(row.get("id") or ""),
        ),
    )


def _target_source(rows: list[dict[str, Any]], action: str) -> dict[str, Any] | None:
    terminal = [
        row for row in rows
        if str(row.get("status") or "").lower() in TERMINAL_STATUSES
    ]
    if action == "RERUN_INFRA":
        matched = [row for row in terminal if str(row.get("verdict") or "").upper() in INFRA_VERDICTS]
        return _latest(matched or terminal)
    if action == "REBIND_STALE":
        matched = [row for row in terminal if str(row.get("verdict") or "").upper() in STALE_VERDICTS]
        return _latest(matched or terminal)
    if action == "STOP_ECONOMIC_FAIL":
        return _latest(row for row in terminal if str(row.get("verdict") or "").upper() in ECONOMIC_FAIL_VERDICTS)
    if action == "STOP_NOT_APPLICABLE":
        return _latest(row for row in terminal if str(row.get("verdict") or "").upper() in NA_VERDICTS)
    return _latest(terminal)


def _q09_news_action(rows: list[dict[str, Any]]) -> tuple[str, str]:
    """Classify the economic Q09 lane; portfolio output is informational only."""
    news = [
        row for row in rows
        if str(row.get("phase") or "").upper() in {"Q09", "Q09_NEWS"}
    ]
    if not news:
        return "FILL_MISSING", "q09_news_prerequisite_missing"
    if any(str(row.get("status") or "").lower() in {"pending", "active"} for row in news):
        return "UNKNOWN", "q09_news_prerequisite_in_flight"
    terminal = [
        row for row in news
        if str(row.get("status") or "").lower() in TERMINAL_STATUSES
    ]
    verdicts = {str(row.get("verdict") or "").upper() for row in terminal}
    if verdicts & ECONOMIC_FAIL_VERDICTS:
        return "STOP_ECONOMIC_FAIL", "terminal_economic_fail_at_q09_news"
    if verdicts & STALE_VERDICTS:
        # CONFIG_LOCKED is a STALE_CLS verdict in census; it is re-bound, never
        # silently reused as a valid Q09_NEWS resting state (reviewer P2 #4).
        return "REBIND_STALE", "stale_or_contract_gap_at_q09_news"
    if verdicts & set(census.INFRA_CLS):
        return "RERUN_INFRA", "infra_failure_at_q09_news"
    if "REVIEW_REQUIRED" in verdicts:
        return "UNKNOWN", "q09_news_manual_review_required"
    if verdicts & set(census.INVALID_CLS):
        return "RERUN_INFRA", "invalid_evidence_at_q09_news"
    return "UNKNOWN", "q09_news_frontier_unclassified"


def _parent_for_gate(
    gate_rows: dict[str, list[dict[str, Any]]], target_gate: str
) -> dict[str, Any] | None:
    index = GATE_INDEX[target_gate]
    if index == 0:
        return None
    predecessor = GATE_CHAIN[index - 1]
    candidates = [
        row for row in gate_rows.get(predecessor, [])
        if str(row.get("status") or "").lower() == "done"
        and str(row.get("verdict") or "").upper() in PASS_VERDICTS
    ]
    if target_gate == "Q10":
        news = [row for row in candidates if str(row.get("phase") or "").upper() == "Q09_NEWS"]
        candidates = news or candidates
    return _latest(candidates)


def action_for_census(row: dict[str, Any]) -> tuple[str, str]:
    """Return the governed planner action for one census frontier row.

    Kept public so read-only operator surfaces can present exactly the same
    action vocabulary without cloning planner policy.
    """
    disposition = str(row.get("disposition") or "").upper()
    frontier_class = str(row.get("frontier_class") or "").upper()
    target = str(row.get("earliest_missing_prerequisite") or "").upper()
    if disposition == "NOT_APPLICABLE" or frontier_class == "NA":
        return "STOP_NOT_APPLICABLE", "frontier_not_applicable"
    if disposition == "ECONOMIC_FAIL" or frontier_class == "ECON_FAIL":
        return "STOP_ECONOMIC_FAIL", "terminal_economic_fail_at_frontier"
    if not target or frontier_class == "COMPLETE":
        return "SKIP_REUSABLE", "full_contiguous_chain_already_reusable"
    if frontier_class == "STALE" or disposition == "STALE":
        return "REBIND_STALE", "stale_or_contract_gap_at_earliest_prerequisite"
    if frontier_class in {"INFRA", "INVALID"}:
        return "RERUN_INFRA", "non_economic_failure_at_earliest_prerequisite"
    if frontier_class == "MISSING":
        return "FILL_MISSING", "earliest_prerequisite_has_no_evidence"
    if frontier_class == "REUSABLE":
        return "SKIP_REUSABLE", "exact_contract_and_hash_equal_evidence"
    return "UNKNOWN", f"unclassified_frontier:{frontier_class or 'EMPTY'}"


def _command_argv(
    *, farm_root: Path, ea_id: str, runtime_phase: str,
    action: str, parent_id: str, rerun_id: str, build_hash: str,
) -> list[str]:
    argv = [
        sys.executable, "tools/strategy_farm/farmctl.py", "--root", str(farm_root),
        "enqueue-backtest", "--ea", ea_id, "--phase", runtime_phase,
    ]
    if parent_id:
        argv.extend(("--from-work-item-id", parent_id))
    if action in {"RERUN_INFRA", "REBIND_STALE"}:
        argv.extend((
            "--append-only-rerun-of", rerun_id,
            "--rerun-reason", f"rb-backfill-planner:{action.lower()}",
        ))
    if build_hash:
        argv.extend(("--expected-current-ex5-sha256", build_hash))
    return argv


def _command_string(argv: list[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(argv)
    return shlex.join(argv)


def _economic_run_key(row: dict[str, Any]) -> str:
    fields = (
        row.get("runtime_phase"), row.get("symbol"), row.get("build_hash"),
        row.get("setfile_hash"), row.get("window_from"), row.get("window_to"),
        row.get("gate_contract_version"),
    )
    if any(not value for value in fields):
        return ""
    return hashlib.sha256("\x1f".join(str(value) for value in fields).encode("utf-8")).hexdigest()


def _compile_failure_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for source in rows:
        if str(source.get("phase") or "").upper() != "COMPILE_EA":
            continue
        if str(source.get("verdict") or "").upper() != "COMPILE_FAIL":
            continue
        evidence_path = Path(str(source.get("evidence_path") or ""))
        evidence: dict[str, Any] = {}
        if evidence_path.is_file():
            try:
                loaded = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
                evidence = loaded if isinstance(loaded, dict) else {}
            except (OSError, ValueError):
                evidence = {}
        compile_log = Path(str(evidence.get("compile_log") or ""))
        log_text = ""
        if compile_log.is_file():
            try:
                raw_log = compile_log.read_bytes()
                encoding = "utf-16" if raw_log.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
                log_text = raw_log.decode(encoding, errors="replace").lower()
            except OSError:
                log_text = ""
        stdlib_missing = bool(log_text) and any(signature in log_text for signature in STDLIB_MISSING_SIGNATURES)
        created = _parse_time(source.get("created_at"))
        now = dt.datetime.now(dt.timezone.utc)
        output.append({
            "rank": 0,
            "record_type": "COMPILE_EA",
            "ea_id": source.get("ea_id") or "",
            "symbol": source.get("symbol") or "",
            "action": "RERUN_INFRA" if stdlib_missing else "UNKNOWN",
            "reason": (
                "stdlib_missing_signature_reachable;separate_compile_repair_ticket"
                if stdlib_missing else
                "compile_fail_without_reachable_stdlib_missing_signature;separate_compile_repair_ticket"
            ),
            "highest_observed_gate": "", "highest_contiguous_valid_gate": "",
            "earliest_missing_prerequisite": "", "target_gate": "COMPILE_EA",
            "runtime_phase": "COMPILE_EA", "frontier_ordinal": -1,
            "remaining_gates": len(GATE_CHAIN),
            "age_days": round((now - created).total_seconds() / 86400, 3) if created else "",
            "oldest_created_at": source.get("created_at") or "",
            "gate_contract_version": "", "build_hash": "", "setfile_hash": "",
            "window_from": "", "window_to": "", "parent_evidence_id": "",
            "parent_evidence_sha256": "", "rerun_of_work_item_id": source.get("id") or "",
            "source_status": source.get("status") or "",
            "source_verdict": source.get("verdict") or "",
            "source_evidence_path": str(compile_log if compile_log.is_file() else evidence_path),
            "economic_run_key": "", "duplicate_of_rank": "",
            "estimated_factory_hours": 0.0, "is_recovery_payload": False,
            "active_symbol_count": 0, "active_symbol_cap": ACTIVE_SYMBOL_CAP,
            "enqueue_eligible": False, "binding_complete": False,
            "farmctl_command": "", "command_argv_json": "[]",
        })
    return output


def build_plan(
    connection: sqlite3.Connection,
    census_rows: list[dict[str, Any]],
    *,
    farm_root: Path = DEFAULT_FARM_ROOT,
    contract_version: str = DEFAULT_CONTRACT_VERSION,
) -> dict[str, Any]:
    """Build a deterministic dry-run plan without mutating SQLite."""
    work_items = _load_work_items(connection)
    reviews = _load_review_tasks(connection)
    medians = phase_median_hours(work_items)
    file_hash_cache: dict[str, str] = {}

    by_pair_gate: dict[tuple[str, str], dict[str, list[dict[str, Any]]]] = defaultdict(
        lambda: defaultdict(list)
    )
    pair_all: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    active_counts: Counter[str] = Counter()
    active_pairs: set[tuple[str, str]] = set()
    for item in work_items:
        ea_id = str(item.get("ea_id") or "")
        symbol = str(item.get("symbol") or "")
        if str(item.get("status") or "").lower() == "active" and symbol:
            active_counts[symbol.upper()] += 1
            active_pairs.add((ea_id, symbol.upper()))
        gate = census.canonical_gate(item.get("phase"))
        if not gate or not ea_id or not symbol:
            continue
        key = (ea_id, symbol)
        by_pair_gate[key][gate].append(item)
        pair_all[key].append(item)

    now = dt.datetime.now(dt.timezone.utc)
    pair_plans: list[dict[str, Any]] = []
    for census_row in census_rows:
        ea_id = str(census_row.get("ea_id") or "")
        symbol = str(census_row.get("symbol") or "")
        target_gate = str(census_row.get("earliest_missing_prerequisite") or "").upper()
        action, reason = action_for_census(census_row)
        gates = by_pair_gate.get((ea_id, symbol), {})
        target_rows = gates.get(target_gate, []) if target_gate else []

        # Q09_PORTFOLIO is informational (OWNER E1); it can neither fill the
        # Q09_NEWS hole nor let a later gate skip it.  The census contiguity walk
        # credits Q09 via a PASS_PORTFOLIO row (census keeps PASS_PORTFOLIO in
        # PASS_ECON), so a pair with a Q10/Q14 PASS above an unpassed Q09_NEWS
        # otherwise reports a frontier past Q09 with the news hole masked.  Cap
        # the frontier at Q08 and re-target the economic Q09_NEWS lane whenever
        # the reported chain has crossed Q09 without a valid Q09_NEWS pass,
        # regardless of how high the frontier string ran.
        q09_rows = gates.get("Q09", [])
        q09_news_valid = any(
            str(item.get("phase") or "").upper() in {"Q09", "Q09_NEWS"}
            and str(item.get("status") or "").lower() == "done"
            and str(item.get("verdict") or "").upper() in PASS_VERDICTS
            for item in q09_rows
        )
        reported_frontier = str(census_row.get("highest_contiguous_valid_gate") or "")
        if GATE_INDEX.get(reported_frontier, -1) >= GATE_INDEX["Q09"] and not q09_news_valid:
            target_gate = "Q09"
            target_rows = [
                item for item in q09_rows
                if str(item.get("phase") or "").upper() != "Q09_PORTFOLIO"
            ]
            action, reason = _q09_news_action(q09_rows)
            reported_frontier = "Q08"
        elif target_gate == "Q09":
            target_rows = [
                item for item in q09_rows
                if str(item.get("phase") or "").upper() != "Q09_PORTFOLIO"
            ]
            action, reason = _q09_news_action(q09_rows)

        open_target = _latest(
            row for row in target_rows
            if str(row.get("status") or "").lower() in {"pending", "active"}
        )
        if open_target and action in ENQUEUE_ACTIONS:
            action = "UNKNOWN"
            reason = f"earliest_prerequisite_already_{str(open_target['status']).lower()}"

        source = _target_source(target_rows, action)
        parent = _parent_for_gate(gates, target_gate) if target_gate in GATE_INDEX else None
        review = reviews.get(ea_id) if target_gate == "Q02" else None
        if target_gate == "Q02" and action in {"RERUN_INFRA", "REBIND_STALE"}:
            parent = source  # farmctl Q02 exact-row rerun requires source == rerun target.

        bindings = _binding_values(source, parent, file_hash_cache)
        parent_id = str((parent or {}).get("id") or (review or {}).get("id") or "")
        parent_evidence_sha = ""
        if parent:
            parent_evidence_sha = _sha256_file(parent.get("evidence_path"), file_hash_cache)
        elif review:
            parent_evidence_sha = hashlib.sha256(
                str(review.get("payload_json") or "{}").encode("utf-8")
            ).hexdigest()
        rerun_id = str((source or {}).get("id") or "") if action in {"RERUN_INFRA", "REBIND_STALE"} else ""

        runtime_phase = RUNTIME_PHASE.get(target_gate, target_gate)
        oldest_times = [
            parsed for parsed in (_parse_time(item.get("created_at")) for item in pair_all.get((ea_id, symbol), []))
            if parsed
        ]
        oldest = min(oldest_times) if oldest_times else None
        frontier_gate = reported_frontier
        frontier_ordinal = GATE_INDEX.get(frontier_gate, -1)
        remaining = len(GATE_CHAIN) - (frontier_ordinal + 1)
        source_payload = _payload(source)
        parent_payload = _payload(parent)
        is_recovery = bool(
            source_payload.get("recovery_class") or parent_payload.get("recovery_class")
        )

        binding_complete = all((
            contract_version, bindings["build_hash"], bindings["setfile_hash"],
            bindings["window_from"], bindings["window_to"], parent_id,
            parent_evidence_sha,
        ))
        command_argv: list[str] = []
        enqueue_eligible = action in ENQUEUE_ACTIONS
        if runtime_phase not in FARMCTL_BACKTEST_PHASES:
            enqueue_eligible = False
            if action in ENQUEUE_ACTIONS:
                reason += ";runtime_phase_not_supported_by_farmctl_enqueue_backtest"
        if action in {"RERUN_INFRA", "REBIND_STALE"} and not rerun_id:
            enqueue_eligible = False
            reason += ";no_terminal_rerun_source"
        if not parent_id:
            enqueue_eligible = False
            if action in ENQUEUE_ACTIONS:
                reason += ";no_exact_predecessor"
        if not binding_complete:
            enqueue_eligible = False
            if action in ENQUEUE_ACTIONS:
                reason += ";incomplete_hash_window_or_parent_binding"
        symbol_key = symbol.upper()
        if (ea_id, symbol_key) in active_pairs:
            enqueue_eligible = False
            if action in ENQUEUE_ACTIONS:
                reason += ";active_ea_symbol_lock"
        if symbol_key and active_counts[symbol_key] >= ACTIVE_SYMBOL_CAP:
            enqueue_eligible = False
            if action in ENQUEUE_ACTIONS:
                reason += ";active_symbol_cap_reached"
        if enqueue_eligible:
            command_argv = _command_argv(
                farm_root=farm_root, ea_id=ea_id, runtime_phase=runtime_phase,
                action=action, parent_id=parent_id, rerun_id=rerun_id,
                build_hash=bindings["build_hash"],
            )

        row = {
            "rank": 0, "record_type": "PAIR", "ea_id": ea_id, "symbol": symbol,
            "action": action, "reason": reason,
            "highest_observed_gate": census_row.get("highest_observed_gate") or "",
            "highest_contiguous_valid_gate": frontier_gate,
            "earliest_missing_prerequisite": target_gate, "target_gate": target_gate,
            "runtime_phase": runtime_phase, "frontier_ordinal": frontier_ordinal,
            "remaining_gates": remaining,
            "age_days": round((now - oldest).total_seconds() / 86400, 3) if oldest else "",
            "oldest_created_at": oldest.isoformat() if oldest else "",
            "gate_contract_version": contract_version,
            **bindings,
            "parent_evidence_id": parent_id,
            "parent_evidence_sha256": parent_evidence_sha,
            "rerun_of_work_item_id": rerun_id,
            "source_status": (source or {}).get("status") or "",
            "source_verdict": (source or {}).get("verdict") or "",
            "source_evidence_path": (source or {}).get("evidence_path") or "",
            "economic_run_key": "", "duplicate_of_rank": "",
            "estimated_factory_hours": medians.get(target_gate, 0.0) if action in ENQUEUE_ACTIONS else 0.0,
            "is_recovery_payload": is_recovery,
            "active_symbol_count": active_counts[symbol_key],
            "active_symbol_cap": ACTIVE_SYMBOL_CAP,
            "enqueue_eligible": enqueue_eligible,
            "binding_complete": binding_complete,
            "farmctl_command": _command_string(command_argv) if command_argv else "",
            "command_argv_json": json.dumps(command_argv),
        }
        row["economic_run_key"] = _economic_run_key(row)
        pair_plans.append(row)

    # Frontier first, then shortest remaining path, then oldest. Recovery-class
    # payloads stay behind ordinary frontier work, matching farmctl ordering.
    far_future = dt.datetime.max.replace(tzinfo=dt.timezone.utc)
    pair_plans.sort(key=lambda row: (
        bool(row["is_recovery_payload"]),
        -int(row["frontier_ordinal"]),
        int(row["remaining_gates"]),
        _parse_time(row["oldest_created_at"]) or far_future,
        str(row["ea_id"]), str(row["symbol"]),
    ))

    seen_economic: dict[str, int] = {}
    for rank, row in enumerate(pair_plans, 1):
        row["rank"] = rank
        key = str(row.get("economic_run_key") or "")
        if row["action"] in ENQUEUE_ACTIONS and key:
            if key in seen_economic:
                row["action"] = "SKIP_REUSABLE"
                row["reason"] = "global_economic_run_dedup"
                row["duplicate_of_rank"] = seen_economic[key]
                row["enqueue_eligible"] = False
                row["farmctl_command"] = ""
                row["command_argv_json"] = "[]"
                row["estimated_factory_hours"] = 0.0
            else:
                seen_economic[key] = rank

    compile_rows = _compile_failure_rows(work_items)
    for offset, row in enumerate(compile_rows, len(pair_plans) + 1):
        row["rank"] = offset
    plan_rows = pair_plans + compile_rows
    return {
        "rows": plan_rows,
        "phase_median_hours": medians,
        "active_symbol_counts": dict(sorted(active_counts.items())),
    }


def _json_ready(row: dict[str, Any]) -> dict[str, Any]:
    return {column: row.get(column, "") for column in PLAN_COLUMNS}


def write_outputs(
    result: dict[str, Any], *, date: str, db_path: Path, census_path: str,
    out_dir: Path, md_dir: Path, contract_version: str,
) -> dict[str, str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    md_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / f"backfill_plan_{date}.csv"
    json_path = out_dir / f"backfill_plan_{date}.json"
    md_path = md_dir / f"BACKFILL_PLAN_{date}.md"
    rows = result["rows"]
    generated = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=PLAN_COLUMNS)
        writer.writeheader()
        writer.writerows(_json_ready(row) for row in rows)

    observed_counts = Counter(str(row["action"]) for row in rows)
    counts = {action: observed_counts.get(action, 0) for action in ALL_ACTIONS}
    estimated = round(sum(float(row.get("estimated_factory_hours") or 0) for row in rows), 3)
    estimated_eligible = round(
        sum(
            float(row.get("estimated_factory_hours") or 0)
            for row in rows if bool(row.get("enqueue_eligible"))
        ),
        3,
    )
    document = {
        "meta": {
            "schema_version": "qm.rebaseline-backfill-plan/v1",
            "generated_at_utc": generated,
            "date": date,
            "db_path": str(db_path).replace("\\", "/"),
            "database_access": "file URI mode=ro + PRAGMA query_only=ON",
            "census_path": census_path,
            "gate_contract_version": contract_version,
            "gate_chain": list(GATE_CHAIN),
            "dry_run": True,
            "active_symbol_cap": ACTIVE_SYMBOL_CAP,
        },
        "summary": {
            "total_rows": len(rows),
            "pair_rows": sum(row["record_type"] == "PAIR" for row in rows),
            "compile_rows": sum(row["record_type"] == "COMPILE_EA" for row in rows),
            "enqueue_eligible_rows": sum(bool(row["enqueue_eligible"]) for row in rows),
            "counts_per_action": counts,
            "estimated_factory_hours": estimated,
            "estimated_factory_hours_enqueue_ready": estimated_eligible,
            "phase_median_hours": result["phase_median_hours"],
        },
        "rows": [_json_ready(row) for row in rows],
    }
    json_path.write_text(json.dumps(document, indent=2, sort_keys=True), encoding="utf-8")

    lines = [
        "# Backfill Plan — Pipeline Rebaseline",
        "",
        f"Generated: `{generated}`",
        f"State DB: `{str(db_path).replace(chr(92), '/')}` (**read-only mode=ro**)",
        f"Input census: `{census_path}`",
        f"Gate contract: `{contract_version}` (active runtime; v4 remains read-inert)",
        "Mode: **dry-run; no enqueue was executed**",
        "",
        "## Summary",
        "",
        f"- Rows: **{len(rows)}** ({document['summary']['pair_rows']} pair, "
        f"{document['summary']['compile_rows']} compile classifications)",
        f"- Enqueue-ready after binding/cap checks: **{document['summary']['enqueue_eligible_rows']}**",
        f"- Estimated factory time (full reparable backfill, bindings pending): "
        f"**{estimated:.3f} h** (sum of target-phase medians over every enqueue-action "
        "row; work-item `updated_at - created_at`)",
        f"- Estimated factory time (enqueue-ready now): **{estimated_eligible:.3f} h** "
        "(enqueue-eligible rows only)",
        "",
        "| action | rows |",
        "|---|---:|",
    ]
    for action, count in counts.items():
        lines.append(f"| {action} | {count} |")
    lines.extend((
        "", "## Phase median durations", "", "| gate | median hours |", "|---|---:|"
    ))
    for gate in GATE_CHAIN:
        if gate in result["phase_median_hours"]:
            lines.append(f"| {gate} | {result['phase_median_hours'][gate]:.4f} |")
    lines.extend((
        "", "## Top 50 — frontier-first / earliest-gap-first", "",
        "| rank | EA | symbol | frontier | next gate | action | hours | enqueue | reason |",
        "|---:|---|---|---|---|---|---:|---|---|",
    ))
    for row in rows[:50]:
        reason = str(row["reason"]).replace("|", "\\|")
        lines.append(
            f"| {row['rank']} | {row['ea_id']} | {row['symbol']} | "
            f"{row['highest_contiguous_valid_gate'] or 'NONE'} | {row['target_gate']} | "
            f"{row['action']} | {float(row['estimated_factory_hours'] or 0):.3f} | "
            f"{str(bool(row['enqueue_eligible'])).lower()} | {reason} |"
        )
    lines.extend((
        "", "## Safety and interpretation", "",
        "The rank key is contiguous frontier descending, remaining gates ascending, then oldest pair first. "
        "Only the earliest gap is represented for a pair. Economic FAIL and not-applicable rows are terminal. "
        "Reruns use `--append-only-rerun-of`; exact economic identities are globally deduplicated. "
        "Rows lacking build/setfile/window/parent-evidence bindings, rows behind the active symbol cap, and "
        "runtime phases unsupported by `farmctl enqueue-backtest` are visible but not apply-eligible.",
        "",
        "COMPILE_EA failures are a separate repair ticket. They are `RERUN_INFRA` only when a reachable "
        "compile log contains the documented missing `Trade/Trade.mqh` or `Object.mqh` signature; all other "
        "COMPILE_FAIL rows are `UNKNOWN` and never become backtest commands.",
        "",
        f"Machine artifacts: `{str(csv_path).replace(chr(92), '/')}` and "
        f"`{str(json_path).replace(chr(92), '/')}`.",
        "",
    ))
    md_path.write_text("\n".join(lines), encoding="utf-8")
    return {"csv": str(csv_path), "json": str(json_path), "markdown": str(md_path)}


def apply_plan(rows: list[dict[str, Any]], max_rows: int, cwd: Path) -> dict[str, Any]:
    """Invoke bounded, already-rendered farmctl commands; never writes DB itself."""
    selected: list[dict[str, Any]] = []
    planned_symbol_counts: Counter[str] = Counter()
    for row in rows:
        if not bool(row.get("enqueue_eligible")):
            continue
        symbol = str(row.get("symbol") or "").upper()
        active_count = int(row.get("active_symbol_count") or 0)
        cap = int(row.get("active_symbol_cap") or ACTIVE_SYMBOL_CAP)
        if symbol and active_count + planned_symbol_counts[symbol] >= cap:
            continue
        selected.append(row)
        if symbol:
            planned_symbol_counts[symbol] += 1
        if len(selected) >= max_rows:
            break
    receipts: list[dict[str, Any]] = []
    for row in selected:
        argv = json.loads(str(row.get("command_argv_json") or "[]"))
        if not isinstance(argv, list) or not argv or "enqueue-backtest" not in argv:
            raise RuntimeError(f"rank {row.get('rank')} has no governed enqueue-backtest argv")
        if row.get("action") in {"RERUN_INFRA", "REBIND_STALE"} and "--append-only-rerun-of" not in argv:
            raise RuntimeError(f"rank {row.get('rank')} rerun is not append-only")
        completed = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, check=False)
        receipts.append({
            "rank": row.get("rank"), "ea_id": row.get("ea_id"), "symbol": row.get("symbol"),
            "returncode": completed.returncode, "stdout": completed.stdout, "stderr": completed.stderr,
        })
        if completed.returncode != 0:
            break
    return {"requested_max_rows": max_rows, "attempted": len(receipts), "receipts": receipts}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--census-csv", type=Path)
    parser.add_argument("--recompute-census", action="store_true")
    parser.add_argument("--limit", type=int, help="pair limit, mainly for smoke/tests")
    parser.add_argument("--date", default=dt.date.today().isoformat())
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--md-dir", type=Path, default=DEFAULT_MD_DIR)
    parser.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    parser.add_argument("--gate-contract-version", default=DEFAULT_CONTRACT_VERSION)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--i-understand-append-only", action="store_true")
    parser.add_argument("--max-rows", type=int)
    parser.add_argument("--quiet", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.apply and not args.i_understand_append_only:
        parser.error("--apply requires --i-understand-append-only")
    if args.apply and (args.max_rows is None or args.max_rows <= 0):
        parser.error("--apply requires --max-rows N with N > 0")
    if args.limit is not None and args.limit <= 0:
        parser.error("--limit must be > 0")

    connection = open_ro(args.db)
    try:
        if args.recompute_census:
            census_rows = recompute_census(connection, args.limit)
            census_source = f"recomputed:{args.db}"
        else:
            census_path = args.census_csv or (args.out_dir / f"census_{args.date}.csv")
            if not census_path.is_file():
                census_rows = recompute_census(connection, args.limit)
                census_source = f"recomputed:{args.db}"
            else:
                census_rows = load_census_csv(census_path)
                if args.limit is not None:
                    census_rows = census_rows[: args.limit]
                census_source = str(census_path).replace("\\", "/")
        result = build_plan(
            connection, census_rows, farm_root=args.farm_root,
            contract_version=args.gate_contract_version,
        )
    finally:
        connection.close()

    paths = write_outputs(
        result, date=args.date, db_path=args.db, census_path=census_source,
        out_dir=args.out_dir, md_dir=args.md_dir,
        contract_version=args.gate_contract_version,
    )
    response: dict[str, Any] = {
        "mode": "apply" if args.apply else "dry-run",
        "paths": paths,
        "rows": len(result["rows"]),
        "enqueue_eligible_rows": sum(bool(row["enqueue_eligible"]) for row in result["rows"]),
    }
    if args.apply:
        response["apply"] = apply_plan(result["rows"], args.max_rows, Path.cwd())
    if not args.quiet:
        print(json.dumps(response, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
