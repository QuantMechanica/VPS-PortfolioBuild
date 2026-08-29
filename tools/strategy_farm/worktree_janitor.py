"""Remove old, clean, process-unreferenced linked worktrees.

The janitor is deliberately narrower than ``git worktree prune``: it considers
only registered linked worktrees below C:/QM/worktrees, never the canonical
checkout, and asks Git to remove a worktree only after all safety predicates
pass. Dirty, young, locked, or process-referenced roots are retained.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


CANONICAL_REPO = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
WORKTREE_PARENT = Path(os.environ.get("QM_WORKTREE_PARENT", r"C:\QM\worktrees"))
REPORT_DIR = Path(r"D:\QM\reports\maintenance")
MIN_AGE_HOURS = 48.0


def _run(args: list[str], *, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args, capture_output=True, text=True, timeout=timeout,
        stdin=subprocess.DEVNULL,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )


def registered_worktrees(canonical_repo: Path = CANONICAL_REPO) -> list[dict[str, object]]:
    result = _run(["git", "-C", str(canonical_repo), "worktree", "list", "--porcelain"])
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout or "git worktree list failed")
    rows: list[dict[str, object]] = []
    current: dict[str, object] = {}
    for line in (*result.stdout.splitlines(), ""):
        if not line:
            if current:
                current["registered"] = True
                rows.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            current["path"] = value
        elif key == "HEAD":
            current["head"] = value
        elif key == "branch":
            current["branch"] = value.removeprefix("refs/heads/")
        elif key in {"detached", "locked", "prunable"}:
            current[key] = value or True
    known = {
        os.path.normcase(str(Path(str(row["path"])).resolve()))
        for row in rows if row.get("path")
    }
    if WORKTREE_PARENT.exists():
        for candidate in WORKTREE_PARENT.iterdir():
            resolved = candidate.resolve()
            if (
                os.path.normcase(str(resolved)) not in known
                and (resolved / "tools" / "strategy_farm").is_dir()
            ):
                rows.append({"path": str(resolved), "registered": False})
    return rows


def process_command_lines() -> list[str]:
    if sys.platform != "win32":
        return []
    script = (
        "@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | "
        "Where-Object CommandLine | Select-Object -ExpandProperty CommandLine) | "
        "ConvertTo-Json -Compress"
    )
    result = _run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script])
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError("process census failed; refusing worktree removal")
    data = json.loads(result.stdout)
    return [str(value) for value in (data if isinstance(data, list) else [data])]


def process_references(path: Path, command_lines: list[str]) -> bool:
    needle = os.path.normcase(str(path.resolve())).replace("/", "\\")
    return any(
        needle in os.path.normcase(line).replace("/", "\\")
        for line in command_lines
    )


def worktree_clean(path: Path) -> bool:
    result = _run([
        "git", "-C", str(path), "status", "--porcelain=v1", "--untracked-files=all"
    ])
    return result.returncode == 0 and not result.stdout.strip()


def worktree_age_hours(path: Path, *, now: float | None = None) -> float:
    # On Windows st_ctime is creation time. The linked-worktree .git marker is
    # created with the worktree and is a stable second witness.
    witnesses = [path.stat().st_ctime]
    marker = path / ".git"
    if marker.exists():
        witnesses.append(marker.stat().st_ctime)
    created = max(witnesses)
    return ((time.time() if now is None else now) - created) / 3600.0


def assess(
    row: dict[str, object],
    *,
    command_lines: list[str],
    canonical_repo: Path = CANONICAL_REPO,
    worktree_parent: Path = WORKTREE_PARENT,
    min_age_hours: float = MIN_AGE_HOURS,
) -> dict[str, object]:
    path = Path(str(row.get("path") or "")).resolve()
    canonical = canonical_repo.resolve()
    parent = worktree_parent.resolve()
    reasons: list[str] = []
    if path == canonical:
        reasons.append("canonical_checkout")
    if path == parent or parent not in path.parents:
        reasons.append("outside_worktree_parent")
    if row.get("locked"):
        reasons.append("git_locked")
    if not path.exists():
        reasons.append("missing")
        age_hours = None
    else:
        age_hours = worktree_age_hours(path)
        if age_hours < min_age_hours:
            reasons.append("younger_than_48h")
        if process_references(path, command_lines):
            reasons.append("process_referenced")
        if not worktree_clean(path):
            reasons.append("dirty_or_unreadable")
    return {
        **row,
        "path": str(path),
        "age_hours": round(age_hours, 2) if age_hours is not None else None,
        "eligible": not reasons,
        "reasons": reasons,
    }


def run(*, apply: bool) -> dict[str, object]:
    commands = process_command_lines()
    assessed = [assess(row, command_lines=commands) for row in registered_worktrees()]
    removed: list[str] = []
    failures: list[dict[str, str]] = []
    if apply:
        for row in assessed:
            if not row["eligible"]:
                continue
            path = str(row["path"])
            if row.get("registered", True):
                result = _run(["git", "-C", str(CANONICAL_REPO), "worktree", "remove", "--", path], timeout=180)
                if result.returncode == 0:
                    removed.append(path)
                else:
                    failures.append({"path": path, "error": (result.stderr or result.stdout).strip()})
            else:
                # ``assess`` already proved this exact resolved path is old,
                # clean, unreferenced, and strictly below WORKTREE_PARENT.
                try:
                    shutil.rmtree(path)
                    removed.append(path)
                except OSError as exc:
                    failures.append({"path": path, "error": repr(exc)})
    return {
        "schema": "qm.worktree-janitor.v1",
        "checked_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "apply": apply,
        "minimum_age_hours": MIN_AGE_HOURS,
        "registered_count": len(assessed),
        "eligible_count": sum(bool(row["eligible"]) for row in assessed),
        "removed": removed,
        "failures": failures,
        "worktrees": assessed,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = run(apply=args.apply)
    output = args.output or REPORT_DIR / "worktree_janitor_latest.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
