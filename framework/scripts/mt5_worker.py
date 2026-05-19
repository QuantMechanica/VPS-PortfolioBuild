#!/usr/bin/env python3
"""Single-terminal MT5 queue worker prototype (claim-based, deterministic)."""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__ is None or __package__ == "":
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.queue_init import ensure_schema

REPO_ROOT = Path(r"C:/QM/repo")
DEFAULT_SQLITE = Path(r"D:/QM/reports/pipeline/mt5_queue.db")
DEFAULT_REPORT_ROOT = Path(r"D:/QM/reports/pipeline")
RUN_SMOKE = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"


def utc_now() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def heartbeat(conn: sqlite3.Connection, *, terminal: str, current_job_id: str | None, last_error: str | None) -> None:
    conn.execute(
        """
        INSERT INTO worker_heartbeat(terminal_id, pid, last_seen_utc, current_job_id, jobs_completed, last_error)
        VALUES(?, ?, ?, ?, 0, ?)
        ON CONFLICT(terminal_id) DO UPDATE SET
          pid=excluded.pid,
          last_seen_utc=excluded.last_seen_utc,
          current_job_id=excluded.current_job_id,
          last_error=excluded.last_error
        """,
        (terminal, os.getpid(), utc_now(), current_job_id, last_error),
    )


def claim_one(conn: sqlite3.Connection, *, terminal: str) -> dict[str, Any] | None:
    row = conn.execute(
        """
        WITH next_job AS (
          SELECT job_id
          FROM jobs
          WHERE status='queued'
          ORDER BY enqueued_at ASC, job_id ASC
          LIMIT 1
        )
        UPDATE jobs
        SET status='claimed', claimed_by=?, claimed_at=?
        WHERE job_id=(SELECT job_id FROM next_job)
        RETURNING job_id, ea_id, version, symbol, period, year, phase, setfile_path
        """,
        (terminal, utc_now()),
    ).fetchone()
    if row is None:
        return None
    return {
        "job_id": str(row[0]),
        "ea_id": str(row[1]),
        "version": str(row[2]),
        "symbol": str(row[3]),
        "period": str(row[4]),
        "year": int(row[5]),
        "phase": str(row[6]),
        "setfile_path": str(row[7]),
    }


def mark_failed(conn: sqlite3.Connection, *, job_id: str, reason: str) -> None:
    conn.execute(
        """
        UPDATE jobs
        SET status='failed', verdict='INVALID', invalidation_reason=?, finished_at=?
        WHERE job_id=?
        """,
        (reason, utc_now(), job_id),
    )


def mark_running(conn: sqlite3.Connection, *, job_id: str) -> None:
    conn.execute("UPDATE jobs SET status='running', started_at=? WHERE job_id=?", (utc_now(), job_id))


def mark_done(conn: sqlite3.Connection, *, job_id: str, verdict: str, result_path: str, invalidation_reason: str) -> None:
    conn.execute(
        """
        UPDATE jobs
        SET status='done', verdict=?, result_path=?, invalidation_reason=?, finished_at=?
        WHERE job_id=?
        """,
        (verdict, result_path, invalidation_reason or None, utc_now(), job_id),
    )
    conn.execute(
        """
        UPDATE worker_heartbeat
        SET jobs_completed=jobs_completed+1
        WHERE terminal_id=(SELECT claimed_by FROM jobs WHERE job_id=?)
        """,
        (job_id,),
    )


def _ea_numeric(ea_id: str) -> str:
    qm5_match = re.match(r"^QM5_(\d+)(?:\D|$)", ea_id)
    if qm5_match:
        return qm5_match.group(1)
    tokens = re.findall(r"(\d+)", ea_id)
    if not tokens:
        raise ValueError(f"ea_id has no numeric component: {ea_id}")
    # Use the trailing numeric token so QM5_1003 resolves to 1003.
    return tokens[-1]


