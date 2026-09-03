"""CENSUS-FIRST claim-selection priority (2026-09-03, CEO).

A bounded, selection-only rule: when claimable OPT_CENSUS cells exist and
admitting a heavy candidate (measured-or-flat reservation >= HEAVY_RUN_RAM_GB)
would push free RAM below the protected census band
(OPT_CENSUS_POST_RESERVATION_FLOOR_GB + OPT_CENSUS_RAM_RESERVATION_GB *
CENSUS_LANES_PROTECTED = 16 GB), the heavy row is DEFERRED this claim round and
the worker falls through to a lighter row -- exactly like skipped_ram_class.  It
never defers a COMPILE_EA row or a priority-tracked OWNER-DEC-PRE0803 Amendment B
lineage rerun, and QM_CENSUS_FIRST_RAM_PRIORITY=0 restores the prior behaviour.
It only defers: no verdict, cap, budget, or census floor changes.
"""
import json
import sqlite3
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker as tw  # noqa: E402


# --------------------------------------------------------------------------
# Constants + protected band: exactly the documented 16 GB, and it tracks the
# census constants rather than redefining the floor.
# --------------------------------------------------------------------------

def test_constants_and_protected_band():
    assert tw.HEAVY_RUN_RAM_GB == 10.0
    assert tw.CENSUS_LANES_PROTECTED == 2
    assert tw._census_first_protected_band_gb() == (
        tw.OPT_CENSUS_POST_RESERVATION_FLOOR_GB
        + tw.OPT_CENSUS_RAM_RESERVATION_GB * tw.CENSUS_LANES_PROTECTED
    )
    assert tw._census_first_protected_band_gb() == 16.0


# --------------------------------------------------------------------------
# Pure predicate: the five required scenarios, deterministic, no DB.
# --------------------------------------------------------------------------

def _defers(**kw):
    base = dict(
        reservation_gb=12.0,
        free_ram_gb=27.0,          # 27 - 12 = 15 < 16 band
        census_cells_claimable=True,
        is_priority_tracked_lineage_rerun=False,
        is_compile=False,
        enabled=True,
    )
    base.update(kw)
    return tw._census_first_defers_heavy_candidate(**base)


def test_pure_heavy_deferred_when_census_claimable_and_below_band():
    assert _defers() is True
    # boundary: exactly at the band is NOT below it -> admit
    assert _defers(free_ram_gb=28.0) is False    # 28 - 12 = 16, not < 16
    assert _defers(free_ram_gb=27.9) is True      # 15.9 < 16


def test_pure_admitted_when_no_census_cells_claimable():
    assert _defers(census_cells_claimable=False) is False


def test_pure_admitted_when_headroom_stays_above_band():
    # 40 - 12 = 28 >= 16 -> admit
    assert _defers(free_ram_gb=40.0) is False


def test_pure_light_candidate_never_deferred():
    # A reservation below the heavy threshold (a 4 GB census cell, an 8 GB
    # ordinary row) is never deferred, even at zero headroom.
    assert _defers(reservation_gb=9.999, free_ram_gb=0.0) is False
    assert _defers(reservation_gb=4.0, free_ram_gb=0.0) is False


def test_pure_lineage_rerun_and_compile_never_deferred():
    # Both exemptions hold even when heavy + census claimable + far below band.
    assert _defers(
        is_priority_tracked_lineage_rerun=True, free_ram_gb=0.0
    ) is False
    assert _defers(is_compile=True, free_ram_gb=0.0) is False


def test_pure_kill_switch_restores_old_behaviour():
    assert _defers(enabled=False, free_ram_gb=0.0) is False


# --------------------------------------------------------------------------
# Lineage predicate: the two Amendment B forms, gated on priority_track.
# --------------------------------------------------------------------------

def test_lineage_append_only_rerun_requires_priority_track():
    assert tw._is_priority_tracked_lineage_rerun(
        {"append_only_rerun": True, "priority_track": True}
    ) is True
    assert tw._is_priority_tracked_lineage_rerun(
        {"append_only_rerun": 1, "priority_track": True}
    ) is True
    # No priority_track -> not exempt.
    assert tw._is_priority_tracked_lineage_rerun(
        {"append_only_rerun": True}
    ) is False
    # priority_track must be the JSON literal true, not the integer 1
    # (identical to farmctl's json_type(...)='true' test).
    assert tw._is_priority_tracked_lineage_rerun(
        {"append_only_rerun": True, "priority_track": 1}
    ) is False


