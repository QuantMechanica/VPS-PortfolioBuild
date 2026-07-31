#!/usr/bin/env python3
"""Record a path-anchored pre-action snapshot for an authorized manual kill.

This command is deliberately non-destructive.  It inspects the requested PID,
rejects identities outside the governed T1-T10 terminal/worker cohort (and all
T_Live identities), then appends one durable JSONL evidence record.  The
operator must cite the returned event ID in the operation's evidence document.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path
from typing import Any


DEFAULT_EVIDENCE_PATH = Path(r"D:\QM\reports\state\manual_process_kills.jsonl")
SCHEMA_VERSION = "qm.manual-process-kill-evidence/v1"
CANONICAL_WORKER_SCRIPT = r"C:\QM\repo\tools\strategy_farm\terminal_worker.py"
TERMINAL_PATH_RE = re.compile(r"(?i)^[A-Z]:\\QM\\mt5\\(T(?:[1-9]|10))\\")
WORKER_TERMINAL_RE = re.compile(
    r"(?i)(?:^|\s)--terminal\s+(T(?:[1-9]|10))(?=\s|$)"
)


class ManualKillEvidenceError(ValueError):
    """Raised when an observed process is not safe to record as a kill target."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def inspect_process(process_id: int) -> dict[str, Any]:
    """Read one Win32 process identity without changing process state."""

    powershell = shutil.which("powershell.exe") or shutil.which("pwsh.exe")
    if powershell is None:
        raise ManualKillEvidenceError("PowerShell is required for Win32 process inspection")
    script = rf"""
$targetProcessId = {process_id}
$row = Get-CimInstance Win32_Process -Filter "ProcessId=$targetProcessId" -ErrorAction Stop
if ($null -eq $row) {{ exit 3 }}
$createdAtUtc = $null
if ($null -ne $row.CreationDate) {{
    $createdAtUtc = ([datetime]$row.CreationDate).ToUniversalTime().ToString('o')
}}
[ordered]@{{
    process_id = [int]$row.ProcessId
    image_path = [string]$row.ExecutablePath
    command_line = [string]$row.CommandLine
    process_created_at_utc = $createdAtUtc
}} | ConvertTo-Json -Compress
"""
    result = subprocess.run(
        (powershell, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise ManualKillEvidenceError(
            f"process {process_id} could not be inspected (rc={result.returncode}): {detail}"
        )
    try:
        snapshot = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ManualKillEvidenceError("process inspection returned invalid JSON") from exc
    if int(snapshot.get("process_id") or 0) != process_id:
        raise ManualKillEvidenceError("process inspection PID mismatch")
    return snapshot


def validate_snapshot(snapshot: dict[str, Any], expected_type: str) -> dict[str, Any]:
    """Return normalized identity details or reject the target fail-closed."""

    process_id = int(snapshot.get("process_id") or 0)
    image_path = str(snapshot.get("image_path") or "").strip()
    command_line = str(snapshot.get("command_line") or "").strip()
    combined = f"{image_path}\n{command_line}"
    if process_id <= 0:
        raise ManualKillEvidenceError("process_id must be positive")
    if not image_path:
        raise ManualKillEvidenceError("observed executable path is empty")
    if "t_live" in combined.lower():
        raise ManualKillEvidenceError("T_Live identities are never valid manual kill targets")

    terminal: str | None = None
    path_anchored = False
    if expected_type == "terminal":
        match = TERMINAL_PATH_RE.match(image_path)
        if match is None or Path(image_path).name.lower() != "terminal64.exe":
            raise ManualKillEvidenceError(
                "terminal target must be terminal64.exe under C:\\QM\\mt5\\T1-T10"
            )
        terminal = match.group(1).upper()
        path_anchored = True
    elif expected_type == "worker":
        image_name = Path(image_path).name.lower()
        worker_match = WORKER_TERMINAL_RE.search(command_line)
        normalized_command = command_line.replace("/", "\\").lower()
        if image_name not in {"python.exe", "pythonw.exe"}:
            raise ManualKillEvidenceError("worker target must run under python.exe/pythonw.exe")
        if CANONICAL_WORKER_SCRIPT.lower() not in normalized_command:
            raise ManualKillEvidenceError("worker target is not the canonical terminal_worker.py")
        if worker_match is None:
            raise ManualKillEvidenceError("worker target lacks an exact --terminal T1-T10 binding")
        terminal = worker_match.group(1).upper()
        path_anchored = True
    else:  # argparse constrains this; retain a library-level fail-closed check.
        raise ManualKillEvidenceError(f"unsupported target type: {expected_type}")

    return {
        "process_id": process_id,
        "target_type": expected_type,
        "terminal": terminal,
        "image_path": image_path,
        "command_line": command_line,
        "process_created_at_utc": snapshot.get("process_created_at_utc"),
        "path_anchored": path_anchored,
        "t_live_excluded": True,
    }


def append_evidence(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )
    descriptor = os.open(path, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)
    try:
        written = os.write(descriptor, raw)
        if written != len(raw):
            raise OSError(f"short evidence write: {written}/{len(raw)} bytes")
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def record_manual_kill_intent(
    *,
    process_id: int,
    target_type: str,
    actor: str,
    reason: str,
    authority_ref: str,
    evidence_path: Path = DEFAULT_EVIDENCE_PATH,
    snapshot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    actor = actor.strip()
    reason = reason.strip()
    authority_ref = authority_ref.strip()
    if not actor:
        raise ManualKillEvidenceError("actor is required")
    if not reason:
        raise ManualKillEvidenceError("reason is required")
    if not authority_ref:
        raise ManualKillEvidenceError("authority_ref is required")

    observed = snapshot if snapshot is not None else inspect_process(process_id)
    target = validate_snapshot(observed, target_type)
    if target["process_id"] != process_id:
        raise ManualKillEvidenceError("requested and observed process IDs differ")

    record = {
        "schema_version": SCHEMA_VERSION,
        "event_id": str(uuid.uuid4()),
        "event_type": "manual_process_kill_pre_action",
        "recorded_at_utc": utc_now(),
        "actor": actor,
        "reason": reason,
        "authority_ref": authority_ref,
        "target": target,
        "recorder": {
            "evidence_path": str(evidence_path),
            "process_mutated": False,
            "next_step": "cite event_id in the operation evidence before any exact-identity stop",
        },
    }
    append_evidence(evidence_path, record)
    return record


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--target-type", choices=("terminal", "worker"), required=True)
    parser.add_argument("--actor", required=True)
    parser.add_argument("--reason", required=True)
    parser.add_argument("--authority-ref", required=True)
    parser.add_argument("--evidence-path", type=Path, default=DEFAULT_EVIDENCE_PATH)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        record = record_manual_kill_intent(
            process_id=args.pid,
            target_type=args.target_type,
            actor=args.actor,
            reason=args.reason,
            authority_ref=args.authority_ref,
            evidence_path=args.evidence_path,
        )
    except ManualKillEvidenceError as exc:
        print(f"REFUSED: {exc}")
        return 2
    print(json.dumps(record, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
