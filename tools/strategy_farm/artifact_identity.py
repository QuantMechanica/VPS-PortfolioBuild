"""Typed per-run artifact identity for ``work_items``.

The payload remains the compatibility source for historical rows.  New completion
writers materialise only values which were already bound by the runner; this module
never hashes a path or manufactures an identity after the fact.
"""
from __future__ import annotations

import json
import re
import sqlite3
from collections.abc import Mapping
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
        ("artifact_identity", "ex5_sha256"),
    ),
    "setfile_sha256": (
        ("expected_setfile_sha256",), ("setfile_sha256",),
        ("baseline_setfile_sha256",), ("setfile_build_hash",),
        ("identities", "baseline_setfile_sha256"),
        ("artifact_identity", "setfile_sha256"),
    ),
    "mq5_sha256": (
        ("expected_mq5_sha256",), ("mq5_sha256",),
        ("baseline_mq5_sha256",), ("source_sha256",),
        ("identities", "mq5_sha256"), ("artifact_identity", "mq5_sha256"),
    ),
    "include_closure_sha256": (
        ("include_closure_sha256",), ("source_closure_sha256",),
        ("identities", "include_closure_sha256"),
        ("artifact_identity", "include_closure_sha256"),
    ),
    "build_id": (
        ("build_id",), ("build_hash",), ("compile_manifest_sha256",),
        ("artifact_identity", "build_id"),
    ),
    "data_window_start": (
        ("data_window_start",), ("expected_from_date",), ("from_date",),
        ("opt_from_date",), ("selection_from_utc",),
        ("window", "from_date"), ("windows", "selection_from_utc"),
        ("artifact_identity", "data_window_start"),
    ),
    "data_window_end": (
        ("data_window_end",), ("expected_to_date",), ("to_date",),
        ("opt_to_date",), ("selection_to_utc",),
        ("window", "to_date"), ("windows", "selection_to_utc"),
        ("artifact_identity", "data_window_end"),
    ),
    "news_calendar_sha256": (
        ("news_calendar_sha256",), ("qm_news_calendar_expected_sha256",),
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
    """Materialise identity and replace an unbound economic verdict with INFRA.

    The intended verdict is retained in the payload for diagnosis, but is never
    written to the verdict column when its required run identity is incomplete.
    """
    identity = extract_identity(summary, payload)
    missing: tuple[str, ...] = ()
    if str(taxonomy).casefold() == "strategy":
        missing = tuple(
            field for field in required_identity_fields(phase, kind, payload)
            if identity[field] is None
        )
    if missing:
        payload["artifact_identity_intended_verdict"] = verdict
        payload["artifact_identity_missing_fields"] = list(missing)
        payload["verdict_reason"] = ARTIFACT_IDENTITY_MISSING
        payload["verdict_taxonomy"] = "infra"
        verdict, taxonomy = "INFRA_FAIL", "infra"
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
        if column in have:
            assignments.append(f"{column}=?")
            values.append(identity.get(column))
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
