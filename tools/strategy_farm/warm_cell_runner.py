"""Fail-closed V4a warm-cell runner contract and offline parity probe.

The production cold worker is deliberately not imported or modified here.  The
runner accepts an injected resident-session backend, so orchestration and parity
logic can be tested without launching MetaTrader.  No production backend is
provided by this ticket: the currently governed CLI consumes tester settings at
terminal startup and does not expose a supported command for a second test in an
already-running terminal.

The command-line entry point is read-only with respect to the farm.  It inventories
authenticated cold GBPUSD references, derives canonical report-metric and closed-
trade bytes, and writes a deviation packet.  It never launches terminal64.exe.
"""
from __future__ import annotations

import argparse
import csv
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import statistics
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Mapping, Protocol, Sequence


# Direct execution sets sys.path to tools/strategy_farm, while the authenticated
# native-report parser lives under framework/scripts.
REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))


FLAG_NAME = "QM_ENABLE_WARM_CELL_RUNNER"
TASK_ID = "c7536f46-2c1e-4ab9-b18c-47cfe01c6491"
PHASE2_TASK_ID = "7d800fe1-be0d-42df-8e67-a9b9a55d0906"
PHASE3_TASK_ID = "2cb9d160-d5c0-46ea-ae45-d145a63cf1f4"
PHASE5_REBASE_TASK_ID = "d3f39dce-ebc5-49fd-a781-dacd049baa68"
PHASE5_OWNER_DECISION_ID = "OWNER-DEC-DEV2-6140-SEAL"
PHASE5_OWNER_DECISION_SHA256 = (
    "781ee98be8931c645a25863f39787081d1a5a82f9df1cdaf2a0f26fa48d03f2b"
)
VALIDATION_TASK_IDS = frozenset(
    {TASK_ID, PHASE2_TASK_ID, PHASE3_TASK_ID, PHASE5_REBASE_TASK_ID}
)
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
MIN_PARITY_CELLS = 20
GOVERNED_RESTART_BACKEND = "GOVERNED_SEQUENTIAL_TESTER_RESTART"
GOVERNED_RESTART_PROFILE = "ISOLATED_DEV2"
DEV2_ROOT = Path(r"D:\QM\mt5\DEV2")
DEV2_REPORTS_ROOT = Path(r"D:\QM\reports\dev2")
DEV2_CONTROLLER_RELATIVE = Path("framework/scripts/run_dev2_smoke.ps1")
DEV2_LANE_CONTRACT_RELATIVE = Path("framework/registry/dev2_lane_contract.json")
DEV2_CREDENTIAL = Path(r"C:\ProgramData\QM\DEV2\credential.machine-dpapi.json")
DEV2_CREDENTIAL_HELPER_RELATIVE = Path("framework/scripts/dev2_machine_credential.ps1")
IDENTITY_FIELDS = (
    "ea_id",
    "symbol",
    "period",
    "model",
    "seed",
    "from_date",
    "to_date",
    "ex5_sha256",
    "mq5_sha256",
    "setfile_sha256",
    "history_manifest_sha256",
)
COLD_PATH_FILES = (
    Path("tools/strategy_farm/terminal_worker.py"),
    Path("framework/scripts/run_smoke.ps1"),
    Path("tools/strategy_farm/opt_census.py"),
    Path("tools/strategy_farm/dl089_matrix_service.py"),
)
# Captured before this task's first edit.  These are physical worktree bytes,
# so CRLF checkout normalization cannot create a false difference against a
# Git blob whose stored bytes use LF.
TASK_START_COLD_PATH_SHA256 = {
    "tools/strategy_farm/terminal_worker.py": "60b80ed28ea1866719fdd75d86f6c48b5560fc7c2ad4eacb7a750cbaf8ea0039",
    "framework/scripts/run_smoke.ps1": "750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a",
    "tools/strategy_farm/opt_census.py": "1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a",
    "tools/strategy_farm/dl089_matrix_service.py": "14d5c0ff11cd65846bd59436a1ab40e3375e154e553c4368b21ebe0c91a51a0c",
}
# Captured immediately before the Phase-2 evidence-tool edit.  DL-089 changed
# terminal_worker.py and dl089_matrix_service.py after the Phase-1 packet, so a
# fresh task boundary is required rather than comparing against stale Phase-1
# bytes.  None of these four governed cold-path files is edited by Phase 2.
PHASE2_TASK_START_COLD_PATH_SHA256 = {
    "tools/strategy_farm/terminal_worker.py": "78d98a793f501bd833d98a912a7d4f8395fd8830d3f2ed6a389a8920b93144bb",
    "framework/scripts/run_smoke.ps1": "750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a",
    "tools/strategy_farm/opt_census.py": "1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a",
    "tools/strategy_farm/dl089_matrix_service.py": "30e3929f3408b801fc47c93f68adcc288f1e418b8ed7d8fe3e707ecaaebf8bb7",
}
# Re-authenticated at the Phase-3 task boundary.  The equality with the Phase-2
# values is intentional evidence that the commissioned backend did not require a
# cold worker, run_smoke, optimizer-census, or DL-089 receipt change.
PHASE3_TASK_START_COLD_PATH_SHA256 = dict(PHASE2_TASK_START_COLD_PATH_SHA256)
# OWNER-DEC-DEV2-6140-SEAL successor boundary.  The governed production/cold
# files remain unchanged by the DEV2-only rebase and parity replay.
PHASE5_TASK_START_COLD_PATH_SHA256 = dict(PHASE2_TASK_START_COLD_PATH_SHA256)


class FlagValueError(ValueError):
    """Raised when the feature flag is neither explicitly on nor off."""


class ActivationRefused(RuntimeError):
    """Raised when warm execution lacks a complete external approval seal."""


