#!/usr/bin/env python3
"""Apply the OWNER-approved DL-082 extension Option-D Q08 regrade append-only.

The command is deliberately two-stage. ``plan`` authenticates the authority,
the exact historical cohort, the retained (plain or gzip) Q08 snapshots, and
the current runnable bindings. ``apply`` accepts only that hash-bound plan,
writes thirteen new aggregate files, inserts thirteen new Q08 rows, and proves
that no historical verdict, Q09 row, or excluded snapshot changed.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import gzip
import hashlib
import json
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any, Iterable, Mapping

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:  # pragma: no cover - package import in tests
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

from framework.scripts.q08_davey import aggregate as q08_aggregate
from tools.strategy_farm import farmctl
from tools.strategy_farm.phase_ids import ACTIVE_GATE_CONTRACT_VERSION, next_phase


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DEFAULT_ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\q08_dl082_ext_option_d")
DECISION_CONFIG = REPO_ROOT / "tools/strategy_farm/config/owner_decision_execution.v1.json"
DECISION_DOC = REPO_ROOT / "docs/ops/DL-082_EXTENSION_VORLAGE_Q08_85_89_2026-09-01.md"
OWNER_RECEIPTS = Path(r"D:\QM\reports\state\owner_decision_receipts.jsonl")
EXECUTION_EVIDENCE = REPO_ROOT / (
    "docs/ops/evidence/2026-09-01_dl082-ext-q08-20260901_b33989e1_execution.md"
)

ROUTER_TASK_ID = "7a9c09d6-5226-48a9-aec2-5d6cfff120fe"
EXECUTION_TASK_ID = "710e4a63-5f7e-5704-9f6e-ed0ff176ecf0"
OWNER_DECISION_ID = "OWNER-DEC-DL082-EXT-Q08-20260901"
OWNER_RECEIPT_ID = "b33989e1-17d8-4ebc-bf42-4045cb871a61"
OWNER_RECEIPT_SHA256 = "9d08ab71262e05cc1fd5fc55b71055d3a5ab5ebac4a8c5ec571ada66a9978932"
EXECUTION_CONTRACT_SHA256 = "256c71115298e343c4806a3508d3ea5c24e7fe1c917f0888cd26f83dd5569e22"
PLAN_SCHEMA = "qm.dl082-ext-option-d-regrade-plan/v1"
RECEIPT_SCHEMA = "qm.dl082-ext-option-d-regrade-receipt/v1"
RE_GRADE_SCHEMA = "qm.dl082-ext-option-d-q08-regrade/v1"
NAMESPACE = uuid.UUID("7a32294b-96db-5b37-b2dd-0ad5e9acf6f2")


# Each path is the exact qualifying snapshot selected from the 220-file
# decision census. A work-item lineage can have several retained snapshots;
# the selected snapshot, not a mutable "latest" lookup, is the authority.
TARGETS: tuple[tuple[str, str, str, Path], ...] = (
    (
        "a472a5f9-c614-4c7d-9ff0-8542085e9a02", "QM5_11421", "AUDUSD.DWX",
        Path(r"D:\QM\reports\work_items\a472a5f9-c614-4c7d-9ff0-8542085e9a02\QM5_11421\Q08\AUDUSD_DWX\aggregate.json"),
    ),
    (
        "57401491-a02f-477c-b215-e30ded3276ac", "QM5_1567", "GBPJPY.DWX",
        Path(r"D:\QM\reports\work_items\57401491-a02f-477c-b215-e30ded3276ac.requeued_20260725T2046540000\QM5_1567\Q08\GBPJPY_DWX\aggregate.json.gz"),
    ),
    (
        "6033e9f6-7820-4ed3-b7b1-89b22e606250", "QM5_1567", "GBPNZD.DWX",
        Path(r"D:\QM\reports\work_items\6033e9f6-7820-4ed3-b7b1-89b22e606250.requeued_20260725T2046540000\QM5_1567\Q08\GBPNZD_DWX\aggregate.json.gz"),
    ),
    (
        "78849592-dffe-4344-8edc-fdf9d1c8fc64", "QM5_1567", "XAGUSD.DWX",
        Path(r"D:\QM\reports\work_items\78849592-dffe-4344-8edc-fdf9d1c8fc64.requeued_20260725T2046540000\QM5_1567\Q08\XAGUSD_DWX\aggregate.json.gz"),
    ),
    (
        "5591c213-70c8-4fec-9929-e34ec9015f5a", "QM5_12552", "USDCAD.DWX",
        Path(r"D:\QM\reports\work_items\5591c213-70c8-4fec-9929-e34ec9015f5a\QM5_12552\Q08\USDCAD_DWX\aggregate.json"),
    ),
    (
        "49f775aa-40e6-4e0a-b446-1b4c76b36c8b", "QM5_1551", "USDJPY.DWX",
        Path(r"D:\QM\reports\work_items\49f775aa-40e6-4e0a-b446-1b4c76b36c8b\QM5_1551\Q08\USDJPY_DWX\aggregate.json"),
    ),
    (
        "3426f0de-f85a-441a-8208-436d9c66c209", "QM5_10569", "XAUUSD.DWX",
        Path(r"D:\QM\reports\work_items\3426f0de-f85a-441a-8208-436d9c66c209\QM5_10569\Q08\XAUUSD_DWX\aggregate.json"),
    ),
    (
        "46e7f5b4-9e7d-402e-9547-692638cfa0a7", "QM5_11403", "EURUSD.DWX",
        Path(r"D:\QM\reports\work_items\46e7f5b4-9e7d-402e-9547-692638cfa0a7\QM5_11403\Q08\EURUSD_DWX\aggregate.json"),
    ),
    (
        "7dac7395-81e5-4e9c-b7ea-716bad0d72c5", "QM5_1355", "NDX.DWX",
        Path(r"D:\QM\reports\work_items\7dac7395-81e5-4e9c-b7ea-716bad0d72c5\QM5_1355\Q08\NDX_DWX\aggregate.json"),
    ),
    (
        "bdee654a-73e8-461c-b2a5-2af8319237c8", "QM5_11294", "NDX.DWX",
        Path(r"D:\QM\reports\work_items\bdee654a-73e8-461c-b2a5-2af8319237c8\QM5_11294\Q08\NDX_DWX\aggregate.json"),
    ),
    (
        "4a806fa5-a7d9-44bd-825c-34a84bac9347", "QM5_12474", "GBPUSD.DWX",
        Path(r"D:\QM\reports\work_items\4a806fa5-a7d9-44bd-825c-34a84bac9347\QM5_12474\Q08\GBPUSD_DWX\aggregate.json.gz"),
    ),
    (
        "bcd27a1b-31b6-4fa3-97f8-e03b0f34a2cc", "QM5_10715", "USDJPY.DWX",
        Path(r"D:\QM\reports\work_items\bcd27a1b-31b6-4fa3-97f8-e03b0f34a2cc\QM5_10715\Q08\USDJPY_DWX\aggregate.json.gz"),
    ),
    (
        "f7f379d3-841d-455a-a64f-ea69ea3fc5ef", "QM5_10476", "USDCAD.DWX",
        Path(r"D:\QM\reports\work_items\f7f379d3-841d-455a-a64f-ea69ea3fc5ef\QM5_10476\Q08\USDCAD_DWX\aggregate.json.gz"),
    ),
)

EURGBP_EXCLUSION = (
    "6fbd21d9-5693-4095-a5d9-594d2cc4c075", "QM5_1567", "EURGBP.DWX",
    Path(r"D:\QM\reports\work_items\6fbd21d9-5693-4095-a5d9-594d2cc4c075.requeued_20260725T2046540000\QM5_1567\Q08\EURGBP_DWX\aggregate.json.gz"),
)

MULTICAUSE_SNAPSHOTS: tuple[Path, ...] = (
    Path(r"D:\QM\reports\work_items\0726967d-01d1-4134-baad-aee2e3141340\QM5_10229\Q08\XAUUSD_DWX\aggregate.json"),
    Path(r"D:\QM\reports\work_items\084a05e0-99cf-435e-bce3-d464d97081e0\QM5_12567\Q08\XNGUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\1ec1974a-fc5b-4760-a663-3f679ddea14d\QM5_11267\Q08\XAUUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\78849592-dffe-4344-8edc-fdf9d1c8fc64\QM5_1567\Q08\XAGUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\83ff9db9-5620-4282-9df8-d9c18dae3b8b\QM5_10566\Q08\XAUUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\b8d5110e-70f1-4873-82d4-b42182898a3e\QM5_10196\Q08\XAUUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\c825cf9a-7e4d-4240-be1d-9bab9b249bf0\QM5_10555\Q08\XAUUSD_DWX\aggregate.json.gz"),
    Path(r"D:\QM\reports\work_items\d9f360d4-6fa3-47ab-bddb-6a33a616f540.requeued_manual_20260718T_calib\QM5_13117\Q08\QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1\aggregate.json.gz"),
)

EXPECTED_CENSUS_VERDICTS = {
    "FAIL_SOFT": 80,
    "PASS": 80,
    "FAIL_HARD": 29,
    "INVALID": 17,
    "INFRA_RECYCLE": 10,
    "INFRA_FAIL": 4,
}
VALID_PERIODS = frozenset({"M1", "M5", "M15", "M30", "H1", "H4", "H6", "H8", "D1", "W1", "MN1"})


class RegradeError(RuntimeError):
    """Fail-closed authority, evidence, scope, or postcondition error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    ).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json_snapshot(path: Path) -> tuple[dict[str, Any], bytes, bytes]:
    if not path.is_file():
        raise RegradeError(f"snapshot_missing:{path}")
    storage = path.read_bytes()
    try:
        raw = gzip.decompress(storage) if path.name.endswith(".gz") else storage
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RegradeError(f"snapshot_unreadable:{path}:{exc}") from exc
    if not isinstance(value, dict):
        raise RegradeError(f"snapshot_not_object:{path}")
    return value, storage, raw


