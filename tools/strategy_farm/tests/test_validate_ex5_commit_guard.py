"""Tests for the fail-closed EX5 commit guard.

Covers the two acceptance cases from router task
b63eaead-7890-4be4-b8e7-0edea3fe6a85 / 0faad91e-2f5a-4401-ab77-7b3141a88f1b:
(1) a staged .ex5 change with no governed COMPILE_EA receipt is refused,
(2) a staged .ex5 change bound to a done/COMPILE_OK receipt passes.
"""

from __future__ import annotations

import hashlib
import sqlite3
import subprocess
from pathlib import Path

import pytest

import validate_ex5_commit_guard as guard

EA_LABEL = "QM5_99999_unit-test-ea"


def _git(*args: str, cwd: Path) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def _init_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git("init", "-q", cwd=repo)
    _git("config", "user.email", "test@example.com", cwd=repo)
    _git("config", "user.name", "Test", cwd=repo)
    _git("config", "core.autocrlf", "false", cwd=repo)
    return repo


def _stage_ea_files(repo: Path, ex5_bytes: bytes, mq5_bytes: bytes) -> Path:
    ea_dir = repo / "framework" / "EAs" / EA_LABEL
    ea_dir.mkdir(parents=True, exist_ok=True)
    ex5_path = ea_dir / f"{EA_LABEL}.ex5"
    mq5_path = ea_dir / f"{EA_LABEL}.mq5"
    ex5_path.write_bytes(ex5_bytes)
    mq5_path.write_bytes(mq5_bytes)
    _git(
        "add",
        "--",
        str(ex5_path.relative_to(repo)),
        str(mq5_path.relative_to(repo)),
        cwd=repo,
    )
    return ex5_path


def _init_state_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "farm_state.sqlite"
    conn = sqlite3.connect(db_path)
    try:
        conn.execute(
            "CREATE TABLE work_items ("
            "id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, "
            "status TEXT, verdict TEXT, ex5_sha256 TEXT, mq5_sha256 TEXT, "
            "updated_at TEXT)"
        )
        conn.commit()
    finally:
        conn.close()
    return db_path


def _insert_receipt(
    db_path: Path,
    *,
    work_item_id: str,
    ea_id: str,
    ex5_sha256: str,
    mq5_sha256: str,
    status: str = "done",
    verdict: str = "COMPILE_OK",
) -> None:
    conn = sqlite3.connect(db_path)
    try:
        conn.execute(
            "INSERT INTO work_items "
            "(id, kind, phase, ea_id, status, verdict, ex5_sha256, mq5_sha256, updated_at) "
            "VALUES (?, 'compile', 'COMPILE_EA', ?, ?, ?, ?, ?, '2026-08-24T00:00:00Z')",
            (work_item_id, ea_id, status, verdict, ex5_sha256, mq5_sha256),
        )
        conn.commit()
    finally:
        conn.close()


def test_rejects_ex5_change_without_governed_receipt(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    _stage_ea_files(repo, ex5_bytes=b"ad-hoc-compiled-bytes", mq5_bytes=b"source v1")

    report = guard.evaluate(repo, db_path)

    assert report["ok"] is False
    (entry,) = report["changes"]
    assert entry["ok"] is False
    assert entry["reason"] == "NO_GOVERNED_COMPILE_EA_RECEIPT"
    assert guard.main(["--repo-root", str(repo), "--db-path", str(db_path)]) == 1


def test_accepts_ex5_change_with_matching_governed_receipt(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    ex5_bytes = b"governed-compiled-bytes"
    mq5_bytes = b"source v1"
    _stage_ea_files(repo, ex5_bytes=ex5_bytes, mq5_bytes=mq5_bytes)
    _insert_receipt(
        db_path,
        work_item_id="wi-1",
        ea_id="QM5_99999",
        ex5_sha256=hashlib.sha256(ex5_bytes).hexdigest(),
        mq5_sha256=hashlib.sha256(mq5_bytes).hexdigest(),
    )

    report = guard.evaluate(repo, db_path)

    assert report["ok"] is True
    (entry,) = report["changes"]
    assert entry["ok"] is True
    assert entry["receipt_work_item_id"] == "wi-1"
    assert guard.main(["--repo-root", str(repo), "--db-path", str(db_path)]) == 0


def test_rejects_when_receipt_binds_a_different_source_hash(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    ex5_bytes = b"governed-compiled-bytes"
    _stage_ea_files(repo, ex5_bytes=ex5_bytes, mq5_bytes=b"source v2 (changed after compile)")
    _insert_receipt(
        db_path,
        work_item_id="wi-1",
        ea_id="QM5_99999",
        ex5_sha256=hashlib.sha256(ex5_bytes).hexdigest(),
        mq5_sha256=hashlib.sha256(b"source v1").hexdigest(),
    )

    report = guard.evaluate(repo, db_path)

    assert report["ok"] is False
    assert report["changes"][0]["reason"] == "NO_GOVERNED_COMPILE_EA_RECEIPT"


def test_rejects_when_receipt_status_is_not_done(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    ex5_bytes = b"pending-compile-bytes"
    mq5_bytes = b"source v1"
    _stage_ea_files(repo, ex5_bytes=ex5_bytes, mq5_bytes=mq5_bytes)
    _insert_receipt(
        db_path,
        work_item_id="wi-1",
        ea_id="QM5_99999",
        ex5_sha256=hashlib.sha256(ex5_bytes).hexdigest(),
        mq5_sha256=hashlib.sha256(mq5_bytes).hexdigest(),
        status="active",
        verdict="",
    )

    report = guard.evaluate(repo, db_path)

    assert report["ok"] is False


def test_no_staged_ex5_changes_passes_clean(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    (repo / "README.md").write_text("hello\n", encoding="utf-8")
    _git("add", "README.md", cwd=repo)

    report = guard.evaluate(repo, db_path)

    assert report == {"ok": True, "changes": []}


def test_unparseable_ea_label_is_rejected(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    db_path = _init_state_db(tmp_path)
    bad_dir = repo / "framework" / "EAs" / "not-a-governed-label"
    bad_dir.mkdir(parents=True)
    ex5_path = bad_dir / "not-a-governed-label.ex5"
    ex5_path.write_bytes(b"whatever")
    _git("add", "--", str(ex5_path.relative_to(repo)), cwd=repo)

    report = guard.evaluate(repo, db_path)

    assert report["ok"] is False
    assert report["changes"][0]["reason"] == "EA_LABEL_UNPARSEABLE"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q"]))
