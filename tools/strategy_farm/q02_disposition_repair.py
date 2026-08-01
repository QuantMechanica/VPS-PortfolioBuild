#!/usr/bin/env python3
"""Guarded ten-row Q02 disposition repair controller.

Dry-run is the default operational phase.  Database mutation is possible only
on 2026-08-02 in Europe/Berlin, while Factory is OFF, no work item is active,
and the global Factory mutation lock is held.  The controller binds the exact
Claude-approved authority-plan digest, a durable full-preimage execution plan,
an online SQLite backup, exact compare-and-swap updates, and an append-only
event/journal trail.  It never enqueues or reruns work.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence
from zoneinfo import ZoneInfo


_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

try:
    from factory_mutation_lock import (  # type: ignore[import-not-found]  # noqa: E402
        FactoryMutationLock,
        path_for_factory_flag,
    )
except ModuleNotFoundError as _mutation_lock_import_error:
    # Some stale registered worktrees do not yet contain the shared lock module.
    # Read-only dry-run remains useful there; every mutation stays fail-closed.
    _MUTATION_LOCK_IMPORT_DETAIL = repr(_mutation_lock_import_error)

    def path_for_factory_flag(factory_off_flag: Path) -> Path:
        return Path(factory_off_flag).with_name("FACTORY_MUTATION.lock")

    class FactoryMutationLock:  # type: ignore[no-redef]
        def __init__(self, path: Path, *, owner: str) -> None:
            self.path = Path(path)
            self.owner = owner

        def __enter__(self) -> "FactoryMutationLock":
            raise RuntimeError(
                "global factory_mutation_lock dependency is unavailable; "
                f"mutation refused ({_MUTATION_LOCK_IMPORT_DETAIL})"
            )

        def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
            return None


AUTHORITY_PLAN_SCHEMA = "qm-q02-disposition-repair-plan/v1"
EXECUTION_PLAN_SCHEMA = "qm-q02-disposition-repair-execution-plan/v1"
DRY_RUN_RECEIPT_SCHEMA = "qm-q02-disposition-repair-dry-run/v1"
JOURNAL_SCHEMA = "qm-q02-disposition-repair-journal/v1"
PAYLOAD_AUDIT_SCHEMA = "qm-q02-disposition-repair-audit/v1"

AUTHORITY_TASK_ID = "f9b2b014-deca-4fd5-ba95-ea5e8ce83e9f"
PREDECESSOR_TASK_ID = "27086064-a384-4e30-b04a-2043c4edeecf"
ACCEPTED_AUTHORITY_PLAN_SHA256 = (
    "5abc62608f1fc5ebce7ee226490c261132aa592a1d5569601bf74cb35666a25d"
)
ACCEPTED_AUTHORITY_PLAN_BYTES = 5676
AUTHORITY_PLAN_OPERATION = "ROW_BOUND_PASS_DISPOSITION_MISMATCH_TO_PASS"
AUTHORIZED_APPLY_DATE = dt.date(2026, 8, 2)
AUTHORIZED_TIMEZONE = ZoneInfo("Europe/Berlin")

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")

TARGET_IDS = (
    "e78b1e33-179f-44ea-aa9b-57b5181f7299",
    "49a7c514-5aa0-43c1-a00b-94d0acc7b07b",
    "fc0e5325-67da-4659-848c-abc9d0580b11",
    "e8f476da-a7e5-48ba-aa94-285b2cdb8b8f",
    "e346032c-5762-4941-b0eb-7a7496bbd649",
    "9f7d6e83-dc82-4fbd-9e13-128b71704db7",
    "677c9a45-b30b-4e97-a028-987f80430a94",
    "7916bcf9-f1d1-4ea2-94e2-9156044d4caf",
    "5f08fb95-cf8b-4378-b8eb-6aec56005367",
    "ce645ca9-26c9-414f-996f-4036cecb61d1",
)

WORK_ITEM_COLUMNS = (
    "id",
    "kind",
    "phase",
    "ea_id",
    "symbol",
    "setfile_path",
    "status",
    "verdict",
    "attempt_count",
    "parent_task_id",
    "evidence_path",
    "claimed_by",
    "payload_json",
    "created_at",
    "updated_at",
)

# These six summaries predate run_smoke/v2.  Claude explicitly accepted their
# exact row/evidence bindings in AUTHORITY_TASK_ID; no schema equivalence is
# inferred.  Any byte or PASS-fact drift fails closed.
LEGACY_SUMMARY_BINDINGS: dict[str, dict[str, Any]] = {
    "e78b1e33-179f-44ea-aa9b-57b5181f7299": {
        "evidence_sha256": "37e6cc21c01786ebc4ee50439d6e1ad794ba18b98cbd01fef8976bbe11ebd336",
        "ok_runs": 1,
        "total_trades": 25,
    },
    "49a7c514-5aa0-43c1-a00b-94d0acc7b07b": {
        "evidence_sha256": "b0c53dd68314bc64f309469cdfc6ea2936e1483ee346f3adeadfeee749674ce6",
        "ok_runs": 1,
        "total_trades": 18,
    },
    "e346032c-5762-4941-b0eb-7a7496bbd649": {
        "evidence_sha256": "d9f6352e0f4fd9cb1ace5b7689ba73a81bcb7dff243351cb750df271ff449045",
        "ok_runs": 1,
        "total_trades": 621,
    },
    "9f7d6e83-dc82-4fbd-9e13-128b71704db7": {
        "evidence_sha256": "f43644204fb3299649395302840482577bce9e847425e84a5a18063d4847220c",
        "ok_runs": 1,
        "total_trades": 153,
    },
    "7916bcf9-f1d1-4ea2-94e2-9156044d4caf": {
        "evidence_sha256": "687679881749b3926e10ab9622c99f24cf07732b0a0d056b169cc911bdb23eea",
        "ok_runs": 1,
        "total_trades": 127,
    },
    "ce645ca9-26c9-414f-996f-4036cecb61d1": {
        "evidence_sha256": "509c9b634a8f8b499a45408561d163ca671b4d81926dbad7f0d97cf6b6f8eb10",
        "ok_runs": 1,
        "total_trades": 25,
    },
}


class DispositionRepairError(RuntimeError):
    """Fail-closed plan, window, evidence, CAS, journal, or revert error."""


class RuntimePaths:
    def __init__(
        self,
        *,
        db: Path = DEFAULT_DB,
        repo: Path = DEFAULT_REPO,
        factory_off_flag: Path = DEFAULT_FACTORY_OFF,
        backup_dir: Path = DEFAULT_BACKUP_DIR,
        mutation_lock: Path | None = None,
    ) -> None:
        self.db = db
        self.repo = repo
        self.factory_off_flag = factory_off_flag
        self.backup_dir = backup_dir
        self.mutation_lock = mutation_lock

    @property
    def lock_path(self) -> Path:
        return self.mutation_lock or path_for_factory_flag(self.factory_off_flag)


def current_utc() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def utc_stamp(moment: dt.datetime | None = None) -> str:
    value = (moment or current_utc()).astimezone(dt.UTC).replace(microsecond=0)
    return value.isoformat().replace("+00:00", "Z")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    except OSError as exc:
        raise DispositionRepairError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    try:
        text = json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise DispositionRepairError(f"value is not canonical-JSON serializable: {exc}") from exc
    return text.encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return sha256_bytes(canonical_json_bytes(value))


def payload_sha256(raw: Any) -> str:
    if not isinstance(raw, str):
        raise DispositionRepairError("payload_json is not text")
    return sha256_bytes(raw.encode("utf-8"))


def _reject_constant(token: str) -> None:
    raise DispositionRepairError(f"non-finite JSON constant: {token}")


def _no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DispositionRepairError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def parse_json_text(raw: str, label: str) -> Any:
    try:
        return json.loads(
            raw,
            object_pairs_hook=_no_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (json.JSONDecodeError, DispositionRepairError) as exc:
        raise DispositionRepairError(f"{label}: invalid JSON: {exc}") from exc


def load_json_strict(path: Path, label: str) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        decoded = raw.decode("utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        raise DispositionRepairError(f"{label}: unreadable JSON: {exc}") from exc
    value = parse_json_text(decoded, label)
    if not isinstance(value, dict):
        raise DispositionRepairError(f"{label}: root must be an object")
    return value, sha256_bytes(raw)


def write_json_atomic(path: Path, value: Mapping[str, Any], *, require_absent: bool) -> str:
    path = path.resolve(strict=False)
    if require_absent and path.exists():
        raise DispositionRepairError(f"refusing to overwrite existing artifact: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n"
    ).encode("utf-8")
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temp.open("xb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        if require_absent and path.exists():
            raise DispositionRepairError(f"artifact appeared before atomic replace: {path}")
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass
    return sha256_bytes(raw)


def normal_sha(value: Any, label: str) -> str:
    token = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", token):
        raise DispositionRepairError(f"{label}: expected SHA-256")
    return token


def connect_ro(path: Path) -> sqlite3.Connection:
    try:
        conn = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA query_only=ON")
        conn.execute("PRAGMA busy_timeout=30000")
        return conn
    except sqlite3.Error as exc:
        raise DispositionRepairError(f"cannot open database read-only: {exc}") from exc


def connect_rw(path: Path) -> sqlite3.Connection:
    try:
        conn = sqlite3.connect(path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=30000")
        return conn
    except sqlite3.Error as exc:
        raise DispositionRepairError(f"cannot open database read-write: {exc}") from exc


def quick_check(conn: sqlite3.Connection) -> str:
    rows = [str(row[0]) for row in conn.execute("PRAGMA quick_check").fetchall()]
    if rows != ["ok"]:
        raise DispositionRepairError(f"database quick_check failed: {rows}")
    return "ok"


def _git_head(repo: Path) -> str | None:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    token = completed.stdout.strip().lower()
    return token if completed.returncode == 0 and re.fullmatch(r"[0-9a-f]{40}", token) else None


def _row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {column: row[column] for column in WORK_ITEM_COLUMNS}


def _fetch_work_item(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    columns = ",".join(WORK_ITEM_COLUMNS)
    return conn.execute(
        f"SELECT {columns} FROM work_items WHERE id=?",  # noqa: S608 - static columns
        (work_item_id,),
    ).fetchone()


def _evidence_facts(row: sqlite3.Row) -> dict[str, Any]:
    evidence_path = Path(str(row["evidence_path"] or "")).resolve(strict=False)
    if not evidence_path.is_file():
        raise DispositionRepairError(f"{row['id']}: evidence file missing: {evidence_path}")
    evidence, raw_sha = load_json_strict(evidence_path, f"{row['id']} evidence")
    runs = evidence.get("runs")
    if not isinstance(runs, list) or not runs:
        raise DispositionRepairError(f"{row['id']}: evidence runs must be a non-empty list")
    if any(not isinstance(run, Mapping) for run in runs):
        raise DispositionRepairError(f"{row['id']}: evidence run is not an object")
    try:
        total_trades = sum(int(run.get("total_trades") or 0) for run in runs)
    except (TypeError, ValueError) as exc:
        raise DispositionRepairError(f"{row['id']}: invalid total_trades: {exc}") from exc
    ok_runs = sum(run.get("status") == "OK" for run in runs)
    evidence_schema = evidence.get("evidence_schema")
    if evidence.get("result") != "PASS":
        raise DispositionRepairError(f"{row['id']}: evidence result is not PASS")
    if ok_runs != len(runs):
        raise DispositionRepairError(
            f"{row['id']}: evidence contains non-OK runs ({ok_runs}/{len(runs)} OK)"
        )
    if total_trades <= 0:
        raise DispositionRepairError(f"{row['id']}: evidence trade count is not positive")
    row_ea = str(row["ea_id"])
    evidence_ea = str(evidence.get("ea_id"))
    if evidence_ea not in {row_ea, row_ea.removeprefix("QM5_")} or evidence.get(
        "symbol"
    ) != row["symbol"]:
        raise DispositionRepairError(f"{row['id']}: evidence EA/symbol binding mismatch")

    legacy_binding = None
    if evidence_schema == "run_smoke/v2":
        identity = evidence.get("execution_identity")
        if not isinstance(identity, Mapping) or identity.get("stable_during_run") is not True:
            raise DispositionRepairError(f"{row['id']}: run_smoke/v2 identity is not stable")
        for role in ("expert_binary", "setfile"):
            binding = identity.get(role)
            if not isinstance(binding, Mapping):
                raise DispositionRepairError(f"{row['id']}: missing {role} identity")
            if binding.get("source_matches_deployed") is not True:
                raise DispositionRepairError(f"{row['id']}: {role} source/deployed mismatch")
            if binding.get("stable_during_run") is not True:
                raise DispositionRepairError(f"{row['id']}: {role} changed during run")
    elif evidence_schema is None:
        legacy_binding = LEGACY_SUMMARY_BINDINGS.get(str(row["id"]))
        if legacy_binding is None:
            raise DispositionRepairError(
                f"{row['id']}: schema-less summary lacks an explicit accepted legacy binding"
            )
        expected = {
            "evidence_sha256": raw_sha,
            "ok_runs": ok_runs,
            "total_trades": total_trades,
        }
        if legacy_binding != expected:
            raise DispositionRepairError(f"{row['id']}: accepted legacy summary binding drifted")
    else:
        raise DispositionRepairError(
            f"{row['id']}: unsupported evidence schema {evidence_schema!r}"
        )

    return {
        "path": str(evidence_path),
        "sha256": raw_sha,
        "bytes": evidence_path.stat().st_size,
        "evidence_schema": evidence_schema,
        "legacy_binding_explicitly_accepted": legacy_binding is not None,
        "summary_result": "PASS",
        "run_count": len(runs),
        "ok_runs": ok_runs,
        "total_trades": total_trades,
    }


def build_authority_plan(conn: sqlite3.Connection) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for work_item_id in TARGET_IDS:
        row = _fetch_work_item(conn, work_item_id)
        if row is None:
            raise DispositionRepairError(f"authority-plan row missing: {work_item_id}")
        facts = _evidence_facts(row)
        rows.append(
            {
                "id": work_item_id,
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "phase": row["phase"],
                "status": row["status"],
                "verdict": row["verdict"],
                "claimed_by": row["claimed_by"],
                "evidence_path": row["evidence_path"],
                "evidence_sha256": facts["sha256"],
                "payload_sha256": payload_sha256(row["payload_json"]),
                "updated_at": row["updated_at"],
                "summary_result": facts["summary_result"],
                "ok_runs": facts["ok_runs"],
                "total_trades": facts["total_trades"],
            }
        )
    plan = {
        "schema": AUTHORITY_PLAN_SCHEMA,
        "authority_required": "separate APPROVED exact-plan task",
        "operation": AUTHORITY_PLAN_OPERATION,
        "rows": rows,
    }
    digest = canonical_sha256(plan)
    if digest != ACCEPTED_AUTHORITY_PLAN_SHA256:
        raise DispositionRepairError(
            "live authority plan does not match Claude-approved canonical SHA-256: "
            f"expected={ACCEPTED_AUTHORITY_PLAN_SHA256} actual={digest}"
        )
    if len(canonical_json_bytes(plan)) != ACCEPTED_AUTHORITY_PLAN_BYTES:
        raise DispositionRepairError("accepted authority plan canonical byte count drifted")
    return plan


def _load_agent_payload(row: sqlite3.Row, label: str) -> dict[str, Any]:
    value = parse_json_text(str(row["payload_json"]), label)
    if not isinstance(value, dict):
        raise DispositionRepairError(f"{label}: payload root must be an object")
    return value


def authority_gate(conn: sqlite3.Connection) -> dict[str, Any]:
    task = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (AUTHORITY_TASK_ID,)).fetchone()
    predecessor = conn.execute(
        "SELECT * FROM agent_tasks WHERE id=?", (PREDECESSOR_TASK_ID,)
    ).fetchone()
    if task is None or predecessor is None:
        raise DispositionRepairError("authority or predecessor agent task is missing")
    payload = _load_agent_payload(task, "authority task")
    predecessor_payload = _load_agent_payload(predecessor, "predecessor task")
    if task["task_type"] != "ops_issue" or task["assigned_agent"] != "codex":
        raise DispositionRepairError("authority task type/assignee mismatch")
    if task["state"] not in {"IN_PROGRESS", "REVIEW", "APPROVED"}:
        raise DispositionRepairError(f"authority task state is not executable: {task['state']}")
    brief = str(payload.get("brief") or "")
    required_brief_tokens = (
        ACCEPTED_AUTHORITY_PLAN_SHA256,
        "qm-q02-disposition-repair-plan/v1",
        "Legacy-summary bindings explicitly accepted",
        "Sunday 2026-08-02 Factory-OFF window",
    )
    if any(token not in brief for token in required_brief_tokens):
        raise DispositionRepairError("authority task brief lacks an exact approved-plan/window token")
    if payload.get("predecessor") != "27086064" or payload.get("reviewer_after") != "claude":
        raise DispositionRepairError("authority task predecessor/reviewer binding mismatch")
    if predecessor["state"] not in {"APPROVED", "PASSED"}:
        raise DispositionRepairError(
            f"predecessor review is not approved/terminal: {predecessor['state']}"
        )
    if predecessor_payload.get("review_close_state") != "APPROVED":
        raise DispositionRepairError("predecessor close-review state is not APPROVED")
    predecessor_verdict = str(predecessor_payload.get("review_close_verdict") or "")
    if "DISPOSITION-REPAIR PLAN REVIEWED AND ACCEPTED" not in predecessor_verdict:
        raise DispositionRepairError("predecessor close-review did not accept the plan")
    if ACCEPTED_AUTHORITY_PLAN_SHA256[:8] not in predecessor_verdict:
        raise DispositionRepairError("predecessor close-review plan digest token mismatch")
    return {
        "authority_task": {
            "id": task["id"],
            "state": task["state"],
            "assigned_agent": task["assigned_agent"],
            "updated_at": task["updated_at"],
            "payload_sha256": payload_sha256(task["payload_json"]),
        },
        "approved_predecessor": {
            "id": predecessor["id"],
            "state": predecessor["state"],
            "updated_at": predecessor["updated_at"],
            "payload_sha256": payload_sha256(predecessor["payload_json"]),
        },
        "legacy_summary_bindings_explicitly_accepted": True,
    }


def pair_gate(conn: sqlite3.Connection, row: sqlite3.Row) -> dict[str, int]:
    values = (row["ea_id"], row["symbol"], row["id"])
    open_count = int(
        conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE phase='Q02' AND ea_id=? AND symbol=? "
            "AND id<>? AND status IN ('pending','active')",
            values,
        ).fetchone()[0]
    )
    noninfra_count = int(
        conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE phase='Q02' AND ea_id=? AND symbol=? "
            "AND id<>? AND status IN ('done','failed') "
            "AND COALESCE(verdict,'') NOT IN ('','INFRA_FAIL')",
            values,
        ).fetchone()[0]
    )
    if open_count or noninfra_count:
        raise DispositionRepairError(
            f"{row['id']}: pair gate blocked open={open_count} noninfra={noninfra_count}"
        )
    return {"open_q02_rows": open_count, "other_noninfra_terminal_q02_rows": noninfra_count}


def _validate_target_row(row: sqlite3.Row) -> None:
    if row["phase"] != "Q02" or row["status"] != "failed" or row["verdict"] != "INFRA_FAIL":
        raise DispositionRepairError(
            f"{row['id']}: expected Q02 failed/INFRA_FAIL, got "
            f"{row['phase']} {row['status']}/{row['verdict']}"
        )
    if row["claimed_by"] is not None:
        raise DispositionRepairError(f"{row['id']}: terminal claim is not null")
    payload = parse_json_text(str(row["payload_json"]), f"{row['id']} payload")
    if not isinstance(payload, dict):
        raise DispositionRepairError(f"{row['id']}: payload root is not an object")
    if "q02_disposition_repair" in payload:
        raise DispositionRepairError(f"{row['id']}: disposition-repair audit already exists")


def build_execution_plan(conn: sqlite3.Connection, paths: RuntimePaths) -> dict[str, Any]:
    authority = authority_gate(conn)
    authority_plan = build_authority_plan(conn)
    targets: list[dict[str, Any]] = []
    for work_item_id in TARGET_IDS:
        row = _fetch_work_item(conn, work_item_id)
        assert row is not None
        _validate_target_row(row)
        preimage = _row_dict(row)
        targets.append(
            {
                "work_item_id": work_item_id,
                "full_preimage": preimage,
                "full_preimage_sha256": canonical_sha256(preimage),
                "payload_sha256": payload_sha256(row["payload_json"]),
                "evidence": _evidence_facts(row),
                "pair_gate": pair_gate(conn, row),
            }
        )
    controller = Path(__file__).resolve()
    return {
        "schema_version": EXECUTION_PLAN_SCHEMA,
        "generated_at_utc": utc_stamp(),
        "operation": AUTHORITY_PLAN_OPERATION,
        "authority": {
            **authority,
            "canonical_plan": authority_plan,
            "canonical_plan_sha256": canonical_sha256(authority_plan),
            "canonical_plan_bytes": len(canonical_json_bytes(authority_plan)),
        },
        "controller": {
            "path": str(controller),
            "sha256": sha256_file(controller),
            "git_head": _git_head(paths.repo),
        },
        "database": {
            "path": str(paths.db.resolve()),
            "quick_check": quick_check(conn),
        },
        "targets": targets,
        "mutation_performed": False,
    }


def _active_count(conn: sqlite3.Connection) -> int:
    return int(conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0])


def window_snapshot(conn: sqlite3.Connection, paths: RuntimePaths) -> dict[str, Any]:
    now = current_utc()
    local = now.astimezone(AUTHORIZED_TIMEZONE)
    flag = None
    if paths.factory_off_flag.is_file():
        flag = {
            "path": str(paths.factory_off_flag.resolve()),
            "sha256": sha256_file(paths.factory_off_flag),
            "bytes": paths.factory_off_flag.stat().st_size,
        }
    return {
        "checked_at_utc": utc_stamp(now),
        "checked_at_europe_berlin": local.isoformat(),
        "authorized_local_date": AUTHORIZED_APPLY_DATE.isoformat(),
        "date_gate_open": local.date() == AUTHORIZED_APPLY_DATE,
        "factory_off": flag,
        "active_work_items": _active_count(conn),
        "mutation_lock_path": str(paths.lock_path.resolve(strict=False)),
    }


def dry_run(
    plan_out: Path,
    receipt_out: Path,
    paths: RuntimePaths,
) -> dict[str, Any]:
    conn = connect_ro(paths.db)
    try:
        plan = build_execution_plan(conn, paths)
        window = window_snapshot(conn, paths)
    finally:
        conn.close()
    plan_sha = write_json_atomic(plan_out, plan, require_absent=True)
    receipt = {
        "schema_version": DRY_RUN_RECEIPT_SCHEMA,
        "generated_at_utc": utc_stamp(),
        "status": "READY_FOR_AUTHORIZED_WINDOW",
        "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
        "execution_plan": {
            "path": str(plan_out.resolve()),
            "sha256": plan_sha,
        },
        "window_snapshot": window,
        "target_count": len(TARGET_IDS),
        "database_quick_check": plan["database"]["quick_check"],
        "mutation_performed": False,
    }
    receipt_sha = write_json_atomic(receipt_out, receipt, require_absent=True)
    return {**receipt, "dry_run_receipt": {"path": str(receipt_out.resolve()), "sha256": receipt_sha}}


def load_execution_plan(
    plan_path: Path,
    expected_execution_plan_sha256: str,
    paths: RuntimePaths,
) -> tuple[dict[str, Any], str]:
    expected = normal_sha(expected_execution_plan_sha256, "expected execution-plan SHA-256")
    plan, raw_sha = load_json_strict(plan_path, "execution plan")
    if raw_sha != expected:
        raise DispositionRepairError(
            f"execution-plan SHA-256 mismatch: expected={expected} actual={raw_sha}"
        )
    if plan.get("schema_version") != EXECUTION_PLAN_SCHEMA:
        raise DispositionRepairError("execution-plan schema mismatch")
    if plan.get("operation") != AUTHORITY_PLAN_OPERATION:
        raise DispositionRepairError("execution-plan operation mismatch")
    authority = plan.get("authority")
    if not isinstance(authority, Mapping):
        raise DispositionRepairError("execution-plan authority section missing")
    canonical_plan = authority.get("canonical_plan")
    if not isinstance(canonical_plan, Mapping):
        raise DispositionRepairError("execution-plan canonical authority plan missing")
    if canonical_sha256(canonical_plan) != ACCEPTED_AUTHORITY_PLAN_SHA256:
        raise DispositionRepairError("execution-plan canonical authority digest mismatch")
    if authority.get("canonical_plan_sha256") != ACCEPTED_AUTHORITY_PLAN_SHA256:
        raise DispositionRepairError("execution-plan declared authority digest mismatch")
    if authority.get("canonical_plan_bytes") != ACCEPTED_AUTHORITY_PLAN_BYTES:
        raise DispositionRepairError("execution-plan authority byte count mismatch")
    controller = plan.get("controller")
    if not isinstance(controller, Mapping):
        raise DispositionRepairError("execution-plan controller binding missing")
    expected_controller = Path(__file__).resolve()
    if Path(str(controller.get("path") or "")).resolve() != expected_controller:
        raise DispositionRepairError("execution-plan controller path mismatch")
    if normal_sha(controller.get("sha256"), "controller SHA-256") != sha256_file(
        expected_controller
    ):
        raise DispositionRepairError("controller bytes differ from immutable execution plan")
    database = plan.get("database")
    if not isinstance(database, Mapping) or Path(str(database.get("path") or "")).resolve() != paths.db.resolve():
        raise DispositionRepairError("execution-plan database path mismatch")
    targets = plan.get("targets")
    if not isinstance(targets, list) or [row.get("work_item_id") for row in targets] != list(
        TARGET_IDS
    ):
        raise DispositionRepairError("execution-plan target order/scope mismatch")
    return plan, raw_sha


def validate_execution_plan_live(
    conn: sqlite3.Connection,
    plan: Mapping[str, Any],
) -> list[dict[str, Any]]:
    authority_gate(conn)
    live_authority = build_authority_plan(conn)
    if live_authority != plan["authority"]["canonical_plan"]:
        raise DispositionRepairError("live canonical authority plan differs from execution plan")
    validated: list[dict[str, Any]] = []
    for target in plan["targets"]:
        work_item_id = str(target["work_item_id"])
        row = _fetch_work_item(conn, work_item_id)
        if row is None:
            raise DispositionRepairError(f"execution-plan row missing: {work_item_id}")
        _validate_target_row(row)
        preimage = _row_dict(row)
        if preimage != target.get("full_preimage"):
            raise DispositionRepairError(f"{work_item_id}: full preimage drifted")
        if canonical_sha256(preimage) != target.get("full_preimage_sha256"):
            raise DispositionRepairError(f"{work_item_id}: full preimage hash drifted")
        facts = _evidence_facts(row)
        if facts != target.get("evidence"):
            raise DispositionRepairError(f"{work_item_id}: evidence facts drifted")
        if pair_gate(conn, row) != target.get("pair_gate"):
            raise DispositionRepairError(f"{work_item_id}: pair-level gate drifted")
        validated.append({"row": row, "preimage": preimage, "evidence": facts})
    return validated


def _require_apply_date() -> dt.datetime:
    now = current_utc()
    local = now.astimezone(AUTHORIZED_TIMEZONE)
    if local.date() != AUTHORIZED_APPLY_DATE:
        raise DispositionRepairError(
            "mutation refused outside authorized Europe/Berlin date "
            f"{AUTHORIZED_APPLY_DATE.isoformat()}; current={local.isoformat()}"
        )
    return now


def _require_factory_window(
    conn: sqlite3.Connection,
    paths: RuntimePaths,
    expected_factory_off_sha256: str,
) -> dict[str, Any]:
    expected = normal_sha(expected_factory_off_sha256, "expected FACTORY_OFF SHA-256")
    if not paths.factory_off_flag.is_file():
        raise DispositionRepairError(f"FACTORY_OFF flag missing: {paths.factory_off_flag}")
    actual = sha256_file(paths.factory_off_flag)
    if actual != expected:
        raise DispositionRepairError(
            f"FACTORY_OFF SHA-256 mismatch: expected={expected} actual={actual}"
        )
    active = _active_count(conn)
    if active != 0:
        raise DispositionRepairError(f"Factory-OFF mutation requires zero active work items; found {active}")
    return {
        "path": str(paths.factory_off_flag.resolve()),
        "sha256": actual,
        "bytes": paths.factory_off_flag.stat().st_size,
        "active_work_items": active,
    }


def create_online_backup(source: sqlite3.Connection, paths: RuntimePaths) -> dict[str, Any]:
    timestamp = current_utc().astimezone(dt.UTC).strftime("%Y%m%dT%H%M%S%fZ")
    destination = (
        paths.backup_dir / f"farm_state_pre_q02_disposition_repair_{timestamp}.sqlite"
    ).resolve(strict=False)
    if destination.exists():
        raise DispositionRepairError(f"backup destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = sqlite3.connect(destination)
    try:
        source.backup(backup)
        if [str(row[0]) for row in backup.execute("PRAGMA quick_check").fetchall()] != ["ok"]:
            raise DispositionRepairError("fresh online backup quick_check failed")
    finally:
        backup.close()
    return {
        "path": str(destination),
        "sha256": sha256_file(destination),
        "bytes": destination.stat().st_size,
        "quick_check": "ok",
        "created_at_utc": utc_stamp(),
    }


def _new_postimage(
    preimage: Mapping[str, Any],
    evidence: Mapping[str, Any],
    *,
    now: str,
    execution_plan_sha256: str,
    backup: Mapping[str, Any],
) -> dict[str, Any]:
    payload = parse_json_text(str(preimage["payload_json"]), f"{preimage['id']} payload")
    if not isinstance(payload, dict):
        raise DispositionRepairError(f"{preimage['id']}: payload root is not an object")
    if "q02_disposition_repair" in payload:
        raise DispositionRepairError(f"{preimage['id']}: audit key already exists")
    payload["q02_disposition_repair"] = {
        "schema_version": PAYLOAD_AUDIT_SCHEMA,
        "applied_at_utc": now,
        "authority_task_id": AUTHORITY_TASK_ID,
        "approved_predecessor_task_id": PREDECESSOR_TASK_ID,
        "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
        "execution_plan_sha256": execution_plan_sha256,
        "backup": copy.deepcopy(dict(backup)),
        "prior_disposition": {
            "status": preimage["status"],
            "verdict": preimage["verdict"],
            "claimed_by": preimage["claimed_by"],
            "updated_at": preimage["updated_at"],
        },
        "prior_payload_sha256": payload_sha256(preimage["payload_json"]),
        "evidence": copy.deepcopy(dict(evidence)),
        "pass_facts": {
            "summary_result": evidence["summary_result"],
            "ok_runs": evidence["ok_runs"],
            "total_trades": evidence["total_trades"],
        },
        "historical_evidence_preserved": True,
        "rerun_or_enqueue_performed": False,
        "pipeline_verdict_inferred": False,
    }
    post = copy.deepcopy(dict(preimage))
    post["status"] = "done"
    post["verdict"] = "PASS"
    post["payload_json"] = json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False
    )
    post["updated_at"] = now
    return post


def _cas_full_preimage(
    conn: sqlite3.Connection,
    preimage: Mapping[str, Any],
    postimage: Mapping[str, Any],
) -> None:
    where = " AND ".join(f"{column} IS ?" for column in WORK_ITEM_COLUMNS)
    cursor = conn.execute(
        f"UPDATE work_items SET status=?,verdict=?,payload_json=?,updated_at=? WHERE {where}",  # noqa: S608
        (
            postimage["status"],
            postimage["verdict"],
            postimage["payload_json"],
            postimage["updated_at"],
            *(preimage[column] for column in WORK_ITEM_COLUMNS),
        ),
    )
    if cursor.rowcount != 1:
        raise DispositionRepairError(
            f"{preimage['id']}: exact full-preimage CAS affected {cursor.rowcount} rows"
        )


def _cas_restore_full_postimage(
    conn: sqlite3.Connection,
    preimage: Mapping[str, Any],
    postimage: Mapping[str, Any],
) -> None:
    set_columns = WORK_ITEM_COLUMNS[1:]
    assignments = ",".join(f"{column}=?" for column in set_columns)
    where = " AND ".join(f"{column} IS ?" for column in WORK_ITEM_COLUMNS)
    cursor = conn.execute(
        f"UPDATE work_items SET {assignments} WHERE {where}",  # noqa: S608
        (
            *(preimage[column] for column in set_columns),
            *(postimage[column] for column in WORK_ITEM_COLUMNS),
        ),
    )
    if cursor.rowcount != 1:
        raise DispositionRepairError(
            f"{preimage['id']}: guarded revert CAS affected {cursor.rowcount} rows"
        )


def _insert_event(
    conn: sqlite3.Connection,
    *,
    timestamp: str,
    entity_type: str,
    entity_id: str,
    event: str,
    detail: Mapping[str, Any],
) -> int:
    cursor = conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
        (
            timestamp,
            entity_type,
            entity_id,
            event,
            canonical_json_bytes(detail).decode("utf-8"),
        ),
    )
    if cursor.rowcount != 1:
        raise DispositionRepairError(f"event insert failed: {event}")
    return int(cursor.lastrowid)


def apply_plan(
    plan_path: Path,
    expected_execution_plan_sha256: str,
    expected_authority_plan_sha256: str,
    expected_factory_off_sha256: str,
    journal_path: Path,
    paths: RuntimePaths,
) -> dict[str, Any]:
    if normal_sha(expected_authority_plan_sha256, "expected authority-plan SHA-256") != (
        ACCEPTED_AUTHORITY_PLAN_SHA256
    ):
        raise DispositionRepairError("expected authority-plan SHA-256 is not the approved digest")
    plan, plan_sha = load_execution_plan(plan_path, expected_execution_plan_sha256, paths)
    journal_path = journal_path.resolve(strict=False)
    if journal_path.exists():
        raise DispositionRepairError(f"journal already exists: {journal_path}")
    _require_apply_date()

    with FactoryMutationLock(paths.lock_path, owner="q02_disposition_repair.apply"):
        preflight = connect_rw(paths.db)
        try:
            factory_receipt = _require_factory_window(
                preflight, paths, expected_factory_off_sha256
            )
            validate_execution_plan_live(preflight, plan)
            quick_check(preflight)
            backup = create_online_backup(preflight, paths)
        finally:
            preflight.close()

        conn = connect_rw(paths.db)
        journal: dict[str, Any] | None = None
        try:
            conn.execute("BEGIN IMMEDIATE")
            _require_apply_date()
            factory_receipt = _require_factory_window(
                conn, paths, expected_factory_off_sha256
            )
            validated = validate_execution_plan_live(conn, plan)
            quick_check(conn)
            now = utc_stamp()
            row_journal: list[dict[str, Any]] = []
            event_ids: list[int] = []
            for item in validated:
                preimage = item["preimage"]
                evidence = item["evidence"]
                postimage = _new_postimage(
                    preimage,
                    evidence,
                    now=now,
                    execution_plan_sha256=plan_sha,
                    backup=backup,
                )
                _cas_full_preimage(conn, preimage, postimage)
                pre_hash = canonical_sha256(preimage)
                post_hash = canonical_sha256(postimage)
                event_id = _insert_event(
                    conn,
                    timestamp=now,
                    entity_type="work_item",
                    entity_id=str(preimage["id"]),
                    event="q02_disposition_repair_applied",
                    detail={
                        "authority_task_id": AUTHORITY_TASK_ID,
                        "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
                        "execution_plan_sha256": plan_sha,
                        "backup_sha256": backup["sha256"],
                        "preimage_sha256": pre_hash,
                        "postimage_sha256": post_hash,
                        "evidence_sha256": evidence["sha256"],
                        "pipeline_verdict_inferred": False,
                    },
                )
                event_ids.append(event_id)
                row_journal.append(
                    {
                        "work_item_id": preimage["id"],
                        "preimage": preimage,
                        "preimage_sha256": pre_hash,
                        "postimage": postimage,
                        "postimage_sha256": post_hash,
                        "evidence": evidence,
                        "apply_event_id": event_id,
                    }
                )
            cohort_event_id = _insert_event(
                conn,
                timestamp=now,
                entity_type="cohort",
                entity_id=AUTHORITY_TASK_ID,
                event="q02_disposition_repair_cohort_applied",
                detail={
                    "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
                    "execution_plan_sha256": plan_sha,
                    "backup_sha256": backup["sha256"],
                    "work_item_ids": list(TARGET_IDS),
                    "row_count": len(TARGET_IDS),
                    "row_event_ids": event_ids,
                    "rerun_or_enqueue_performed": False,
                },
            )
            _require_apply_date()
            factory_receipt = _require_factory_window(
                conn, paths, expected_factory_off_sha256
            )
            transaction_check = quick_check(conn)
            journal = {
                "schema_version": JOURNAL_SCHEMA,
                "state": "prepared",
                "prepared_at_utc": now,
                "authority_task_id": AUTHORITY_TASK_ID,
                "approved_predecessor_task_id": PREDECESSOR_TASK_ID,
                "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
                "execution_plan": {
                    "path": str(plan_path.resolve()),
                    "sha256": plan_sha,
                },
                "factory_off_receipt": factory_receipt,
                "backup": backup,
                "rows": row_journal,
                "cohort_event_id": cohort_event_id,
                "transaction_quick_check": transaction_check,
            }
            prepared_sha = write_json_atomic(journal_path, journal, require_absent=True)
            journal["prepared_journal_sha256"] = prepared_sha
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()

        journal["state"] = "committed_pending_verification"
        journal["committed_at_utc"] = utc_stamp()
        write_json_atomic(journal_path, journal, require_absent=False)

        post = connect_ro(paths.db)
        try:
            post_check = quick_check(post)
            for row_record in journal["rows"]:
                row = _fetch_work_item(post, str(row_record["work_item_id"]))
                if row is None or _row_dict(row) != row_record["postimage"]:
                    raise DispositionRepairError(
                        f"post-commit verification failed: {row_record['work_item_id']}"
                    )
        finally:
            post.close()
        journal["state"] = "committed"
        journal["post_commit_quick_check"] = post_check
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "APPLIED",
            "row_count": len(TARGET_IDS),
            "authority_plan_sha256": ACCEPTED_AUTHORITY_PLAN_SHA256,
            "execution_plan_sha256": plan_sha,
            "backup": backup,
            "journal_path": str(journal_path),
            "journal_sha256": final_sha,
            "post_commit_quick_check": post_check,
            "rerun_or_enqueue_performed": False,
            "pipeline_verdict_inferred": False,
        }


def revert_journal(
    journal_path: Path,
    expected_journal_sha256: str,
    expected_factory_off_sha256: str,
    paths: RuntimePaths,
) -> dict[str, Any]:
    expected_journal = normal_sha(expected_journal_sha256, "expected journal SHA-256")
    journal, raw_sha = load_json_strict(journal_path, "revert journal")
    if raw_sha != expected_journal:
        raise DispositionRepairError("revert journal SHA-256 mismatch")
    if journal.get("schema_version") != JOURNAL_SCHEMA or journal.get("state") not in {
        "prepared",
        "committed_pending_verification",
        "committed",
    }:
        raise DispositionRepairError("journal is not a revertible disposition-repair journal")
    if journal.get("authority_task_id") != AUTHORITY_TASK_ID:
        raise DispositionRepairError("journal authority task mismatch")
    if journal.get("authority_plan_sha256") != ACCEPTED_AUTHORITY_PLAN_SHA256:
        raise DispositionRepairError("journal authority-plan digest mismatch")
    rows = journal.get("rows")
    if not isinstance(rows, list) or [row.get("work_item_id") for row in rows] != list(TARGET_IDS):
        raise DispositionRepairError("journal row scope/order mismatch")
    _require_apply_date()

    with FactoryMutationLock(paths.lock_path, owner="q02_disposition_repair.revert"):
        conn = connect_rw(paths.db)
        try:
            conn.execute("BEGIN IMMEDIATE")
            _require_apply_date()
            _require_factory_window(conn, paths, expected_factory_off_sha256)
            quick_check(conn)
            for record in rows:
                preimage = record.get("preimage")
                postimage = record.get("postimage")
                if not isinstance(preimage, Mapping) or not isinstance(postimage, Mapping):
                    raise DispositionRepairError("journal pre/post image missing")
                if canonical_sha256(preimage) != record.get("preimage_sha256"):
                    raise DispositionRepairError(f"{record.get('work_item_id')}: journal preimage hash mismatch")
                if canonical_sha256(postimage) != record.get("postimage_sha256"):
                    raise DispositionRepairError(f"{record.get('work_item_id')}: journal postimage hash mismatch")
                current = _fetch_work_item(conn, str(record["work_item_id"]))
                if current is None or _row_dict(current) != dict(postimage):
                    raise DispositionRepairError(
                        f"{record['work_item_id']}: guarded revert refused partial/drifted post-state"
                    )
            now = utc_stamp()
            revert_event_ids: list[int] = []
            for record in rows:
                _cas_restore_full_postimage(conn, record["preimage"], record["postimage"])
                revert_event_ids.append(
                    _insert_event(
                        conn,
                        timestamp=now,
                        entity_type="work_item",
                        entity_id=str(record["work_item_id"]),
                        event="q02_disposition_repair_reverted",
                        detail={
                            "journal_sha256": raw_sha,
                            "preimage_sha256": record["preimage_sha256"],
                            "postimage_sha256": record["postimage_sha256"],
                        },
                    )
                )
            cohort_event_id = _insert_event(
                conn,
                timestamp=now,
                entity_type="cohort",
                entity_id=AUTHORITY_TASK_ID,
                event="q02_disposition_repair_cohort_reverted",
                detail={
                    "journal_sha256": raw_sha,
                    "work_item_ids": list(TARGET_IDS),
                    "row_event_ids": revert_event_ids,
                },
            )
            _require_apply_date()
            _require_factory_window(conn, paths, expected_factory_off_sha256)
            transaction_check = quick_check(conn)
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()

        post = connect_ro(paths.db)
        try:
            post_check = quick_check(post)
            for record in rows:
                current = _fetch_work_item(post, str(record["work_item_id"]))
                if current is None or _row_dict(current) != record["preimage"]:
                    raise DispositionRepairError(
                        f"{record['work_item_id']}: post-revert verification failed"
                    )
        finally:
            post.close()
        journal["state"] = "reverted"
        journal["reverted_at_utc"] = utc_stamp()
        journal["revert"] = {
            "source_journal_sha256": raw_sha,
            "row_event_ids": revert_event_ids,
            "cohort_event_id": cohort_event_id,
            "transaction_quick_check": transaction_check,
            "post_commit_quick_check": post_check,
        }
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "REVERTED",
            "row_count": len(TARGET_IDS),
            "journal_path": str(journal_path.resolve()),
            "journal_sha256": final_sha,
            "post_commit_quick_check": post_check,
        }


def _add_runtime_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    dry = commands.add_parser("dry-run", help="write immutable execution plan and receipt")
    _add_runtime_args(dry)
    dry.add_argument("--plan-out", type=Path, required=True)
    dry.add_argument("--receipt-out", type=Path, required=True)

    apply = commands.add_parser("apply", help="apply exact ten-row repair in authorized window")
    _add_runtime_args(apply)
    apply.add_argument("--plan", type=Path, required=True)
    apply.add_argument("--expected-execution-plan-sha256", required=True)
    apply.add_argument("--expected-authority-plan-sha256", required=True)
    apply.add_argument("--expected-factory-off-sha256", required=True)
    apply.add_argument("--journal-out", type=Path, required=True)
    apply.add_argument("--receipt-out", type=Path)

    revert = commands.add_parser("revert", help="guarded all-ten-row journal revert")
    _add_runtime_args(revert)
    revert.add_argument("--journal", type=Path, required=True)
    revert.add_argument("--expected-journal-sha256", required=True)
    revert.add_argument("--expected-factory-off-sha256", required=True)
    revert.add_argument("--receipt-out", type=Path)
    return parser


def _paths(args: argparse.Namespace) -> RuntimePaths:
    return RuntimePaths(
        db=args.db,
        repo=args.repo,
        factory_off_flag=args.factory_off_flag,
        backup_dir=args.backup_dir,
        mutation_lock=args.mutation_lock,
    )


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    paths = _paths(args)
    try:
        if args.command == "dry-run":
            result = dry_run(args.plan_out, args.receipt_out, paths)
        elif args.command == "apply":
            result = apply_plan(
                args.plan,
                args.expected_execution_plan_sha256,
                args.expected_authority_plan_sha256,
                args.expected_factory_off_sha256,
                args.journal_out,
                paths,
            )
            if args.receipt_out:
                receipt_sha = write_json_atomic(args.receipt_out, result, require_absent=True)
                result["apply_receipt"] = {
                    "path": str(args.receipt_out.resolve()),
                    "sha256": receipt_sha,
                }
        else:
            result = revert_journal(
                args.journal,
                args.expected_journal_sha256,
                args.expected_factory_off_sha256,
                paths,
            )
            if args.receipt_out:
                receipt_sha = write_json_atomic(args.receipt_out, result, require_absent=True)
                result["revert_receipt"] = {
                    "path": str(args.receipt_out.resolve()),
                    "sha256": receipt_sha,
                }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (DispositionRepairError, OSError, sqlite3.Error, KeyError, TypeError, ValueError) as exc:
        print(f"q02 disposition repair refused: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
