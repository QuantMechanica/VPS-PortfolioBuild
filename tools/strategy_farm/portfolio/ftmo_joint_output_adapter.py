"""Fail-closed adapter from QM joint-output JSONL to FTMO money evidence.

The current QM5_20181 streams are useful execution/fidelity evidence, but they
are not sufficient for an FTMO money gate.  In particular, the legacy
``EQUITY_BAR``/``EQUITY_LOW`` rows do not prove a regular Prague-midnight grid,
tick/event-complete interval minima for non-host symbols, reconciled position
opens, or pending-order state.  Legacy ``TRADE_CLOSED`` rows also omit the
position/deal identity and lifecycle balance events needed to reconcile entry
commission, exit commission, swap, and realised profit to account balance.

This adapter never fills those gaps.  It returns ``SETUP_DATA_MISSING`` for the
legacy schema.  It emits an evaluable trace only for the explicit v2 producer
contract below:

* The first equity JSONL row is one ``FTMO_JOINT_TRACE_META`` row with the
  producer/run identity, provenance bases and exact expected book membership.
* Remaining equity rows are ``FTMO_JOINT_TRACE_POINT`` rows on one regular UTC
  grid, beginning and ending at exact 00:00 Europe/Prague boundaries.  Every
  point carries an event-complete interval minimum, endpoint/open-event counts,
  pending-order state, exact covered magics/symbols, and per-magic floating P&L.
* Trade rows use q08 schema v2: one fully closed position lifecycle per row,
  stable position/deal identifiers and deal-bound balance events whose amounts
  reconcile exactly to profit + swap + all entry/exit commission and fees.

An evaluable invocation additionally authenticates the harvested streams against
an isolated runner receipt and exact EX5/set/report hashes, and validates a
hash-bound official-rules snapshot no older than seven days.  Merely computing a
hash over caller-selected JSON is not treated as provenance.

The normalized trace is delegated to :mod:`ftmo_rules_engine`; this adapter
does not implement a second set of FTMO arithmetic.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:  # pragma: no cover - direct script invocation fallback
    from . import ftmo_rules_engine as rules_engine
except ImportError:  # pragma: no cover
    import ftmo_rules_engine as rules_engine  # type: ignore


ADAPTER_SCHEMA_VERSION = 1
PROVENANCE_SCHEMA_VERSION = 1
RULE_SNAPSHOT_SCHEMA_VERSION = 1
RULE_SNAPSHOT_MAX_AGE = dt.timedelta(days=7)
EQUITY_META_EVENT = "FTMO_JOINT_TRACE_META"
EQUITY_POINT_EVENT = "FTMO_JOINT_TRACE_POINT"
Q08_TRADE_SCHEMA_VERSION = 2
COVERAGE_BASIS = "TICK_EVENT_COMPLETE_ALL_BOOK_SYMBOLS_AND_ACCOUNT_EVENTS"
PENDING_ORDERS_BASIS = (
    "RECONCILED_PENDING_ORDER_STATE_AT_ENDPOINT_AND_EVENT_COMPLETE_INTERVAL"
)
TRADE_NET_BASIS = (
    "FULL_POSITION_LIFECYCLE_PROFIT_SWAP_AND_ENTRY_EXIT_COMMISSION"
)
FLOATING_BASIS = "OPEN_POSITION_PROFIT_AND_ACCRUED_SWAP_BY_MAGIC"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_ALLOWED_BALANCE_COMPONENTS = frozenset(
    {"PROFIT", "SWAP", "COMMISSION", "FEE"}
)
_MAX_RULE_SNAPSHOT_FUTURE_SKEW = dt.timedelta(minutes=5)


LEGACY_MISSING_REQUIREMENTS = (
    "EQUITY_STREAM_META_MISSING",
    "INTERVAL_MIN_EQUITY_MISSING",
    "OPEN_POSITIONS_MISSING",
    "OPENED_POSITIONS_MISSING",
    "PENDING_ORDERS_MISSING",
    "PRAGUE_DAY_ANCHOR_MISSING",
    "ALL_SYMBOL_EVENT_COVERAGE_MISSING",
    "COST_BASIS_ATTESTATION_MISSING",
    "TRADE_SCHEMA_V2_MISSING",
    "TRADE_POSITION_IDENTITY_MISSING",
    "TRADE_BALANCE_EVENTS_MISSING",
)


class EvidenceContractError(ValueError):
    """Base class for fail-closed input-contract failures."""

    status = "SETUP_DATA_INVALID"

    def __init__(self, reason: str, *, details: Sequence[str] = ()) -> None:
        super().__init__(reason)
        self.reason = reason
        self.details = tuple(details)


class SetupDataMissing(EvidenceContractError):
    status = "SETUP_DATA_MISSING"


class SetupDataInvalid(EvidenceContractError):
    status = "SETUP_DATA_INVALID"


@dataclass(frozen=True, order=True)
class ExpectedMember:
    magic: int
    symbol: str


@dataclass(frozen=True)
class ProvenanceBinding:
    work_item_id: str
    evidence_run_id: str
    producer_version: str
    runner_receipt_path: str
    runner_receipt_sha256: str
    ex5_path: str
    ex5_sha256: str
    setfile_path: str
    setfile_sha256: str
    report_path: str
    report_sha256: str

    def fingerprint_payload(self) -> dict[str, Any]:
        return {
            "schema_version": PROVENANCE_SCHEMA_VERSION,
            "work_item_id": self.work_item_id,
            "evidence_run_id": self.evidence_run_id,
            "producer_version": self.producer_version,
            "runner_receipt_sha256": self.runner_receipt_sha256,
            "ex5_sha256": self.ex5_sha256,
            "setfile_sha256": self.setfile_sha256,
            "report_sha256": self.report_sha256,
        }

    def artifact_payload(self) -> dict[str, Any]:
        return self.fingerprint_payload() | {
            "runner_receipt_path": self.runner_receipt_path,
            "ex5_path": self.ex5_path,
            "setfile_path": self.setfile_path,
            "report_path": self.report_path,
        }


@dataclass(frozen=True)
class RuleSnapshotBinding:
    path: str
    sha256: str
    source_url: str
    source_observations_sha256: str
    retrieved_at_utc: str
    engine_profile_sha256: str
    age_seconds_at_evaluation: int

    def artifact_payload(self) -> dict[str, Any]:
        return {
            "schema_version": RULE_SNAPSHOT_SCHEMA_VERSION,
            "path": self.path,
            "sha256": self.sha256,
            "source_url": self.source_url,
            "source_observations_sha256": self.source_observations_sha256,
            "retrieved_at_utc": self.retrieved_at_utc,
            "engine_profile_sha256": self.engine_profile_sha256,
            "age_seconds_at_evaluation": self.age_seconds_at_evaluation,
            "maximum_age_seconds": int(RULE_SNAPSHOT_MAX_AGE.total_seconds()),
        }


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for key, value in pairs:
        if key in output:
            raise SetupDataInvalid(f"json_duplicate_key:{key}")
        output[key] = value
    return output


def _parse_json_line(line: str, line_number: int, stream_name: str) -> dict[str, Any]:
    try:
        value = json.loads(line, object_pairs_hook=_reject_duplicate_keys)
    except json.JSONDecodeError as exc:
        raise SetupDataInvalid(
            f"{stream_name}_json_invalid_line:{line_number}"
        ) from exc
    if not isinstance(value, dict):
        raise SetupDataInvalid(f"{stream_name}_row_not_object:{line_number}")
    return value


def _read_snapshot(path: Path, label: str) -> tuple[bytes, str]:
    try:
        payload = path.read_bytes()
    except FileNotFoundError as exc:
        raise SetupDataMissing(f"{label}_file_missing") from exc
    except OSError as exc:
        raise SetupDataInvalid(f"{label}_file_unreadable:{type(exc).__name__}") from exc
    return payload, hashlib.sha256(payload).hexdigest()


def _decode_snapshot(payload: bytes, label: str) -> str:
    try:
        return payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise SetupDataInvalid(f"{label}_utf8_invalid") from exc


def _parse_json_document(payload: bytes, label: str) -> dict[str, Any]:
    text = _decode_snapshot(payload, label)
    try:
        value = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except json.JSONDecodeError as exc:
        raise SetupDataInvalid(f"{label}_json_invalid") from exc
    if not isinstance(value, dict):
        raise SetupDataInvalid(f"{label}_json_not_object")
    return value


def _parse_jsonl_snapshot(
    payload: bytes,
    stream_name: str,
    *,
    first_only: bool = False,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(
        _decode_snapshot(payload, stream_name).splitlines(), 1
    ):
        if line.strip():
            rows.append(_parse_json_line(line, line_number, stream_name))
            if first_only:
                break
    if not rows:
        raise SetupDataMissing(f"{stream_name}_stream_empty")
    return rows


def load_jsonl(path: Path, stream_name: str) -> list[dict[str, Any]]:
    payload, _sha256 = _read_snapshot(path, stream_name)
    return _parse_jsonl_snapshot(payload, stream_name)


def file_sha256(path: Path) -> str:
    _payload, digest = _read_snapshot(path, "source")
    return digest


def _parse_timestamp(value: Any, label: str) -> dt.datetime:
    if isinstance(value, bool) or value is None:
        raise SetupDataInvalid(f"{label}_invalid")
    if isinstance(value, (int, float)):
        if not math.isfinite(float(value)):
            raise SetupDataInvalid(f"{label}_nonfinite")
        try:
            return dt.datetime.fromtimestamp(float(value), tz=dt.UTC)
        except (OverflowError, OSError, ValueError) as exc:
            raise SetupDataInvalid(f"{label}_invalid") from exc
    raw = str(value).strip()
    if not raw:
        raise SetupDataInvalid(f"{label}_invalid")
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(raw)
    except ValueError as exc:
        raise SetupDataInvalid(f"{label}_invalid") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise SetupDataInvalid(f"{label}_timezone_missing")
    return parsed.astimezone(dt.UTC)


def _timestamp_text(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _money(value: Any, label: str, decimals: int = 2) -> Decimal:
    if isinstance(value, bool) or value is None:
        raise SetupDataInvalid(f"{label}_invalid")
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise SetupDataInvalid(f"{label}_invalid") from exc
    if not parsed.is_finite():
        raise SetupDataInvalid(f"{label}_nonfinite")
    quantum = Decimal(1).scaleb(-decimals)
    if parsed.quantize(quantum) != parsed:
        raise SetupDataInvalid(f"{label}_precision_exceeds_{decimals}")
    return parsed


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool):
        raise SetupDataInvalid(f"{label}_invalid")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise SetupDataInvalid(f"{label}_invalid") from exc
    if parsed <= 0 or str(parsed) != str(value).strip():
        raise SetupDataInvalid(f"{label}_invalid")
    return parsed


def _nonnegative_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise SetupDataInvalid(f"{label}_invalid")
    return value


def _canonical_members(values: Iterable[ExpectedMember]) -> tuple[ExpectedMember, ...]:
    members = tuple(sorted(values))
    if not members:
        raise SetupDataInvalid("expected_members_empty")
    if len(set(members)) != len(members):
        raise SetupDataInvalid("expected_members_duplicate")
    magics = [member.magic for member in members]
    if len(set(magics)) != len(magics):
        raise SetupDataInvalid("expected_member_magic_duplicate")
    for member in members:
        if member.magic <= 0 or not member.symbol or member.symbol != member.symbol.strip():
            raise SetupDataInvalid("expected_member_invalid")
    return members


def parse_member(value: str) -> ExpectedMember:
    raw = str(value).strip()
    if ":" not in raw:
        raise argparse.ArgumentTypeError("member must be MAGIC:SYMBOL")
    magic_raw, symbol = raw.split(":", 1)
    try:
        magic = int(magic_raw)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("member magic must be a positive integer") from exc
    if magic <= 0 or not symbol or symbol != symbol.strip():
        raise argparse.ArgumentTypeError("member must be MAGIC:SYMBOL")
    return ExpectedMember(magic=magic, symbol=symbol)


def _members_from_meta(value: Any) -> tuple[ExpectedMember, ...]:
    if not isinstance(value, list):
        raise SetupDataMissing("expected_members_metadata_missing")
    members: list[ExpectedMember] = []
    for index, row in enumerate(value):
        if not isinstance(row, Mapping):
            raise SetupDataInvalid(f"expected_member_metadata_invalid:{index}")
        magic = _positive_int(row.get("magic"), f"expected_member_magic:{index}")
        symbol = row.get("symbol")
        if not isinstance(symbol, str) or not symbol or symbol != symbol.strip():
            raise SetupDataInvalid(f"expected_member_symbol:{index}_invalid")
        members.append(ExpectedMember(magic, symbol))
    return _canonical_members(members)


def _require_sha256(value: Any, label: str) -> str:
    normalized = str(value or "").strip().lower()
    if not _SHA256_RE.fullmatch(normalized):
        raise SetupDataInvalid(f"{label}_sha256_invalid")
    return normalized


def _resolved(path: Path, label: str) -> Path:
    try:
        return path.resolve(strict=True)
    except OSError as exc:
        raise SetupDataMissing(f"{label}_path_missing") from exc


def _validate_bound_file(
    path: Path, expected_sha256: Any, label: str
) -> tuple[bytes, str]:
    expected = _require_sha256(expected_sha256, f"expected_{label}")
    payload, actual = _read_snapshot(path, label)
    if actual != expected:
        raise SetupDataInvalid(f"{label}_sha256_mismatch:{actual}!={expected}")
    return payload, actual


def validate_rule_snapshot(
    path: Path,
    *,
    expected_sha256: str,
    evaluated_at_utc: dt.datetime | None = None,
) -> RuleSnapshotBinding:
    """Authenticate a current official-rules receipt against the engine profile."""

    expected = _require_sha256(expected_sha256, "expected_rules_snapshot")
    payload, actual = _read_snapshot(path, "rules_snapshot")
    if actual != expected:
        raise SetupDataInvalid(
            f"rules_snapshot_sha256_mismatch:{actual}!={expected}"
        )
    snapshot = _parse_json_document(payload, "rules_snapshot")
    if snapshot.get("schema") != "qm.ftmo-official-rules-snapshot/v1":
        raise SetupDataInvalid("rules_snapshot_schema_version_invalid")
    if snapshot.get("freshness_max_age_days") != 7:
        raise SetupDataInvalid("rules_snapshot_freshness_contract_invalid")
    sources = snapshot.get("sources")
    if not isinstance(sources, list) or not sources:
        raise SetupDataMissing("rules_snapshot_sources_missing")
    normalized_sources: list[dict[str, Any]] = []
    for index, source in enumerate(sources):
        if not isinstance(source, Mapping):
            raise SetupDataInvalid(f"rules_snapshot_source_invalid:{index}")
        source_id = source.get("source_id")
        url = source.get("url")
        response_bytes = source.get("response_bytes")
        if (
            not isinstance(source_id, str)
            or not source_id
            or not isinstance(url, str)
            or not url.startswith("https://ftmo.com/")
            or source.get("http_status") != 200
            or isinstance(response_bytes, bool)
            or not isinstance(response_bytes, int)
            or response_bytes <= 0
        ):
            raise SetupDataInvalid(f"rules_snapshot_source_invalid:{index}")
        response_sha = _require_sha256(
            source.get("response_sha256_observation"),
            f"rules_snapshot_source:{index}",
        )
        normalized_sources.append(
            {
                "source_id": source_id,
                "url": url,
                "http_status": 200,
                "response_bytes": response_bytes,
                "response_sha256_observation": response_sha,
                "last_modified_utc_observation": source.get(
                    "last_modified_utc_observation"
                ),
            }
        )
    if sum(
        1
        for source in normalized_sources
        if source["url"] == rules_engine.RULES_SOURCE_URL
    ) != 1:
        raise SetupDataInvalid("rules_snapshot_primary_source_missing_or_duplicate")
    source_observations_sha = hashlib.sha256(
        json.dumps(
            normalized_sources, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
    ).hexdigest()
    claims = snapshot.get("normalized_claims")
    expected_claims = {
        "phase1_profit_target_percent": "10",
        "verification_profit_target_percent": "5",
        "profit_target_operator": "STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT",
        "maximum_daily_loss_percent_of_initial": "5",
        "maximum_daily_loss_reset_timezone": "Europe/Prague",
        "maximum_daily_loss_reset_local_time": "00:00:00",
        "maximum_daily_loss_basis": (
            "MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT"
        ),
        "maximum_daily_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
        "maximum_loss_percent_of_initial": "10",
        "maximum_loss_model": "STATIC_INITIAL_CAPITAL",
        "maximum_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
        "minimum_trading_days_per_phase": 4,
        "trading_day_qualifier": (
            "AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY"
        ),
        "maximum_trading_period_days": None,
    }
    if not isinstance(claims, Mapping) or any(
        claims.get(key) != value for key, value in expected_claims.items()
    ):
        raise SetupDataInvalid("rules_snapshot_normalized_claims_mismatch")
    expected_profile_sha = rules_engine.frozen_rule_profile_sha256()
    declared_profile_sha = snapshot.get("engine_profile_sha256")
    if declared_profile_sha is not None and _require_sha256(
        declared_profile_sha, "rules_snapshot_engine_profile"
    ) != expected_profile_sha:
        raise SetupDataInvalid(
            "rules_snapshot_engine_profile_mismatch:"
            f"{declared_profile_sha}!={expected_profile_sha}"
        )
    retrieved_raw = snapshot.get("retrieved_at_utc")
    if not isinstance(retrieved_raw, str) or not retrieved_raw.strip():
        raise SetupDataMissing("rules_snapshot_retrieved_at_utc_missing")
    retrieved = _parse_timestamp(retrieved_raw, "rules_snapshot_retrieved_at_utc")
    now = evaluated_at_utc or dt.datetime.now(dt.UTC)
    if now.tzinfo is None or now.utcoffset() is None:
        raise SetupDataInvalid("evaluation_time_timezone_missing")
    now = now.astimezone(dt.UTC)
    if retrieved > now + _MAX_RULE_SNAPSHOT_FUTURE_SKEW:
        raise SetupDataInvalid("rules_snapshot_retrieved_in_future")
    age = now - retrieved
    if age > RULE_SNAPSHOT_MAX_AGE:
        raise SetupDataMissing(
            "rules_snapshot_stale:"
            f"{int(age.total_seconds())}>{int(RULE_SNAPSHOT_MAX_AGE.total_seconds())}"
        )
    return RuleSnapshotBinding(
        path=str(_resolved(path, "rules_snapshot")),
        sha256=actual,
        source_url=rules_engine.RULES_SOURCE_URL,
        source_observations_sha256=source_observations_sha,
        retrieved_at_utc=_timestamp_text(retrieved),
        engine_profile_sha256=expected_profile_sha,
        age_seconds_at_evaluation=max(0, int(age.total_seconds())),
    )


def _receipt_streams(receipt: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    post_run = receipt.get("post_run_stream")
    if not isinstance(post_run, Mapping) or post_run.get("valid") is not True:
        raise SetupDataInvalid("runner_receipt_post_run_stream_invalid")
    raw = post_run.get("streams")
    streams = list(raw) if isinstance(raw, list) else [post_run]
    if not streams or any(not isinstance(item, Mapping) for item in streams):
        raise SetupDataInvalid("runner_receipt_post_run_streams_invalid")
    return streams


def _validate_receipt_stream(
    streams: Sequence[Mapping[str, Any]],
    *,
    stream_type: str,
    path: Path,
    sha256: str,
) -> None:
    matches = [item for item in streams if item.get("stream_type") == stream_type]
    if len(matches) != 1:
        raise SetupDataInvalid(f"runner_receipt_{stream_type}_binding_count_invalid")
    stream = matches[0]
    if stream.get("valid") is not True:
        raise SetupDataInvalid(f"runner_receipt_{stream_type}_invalid")
    target = stream.get("target")
    if not isinstance(target, str) or _resolved(Path(target), stream_type) != _resolved(
        path, stream_type
    ):
        raise SetupDataInvalid(f"runner_receipt_{stream_type}_path_mismatch")
    harvested = stream.get("harvested")
    if not isinstance(harvested, Mapping) or harvested.get("sha256") != sha256:
        raise SetupDataInvalid(f"runner_receipt_{stream_type}_sha256_mismatch")


def _validate_receipt_artifact(
    receipt: Mapping[str, Any],
    *,
    role: str,
    path: Path,
    sha256: str,
) -> None:
    preflight = receipt.get("preflight")
    artifacts = preflight.get("artifacts") if isinstance(preflight, Mapping) else None
    if not isinstance(artifacts, list):
        raise SetupDataInvalid("runner_receipt_preflight_artifacts_missing")
    matches = [item for item in artifacts if isinstance(item, Mapping) and item.get("role") == role]
    if len(matches) != 1:
        raise SetupDataInvalid(f"runner_receipt_{role}_binding_count_invalid")
    artifact = matches[0]
    if artifact.get("valid") is not True:
        raise SetupDataInvalid(f"runner_receipt_{role}_invalid")
    recorded_path = artifact.get("path")
    if (
        not isinstance(recorded_path, str)
        or _resolved(Path(recorded_path), role) != _resolved(path, role)
        or artifact.get("actual_sha256") != sha256
        or artifact.get("expected_sha256") != sha256
    ):
        raise SetupDataInvalid(f"runner_receipt_{role}_binding_mismatch")


def validate_provenance(
    *,
    runner_receipt_path: Path,
    expected_runner_receipt_sha256: str,
    ex5_path: Path,
    expected_ex5_sha256: str,
    setfile_path: Path,
    expected_setfile_sha256: str,
    report_path: Path,
    expected_report_sha256: str,
    trades_path: Path,
    trade_sha256: str,
    equity_path: Path,
    equity_sha256: str,
    expected_work_item_id: str,
    expected_evidence_run_id: str,
    expected_producer_version: str,
) -> ProvenanceBinding:
    work_item_id = str(expected_work_item_id or "").strip()
    evidence_run_id = str(expected_evidence_run_id or "").strip()
    producer_version = str(expected_producer_version or "").strip()
    if not work_item_id:
        raise SetupDataMissing("expected_work_item_id_missing")
    if not evidence_run_id:
        raise SetupDataMissing("expected_evidence_run_id_missing")
    if not producer_version:
        raise SetupDataMissing("expected_producer_version_missing")

    receipt_expected = _require_sha256(
        expected_runner_receipt_sha256, "expected_runner_receipt"
    )
    receipt_bytes, receipt_actual = _read_snapshot(
        runner_receipt_path, "runner_receipt"
    )
    if receipt_actual != receipt_expected:
        raise SetupDataInvalid(
            f"runner_receipt_sha256_mismatch:{receipt_actual}!={receipt_expected}"
        )
    receipt = _parse_json_document(receipt_bytes, "runner_receipt")
    if (
        receipt.get("schema_version") != 1
        or receipt.get("mode") != "apply"
        or receipt.get("worker_exit_code") != 0
    ):
        raise SetupDataInvalid("runner_receipt_execution_invalid")
    if receipt.get("work_item_id") != work_item_id:
        raise SetupDataInvalid("runner_receipt_work_item_id_mismatch")
    post_item = receipt.get("post_work_item")
    if (
        not isinstance(post_item, Mapping)
        or post_item.get("id") != work_item_id
        or post_item.get("status") != "done"
        or post_item.get("verdict") != "PASS"
    ):
        raise SetupDataInvalid("runner_receipt_work_item_not_done_pass")
    preflight = receipt.get("preflight")
    preflight_item = preflight.get("work_item") if isinstance(preflight, Mapping) else None
    if (
        not isinstance(preflight_item, Mapping)
        or preflight_item.get("evidence_run_id") != evidence_run_id
    ):
        raise SetupDataInvalid("runner_receipt_evidence_run_id_mismatch")

    _ex5_bytes, ex5_sha = _validate_bound_file(
        ex5_path, expected_ex5_sha256, "ex5"
    )
    setfile_bytes, setfile_sha = _validate_bound_file(
        setfile_path, expected_setfile_sha256, "setfile"
    )
    _report_bytes, report_sha = _validate_bound_file(
        report_path, expected_report_sha256, "report"
    )
    set_evidence_ids = []
    for line in _decode_snapshot(setfile_bytes, "setfile").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith((";", "#")) or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key.strip() == "qm_evidence_run_id":
            set_evidence_ids.append(value.strip())
    if set_evidence_ids != [evidence_run_id]:
        raise SetupDataInvalid("setfile_evidence_run_id_mismatch")
    evidence_path = post_item.get("evidence_path")
    if (
        not isinstance(evidence_path, str)
        or _resolved(Path(evidence_path), "report") != _resolved(report_path, "report")
    ):
        raise SetupDataInvalid("runner_receipt_report_path_mismatch")

    _validate_receipt_artifact(
        receipt, role="staged_ex5", path=ex5_path, sha256=ex5_sha
    )
    _validate_receipt_artifact(
        receipt, role="setfile", path=setfile_path, sha256=setfile_sha
    )
    streams = _receipt_streams(receipt)
    _validate_receipt_stream(
        streams,
        stream_type="q08_trades",
        path=trades_path,
        sha256=trade_sha256,
    )
    _validate_receipt_stream(
        streams,
        stream_type="q08_equity",
        path=equity_path,
        sha256=equity_sha256,
    )
    return ProvenanceBinding(
        work_item_id=work_item_id,
        evidence_run_id=evidence_run_id,
        producer_version=producer_version,
        runner_receipt_path=str(_resolved(runner_receipt_path, "runner_receipt")),
        runner_receipt_sha256=receipt_actual,
        ex5_path=str(_resolved(ex5_path, "ex5")),
        ex5_sha256=ex5_sha,
        setfile_path=str(_resolved(setfile_path, "setfile")),
        setfile_sha256=setfile_sha,
        report_path=str(_resolved(report_path, "report")),
        report_sha256=report_sha,
    )


def _require_meta_value(meta: Mapping[str, Any], key: str, expected: Any) -> None:
    if key not in meta:
        raise SetupDataMissing(f"equity_meta_{key}_missing")
    if meta[key] != expected:
        raise SetupDataInvalid(f"equity_meta_{key}_mismatch")


def _required(row: Mapping[str, Any], key: str, reason: str) -> Any:
    if key not in row or row[key] is None:
        raise SetupDataMissing(reason)
    return row[key]


def _legacy_artifact(
    trade_first: Mapping[str, Any] | None,
    equity_first: Mapping[str, Any] | None,
    *,
    trade_sha256: str,
    equity_sha256: str,
) -> dict[str, Any]:
    missing = list(LEGACY_MISSING_REQUIREMENTS)
    # Keep the list evidence-specific if a partially upgraded producer exists.
    if equity_first:
        field_to_reason = {
            "interval_min_equity": "INTERVAL_MIN_EQUITY_MISSING",
            "open_positions": "OPEN_POSITIONS_MISSING",
            "opened_positions": "OPENED_POSITIONS_MISSING",
            "pending_orders": "PENDING_ORDERS_MISSING",
            "day_anchor": "PRAGUE_DAY_ANCHOR_MISSING",
            "coverage_complete": "ALL_SYMBOL_EVENT_COVERAGE_MISSING",
        }
        for field, reason in field_to_reason.items():
            if field in equity_first and reason in missing:
                missing.remove(reason)
    if trade_first:
        if trade_first.get("schema_version") == Q08_TRADE_SCHEMA_VERSION:
            missing.remove("TRADE_SCHEMA_V2_MISSING")
        if "position_id" in trade_first:
            missing.remove("TRADE_POSITION_IDENTITY_MISSING")
        if "balance_events" in trade_first:
            missing.remove("TRADE_BALANCE_EVENTS_MISSING")
    return {
        "schema_version": ADAPTER_SCHEMA_VERSION,
        "status": "SETUP_DATA_MISSING",
        "reason": "legacy_qm5_20181_output_lacks_money_gate_contract",
        "money_gate_eligible": False,
        "missing_requirements": missing,
        "detected_equity_event": None if not equity_first else equity_first.get("event"),
        "detected_trade_event": None if not trade_first else trade_first.get("event"),
        "required_equity_meta_event": EQUITY_META_EVENT,
        "required_equity_point_event": EQUITY_POINT_EVENT,
        "required_trade_schema_version": Q08_TRADE_SCHEMA_VERSION,
        "source": {
            "q08_trades_sha256": trade_sha256,
            "q08_equity_sha256": equity_sha256,
        },
        "challenge_proof": False,
    }


def _validate_metadata(
    meta: Mapping[str, Any],
    *,
    expected_members: tuple[ExpectedMember, ...],
    provenance: ProvenanceBinding,
) -> tuple[str, str, int, int]:
    _require_meta_value(meta, "event", EQUITY_META_EVENT)
    _require_meta_value(meta, "schema_version", ADAPTER_SCHEMA_VERSION)
    _require_meta_value(meta, "q08_trade_schema_version", Q08_TRADE_SCHEMA_VERSION)
    _require_meta_value(meta, "currency", "USD")
    _require_meta_value(meta, "balance_basis", rules_engine.BALANCE_BASIS_NET_TRADING)
    _require_meta_value(meta, "equity_basis", rules_engine.EQUITY_BASIS_MTM)
    _require_meta_value(
        meta, "opened_positions_basis", rules_engine.OPENED_POSITIONS_BASIS
    )
    _require_meta_value(
        meta,
        "interval_min_equity_basis",
        rules_engine.INTERVAL_MIN_EQUITY_BASIS,
    )
    _require_meta_value(meta, "pending_orders_basis", PENDING_ORDERS_BASIS)
    _require_meta_value(meta, "coverage_basis", COVERAGE_BASIS)
    _require_meta_value(meta, "trade_net_basis", TRADE_NET_BASIS)
    _require_meta_value(meta, "floating_basis", FLOATING_BASIS)
    trace_id = meta.get("trace_id")
    if not isinstance(trace_id, str) or not trace_id.strip():
        raise SetupDataMissing("equity_meta_trace_id_missing")
    run_id = meta.get("run_id")
    if not isinstance(run_id, str) or not run_id.strip():
        raise SetupDataMissing("equity_meta_run_id_missing")
    if run_id.strip() != provenance.evidence_run_id:
        raise SetupDataInvalid("equity_meta_run_id_mismatch")
    producer_version = meta.get("producer_version")
    if not isinstance(producer_version, str) or not producer_version.strip():
        raise SetupDataMissing("equity_meta_producer_version_missing")
    if producer_version.strip() != provenance.producer_version:
        raise SetupDataInvalid("equity_meta_producer_version_mismatch")
    grid_seconds = meta.get("grid_seconds")
    if (
        isinstance(grid_seconds, bool)
        or not isinstance(grid_seconds, int)
        or grid_seconds <= 0
        or grid_seconds > 3600
        or 3600 % grid_seconds != 0
    ):
        raise SetupDataInvalid("equity_meta_grid_seconds_invalid")
    money_decimals = meta.get("money_decimals")
    if money_decimals != 2:
        raise SetupDataInvalid("equity_meta_money_decimals_must_be_2")
    if _members_from_meta(meta.get("expected_members")) != expected_members:
        raise SetupDataInvalid("equity_meta_expected_members_mismatch")
    host_symbol = meta.get("host_symbol")
    if (
        not isinstance(host_symbol, str)
        or host_symbol not in {member.symbol for member in expected_members}
    ):
        raise SetupDataInvalid("equity_meta_host_symbol_invalid")
    return trace_id.strip(), run_id.strip(), grid_seconds, money_decimals


@dataclass(frozen=True)
class _BalanceEvent:
    timestamp: dt.datetime
    amount: Decimal


@dataclass(frozen=True)
class _PositionLifecycle:
    position_id: int
    entry_time: dt.datetime
    close_time: dt.datetime
    member: ExpectedMember
    balance_events: tuple[_BalanceEvent, ...]


def _validate_trade_rows(
    rows: Sequence[Mapping[str, Any]],
    *,
    expected_members: tuple[ExpectedMember, ...],
    run_id: str,
    producer_version: str,
    money_decimals: int,
) -> tuple[_PositionLifecycle, ...]:
    expected_set = set(expected_members)
    seen_positions: set[int] = set()
    seen_deals: set[int] = set()
    lifecycles: list[_PositionLifecycle] = []
    for index, row in enumerate(rows):
        if row.get("event") != "TRADE_CLOSED":
            raise SetupDataInvalid(f"trade_event_invalid:{index}")
        if row.get("schema_version") != Q08_TRADE_SCHEMA_VERSION:
            raise SetupDataMissing(f"trade_schema_v2_missing:{index}")
        if row.get("run_id") != run_id:
            reason = (
                f"trade_run_id_missing:{index}"
                if "run_id" not in row
                else f"trade_run_id_mismatch:{index}"
            )
            error_type = SetupDataMissing if "run_id" not in row else SetupDataInvalid
            raise error_type(reason)
        if row.get("producer_version") != producer_version:
            reason = (
                f"trade_producer_version_missing:{index}"
                if "producer_version" not in row
                else f"trade_producer_version_mismatch:{index}"
            )
            error_type = (
                SetupDataMissing
                if "producer_version" not in row
                else SetupDataInvalid
            )
            raise error_type(reason)
        if row.get("position_fully_closed") is not True:
            raise SetupDataMissing(f"trade_full_position_attestation_missing:{index}")
        position_id = _positive_int(
            _required(row, "position_id", f"trade_position_id_missing:{index}"),
            f"position_id:{index}",
        )
        if position_id in seen_positions:
            raise SetupDataInvalid(f"position_id_duplicate:{position_id}")
        seen_positions.add(position_id)
        entry_deal_ids = row.get("entry_deal_ids")
        exit_deal_ids = row.get("exit_deal_ids")
        if not isinstance(entry_deal_ids, list) or not entry_deal_ids:
            raise SetupDataMissing(f"entry_deal_ids_missing:{index}")
        if not isinstance(exit_deal_ids, list) or not exit_deal_ids:
            raise SetupDataMissing(f"exit_deal_ids_missing:{index}")
        row_deal_ids: set[int] = set()
        for group_name, values in (
            ("entry_deal_ids", entry_deal_ids),
            ("exit_deal_ids", exit_deal_ids),
        ):
            local: set[int] = set()
            for deal_index, value in enumerate(values):
                deal_id = _positive_int(value, f"{group_name}:{index}:{deal_index}")
                if deal_id in local or deal_id in seen_deals:
                    raise SetupDataInvalid(f"deal_id_duplicate:{deal_id}")
                local.add(deal_id)
                row_deal_ids.add(deal_id)
                seen_deals.add(deal_id)
        magic = _positive_int(
            _required(row, "magic", f"trade_magic_missing:{index}"), f"magic:{index}"
        )
        symbol = _required(row, "symbol", f"trade_symbol_missing:{index}")
        if not isinstance(symbol, str):
            raise SetupDataInvalid(f"symbol:{index}_invalid")
        member = ExpectedMember(magic, symbol)
        if member not in expected_set:
            raise SetupDataInvalid(f"unexpected_trade_member:{magic}:{symbol}")
        entry_time = _parse_timestamp(
            _required(row, "entry_time", f"trade_entry_time_missing:{index}"),
            f"entry_time:{index}",
        )
        close_time = _parse_timestamp(
            _required(row, "time", f"trade_close_time_missing:{index}"),
            f"close_time:{index}",
        )
        if entry_time >= close_time:
            raise SetupDataInvalid(f"trade_time_order_invalid:{index}")
        profit = _money(
            _required(row, "profit", f"trade_profit_missing:{index}"),
            f"profit:{index}",
            money_decimals,
        )
        swap = _money(
            _required(row, "swap", f"trade_swap_missing:{index}"),
            f"swap:{index}",
            money_decimals,
        )
        commission = _money(
            _required(row, "commission", f"trade_commission_missing:{index}"),
            f"commission:{index}",
            money_decimals,
        )
        fee = _money(
            _required(row, "fee", f"trade_fee_missing:{index}"),
            f"fee:{index}",
            money_decimals,
        )
        net = _money(
            _required(row, "net", f"trade_net_missing:{index}"),
            f"net:{index}",
            money_decimals,
        )
        if profit + swap + commission + fee != net:
            raise SetupDataInvalid(f"trade_net_components_mismatch:{index}")
        raw_events = row.get("balance_events")
        if not isinstance(raw_events, list) or not raw_events:
            raise SetupDataMissing(f"trade_balance_events_missing:{index}")
        component_totals = {component: Decimal(0) for component in _ALLOWED_BALANCE_COMPONENTS}
        balance_events: list[_BalanceEvent] = []
        balance_event_deals: set[int] = set()
        previous_event_time: dt.datetime | None = None
        for event_index, event in enumerate(raw_events):
            if not isinstance(event, Mapping):
                raise SetupDataInvalid(f"balance_event_invalid:{index}:{event_index}")
            component = event.get("component")
            if component not in _ALLOWED_BALANCE_COMPONENTS:
                raise SetupDataInvalid(
                    f"balance_event_component_invalid:{index}:{event_index}"
                )
            deal_id = _positive_int(
                _required(
                    event,
                    "deal_id",
                    f"balance_event_deal_id_missing:{index}:{event_index}",
                ),
                f"balance_event_deal_id:{index}:{event_index}",
            )
            if deal_id not in row_deal_ids:
                raise SetupDataInvalid(
                    f"balance_event_deal_id_not_in_lifecycle:{index}:{event_index}"
                )
            balance_event_deals.add(deal_id)
            timestamp = _parse_timestamp(
                event.get("time"), f"balance_event_time:{index}:{event_index}"
            )
            if timestamp < entry_time or timestamp > close_time:
                raise SetupDataInvalid(
                    f"balance_event_outside_position_lifecycle:{index}:{event_index}"
                )
            if previous_event_time is not None and timestamp < previous_event_time:
                raise SetupDataInvalid(f"balance_events_not_ordered:{index}")
            previous_event_time = timestamp
            amount = _money(
                event.get("amount"),
                f"balance_event_amount:{index}:{event_index}",
                money_decimals,
            )
            component_totals[component] += amount
            balance_events.append(_BalanceEvent(timestamp, amount))
        expected_components = {
            "PROFIT": profit,
            "SWAP": swap,
            "COMMISSION": commission,
            "FEE": fee,
        }
        if component_totals != expected_components:
            raise SetupDataInvalid(f"trade_balance_components_mismatch:{index}")
        if balance_event_deals != row_deal_ids:
            raise SetupDataInvalid(f"trade_deal_balance_events_incomplete:{index}")
        if sum((event.amount for event in balance_events), Decimal(0)) != net:
            raise SetupDataInvalid(f"trade_balance_events_net_mismatch:{index}")
        lifecycles.append(
            _PositionLifecycle(
                position_id=position_id,
                entry_time=entry_time,
                close_time=close_time,
                member=member,
                balance_events=tuple(balance_events),
            )
        )
    return tuple(sorted(lifecycles, key=lambda item: (item.entry_time, item.position_id)))


def _require_exact_member_vector(
    values: Any,
    *,
    label: str,
    expected_members: tuple[ExpectedMember, ...],
) -> None:
    if not isinstance(values, list):
        raise SetupDataMissing(f"{label}_missing")
    if label == "covered_magics":
        try:
            actual = sorted(_positive_int(value, label) for value in values)
        except SetupDataInvalid:
            raise
        expected = sorted(member.magic for member in expected_members)
    else:
        if any(not isinstance(value, str) for value in values):
            raise SetupDataInvalid(f"{label}_invalid")
        actual = sorted(values)
        expected = sorted({member.symbol for member in expected_members})
    if actual != expected or len(actual) != len(set(actual)):
        raise SetupDataInvalid(f"{label}_mismatch")


def _require_member_count_vector(
    values: Any,
    *,
    label: str,
    expected_members: tuple[ExpectedMember, ...],
) -> dict[ExpectedMember, int]:
    if not isinstance(values, list):
        raise SetupDataMissing(f"{label}_missing")
    counts: dict[ExpectedMember, int] = {}
    expected = set(expected_members)
    for index, item in enumerate(values):
        if not isinstance(item, Mapping):
            raise SetupDataInvalid(f"{label}_row_invalid:{index}")
        member = ExpectedMember(
            _positive_int(item.get("magic"), f"{label}_magic:{index}"),
            str(item.get("symbol") or ""),
        )
        if member not in expected or member in counts:
            raise SetupDataInvalid(f"{label}_member_mismatch:{index}")
        counts[member] = _nonnegative_int(
            _required(item, "count", f"{label}_count_missing:{index}"),
            f"{label}_count:{index}",
        )
    if set(counts) != expected:
        raise SetupDataInvalid(f"{label}_members_incomplete")
    return counts


def _validate_point_rows(
    rows: Sequence[Mapping[str, Any]],
    *,
    expected_members: tuple[ExpectedMember, ...],
    lifecycles: tuple[_PositionLifecycle, ...],
    grid_seconds: int,
    money_decimals: int,
    initial_balance: Decimal,
    trace_id: str,
    run_id: str,
    producer_version: str,
) -> tuple[list[dict[str, Any]], list[int]]:
    if not rows:
        raise SetupDataMissing("equity_point_rows_missing")
    normalized_rows: list[dict[str, Any]] = []
    pending_orders: list[int] = []
    previous_timestamp: dt.datetime | None = None
    expected_balance = initial_balance
    consumed_balance_events: set[tuple[int, int]] = set()
    for index, row in enumerate(rows):
        if row.get("event") != EQUITY_POINT_EVENT:
            raise SetupDataInvalid(f"equity_point_event_invalid:{index}")
        if row.get("schema_version") != ADAPTER_SCHEMA_VERSION:
            raise SetupDataInvalid(f"equity_point_schema_version_invalid:{index}")
        if row.get("trace_id") != trace_id:
            raise SetupDataInvalid(f"equity_point_trace_id_mismatch:{index}")
        if row.get("run_id") != run_id:
            raise SetupDataInvalid(f"equity_point_run_id_mismatch:{index}")
        if row.get("producer_version") != producer_version:
            raise SetupDataInvalid(f"equity_point_producer_version_mismatch:{index}")
        if row.get("coverage_complete") is not True:
            raise SetupDataMissing(f"equity_point_coverage_incomplete:{index}")
        _require_exact_member_vector(
            row.get("covered_magics"),
            label="covered_magics",
            expected_members=expected_members,
        )
        _require_exact_member_vector(
            row.get("covered_symbols"),
            label="covered_symbols",
            expected_members=expected_members,
        )
        sequence = _nonnegative_int(
            _required(
                row, "interval_sequence", f"interval_sequence_missing:{index}"
            ),
            f"interval_sequence:{index}",
        )
        if sequence != index:
            raise SetupDataInvalid(f"interval_sequence_mismatch:{index}:{sequence}")
        timestamp = _parse_timestamp(
            _required(row, "t_utc", f"equity_t_utc_missing:{index}"),
            f"equity_t_utc:{index}",
        )
        interval_start = _parse_timestamp(
            _required(
                row,
                "interval_start_utc",
                f"interval_start_utc_missing:{index}",
            ),
            f"interval_start_utc:{index}",
        )
        interval_end = _parse_timestamp(
            _required(
                row, "interval_end_utc", f"interval_end_utc_missing:{index}"
            ),
            f"interval_end_utc:{index}",
        )
        if interval_end != timestamp:
            raise SetupDataInvalid(f"interval_end_mismatch:{index}")
        if index == 0:
            if interval_start != timestamp:
                raise SetupDataInvalid("first_interval_not_zero_width")
        else:
            assert previous_timestamp is not None
            if interval_start != previous_timestamp:
                raise SetupDataInvalid(f"interval_start_mismatch:{index}")
            elapsed = int((timestamp - previous_timestamp).total_seconds())
            if elapsed != grid_seconds:
                raise SetupDataMissing(
                    f"equity_grid_interval_missing:{index}:{elapsed}!={grid_seconds}"
                )
        previous_timestamp = timestamp
        balance = _money(
            _required(row, "balance", f"equity_balance_missing:{index}"),
            f"equity_balance:{index}",
            money_decimals,
        )
        equity = _money(
            _required(row, "equity", f"equity_missing:{index}"),
            f"equity:{index}",
            money_decimals,
        )
        interval_min = _money(
            _required(
                row,
                "interval_min_equity",
                f"interval_min_equity_missing:{index}",
            ),
            f"interval_min_equity:{index}",
            money_decimals,
        )
        open_positions = _nonnegative_int(
            _required(row, "open_positions", f"open_positions_missing:{index}"),
            f"open_positions:{index}",
        )
        opened_positions = _nonnegative_int(
            _required(
                row, "opened_positions", f"opened_positions_missing:{index}"
            ),
            f"opened_positions:{index}",
        )
        pending = _nonnegative_int(
            _required(row, "pending_orders", f"pending_orders_missing:{index}"),
            f"pending_orders:{index}",
        )
        open_by_member = _require_member_count_vector(
            row.get("open_positions_by_member"),
            label="open_positions_by_member",
            expected_members=expected_members,
        )
        opened_by_member = _require_member_count_vector(
            row.get("opened_positions_by_member"),
            label="opened_positions_by_member",
            expected_members=expected_members,
        )
        pending_by_member = _require_member_count_vector(
            row.get("pending_orders_by_member"),
            label="pending_orders_by_member",
            expected_members=expected_members,
        )
        if sum(open_by_member.values()) != open_positions:
            raise SetupDataInvalid(f"open_positions_member_total_mismatch:{index}")
        if sum(opened_by_member.values()) != opened_positions:
            raise SetupDataInvalid(f"opened_positions_member_total_mismatch:{index}")
        if sum(pending_by_member.values()) != pending:
            raise SetupDataInvalid(f"pending_orders_member_total_mismatch:{index}")
        day_anchor = row.get("day_anchor")
        if not isinstance(day_anchor, bool):
            raise SetupDataMissing(f"day_anchor_missing:{index}")
        raw_floating = row.get("fl")
        if not isinstance(raw_floating, list):
            raise SetupDataMissing(f"floating_breakdown_missing:{index}")
        floating_by_member: dict[ExpectedMember, Decimal] = {}
        for float_index, floating in enumerate(raw_floating):
            if not isinstance(floating, Mapping):
                raise SetupDataInvalid(f"floating_row_invalid:{index}:{float_index}")
            member = ExpectedMember(
                _positive_int(
                    floating.get("magic"), f"floating_magic:{index}:{float_index}"
                ),
                str(floating.get("symbol") or ""),
            )
            if member not in set(expected_members) or member in floating_by_member:
                raise SetupDataInvalid(f"floating_member_mismatch:{index}:{float_index}")
            floating_by_member[member] = _money(
                floating.get("f"), f"floating_value:{index}:{float_index}", money_decimals
            )
        if set(floating_by_member) != set(expected_members):
            raise SetupDataInvalid(f"floating_members_incomplete:{index}")
        fl_total = _money(
            _required(row, "fl_total", f"floating_total_missing:{index}"),
            f"fl_total:{index}",
            money_decimals,
        )
        if sum(floating_by_member.values(), Decimal(0)) != fl_total:
            raise SetupDataInvalid(f"floating_total_mismatch:{index}")
        if balance + fl_total != equity:
            raise SetupDataInvalid(f"account_equity_identity_mismatch:{index}")

        lower_bound = timestamp if index == 0 else _parse_timestamp(
            rows[index - 1].get("t_utc"), f"equity_t_utc:{index - 1}"
        )
        for lifecycle in lifecycles:
            for event_index, event in enumerate(lifecycle.balance_events):
                identity = (lifecycle.position_id, event_index)
                if identity in consumed_balance_events:
                    continue
                if (index == 0 and event.timestamp <= timestamp) or (
                    index > 0 and lower_bound < event.timestamp <= timestamp
                ):
                    expected_balance += event.amount
                    consumed_balance_events.add(identity)
        if balance != expected_balance:
            raise SetupDataInvalid(
                f"balance_trade_reconciliation_mismatch:{index}:"
                f"{balance}!={expected_balance}"
            )
        expected_open = sum(
            1
            for lifecycle in lifecycles
            if lifecycle.entry_time <= timestamp < lifecycle.close_time
        )
        expected_opened = 0 if index == 0 else sum(
            1
            for lifecycle in lifecycles
            if lower_bound < lifecycle.entry_time <= timestamp
        )
        if open_positions != expected_open:
            raise SetupDataInvalid(
                f"open_positions_trade_reconciliation_mismatch:{index}:"
                f"{open_positions}!={expected_open}"
            )
        if opened_positions != expected_opened:
            raise SetupDataInvalid(
                f"opened_positions_trade_reconciliation_mismatch:{index}:"
                f"{opened_positions}!={expected_opened}"
            )
        expected_open_by_member = {
            member: sum(
                1
                for lifecycle in lifecycles
                if lifecycle.member == member
                and lifecycle.entry_time <= timestamp < lifecycle.close_time
            )
            for member in expected_members
        }
        expected_opened_by_member = {
            member: (
                0
                if index == 0
                else sum(
                    1
                    for lifecycle in lifecycles
                    if lifecycle.member == member
                    and lower_bound < lifecycle.entry_time <= timestamp
                )
            )
            for member in expected_members
        }
        if open_by_member != expected_open_by_member:
            raise SetupDataInvalid(f"open_positions_member_reconciliation_mismatch:{index}")
        if opened_by_member != expected_opened_by_member:
            raise SetupDataInvalid(
                f"opened_positions_member_reconciliation_mismatch:{index}"
            )
        normalized_rows.append(
            {
                "ts_utc": _timestamp_text(timestamp),
                "balance": format(balance, ".2f"),
                "equity": format(equity, ".2f"),
                "interval_min_equity": format(interval_min, ".2f"),
                "open_positions": open_positions,
                "opened_positions": opened_positions,
                "day_anchor": day_anchor,
            }
        )
        pending_orders.append(pending)
    final_timestamp = _parse_timestamp(rows[-1].get("t_utc"), "final_equity_t_utc")
    if any(event.timestamp > final_timestamp for lifecycle in lifecycles for event in lifecycle.balance_events):
        raise SetupDataInvalid("trade_balance_event_after_trace_end")
    first_timestamp = _parse_timestamp(rows[0].get("t_utc"), "first_equity_t_utc")
    if any(lifecycle.entry_time <= first_timestamp for lifecycle in lifecycles):
        raise SetupDataInvalid("position_lifecycle_not_strictly_after_clean_start")
    if any(lifecycle.close_time > final_timestamp for lifecycle in lifecycles):
        raise SetupDataInvalid("position_lifecycle_after_trace_end")
    if normalized_rows[0]["open_positions"] != 0 or pending_orders[0] != 0:
        raise SetupDataInvalid("trace_start_not_flat_without_pending_orders")
    if normalized_rows[-1]["open_positions"] != 0 or pending_orders[-1] != 0:
        raise SetupDataMissing("trace_end_not_flat_without_pending_orders")
    return normalized_rows, pending_orders


def adapt_and_evaluate(
    trade_rows: Sequence[Mapping[str, Any]],
    equity_rows: Sequence[Mapping[str, Any]],
    *,
    expected_members: Iterable[ExpectedMember],
    trade_sha256: str,
    equity_sha256: str,
    phase: str,
    provenance: ProvenanceBinding,
    rules_snapshot: RuleSnapshotBinding,
    initial_balance: Any = "100000.00",
    maximum_grid_seconds: int = 3600,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Return ``(artifact, normalized_trace_envelope_or_none)``.

    Contract errors are rendered as artifacts so automation cannot mistake a
    producer/setup defect for a strategy breach or a successful money gate.
    """

    members = _canonical_members(expected_members)
    if not isinstance(provenance, ProvenanceBinding):
        raise SetupDataMissing("validated_provenance_binding_required")
    if not isinstance(rules_snapshot, RuleSnapshotBinding):
        raise SetupDataMissing("validated_rules_snapshot_binding_required")
    if not _SHA256_RE.fullmatch(trade_sha256):
        raise SetupDataInvalid("trade_sha256_invalid")
    if not _SHA256_RE.fullmatch(equity_sha256):
        raise SetupDataInvalid("equity_sha256_invalid")
    trade_first = trade_rows[0] if trade_rows else None
    equity_first = equity_rows[0] if equity_rows else None
    if not equity_first or equity_first.get("event") != EQUITY_META_EVENT:
        return (
            _legacy_artifact(
                trade_first,
                equity_first,
                trade_sha256=trade_sha256,
                equity_sha256=equity_sha256,
            ),
            None,
        )
    try:
        trace_id, run_id, grid_seconds, money_decimals = _validate_metadata(
            equity_first,
            expected_members=members,
            provenance=provenance,
        )
        initial = _money(initial_balance, "initial_balance", money_decimals)
        lifecycles = _validate_trade_rows(
            trade_rows,
            expected_members=members,
            run_id=run_id,
            producer_version=provenance.producer_version,
            money_decimals=money_decimals,
        )
        points, pending_orders = _validate_point_rows(
            equity_rows[1:],
            expected_members=members,
            lifecycles=lifecycles,
            grid_seconds=grid_seconds,
            money_decimals=money_decimals,
            initial_balance=initial,
            trace_id=trace_id,
            run_id=run_id,
            producer_version=provenance.producer_version,
        )
        fingerprint_payload = {
            "adapter_schema_version": ADAPTER_SCHEMA_VERSION,
            "q08_trades_sha256": trade_sha256,
            "q08_equity_sha256": equity_sha256,
            "run_id": run_id,
            "producer_version": provenance.producer_version,
            "expected_members": [
                {"magic": member.magic, "symbol": member.symbol} for member in members
            ],
            "provenance": provenance.fingerprint_payload(),
            "rules_snapshot_sha256": rules_snapshot.sha256,
        }
        source_fingerprint = hashlib.sha256(
            json.dumps(
                fingerprint_payload, sort_keys=True, separators=(",", ":")
            ).encode("utf-8")
        ).hexdigest()
        trace_envelope = {
            "schema_version": rules_engine.TRACE_SCHEMA_VERSION,
            "trace_id": trace_id,
            "currency": "USD",
            "source_fingerprint_sha256": source_fingerprint,
            "money_decimals": money_decimals,
            "grid_seconds": grid_seconds,
            "balance_basis": rules_engine.BALANCE_BASIS_NET_TRADING,
            "equity_basis": rules_engine.EQUITY_BASIS_MTM,
            "opened_positions_basis": rules_engine.OPENED_POSITIONS_BASIS,
            "interval_min_equity_basis": rules_engine.INTERVAL_MIN_EQUITY_BASIS,
            "rows": points,
        }
        normalized = rules_engine.normalize_trace(trace_envelope)
        evaluation = rules_engine.evaluate_two_step_phase(
            normalized,
            phase=phase,
            initial_balance=format(initial, ".2f"),
            assumptions=rules_engine.EvaluationAssumptions(
                maximum_grid_seconds=maximum_grid_seconds
            ),
        )
        evaluation["validated_official_rules_snapshot"] = (
            rules_snapshot.artifact_payload()
        )
        artifact = {
            "schema_version": ADAPTER_SCHEMA_VERSION,
            "status": evaluation["status"],
            "reason": evaluation["reason"],
            "money_gate_eligible": evaluation["status"] == "SCREEN_PASS",
            "phase": str(phase).strip().upper(),
            "source": fingerprint_payload | {
                "source_fingerprint_sha256": source_fingerprint
            },
            "provenance": provenance.artifact_payload(),
            "rules_snapshot": rules_snapshot.artifact_payload(),
            "coverage": {
                "basis": COVERAGE_BASIS,
                "grid_seconds": grid_seconds,
                "points": len(points),
                "position_lifecycles": len(lifecycles),
                "pending_order_state_complete": True,
                "maximum_pending_orders_observed": max(pending_orders, default=0),
                "prague_day_anchors": sum(1 for point in points if point["day_anchor"]),
            },
            "evaluation": evaluation,
            "challenge_proof": False,
        }
        return artifact, trace_envelope
    except EvidenceContractError as exc:
        return {
            "schema_version": ADAPTER_SCHEMA_VERSION,
            "status": exc.status,
            "reason": exc.reason,
            "money_gate_eligible": False,
            "details": list(exc.details),
            "source": {
                "q08_trades_sha256": trade_sha256,
                "q08_equity_sha256": equity_sha256,
            },
            "provenance": provenance.artifact_payload(),
            "rules_snapshot": rules_snapshot.artifact_payload(),
            "challenge_proof": False,
        }, None
    except rules_engine.TraceValidationError as exc:
        return {
            "schema_version": ADAPTER_SCHEMA_VERSION,
            "status": "SETUP_DATA_INVALID",
            "reason": f"ftmo_trace_validation_failed:{exc}",
            "money_gate_eligible": False,
            "source": {
                "q08_trades_sha256": trade_sha256,
                "q08_equity_sha256": equity_sha256,
            },
            "provenance": provenance.artifact_payload(),
            "rules_snapshot": rules_snapshot.artifact_payload(),
            "challenge_proof": False,
        }, None