def write_exact(path: Path, raw: bytes) -> str:
    digest = sha256_bytes(raw)
    if path.exists():
        if sha256_file(path) != digest:
            raise RegradeError(f"output_exists_with_different_bytes:{path}")
        return digest
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(raw)
    temporary.replace(path)
    return digest


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
        conn.execute("PRAGMA query_only=ON")
    else:
        conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def row_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def row_sha256(row: sqlite3.Row) -> str:
    return sha256_bytes(canonical_bytes(row_snapshot(row)))


def new_work_item_id(ea_id: str, symbol: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{OWNER_DECISION_ID}|Q08|{ea_id}|{symbol}"))


def normalize_ea(value: Any) -> str:
    text = str(value or "").strip().upper()
    return text if text.startswith("QM5_") else f"QM5_{text}"


def option_d_decision(aggregate: Mapping[str, Any]) -> dict[str, Any]:
    classification = aggregate.get("verdict_classification")
    if not isinstance(classification, dict):
        raise RegradeError("verdict_classification_missing")
    return q08_aggregate._dl082_ext_option_d(
        classification, aggregate.get("cost_cushion_tier")
    )


def _setfile_values(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        raise RegradeError(f"setfile_unreadable:{path}:{exc}") from exc
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip().upper()] = value.strip()
    return values


def runnable_binding(setfile_path: Path) -> dict[str, Any]:
    if not setfile_path.is_file():
        raise RegradeError(f"setfile_missing:{setfile_path}")
    values = _setfile_values(setfile_path)
    try:
        risk_fixed = float(values["RISK_FIXED"])
        risk_percent = float(values["RISK_PERCENT"])
    except (KeyError, ValueError) as exc:
        raise RegradeError(f"fixed_risk_contract_invalid:{setfile_path}:{exc}") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise RegradeError(
            f"fixed_risk_contract_violation:{setfile_path}:{risk_fixed}:{risk_percent}"
        )
    stale_raw = values.get("QM_NEWS_STALE_MAX_HOURS")
    stale_hours = None
    if stale_raw is not None:
        try:
            stale_hours = float(stale_raw)
        except ValueError as exc:
            raise RegradeError(f"news_stale_ceiling_invalid:{setfile_path}:{stale_raw}") from exc
        if stale_hours > 336:
            raise RegradeError(f"news_stale_ceiling_above_336:{setfile_path}:{stale_hours}")
    ea_dir = setfile_path.parent.parent
    mq5_path = ea_dir / f"{ea_dir.name}.mq5"
    ex5_path = ea_dir / f"{ea_dir.name}.ex5"
    if not mq5_path.is_file() or not ex5_path.is_file():
        raise RegradeError(f"runnable_artifact_missing:{ea_dir}")
    return {
        "setfile_path": str(setfile_path.resolve()),
        "setfile_sha256": sha256_file(setfile_path),
        "mq5_path": str(mq5_path.resolve()),
        "mq5_sha256": sha256_file(mq5_path),
        "ex5_path": str(ex5_path.resolve()),
        "ex5_sha256": sha256_file(ex5_path),
        "expert": f"QM\\{ea_dir.name}",
        "risk_fixed": risk_fixed,
        "risk_percent": risk_percent,
        "qm_news_stale_max_hours": stale_hours,
    }


def _period_from_snapshot(aggregate: Mapping[str, Any], setfile_path: Path) -> str:
    baseline = aggregate.get("baseline_run") or {}
    period = str(baseline.get("period") or "").strip().upper()
    if period:
        return period
    parts = setfile_path.stem.upper().split("_")
    for token in reversed(parts):
        if token in VALID_PERIODS:
            return token
    raise RegradeError(f"period_missing:{setfile_path}")


def authority_snapshot(conn: sqlite3.Connection) -> dict[str, Any]:
    if not DECISION_CONFIG.is_file() or not DECISION_DOC.is_file() or not OWNER_RECEIPTS.is_file():
        raise RegradeError("authority_input_missing")
    config = json.loads(DECISION_CONFIG.read_text(encoding="utf-8-sig"))
    decisions = [
        row for row in config.get("decisions", [])
        if row.get("id") == OWNER_DECISION_ID
    ]
    if len(decisions) != 1:
        raise RegradeError(f"decision_contract_count:{len(decisions)}")
    decision = decisions[0]
    yes = decision.get("choices", {}).get("YES", {})
    if yes.get("mode") != "APPLY_AND_VERIFY" or "13" not in str(yes.get("objective") or ""):
        raise RegradeError("decision_contract_not_apply_option_d_13")

    receipts: list[dict[str, Any]] = []
    for line_number, line in enumerate(
        OWNER_RECEIPTS.read_text(encoding="utf-8-sig").splitlines(), start=1
    ):
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError as exc:
            raise RegradeError(f"owner_receipt_json_invalid:{line_number}:{exc}") from exc
        if record.get("receipt_id") == OWNER_RECEIPT_ID:
            receipts.append(record)
    if len(receipts) != 1:
        raise RegradeError(f"owner_receipt_count:{len(receipts)}")
    receipt = receipts[0]
    required_receipt = {
        "decision_id": OWNER_DECISION_ID,
        "decision": "YES",
        "receipt_sha256": OWNER_RECEIPT_SHA256,
        "execution_task_id": EXECUTION_TASK_ID,
        "execution_authorized": True,
        "execution_handoff_authorized": True,
        "live_execution_authorized": False,
        "deployment_authorized": False,
        "autotrading_authorized": False,
    }
    for key, expected in required_receipt.items():
        if receipt.get(key) != expected:
            raise RegradeError(f"owner_receipt_mismatch:{key}:{receipt.get(key)!r}")

    task = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (EXECUTION_TASK_ID,)).fetchone()
    if task is None:
        raise RegradeError("execution_task_missing")
    try:
        task_payload = json.loads(task["payload_json"])
    except (TypeError, json.JSONDecodeError) as exc:
        raise RegradeError(f"execution_task_payload_invalid:{exc}") from exc
    if task_payload.get("execution_contract_sha256") != EXECUTION_CONTRACT_SHA256:
        raise RegradeError("execution_contract_sha_mismatch")
    if task_payload.get("expected_artifact") != str(EXECUTION_EVIDENCE):
        raise RegradeError("execution_expected_artifact_mismatch")
    owner = task_payload.get("owner_decision") or {}
    if (
        owner.get("decision_id") != OWNER_DECISION_ID
        or owner.get("receipt_id") != OWNER_RECEIPT_ID
        or owner.get("receipt_sha256") != OWNER_RECEIPT_SHA256
    ):
        raise RegradeError("execution_owner_binding_mismatch")
    authority = task_payload.get("authority") or {}
    if authority.get("execution_authorized") is not True:
        raise RegradeError("execution_not_authorized")
    if any(
        authority.get(key) is not False
        for key in (
            "autotrading_authorized", "deployment_authorized",
            "factory_pause_authorized", "live_execution_authorized",
        )
    ):
        raise RegradeError("execution_boundary_broadened")
    return {
        "decision_contract_path": str(DECISION_CONFIG.resolve()),
        "decision_record_sha256": sha256_bytes(canonical_bytes(decision)),
        "decision_doc_path": str(DECISION_DOC.resolve()),
        "decision_doc_sha256": sha256_file(DECISION_DOC),
        "owner_receipts_path": str(OWNER_RECEIPTS.resolve()),
        "owner_receipt_record_sha256": sha256_bytes(canonical_bytes(receipt)),
        "owner_receipt_declared_sha256": OWNER_RECEIPT_SHA256,
        "execution_task_id": EXECUTION_TASK_ID,
        "execution_task_row_sha256": row_sha256(task),
        "execution_contract_sha256": EXECUTION_CONTRACT_SHA256,
    }