class ParityDeviation(RuntimeError):
    """Raised immediately when a warm cell differs from its cold reference."""

    def __init__(
        self,
        message: str,
        *,
        comparisons: Sequence[Mapping[str, Any]] | None = None,
        warm_result: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.comparisons = [dict(row) for row in (comparisons or [])]
        self.warm_result = dict(warm_result or {})


class ResidentSessionBackend(Protocol):
    """Backend boundary for a future, separately reviewed resident tester adapter."""

    def open_session(self, pair_contract: Mapping[str, Any]) -> Any: ...

    def run_cell(self, session: Any, cell: Mapping[str, Any]) -> Mapping[str, Any]: ...

    def close_session(self, session: Any) -> None: ...


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def feature_flag_enabled(environ: Mapping[str, str] | None = None) -> bool:
    """Return the explicit flag state; absent/blank is Default-OFF."""

    source = os.environ if environ is None else environ
    raw = source.get(FLAG_NAME)
    if raw is None or not str(raw).strip():
        return False
    normalized = str(raw).strip().lower()
    if normalized in {"0", "false", "no", "off"}:
        return False
    if normalized in {"1", "true", "yes", "on"}:
        return True
    raise FlagValueError(
        f"{FLAG_NAME} must be an explicit on/off value; got {raw!r}"
    )


def activation_problems(manifest: Mapping[str, Any] | None) -> list[str]:
    """Validate the external seal required before an injected backend may run."""

    if not manifest:
        return ["ACTIVATION_MANIFEST_MISSING"]
    problems: list[str] = []
    expected = {
        "schema": "qm.warm-cell-activation/v1",
        "review_state": "APPROVED",
        "approved_by": "OWNER",
        "activation_authorized": True,
        "all_exact": True,
        "execution_backend": "SUPPORTED_RESIDENT_TESTER_CONTROL",
        "profile_mode": "DISPOSABLE",
        "cold_path_default": "OFF",
    }
    for field, value in expected.items():
        if manifest.get(field) != value:
            problems.append(f"ACTIVATION_{field.upper()}_INVALID")
    try:
        comparisons = int(manifest.get("comparison_count") or 0)
    except (TypeError, ValueError):
        comparisons = 0
    if comparisons < MIN_PARITY_CELLS:
        problems.append("ACTIVATION_PARITY_SAMPLE_BELOW_20")
    if not str(manifest.get("parity_packet_sha256") or "").strip():
        problems.append("ACTIVATION_PARITY_PACKET_UNBOUND")
    return problems


def validation_authorization_problems(
    manifest: Mapping[str, Any] | None,
) -> list[str]:
    """Validate a non-production seal for the first disposable parity run."""

    if not manifest:
        return ["VALIDATION_AUTHORIZATION_MISSING"]
    problems: list[str] = []
    expected = {
        "schema": "qm.warm-cell-validation-run/v1",
        "purpose": "OFFLINE_PARITY_VALIDATION",
        "authorized_by": "OWNER_COMMISSION",
        "production_wiring": False,
        "active_terminal_allowed": False,
    }
    for field, value in expected.items():
        if manifest.get(field) != value:
            problems.append(f"VALIDATION_{field.upper()}_INVALID")
    if manifest.get("task_id") not in VALIDATION_TASK_IDS:
        problems.append("VALIDATION_TASK_ID_INVALID")
    backend_profile = (
        manifest.get("execution_backend"),
        manifest.get("profile_mode"),
    )
    allowed_backend_profiles = {
        ("SUPPORTED_RESIDENT_TESTER_CONTROL", "DISPOSABLE"),
        (GOVERNED_RESTART_BACKEND, GOVERNED_RESTART_PROFILE),
    }
    if backend_profile not in allowed_backend_profiles:
        problems.append("VALIDATION_BACKEND_PROFILE_INVALID")
    if backend_profile == (GOVERNED_RESTART_BACKEND, GOVERNED_RESTART_PROFILE):
        if manifest.get("task_id") not in {PHASE3_TASK_ID, PHASE5_REBASE_TASK_ID}:
            problems.append("VALIDATION_RESTART_TASK_ID_INVALID")
        if manifest.get("lane") != "DEV2":
            problems.append("VALIDATION_RESTART_LANE_INVALID")
    if manifest.get("task_id") == PHASE5_REBASE_TASK_ID:
        phase5_expected = {
            "owner_decision_id": PHASE5_OWNER_DECISION_ID,
            "owner_decision_sha256": PHASE5_OWNER_DECISION_SHA256,
            "owner_signature": PHASE5_OWNER_DECISION_ID,
            "candidate_program_build": 6140,
            "allow_mixed_pairs": True,
        }
        for field, value in phase5_expected.items():
            if manifest.get(field) != value:
                problems.append(f"VALIDATION_PHASE5_{field.upper()}_INVALID")
        for field in (
            "candidate_lane_contract_sha256",
            "cold_reference_csv_sha256",
            "common_history_manifest_sha256",
        ):
            if not re.fullmatch(r"[0-9a-f]{64}", str(manifest.get(field) or "")):
                problems.append(f"VALIDATION_PHASE5_{field.upper()}_INVALID")
    try:
        minimum = int(manifest.get("minimum_comparisons") or 0)
    except (TypeError, ValueError):
        minimum = 0
    if minimum < MIN_PARITY_CELLS:
        problems.append("VALIDATION_PARITY_SAMPLE_BELOW_20")
    return problems


def require_run_authorization(
    *,
    environ: Mapping[str, str] | None,
    manifest: Mapping[str, Any] | None,
) -> str:
    """Return COLD/VALIDATION/ACTIVATION or fail closed before backend use."""

    if not feature_flag_enabled(environ):
        return "COLD"
    schema = str((manifest or {}).get("schema") or "")
    if schema == "qm.warm-cell-validation-run/v1":
        problems = validation_authorization_problems(manifest)
        mode = "VALIDATION"
    else:
        problems = activation_problems(manifest)
        mode = "ACTIVATION"
    if problems:
        raise ActivationRefused(";".join(problems))
    return mode


def require_activation(
    *,
    environ: Mapping[str, str] | None,
    activation_manifest: Mapping[str, Any] | None,
) -> bool:
    """Return False for cold-path execution or raise unless warm use is sealed."""

    if not feature_flag_enabled(environ):
        return False
    problems = activation_problems(activation_manifest)
    if problems:
        raise ActivationRefused(";".join(problems))
    return True


def _json_ready(value: Any) -> Any:
    if dataclasses.is_dataclass(value):
        return _json_ready(dataclasses.asdict(value))
    if isinstance(value, dt.datetime):
        rendered = value.astimezone(dt.timezone.utc).isoformat()
        return rendered.replace("+00:00", "Z")
    if isinstance(value, Mapping):
        return {str(key): _json_ready(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_ready(item) for item in value]
    return value


def _json_field_paths(value: Any, prefix: str = "$") -> list[str]:
    """Return a deterministic field-shape inventory without retaining values."""

    if isinstance(value, Mapping):
        rows = [f"{prefix}:object"]
        for key in sorted(str(item) for item in value):
            rows.extend(_json_field_paths(value[key], f"{prefix}.{key}"))
        return rows
    if isinstance(value, (list, tuple)):
        rows = [f"{prefix}:array"]
        shapes = {
            tuple(_json_field_paths(item, f"{prefix}[]")) for item in value
        }
        for shape in sorted(shapes):
            rows.extend(shape)
        return rows
    return [f"{prefix}:scalar"]


def receipt_schema_fingerprint(summary: Mapping[str, Any]) -> dict[str, Any]:
    fields = _json_field_paths(summary)
    return {
        "field_paths": fields,
        "field_path_count": len(fields),
        "sha256": sha256_bytes(canonical_json_bytes(fields)),
    }


def result_fingerprints(result: Mapping[str, Any]) -> dict[str, Any]:
    """Fingerprint exact identity, report fields, and canonical trade-list bytes."""

    identity = {field: result.get(field) for field in IDENTITY_FIELDS}
    metrics = _json_ready(result.get("report_metrics") or {})
    trades = _json_ready(result.get("trades") or [])
    identity_bytes = canonical_json_bytes(identity)
    metric_bytes = canonical_json_bytes(metrics)
    trade_bytes = canonical_json_bytes(trades)
    return {
        "identity": identity,
        "report_metrics": metrics,
        "trades": trades,
        "identity_sha256": sha256_bytes(identity_bytes),
        "report_metrics_sha256": sha256_bytes(metric_bytes),
        "trade_list_sha256": sha256_bytes(trade_bytes),
        "trade_count": len(trades),
        "entry_trading_days": result.get("entry_trading_days"),
        "logger_sample_sha256": result.get("logger_sample_sha256"),
        "native_report_sha256": result.get("native_report_sha256")
        or result.get("report_sha256"),
        "receipt_schema_sha256": result.get("receipt_schema_sha256"),
    }


def compare_cell_results(
    cold: Mapping[str, Any], warm: Mapping[str, Any]
) -> dict[str, Any]:
    cold_fp = result_fingerprints(cold)
    warm_fp = result_fingerprints(warm)
    identity_mismatches = [
        field
        for field in IDENTITY_FIELDS
        if cold_fp["identity"].get(field) != warm_fp["identity"].get(field)
    ]
    cell_key_match = cold.get("cell_key") == warm.get("cell_key")
    metric_match = cold_fp["report_metrics_sha256"] == warm_fp["report_metrics_sha256"]
    trade_match = cold_fp["trade_list_sha256"] == warm_fp["trade_list_sha256"]
    entry_days_match = (
        cold_fp["entry_trading_days"] == warm_fp["entry_trading_days"]
    )
    logger_match = (
        cold_fp["logger_sample_sha256"] == warm_fp["logger_sample_sha256"]
    )
    native_report_match = (
        cold_fp["native_report_sha256"] == warm_fp["native_report_sha256"]
    )
    receipt_schema_match = (
        cold_fp["receipt_schema_sha256"] == warm_fp["receipt_schema_sha256"]
    )
    exact = (
        cell_key_match
        and not identity_mismatches
        and metric_match
        and trade_match
        and entry_days_match
        and logger_match
        and native_report_match
        and receipt_schema_match
    )
    return {
        "cell_key": cold.get("cell_key"),
        "warm_cell_key": warm.get("cell_key"),
        "cell_key_match": cell_key_match,
        "identity_exact_match": not identity_mismatches,
        "identity_mismatch_fields": identity_mismatches,
        "report_metrics_field_exact_match": metric_match,
        "trade_list_byte_exact_match": trade_match,
        "entry_trading_days_exact_match": entry_days_match,
        "logger_sample_byte_exact_match": logger_match,
        "native_report_byte_exact_match": native_report_match,
        "receipt_schema_exact_match": receipt_schema_match,
        "all_exact": exact,
        "cold_identity_sha256": cold_fp["identity_sha256"],
        "warm_identity_sha256": warm_fp["identity_sha256"],
        "cold_report_metrics_sha256": cold_fp["report_metrics_sha256"],
        "warm_report_metrics_sha256": warm_fp["report_metrics_sha256"],
        "cold_trade_list_sha256": cold_fp["trade_list_sha256"],
        "warm_trade_list_sha256": warm_fp["trade_list_sha256"],
        "cold_trade_count": cold_fp["trade_count"],
        "warm_trade_count": warm_fp["trade_count"],
        "cold_entry_trading_days": cold_fp["entry_trading_days"],
        "warm_entry_trading_days": warm_fp["entry_trading_days"],
        "cold_logger_sample_sha256": cold_fp["logger_sample_sha256"],
        "warm_logger_sample_sha256": warm_fp["logger_sample_sha256"],
        "cold_native_report_sha256": cold_fp["native_report_sha256"],
        "warm_native_report_sha256": warm_fp["native_report_sha256"],
        "cold_receipt_schema_sha256": cold_fp["receipt_schema_sha256"],
        "warm_receipt_schema_sha256": warm_fp["receipt_schema_sha256"],
        "cold_elapsed_seconds": cold.get("cold_elapsed_seconds"),
        "warm_elapsed_seconds": warm.get("warm_elapsed_seconds"),
    }


def parity_summary(
    comparisons: Sequence[Mapping[str, Any]], *, minimum: int = MIN_PARITY_CELLS
) -> dict[str, Any]:
    unique_keys = {str(row.get("cell_key")) for row in comparisons if row.get("cell_key")}
    exact_count = sum(1 for row in comparisons if row.get("all_exact") is True)
    problems: list[str] = []
    if len(comparisons) < minimum or len(unique_keys) < minimum:
        problems.append("PARITY_SAMPLE_BELOW_MINIMUM")
    if exact_count != len(comparisons):
        problems.append("PARITY_DEVIATION_PRESENT")
    return {
        "schema": "qm.warm-cell-parity/v1",
        "minimum_required": minimum,
        "comparison_count": len(comparisons),
        "unique_cell_count": len(unique_keys),
        "exact_count": exact_count,
        "all_exact": not problems,
        "problems": problems,
    }


class WarmCellRunner:
    """Sequential single-session runner; backend activation is externally sealed."""

    def __init__(self, backend: ResidentSessionBackend):
        self.backend = backend

    def run(
        self,
        *,
        cells: Sequence[Mapping[str, Any]],
        cold_references: Mapping[str, Mapping[str, Any]],
        environ: Mapping[str, str] | None = None,
        activation_manifest: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        authorization_mode = require_run_authorization(
            environ=environ, manifest=activation_manifest
        )
        if authorization_mode == "COLD":
            return {
                "status": "COLD_PATH_UNCHANGED",
                "flag": FLAG_NAME,
                "flag_enabled": False,
                "cells_executed": 0,
            }
        if len(cells) < MIN_PARITY_CELLS:
            raise ActivationRefused("RUN_BATCH_BELOW_20_CELLS")
        keys = [str(cell.get("cell_key") or "") for cell in cells]
        if any(not key for key in keys) or len(set(keys)) != len(keys):
            raise ActivationRefused("RUN_BATCH_CELL_KEYS_INVALID")
        if any(key not in cold_references for key in keys):
            raise ActivationRefused("RUN_BATCH_COLD_REFERENCE_MISSING")

        pair_fields = ("ea_id", "symbol", "period", "ex5_sha256", "history_manifest_sha256")
        first = cold_references[keys[0]]
        pair_contract = {field: first.get(field) for field in pair_fields}
        mixed_pair = any(
            any(
                cold_references[key].get(field) != pair_contract[field]
                for field in pair_fields
            )
            for key in keys[1:]
        )
        phase5_mixed_authorized = bool(
            (activation_manifest or {}).get("task_id") == PHASE5_REBASE_TASK_ID
            and (activation_manifest or {}).get("allow_mixed_pairs") is True
        )
        if mixed_pair and not phase5_mixed_authorized:
            raise ActivationRefused("RUN_BATCH_PAIR_IDENTITY_MIXED")
        if mixed_pair:
            histories = {
                str(cold_references[key].get("history_manifest_sha256") or "")
                for key in keys
            }
            if len(histories) != 1 or "" in histories:
                raise ActivationRefused("RUN_BATCH_MIXED_HISTORY_MANIFEST")
            pair_contract = {
                "history_manifest_sha256": next(iter(histories)),
                "mixed_pairs": True,
                "pair_count": len(
                    {
                        (
                            cold_references[key].get("ea_id"),
                            cold_references[key].get("symbol"),
                            cold_references[key].get("period"),
                            cold_references[key].get("ex5_sha256"),
                        )
                        for key in keys
                    }
                ),
            }

        session = self.backend.open_session(pair_contract)
        comparisons: list[dict[str, Any]] = []
        try:
            for cell in cells:
                key = str(cell["cell_key"])
                warm = self.backend.run_cell(session, cell)
                comparison = compare_cell_results(cold_references[key], warm)
                comparisons.append(comparison)
                if not comparison["all_exact"]:
                    raise ParityDeviation(
                        f"warm parity deviation at {key}: "
                        + ",".join(comparison["identity_mismatch_fields"]),
                        comparisons=comparisons,
                        warm_result=warm,
                    )
        finally:
            self.backend.close_session(session)

        summary = parity_summary(comparisons)
        if not summary["all_exact"]:
            raise ParityDeviation(
                "warm parity sample did not satisfy the sealed minimum",
                comparisons=comparisons,
            )
        return {
            "status": "EXACT_PARITY",
            "flag": FLAG_NAME,
            "flag_enabled": True,
            "cells_executed": len(comparisons),
            "session_count": 1,
            "authorization_mode": authorization_mode,
            "comparisons": comparisons,
            "parity": summary,
        }


def _read_only_connection(path: Path) -> sqlite3.Connection:
    resolved = Path(path).resolve()
    con = sqlite3.connect(resolved.as_uri() + "?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only=ON")
    return con


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _utc_datetime(value: Any) -> dt.datetime | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    try:
        parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def elapsed_seconds(start: Any, end: Any) -> float | None:
    started = _utc_datetime(start)
    completed = _utc_datetime(end)
    if started is None or completed is None or completed < started:
        return None
    return round((completed - started).total_seconds(), 3)


def _canonical_closed_trades(report_path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    from framework.scripts.q10_recency import extract_closed_trades

    trades, stats = extract_closed_trades(report_path)
    return _json_ready(trades), _json_ready(stats)


def cold_references(
    con: sqlite3.Connection,
    *,
    ea_id: str = "QM5_41161",
    symbol: str = "GBPUSD.DWX",
    year: int = 2019,
) -> list[dict[str, Any]]:
    rows = con.execute(
        """
        SELECT id, evidence_path, payload_json, ex5_sha256, setfile_sha256,
               mq5_sha256, updated_at
        FROM work_items
        WHERE ea_id=? AND symbol=? AND phase='OPT_CENSUS'
          AND status='done' AND verdict='MEASURED'
        ORDER BY updated_at, id
        """,
        (ea_id, symbol),
    ).fetchall()
    output: list[dict[str, Any]] = []
    for row in rows:
        payload = json.loads(row["payload_json"] or "{}")
        if int(payload.get("year") or 0) != int(year):
            continue
        record: dict[str, Any] = {
            "cell_key": payload.get("cell_key"),
            "work_item_id": row["id"],
            "arm": payload.get("arm"),
            "direction": str(payload.get("direction") or "NONE").upper(),
            "predicate_id": int(payload.get("predicate_id") or 0),
            "ea_id": ea_id,
            "symbol": symbol,
            "period": payload.get("expected_period") or payload.get("host_timeframe"),
            "model": None,
            "seed": payload.get("seed", payload.get("requested_seed")),
            "from_date": payload.get("from_date") or payload.get("expected_from_date"),
            "to_date": payload.get("to_date") or payload.get("expected_to_date"),
            "ex5_sha256": row["ex5_sha256"] or payload.get("expected_ex5_sha256"),
            "mq5_sha256": row["mq5_sha256"] or payload.get("expected_mq5_sha256"),
            "setfile_sha256": row["setfile_sha256"] or payload.get("expected_setfile_sha256"),
            "history_manifest_sha256": (
                payload.get("custom_history_copy_on_claim") or {}
            ).get("manifest_sha256"),
            "history_receipt_path": (
                payload.get("custom_history_copy_on_claim") or {}
            ).get("receipt_path"),
            "summary_path": str(row["evidence_path"] or ""),
            "updated_at": row["updated_at"],
            "started_at_utc": payload.get("started_at_iso"),
            "reference_status": "INVALID",
            "reference_errors": [],
        }
        try:
            summary_path = Path(record["summary_path"])
            summary = _load_json(summary_path)
            if summary.get("evidence_schema") != "run_smoke/v2":
                raise ValueError(
                    f"unexpected cold receipt schema: {summary.get('evidence_schema')!r}"
                )
            ok_runs = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
            if len(ok_runs) != 1:
                raise ValueError(f"expected one OK run, found {len(ok_runs)}")
            run = ok_runs[0]
            record["completed_at_utc"] = summary.get("timestamp_utc") or row["updated_at"]
            record["cold_elapsed_seconds"] = elapsed_seconds(
                record["started_at_utc"], record["completed_at_utc"]
            )
            report_path = Path(str(run.get("report_canonical_path") or ""))
            if not report_path.is_file():
                raise ValueError(f"native report missing: {report_path}")
            trades, parsed_stats = _canonical_closed_trades(report_path)
            actual_report_sha256 = sha256_file(report_path)
            recorded_report_sha256 = str(run.get("report_sha256") or "").lower()
            if recorded_report_sha256 and recorded_report_sha256 != actual_report_sha256:
                raise ValueError("cold native report hash does not match its receipt")
            record["model"] = summary.get("model")
            record["report_path"] = str(report_path.resolve())
            record["report_sha256"] = actual_report_sha256
            record["native_report_sha256"] = actual_report_sha256
            record["summary_sha256"] = sha256_file(summary_path)
            receipt_schema = receipt_schema_fingerprint(summary)
            record["receipt_schema_sha256"] = receipt_schema["sha256"]
            record["receipt_schema_field_paths"] = receipt_schema["field_paths"]
            record["entry_trading_days"] = len(
                {
                    str(trade.get("entry_time") or "")[:10]
                    for trade in trades
                    if trade.get("entry_time")
                }
            )
            logger_path = Path(
                str(
                    summary.get("logger_sample_path")
                    or (summary.get("logger_sample") or {}).get("path")
                    or ""
                )
            )
            if not logger_path.is_file():
                raise ValueError(f"cold logger sample missing: {logger_path}")
            actual_logger_sha256 = sha256_file(logger_path)
            recorded_logger_sha256 = str(
                (summary.get("logger_sample") or {}).get("sha256") or ""
            ).lower()
            if recorded_logger_sha256 and recorded_logger_sha256 != actual_logger_sha256:
                raise ValueError("cold logger sample hash does not match its receipt")
            record["logger_sample_path"] = str(logger_path.resolve())
            record["logger_sample_sha256"] = actual_logger_sha256
            setfile_source = Path(
                str(
                    ((summary.get("execution_identity") or {}).get("setfile") or {})
                    .get("source", {})
                    .get("path", "")
                )
            )
            if not setfile_source.is_file():
                raise ValueError(f"cold setfile source missing: {setfile_source}")
            if sha256_file(setfile_source) != str(record["setfile_sha256"]).lower():
                raise ValueError("cold setfile source hash does not match work item")
            record["setfile_source_path"] = str(setfile_source.resolve())
            record["expert"] = summary.get("expert")
            record["ea_label"] = summary.get("ea_label")
            record["report_metrics"] = {
                "total_trades": run.get("total_trades"),
                "total_trades_raw": run.get("total_trades_raw"),
                "profit_factor": run.get("profit_factor"),
                "profit_factor_raw": run.get("profit_factor_raw"),
                "net_profit": run.get("net_profit"),
                "net_profit_raw": run.get("net_profit_raw"),
                "drawdown": run.get("drawdown"),
                "drawdown_raw": run.get("drawdown_raw"),
                "from_date": run.get("from_date"),
                "to_date": run.get("to_date"),
                "real_ticks_marker": run.get("real_ticks_marker"),
                "native_parser": parsed_stats,
            }
            record["trades"] = trades
            fp = result_fingerprints(record)
            record["identity_sha256"] = fp["identity_sha256"]
            record["report_metrics_sha256"] = fp["report_metrics_sha256"]
            record["trade_list_sha256"] = fp["trade_list_sha256"]
            record["trade_count"] = fp["trade_count"]
            record["reference_status"] = "AUTHENTICATED_COLD"
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            record["reference_errors"].append(str(exc))
        output.append(record)
    return output


def _path_is_within(path: Path, root: Path) -> bool:
    try:
        Path(path).resolve().relative_to(Path(root).resolve())
    except ValueError:
        return False
    return True


def _setfile_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in Path(path).read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().split("||", 1)[0]
    return values


def validate_validation_setfile(path: Path) -> dict[str, Any]:
    """Enforce the immutable build guardrails before a validation launch."""

    values = _setfile_values(path)
    try:
        risk_fixed = float(values.get("RISK_FIXED", ""))
        risk_percent = float(values.get("RISK_PERCENT", ""))
    except ValueError as exc:
        raise ActivationRefused("VALIDATION_SETFILE_RISK_VALUES_INVALID") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise ActivationRefused("VALIDATION_SETFILE_RISK_CONTRACT_INVALID")
    stale_raw = values.get("qm_news_stale_max_hours")
    if stale_raw is not None:
        try:
            stale_hours = float(stale_raw)
        except ValueError as exc:
            raise ActivationRefused("VALIDATION_SETFILE_NEWS_STALE_INVALID") from exc
        if stale_hours > 336:
            raise ActivationRefused("VALIDATION_SETFILE_NEWS_STALE_ABOVE_336")
    return {
        "path": str(Path(path).resolve()),
        "sha256": sha256_file(path),
        "risk_fixed": risk_fixed,
        "risk_percent": risk_percent,
        "qm_news_stale_max_hours": None if stale_raw is None else float(stale_raw),
    }


def audit_history_receipt(
    *, receipt_path: Path, lane_root: Path, expected_manifest_sha256: str
) -> dict[str, Any]:
    """Read-only, byte-exact audit of a frozen custom-history projection."""

    receipt = _load_json(receipt_path)
    if receipt.get("schema_version") != "qm.custom-history-copy-on-claim/v1":
        raise ActivationRefused("HISTORY_RECEIPT_SCHEMA_INVALID")
    if receipt.get("status") != "PASS_PRIVATIZED":
        raise ActivationRefused("HISTORY_RECEIPT_STATUS_INVALID")
    if str(receipt.get("manifest_sha256") or "").lower() != str(
        expected_manifest_sha256
    ).lower():
        raise ActivationRefused("HISTORY_RECEIPT_MANIFEST_MISMATCH")
    files = receipt.get("files")
    if not isinstance(files, list) or len(files) < 1:
        raise ActivationRefused("HISTORY_RECEIPT_FILES_MISSING")
    custom_root = Path(lane_root).resolve() / "Bases" / "Custom"
    rows: list[dict[str, Any]] = []
    problems: list[str] = []
    for item in files:
        relative = Path(str(item.get("relative_path") or ""))
        target = (custom_root / relative).resolve()
        if not _path_is_within(target, custom_root):
            problems.append(f"PATH_ESCAPE:{relative.as_posix()}")
            continue
        if not target.is_file():
            problems.append(f"MISSING:{relative.as_posix()}")
            continue
        actual_size = target.stat().st_size
        actual_sha256 = sha256_file(target)
        expected_size = int(item.get("size") or -1)
        expected_sha256 = str(item.get("sha256") or "").lower()
        exact = actual_size == expected_size and actual_sha256 == expected_sha256
        rows.append(
            {
                "relative_path": relative.as_posix(),
                "size": actual_size,
                "sha256": actual_sha256,
                "exact": exact,
            }
        )
        if not exact:
            problems.append(f"BYTE_MISMATCH:{relative.as_posix()}")
    if problems:
        raise ActivationRefused("HISTORY_PROJECTION_INVALID:" + ";".join(problems[:10]))
    inventory = [
        {"relative_path": row["relative_path"], "size": row["size"], "sha256": row["sha256"]}
        for row in rows
    ]
    return {
        "status": "PASS_EXACT",
        "receipt_path": str(Path(receipt_path).resolve()),
        "receipt_file_sha256": sha256_file(receipt_path),
        "manifest_sha256": str(expected_manifest_sha256).lower(),
        "file_count": len(rows),
        "inventory_sha256": sha256_bytes(canonical_json_bytes(inventory)),
        "files": rows,
    }


def _parse_json_envelope(output: str) -> dict[str, Any]:
    text = str(output or "").strip()
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        starts = [index for index, char in enumerate(text) if char == "{"]
        value = None
        for start in reversed(starts):
            try:
                candidate = json.loads(text[start:])
            except json.JSONDecodeError:
                continue
            value = candidate
            break
        if value is None:
            raise ActivationRefused("DEV2_CONTROLLER_JSON_MISSING")
    if not isinstance(value, dict):
        raise ActivationRefused("DEV2_CONTROLLER_JSON_NOT_OBJECT")
    return value


def _summary_path_from_controller_log(path: Path) -> Path:
    text = Path(path).read_text(encoding="utf-8-sig", errors="replace")
    matches = re.findall(r"(?m)^run_smoke\.summary=(.+?)\s*$", text)
    if len(matches) != 1:
        raise ActivationRefused(
            f"DEV2_RUN_SMOKE_SUMMARY_POINTER_COUNT_{len(matches)}"
        )
    summary_path = Path(matches[0].strip())
    if not summary_path.is_file():
        raise ActivationRefused("DEV2_RUN_SMOKE_SUMMARY_MISSING")
    return summary_path.resolve()


def _dev2_lane_state() -> dict[str, Any]:
    script = (
        "$laneRoot=[System.IO.Path]::GetFullPath('D:\\QM\\mt5\\DEV2');"
        "$rows=@(Get-CimInstance Win32_Process -Property ProcessId,ExecutablePath "
        "-ErrorAction Stop | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) "
        "-and [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($laneRoot+'\\',"
        "[System.StringComparison]::OrdinalIgnoreCase) });"
        "$user=Get-LocalUser -Name QMDev2 -ErrorAction Stop;"
        "[pscustomobject]@{process_count=$rows.Count;process_ids=@($rows|ForEach-Object{[int]$_.ProcessId});"
        "account_enabled=[bool]$user.Enabled;password_required=[bool]$user.PasswordRequired}"
        "|ConvertTo-Json -Compress"
    )
    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if completed.returncode != 0:
        raise ActivationRefused("DEV2_LANE_STATE_PROBE_FAILED")
    return _parse_json_envelope(completed.stdout)


class GovernedDev2RestartBackend:
    """Validation-only backend using the isolated DEV2 Scheduled-Task controller.

    It deliberately restarts the tester for each cell in one fixed, governed
    process space.  It is not production wiring and does not claim resident IPC.
    """

    def __init__(
        self,
        *,
        repo_root: Path,
        artifact_dir: Path,
        expected_history_manifest_sha256: str,
        history_receipt_path: Path | None = None,
        history_receipt_paths: Sequence[Path] | None = None,
        process_runner: Any | None = None,
        lane_probe: Any | None = None,
    ) -> None:
        self.repo_root = Path(repo_root).resolve()
        self.artifact_dir = Path(artifact_dir).resolve()
        supplied_receipts = list(history_receipt_paths or [])
        if history_receipt_path is not None:
            supplied_receipts.insert(0, history_receipt_path)
        self.history_receipt_paths = list(
            dict.fromkeys(Path(path).resolve() for path in supplied_receipts)
        )
        if not self.history_receipt_paths:
            raise ActivationRefused("DEV2_HISTORY_RECEIPTS_REQUIRED")
        self.history_receipt_path = self.history_receipt_paths[0]
        self.expected_history_manifest_sha256 = str(
            expected_history_manifest_sha256
        ).lower()
        self.process_runner = process_runner or subprocess.run
        self.lane_probe = lane_probe or _dev2_lane_state
        self.controller_path = self.repo_root / DEV2_CONTROLLER_RELATIVE
        self.contract_path = self.repo_root / DEV2_LANE_CONTRACT_RELATIVE
        self.helper_path = self.repo_root / DEV2_CREDENTIAL_HELPER_RELATIVE
        self.run_smoke_path = self.repo_root / "framework/scripts/run_smoke.ps1"
        self.results: list[dict[str, Any]] = []
        self.session_summary: dict[str, Any] = {}
        self.active_fixed_inputs: dict[str, Any] = {}

    def _fixed_inputs(self) -> dict[str, Any]:
        required = (
            self.controller_path,
            self.contract_path,
            self.helper_path,
            self.run_smoke_path,
            DEV2_CREDENTIAL,
        )
        for path in required:
            if not Path(path).is_file():
                raise ActivationRefused(f"DEV2_FIXED_INPUT_MISSING:{path}")
        contract = _load_json(self.contract_path)
        if contract.get("contract_id") != "QM_DEV2_ISOLATED_MT5_LANE_V3":
            raise ActivationRefused("DEV2_LANE_CONTRACT_INVALID")
        programs: dict[str, dict[str, Any]] = {}
        for name, expected in (contract.get("program_sha256") or {}).items():
            path = DEV2_ROOT / str(name)
            actual = sha256_file(path)
            if actual != str(expected).lower():
                raise ActivationRefused(f"DEV2_PROGRAM_HASH_MISMATCH:{name}")
            programs[str(name)] = {"path": str(path.resolve()), "sha256": actual}
        return {
            "controller": {
                "path": str(self.controller_path),
                "sha256": sha256_file(self.controller_path),
            },
            "lane_contract": {
                "path": str(self.contract_path),
                "sha256": sha256_file(self.contract_path),
                "contract_id": contract.get("contract_id"),
            },
            "credential": {
                "path": str(DEV2_CREDENTIAL),
                "sha256": sha256_file(DEV2_CREDENTIAL),
            },
            "credential_helper": {
                "path": str(self.helper_path),
                "sha256": sha256_file(self.helper_path),
            },
            "run_smoke": {
                "path": str(self.run_smoke_path),
                "sha256": sha256_file(self.run_smoke_path),
            },
            "programs": programs,
        }

    @staticmethod
    def _fixed_input_problems(fixed: Mapping[str, Any]) -> list[str]:
        problems: list[str] = []
        for label in (
            "controller",
            "lane_contract",
            "credential",
            "credential_helper",
            "run_smoke",
        ):
            identity = fixed.get(label) or {}
            path = Path(str(identity.get("path") or ""))
            if not path.is_file():
                problems.append(f"MISSING:{label}")
            elif sha256_file(path) != identity.get("sha256"):
                problems.append(f"HASH_CHANGED:{label}")
        for name, identity in (fixed.get("programs") or {}).items():
            path = Path(str(identity.get("path") or ""))
            if not path.is_file():
                problems.append(f"MISSING:program:{name}")
            elif sha256_file(path) != identity.get("sha256"):
                problems.append(f"HASH_CHANGED:program:{name}")
        return problems

    def _audit_histories(self) -> dict[str, Any]:
        audits = [
            audit_history_receipt(
                receipt_path=receipt_path,
                lane_root=DEV2_ROOT,
                expected_manifest_sha256=self.expected_history_manifest_sha256,
            )
            for receipt_path in self.history_receipt_paths
        ]
        inventory = sorted(
            [
                {
                    "receipt_path": audit["receipt_path"],
                    "receipt_file_sha256": audit["receipt_file_sha256"],
                    "inventory_sha256": audit["inventory_sha256"],
                    "file_count": audit["file_count"],
                }
                for audit in audits
            ],
            key=lambda item: item["receipt_path"],
        )
        return {
            "status": "PASS_EXACT_MULTI_RECEIPT",
            "manifest_sha256": self.expected_history_manifest_sha256,
            "receipt_count": len(audits),
            "inventory_count": len({row["inventory_sha256"] for row in inventory}),
            "inventory_sha256": sha256_bytes(canonical_json_bytes(inventory)),
            "receipts": audits,
        }

    def open_session(self, pair_contract: Mapping[str, Any]) -> dict[str, Any]:
        if pair_contract.get("history_manifest_sha256") != self.expected_history_manifest_sha256:
            raise ActivationRefused("DEV2_SESSION_HISTORY_MANIFEST_MISMATCH")
        if not _path_is_within(self.artifact_dir, self.repo_root):
            raise ActivationRefused("DEV2_SESSION_ARTIFACT_DIR_OUTSIDE_REPO")
        self.artifact_dir.mkdir(parents=True, exist_ok=False)
        lane_before = self.lane_probe()
        if int(lane_before.get("process_count") or 0) != 0:
            raise ActivationRefused("DEV2_SESSION_LANE_NOT_IDLE")
        if lane_before.get("account_enabled") is not False:
            raise ActivationRefused("DEV2_SESSION_ACCOUNT_NOT_DISABLED")
        if lane_before.get("password_required") is not True:
            raise ActivationRefused("DEV2_SESSION_PASSWORD_CONTRACT_INVALID")
        fixed = self._fixed_inputs()
        self.active_fixed_inputs = fixed
        history_before = self._audit_histories()
        return {
            "schema": "qm.warm-cell-governed-restart-session/v1",
            "session_id": str(uuid.uuid4()),
            "started_utc": utc_now(),
            "started_monotonic": time.monotonic(),
            "pair_contract": dict(pair_contract),
            "lane": "DEV2",
            "lane_before": lane_before,
            "fixed_inputs": fixed,
            "history_before": history_before,
            "terminal_restarts": 0,
        }

    def _authenticate_summary(
        self,
        *,
        summary_path: Path,
        cell: Mapping[str, Any],
        controller_result: Mapping[str, Any],
        wall_seconds: float,
    ) -> dict[str, Any]:
        summary = _load_json(summary_path)
        if summary.get("evidence_schema") != "run_smoke/v2":
            raise ActivationRefused("DEV2_RECEIPT_SCHEMA_INVALID")
        if summary.get("result") != "PASS":
            raise ActivationRefused(f"DEV2_RECEIPT_RESULT_{summary.get('result')}")
        ok_runs = [row for row in summary.get("runs", []) if row.get("status") == "OK"]
        if len(ok_runs) != 1:
            raise ActivationRefused("DEV2_RECEIPT_OK_RUN_COUNT_INVALID")
        run = ok_runs[0]
        report_path = Path(str(run.get("report_canonical_path") or ""))
        if not report_path.is_file():
            raise ActivationRefused("DEV2_NATIVE_REPORT_MISSING")
        report_sha256 = sha256_file(report_path)
        if report_sha256 != str(run.get("report_sha256") or "").lower():
            raise ActivationRefused("DEV2_NATIVE_REPORT_HASH_MISMATCH")
        logger_path = Path(
            str(
                summary.get("logger_sample_path")
                or (summary.get("logger_sample") or {}).get("path")
                or ""
            )
        )
        if not logger_path.is_file():
            raise ActivationRefused("DEV2_LOGGER_SAMPLE_MISSING")
        logger_sha256 = sha256_file(logger_path)
        if logger_sha256 != str(
            (summary.get("logger_sample") or {}).get("sha256") or ""
        ).lower():
            raise ActivationRefused("DEV2_LOGGER_SAMPLE_HASH_MISMATCH")
        execution = summary.get("execution_identity") or {}
        expert_binary = execution.get("expert_binary") or {}
        setfile = execution.get("setfile") or {}
        mq5 = execution.get("mq5_source") or {}
        run_smoke = execution.get("run_smoke") or {}
        expected = {
            "ea_id": int(str(cell.get("ea_id") or "").replace("QM5_", "")),
            "symbol": cell.get("symbol"),
            "period": cell.get("period"),
            "model": int(cell.get("model") or 0),
            "from_date": cell.get("from_date"),
            "to_date": cell.get("to_date"),
            "expert": cell.get("expert"),
        }
        actual = {field: summary.get(field) for field in expected}
        if actual != expected:
            raise ActivationRefused("DEV2_RECEIPT_EXECUTION_IDENTITY_MISMATCH")
        if (
            (expert_binary.get("deployed") or {}).get("sha256")
            != cell.get("ex5_sha256")
            or expert_binary.get("stable_during_run") is not True
            or (setfile.get("deployed") or {}).get("sha256")
            != cell.get("setfile_sha256")
            or setfile.get("source_matches_deployed") is not True
            or setfile.get("stable_during_run") is not True
            or mq5.get("sha256") != cell.get("mq5_sha256")
            or run_smoke.get("sha256")
            != self.active_fixed_inputs.get("run_smoke", {}).get("sha256")
            or controller_result.get("run_smoke_sha256")
            != self.active_fixed_inputs.get("run_smoke", {}).get("sha256")
        ):
            raise ActivationRefused("DEV2_RECEIPT_FILE_IDENTITY_MISMATCH")
        trades, parsed_stats = _canonical_closed_trades(report_path)
        receipt_schema = receipt_schema_fingerprint(summary)
        return {
            "cell_key": cell.get("cell_key"),
            "work_item_id": cell.get("work_item_id"),
            "arm": cell.get("arm"),
            "ea_id": cell.get("ea_id"),
            "symbol": cell.get("symbol"),
            "period": cell.get("period"),
            "model": cell.get("model"),
            "seed": cell.get("seed"),
            "from_date": cell.get("from_date"),
            "to_date": cell.get("to_date"),
            "ex5_sha256": cell.get("ex5_sha256"),
            "mq5_sha256": cell.get("mq5_sha256"),
            "setfile_sha256": cell.get("setfile_sha256"),
            "history_manifest_sha256": self.expected_history_manifest_sha256,
            "summary_path": str(summary_path),
            "summary_sha256": sha256_file(summary_path),
            "receipt_schema_sha256": receipt_schema["sha256"],
            "receipt_schema_field_paths": receipt_schema["field_paths"],
            "native_report_path": str(report_path.resolve()),
            "native_report_sha256": report_sha256,
            "report_sha256": report_sha256,
            "logger_sample_path": str(logger_path.resolve()),
            "logger_sample_sha256": logger_sha256,
            "entry_trading_days": len(
                {
                    str(trade.get("entry_time") or "")[:10]
                    for trade in trades
                    if trade.get("entry_time")
                }
            ),
            "report_metrics": {
                "total_trades": run.get("total_trades"),
                "total_trades_raw": run.get("total_trades_raw"),
                "profit_factor": run.get("profit_factor"),
                "profit_factor_raw": run.get("profit_factor_raw"),
                "net_profit": run.get("net_profit"),
                "net_profit_raw": run.get("net_profit_raw"),
                "drawdown": run.get("drawdown"),
                "drawdown_raw": run.get("drawdown_raw"),
                "from_date": run.get("from_date"),
                "to_date": run.get("to_date"),
                "real_ticks_marker": run.get("real_ticks_marker"),
                "native_parser": parsed_stats,
            },
            "trades": trades,
            "warm_elapsed_seconds": round(float(wall_seconds), 3),
            "controller_result": _json_ready(controller_result),
        }

    def run_cell(
        self, session: dict[str, Any], cell: Mapping[str, Any]
    ) -> Mapping[str, Any]:
        fixed_problems = self._fixed_input_problems(session["fixed_inputs"])
        if fixed_problems:
            raise ActivationRefused(
                "DEV2_SESSION_FIXED_INPUT_DRIFT:" + ";".join(fixed_problems)
            )
        setfile_path = Path(str(cell.get("setfile_path") or "")).resolve()
        if not setfile_path.is_file() or not _path_is_within(setfile_path, self.repo_root):
            raise ActivationRefused("DEV2_CELL_SETFILE_OUTSIDE_REPO_OR_MISSING")
        setfile_guard = validate_validation_setfile(setfile_path)
        if setfile_guard["sha256"] != cell.get("setfile_sha256"):
            raise ActivationRefused("DEV2_CELL_SETFILE_HASH_MISMATCH")
        run_index = len(self.results) + 1
        run_dir = self.artifact_dir / f"cell_{run_index:02d}"
        run_dir.mkdir(parents=True, exist_ok=False)
        fixed = session["fixed_inputs"]
        ea_numeric = int(str(cell.get("ea_id") or "").replace("QM5_", ""))
        timeout_seconds = int(cell.get("timeout_seconds") or 7200)
        command = [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(self.controller_path),
            "-EAId",
            str(ea_numeric),
            "-Symbol",
            str(cell.get("symbol")),
            "-Year",
            str(cell.get("from_date"))[:4],
            "-FromDate",
            str(cell.get("from_date")),
            "-ToDate",
            str(cell.get("to_date")),
            "-Expert",
            str(cell.get("expert")),
            "-Period",
            str(cell.get("period")),
            "-Runs",
            "1",
            "-MinTrades",
            str(int(cell.get("min_trades") or 5)),
            "-Model",
            str(int(cell.get("model") or 4)),
            "-TimeoutSeconds",
            str(timeout_seconds),
            "-SetFile",
            str(setfile_path),
            "-ExpectedCredentialSha256",
            fixed["credential"]["sha256"],
            "-ExpectedHelperSha256",
            fixed["credential_helper"]["sha256"],
        ]
        started = time.monotonic()
        completed = self.process_runner(
            command,
            cwd=self.repo_root,
            check=False,
            capture_output=True,
            text=True,
            timeout=max(3600, timeout_seconds * 3 + 3600),
        )
        wall_seconds = time.monotonic() - started
        _atomic_text(run_dir / "controller_stdout.log", completed.stdout or "")
        _atomic_text(run_dir / "controller_stderr.log", completed.stderr or "")
        if completed.returncode != 0:
            raise ActivationRefused(
                f"DEV2_CONTROLLER_FAILED_CELL_{run_index:02d}_EXIT_{completed.returncode}"
            )
        controller_result = _parse_json_envelope(completed.stdout)
        if controller_result.get("success") is not True:
            raise ActivationRefused("DEV2_CONTROLLER_RESULT_NOT_SUCCESS")
        if (
            controller_result.get("dev2_account_restored_disabled") is not True
            or controller_result.get("cleanup_lease_disarmed") is not True
        ):
            raise ActivationRefused("DEV2_CONTROLLER_CONTAINMENT_NOT_CLOSED")
        controller_log = Path(str(controller_result.get("log_path") or ""))
        if not controller_log.is_file():
            raise ActivationRefused("DEV2_CONTROLLER_LOG_MISSING")
        summary_path = _summary_path_from_controller_log(controller_log)
        result = self._authenticate_summary(
            summary_path=summary_path,
            cell=cell,
            controller_result=controller_result,
            wall_seconds=wall_seconds,
        )
        result["controller_stdout_path"] = str((run_dir / "controller_stdout.log").resolve())
        result["controller_stderr_path"] = str((run_dir / "controller_stderr.log").resolve())
        result["setfile_guard"] = setfile_guard
        self.results.append(dict(result))
        session["terminal_restarts"] += 1
        return result

    def close_session(self, session: dict[str, Any]) -> None:
        history_after = self._audit_histories()
        lane_after = self.lane_probe()
        problems: list[str] = []
        if int(lane_after.get("process_count") or 0) != 0:
            problems.append("DEV2_PROCESS_REMAINS")
        if lane_after.get("account_enabled") is not False:
            problems.append("DEV2_ACCOUNT_ENABLED_AFTER")
        if lane_after.get("password_required") is not True:
            problems.append("DEV2_PASSWORD_CONTRACT_AFTER")
        if (
            history_after["inventory_sha256"]
            != session["history_before"]["inventory_sha256"]
        ):
            problems.append("DEV2_HISTORY_CHANGED_DURING_SESSION")
        problems.extend(self._fixed_input_problems(session["fixed_inputs"]))
        self.session_summary = {
            "schema": session["schema"],
            "session_id": session["session_id"],
            "lane": session["lane"],
            "started_utc": session["started_utc"],
            "finished_utc": utc_now(),
            "elapsed_seconds": round(
                time.monotonic() - float(session["started_monotonic"]), 3
            ),
            "terminal_restarts": session["terminal_restarts"],
            "cells_authenticated": len(self.results),
            "lane_before": session["lane_before"],
            "lane_after": lane_after,
            "fixed_inputs": session["fixed_inputs"],
            "history_before": session["history_before"],
            "history_after": history_after,
            "problems": problems,
            "closed_exact": not problems,
        }
        _atomic_text(
            self.artifact_dir / "session_summary.json",
            json.dumps(self.session_summary, indent=2, sort_keys=True) + "\n",
        )
        if problems:
            raise ActivationRefused("DEV2_SESSION_CLOSE_FAILED:" + ";".join(problems))


def cold_path_identity(
    repo_root: Path,
    task_start_hashes: Mapping[str, str] = TASK_START_COLD_PATH_SHA256,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for relative in COLD_PATH_FILES:
        workspace = Path(repo_root) / relative
        workspace_hash = sha256_file(workspace)
        task_start_hash = task_start_hashes[relative.as_posix()]
        diff = subprocess.run(
            ["git", "diff", "--quiet", "--", relative.as_posix()],
            cwd=repo_root,
            check=False,
            capture_output=True,
        )
        if diff.returncode not in {0, 1}:
            raise RuntimeError(
                f"git diff failed for {relative}: {diff.stderr.decode(errors='replace')}"
            )
        rows.append(
            {
                "path": relative.as_posix(),
                "workspace_sha256": workspace_hash,
                "task_start_sha256": task_start_hash,
                "byte_identical_to_task_start": workspace_hash == task_start_hash,
                "tracked_content_equal_to_head": diff.returncode == 0,
            }
        )
    return rows


def build_deviation_packet(
    *,
    references: Sequence[Mapping[str, Any]],
    repo_root: Path,
    db_path: Path,
) -> dict[str, Any]:
    authenticated = [row for row in references if row.get("reference_status") == "AUTHENTICATED_COLD"]
    cold_identity = cold_path_identity(repo_root)
    run_smoke_text = (Path(repo_root) / "framework/scripts/run_smoke.ps1").read_text(
        encoding="utf-8-sig"
    )
    reasons = [
        "UNSUPPORTED_RESIDENT_TESTER_CONTROL",
        "WARM_PARITY_NOT_RUN",
    ]
    if len(authenticated) < MIN_PARITY_CELLS:
        reasons.append("AUTHENTICATED_COLD_REFERENCE_FLOOR_NOT_MET")
    return {
        "schema": "qm.warm-cell-runner-deviation/v1",
        "generated_at_utc": utc_now(),
        "verdict": "DEVIATION_STOP",
        "task_id": TASK_ID,
        "flag": {
            "name": FLAG_NAME,
            "default": "OFF",
            "production_wiring_present": False,
            "activation_in_scope": False,
        },
        "execution": {
            "launch_performed": False,
            "terminal_process_started": False,
            "warm_cells_run": 0,
            "database_open_mode": "URI mode=ro + PRAGMA query_only=ON",
            "database_write_performed": False,
            "db_path": str(Path(db_path).resolve()),
        },
        "reasons": reasons,
        "current_interface": {
            "run_smoke_sha256": sha256_file(Path(repo_root) / "framework/scripts/run_smoke.ps1"),
            "sets_shutdown_terminal_1": "ShutdownTerminal=1" in run_smoke_text,
            "starts_process_for_each_test": "Start-Process -FilePath $TerminalExe" in run_smoke_text,
            "allow_running_skips_fresh_logger": "reason=allow_running_terminal" in run_smoke_text,
            "supported_resident_next_cell_command_found": False,
        },
        "cold_path_files": cold_identity,
        "cold_path_byte_identical_to_task_start": all(
            row["byte_identical_to_task_start"] for row in cold_identity
        ),
        "reference_inventory": {
            "minimum_required": MIN_PARITY_CELLS,
            "rows_found": len(references),
            "authenticated_count": len(authenticated),
            "floor_met": len(authenticated) >= MIN_PARITY_CELLS,
            "warm_comparison_count": 0,
            "exact_comparison_count": 0,
        },
        "references": list(references),
        "activation_checklist": [
            "OWNER approves a supported resident tester-control backend; startup config replay is not treated as resident control.",
            "Use only a fresh disposable portable profile with isolated agent ports/cache, or a governed idle slot; never an active T1-T10 terminal.",
            "Inventory at least 20 authenticated cold cells with identical EA, symbol, history, model, window, setfile and seed bindings.",
            "Run all reference cells in one resident session and stop on the first identity, report-field or canonical trade-byte deviation.",
            "Repeat the complete warm batch to prove deterministic receipts and unchanged append-only evidence schema.",
            "Create an OWNER-approved qm.warm-cell-activation/v1 seal binding the parity packet hash and reviewed backend.",
            "Wire the flag only in a separate reviewed restart window; leave it unset by default and never enable AutoTrading or T_Live.",
            "Rollback by unsetting the flag and using the governed restart procedure after active tests finish; never start terminal64.exe manually.",
        ],
    }


def oldest_authenticated_references(
    references: Sequence[Mapping[str, Any]], *, limit: int = MIN_PARITY_CELLS
) -> list[dict[str, Any]]:
    """Select the oldest complete receipts, with work-item id as the tie-break."""

    authenticated = [
        dict(row)
        for row in references
        if row.get("reference_status") == "AUTHENTICATED_COLD"
    ]
    authenticated.sort(
        key=lambda row: (str(row.get("updated_at") or ""), str(row.get("work_item_id") or ""))
    )
    return authenticated[:limit]


def cold_timing_summary(references: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    samples = [
        float(row["cold_elapsed_seconds"])
        for row in references
        if row.get("cold_elapsed_seconds") is not None
    ]
    if not samples:
        return {
            "sample_count": 0,
            "total_seconds": None,
            "mean_seconds": None,
            "median_seconds": None,
            "minimum_seconds": None,
            "maximum_seconds": None,
        }
    return {
        "sample_count": len(samples),
        "total_seconds": round(sum(samples), 3),
        "mean_seconds": round(statistics.fmean(samples), 3),
        "median_seconds": round(statistics.median(samples), 3),
        "minimum_seconds": round(min(samples), 3),
        "maximum_seconds": round(max(samples), 3),
    }


def build_phase2_deviation_packet(
    *,
    references: Sequence[Mapping[str, Any]],
    repo_root: Path,
    db_path: Path,
) -> dict[str, Any]:
    """Build the commissioned USDJPY packet without inventing a warm backend."""

    authenticated = [
        row for row in references if row.get("reference_status") == "AUTHENTICATED_COLD"
    ]
    selected = oldest_authenticated_references(references)
    if len(selected) < MIN_PARITY_CELLS:
        raise ValueError(
            f"Phase-2 requires {MIN_PARITY_CELLS} authenticated cold references; "
            f"found {len(selected)}"
        )
    cohort_fields = (
        "ea_id",
        "symbol",
        "period",
        "model",
        "seed",
        "from_date",
        "to_date",
        "ex5_sha256",
        "mq5_sha256",
        "history_manifest_sha256",
    )
    first = selected[0]
    cohort_contract = {field: first.get(field) for field in cohort_fields}
    cohort_mismatches = {
        field: sorted({str(row.get(field)) for row in selected})
        for field in cohort_fields
        if any(row.get(field) != first.get(field) for row in selected[1:])
    }
    selection_rows = [
        {
            "selection_rank": index,
            "cell_key": row.get("cell_key"),
            "work_item_id": row.get("work_item_id"),
            "updated_at": row.get("updated_at"),
            "identity_sha256": row.get("identity_sha256"),
            "report_metrics_sha256": row.get("report_metrics_sha256"),
            "trade_list_sha256": row.get("trade_list_sha256"),
        }
        for index, row in enumerate(selected, start=1)
    ]
    for index, row in enumerate(selected, start=1):
        row["selection_rank"] = index
    cold_identity = cold_path_identity(
        repo_root, PHASE2_TASK_START_COLD_PATH_SHA256
    )
    run_smoke_path = Path(repo_root) / "framework/scripts/run_smoke.ps1"
    run_smoke_text = run_smoke_path.read_text(encoding="utf-8-sig")
    timing = cold_timing_summary(selected)
    timing_complete = timing["sample_count"] == MIN_PARITY_CELLS
    return {
        "schema": "qm.warm-cell-phase2-validation/v1",
        "generated_at_utc": utc_now(),
        "task_id": PHASE2_TASK_ID,
        "verdict": "DEVIATION_STOP_UNSUPPORTED_BACKEND",
        "reasons": [
            "UNSUPPORTED_RESIDENT_TESTER_CONTROL",
            "WARM_PARITY_NOT_RUN",
            "WARM_TIMING_NOT_MEASURABLE",
        ],
        "flag": {
            "name": FLAG_NAME,
            "default": "OFF",
            "observed_process_environment": os.environ.get(FLAG_NAME),
            "observed_enabled": feature_flag_enabled(),
            "production_wiring_present": False,
            "activation_in_scope": False,
        },
        "execution": {
            "launch_performed": False,
            "terminal_process_started": False,
            "warm_cells_run": 0,
            "production_claims_created": 0,
            "database_open_mode": "URI mode=ro + PRAGMA query_only=ON",
            "database_write_performed": False,
            "db_path": str(Path(db_path).resolve()),
        },
        "selection": {
            "contract": "oldest AUTHENTICATED_COLD by (updated_at, work_item_id)",
            "rows_found": len(references),
            "authenticated_count": len(authenticated),
            "selected_count": len(selected),
            "selection_sha256": sha256_bytes(canonical_json_bytes(selection_rows)),
            "rows": selection_rows,
        },
        "cohort": {
            "contract": cohort_contract,
            "common_identity_exact": not cohort_mismatches,
            "mismatches": cohort_mismatches,
            "cell_specific_setfiles": True,
        },
        "comparison": {
            "required": MIN_PARITY_CELLS,
            "attempted": 0,
            "exact": 0,
            "deviations": 0,
            "not_run": MIN_PARITY_CELLS,
            "all_exact": None,
            "status": "NOT_RUN_UNSUPPORTED_RESIDENT_CONTROL",
        },
        "timing": {
            "cold_measurement_basis": (
                "summary.timestamp_utc minus payload.started_at_iso for each governed cold cell"
            ),
            "cold": timing,
            "cold_timing_complete": timing_complete,
            "warm": {
                "sample_count": 0,
                "total_seconds": None,
                "mean_seconds": None,
                "median_seconds": None,
            },
            "speedup_ratio_cold_over_warm": None,
            "status": "NOT_MEASURABLE_WARM_RUN_NOT_STARTED",
        },
        "current_interface": {
            "run_smoke_sha256": sha256_file(run_smoke_path),
            "sets_shutdown_terminal_1": "ShutdownTerminal=1" in run_smoke_text,
            "starts_process_for_each_test": "Start-Process -FilePath $TerminalExe" in run_smoke_text,
            "allow_running_skips_fresh_logger": "reason=allow_running_terminal" in run_smoke_text,
            "supported_resident_next_cell_command_found": False,
            "native_optimizer_field_exact_receipt_supported": False,
        },
        "cold_path_files": cold_identity,
        "cold_path_byte_identical_to_phase2_start": all(
            row["byte_identical_to_task_start"] for row in cold_identity
        ),
        "selected_references": selected,
        "activation_checklist": [
            {
                "gate": "supported resident tester-control backend reviewed",
                "status": "BLOCKED",
                "evidence": "Only an injected Protocol/fake backend exists; no governed next-cell implementation exists.",
            },
            {
                "gate": "20 oldest complete homogeneous cold references",
                "status": "PASS" if not cohort_mismatches else "BLOCKED",
                "evidence": f"{len(selected)} selected; selection SHA-256 is bound in this packet.",
            },
            {
                "gate": "20/20 field- and trade-byte exact warm parity",
                "status": "BLOCKED",
                "evidence": "0 warm cells were launched; equality is null, not assumed.",
            },
            {
                "gate": "measured warm-versus-cold speedup",
                "status": "BLOCKED",
                "evidence": "Cold timing is measured for 20 cells; warm timing is null.",
            },
            {
                "gate": "repeat complete warm batch deterministically",
                "status": "BLOCKED",
                "evidence": "Requires the same reviewed backend after first-batch exact parity.",
            },
            {
                "gate": "OWNER activation seal binding backend and parity packet",
                "status": "BLOCKED",
                "evidence": "Not eligible until parity and speedup gates pass.",
            },
            {
                "gate": "production remains Default-OFF",
                "status": "PASS" if not feature_flag_enabled() else "BLOCKED",
                "evidence": "No production wiring, claims, queue writes, terminal launch, T_Live, or AutoTrading change.",
            },
        ],
    }


def render_phase2_report(packet: Mapping[str, Any]) -> str:
    selection = packet["selection"]
    comparison = packet["comparison"]
    timing = packet["timing"]
    cohort = packet["cohort"]
    lines = [
        "# V4a Phase 2 — USDJPY warm-runner validation deviation stop",
        "",
        "**Verdict:** `DEVIATION_STOP_UNSUPPORTED_BACKEND`",
        "**Execution:** `NO_MT5_LAUNCH`",
        f"**Feature flag:** `{FLAG_NAME}` remained globally unset/Default-OFF.",
        "",
        "The commissioned reference floor now passes, but the execution precondition does not. "
        "The repository still has only an injected resident-session interface used by tests; it has no reviewed backend that can submit a second tester cell to one already-running MT5 session. The governed cold launcher starts one terminal process per cell. Therefore no warm result, parity value, timing value, or speedup claim was fabricated.",
        "",
        "## Acceptance result",
        "",
        "| Criterion | Result |",
        "|---|---|",
        f"| Deterministic oldest complete cohort | PASS — {selection['selected_count']} of {selection['authenticated_count']} authenticated receipts selected; selection `{selection['selection_sha256']}` |",
        f"| 20/20 comparison table with hashes | DEVIATION — {comparison['attempted']}/20 warm comparisons; all 20 cold hashes are bound below and warm fields are explicitly NOT RUN |",
        f"| Warm versus cold timing | DEVIATION — 20-cell cold total {timing['cold']['total_seconds']} s; warm timing and speedup are null |",
        "| Activation checklist | NOT ELIGIBLE — backend, exact-parity, speedup, repeatability, and OWNER-seal gates remain blocked |",
        "| Cold path / DL-089 | PASS — four governed cold-path files match their Phase-2 start bytes; no production claim or DL-089 mutation |",
        "",
        "## Deterministic cohort",
        "",
        f"The read-only snapshot found **{selection['rows_found']}** measured USDJPY rows, all **{selection['authenticated_count']}** authenticated. Selection is ascending `(updated_at, work_item_id)` after receipt authentication. Common identity exact: **{str(cohort['common_identity_exact']).upper()}**. Setfiles are intentionally cell-specific because each arm encodes a different predicate.",
        "",
        "| Field | Common value |",
        "|---|---|",
    ]
    for field, value in cohort["contract"].items():
        lines.append(f"| `{field}` | `{value}` |")
    lines.extend(
        [
            "",
            "## Timing",
            "",
            "Cold elapsed time is measured from each governed receipt's `payload.started_at_iso` to `summary.timestamp_utc`. It includes the existing per-cell startup path and is the relevant cold baseline. No warm elapsed clock exists because the unsupported backend gate stopped execution before launch.",
            "",
            "| Path | Cells | Total s | Mean s | Median s | Min s | Max s | Speedup |",
            "|---|---:|---:|---:|---:|---:|---:|---|",
            f"| Cold governed receipts | {timing['cold']['sample_count']} | {timing['cold']['total_seconds']} | {timing['cold']['mean_seconds']} | {timing['cold']['median_seconds']} | {timing['cold']['minimum_seconds']} | {timing['cold']['maximum_seconds']} | baseline |",
            "| Warm resident session | 0 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT MEASURABLE |",
            "",
            "## 20-cell comparison table",
            "",
            "| # | Arm | Work item | Cold s | Metrics SHA-256 | Trade-list SHA-256 | Warm | Exact |",
            "|---:|---|---|---:|---|---|---|---|",
        ]
    )
    for row in packet["selected_references"]:
        lines.append(
            f"| {row['selection_rank']} | {row.get('arm')} | `{row.get('work_item_id')}` | "
            f"{row.get('cold_elapsed_seconds')} | `{row.get('report_metrics_sha256')}` | "
            f"`{row.get('trade_list_sha256')}` | NOT RUN | NULL |"
        )
    lines.extend(
        [
            "",
            "## Why the warm launch is not valid yet",
            "",
            "`warm_cell_runner.py` defines sequencing, authorization, exact comparison, and immediate deviation stop around an injected backend. It deliberately contains no MetaTrader launcher. The governed `run_smoke.ps1` writes `ShutdownTerminal=1` and starts `/portable /config:<ini>` for every test. A second startup invocation is not resident next-cell control, and `-AllowRunningTerminal` also bypasses the fresh logger-authentication path.",
            "",
            "The only supported MT5 multi-pass mechanism found is native optimization. The V4b feasibility packet already proved its standard pass report lacks the per-pass closed-trade list, entry-day evidence, logger sample, and native report bytes required for field-for-field cold receipt parity. It cannot be substituted silently.",
            "",
            "## Activation checklist",
            "",
            "| Gate | Status | Evidence / next condition |",
            "|---|---|---|",
        ]
    )
    for item in packet["activation_checklist"]:
        lines.append(f"| {item['gate']} | **{item['status']}** | {item['evidence']} |")
    lines.extend(
        [
            "",
            "## Cold-path identity",
            "",
            "| File | Workspace SHA-256 | Phase-2 start SHA-256 | Exact |",
            "|---|---|---|---|",
        ]
    )
    for row in packet["cold_path_files"]:
        lines.append(
            f"| `{row['path']}` | `{row['workspace_sha256']}` | `{row['task_start_sha256']}` | "
            f"{str(row['byte_identical_to_task_start']).upper()} |"
        )
    lines.extend(
        [
            "",
            "## Safety record",
            "",
            "- The farm database was opened with SQLite URI `mode=ro` and `PRAGMA query_only=ON`.",
            "- No terminal, tester, worker, production claim, queue row, verdict, policy file, DL-089 receipt, T_Live, or AutoTrading state was changed.",
            "- This is a deviation packet, not pipeline evidence and not an activation authorization.",
            "",
        ]
    )
    return "\n".join(lines)


def render_report(packet: Mapping[str, Any]) -> str:
    inv = packet["reference_inventory"]
    lines = [
        "# V4a warm-terminal cell runner — fail-closed deviation",
        "",
        "**Verdict:** `DEVIATION_STOP`",
        "**Execution:** `NO_MT5_LAUNCH`",
        f"**Feature flag:** `{FLAG_NAME}` is Default-OFF and is not wired into the production worker.",
        "",
        "The reusable single-session orchestration and exact-parity validator were built and unit-tested behind the flag. The commissioned warm replay was not started: the governed MT5 command surface only consumes tester configuration at process startup, and the existing cold runner starts a new terminal process for every test. No supported command was found that submits the next cell to an already-running tester. Treating a second `/config` launch or `-AllowRunningTerminal` as that command would be unsafe and would also skip fresh logger authentication.",
        "",
        "## Acceptance result",
        "",
        "| Criterion | Result |",
        "|---|---|",
        "| Default-OFF; cold path byte-identical | PASS — flag absence selects `COLD_PATH_UNCHANGED`; all four governed cold-path files retain their exact task-start bytes and have no tracked diff |",
        f"| ≥20 exact cold/warm comparisons or deviation | DEVIATION — {inv['authenticated_count']} authenticated cold references available; 0 warm cells launched; no equality claim made |",
        "| Runner and flag tests | PASS — fake resident backend proves one-session sequencing, exact comparison, immediate mismatch stop, activation refusal, and Default-OFF no-op |",
        "| Evidence and activation checklist | PASS — JSON reference packet, CSV deviation table, this report, and explicit checklist |",
        "",
        "## Why execution stopped",
        "",
        "The platform-start interface is a startup configuration contract. The current `run_smoke.ps1` writes `ShutdownTerminal=1` and its `Start-TesterRun` function calls `Start-Process` with `/portable /config:<ini>` for each test. `-AllowRunningTerminal` only bypasses exclusivity/logger checks; it does not provide a resident next-cell IPC.",
        "",
        "The official [platform-start documentation](https://www.metatrader5.com/en/terminal/help/start_advanced/start) describes `/config` as startup configuration, states that two copies cannot run from one directory, and documents `ShutdownTerminal` after testing. No supported resident sequential-test command is documented there. A native optimizer is the supported multi-pass path, but the separate V4b preflight found that its standard pass evidence cannot reproduce the current receipt contract field-for-field.",
        "",
        f"At snapshot time the read-only farm query found **{inv['authenticated_count']}** authenticated GBPUSD 2019 cold references (minimum **{inv['minimum_required']}**). Thus the reference floor is independently short even before the missing warm backend is considered.",
        "",
        "## Cold reference inventory",
        "",
        "| Arm | Work item | Trades | Metrics SHA-256 | Trade-list SHA-256 | Warm result |",
        "|---|---|---:|---|---|---|",
    ]
    for row in packet["references"]:
        lines.append(
            f"| {row.get('arm')} | `{row.get('work_item_id')}` | {row.get('trade_count')} | "
            f"`{row.get('report_metrics_sha256') or 'INVALID'}` | "
            f"`{row.get('trade_list_sha256') or 'INVALID'}` | NOT RUN |"
        )
    lines.extend(
        [
            "",
            "The JSON packet retains the canonical cold trade rows and report fields, so a later authorized backend can compare the exact bytes rather than reconstructed aggregates.",
            "",
            "## Cold-path identity",
            "",
            "| File | Workspace SHA-256 | Task-start SHA-256 | Exact |",
            "|---|---|---|---|",
        ]
    )
    for row in packet["cold_path_files"]:
        lines.append(
            f"| `{row['path']}` | `{row['workspace_sha256']}` | "
            f"`{row['task_start_sha256']}` | {str(row['byte_identical_to_task_start']).upper()} |"
        )
    lines.extend(["", "## Activation checklist", ""])
    for index, item in enumerate(packet["activation_checklist"], start=1):
        lines.append(f"{index}. {item}")
    lines.extend(
        [
            "",
            "## Safety record",
            "",
            "- Farm database opened with SQLite URI `mode=ro` and `PRAGMA query_only=ON`; no queue, verdict, gate, DL-089, worker, or receipt was changed.",
            "- No terminal process was launched; T1-T10, T_Live and AutoTrading were untouched.",
            "- The module contains no MetaTrader launcher and production wiring is absent. An exact disposable-validation authorization is required for parity work; later production use additionally requires the OWNER activation seal.",
            "",
        ]
    )
    return "\n".join(lines)


def _atomic_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(value, encoding="utf-8", newline="\n")
    os.replace(temp, path)


def write_outputs(
    *, packet: Mapping[str, Any], output_dir: Path, output_stem: str
) -> dict[str, Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / f"{output_stem}.md"
    packet_path = output_dir / f"{output_stem}_packet.json"
    comparison_path = output_dir / f"{output_stem}_comparison.csv"
    _atomic_text(packet_path, json.dumps(packet, indent=2, sort_keys=True) + "\n")
    _atomic_text(report_path, render_report(packet))
    fields = [
        "cell_key",
        "work_item_id",
        "arm",
        "direction",
        "predicate_id",
        "reference_status",
        "identity_sha256",
        "report_metrics_sha256",
        "trade_list_sha256",
        "trade_count",
        "warm_status",
        "all_exact",
    ]
    temp = comparison_path.with_name(f".{comparison_path.name}.{os.getpid()}.tmp")
    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for reference in packet["references"]:
            writer.writerow(
                {
                    **{field: reference.get(field) for field in fields},
                    "warm_status": "NOT_RUN_UNSUPPORTED_RESIDENT_CONTROL",
                    "all_exact": None,
                }
            )
    os.replace(temp, comparison_path)
    return {
        "report": report_path,
        "packet": packet_path,
        "comparison": comparison_path,
    }


def write_phase2_outputs(
    *, packet: Mapping[str, Any], output_dir: Path, output_stem: str
) -> dict[str, Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / f"{output_stem}.md"
    packet_path = output_dir / f"{output_stem}_packet.json"
    comparison_path = output_dir / f"{output_stem}_comparison.csv"
    _atomic_text(packet_path, json.dumps(packet, indent=2, sort_keys=True) + "\n")
    _atomic_text(report_path, render_phase2_report(packet))
    fields = [
        "selection_rank",
        "cell_key",
        "work_item_id",
        "arm",
        "updated_at",
        "cold_elapsed_seconds",
        "identity_sha256",
        "report_metrics_sha256",
        "trade_list_sha256",
        "trade_count",
        "warm_status",
        "warm_elapsed_seconds",
        "warm_identity_sha256",
        "warm_report_metrics_sha256",
        "warm_trade_list_sha256",
        "all_exact",
    ]
    temp = comparison_path.with_name(f".{comparison_path.name}.{os.getpid()}.tmp")
    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for reference in packet["selected_references"]:
            writer.writerow(
                {
                    **{field: reference.get(field) for field in fields},
                    "warm_status": "NOT_RUN_UNSUPPORTED_RESIDENT_CONTROL",
                    "warm_elapsed_seconds": None,
                    "warm_identity_sha256": None,
                    "warm_report_metrics_sha256": None,
                    "warm_trade_list_sha256": None,
                    "all_exact": None,
                }
            )
    os.replace(temp, comparison_path)
    return {
        "report": report_path,
        "packet": packet_path,
        "comparison": comparison_path,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--year", type=int, default=2019)
    parser.add_argument(
        "--phase2-usdjpy",
        action="store_true",
        help="emit the fail-closed 20-cell QM5_41097/USDJPY Phase-2 packet",
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--output-stem",
        default="c7536f46_v4a_warm_terminal_runner_2026-08-27",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    with _read_only_connection(args.db) as con:
        con.execute("BEGIN")
        if args.phase2_usdjpy:
            references = cold_references(
                con,
                ea_id="QM5_41097",
                symbol="USDJPY.DWX",
                year=args.year,
            )
        else:
            references = cold_references(con, year=args.year)
        con.rollback()
    if args.phase2_usdjpy:
        packet = build_phase2_deviation_packet(
            references=references,
            repo_root=args.repo_root.resolve(),
            db_path=args.db.resolve(),
        )
        outputs = write_phase2_outputs(
            packet=packet,
            output_dir=args.output_dir,
            output_stem=args.output_stem,
        )
        cold_references_count = packet["selection"]["authenticated_count"]
    else:
        packet = build_deviation_packet(
            references=references,
            repo_root=args.repo_root.resolve(),
            db_path=args.db.resolve(),
        )
        outputs = write_outputs(
            packet=packet,
            output_dir=args.output_dir,
            output_stem=args.output_stem,
        )
        cold_references_count = packet["reference_inventory"]["authenticated_count"]
    print(
        json.dumps(
            {
                "status": packet["verdict"],
                "flag_default": packet["flag"]["default"],
                "cold_path_unchanged": (
                    packet.get("cold_path_byte_identical_to_task_start")
                    if not args.phase2_usdjpy
                    else packet.get("cold_path_byte_identical_to_phase2_start")
                ),
                "cold_references": cold_references_count,
                "warm_cells": packet["execution"]["warm_cells_run"],
                "launch_performed": packet["execution"]["launch_performed"],
                "outputs": {key: str(path.resolve()) for key, path in outputs.items()},
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
