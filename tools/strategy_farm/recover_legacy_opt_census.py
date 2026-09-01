"""Seal the exact QM5_41097 legacy DL-089 census without rewriting evidence.

This is a deliberately narrow recovery ceremony for OWNER task
64752aff-f026-45c0-961a-5cc618a01ceb.  The original 1,085-cell ledger predates
the governed Q12 binding enforced by terminal_worker.  The ceremony:

* preserves the original ledger bytes and all completed work-item rows;
* appends one deterministic Q12 wrapper and a sealed ledger copy;
* repairs only pending, unclaimed, null-verdict annual cells by payload CAS;
* installs an active Q12 review hold, so no selector advance can occur before
  independent review while governed terminal workers may resume annual cells;
* diagnoses, but does not rewrite, the unrelated pending Q04 row.

It never launches MT5, routes agent work, or changes a gate/selection rule.
Dry-run is the default.  ``--apply`` is required for any write.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    import dl089_scheduling
    import farmctl
    import opt_census as census
    import opt_census_select as selector
    import optimization_fork_driver as fork_driver
    import terminal_worker
    from factory_mutation_lock import FactoryMutationLock
    from phase_ids import ACTIVE_GATE_MANIFEST
except ModuleNotFoundError:
    from tools.strategy_farm import dl089_scheduling
    from tools.strategy_farm import farmctl
    from tools.strategy_farm import opt_census as census
    from tools.strategy_farm import opt_census_select as selector
    from tools.strategy_farm import optimization_fork_driver as fork_driver
    from tools.strategy_farm import terminal_worker
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
    from tools.strategy_farm.phase_ids import ACTIVE_GATE_MANIFEST


SCHEMA = "qm.dl089-legacy-census-recovery/v1"
ADOPTION_SCHEMA = "qm.dl089-legacy-done-adoption/v1"
REGISTRATION_SCHEMA = "qm.dl089-legacy-matrix-registration/v1"
RECEIPT_SCHEMA = "qm.dl089-legacy-census-recovery-receipt/v1"
SIBLING_SCHEMA = "qm.dl089-legacy-measurement-sibling/v1"
OWNER_TASK_ID = "64752aff-f026-45c0-961a-5cc618a01ceb"
SUBJECT_EA_ID = "QM5_13213"
MEASUREMENT_EA_ID = "QM5_41097"
SYMBOL = "USDJPY.DWX"
TIMEFRAME = "H1"
PROGRAM_ID = "DL089_QM5_41097_USDJPY_DWX_2019_2025"
PARENT_WORK_ITEM_ID = "e5a8f194-2369-4d59-b6b0-f6f5a6872478"
Q04_WORK_ITEM_ID = "dba6365b-14cf-49d2-a0e1-af534baf4b17"
LEGACY_Q02_WORK_ITEM_ID = "9851938c-5ff4-4b30-b69a-fc4a7668134a"
LEGACY_LEDGER_SHA256 = (
    "eb4a981fc42f60f53947024fd591dea0ef6813ca50cc95e0eb17a03ae01c7943"
)
SOURCE_SHA256 = (
    "8e5cfdbf6f513bdbfd5fdcd25357907cad124497123b8a1abe133c9f2d1d6329"
)
EX5_SHA256 = (
    "e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e"
)
EXPECTED_DONE = 486
EXPECTED_PENDING = 599
EXPECTED_CELLS = 1085
RUNNER_REVISION = "dl089-matrix-runner-v2"
REVIEW_HOLD_CODE = "Q12_LEGACY_CENSUS_RECOVERY_REVIEW_PENDING"
RECOVERY_NAMESPACE = uuid.UUID("48ff9264-b932-4cca-98b8-85777a2973bf")

DEFAULT_LEGACY_LEDGER = Path(
    r"D:\QM\strategy_farm\opt_census\QM5_41097_USDJPY\ledger.json"
)
DEFAULT_ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\opt_census")
EA_DIR_NAME = "QM5_41097_balke-gmt3-range-breakout-opt"


class RecoveryError(RuntimeError):
    """The exact legacy recovery precondition is not satisfied."""


@dataclass(frozen=True)
class RecoveryPlan:
    q12_work_item_id: str
    q12_payload: dict[str, Any]
    q12_payload_json: str
    q12_row: dict[str, Any]
    declaration: dict[str, Any]
    legacy_ledger: dict[str, Any]
    sealed_ledger: dict[str, Any]
    pending_rows: tuple[dict[str, Any], ...]
    done_rows: tuple[dict[str, Any], ...]
    done_adoption: dict[str, Any]
    registration: dict[str, Any]
    q04_diagnostic: dict[str, Any]
    paths: dict[str, Path]
    bindings: dict[str, Any]
    base_setfile_bytes: bytes


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _pretty_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise RecoveryError(f"bound file missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _content_binding(path: Path, data: bytes) -> dict[str, Any]:
    return {
        "path": str(path.resolve()),
        "sha256": _sha256_bytes(data),
        "size_bytes": len(data),
    }


def _atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _copy_exact(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with source.open("rb") as src, temporary.open("xb") as dst:
            shutil.copyfileobj(src, dst, length=1024 * 1024)
            dst.flush()
            os.fsync(dst.fileno())
        os.replace(temporary, target)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _decode_payload(row: Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise RecoveryError(f"invalid payload JSON for {row['id']}") from exc
    if not isinstance(value, dict):
        raise RecoveryError(f"payload is not an object for {row['id']}")
    return value


def _base_setfile_from_baseline(ledger: Mapping[str, Any]) -> bytes:
    baseline = next(
        (
            cell
            for cell in ledger.get("cells", [])
            if int(cell.get("year", 0)) == 2019 and cell.get("arm") == "baseline"
        ),
        None,
    )
    if baseline is None:
        raise RecoveryError("legacy ledger has no 2019 baseline cell")
    path = Path(str(baseline["setfile_path"]))
    if not path.is_file():
        raise RecoveryError(f"legacy baseline setfile missing: {path}")
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    expected_prefixes = (
        "; opt_census_schema:",
        "; opt_census_cell_key:",
        "; opt_census_from_date:",
        "; opt_census_to_date:",
    )
    if len(lines) < 5 or any(
        not lines[index].startswith(prefix)
        for index, prefix in enumerate(expected_prefixes)
    ):
        raise RecoveryError("legacy baseline setfile has an unexpected census stamp")
    text = "\n".join(lines[len(expected_prefixes) :]).rstrip() + "\n"
    values: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key.strip() in values:
            raise RecoveryError(f"duplicate base-setfile input: {key.strip()}")
        values[key.strip()] = value.strip()
    required = {"qm_ea_id", "RISK_FIXED", "RISK_PERCENT", *census.SET_KEYS}
    missing = sorted(required - values.keys())
    if missing:
        raise RecoveryError("recovered base setfile missing inputs: " + ", ".join(missing))
    if values["qm_ea_id"] != MEASUREMENT_EA_ID.removeprefix("QM5_"):
        raise RecoveryError("recovered base setfile EA identity mismatch")
    if float(values["RISK_FIXED"]) <= 0 or float(values["RISK_PERCENT"]) != 0:
        raise RecoveryError("recovered base setfile violates fixed-risk contract")
    stale = values.get("qm_news_stale_max_hours")
    if stale is not None and float(stale) > 336:
        raise RecoveryError("recovered base setfile news stale ceiling exceeds 336")
    if "; environment:" not in text.lower() or "backtest" not in text.lower():
        raise RecoveryError("recovered base setfile lacks backtest environment header")
    if any(values[key] != "0" for key in census.SET_KEYS):
        raise RecoveryError("recovered base setfile is not pattern-neutral")
    return text.encode("utf-8")


def _done_row_digest(rows: Sequence[Mapping[str, Any]]) -> str:
    fields = (
        "id",
        "status",
        "verdict",
        "claimed_by",
        "parent_task_id",
        "evidence_path",
        "payload_json",
        "gate_contract_version",
        "ex5_sha256",
        "setfile_sha256",
        "mq5_sha256",
        "data_window_start",
        "data_window_end",
        "updated_at",
    )
    canonical = [
        {key: row[key] for key in fields}
        for row in sorted(rows, key=lambda value: str(value["id"]))
    ]
    return _sha256_bytes(_canonical_bytes(canonical))


def _validate_done_evidence(
    row: Mapping[str, Any],
    cell: Mapping[str, Any],
    *,
    setfile_sha256: str,
) -> dict[str, Any]:
    work_item_id = str(row["id"])
    expected_columns = {
        "status": "done",
        "verdict": "MEASURED",
        "claimed_by": None,
        "mq5_sha256": SOURCE_SHA256,
        "ex5_sha256": EX5_SHA256,
        "setfile_sha256": setfile_sha256,
        "data_window_start": cell["from_date"],
        "data_window_end": cell["to_date"],
    }
    for key, expected in expected_columns.items():
        if row[key] != expected:
            raise RecoveryError(
                f"done row {work_item_id} {key} mismatch: {row[key]!r} != {expected!r}"
            )
    evidence_path = Path(str(row["evidence_path"] or ""))
    if not evidence_path.is_file():
        raise RecoveryError(f"done row {work_item_id} evidence missing")
    try:
        summary = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RecoveryError(f"done row {work_item_id} evidence is invalid JSON") from exc
    execution = summary.get("execution_identity") or {}
    expert = execution.get("expert_binary") or {}
    source = execution.get("mq5_source") or {}
    setfile = execution.get("setfile") or {}
    ok_runs = [
        run
        for run in summary.get("runs", [])
        if run.get("status") == "OK"
        and run.get("real_ticks_marker") is True
        and str(run.get("report_sha256") or "")
    ]
    checks = {
        "summary_result": summary.get("result") == "PASS",
        "stable_execution": execution.get("stable_during_run") is True,
        "binary_binding": (
            expert.get("required_sha256") == EX5_SHA256
            and expert.get("stable_during_run") is True
        ),
        "source_binding": source.get("sha256") == SOURCE_SHA256,
        "setfile_binding": (
            (setfile.get("source") or {}).get("sha256") == setfile_sha256
            and setfile.get("source_matches_deployed") is True
            and setfile.get("stable_during_run") is True
        ),
        "window_binding": (
            summary.get("from_date") == cell["from_date"]
            and summary.get("to_date") == cell["to_date"]
        ),
        "scope_binding": (
            str(summary.get("ea_id")) == MEASUREMENT_EA_ID.removeprefix("QM5_")
            and summary.get("symbol") == SYMBOL
            and summary.get("period") == TIMEFRAME
        ),
        "real_tick_run": bool(ok_runs),
        "news_contract": (
            (summary.get("news_calendar") or {}).get("status") == "OK"
            and int((summary.get("news_calendar") or {}).get("max_age_hours", 9999))
            <= 336
        ),
        "no_log_bomb": summary.get("log_bomb_detected") is False,
    }
    failed = sorted(key for key, value in checks.items() if not value)
    if failed:
        raise RecoveryError(
            f"done row {work_item_id} evidence failed: {','.join(failed)}"
        )
    return {
        "work_item_id": work_item_id,
        "cell_key": cell["cell_key"],
        "evidence_path": str(evidence_path.resolve()),
        "evidence_sha256": _sha256_file(evidence_path),
        "setfile_sha256": setfile_sha256,
        "successful_real_tick_attempts": len(ok_runs),
        "attempt_count_in_summary": len(summary.get("runs", [])),
    }


def _validate_matrix_rows(
    conn: sqlite3.Connection,
    ledger: Mapping[str, Any],
) -> tuple[tuple[dict[str, Any], ...], tuple[dict[str, Any], ...], list[dict[str, Any]]]:
    cells = [dict(value) for value in ledger.get("cells", [])]
    if len(cells) != EXPECTED_CELLS:
        raise RecoveryError(f"legacy ledger expected {EXPECTED_CELLS} cells, found {len(cells)}")
    cell_by_id = {str(cell["work_item_id"]): cell for cell in cells}
    if len(cell_by_id) != EXPECTED_CELLS:
        raise RecoveryError("legacy ledger cell IDs are not unique")
    marks = ",".join("?" for _ in cell_by_id)
    rows = [
        dict(row)
        for row in conn.execute(
            f"SELECT * FROM work_items WHERE id IN ({marks})", tuple(cell_by_id)
        ).fetchall()
    ]
    if len(rows) != EXPECTED_CELLS:
        raise RecoveryError(
            f"legacy ledger has {EXPECTED_CELLS - len(rows)} missing work-item rows"
        )
    done: list[dict[str, Any]] = []
    pending: list[dict[str, Any]] = []
    adoption: list[dict[str, Any]] = []
    for row in rows:
        work_item_id = str(row["id"])
        cell = cell_by_id[work_item_id]
        payload = _decode_payload(row)
        if (
            row["ea_id"] != MEASUREMENT_EA_ID
            or row["symbol"] != SYMBOL
            or str(row["phase"]).upper() != census.PHASE
            or str(row["setfile_path"]) != str(cell["setfile_path"])
        ):
            raise RecoveryError(f"legacy row scope mismatch: {work_item_id}")
        for key in ("cell_key", "arm", "direction", "predicate_id", "year", "from_date", "to_date"):
            if payload.get(key) != cell.get(key):
                raise RecoveryError(f"legacy row {work_item_id} payload {key} mismatch")
        setfile_path = Path(str(cell["setfile_path"]))
        if not setfile_path.is_file():
            raise RecoveryError(f"legacy cell setfile missing: {setfile_path}")
        setfile_sha256 = _sha256_file(setfile_path)
        row["_cell"] = cell
        row["_setfile_sha256"] = setfile_sha256
        if row["status"] == "done":
            adoption.append(
                _validate_done_evidence(
                    row,
                    cell,
                    setfile_sha256=setfile_sha256,
                )
            )
            done.append(row)
        elif row["status"] == "pending":
            if row["claimed_by"] is not None or row["verdict"] is not None:
                raise RecoveryError(f"pending CAS guard failed for {work_item_id}")
            if row["parent_task_id"] is not None:
                raise RecoveryError(f"legacy pending row already has parent: {work_item_id}")
            if payload.get("q12_work_item_id") or payload.get("q12_declaration_sha256"):
                raise RecoveryError(f"legacy pending row is partly governed: {work_item_id}")
            pending.append(row)
        else:
            raise RecoveryError(
                f"legacy row {work_item_id} has unsupported status {row['status']}"
            )
    if len(done) != EXPECTED_DONE or len(pending) != EXPECTED_PENDING:
        raise RecoveryError(
            f"legacy census changed: done={len(done)} pending={len(pending)} "
            f"expected={EXPECTED_DONE}/{EXPECTED_PENDING}"
        )
    return tuple(done), tuple(pending), adoption


def _candidate_declaration(
    ledger: Mapping[str, Any],
    *,
    measurement_bindings: Mapping[str, Any],
    base_setfile_text: str,
) -> dict[str, Any]:
    declaration = fork_driver._pattern_candidate_declaration(
        parent={"ea_id": MEASUREMENT_EA_ID, "symbol": SYMBOL},
        parent_bindings={
            "source": measurement_bindings["source"],
            "setfile": {
                **measurement_bindings["setfile"],
                "text": base_setfile_text,
            },
        },
    )
    declaration["ea_id"] = SUBJECT_EA_ID
    declaration["declaration_sha256"] = _sha256_bytes(
        _canonical_bytes(
            {key: value for key, value in declaration.items() if key != "declaration_sha256"}
        )
    )
    legacy_cells = {
        str(cell["work_item_id"]): cell for cell in ledger.get("cells", [])
    }
    declared_cells = declaration["annual_cells"]
    if len(declared_cells) != EXPECTED_CELLS:
        raise RecoveryError("generated declaration does not contain 1,085 annual cells")
    for declared in declared_cells:
        legacy = legacy_cells.get(str(declared["work_item_id"]))
        if legacy is None:
            raise RecoveryError(
                f"declaration changes legacy candidate identity: {declared['cell_key']}"
            )
        for key in (
            "cell_key",
            "work_item_id",
            "year",
            "from_date",
            "to_date",
            "arm",
            "direction",
            "predicate_id",
        ):
            if declared[key] != legacy[key]:
                raise RecoveryError(
                    f"declaration changes legacy candidate field {key}: {declared['cell_key']}"
                )
    return declaration


def _q04_diagnostic(conn: sqlite3.Connection) -> dict[str, Any]:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (Q04_WORK_ITEM_ID,)).fetchone()
    if row is None:
        return {"work_item_id": Q04_WORK_ITEM_ID, "root_cause": "ROW_MISSING"}
    ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    position = next(
        (index for index, candidate in enumerate(ordered, start=1) if candidate["id"] == row["id"]),
        None,
    )
    history: dict[str, Any] = {}
    for terminal in farmctl.worker_policy_terminals():
        ok, detail = terminal_worker._p2_history_claimable(
            row, terminal, farmctl._dwx_symbol_history_registry()
        )
        history[str(terminal)] = {"claimable": bool(ok), "detail": detail}
    holds = [
        dict(value)
        for value in conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (row["id"],)
        ).fetchall()
    ]
    active_pair = int(
        conn.execute(
            "SELECT count(*) FROM work_items WHERE status='active' "
            "AND (upper(symbol)=upper(?) OR ea_id=?)",
            (row["symbol"], row["ea_id"]),
        ).fetchone()[0]
    )
    return {
        "work_item_id": row["id"],
        "status": row["status"],
        "verdict": row["verdict"],
        "claimed_by": row["claimed_by"],
        "gate_contract_version": row["gate_contract_version"],
        "active_holds": [value for value in holds if int(value.get("active") or 0)],
        "active_pair_rows": active_pair,
        "pending_order_position": position,
        "pending_order_total": len(ordered),
        "history_claimable_all_terminals": all(
            value["claimable"] for value in history.values()
        ),
        "history_by_terminal": history,
        "root_cause": (
            "ORDINARY_Q04_QUEUE_TAIL_NO_HOLD_OR_HISTORY_BLOCK"
            if position is not None and not holds and active_pair == 0
            else "Q04_REQUIRES_SEPARATE_REVIEW"
        ),
        "mutation": "NONE_ROOT_CAUSE_ONLY",
    }


def build_plan(
    conn: sqlite3.Connection,
    *,
    repo_root: Path,
    legacy_ledger_path: Path,
    artifact_root: Path,
) -> RecoveryPlan:
    repo_root = repo_root.resolve()
    legacy_ledger_path = legacy_ledger_path.resolve()
    if _sha256_file(legacy_ledger_path) != LEGACY_LEDGER_SHA256:
        raise RecoveryError("legacy ledger SHA-256 changed; refuse candidate-universe drift")
    legacy_ledger = json.loads(legacy_ledger_path.read_text(encoding="utf-8-sig"))
    if (
        legacy_ledger.get("schema") != census.SCHEMA
        or legacy_ledger.get("program_id") != PROGRAM_ID
        or legacy_ledger.get("ea_id") != MEASUREMENT_EA_ID
        or legacy_ledger.get("symbol") != SYMBOL
        or legacy_ledger.get("planned_trials") != EXPECTED_CELLS
    ):
        raise RecoveryError("legacy ledger identity/header mismatch")

    active = conn.execute(
        "SELECT id,phase,claimed_by FROM work_items WHERE ea_id=? AND status='active'",
        (MEASUREMENT_EA_ID,),
    ).fetchall()
    if active:
        raise RecoveryError(
            "strict no-touch stop: QM5_41097 has active rows: "
            + ",".join(str(row["id"]) for row in active)
        )

    source_path = repo_root / "framework" / "EAs" / EA_DIR_NAME / f"{EA_DIR_NAME}.mq5"
    ex5_path = repo_root / "framework" / "EAs" / EA_DIR_NAME / f"{EA_DIR_NAME}.ex5"
    card_path = repo_root / "framework" / "EAs" / EA_DIR_NAME / "docs" / "strategy_card.md"
    grid_path = repo_root / "framework" / "EAs" / EA_DIR_NAME / "opt_param_grid.json"
    if _sha256_file(source_path) != SOURCE_SHA256:
        raise RecoveryError("QM5_41097 source hash drift")
    if _sha256_file(ex5_path) != EX5_SHA256:
        raise RecoveryError("QM5_41097 executable hash drift")

    program_dir = artifact_root.resolve() / PROGRAM_ID
    paths = {
        "program_dir": program_dir,
        "legacy_ledger_copy": program_dir / "legacy_source_ledger.json",
        "sealed_ledger": program_dir / "ledger.json",
        "declaration": program_dir / "q12_declaration.json",
        "done_adoption": program_dir / "legacy_done_adoption.json",
        "registration": program_dir / "runner_registration.json",
        "receipt": program_dir / "recovery_receipt.json",
    }
    base_bytes = _base_setfile_from_baseline(legacy_ledger)
    base_path = (
        program_dir
        / "base_setfiles"
        / f"{EA_DIR_NAME}_{SYMBOL}_{TIMEFRAME}_legacy_recovery_{_sha256_bytes(base_bytes)[:16]}.set"
    )
    paths["base_setfile"] = base_path
    measurement_bindings = {
        "source": _binding(source_path),
        "binary": _binding(ex5_path),
        "setfile": _content_binding(base_path, base_bytes),
        "card": _binding(card_path),
        "param_grid": _binding(grid_path),
    }

    done_rows, pending_rows, adoption_rows = _validate_matrix_rows(conn, legacy_ledger)
    declaration = _candidate_declaration(
        legacy_ledger,
        measurement_bindings=measurement_bindings,
        base_setfile_text=base_bytes.decode("utf-8"),
    )
    q12_id = str(
        uuid.uuid5(
            RECOVERY_NAMESPACE,
            f"{OWNER_TASK_ID}:{PROGRAM_ID}:{LEGACY_LEDGER_SHA256}:{declaration['declaration_sha256']}",
        )
    )

    parent = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (PARENT_WORK_ITEM_ID,)
    ).fetchone()
    if (
        parent is None
        or parent["ea_id"] != SUBJECT_EA_ID
        or parent["symbol"] != SYMBOL
        or str(parent["phase"]).upper() != "Q09"
        or parent["status"] != "done"
        or parent["verdict"] != "PASS"
    ):
        raise RecoveryError("bound QM5_13213 Q09/PASS parent is unavailable")
    parent_bindings = fork_driver._artifact_bindings(parent)
    harness = fork_driver._harness_state(conn)
    if harness.get("green") is not True:
        raise RecoveryError("DL-089 fixture harness is not green")

    legacy_q02 = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (LEGACY_Q02_WORK_ITEM_ID,)
    ).fetchone()
    if (
        legacy_q02 is None
        or legacy_q02["ea_id"] != MEASUREMENT_EA_ID
        or legacy_q02["symbol"] != SYMBOL
        or str(legacy_q02["phase"]).upper() != "Q02"
        or legacy_q02["status"] != "done"
        or legacy_q02["verdict"] != "PASS"
        or str(legacy_q02["ex5_sha256"] or "").lower() != EX5_SHA256
        or str(legacy_q02["mq5_sha256"] or "").lower() != SOURCE_SHA256
    ):
        raise RecoveryError("legacy Q02 execution receipt is not identity-valid")
    q02_evidence = _binding(Path(str(legacy_q02["evidence_path"])))

    done_adoption = {
        "schema": ADOPTION_SCHEMA,
        "authority_task_id": OWNER_TASK_ID,
        "program_id": PROGRAM_ID,
        "q12_work_item_id": q12_id,
        "source_ledger": _binding(legacy_ledger_path),
        "source_sha256": SOURCE_SHA256,
        "binary_sha256": EX5_SHA256,
        "done_count": len(done_rows),
        "done_rows_digest": _done_row_digest(done_rows),
        "validation_contract": {
            "row_identity_columns_bound": True,
            "summary_execution_identity_bound": True,
            "at_least_one_successful_real_tick_attempt": True,
            "news_stale_max_hours_ceiling": 336,
            "verdict_rewrite_allowed": False,
        },
        "rows": sorted(adoption_rows, key=lambda value: value["work_item_id"]),
    }
    adoption_bytes = _pretty_bytes(done_adoption)

    sealed_ledger = json.loads(json.dumps(legacy_ledger))
    sealed_ledger.update(
        {
            "subject_ea_id": SUBJECT_EA_ID,
            "q12_work_item_id": q12_id,
            "q12_declaration_sha256": declaration["declaration_sha256"],
            "declaration_sha256": declaration["declaration_sha256"],
            "declaration_revision": fork_driver.PATTERN_DECLARATION_REVISION,
            "matrix_runner_revision": RUNNER_REVISION,
            "base_setfile_path": str(base_path.resolve()),
            "base_setfile_sha256": measurement_bindings["setfile"]["sha256"],
            "output_dir": str((program_dir / "setfiles").resolve()),
            "driver": selector.init_driver(),
            "legacy_recovery": {
                "schema": SCHEMA,
                "authority_task_id": OWNER_TASK_ID,
                "source_ledger_path": str(legacy_ledger_path),
                "source_ledger_sha256": LEGACY_LEDGER_SHA256,
                "source_ledger_copy_path": str(paths["legacy_ledger_copy"].resolve()),
                "done_adoption_path": str(paths["done_adoption"].resolve()),
                "done_adoption_sha256": _sha256_bytes(adoption_bytes),
                "done_rows_preserved": len(done_rows),
                "pending_rows_to_repair": len(pending_rows),
                "selection_advance_review_hold": REVIEW_HOLD_CODE,
            },
        }
    )

    q04_diagnostic = _q04_diagnostic(conn)
    payload = fork_driver._stage_payload(
        manifest=ACTIVE_GATE_MANIFEST,
        role="PATTERN",
        phase="Q12",
        parent=parent,
        parent_bindings=parent_bindings,
        harness=harness,
    )
    payload.update(
        {
            "pattern_filter_sweep": declaration,
            "execution_lane": "DL089_MATRIX_RUNNER",
            "queue_order_at": str(legacy_ledger["created_at_utc"]),
            "matrix_runner": {
                "schema": "qm.dl089-matrix-runner/v1",
                "revision": RUNNER_REVISION,
                "pair_mode": "SERIAL",
                "priority_window_cap": 8,
                "legacy_recovery": True,
                "review_hold_code": REVIEW_HOLD_CODE,
            },
            "legacy_census_recovery": {
                "schema": SCHEMA,
                "authority_task_id": OWNER_TASK_ID,
                "subject_ea_id": SUBJECT_EA_ID,
                "measurement_ea_id": MEASUREMENT_EA_ID,
                "program_id": PROGRAM_ID,
                "source_ledger": _binding(legacy_ledger_path),
                "sealed_ledger_path": str(paths["sealed_ledger"].resolve()),
                "done_adoption_path": str(paths["done_adoption"].resolve()),
                "done_adoption_sha256": _sha256_bytes(adoption_bytes),
                "measurement_sibling": {
                    "schema": SIBLING_SCHEMA,
                    "ea_id": MEASUREMENT_EA_ID,
                    "ea_label": EA_DIR_NAME,
                    "symbol": SYMBOL,
                    "timeframe": TIMEFRAME,
                    "bindings": measurement_bindings,
                    "legacy_q02_work_item_id": LEGACY_Q02_WORK_ITEM_ID,
                    "legacy_q02_evidence": q02_evidence,
                },
                "done_rows_preserved": len(done_rows),
                "pending_rows_repaired_by_cas": len(pending_rows),
                "selection_advance_allowed": False,
                "selection_advance_blocker": REVIEW_HOLD_CODE,
            },
        }
    )
    payload["routing_identity_sha256"] = _sha256_bytes(_canonical_bytes(payload))
    payload_json = json.dumps(payload, sort_keys=True)
    now = _utc_now()
    q12_row = {
        "id": q12_id,
        "kind": "analytic",
        "phase": "Q12",
        "ea_id": SUBJECT_EA_ID,
        "symbol": SYMBOL,
        "setfile_path": str(parent["setfile_path"]),
        "status": "pending",
        "verdict": None,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": payload_json,
        "created_at": now,
        "updated_at": now,
        "gate_contract_version": "v4",
        "ex5_sha256": parent_bindings["binary"]["sha256"],
        "setfile_sha256": parent_bindings["setfile"]["sha256"],
        "mq5_sha256": parent_bindings["source"]["sha256"],
        "verdict_taxonomy": "open",
        "sh3_enforced": 1,
    }
    registration = {
        "schema": REGISTRATION_SCHEMA,
        "authority_task_id": OWNER_TASK_ID,
        "q12_work_item_id": q12_id,
        "subject_ea_id": SUBJECT_EA_ID,
        "measurement_ea_id": MEASUREMENT_EA_ID,
        "program_id": PROGRAM_ID,
        "declaration_sha256": declaration["declaration_sha256"],
        "annual_cells_sha256": declaration["annual_cells_sha256"],
        "wf_cells_sha256": declaration["wf_cells_sha256"],
        "matrix_runner_revision": RUNNER_REVISION,
        "legacy_source_ledger": _binding(legacy_ledger_path),
        "sealed_ledger_path": str(paths["sealed_ledger"].resolve()),
        "measurement_bindings": measurement_bindings,
        "legacy_q02_work_item_id": LEGACY_Q02_WORK_ITEM_ID,
        "legacy_q02_evidence": q02_evidence,
        "done_adoption_path": str(paths["done_adoption"].resolve()),
        "done_adoption_sha256": _sha256_bytes(adoption_bytes),
        "done_cells_preserved": len(done_rows),
        "pending_cells_guarded_cas": len(pending_rows),
        "review_hold_code": REVIEW_HOLD_CODE,
        "selection_advance_allowed": False,
        "q04_diagnostic": q04_diagnostic,
    }
    return RecoveryPlan(
        q12_work_item_id=q12_id,
        q12_payload=payload,
        q12_payload_json=payload_json,
        q12_row=q12_row,
        declaration=declaration,
        legacy_ledger=legacy_ledger,
        sealed_ledger=sealed_ledger,
        pending_rows=pending_rows,
        done_rows=done_rows,
        done_adoption=done_adoption,
        registration=registration,
        q04_diagnostic=q04_diagnostic,
        paths=paths,
        bindings=measurement_bindings,
        base_setfile_bytes=base_bytes,
    )


def _desired_pending_payload(plan: RecoveryPlan, row: Mapping[str, Any]) -> dict[str, Any]:
    cell = row["_cell"]
    payload = _decode_payload(row)
    payload.update(
        {
            "schema": census.SCHEMA,
            "program_id": PROGRAM_ID,
            "cell_key": cell["cell_key"],
            "year": cell["year"],
            "arm": cell["arm"],
            "direction": cell["direction"],
            "predicate_id": cell["predicate_id"],
            "from_date": cell["from_date"],
            "to_date": cell["to_date"],
            "host_timeframe": TIMEFRAME,
            "opt_census_pool": True,
            "declared_trial_count": census.DECLARED_TRIAL_COUNT,
            "planned_trials": EXPECTED_CELLS,
            "ledger_path": str(plan.paths["sealed_ledger"].resolve()),
            "q12_work_item_id": plan.q12_work_item_id,
            "q12_declaration_sha256": plan.declaration["declaration_sha256"],
            "matrix_runner_revision": RUNNER_REVISION,
            "ea_dir_name": EA_DIR_NAME,
            "expected_ex5_path": plan.bindings["binary"]["path"],
            "expected_ex5_sha256": EX5_SHA256,
            "expected_mq5_sha256": SOURCE_SHA256,
            "expected_setfile_sha256": row["_setfile_sha256"],
            "expected_symbol": SYMBOL,
            "expected_period": TIMEFRAME,
            "expected_expert": f"QM\\{EA_DIR_NAME}",
            "expected_from_date": cell["from_date"],
            "expected_to_date": cell["to_date"],
            "expected_trades_per_year_per_symbol": 20,
            "evidence_binding_required": True,
            "legacy_governance_recovery": {
                "schema": SCHEMA,
                "authority_task_id": OWNER_TASK_ID,
                "source_ledger_sha256": LEGACY_LEDGER_SHA256,
                "pending_only_cas": True,
            },
        }
    )
    return payload


def _insert_q12(conn: sqlite3.Connection, plan: RecoveryPlan, *, now: str) -> int:
    existing = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (plan.q12_work_item_id,)
    ).fetchone()
    if existing is not None:
        if (
            str(existing["phase"]).upper() != "Q12"
            or existing["ea_id"] != SUBJECT_EA_ID
            or existing["symbol"] != SYMBOL
            or existing["payload_json"] != plan.q12_payload_json
        ):
            raise RecoveryError("deterministic Q12 recovery identity collision")
        return 0
    row = dict(plan.q12_row)
    row["created_at"] = now
    row["updated_at"] = now
    conn.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
          gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
          verdict_taxonomy,sh3_enforced
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        tuple(
            row[key]
            for key in (
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
                "gate_contract_version",
                "ex5_sha256",
                "setfile_sha256",
                "mq5_sha256",
                "verdict_taxonomy",
                "sh3_enforced",
            )
        ),
    )
    return 1


def apply_database_recovery(conn: sqlite3.Connection, plan: RecoveryPlan) -> dict[str, Any]:
    """Apply the append-only wrapper and pending-only CAS in one transaction."""

    now = _utc_now()
    done_before = _done_row_digest(plan.done_rows)
    conn.execute("BEGIN IMMEDIATE")
    try:
        active = conn.execute(
            "SELECT id FROM work_items WHERE ea_id=? AND status='active'",
            (MEASUREMENT_EA_ID,),
        ).fetchall()
        if active:
            raise RecoveryError("strict no-touch stop: QM5_41097 became active")
        inserted_q12 = _insert_q12(conn, plan, now=now)
        repaired = 0
        already_valid = 0
        for planned in plan.pending_rows:
            work_item_id = str(planned["id"])
            current = conn.execute(
                "SELECT * FROM work_items WHERE id=?", (work_item_id,)
            ).fetchone()
            if current is None:
                raise RecoveryError(f"pending row disappeared: {work_item_id}")
            desired = _desired_pending_payload(plan, planned)
            desired_json = json.dumps(desired, sort_keys=True)
            already = (
                current["status"] == "pending"
                and current["claimed_by"] is None
                and current["verdict"] is None
                and current["parent_task_id"] == plan.q12_work_item_id
                and current["payload_json"] == desired_json
                and current["gate_contract_version"] == planned["gate_contract_version"]
                and current["ex5_sha256"] == EX5_SHA256
                and current["mq5_sha256"] == SOURCE_SHA256
                and current["setfile_sha256"] == planned["_setfile_sha256"]
            )
            if already:
                already_valid += 1
                continue
            if (
                current["status"] != "pending"
                or current["claimed_by"] is not None
                or current["verdict"] is not None
                or current["parent_task_id"] is not None
                or current["payload_json"] != planned["payload_json"]
            ):
                raise RecoveryError(f"pending CAS preimage changed: {work_item_id}")
            cursor = conn.execute(
                """
                UPDATE work_items
                SET parent_task_id=?,payload_json=?,updated_at=?,
                    ex5_sha256=?,mq5_sha256=?,setfile_sha256=?
                WHERE id=? AND status='pending' AND claimed_by IS NULL AND verdict IS NULL
                  AND parent_task_id IS NULL AND payload_json=?
                """,
                (
                    plan.q12_work_item_id,
                    desired_json,
                    now,
                    EX5_SHA256,
                    SOURCE_SHA256,
                    planned["_setfile_sha256"],
                    work_item_id,
                    planned["payload_json"],
                ),
            )
            if cursor.rowcount != 1:
                raise RecoveryError(f"pending CAS lost: {work_item_id}")
            repaired += 1

        existing_hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?",
            (plan.q12_work_item_id,),
        ).fetchone()
        if existing_hold is None:
            conn.execute(
                """
                INSERT INTO work_item_holds(
                  work_item_id,hold_code,reason,active,release_on_restart,
                  created_at,updated_at
                ) VALUES(?,?,?,1,0,?,?)
                """,
                (
                    plan.q12_work_item_id,
                    REVIEW_HOLD_CODE,
                    "Independent review required before any selector advance; governed annual measurement may continue",
                    now,
                    now,
                ),
            )
            hold_inserted = 1
        elif (
            existing_hold["hold_code"] == REVIEW_HOLD_CODE
            and int(existing_hold["active"] or 0) == 1
        ):
            hold_inserted = 0
        else:
            raise RecoveryError("Q12 recovery has an incompatible existing hold")

        ids = [str(row["id"]) for row in plan.done_rows]
        marks = ",".join("?" for _ in ids)
        done_after_rows = [
            dict(row)
            for row in conn.execute(
                f"SELECT * FROM work_items WHERE id IN ({marks})", ids
            ).fetchall()
        ]
        done_after = _done_row_digest(done_after_rows)
        if done_after != done_before:
            raise RecoveryError("completed evidence rows changed during recovery")

        governed = int(
            conn.execute(
                """
                SELECT count(*) FROM work_items
                WHERE phase=? AND ea_id=? AND status='pending' AND claimed_by IS NULL
                  AND verdict IS NULL AND parent_task_id=?
                  AND json_extract(payload_json,'$.q12_work_item_id')=?
                  AND json_extract(payload_json,'$.q12_declaration_sha256')=?
                """,
                (
                    census.PHASE,
                    MEASUREMENT_EA_ID,
                    plan.q12_work_item_id,
                    plan.q12_work_item_id,
                    plan.declaration["declaration_sha256"],
                ),
            ).fetchone()[0]
        )
        if governed != EXPECTED_PENDING:
            raise RecoveryError(f"post-CAS governed pending count is {governed}")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return {
        "q12_rows_inserted": inserted_q12,
        "review_holds_inserted": hold_inserted,
        "pending_rows_repaired": repaired,
        "pending_rows_already_valid": already_valid,
        "governed_pending_rows": governed,
        "done_rows_preserved": len(plan.done_rows),
        "done_rows_digest_before": done_before,
        "done_rows_digest_after": done_after,
        "verdict_rows_touched": 0,
    }


def _write_plan_artifacts(plan: RecoveryPlan, legacy_ledger_path: Path) -> dict[str, Any]:
    _copy_exact(legacy_ledger_path, plan.paths["legacy_ledger_copy"])
    _atomic_write_bytes(plan.paths["base_setfile"], plan.base_setfile_bytes)
    _atomic_write_bytes(plan.paths["declaration"], _pretty_bytes(plan.declaration))
    _atomic_write_bytes(plan.paths["done_adoption"], _pretty_bytes(plan.done_adoption))
    _atomic_write_bytes(plan.paths["sealed_ledger"], _pretty_bytes(plan.sealed_ledger))
    _atomic_write_bytes(plan.paths["registration"], _pretty_bytes(plan.registration))
    return {
        key: {
            "path": str(path.resolve()),
            "sha256": _sha256_file(path),
            "size_bytes": path.stat().st_size,
        }
        for key, path in plan.paths.items()
        if key not in {"program_dir", "receipt"}
    }


def _claimability_snapshot(conn: sqlite3.Connection, plan: RecoveryPlan) -> dict[str, Any]:
    ids = [str(cell["work_item_id"]) for cell in plan.sealed_ledger["cells"]]
    marks = ",".join("?" for _ in ids)
    rows = [
        dict(row)
        for row in conn.execute(
            f"SELECT * FROM work_items WHERE id IN ({marks})", ids
        ).fetchall()
    ]
    governed_pending = [
        row
        for row in rows
        if row["status"] == "pending"
        and row["claimed_by"] is None
        and row["verdict"] is None
        and terminal_worker._is_governed_dl089_census_payload(
            _decode_payload(row)
        )
    ]
    frontier = dl089_scheduling.arm_frontier(rows, plan.sealed_ledger)
    pending_frontier = [
        row
        for row in frontier.values()
        if str(row["status"]).lower() == "pending"
    ]
    return {
        "governed_pending_count": len(governed_pending),
        "arm_frontier_count": len(frontier),
        "pending_arm_frontier_count": len(pending_frontier),
        "first_pending_frontier_id": (
            None if not pending_frontier else str(pending_frontier[0]["id"])
        ),
        "all_pending_payloads_governed": len(governed_pending) == EXPECTED_PENDING,
    }


def execute(
    *,
    repo_root: Path,
    farm_root: Path,
    legacy_ledger_path: Path,
    artifact_root: Path,
    apply: bool,
) -> dict[str, Any]:
    db_path = farmctl.db_path(farm_root)
    with farmctl.connect(farm_root) as conn:
        plan = build_plan(
            conn,
            repo_root=repo_root,
            legacy_ledger_path=legacy_ledger_path,
            artifact_root=artifact_root,
        )
    summary: dict[str, Any] = {
        "schema": RECEIPT_SCHEMA,
        "applied": False,
        "authority_task_id": OWNER_TASK_ID,
        "program_id": PROGRAM_ID,
        "q12_work_item_id": plan.q12_work_item_id,
        "declaration_sha256": plan.declaration["declaration_sha256"],
        "legacy_ledger_path": str(legacy_ledger_path.resolve()),
        "legacy_ledger_sha256": LEGACY_LEDGER_SHA256,
        "sealed_ledger_path": str(plan.paths["sealed_ledger"].resolve()),
        "done_validity_assessment": {
            "valid": len(plan.done_rows),
            "invalid": 0,
            "append_only_reenqueue_required": 0,
            "append_only_reenqueue_cost_backtests": 0,
        },
        "pending_cas_plan": len(plan.pending_rows),
        "q04_diagnostic": plan.q04_diagnostic,
        "selection_advance": "BLOCKED_PENDING_INDEPENDENT_REVIEW",
        "review_hold_code": REVIEW_HOLD_CODE,
    }
    if not apply:
        return summary

    lock_path = farm_root / "state" / "factory_mutation.lock"
    with FactoryMutationLock(
        lock_path,
        owner=f"recover_legacy_opt_census:{OWNER_TASK_ID}",
    ):
        # Rebuild under the mutation lock so every DB/file precondition is fresh.
        with farmctl.connect(farm_root) as conn:
            plan = build_plan(
                conn,
                repo_root=repo_root,
                legacy_ledger_path=legacy_ledger_path,
                artifact_root=artifact_root,
            )
        artifact_bindings = _write_plan_artifacts(plan, legacy_ledger_path)
        with farmctl.connect(farm_root) as conn:
            database = apply_database_recovery(conn, plan)
            claimability = _claimability_snapshot(conn, plan)
        if claimability["all_pending_payloads_governed"] is not True:
            raise RecoveryError("post-commit claimability verification failed")
        if _sha256_file(legacy_ledger_path) != LEGACY_LEDGER_SHA256:
            raise RecoveryError("legacy ledger changed during recovery")
        receipt = {
            **summary,
            "applied": True,
            "applied_at_utc": _utc_now(),
            "database_path": str(db_path.resolve()),
            "database_result": database,
            "claimability": claimability,
            "artifacts": artifact_bindings,
            "legacy_ledger_history_mutated": False,
            "verdict_rows_touched": 0,
        }
        _atomic_write_bytes(plan.paths["receipt"], _pretty_bytes(receipt))
        receipt["receipt"] = _binding(plan.paths["receipt"])
        return receipt


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=farmctl.CANONICAL_REPO_ROOT)
    parser.add_argument("--farm-root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--legacy-ledger", type=Path, default=DEFAULT_LEGACY_LEDGER)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        result = execute(
            repo_root=args.repo_root,
            farm_root=args.farm_root,
            legacy_ledger_path=args.legacy_ledger,
            artifact_root=args.artifact_root,
            apply=bool(args.apply),
        )
    except (
        RecoveryError,
        fork_driver.OptimizationForkError,
        census.CensusError,
        sqlite3.Error,
        OSError,
        ValueError,
    ) as exc:
        print(
            json.dumps(
                {
                    "schema": RECEIPT_SCHEMA,
                    "applied": False,
                    "status": "REFUSED",
                    "error": f"{type(exc).__name__}: {exc}",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
