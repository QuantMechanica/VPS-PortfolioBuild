#!/usr/bin/env python3
"""Deterministic agent/worktree preflight (OWNER mandate, 2026-09-16).

A write-capable agent/run MUST pass this preflight before its first edit.

Checks (each emits a structured finding; any hard failure exits 2):
  1. EXPECTED_BASE_BRANCH - current branch == expected canonical branch
     (default ``agents/board-advisor``; ``--expected-branch`` / env
     ``QM_AGENT_EXPECTED_BRANCH``).
  2. EXPECTED_REPO_PATH - absolute repo root == expected path (default
     ``C:/QM/repo``; env ``QM_AGENT_EXPECTED_REPO_PATH``). Fails closed if the
     root path contains a ``QM/worktrees`` or ``.claude/worktrees`` directory
     pair (e.g. ``C:/QM/worktrees/*``, ``*/.claude/worktrees/*``) unless
     ``--allow-worktree PATH=BRANCH`` names an exact expected worktree
     path+branch pair (repeatable).
  3. NOT_STALE_MAIN - current branch must not be ``main``. Fail closed
     always: the tool NEVER auto-resets, never rebases, never edits git state.
  4. BASE_DESCENDANT - HEAD contains (is a descendant of, or equals) the
     orchestration base commit. Default base: tip of
     ``origin/<expected-branch>`` as fetched LOCALLY (env
     ``QM_AGENT_BASE_COMMIT`` overrides). This tool NEVER fetches; it only
     reads local refs, so run ``git fetch`` outside the tool per normal cadence.
  5. PATH_OWNERSHIP - for each declared path (``--paths a b c``), verify no
     OTHER active spawn lease / agent_tasks row claims it. Sources:
     ``D:/QM/strategy_farm/state/farm_state.sqlite`` (env
     ``QM_AGENT_FARM_STATE_DB`` overrides; required in tests) - spawn_leases
     (expires_at in the future; unparseable expiry counts as active = fail
     closed) joined to agent_tasks for the claimed artifact_path, and
     agent_tasks rows with state in TODO/IN_PROGRESS/REVIEW. Overlap =
     declared path is boundary-prefix-related to a claimed path. Prefix
     overlaps are findings (reported, non-fatal); a direct collision
     (normalized paths equal, owned by another task) is a hard failure.

Exit codes: 0 = PASS (one PASS json line including branch/head/base/
is_descendant/lease_scan counts); 2 = any hard check failed - prints exactly
one line containing ``AGENT_WORKTREE_BASE_INVALID`` followed by compact json
``{check, detail:{task, worktree, branch, head, base, stale_by, collisions}}``.

Read-only: never edits git state, never resets, never rebases, never fetches,
opens the sqlite DB in read-only mode.
"""

from __future__ import annotations

import argparse
import json
import os
import posixpath
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

TOOL = "agent_worktree_preflight"
TOOL_VERSION = 1

DEFAULT_EXPECTED_BRANCH = "agents/board-advisor"
DEFAULT_EXPECTED_REPO_PATH = "C:/QM/repo"
DEFAULT_FARM_STATE_DB = "D:/QM/strategy_farm/state/farm_state.sqlite"

FAIL_TOKEN = "AGENT_WORKTREE_BASE_INVALID"

CHECK_ORDER = [
    "EXPECTED_BASE_BRANCH",
    "EXPECTED_REPO_PATH",
    "NOT_STALE_MAIN",
    "BASE_DESCENDANT",
    "PATH_OWNERSHIP",
]

ACTIVE_TASK_STATES = ("TODO", "IN_PROGRESS", "REVIEW")
LEASE_KEY_PREFIX = "agent_task:"


def _git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed rc={proc.returncode}: {proc.stderr.strip()}"
        )
    return proc.stdout.strip()


def _norm_path(p: str) -> str:
    p = p.replace("\\", "/").strip()
    p = posixpath.normpath(p)
    if p == ".":
        p = ""
    return p.rstrip("/").casefold()


def _is_boundary_prefix(prefix: str, whole: str) -> bool:
    return whole == prefix or whole.startswith(prefix + "/")


