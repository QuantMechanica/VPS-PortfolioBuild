"""Hermetic tests for agent_worktree_preflight.

Temp git repos are built via subprocess (init / branches / commits); the farm
state DB is a tmp sqlite created here; all canonical values arrive via env
overrides or CLI flags. No network, no fetch, no writes to the real repo.
"""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

TOOL = Path(__file__).resolve().parents[1] / "agent_worktree_preflight.py"
FAIL_TOKEN = "AGENT_WORKTREE_BASE_INVALID"

SCHEMA = """
CREATE TABLE spawn_leases (
    task_key TEXT PRIMARY KEY, agent_id TEXT NOT NULL,
    acquired_at TEXT NOT NULL, expires_at TEXT NOT NULL, owner_token TEXT,
    owner_pid INTEGER, owner_host TEXT, renewed_at TEXT);
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY, task_type TEXT NOT NULL, state TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 50, required_capabilities_json TEXT NOT NULL,
    assigned_agent TEXT, budget_class TEXT NOT NULL DEFAULT 'standard',
    parent_id TEXT, artifact_path TEXT, verdict TEXT,
    payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
    required_skills_json TEXT NOT NULL DEFAULT '[]');
"""


def _git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True
    )
    assert proc.returncode == 0, f"git {' '.join(args)}: {proc.stderr}"
    return proc.stdout.strip()


def _commit(repo: Path, name: str) -> str:
    (repo / f"{name}.txt").write_text(f"{name}\n")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", name)
    return _git(repo, "rev-parse", "HEAD")


@pytest.fixture
def farm_db(tmp_path: Path) -> Path:
    db = tmp_path / "farm_state.sqlite"
    conn = sqlite3.connect(db)
    conn.executescript(SCHEMA)
    conn.close()
    return db


def _make_repo(tmp_path: Path, name: str = "repo") -> Path:
    repo = tmp_path / name
    repo.mkdir(parents=True)
    _git(repo, "init", "-b", "main")
    _git(repo, "config", "user.email", "preflight@test")
    _git(repo, "config", "user.name", "preflight-test")
    _commit(repo, "seed")
    return repo


def _make_canonical(tmp_path: Path, farm_db: Path, name: str = "repo"):
    """Repo shaped like the canonical orchestration checkout."""
    repo = _make_repo(tmp_path, name)
    _git(repo, "branch", "agents/board-advisor")
    _git(repo, "checkout", "agents/board-advisor")
    tip = _commit(repo, "board-tip")
    _git(repo, "update-ref", "refs/remotes/origin/agents/board-advisor", tip)
    env = _env(repo, farm_db)
    return repo, tip, env


def _env(repo: Path, farm_db: Path, **extra: str) -> dict:
    env = os.environ.copy()
    env["QM_AGENT_EXPECTED_REPO_PATH"] = str(repo)
    env["QM_AGENT_FARM_STATE_DB"] = str(farm_db)
    env.update(extra)
    return env


def _run(repo: Path, env: dict, *argv: str):
    proc = subprocess.run(
        [sys.executable, str(TOOL), "--repo", str(repo), *argv],
        capture_output=True,
        text=True,
        env=env,
    )
    return proc


def _fail_payload(proc) -> dict:
    assert proc.returncode == 2, proc.stdout + proc.stderr
    lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
    assert len(lines) == 1, f"expected exactly one output line, got {lines!r}"
    assert lines[0].startswith(FAIL_TOKEN)
    return json.loads(lines[0][len(FAIL_TOKEN):])


