"""Deterministic, read-only MNT-043/MNT-044 closure and evidence drift scanner.

The scanner opens the farm database with ``mode=ro`` and ``query_only=ON``.  It
never updates ``work_items`` (or any other runtime table), never compiles, never
launches MT5, and never touches Factory/T_Live.  Its two optional persistence
operations are deliberately outside the runtime database:

* a scan report is written create-only (an existing path is refused);
* re-adjudication events are appended to a hash-chained JSONL overlay.

Raw pipeline verdicts remain historical facts.  The overlay supplies the
effective admission status without laundering missing, stale, or unauthenticated
evidence into a PASS.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


REPORT_SCHEMA = "qm/mnt-closure-drift-report/v1"
OVERLAY_SCHEMA = "qm/mnt-adjudication-overlay-event/v1"
TOOL_ID = "mnt_closure_drift/v1"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_RUNTIME_LIVE_POINTER = Path(r"D:\QM\reports\state\live_deployment_pointer.json")
DEFAULT_PHASES = ("Q06", "Q07")

PASS_VERDICTS = frozenset({"PASS", "PASS_PORTFOLIO"})
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
EA_ID_RE = re.compile(r"QM5_(\d+)", re.IGNORECASE)
INCLUDE_RE = re.compile(r'^\s*#include\s*[<"]([^>"]+)[>"]', re.MULTILINE)
Q07_SET_SEED_RE = re.compile(
    r"_q06_stress_harsh_seed(?P<seed>\d+)\.set\b", re.IGNORECASE
)
PLATFORM_INCLUDE_PREFIXES = (
    "arrays/",
    "canvas/",
    "controls/",
    "expert/",
    "files/",
    "graphics/",
    "indicators/",
    "math/",
    "trade/",
)

REASON_ORDER = (
    "MISSING_FILE",
    "UNREADABLE",
    "PARSE_ERROR_BACKFILL",
    "EVIDENCE_SCOPE_MISMATCH",
    "EVIDENCE_VERDICT_MISMATCH",
    "NULL_KPI",
    "ZERO_VARIANCE",
    "SEED_AUTH_MISSING",
    "IDENTITY_HASH_MISSING",
    "BINARY_VINTAGE_MISMATCH",
    "SOURCE_CLOSURE_UNRESOLVED",
    "SOURCE_CLOSURE_DRIFT",
)
REASON_RANK = {name: index for index, name in enumerate(REASON_ORDER)}


class ScanError(RuntimeError):
    """A structural or provenance error which must fail closed."""


@dataclass
class Subject:
    ea_id: str
    symbol: str
    memberships: list[dict[str, Any]] = field(default_factory=list)
    artifact_hints: list[dict[str, Any]] = field(default_factory=list)
    recorded_identities: list[dict[str, Any]] = field(default_factory=list)

    @property
    def key(self) -> tuple[str, str]:
        return self.ea_id, self.symbol


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value.lower()) is not None


def load_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ScanError(f"unreadable JSON object: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ScanError(f"JSON root is not an object: {path}")
    return value


def try_json_object(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        return load_json_object(path), None
    except ScanError as exc:
        return None, str(exc)


def parse_json_object(raw: Any) -> dict[str, Any]:
    if isinstance(raw, dict):
        return dict(raw)
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def normalize_ea_id(value: Any) -> str:
    match = EA_ID_RE.search(str(value or ""))
    if match:
        return f"QM5_{int(match.group(1))}"
    text = str(value or "").strip()
    if text.isdigit():
        return f"QM5_{int(text)}"
    raise ScanError(f"cannot normalize EA id: {value!r}")


def normalize_symbol(value: Any) -> str:
    symbol = str(value or "").strip()
    if not symbol:
        raise ScanError("symbol is empty")
    return symbol.upper()


def path_key(path: Path) -> str:
    return str(path).replace("/", "\\").rstrip("\\").casefold()


def normalize_path(value: Any, *, base: Path | None = None) -> Path | None:
    text = str(value or "").strip()
    if not text:
        return None
    path = Path(text)
    if not path.is_absolute() and base is not None:
        path = base / path
    return path


def open_db_read_only(path: Path) -> sqlite3.Connection:
    resolved = path.resolve(strict=True)
    uri = f"file:{resolved.as_posix()}?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=30)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only=ON")
    connection.execute("PRAGMA busy_timeout=30000")
    if int(connection.execute("PRAGMA query_only").fetchone()[0]) != 1:
        connection.close()
        raise ScanError("SQLite query_only could not be enabled")
    connection.execute("BEGIN")
    return connection


def table_exists(connection: sqlite3.Connection, table: str) -> bool:
    row = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    return row is not None


def work_item_snapshot(row: Mapping[str, Any]) -> dict[str, Any]:
    keys = (
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
        "payload_json",
        "created_at",
        "updated_at",
    )
    return {key: row[key] if key in row.keys() else None for key in keys}


def subject_for(
    subjects: dict[tuple[str, str], Subject], ea_id: Any, symbol: Any
) -> Subject:
    normalized = (normalize_ea_id(ea_id), normalize_symbol(symbol))
    subject = subjects.get(normalized)
    if subject is None:
        subject = Subject(*normalized)
        subjects[normalized] = subject
    return subject


def identity_fields(value: Mapping[str, Any]) -> dict[str, Any]:
    aliases = {
        "mq5_sha256": ("expected_mq5_sha256", "mq5_sha256", "ea_sha256"),
        "ex5_sha256": (
            "expected_ex5_sha256",
            "ex5_sha256",
            "binary_sha256",
            "binary_sha",
        ),
        "setfile_sha256": (
            "expected_setfile_sha256",
            "setfile_sha256",
            "set_sha256",
        ),
        "evidence_sha256": ("evidence_sha256", "aggregate_sha256"),
        "source_closure_sha256": (
            "source_closure_sha256",
            "source_closure_manifest_sha256",
            "closure_sha256",
        ),
        "input_sha256": ("input_sha256", "inputs_sha256"),
    }
    result: dict[str, Any] = {}
    for output, names in aliases.items():
        for name in names:
            candidate = value.get(name)
            if valid_sha256(candidate):
                result[output] = str(candidate).lower()
                break
    return result


def trace_work_item_lineage(
    connection: sqlite3.Connection, start_id: Any, *, limit: int = 32
) -> dict[str, Any]:
    current = str(start_id or "").strip()
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    issue = None
    while current and len(rows) < limit:
        if current in seen:
            issue = "LINEAGE_CYCLE"
            break
        seen.add(current)
        row = connection.execute(
            "SELECT id, phase, status, verdict, payload_json FROM work_items WHERE id=?",
            (current,),
        ).fetchone()
        if row is None:
            issue = "LINEAGE_PARENT_MISSING"
            break
        rows.append(
            {
                "work_item_id": row["id"],
                "phase": row["phase"],
                "status": row["status"],
                "verdict": row["verdict"],
            }
        )
        payload = parse_json_object(row["payload_json"])
        current = str(payload.get("promoted_from_work_item") or "").strip()
    if current and len(rows) >= limit:
        issue = "LINEAGE_DEPTH_EXCEEDED"
    return {"rows": rows, "issue": issue}


def add_db_cohorts(
    connection: sqlite3.Connection, subjects: dict[tuple[str, str], Subject]
) -> None:
    if table_exists(connection, "portfolio_candidates"):
        rows = connection.execute(
            """
            SELECT pc.ea_id, pc.symbol, pc.q11_work_item_id, pc.state,
                   pc.evidence_path AS candidate_evidence_path,
                   w.phase AS source_phase, w.setfile_path, w.evidence_path,
                   w.payload_json
            FROM portfolio_candidates pc
            LEFT JOIN work_items w ON w.id=pc.q11_work_item_id
            ORDER BY pc.ea_id, pc.symbol, pc.q11_work_item_id
            """
        ).fetchall()
        for row in rows:
            subject = subject_for(subjects, row["ea_id"], row["symbol"])
            payload = parse_json_object(row["payload_json"])
            subject.memberships.append(
                {
                    "kind": "portfolio_candidate",
                    "source_id": row["q11_work_item_id"],
                    "state": row["state"],
                    "source_phase": row["source_phase"],
                    "lineage": trace_work_item_lineage(
                        connection, row["q11_work_item_id"]
                    ),
                }
            )
            subject.recorded_identities.append(
                {
                    "source": f"work_item:{row['q11_work_item_id']}",
                    **identity_fields(payload),
                }
            )
            for role, raw_path, expected in (
                ("setfile", row["setfile_path"], payload.get("expected_setfile_sha256")),
                ("evidence", row["evidence_path"], payload.get("evidence_sha256")),
                (
                    "candidate_evidence",
                    row["candidate_evidence_path"],
                    payload.get("evidence_sha256"),
                ),
            ):
                if raw_path:
                    subject.artifact_hints.append(
                        {
                            "role": role,
                            "path": str(raw_path),
                            "expected_sha256": str(expected).lower()
                            if valid_sha256(expected)
                            else None,
                            "source": f"portfolio_candidate:{row['q11_work_item_id']}",
                        }
                    )

    rows = connection.execute(
        """
        SELECT id, ea_id, symbol, setfile_path, evidence_path, payload_json
        FROM work_items
        WHERE phase='Q10' AND status='done' AND verdict='PASS'
        ORDER BY ea_id, symbol, id
        """
    ).fetchall()
    for row in rows:
        subject = subject_for(subjects, row["ea_id"], row["symbol"])
        payload = parse_json_object(row["payload_json"])
        subject.memberships.append(
            {
                "kind": "q10_candidate",
                "source_id": row["id"],
                "state": "PASS",
                "lineage": trace_work_item_lineage(connection, row["id"]),
            }
        )
        subject.recorded_identities.append(
            {"source": f"work_item:{row['id']}", **identity_fields(payload)}
        )
        for role, raw_path, expected in (
            ("setfile", row["setfile_path"], payload.get("expected_setfile_sha256")),
            ("evidence", row["evidence_path"], payload.get("evidence_sha256")),
        ):
            if raw_path:
                subject.artifact_hints.append(
                    {
                        "role": role,
                        "path": str(raw_path),
                        "expected_sha256": str(expected).lower()
                        if valid_sha256(expected)
                        else None,
                        "source": f"q10:{row['id']}",
                    }
                )


def manifest_sleeves(payload: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    for key in ("sleeves", "accounts", "candidates"):
        rows = payload.get(key)
        if isinstance(rows, list):
            return [row for row in rows if isinstance(row, Mapping)]
    return []


def add_manifest_cohort(
    subjects: dict[tuple[str, str], Subject],
    manifest_path: Path,
    *,
    kind: str,
    authority: str,
) -> dict[str, Any]:
    payload = load_json_object(manifest_path)
    manifest_hash = sha256_file(manifest_path)
    sleeves = manifest_sleeves(payload)
    descriptor = {
        "kind": kind,
        "path": str(manifest_path),
        "sha256": manifest_hash,
        "authority": authority,
        "declared_status": payload.get("status"),
        "declared_count": payload.get("n_sleeves", len(sleeves)),
        "parsed_count": len(sleeves),
    }
    for index, sleeve in enumerate(sleeves):
        ea_raw = sleeve.get("ea_id") or sleeve.get("ea") or sleeve.get("ea_label")
        symbol = sleeve.get("symbol") or sleeve.get("host_symbol")
        try:
            subject = subject_for(subjects, ea_raw, symbol)
        except ScanError:
            descriptor.setdefault("invalid_sleeves", []).append(index)
            continue
        source_id = f"{manifest_hash}:{index}"
        subject.memberships.append(
            {
                "kind": kind,
                "source_id": source_id,
                "state": payload.get("status"),
                "manifest_path": str(manifest_path),
                "authority": authority,
            }
        )
        subject.recorded_identities.append(
            {"source": source_id, **identity_fields(sleeve)}
        )
        hints = (
            ("mq5", sleeve.get("mq5_path"), sleeve.get("mq5_sha256")),
            (
                "ex5",
                sleeve.get("ex5_path") or sleeve.get("binary_path"),
                sleeve.get("ex5_sha256")
                or sleeve.get("binary_sha256")
                or sleeve.get("binary_sha"),
            ),
            (
                "setfile",
                sleeve.get("deployed_preset")
                or sleeve.get("setfile")
                or sleeve.get("backtest_set"),
                sleeve.get("setfile_sha256") or sleeve.get("set_sha256"),
            ),
        )
        for role, raw_path, expected in hints:
            path = normalize_path(raw_path, base=manifest_path.parent)
            if path is not None:
                subject.artifact_hints.append(
                    {
                        "role": role,
                        "path": str(path),
                        "expected_sha256": str(expected).lower()
                        if valid_sha256(expected)
                        else None,
                        "source": source_id,
                    }
                )
    return descriptor


def default_live_manifest(
    repo_root: Path, runtime_pointer: Path
) -> tuple[Path | None, str, dict[str, Any]]:
    diagnostic: dict[str, Any] = {
        "runtime_pointer": str(runtime_pointer),
        "runtime_pointer_exists": runtime_pointer.is_file(),
    }
    if runtime_pointer.is_file():
        payload, error = try_json_object(runtime_pointer)
        diagnostic["runtime_pointer_error"] = error
        if payload:
            path = normalize_path(payload.get("manifest_path"), base=runtime_pointer.parent)
            signed = payload.get("signed") is True and bool(payload.get("approved_by"))
            authenticated = payload.get("authenticated") is True or valid_sha256(
                payload.get("manifest_sha256")
            )
            if path and path.is_file():
                authority = "SIGNED_RUNTIME" if signed and authenticated else "RUNTIME_UNAUTHENTICATED"
                return path, authority, diagnostic

    config_path = repo_root / "tools" / "strategy_farm" / "config" / "live_deployment.json"
    diagnostic["fallback_config"] = str(config_path)
    if not config_path.is_file():
        return None, "MISSING", diagnostic
    payload, error = try_json_object(config_path)
    diagnostic["fallback_error"] = error
    if not payload:
        return None, "MISSING", diagnostic
    path = normalize_path(payload.get("manifest_path"), base=config_path.parent)
    if path and path.is_file():
        return path, "FALLBACK_UNAUTHENTICATED", diagnostic
    return None, "MISSING", diagnostic


def read_text_lossless(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in raw[:512]:
        encodings = ("utf-16", "utf-16-le", "utf-8-sig", "cp1252")
    else:
        encodings = ("utf-8-sig", "utf-16", "utf-16-le", "cp1252")
    for encoding in encodings:
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("unknown", raw, 0, len(raw), "no supported encoding")


def strip_mql_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def resolve_include(source: Path, token: str, repo_root: Path) -> Path | None:
    cleaned = token.strip().replace("\\", "/")
    candidates = [source.parent / cleaned]
    if cleaned.casefold().startswith("qm/"):
        candidates.append(repo_root / "framework" / "include" / cleaned)
    candidates.append(repo_root / "framework" / "include" / cleaned)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def source_closure(source: Path, repo_root: Path) -> dict[str, Any]:
    pending = [source.resolve(strict=True)]
    seen: set[str] = set()
    members: list[Path] = []
    unresolved: set[str] = set()
    external: set[str] = set()
    while pending:
        path = pending.pop()
        key = path_key(path)
        if key in seen:
            continue
        seen.add(key)
        members.append(path)
        text = strip_mql_comments(read_text_lossless(path))
        for token in INCLUDE_RE.findall(text):
            resolved = resolve_include(path, token, repo_root)
            cleaned = token.strip().replace("\\", "/")
            if resolved is not None:
                if path_key(resolved) not in seen:
                    pending.append(resolved)
            elif cleaned.casefold().startswith(PLATFORM_INCLUDE_PREFIXES):
                external.add(cleaned)
            else:
                unresolved.add(cleaned)
    rows = []
    for path in sorted(members, key=path_key):
        try:
            relative = path.relative_to(repo_root).as_posix()
        except ValueError:
            relative = str(path)
        rows.append({"path": relative, "sha256": sha256_file(path)})
    return {
        "resolver": "RECURSIVE_MQL5_INCLUDE_CLOSURE",
        "members": rows,
        "member_count": len(rows),
        "aggregate_sha256": canonical_sha256(rows),
        "external_platform_includes": sorted(external, key=str.casefold),
        "unresolved_repo_includes": sorted(unresolved, key=str.casefold),
    }


def resolve_ea_dir(repo_root: Path, ea_id: str, names: Iterable[Any]) -> tuple[Path | None, list[str]]:
    root = repo_root / "framework" / "EAs"
    candidates: dict[str, Path] = {}
    for raw in names:
        text = str(raw or "").strip()
        if text:
            candidate = root / Path(text).name
            if candidate.is_dir():
                candidates[path_key(candidate)] = candidate
    match = EA_ID_RE.search(ea_id)
    if match and root.is_dir():
        prefix = f"QM5_{int(match.group(1))}_"
        exact = root / f"QM5_{int(match.group(1))}"
        if exact.is_dir():
            candidates[path_key(exact)] = exact
        for candidate in root.glob(prefix + "*"):
            if candidate.is_dir():
                candidates[path_key(candidate)] = candidate
    ordered = sorted(candidates.values(), key=path_key)
    if len(ordered) == 1:
        return ordered[0], []
    if not ordered:
        return None, ["EA_DIRECTORY_MISSING"]
    return None, ["EA_DIRECTORY_AMBIGUOUS:" + "|".join(str(path) for path in ordered)]


def canonical_ea_files(ea_dir: Path) -> tuple[Path | None, Path | None]:
    preferred_mq5 = ea_dir / f"{ea_dir.name}.mq5"
    preferred_ex5 = ea_dir / f"{ea_dir.name}.ex5"
    mq5 = preferred_mq5 if preferred_mq5.is_file() else None
    ex5 = preferred_ex5 if preferred_ex5.is_file() else None
    if mq5 is None:
        choices = sorted(ea_dir.glob("*.mq5"), key=path_key)
        mq5 = choices[0] if len(choices) == 1 else None
    if ex5 is None:
        choices = sorted(ea_dir.glob("*.ex5"), key=path_key)
        ex5 = choices[0] if len(choices) == 1 else None
    return mq5, ex5


def parse_set_inputs(path: Path) -> dict[str, Any]:
    values: dict[str, str] = {}
    duplicates: list[str] = []
    for number, raw in enumerate(read_text_lossless(path).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if not key:
            continue
        if key in values:
            duplicates.append(f"{key}:{number}")
        values[key] = value.split("||", 1)[0].strip()
    return {
        "input_count": len(values),
        "inputs_sha256": canonical_sha256(values),
        "duplicate_keys": sorted(duplicates),
    }


def inspect_artifact_hint(hint: Mapping[str, Any]) -> dict[str, Any]:
    path = Path(str(hint.get("path") or ""))
    expected = hint.get("expected_sha256")
    result = {
        "role": hint.get("role"),
        "path": str(path),
        "source": hint.get("source"),
        "expected_sha256": expected if valid_sha256(expected) else None,
        "exists": path.is_file(),
        "observed_sha256": None,
        "status": "MISSING",
    }
    if not path.is_file():
        return result
    try:
        observed = sha256_file(path)
    except OSError:
        result["status"] = "UNREADABLE"
        return result
    result["observed_sha256"] = observed
    if valid_sha256(expected):
        result["status"] = "MATCH" if observed == str(expected).lower() else "DRIFT"
    else:
        result["status"] = "OBSERVED_UNPINNED"
    if hint.get("role") == "setfile":
        try:
            result["input_binding"] = parse_set_inputs(path)
            result["input_binding"]["status"] = (
                "BOUND_BY_SET_SHA256" if result["status"] == "MATCH" else "OBSERVED_ONLY"
            )
        except (OSError, UnicodeError):
            result["input_binding"] = {"status": "UNREADABLE"}
    return result


def inspect_subject(subject: Subject, repo_root: Path) -> dict[str, Any]:
    names = []
    for membership in subject.memberships:
        names.append(membership.get("ea_label"))
    for hint in subject.artifact_hints:
        raw = hint.get("path")
        if raw:
            parts = Path(str(raw)).parts
            names.extend(part for part in parts if EA_ID_RE.search(part))
    ea_dir, resolution_issues = resolve_ea_dir(repo_root, subject.ea_id, names)
    issues = list(resolution_issues)
    closure = None
    canonical = {"mq5": None, "ex5": None}
    expected_by_kind: dict[str, set[str]] = defaultdict(set)
    for identity in subject.recorded_identities:
        for key in ("mq5_sha256", "ex5_sha256", "source_closure_sha256"):
            if valid_sha256(identity.get(key)):
                expected_by_kind[key].add(str(identity[key]).lower())

    if ea_dir is not None:
        mq5, ex5 = canonical_ea_files(ea_dir)
        for role, path, expected_key in (
            ("mq5", mq5, "mq5_sha256"),
            ("ex5", ex5, "ex5_sha256"),
        ):
            expected_values = sorted(expected_by_kind[expected_key])
            canonical[role] = {
                "path": str(path) if path else None,
                "exists": bool(path and path.is_file()),
                "observed_sha256": sha256_file(path) if path and path.is_file() else None,
                "recorded_sha256s": expected_values,
            }
            if path is None:
                issues.append(f"{role.upper()}_MISSING")
            elif not expected_values:
                issues.append(f"{role.upper()}_HASH_UNBOUND")
            elif len(expected_values) > 1:
                issues.append(f"{role.upper()}_IDENTITY_CONFLICT")
            elif canonical[role]["observed_sha256"] != expected_values[0]:
                issues.append(f"{role.upper()}_DRIFT")
        if mq5 is not None:
            try:
                closure = source_closure(mq5, repo_root)
            except (OSError, UnicodeError) as exc:
                issues.append("SOURCE_CLOSURE_UNREADABLE")
                closure = {"error": str(exc)}
            if closure and closure.get("unresolved_repo_includes"):
                issues.append("SOURCE_CLOSURE_UNRESOLVED")
            expected_closures = sorted(expected_by_kind["source_closure_sha256"])
            if not expected_closures:
                issues.append("SOURCE_CLOSURE_HASH_UNBOUND")
            elif len(expected_closures) > 1:
                issues.append("SOURCE_CLOSURE_IDENTITY_CONFLICT")
            elif closure and closure.get("aggregate_sha256") != expected_closures[0]:
                issues.append("SOURCE_CLOSURE_DRIFT")

    artifacts = [inspect_artifact_hint(hint) for hint in subject.artifact_hints]
    for artifact in artifacts:
        if artifact["status"] in {"MISSING", "UNREADABLE", "DRIFT"}:
            issues.append(f"{str(artifact['role']).upper()}_{artifact['status']}")
        elif artifact["status"] == "OBSERVED_UNPINNED":
            issues.append(f"{str(artifact['role']).upper()}_HASH_UNBOUND")
    issues = sorted(set(issues))
    if any(issue.endswith(("_DRIFT", "_MISMATCH")) for issue in issues):
        status = "DRIFT"
    elif any(issue.endswith(("_MISSING", "_UNREADABLE")) for issue in issues):
        status = "MISSING"
    elif issues:
        status = "UNBOUND"
    else:
        status = "CLOSED"
    memberships = sorted(
        subject.memberships,
        key=lambda item: (
            str(item.get("kind")),
            str(item.get("source_id")),
            str(item.get("state")),
        ),
    )
    return {
        "subject_id": canonical_sha256(
            {"ea_id": subject.ea_id, "symbol": subject.symbol, "memberships": memberships}
        ),
        "ea_id": subject.ea_id,
        "symbol": subject.symbol,
        "status": status,
        "issues": issues,
        "memberships": memberships,
        "canonical_ea_dir": str(ea_dir) if ea_dir else None,
        "canonical_artifacts": canonical,
        "source_closure": closure,
        "artifacts": sorted(
            artifacts,
            key=lambda item: (str(item.get("role")), path_key(Path(item["path"]))),
        ),
    }


def settings_row_label(row_html: str) -> str | None:
    match = re.search(
        r'<td\b[^>]*\bcolspan\s*=\s*["\']?3(?!\d)[^>]*>(.*?)</td>',
        row_html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match is None:
        return None
    return re.sub(r"<[^>]+>", "", match.group(1)).strip().rstrip(":").strip()


def report_inputs_region(html: str) -> str | None:
    rows = list(re.finditer(r"<tr\b.*?</tr>", html, flags=re.IGNORECASE | re.DOTALL))
    start = None
    for index, row in enumerate(rows):
        label = settings_row_label(row.group(0))
        if label is not None and label.casefold() == "inputs":
            start = index
            break
    if start is None:
        return None
    parts = [rows[start].group(0)]
    for row in rows[start + 1 :]:
        label = settings_row_label(row.group(0))
        if label is None or label != "":
            break
        parts.append(row.group(0))
    return "".join(parts)


def effective_seed_from_report(path: Path) -> int | None:
    try:
        html = read_text_lossless(path)
    except (OSError, UnicodeError):
        return None
    region = report_inputs_region(html)
    if region is None:
        return None
    seeds = {
        int(value)
        for value in re.findall(
            r"<b>\s*qm_rng_seed\s*=\s*(\d+)\s*</b>",
            region,
            flags=re.IGNORECASE,
        )
    }
    return seeds.pop() if len(seeds) == 1 else None


def label_seed_from_tester_ini(path: Path) -> int | None:
    try:
        text = read_text_lossless(path)
    except (OSError, UnicodeError):
        return None
    match = Q07_SET_SEED_RE.search(text)
    return int(match.group("seed")) if match else None


def run_dir_for_summary(summary_path: Path, summary: Mapping[str, Any]) -> Path | None:
    runs = summary.get("runs")
    if isinstance(runs, list) and runs:
        run = runs[-1] if isinstance(runs[-1], Mapping) else {}
        for key in ("report_canonical_path", "report_source_path", "tester_ini_path"):
            raw = run.get(key)
            if not raw:
                continue
            recorded = Path(str(raw))
            rebased = summary_path.parent / "raw" / recorded.parent.name
            if rebased.is_dir():
                return rebased
            if recorded.parent.is_dir():
                return recorded.parent
    candidates = sorted({path.parent for path in summary_path.parent.rglob("report.htm")}, key=path_key)
    return candidates[0] if len(candidates) == 1 else None


def nested_mapping(value: Any, *keys: str) -> Mapping[str, Any] | None:
    current = value
    for key in keys:
        if not isinstance(current, Mapping):
            return None
        current = current.get(key)
    return current if isinstance(current, Mapping) else None


def recorded_artifact(identity: Mapping[str, Any], *keys: str) -> Mapping[str, Any]:
    value = nested_mapping(identity, *keys)
    return value or {}


def actual_matches_recorded_artifact(binding: Mapping[str, Any]) -> tuple[bool, str | None]:
    expected = binding.get("sha256")
    path = normalize_path(binding.get("path"))
    if not valid_sha256(expected) or path is None:
        return False, "HASH_OR_PATH_MISSING"
    if not path.is_file():
        return False, "FILE_MISSING"
    try:
        return sha256_file(path) == str(expected).lower(), None
    except OSError:
        return False, "UNREADABLE"


def summary_identity(
    summary_path: Path,
    *,
    repo_root: Path,
    expected_ea_id: str,
    expected_symbol: str,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "summary_path": str(summary_path),
        "summary_sha256": None,
        "issues": [],
        "mq5_sha256": None,
        "ex5_sha256": None,
        "setfile_sha256": None,
        "report_sha256": None,
        "tester_ini_sha256": None,
        "source_closure_sha256": None,
    }
    if not summary_path.is_file():
        result["issues"].append("SUMMARY_MISSING")
        return result
    result["summary_sha256"] = sha256_file(summary_path)
    summary, error = try_json_object(summary_path)
    if summary is None:
        result["issues"].append("SUMMARY_UNREADABLE")
        result["error"] = error
        return result
    try:
        summary_ea = normalize_ea_id(summary.get("ea_id"))
        summary_symbol = normalize_symbol(summary.get("symbol"))
    except ScanError:
        result["issues"].append("SUMMARY_SCOPE_MISSING")
    else:
        if summary_ea != expected_ea_id or summary_symbol != expected_symbol:
            result["issues"].append("SUMMARY_SCOPE_MISMATCH")
    identity = summary.get("execution_identity")
    if not isinstance(identity, Mapping):
        result["issues"].append("EXECUTION_IDENTITY_MISSING")
        return result
    if identity.get("stable_during_run") is not True:
        result["issues"].append("EXECUTION_IDENTITY_UNSTABLE")

    mq5 = recorded_artifact(identity, "mq5_source")
    source_ex5 = recorded_artifact(identity, "expert_binary", "source")
    deployed_ex5 = recorded_artifact(identity, "expert_binary", "deployed")
    source_set = recorded_artifact(identity, "setfile", "source")
    deployed_set = recorded_artifact(identity, "setfile", "deployed")
    result["mq5_sha256"] = str(mq5.get("sha256") or "").lower() or None
    result["ex5_sha256"] = str(source_ex5.get("sha256") or "").lower() or None
    result["setfile_sha256"] = str(source_set.get("sha256") or "").lower() or None
    for label, artifact in (
        ("MQ5", mq5),
        ("EX5_SOURCE", source_ex5),
        ("EX5_DEPLOYED", deployed_ex5),
        ("SET_SOURCE", source_set),
        ("SET_DEPLOYED", deployed_set),
    ):
        if not valid_sha256(artifact.get("sha256")):
            result["issues"].append(f"{label}_HASH_MISSING")
    if (
        valid_sha256(source_ex5.get("sha256"))
        and valid_sha256(deployed_ex5.get("sha256"))
        and str(source_ex5["sha256"]).lower() != str(deployed_ex5["sha256"]).lower()
    ):
        result["issues"].append("EX5_SOURCE_DEPLOYED_MISMATCH")
    if (
        valid_sha256(source_set.get("sha256"))
        and valid_sha256(deployed_set.get("sha256"))
        and str(source_set["sha256"]).lower() != str(deployed_set["sha256"]).lower()
    ):
        result["issues"].append("SET_SOURCE_DEPLOYED_MISMATCH")
    if nested_mapping(identity, "expert_binary") and nested_mapping(identity, "expert_binary").get(
        "stable_during_run"
    ) is not True:
        result["issues"].append("EX5_UNSTABLE_DURING_RUN")
    if nested_mapping(identity, "setfile") and nested_mapping(identity, "setfile").get(
        "stable_during_run"
    ) is not True:
        result["issues"].append("SET_UNSTABLE_DURING_RUN")

    closure_hash = None
    for container in (summary, identity):
        if isinstance(container, Mapping):
            values = identity_fields(container)
            if valid_sha256(values.get("source_closure_sha256")):
                closure_hash = values["source_closure_sha256"]
                break
    result["source_closure_sha256"] = closure_hash
    if closure_hash is None:
        result["issues"].append("SOURCE_CLOSURE_HASH_MISSING")

    # Current-tree comparison establishes vintage; mtime is deliberately ignored.
    mq5_path = normalize_path(mq5.get("path"))
    if mq5_path and mq5_path.is_file() and valid_sha256(mq5.get("sha256")):
        if sha256_file(mq5_path) != str(mq5["sha256"]).lower():
            result["issues"].append("MQ5_CURRENT_DRIFT")
        try:
            closure = source_closure(mq5_path, repo_root)
            result["observed_source_closure_sha256"] = closure["aggregate_sha256"]
            if closure["unresolved_repo_includes"]:
                result["issues"].append("SOURCE_CLOSURE_UNRESOLVED")
            if closure_hash and closure["aggregate_sha256"] != closure_hash:
                result["issues"].append("SOURCE_CLOSURE_CURRENT_DRIFT")
        except (OSError, UnicodeError):
            result["issues"].append("SOURCE_CLOSURE_UNREADABLE")
    elif not mq5_path or not mq5_path.is_file():
        result["issues"].append("MQ5_CURRENT_MISSING")
    ex5_path = normalize_path(source_ex5.get("path"))
    if ex5_path and ex5_path.is_file() and valid_sha256(source_ex5.get("sha256")):
        if sha256_file(ex5_path) != str(source_ex5["sha256"]).lower():
            result["issues"].append("EX5_CURRENT_DRIFT")
    elif not ex5_path or not ex5_path.is_file():
        result["issues"].append("EX5_CURRENT_MISSING")

    run_dir = run_dir_for_summary(summary_path, summary)
    result["run_dir"] = str(run_dir) if run_dir else None
    if run_dir is None:
        result["issues"].append("RUN_DIR_MISSING")
    else:
        report_path = run_dir / "report.htm"
        tester_path = run_dir / "tester.ini"
        runs = summary.get("runs") if isinstance(summary.get("runs"), list) else []
        run = runs[-1] if runs and isinstance(runs[-1], Mapping) else {}
        expected_report = run.get("report_sha256")
        expected_tester = run.get("tester_ini_sha256")
        for label, path, expected in (
            ("REPORT", report_path, expected_report),
            ("TESTER_INI", tester_path, expected_tester),
        ):
            if not path.is_file():
                result["issues"].append(f"{label}_MISSING")
            elif not valid_sha256(expected):
                result["issues"].append(f"{label}_HASH_MISSING")
            elif sha256_file(path) != str(expected).lower():
                result["issues"].append(f"{label}_HASH_MISMATCH")
        result["report_sha256"] = str(expected_report).lower() if valid_sha256(expected_report) else None
        result["tester_ini_sha256"] = (
            str(expected_tester).lower() if valid_sha256(expected_tester) else None
        )
    result["issues"] = sorted(set(result["issues"]))
    return result


def load_canonical_seeds(repo_root: Path) -> tuple[list[int], dict[str, Any]]:
    path = repo_root / "framework" / "registry" / "multiseed_seeds.json"
    payload = load_json_object(path)
    raw = payload.get("seeds")
    if not isinstance(raw, list) or not raw or not all(isinstance(value, int) for value in raw):
        raise ScanError(f"invalid multiseed registry: {path}")
    seeds = [int(value) for value in raw]
    if len(seeds) != len(set(seeds)):
        raise ScanError(f"duplicate multiseed registry values: {path}")
    return seeds, {"path": str(path), "sha256": sha256_file(path), "seeds": seeds}


def q07_seed_auth(
    evidence: Mapping[str, Any],
    *,
    expected_seeds: Sequence[int],
    repo_root: Path,
    ea_id: str,
    symbol: str,
    runner_symbol: str | None = None,
) -> dict[str, Any]:
    issues: list[str] = []
    aggregate_seeds = evidence.get("seeds")
    if aggregate_seeds != list(expected_seeds):
        issues.append("AGGREGATE_SEED_SET_MISMATCH")
    details = evidence.get("per_seed_detail")
    if not isinstance(details, list):
        details = []
        issues.append("PER_SEED_DETAIL_MISSING")
    by_seed: dict[int, Mapping[str, Any]] = {}
    for detail in details:
        if not isinstance(detail, Mapping) or not isinstance(detail.get("seed"), int):
            issues.append("PER_SEED_DETAIL_INVALID")
            continue
        seed = int(detail["seed"])
        if seed in by_seed:
            issues.append("PER_SEED_DUPLICATE")
        by_seed[seed] = detail
    if sorted(by_seed) != sorted(expected_seeds):
        issues.append("PER_SEED_SET_MISMATCH")
    rows: list[dict[str, Any]] = []
    for seed in expected_seeds:
        detail = by_seed.get(seed)
        row: dict[str, Any] = {
            "requested_seed": seed,
            "label_seed": None,
            "effective_seed": None,
            "summary_path": None,
            "summary_sha256": None,
            "summary_sha256_recorded": None,
            "identity": None,
            "status": "UNAUTHENTICATED",
        }
        if detail is None:
            row["issues"] = ["SEED_SLOT_MISSING"]
            rows.append(row)
            continue
        summary_path = normalize_path(detail.get("summary_path"))
        row["summary_path"] = str(summary_path) if summary_path else None
        recorded_summary_sha = detail.get("summary_sha256")
        row["summary_sha256_recorded"] = (
            str(recorded_summary_sha).lower() if valid_sha256(recorded_summary_sha) else None
        )
        row_issues: list[str] = []
        if summary_path is None or not summary_path.is_file():
            row_issues.append("SUMMARY_MISSING")
        else:
            row["summary_sha256"] = sha256_file(summary_path)
            if not valid_sha256(recorded_summary_sha):
                # Current Q07 aggregates record only a path.  That is intentionally
                # not treated as an immutable aggregate -> summary binding.
                row_issues.append("SUMMARY_HASH_UNBOUND_IN_AGGREGATE")
            elif row["summary_sha256"] != str(recorded_summary_sha).lower():
                row_issues.append("SUMMARY_HASH_MISMATCH")
            identity = summary_identity(
                summary_path,
                repo_root=repo_root,
                expected_ea_id=ea_id,
                expected_symbol=runner_symbol or symbol,
            )
            row["identity"] = identity
            summary, _error = try_json_object(summary_path)
            run_dir = run_dir_for_summary(summary_path, summary or {})
            if run_dir is not None:
                row["label_seed"] = label_seed_from_tester_ini(run_dir / "tester.ini")
                row["effective_seed"] = effective_seed_from_report(run_dir / "report.htm")
            if row["label_seed"] != seed:
                row_issues.append("LABEL_SEED_MISMATCH_OR_MISSING")
            if row["effective_seed"] != seed:
                row_issues.append("EFFECTIVE_SEED_MISMATCH_OR_MISSING")
            if detail.get("invalid_reason"):
                row_issues.append("SEED_DETAIL_INVALID_REASON")
            row_issues.extend(identity["issues"])
        row["issues"] = sorted(set(row_issues))
        row["status"] = "AUTHENTICATED" if not row["issues"] else "UNAUTHENTICATED"
        rows.append(row)
    return {
        "expected_seeds": list(expected_seeds),
        "status": "AUTHENTICATED" if not issues and all(row["status"] == "AUTHENTICATED" for row in rows) else "UNAUTHENTICATED",
        "issues": sorted(set(issues)),
        "runs": rows,
    }


def reason_sort(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (REASON_RANK.get(item, 10_000), item))


def priority_for_memberships(memberships: Sequence[Mapping[str, Any]]) -> tuple[str, str]:
    kinds = {str(item.get("kind")) for item in memberships}
    if "live_manifest" in kinds:
        return "P0_LIVE", "HOLD_OWNER_REVIEW"
    if kinds & {"portfolio_manifest", "portfolio_candidate", "q10_candidate"}:
        return "P0_ADMISSION", "NO_AUTOMATIC_LIVE_ACTION"
    return "P1_HISTORY", "NO_RUNTIME_ACTION"


def inspect_work_item(
    row: Mapping[str, Any],
    *,
    memberships: Sequence[Mapping[str, Any]],
    repo_root: Path,
    canonical_seeds: Sequence[int],
) -> dict[str, Any]:
    raw = work_item_snapshot(row)
    raw_hash = canonical_sha256(raw)
    payload = parse_json_object(row["payload_json"])
    reasons: list[str] = []
    evidence_path = normalize_path(row["evidence_path"])
    evidence: dict[str, Any] | None = None
    evidence_sha = None
    evidence_error = None
    if evidence_path is None or not evidence_path.is_file():
        reasons.append("MISSING_FILE")
    else:
        evidence_sha = sha256_file(evidence_path)
        evidence, evidence_error = try_json_object(evidence_path)
        if evidence is None:
            reasons.append("UNREADABLE")

    payload_text = json.dumps(payload, sort_keys=True).casefold()
    verdict_reason = str(payload.get("verdict_reason") or "").casefold()
    if (
        "parse_error" in payload_text
        or ("backfill" in payload_text and int(row["attempt_count"] or 0) == 0)
        or ("parse_error" in verdict_reason and int(row["attempt_count"] or 0) == 0)
    ):
        reasons.append("PARSE_ERROR_BACKFILL")

    bindings: dict[str, Any] = {
        "evidence": {
            "path": str(evidence_path) if evidence_path else None,
            "sha256": evidence_sha,
            "error": evidence_error,
        },
        "summaries": [],
        "input": {"status": "UNBOUND"},
        "work_item_setfile": None,
    }
    setfile_path = normalize_path(row["setfile_path"])
    expected_setfile_sha = payload.get("expected_setfile_sha256")
    set_binding = {
        "path": str(setfile_path) if setfile_path else None,
        "expected_sha256": str(expected_setfile_sha).lower()
        if valid_sha256(expected_setfile_sha)
        else None,
        "observed_sha256": None,
        "status": "MISSING",
    }
    if setfile_path and setfile_path.is_file():
        set_binding["observed_sha256"] = sha256_file(setfile_path)
        if valid_sha256(expected_setfile_sha):
            set_binding["status"] = (
                "MATCH"
                if set_binding["observed_sha256"] == str(expected_setfile_sha).lower()
                else "DRIFT"
            )
        else:
            set_binding["status"] = "OBSERVED_UNPINNED"
        try:
            set_binding["input_binding"] = parse_set_inputs(setfile_path)
        except (OSError, UnicodeError):
            set_binding["input_binding"] = {"status": "UNREADABLE"}
    bindings["work_item_setfile"] = set_binding
    if set_binding["status"] in {"MISSING", "UNREADABLE", "OBSERVED_UNPINNED"}:
        reasons.append("IDENTITY_HASH_MISSING")
    elif set_binding["status"] == "DRIFT":
        reasons.append("SETFILE_DRIFT")

    expected_evidence_sha = payload.get("evidence_sha256")
    bindings["evidence"]["expected_sha256"] = (
        str(expected_evidence_sha).lower() if valid_sha256(expected_evidence_sha) else None
    )
    if evidence_sha is not None:
        if not valid_sha256(expected_evidence_sha):
            reasons.append("IDENTITY_HASH_MISSING")
        elif evidence_sha != str(expected_evidence_sha).lower():
            reasons.append("EVIDENCE_CONTENT_DRIFT")
    if evidence is not None:
        try:
            evidence_ea = normalize_ea_id(evidence.get("ea_id"))
            evidence_symbol = normalize_symbol(evidence.get("symbol"))
        except ScanError:
            reasons.append("EVIDENCE_SCOPE_MISMATCH")
        else:
            if evidence_ea != normalize_ea_id(row["ea_id"]) or evidence_symbol != normalize_symbol(
                row["symbol"]
            ):
                reasons.append("EVIDENCE_SCOPE_MISMATCH")
        if str(evidence.get("phase") or "").upper() != str(row["phase"]).upper():
            reasons.append("EVIDENCE_SCOPE_MISMATCH")
        if str(evidence.get("verdict") or "").upper() != str(row["verdict"] or "").upper():
            reasons.append("EVIDENCE_VERDICT_MISMATCH")

        if row["phase"] == "Q07":
            metrics = evidence.get("metrics") if isinstance(evidence.get("metrics"), Mapping) else {}
            if metrics.get("variance_pct") is None or metrics.get("min_pf") is None:
                reasons.append("NULL_KPI")
            if metrics.get("variance_pct") == 0 or metrics.get("spread") == 0:
                reasons.append("ZERO_VARIANCE")
            seed_auth = q07_seed_auth(
                evidence,
                expected_seeds=canonical_seeds,
                repo_root=repo_root,
                ea_id=normalize_ea_id(row["ea_id"]),
                symbol=normalize_symbol(row["symbol"]),
                runner_symbol=normalize_symbol(
                    evidence.get("runner_symbol") or row["symbol"]
                ),
            )
            bindings["input"] = seed_auth
            bindings["summaries"] = [run.get("identity") for run in seed_auth["runs"]]
            if seed_auth["status"] != "AUTHENTICATED":
                reasons.append("SEED_AUTH_MISSING")
            summary_issues = {
                issue
                for run in seed_auth["runs"]
                for issue in run.get("issues", [])
            }
        else:
            if evidence.get("pf") is None or evidence.get("trades") is None:
                reasons.append("NULL_KPI")
            summary_path = normalize_path(evidence.get("summary_path"))
            recorded_summary_sha = evidence.get("summary_sha256")
            identity = (
                summary_identity(
                    summary_path,
                    repo_root=repo_root,
                    expected_ea_id=normalize_ea_id(row["ea_id"]),
                    expected_symbol=normalize_symbol(row["symbol"]),
                )
                if summary_path is not None
                else {"issues": ["SUMMARY_MISSING"]}
            )
            bindings["summaries"] = [identity]
            summary_issues = set(identity.get("issues", []))
            if summary_path is None or not summary_path.is_file():
                reasons.append("IDENTITY_HASH_MISSING")
            elif not valid_sha256(recorded_summary_sha):
                reasons.append("IDENTITY_HASH_MISSING")
            elif sha256_file(summary_path) != str(recorded_summary_sha).lower():
                reasons.append("EVIDENCE_CONTENT_DRIFT")
            bindings["input"] = {
                "status": "BOUND_BY_SET_AND_REPORT_HASHES"
                if not {
                    issue
                    for issue in summary_issues
                    if "SET_" in issue or "REPORT_" in issue or "TESTER_INI_" in issue
                }
                else "UNBOUND",
            }

        identity_missing_tokens = (
            "_HASH_MISSING",
            "_HASH_UNBOUND",
            "IDENTITY_MISSING",
            "SUMMARY_MISSING",
            "RUN_DIR_MISSING",
            "_CURRENT_MISSING",
        )
        if any(any(token in issue for token in identity_missing_tokens) for issue in summary_issues):
            reasons.append("IDENTITY_HASH_MISSING")
        if any(
            issue
            in {
                "MQ5_CURRENT_DRIFT",
                "EX5_CURRENT_DRIFT",
                "SOURCE_CLOSURE_CURRENT_DRIFT",
            }
            for issue in summary_issues
        ):
            reasons.append("BINARY_VINTAGE_MISMATCH")
        if "SOURCE_CLOSURE_UNRESOLVED" in summary_issues:
            reasons.append("SOURCE_CLOSURE_UNRESOLVED")
        if "SOURCE_CLOSURE_CURRENT_DRIFT" in summary_issues:
            reasons.append("SOURCE_CLOSURE_DRIFT")

    reasons = reason_sort(reasons)
    if "BINARY_VINTAGE_MISMATCH" in reasons:
        effective = "EVIDENCE_VINTAGE_STALE"
    elif reasons:
        effective = "PROVENANCE_UNVERIFIED"
    else:
        effective = "PASS"
    priority, live_action = priority_for_memberships(memberships)
    adjudication = {
        "work_item_id": row["id"],
        "raw_row_sha256": raw_hash,
        "phase": row["phase"],
        "ea_id": normalize_ea_id(row["ea_id"]),
        "symbol": normalize_symbol(row["symbol"]),
        "original_status": row["status"],
        "original_verdict": row["verdict"],
        "effective_admission_status": effective,
        "reason_classes": reasons,
        "priority": priority,
        "live_action": live_action,
        "evidence_path": str(evidence_path) if evidence_path else None,
        "evidence_sha256": evidence_sha,
        "memberships": sorted(
            memberships,
            key=lambda item: (str(item.get("kind")), str(item.get("source_id"))),
        ),
        "bindings": bindings,
    }
    adjudication["adjudication_fingerprint_sha256"] = canonical_sha256(adjudication)
    return adjudication


def build_cohort_coverage(
    subject_reports: Sequence[Mapping[str, Any]],
    adjudications: Sequence[Mapping[str, Any]],
    phases: Sequence[str],
) -> list[dict[str, Any]]:
    by_key_phase: dict[tuple[str, str, str], list[Mapping[str, Any]]] = defaultdict(list)
    for adjudication in adjudications:
        by_key_phase[
            (
                str(adjudication["ea_id"]),
                str(adjudication["symbol"]),
                str(adjudication["phase"]),
            )
        ].append(adjudication)
    rows: list[dict[str, Any]] = []
    for subject in subject_reports:
        bound_by_phase: dict[str, set[str]] = defaultdict(set)
        lineage_issues: set[str] = set()
        for membership in subject.get("memberships", []):
            lineage = membership.get("lineage") if isinstance(membership, Mapping) else None
            if not isinstance(lineage, Mapping):
                continue
            if lineage.get("issue"):
                lineage_issues.add(str(lineage["issue"]))
            for item in lineage.get("rows", []):
                if isinstance(item, Mapping) and item.get("phase") and item.get("work_item_id"):
                    bound_by_phase[str(item["phase"])].add(str(item["work_item_id"]))
        phase_rows: list[dict[str, Any]] = []
        for phase in phases:
            candidates = sorted(
                by_key_phase.get((str(subject["ea_id"]), str(subject["symbol"]), phase), []),
                key=lambda item: str(item["work_item_id"]),
            )
            bound_ids = bound_by_phase.get(phase, set())
            bound = [item for item in candidates if str(item["work_item_id"]) in bound_ids]
            if bound and any(item["effective_admission_status"] == "PASS" for item in bound):
                status = "BOUND_PASS"
            elif bound:
                status = "BOUND_HOLD"
            elif candidates:
                status = "PAIR_ONLY_UNBOUND"
            else:
                status = "MISSING"
            if subject.get("status") != "CLOSED" and status == "BOUND_PASS":
                status = "SUBJECT_CLOSURE_HOLD"
            phase_rows.append(
                {
                    "phase": phase,
                    "status": status,
                    "lineage_bound_work_item_ids": sorted(bound_ids),
                    "pair_match_work_item_ids": [str(item["work_item_id"]) for item in candidates],
                    "effective_statuses": dict(
                        sorted(Counter(item["effective_admission_status"] for item in bound).items())
                    ),
                }
            )
        rows.append(
            {
                "subject_id": subject["subject_id"],
                "ea_id": subject["ea_id"],
                "symbol": subject["symbol"],
                "subject_status": subject["status"],
                "lineage_issues": sorted(lineage_issues),
                "phases": phase_rows,
            }
        )
    return rows


def scan(
    *,
    db_path: Path,
    repo_root: Path,
    live_manifests: Sequence[Path] = (),
    portfolio_manifests: Sequence[Path] = (),
    include_default_live: bool = True,
    runtime_live_pointer: Path = DEFAULT_RUNTIME_LIVE_POINTER,
    phases: Sequence[str] = DEFAULT_PHASES,
    observed_at_utc: str | None = None,
) -> dict[str, Any]:
    repo_root = repo_root.resolve(strict=True)
    observed = observed_at_utc or dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    subjects: dict[tuple[str, str], Subject] = {}
    manifest_descriptors: list[dict[str, Any]] = []
    live_resolution: dict[str, Any] = {}
    connection = open_db_read_only(db_path)
    try:
        add_db_cohorts(connection, subjects)
        manifest_paths_seen: set[str] = set()
        if include_default_live:
            path, authority, live_resolution = default_live_manifest(repo_root, runtime_live_pointer)
            if path is not None:
                manifest_paths_seen.add(path_key(path))
                manifest_descriptors.append(
                    add_manifest_cohort(
                        subjects, path, kind="live_manifest", authority=authority
                    )
                )
        for path in live_manifests:
            resolved = path.resolve(strict=True)
            if path_key(resolved) not in manifest_paths_seen:
                manifest_paths_seen.add(path_key(resolved))
                manifest_descriptors.append(
                    add_manifest_cohort(
                        subjects, resolved, kind="live_manifest", authority="EXPLICIT"
                    )
                )
        for path in portfolio_manifests:
            resolved = path.resolve(strict=True)
            if path_key(resolved) not in manifest_paths_seen:
                manifest_paths_seen.add(path_key(resolved))
                manifest_descriptors.append(
                    add_manifest_cohort(
                        subjects,
                        resolved,
                        kind="portfolio_manifest",
                        authority="EXPLICIT",
                    )
                )

        subject_reports = [
            inspect_subject(subjects[key], repo_root) for key in sorted(subjects)
        ]
        memberships_by_key = {
            key: sorted(
                subject.memberships,
                key=lambda item: (str(item.get("kind")), str(item.get("source_id"))),
            )
            for key, subject in subjects.items()
        }
        phase_list = tuple(sorted({str(phase).upper() for phase in phases}))
        placeholders = ",".join("?" for _ in phase_list)
        rows = connection.execute(
            f"""
            SELECT * FROM work_items
            WHERE phase IN ({placeholders})
              AND status='done'
              AND verdict='PASS'
            ORDER BY phase, ea_id, symbol, updated_at, id
            """,
            phase_list,
        ).fetchall()
        canonical_seeds, seed_registry = load_canonical_seeds(repo_root)
        adjudications = []
        for row in rows:
            key = (normalize_ea_id(row["ea_id"]), normalize_symbol(row["symbol"]))
            adjudications.append(
                inspect_work_item(
                    row,
                    memberships=memberships_by_key.get(key, []),
                    repo_root=repo_root,
                    canonical_seeds=canonical_seeds,
                )
            )
        cohort_coverage = build_cohort_coverage(
            subject_reports, adjudications, phase_list
        )
    finally:
        connection.rollback()
        connection.close()

    subject_statuses = Counter(row["status"] for row in subject_reports)
    effective_statuses = Counter(row["effective_admission_status"] for row in adjudications)
    priorities = Counter(row["priority"] for row in adjudications)
    reasons = Counter(reason for row in adjudications for reason in row["reason_classes"])
    coverage_statuses = Counter(
        phase["status"] for row in cohort_coverage for phase in row["phases"]
    )
    deterministic_payload = {
        "database": str(db_path.resolve()),
        "repo_root": str(repo_root),
        "phases": list(phase_list),
        "manifests": sorted(manifest_descriptors, key=lambda item: (item["kind"], item["path"])),
        "seed_registry": seed_registry,
        "subjects": subject_reports,
        "cohort_coverage": cohort_coverage,
        "adjudications": adjudications,
    }
    report = {
        "schema": REPORT_SCHEMA,
        "tool": TOOL_ID,
        "observed_at_utc": observed,
        "read_only_contract": {
            "sqlite_uri_mode": "ro",
            "sqlite_query_only": True,
            "runtime_db_writes": 0,
            "factory_actions": 0,
            "tlive_actions": 0,
            "historical_verdict_updates": 0,
        },
        "live_manifest_resolution": live_resolution,
        **deterministic_payload,
        "summary": {
            "subjects": len(subject_reports),
            "subject_statuses": dict(sorted(subject_statuses.items())),
            "adjudications": len(adjudications),
            "effective_statuses": dict(sorted(effective_statuses.items())),
            "priorities": dict(sorted(priorities.items())),
            "reason_classes": dict(sorted(reasons.items())),
            "coverage_statuses": dict(sorted(coverage_statuses.items())),
        },
        "scan_fingerprint_sha256": canonical_sha256(deterministic_payload),
    }
    return report


def overlay_event_from_adjudication(
    adjudication: Mapping[str, Any], *, reviewer: str, observed_at_utc: str
) -> dict[str, Any]:
    core = {
        "schema": OVERLAY_SCHEMA,
        "tool": TOOL_ID,
        "reviewer": reviewer,
        "observed_at_utc": observed_at_utc,
        "work_item_id": adjudication["work_item_id"],
        "raw_row_sha256": adjudication["raw_row_sha256"],
        "phase": adjudication["phase"],
        "ea_id": adjudication["ea_id"],
        "symbol": adjudication["symbol"],
        "original_status": adjudication["original_status"],
        "original_verdict": adjudication["original_verdict"],
        "effective_admission_status": adjudication["effective_admission_status"],
        "reason_classes": adjudication["reason_classes"],
        "priority": adjudication["priority"],
        "live_action": adjudication["live_action"],
        "evidence_path": adjudication["evidence_path"],
        "evidence_sha256": adjudication["evidence_sha256"],
        "adjudication_fingerprint_sha256": adjudication[
            "adjudication_fingerprint_sha256"
        ],
    }
    event_identity = dict(core)
    event_identity.pop("observed_at_utc")
    event_identity.pop("reviewer")
    core["event_id"] = canonical_sha256(event_identity)
    return core


def validate_overlay_chain(path: Path) -> tuple[list[dict[str, Any]], str | None]:
    if not path.exists():
        return [], None
    events: list[dict[str, Any]] = []
    previous = None
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                raise ScanError(f"blank line in overlay {path}:{line_number}")
            try:
                event = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ScanError(f"invalid overlay JSON {path}:{line_number}: {exc}") from exc
            if not isinstance(event, dict) or event.get("schema") != OVERLAY_SCHEMA:
                raise ScanError(f"invalid overlay event schema {path}:{line_number}")
            if event.get("previous_event_sha256") != previous:
                raise ScanError(f"overlay chain predecessor mismatch {path}:{line_number}")
            claimed = event.get("event_sha256")
            unsigned = dict(event)
            unsigned.pop("event_sha256", None)
            actual = canonical_sha256(unsigned)
            if claimed != actual:
                raise ScanError(f"overlay event hash mismatch {path}:{line_number}")
            previous = actual
            events.append(event)
    return events, previous


def append_overlay(
    path: Path,
    events: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    if not path.parent.is_dir():
        raise ScanError(f"overlay parent directory does not exist: {path.parent}")
    lock = path.with_name(path.name + ".lock")
    try:
        descriptor = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ScanError(f"overlay append lock already exists: {lock}") from exc
    try:
        os.close(descriptor)
        existing, previous = validate_overlay_chain(path)
        known = {str(event.get("event_id")) for event in existing}
        appended = 0
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            for candidate in sorted(events, key=lambda item: str(item.get("event_id"))):
                if candidate.get("schema") != OVERLAY_SCHEMA:
                    raise ScanError("candidate overlay event has wrong schema")
                event_id = str(candidate.get("event_id") or "")
                if not valid_sha256(event_id):
                    raise ScanError("candidate overlay event_id is invalid")
                if event_id in known:
                    continue
                event = dict(candidate)
                event["previous_event_sha256"] = previous
                event["event_sha256"] = canonical_sha256(event)
                handle.write(canonical_json_bytes(event).decode("utf-8") + "\n")
                handle.flush()
                os.fsync(handle.fileno())
                previous = event["event_sha256"]
                known.add(event_id)
                appended += 1
        return {
            "path": str(path),
            "existing": len(existing),
            "appended": appended,
            "total": len(existing) + appended,
            "tail_event_sha256": previous,
        }
    finally:
        try:
            lock.unlink()
        except FileNotFoundError:
            pass


def effective_overlay(path: Path) -> dict[str, dict[str, Any]]:
    events, _tail = validate_overlay_chain(path)
    current: dict[str, dict[str, Any]] = {}
    for event in events:
        current[str(event["work_item_id"])] = event
    return dict(sorted(current.items()))


def write_report_create_only(path: Path, report: Mapping[str, Any]) -> None:
    if not path.parent.is_dir():
        raise ScanError(f"report parent directory does not exist: {path.parent}")
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, ensure_ascii=False, sort_keys=True, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())


def parse_utc(value: str) -> str:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid ISO-8601 timestamp: {value}") from exc
    if parsed.tzinfo is None:
        raise argparse.ArgumentTypeError("timestamp must include an offset")
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    scan_parser = sub.add_parser("scan", help="read-only scan; JSON to stdout by default")
    scan_parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    scan_parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    scan_parser.add_argument("--runtime-live-pointer", type=Path, default=DEFAULT_RUNTIME_LIVE_POINTER)
    scan_parser.add_argument("--no-default-live", action="store_true")
    scan_parser.add_argument("--live-manifest", type=Path, action="append", default=[])
    scan_parser.add_argument("--portfolio-manifest", type=Path, action="append", default=[])
    scan_parser.add_argument("--phase", action="append", choices=("Q06", "Q07"))
    scan_parser.add_argument("--observed-at-utc", type=parse_utc)
    scan_parser.add_argument("--report-out", type=Path)

    append_parser = sub.add_parser("append-overlay", help="append new hash-chained events")
    append_parser.add_argument("--report", type=Path, required=True)
    append_parser.add_argument("--overlay", type=Path, required=True)
    append_parser.add_argument("--reviewer", required=True)

    effective_parser = sub.add_parser("effective-overlay", help="read current overlay states")
    effective_parser.add_argument("--overlay", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "scan":
            report = scan(
                db_path=args.db,
                repo_root=args.repo_root,
                live_manifests=args.live_manifest,
                portfolio_manifests=args.portfolio_manifest,
                include_default_live=not args.no_default_live,
                runtime_live_pointer=args.runtime_live_pointer,
                phases=args.phase or DEFAULT_PHASES,
                observed_at_utc=args.observed_at_utc,
            )
            if args.report_out:
                write_report_create_only(args.report_out, report)
                print(
                    json.dumps(
                        {
                            "report": str(args.report_out),
                            "scan_fingerprint_sha256": report["scan_fingerprint_sha256"],
                            "summary": report["summary"],
                        },
                        sort_keys=True,
                    )
                )
            else:
                json.dump(report, sys.stdout, ensure_ascii=False, sort_keys=True, indent=2)
                sys.stdout.write("\n")
            return 0
        if args.command == "append-overlay":
            report = load_json_object(args.report)
            if report.get("schema") != REPORT_SCHEMA:
                raise ScanError("report schema is not supported")
            events = [
                overlay_event_from_adjudication(
                    adjudication,
                    reviewer=args.reviewer,
                    observed_at_utc=str(report.get("observed_at_utc")),
                )
                for adjudication in report.get("adjudications", [])
                if isinstance(adjudication, Mapping)
            ]
            print(json.dumps(append_overlay(args.overlay, events), sort_keys=True))
            return 0
        if args.command == "effective-overlay":
            json.dump(effective_overlay(args.overlay), sys.stdout, ensure_ascii=False, sort_keys=True, indent=2)
            sys.stdout.write("\n")
            return 0
    except (OSError, sqlite3.Error, ScanError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
