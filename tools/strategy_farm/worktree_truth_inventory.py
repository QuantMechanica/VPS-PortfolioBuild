"""Generate a read-only, ref-explicit Git worktree truth inventory.

No fetch, checkout, branch update, commit, merge, or worktree mutation is
performed. Ahead/behind is always labelled against the captured ``origin/main``
OID; "unpushed" is reported only when a local branch has an actual upstream.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
from pathlib import Path
from typing import Any


SCHEMA = "qm.repo-worktree-truth.v1"


def _run(repo: Path, *args: str, check: bool = True) -> str:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
        timeout=120,
        creationflags=flags,
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} rc={result.returncode}: {result.stderr.strip()}")
    return result.stdout


def _parse_worktrees(raw: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    current: dict[str, Any] = {}
    for line in [*raw.splitlines(), ""]:
        if not line:
            if current:
                records.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        if key in {"detached", "bare", "prunable"}:
            current[key] = True if not value else value
        elif key == "locked":
            current[key] = value or True
        else:
            current[key] = value
    return records


def _counts(repo: Path, left: str, right: str) -> tuple[int | None, int | None]:
    raw = _run(repo, "rev-list", "--left-right", "--count", f"{left}...{right}", check=False).strip()
    try:
        left_only, right_only = raw.split()
        return int(left_only), int(right_only)
    except (ValueError, TypeError):
        return None, None


def _owner_and_role(path: Path, branch: str | None, detached: bool) -> tuple[str, str, str]:
    normalized = str(path).replace("\\", "/").lower()
    branch_text = str(branch or "").lower()
    name = path.name.lower()
    if normalized == "c:/qm/repo":
        return "Board Advisor lane; close-out authority Claude+OWNER", "canonical_operative", "explicit_contract"
    if name == "cto_main":
        return "Claude+OWNER", "main_integration_staging", "explicit_contract"
    if "/runtime_worktrees/" in normalized:
        return "Pipeline-Operator", "runtime_detached_execution", "path_contract"
    if "claude" in branch_text or name.startswith(("claude", "sonnet")):
        return "Claude", "agent_task_worktree", "branch_or_path"
    if "gemini" in branch_text or name.startswith("gemini"):
        return "Gemini/Antigravity", "agent_task_worktree", "branch_or_path"
    if "codex" in branch_text or name.startswith(("codex", "ftmo", "src-")):
        return "Codex", "agent_task_worktree", "branch_or_path"
    if name in {"pipeline-operations"} or name.startswith(("q08", "q09", "q11")):
        return "Pipeline-Operator", "pipeline_task_worktree", "path_contract"
    if name in {"docs-km"}:
        return "Docs/KM", "documentation_worktree", "path_contract"
    if name in {"pdf-analyst", "youtube-analyst"}:
        return "Research", "source_analysis_worktree", "path_contract"
    if name.startswith("development"):
        return "Development", "development_worktree", "path_contract"
    if detached:
        return "Claude+OWNER disposition", "legacy_detached_worktree", "safe_default"
    return "Claude+OWNER disposition", "unclassified_branch_worktree", "safe_default"


def _branch_inventory(repo: Path, origin_main: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    raw = _run(
        repo,
        "for-each-ref",
        "--format=%(refname:short)%00%(objectname)%00%(upstream:short)",
        "refs/heads",
    )
    branches: list[dict[str, Any]] = []
    for line in raw.splitlines():
        name, oid, upstream = (line.split("\x00") + ["", ""])[:3]
        behind_main, ahead_main = _counts(repo, origin_main, name)
        upstream_ahead = upstream_behind = None
        if upstream:
            upstream_behind, upstream_ahead = _counts(repo, upstream, name)
        branches.append({
            "branch": name,
            "head": oid,
            "upstream": upstream or None,
            "behind_origin_main": behind_main,
            "ahead_origin_main": ahead_main,
            "behind_upstream": upstream_behind,
            "ahead_upstream_unpushed": upstream_ahead,
        })
    with_upstream = [row for row in branches if row["upstream"]]
    summary = {
        "local_branch_count": len(branches),
        "branches_with_upstream": len(with_upstream),
        "branches_without_upstream": len(branches) - len(with_upstream),
        "branches_ahead_origin_main": sum((row["ahead_origin_main"] or 0) > 0 for row in branches),
        "sum_ahead_origin_main_non_deduplicated": sum(row["ahead_origin_main"] or 0 for row in branches),
        "branches_ahead_their_upstream": sum((row["ahead_upstream_unpushed"] or 0) > 0 for row in with_upstream),
        "sum_unpushed_against_configured_upstreams_non_deduplicated": sum(
            row["ahead_upstream_unpushed"] or 0 for row in with_upstream
        ),
        "unpushed_definition": "ahead_upstream only; undefined for branches without upstream",
    }
    return branches, summary


def generate(repo: Path) -> dict[str, Any]:
    repo = repo.resolve()
    origin_main = _run(repo, "rev-parse", "origin/main").strip()
    local_main = _run(repo, "rev-parse", "main", check=False).strip() or None
    canonical_head = _run(repo, "rev-parse", "HEAD").strip()
    canonical_branch = _run(repo, "branch", "--show-current").strip() or None
    branch_rows, branch_summary = _branch_inventory(repo, origin_main)
    worktrees: list[dict[str, Any]] = []
    for raw in _parse_worktrees(_run(repo, "worktree", "list", "--porcelain")):
        path = Path(raw["worktree"])
        head = str(raw.get("HEAD") or "")
        ref = str(raw.get("branch") or "")
        branch = ref.removeprefix("refs/heads/") or None
        detached = bool(raw.get("detached")) or branch is None
        behind, ahead = _counts(repo, origin_main, head)
        status_raw = _run(path, "status", "--porcelain=v1", "--untracked-files=normal", check=False)
        status_lines = [line for line in status_raw.splitlines() if line]
        tracked = sum(not line.startswith("??") for line in status_lines)
        untracked = sum(line.startswith("??") for line in status_lines)
        owner, role, owner_basis = _owner_and_role(path, branch, detached)
        upstream = None
        behind_upstream = ahead_upstream = None
        if branch:
            upstream = _run(
                repo,
                "for-each-ref",
                "--format=%(upstream:short)",
                f"refs/heads/{branch}",
                check=False,
            ).strip() or None
            if upstream:
                behind_upstream, ahead_upstream = _counts(repo, upstream, head)
        worktrees.append({
            "path": str(path).replace("\\", "/"),
            "head": head,
            "branch": branch,
            "detached": detached,
            "locked": raw.get("locked", False),
            "prunable": raw.get("prunable", False),
            "comparison_ref": "origin/main",
            "comparison_ref_oid": origin_main,
            "behind_origin_main": behind,
            "ahead_origin_main": ahead,
            "upstream": upstream,
            "behind_upstream": behind_upstream,
            "ahead_upstream_unpushed": ahead_upstream,
            "dirty": bool(status_lines),
            "tracked_dirty_count": tracked,
            "untracked_count": untracked,
            "status_probe_ok": path.exists(),
            "owner": owner,
            "owner_basis": owner_basis,
            "role": role,
        })
    return {
        "schema": SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "read_only_generation": True,
        "fetch_performed": False,
        "canonical_repo": str(repo).replace("\\", "/"),
        "canonical_branch": canonical_branch,
        "canonical_head": canonical_head,
        "origin_main_oid": origin_main,
        "local_main_oid": local_main,
        "branch_summary": branch_summary,
        "branches": branch_rows,
        "worktree_count": len(worktrees),
        "dirty_worktree_count": sum(row["dirty"] for row in worktrees),
        "detached_worktree_count": sum(row["detached"] for row in worktrees),
        "worktrees": worktrees,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(r"C:\QM\repo"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    payload = generate(args.repo)
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix(args.output.suffix + ".tmp")
        temporary.write_text(rendered, encoding="utf-8")
        temporary.replace(args.output)
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
