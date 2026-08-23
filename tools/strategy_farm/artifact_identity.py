"""Typed per-run artifact identity for ``work_items``.

The payload remains the compatibility source for historical rows.  New completion
writers materialise only values which were already bound by the runner; this module
never hashes a path or manufactures an identity after the fact.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from collections.abc import Mapping
from pathlib import Path
from typing import Any


IDENTITY_COLUMNS = (
    "ex5_sha256",
    "setfile_sha256",
    "mq5_sha256",
    "include_closure_sha256",
    "build_id",
    "data_window_start",
    "data_window_end",
    "news_calendar_sha256",
)

SHA256_COLUMNS = frozenset(
    {"ex5_sha256", "setfile_sha256", "mq5_sha256", "include_closure_sha256",
     "news_calendar_sha256"}
)
SHA256_RE = re.compile(r"[0-9a-f]{64}")
ARTIFACT_IDENTITY_MISSING = "ARTIFACT_IDENTITY_MISSING"

_PATHS: dict[str, tuple[tuple[str, ...], ...]] = {
    "ex5_sha256": (
        ("expected_ex5_sha256",), ("expected_current_ex5_sha256",),
        ("staged_ex5_sha256",), ("ex5_sha256",),
        ("baseline_ex5_sha256",), ("identities", "ex5_sha256"),
        ("artifact_sha256", "expected_ex5_sha256"),
        ("spawn_binding", "expected_ex5_sha256"),
        ("run_binding", "expected_ex5_sha256"),
        ("bindings", "expected_ex5_sha256"),
        ("staged_ex5", "required_sha256"),
        ("staged_ex5", "source_sha256"),
        ("evidence_identity", "ex5_sha256"),
        ("execution_identity", "expert_binary", "required_sha256"),
        ("execution_identity", "expert_binary", "deployed", "sha256"),
        ("validated_build", "ex5_sha256"),
        ("artifact_identity", "ex5_sha256"),
    ),
    "setfile_sha256": (
        ("expected_setfile_sha256",), ("setfile_sha256",),
        ("baseline_setfile_sha256",), ("setfile_build_hash",),
        ("artifact_sha256", "expected_setfile_sha256"),
        ("spawn_binding", "expected_setfile_sha256"),
        ("run_binding", "expected_setfile_sha256"),
        ("bindings", "expected_setfile_sha256"),
        ("identities", "baseline_setfile_sha256"),
        ("identities", "setfile_sha256"),
        ("evidence_identity", "setfile_sha256"),
        ("execution_identity", "setfile", "source", "sha256"),
        ("execution_identity", "setfile", "deployed", "sha256"),
        ("validated_build", "setfile_sha256"),
        ("artifact_identity", "setfile_sha256"),
    ),
    "mq5_sha256": (
        ("expected_mq5_sha256",), ("mq5_sha256",),
        ("baseline_mq5_sha256",), ("source_sha256",),
        ("artifact_sha256", "expected_mq5_sha256"),
        ("spawn_binding", "expected_mq5_sha256"),
        ("run_binding", "expected_mq5_sha256"),
        ("bindings", "expected_mq5_sha256"),
        ("execution_identity", "mq5_source", "sha256"),
        ("validated_build", "mq5_sha256"),
        ("identities", "mq5_sha256"), ("artifact_identity", "mq5_sha256"),
    ),
    "include_closure_sha256": (
        ("include_closure_sha256",), ("source_closure_sha256",),
        ("artifact_sha256", "include_closure_sha256"),
        ("spawn_binding", "include_closure_sha256"),
        ("run_binding", "include_closure_sha256"),
        ("bindings", "include_closure_sha256"),
        ("identities", "include_closure_sha256"),
        ("artifact_identity", "include_closure_sha256"),
    ),
    "build_id": (
        ("build_id",), ("build_hash",), ("compile_manifest_sha256",),
        ("build_sha256",), ("artifact_build_hash",), ("ea_build_hash",),
        ("artifact_sha256", "build_hash"),
        ("spawn_binding", "build_id"), ("spawn_binding", "build_hash"),
        ("run_binding", "build_id"), ("run_binding", "build_hash"),
        ("bindings", "build_id"), ("bindings", "build_hash"),
        ("validated_build", "build_id"), ("validated_build", "build_hash"),
        ("artifact_identity", "build_id"),
    ),
    "data_window_start": (
        ("data_window_start",), ("expected_from_date",), ("from_date",),
        ("opt_from_date",), ("selection_from_utc",), ("history_from",),
        ("from_year",),
        ("window", "from_date"), ("windows", "selection_from_utc"),
        ("windows", "full_from_utc"), ("test_window", "from_date"),
        ("spawn_binding", "expected_from_date"),
        ("run_binding", "expected_from_date"),
        ("bindings", "expected_from_date"),
        ("artifact_identity", "data_window_start"),
    ),
    "data_window_end": (
        ("data_window_end",), ("expected_to_date",), ("to_date",),
        ("opt_to_date",), ("selection_to_utc",), ("history_to",),
        ("to_year",),
        ("window", "to_date"), ("windows", "selection_to_utc"),
        ("windows", "full_to_utc"), ("test_window", "to_date"),
        ("spawn_binding", "expected_to_date"),
        ("run_binding", "expected_to_date"),
        ("bindings", "expected_to_date"),
        ("artifact_identity", "data_window_end"),
    ),
    "news_calendar_sha256": (
        ("news_calendar_sha256",), ("qm_news_calendar_expected_sha256",),
        ("artifact_sha256", "news_calendar_sha256"),
        ("spawn_binding", "news_calendar_sha256"),
        ("run_binding", "news_calendar_sha256"),
        ("bindings", "news_calendar_sha256"),
        ("calendar_bundle", "content_sha256"),
        ("news_calendar", "content_sha256"),
        ("artifact_identity", "news_calendar_sha256"),
    ),
}


def _at_path(source: Mapping[str, Any], path: tuple[str, ...]) -> Any:
    value: Any = source
    for part in path:
        if not isinstance(value, Mapping):
            return None
        value = value.get(part)
    return value


def _normalise(column: str, value: Any) -> str | None:
    if value is None:
        return None
    token = str(value).strip()
    if not token or token.casefold() in {"none", "null"}:
        return None
    if column in SHA256_COLUMNS:
        token = token.casefold()
        return token if SHA256_RE.fullmatch(token) else None
    return token


def extract_identity(*sources: Mapping[str, Any] | None) -> dict[str, str | None]:
    """Copy the first valid bound value for each typed identity column.

    Source order is precedence order.  Completion callers should put authenticated
    runner output before the enqueue payload.
    """
    result: dict[str, str | None] = {column: None for column in IDENTITY_COLUMNS}
    for column, paths in _PATHS.items():
        for source in sources:
            if not isinstance(source, Mapping):
                continue
            for path in paths:
                value = _normalise(column, _at_path(source, path))
                if value is not None:
                    result[column] = value
                    break
            if result[column] is not None:
                break
    return result


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_bound_json(
    raw_path: Any,
    *,
    expected_sha256: Any = None,
    role: str,
) -> tuple[dict[str, Any] | None, str | None]:
    """Read one path explicitly bound by the row/runner, optionally hash-pinned."""
    token = str(raw_path or "").strip()
    if not token:
        return None, None
    path = Path(token)
    try:
        if not path.is_file():
            return None, f"{role}_missing:{path}"
        expected = _normalise("ex5_sha256", expected_sha256)
        if expected_sha256 is not None and expected is None:
            return None, f"{role}_expected_sha256_invalid"
        if expected is not None and _sha256_file(path) != expected:
            return None, f"{role}_sha256_mismatch:{path}"
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        return None, f"{role}_unreadable:{path}:{exc}"
    if not isinstance(value, dict):
        return None, f"{role}_not_object:{path}"
    return value, None


def _bound_sidecar_sources(
    summary: Mapping[str, Any] | None,
    payload: Mapping[str, Any],
) -> tuple[list[Mapping[str, Any]], list[str]]:
    """Load only evidence/plan files explicitly named by this row's run binding."""
    sources: list[Mapping[str, Any]] = []
    errors: list[str] = []

    def add(raw_path: Any, *, expected: Any = None, role: str) -> dict[str, Any] | None:
        value, error = _load_bound_json(
            raw_path, expected_sha256=expected, role=role
        )
        if error:
            errors.append(error)
        if value is not None:
            sources.append(value)
        return value

    if isinstance(summary, Mapping):
        add(summary.get("summary_path"), role="runner_summary")
        details = summary.get("per_seed_detail")
        if isinstance(details, list):
            for offset, detail in enumerate(details):
                if isinstance(detail, Mapping):
                    add(
                        detail.get("summary_path"),
                        role=f"multiseed_summary_{offset}",
                    )

    plan = add(
        payload.get("q09_run_plan_path"),
        expected=payload.get("q09_run_plan_file_sha256"),
        role="q09_run_plan",
    )
    if plan is not None:
        add(
            plan.get("input_manifest_path"),
            expected=plan.get("input_manifest_sha256"),
            role="q09_input_manifest",
        )
    return sources, errors


