"""The worktree clean task must commit, not revert, a rebuilt .ex5 that a
COMPILE_OK receipt binds (2026-09-20, QM5_41347 census incident)."""
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import run_worktree_clean_task as task  # noqa: E402


def _db(tmp_path, ea_id, sha):
    db = tmp_path / "farm_state.sqlite"
    con = sqlite3.connect(db)
    con.execute("CREATE TABLE work_items (id TEXT, kind TEXT, phase TEXT, ea_id TEXT, status TEXT, verdict TEXT, ex5_sha256 TEXT)")
    con.execute("INSERT INTO work_items VALUES ('r1','compile','COMPILE_EA',?,'done','COMPILE_OK',?)", (ea_id, sha))
    con.commit(); con.close()
    return db


def test_receipted_modified_ex5_is_selected_and_unreceipted_is_not(tmp_path):
    repo = tmp_path / "repo"
    d = repo / "framework" / "EAs" / "QM5_41347_cs-ichi-cloud-opt"
    d.mkdir(parents=True)
    ex5 = d / "QM5_41347_cs-ichi-cloud-opt.ex5"
    ex5.write_bytes(b"binary-v2")
    sha = task._sha256_file(ex5)
    db = _db(tmp_path, "QM5_41347", sha)
    status = [" M framework/EAs/QM5_41347_cs-ichi-cloud-opt/QM5_41347_cs-ichi-cloud-opt.ex5"]
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == [
        "framework/EAs/QM5_41347_cs-ichi-cloud-opt/QM5_41347_cs-ichi-cloud-opt.ex5"
    ]
    ex5.write_bytes(b"binary-unreceipted")
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == []
    # untracked and non-ex5 lines are ignored
    assert task._receipted_tracked_ex5(["?? framework/EAs/QM5_1_x/QM5_1_x.ex5", " M tools/x.py"], repo_root=repo, db_path=db) == []