def _validate_authority_snapshot(conn: sqlite3.Connection, expected: Mapping[str, Any]) -> None:
    current = authority_snapshot(conn)
    if current != dict(expected):
        raise RegradeError("authority_snapshot_drift")


def _source_row(
    conn: sqlite3.Connection, source_id: str, ea_id: str, symbol: str,
) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
    if row is None:
        raise RegradeError(f"source_work_item_missing:{source_id}")
    taxonomy = str(row["verdict_taxonomy"] or row["verdict_taxonomy_stored"] or "").lower()
    if (
        row["ea_id"] != ea_id
        or row["symbol"] != symbol
        or str(row["phase"]).upper() != "Q08"
        or row["kind"] != "backtest"
        or row["status"] != "done"
        or row["verdict"] != "FAIL_HARD"
        or taxonomy != "strategy"
    ):
        raise RegradeError(f"source_work_item_prestate_mismatch:{source_id}")
    return row


def _snapshot_identity(
    path: Path, aggregate: Mapping[str, Any], storage: bytes, raw: bytes,
) -> dict[str, Any]:
    return {
        "path": str(path.resolve()),
        "storage": "gzip" if path.name.endswith(".gz") else "plain",
        "storage_sha256": sha256_bytes(storage),
        "json_bytes_sha256": sha256_bytes(raw),
        "verdict": aggregate.get("verdict"),
        "verdict_classification_sha256": sha256_bytes(
            canonical_bytes(aggregate.get("verdict_classification") or {})
        ),
    }


def _output_path(artifact_root: Path, work_item_id: str, ea_id: str, symbol: str) -> Path:
    symbol_slug = symbol.replace(".", "_")
    return artifact_root / "rows" / work_item_id / ea_id / "Q08" / symbol_slug / "aggregate.json"


def build_regrade_aggregate(
    source: Mapping[str, Any], *, target: Mapping[str, Any],
    authority: Mapping[str, Any], generated_at_utc: str,
) -> dict[str, Any]:
    result = copy.deepcopy(dict(source))
    decision = option_d_decision(result)
    if not decision.get("applied"):
        raise RegradeError(f"selected_snapshot_not_option_d:{target['source_work_item_id']}")
    if result.get("verdict") != "FAIL_HARD":
        raise RegradeError(f"selected_snapshot_not_fail_hard:{target['source_work_item_id']}")
    result["evidence_schema"] = "q08_aggregate/v2"
    result["verdict"] = "FAIL_SOFT"
    result["dl082_ext_option_d"] = True
    result["dl082_ext_option_d_reason_codes"] = decision["reason_codes"]
    result["dl082_ext_option_d_detail"] = decision
    calibration = copy.deepcopy(result.get("verdict_calibration") or {})
    calibration["DL082_EXT_OPTION_D_HARD_GATES"] = sorted(
        q08_aggregate.DL082_EXT_OPTION_D_HARD_GATES
    )
    calibration["DL082_EXT_OPTION_D_REQUIRED"] = {
        "cost_cushion_tier": ["PASS"],
        "8.2_dsr_mc_fdr": ["PASS"],
        "8.7_pbo": sorted(q08_aggregate.DL082_EXT_OPTION_D_PBO_LABELS),
        "8.8_edge_decay": ["PASS"],
        "non_target_edge_hard": [],
    }
    result["verdict_calibration"] = calibration
    source_generated = result.get("generated_at_utc")
    result["generated_at_utc"] = generated_at_utc
    result["dl082_ext_regrade"] = {
        "schema": RE_GRADE_SCHEMA,
        "append_only": True,
        "calibration_only": True,
        "mt5_rerun_performed": False,
        "historical_evidence_preserved": True,
        "historical_verdict_preserved": True,
        "source_work_item_id": target["source_work_item_id"],
        "source_work_item_row_sha256": target["source_work_item_row_sha256"],
        "source_snapshot": target["source_snapshot"],
        "source_generated_at_utc": source_generated,
        "regraded_at_utc": generated_at_utc,
        "new_work_item_id": target["new_work_item_id"],
        "owner_decision_id": OWNER_DECISION_ID,
        "owner_receipt_id": OWNER_RECEIPT_ID,
        "owner_receipt_declared_sha256": OWNER_RECEIPT_SHA256,
        "decision_record_sha256": authority["decision_record_sha256"],
        "decision_doc_sha256": authority["decision_doc_sha256"],
        "router_task_id": ROUTER_TASK_ID,
        "q09_eligibility": {
            "gate_contract_version": "v4",
            "source_phase": "Q08",
            "source_status": "done",
            "source_verdict": "FAIL_SOFT",
            "existing_admission_verdict": "FAIL_SOFT",
            "next_phase": "Q09",
            "enqueued": False,
        },
        "append_time_runnable_binding": target["runnable_binding"],
    }
    return result


