"""Create and validate the governed non-admission DWX M1 overlap export."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sys
import uuid
from typing import Any, Mapping

REPO_ROOT = Path("C:/QM/repo")
sys.path.insert(0, str(REPO_ROOT))

try:
    from tools.dukascopy import common as dukascopy_common
    from tools.strategy_farm import custom_history_contract
    from tools.strategy_farm import custom_history_copy_on_claim
    from tools.strategy_farm import custom_history_gate
    from tools.strategy_farm import farmctl
except ModuleNotFoundError:
    from tools.dukascopy import common as dukascopy_common
    import custom_history_contract
    import custom_history_copy_on_claim
    import custom_history_gate
    import farmctl

EXPORT_WRAPPER = REPO_ROOT / "framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py"
EXPORT_SOURCE = REPO_ROOT / "framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5"
GOVERNANCE_GUARD = REPO_ROOT / "framework/scripts/mt5_diagnostics/dwx_tick_tail_probe.py"
SYMBOL_MATRIX = REPO_ROOT / "framework/registry/dwx_symbol_matrix.csv"
HISTORY_RANGES = REPO_ROOT / "docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv"
RECONCILE_OVERLAP = REPO_ROOT / "tools/dukascopy/reconcile_overlap.py"
PRICE_SCALE = Path("D:/QM/reports/dukascopy/splice/20260909_185632/price_scale.csv")
EXPORT_ROOT = Path("D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1")
OVERLAP_START_UTC = dt.datetime(2025, 10, 1, tzinfo=dt.timezone.utc)
OVERLAP_END_UTC = dt.datetime(2026, 4, 1, tzinfo=dt.timezone.utc)
OVERLAP_START_TEXT = "2025-10-01T00:00:00Z"
OVERLAP_END_TEXT = "2026-04-01T00:00:00Z"
OVERLAP_START_BROKER_EPOCH = dukascopy_common.broker_epoch_seconds_for_utc(
    OVERLAP_START_UTC
)
OVERLAP_END_BROKER_EPOCH = dukascopy_common.broker_epoch_seconds_for_utc(
    OVERLAP_END_UTC
)
M1_HEADER = ["time", "open", "high", "low", "close", "tickvol"]
SUMMARY_SCHEMA = "qm.dwx-m1-overlap-export-summary/v1"
EXPORT_MANIFEST_SCHEMA = "qm.dwx-m1-overlap-export-manifest/v1"
STAMP_RE = re.compile(r"^20\d{6}_\d{6}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
DISPATCH_BINDING_KEYS = (
    "authority_task_id",
    "diagnostic_allowed_terminals",
    "diagnostic_contract",
    "diagnostic_history_symbols",
    "diagnostic_non_admission",
    "diagnostic_queue_rank",
    "end_broker_epoch",
    "export_source_sha256",
    "export_stamp",
    "export_timeout_seconds",
    "export_wrapper_sha256",
    "governance_guard_sha256",
    "history_ranges_sha256",
    "manifest_path",
    "manifest_sha256",
    "no_gate_verdict",
    "output_dir",
    "overlap_end_utc",
    "overlap_start_utc",
    "period",
    "price_scale_path",
    "price_scale_sha256",
    "priority_track",
    "read_only",
    "reconcile_overlap_sha256",
    "start_broker_epoch",
    "symbol_matrix_sha256",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _canonical_sha256(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("ascii")
    return hashlib.sha256(encoded).hexdigest()


def dispatch_binding_body(payload: Mapping[str, Any]) -> dict[str, Any]:
    return {key: payload.get(key) for key in DISPATCH_BINDING_KEYS}


def load_symbols(path: Path = SYMBOL_MATRIX) -> list[str]:
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    symbols = sorted({str(row.get("symbol") or "").strip().upper() for row in rows})
    if (
        len(rows) != 37
        or len(symbols) != 37
        or any(not symbol.endswith(".DWX") for symbol in symbols)
        or symbols != sorted(dukascopy_common.CANONICAL_SYMBOLS)
    ):
        raise ValueError("DWX symbol matrix must contain the exact 37-symbol universe")
    return symbols


def _history_range_binding(symbols: list[str]) -> dict[str, Any]:
    with HISTORY_RANGES.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = [row for row in reader if str(row.get("period") or "").upper() == "M1"]
    by_symbol = {str(row["symbol"]).upper(): row for row in rows}
    if set(by_symbol) != set(symbols) or len(rows) != 37:
        raise ValueError("P0 history-range evidence lacks exact 37-symbol M1 coverage")
    if any("T1" not in str(by_symbol[symbol]["source_terminals"]).split(",") for symbol in symbols):
        raise ValueError("P0 history-range evidence does not authorize T1 for every symbol")
    if any(int(by_symbol[symbol]["first_year"]) > 2025 for symbol in symbols):
        raise ValueError("P0 history ranges do not reach the fixed overlap start")
    return {
        "path": str(HISTORY_RANGES),
        "sha256": sha256_file(HISTORY_RANGES),
        "m1_symbol_count": len(rows),
    }


def _price_scale_binding(path: Path | None = None) -> dict[str, Any]:
    resolved_path = PRICE_SCALE if path is None else Path(path)
    metadata = dukascopy_common.load_nonfx_instrument_metadata(resolved_path)
    return {
        "path": str(resolved_path.resolve()),
        "sha256": sha256_file(resolved_path),
        "symbol_count": len(metadata),
        "schema": dukascopy_common.NONFX_METADATA_HEADER,
    }


def validate_payload(
    payload: Mapping[str, Any],
    *,
    terminal: str = "T1",
    verify_files: bool = True,
) -> dict[str, Any]:
    symbols = [str(value).upper() for value in payload.get("diagnostic_history_symbols") or []]
    reasons: list[str] = []
    if payload.get("diagnostic_contract") != farmctl.DWX_M1_OVERLAP_EXPORT_CONTRACT:
        reasons.append("contract")
    if payload.get("diagnostic_non_admission") is not True:
        reasons.append("non_admission")
    if payload.get("diagnostic_allowed_terminals") != ["T1"] or terminal.upper() != "T1":
        reasons.append("terminal")
    try:
        expected_symbols = load_symbols()
    except (OSError, ValueError):
        expected_symbols = []
    if symbols != expected_symbols:
        reasons.append("symbols")
    if payload.get("period") != "M1":
        reasons.append("period")
    if not STAMP_RE.fullmatch(str(payload.get("export_stamp") or "")):
        reasons.append("stamp")
    try:
        uuid.UUID(str(payload.get("authority_task_id") or ""))
    except (TypeError, ValueError):
        reasons.append("authority")
    expected_output = (EXPORT_ROOT / str(payload.get("export_stamp") or "")).resolve()
    if Path(str(payload.get("output_dir") or "")).resolve() != expected_output:
        reasons.append("output_dir")
    manifest_path = Path(str(payload.get("manifest_path") or ""))
    if not manifest_path.is_absolute() or manifest_path.name != "archive_manifest_owner_approved.json":
        reasons.append("manifest_path")
    if Path(str(payload.get("price_scale_path") or "")).resolve() != PRICE_SCALE.resolve():
        reasons.append("price_scale_path")
    if (
        payload.get("overlap_start_utc") != OVERLAP_START_TEXT
        or payload.get("overlap_end_utc") != OVERLAP_END_TEXT
        or payload.get("start_broker_epoch") != OVERLAP_START_BROKER_EPOCH
        or payload.get("end_broker_epoch") != OVERLAP_END_BROKER_EPOCH
    ):
        reasons.append("fixed_window")
    if (
        payload.get("diagnostic_queue_rank") != 0
        or payload.get("priority_track") is not True
        or payload.get("no_gate_verdict") is not True
        or payload.get("read_only") is not True
    ):
        reasons.append("safety_flags")
    try:
        timeout_seconds = int(payload.get("export_timeout_seconds"))
    except (TypeError, ValueError):
        timeout_seconds = 0
    if not 300 <= timeout_seconds <= 3600:
        reasons.append("timeout")
    for key in (
        "export_source_sha256",
        "export_wrapper_sha256",
        "governance_guard_sha256",
        "symbol_matrix_sha256",
        "history_ranges_sha256",
        "reconcile_overlap_sha256",
        "price_scale_sha256",
        "manifest_sha256",
        "dispatch_binding_sha256",
    ):
        if not SHA_RE.fullmatch(str(payload.get(key) or "")):
            reasons.append(key)
    if payload.get("dispatch_binding_sha256") != _canonical_sha256(
        dispatch_binding_body(payload)
    ):
        reasons.append("dispatch_binding")
    if verify_files:
        expected_files = (
            (EXPORT_SOURCE, "export_source_sha256"),
            (EXPORT_WRAPPER, "export_wrapper_sha256"),
            (GOVERNANCE_GUARD, "governance_guard_sha256"),
            (SYMBOL_MATRIX, "symbol_matrix_sha256"),
            (HISTORY_RANGES, "history_ranges_sha256"),
            (RECONCILE_OVERLAP, "reconcile_overlap_sha256"),
            (PRICE_SCALE, "price_scale_sha256"),
        )
        for path, key in expected_files:
            if not path.is_file() or sha256_file(path) != payload.get(key):
                reasons.append(f"file:{key}")
        try:
            _price_scale_binding()
        except (OSError, TypeError, ValueError):
            reasons.append("price_scale_contract")
    if reasons:
        raise ValueError(
            "invalid DWX M1 overlap export payload: "
            + ",".join(sorted(set(reasons)))
        )
    return {"valid": True, "symbol_count": len(symbols), "terminal": "T1"}


def build_plan(root: Path, stamp: str, authority_task_id: str) -> dict[str, Any]:
    if not STAMP_RE.fullmatch(str(stamp)):
        raise ValueError("export stamp must use YYYYMMDD_HHMMSS")
    try:
        uuid.UUID(str(authority_task_id))
    except (TypeError, ValueError) as exc:
        raise ValueError("authority task id must be a UUID") from exc
    symbols = load_symbols()
    history = _history_range_binding(symbols)
    price_scale = _price_scale_binding()
    activation = custom_history_gate.load_activation(Path(root))
    if not activation or activation.get("enabled") is not True:
        raise ValueError("custom-history isolation activation is absent or disabled")
    manifest_path = Path(str(activation["manifest_path"]))
    manifest = custom_history_contract.load_manifest(
        manifest_path, require_owner_approval=True
    )
    custom_history_copy_on_claim.select_archive_rows_for_symbols(manifest, symbols)
    payload: dict[str, Any] = {
        "authority_task_id": str(authority_task_id),
        "diagnostic_allowed_terminals": ["T1"],
        "diagnostic_contract": farmctl.DWX_M1_OVERLAP_EXPORT_CONTRACT,
        "diagnostic_history_symbols": symbols,
        "diagnostic_non_admission": True,
        "diagnostic_queue_rank": 0,
        "end_broker_epoch": OVERLAP_END_BROKER_EPOCH,
        "export_source_sha256": sha256_file(EXPORT_SOURCE),
        "export_stamp": stamp,
        "export_timeout_seconds": 3600,
        "export_wrapper_sha256": sha256_file(EXPORT_WRAPPER),
        "governance_guard_sha256": sha256_file(GOVERNANCE_GUARD),
        "history_ranges_sha256": history["sha256"],
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest["manifest_sha256"],
        "no_gate_verdict": True,
        "output_dir": str((EXPORT_ROOT / stamp).resolve()),
        "overlap_end_utc": OVERLAP_END_TEXT,
        "overlap_start_utc": OVERLAP_START_TEXT,
        "period": "M1",
        "price_scale_path": price_scale["path"],
        "price_scale_sha256": price_scale["sha256"],
        "priority_track": True,
        "read_only": True,
        "reconcile_overlap_sha256": sha256_file(RECONCILE_OVERLAP),
        "start_broker_epoch": OVERLAP_START_BROKER_EPOCH,
        "symbol_matrix_sha256": sha256_file(SYMBOL_MATRIX),
    }
    payload.update(
        {
            "dispatch_binding_sha256": _canonical_sha256(
                dispatch_binding_body(payload)
            ),
            "history_range_binding": history,
            "price_scale_binding": price_scale,
        }
    )
    validate_payload(payload)
    return {
        "kind": farmctl.DIAGNOSTIC_WORK_ITEM_KIND,
        "phase": farmctl.DWX_M1_OVERLAP_EXPORT_PHASE,
        "ea_id": farmctl.DWX_M1_OVERLAP_EXPORT_EA_ID,
        "symbol": "DWX_UNIVERSE",
        "setfile_path": "",
        "payload": payload,
    }


def enqueue(
    root: Path,
    *,
    stamp: str,
    authority_task_id: str,
    apply: bool,
) -> dict[str, Any]:
    plan = build_plan(root, stamp, authority_task_id)
    result: dict[str, Any] = {"apply": bool(apply), "plan": plan, "enqueued": False}
    if not apply:
        return result
    farmctl.init_db(Path(root))
    now = farmctl.utc_now()
    item_id = str(uuid.uuid4())
    with farmctl.connect(Path(root)) as connection:
        connection.execute("BEGIN IMMEDIATE")
        existing = connection.execute(
            "SELECT id,status FROM work_items WHERE kind=? AND phase=? "
            "AND status IN ('pending','active') ORDER BY created_at LIMIT 1",
            (farmctl.DIAGNOSTIC_WORK_ITEM_KIND, farmctl.DWX_M1_OVERLAP_EXPORT_PHASE),
        ).fetchone()
        if existing is not None:
            connection.rollback()
            return {
                **result,
                "reason": "OPEN_Q00_DIAGNOSTIC_ALREADY_EXISTS",
                "existing": dict(existing),
            }
        connection.execute(
            "INSERT INTO work_items (id,kind,phase,ea_id,symbol,setfile_path,status,"
            "attempt_count,payload_json,created_at,updated_at,gate_contract_version) "
            "VALUES (?,?,?,?,?,?,'pending',0,?,?,?,?)",
            (
                item_id,
                plan["kind"],
                plan["phase"],
                plan["ea_id"],
                plan["symbol"],
                plan["setfile_path"],
                json.dumps(plan["payload"], sort_keys=True),
                now,
                now,
                farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            ),
        )
        connection.commit()
    result.update({"enqueued": True, "work_item_id": item_id})
    return result


def _validate_export_manifest(
    manifest_path: Path,
    payload: Mapping[str, Any],
    *,
    verify_files: bool,
) -> dict[str, Any]:
    value = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError("M1 export manifest must be an object")
    symbols = load_symbols()
    files = value.get("files")
    if (
        value.get("schema_version") != EXPORT_MANIFEST_SCHEMA
        or value.get("source_terminal") != "T1"
        or value.get("read_only") is not True
        or value.get("period") != "M1"
        or value.get("overlap_start_utc") != OVERLAP_START_TEXT
        or value.get("overlap_end_utc") != OVERLAP_END_TEXT
        or value.get("window_end_inclusive") is not True
        or value.get("schema") != M1_HEADER
        or value.get("symbols") != symbols
        or value.get("symbol_count") != 37
        or not isinstance(files, list)
        or len(files) != 37
    ):
        raise ValueError("M1 export manifest contract mismatch")
    if any(not isinstance(row, dict) for row in files):
        raise ValueError("M1 export manifest file bindings must be objects")
    by_symbol = {str(row.get("symbol") or "").upper(): row for row in files}
    if set(by_symbol) != set(symbols) or len(by_symbol) != 37:
        raise ValueError("M1 export manifest lacks exact 37-symbol coverage")
    expected_dir = (EXPORT_ROOT / str(payload.get("export_stamp") or "") / "dwx_m1").resolve()
    total_rows = 0
    for symbol in symbols:
        row = by_symbol[symbol]
        path = Path(str(row.get("path") or "")).resolve()
        if (
            path != expected_dir / f"{symbol}_M1.csv"
            or row.get("schema") != M1_HEADER
            or int(row.get("rows") or 0) <= 0
            or not SHA_RE.fullmatch(str(row.get("sha256") or ""))
        ):
            raise ValueError(f"invalid M1 export binding: {symbol}")
        total_rows += int(row["rows"])
        if verify_files and (not path.is_file() or sha256_file(path) != row["sha256"]):
            raise ValueError(f"M1 export file binding mismatch: {symbol}")
    if int(value.get("total_rows") or 0) != total_rows:
        raise ValueError("M1 export manifest total row count mismatch")
    price_scale = value.get("price_scale_csv") or {}
    if (
        Path(str(price_scale.get("path") or "")).resolve()
        != Path(str(payload.get("price_scale_path") or "")).resolve()
        or price_scale.get("sha256") != payload.get("price_scale_sha256")
        or price_scale.get("symbol_count") != 9
        or price_scale.get("schema") != dukascopy_common.NONFX_METADATA_HEADER
    ):
        raise ValueError("M1 export manifest price-scale binding mismatch")
    reconcile = value.get("reconcile_overlap") or {}
    if (
        Path(str(reconcile.get("path") or "")).resolve()
        != RECONCILE_OVERLAP.resolve()
        or reconcile.get("sha256") != payload.get("reconcile_overlap_sha256")
        or reconcile.get("reader") != "read_m1_csv"
    ):
        raise ValueError("M1 export manifest reconciliation binding mismatch")
    return {"symbols": len(symbols), "total_rows": total_rows}


def validate_summary(
    summary: Mapping[str, Any],
    payload: Mapping[str, Any],
    work_item_id: str,
    *,
    verify_files: bool = True,
) -> dict[str, Any]:
    reasons: list[str] = []
    if summary.get("schema_version") != SUMMARY_SCHEMA:
        reasons.append("schema")
    if not STAMP_RE.fullmatch(str(summary.get("run_tag") or "")):
        reasons.append("run_tag")
    if str(summary.get("work_item_id") or "") != str(work_item_id):
        reasons.append("work_item")
    if summary.get("export_stamp") != payload.get("export_stamp"):
        reasons.append("stamp")
    if summary.get("terminal") != "T1":
        reasons.append("terminal")
    if summary.get("status") != "PASS" or summary.get("verdict") != "REVIEW_REQUIRED":
        reasons.append("status")
    if summary.get("no_gate_verdict") is not True:
        reasons.append("gate_verdict")
    if summary.get("signed_archive_unchanged") is not True:
        reasons.append("archive")
    if summary.get("error") not in (None, ""):
        reasons.append("error")
    receipt_path = Path(str(summary.get("export_receipt_path") or ""))
    manifest_binding = summary.get("m1_export_manifest")
    manifest_path = (
        Path(str(manifest_binding.get("path") or ""))
        if isinstance(manifest_binding, dict)
        else Path()
    )
    if not SHA_RE.fullmatch(str(summary.get("export_receipt_sha256") or "")):
        reasons.append("receipt_binding")
    if (
        not isinstance(manifest_binding, dict)
        or manifest_binding.get("symbols") != 37
        or int(manifest_binding.get("total_rows") or 0) <= 0
        or manifest_binding.get("schema") != M1_HEADER
        or manifest_binding.get("overlap_start_utc") != OVERLAP_START_TEXT
        or manifest_binding.get("overlap_end_utc") != OVERLAP_END_TEXT
        or not SHA_RE.fullmatch(str(manifest_binding.get("sha256") or ""))
    ):
        reasons.append("manifest_binding")
    expected_dir = (EXPORT_ROOT / str(payload.get("export_stamp") or "")).resolve()
    try:
        if receipt_path.resolve() != expected_dir / "export_receipt.json":
            reasons.append("receipt_scope")
        if manifest_path.resolve() != expected_dir / "dwx_m1_manifest.json":
            reasons.append("manifest_scope")
    except OSError:
        reasons.append("output_scope")
    if verify_files:
        if (
            not receipt_path.is_file()
            or sha256_file(receipt_path) != summary.get("export_receipt_sha256")
        ):
            reasons.append("receipt")
        if (
            not isinstance(manifest_binding, dict)
            or not manifest_path.is_file()
            or sha256_file(manifest_path) != manifest_binding.get("sha256")
        ):
            reasons.append("manifest")
        else:
            try:
                checked = _validate_export_manifest(
                    manifest_path, payload, verify_files=True
                )
                if checked["total_rows"] != manifest_binding.get("total_rows"):
                    reasons.append("manifest_rows")
            except (OSError, TypeError, ValueError, json.JSONDecodeError):
                reasons.append("manifest_contract")
    if reasons:
        raise ValueError(
            "invalid DWX M1 overlap export summary: "
            + ",".join(sorted(set(reasons)))
        )
    return {
        "valid": True,
        "verdict": "REVIEW_REQUIRED",
        "evidence_path": str(receipt_path),
        "m1_export_manifest": str(manifest_path),
        "exports_dir": str(expected_dir / "dwx_m1"),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument(
        "--stamp",
        default=dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S"),
    )
    parser.add_argument("--authority-task-id", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    result = enqueue(
        args.root,
        stamp=args.stamp,
        authority_task_id=args.authority_task_id,
        apply=args.apply,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if (not args.apply or result.get("enqueued")) else 2


if __name__ == "__main__":
    raise SystemExit(main())
