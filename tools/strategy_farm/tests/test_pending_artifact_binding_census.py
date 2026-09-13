import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import pending_artifact_binding_census as census


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT,ea_id TEXT,symbol TEXT,phase TEXT,status TEXT,setfile_path TEXT,
          payload_json TEXT,created_at TEXT,updated_at TEXT,claimed_by TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT,hold_code TEXT,reason TEXT,active INTEGER,release_on_restart INTEGER);
        """
    )
    conn.commit()
    conn.close()


def _insert(
    db: Path,
    setfile: Path,
    payload: dict,
    *,
    hold: bool = False,
    ea_id: str = "QM5_1",
    row_id: str = "row-1",
    phase: str = "Q02",
) -> None:
    conn = sqlite3.connect(db)
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        (row_id, ea_id, "EURUSD.DWX", phase, "pending", str(setfile),
         json.dumps(payload), "2026-01-01", "2026-01-01", None),
    )
    if hold:
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?,?)",
            (row_id, "ARTIFACT_QUARANTINE", "test", 1, 0),
        )
    conn.commit()
    conn.close()


def _opt_census_setfile(tmp_path: Path, ea_dir_name: str) -> Path:
    """A WINSWEEP/OPT_CENSUS set file living OUTSIDE framework/EAs."""
    sets = (
        tmp_path / "artifacts" / "opt_census"
        / f"WINSWEEP_{ea_dir_name}_PRESCREEN" / "setfiles"
    )
    sets.mkdir(parents=True)
    setfile = sets / f"{ea_dir_name}_USDJPY.DWX_H1_2020_c06.set"
    setfile.write_bytes(b"A=1\n")
    return setfile


def test_full_census_classifies_missing_binary_and_reports_hold(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    setfile = sets / "demo.set"
    setfile.write_bytes(b"A=1\n")
    (ea / "QM5_1_demo.mq5").write_bytes(b"source\n")
    _db(db)
    _insert(db, setfile, {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": "a" * 64,
        "expected_mq5_sha256": _sha(b"source\n"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    }, hold=True)

    result = census.build_census(db, eas)

    assert result["drifted_rows"] == 1
    assert result["class_counts"] == {"MISSING": 1}
    assert result["rows"][0]["hold"]["hold_code"] == "ARTIFACT_QUARANTINE"
    assert result["rows"][0]["disposition"] == "WAIT_GOVERNED_ARTIFACT_RESTORE_OR_RECOMPILE"


def test_setfile_only_content_change_requires_append_only_successor(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    ex5 = ea / "QM5_1_demo.ex5"; ex5.write_bytes(b"binary")
    mq5 = ea / "QM5_1_demo.mq5"; mq5.write_bytes(b"source\n")
    setfile = sets / "demo.set"; setfile.write_bytes(b"A=2\n")
    _db(db)
    _insert(db, setfile, {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"source\n"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    })

    result = census.build_census(db, eas)

    assert result["mismatched_bindings"] == 1
    assert result["rows"][0]["findings"][0]["classification"] == "CONTENT_CHANGED"
    assert result["rows"][0]["disposition"] == "GOVERNED_APPEND_ONLY_SETFILE_SUCCESSOR_REQUIRED"


def test_external_matrix_setfile_uses_explicit_executable_binding(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    ea.mkdir(parents=True)
    ex5 = ea / "QM5_1_demo.ex5"; ex5.write_bytes(b"binary")
    mq5 = ea / "QM5_1_demo.mq5"; mq5.write_bytes(b"source")
    sets = tmp_path / "artifacts" / "DL089_PROGRAM" / "setfiles"
    sets.mkdir(parents=True)
    setfile = sets / "cell.set"; setfile.write_bytes(b"A=1\n")
    _db(db)
    _insert(db, setfile, {
        "expected_ex5_path": str(ex5), "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"source"), "expected_setfile_sha256": _sha(b"A=1\n"),
    })
    assert census.build_census(db, eas)["drifted_rows"] == 0
    ex5.write_bytes(b"changed")
    result = census.build_census(db, eas)
    assert result["class_counts"] == {"CONTENT_CHANGED": 1}
    assert result["rows"][0]["findings"][0]["path"] == str(ex5)
    assert result["rows"][0]["findings"][0]["derivation"] == "expected_path"


def test_opt_census_setfile_resolves_binary_by_ea_id(tmp_path: Path) -> None:
    # WINSWEEP/OPT_CENSUS cell: the set file lives OUTSIDE framework/EAs and the
    # payload carries only SHAs (no ea_dir_name, no expected_ex5_path). Resolving
    # by ea_id must find the real binary, so matching SHAs => no false MISSING.
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_41405_balke-clock-audit-opt"
    ea.mkdir(parents=True)
    (ea / f"{ea.name}.ex5").write_bytes(b"binary")
    (ea / f"{ea.name}.mq5").write_bytes(b"source")
    setfile = _opt_census_setfile(tmp_path, ea.name)
    _db(db)
    _insert(db, setfile, {
        "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"source"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    }, ea_id="QM5_41405", phase="OPT_CENSUS")

    result = census.build_census(db, eas)

    assert result["drifted_rows"] == 0
    assert result["mismatched_bindings"] == 0
    # The resolver reports the ea_id derivation and the real binary path.
    row = {"setfile_path": str(setfile), "ea_id": "QM5_41405"}
    paths = census.resolve_artifact_paths(row, {}, eas)
    assert paths["ex5"] == (ea / f"{ea.name}.ex5", "ea_id_resolution")
    assert paths["mq5"] == (ea / f"{ea.name}.mq5", "ea_id_resolution")
    assert paths["setfile"][1] == "work_item_setfile"


def test_content_changed_detected_via_ea_id_resolution(tmp_path: Path) -> None:
    # A rebuilt binary (SHA differs from the pinned payload) is still real drift.
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_41405_balke-clock-audit-opt"
    ea.mkdir(parents=True)
    (ea / f"{ea.name}.ex5").write_bytes(b"REBUILT-binary")
    (ea / f"{ea.name}.mq5").write_bytes(b"source")
    setfile = _opt_census_setfile(tmp_path, ea.name)
    _db(db)
    _insert(db, setfile, {
        "expected_ex5_sha256": _sha(b"binary"),  # stale pin vs disk
        "expected_mq5_sha256": _sha(b"source"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    }, ea_id="QM5_41405", phase="OPT_CENSUS")

    result = census.build_census(db, eas)

    assert result["class_counts"] == {"CONTENT_CHANGED": 1}
    finding = result["rows"][0]["findings"][0]
    assert finding["role"] == "ex5"
    assert finding["classification"] == "CONTENT_CHANGED"
    assert finding["derivation"] == "ea_id_resolution"
    assert finding["path"] == str(ea / f"{ea.name}.ex5")


def test_missing_binary_detected_via_ea_id_resolution(tmp_path: Path) -> None:
    # A genuinely absent ea_id binary must still be reported MISSING.
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_41405_balke-clock-audit-opt"
    ea.mkdir(parents=True)
    (ea / f"{ea.name}.mq5").write_bytes(b"source")  # only mq5 present
    setfile = _opt_census_setfile(tmp_path, ea.name)
    _db(db)
    _insert(db, setfile, {
        "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"source"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    }, ea_id="QM5_41405", phase="OPT_CENSUS")

    result = census.build_census(db, eas)

    assert result["class_counts"] == {"MISSING": 1}
    finding = result["rows"][0]["findings"][0]
    assert finding["role"] == "ex5"
    assert finding["classification"] == "MISSING"
    assert finding["derivation"] == "ea_id_resolution"
