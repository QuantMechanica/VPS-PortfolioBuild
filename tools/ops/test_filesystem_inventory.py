"""Unit tests for tools/ops/filesystem_inventory.py (read-only inventory).

Covers:
  * path-prefix classification (most-specific-first wins),
  * the fail-safe: unknown -> review, never keep / never_touch / delete,
  * no-descend flags for T_Live and factory terminals,
  * backup restore-status sidecar detection (existence only, no hashing),
  * per-root entry-cap truncation is reported, not silent.
"""
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(__file__))
import filesystem_inventory as fi  # noqa: E402


# --- classification: known prefixes ------------------------------------------
@pytest.mark.parametrize("path,cls,owner,ret", [
    ("D:\\QM\\strategy_farm\\state", fi.CLASS_ACTIVE_RUNTIME, fi.OWNER_FACTORY, fi.RET_KEEP),
    ("D:\\QM\\strategy_farm\\state\\farm_state.sqlite", fi.CLASS_ACTIVE_RUNTIME,
     fi.OWNER_FACTORY, fi.RET_KEEP),
    ("D:\\QM\\reports\\canonical\\x", fi.CLASS_CANONICAL_EVIDENCE, fi.OWNER_PIPELINE, fi.RET_KEEP),
    ("D:\\QM\\reports\\QM5_10706", fi.CLASS_GENERATED_REPORT, fi.OWNER_PIPELINE, fi.RET_REVIEW),
    ("G:\\My Drive\\QM_Backups", fi.CLASS_BACKUP, fi.OWNER_OPS, fi.RET_KEEP),
    ("D:\\QM\\backups\\x", fi.CLASS_BACKUP, fi.OWNER_OPS, fi.RET_ARCHIVE),
    ("C:\\QM\\deploy\\rel1", fi.CLASS_DEPLOY, fi.OWNER_OPS, fi.RET_KEEP),
    ("C:\\QM\\repo\\tools", fi.CLASS_ACTIVE_RUNTIME, fi.OWNER_OPS, fi.RET_KEEP),
    ("C:\\QM\\scratch\\z", fi.CLASS_SCRATCH, fi.OWNER_OPS, fi.RET_REVIEW),
    ("D:\\QM\\data\\news_calendar", fi.CLASS_ACTIVE_RUNTIME, fi.OWNER_PIPELINE, fi.RET_KEEP),
])
def test_classify_known(path, cls, owner, ret):
    c = fi.classify(path)
    assert c.cls == cls
    assert c.owner == owner
    assert c.retention == ret


# --- most-specific-first: state/backups beats state --------------------------
def test_most_specific_prefix_wins():
    inner = fi.classify("D:\\QM\\strategy_farm\\state\\backups\\snap.sqlite")
    assert inner.cls == fi.CLASS_BACKUP
    assert inner.matched_prefix == "d:/qm/strategy_farm/state/backups"
    outer = fi.classify("D:\\QM\\strategy_farm\\state\\farm_state.sqlite")
    assert outer.cls == fi.CLASS_ACTIVE_RUNTIME
    assert outer.matched_prefix == "d:/qm/strategy_farm/state"


# --- fail-safe: unknown -> REVIEW, never keep/never_touch --------------------
def test_unknown_falls_to_review_not_cleanup():
    c = fi.classify("D:\\QM\\some_unmapped_dir\\stuff")
    assert c.cls == fi.CLASS_UNKNOWN
    assert c.owner == fi.OWNER_UNKNOWN
    # the crux: an unknown dir is flagged for review, NOT trusted (keep),
    # NOT frozen (never_touch), and there is no auto-delete value at all.
    assert c.retention == fi.RET_REVIEW
    assert c.retention != fi.RET_KEEP
    assert c.retention != fi.RET_NEVER_TOUCH


def test_retention_enum_has_no_delete_value():
    # By construction there is no 'delete'/'cleanup_now' retention -- the most
    # aggressive suggestion the tool can emit is a review candidate.
    all_ret = {fi.RET_KEEP, fi.RET_ARCHIVE, fi.RET_REVIEW, fi.RET_NEVER_TOUCH}
    assert "delete" not in all_ret
    assert all("delete" not in r for r in all_ret)


