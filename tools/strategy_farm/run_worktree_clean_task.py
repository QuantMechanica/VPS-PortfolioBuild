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

REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"
LOG_DIR = FARM_ROOT / "logs"
LOCK_PATH = LOG_DIR / "worktree_clean_task.lock"
LOCK_STALE_SECONDS = 2 * 60 * 60
FACTORY_OFF_FLAG = FARM_ROOT / "state" / "FACTORY_OFF.flag"

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


def _write_result_log(log_path: Path, payload: dict) -> None:
    log_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


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


def _sha256_file(path: Path) -> str:
    import hashlib
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _compile_receipt_exists(ea_id: str, ex5_sha256: str, db_path: Path = DB_PATH) -> bool:
    """A governed COMPILE_OK receipt binding exactly this on-disk binary."""
    if not db_path.exists():
        return False
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        row = con.execute(
            """
            SELECT 1 FROM work_items
            WHERE kind='compile' AND phase='COMPILE_EA' AND ea_id=?
              AND status='done' AND verdict='COMPILE_OK' AND ex5_sha256=?
            LIMIT 1
            """,
            (ea_id, ex5_sha256.lower()),
        ).fetchone()
    finally:
        con.close()
    return row is not None


def _receipted_tracked_ex5(status: list[str], repo_root: Path = REPO_ROOT,
                           db_path: Path = DB_PATH) -> list[str]:
    """Modified tracked .ex5 files whose bytes are bound by a COMPILE_OK receipt.

    2026-09-20 (Fable): ``_cleanup_volatile`` restores EVERY modified tracked
    .ex5 to HEAD every 30 minutes (``clean_repo_worktree.ps1 -RestoreTrackedEx5``).
    A governed rebuild whose binary was not committed within that window was
    silently reverted to the previous build: QM5_41347's 08:01Z rebuild
    (COMPILE_OK 20cce28d, ex5 862045c6) was replaced by the 2026-09-05
    slot-0-only binary at 08:30:14Z and the running DL-089 census failed 8
    cells with EA_MAGIC_NOT_REGISTERED before the poison-pill breaker tripped.
    Such binaries are exactly what the ex5 commit guard admits, so the janitor
    now commits them (with their EA's restamped setfiles) before it cleans.
    """
    out: list[str] = []
    for line in status:
        if len(line) < 4:
            continue
        # 2026-09-20 (Fable, addendum): a FIRST governed compile of an EA whose
        # directory is tracked but never carried a binary leaves the .ex5 as an
        # untracked "??" file (QM5_38001/39002/39004 in the Velocity intake
        # wave); it is receipted exactly like a rebuilt tracked binary and is
        # committed here as well, otherwise the Q02 canary claims against a
        # binary that only exists in the working tree.
        rel = line[3:].strip().replace("\\", "/")
        m = re.match(r"^framework/EAs/(QM5_\d+)_[^/]+/[^/]+\.ex5$", rel)
        if not m:
            continue
        path = repo_root / rel
        if not path.is_file():
            continue
        try:
            digest = _sha256_file(path)
        except OSError:
            continue
        if _compile_receipt_exists(m.group(1), digest, db_path):
            out.append(rel)
    return out


def _commit_receipted_tracked_ex5(status: list[str]) -> list[str]:
    receipted = _receipted_tracked_ex5(status)
    if not receipted:
        return []
    stage = list(receipted)
    ea_dirs = {rel.rsplit("/", 1)[0] for rel in receipted}
    for line in status:
        if len(line) < 4 or line.startswith("?? "):
            continue
        rel = line[3:].strip().replace("\\", "/")
        if rel.endswith(".set") and any(rel.startswith(d + "/sets/") for d in ea_dirs):
            stage.append(rel)
    _run(["git", "add", "--", *stage], timeout=120).check_returncode()
    ea_ids = sorted({Path(rel).name.split("_", 2)[0] + "_" + Path(rel).name.split("_", 2)[1] for rel in receipted})
    message = ("build: commit receipted rebuilt binaries " + ", ".join(ea_ids) + "\n\n"
               "COMPILE_OK receipt binds each .ex5; committed by the worktree clean task "
               "so -RestoreTrackedEx5 can no longer revert a governed rebuild (2026-09-20).")
    _run(["git", "commit", "-m", message, "--", *stage], timeout=180).check_returncode()
    return receipted


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
        if FACTORY_OFF_FLAG.exists():
            payload = {
                "checked_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
                "skipped": "FACTORY_OFF.flag set",
                "flag": str(FACTORY_OFF_FLAG),
            }
            _write_result_log(log_path, payload)
            print(json.dumps(payload, indent=2, sort_keys=True))
            return 0
        # This scheduled task is explicitly in Factory OFF's quiescence set.
        # OFF asserts the flag, disables its trigger, and waits for the running
        # task to drain.  The task-local lock prevents overlap, so holding the
        # factory-wide mutation lock during git hooks, push, or cleanup would add
        # no safety and would starve terminal claim admission.
        if FACTORY_OFF_FLAG.exists():
            payload = {
                "checked_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
                "skipped": "FACTORY_OFF.flag set after lock",
                "flag": str(FACTORY_OFF_FLAG),
            }
            _write_result_log(log_path, payload)
            print(json.dumps(payload, indent=2, sort_keys=True))
            return 0
        status = _git_status()
        completed = _stage_completed_builds(status)
        message = _commit_and_push(completed)
        receipted = _commit_receipted_tracked_ex5(_git_status())
        _cleanup_volatile()
        final_status = _git_status()
        payload = {
            "checked_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
            "committed": message,
            "completed_dirs": completed,
            "receipted_ex5_committed": receipted,
            "dirty_after": final_status,
        }
        _write_result_log(log_path, payload)
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
