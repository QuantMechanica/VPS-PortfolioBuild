"""Append-only governance and experiment record contracts.

This module is deliberately not wired into the factory, database, scheduler, or
pipeline.  It provides the create-new persistence primitive and strict record
validation needed before those systems are allowed to consume governance data.

Record hashes are SHA-256 over canonical UTF-8 JSON of every field except
``record_sha256``.  Canonical JSON uses sorted keys, compact separators, no BOM,
and no trailing newline.  Files add exactly one trailing LF after the complete,
sealed record.
"""

from __future__ import annotations

import copy
import hashlib
import hmac
import json
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping


SOURCE_AUTHORIZATION_V1 = "qm.source-authorization/v1"
G0_DECISION_V1 = "qm.g0-decision/v1"
EXPERIMENT_RECORD_V1 = "qm.experiment-record/v1"
SUPPORTED_SCHEMA_VERSIONS = frozenset(
    {SOURCE_AUTHORIZATION_V1, G0_DECISION_V1, EXPERIMENT_RECORD_V1}
)

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$")
_SYMBOL_RE = re.compile(r"^[A-Z0-9][A-Z0-9._-]{0,31}$")
_TIMEFRAME_RE = re.compile(r"^(?:M[1-9][0-9]*|H[1-9][0-9]*|D1|W1|MN1)$")
_UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$")


class GovernanceRecordError(ValueError):
    """A record violates its immutable governance contract."""


@dataclass(frozen=True)
class WriteReceipt:
    path: Path
    schema_version: str
    record_sha256: str
    size_bytes: int