def target_snapshot(
    conn: sqlite3.Connection, target: tuple[str, str, str, Path],
    *, artifact_root: Path, authority: Mapping[str, Any], generated_at_utc: str,
) -> dict[str, Any]:
    source_id, ea_id, symbol, snapshot_path = target
    row = _source_row(conn, source_id, ea_id, symbol)
    aggregate, storage, raw = read_json_snapshot(snapshot_path)
    if (
        normalize_ea(aggregate.get("ea_id")) != ea_id
        or str(aggregate.get("symbol") or "").upper() != symbol
        or str(aggregate.get("phase") or "").upper() != "Q08"
        or aggregate.get("verdict") != "FAIL_HARD"
    ):
        raise RegradeError(f"source_snapshot_identity_mismatch:{snapshot_path}")
    decision = option_d_decision(aggregate)
    if not decision.get("applied"):
        raise RegradeError(f"source_snapshot_not_option_d:{snapshot_path}")
    new_id = new_work_item_id(ea_id, symbol)
    if conn.execute("SELECT 1 FROM work_items WHERE id=?", (new_id,)).fetchone():
        raise RegradeError(f"regrade_row_already_exists:{new_id}")
    if conn.execute(
        """SELECT 1 FROM work_items
           WHERE json_valid(payload_json)=1
             AND json_extract(payload_json,'$.dl082_ext_regrade')=1
             AND ea_id=? AND symbol=? LIMIT 1""",
        (ea_id, symbol),
    ).fetchone():
        raise RegradeError(f"pair_already_regraded:{ea_id}:{symbol}")
    setfile = Path(str(row["setfile_path"])).resolve()
    binding = runnable_binding(setfile)
    period = _period_from_snapshot(aggregate, setfile)
    binding["period"] = period
    snapshot = {
        "source_work_item_id": source_id,
        "source_work_item_row_sha256": row_sha256(row),
        "ea_id": ea_id,
        "symbol": symbol,
        "source_snapshot": _snapshot_identity(snapshot_path, aggregate, storage, raw),
        "option_d_decision": decision,
        "setfile_path": str(setfile),
        "runnable_binding": binding,
        "new_work_item_id": new_id,
        "new_evidence_path": str(_output_path(artifact_root, new_id, ea_id, symbol).resolve()),
        "source_data_window_start": row["data_window_start"],
        "source_data_window_end": row["data_window_end"],
        "source_news_calendar_sha256": row["news_calendar_sha256"],
    }
    output = build_regrade_aggregate(
        aggregate, target=snapshot, authority=authority, generated_at_utc=generated_at_utc
    )
    snapshot["new_evidence_sha256"] = sha256_bytes(canonical_bytes(output))
    return snapshot


def _work_item_id_from_report_path(path: Path) -> str:
    try:
        directory = path.relative_to(Path(r"D:\QM\reports\work_items")).parts[0]
    except (ValueError, IndexError) as exc:
        raise RegradeError(f"unexpected_report_path:{path}") from exc
    return directory.split(".requeued_", 1)[0].split(".requeued", 1)[0]


def exclusion_snapshot(path: Path) -> dict[str, Any]:
    aggregate, storage, raw = read_json_snapshot(path)
    if aggregate.get("verdict") != "FAIL_HARD":
        raise RegradeError(f"excluded_snapshot_not_fail_hard:{path}")
    decision = option_d_decision(aggregate)
    if decision.get("applied"):
        raise RegradeError(f"excluded_snapshot_became_option_d:{path}")
    return {
        "source_work_item_id": _work_item_id_from_report_path(path),
        "ea_id": normalize_ea(aggregate.get("ea_id")),
        "symbol": str(aggregate.get("symbol") or ""),
        "snapshot": _snapshot_identity(path, aggregate, storage, raw),
        "option_d_decision": decision,
    }


def cohort_census() -> dict[str, Any]:
    root = Path(r"D:\QM\reports\work_items")
    paths = sorted(root.glob("*/*/Q08/*/aggregate.json"))
    paths.extend(sorted(root.glob("*/*/Q08/*/aggregate.json.gz")))
    verdict_counts: dict[str, int] = {}
    fail_hard_count = 0
    eligible_rows: list[dict[str, str]] = []
    multicause_paths: list[str] = []
    for path in paths:
        aggregate, _storage, _raw = read_json_snapshot(path)
        verdict = str(aggregate.get("verdict") or "")
        verdict_counts[verdict] = verdict_counts.get(verdict, 0) + 1
        if verdict != "FAIL_HARD":
            continue
        fail_hard_count += 1
        decision = option_d_decision(aggregate)
        if decision.get("applied"):
            eligible_rows.append({
                "path": str(path.resolve()),
                "ea_id": normalize_ea(aggregate.get("ea_id")),
                "symbol": str(aggregate.get("symbol") or ""),
            })
        if decision.get("non_target_hard_causes"):
            multicause_paths.append(str(path.resolve()))

    eligible_pairs = sorted({(row["ea_id"], row["symbol"]) for row in eligible_rows})
    expected_pairs = sorted((ea_id, symbol) for _source, ea_id, symbol, _path in TARGETS)
    expected_multicauses = sorted(str(path.resolve()) for path in MULTICAUSE_SNAPSHOTS)
    if len(paths) != 220:
        raise RegradeError(f"cohort_file_count:{len(paths)}")
    if verdict_counts != EXPECTED_CENSUS_VERDICTS:
        raise RegradeError(f"cohort_verdict_counts:{verdict_counts}")
    if fail_hard_count != 29:
        raise RegradeError(f"cohort_fail_hard_count:{fail_hard_count}")
    if len(eligible_rows) != 15 or eligible_pairs != expected_pairs:
        raise RegradeError(
            f"cohort_option_d_scope:rows={len(eligible_rows)}:pairs={eligible_pairs}"
        )
    if sorted(multicause_paths) != expected_multicauses:
        raise RegradeError(f"cohort_multicause_scope:{multicause_paths}")
    return {
        "aggregate_file_count": len(paths),
        "verdict_counts": verdict_counts,
        "fail_hard_count": fail_hard_count,
        "option_d_qualifying_snapshot_count": len(eligible_rows),
        "option_d_unique_pair_count": len(eligible_pairs),
        "option_d_unique_pairs": [list(pair) for pair in eligible_pairs],
        "multicause_fail_hard_count": len(multicause_paths),
        "multicause_paths": multicause_paths,
        "census_sha256": sha256_bytes(canonical_bytes({
            "paths": [str(path.resolve()) for path in paths],
            "verdict_counts": verdict_counts,
            "eligible_rows": eligible_rows,
            "multicause_paths": multicause_paths,
        })),
    }