def _paths_overlap(a: str, b: str) -> bool:
    return _is_boundary_prefix(a, b) or _is_boundary_prefix(b, a)


def _is_abs(p: str) -> bool:
    return (len(p) > 2 and p[1] == ":" and p[2] == "/" and p[0].isalpha()) or p.startswith(
        "/"
    )


def _resolve_declared(path: str, worktree: str) -> str:
    p = path.replace("\\", "/").strip()
    if not _is_abs(p):
        p = posixpath.join(_norm_path(worktree), _norm_path(p))
    return _norm_path(p)


def _is_forbidden_worktree_dir(norm_root: str) -> bool:
    segs = norm_root.split("/")
    pairs = {(segs[i], segs[i + 1]) for i in range(len(segs) - 1)}
    return bool(pairs & {("qm", "worktrees"), (".claude", "worktrees")})


def _parse_iso(dt: str) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(dt.strip())
    except (ValueError, AttributeError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def _lease_is_active(expires_at: str, now: datetime) -> bool:
    parsed = _parse_iso(expires_at)
    if parsed is None:
        return True  # fail closed: unparseable expiry counts as active
    return parsed > now


def _task_id_from_lease_key(task_key: str) -> str:
    if task_key.startswith(LEASE_KEY_PREFIX):
        return task_key[len(LEASE_KEY_PREFIX) :]
    return task_key


def _collect_claims(db_path: str, now: datetime) -> tuple[list[dict], dict]:
    """Return (claims, scan_counts). Read-only; claims are fail-closed."""
    counts = {
        "db": db_path,
        "active_leases": 0,
        "active_tasks": 0,
        "claims": 0,
        "collisions": 0,
        "findings": 0,
    }
    uri = f"file:{db_path}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    try:
        rows = conn.execute(
            "SELECT id, state, artifact_path, assigned_agent FROM agent_tasks"
        ).fetchall()
        task_paths = {}
        for task_id, state, artifact_path, assigned_agent in rows:
            if artifact_path:
                task_paths[task_id] = (artifact_path, assigned_agent)
            if state in ACTIVE_TASK_STATES and artifact_path:
                counts["active_tasks"] += 1

        claims: dict[tuple[str, str], dict] = {}
        for task_id, state, artifact_path, assigned_agent in rows:
            if state not in ACTIVE_TASK_STATES or not artifact_path:
                continue
            key = (_norm_path(artifact_path), task_id)
            claims[key] = {
                "path": artifact_path,
                "owner": assigned_agent or "unassigned",
                "task": task_id,
                "source": "agent_tasks",
            }

        lease_rows = conn.execute(
            "SELECT task_key, agent_id, expires_at FROM spawn_leases"
        ).fetchall()
        for task_key, agent_id, expires_at in lease_rows:
            if not _lease_is_active(expires_at or "", now):
                continue
            counts["active_leases"] += 1
            task_id = _task_id_from_lease_key(task_key)
            mapped = task_paths.get(task_id)
            claimed_path = mapped[0] if mapped else None
            if not claimed_path:
                continue  # lease with no mappable artifact_path claims no path
            # Same (path, task) as an agent_tasks claim: dedupe, keep first.
            key = (_norm_path(claimed_path), task_id)
            claims.setdefault(
                key,
                {
                    "path": claimed_path,
                    "owner": agent_id or "unassigned",
                    "task": task_id,
                    "source": "spawn_leases",
                },
            )
    finally:
        conn.close()

    counts["claims"] = len(claims)
    return list(claims.values()), counts


def _scan_ownership(
    declared: list[str],
    worktree: str,
    db_path: str,
    task_id: str | None,
    now: datetime,
) -> tuple[bool, dict, list[dict], dict]:
    """PATH_OWNERSHIP. Findings for prefix overlap, hard fail on collision."""
    claims, counts = _collect_claims(db_path, now)
    collisions: list[dict] = []
    findings: list[dict] = []
    self_ids = {t for t in (task_id, f"{LEASE_KEY_PREFIX}{task_id}") if t}
    for raw in declared:
        resolved = _resolve_declared(raw, worktree)
        for claim in claims:
            if claim["task"] in self_ids:
                continue
            claimed_norm = _norm_path(claim["path"])
            if claimed_norm == resolved:
                collisions.append(
                    {
                        "declared": raw,
                        "resolved": resolved,
                        "claimed": claim["path"],
                        "owner": claim["owner"],
                        "task": claim["task"],
                        "source": claim["source"],
                    }
                )
            elif _paths_overlap(resolved, claimed_norm):
                findings.append(
                    {
                        "declared": raw,
                        "resolved": resolved,
                        "claimed": claim["path"],
                        "owner": claim["owner"],
                        "task": claim["task"],
                        "source": claim["source"],
                    }
                )
    counts["collisions"] = len(collisions)
    counts["findings"] = len(findings)
    detail = {"declared_paths": declared, "collisions": collisions, "findings": findings}
    return (len(collisions) == 0), detail, collisions, counts


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--repo", type=Path, default=None,
                        help="repo to inspect (default: cwd). Read-only.")
    parser.add_argument("--task-id", default=None,
                        help="calling task id; recorded in output and excluded from collision reporting")
    parser.add_argument("--paths", nargs="+", default=[],
                        help="paths this run intends to write (ownership scan)")
    parser.add_argument("--expected-branch", default=None,
                        help=f"canonical branch (default env QM_AGENT_EXPECTED_BRANCH or {DEFAULT_EXPECTED_BRANCH})")
    parser.add_argument("--expected-repo-path", default=None,
                        help=f"canonical repo root (default env QM_AGENT_EXPECTED_REPO_PATH or {DEFAULT_EXPECTED_REPO_PATH})")
    parser.add_argument("--base-commit", default=None,
                        help="orchestration base commit (default env QM_AGENT_BASE_COMMIT or "
                             "tip of origin/<expected-branch> as fetched locally; never fetched here)")
    parser.add_argument("--allow-worktree", action="append", default=[], metavar="PATH=BRANCH",
                        help="exact authorized worktree path=branch pair (repeatable)")
    parser.add_argument("--farm-state-db", default=None,
                        help=f"farm state sqlite (default env QM_AGENT_FARM_STATE_DB or {DEFAULT_FARM_STATE_DB})")
    args = parser.parse_args()

    expected_branch = args.expected_branch or os.environ.get(
        "QM_AGENT_EXPECTED_BRANCH", DEFAULT_EXPECTED_BRANCH
    )
    expected_repo = args.expected_repo_path or os.environ.get(
        "QM_AGENT_EXPECTED_REPO_PATH", DEFAULT_EXPECTED_REPO_PATH
    )
    base_commit = args.base_commit or os.environ.get("QM_AGENT_BASE_COMMIT")
    db_path = args.farm_state_db or os.environ.get(
        "QM_AGENT_FARM_STATE_DB", DEFAULT_FARM_STATE_DB
    )

    findings: dict[str, dict] = {}
    worktree = ""
    branch = ""
    head = ""
    base = ""
    stale_by: int | None = None

    def _fail_line(check, failed, collisions=None):
        detail = {
            "task": args.task_id,
            "worktree": worktree or None,
            "branch": branch or None,
            "head": head or None,
            "base": base or None,
            "stale_by": stale_by,
            "collisions": collisions or [],
        }
        payload = {"check": check, "failed_checks": failed, "detail": detail}
        print(f"{FAIL_TOKEN} {json.dumps(payload, sort_keys=True, separators=(',', ':'))}")
        return 2

    try:
        repo = (args.repo or Path.cwd()).resolve()
        worktree = _git(repo, "rev-parse", "--show-toplevel")
        branch = _git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        head = _git(repo, "rev-parse", "HEAD")
    except Exception:  # unborn HEAD, missing git, etc.
        return _fail_line("INTERNAL_ERROR", ["INTERNAL_ERROR"])

    resolved_base = base_commit
    if not resolved_base:
        try:
            resolved_base = _git(repo, "rev-parse", f"origin/{expected_branch}")
        except Exception:
            resolved_base = None
    base = resolved_base

    # 1. EXPECTED_BASE_BRANCH
    findings["EXPECTED_BASE_BRANCH"] = {
        "ok": branch == expected_branch,
        "detail": {"branch": branch, "expected": expected_branch},
    }

    # 2. EXPECTED_REPO_PATH
    norm_root = _norm_path(worktree)
    norm_expected = _norm_path(expected_repo)
    allowed_pairs = []
    for raw in args.allow_worktree:
        if "=" not in raw:
            findings["EXPECTED_REPO_PATH"] = {
                "ok": False,
                "detail": {"reason": f"malformed --allow-worktree (want PATH=BRANCH): {raw}"},
            }
            break
        p, b = raw.split("=", 1)
        allowed_pairs.append((_norm_path(p), b))
    else:
        pair_match = any(p == norm_root and b == branch for p, b in allowed_pairs)
        in_repo = norm_root == norm_expected
        forbidden_dir = _is_forbidden_worktree_dir(norm_root)
        ok = in_repo or (pair_match and not in_repo)
        if forbidden_dir and not pair_match:
            ok = False
        findings["EXPECTED_REPO_PATH"] = {
            "ok": ok,
            "detail": {
                "worktree": worktree,
                "expected": expected_repo,
                "in_canonical_repo": in_repo,
                "forbidden_worktree_dir": forbidden_dir,
                "allowed_pair_match": pair_match,
            },
        }

    # 3. NOT_STALE_MAIN (fail closed; never auto-reset/rebase)
    findings["NOT_STALE_MAIN"] = {
        "ok": branch != "main",
        "detail": {"branch": branch},
    }
    if branch == "main":
        try:
            origin_main = _git(repo, "rev-parse", "origin/main")
            stale_by = int(_git(repo, "rev-list", "--count", f"HEAD..{origin_main}"))
        except Exception:
            stale_by = None

    # 4. BASE_DESCENDANT
    if not base:
        findings["BASE_DESCENDANT"] = {
            "ok": False,
            "detail": {"reason": f"base commit unresolved (origin/{expected_branch} missing; "
                                 f"set QM_AGENT_BASE_COMMIT); no fetch performed by this tool"},
        }
    else:
        proc = subprocess.run(
            ["git", "-C", str(repo), "merge-base", "--is-ancestor", base, "HEAD"],
            capture_output=True,
        )
        is_descendant = proc.returncode == 0
        if not is_descendant:
            try:
                stale_by = int(_git(repo, "rev-list", "--count", f"HEAD..{base}"))
            except Exception:
                stale_by = None
        findings["BASE_DESCENDANT"] = {
            "ok": is_descendant,
            "detail": {"head": head, "base": base, "is_descendant": is_descendant,
                       "stale_by": stale_by},
        }

    # 5. PATH_OWNERSHIP
    ownership_collisions: list[dict] = []
    scan_counts: dict = {}
    try:
        ok, detail, ownership_collisions, scan_counts = _scan_ownership(
            args.paths, worktree, db_path, args.task_id, datetime.now(timezone.utc)
        )
        findings["PATH_OWNERSHIP"] = {"ok": ok, "detail": detail}
    except Exception as exc:
        findings["PATH_OWNERSHIP"] = {
            "ok": False,
            "detail": {"reason": f"ownership scan unavailable (fail closed): "
                                 f"{type(exc).__name__}: {exc}", "db": db_path},
        }

    failed = [name for name in CHECK_ORDER if not findings[name]["ok"]]
    if failed:
        primary = failed[0]
        cols = ownership_collisions if primary == "PATH_OWNERSHIP" else []
        return _fail_line(primary, failed, cols)

    result = {
        "status": "PASS",
        "tool": TOOL,
        "tool_version": TOOL_VERSION,
        "task_id": args.task_id,
        "worktree": worktree,
        "branch": branch,
        "head": head,
        "base": base,
        "is_descendant": findings["BASE_DESCENDANT"]["detail"].get("is_descendant"),
        "lease_scan": scan_counts,
        "checks": [
            {"check": name, **findings[name]} for name in CHECK_ORDER
        ],
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
