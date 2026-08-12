#!/usr/bin/env python3
"""OWNER-scoped, one-row Q08 requalification controller.

Dry-run is the default.  The global MNT-007 recovery classifier is deliberately
untouched: this controller can act only on the exact OWNER-authorized exception
target and only after an implementation-review receipt is bound into its JSON
contract.  Apply/revert additionally require Factory OFF, zero active work
items, the global Factory mutation lock, one ``BEGIN IMMEDIATE`` transaction,
an exact row CAS, and a durable pre/post journal.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import importlib.util
import json
import os
import re
import sqlite3
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence


_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag  # noqa: E402


CONTRACT_SCHEMA = "qm.q08-single-target-requal-exception/v1"
PLAN_SCHEMA = "qm.q08-single-target-requal-plan/v1"
JOURNAL_SCHEMA = "qm.q08-single-target-requal-journal/v1"
OWNER_REFERENCE = "OWNER_DECISION_2026-07-31_Q08_SINGLE_TARGET_REQUAL"
OWNER_DECISION_RELATIVE_PATH = Path(
    "docs/ops/CODEX_BRIEF_2026-07-31_q08_single_target_requal.md"
)
OWNER_DECISION_SHA256 = "2a5bc603e4eb7cd0e1ab56501286ff28256588948214f029cb350b65637afc71"
OWNER_DECISION_COMMIT = "31475d9f1c476c9ca43d94fef58cc13b933c1337"
REASON_CLASS = "MARKERLESS_STRATEGY_ASSIGNMENTS_PARSER_DEFECT"
PARSER_FIX_COMMIT = "12629f50717461e0a66c3af5b466f1d8fcc11e59"
GLOBAL_INVARIANT = "MNT-007_Q08_INVALID_REPORT_NON_RETRYABLE_UNCHANGED"

AUTHORIZED_TARGET = {
    "work_item_id": "95015420-11d0-4c11-bb98-25fa2a361048",
    "ea_id": "QM5_10582",
    "symbol": "XAUUSD.DWX",
    "phase": "Q08",
}

TARGET_SETFILE_SHA256 = {
    "setfile_base": "082028275fbb0870d5e0665f5c3131d2d360bb8ff36597aada955c3692eb9d04",
    "setfile_ablation_00": "8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3",
    "setfile_ablation_01": "f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6",
    "setfile_ablation_02": "477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1",
}

REQUIRED_ARTIFACT_ROLES = frozenset(
    {
        "controller_source",
        "parser_source",
        "mq5",
        "ex5",
        *TARGET_SETFILE_SHA256,
    }
)
SETFILE_ROLES = (
    "setfile_base",
    "setfile_ablation_00",
    "setfile_ablation_01",
    "setfile_ablation_02",
)

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_REPORTS = Path(r"D:\QM\reports\work_items")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
DEFAULT_ARCHIVE = DEFAULT_REPORTS / "_requal_archive"

STATE_FIELDS = (
    "status",
    "verdict",
    "attempt_count",
    "evidence_path",
    "claimed_by",
    "payload_json",
    "updated_at",
)
STALE_RUNTIME_KEYS = (
    "pid",
    "started_at_iso",
    "log_path",
    "claimed_at_iso",
    "claimed_by_worker_pid",
    "commit_reservation_gb",
    "commit_reservation_until_utc",
    "terminal",
)


class RequalError(RuntimeError):
    """Fail-closed contract, gate, CAS, archive, or journal error."""


@dataclass(frozen=True)
class RuntimePaths:
    db: Path = DEFAULT_DB
    repo: Path = DEFAULT_REPO
    reports_root: Path = DEFAULT_REPORTS
    factory_off_flag: Path = DEFAULT_FACTORY_OFF
    archive_root: Path = DEFAULT_ARCHIVE
    mutation_lock: Path | None = None

    @property
    def lock_path(self) -> Path:
        return self.mutation_lock or path_for_factory_flag(self.factory_off_flag)


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    except OSError as exc:
        raise RequalError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def normalized_lf_bytes(path: Path) -> bytes:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise RequalError(f"cannot read text artifact {path}: {exc}") from exc
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def artifact_identity(path: Path, basis: str) -> tuple[str, int]:
    if basis == "RAW_BYTES":
        return sha256_file(path), path.stat().st_size
    if basis == "UTF8_TEXT_LF_NORMALIZED":
        raw = normalized_lf_bytes(path)
        try:
            raw.decode("utf-8", errors="strict")
        except UnicodeDecodeError as exc:
            raise RequalError(f"normalized text artifact is not UTF-8: {path}: {exc}") from exc
        return sha256_bytes(raw), len(raw)
    raise RequalError(f"unsupported artifact SHA-256 basis: {basis}")


def payload_sha256(raw: Any) -> str:
    if not isinstance(raw, str):
        raise RequalError("payload_json is not text")
    return sha256_bytes(raw.encode("utf-8"))


def _reject_constant(token: str) -> None:
    raise RequalError(f"non-finite JSON constant: {token}")


def _no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RequalError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path, label: str) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        value = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_no_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RequalError(f"{label}: unreadable/invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise RequalError(f"{label}: root must be an object")
    return value, sha256_bytes(raw)


def _normal_sha(value: Any, label: str) -> str:
    token = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", token):
        raise RequalError(f"{label}: expected SHA-256")
    return token


def _normal_commit(value: Any, label: str) -> str:
    token = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", token):
        raise RequalError(f"{label}: expected full Git commit SHA")
    return token


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve(strict=False))) == os.path.normcase(
        str(right.resolve(strict=False))
    )


def _is_within(child: Path, parent: Path) -> bool:
    child_resolved = child.resolve(strict=False)
    parent_resolved = parent.resolve(strict=False)
    try:
        child_resolved.relative_to(parent_resolved)
    except ValueError:
        return False
    return True


def connect_ro(path: Path) -> sqlite3.Connection:
    try:
        uri = path.resolve().as_uri() + "?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=30)
    except sqlite3.Error as exc:
        raise RequalError(f"cannot open database read-only: {exc}") from exc
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def connect_rw(path: Path) -> sqlite3.Connection:
    try:
        conn = sqlite3.connect(path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=30000")
        return conn
    except sqlite3.Error as exc:
        raise RequalError(f"cannot open database read-write: {exc}") from exc


def write_json_atomic(path: Path, value: Mapping[str, Any], *, require_absent: bool) -> str:
    path = path.resolve(strict=False)
    if require_absent and path.exists():
        raise RequalError(f"refusing to overwrite existing artifact: {path}")
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
            raise RequalError(f"artifact appeared before atomic replace: {path}")
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass
    return sha256_bytes(raw)


def _run_git(repo: Path, *args: str, binary: bool = False) -> bytes | str:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            capture_output=True,
            text=not binary,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise RequalError(f"Git provenance check failed: {exc}") from exc
    if completed.returncode != 0:
        stderr = completed.stderr if isinstance(completed.stderr, str) else completed.stderr.decode(
            "utf-8", errors="replace"
        )
        raise RequalError(f"Git command failed ({' '.join(args)}): {stderr.strip()}")
    return completed.stdout


def verify_git_provenance(
    contract: Mapping[str, Any], paths: RuntimePaths, artifacts: Mapping[str, Mapping[str, Any]]
) -> dict[str, Any]:
    fix = contract["parser_fix"]
    commit = _normal_commit(fix.get("commit_sha"), "parser_fix.commit_sha")
    if commit != PARSER_FIX_COMMIT:
        raise RequalError("parser fix commit is not the OWNER-scoped fallback commit")
    head = str(_run_git(paths.repo, "rev-parse", "HEAD")).strip().lower()
    _normal_commit(head, "git HEAD")
    _run_git(paths.repo, "merge-base", "--is-ancestor", commit, head)
    _run_git(paths.repo, "merge-base", "--is-ancestor", OWNER_DECISION_COMMIT, head)

    parser_path = Path(str(artifacts["parser_source"]["path"])).resolve()
    controller_path = Path(str(artifacts["controller_source"]["path"])).resolve()
    if not _is_within(parser_path, paths.repo) or not _is_within(controller_path, paths.repo):
        raise RequalError("controller/parser source is outside the repository")
    parser_rel = parser_path.relative_to(paths.repo.resolve()).as_posix()
    controller_rel = controller_path.relative_to(paths.repo.resolve()).as_posix()
    if parser_rel != "framework/scripts/q08_5_neighborhood_runner.py":
        raise RequalError("parser_source is not the canonical Q08 parser")
    if controller_rel != "tools/strategy_farm/q08_single_target_requal.py":
        raise RequalError("controller_source is not the canonical controller")
    fixed_bytes = _run_git(paths.repo, "show", f"{commit}:{parser_rel}", binary=True)
    assert isinstance(fixed_bytes, bytes)
    fixed_digest = sha256_bytes(fixed_bytes)
    if fixed_digest != _normal_sha(
        fix.get("file_sha256_at_fix_commit"), "parser_fix.file_sha256_at_fix_commit"
    ):
        raise RequalError("parser file at fix commit does not match exception contract")
    owner_bytes = _run_git(
        paths.repo,
        "show",
        f"{OWNER_DECISION_COMMIT}:{OWNER_DECISION_RELATIVE_PATH.as_posix()}",
        binary=True,
    )
    assert isinstance(owner_bytes, bytes)
    if sha256_bytes(owner_bytes) != OWNER_DECISION_SHA256:
        raise RequalError("committed OWNER decision source digest mismatch")
    status = str(
        _run_git(paths.repo, "status", "--porcelain", "--", parser_rel, controller_rel)
    ).strip()
    if status:
        raise RequalError(f"controller/parser source scope is not committed and clean: {status}")
    review = contract["implementation_review"]
    reviewed_commit = None
    if review.get("status") == "APPROVED":
        reviewed_commit = _normal_commit(
            review.get("reviewed_controller_commit"), "reviewed controller commit"
        )
        _run_git(paths.repo, "merge-base", "--is-ancestor", reviewed_commit, head)
        reviewed_bytes = _run_git(
            paths.repo, "show", f"{reviewed_commit}:{controller_rel}", binary=True
        )
        assert isinstance(reviewed_bytes, bytes)
        if sha256_bytes(reviewed_bytes) != artifacts["controller_source"]["sha256"]:
            raise RequalError("reviewed commit does not contain the bound controller bytes")
    return {
        "head_commit": head,
        "parser_fix_commit": commit,
        "parser_file_sha256_at_fix_commit": fixed_digest,
        "source_scope_clean": True,
        "reviewed_controller_commit": reviewed_commit,
    }


def validate_contract(contract: Mapping[str, Any], paths: RuntimePaths) -> dict[str, dict[str, Any]]:
    if contract.get("schema_version") != CONTRACT_SCHEMA:
        raise RequalError("exception contract schema mismatch")
    authorization = contract.get("authorization")
    if not isinstance(authorization, Mapping):
        raise RequalError("authorization object missing")
    expected_authorization = {
        "authority": "OWNER",
        "owner_reference": OWNER_REFERENCE,
        "decision_date": "2026-07-31",
        "scope": "EXACT_ONE_ROW_Q08_REQUALIFICATION_CONTROLLER",
        "global_invariant": GLOBAL_INVARIANT,
        "global_invariant_weakened": False,
    }
    for key, expected in expected_authorization.items():
        if authorization.get(key) != expected:
            raise RequalError(f"authorization mismatch: {key}")
    decision_source = authorization.get("decision_source")
    expected_decision_path = (paths.repo / OWNER_DECISION_RELATIVE_PATH).resolve()
    if not isinstance(decision_source, Mapping):
        raise RequalError("authorization decision_source binding missing")
    if (
        not _same_path(Path(str(decision_source.get("path") or "")), expected_decision_path)
        or _normal_sha(decision_source.get("sha256"), "decision_source.sha256")
        != OWNER_DECISION_SHA256
        or _normal_commit(decision_source.get("commit_sha"), "decision_source.commit_sha")
        != OWNER_DECISION_COMMIT
        or not expected_decision_path.is_file()
        or artifact_identity(expected_decision_path, "UTF8_TEXT_LF_NORMALIZED")[0]
        != OWNER_DECISION_SHA256
    ):
        raise RequalError("authorization decision_source identity mismatch")

    target = contract.get("target")
    if not isinstance(target, Mapping):
        raise RequalError("target object missing")
    for key, expected in AUTHORIZED_TARGET.items():
        if target.get(key) != expected:
            raise RequalError(f"target is outside OWNER authorization: {key}")
    if target.get("reason_class") != REASON_CLASS:
        raise RequalError("target reason class mismatch")
    expected_state = target.get("expected_state")
    if not isinstance(expected_state, Mapping):
        raise RequalError("target expected_state missing")
    if (
        expected_state.get("status") != "done"
        or expected_state.get("phase") != "Q08"
        or expected_state.get("verdict") != "INFRA_FAIL"
    ):
        raise RequalError("expected row state is not the authorized INVALID/INFRA pre-state")
    _normal_sha(expected_state.get("payload_sha256"), "target.expected_state.payload_sha256")

    fix = contract.get("parser_fix")
    if not isinstance(fix, Mapping):
        raise RequalError("parser_fix object missing")
    if (
        fix.get("defect_class") != "STRATEGY_LINES_WITHOUT_SECTION_MARKER"
        or _normal_commit(fix.get("commit_sha"), "parser_fix.commit_sha") != PARSER_FIX_COMMIT
    ):
        raise RequalError("parser fix identity mismatch")
    _normal_sha(fix.get("file_sha256_at_fix_commit"), "parser fix file digest")

    raw_artifacts = contract.get("artifact_bindings")
    if not isinstance(raw_artifacts, list):
        raise RequalError("artifact_bindings must be a list")
    artifacts: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(raw_artifacts):
        if not isinstance(raw, Mapping):
            raise RequalError(f"artifact_bindings[{index}] must be an object")
        role = str(raw.get("role") or "").strip()
        if not role or role in artifacts:
            raise RequalError(f"duplicate/empty artifact role: {role}")
        path = Path(str(raw.get("path") or "")).resolve()
        expected_sha = _normal_sha(raw.get("sha256"), f"artifact {role} sha256")
        basis = str(raw.get("sha256_basis") or "")
        if not path.is_file():
            raise RequalError(f"artifact missing: {role}: {path}")
        actual_sha, actual_bytes = artifact_identity(path, basis)
        if actual_sha != expected_sha:
            raise RequalError(f"artifact digest mismatch: {role}: {path}")
        expected_bytes = raw.get("bytes")
        if isinstance(expected_bytes, bool) or not isinstance(expected_bytes, int):
            raise RequalError(f"artifact byte count missing: {role}")
        if actual_bytes != expected_bytes:
            raise RequalError(f"artifact byte count mismatch: {role}")
        artifacts[role] = {
            "role": role,
            "path": str(path),
            "sha256": actual_sha,
            "sha256_basis": basis,
            "bytes": expected_bytes,
        }
    if set(artifacts) != set(REQUIRED_ARTIFACT_ROLES):
        raise RequalError(
            f"artifact roles must be exact: expected={sorted(REQUIRED_ARTIFACT_ROLES)} "
            f"actual={sorted(artifacts)}"
        )
    for role, artifact in artifacts.items():
        expected_basis = (
            "UTF8_TEXT_LF_NORMALIZED"
            if role in {"controller_source", "parser_source"}
            else "RAW_BYTES"
        )
        if artifact["sha256_basis"] != expected_basis:
            raise RequalError(f"artifact hash basis mismatch: {role}")
    for role, expected_sha in TARGET_SETFILE_SHA256.items():
        if artifacts[role]["sha256"] != expected_sha:
            raise RequalError(f"setfile bytes changed from OWNER-approved vintage: {role}")
    if not _same_path(Path(artifacts["controller_source"]["path"]), Path(__file__)):
        raise RequalError("controller_source binding does not name this controller")
    if not _same_path(
        Path(str(target.get("setfile_path") or "")),
        Path(artifacts["setfile_ablation_00"]["path"]),
    ):
        raise RequalError("target row setfile must be the bound ablation-00 vintage")

    archive = contract.get("evidence_archive")
    if not isinstance(archive, Mapping):
        raise RequalError("evidence_archive contract missing")
    if (
        archive.get("policy") != "MOVE_WHOLE_WORK_ITEM_ROOT_NO_DELETE_NO_OVERWRITE"
        or not _same_path(Path(str(archive.get("root") or "")), paths.archive_root)
    ):
        raise RequalError("evidence archive policy/root mismatch")

    review = contract.get("implementation_review")
    if not isinstance(review, Mapping) or review.get("status") not in {"PENDING", "APPROVED"}:
        raise RequalError("implementation_review must be PENDING or APPROVED")
    if review.get("status") == "APPROVED":
        if review.get("reviewer") != "Claude" or review.get("verdict") != "APPROVED":
            raise RequalError("implementation review approval identity mismatch")
        _normal_commit(review.get("reviewed_controller_commit"), "reviewed controller commit")
        receipt = review.get("receipt")
        if not isinstance(receipt, Mapping):
            raise RequalError("implementation review receipt binding missing")
        receipt_path = Path(str(receipt.get("path") or "")).resolve()
        receipt_sha = _normal_sha(receipt.get("sha256"), "review receipt sha256")
        if not receipt_path.is_file() or sha256_file(receipt_path) != receipt_sha:
            raise RequalError("implementation review receipt missing or changed")
    return artifacts


def _load_parser(parser_path: Path) -> Callable[[Path], Mapping[str, Any]]:
    module_name = f"_qm_q08_parser_{uuid.uuid4().hex}"
    spec = importlib.util.spec_from_file_location(module_name, parser_path)
    if spec is None or spec.loader is None:
        raise RequalError(f"cannot load parser module: {parser_path}")
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except BaseException as exc:
        raise RequalError(f"parser module import failed: {exc}") from exc
    function = getattr(module, "parse_setfile_assignments", None)
    if not callable(function):
        raise RequalError("parse_setfile_assignments is missing")
    return function


def parser_gate(
    artifacts: Mapping[str, Mapping[str, Any]],
    *,
    parser_loader: Callable[[Path], Callable[[Path], Mapping[str, Any]]] = _load_parser,
) -> dict[str, Any]:
    rows = []
    parser = parser_loader(Path(str(artifacts["parser_source"]["path"])))
    for role in SETFILE_ROLES:
        path = Path(str(artifacts[role]["path"]))
        try:
            assignments = parser(path)
            count = len(assignments)
            error = None if count > 0 else "parse_setfile_assignments returned zero assignments"
        except BaseException as exc:
            count = 0
            error = f"{type(exc).__name__}: {exc}"
        rows.append(
            {
                "role": role,
                "path": str(path),
                "sha256": artifacts[role]["sha256"],
                "assignment_count": count,
                "error": error,
            }
        )
    blockers = [f"{row['role']}: {row['error']}" for row in rows if row["error"]]
    return {"status": "PASS" if not blockers else "BLOCKED", "setfiles": rows, "blockers": blockers}


def _fetch_target(conn: sqlite3.Connection) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM work_items WHERE id=?", (AUTHORIZED_TARGET["work_item_id"],)
    ).fetchone()


def _state(row: sqlite3.Row) -> dict[str, Any]:
    return {field: row[field] for field in STATE_FIELDS}


def _state_matches(row: sqlite3.Row, expected: Mapping[str, Any]) -> bool:
    return all(row[field] == expected.get(field) for field in STATE_FIELDS)


def _row_gate(row: sqlite3.Row | None, contract: Mapping[str, Any]) -> dict[str, Any]:
    if row is None:
        return {"status": "BLOCKED", "mismatches": ["target row missing"], "row": None}
    target = contract["target"]
    expected = target["expected_state"]
    actual_payload_sha = payload_sha256(row["payload_json"])
    checks = {
        "id": (row["id"], AUTHORIZED_TARGET["work_item_id"]),
        "ea_id": (row["ea_id"], AUTHORIZED_TARGET["ea_id"]),
        "symbol": (row["symbol"], AUTHORIZED_TARGET["symbol"]),
        "phase": (row["phase"], expected["phase"]),
        "status": (row["status"], expected["status"]),
        "verdict": (row["verdict"], expected["verdict"]),
        "payload_sha256": (actual_payload_sha, str(expected["payload_sha256"]).lower()),
        "setfile_path": (str(Path(row["setfile_path"]).resolve()), str(Path(target["setfile_path"]).resolve())),
    }
    mismatches = [f"{key}: actual={actual!r} expected={wanted!r}" for key, (actual, wanted) in checks.items() if actual != wanted]
    return {
        "status": "PASS" if not mismatches else "BLOCKED",
        "mismatches": mismatches,
        "row": {
            "id": row["id"],
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "phase": row["phase"],
            "status": row["status"],
            "verdict": row["verdict"],
            "setfile_path": row["setfile_path"],
            "evidence_path": row["evidence_path"],
            "payload_sha256": actual_payload_sha,
            "state": _state(row),
        },
    }


def _archive_gate(row: sqlite3.Row | None, paths: RuntimePaths, contract_sha256: str) -> dict[str, Any]:
    if row is None:
        return {"status": "BLOCKED", "blockers": ["target row missing"]}
    source = (paths.reports_root / str(row["id"])).resolve()
    destination = (
        paths.archive_root / str(row["id"]) / f"exception_{contract_sha256[:16]}"
    ).resolve()
    blockers: list[str] = []
    if not _is_within(source, paths.reports_root) or not _is_within(destination, paths.archive_root):
        blockers.append("archive path escapes configured roots")
    if not source.is_dir():
        blockers.append(f"source report root missing: {source}")
    if destination.exists():
        blockers.append(f"archive destination already exists: {destination}")
    evidence_path = Path(str(row["evidence_path"] or "")).resolve()
    if not evidence_path.is_file() or not _is_within(evidence_path, source):
        blockers.append(f"old INVALID aggregate missing/outside report root: {evidence_path}")
    evidence = None
    if evidence_path.is_file() and _is_within(evidence_path, source):
        evidence = {
            "path": str(evidence_path),
            "sha256": sha256_file(evidence_path),
            "bytes": evidence_path.stat().st_size,
        }
    return {
        "status": "PASS" if not blockers else "BLOCKED",
        "source": str(source),
        "destination": str(destination),
        "old_invalid_aggregate": evidence,
        "policy": "MOVE_WHOLE_WORK_ITEM_ROOT_NO_DELETE_NO_OVERWRITE",
        "blockers": blockers,
    }


def _window_gate(conn: sqlite3.Connection, paths: RuntimePaths) -> dict[str, Any]:
    active = int(conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0])
    if paths.factory_off_flag.is_file():
        flag = {
            "path": str(paths.factory_off_flag.resolve()),
            "sha256": sha256_file(paths.factory_off_flag),
            "bytes": paths.factory_off_flag.stat().st_size,
        }
    else:
        flag = None
    blockers = []
    if flag is None:
        blockers.append("FACTORY_OFF flag missing")
    if active != 0:
        blockers.append(f"active work-item count is {active}, expected 0")
    return {
        "status": "PASS" if not blockers else "BLOCKED",
        "factory_off": flag,
        "active_work_items": active,
        "blockers": blockers,
    }


def build_plan(
    contract: Mapping[str, Any],
    contract_path: Path,
    contract_sha256: str,
    paths: RuntimePaths,
    *,
    conn: sqlite3.Connection | None = None,
    git_verifier: Callable[
        [Mapping[str, Any], RuntimePaths, Mapping[str, Mapping[str, Any]]], dict[str, Any]
    ] = verify_git_provenance,
    parser_loader: Callable[[Path], Callable[[Path], Mapping[str, Any]]] = _load_parser,
) -> dict[str, Any]:
    artifacts = validate_contract(contract, paths)
    git_gate: dict[str, Any]
    try:
        git_gate = {"status": "PASS", **git_verifier(contract, paths, artifacts), "blockers": []}
    except RequalError as exc:
        git_gate = {"status": "BLOCKED", "blockers": [str(exc)]}
    parse_gate = parser_gate(artifacts, parser_loader=parser_loader)

    owned = conn is None
    connection = conn or connect_ro(paths.db)
    try:
        row = _fetch_target(connection)
        row_check = _row_gate(row, contract)
        archive = _archive_gate(row, paths, contract_sha256)
        window = _window_gate(connection, paths)
    finally:
        if owned:
            connection.close()

    review = contract["implementation_review"]
    review_blockers = [] if review.get("status") == "APPROVED" else [
        "Claude implementation review is not APPROVED in the exception contract"
    ]
    review_gate = {
        "status": "PASS" if not review_blockers else "BLOCKED",
        "review": copy.deepcopy(dict(review)),
        "blockers": review_blockers,
    }
    gates = {
        "git_provenance": git_gate,
        "artifact_bindings": {"status": "PASS", "artifacts": list(artifacts.values()), "blockers": []},
        "parser_all_four_setfiles": parse_gate,
        "row_cas": row_check,
        "archive_required": archive,
        "implementation_review": review_gate,
        "apply_window": window,
    }
    blockers = [
        f"{name}: {blocker}"
        for name, gate in gates.items()
        if gate.get("status") != "PASS"
        for blocker in (gate.get("blockers") or gate.get("mismatches") or ["gate blocked"])
    ]
    return {
        "schema_version": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "mode": "DRY_RUN",
        "status": "READY_FOR_APPLY" if not blockers else "BLOCKED",
        "global_invariant": {
            "name": GLOBAL_INVARIANT,
            "weakened": False,
            "global_recovery_tool_modified": False,
        },
        "exception_contract": {
            "path": str(contract_path.resolve()),
            "sha256": contract_sha256,
        },
        "target": copy.deepcopy(AUTHORIZED_TARGET),
        "gates": gates,
        "blockers": blockers,
        "mutation_performed": False,
    }


def _new_payload(
    row: sqlite3.Row,
    plan: Mapping[str, Any],
    contract: Mapping[str, Any],
    now: str,
) -> str:
    try:
        payload = json.loads(row["payload_json"])
    except (TypeError, json.JSONDecodeError) as exc:
        raise RequalError(f"current payload_json cannot be preserved: {exc}") from exc
    if not isinstance(payload, dict):
        raise RequalError("current payload_json root is not an object")
    for key in STALE_RUNTIME_KEYS:
        payload.pop(key, None)
    artifact_rows = plan["gates"]["artifact_bindings"]["artifacts"]
    archive = plan["gates"]["archive_required"]
    payload["q08_single_target_requalification"] = {
        "schema_version": "qm.q08-single-target-requal-payload/v1",
        "applied_at_utc": now,
        "owner_reference": OWNER_REFERENCE,
        "reason_class": REASON_CLASS,
        "global_invariant": GLOBAL_INVARIANT,
        "exception_contract": copy.deepcopy(plan["exception_contract"]),
        "parser_fix_commit": PARSER_FIX_COMMIT,
        "controller_head_commit": plan["gates"]["git_provenance"].get("head_commit"),
        "prior_payload_sha256": payload_sha256(row["payload_json"]),
        "archived_report_root": archive["destination"],
        "artifact_bindings": copy.deepcopy(artifact_rows),
        "setfile_bytes_unchanged": True,
        "pipeline_verdict_inferred": False,
    }
    payload["requeued_by"] = "q08_single_target_requal"
    payload["requeued_at_utc"] = now
    payload["requeue_reason"] = "owner_authorized_q08_parser_defect_requalification"
    payload["requeue_prior_verdict"] = row["verdict"]
    payload["requeue_prior_verdict_reason"] = payload.get("verdict_reason")
    payload["archived_report_root_on_requeue"] = archive["destination"]
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _cas_update_to_post(
    conn: sqlite3.Connection, row: sqlite3.Row, post: Mapping[str, Any]
) -> None:
    cursor = conn.execute(
        "UPDATE work_items SET status=?, verdict=?, attempt_count=?, evidence_path=?, "
        "claimed_by=?, payload_json=?, updated_at=? "
        "WHERE id=? AND phase IS ? AND status IS ? AND verdict IS ? AND payload_json IS ? "
        "AND updated_at IS ?",
        (
            *(post[field] for field in STATE_FIELDS),
            row["id"],
            row["phase"],
            row["status"],
            row["verdict"],
            row["payload_json"],
            row["updated_at"],
        ),
    )
    if cursor.rowcount != 1:
        raise RequalError(f"exact target CAS affected {cursor.rowcount} rows, expected 1")


def _cas_restore_pre(
    conn: sqlite3.Connection,
    work_item_id: str,
    phase: str,
    pre: Mapping[str, Any],
    post: Mapping[str, Any],
) -> None:
    cursor = conn.execute(
        "UPDATE work_items SET status=?, verdict=?, attempt_count=?, evidence_path=?, "
        "claimed_by=?, payload_json=?, updated_at=? "
        "WHERE id=? AND phase IS ? AND status IS ? AND verdict IS ? AND attempt_count IS ? "
        "AND evidence_path IS ? AND claimed_by IS ? AND payload_json IS ? AND updated_at IS ?",
        (
            *(pre[field] for field in STATE_FIELDS),
            work_item_id,
            phase,
            *(post[field] for field in STATE_FIELDS),
        ),
    )
    if cursor.rowcount != 1:
        raise RequalError(f"guarded revert CAS affected {cursor.rowcount} rows, expected 1")


def _insert_event(
    conn: sqlite3.Connection, work_item_id: str, event: str, detail: Mapping[str, Any], now: str
) -> int:
    cursor = conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
        (now, "work_item", work_item_id, event, json.dumps(detail, sort_keys=True)),
    )
    if cursor.rowcount != 1:
        raise RequalError("farm event insert did not affect exactly one row")
    return int(cursor.lastrowid)


def apply_contract(
    contract: Mapping[str, Any],
    contract_path: Path,
    contract_sha256: str,
    expected_contract_sha256: str,
    expected_factory_off_sha256: str,
    journal_path: Path,
    paths: RuntimePaths,
    *,
    git_verifier: Callable[
        [Mapping[str, Any], RuntimePaths, Mapping[str, Mapping[str, Any]]], dict[str, Any]
    ] = verify_git_provenance,
    parser_loader: Callable[[Path], Callable[[Path], Mapping[str, Any]]] = _load_parser,
) -> dict[str, Any]:
    if contract_sha256 != _normal_sha(expected_contract_sha256, "expected contract SHA-256"):
        raise RequalError("exception contract SHA-256 mismatch")
    expected_flag = _normal_sha(expected_factory_off_sha256, "expected FACTORY_OFF SHA-256")
    journal_path = journal_path.resolve(strict=False)
    if journal_path.exists():
        raise RequalError(f"journal already exists: {journal_path}")

    with FactoryMutationLock(paths.lock_path, owner="q08_single_target_requal.apply"):
        if not paths.factory_off_flag.is_file():
            raise RequalError(f"FACTORY_OFF flag missing: {paths.factory_off_flag}")
        actual_flag = sha256_file(paths.factory_off_flag)
        if actual_flag != expected_flag:
            raise RequalError(
                f"FACTORY_OFF SHA-256 mismatch: expected={expected_flag} actual={actual_flag}"
            )
        conn = connect_rw(paths.db)
        moved = False
        source: Path | None = None
        destination: Path | None = None
        try:
            conn.execute("BEGIN IMMEDIATE")
            plan = build_plan(
                contract,
                contract_path,
                contract_sha256,
                paths,
                conn=conn,
                git_verifier=git_verifier,
                parser_loader=parser_loader,
            )
            if plan["status"] != "READY_FOR_APPLY":
                raise RequalError("apply gates blocked: " + "; ".join(plan["blockers"]))
            current_flag = sha256_file(paths.factory_off_flag)
            if current_flag != expected_flag:
                raise RequalError("FACTORY_OFF flag changed inside mutation boundary")
            if int(conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]):
                raise RequalError("active work item appeared inside apply transaction")

            row = _fetch_target(conn)
            assert row is not None
            pre = _state(row)
            now = utc_now()
            new_payload = _new_payload(row, plan, contract, now)
            post = {
                "status": "pending",
                "verdict": None,
                "attempt_count": 0,
                "evidence_path": None,
                "claimed_by": None,
                "payload_json": new_payload,
                "updated_at": now,
            }
            archive = plan["gates"]["archive_required"]
            source = Path(archive["source"])
            destination = Path(archive["destination"])
            if _is_within(journal_path, source) or _is_within(journal_path, destination):
                raise RequalError("journal path may not be inside source/archive report roots")
            journal: dict[str, Any] = {
                "schema_version": JOURNAL_SCHEMA,
                "state": "planned",
                "planned_at_utc": now,
                "exception_contract": copy.deepcopy(plan["exception_contract"]),
                "factory_off_receipt": {
                    "path": str(paths.factory_off_flag.resolve()),
                    "sha256": current_flag,
                    "active_work_items": 0,
                },
                "target": copy.deepcopy(AUTHORIZED_TARGET),
                "archive": copy.deepcopy(archive),
                "pre_apply": pre,
                "post_apply": post,
                "event": None,
            }
            write_json_atomic(journal_path, journal, require_absent=True)

            destination.parent.mkdir(parents=True, exist_ok=True)
            source.rename(destination)
            moved = True
            _cas_update_to_post(conn, row, post)
            event_id = _insert_event(
                conn,
                row["id"],
                "q08_single_target_requalification_applied",
                {
                    "owner_reference": OWNER_REFERENCE,
                    "contract_sha256": contract_sha256,
                    "archive_destination": str(destination),
                    "prior_payload_sha256": payload_sha256(pre["payload_json"]),
                    "post_payload_sha256": payload_sha256(post["payload_json"]),
                    "pipeline_verdict_inferred": False,
                },
                now,
            )
            conn.commit()
        except BaseException:
            conn.rollback()
            if moved and source is not None and destination is not None:
                try:
                    destination.rename(source)
                except OSError as exc:
                    raise RequalError(
                        f"apply failed and archive compensation also failed: {destination} -> {source}: {exc}"
                    ) from exc
            raise
        finally:
            conn.close()

        journal["state"] = "committed"
        journal["committed_at_utc"] = now
        journal["event"] = {"id": event_id, "event": "q08_single_target_requalification_applied"}
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "APPLIED",
            "work_item_id": AUTHORIZED_TARGET["work_item_id"],
            "journal_path": str(journal_path),
            "journal_sha256": final_sha,
            "archive_destination": str(destination),
            "event_id": event_id,
            "pipeline_verdict_inferred": False,
        }


def revert_journal(
    journal_path: Path,
    expected_journal_sha256: str,
    expected_factory_off_sha256: str,
    paths: RuntimePaths,
) -> dict[str, Any]:
    expected_journal = _normal_sha(expected_journal_sha256, "expected journal SHA-256")
    if sha256_file(journal_path) != expected_journal:
        raise RequalError("journal SHA-256 mismatch")
    journal, _digest = load_json_strict(journal_path, "revert journal")
    if journal.get("schema_version") != JOURNAL_SCHEMA:
        raise RequalError("revert journal schema mismatch")
    if journal.get("state") not in {"planned", "committed"}:
        raise RequalError(f"journal state is not revertible: {journal.get('state')}")
    if journal.get("target") != AUTHORIZED_TARGET:
        raise RequalError("journal target is outside OWNER authorization")
    expected_flag = _normal_sha(expected_factory_off_sha256, "expected FACTORY_OFF SHA-256")
    pre = journal.get("pre_apply")
    post = journal.get("post_apply")
    archive = journal.get("archive")
    if not all(isinstance(value, Mapping) for value in (pre, post, archive)):
        raise RequalError("journal pre/post/archive sections missing")
    source = Path(str(archive["source"])).resolve()
    destination = Path(str(archive["destination"])).resolve()
    if not _is_within(source, paths.reports_root) or not _is_within(destination, paths.archive_root):
        raise RequalError("journal archive paths escape configured roots")

    with FactoryMutationLock(paths.lock_path, owner="q08_single_target_requal.revert"):
        if not paths.factory_off_flag.is_file():
            raise RequalError(f"FACTORY_OFF flag missing: {paths.factory_off_flag}")
        if sha256_file(paths.factory_off_flag) != expected_flag:
            raise RequalError("FACTORY_OFF SHA-256 mismatch during revert")
        conn = connect_rw(paths.db)
        moved_back = False
        db_restored = False
        try:
            conn.execute("BEGIN IMMEDIATE")
            active = int(conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0])
            if active != 0:
                raise RequalError(f"revert requires zero active work items; found {active}")
            row = _fetch_target(conn)
            if row is None:
                raise RequalError("revert target row missing")
            row_is_post = _state_matches(row, post)
            row_is_pre = _state_matches(row, pre)
            if not row_is_post and not row_is_pre:
                raise RequalError("guarded revert refused: row drifted from journal pre/post states")
            if source.exists() and destination.exists():
                raise RequalError("guarded revert refused: source and archive both exist")
            if not source.exists():
                if not destination.is_dir():
                    raise RequalError("guarded revert refused: archived report root is missing")
                source.parent.mkdir(parents=True, exist_ok=True)
                destination.rename(source)
                moved_back = True
            if row_is_post:
                _cas_restore_pre(conn, row["id"], row["phase"], pre, post)
                db_restored = True
            now = utc_now()
            event_id = _insert_event(
                conn,
                row["id"],
                "q08_single_target_requalification_reverted",
                {
                    "journal_sha256": expected_journal,
                    "row_was_post_apply": row_is_post,
                    "archive_restored": moved_back,
                },
                now,
            )
            conn.commit()
        except BaseException:
            conn.rollback()
            if moved_back:
                try:
                    source.rename(destination)
                except OSError as exc:
                    raise RequalError(
                        f"revert failed and archive compensation also failed: {source} -> {destination}: {exc}"
                    ) from exc
            raise
        finally:
            conn.close()

        journal["state"] = "reverted"
        journal["reverted_at_utc"] = now
        journal["revert"] = {
            "event_id": event_id,
            "db_row_restored": db_restored,
            "archive_restored": moved_back,
        }
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "REVERTED",
            "work_item_id": AUTHORIZED_TARGET["work_item_id"],
            "journal_path": str(journal_path.resolve()),
            "journal_sha256": final_sha,
            "event_id": event_id,
            "db_row_restored": db_restored,
            "archive_restored": moved_back,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--exception-contract", type=Path)
    parser.add_argument("--expected-contract-sha256")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--reports-root", type=Path, default=DEFAULT_REPORTS)
    parser.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    parser.add_argument("--mutation-lock", type=Path)
    parser.add_argument("--plan-out", type=Path, help="optional durable dry-run plan; never DB state")
    parser.add_argument("--apply", action="store_true", help="mutate exact row; dry-run is default")
    parser.add_argument("--journal-out", type=Path, help="required new journal path for --apply")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--revert", type=Path, help="guarded revert of an applied journal")
    parser.add_argument("--expected-journal-sha256")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    paths = RuntimePaths(
        db=args.db,
        repo=args.repo,
        reports_root=args.reports_root,
        archive_root=args.archive_root,
        factory_off_flag=args.factory_off_flag,
        mutation_lock=args.mutation_lock,
    )
    try:
        if args.revert is not None:
            if args.apply or args.exception_contract or args.plan_out or args.journal_out:
                raise RequalError("--revert is standalone and cannot be combined with plan/apply")
            if not args.expected_journal_sha256 or not args.expected_factory_off_sha256:
                raise RequalError(
                    "--revert requires --expected-journal-sha256 and --expected-factory-off-sha256"
                )
            result = revert_journal(
                args.revert,
                args.expected_journal_sha256,
                args.expected_factory_off_sha256,
                paths,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        if args.exception_contract is None:
            raise RequalError("--exception-contract is required")
        contract, contract_sha = load_json_strict(args.exception_contract, "exception contract")
        if args.expected_contract_sha256 and contract_sha != _normal_sha(
            args.expected_contract_sha256, "expected contract SHA-256"
        ):
            raise RequalError("exception contract SHA-256 mismatch")

        if args.apply:
            if args.plan_out:
                raise RequalError("--plan-out is dry-run only; --apply requires --journal-out")
            if not args.journal_out or not args.expected_contract_sha256:
                raise RequalError(
                    "--apply requires --journal-out and --expected-contract-sha256"
                )
            if not args.expected_factory_off_sha256:
                raise RequalError("--apply requires --expected-factory-off-sha256")
            result = apply_contract(
                contract,
                args.exception_contract,
                contract_sha,
                args.expected_contract_sha256,
                args.expected_factory_off_sha256,
                args.journal_out,
                paths,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        if args.journal_out or args.expected_journal_sha256:
            raise RequalError("journal arguments are not valid in dry-run mode")
        plan = build_plan(contract, args.exception_contract, contract_sha, paths)
        if args.plan_out:
            plan_sha = write_json_atomic(args.plan_out, plan, require_absent=True)
            plan["plan_artifact"] = {
                "path": str(args.plan_out.resolve()),
                "sha256": plan_sha,
            }
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0 if plan["status"] == "READY_FOR_APPLY" else 1
    except (RequalError, OSError, sqlite3.Error, KeyError, TypeError, ValueError) as exc:
        print(f"q08 single-target requalification refused: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