def _validate_excluded_work_item(
    conn: sqlite3.Connection, item: Mapping[str, Any],
) -> dict[str, Any]:
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (item["source_work_item_id"],)
    ).fetchone()
    if row is None:
        raise RegradeError(f"excluded_work_item_missing:{item['source_work_item_id']}")
    if (
        str(row["phase"]).upper() != "Q08"
        or row["status"] != "done"
        or row["verdict"] != "FAIL_HARD"
    ):
        raise RegradeError(f"excluded_work_item_not_terminal:{item['source_work_item_id']}")
    result = copy.deepcopy(dict(item))
    result["source_work_item_row_sha256"] = row_sha256(row)
    return result


def _phase_counts(conn: sqlite3.Connection) -> dict[str, int]:
    return {
        str(row["phase"]): int(row["n"])
        for row in conn.execute(
            "SELECT phase,COUNT(*) AS n FROM work_items GROUP BY phase ORDER BY phase"
        ).fetchall()
    }


def _q09_identity(conn: sqlite3.Connection) -> dict[str, Any]:
    rows = [
        str(row["id"])
        for row in conn.execute("SELECT id FROM work_items WHERE phase='Q09' ORDER BY id")
    ]
    return {"count": len(rows), "ids_sha256": sha256_bytes(canonical_bytes(rows))}


def build_plan(db: Path, artifact_root: Path) -> dict[str, Any]:
    if ACTIVE_GATE_CONTRACT_VERSION != "v4" or next_phase("Q08") != "Q09":
        raise RegradeError(
            f"q09_admission_topology_mismatch:{ACTIVE_GATE_CONTRACT_VERSION}:{next_phase('Q08')}"
        )
    if not hasattr(q08_aggregate, "_dl082_ext_option_d"):
        raise RegradeError("option_d_calibration_not_loaded")
    generated = utc_now()
    conn = connect(db, read_only=True)
    try:
        authority = authority_snapshot(conn)
        targets = [
            target_snapshot(
                conn, target, artifact_root=artifact_root,
                authority=authority, generated_at_utc=generated,
            )
            for target in TARGETS
        ]
        eur_source, eur_ea, eur_symbol, eur_path = EURGBP_EXCLUSION
        eur = exclusion_snapshot(eur_path)
        if (
            eur["source_work_item_id"] != eur_source
            or eur["ea_id"] != eur_ea
            or eur["symbol"] != eur_symbol
            or eur["option_d_decision"].get("inputs", {}).get("8.7_pbo") != "INVALID"
        ):
            raise RegradeError("eurgbp_exclusion_mismatch")
        eur = _validate_excluded_work_item(conn, eur)
        multicauses = [
            _validate_excluded_work_item(conn, exclusion_snapshot(path))
            for path in MULTICAUSE_SNAPSHOTS
        ]
        if any(not item["option_d_decision"].get("non_target_hard_causes") for item in multicauses):
            raise RegradeError("multicause_without_non_target_hard")
        phase_counts = _phase_counts(conn)
        q09 = _q09_identity(conn)
    finally:
        conn.close()
    census = cohort_census()
    target_pairs = [[row["ea_id"], row["symbol"]] for row in targets]
    if len(targets) != 13 or len({tuple(pair) for pair in target_pairs}) != 13:
        raise RegradeError("target_pair_count_not_13")
    target_manifest_sha = sha256_bytes(canonical_bytes([
        {
            "source_work_item_id": row["source_work_item_id"],
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "source_snapshot": row["source_snapshot"],
            "new_work_item_id": row["new_work_item_id"],
            "new_evidence_sha256": row["new_evidence_sha256"],
        }
        for row in targets
    ]))
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": generated,
        "database": str(db.resolve()),
        "artifact_root": str(artifact_root.resolve()),
        "router_task_id": ROUTER_TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "owner_receipt_id": OWNER_RECEIPT_ID,
        "authority": authority,
        "mutation": "APPEND_EXACTLY_13_Q08_FAIL_SOFT_REGRADES",
        "historical_work_item_updates": 0,
        "q09_rows_inserted": 0,
        "active_gate_contract_version": ACTIVE_GATE_CONTRACT_VERSION,
        "q08_next_phase": next_phase("Q08"),
        "q08_fail_soft_is_existing_admission": True,
        "cohort_census": census,
        "target_manifest_sha256": target_manifest_sha,
        "targets": targets,
        "eurgbp_exclusion": eur,
        "multicause_exclusions": multicauses,
        "phase_counts_before": phase_counts,
        "q09_identity_before": q09,
    }
    return plan


def _target_manifest_sha(targets: Iterable[Mapping[str, Any]]) -> str:
    return sha256_bytes(canonical_bytes([
        {
            "source_work_item_id": row["source_work_item_id"],
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "source_snapshot": row["source_snapshot"],
            "new_work_item_id": row["new_work_item_id"],
            "new_evidence_sha256": row["new_evidence_sha256"],
        }
        for row in targets
    ]))


def _validate_file_identity(identity: Mapping[str, Any]) -> dict[str, Any]:
    path = Path(str(identity["path"]))
    aggregate, storage, raw = read_json_snapshot(path)
    if sha256_bytes(storage) != identity.get("storage_sha256"):
        raise RegradeError(f"snapshot_storage_drift:{path}")
    if sha256_bytes(raw) != identity.get("json_bytes_sha256"):
        raise RegradeError(f"snapshot_json_drift:{path}")
    if aggregate.get("verdict") != identity.get("verdict"):
        raise RegradeError(f"snapshot_verdict_drift:{path}")
    if sha256_bytes(canonical_bytes(aggregate.get("verdict_classification") or {})) != identity.get(
        "verdict_classification_sha256"
    ):
        raise RegradeError(f"snapshot_classification_drift:{path}")
    return aggregate


