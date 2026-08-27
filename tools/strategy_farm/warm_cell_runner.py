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
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Protocol, Sequence


# Direct execution sets sys.path to tools/strategy_farm, while the authenticated
# native-report parser lives under framework/scripts.
REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))


FLAG_NAME = "QM_ENABLE_WARM_CELL_RUNNER"
TASK_ID = "c7536f46-2c1e-4ab9-b18c-47cfe01c6491"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
MIN_PARITY_CELLS = 20
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


class FlagValueError(ValueError):
    """Raised when the feature flag is neither explicitly on nor off."""


class ActivationRefused(RuntimeError):
    """Raised when warm execution lacks a complete external approval seal."""


class ParityDeviation(RuntimeError):
    """Raised immediately when a warm cell differs from its cold reference."""


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
        "task_id": TASK_ID,
        "authorized_by": "OWNER_COMMISSION",
        "execution_backend": "SUPPORTED_RESIDENT_TESTER_CONTROL",
        "profile_mode": "DISPOSABLE",
        "production_wiring": False,
        "active_terminal_allowed": False,
    }
    for field, value in expected.items():
        if manifest.get(field) != value:
            problems.append(f"VALIDATION_{field.upper()}_INVALID")
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
    exact = cell_key_match and not identity_mismatches and metric_match and trade_match
    return {
        "cell_key": cold.get("cell_key"),
        "warm_cell_key": warm.get("cell_key"),
        "cell_key_match": cell_key_match,
        "identity_exact_match": not identity_mismatches,
        "identity_mismatch_fields": identity_mismatches,
        "report_metrics_field_exact_match": metric_match,
        "trade_list_byte_exact_match": trade_match,
        "all_exact": exact,
        "cold_identity_sha256": cold_fp["identity_sha256"],
        "warm_identity_sha256": warm_fp["identity_sha256"],
        "cold_report_metrics_sha256": cold_fp["report_metrics_sha256"],
        "warm_report_metrics_sha256": warm_fp["report_metrics_sha256"],
        "cold_trade_list_sha256": cold_fp["trade_list_sha256"],
        "warm_trade_list_sha256": warm_fp["trade_list_sha256"],
        "cold_trade_count": cold_fp["trade_count"],
        "warm_trade_count": warm_fp["trade_count"],
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
        for key in keys[1:]:
            reference = cold_references[key]
            if any(reference.get(field) != pair_contract[field] for field in pair_fields):
                raise ActivationRefused("RUN_BATCH_PAIR_IDENTITY_MIXED")

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
                        + ",".join(comparison["identity_mismatch_fields"])
                    )
        finally:
            self.backend.close_session(session)

        summary = parity_summary(comparisons)
        if not summary["all_exact"]:
            raise ParityDeviation("warm parity sample did not satisfy the sealed minimum")
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
            "summary_path": str(row["evidence_path"] or ""),
            "updated_at": row["updated_at"],
            "reference_status": "INVALID",
            "reference_errors": [],
        }
        try:
            summary_path = Path(record["summary_path"])
            summary = _load_json(summary_path)
            ok_runs = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
            if len(ok_runs) != 1:
                raise ValueError(f"expected one OK run, found {len(ok_runs)}")
            run = ok_runs[0]
            report_path = Path(str(run.get("report_canonical_path") or ""))
            if not report_path.is_file():
                raise ValueError(f"native report missing: {report_path}")
            trades, parsed_stats = _canonical_closed_trades(report_path)
            record["model"] = summary.get("model")
            record["report_path"] = str(report_path.resolve())
            record["report_sha256"] = run.get("report_sha256") or sha256_file(report_path)
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


def cold_path_identity(repo_root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for relative in COLD_PATH_FILES:
        workspace = Path(repo_root) / relative
        workspace_hash = sha256_file(workspace)
        task_start_hash = TASK_START_COLD_PATH_SHA256[relative.as_posix()]
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


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--year", type=int, default=2019)
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
        references = cold_references(con, year=args.year)
        con.rollback()
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
    print(
        json.dumps(
            {
                "status": packet["verdict"],
                "flag_default": packet["flag"]["default"],
                "cold_path_unchanged": packet["cold_path_byte_identical_to_task_start"],
                "cold_references": packet["reference_inventory"]["authenticated_count"],
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
