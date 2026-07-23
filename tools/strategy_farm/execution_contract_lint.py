#!/usr/bin/env python3
"""Lint Strategy Card v2 execution contracts against their MQL5 sources.

The contract deliberately separates source mechanics from framework execution
overrides. It is stdlib-only so it can run in the farm controller, prebuild
checks and CI without PyYAML/jsonschema dependencies.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = REPO_ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"
DEFAULT_SYMBOL_MATRIX = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"

NON_ORDER_ROUTABLE_MARKERS = (
    "backtest-only",
    "non-order-routable",
    "broker routet keine orders",
)
ROUTING_MATRIX_COLUMNS = {
    "symbol",
    "evidence_line",
    "live_order_symbol",
    "live_order_status",
    "routing_evidence_ref",
}
ROUTING_STATUS = "BACKTEST_ALIAS_TO_ORDER_ROUTABLE_BROKER_SYMBOL"
MATRIX_ORDER_ROUTABLE_STATUS = "ORDER_ROUTABLE_CONFIRMED"
ROUTING_QUALIFICATION_STATUSES = {"PASS", "REQUAL_REQUIRED", "BLOCKED"}
STALE_SP500_ROUTING_REASONS = {
    "darwinex_zero_sp500_dwx_backtest_only_non_order_routable",
    "substitute_to_ndx_or_ws30_full_requalification_required",
}

TIMEFRAMES = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"}
CONTRACT_SYMBOL_RE = re.compile(r"^[A-Z][A-Z0-9]{1,15}\.DWX$")
VARIANT_ID_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
FRIDAY_MODES = {"DISABLED", "CARD_RULE", "FRAMEWORK_OVERRIDE"}
QUALIFICATION_STATUSES = {"PASS", "REQUAL_REQUIRED", "BLOCKED"}
PROMOTION_STATUSES = {"ELIGIBLE", "REQUAL_REQUIRED", "BLOCKED"}
UNRESOLVED_SEMANTIC_CONFLICT_PREFIX = "unresolved_semantic_conflict_"
MODE_TOKENS = {
    "DISABLED": "QM_FRIDAY_CLOSE_DISABLED",
    "CARD_RULE": "QM_FRIDAY_CLOSE_CARD_RULE",
    "FRAMEWORK_OVERRIDE": "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE",
}

NEWS_FILE_CALENDAR_POLICY = "FTMO_PRE30_POST30_NEWS_FILES_FAIL_CLOSED"
NEWS_FILE_CALENDAR_ROLES = {
    "SHARED_PRIMARY",
    "SHARED_SECONDARY",
    "QMDEV1_COMMON_PRIMARY",
    "QMDEV1_COMMON_SECONDARY",
}
NEWS_FILE_CALENDAR_FIELDS = {
    "role",
    "path",
    "sha256",
    "coverage_start",
    "coverage_end",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
DEPENDENCY_ID_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
DATA_DEPENDENCY_TYPES = {"calendar", "artifact", "signal_anchor", "session_metadata"}
DEPENDENCY_REQUIRED_FOR = {"ENTRY", "EXIT", "SIZING", "SIGNAL_ONLY", "PROMOTION"}
SESSION_METADATA_KINDS = {
    "BROKER_SESSION",
    "BROKER_BREAKS",
    "ROLLOVER",
    "FINANCING",
    "SESSION_EXCEPTION_CALENDAR",
}

EXECUTION_CALL_RE = re.compile(
    r"QM_FrameworkDeclareExecutionContract\s*\(\s*"
    r"(?P<timeframe>PERIOD_[A-Z0-9]+)\s*,\s*"
    r"(?P<mode>QM_FRIDAY_CLOSE_[A-Z_]+)\s*,\s*"
    r'"(?P<declaration>[^"]*)"\s*\)',
    re.DOTALL,
)

CARD_V2_SECTIONS = (
    "## source-defined rules",
    "## qm interpretations",
    "## framework execution overrides",
    "## exit precedence",
    "## runtime data dependencies",
    "## falsification and requalification",
)


@dataclass(frozen=True)
class Issue:
    severity: str
    code: str
    message: str
    ea_id: int | None = None
    path: str | None = None


def _issue(
    code: str,
    message: str,
    *,
    ea_id: int | None = None,
    path: Path | str | None = None,
    severity: str = "ERROR",
) -> Issue:
    return Issue(
        severity=severity,
        code=code,
        message=message,
        ea_id=ea_id,
        path=str(path) if path is not None else None,
    )


def _flat_frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return {}
    result: dict[str, str] = {}
    for line in match.group(1).splitlines():
        field = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if field:
            result[field.group(1)] = field.group(2).strip().strip('"').strip("'")
    return result


def lint_card_v2(card: Path, contract: dict[str, Any] | None = None) -> list[Issue]:
    if not card.exists():
        return [_issue("card_missing", "Strategy Card does not exist", path=card)]
    text = card.read_text(encoding="utf-8-sig", errors="replace")
    fm = _flat_frontmatter(text)
    issues: list[Issue] = []
    if fm.get("card_schema_version") != "2":
        issues.append(_issue("card_v2_version_missing", "card_schema_version must be 2", path=card))
    if not fm.get("execution_contract_ref"):
        issues.append(_issue("card_v2_contract_ref_missing", "execution_contract_ref is required", path=card))
    if not fm.get("execution_contract_status"):
        issues.append(_issue("card_v2_contract_status_missing", "execution_contract_status is required", path=card))

    lower = text.lower()
    for heading in CARD_V2_SECTIONS:
        if heading not in lower:
            issues.append(
                _issue(
                    "card_v2_section_missing",
                    f"required Card-v2 section missing: {heading}",
                    path=card,
                )
            )

    if contract is not None:
        ea_id = int(contract["ea_id"])
        if str(ea_id) not in fm.get("execution_contract_ref", ""):
            issues.append(
                _issue(
                    "card_v2_contract_ref_mismatch",
                    f"execution_contract_ref does not bind ea_id {ea_id}",
                    ea_id=ea_id,
                    path=card,
                )
            )
    return issues


def _require_keys(obj: dict[str, Any], keys: Iterable[str], ea_id: int | None) -> list[Issue]:
    return [
        _issue("contract_field_missing", f"required field missing: {key}", ea_id=ea_id)
        for key in keys
        if key not in obj
    ]


def execution_contract_identity(
    contract: dict[str, Any],
) -> tuple[int, str | None, str | None, str | None]:
    """Return the policy identity for one execution-contract record.

    ``symbol`` and ``timeframe`` are an optional pair for backwards
    compatibility.  Omitting both produces a legacy EA-wide identity.
    ``variant_id`` is optional only on an exact sleeve identity.  A partially
    declared or malformed identity is never coerced into the legacy scope.
    """

    ea_id = contract.get("ea_id")
    if not isinstance(ea_id, int) or isinstance(ea_id, bool) or ea_id <= 0:
        raise ValueError("ea_id must be a positive integer")
    has_symbol = "symbol" in contract
    has_timeframe = "timeframe" in contract
    has_variant = "variant_id" in contract
    if has_symbol != has_timeframe:
        raise ValueError("symbol and timeframe must be declared together")
    if has_variant and not has_symbol:
        raise ValueError("variant_id requires symbol and timeframe")
    if not has_symbol:
        return ea_id, None, None, None
    symbol = contract.get("symbol")
    timeframe = contract.get("timeframe")
    if not isinstance(symbol, str) or not isinstance(timeframe, str):
        raise ValueError("symbol and timeframe must be strings")
    if not CONTRACT_SYMBOL_RE.fullmatch(symbol):
        raise ValueError("symbol must be an uppercase literal .DWX symbol")
    if timeframe not in TIMEFRAMES:
        raise ValueError("timeframe is invalid")
    variant_id = contract.get("variant_id") if has_variant else None
    if has_variant and (
        not isinstance(variant_id, str) or not VARIANT_ID_RE.fullmatch(variant_id)
    ):
        raise ValueError("variant_id must be an uppercase identifier")
    return ea_id, symbol, timeframe, variant_id


def execution_contract_identity_label(contract: dict[str, Any]) -> str:
    ea_id, symbol, timeframe, variant_id = execution_contract_identity(contract)
    if symbol is None:
        return f"{ea_id}:*:LEGACY_EA"
    variant = variant_id or "VARIANT_UNSPECIFIED"
    return f"{ea_id}:{symbol}:{timeframe}:{variant}"


def safe_execution_contract_identity_label(contract: dict[str, Any]) -> str:
    """Render an identity without letting malformed registry input crash CLI output."""

    try:
        return execution_contract_identity_label(contract)
    except ValueError:
        return f"{contract.get('ea_id', 'UNKNOWN')}:INVALID"


def load_non_order_routable_symbols(
    matrix: Path = DEFAULT_SYMBOL_MATRIX,
) -> tuple[dict[str, dict[str, str]], str | None]:
    """Return explicit non-order-routable symbols declared by the DWX matrix.

    Dedicated ``live_order_status`` values take precedence over legacy prose.
    This is important for custom ``.DWX`` aliases: the test alias can be
    backtest-only while its explicitly mapped broker ticker is order-routable.
    Legacy rows without structured routing fields retain the narrow marker
    fallback for backwards-compatible fail-closed adjudication.
    """

    try:
        with matrix.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None or not {"symbol", "evidence_line"}.issubset(reader.fieldnames):
                return {}, "symbol matrix requires symbol and evidence_line columns"
            blocked: dict[str, dict[str, str]] = {}
            for row in reader:
                symbol = str(row.get("symbol") or "").strip().upper()
                evidence = str(row.get("evidence_line") or "").strip()
                live_status = str(row.get("live_order_status") or "").strip().upper()
                folded = evidence.casefold()
                explicitly_blocked = live_status in {
                    "NON_ORDER_ROUTABLE",
                    "NON_ORDER_ROUTABLE_CONFIRMED",
                }
                legacy_blocked = not live_status and any(
                    marker in folded for marker in NON_ORDER_ROUTABLE_MARKERS
                )
                if symbol and (explicitly_blocked or legacy_blocked):
                    blocked[symbol] = {str(key): str(value or "") for key, value in row.items()}
            return blocked, None
    except OSError as exc:
        return {}, f"cannot read symbol matrix {matrix}: {exc}"


def load_symbol_routing_rows(
    matrix: Path = DEFAULT_SYMBOL_MATRIX,
) -> tuple[dict[str, dict[str, str]], str | None]:
    """Load explicit test-to-live symbol routes from the DWX matrix.

    A row is a route only when at least one routing field is populated.  Such a
    row must populate all routing fields.  This prevents a test alias from
    becoming an inferred live ticker when its exact broker symbol or evidence
    binding is absent.
    """

    try:
        with matrix.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None or not ROUTING_MATRIX_COLUMNS.issubset(reader.fieldnames):
                missing = sorted(ROUTING_MATRIX_COLUMNS - set(reader.fieldnames or ()))
                return {}, "symbol matrix missing routing columns: " + ",".join(missing)
            routes: dict[str, dict[str, str]] = {}
            for ordinal, row in enumerate(reader, start=2):
                symbol = str(row.get("symbol") or "").strip().upper()
                live_symbol = str(row.get("live_order_symbol") or "").strip().upper()
                live_status = str(row.get("live_order_status") or "").strip().upper()
                evidence_ref = str(row.get("routing_evidence_ref") or "").strip()
                if not any((live_symbol, live_status, evidence_ref)):
                    continue
                if not symbol or not all((live_symbol, live_status, evidence_ref)):
                    return {}, f"incomplete symbol route at matrix row {ordinal}"
                if symbol in routes:
                    return {}, f"duplicate symbol route for {symbol}"
                routes[symbol] = {
                    str(key): str(value or "").strip()
                    for key, value in row.items()
                }
            return routes, None
    except OSError as exc:
        return {}, f"cannot read symbol matrix {matrix}: {exc}"


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _calendar_csv_coverage(path: Path) -> tuple[tuple[date, date] | None, str | None]:
    """Return the inclusive date coverage encoded by a supported news CSV."""

    try:
        with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = {
                str(field).strip().casefold(): str(field)
                for field in (reader.fieldnames or [])
                if field
            }
            date_field = next(
                (
                    fields[name]
                    for name in ("datetime", "datetime_utc", "date")
                    if name in fields
                ),
                None,
            )
            if date_field is None:
                return None, "news CSV has no supported date column"

            earliest: date | None = None
            latest: date | None = None
            for ordinal, row in enumerate(reader, start=2):
                raw = str(row.get(date_field) or "").strip()
                if not raw:
                    return None, f"news CSV row {ordinal} has an empty date"
                try:
                    value = date.fromisoformat(raw[:10].replace(".", "-"))
                except ValueError:
                    return None, f"news CSV row {ordinal} has invalid date {raw!r}"
                earliest = value if earliest is None or value < earliest else earliest
                latest = value if latest is None or value > latest else latest
    except OSError as exc:
        return None, f"cannot read news CSV: {exc}"

    if earliest is None or latest is None:
        return None, "news CSV contains no data rows"
    return (earliest, latest), None


def _lint_ftmo_news_file_calendar(
    calendar: dict[str, Any],
    *,
    text: str,
    source: Path,
    repo_root: Path,
    as_of: date | None,
    ea_id: int | None,
) -> list[Issue]:
    issues: list[Issue] = []
    expected_values: dict[str, Any] = {
        "temporal_mode": "PRE30_POST30",
        "compliance_profile": "FTMO",
        "minimum_impact": "high",
        "stale_max_hours": 336,
        "stale_behavior": "INIT_AND_ENTRY_FAIL_CLOSED",
        "live_source": "NATIVE_MT5_CALENDAR",
    }
    invalid_values = [
        f"{field}={calendar.get(field)!r}"
        for field, expected in expected_values.items()
        if calendar.get(field) != expected
        or (field == "stale_max_hours" and type(calendar.get(field)) is not int)
    ]
    if invalid_values:
        issues.append(
            _issue(
                "calendar_news_contract_invalid",
                "exact FTMO news policy values required: " + ", ".join(invalid_values),
                ea_id=ea_id,
            )
        )

    sources = calendar.get("sources")
    if not isinstance(sources, list) or len(sources) != len(NEWS_FILE_CALENDAR_ROLES):
        issues.append(
            _issue(
                "calendar_news_contract_invalid",
                "news policy requires exactly four source records",
                ea_id=ea_id,
            )
        )
        source_records: list[Any] = sources if isinstance(sources, list) else []
    else:
        source_records = sources

    by_role: dict[str, tuple[dict[str, Any], Path, str | None]] = {}
    declared_roles: list[str] = []
    for ordinal, record in enumerate(source_records, start=1):
        if not isinstance(record, dict) or set(record) != NEWS_FILE_CALENDAR_FIELDS:
            issues.append(
                _issue(
                    "calendar_news_contract_invalid",
                    f"news source {ordinal} must contain exactly {sorted(NEWS_FILE_CALENDAR_FIELDS)}",
                    ea_id=ea_id,
                )
            )
            continue

        role = str(record.get("role") or "")
        declared_roles.append(role)
        path_value = str(record.get("path") or "").strip()
        artifact = Path(path_value)
        if not artifact.is_absolute():
            artifact = repo_root / artifact

        declared_hash = str(record.get("sha256") or "")
        actual_hash: str | None = None
        if not artifact.is_file():
            issues.append(
                _issue(
                    "calendar_news_source_missing",
                    f"{role or f'source {ordinal}'} does not exist",
                    ea_id=ea_id,
                    path=artifact,
                )
            )
        else:
            try:
                actual_hash = _sha256_file(artifact)
            except OSError as exc:
                issues.append(
                    _issue(
                        "calendar_news_source_missing",
                        f"cannot read {role or f'source {ordinal}'}: {exc}",
                        ea_id=ea_id,
                        path=artifact,
                    )
                )
            else:
                if not SHA256_RE.fullmatch(declared_hash) or declared_hash != actual_hash:
                    issues.append(
                        _issue(
                            "calendar_news_source_hash_mismatch",
                            f"{role or f'source {ordinal}'} SHA-256 differs from the contract",
                            ea_id=ea_id,
                            path=artifact,
                        )
                    )

                coverage, coverage_error = _calendar_csv_coverage(artifact)
                declared_start_raw = str(record.get("coverage_start") or "")
                declared_end_raw = str(record.get("coverage_end") or "")
                try:
                    declared_start = date.fromisoformat(declared_start_raw)
                    declared_end = date.fromisoformat(declared_end_raw)
                except ValueError:
                    declared_start = declared_end = None
                if (
                    coverage_error is not None
                    or declared_start is None
                    or declared_end is None
                    or declared_start > declared_end
                    or coverage != (declared_start, declared_end)
                ):
                    detail = coverage_error or (
                        f"declared {declared_start_raw}..{declared_end_raw}, "
                        f"actual {coverage[0].isoformat()}..{coverage[1].isoformat()}"
                        if coverage is not None
                        else f"invalid declared coverage {declared_start_raw}..{declared_end_raw}"
                    )
                    issues.append(
                        _issue(
                            "calendar_news_coverage_mismatch",
                            f"{role or f'source {ordinal}'} coverage mismatch: {detail}",
                            ea_id=ea_id,
                            path=artifact,
                        )
                    )
                elif as_of is not None and as_of > declared_end:
                    issues.append(
                        _issue(
                            "calendar_news_expired",
                            f"{role} coverage ended {declared_end.isoformat()} before {as_of.isoformat()}",
                            ea_id=ea_id,
                            path=artifact,
                        )
                    )

        if role in by_role:
            issues.append(
                _issue(
                    "calendar_news_contract_invalid",
                    f"duplicate news source role {role!r}",
                    ea_id=ea_id,
                )
            )
        else:
            by_role[role] = (record, artifact, actual_hash)

    if set(declared_roles) != NEWS_FILE_CALENDAR_ROLES:
        issues.append(
            _issue(
                "calendar_news_contract_invalid",
                "news source roles must be exactly " + ", ".join(sorted(NEWS_FILE_CALENDAR_ROLES)),
                ea_id=ea_id,
            )
        )

    for shared_role, common_role in (
        ("SHARED_PRIMARY", "QMDEV1_COMMON_PRIMARY"),
        ("SHARED_SECONDARY", "QMDEV1_COMMON_SECONDARY"),
    ):
        if shared_role not in by_role or common_role not in by_role:
            continue
        shared_record, shared_path, shared_hash = by_role[shared_role]
        common_record, common_path, common_hash = by_role[common_role]
        if (
            shared_record.get("sha256") != common_record.get("sha256")
            or (shared_hash is not None and common_hash is not None and shared_hash != common_hash)
        ):
            issues.append(
                _issue(
                    "calendar_news_copy_drift",
                    f"{shared_role} and {common_role} are not byte-equal",
                    ea_id=ea_id,
                    path=f"{shared_path} | {common_path}",
                )
            )

    runtime_patterns = {
        "temporal default": r"\bqm_news_temporal\s*=\s*QM_NEWS_TEMPORAL_PRE30_POST30\s*;",
        "compliance default": r"\bqm_news_compliance\s*=\s*QM_NEWS_COMPLIANCE_FTMO\s*;",
        "stale horizon default": r"\bqm_news_stale_max_hours\s*=\s*336\s*;",
        "impact default": r'\bqm_news_min_impact\s*=\s*"high"\s*;',
        # Accept both the bare single-statement guard (``)) return;``) and the
        # richer braced fail-closed block (``)) { block_reason=...; return ...; }``)
        # used by real EAs. The ``[^{}]*`` body cannot cross a brace, so an entry
        # branch that opens ``{`` but never returns is still correctly flagged.
        "entry fail-closed call": r"if\s*\(\s*!Strategy_EntryNewsAllows\s*\([^)]*\)\s*\)\s*(?:\{[^{}]*)?return\b",
        "initialization fail-closed call": r"if\s*\(\s*!QM_FrameworkInit\s*\(.*?\)\s*\)\s*return\s+INIT_FAILED\s*;",
    }
    missing_runtime = [
        label
        for label, pattern in runtime_patterns.items()
        if not re.search(pattern, text, re.DOTALL)
    ]
    if missing_runtime:
        issues.append(
            _issue(
                "runtime_news_policy_mismatch",
                "runtime lacks exact news policy binding: " + ", ".join(missing_runtime),
                ea_id=ea_id,
                path=source,
            )
        )

    return issues


def _resolve_ref(path_ref: str, repo_root: Path) -> Path:
    path = Path(path_ref)
    return path if path.is_absolute() else repo_root / path


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _card_ea_id(raw: str) -> int | None:
    match = re.fullmatch(r"(?:QM5_)?([1-9][0-9]*)", raw.strip(), re.IGNORECASE)
    return int(match.group(1)) if match else None


def _status_reason(prefix: str, value: object) -> str:
    token = re.sub(r"[^a-z0-9]+", "_", str(value).casefold()).strip("_") or "missing"
    return f"{prefix}_{token}_not_approved"


def _lint_card_binding(
    contract: dict[str, Any],
    *,
    repo_root: Path,
    promotion_status: str,
    promotion_reasons: set[str],
) -> list[Issue]:
    binding = contract.get("card_binding")
    if binding is None:
        return []

    ea_id = int(contract["ea_id"])
    issues: list[Issue] = []
    if not isinstance(binding, dict):
        return [_issue("card_binding_invalid", "card_binding must be an object", ea_id=ea_id)]
    required = (
        "ea_id",
        "slug",
        "timeframe",
        "variant_id",
        "status",
        "execution_contract_status",
    )
    binding_issues = _require_keys(binding, required, ea_id)
    issues.extend(binding_issues)
    if binding_issues:
        return issues

    expected = {
        "ea_id": ea_id,
        "slug": str(contract["slug"]),
        "timeframe": str(contract["strategy_timeframe"]),
        "variant_id": contract.get("variant_id"),
    }
    for field, expected_value in expected.items():
        if binding.get(field) != expected_value:
            issues.append(
                _issue(
                    "card_binding_contract_mismatch",
                    f"card_binding.{field}={binding.get(field)!r} != contract {expected_value!r}",
                    ea_id=ea_id,
                )
            )

    card_ref = str(contract["card_ref"])
    if card_ref == "MISSING_CANONICAL_APPROVED_CARD":
        issues.append(
            _issue(
                "card_binding_missing_card",
                "a structured card binding cannot target the missing-card sentinel",
                ea_id=ea_id,
            )
        )
        return issues

    card = _resolve_ref(card_ref, repo_root)
    issues.extend(lint_card_v2(card, contract))
    if card.exists():
        card_text = card.read_text(encoding="utf-8-sig", errors="replace")
        frontmatter = _flat_frontmatter(card_text)
        card_values: dict[str, object] = {
            "ea_id": _card_ea_id(frontmatter.get("ea_id", "")),
            "slug": frontmatter.get("slug"),
            "timeframe": frontmatter.get("timeframe"),
            "variant_id": frontmatter.get("variant_id"),
            "status": frontmatter.get("status"),
            "execution_contract_status": frontmatter.get("execution_contract_status"),
        }
        for field in required:
            if card_values[field] != binding.get(field):
                issues.append(
                    _issue(
                        "card_binding_frontmatter_mismatch",
                        f"Card {field}={card_values[field]!r} != binding {binding.get(field)!r}",
                        ea_id=ea_id,
                        path=card,
                    )
                )

    for field, reason_prefix in (
        ("status", "card_status"),
        ("execution_contract_status", "card_execution_contract_status"),
    ):
        value = binding.get(field)
        reason = _status_reason(reason_prefix, value)
        if str(value).upper() != "APPROVED":
            if promotion_status != "BLOCKED":
                issues.append(
                    _issue(
                        "unapproved_card_binding_not_blocked",
                        f"card_binding.{field}={value!r} requires BLOCKED promotion",
                        ea_id=ea_id,
                    )
                )
            if reason not in promotion_reasons:
                issues.append(
                    _issue(
                        "card_binding_block_reason_missing",
                        f"promotion reasons must include {reason}",
                        ea_id=ea_id,
                    )
                )
        elif reason in promotion_reasons:
            issues.append(
                _issue(
                    "card_binding_block_reason_stale",
                    f"approved Card binding retains stale reason {reason}",
                    ea_id=ea_id,
                )
            )
    return issues


def _lint_dependency_file(
    dependency: dict[str, Any],
    *,
    repo_root: Path,
    ea_id: int,
) -> list[Issue]:
    """Verify bound bytes; BLOCKED may omit bytes, but cannot bind false bytes."""

    qualification = dependency.get("qualification_status")
    path_ref = dependency.get("path")
    expected_hash = dependency.get("sha256")
    if qualification == "PASS" and (not isinstance(path_ref, str) or not path_ref):
        return [
            _issue(
                "dependency_path_missing",
                f"PASS dependency {dependency.get('dependency_id')!r} requires a path",
                ea_id=ea_id,
            )
        ]
    if qualification != "PASS" and (
        not isinstance(path_ref, str)
        or not path_ref
        or expected_hash is None
    ):
        return []
    path = _resolve_ref(path_ref, repo_root)
    if not path.is_file():
        return [
            _issue(
                "dependency_file_missing",
                f"bound dependency {dependency.get('dependency_id')!r} does not exist",
                ea_id=ea_id,
                path=path,
            )
        ]
    if not isinstance(expected_hash, str) or not SHA256_RE.fullmatch(expected_hash):
        return [
            _issue(
                "dependency_hash_invalid",
                f"PASS dependency {dependency.get('dependency_id')!r} requires sha256",
                ea_id=ea_id,
                path=path,
            )
        ]
    actual_hash = _sha256_file(path)
    if actual_hash != expected_hash:
        return [
            _issue(
                "dependency_hash_mismatch",
                f"dependency {dependency.get('dependency_id')!r} hash differs from contract",
                ea_id=ea_id,
                path=path,
            )
        ]
    return []


def _lint_data_dependencies(
    contract: dict[str, Any],
    *,
    repo_root: Path,
    as_of: date | None,
    promotion_status: str,
    promotion_reasons: set[str],
) -> list[Issue]:
    dependencies = contract.get("data_dependencies")
    if dependencies is None:
        return []
    ea_id = int(contract["ea_id"])
    if not isinstance(dependencies, list) or not dependencies:
        return [
            _issue(
                "data_dependencies_invalid",
                "data_dependencies must be a non-empty list",
                ea_id=ea_id,
            )
        ]

    issues: list[Issue] = []
    seen_ids: set[str] = set()
    for dependency in dependencies:
        if not isinstance(dependency, dict):
            issues.append(
                _issue("data_dependency_invalid", "each dependency must be an object", ea_id=ea_id)
            )
            continue
        required = (
            "dependency_id",
            "type",
            "qualification_status",
            "required_for",
            "block_reason",
        )
        missing = _require_keys(dependency, required, ea_id)
        issues.extend(missing)
        if missing:
            continue
        dependency_id = str(dependency["dependency_id"])
        if not DEPENDENCY_ID_RE.fullmatch(dependency_id):
            issues.append(
                _issue(
                    "data_dependency_id_invalid",
                    f"invalid dependency_id: {dependency_id!r}",
                    ea_id=ea_id,
                )
            )
        if dependency_id in seen_ids:
            issues.append(
                _issue(
                    "data_dependency_duplicate",
                    f"duplicate dependency_id: {dependency_id}",
                    ea_id=ea_id,
                )
            )
        seen_ids.add(dependency_id)

        dependency_type = str(dependency["type"])
        qualification = str(dependency["qualification_status"])
        required_for = dependency["required_for"]
        block_reason = dependency["block_reason"]
        if dependency_type not in DATA_DEPENDENCY_TYPES:
            issues.append(
                _issue(
                    "data_dependency_type_invalid",
                    f"invalid dependency type: {dependency_type}",
                    ea_id=ea_id,
                )
            )
        if qualification not in QUALIFICATION_STATUSES:
            issues.append(
                _issue(
                    "data_dependency_qualification_invalid",
                    f"invalid dependency qualification: {qualification}",
                    ea_id=ea_id,
                )
            )
        if (
            not isinstance(required_for, list)
            or not required_for
            or any(item not in DEPENDENCY_REQUIRED_FOR for item in required_for)
        ):
            issues.append(
                _issue(
                    "data_dependency_required_for_invalid",
                    f"invalid required_for on {dependency_id}",
                    ea_id=ea_id,
                )
            )

        if qualification == "PASS":
            if block_reason is not None:
                issues.append(
                    _issue(
                        "data_dependency_pass_has_block_reason",
                        f"PASS dependency {dependency_id} cannot retain a block reason",
                        ea_id=ea_id,
                    )
                )
        else:
            if not isinstance(block_reason, str) or not block_reason:
                issues.append(
                    _issue(
                        "data_dependency_block_reason_missing",
                        f"unqualified dependency {dependency_id} requires a block reason",
                        ea_id=ea_id,
                    )
                )
            elif block_reason not in promotion_reasons:
                issues.append(
                    _issue(
                        "data_dependency_promotion_reason_missing",
                        f"promotion reasons must include {block_reason}",
                        ea_id=ea_id,
                    )
                )
            if promotion_status == "ELIGIBLE":
                issues.append(
                    _issue(
                        "unqualified_dependency_promotable",
                        f"unqualified dependency {dependency_id} cannot be promotion-eligible",
                        ea_id=ea_id,
                    )
                )
            if qualification == "BLOCKED" and promotion_status != "BLOCKED":
                issues.append(
                    _issue(
                        "blocked_dependency_not_blocked",
                        f"BLOCKED dependency {dependency_id} requires BLOCKED promotion",
                        ea_id=ea_id,
                    )
                )

        if dependency_type == "calendar":
            calendar_missing = _require_keys(
                dependency,
                ("source_ref", "calendar_policy", "stale_behavior"),
                ea_id,
            )
            issues.extend(calendar_missing)
        if dependency_type in {"calendar", "artifact"} and "path" in dependency:
            issues.extend(
                _lint_dependency_file(dependency, repo_root=repo_root, ea_id=ea_id)
            )
        if dependency_type == "artifact":
            artifact_missing = _require_keys(dependency, ("path", "sha256"), ea_id)
            issues.extend(artifact_missing)
        if dependency_type == "signal_anchor":
            signal_missing = _require_keys(
                dependency,
                ("symbol", "timeframe", "order_allowed"),
                ea_id,
            )
            issues.extend(signal_missing)
            if dependency.get("order_allowed") is not False:
                issues.append(
                    _issue(
                        "signal_anchor_order_forbidden",
                        f"signal anchor {dependency_id} must set order_allowed=false",
                        ea_id=ea_id,
                    )
                )
            if not isinstance(dependency.get("symbol"), str) or not CONTRACT_SYMBOL_RE.fullmatch(
                str(dependency.get("symbol"))
            ):
                issues.append(
                    _issue(
                        "signal_anchor_symbol_invalid",
                        f"signal anchor {dependency_id} must use a literal .DWX symbol",
                        ea_id=ea_id,
                    )
                )
            if dependency.get("timeframe") not in TIMEFRAMES:
                issues.append(
                    _issue(
                        "signal_anchor_timeframe_invalid",
                        f"signal anchor {dependency_id} has invalid timeframe",
                        ea_id=ea_id,
                    )
                )
        if dependency_type == "session_metadata":
            session_missing = _require_keys(
                dependency,
                ("metadata_kind", "source_ref"),
                ea_id,
            )
            issues.extend(session_missing)
            if dependency.get("metadata_kind") not in SESSION_METADATA_KINDS:
                issues.append(
                    _issue(
                        "session_metadata_kind_invalid",
                        f"session metadata {dependency_id} has invalid metadata_kind",
                        ea_id=ea_id,
                    )
                )

        coverage_start = dependency.get("coverage_start")
        coverage_end = dependency.get("coverage_end")
        if coverage_start is not None or coverage_end is not None:
            try:
                start_date = date.fromisoformat(str(coverage_start))
                end_date = date.fromisoformat(str(coverage_end))
            except ValueError:
                issues.append(
                    _issue(
                        "data_dependency_coverage_invalid",
                        f"dependency {dependency_id} has invalid coverage dates",
                        ea_id=ea_id,
                    )
                )
            else:
                if start_date > end_date:
                    issues.append(
                        _issue(
                            "data_dependency_coverage_invalid",
                            f"dependency {dependency_id} coverage starts after it ends",
                            ea_id=ea_id,
                        )
                    )
                if qualification == "PASS" and as_of is not None and as_of > end_date:
                    issues.append(
                        _issue(
                            "data_dependency_expired",
                            f"qualified dependency {dependency_id} expired {end_date.isoformat()}",
                            ea_id=ea_id,
                        )
                    )
    return issues


def _parse_setfile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.split("||", 1)[0].strip()
    return values


def _lint_runtime_binding(
    contract: dict[str, Any],
    *,
    repo_root: Path,
    source: Path,
    source_text: str,
) -> list[Issue]:
    binding = contract.get("runtime_binding")
    if binding is None:
        return []
    ea_id = int(contract["ea_id"])
    if not isinstance(binding, dict):
        return [_issue("runtime_binding_invalid", "runtime_binding must be an object", ea_id=ea_id)]
    required = ("qm_ea_id", "magic_slot_offset", "setfile", "setfile_sha256")
    issues = _require_keys(binding, required, ea_id)
    if issues:
        return issues

    qm_ea_id = binding.get("qm_ea_id")
    slot = binding.get("magic_slot_offset")
    if qm_ea_id != ea_id:
        issues.append(
            _issue(
                "runtime_qm_ea_id_contract_mismatch",
                f"runtime_binding.qm_ea_id={qm_ea_id!r} != contract ea_id {ea_id}",
                ea_id=ea_id,
            )
        )
    if not isinstance(slot, int) or isinstance(slot, bool) or slot < 0:
        issues.append(
            _issue("runtime_magic_slot_invalid", "magic_slot_offset must be a non-negative integer", ea_id=ea_id)
        )

    source_ea = re.search(
        r"\binput\s+(?:int|long)\s+qm_ea_id\s*=\s*([0-9]+)\s*;",
        source_text,
    )
    if source_ea is None:
        issues.append(
            _issue("runtime_qm_ea_id_missing", "source input qm_ea_id default is missing", ea_id=ea_id, path=source)
        )
    elif int(source_ea.group(1)) != ea_id:
        issues.append(
            _issue(
                "runtime_qm_ea_id_mismatch",
                f"source qm_ea_id={source_ea.group(1)} != contract ea_id {ea_id}",
                ea_id=ea_id,
                path=source,
            )
        )
    if not re.search(
        r"\binput\s+(?:int|long)\s+qm_magic_slot_offset\s*=\s*[0-9]+\s*;",
        source_text,
    ):
        issues.append(
            _issue(
                "runtime_magic_slot_input_missing",
                "source input qm_magic_slot_offset default is missing",
                ea_id=ea_id,
                path=source,
            )
        )

    variant_id = contract.get("variant_id")
    source_variant = re.search(
        r"\b(?P<storage>input|const)\s+string\s+strategy_variant_id\s*=\s*"
        r'"(?P<value>[A-Z][A-Z0-9_]*)"\s*;',
        source_text,
    )
    if source_variant is None:
        issues.append(
            _issue(
                "runtime_variant_id_missing",
                "source must bind strategy_variant_id as an input or const string",
                ea_id=ea_id,
                path=source,
            )
        )
    elif source_variant.group("value") != variant_id:
        issues.append(
            _issue(
                "runtime_variant_id_mismatch",
                f"source variant {source_variant.group('value')!r} != contract {variant_id!r}",
                ea_id=ea_id,
                path=source,
            )
        )

    friday = contract.get("friday_close", {})
    if isinstance(friday, dict) and friday.get("enabled") is True:
        source_hour = re.search(
            r"\binput\s+int\s+qm_friday_close_hour(?:_broker)?\s*=\s*([0-9]+)\s*;",
            source_text,
        )
        if source_hour is None:
            issues.append(
                _issue(
                    "runtime_friday_hour_missing",
                    "enabled Friday contract requires a source broker-hour input",
                    ea_id=ea_id,
                    path=source,
                )
            )
        elif int(source_hour.group(1)) != friday.get("hour_broker"):
            issues.append(
                _issue(
                    "runtime_friday_hour_mismatch",
                    "source Friday broker hour differs from contract",
                    ea_id=ea_id,
                    path=source,
                )
            )

    setfile = _resolve_ref(str(binding["setfile"]), repo_root)
    if not setfile.is_file():
        issues.append(_issue("runtime_setfile_missing", "bound setfile does not exist", ea_id=ea_id, path=setfile))
        return issues
    expected_hash = binding.get("setfile_sha256")
    actual_hash = _sha256_file(setfile)
    if not isinstance(expected_hash, str) or not SHA256_RE.fullmatch(expected_hash):
        issues.append(_issue("runtime_setfile_hash_invalid", "setfile_sha256 is invalid", ea_id=ea_id, path=setfile))
    elif actual_hash != expected_hash:
        issues.append(_issue("runtime_setfile_hash_mismatch", "setfile hash differs from contract", ea_id=ea_id, path=setfile))

    try:
        _identity_ea, symbol, timeframe, _variant = execution_contract_identity(contract)
    except ValueError:
        symbol = timeframe = None
    expected_prefix = f"QM5_{ea_id}_{contract['slug']}_"
    if not setfile.name.startswith(expected_prefix):
        issues.append(
            _issue("runtime_setfile_identity_mismatch", "setfile name does not match EA identity", ea_id=ea_id, path=setfile)
        )
    if symbol is not None and timeframe is not None and f"_{symbol}_{timeframe}_" not in setfile.name:
        issues.append(
            _issue("runtime_setfile_sleeve_mismatch", "setfile name does not match sleeve symbol/timeframe", ea_id=ea_id, path=setfile)
        )

    set_values = _parse_setfile(setfile)
    if set_values.get("qm_ea_id") != str(ea_id):
        issues.append(
            _issue("runtime_setfile_ea_id_mismatch", "setfile qm_ea_id differs from contract", ea_id=ea_id, path=setfile)
        )
    if isinstance(slot, int) and set_values.get("qm_magic_slot_offset") != str(slot):
        issues.append(
            _issue("runtime_setfile_slot_mismatch", "setfile magic slot differs from contract", ea_id=ea_id, path=setfile)
        )
    if (
        source_variant is not None
        and source_variant.group("storage") == "input"
        and set_values.get("strategy_variant_id") != str(variant_id)
    ):
        issues.append(
            _issue(
                "runtime_setfile_variant_mismatch",
                "setfile strategy_variant_id differs from contract",
                ea_id=ea_id,
                path=setfile,
            )
        )

    magic_ref = str(binding.get("magic_registry", "framework/registry/magic_numbers.csv"))
    magic_registry = _resolve_ref(magic_ref, repo_root)
    try:
        with magic_registry.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except OSError as exc:
        issues.append(
            _issue("runtime_magic_registry_missing", str(exc), ea_id=ea_id, path=magic_registry)
        )
        return issues
    matching_rows = [
        row
        for row in rows
        if row.get("ea_id") == str(ea_id)
        and row.get("symbol_slot") == str(slot)
        and row.get("symbol") == symbol
    ]
    if len(matching_rows) != 1:
        issues.append(
            _issue(
                "runtime_magic_registry_binding_missing",
                f"expected one active magic row for ea_id={ea_id}, slot={slot}, symbol={symbol}; found {len(matching_rows)}",
                ea_id=ea_id,
                path=magic_registry,
            )
        )
    else:
        row = matching_rows[0]
        expected_magic = ea_id * 10000 + int(slot)
        if row.get("status", "").casefold() != "active":
            issues.append(
                _issue("runtime_magic_registry_inactive", "bound magic row is not active", ea_id=ea_id, path=magic_registry)
            )
        if row.get("magic") != str(expected_magic):
            issues.append(
                _issue("runtime_magic_number_mismatch", f"magic must equal {expected_magic}", ea_id=ea_id, path=magic_registry)
            )
    return issues


def lint_contract(
    contract: dict[str, Any],
    *,
    repo_root: Path = REPO_ROOT,
    as_of: date | None = None,
) -> list[Issue]:
    issues: list[Issue] = []
    ea_id_raw = contract.get("ea_id")
    ea_id = ea_id_raw if isinstance(ea_id_raw, int) else None
    issues.extend(
        _require_keys(
            contract,
            (
                "ea_id",
                "slug",
                "card_ref",
                "source",
                "strategy_timeframe",
                "bar_gate_timeframe",
                "friday_close",
                "calendar",
                "promotion",
            ),
            ea_id,
        )
    )
    if issues:
        return issues

    strategy_tf = str(contract["strategy_timeframe"])
    gate_tf = str(contract["bar_gate_timeframe"])
    try:
        (
            _identity_ea,
            identity_symbol,
            identity_tf,
            _identity_variant,
        ) = execution_contract_identity(contract)
    except ValueError as exc:
        issues.append(
            _issue(
                "contract_identity_invalid",
                str(exc),
                ea_id=ea_id,
            )
        )
        identity_symbol = identity_tf = None
    if strategy_tf not in TIMEFRAMES:
        issues.append(_issue("timeframe_invalid", f"invalid strategy_timeframe: {strategy_tf}", ea_id=ea_id))
    if gate_tf not in TIMEFRAMES:
        issues.append(_issue("timeframe_invalid", f"invalid bar_gate_timeframe: {gate_tf}", ea_id=ea_id))
    if strategy_tf != gate_tf:
        issues.append(
            _issue(
                "timeframe_gate_mismatch",
                f"strategy timeframe {strategy_tf} != bar gate {gate_tf}",
                ea_id=ea_id,
            )
        )
    if identity_tf is not None and identity_tf != strategy_tf:
        issues.append(
            _issue(
                "contract_identity_timeframe_mismatch",
                f"sleeve identity timeframe {identity_tf} != strategy timeframe {strategy_tf}",
                ea_id=ea_id,
            )
        )

    friday = contract["friday_close"]
    if not isinstance(friday, dict):
        issues.append(_issue("friday_contract_invalid", "friday_close must be an object", ea_id=ea_id))
        return issues
    issues.extend(
        _require_keys(
            friday,
            ("enabled", "hour_broker", "mode", "declaration", "qualification_status"),
            ea_id,
        )
    )
    if issues:
        return issues

    mode = str(friday["mode"])
    qualification = str(friday["qualification_status"])
    enabled = friday["enabled"]
    hour = friday["hour_broker"]
    declaration = str(friday["declaration"])
    if mode not in FRIDAY_MODES:
        issues.append(_issue("friday_mode_invalid", f"invalid Friday mode: {mode}", ea_id=ea_id))
    if qualification not in QUALIFICATION_STATUSES:
        issues.append(_issue("friday_qualification_invalid", f"invalid status: {qualification}", ea_id=ea_id))
    if mode == "DISABLED" and (enabled is not False or hour is not None):
        issues.append(_issue("friday_disabled_mismatch", "DISABLED requires enabled=false and hour=null", ea_id=ea_id))
    if mode != "DISABLED" and (enabled is not True or not isinstance(hour, int) or not 0 <= hour <= 23):
        issues.append(_issue("friday_enabled_mismatch", "enabled Friday modes require a broker hour 0..23", ea_id=ea_id))
    if mode == "FRAMEWORK_OVERRIDE" and not declaration:
        issues.append(_issue("friday_override_reason_missing", "framework override requires a declaration", ea_id=ea_id))
    if mode == "CARD_RULE" and not friday.get("card_evidence"):
        issues.append(_issue("friday_card_evidence_missing", "CARD_RULE requires card evidence", ea_id=ea_id))

    promotion = contract["promotion"]
    if not isinstance(promotion, dict):
        issues.append(_issue("promotion_invalid", "promotion must be an object", ea_id=ea_id))
        return issues
    promotion_status = str(promotion.get("status", ""))
    reasons = promotion.get("block_reasons")
    if promotion_status not in PROMOTION_STATUSES:
        issues.append(_issue("promotion_status_invalid", f"invalid promotion status: {promotion_status}", ea_id=ea_id))
    if not isinstance(reasons, list):
        issues.append(_issue("promotion_reasons_invalid", "block_reasons must be a list", ea_id=ea_id))
    elif promotion_status != "ELIGIBLE" and not reasons:
        issues.append(_issue("promotion_reason_missing", "non-eligible contract requires block reasons", ea_id=ea_id))
    elif promotion_status == "ELIGIBLE" and reasons:
        issues.append(
            _issue(
                "eligible_contract_has_block_reasons",
                "an eligible contract cannot retain promotion block reasons",
                ea_id=ea_id,
            )
        )
    if qualification == "BLOCKED" and promotion_status != "BLOCKED":
        issues.append(
            _issue(
                "blocked_friday_contract_not_blocked",
                "a BLOCKED Friday execution contract requires BLOCKED promotion",
                ea_id=ea_id,
            )
        )
    if (
        isinstance(reasons, list)
        and any(str(reason).startswith(UNRESOLVED_SEMANTIC_CONFLICT_PREFIX) for reason in reasons)
        and promotion_status != "BLOCKED"
    ):
        issues.append(
            _issue(
                "unresolved_semantic_conflict_not_blocked",
                "an unresolved Card/runtime semantic conflict requires BLOCKED promotion",
                ea_id=ea_id,
            )
        )
    if mode == "FRAMEWORK_OVERRIDE" and qualification != "PASS" and promotion_status == "ELIGIBLE":
        issues.append(
            _issue(
                "unqualified_override_promotable",
                "an unqualified framework override cannot be promotion-eligible",
                ea_id=ea_id,
            )
        )
    if contract["card_ref"] == "MISSING_CANONICAL_APPROVED_CARD" and promotion_status != "BLOCKED":
        issues.append(_issue("missing_card_not_blocked", "missing canonical Card must block promotion", ea_id=ea_id))

    reason_set = {str(item) for item in reasons} if isinstance(reasons, list) else set()
    if contract.get("runtime_binding") is not None and contract.get("card_binding") is None:
        issues.append(
            _issue(
                "runtime_binding_card_binding_missing",
                "runtime_binding requires an exact card_binding",
                ea_id=ea_id,
            )
        )
    if contract.get("data_dependencies") is not None:
        missing_bindings = [
            field
            for field in ("card_binding", "runtime_binding")
            if contract.get(field) is None
        ]
        if missing_bindings:
            issues.append(
                _issue(
                    "data_dependencies_binding_missing",
                    "data_dependencies require " + ", ".join(missing_bindings),
                    ea_id=ea_id,
                )
            )
    issues.extend(
        _lint_card_binding(
            contract,
            repo_root=repo_root,
            promotion_status=promotion_status,
            promotion_reasons=reason_set,
        )
    )
    issues.extend(
        _lint_data_dependencies(
            contract,
            repo_root=repo_root,
            as_of=as_of,
            promotion_status=promotion_status,
            promotion_reasons=reason_set,
        )
    )

    legacy_routing = contract.get("darwinex_zero_routing")
    routing = contract.get("symbol_routing")
    if legacy_routing is not None and routing is not None:
        issues.append(
            _issue(
                "symbol_routing_duplicate",
                "declare symbol_routing or darwinex_zero_routing, not both",
                ea_id=ea_id,
            )
        )
    if routing is None:
        routing = legacy_routing
    if routing is not None:
        if not isinstance(routing, dict):
            issues.append(
                _issue(
                    "dxz_routing_contract_invalid",
                    "symbol routing must be an object",
                    ea_id=ea_id,
                )
            )
        else:
            routing_issues = _require_keys(
                routing,
                (
                    "test_symbol",
                    "live_order_symbol",
                    "status",
                    "source_registry",
                    "evidence_ref",
                    "automatic_symbol_inference",
                    "qualification_status",
                    "full_requalification_required",
                ),
                ea_id,
            )
            issues.extend(routing_issues)
            if not routing_issues:
                test_symbol = str(routing["test_symbol"]).strip().upper()
                live_symbol = str(routing["live_order_symbol"]).strip().upper()
                routing_status = str(routing["status"])
                routing_qualification = str(routing["qualification_status"])
                evidence_ref = str(routing["evidence_ref"]).strip().replace("\\", "/")
                source_registry = Path(str(routing["source_registry"]))
                matrix = source_registry if source_registry.is_absolute() else repo_root / source_registry
                if identity_symbol is not None and test_symbol != identity_symbol:
                    issues.append(
                        _issue(
                            "dxz_alias_contract_symbol_mismatch",
                            f"routing test symbol {test_symbol} != contract symbol {identity_symbol}",
                            ea_id=ea_id,
                        )
                    )
                routes, matrix_error = load_symbol_routing_rows(matrix)
                if matrix_error:
                    issues.append(
                        _issue(
                            "dxz_routing_matrix_invalid",
                            matrix_error,
                            ea_id=ea_id,
                            path=matrix,
                        )
                    )
                else:
                    matrix_route = routes.get(test_symbol)
                    if matrix_route is None:
                        issues.append(
                            _issue(
                                "dxz_alias_route_missing",
                                f"{test_symbol} has no explicit live-symbol route in the matrix",
                                ea_id=ea_id,
                                path=matrix,
                            )
                        )
                    else:
                        matrix_live = str(matrix_route.get("live_order_symbol") or "").upper()
                        matrix_status = str(matrix_route.get("live_order_status") or "").upper()
                        matrix_evidence = str(matrix_route.get("routing_evidence_ref") or "").replace(
                            "\\", "/"
                        )
                        if matrix_live != live_symbol:
                            issues.append(
                                _issue(
                                    "dxz_alias_live_symbol_mismatch",
                                    f"matrix maps {test_symbol} to {matrix_live}, contract maps to {live_symbol}",
                                    ea_id=ea_id,
                                    path=matrix,
                                )
                            )
                        if matrix_status != MATRIX_ORDER_ROUTABLE_STATUS:
                            issues.append(
                                _issue(
                                    "dxz_alias_routability_unconfirmed",
                                    f"matrix status {matrix_status!r} is not {MATRIX_ORDER_ROUTABLE_STATUS}",
                                    ea_id=ea_id,
                                    path=matrix,
                                )
                            )
                        if matrix_evidence != evidence_ref:
                            issues.append(
                                _issue(
                                    "dxz_alias_evidence_mismatch",
                                    "matrix and execution contract bind different routing evidence",
                                    ea_id=ea_id,
                                    path=matrix,
                                )
                            )

                blocked_symbols, blocked_matrix_error = load_non_order_routable_symbols(matrix)
                if blocked_matrix_error:
                    issues.append(
                        _issue(
                            "dxz_routing_matrix_invalid",
                            blocked_matrix_error,
                            ea_id=ea_id,
                            path=matrix,
                        )
                    )
                elif test_symbol in blocked_symbols:
                    issues.append(
                        _issue(
                            "dxz_alias_routability_contradiction",
                            f"{test_symbol} is both explicitly routed and explicitly non-order-routable",
                            ea_id=ea_id,
                            path=matrix,
                        )
                    )

                if not test_symbol.endswith(".DWX"):
                    issues.append(
                        _issue(
                            "dxz_alias_test_symbol_invalid",
                            "test_symbol must be a literal .DWX symbol",
                            ea_id=ea_id,
                        )
                    )
                if not live_symbol or live_symbol.endswith(".DWX") or live_symbol == test_symbol:
                    issues.append(
                        _issue(
                            "dxz_alias_live_symbol_invalid",
                            "live_order_symbol must be explicit and distinct from the .DWX test alias",
                            ea_id=ea_id,
                        )
                    )
                if routing_status != ROUTING_STATUS:
                    issues.append(
                        _issue(
                            "dxz_routing_status_invalid",
                            f"routing status must be {ROUTING_STATUS}",
                            ea_id=ea_id,
                        )
                    )
                if routing["automatic_symbol_inference"] is not False:
                    issues.append(
                        _issue(
                            "dxz_automatic_symbol_inference_forbidden",
                            "the live order symbol must never be inferred from a test alias",
                            ea_id=ea_id,
                        )
                    )
                if routing_qualification not in ROUTING_QUALIFICATION_STATUSES:
                    issues.append(
                        _issue(
                            "dxz_routing_qualification_invalid",
                            f"invalid routing qualification: {routing_qualification}",
                            ea_id=ea_id,
                        )
                    )
                if routing["full_requalification_required"] is not True:
                    issues.append(
                        _issue(
                            "dxz_full_requalification_missing",
                            "an explicit test-to-live alias requires full requalification",
                            ea_id=ea_id,
                        )
                    )

                evidence_path_ref = Path(str(routing["evidence_ref"]))
                evidence_path = (
                    evidence_path_ref
                    if evidence_path_ref.is_absolute()
                    else repo_root / evidence_path_ref
                )
                if not evidence_path.is_file():
                    issues.append(
                        _issue(
                            "dxz_alias_evidence_missing",
                            "routing evidence document does not exist",
                            ea_id=ea_id,
                            path=evidence_path,
                        )
                    )

                test_token = re.sub(r"[^a-z0-9]+", "_", test_symbol.casefold()).strip("_")
                live_token = re.sub(r"[^a-z0-9]+", "_", live_symbol.casefold()).strip("_")
                requal_reason = f"{test_token}_to_{live_token}_alias_full_requalification_required"
                stale_reasons = sorted(reason_set & STALE_SP500_ROUTING_REASONS)
                if stale_reasons:
                    issues.append(
                        _issue(
                            "dxz_stale_non_routability_block_reason",
                            "order-routable alias retains stale non-routability/substitution reasons",
                            ea_id=ea_id,
                        )
                    )
                if routing_qualification != "PASS":
                    if promotion_status == "ELIGIBLE":
                        issues.append(
                            _issue(
                                "dxz_unqualified_alias_promotable",
                                "an unqualified test-to-live alias cannot be promotion-eligible",
                                ea_id=ea_id,
                            )
                        )
                    if requal_reason not in reason_set:
                        issues.append(
                            _issue(
                                "dxz_alias_requalification_reason_missing",
                                f"promotion reasons must include {requal_reason}",
                                ea_id=ea_id,
                            )
                        )
                elif requal_reason in reason_set:
                    issues.append(
                        _issue(
                            "dxz_alias_requalification_reason_stale",
                            "qualified alias retains a completed requalification reason",
                            ea_id=ea_id,
                        )
                    )
                if routing_qualification == "BLOCKED" and promotion_status != "BLOCKED":
                    issues.append(
                        _issue(
                            "dxz_blocked_alias_not_blocked",
                            "a BLOCKED alias qualification requires BLOCKED promotion",
                            ea_id=ea_id,
                        )
                    )

    source = repo_root / Path(str(contract["source"]))
    if not source.exists():
        issues.append(_issue("ea_source_missing", "EA source does not exist", ea_id=ea_id, path=source))
        return issues
    text = source.read_text(encoding="utf-8-sig", errors="replace")
    expected_stem = f"QM5_{ea_id}_{contract['slug']}"
    if source.stem != expected_stem:
        issues.append(
            _issue(
                "ea_source_identity_mismatch",
                f"source stem {source.stem!r} != {expected_stem!r}",
                ea_id=ea_id,
                path=source,
            )
        )

    issues.extend(
        _lint_runtime_binding(
            contract,
            repo_root=repo_root,
            source=source,
            source_text=text,
        )
    )

    calls = [match.groupdict() for match in EXECUTION_CALL_RE.finditer(text)]
    expected_tf_token = f"PERIOD_{strategy_tf}"
    expected_mode = MODE_TOKENS.get(mode)
    expected_call = {
        "timeframe": expected_tf_token,
        "mode": expected_mode,
        "declaration": declaration,
    }
    matching_calls = [
        call
        for call in calls
        if call["timeframe"] == expected_call["timeframe"]
        and call["mode"] == expected_call["mode"]
        and call["declaration"] == expected_call["declaration"]
    ]
    if len(calls) == 1:
        call = calls[0]
        if call["timeframe"] != expected_tf_token:
            issues.append(
                _issue(
                    "runtime_timeframe_mismatch",
                    f"runtime {call['timeframe']} != contract {expected_tf_token}",
                    ea_id=ea_id,
                    path=source,
                )
            )
        if expected_mode and call["mode"] != expected_mode:
            issues.append(
                _issue(
                    "runtime_friday_mode_mismatch",
                    f"runtime {call['mode']} != contract {expected_mode}",
                    ea_id=ea_id,
                    path=source,
                )
            )
        if call["declaration"] != declaration:
            issues.append(
                _issue(
                    "runtime_declaration_mismatch",
                    "runtime Friday declaration differs from registry",
                    ea_id=ea_id,
                    path=source,
                )
            )
    elif len(matching_calls) != 1:
        issues.append(
            _issue(
                "execution_contract_call_count",
                "expected exactly one runtime declaration matching this sleeve "
                f"({expected_tf_token}, {expected_mode}, {declaration!r}); "
                f"found {len(matching_calls)} among {len(calls)} declaration(s)",
                ea_id=ea_id,
                path=source,
            )
        )

    gate_pattern = re.compile(
        rf"QM_IsNewBar\s*\(\s*_Symbol\s*,\s*PERIOD_{re.escape(gate_tf)}\s*\)"
    )
    if not gate_pattern.search(text):
        issues.append(
            _issue(
                "runtime_bar_gate_missing",
                f"explicit PERIOD_{gate_tf} bar gate is missing",
                ea_id=ea_id,
                path=source,
            )
        )

    friday_input = re.search(r"qm_friday_close_enabled\s*=\s*(true|false)", text)
    if not friday_input:
        issues.append(_issue("runtime_friday_input_missing", "Friday input default not found", ea_id=ea_id, path=source))
    elif (friday_input.group(1) == "true") != bool(enabled):
        issues.append(_issue("runtime_friday_enabled_mismatch", "Friday input default differs from contract", ea_id=ea_id, path=source))

    calendar = contract["calendar"]
    if not isinstance(calendar, dict) or calendar.get("policy") not in {
        "NONE",
        "FIXED_EVENT_TABLE",
        NEWS_FILE_CALENDAR_POLICY,
    }:
        issues.append(_issue("calendar_policy_invalid", "invalid calendar policy", ea_id=ea_id))
    elif calendar.get("policy") == "FIXED_EVENT_TABLE":
        valid_raw = str(calendar.get("valid_through", ""))
        try:
            valid_through = date.fromisoformat(valid_raw)
        except ValueError:
            issues.append(_issue("calendar_valid_through_invalid", f"invalid date: {valid_raw}", ea_id=ea_id))
        else:
            if as_of is not None and as_of > valid_through:
                issues.append(
                    _issue(
                        "calendar_expired",
                        f"calendar expired {valid_through.isoformat()} before {as_of.isoformat()}",
                        ea_id=ea_id,
                        path=source,
                    )
                )
            key = valid_through.strftime("%Y%m%d")
            if not re.search(rf"g_event_calendar_valid_through_key\s*=\s*{key}\b", text):
                issues.append(_issue("runtime_calendar_horizon_mismatch", "MQL calendar horizon differs from registry", ea_id=ea_id, path=source))
            if "SETUP_DATA_STALE" not in text or "Strategy_CalendarCoverageAllows" not in text:
                issues.append(_issue("runtime_calendar_fail_closed_missing", "calendar lacks fail-closed stale guard", ea_id=ea_id, path=source))
    elif calendar.get("policy") == NEWS_FILE_CALENDAR_POLICY:
        issues.extend(
            _lint_ftmo_news_file_calendar(
                calendar,
                text=text,
                source=source,
                repo_root=repo_root,
                as_of=as_of,
                ea_id=ea_id,
            )
        )

    return issues


def lint_registry(
    registry: Path = DEFAULT_REGISTRY,
    *,
    repo_root: Path = REPO_ROOT,
    as_of: date | None = None,
    ea_ids: set[int] | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]], list[Issue]]:
    payload = json.loads(registry.read_text(encoding="utf-8"))
    issues: list[Issue] = []
    if payload.get("schema_version") != 2:
        issues.append(_issue("registry_schema_version", "schema_version must be 2", path=registry))
    contracts = payload.get("contracts")
    if not isinstance(contracts, list):
        return payload, [], issues + [_issue("contracts_invalid", "contracts must be a list", path=registry)]

    selected = [
        item for item in contracts
        if isinstance(item, dict) and (ea_ids is None or item.get("ea_id") in ea_ids)
    ]
    seen_exact: set[tuple[int, str, str, str | None]] = set()
    seen_legacy: set[int] = set()
    exact_eas: set[int] = set()
    for contract in selected:
        ea_id = contract.get("ea_id")
        try:
            identity_ea, symbol, timeframe, variant_id = execution_contract_identity(
                contract
            )
        except ValueError:
            identity_ea = ea_id if isinstance(ea_id, int) else None
            symbol = timeframe = variant_id = None
        else:
            if symbol is None:
                if identity_ea in seen_legacy:
                    issues.append(
                        _issue(
                            "duplicate_legacy_ea_id",
                            "duplicate legacy EA-wide execution contract",
                            ea_id=identity_ea,
                            path=registry,
                        )
                    )
                if identity_ea in exact_eas:
                    issues.append(
                        _issue(
                            "mixed_contract_scope",
                            "one EA cannot mix legacy EA-wide and sleeve-specific contracts",
                            ea_id=identity_ea,
                            path=registry,
                        )
                    )
                seen_legacy.add(identity_ea)
            else:
                exact = (identity_ea, symbol, str(timeframe), variant_id)
                if exact in seen_exact:
                    identity_label = execution_contract_identity_label(contract)
                    issues.append(
                        _issue(
                            "duplicate_sleeve_identity",
                            f"duplicate execution contract for {identity_label}",
                            ea_id=identity_ea,
                            path=registry,
                        )
                    )
                if identity_ea in seen_legacy:
                    issues.append(
                        _issue(
                            "mixed_contract_scope",
                            "one EA cannot mix legacy EA-wide and sleeve-specific contracts",
                            ea_id=identity_ea,
                            path=registry,
                        )
                    )
                seen_exact.add(exact)
                exact_eas.add(identity_ea)
        issues.extend(lint_contract(contract, repo_root=repo_root, as_of=as_of))

    # One source may deliberately expose multiple mutually-exclusive runtime
    # modes.  Every literal declaration still needs a registered sleeve tuple;
    # this prevents the per-sleeve matching allowance above from hiding an
    # unregistered execution path.
    source_contracts: dict[tuple[int, str], list[dict[str, Any]]] = {}
    for contract in selected:
        ea_id = contract.get("ea_id")
        source_raw = contract.get("source")
        if isinstance(ea_id, int) and isinstance(source_raw, str):
            source_contracts.setdefault((ea_id, source_raw), []).append(contract)
    for (ea_id, source_raw), siblings in source_contracts.items():
        source = repo_root / Path(source_raw)
        if not source.exists():
            continue
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        actual_calls = [
            (
                match.group("timeframe"),
                match.group("mode"),
                match.group("declaration"),
            )
            for match in EXECUTION_CALL_RE.finditer(text)
        ]
        expected_calls = {
            (
                f"PERIOD_{item.get('strategy_timeframe')}",
                MODE_TOKENS.get(str(item.get("friday_close", {}).get("mode"))),
                str(item.get("friday_close", {}).get("declaration", "")),
            )
            for item in siblings
        }
        for call in sorted(set(actual_calls) - expected_calls):
            issues.append(
                _issue(
                    "runtime_declaration_unregistered",
                    "runtime declaration has no registered sleeve contract: "
                    f"{call[0]}, {call[1]}, {call[2]!r}",
                    ea_id=ea_id,
                    path=source,
                )
            )
        for call in sorted(set(actual_calls)):
            if actual_calls.count(call) > 1:
                issues.append(
                    _issue(
                        "runtime_declaration_duplicate",
                        "runtime declaration tuple appears more than once: "
                        f"{call[0]}, {call[1]}, {call[2]!r}",
                        ea_id=ea_id,
                        path=source,
                    )
                )
    if ea_ids is not None:
        seen_eas = seen_legacy | exact_eas
        missing = ea_ids - seen_eas
        for ea_id in sorted(missing):
            issues.append(_issue("contract_missing", "requested EA has no execution contract", ea_id=ea_id, path=registry))
    return payload, selected, issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contracts", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--as-of", default=date.today().isoformat())
    parser.add_argument("--ea-id", action="append", type=int)
    parser.add_argument("--require-promotable", action="store_true")
    parser.add_argument("--card", type=Path, help="Optionally lint one Card-v2 Markdown file")
    args = parser.parse_args(argv)

    as_of = date.fromisoformat(args.as_of)
    requested = set(args.ea_id) if args.ea_id else None
    payload, selected, issues = lint_registry(
        args.contracts,
        repo_root=args.repo_root,
        as_of=as_of,
        ea_ids=requested,
    )
    if args.card:
        contract = selected[0] if len(selected) == 1 else None
        issues.extend(lint_card_v2(args.card, contract))

    errors = [item for item in issues if item.severity == "ERROR"]
    blocked = [
        {
            "ea_id": item["ea_id"],
            "symbol": item.get("symbol"),
            "timeframe": item.get("timeframe"),
            "variant_id": item.get("variant_id"),
            "contract_identity": safe_execution_contract_identity_label(item),
            "status": item["promotion"]["status"],
            "reasons": item["promotion"]["block_reasons"],
        }
        for item in selected
        if item.get("promotion", {}).get("status") != "ELIGIBLE"
    ]
    status = "error" if errors else "ok"
    exit_code = 2 if errors else 0
    if not errors and args.require_promotable and blocked:
        status = "blocked"
        exit_code = 3

    print(
        json.dumps(
            {
                "status": status,
                "schema_version": payload.get("schema_version"),
                "book_id": payload.get("book_id"),
                "contracts_checked": len(selected),
                "issues": [asdict(item) for item in issues],
                "promotion_blocks": blocked,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
