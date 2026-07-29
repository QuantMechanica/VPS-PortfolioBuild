#!/usr/bin/env python3
"""Reconcile phantom factory capacity in legacy ``dispatch_state.json``.

The command is read-only unless ``--apply`` is present.  Apply is allowed only
while FACTORY_OFF is hash-bound, no T1-T10 terminal process exists, the state
file still has the planned SHA-256, and a byte-for-byte backup target is fresh.
Unfinished dedup records are moved (not discarded) to ``dispatch_history``;
phase-matrix verdict evidence is byte-logically unchanged.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
STRATEGY_FARM_TOOLS = REPO_ROOT / "tools" / "strategy_farm"
if str(STRATEGY_FARM_TOOLS) not in sys.path:
    sys.path.insert(0, str(STRATEGY_FARM_TOOLS))

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag  # noqa: E402


DEFAULT_STATE = Path(r"D:\QM\reports\pipeline\dispatch_state.json")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
FACTORY_TERMINALS = {f"T{i}" for i in range(1, 11)}


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha256(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def detect_factory_terminal_processes() -> list[dict[str, Any]]:
    """Return T1-T10 terminal64 processes; T_Live is explicitly out of scope."""
    if os.name != "nt":
        return []
    script = (
        "$rows=Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
        "Select-Object ProcessId,ExecutablePath,CommandLine; "
        "$rows | ConvertTo-Json -Compress"
    )
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", script],
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"terminal process probe failed: {proc.stderr.strip()}")
    raw = proc.stdout.strip()
    if not raw:
        return []
    payload = json.loads(raw)
    rows = payload if isinstance(payload, list) else [payload]
    found: list[dict[str, Any]] = []
    for row in rows:
        path = str(row.get("ExecutablePath") or row.get("CommandLine") or "")
        normalized = path.replace("/", "\\").upper()
        terminal = next(
            (
                item
                for item in FACTORY_TERMINALS
                if f"\\MT5\\{item}\\" in normalized
                or f"\\MT5\\{item}_" in normalized
            ),
            None,
        )
        if terminal:
            found.append({
                "terminal": terminal,
                "pid": row.get("ProcessId"),
                "executable_path": row.get("ExecutablePath"),
                "command_line": row.get("CommandLine"),
            })
    return sorted(found, key=lambda item: (item["terminal"], int(item.get("pid") or 0)))


def load_state(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError("dispatch state must be a JSON object")
    return payload


def unfinished_dedup(state: dict[str, Any]) -> dict[str, dict[str, Any]]:
    dedup = state.get("dedup") or {}
    if not isinstance(dedup, dict):
        raise ValueError("dispatch_state.dedup must be an object")
    return {
        str(key): value
        for key, value in dedup.items()
        if isinstance(value, dict) and str(value.get("status") or "scheduled") != "complete"
    }


def build_plan(path: Path) -> dict[str, Any]:
    state = load_state(path)
    unfinished = unfinished_dedup(state)
    by_terminal: dict[str, int] = {}
    for record in unfinished.values():
        terminal = str(record.get("terminal") or "UNKNOWN")
        by_terminal[terminal] = by_terminal.get(terminal, 0) + 1
    running = state.get("running") or {}
    running_total = sum(int(value or 0) for value in running.values()) if isinstance(running, dict) else 0
    return {
        "mode": "dry_run",
        "state_path": str(path),
        "state_sha256": sha256_file(path),
        "phase_matrix_sha256": canonical_sha256(state.get("phase_matrix_index") or {}),
        "running_before": running,
        "running_total": running_total,
        "unfinished_count": len(unfinished),
        "unfinished_by_terminal": dict(sorted(by_terminal.items())),
        "capacity_counter_consistent": running_total == len(unfinished),
        "unfinished_keys": sorted(unfinished),
    }


def _write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, raw_tmp = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    tmp = Path(raw_tmp)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def apply_reconciliation(
    path: Path,
    *,
    expected_state_sha256: str,
    factory_off_flag: Path,
    expected_factory_off_sha256: str,
    backup_path: Path,
    reason: str,
    process_probe=detect_factory_terminal_processes,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    with FactoryMutationLock(lock_path, owner="reconcile_dispatch_state.apply"):
        actual_state_sha = sha256_file(path)
        if actual_state_sha.lower() != expected_state_sha256.strip().lower():
            raise RuntimeError(
                f"dispatch state SHA-256 mismatch: expected {expected_state_sha256}, actual {actual_state_sha}"
            )
        if not factory_off_flag.is_file():
            raise RuntimeError(f"FACTORY_OFF flag missing: {factory_off_flag}")
        actual_flag_sha = sha256_file(factory_off_flag)
        if actual_flag_sha.lower() != expected_factory_off_sha256.strip().lower():
            raise RuntimeError("FACTORY_OFF SHA-256 mismatch")
        processes = process_probe()
        if processes:
            raise RuntimeError(f"factory terminal processes still running: {processes}")
        if backup_path.exists():
            raise FileExistsError(f"backup target already exists: {backup_path}")

        state = load_state(path)
        before_phase_sha = canonical_sha256(state.get("phase_matrix_index") or {})
        unfinished = unfinished_dedup(state)
        reconciled_at = utc_now()
        history = state.setdefault("dispatch_history", {})
        if not isinstance(history, dict):
            raise ValueError("dispatch_state.dispatch_history must be an object")
        collisions = sorted(set(unfinished).intersection(history))
        if collisions:
            raise RuntimeError(f"dispatch_history key collision: {collisions[:5]}")

        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, backup_path)
        backup_sha = sha256_file(backup_path)
        if backup_sha != actual_state_sha:
            raise RuntimeError("byte-for-byte dispatch backup verification failed")

        dedup = state.setdefault("dedup", {})
        for key, record in unfinished.items():
            archived = dict(record)
            archived["status"] = "abandoned_factory_off"
            archived["abandoned_at"] = reconciled_at
            archived["abandon_reason"] = reason
            history[key] = archived
            del dedup[key]
        running_before = dict(state.get("running") or {})
        terminal_keys = set(running_before).union(FACTORY_TERMINALS)
        state["running"] = {key: 0 for key in sorted(terminal_keys, key=lambda x: (len(x), x))}
        receipt = {
            "reconciled_at": reconciled_at,
            "reason": reason,
            "pre_state_sha256": actual_state_sha,
            "factory_off_sha256": actual_flag_sha,
            "backup_path": str(backup_path),
            "backup_sha256": backup_sha,
            "unfinished_archived": len(unfinished),
            "running_before": running_before,
            "running_after": state["running"],
            "phase_matrix_sha256": before_phase_sha,
            "mutation_lock_path": str(lock_path),
        }
        receipts = state.setdefault("maintenance_reconciliations", [])
        if not isinstance(receipts, list):
            raise ValueError("dispatch_state.maintenance_reconciliations must be an array")
        receipts.append(receipt)
        _write_json_atomic(path, state)

        verified = load_state(path)
        after_phase_sha = canonical_sha256(verified.get("phase_matrix_index") or {})
        if after_phase_sha != before_phase_sha:
            raise RuntimeError("phase_matrix_index changed during capacity reconciliation")
        if any(int(value or 0) != 0 for value in (verified.get("running") or {}).values()):
            raise RuntimeError("running capacity counters were not fully cleared")
        return {
            "mode": "apply",
            **receipt,
            "post_state_sha256": sha256_file(path),
            "phase_matrix_sha256_after": after_phase_sha,
            "factory_processes": processes,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-state-sha256")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--backup-path", type=Path)
    parser.add_argument("--reason", default="intentional Factory-OFF maintenance reconciliation")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if not args.apply:
        result = build_plan(args.state)
    else:
        missing = [
            name
            for name, value in (
                ("--expected-state-sha256", args.expected_state_sha256),
                ("--expected-factory-off-sha256", args.expected_factory_off_sha256),
                ("--backup-path", args.backup_path),
            )
            if not value
        ]
        if missing:
            raise ValueError(f"apply requires {', '.join(missing)}")
        result = apply_reconciliation(
            args.state,
            expected_state_sha256=args.expected_state_sha256,
            factory_off_flag=args.factory_off_flag,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            backup_path=args.backup_path,
            reason=args.reason,
        )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        raise SystemExit(1)
