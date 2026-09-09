"""Create and validate the governed non-admission DWX tick-tail work item."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import uuid
from typing import Any, Mapping

try:
    from tools.strategy_farm import custom_history_contract
    from tools.strategy_farm import custom_history_copy_on_claim
    from tools.strategy_farm import custom_history_gate
    from tools.strategy_farm import farmctl
except ModuleNotFoundError:
    import custom_history_contract
    import custom_history_copy_on_claim
    import custom_history_gate
    import farmctl


REPO_ROOT = Path("C:/QM/repo")
PROBE_WRAPPER = REPO_ROOT / "framework/scripts/mt5_diagnostics/dwx_tick_tail_probe.py"
PROBE_SOURCE = REPO_ROOT / "framework/scripts/mt5_diagnostics/QM_DWX_Tick_Tail_Probe.mq5"
SYMBOL_MATRIX = REPO_ROOT / "framework/registry/dwx_symbol_matrix.csv"
HISTORY_RANGES = REPO_ROOT / "docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv"
SPLICE_ROOT = Path("D:/QM/reports/dukascopy/splice")
SUMMARY_SCHEMA = "qm.dwx-tick-tail-probe-summary/v1"
STAMP_RE = re.compile(r"^20\d{6}_\d{6}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
DISPATCH_BINDING_KEYS = (
    "authority_task_id",
    "diagnostic_allowed_terminals",
    "diagnostic_contract",
    "diagnostic_history_symbols",
    "diagnostic_non_admission",
    "diagnostic_queue_rank",
    "history_ranges_sha256",
    "manifest_path",
    "manifest_sha256",
    "no_gate_verdict",
    "output_dir",
    "period",
    "priority_track",
    "probe_source_sha256",
    "probe_stamp",
    "probe_timeout_seconds",
    "probe_wrapper_sha256",
    "read_only",
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
    if len(rows) != 37 or len(symbols) != 37 or any(not symbol.endswith(".DWX") for symbol in symbols):
        raise ValueError("DWX symbol matrix must contain exactly 37 unique .DWX rows")
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
    return {
        "path": str(HISTORY_RANGES),
        "sha256": sha256_file(HISTORY_RANGES),
        "m1_symbol_count": len(rows),
        "first_years": sorted({int(row["first_year"]) for row in rows}),
        "last_years": sorted({int(row["last_year"]) for row in rows}),
    }


def validate_payload(
    payload: Mapping[str, Any],
    *,
    terminal: str = "T1",
    verify_files: bool = True,
) -> dict[str, Any]:
    symbols = [str(value).upper() for value in payload.get("diagnostic_history_symbols") or []]
    reasons: list[str] = []
    if payload.get("diagnostic_contract") != farmctl.DWX_TICK_TAIL_PROBE_CONTRACT:
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
    if not STAMP_RE.fullmatch(str(payload.get("probe_stamp") or "")):
        reasons.append("stamp")
    try:
        uuid.UUID(str(payload.get("authority_task_id") or ""))
    except ValueError:
        reasons.append("authority")
    expected_output = (
        SPLICE_ROOT / str(payload.get("probe_stamp") or "")
    ).resolve()
    if Path(str(payload.get("output_dir") or "")).resolve() != expected_output:
        reasons.append("output_dir")
    manifest_path = Path(str(payload.get("manifest_path") or ""))
    if not manifest_path.is_absolute() or manifest_path.name != "archive_manifest_owner_approved.json":
        reasons.append("manifest_path")
    if (
        payload.get("diagnostic_queue_rank") != 0
        or payload.get("priority_track") is not True
        or payload.get("no_gate_verdict") is not True
        or payload.get("read_only") is not True
    ):
        reasons.append("safety_flags")
    try:
        timeout_seconds = int(payload.get("probe_timeout_seconds"))
    except (TypeError, ValueError):
        timeout_seconds = 0
    if not 300 <= timeout_seconds <= 3600:
        reasons.append("timeout")
    for key in (
        "probe_source_sha256",
        "probe_wrapper_sha256",
        "symbol_matrix_sha256",
        "history_ranges_sha256",
        "manifest_sha256",
        "dispatch_binding_sha256",
    ):
        if not SHA_RE.fullmatch(str(payload.get(key) or "")):
            reasons.append(key)
    binding_body = dispatch_binding_body(payload)
    if payload.get("dispatch_binding_sha256") != _canonical_sha256(binding_body):
        reasons.append("dispatch_binding")
    if verify_files:
        expected_files = (
            (PROBE_SOURCE, "probe_source_sha256"),
            (PROBE_WRAPPER, "probe_wrapper_sha256"),
            (SYMBOL_MATRIX, "symbol_matrix_sha256"),
            (HISTORY_RANGES, "history_ranges_sha256"),
        )
        for path, key in expected_files:
            if not path.is_file() or sha256_file(path) != payload.get(key):
                reasons.append(f"file:{key}")
    if reasons:
        raise ValueError("invalid DWX tick-tail diagnostic payload: " + ",".join(sorted(set(reasons))))
    return {"valid": True, "symbol_count": len(symbols), "terminal": "T1"}


def build_plan(root: Path, stamp: str, authority_task_id: str) -> dict[str, Any]:
    if not STAMP_RE.fullmatch(str(stamp)):
        raise ValueError("probe stamp must use YYYYMMDD_HHMMSS")
    try:
        uuid.UUID(str(authority_task_id))
    except ValueError as exc:
        raise ValueError("authority task id must be a UUID") from exc
    symbols = load_symbols()
    history = _history_range_binding(symbols)
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
        "diagnostic_contract": farmctl.DWX_TICK_TAIL_PROBE_CONTRACT,
        "diagnostic_history_symbols": symbols,
        "diagnostic_non_admission": True,
        "diagnostic_queue_rank": 0,
        "history_ranges_sha256": history["sha256"],
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest["manifest_sha256"],
        "no_gate_verdict": True,
        "output_dir": str((SPLICE_ROOT / stamp).resolve()),
        "period": "M1",
        "priority_track": True,
        "probe_source_sha256": sha256_file(PROBE_SOURCE),
        "probe_stamp": stamp,
        "probe_timeout_seconds": 1800,
        "probe_wrapper_sha256": sha256_file(PROBE_WRAPPER),
        "read_only": True,
        "symbol_matrix_sha256": sha256_file(SYMBOL_MATRIX),
    }
    payload.update({
        "dispatch_binding_sha256": _canonical_sha256(dispatch_binding_body(payload)),
        "history_range_binding": history,
    })
    validate_payload(payload)
    return {
        "kind": farmctl.DIAGNOSTIC_WORK_ITEM_KIND,
        "phase": farmctl.DWX_TICK_TAIL_PROBE_PHASE,
        "ea_id": farmctl.DWX_TICK_TAIL_PROBE_EA_ID,
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
            (farmctl.DIAGNOSTIC_WORK_ITEM_KIND, farmctl.DWX_TICK_TAIL_PROBE_PHASE),
        ).fetchone()
        if existing is not None:
            connection.rollback()
            return {
                **result,
                "reason": "OPEN_PROBE_ALREADY_EXISTS",
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
    if summary.get("probe_stamp") != payload.get("probe_stamp"):
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
    receipt_path = Path(str(summary.get("probe_receipt_path") or ""))
    csv_binding = summary.get("tick_tail_csv")
    csv_path = Path(str(csv_binding.get("path") or "")) if isinstance(csv_binding, dict) else Path()
    price_binding = summary.get("price_scale_csv")
    price_path = Path(str(price_binding.get("path") or "")) if isinstance(price_binding, dict) else Path()
    expected_schema = [
        "symbol", "last_tick_time_msc", "last_tick_utc", "last_tick_bid",
        "last_tick_ask", "tick_count_last_day", "first_tick_time_msc",
        "source_terminal", "probe_sha256",
    ]
    if not SHA_RE.fullmatch(str(summary.get("probe_receipt_sha256") or "")):
        reasons.append("receipt_binding")
    if (
        not isinstance(csv_binding, dict)
        or csv_binding.get("rows") != 37
        or csv_binding.get("schema") != expected_schema
        or not SHA_RE.fullmatch(str(csv_binding.get("sha256") or ""))
    ):
        reasons.append("csv_binding")
    if (
        not isinstance(price_binding, dict)
        or price_binding.get("rows") != 9
        or price_binding.get("schema") != ["symbol", "digits", "point", "price_scale"]
        or price_binding.get("source_terminal") != "T1"
        or not SHA_RE.fullmatch(str(price_binding.get("sha256") or ""))
    ):
        reasons.append("price_scale_binding")
    expected_dir = (SPLICE_ROOT / str(payload.get("probe_stamp") or "")).resolve()
    try:
        if receipt_path.resolve() != expected_dir / "probe_receipt.json":
            reasons.append("receipt_scope")
        if csv_path.resolve() != expected_dir / "tick_tail.csv":
            reasons.append("csv_scope")
        if price_path.resolve() != expected_dir / "price_scale.csv":
            reasons.append("price_scale_scope")
    except OSError:
        reasons.append("output_scope")
    if verify_files:
        if not receipt_path.is_file() or sha256_file(receipt_path) != summary.get("probe_receipt_sha256"):
            reasons.append("receipt")
        if (
            not isinstance(csv_binding, dict)
            or not csv_path.is_file()
            or sha256_file(csv_path) != csv_binding.get("sha256")
        ):
            reasons.append("csv")
        if (
            not isinstance(price_binding, dict)
            or not price_path.is_file()
            or sha256_file(price_path) != price_binding.get("sha256")
        ):
            reasons.append("price_scale_csv")
    if reasons:
        raise ValueError("invalid DWX tick-tail summary: " + ",".join(sorted(set(reasons))))
    return {
        "valid": True,
        "verdict": "REVIEW_REQUIRED",
        "evidence_path": str(receipt_path),
        "tick_tail_csv": str(csv_path),
        "price_scale_csv": str(price_path),
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