def validate_plan(plan: Mapping[str, Any], db: Path) -> None:
    if (
        plan.get("schema") != PLAN_SCHEMA
        or plan.get("router_task_id") != ROUTER_TASK_ID
        or plan.get("owner_decision_id") != OWNER_DECISION_ID
        or plan.get("owner_receipt_id") != OWNER_RECEIPT_ID
    ):
        raise RegradeError("plan_authority_mismatch")
    if Path(str(plan.get("database"))).resolve() != db.resolve():
        raise RegradeError("plan_database_mismatch")
    if (
        ACTIVE_GATE_CONTRACT_VERSION != "v4"
        or next_phase("Q08") != "Q09"
        or plan.get("active_gate_contract_version") != "v4"
        or plan.get("q08_next_phase") != "Q09"
    ):
        raise RegradeError("plan_q09_topology_mismatch")
    targets = plan.get("targets") or []
    expected_scope = {(source, ea, symbol) for source, ea, symbol, _path in TARGETS}
    actual_scope = {
        (row.get("source_work_item_id"), row.get("ea_id"), row.get("symbol"))
        for row in targets
    }
    if len(targets) != 13 or actual_scope != expected_scope:
        raise RegradeError("plan_target_scope_mismatch")
    if _target_manifest_sha(targets) != plan.get("target_manifest_sha256"):
        raise RegradeError("plan_target_manifest_sha_mismatch")
    if len(plan.get("multicause_exclusions") or []) != 8:
        raise RegradeError("plan_multicause_count_mismatch")
    conn = connect(db, read_only=True)
    try:
        _validate_authority_snapshot(conn, plan.get("authority") or {})
        for target in targets:
            source = _source_row(
                conn, target["source_work_item_id"], target["ea_id"], target["symbol"]
            )
            if row_sha256(source) != target.get("source_work_item_row_sha256"):
                raise RegradeError(f"source_work_item_drift:{target['source_work_item_id']}")
            if conn.execute(
                "SELECT 1 FROM work_items WHERE id=?", (target["new_work_item_id"],)
            ).fetchone():
                raise RegradeError(f"regrade_row_already_exists:{target['new_work_item_id']}")
            source_aggregate = _validate_file_identity(target["source_snapshot"])
            decision = option_d_decision(source_aggregate)
            if not decision.get("applied") or decision != target.get("option_d_decision"):
                raise RegradeError(f"option_d_decision_drift:{target['source_work_item_id']}")
            binding = runnable_binding(Path(target["setfile_path"]))
            binding["period"] = _period_from_snapshot(
                source_aggregate, Path(target["setfile_path"])
            )
            if binding != target.get("runnable_binding"):
                raise RegradeError(f"runnable_binding_drift:{target['ea_id']}:{target['symbol']}")
        excluded = [plan.get("eurgbp_exclusion") or {}, *(plan.get("multicause_exclusions") or [])]
        for item in excluded:
            aggregate = _validate_file_identity(item["snapshot"])
            if option_d_decision(aggregate) != item.get("option_d_decision"):
                raise RegradeError(f"excluded_decision_drift:{item['snapshot']['path']}")
            row = conn.execute(
                "SELECT * FROM work_items WHERE id=?", (item["source_work_item_id"],)
            ).fetchone()
            if row is None or row_sha256(row) != item.get("source_work_item_row_sha256"):
                raise RegradeError(f"excluded_work_item_drift:{item['source_work_item_id']}")
    finally:
        conn.close()


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_dl082_ext_option_d_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination), timeout=30)
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def _reconstruct_outputs(plan: Mapping[str, Any]) -> list[dict[str, Any]]:
    outputs: list[dict[str, Any]] = []
    authority = plan["authority"]
    generated = str(plan["generated_at_utc"])
    for target in plan["targets"]:
        source = _validate_file_identity(target["source_snapshot"])
        aggregate = build_regrade_aggregate(
            source, target=target, authority=authority, generated_at_utc=generated
        )
        raw = canonical_bytes(aggregate)
        digest = sha256_bytes(raw)
        if digest != target["new_evidence_sha256"]:
            raise RegradeError(f"regrade_evidence_sha_drift:{target['new_work_item_id']}")
        outputs.append({"target": target, "aggregate": aggregate, "raw": raw, "sha256": digest})
    return outputs


def _row_payload(
    target: Mapping[str, Any], *, plan_sha256: str,
) -> dict[str, Any]:
    binding = target["runnable_binding"]
    return {
        "dl082_ext_regrade": True,
        "dl082_ext_regrade_schema": RE_GRADE_SCHEMA,
        "append_only": True,
        "calibration_only": True,
        "mt5_rerun_performed": False,
        "historical_evidence_preserved": True,
        "historical_verdict_preserved": True,
        "source_work_item_id": target["source_work_item_id"],
        "source_work_item_row_sha256": target["source_work_item_row_sha256"],
        "source_snapshot": target["source_snapshot"],
        "owner_decision_id": OWNER_DECISION_ID,
        "owner_receipt_id": OWNER_RECEIPT_ID,
        "owner_receipt_sha256": OWNER_RECEIPT_SHA256,
        "execution_task_id": EXECUTION_TASK_ID,
        "router_task_id": ROUTER_TASK_ID,
        "execution_evidence_path": str(EXECUTION_EVIDENCE.resolve()),
        "plan_sha256": plan_sha256,
        "phase": "Q08",
        "gate_contract_version": "v4",
        "verdict_reason": "DL082_EXT_OPTION_D_APPEND_ONLY_CALIBRATION_REGRADE",
        "verdict_taxonomy": "strategy",
        "evidence_provenance": "append_only_calibration_regrade",
        "expected_mq5_sha256": binding["mq5_sha256"],
        "expected_ex5_sha256": binding["ex5_sha256"],
        "expected_setfile_sha256": binding["setfile_sha256"],
        "expected_symbol": target["symbol"],
        "expected_period": binding["period"],
        "expected_expert": binding["expert"],
        "risk_fixed": binding["risk_fixed"],
        "risk_percent": binding["risk_percent"],
        "qm_news_stale_max_hours": binding["qm_news_stale_max_hours"],
        "q09_eligibility": {
            "active_contract": "v4",
            "existing_q08_admission_verdict": "FAIL_SOFT",
            "next_phase": "Q09",
            "eligible": True,
            "enqueued": False,
        },
    }


