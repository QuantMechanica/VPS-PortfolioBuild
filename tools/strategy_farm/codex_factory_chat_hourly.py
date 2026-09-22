"""Queue the OWNER's hourly inspection into one existing interactive Codex thread.

No new model session, SMTP, Factory DB writes or terminal control. The CLI owns
queue writes; the SQLite read below only prevents an offline reminder backlog.
"""
from __future__ import annotations

import argparse
from contextlib import closing, contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import uuid

MARKER = "[QM-FACTORY-HOURLY]"


def utc_bucket(now: datetime) -> str:
    if now.tzinfo is None:
        raise ValueError("An aware timestamp is required")
    return now.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:00Z")


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


@contextmanager
def process_lock(path: Path):
    """OS releases this lock on a crash; an abandoned file is harmless."""
    import msvcrt

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as handle:
        handle.seek(0, 2)
        if handle.tell() == 0:
            handle.write(b"0")
            handle.flush()
        handle.seek(0)
        msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)


def pending_reminder(queue_db: Path, thread_id: str) -> bool:
    # A missing/changed queue schema fails closed instead of sending duplicates.
    with closing(sqlite3.connect(queue_db.resolve().as_uri() + "?mode=ro", uri=True, timeout=5)) as db:
        rows = db.execute("SELECT payload_json FROM queued_items WHERE thread_id = ?", (thread_id,))
        return any(MARKER in row[0] for row in rows)


def dispatch(config: dict, now: datetime, runner=subprocess.run) -> dict:
    thread = str(uuid.UUID(config["thread_id"]))
    bucket = utc_bucket(now)
    state_path = Path(config["state_dir"]) / "dispatch_state.json"
    previous = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    result = {"at_utc": now.astimezone(timezone.utc).isoformat(), "bucket": bucket, "thread_id": thread}
    if previous.get("bucket") == bucket and previous.get("thread_id") == thread:
        return {**result, "status": "skipped_same_hour", "previous_status": previous.get("status")}
    if pending_reminder(Path(config["queue_db"]), thread):
        return {**result, "status": "skipped_pending_reminder"}

    prompt = Path(config["prompt_file"]).read_text(encoding="utf-8").strip()
    if not prompt:
        raise ValueError("Empty hourly inspection prompt")
    message = f"{MARKER} Planzeit UTC {bucket}.\n\n{prompt}"
    command = [config["codex_exe"], "queue", "--thread", thread, "--message", message]
    # Reserve before invoking the CLI: timeout/crash can mean the queue write
    # succeeded. Do not retry an ambiguous invocation within the same UTC hour.
    atomic_json(state_path, {**result, "status": "reserved"})
    try:
        completed = runner(command, cwd=config["repo_root"], capture_output=True,
                           text=True, encoding="utf-8", errors="replace", timeout=45,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        result["status"] = "queued" if completed.returncode == 0 else "queue_error"
        result["exit_code"] = completed.returncode
        result["cli_output"] = (completed.stdout + completed.stderr)[-2000:]
    except (OSError, subprocess.TimeoutExpired) as exc:
        result.update(status="delivery_unknown", error=type(exc).__name__)
    atomic_json(state_path, result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8-sig"))
    state_dir = Path(config["state_dir"])
    with process_lock(state_dir / "dispatch.lock"):
        try:
            result = dispatch(config, datetime.now(timezone.utc))
        except Exception as exc:
            result = {"at_utc": datetime.now(timezone.utc).isoformat(),
                      "status": "check_error", "error": f"{type(exc).__name__}: {exc}"}
        atomic_json(state_dir / "last_run.json", result)
        with (state_dir / "dispatch.jsonl").open("a", encoding="utf-8") as log:
            log.write(json.dumps(result, ensure_ascii=False) + "\n")
    return 0 if result["status"] in ("queued", "skipped_same_hour", "skipped_pending_reminder") else 1


if __name__ == "__main__":
    raise SystemExit(main())