def test_lineage_fresh_q02_seed_requires_old_work_item_id():
    assert tw._is_priority_tracked_lineage_rerun(
        {
            "fresh_q02_seed": True,
            "requalification_old_work_item_id": "wi-old",
            "priority_track": True,
        }
    ) is True
    # Empty / missing requalification id -> not exempt.
    assert tw._is_priority_tracked_lineage_rerun(
        {
            "fresh_q02_seed": True,
            "requalification_old_work_item_id": "",
            "priority_track": True,
        }
    ) is False
    assert tw._is_priority_tracked_lineage_rerun(
        {"fresh_q02_seed": True, "priority_track": True}
    ) is False


def test_lineage_ignores_unrelated_and_bad_payloads():
    assert tw._is_priority_tracked_lineage_rerun({}) is False
    assert tw._is_priority_tracked_lineage_rerun(None) is False
    assert tw._is_priority_tracked_lineage_rerun(
        {"priority_track": True}
    ) is False


# --------------------------------------------------------------------------
# Kill-switch env resolution.
# --------------------------------------------------------------------------

def test_kill_switch_env(monkeypatch):
    monkeypatch.delenv("QM_CENSUS_FIRST_RAM_PRIORITY", raising=False)
    assert tw._census_first_ram_priority_enabled() is True
    monkeypatch.setenv("QM_CENSUS_FIRST_RAM_PRIORITY", "1")
    assert tw._census_first_ram_priority_enabled() is True
    monkeypatch.setenv("QM_CENSUS_FIRST_RAM_PRIORITY", "0")
    assert tw._census_first_ram_priority_enabled() is False


# --------------------------------------------------------------------------
# In-transaction census-cell EXISTS helper (real DB).
# --------------------------------------------------------------------------