def _resolve_ex5_name(job: dict[str, Any], terminal_root: Path) -> Path:
    experts = terminal_root / "MQL5" / "Experts" / "QM"
    ea_id = job["ea_id"]
    direct = experts / f"{ea_id}.ex5"
    if direct.exists():
        return direct
    prefixed = sorted(experts.glob(f"{ea_id}_*.ex5"))
    if len(prefixed) == 1:
        return prefixed[0]
    raise FileNotFoundError(f"deploy_missing: unable to resolve .ex5 for {ea_id} under {experts}")


def _parse_summary_path(text: str) -> Path | None:
    match = re.search(r"run_smoke\.summary=(\S+)", text)
    if not match:
        return None
    return Path(match.group(1).strip())


def run_job(
    job: dict[str, Any], *, terminal: str, report_root: Path, mt5_root: Path, timeout_seconds: int
) -> tuple[str, str, str]:
    terminal_root = mt5_root / terminal
    terminal_exe = terminal_root / "terminal64.exe"
    if not terminal_exe.exists():
        raise FileNotFoundError(f"deploy_missing:{terminal_exe}")

    profile = terminal_root / "MQL5" / "Profiles" / "Tester" / "Groups"
    if not profile.exists() or not any(profile.glob("*.txt")):
        raise FileNotFoundError(f"missing_commission_profile:{profile}")

    ex5_path = _resolve_ex5_name(job, terminal_root)
    setfile = Path(job["setfile_path"])
    if not setfile.exists():
        raise FileNotFoundError(f"deploy_missing:{setfile}")

    cmd = [
        "pwsh.exe",
        "-NoProfile",
        "-File",
        str(RUN_SMOKE),
        "-EAId",
        _ea_numeric(job["ea_id"]),
        "-Symbol",
        job["symbol"],
        "-Year",
        str(job["year"]),
        "-Terminal",
        terminal,
        "-Period",
        job["period"],
        "-Runs",
        "2",
        "-Model",
        "4",
        "-Expert",
        f"QM\\{ex5_path.stem}",
        "-SetFile",
        str(setfile),
        "-ReportRoot",
        str(report_root),
        "-TimeoutSeconds",
        str(int(timeout_seconds)),
        "-AllowRunningTerminal",
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=max(1, int(timeout_seconds)) + 30,
            creationflags=creationflags,
        )
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + "\n" + (exc.stderr or "")
        raise TimeoutError(f"run_smoke_timeout:timeout_seconds={timeout_seconds};output_tail={output[-1000:]}") from exc
    output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    summary = _parse_summary_path(output)

    if summary is None or not summary.exists():
        raise RuntimeError(f"no_summary_json:rc={proc.returncode}")

    payload = json.loads(summary.read_text(encoding="utf-8-sig"))
    verdict = "PASS" if payload.get("result") == "PASS" else "FAIL"
    reason = "" if verdict == "PASS" else "run_smoke_fail"
    return verdict, str(summary), reason


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MT5 claim-based worker prototype.")
    parser.add_argument("--terminal", required=True, help="Factory terminal id (T1..T10).")
    parser.add_argument("--sqlite", default=str(DEFAULT_SQLITE), help="Path to mt5_queue.db.")
    parser.add_argument("--report-root", default=str(DEFAULT_REPORT_ROOT), help="Report output root.")
    parser.add_argument("--mt5-root", default=r"D:/QM/mt5", help="MT5 terminals root (contains T1..T10).")
    parser.add_argument("--poll-sec", type=int, default=30, help="Sleep when queue is empty.")
    parser.add_argument("--timeout-seconds", type=int, default=60, help="run_smoke timeout seconds per run.")
    parser.add_argument("--once", action="store_true", help="Run one claim cycle and exit.")
    return parser.parse_args()


