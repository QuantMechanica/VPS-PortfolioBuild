import csv
import hashlib
import json
from pathlib import Path
import re
import sqlite3

import pytest

from tools.strategy_farm.session_tools import prepare_balke_pattern_recovery_20260909 as repair

REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework/EAs" / repair.EA
OLD_DIR = REPO / "framework/EAs" / repair.OLD


def test_frozen_parent_is_unchanged():
    assert repair.sha(OLD_DIR / (repair.OLD + ".mq5")) == repair.OLD_SOURCE_SHA
    assert repair.sha(OLD_DIR / (repair.OLD + ".ex5")) == repair.OLD_EX5_SHA


def test_source_delta_is_only_identity_description_and_managed_guard():
    old = (OLD_DIR / (repair.OLD + ".mq5")).read_text(encoding="utf-8-sig")
    new = (EA_DIR / (repair.EA + ".mq5")).read_text(encoding="utf-8-sig")
    expected = old.replace("41097", "41398").replace(
        "#include <QM/QM_Common.mqh>",
        "// Recovery 2026-09-09: own the straddle veto once; preserve parent mechanics.\n"
        "#define QM_PATTERN_PERMISSION_EA_MANAGED\n#include <QM/QM_Common.mqh>")
    expected = expected.replace('DL-089 optimization instrument"',
                                'DL-089 pattern repair measurement instrument"')
    assert new == expected


def test_guard_precedes_common_and_d1_reference_is_not_an_input():
    source = (EA_DIR / (repair.EA + ".mq5")).read_text(encoding="utf-8-sig")
    assert source.index("#define QM_PATTERN_PERMISSION_EA_MANAGED") < source.index("#include <QM/QM_Common.mqh>")
    assert "const ENUM_TIMEFRAMES QM_PPC_REFERENCE_TF = PERIOD_D1;" in source
    assert "const int             QM_PPC_CLOSED_SHIFT = 1;" in source
    assert source.count("const QM_PermissionResult perm = Census_Permission();") == 1


def test_baseline_pins_every_declared_input_to_original_default():
    source = (EA_DIR / (repair.EA + ".mq5")).read_text(encoding="utf-8-sig")
    defaults = dict(re.findall(r"^input\s+\w+\s+(\w+)\s*=\s*([^;]+);", source, re.M))
    setfile = EA_DIR / "sets" / (repair.EA + "_USDJPY.DWX_H1_backtest.set")
    assignments = re.findall(r"^(\w+)=(.*)$", setfile.read_text(encoding="utf-8-sig"), re.M)
    assert len(assignments) == len(dict(assignments)), "duplicate input assignment"
    values = dict(assignments)
    assert set(values) == set(defaults), "missing or extra EA inputs"
    enums = {"QM_NEWS_TEMPORAL_PRE30_POST30": "3", "QM_NEWS_COMPLIANCE_DXZ": "1", "QM_NEWS_OFF": "0"}
    for key, value in defaults.items():
        expected = enums.get(value.strip(), value.strip().strip('"'))
        actual = values[key].strip()
        try:
            assert float(actual) == float(expected), key
        except ValueError:
            assert actual == expected, key
    assert all(values[f"opt_pp_{side}{i}"] == "0" for side in ("buy", "sell") for i in (1, 2, 3))


def test_registry_and_card_are_unique_and_aligned():
    card = REPO / "artifacts/cards_approved" / (repair.EA + ".md")
    assert card.read_bytes() == (EA_DIR / "docs/strategy_card.md").read_bytes()
    for name, key in (("ea_id_registry.csv", "ea_id"), ("magic_numbers.csv", "ea_id")):
        with (REPO / "framework/registry" / name).open(encoding="utf-8-sig", newline="") as fh:
            rows = [r for r in csv.DictReader(fh) if r[key] == "41398"]
        assert len(rows) == 1
        assert rows[0]["status"] == "active"
        if name == "magic_numbers.csv":
            assert (rows[0]["symbol_slot"], rows[0]["symbol"], rows[0]["magic"]) == ("0", "USDJPY.DWX", "413980000")


def rows_fixture():
    return [dict(id=wid, ea_id="QM5_13213", symbol="USDJPY.DWX", phase="Q12",
                 status="pending", verdict=None, claimed_by=None) for wid in sorted(repair.Q12_IDS)]


@pytest.mark.parametrize("key,value", [("status", "active"), ("verdict", "PASS"),
                                      ("claimed_by", "T4"), ("symbol", "XAUUSD.DWX")])
def test_hold_scope_rejects_changed_or_measured_rows(key, value):
    rows = rows_fixture()
    rows[0][key] = value
    with pytest.raises(ValueError):
        repair.validate_scope(rows)


def test_hold_scope_rejects_a_fourth_duplicate():
    rows = rows_fixture()
    rows.append({**rows[0], "id": "new-unreviewed-row"})
    with pytest.raises(ValueError):
        repair.validate_scope(rows)


def test_hold_installation_preserves_work_items_and_cannot_auto_release():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE work_items(id TEXT PRIMARY KEY,ea_id TEXT,symbol TEXT,phase TEXT,
                                status TEXT,verdict TEXT,claimed_by TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,
            active INTEGER,release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
            released_at TEXT,release_note TEXT);
    """)
    rows = rows_fixture()
    for row in rows:
        db.execute("INSERT INTO work_items VALUES(?,?,?,?,?,?,?)", tuple(row.values()))
    receipt = {"work_items_before_sha256": repair.digest(rows)}
    repair.install_holds(db, rows, receipt)
    assert receipt["work_items_after_sha256"] == receipt["work_items_before_sha256"]
    assert db.execute("SELECT count(*) FROM work_item_holds WHERE active=1 AND release_on_restart=0 AND hold_code=?",
                      (repair.HOLD,)).fetchone()[0] == 3
    repair.install_holds(db, rows, receipt)
    assert db.execute("SELECT count(*) FROM work_item_holds").fetchone()[0] == 3


def test_repaired_pattern_header_remains_pinned():
    raw = (REPO / "framework/include/QM/QM_PatternPermission.mqh").read_bytes().replace(b"\r\n", b"\n")
    assert hashlib.sha256(raw).hexdigest() == repair.PATTERN_SHA