def required_identity_fields(phase: str, kind: str, payload: Mapping[str, Any]) -> tuple[str, ...]:
    """Return the bindings required for an economic verdict in this runner lane."""
    phase_upper = str(phase or "").upper()
    kind_lower = str(kind or "").lower()
    if kind_lower not in {"backtest", "analytic"} and not phase_upper.startswith("Q"):
        return ()
    required = ["ex5_sha256", "setfile_sha256", "data_window_start", "data_window_end"]
    if phase_upper.startswith("Q09") or payload.get("q09_run_plan_path"):
        required.extend(("include_closure_sha256", "news_calendar_sha256"))
    return tuple(required)


def prepare_completion(
    *,
    phase: str,
    kind: str,
    payload: dict[str, Any],
    summary: Mapping[str, Any] | None,
    verdict: str,
    taxonomy: str,
) -> tuple[str, str, dict[str, str | None], tuple[str, ...]]:
    """Materialise bound identity and fail closed only when no binding exists.

    SH-2 columns are nullable.  A partial authenticated binding is therefore
    stamped as partial and keeps its economic verdict; only a strategy result
    with zero identity across runner output, row payload, and bound sidecars is
    replaced by ``INFRA_FAIL``.
    """
    sidecars, source_errors = _bound_sidecar_sources(summary, payload)
    identity = extract_identity(summary, *sidecars, payload)
    missing: tuple[str, ...] = ()
    required_missing: tuple[str, ...] = ()
    if str(taxonomy).casefold() == "strategy":
        required_missing = tuple(
            field for field in required_identity_fields(phase, kind, payload)
            if identity[field] is None
        )
    has_binding = any(value is not None for value in identity.values())
    if required_missing and not has_binding:
        missing = required_missing
        payload["artifact_identity_intended_verdict"] = verdict
        payload["artifact_identity_missing_fields"] = list(missing)
        payload["verdict_reason"] = ARTIFACT_IDENTITY_MISSING
        payload["verdict_taxonomy"] = "infra"
        verdict, taxonomy = "INFRA_FAIL", "infra"
    else:
        if payload.get("verdict_reason") == ARTIFACT_IDENTITY_MISSING:
            payload.pop("verdict_reason", None)
        payload.pop("artifact_identity_intended_verdict", None)
        payload.pop("artifact_identity_missing_fields", None)
        if required_missing:
            payload["artifact_identity_partial_missing_fields"] = list(
                required_missing
            )
        else:
            payload.pop("artifact_identity_partial_missing_fields", None)
    if source_errors:
        payload["artifact_identity_source_errors"] = source_errors
    else:
        payload.pop("artifact_identity_source_errors", None)
    payload["artifact_identity"] = {
        key: value for key, value in identity.items() if value is not None
    }
    return verdict, taxonomy, identity, missing


def table_columns(conn: sqlite3.Connection, table: str = "work_items") -> set[str]:
    return {str(row[1]) for row in conn.execute(f"PRAGMA table_info({table})")}


def identity_update_clause(
    conn: sqlite3.Connection,
    identity: Mapping[str, str | None],
    taxonomy: str,
) -> tuple[str, list[Any]]:
    """SQL assignment fragment for schemas before or after the OFF migration."""
    have = table_columns(conn)
    assignments: list[str] = []
    values: list[Any] = []
    for column in IDENTITY_COLUMNS:
        value = identity.get(column)
        if column in have and value is not None:
            assignments.append(f"{column}=?")
            values.append(value)
    if "verdict_taxonomy" in have:
        assignments.append("verdict_taxonomy=?")
        values.append(taxonomy)
    if "verdict_taxonomy_stored" in have:
        assignments.append("verdict_taxonomy_stored=?")
        values.append(taxonomy)
    return ", ".join(assignments), values


def payload_object(raw: str | bytes | None) -> dict[str, Any]:
    try:
        value = json.loads(raw or "{}")
    except (TypeError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}
