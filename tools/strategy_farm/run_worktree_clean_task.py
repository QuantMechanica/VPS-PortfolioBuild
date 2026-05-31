"""Scheduled worktree janitor for completed strategy-farm build artifacts.

This task is intentionally conservative. It commits/pushes completed EA build
artifacts that the farm already marked done, then delegates volatile cleanup to
clean_repo_worktree.ps1. It does not delete or archive in-progress EA dirs.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(r"C:\QM\repo")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"
LOG_DIR = FARM_ROOT / "logs"
LOCK_PATH = LOG_DIR / "worktree_clean_task.lock"
LOCK_STALE_SECONDS = 2 * 60 * 60

SHARED_BUILD_PATHS = [
    "framework/include/QM/QM_MagicResolver.mqh",
    "framework/registry/ea_id_registry.csv",
    "framework/registry/magic_numbers.csv",
    "public-data/process-roadmap.json",
    "public-data/public-snapshot.json",
    "public-data/strategy-archive.json",
]


def _run(args: list[str], *, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        text=True,
        capture_output=True,
        timeout=timeout,
        stdin=subprocess.DEVNULL,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )


def _acquire_lock() -> int | None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        return os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        try:
            if time.time() - LOCK_PATH.stat().st_mtime <= LOCK_STALE_SECONDS:
                return None
            LOCK_PATH.unlink()
            return os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except OSError:
            return None


def _git_status() -> list[str]:
    p = _run(["git", "status", "--porcelain=v1", "--untracked-files=normal"])
    if p.returncode != 0:
        raise RuntimeError(p.stderr or p.stdout)
    return [line for line in p.stdout.splitlines() if line.strip()]


def _untracked_ea_dirs(status: list[str]) -> list[str]:
    dirs: set[str] = set()
    for line in status:
        if not line.startswith("?? "):
            continue
        rel = line[3:].strip().replace("\\", "/").rstrip("/")
        m = re.match(r"^(framework/EAs/(QM5_\d+_[^/]+))(?:/.*)?$", rel)
        if m:
            dirs.add(m.group(1))
    return sorted(dirs)


def _load_latest_build_result(ea_id: str) -> dict | None:
    if not DB_PATH.exists():
        return None
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    try:
        row = con.execute(
            """
            SELECT payload_json FROM tasks
            WHERE kind='build_ea' AND status='done' AND card_id=?
            ORDER BY updated_at DESC LIMIT 1
            """,
            (ea_id,),
        ).fetchone()
    finally:
        con.close()
    if row is None:
        return None
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except json.JSONDecodeError:
        return None
    result = payload.get("codex_result") if isinstance(payload.get("codex_result"), dict) else None
    brp = payload.get("build_result_path")
    if not result and brp and Path(str(brp)).exists():
        try:
            result = json.loads(Path(str(brp)).read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            result = None
    return result


def _is_completed_ea_dir(repo_rel: str) -> bool:
    name = Path(repo_rel).name
    m = re.match(r"^(QM5_\d+)_", name)
    if not m:
        return False
    ea_id = m.group(1)
    result = _load_latest_build_result(ea_id)
    if not result:
        return False
    if result.get("compile_succeeded") is not True:
        return False
    if result.get("build_check_passed") is not True:
        return False
    ea_dir = REPO_ROOT / repo_rel
    mq5 = ea_dir / f"{name}.mq5"
    ex5 = ea_dir / f"{name}.ex5"
    return mq5.exists() and ex5.exists()


def _stage_completed_builds(status: list[str]) -> list[str]:
    ea_dirs = _untracked_ea_dirs(status)
    if not ea_dirs:
        return []
    completed = [d for d in ea_dirs if _is_completed_ea_dir(d)]
    if len(completed) != len(ea_dirs):
        return []
    stage_paths = completed[:]
    dirty_shared = {line[3:].strip().replace("\\", "/") for line in status if not line.startswith("?? ")}
    stage_paths.extend(p for p in SHARED_BUILD_PATHS if p in dirty_shared)
    _run(["git", "add", "--", *stage_paths], timeout=120).check_returncode()
    return completed


def _commit_and_push(completed_dirs: list[str]) -> str | None:
    staged = _run(["git", "diff", "--cached", "--name-only"])
    if not staged.stdout.strip():
        return None
    ea_ids = [Path(d).name.split("_", 2)[0] + "_" + Path(d).name.split("_", 2)[1] for d in completed_dirs]
    message = "build: add " + (" and ".join(ea_ids) if ea_ids else "completed EA artifacts")
    _run(["git", "commit", "-m", message], timeout=180).check_returncode()
    _run(["git", "push", "origin", "HEAD:agents/board-advisor"], timeout=180).check_returncode()
    _run(["git", "push", "origin", "HEAD:main"], timeout=180).check_returncode()
    return message


def _cleanup_volatile() -> None:
    script = REPO_ROOT / "tools" / "strategy_farm" / "clean_repo_worktree.ps1"
    if not script.exists():
        return
    subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            "-RestorePublicData",
            "-RestoreTrackedEx5",
        ],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        timeout=180,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"worktree_clean_task_{stamp}.log"
    fd = _acquire_lock()
    if fd is None:
        return 0
    try:
        os.write(fd, str(os.getpid()).encode("ascii"))
        status = _git_status()
        completed = _stage_completed_builds(status)
        message = _commit_and_push(completed)
        _cleanup_volatile()
        final_status = _git_status()
        payload = {
            "checked_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
            "committed": message,
            "completed_dirs": completed,
            "dirty_after": final_status,
        }
        log_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0
    finally:
        os.close(fd)
        try:
            LOCK_PATH.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
        (LOG_DIR / f"worktree_clean_task_{stamp}.error.log").write_text(
            repr(exc),
            encoding="utf-8",
        )
        raise
