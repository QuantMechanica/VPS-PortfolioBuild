#!/usr/bin/env python3
"""Run one exact work item while the autonomous Factory remains OFF.

Dry-run is the default.  Apply is bound to the current FACTORY_OFF file, the
logical SQLite image, the exact pre-claim payload, and the worker script.  A
single global mutation lock remains held for snapshot, claim, tester run and
receipt publication, so Factory_ON and maintenance one-shots cannot overlap.

This controller never chooses queue work.  The requested row must carry an
active non-releasing maintenance hold and an explicit terminal identity.
T5 and T_Live are structurally forbidden.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag


DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_DB_REL = Path("state") / "farm_state.sqlite"
DEFAULT_REPO_ROOT = Path(r"C:\QM\repo")
DEFAULT_WORKER = Path(r"C:\QM\repo\tools\strategy_farm\terminal_worker.py")
DEFAULT_REPORTS_WORK_ITEMS = Path(r"D:\QM\reports\work_items")
DEFAULT_FILE_COMMON_Q08 = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"
)
ALLOWED_TERMINALS = frozenset({"T1", "T2", "T3", "T4", "T6", "T7", "T8", "T9", "T10"})


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def sqlite_state_sha256(db: Path) -> str:
    with connect_ro(db) as conn:
        return hashlib.sha256(conn.serialize()).hexdigest()


def sqlite_snapshot(source: Path, target: Path) -> str:
    if target.exists():
        raise FileExistsError(f"snapshot target already exists: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    src = sqlite3.connect(source, timeout=30)
    dst = sqlite3.connect(target)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return sha256_file(target)


def checkpoint_wal(db: Path) -> dict[str, int]:
    with sqlite3.connect(db, timeout=30, isolation_level=None) as conn:
        conn.execute("PRAGMA busy_timeout=30000")
        row = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    busy, log_frames, checkpointed = (int(value or 0) for value in row)
    if busy:
        raise RuntimeError("SQLite WAL checkpoint remained busy after isolated run")
    return {"busy": busy, "log_frames": log_frames, "checkpointed_frames": checkpointed}


def _artifact(path_value: Any, expected_sha: Any, role: str) -> dict[str, Any]:
    path = Path(str(path_value or ""))
    expected = str(expected_sha or "").strip().lower()
    result: dict[str, Any] = {"role": role, "path": str(path), "expected_sha256": expected}
    if not path.is_file():
        result.update({"valid": False, "reason": "missing"})
        return result
    actual = sha256_file(path)
    result.update({"actual_sha256": actual, "valid": bool(expected) and actual == expected})
    if not expected:
        result["reason"] = "expected_hash_missing"
    elif actual != expected:
        result["reason"] = "hash_mismatch"
    return result


def _line_count(path: Path) -> int:
    with path.open("rb") as handle:
        return sum(1 for _ in handle)


def _stream_fingerprint(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"exists": False}
    stat = path.stat()
    return {
        "exists": True,
        "sha256": sha256_file(path),
        "bytes": stat.st_size,
        "lines": _line_count(path),
        "mtime_ns": stat.st_mtime_ns,
    }


def _post_run_stream_plan(payload: dict[str, Any], work_item_id: str) -> dict[str, Any]:
    source_value = str(payload.get("post_run_file_common_source") or "").strip()
    if not source_value:
        return {"requested": False, "valid": True}

    source = Path(source_value)
    report_root = Path(str(payload.get("report_root") or ""))
    expected_report_root = DEFAULT_REPORTS_WORK_ITEMS / work_item_id
    target = report_root / f"q08_trades_{source.stem}.timer_v2.jsonl"
    errors: list[str] = []
    try:
        if source.resolve().parent != DEFAULT_FILE_COMMON_Q08.resolve():
            errors.append("post-run source is outside the governed FILE_COMMON q08_trades directory")
    except OSError as exc:
        errors.append(f"post-run source cannot be resolved: {exc}")
    if source.suffix.lower() != ".jsonl":
        errors.append("post-run source must be a JSONL file")
    try:
        if report_root.resolve() != expected_report_root.resolve():
            errors.append(
                "report_root must be the exact governed work-item evidence directory: "
                f"{expected_report_root}"
            )
    except OSError as exc:
        errors.append(f"report_root cannot be resolved: {exc}")
    if target.exists():
        errors.append(f"post-run evidence target already exists: {target}")

    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "source": str(source),
        "target": str(target),
        "pre_run_source": _stream_fingerprint(source),
        "pre_v2_capture": {
            "path": payload.get("pre_v2_file_common_capture_path"),
            "sha256": str(payload.get("pre_v2_file_common_capture_sha256") or "").lower(),
            "bytes": payload.get("pre_v2_file_common_capture_bytes"),
            "lines": payload.get("pre_v2_file_common_capture_lines"),
        },
    }


def _harvest_post_run_stream(
    contract: dict[str, Any], *, worker_started_wall_ns: int
) -> dict[str, Any]:
    """Atomically preserve a fresh FILE_COMMON stream before releasing the lock.

    A pre-existing unchanged file is never accepted: that would silently bind
    stale evidence to the isolated rerun.  Failures are returned as receipt
    data so a completed worker can still be forensically reconstructed.
    """
    if not contract.get("requested"):
        return {"requested": False, "valid": True}
    result: dict[str, Any] = {
        "requested": True,
        "valid": False,
        "source": contract.get("source"),
        "target": contract.get("target"),
        "pre_run_source": contract.get("pre_run_source"),
        "pre_v2_capture": contract.get("pre_v2_capture"),
    }
    try:
        if not contract.get("valid"):
            raise RuntimeError(f"invalid harvest contract: {contract.get('errors')}")
        source = Path(str(contract["source"]))
        target = Path(str(contract["target"]))
        post_source = _stream_fingerprint(source)
        result["post_run_source"] = post_source
        if not post_source.get("exists"):
            raise RuntimeError("post-run FILE_COMMON stream is missing")
        pre_source = contract.get("pre_run_source") or {}
        if int(post_source.get("mtime_ns") or 0) < worker_started_wall_ns - 2_000_000_000:
            raise RuntimeError("post-run FILE_COMMON stream predates the isolated worker")
        same_preflight_content = (
            pre_source.get("exists")
            and post_source.get("sha256") == pre_source.get("sha256")
        )
        same_preflight_mtime = (
            pre_source.get("exists")
            and int(post_source.get("mtime_ns") or 0) <= int(pre_source.get("mtime_ns") or 0)
        )
        if same_preflight_content and same_preflight_mtime:
            raise RuntimeError("post-run FILE_COMMON stream is unchanged from controller preflight")
        capture_sha = str((contract.get("pre_v2_capture") or {}).get("sha256") or "").lower()
        if capture_sha and post_source.get("sha256") == capture_sha:
            raise RuntimeError("post-run FILE_COMMON stream equals the pre-v2 capture")
        if target.exists():
            raise FileExistsError(f"post-run evidence target already exists: {target}")

        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(f"{target.name}.{os.getpid()}.tmp")
        try:
            with source.open("rb") as source_handle, tmp.open("xb") as target_handle:
                shutil.copyfileobj(source_handle, target_handle, length=1024 * 1024)
                target_handle.flush()
                os.fsync(target_handle.fileno())
            copied = _stream_fingerprint(tmp)
            if copied.get("sha256") != post_source.get("sha256"):
                raise RuntimeError("FILE_COMMON source changed during evidence copy")
            os.replace(tmp, target)
        finally:
            tmp.unlink(missing_ok=True)
        harvested = _stream_fingerprint(target)
        if harvested.get("sha256") != post_source.get("sha256"):
            raise RuntimeError("published evidence hash differs from FILE_COMMON source")
        result.update({
            "valid": True,
            "harvested": harvested,
            "content_identical_but_rewritten": bool(same_preflight_content),
        })
    except Exception as exc:
        result["error"] = str(exc)
    return result


def recover_harvest_from_receipt(
    root: Path,
    *,
    source_receipt_path: Path,
    expected_source_receipt_sha256: str,
    recovery_receipt_path: Path,
) -> dict[str, Any]:
    """Recover only the evidence copy from a completed isolated-run receipt.

    This path cannot rerun or mutate a work item.  It exists for a controller
    harvest false-negative and authenticates the exact original receipt, its
    post-run DB state, the unchanged Factory-OFF flag and a quiet tester fleet.
    """
    if not source_receipt_path.is_file():
        raise FileNotFoundError(f"source receipt missing: {source_receipt_path}")
    source_receipt_sha = sha256_file(source_receipt_path)
    _require_equal(
        "source receipt SHA-256", expected_source_receipt_sha256, source_receipt_sha
    )
    receipt = json.loads(source_receipt_path.read_text(encoding="utf-8"))
    post_item = receipt.get("post_work_item") or {}
    failed_harvest = receipt.get("post_run_stream") or {}
    if receipt.get("mode") != "apply" or int(receipt.get("worker_exit_code", -1)) != 0:
        raise RuntimeError("source receipt is not a completed worker execution")
    if post_item.get("status") != "done" or post_item.get("verdict") != "PASS":
        raise RuntimeError("source receipt does not bind a done/PASS work item")
    if not failed_harvest.get("requested") or failed_harvest.get("valid") is not False:
        raise RuntimeError("source receipt is not an eligible failed harvest")

    flag = root / "state" / "FACTORY_OFF.flag"
    db = root / DEFAULT_DB_REL
    lock_path = path_for_factory_flag(flag)
    with FactoryMutationLock(
        lock_path, owner=f"isolated_harvest_recovery:{post_item.get('id')}"
    ):
        _require_equal("FACTORY_OFF SHA-256", receipt["factory_off_sha256"], sha256_file(flag))
        _require_equal(
            "post-run logical DB state SHA-256",
            receipt["post_db_state_sha256"],
            sqlite_state_sha256(db),
        )
        processes = _factory_processes()
        if processes:
            raise RuntimeError(f"factory terminal/tester processes are present: {len(processes)}")
        started = dt.datetime.fromisoformat(str(receipt["started_at_utc"]))
        if started.tzinfo is None:
            raise RuntimeError("source receipt started_at_utc is not timezone-aware")
        started_ns = int(started.timestamp() * 1_000_000_000)
        contract = (receipt.get("preflight") or {}).get("post_run_stream") or {}
        harvest = _harvest_post_run_stream(
            contract, worker_started_wall_ns=started_ns
        )
        result = {
            "schema_version": 1,
            "mode": "harvest_recovery",
            "recovered_at_utc": utc_now(),
            "source_receipt_path": str(source_receipt_path),
            "source_receipt_sha256": source_receipt_sha,
            "controller_path": str(Path(__file__).resolve()),
            "controller_sha256": sha256_file(Path(__file__).resolve()),
            "work_item_id": post_item.get("id"),
            "factory_off_sha256": sha256_file(flag),
            "db_state_sha256": sqlite_state_sha256(db),
            "factory_processes": processes,
            "harvest": harvest,
            "live_scope_touched": False,
            "autotrading_touched": False,
        }
        _write_receipt(recovery_receipt_path, result)
        return result


def _factory_processes() -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    command = (
        "$rows=Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe' OR Name='metatester64.exe'\" "
        "| Select-Object Name,ProcessId,ExecutablePath,CommandLine; "
        "$rows | ConvertTo-Json -Compress"
    )
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"factory process probe failed: {proc.stderr.strip()}")
    raw = proc.stdout.strip()
    if not raw:
        return []
    parsed = json.loads(raw)
    rows = parsed if isinstance(parsed, list) else [parsed]
    found: list[dict[str, Any]] = []
    for row in rows:
        if str(row.get("Name") or "").lower() == "metatester64.exe":
            found.append(row)
            continue
        haystack = str(row.get("ExecutablePath") or row.get("CommandLine") or "")
        normalized = haystack.replace("/", "\\").upper()
        if any(f"\\MT5\\T{i}\\" in normalized or f"\\MT5\\T{i}_" in normalized for i in range(1, 11)):
            found.append(row)
    return found


def build_plan(
    root: Path,
    *,
    terminal: str,
    work_item_id: str,
    worker_script: Path,
    repo_root: Path = DEFAULT_REPO_ROOT,
) -> dict[str, Any]:
    terminal = terminal.upper()
    db = root / DEFAULT_DB_REL
    flag = root / "state" / "FACTORY_OFF.flag"
    errors: list[str] = []
    if terminal not in ALLOWED_TERMINALS:
        errors.append(f"terminal {terminal!r} is forbidden for isolated runs")
    if not flag.is_file():
        errors.append(f"FACTORY_OFF flag missing: {flag}")
    if not db.is_file():
        errors.append(f"farm DB missing: {db}")
    if not worker_script.is_file():
        errors.append(f"worker script missing: {worker_script}")
    if errors:
        return {"mode": "dry_run", "valid": False, "errors": errors}

    with connect_ro(db) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1",
            (work_item_id,),
        ).fetchone()
    if row is None:
        errors.append(f"work item missing: {work_item_id}")
        return {"mode": "dry_run", "valid": False, "errors": errors}

    payload_text = str(row["payload_json"] or "{}")
    try:
        payload = json.loads(payload_text)
    except ValueError:
        payload = {}
        errors.append("payload_json is invalid")
    if row["status"] != "pending" or row["claimed_by"] is not None:
        errors.append(f"work item is not pending/unclaimed: {row['status']}/{row['claimed_by']}")
    if hold is None:
        errors.append("active maintenance hold is required")
    elif int(hold["release_on_restart"] or 0) != 0:
        errors.append("isolated run requires a non-releasing hold")
    payload_terminal = str(payload.get("terminal") or "").upper()
    if payload_terminal != terminal:
        errors.append(f"payload terminal mismatch: expected {terminal}, actual {payload_terminal!r}")
    avoid = {str(value).upper() for value in (payload.get("avoid_terminals") or [])}
    if terminal in avoid:
        errors.append(f"terminal {terminal} is explicitly avoided")

    ea_dir_name = str(payload.get("ea_dir_name") or "")
    mq5_path = repo_root / "framework" / "EAs" / ea_dir_name / f"{ea_dir_name}.mq5"
    artifacts = [
        _artifact(row["setfile_path"], payload.get("expected_setfile_sha256"), "setfile"),
        _artifact(payload.get("staged_ex5_path"), payload.get("staged_ex5_sha256"), "staged_ex5"),
        _artifact(mq5_path, payload.get("expected_mq5_sha256"), "mq5"),
    ]
    errors.extend(
        f"{item['role']} artifact invalid: {item.get('reason', 'hash_mismatch')}"
        for item in artifacts
        if not item["valid"]
    )
    post_run_stream = _post_run_stream_plan(payload, work_item_id)
    errors.extend(post_run_stream.get("errors") or [])
    processes = _factory_processes()
    if processes:
        errors.append(f"factory terminal/tester processes are present: {len(processes)}")

    return {
        "mode": "dry_run",
        "valid": not errors,
        "errors": errors,
        "root": str(root),
        "db": str(db),
        "db_sha256": sha256_file(db),
        "db_state_sha256": sqlite_state_sha256(db),
        "factory_off_flag": str(flag),
        "factory_off_sha256": sha256_file(flag),
        "terminal": terminal,
        "work_item_id": work_item_id,
        "work_item": {
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "phase": row["phase"],
            "status": row["status"],
            "claimed_by": row["claimed_by"],
            "payload_sha256": sha256_text(payload_text),
        },
        "hold": dict(hold) if hold is not None else None,
        "artifacts": artifacts,
        "post_run_stream": post_run_stream,
        "worker_script": str(worker_script),
        "worker_sha256": sha256_file(worker_script),
        "factory_processes": processes,
    }


def _require_equal(label: str, expected: str, actual: str) -> None:
    if expected.strip().lower() != actual.strip().lower():
        raise RuntimeError(f"{label} mismatch: expected={expected} actual={actual}")


def _write_receipt(path: Path, payload: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(f"receipt target already exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def execute(
    root: Path,
    *,
    terminal: str,
    work_item_id: str,
    worker_script: Path,
    repo_root: Path,
    timeout_minutes: float,
    expected_factory_off_sha256: str,
    expected_db_state_sha256: str,
    expected_payload_sha256: str,
    expected_worker_sha256: str,
    snapshot_path: Path,
    receipt_path: Path,
    worker_log_path: Path,
) -> dict[str, Any]:
    flag = root / "state" / "FACTORY_OFF.flag"
    lock_path = path_for_factory_flag(flag)
    with FactoryMutationLock(lock_path, owner=f"isolated_work_item:{work_item_id}:{terminal.upper()}"):
        plan = build_plan(
            root,
            terminal=terminal,
            work_item_id=work_item_id,
            worker_script=worker_script,
            repo_root=repo_root,
        )
        if not plan.get("valid"):
            raise RuntimeError(f"isolated run preflight failed: {plan.get('errors')}")
        _require_equal("FACTORY_OFF SHA-256", expected_factory_off_sha256, plan["factory_off_sha256"])
        _require_equal("logical DB state SHA-256", expected_db_state_sha256, plan["db_state_sha256"])
        _require_equal("work-item payload SHA-256", expected_payload_sha256, plan["work_item"]["payload_sha256"])
        _require_equal("worker SHA-256", expected_worker_sha256, plan["worker_sha256"])

        snapshot_sha = sqlite_snapshot(Path(plan["db"]), snapshot_path)
        worker_log_path.parent.mkdir(parents=True, exist_ok=True)
        command = [
            sys.executable,
            str(worker_script),
            "--terminal",
            terminal.upper(),
            "--root",
            str(root),
            "--timeout-minutes",
            str(timeout_minutes),
            "--work-item-id",
            work_item_id,
        ]
        started_at = utc_now()
        worker_started_wall_ns = time.time_ns()
        worker_env = os.environ.copy()
        # Script execution puts only tools/strategy_farm on sys.path.  Bind the
        # repo package root explicitly and discard ambient PYTHONPATH entries so
        # imports cannot resolve from an unrelated checkout.
        worker_env["PYTHONPATH"] = str(repo_root)
        with worker_log_path.open("x", encoding="utf-8") as log_handle:
            process = subprocess.Popen(
                command,
                # terminal_worker imports the repo-level ``framework`` package.
                # A controller may live in a linked maintenance worktree, but
                # the hash-bound worker and artifacts above belong to the
                # explicitly selected canonical repo root.
                cwd=str(repo_root),
                env=worker_env,
                stdout=log_handle,
                stderr=subprocess.STDOUT,
                text=True,
            )
            hard_deadline = time.monotonic() + (timeout_minutes + 20.0) * 60.0
            next_heartbeat = time.monotonic()
            while process.poll() is None:
                now = time.monotonic()
                if now >= hard_deadline:
                    process.terminate()
                    try:
                        process.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        process.kill()
                    raise RuntimeError("isolated worker exceeded controller hard deadline")
                if now >= next_heartbeat:
                    print(json.dumps({
                        "event": "isolated_run_heartbeat",
                        "work_item_id": work_item_id,
                        "terminal": terminal.upper(),
                        "worker_pid": process.pid,
                        "elapsed_seconds": int((timeout_minutes + 20.0) * 60.0 - (hard_deadline - now)),
                    }), flush=True)
                    next_heartbeat = now + 30.0
                time.sleep(2.0)
            worker_exit_code = int(process.returncode or 0)

        if sha256_file(flag) != plan["factory_off_sha256"]:
            raise RuntimeError("FACTORY_OFF flag changed during isolated run")
        post_run_stream = _harvest_post_run_stream(
            plan["post_run_stream"], worker_started_wall_ns=worker_started_wall_ns
        )
        db = Path(plan["db"])
        wal_checkpoint = checkpoint_wal(db)
        with connect_ro(db) as conn:
            post = conn.execute(
                "SELECT id,status,verdict,claimed_by,evidence_path,updated_at,payload_json "
                "FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()
        if post is None:
            raise RuntimeError("work item disappeared during isolated run")
        result = {
            "schema_version": 1,
            "mode": "apply",
            "started_at_utc": started_at,
            "completed_at_utc": utc_now(),
            "terminal": terminal.upper(),
            "work_item_id": work_item_id,
            "preflight": plan,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "worker_log_path": str(worker_log_path),
            "worker_log_sha256": sha256_file(worker_log_path),
            "worker_exit_code": worker_exit_code,
            "post_run_stream": post_run_stream,
            "post_work_item": {
                key: post[key]
                for key in ("id", "status", "verdict", "claimed_by", "evidence_path", "updated_at")
            },
            "post_payload_sha256": sha256_text(str(post["payload_json"] or "{}")),
            "post_db_sha256": sha256_file(db),
            "post_db_state_sha256": sqlite_state_sha256(db),
            "factory_off_sha256": sha256_file(flag),
            "wal_checkpoint": wal_checkpoint,
            "live_scope_touched": False,
            "autotrading_touched": False,
        }
        _write_receipt(receipt_path, result)
        return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--terminal")
    parser.add_argument("--work-item-id")
    parser.add_argument("--worker-script", type=Path, default=DEFAULT_WORKER)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--timeout-minutes", type=float, default=90.0)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--expected-db-state-sha256")
    parser.add_argument("--expected-payload-sha256")
    parser.add_argument("--expected-worker-sha256")
    parser.add_argument("--snapshot-path", type=Path)
    parser.add_argument("--receipt-path", type=Path)
    parser.add_argument("--worker-log-path", type=Path)
    parser.add_argument("--recover-harvest-from-receipt", type=Path)
    parser.add_argument("--expected-source-receipt-sha256")
    parser.add_argument("--recovery-receipt-path", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.recover_harvest_from_receipt:
        if not args.expected_source_receipt_sha256 or not args.recovery_receipt_path:
            parser.error(
                "harvest recovery requires --expected-source-receipt-sha256 "
                "and --recovery-receipt-path"
            )
        result = recover_harvest_from_receipt(
            args.root,
            source_receipt_path=args.recover_harvest_from_receipt,
            expected_source_receipt_sha256=args.expected_source_receipt_sha256,
            recovery_receipt_path=args.recovery_receipt_path,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["harvest"].get("valid") else 2
    if not args.terminal or not args.work_item_id:
        parser.error("--terminal and --work-item-id are required for an isolated run")
    if not args.apply:
        print(json.dumps(build_plan(
            args.root,
            terminal=args.terminal,
            work_item_id=args.work_item_id,
            worker_script=args.worker_script,
            repo_root=args.repo_root,
        ), indent=2, sort_keys=True))
        return 0
    required = {
        "--expected-factory-off-sha256": args.expected_factory_off_sha256,
        "--expected-db-state-sha256": args.expected_db_state_sha256,
        "--expected-payload-sha256": args.expected_payload_sha256,
        "--expected-worker-sha256": args.expected_worker_sha256,
        "--snapshot-path": args.snapshot_path,
        "--receipt-path": args.receipt_path,
        "--worker-log-path": args.worker_log_path,
    }
    missing = [name for name, value in required.items() if value in (None, "")]
    if missing:
        parser.error("apply requires " + ", ".join(missing))
    result = execute(
        args.root,
        terminal=args.terminal,
        work_item_id=args.work_item_id,
        worker_script=args.worker_script,
        repo_root=args.repo_root,
        timeout_minutes=args.timeout_minutes,
        expected_factory_off_sha256=args.expected_factory_off_sha256,
        expected_db_state_sha256=args.expected_db_state_sha256,
        expected_payload_sha256=args.expected_payload_sha256,
        expected_worker_sha256=args.expected_worker_sha256,
        snapshot_path=args.snapshot_path,
        receipt_path=args.receipt_path,
        worker_log_path=args.worker_log_path,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    terminal_status = result["post_work_item"]["status"] in {"done", "failed"}
    evidence_valid = bool(result["post_run_stream"].get("valid"))
    return 0 if terminal_status and evidence_valid else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        raise SystemExit(1)