def apply_plan(
    *, db: Path, plan_path: Path, expected_plan_sha256: str,
    receipt_out: Path, backup_dir: Path, mutation_lock: Path,
) -> dict[str, Any]:
    expected_plan_sha256 = expected_plan_sha256.lower()
    if sha256_file(plan_path) != expected_plan_sha256:
        raise RegradeError("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan, db)
    outputs = _reconstruct_outputs(plan)
    for output in outputs:
        path = Path(output["target"]["new_evidence_path"])
        if write_exact(path, output["raw"]) != output["sha256"]:
            raise RegradeError(f"evidence_write_sha_mismatch:{path}")

    backup_path, backup_sha = backup_database(db, backup_dir)
    inserted: list[dict[str, Any]] = []
    source_hashes_after: dict[str, str] = {}
    phase_counts_before: dict[str, int] = {}
    phase_counts_after: dict[str, int] = {}
    q09_before: dict[str, Any] = {}
    q09_after: dict[str, Any] = {}
    quick_check = ""
    now = str(plan["generated_at_utc"])

    with FactoryMutationLock(mutation_lock, owner=f"dl082-option-d:{ROUTER_TASK_ID}"):
        conn = connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            _validate_authority_snapshot(conn, plan["authority"])
            phase_counts_before = _phase_counts(conn)
            q09_before = _q09_identity(conn)
            work_item_count_before = int(
                conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]
            )
            for output in outputs:
                target = output["target"]
                source = _source_row(
                    conn, target["source_work_item_id"], target["ea_id"], target["symbol"]
                )
                if row_sha256(source) != target["source_work_item_row_sha256"]:
                    raise RegradeError(f"live_source_drift:{target['source_work_item_id']}")
                _validate_file_identity(target["source_snapshot"])
                if sha256_file(Path(target["new_evidence_path"])) != target["new_evidence_sha256"]:
                    raise RegradeError(f"written_evidence_drift:{target['new_work_item_id']}")
                binding = target["runnable_binding"]
                payload = _row_payload(target, plan_sha256=expected_plan_sha256)
                conn.execute(
                    """INSERT INTO work_items(
                         id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                         parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                         verdict_taxonomy_stored,clean_status_stored,gate_contract_version,
                         ex5_sha256,setfile_sha256,mq5_sha256,include_closure_sha256,build_id,
                         data_window_start,data_window_end,news_calendar_sha256,
                         verdict_taxonomy,sh3_enforced)
                       VALUES(?,'backtest','Q08',?,?,?,'done','FAIL_SOFT',0,NULL,?,NULL,?,?,?,
                              'strategy','done','v4',?,?,?,NULL,NULL,?,?,?,'strategy',1)""",
                    (
                        target["new_work_item_id"], target["ea_id"], target["symbol"],
                        target["setfile_path"], target["new_evidence_path"],
                        json.dumps(payload, sort_keys=True), now, now,
                        binding["ex5_sha256"], binding["setfile_sha256"], binding["mq5_sha256"],
                        target["source_data_window_start"], target["source_data_window_end"],
                        target["source_news_calendar_sha256"],
                    ),
                )
                event_detail = {
                    "decision": OWNER_DECISION_ID,
                    "new_work_item_id": target["new_work_item_id"],
                    "source_work_item_id": target["source_work_item_id"],
                    "source_snapshot_sha256": target["source_snapshot"]["json_bytes_sha256"],
                    "new_evidence_sha256": target["new_evidence_sha256"],
                    "historical_verdict_preserved": True,
                    "q09_enqueued": False,
                }
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (
                        now, "work_item", target["new_work_item_id"],
                        "dl082_ext_option_d_q08_regraded", json.dumps(event_detail, sort_keys=True),
                    ),
                )

            new_ids = [target["new_work_item_id"] for target in plan["targets"]]
            placeholders = ",".join("?" for _ in new_ids)
            rows = conn.execute(
                "SELECT * FROM work_items WHERE id IN (" + placeholders + ") ORDER BY id",
                new_ids,
            ).fetchall()
            if len(rows) != 13:
                raise RegradeError(f"inserted_regrade_count:{len(rows)}")
            for row in rows:
                payload = json.loads(row["payload_json"])
                if (
                    row["phase"] != "Q08"
                    or row["status"] != "done"
                    or row["verdict"] != "FAIL_SOFT"
                    or row["gate_contract_version"] != "v4"
                    or row["verdict_taxonomy"] != "strategy"
                    or int(row["sh3_enforced"]) != 1
                    or payload.get("dl082_ext_regrade") is not True
                    or payload.get("q09_eligibility", {}).get("eligible") is not True
                    or payload.get("q09_eligibility", {}).get("enqueued") is not False
                ):
                    raise RegradeError(f"inserted_regrade_postcondition:{row['id']}")
                inserted.append({
                    "work_item_id": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "row_sha256": row_sha256(row),
                    "evidence_path": row["evidence_path"],
                    "evidence_sha256": sha256_file(Path(row["evidence_path"])),
                    "source_work_item_id": payload["source_work_item_id"],
                    "source_snapshot_sha256": payload["source_snapshot"]["json_bytes_sha256"],
                })

            for item in [*plan["targets"], plan["eurgbp_exclusion"], *plan["multicause_exclusions"]]:
                source_id = item["source_work_item_id"]
                source = conn.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
                expected = item["source_work_item_row_sha256"]
                actual = row_sha256(source) if source is not None else ""
                if actual != expected:
                    raise RegradeError(f"historical_source_mutated:{source_id}")
                source_hashes_after[source_id] = actual
                identity = item.get("source_snapshot") or item.get("snapshot")
                _validate_file_identity(identity)

            work_item_count_after = int(
                conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]
            )
            if work_item_count_after - work_item_count_before != 13:
                raise RegradeError(
                    f"work_item_delta:{work_item_count_before}:{work_item_count_after}"
                )
            phase_counts_after = _phase_counts(conn)
            expected_phase_counts = dict(phase_counts_before)
            expected_phase_counts["Q08"] = expected_phase_counts.get("Q08", 0) + 13
            if phase_counts_after != expected_phase_counts:
                raise RegradeError("non_q08_work_item_mutation_detected")
            q09_after = _q09_identity(conn)
            if q09_after != q09_before:
                raise RegradeError("q09_rows_changed")
            quick_check = str(conn.execute("PRAGMA quick_check").fetchone()[0])
            if quick_check != "ok":
                raise RegradeError(f"quick_check:{quick_check}")
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": now,
        "router_task_id": ROUTER_TASK_ID,
        "execution_task_id": EXECUTION_TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "owner_receipt_id": OWNER_RECEIPT_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected_plan_sha256,
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "inserted_regrades": inserted,
        "regrade_count": len(inserted),
        "historical_work_item_updates": 0,
        "historical_source_row_sha256_after": source_hashes_after,
        "eurgbp_terminal": True,
        "multicause_terminal_count": 8,
        "phase_counts_before": phase_counts_before,
        "phase_counts_after": phase_counts_after,
        "q09_identity_before": q09_before,
        "q09_identity_after": q09_after,
        "q09_rows_inserted": 0,
        "q09_eligibility_proof": {
            "active_contract": ACTIVE_GATE_CONTRACT_VERSION,
            "q08_next_phase": next_phase("Q08"),
            "existing_q08_admission_verdict": "FAIL_SOFT",
            "eligible_row_count": len(inserted),
        },
        "quick_check": quick_check,
    }
    raw_without_self = canonical_bytes(receipt)
    receipt["receipt_content_sha256"] = sha256_bytes(raw_without_self)
    receipt_raw = canonical_bytes(receipt)
    write_exact(receipt_out, receipt_raw)
    receipt["receipt_file_sha256"] = sha256_bytes(receipt_raw)
    return receipt