def _duplicate_key_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise GovernanceRecordError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_floats(value: Any, path: str = "$") -> None:
    if isinstance(value, float):
        raise GovernanceRecordError(f"floating-point JSON value rejected at {path}")
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                raise GovernanceRecordError(f"non-string object key rejected at {path}")
            _reject_floats(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _reject_floats(child, f"{path}[{index}]")


def _canonical_json_bytes(value: Mapping[str, Any], *, file_form: bool) -> bytes:
    _reject_floats(value)
    try:
        encoded = json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise GovernanceRecordError(f"record is not canonical-JSON compatible: {exc}") from exc
    return encoded + (b"\n" if file_form else b"")


def canonical_record_hash(record: Mapping[str, Any]) -> str:
    """Return the content hash, excluding the self-referential hash field."""

    if not isinstance(record, Mapping):
        raise GovernanceRecordError("record root must be an object")
    payload = dict(record)
    payload.pop("record_sha256", None)
    return hashlib.sha256(_canonical_json_bytes(payload, file_form=False)).hexdigest()


def _exact_keys(value: Any, required: set[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise GovernanceRecordError(f"{path} must be an object")
    actual = set(value)
    if actual != required:
        missing = sorted(required - actual)
        extra = sorted(actual - required)
        raise GovernanceRecordError(
            f"{path} key set mismatch; missing={missing}, extra={extra}"
        )
    return value


def _string(value: Any, path: str, *, max_length: int = 4096) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise GovernanceRecordError(f"{path} must be a non-blank, trimmed string")
    if len(value) > max_length:
        raise GovernanceRecordError(f"{path} exceeds {max_length} characters")
    return value


def _optional_string(value: Any, path: str) -> str | None:
    if value is None:
        return None
    return _string(value, path, max_length=128)


def _identifier(value: Any, path: str) -> str:
    candidate = _string(value, path, max_length=128)
    if _IDENTIFIER_RE.fullmatch(candidate) is None:
        raise GovernanceRecordError(f"{path} is not a canonical identifier")
    return candidate


def _sha256(value: Any, path: str) -> str:
    if not isinstance(value, str) or _SHA256_RE.fullmatch(value) is None:
        raise GovernanceRecordError(f"{path} must be a lowercase SHA-256 hex digest")
    return value


def _utc(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or _UTC_RE.fullmatch(value) is None:
        raise GovernanceRecordError(f"{path} must be an RFC3339 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise GovernanceRecordError(f"{path} is not a real timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise GovernanceRecordError(f"{path} must be UTC")
    return parsed


def _integer(value: Any, path: str, *, minimum: int = 1) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise GovernanceRecordError(f"{path} must be an integer >= {minimum}")
    return value


def _verify_record_hash(record: Mapping[str, Any]) -> None:
    supplied = _sha256(record.get("record_sha256"), "$.record_sha256")
    expected = canonical_record_hash(record)
    if not hmac.compare_digest(supplied, expected):
        raise GovernanceRecordError(
            f"record_sha256 mismatch: supplied={supplied}, expected={expected}"
        )


def _validate_source_authorization_shape(record: dict[str, Any]) -> None:
    _exact_keys(
        record,
        {
            "schema_version",
            "authorization_id",
            "source_ref",
            "source_sha256",
            "decision",
            "authority",
            "owner_identity",
            "decided_at_utc",
            "rationale",
            "record_sha256",
        },
        "$",
    )
    if record["schema_version"] != SOURCE_AUTHORIZATION_V1:
        raise GovernanceRecordError("unsupported source authorization schema_version")
    _identifier(record["authorization_id"], "$.authorization_id")
    _string(record["source_ref"], "$.source_ref", max_length=2048)
    _sha256(record["source_sha256"], "$.source_sha256")
    if record["decision"] not in {"AUTHORIZED", "REJECTED"}:
        raise GovernanceRecordError("$.decision must be AUTHORIZED or REJECTED")
    if record["authority"] != "OWNER":
        raise GovernanceRecordError("source authorization requires authority=OWNER")
    _string(record["owner_identity"], "$.owner_identity", max_length=128)
    _utc(record["decided_at_utc"], "$.decided_at_utc")
    _string(record["rationale"], "$.rationale")


def _validate_g0_decision_shape(record: dict[str, Any]) -> None:
    _exact_keys(
        record,
        {
            "schema_version",
            "decision_id",
            "card_id",
            "card_sha256",
            "source_authorization_id",
            "source_sha256",
            "decision",
            "authority",
            "agent_identity",
            "owner_identity",
            "decided_at_utc",
            "rationale",
            "record_sha256",
        },
        "$",
    )
    if record["schema_version"] != G0_DECISION_V1:
        raise GovernanceRecordError("unsupported G0 decision schema_version")
    _identifier(record["decision_id"], "$.decision_id")
    _identifier(record["card_id"], "$.card_id")
    _sha256(record["card_sha256"], "$.card_sha256")
    _identifier(record["source_authorization_id"], "$.source_authorization_id")
    _sha256(record["source_sha256"], "$.source_sha256")
    _utc(record["decided_at_utc"], "$.decided_at_utc")
    _string(record["rationale"], "$.rationale")

    authority = record["authority"]
    decision = record["decision"]
    if authority == "AGENT":
        if decision not in {
            "RECOMMEND_APPROVE",
            "RECOMMEND_REJECT",
            "RECOMMEND_CHANGES_REQUIRED",
        }:
            raise GovernanceRecordError("agents may emit recommendation decisions only")
        _string(record["agent_identity"], "$.agent_identity", max_length=128)
        if record["owner_identity"] is not None:
            raise GovernanceRecordError("agent recommendation owner_identity must be null")
    elif authority == "OWNER":
        if decision not in {"APPROVED", "REJECTED"}:
            raise GovernanceRecordError("OWNER may emit final APPROVED or REJECTED only")
        _string(record["owner_identity"], "$.owner_identity", max_length=128)
        if record["agent_identity"] is not None:
            raise GovernanceRecordError("OWNER decision agent_identity must be null")
    else:
        raise GovernanceRecordError("$.authority must be AGENT or OWNER")


_PARAMETER_CELL_KEYS = {"cell_id", "cell_sha256"}
_DATA_CUT_KEYS = {"cut_id", "dataset_sha256", "cut_at_utc"}
_SEAL_KEYS = {"seal_id", "evidence_sha256", "sealed_at_utc"}
_TRIAL_BUDGET_KEYS = {
    "budget_id",
    "independent_trial_ordinal",
    "independent_trial_limit",
}


def _validate_experiment_shape(record: dict[str, Any]) -> None:
    _exact_keys(
        record,
        {
            "schema_version",
            "experiment_id",
            "independent_trial_id",
            "attempt_id",
            "attempt_kind",
            "retry_of",
            "family_fingerprint",
            "card_sha256",
            "parameter_cell",
            "symbol",
            "timeframe",
            "data_cut",
            "dev_seal",
            "oos_seal",
            "trial_budget",
            "created_at_utc",
            "producer",
            "record_sha256",
        },
        "$",
    )
    if record["schema_version"] != EXPERIMENT_RECORD_V1:
        raise GovernanceRecordError("unsupported experiment record schema_version")
    _identifier(record["experiment_id"], "$.experiment_id")
    _identifier(record["independent_trial_id"], "$.independent_trial_id")
    _identifier(record["attempt_id"], "$.attempt_id")
    _sha256(record["family_fingerprint"], "$.family_fingerprint")
    _sha256(record["card_sha256"], "$.card_sha256")
    _utc(record["created_at_utc"], "$.created_at_utc")

    parameter_cell = _exact_keys(record["parameter_cell"], _PARAMETER_CELL_KEYS, "$.parameter_cell")
    _identifier(parameter_cell["cell_id"], "$.parameter_cell.cell_id")
    _sha256(parameter_cell["cell_sha256"], "$.parameter_cell.cell_sha256")

    symbol = record["symbol"]
    if not isinstance(symbol, str) or _SYMBOL_RE.fullmatch(symbol) is None:
        raise GovernanceRecordError("$.symbol must use the canonical uppercase symbol form")
    timeframe = record["timeframe"]
    if not isinstance(timeframe, str) or _TIMEFRAME_RE.fullmatch(timeframe) is None:
        raise GovernanceRecordError("$.timeframe is not a canonical timeframe")

    data_cut = _exact_keys(record["data_cut"], _DATA_CUT_KEYS, "$.data_cut")
    _identifier(data_cut["cut_id"], "$.data_cut.cut_id")
    _sha256(data_cut["dataset_sha256"], "$.data_cut.dataset_sha256")
    _utc(data_cut["cut_at_utc"], "$.data_cut.cut_at_utc")

    for field in ("dev_seal", "oos_seal"):
        seal = _exact_keys(record[field], _SEAL_KEYS, f"$.{field}")
        _identifier(seal["seal_id"], f"$.{field}.seal_id")
        _sha256(seal["evidence_sha256"], f"$.{field}.evidence_sha256")
        _utc(seal["sealed_at_utc"], f"$.{field}.sealed_at_utc")

    budget = _exact_keys(record["trial_budget"], _TRIAL_BUDGET_KEYS, "$.trial_budget")
    _identifier(budget["budget_id"], "$.trial_budget.budget_id")
    ordinal = _integer(
        budget["independent_trial_ordinal"],
        "$.trial_budget.independent_trial_ordinal",
    )
    limit = _integer(
        budget["independent_trial_limit"],
        "$.trial_budget.independent_trial_limit",
    )
    if ordinal > limit:
        raise GovernanceRecordError("independent trial ordinal exceeds trial budget")

    producer = _exact_keys(record["producer"], {"authority", "identity"}, "$.producer")
    if producer["authority"] not in {"AGENT", "OWNER", "SYSTEM"}:
        raise GovernanceRecordError("$.producer.authority is invalid")
    _string(producer["identity"], "$.producer.identity", max_length=128)

    if record["attempt_kind"] == "ORIGINAL":
        if record["retry_of"] is not None:
            raise GovernanceRecordError("ORIGINAL attempt retry_of must be null")
    elif record["attempt_kind"] == "INFRA_RETRY":
        _identifier(record["retry_of"], "$.retry_of")
    else:
        raise GovernanceRecordError("$.attempt_kind must be ORIGINAL or INFRA_RETRY")


_RETRY_IMMUTABLE_FIELDS = (
    "experiment_id",
    "independent_trial_id",
    "family_fingerprint",
    "card_sha256",
    "parameter_cell",
    "symbol",
    "timeframe",
    "data_cut",
    "dev_seal",
    "oos_seal",
    "trial_budget",
)


def _validated_prior_experiments(
    prior_records: Iterable[Mapping[str, Any]],
) -> dict[str, dict[str, Any]]:
    by_attempt: dict[str, dict[str, Any]] = {}
    for index, candidate in enumerate(prior_records):
        if not isinstance(candidate, Mapping):
            raise GovernanceRecordError(f"prior_records[{index}] must be an object")
        prior = dict(candidate)
        _reject_floats(prior)
        _validate_experiment_shape(prior)
        _verify_record_hash(prior)
        attempt_id = prior["attempt_id"]
        if attempt_id in by_attempt:
            raise GovernanceRecordError(f"duplicate prior attempt_id: {attempt_id}")
        by_attempt[attempt_id] = prior
    return by_attempt


def _validate_experiment_lineage(
    record: dict[str, Any], prior_records: Iterable[Mapping[str, Any]]
) -> None:
    by_attempt = _validated_prior_experiments(prior_records)
    if record["attempt_id"] in by_attempt:
        raise GovernanceRecordError(f"attempt_id already exists: {record['attempt_id']}")

    for prior in by_attempt.values():
        same_budget_slot = (
            prior["experiment_id"] == record["experiment_id"]
            and prior["trial_budget"]["budget_id"] == record["trial_budget"]["budget_id"]
            and prior["trial_budget"]["independent_trial_ordinal"]
            == record["trial_budget"]["independent_trial_ordinal"]
        )
        if same_budget_slot and prior["independent_trial_id"] != record["independent_trial_id"]:
            raise GovernanceRecordError(
                "one experiment budget slot cannot mint multiple independent_trial_id values"
            )

    if record["attempt_kind"] == "ORIGINAL":
        if any(
            prior["independent_trial_id"] == record["independent_trial_id"]
            for prior in by_attempt.values()
        ):
            raise GovernanceRecordError(
                "existing independent_trial_id must continue as INFRA_RETRY, not ORIGINAL"
            )
        return

    retry_of = record["retry_of"]
    if retry_of not in by_attempt:
        raise GovernanceRecordError(
            f"INFRA_RETRY retry_of target not supplied in prior_records: {retry_of}"
        )
    target = by_attempt[retry_of]
    changed = [field for field in _RETRY_IMMUTABLE_FIELDS if record[field] != target[field]]
    if changed:
        raise GovernanceRecordError(
            "INFRA_RETRY changed immutable trial bindings: " + ", ".join(changed)
        )
    if _utc(record["created_at_utc"], "$.created_at_utc") < _utc(
        target["created_at_utc"], "$.retry_of.created_at_utc"
    ):
        raise GovernanceRecordError("INFRA_RETRY cannot predate its retry_of target")

    visited = {record["attempt_id"]}
    cursor = target
    while cursor["attempt_kind"] == "INFRA_RETRY":
        cursor_id = cursor["attempt_id"]
        if cursor_id in visited:
            raise GovernanceRecordError("INFRA_RETRY lineage cycle detected")
        visited.add(cursor_id)
        parent_id = cursor["retry_of"]
        if parent_id not in by_attempt:
            raise GovernanceRecordError(
                f"incomplete INFRA_RETRY ancestry in prior_records: {parent_id}"
            )
        parent = by_attempt[parent_id]
        changed = [field for field in _RETRY_IMMUTABLE_FIELDS if cursor[field] != parent[field]]
        if changed:
            raise GovernanceRecordError("prior INFRA_RETRY lineage changed immutable bindings")
        cursor = parent


def validate_source_authorization(record: Mapping[str, Any]) -> None:
    candidate = dict(record) if isinstance(record, Mapping) else record
    _reject_floats(candidate)
    _validate_source_authorization_shape(candidate)
    _verify_record_hash(candidate)


def validate_g0_decision(record: Mapping[str, Any]) -> None:
    candidate = dict(record) if isinstance(record, Mapping) else record
    _reject_floats(candidate)
    _validate_g0_decision_shape(candidate)
    _verify_record_hash(candidate)


def validate_experiment_record(
    record: Mapping[str, Any], *, prior_records: Iterable[Mapping[str, Any]] = ()
) -> None:
    candidate = dict(record) if isinstance(record, Mapping) else record
    _reject_floats(candidate)
    _validate_experiment_shape(candidate)
    _verify_record_hash(candidate)
    _validate_experiment_lineage(candidate, prior_records)


def validate_record(
    record: Mapping[str, Any], *, prior_records: Iterable[Mapping[str, Any]] = ()
) -> None:
    if not isinstance(record, Mapping):
        raise GovernanceRecordError("record root must be an object")
    schema_version = record.get("schema_version")
    if schema_version == SOURCE_AUTHORIZATION_V1:
        validate_source_authorization(record)
    elif schema_version == G0_DECISION_V1:
        validate_g0_decision(record)
    elif schema_version == EXPERIMENT_RECORD_V1:
        validate_experiment_record(record, prior_records=prior_records)
    else:
        raise GovernanceRecordError(f"unsupported schema_version: {schema_version!r}")


def seal_record(
    payload: Mapping[str, Any], *, prior_records: Iterable[Mapping[str, Any]] = ()
) -> dict[str, Any]:
    """Copy a hashless payload, add its canonical hash, and fully validate it."""

    if not isinstance(payload, Mapping):
        raise GovernanceRecordError("record root must be an object")
    if "record_sha256" in payload:
        raise GovernanceRecordError("seal_record requires a hashless payload")
    sealed = copy.deepcopy(dict(payload))
    sealed["record_sha256"] = canonical_record_hash(sealed)
    validate_record(sealed, prior_records=prior_records)
    return sealed


def load_record(
    path: Path | str,
    *,
    prior_records: Iterable[Mapping[str, Any]] = (),
    require_canonical_bytes: bool = True,
) -> dict[str, Any]:
    source = Path(path)
    raw = source.read_bytes()
    try:
        decoded = raw.decode("utf-8")
        record = json.loads(decoded, object_pairs_hook=_duplicate_key_guard)
    except GovernanceRecordError:
        raise
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise GovernanceRecordError(f"invalid governance record JSON: {exc}") from exc
    if not isinstance(record, dict):
        raise GovernanceRecordError("record root must be an object")
    validate_record(record, prior_records=prior_records)
    if require_canonical_bytes and raw != _canonical_json_bytes(record, file_form=True):
        raise GovernanceRecordError("record file is not in canonical UTF-8 JSON form")
    return record


def write_new_record(
    path: Path | str,
    payload: Mapping[str, Any],
    *,
    prior_records: Iterable[Mapping[str, Any]] = (),
) -> WriteReceipt:
    """Atomically claim a new path and write one canonical, sealed record.

    Existing paths are never opened for writing.  The parent directory must
    already exist so this primitive cannot silently expand its persistence scope.
    """

    destination = Path(path)
    if not destination.parent.is_dir():
        raise GovernanceRecordError(f"record parent directory does not exist: {destination.parent}")

    if "record_sha256" in payload:
        sealed = copy.deepcopy(dict(payload))
        validate_record(sealed, prior_records=prior_records)
    else:
        sealed = seal_record(payload, prior_records=prior_records)
    raw = _canonical_json_bytes(sealed, file_form=True)

    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    try:
        descriptor = os.open(destination, flags, 0o600)
    except FileExistsError as exc:
        raise GovernanceRecordError(f"refusing to overwrite existing record: {destination}") from exc

    try:
        with os.fdopen(descriptor, "wb") as stream:
            descriptor = -1
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        if descriptor >= 0:
            os.close(descriptor)

    # Keep an ambiguously durable partial record fail-closed. A pathname unlink
    # after the owned handle closes could remove a concurrent replacement.

    return WriteReceipt(
        path=destination,
        schema_version=sealed["schema_version"],
        record_sha256=sealed["record_sha256"],
        size_bytes=len(raw),
    )
