#!/usr/bin/env python3
"""Quarantine the uncontracted QM5_10834 WS30 transport from DEV2.

This is a create-only, recoverable reconciliation.  It accepts only the exact
98-file historical transport authenticated by its original provision receipt,
requires DEV2 idle and disabled, and atomically moves the two WS30 symbol
directories to a task-bound quarantine outside the terminal lane.  It never
deletes files, starts MT5, enables the account, or expands the signed lane
contract.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))

from tools.strategy_farm import warm_cell_runner as core


TASK_ID = "a413ae7d-75bc-43f4-93b0-4fa8f27732f8"
FLAG_NAME = "QM_ENABLE_DEV2_WS30_QUARANTINE"
AUTH_SCHEMA = "qm.dev2-ws30-quarantine-authorization/v1"
RECEIPT_SCHEMA = "qm.dev2-ws30-quarantine/v1"
SYMBOL = "WS30.DWX"
DEV2_ROOT = Path(r"D:\QM\mt5\DEV2")
CUSTOM_ROOT = DEV2_ROOT / "Bases" / "Custom"
REPORTS_DEV2_ROOT = Path(r"D:\QM\reports\dev2")
DEFAULT_QUARANTINE_ROOT = (
    REPORTS_DEV2_ROOT / "quarantine" / "a413ae7d_ws30_transport_2026-08-27"
)
PROVISION_RECEIPT = Path(
    r"D:\QM\reports\setup\tick-data-timezone\WS30.DWX_DEV2_TRANSPORT_001\provision_receipt.json"
)
DATA_RECEIPT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\data\WS30_DWX_201807_202512_DEV2_backtest_data_receipt.json"
)
PROVISIONER_RELATIVE = Path(
    "framework/EAs/QM5_10834_tv-nq-ict-ob/tools/candidate_analysis/"
    "provision_ws30_dev2_transport.py"
)
CONTRACT_RELATIVE = Path("framework/registry/dev2_lane_contract.json")
DEFAULT_EVIDENCE = (
    REPO_IMPORT_ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "a413ae7d_dev2_ws30_quarantine_2026-08-27.json"
)
EXPECTED_ALLOWED_SYMBOLS = {
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "GDAXI.DWX",
    "NDX.DWX",
    "USDJPY.DWX",
    "XAUUSD.DWX",
}


class ReconciliationRefused(RuntimeError):
    """A fail-closed reconciliation invariant was not satisfied."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ReconciliationRefused(message)


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ReconciliationRefused(f"expected JSON object: {path}")
    return value


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _assert_no_reparse(path: Path) -> None:
    resolved = path.resolve()
    current = resolved
    while True:
        if current.exists():
            info = current.lstat()
            attributes = int(getattr(info, "st_file_attributes", 0))
            reparse = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
            if current.is_symlink() or attributes & reparse:
                raise ReconciliationRefused(f"reparse component refused: {current}")
        if current.parent == current:
            break
        current = current.parent


def _canonical_sha256(value: Any) -> str:
    encoded = json.dumps(
        value, ensure_ascii=True, sort_keys=True, separators=(",", ":")
    ).encode("ascii")
    return hashlib.sha256(encoded).hexdigest()


def _binding(path: Path) -> dict[str, Any]:
    path = path.resolve()
    _require(path.is_file(), f"required file missing: {path}")
    info = path.stat()
    _require(info.st_nlink == 1, f"hard-linked file refused: {path}")
    return {
        "path": str(path),
        "size": info.st_size,
        "sha256": core.sha256_file(path),
        "creation_time_ns": info.st_ctime_ns,
        "last_write_time_ns": info.st_mtime_ns,
    }