# --- no-descend classifications ----------------------------------------------
def test_tlive_is_never_touch_and_no_descend():
    c = fi.classify("C:\\QM\\mt5\\T_Live")
    assert c.retention == fi.RET_NEVER_TOUCH
    assert c.owner == fi.OWNER_LIVE
    assert c.no_descend_reason is not None


def test_factory_terminals_no_descend():
    for p in ("D:\\QM\\mt5\\T1", "D:\\QM\\mt5\\T10", "D:\\QM\\mt5\\DEV1",
              "D:\\QM\\mt5\\FTMO_STREAM1"):
        c = fi.classify(p)
        assert c.no_descend_reason is not None, p
        assert c.retention == fi.RET_NEVER_TOUCH, p


# --- norm helper -------------------------------------------------------------
def test_norm_backslash_and_case():
    assert fi.norm("C:\\QM\\Repo\\Tools") == "c:/qm/repo/tools"
    assert fi.norm("d:/qm/data/") == "d:/qm/data"


# --- backup restore-status: sidecar existence, no hashing --------------------
def test_backup_restore_status_detects_sidecar(tmp_path):
    zip_path = tmp_path / "hyonix_backup.zip"
    zip_path.write_bytes(b"PK\x03\x04fake")
    (tmp_path / "hyonix_backup.zip.sha256").write_text("deadbeef  hyonix_backup.zip")
    # an archive WITHOUT a sidecar
    (tmp_path / "orphan.bundle").write_bytes(b"bundle")
    rs = fi.scan_backup_restore_status(str(tmp_path))
    by_name = {a["name"]: a for a in rs["archives"]}
    assert by_name["hyonix_backup.zip"]["sidecar_present"] is True
    assert by_name["orphan.bundle"]["sidecar_present"] is False
    assert rs["all_have_sidecar"] is False
    assert rs["archive_count"] == 2
    assert rs["newest_backup_utc"] is not None


def test_backup_restore_status_all_present(tmp_path):
    (tmp_path / "b.zip").write_bytes(b"x")
    (tmp_path / "b.zip.sha256").write_text("h  b.zip")
    rs = fi.scan_backup_restore_status(str(tmp_path))
    assert rs["all_have_sidecar"] is True


# --- truncation is reported, not silent --------------------------------------
def test_truncation_note_emitted(tmp_path):
    # create more entries than a tiny cap
    for i in range(20):
        (tmp_path / f"f{i}.txt").write_text("x")
    w = fi._Walker(str(tmp_path), report_depth=4, max_entries=5)
    res = w.run()
    assert res.truncated is True
    assert res.truncation_note is not None
    assert "TRUNCATED" in res.truncation_note
    assert res.entries_scanned <= 5 + 1  # cap respected (small slack)


def test_no_truncation_when_under_cap(tmp_path):
    (tmp_path / "a.txt").write_text("x")
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "b.txt").write_text("yy")
    w = fi._Walker(str(tmp_path), report_depth=4, max_entries=1000)
    res = w.run()
    assert res.truncated is False
    assert res.truncation_note is None
    # root node aggregates both files
    root_node = next(n for n in res.nodes if fi.norm(n.path) == fi.norm(str(tmp_path)))
    assert root_node.file_count == 2
    assert root_node.size_bytes == 3


# --- report-depth limits emitted nodes but not aggregation -------------------
def test_report_depth_limits_emitted_nodes(tmp_path):
    deep = tmp_path / "a" / "b" / "c" / "d"
    deep.mkdir(parents=True)
    (deep / "leaf.txt").write_text("zzzzz")  # 5 bytes at depth 4
    w = fi._Walker(str(tmp_path), report_depth=1, max_entries=1000)
    res = w.run()
    depths = {n.depth for n in res.nodes}
    assert max(depths) <= 1
    # depth-0 root still counts the deep leaf's bytes
    root_node = next(n for n in res.nodes if n.depth == 0)
    assert root_node.size_bytes == 5
    assert root_node.file_count == 1


def test_run_inventory_missing_root_marked():
    res = fi.run_inventory(["D:\\QM\\definitely_missing_xyz"], 3, 1000)
    assert res[0].exists is False
    assert res[0].nodes == []