def acquire_terminal_lock(terminal: str, lock_dir: Path) -> tuple[Path, bool]:
    """Single-instance guard. Returns (lock_path, acquired).
    If another live worker process holds the lock, refuse. Otherwise claim it.
    Stale locks (process no longer running) are taken over."""
    lock_path = lock_dir / f".worker_{terminal}.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    my_pid = os.getpid()
    if lock_path.exists():
        try:
            existing = int(lock_path.read_text().strip() or "0")
        except (ValueError, OSError):
            existing = 0
        if existing > 0 and existing != my_pid:
            # Check whether existing process is still alive
            try:
                # Windows-friendly: os.kill(pid, 0) returns OSError if dead
                os.kill(existing, 0)
                return lock_path, False
            except OSError:
                pass  # stale, take over
    lock_path.write_text(str(my_pid), encoding="utf-8")
    return lock_path, True


def release_terminal_lock(lock_path: Path) -> None:
    try:
        if lock_path.exists():
            stored = lock_path.read_text(encoding="utf-8").strip()
            if stored == str(os.getpid()):
                lock_path.unlink()
    except OSError:
        pass


def main() -> int:
    args = parse_args()
    terminal = str(args.terminal).upper()
    if not re.fullmatch(r"T(?:[1-9]|10)", terminal):
        print("[REFUSED] terminal is outside factory scope")
        print(json.dumps({"status": "error", "reason": "terminal_out_of_policy", "terminal": terminal}))
        return 2
    if not (Path(args.mt5_root) / terminal / "terminal64.exe").exists():
        print(json.dumps({"status": "error", "reason": "terminal_not_installed", "terminal": terminal}))
        return 2

    sqlite_path = Path(args.sqlite)
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)

    lock_path, acquired = acquire_terminal_lock(terminal, sqlite_path.parent)
    if not acquired:
        existing_pid = lock_path.read_text(encoding="utf-8").strip()
        print(f"[REFUSED] another worker holds {terminal} lock (PID {existing_pid})")
        print(json.dumps({"status": "skipped", "reason": "lock_held_by_other_pid", "terminal": terminal, "holder_pid": existing_pid}))
        return 3

    mt5_root = Path(args.mt5_root)

    try:
        while True:
            conn = sqlite3.connect(str(sqlite_path))
            conn.row_factory = sqlite3.Row
            try:
                ensure_schema(conn)
                heartbeat(conn, terminal=terminal, current_job_id=None, last_error=None)
                job = claim_one(conn, terminal=terminal)
                conn.commit()
                if job is None:
                    heartbeat(conn, terminal=terminal, current_job_id=None, last_error=None)
                    conn.commit()
                    if args.once:
                        print(json.dumps({"status": "idle", "terminal": terminal}, sort_keys=True))
                        return 0
                    time.sleep(max(1, int(args.poll_sec)))
                    continue

                heartbeat(conn, terminal=terminal, current_job_id=job["job_id"], last_error=None)
                mark_running(conn, job_id=job["job_id"])
                conn.commit()

                try:
                    verdict, result_path, reason = run_job(
                        job,
                        terminal=terminal,
                        report_root=Path(args.report_root),
                        mt5_root=mt5_root,
                        timeout_seconds=max(60, int(args.timeout_seconds)),
                    )
                    mark_done(conn, job_id=job["job_id"], verdict=verdict, result_path=result_path, invalidation_reason=reason)
                    heartbeat(conn, terminal=terminal, current_job_id=None, last_error=None)
                    conn.commit()
                    print(json.dumps({"status": "done", "terminal": terminal, "job_id": job["job_id"], "verdict": verdict}, sort_keys=True))
                except Exception as exc:  # noqa: BLE001
                    reason = str(exc)
                    mark_failed(conn, job_id=job["job_id"], reason=reason)
                    heartbeat(conn, terminal=terminal, current_job_id=None, last_error=reason)
                    conn.commit()
                    print(json.dumps({"status": "failed", "terminal": terminal, "job_id": job["job_id"], "reason": reason}, sort_keys=True))

                if args.once:
                    return 0
            finally:
                conn.close()
    except KeyboardInterrupt:
        return 130
    finally:
        release_terminal_lock(lock_path)


if __name__ == "__main__":
    raise SystemExit(main())