def _git(repo_root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if completed.returncode != 0:
        raise ReconciliationRefused(
            f"git command failed: {' '.join(args)}: {completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def _symbol_dirs(custom_root: Path) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for kind in ("history", "ticks"):
        root = custom_root / kind
        _require(root.is_dir(), f"custom {kind} root missing")
        result[kind] = sorted(
            (path.name for path in root.iterdir() if path.is_dir()),
            key=str.casefold,
        )
    return result


def _validate_authorization(
    path: Path, *, quarantine_root: Path, repo_root: Path
) -> dict[str, Any]:
    _require(os.environ.get(FLAG_NAME) == "1", f"{FLAG_NAME}=1 required")
    manifest = _load_json(path)
    expected = {
        "schema": AUTH_SCHEMA,
        "task_id": TASK_ID,
        "operation": "QUARANTINE_UNCONTRACTED_CUSTOM_HISTORY",
        "lane": "DEV2",
        "symbol": SYMBOL,
        "allow_delete": False,
        "allow_contract_expansion": False,
        "allow_terminal_start": False,
        "allow_account_enable": False,
        "factory_terminals_allowed": False,
        "live_allowed": False,
    }
    failed = [name for name, value in expected.items() if manifest.get(name) != value]
    _require(not failed, f"authorization mismatch: {failed}")
    _require(Path(str(manifest["source_custom_root"])).resolve() == CUSTOM_ROOT.resolve(), "authorization source root drift")
    _require(Path(str(manifest["quarantine_root"])).resolve() == quarantine_root, "authorization quarantine root drift")
    _require(Path(str(manifest["provision_receipt"])).resolve() == PROVISION_RECEIPT.resolve(), "authorization provision receipt drift")
    _require(repo_root == REPO_IMPORT_ROOT.resolve(), "reconciliation must use canonical checkout")
    return manifest


def _expected_inventory(
    provision: Mapping[str, Any], *, custom_root: Path
) -> tuple[list[dict[str, Any]], dict[Path, dict[str, Any]]]:
    rows = provision.get("files")
    _require(isinstance(rows, list) and len(rows) == 98, "provision inventory must contain 98 files")
    basis: list[dict[str, Any]] = []
    by_path: dict[Path, dict[str, Any]] = {}
    for row in rows:
        kind = str(row.get("kind") or "")
        period = str(row.get("period") or "")
        target = row.get("target") or {}
        suffix = ".hcc" if kind == "history" else ".tkc" if kind == "ticks" else ""
        _require(bool(suffix), f"unexpected provision kind: {kind}")
        expected_path = (custom_root / kind / SYMBOL / f"{period}{suffix}").resolve()
        actual_path = Path(str(target.get("path") or "")).resolve()
        _require(actual_path == expected_path, f"provision target path drift: {actual_path}")
        expected = {
            "kind": kind,
            "period": period,
            "size": int(target.get("size") or -1),
            "sha256": str(target.get("sha256") or "").lower(),
        }
        basis.append(expected)
        by_path[actual_path] = expected
    return basis, by_path


def _authenticate_inventory(
    expected_by_path: Mapping[Path, Mapping[str, Any]], *, root: Path
) -> dict[str, Any]:
    actual_paths = {
        path.resolve()
        for kind in ("history", "ticks")
        for path in (root / kind / SYMBOL).rglob("*")
        if path.is_file()
    }
    expected_paths = set(expected_by_path)
    _require(actual_paths == expected_paths, "WS30 physical file set drift")
    rows: list[dict[str, Any]] = []
    for path, expected in expected_by_path.items():
        binding = _binding(path)
        _require(
            binding["size"] == expected["size"]
            and binding["sha256"] == expected["sha256"],
            f"WS30 byte drift: {path}",
        )
        rows.append({**dict(expected), **binding})
    basis = [
        {
            "kind": row["kind"],
            "period": row["period"],
            "size": row["size"],
            "sha256": row["sha256"],
        }
        for row in rows
    ]
    return {
        "file_count": len(rows),
        "total_bytes": sum(int(row["size"]) for row in rows),
        "file_set_sha256": _canonical_sha256(basis),
        "files": rows,
    }


def _quarantine_expected_paths(
    expected: Mapping[Path, Mapping[str, Any]], quarantine_root: Path
) -> dict[Path, dict[str, Any]]:
    result: dict[Path, dict[str, Any]] = {}
    for source, row in expected.items():
        relative = source.relative_to(CUSTOM_ROOT.resolve())
        result[(quarantine_root / "Bases" / "Custom" / relative).resolve()] = dict(row)
    return result


def execute(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = args.repo_root.resolve()
    quarantine_root = args.quarantine_root.resolve()
    evidence_path = args.evidence_path.resolve()
    authorization = _validate_authorization(
        args.authorization_manifest.resolve(),
        quarantine_root=quarantine_root,
        repo_root=repo_root,
    )
    _require(_git(repo_root, "branch", "--show-current") == "agents/board-advisor", "canonical checkout is not agents/board-advisor")
    _require(_within(quarantine_root, REPORTS_DEV2_ROOT), "quarantine escaped DEV2 reports root")
    _require(quarantine_root != REPORTS_DEV2_ROOT.resolve(), "quarantine root is too broad")
    _require(quarantine_root.drive.casefold() == CUSTOM_ROOT.resolve().drive.casefold(), "quarantine must stay on the DEV2 volume")
    _require(not quarantine_root.exists(), "create-only quarantine root exists")
    _require(evidence_path == DEFAULT_EVIDENCE.resolve(), "evidence path is not canonical")
    _require(not evidence_path.exists(), "create-only evidence path exists")
    _assert_no_reparse(CUSTOM_ROOT)
    _assert_no_reparse(REPORTS_DEV2_ROOT)

    lane_before = core._dev2_lane_state()
    _require(int(lane_before.get("process_count") or 0) == 0, "DEV2 is not idle")
    _require(lane_before.get("account_enabled") is False, "QMDev2 account is enabled")
    _require(lane_before.get("password_required") is True, "QMDev2 password contract drift")

    contract_path = repo_root / CONTRACT_RELATIVE
    contract = _load_json(contract_path)
    contract_hash = core.sha256_file(contract_path)
    _require(contract_hash == str(authorization["lane_contract_sha256"]).lower(), "lane contract hash drift")
    allowed = {str(value) for value in contract.get("allowed_symbols") or []}
    _require(allowed == EXPECTED_ALLOWED_SYMBOLS, "DEV2 allowlist drift")
    _require(SYMBOL not in allowed, "WS30 is now contract-approved; quarantine refused")

    provision_hash = core.sha256_file(PROVISION_RECEIPT)
    _require(provision_hash == str(authorization["provision_receipt_sha256"]).lower(), "provision receipt hash drift")
    provision = _load_json(PROVISION_RECEIPT)
    _require(provision.get("status") == "PASS", "provision receipt is not PASS")
    _require(provision.get("artifact_type") == "QM5_10834_WS30_DEV2_PROVISION_RECEIPT", "provision receipt type drift")
    _require(provision.get("source_terminal") == "T1" and provision.get("target_terminal") == "DEV2", "provision lane provenance drift")
    _require(provision.get("symbol") == SYMBOL, "provision symbol drift")
    _require(int(provision.get("file_count") or 0) == int(authorization["expected_file_count"]), "authorized file count drift")
    _require(str(provision.get("target_file_set_sha256") or "").lower() == str(authorization["expected_file_set_sha256"]).lower(), "authorized file-set hash drift")
    basis, expected = _expected_inventory(provision, custom_root=CUSTOM_ROOT)
    _require(_canonical_sha256(basis) == provision["target_file_set_sha256"], "provision canonical file-set hash invalid")

    before_dirs = _symbol_dirs(CUSTOM_ROOT)
    expected_before = sorted(allowed | {SYMBOL}, key=str.casefold)
    _require(all(before_dirs[kind] == expected_before for kind in ("history", "ticks")), "DEV2 physical symbol set has drift beyond WS30")
    before_inventory = _authenticate_inventory(expected, root=CUSTOM_ROOT)

    source_history = (CUSTOM_ROOT / "history" / SYMBOL).resolve()
    source_ticks = (CUSTOM_ROOT / "ticks" / SYMBOL).resolve()
    _require(_within(source_history, CUSTOM_ROOT) and _within(source_ticks, CUSTOM_ROOT), "source path escaped DEV2 Custom root")
    _require(source_history.is_dir() and source_ticks.is_dir(), "WS30 source directories missing")
    destination_custom = quarantine_root / "Bases" / "Custom"
    destination_history = destination_custom / "history" / SYMBOL
    destination_ticks = destination_custom / "ticks" / SYMBOL

    quarantine_root.parent.mkdir(parents=True, exist_ok=True)
    _assert_no_reparse(quarantine_root.parent)
    quarantine_root.mkdir(exist_ok=False)
    destination_history.parent.mkdir(parents=True, exist_ok=False)
    destination_ticks.parent.mkdir(parents=True, exist_ok=False)
    moved: list[tuple[Path, Path]] = []
    try:
        os.replace(source_history, destination_history)
        moved.append((source_history, destination_history))
        os.replace(source_ticks, destination_ticks)
        moved.append((source_ticks, destination_ticks))
        _require(not source_history.exists() and not source_ticks.exists(), "WS30 remained in DEV2 after move")
        quarantine_expected = _quarantine_expected_paths(expected, quarantine_root)
        after_inventory = _authenticate_inventory(
            quarantine_expected, root=destination_custom
        )
        _require(
            before_inventory["file_set_sha256"] == after_inventory["file_set_sha256"]
            and before_inventory["total_bytes"] == after_inventory["total_bytes"],
            "quarantine inventory changed during move",
        )
        after_dirs = _symbol_dirs(CUSTOM_ROOT)
        expected_after = sorted(allowed, key=str.casefold)
        _require(all(after_dirs[kind] == expected_after for kind in ("history", "ticks")), "DEV2 physical symbol set does not match contract after move")
    except Exception:
        for source, destination in reversed(moved):
            if destination.exists() and not source.exists():
                os.replace(destination, source)
        raise

    lane_after = core._dev2_lane_state()
    _require(int(lane_after.get("process_count") or 0) == 0, "DEV2 process appeared during quarantine")
    _require(lane_after.get("account_enabled") is False, "QMDev2 account enabled during quarantine")
    _require(lane_after.get("password_required") is True, "QMDev2 password contract changed")

    provisioner = repo_root / PROVISIONER_RELATIVE
    data_receipt_binding = _binding(DATA_RECEIPT)
    receipt = {
        "schema": RECEIPT_SCHEMA,
        "task_id": TASK_ID,
        "completed_utc": core.utc_now(),
        "status": "PASS_QUARANTINED_RECOVERABLE",
        "decision": {
            "reason": "QM5_10834 offline WS30 transport is outside the signed six-symbol DEV2 lane contract",
            "contract_expanded": False,
            "files_deleted": 0,
            "recoverable": True,
        },
        "authorization": {
            "path": str(args.authorization_manifest.resolve()),
            "sha256": core.sha256_file(args.authorization_manifest),
            "manifest": authorization,
            "feature_flag": FLAG_NAME,
            "feature_flag_process_value": os.environ.get(FLAG_NAME),
        },
        "provenance": {
            "provision_receipt": _binding(PROVISION_RECEIPT),
            "provision_completed_utc": provision.get("completed_utc"),
            "source_terminal_at_transport": provision.get("source_terminal"),
            "target_terminal_at_transport": provision.get("target_terminal"),
            "source_target_sha256_equal": provision.get("source_target_sha256_equal"),
            "provisioner": _binding(provisioner),
            "provisioner_git_commit": "e183104e448c7771562e0064cf3287d2ba5578b1",
            "data_receipt": data_receipt_binding,
            "data_receipt_created_utc": _load_json(DATA_RECEIPT).get("created_utc"),
            "prior_v4a_handoff": str((repo_root / "docs/ops/evidence/2cb9d160_v4a_phase3_handoff_2026-08-27.md").resolve()),
        },
        "lane_contract": {
            "path": str(contract_path.resolve()),
            "sha256": contract_hash,
            "contract_id": contract.get("contract_id"),
            "allowed_symbols": sorted(allowed, key=str.casefold),
            "ws30_allowed": False,
        },
        "source": {
            "custom_root": str(CUSTOM_ROOT.resolve()),
            "history": str(source_history),
            "ticks": str(source_ticks),
            "symbol_directories_before": before_dirs,
            "symbol_directories_after": after_dirs,
            "absent_after": not source_history.exists() and not source_ticks.exists(),
        },
        "quarantine": {
            "root": str(quarantine_root),
            "history": str(destination_history.resolve()),
            "ticks": str(destination_ticks.resolve()),
            "inventory": after_inventory,
        },
        "pre_move_inventory": before_inventory,
        "inventory_preserved": before_inventory["file_set_sha256"] == after_inventory["file_set_sha256"],
        "lane_before": lane_before,
        "lane_after": lane_after,
        "safety": {
            "terminal_started": False,
            "account_enabled": False,
            "factory_terminals_touched": False,
            "live_touched": False,
            "auto_trading_touched": False,
            "contract_modified": False,
            "delete_used": False,
        },
    }
    text = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    quarantine_receipt = quarantine_root / "quarantine_receipt.json"
    core._atomic_text(quarantine_receipt, text)
    core._atomic_text(evidence_path, text)
    _require(core.sha256_file(quarantine_receipt) == core.sha256_file(evidence_path), "quarantine/canonical receipt copy mismatch")
    return {
        "status": receipt["status"],
        "file_count": after_inventory["file_count"],
        "total_bytes": after_inventory["total_bytes"],
        "file_set_sha256": after_inventory["file_set_sha256"],
        "quarantine_root": str(quarantine_root),
        "evidence": str(evidence_path),
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_IMPORT_ROOT)
    parser.add_argument("--authorization-manifest", type=Path, required=True)
    parser.add_argument("--quarantine-root", type=Path, default=DEFAULT_QUARANTINE_ROOT)
    parser.add_argument("--evidence-path", type=Path, default=DEFAULT_EVIDENCE)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        result = execute(parse_args(argv))
    except Exception as exc:
        print(json.dumps({"status": "REFUSED", "error": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
