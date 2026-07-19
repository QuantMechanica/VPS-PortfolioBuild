"""Windows-only supervisor for one Strategy Farm Codex process tree.

The supervisor puts itself in a uniquely named Job Object before it launches
Codex.  Children inherit that job, so the controller can later terminate the
whole owned tree by Job Object handle instead of by a reusable PID.

This file is an internal implementation detail of ``managed_codex.py``.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path

try:
    from managed_codex import _assign_current_process_to_windows_job, _create_windows_job
except ModuleNotFoundError:
    from tools.strategy_farm.managed_codex import (
        _assign_current_process_to_windows_job,
        _create_windows_job,
    )


def _write_ready(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        temporary.write_text(
            json.dumps(payload, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--job-name", required=True)
    parser.add_argument("--ready-path", required=True)
    parser.add_argument("--payload-b64", required=True)
    args = parser.parse_args()

    if os.name != "nt":
        raise RuntimeError("managed Codex supervisor is Windows-only")

    payload = json.loads(base64.urlsafe_b64decode(args.payload_b64).decode("utf-8"))
    argv = payload["argv"]
    cwd = payload["cwd"]
    shell = bool(payload["shell"])
    creationflags = int(payload["creationflags"])

    # Do not close this handle explicitly.  KILL_ON_JOB_CLOSE makes the OS
    # terminate every remaining member when this supervisor exits or crashes.
    job_handle = _create_windows_job(args.job_name)
    _assign_current_process_to_windows_job(job_handle)

    stdin_stream = getattr(sys.stdin, "buffer", sys.stdin)
    stdout_stream = getattr(sys.stdout, "buffer", sys.stdout)
    stderr_stream = getattr(sys.stderr, "buffer", sys.stderr)
    child = subprocess.Popen(
        argv,
        cwd=cwd,
        shell=shell,
        stdin=stdin_stream,
        stdout=stdout_stream,
        stderr=stderr_stream,
        creationflags=creationflags,
        close_fds=True,
    )
    _write_ready(
        Path(args.ready_path),
        {
            "job_name": args.job_name,
            "supervisor_pid": os.getpid(),
            "child_pid": child.pid,
        },
    )
    return int(child.wait())


if __name__ == "__main__":
    try:
        exit_code = main()
    except Exception as exc:
        print(f"managed Codex supervisor failed: {exc!r}", file=sys.stderr, flush=True)
        raise
    raise SystemExit(exit_code)