def evaluate_files(
    trades_path: Path,
    equity_path: Path,
    *,
    expected_members: Iterable[ExpectedMember],
    phase: str,
    runner_receipt_path: Path | None = None,
    expected_runner_receipt_sha256: str | None = None,
    ex5_path: Path | None = None,
    expected_ex5_sha256: str | None = None,
    setfile_path: Path | None = None,
    expected_setfile_sha256: str | None = None,
    report_path: Path | None = None,
    expected_report_sha256: str | None = None,
    expected_work_item_id: str | None = None,
    expected_evidence_run_id: str | None = None,
    expected_producer_version: str | None = None,
    rules_snapshot_path: Path | None = None,
    expected_rules_snapshot_sha256: str | None = None,
    initial_balance: Any = "100000.00",
    maximum_grid_seconds: int = 3600,
    evaluated_at_utc: dt.datetime | None = None,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    # Each source is read exactly once.  The digest and JSON rows therefore bind
    # the same immutable byte snapshot even if an upstream file is concurrently
    # replaced or appended; the runner receipt hash check below then proves that
    # this snapshot is the governed harvested one.
    trade_bytes, trade_hash = _read_snapshot(trades_path, "q08_trades")
    equity_bytes, equity_hash = _read_snapshot(equity_path, "q08_equity")
    trade_rows = _parse_jsonl_snapshot(trade_bytes, "q08_trades")
    first_equity = _parse_jsonl_snapshot(
        equity_bytes, "q08_equity", first_only=True
    )[0]
    if first_equity.get("event") != EQUITY_META_EVENT:
        return (
            _legacy_artifact(
                trade_rows[0] if trade_rows else None,
                first_equity,
                trade_sha256=trade_hash,
                equity_sha256=equity_hash,
            ),
            None,
        )
    required = {
        "runner_receipt_path": runner_receipt_path,
        "expected_runner_receipt_sha256": expected_runner_receipt_sha256,
        "ex5_path": ex5_path,
        "expected_ex5_sha256": expected_ex5_sha256,
        "setfile_path": setfile_path,
        "expected_setfile_sha256": expected_setfile_sha256,
        "report_path": report_path,
        "expected_report_sha256": expected_report_sha256,
        "expected_work_item_id": expected_work_item_id,
        "expected_evidence_run_id": expected_evidence_run_id,
        "expected_producer_version": expected_producer_version,
        "rules_snapshot_path": rules_snapshot_path,
        "expected_rules_snapshot_sha256": expected_rules_snapshot_sha256,
    }
    missing = [key for key, value in required.items() if value is None or value == ""]
    if missing:
        raise SetupDataMissing(
            "money_gate_provenance_arguments_missing", details=missing
        )
    assert runner_receipt_path is not None
    assert ex5_path is not None
    assert setfile_path is not None
    assert report_path is not None
    assert rules_snapshot_path is not None
    provenance = validate_provenance(
        runner_receipt_path=runner_receipt_path,
        expected_runner_receipt_sha256=str(expected_runner_receipt_sha256),
        ex5_path=ex5_path,
        expected_ex5_sha256=str(expected_ex5_sha256),
        setfile_path=setfile_path,
        expected_setfile_sha256=str(expected_setfile_sha256),
        report_path=report_path,
        expected_report_sha256=str(expected_report_sha256),
        trades_path=trades_path,
        trade_sha256=trade_hash,
        equity_path=equity_path,
        equity_sha256=equity_hash,
        expected_work_item_id=str(expected_work_item_id),
        expected_evidence_run_id=str(expected_evidence_run_id),
        expected_producer_version=str(expected_producer_version),
    )
    rules_snapshot = validate_rule_snapshot(
        rules_snapshot_path,
        expected_sha256=str(expected_rules_snapshot_sha256),
        evaluated_at_utc=evaluated_at_utc,
    )
    equity_rows = _parse_jsonl_snapshot(equity_bytes, "q08_equity")
    return adapt_and_evaluate(
        trade_rows,
        equity_rows,
        expected_members=expected_members,
        trade_sha256=trade_hash,
        equity_sha256=equity_hash,
        phase=phase,
        provenance=provenance,
        rules_snapshot=rules_snapshot,
        initial_balance=initial_balance,
        maximum_grid_seconds=maximum_grid_seconds,
    )


def _path_identity(path: Path) -> str:
    return os.path.normcase(str(path.resolve(strict=False)))


def _validate_output_paths(
    *,
    out: Path,
    trace_out: Path,
    protected_inputs: Iterable[Path | None],
) -> None:
    out_identity = _path_identity(out)
    trace_identity = _path_identity(trace_out)
    if out_identity == trace_identity:
        raise SetupDataInvalid("output_paths_collide")
    protected = {
        _path_identity(path) for path in protected_inputs if path is not None
    }
    if out_identity in protected or trace_identity in protected:
        raise SetupDataInvalid("output_path_collides_with_input")
    if out.exists():
        raise SetupDataInvalid("artifact_output_already_exists")
    if trace_out.exists():
        raise SetupDataInvalid("trace_output_already_exists")


def _write_json_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(value, indent=2, sort_keys=True) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(rendered)
        handle.flush()
        os.fsync(handle.fileno())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trades", type=Path, required=True)
    parser.add_argument("--equity", type=Path, required=True)
    parser.add_argument(
        "--member",
        action="append",
        type=parse_member,
        required=True,
        help="Expected exact book member MAGIC:SYMBOL; repeat for every sleeve.",
    )
    parser.add_argument("--phase", choices=("PHASE1", "VERIFICATION"), default="PHASE1")
    parser.add_argument("--initial-balance", default="100000.00")
    parser.add_argument("--maximum-grid-seconds", type=int, default=3600)
    parser.add_argument("--runner-receipt", type=Path)
    parser.add_argument("--expected-runner-receipt-sha256")
    parser.add_argument("--ex5", type=Path)
    parser.add_argument("--expected-ex5-sha256")
    parser.add_argument("--setfile", type=Path)
    parser.add_argument("--expected-setfile-sha256")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--expected-report-sha256")
    parser.add_argument("--expected-work-item-id")
    parser.add_argument("--expected-evidence-run-id")
    parser.add_argument("--expected-producer-version")
    parser.add_argument("--rules-snapshot", type=Path)
    parser.add_argument("--expected-rules-snapshot-sha256")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--trace-out", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        _validate_output_paths(
            out=args.out,
            trace_out=args.trace_out,
            protected_inputs=(
                args.trades,
                args.equity,
                args.runner_receipt,
                args.ex5,
                args.setfile,
                args.report,
                args.rules_snapshot,
            ),
        )
    except EvidenceContractError as exc:
        print(
            json.dumps(
                {
                    "schema_version": ADAPTER_SCHEMA_VERSION,
                    "status": exc.status,
                    "reason": exc.reason,
                    "money_gate_eligible": False,
                    "challenge_proof": False,
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    try:
        artifact, trace = evaluate_files(
            args.trades,
            args.equity,
            expected_members=args.member,
            phase=args.phase,
            runner_receipt_path=args.runner_receipt,
            expected_runner_receipt_sha256=args.expected_runner_receipt_sha256,
            ex5_path=args.ex5,
            expected_ex5_sha256=args.expected_ex5_sha256,
            setfile_path=args.setfile,
            expected_setfile_sha256=args.expected_setfile_sha256,
            report_path=args.report,
            expected_report_sha256=args.expected_report_sha256,
            expected_work_item_id=args.expected_work_item_id,
            expected_evidence_run_id=args.expected_evidence_run_id,
            expected_producer_version=args.expected_producer_version,
            rules_snapshot_path=args.rules_snapshot,
            expected_rules_snapshot_sha256=args.expected_rules_snapshot_sha256,
            initial_balance=args.initial_balance,
            maximum_grid_seconds=args.maximum_grid_seconds,
        )
    except EvidenceContractError as exc:
        artifact = {
            "schema_version": ADAPTER_SCHEMA_VERSION,
            "status": exc.status,
            "reason": exc.reason,
            "money_gate_eligible": False,
            "details": list(exc.details),
            "challenge_proof": False,
        }
        trace = None
    # Publish an admissible trace before its decision artifact.  A caught write
    # failure can therefore never leave a SCREEN_PASS artifact that points to a
    # missing trace.  Existing paths and all input/output collisions were refused
    # before any source was evaluated.
    if trace is not None:
        _write_json_exclusive(args.trace_out, trace)
    _write_json_exclusive(args.out, artifact)
    if trace is None:
        print("trace not written: source evidence is not admissible")
    return 0 if artifact["status"] == "SCREEN_PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