def verify_receipt(*, db: Path, receipt_path: Path) -> dict[str, Any]:
    receipt_file_sha = sha256_file(receipt_path)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
    if receipt.get("schema") != RECEIPT_SCHEMA or receipt.get("regrade_count") != 13:
        raise RegradeError("receipt_scope_mismatch")
    plan_path = Path(str(receipt.get("plan_path")))
    if sha256_file(plan_path) != receipt.get("plan_sha256"):
        raise RegradeError("receipt_plan_binding_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    if _target_manifest_sha(plan.get("targets") or []) != plan.get("target_manifest_sha256"):
        raise RegradeError("receipt_target_manifest_mismatch")
    inserted = receipt.get("inserted_regrades") or []
    if len(inserted) != 13 or len({row["work_item_id"] for row in inserted}) != 13:
        raise RegradeError("receipt_inserted_scope_mismatch")
    if (
        ACTIVE_GATE_CONTRACT_VERSION != "v4"
        or next_phase("Q08") != "Q09"
        or "FAIL_SOFT" not in farmctl._CASCADE_PASS_VERDICTS_BY_PREDECESSOR["Q08"]
    ):
        raise RegradeError("q09_existing_admission_not_active")

    conn = connect(db, read_only=True)
    try:
        _validate_authority_snapshot(conn, plan["authority"])
        verified_rows: list[dict[str, Any]] = []
        new_ids = [row["work_item_id"] for row in inserted]
        for expected in inserted:
            row = conn.execute(
                "SELECT * FROM work_items WHERE id=?", (expected["work_item_id"],)
            ).fetchone()
            if row is None or row_sha256(row) != expected["row_sha256"]:
                raise RegradeError(f"regrade_row_drift:{expected['work_item_id']}")
            payload = json.loads(row["payload_json"])
            if (
                row["phase"] != "Q08"
                or row["status"] != "done"
                or row["verdict"] != "FAIL_SOFT"
                or row["gate_contract_version"] != "v4"
                or payload.get("dl082_ext_regrade") is not True
            ):
                raise RegradeError(f"regrade_row_contract_failed:{row['id']}")
            evidence_path = Path(str(row["evidence_path"]))
            if sha256_file(evidence_path) != expected["evidence_sha256"]:
                raise RegradeError(f"regrade_evidence_drift:{row['id']}")
            aggregate, _storage, _raw = read_json_snapshot(evidence_path)
            if (
                aggregate.get("verdict") != "FAIL_SOFT"
                or aggregate.get("dl082_ext_option_d") is not True
                or not option_d_decision(aggregate).get("applied")
            ):
                raise RegradeError(f"regrade_evidence_contract_failed:{row['id']}")
            verified_rows.append({
                "work_item_id": row["id"], "ea_id": row["ea_id"],
                "symbol": row["symbol"], "row_sha256": expected["row_sha256"],
                "evidence_sha256": expected["evidence_sha256"],
            })

        placeholders = ",".join("?" for _ in new_ids)
        supersedes = int(conn.execute(
            "SELECT COUNT(*) FROM work_item_supersedes WHERE work_item_id IN (" + placeholders
            + ") OR superseded_by_work_item_id IN (" + placeholders + ")",
            [*new_ids, *new_ids],
        ).fetchone()[0])
        dependencies = int(conn.execute(
            "SELECT COUNT(*) FROM work_item_dependencies WHERE child_work_item_id IN ("
            + placeholders + ") OR parent_work_item_id IN (" + placeholders + ")",
            [*new_ids, *new_ids],
        ).fetchone()[0])
        promoted_q09 = int(conn.execute(
            """SELECT COUNT(*) FROM work_items
               WHERE phase='Q09' AND json_valid(payload_json)=1
                 AND json_extract(payload_json,'$.promoted_from_work_item') IN ("""
            + placeholders + ")",
            new_ids,
        ).fetchone()[0])
        if supersedes != 0 or dependencies != 0 or promoted_q09 != 0:
            raise RegradeError(
                f"unexpected_follow_on_edges:supersedes={supersedes}:dependencies={dependencies}:q09={promoted_q09}"
            )

        for source_id, expected_sha in receipt["historical_source_row_sha256_after"].items():
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
            if row is None or row_sha256(row) != expected_sha or row["verdict"] != "FAIL_HARD":
                raise RegradeError(f"historical_source_not_preserved:{source_id}")

        eur = plan["eurgbp_exclusion"]
        eur_aggregate = _validate_file_identity(eur["snapshot"])
        if (
            option_d_decision(eur_aggregate).get("applied")
            or eur_aggregate.get("verdict") != "FAIL_HARD"
            or (eur_aggregate.get("verdict_classification") or {}).get("8.7_pbo") != "INVALID"
        ):
            raise RegradeError("eurgbp_exclusion_not_preserved")
        for item in plan["multicause_exclusions"]:
            aggregate = _validate_file_identity(item["snapshot"])
            decision = option_d_decision(aggregate)
            if (
                aggregate.get("verdict") != "FAIL_HARD"
                or decision.get("applied")
                or not decision.get("non_target_hard_causes")
            ):
                raise RegradeError(f"multicause_exclusion_not_preserved:{item['snapshot']['path']}")
        quick_check = str(conn.execute("PRAGMA quick_check").fetchone()[0])
        if quick_check != "ok":
            raise RegradeError(f"quick_check:{quick_check}")
    finally:
        conn.close()
    return {
        "status": "ok",
        "mode": "verify",
        "receipt_path": str(receipt_path.resolve()),
        "receipt_file_sha256": receipt_file_sha,
        "verified_regrade_count": len(verified_rows),
        "verified_regrades": verified_rows,
        "historical_source_updates": 0,
        "eurgbp_terminal": True,
        "multicause_terminal_count": 8,
        "supersedes_edges": supersedes,
        "dependency_edges": dependencies,
        "q09_rows_promoted_from_regrades": promoted_q09,
        "q09_eligibility": {
            "active_contract": ACTIVE_GATE_CONTRACT_VERSION,
            "q08_next_phase": next_phase("Q08"),
            "existing_q08_admission_verdict": "FAIL_SOFT",
        },
        "quick_check": quick_check,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply", "verify"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    args = parser.parse_args()
    try:
        if args.mode == "plan":
            if args.plan_out is None:
                raise RegradeError("plan_out_required")
            plan = build_plan(args.db, args.artifact_root)
            raw = canonical_bytes(plan)
            plan_sha = write_exact(args.plan_out, raw)
            result = {
                "status": "ok",
                "mode": "plan",
                "pair_count": len(plan["targets"]),
                "plan_path": str(args.plan_out.resolve()),
                "plan_sha256": plan_sha,
                "cohort_census": plan["cohort_census"],
            }
        elif args.mode == "apply":
            if args.plan is None or not args.expected_plan_sha256 or args.receipt_out is None:
                raise RegradeError("apply_requires_plan_hash_and_receipt")
            result = apply_plan(
                db=args.db,
                plan_path=args.plan,
                expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out,
                backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock,
            )
            result = {"status": "ok", "mode": "apply", **result}
        else:
            if args.receipt is None:
                raise RegradeError("verify_requires_receipt")
            result = verify_receipt(db=args.db, receipt_path=args.receipt)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (
        RegradeError, OSError, sqlite3.Error, ValueError, KeyError, TypeError,
        json.JSONDecodeError,
    ) as exc:
        print(json.dumps({
            "status": "aborted",
            "reason": f"{type(exc).__name__}: {exc}",
        }, indent=2, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