def _pass_payload(proc) -> dict:
    assert proc.returncode == 0, proc.stdout + proc.stderr
    return json.loads(proc.stdout.strip().splitlines()[-1])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _insert_claim(
    db: Path,
    task_id: str,
    artifact_path: str,
    *,
    state: str = "IN_PROGRESS",
    agent: str = "other-agent",
    lease_expiry: datetime | None = None,
) -> None:
    conn = sqlite3.connect(db)
    now = _now()
    conn.execute(
        "INSERT INTO agent_tasks (id, task_type, state, artifact_path, "
        "assigned_agent, required_capabilities_json, payload_json, "
        "created_at, updated_at) VALUES (?, 'ops_issue', ?, ?, ?, '[]', '{}', ?, ?)",
        (task_id, state, artifact_path, agent, now.isoformat(), now.isoformat()),
    )
    if lease_expiry is not None:
        conn.execute(
            "INSERT INTO spawn_leases (task_key, agent_id, acquired_at, expires_at) "
            "VALUES (?, ?, ?, ?)",
            (
                f"agent_task:{task_id}",
                agent,
                (now - timedelta(minutes=5)).isoformat(),
                lease_expiry.isoformat(),
            ),
        )
    conn.commit()
    conn.close()


def test_pass_on_canonical_shaped_repo(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    proc = _run(repo, env, "--task-id", "t-1", "--paths", "docs/ops/new_note.md")
    payload = _pass_payload(proc)
    assert payload["status"] == "PASS"
    assert payload["branch"] == "agents/board-advisor"
    assert payload["head"] == tip
    assert payload["base"] == tip
    assert payload["is_descendant"] is True
    assert payload["lease_scan"]["active_leases"] == 0
    assert payload["lease_scan"]["active_tasks"] == 0
    assert payload["lease_scan"]["claims"] == 0
    assert payload["lease_scan"]["collisions"] == 0


def test_fail_not_stale_main(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    _git(repo, "checkout", "main")
    proc = _run(repo, env, "--task-id", "t-2")
    payload = _fail_payload(proc)
    assert "NOT_STALE_MAIN" in payload["failed_checks"]
    assert payload["detail"]["branch"] == "main"
    assert payload["detail"]["head"]


def test_fail_when_head_behind_base(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    _git(repo, "reset", "--hard", "HEAD~1")
    proc = _run(repo, env, "--task-id", "t-3")
    payload = _fail_payload(proc)
    assert payload["check"] == "BASE_DESCENDANT"
    assert "BASE_DESCENDANT" in payload["failed_checks"]
    assert payload["detail"]["stale_by"] == 1
    assert payload["detail"]["base"] == tip


def test_pass_when_head_equals_base(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    env = _env(repo, farm_db, QM_AGENT_BASE_COMMIT=tip)
    proc = _run(repo, env, "--task-id", "t-4")
    payload = _pass_payload(proc)
    assert payload["base"] == tip
    assert payload["is_descendant"] is True


def test_fail_on_active_lease_path_collision(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    claimed = str(repo / "docs" / "ops" / "evidence" / "receipt_x.md")
    _insert_claim(farm_db, "task-owned-by-other", claimed,
                  lease_expiry=_now() + timedelta(minutes=30))
    proc = _run(repo, env, "--task-id", "t-5", "--paths", "docs/ops/evidence/receipt_x.md")
    payload = _fail_payload(proc)
    assert payload["check"] == "PATH_OWNERSHIP"
    assert "PATH_OWNERSHIP" in payload["failed_checks"]
    cols = payload["detail"]["collisions"]
    assert len(cols) == 1
    assert cols[0]["owner"] == "other-agent"
    assert cols[0]["task"] in (
        "task-owned-by-other",
        "agent_task:task-owned-by-other",
    )


def test_expired_lease_does_not_collide(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    claimed = str(repo / "docs" / "ops" / "receipt_y.md")
    # Task itself is no longer active (PASSED) and its lease is expired:
    # nothing actively claims the path.
    _insert_claim(farm_db, "expired-task", claimed, state="PASSED",
                  lease_expiry=_now() - timedelta(minutes=1))
    proc = _run(repo, env, "--task-id", "t-6", "--paths", "docs/ops/receipt_y.md")
    payload = _pass_payload(proc)
    assert payload["lease_scan"]["active_leases"] == 0


def test_prefix_overlap_is_finding_not_failure(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    claimed = str(repo / "docs" / "ops" / "evidence")
    _insert_claim(farm_db, "dir-owner", claimed,
                  lease_expiry=_now() + timedelta(minutes=30))
    proc = _run(
        repo, env, "--task-id", "t-7",
        "--paths", "docs/ops/evidence/receipt_z.md",
    )
    payload = _pass_payload(proc)
    assert payload["lease_scan"]["findings"] >= 1
    assert payload["lease_scan"]["collisions"] == 0


def test_allow_worktree_exact_pair_passes(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    wt = _make_repo(tmp_path / "wtroot", "kimi-feature")
    _git(wt, "branch", "agents/kimi-feature")
    _git(wt, "checkout", "agents/kimi-feature")
    wt_tip = _commit(wt, "wt-work")
    _git(wt, "update-ref", "refs/remotes/origin/agents/kimi-feature", wt_tip)
    env = _env(
        wt, farm_db,
        QM_AGENT_EXPECTED_BRANCH="agents/kimi-feature",
        QM_AGENT_EXPECTED_REPO_PATH=str(tmp_path / "decoy-canonical"),
    )
    proc = _run(
        wt, env,
        "--allow-worktree", f"{wt}=agents/kimi-feature",
        "--task-id", "t-8",
    )
    payload = _pass_payload(proc)
    assert payload["branch"] == "agents/kimi-feature"


def test_allow_worktree_wrong_branch_fails(tmp_path, farm_db):
    repo, tip, env = _make_canonical(tmp_path, farm_db)
    wt = _make_repo(tmp_path / "wtroot2", "kimi-feature")
    _git(wt, "branch", "agents/kimi-feature")
    _git(wt, "checkout", "agents/kimi-feature")
    wt_tip = _commit(wt, "wt-work")
    _git(wt, "update-ref", "refs/remotes/origin/agents/kimi-feature", wt_tip)
    env = _env(
        wt, farm_db,
        QM_AGENT_EXPECTED_BRANCH="agents/kimi-feature",
        QM_AGENT_EXPECTED_REPO_PATH=str(tmp_path / "decoy-canonical"),
    )
    proc = _run(
        wt, env,
        "--allow-worktree", f"{wt}=agents/some-other-branch",
        "--task-id", "t-9",
    )
    payload = _fail_payload(proc)
    assert "EXPECTED_REPO_PATH" in payload["failed_checks"]


def test_forbidden_worktree_dir_fails_closed_without_pair(tmp_path, farm_db):
    qm_wt = tmp_path / "QM" / "worktrees" / "shared-agent-wt"
    qm_wt.mkdir(parents=True)
    _git(qm_wt, "init", "-b", "agents/board-advisor")
    _git(qm_wt, "config", "user.email", "preflight@test")
    _git(qm_wt, "config", "user.name", "preflight-test")
    (qm_wt / "f.txt").write_text("x\n")
    _git(qm_wt, "add", ".")
    _git(qm_wt, "commit", "-m", "seed")
    wt_tip = _git(qm_wt, "rev-parse", "HEAD")
    _git(qm_wt, "update-ref", "refs/remotes/origin/agents/board-advisor", wt_tip)
    env = _env(qm_wt, farm_db, QM_AGENT_EXPECTED_REPO_PATH=str(tmp_path / "canonical"))
    proc = _run(qm_wt, env, "--task-id", "t-10")
    payload = _fail_payload(proc)
    assert "EXPECTED_REPO_PATH" in payload["failed_checks"]


def test_unresolvable_base_fails_closed(tmp_path, farm_db):
    repo = _make_repo(tmp_path, "repo-no-origin")
    _git(repo, "branch", "agents/board-advisor")
    _git(repo, "checkout", "agents/board-advisor")
    _commit(repo, "work")
    env = _env(repo, farm_db)
    proc = _run(repo, env, "--task-id", "t-11")
    payload = _fail_payload(proc)
    assert "BASE_DESCENDANT" in payload["failed_checks"]
    assert payload["detail"]["base"] is None