def _insert(conn, item_id, phase, *, status="pending"):
    now = "2026-09-03T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,
                               verdict,evidence_path,payload_json,created_at,
                               updated_at)
        VALUES(?,?,?,?,?, 'x.set', ?, NULL, NULL, '{}', ?, ?)
        """,
        (item_id, "backtest", phase, f"QM5_{item_id}", "EURUSD.DWX", status,
         now, now),
    )


def test_census_cells_claimable_exists_helper(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        assert tw._opt_census_cells_claimable_in_txn(conn) is False
        _insert(conn, "ord", "Q02")
        assert tw._opt_census_cells_claimable_in_txn(conn) is False
        _insert(conn, "cell", "OPT_CENSUS")
        assert tw._opt_census_cells_claimable_in_txn(conn) is True
        conn.commit()


def test_census_cells_claimable_excludes_held_and_superseded(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        _insert(conn, "cell", "OPT_CENSUS")
        assert tw._opt_census_cells_claimable_in_txn(conn) is True
        conn.execute(
            "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
            "created_at,updated_at) VALUES('cell','X','t',1,?,?)",
            (now, now),
        )
        assert tw._opt_census_cells_claimable_in_txn(conn) is False
        conn.execute(
            "UPDATE work_item_holds SET active=0 WHERE work_item_id='cell'"
        )
        assert tw._opt_census_cells_claimable_in_txn(conn) is True
        conn.execute(
            "INSERT INTO work_item_supersedes(work_item_id,"
            "superseded_by_work_item_id,reason,source_encoding,recorded_by,"
            "recorded_at) VALUES('cell',NULL,'t','canonical','test',?)",
            (now,),
        )
        assert tw._opt_census_cells_claimable_in_txn(conn) is False
        conn.commit()


# --------------------------------------------------------------------------
# claim_atomic wiring: a heavy candidate is deferred / admitted / exempt at the
# real claim path.  The candidate is made heavy by overriding only its
# reservation (the classifier has its own tests); census existence is injected
# through the helper so the heavy row is the sole pending row and thus the
# deterministic initial candidate.  Selection-only -- a deferred row stays
# pending, never verdicted.
# --------------------------------------------------------------------------

def _insert_backtest(root, item_id, symbol="EURUSD.DWX", phase="P3", payload=None):
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.execute(
            """
            INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,
                                   status,verdict,attempt_count,parent_task_id,
                                   evidence_path,claimed_by,payload_json,
                                   created_at,updated_at)
            VALUES(?,?,?,?,?,?, 'pending', NULL, 0, NULL, NULL, NULL, ?, ?, ?)
            """,
            (item_id, "backtest", phase, "QM5_9999", symbol, "dummy.set",
             json.dumps(payload or {}), now, now),
        )
        conn.commit()


@pytest.fixture
def heavy_claim(monkeypatch):
    """Make 'heavy-row' reserve 12 GB and neutralize the commit/calendar gates.

    Returns the monkeypatch so each test can inject free RAM and census
    existence via _run_claim.
    """
    real_reservation = tw._ram_reservation_for_candidate

    def fake_reservation(item, payload, multisym):
        if tw._work_item_value(item, "id") == "heavy-row":
            return ("ordinary", 12.0)
        return real_reservation(item, payload, multisym)

    monkeypatch.setattr(tw, "_ram_reservation_for_candidate", fake_reservation)
    monkeypatch.setattr(tw, "_commit_headroom_gb", lambda: 10_000.0)
    monkeypatch.setattr(
        tw.farmctl,
        "_news_calendar_preflight",
        lambda *a, **k: {"ok": True, "status": "VALID"},
    )
    return monkeypatch


def _run_claim(monkeypatch, root, *, free_ram, census, terminal="T1"):
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: free_ram)
    monkeypatch.setattr(
        tw, "_opt_census_cells_claimable_in_txn", lambda conn: census
    )
    return tw.claim_atomic(root, terminal)


def _status(root, item_id):
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        return conn.execute(
            "SELECT status,claimed_by FROM work_items WHERE id=?", (item_id,)
        ).fetchone()


def test_claim_defers_heavy_when_census_claimable_and_tight(tmp_path, heavy_claim):
    monkeypatch = heavy_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "heavy-row")
    result = _run_claim(monkeypatch, root, free_ram=27.0, census=True)

    assert result.get("claimed") is False, result
    assert result["reason"] == "no_pending_claimable"
    skipped = result["census_lane_protection_skipped"]
    assert len(skipped) == 1
    assert skipped[0]["item_id"] == "heavy-row"
    assert skipped[0]["reason"] == "census_lane_protection"
    assert skipped[0]["reservation_gb"] == 12.0
    assert skipped[0]["protected_band_gb"] == 16.0
    # Deferred, never verdicted: the row is still pending and unclaimed.
    assert _status(root, "heavy-row") == ("pending", None)


def test_claim_admits_heavy_when_no_census_cells(tmp_path, heavy_claim):
    monkeypatch = heavy_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "heavy-row")
    result = _run_claim(monkeypatch, root, free_ram=27.0, census=False)

    assert result.get("claimed") is True, result
    assert result["item"]["id"] == "heavy-row"
    assert result["census_lane_protection_skipped"] == []
    assert _status(root, "heavy-row") == ("active", "T1")


def test_claim_admits_heavy_when_headroom_above_band(tmp_path, heavy_claim):
    monkeypatch = heavy_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "heavy-row")
    result = _run_claim(monkeypatch, root, free_ram=40.0, census=True)

    assert result.get("claimed") is True, result
    assert result["item"]["id"] == "heavy-row"
    assert result["census_lane_protection_skipped"] == []
    assert _status(root, "heavy-row") == ("active", "T1")


def test_claim_never_defers_priority_tracked_lineage_rerun(tmp_path, heavy_claim):
    monkeypatch = heavy_claim
    root = tmp_path / "farm"
    _insert_backtest(
        root,
        "heavy-row",
        payload={"append_only_rerun": True, "priority_track": True},
    )
    # Tight headroom + census claimable would defer an ordinary heavy row; the
    # Amendment B lineage exemption admits it anyway.
    result = _run_claim(monkeypatch, root, free_ram=27.0, census=True)

    assert result.get("claimed") is True, result
    assert result["item"]["id"] == "heavy-row"
    assert result["census_lane_protection_skipped"] == []


def test_claim_kill_switch_restores_old_behaviour(tmp_path, heavy_claim):
    monkeypatch = heavy_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "heavy-row")
    monkeypatch.setenv("QM_CENSUS_FIRST_RAM_PRIORITY", "0")
    # Same tight headroom + census claimable as the defer case; the kill switch
    # admits in claim order exactly as before the rule existed.
    result = _run_claim(monkeypatch, root, free_ram=27.0, census=True)

    assert result.get("claimed") is True, result
    assert result["item"]["id"] == "heavy-row"
    assert result["census_lane_protection_skipped"] == []
    assert _status(root, "heavy-row") == ("active", "T1")
