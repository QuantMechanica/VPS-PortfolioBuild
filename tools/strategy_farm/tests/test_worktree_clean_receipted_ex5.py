"""The worktree clean task must commit, not revert, a rebuilt .ex5 that a
COMPILE_OK receipt binds (2026-09-20, QM5_41347 census incident)."""
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import run_worktree_clean_task as task  # noqa: E402


def _db(tmp_path, ea_id, sha, mq5_sha=None):
    db = tmp_path / "farm_state.sqlite"
    con = sqlite3.connect(db)
    con.execute("CREATE TABLE work_items (id TEXT, kind TEXT, phase TEXT, ea_id TEXT, status TEXT, verdict TEXT, ex5_sha256 TEXT, mq5_sha256 TEXT)")
    con.execute("INSERT INTO work_items VALUES ('r1','compile','COMPILE_EA',?,'done','COMPILE_OK',?,?)", (ea_id, sha, mq5_sha))
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


def test_untracked_receipted_ex5_is_selected(tmp_path):
    """First compile of a tracked EA dir: the new binary is untracked ('??') and must be committed too."""
    repo = tmp_path / "repo"
    d = repo / "framework" / "EAs" / "QM5_39004_forexfactory-thv-cobra-trix-scalper"
    d.mkdir(parents=True)
    ex5 = d / "QM5_39004_forexfactory-thv-cobra-trix-scalper.ex5"
    ex5.write_bytes(b"first-binary")
    db = _db(tmp_path, "QM5_39004", task._sha256_file(ex5))
    status = ["?? framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper/QM5_39004_forexfactory-thv-cobra-trix-scalper.ex5"]
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == [
        "framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper/QM5_39004_forexfactory-thv-cobra-trix-scalper.ex5"
    ]
    # an untracked binary WITHOUT a receipt is still left alone
    ex5.write_bytes(b"unreceipted")
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == []


def test_binary_whose_source_changed_after_the_receipt_is_not_staged(tmp_path):
    """Guard rule: receipt must bind ex5 AND mq5 digests (QM5_12351 case, 2026-09-20)."""
    repo = tmp_path / "repo"
    d = repo / "framework" / "EAs" / "QM5_12351_alp-ema12-26"
    d.mkdir(parents=True)
    ex5 = d / "QM5_12351_alp-ema12-26.ex5"; ex5.write_bytes(b"binary")
    mq5 = d / "QM5_12351_alp-ema12-26.mq5"; mq5.write_bytes(b"source-v1")
    db = _db(tmp_path, "QM5_12351", task._sha256_file(ex5), task._sha256_file(mq5))
    status = ["?? framework/EAs/QM5_12351_alp-ema12-26/QM5_12351_alp-ema12-26.ex5"]
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == [
        "framework/EAs/QM5_12351_alp-ema12-26/QM5_12351_alp-ema12-26.ex5"]
    mq5.write_bytes(b"source-v2-edited-after-receipt")
    assert task._receipted_tracked_ex5(status, repo_root=repo, db_path=db) == []
