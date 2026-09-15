"""Worker-side seam for the resource-aware scheduler (directive 3 §12, §44G).

Verifies: (a) kill switch OFF is a no-op; (b) a heavy qualifying drain candidate
is suppressed when a fitting smaller row exists in the head window and the fleet
is busy; (c) a heavy candidate arms normally in a quiet window with no fitting
smaller; (d) the QM_RAM_TABLE=calibrated flat-reservation override is opt-in and
default-off.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import resource_scheduler as rs  # noqa: E402
import terminal_worker as tw  # noqa: E402


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.delenv(tw.resource_scheduler.ENV_KILL_SWITCH, raising=False)
    monkeypatch.delenv(tw.CALIBRATED_RAM_TABLE_ENV, raising=False)
    # reset the calibrated-table module cache between tests
    tw._CALIBRATED_RAM_TABLE_CACHE.update({"loaded": False, "by_class": {}, "by_base": {}})


HEAVY = {"item_id": "SPX1", "reservation_gb": 44.0, "ea_id": "QM5_SP"}


def _patch_state(monkeypatch):
    saved = {}
    monkeypatch.setattr(tw, "_load_resource_scheduler_state", lambda root: {"tracking": dict(saved)})
    def _save(root, state):
        saved.clear()
        saved.update(state.get("tracking", {}))
        return True
    monkeypatch.setattr(tw, "_write_resource_scheduler_state_atomic", _save)
    return saved


# --- (a) kill switch off is a no-op ------------------------------------------
def test_gate_noop_when_disabled(monkeypatch, tmp_path):
    # scheduler disabled by default; must return the candidate unchanged and no event
    out, event = tw._resource_scheduler_gate_predrain(
        tmp_path, qualifying=dict(HEAVY), free_ram_gb=30.0,
        multisym_ids=frozenset(), now_epoch=1000.0,
    )
    assert out == HEAVY
    assert event is None


def test_gate_noop_when_qualifying_none(monkeypatch, tmp_path):
    monkeypatch.setenv(tw.resource_scheduler.ENV_KILL_SWITCH, "1")
    out, event = tw._resource_scheduler_gate_predrain(
        tmp_path, qualifying=None, free_ram_gb=30.0,
        multisym_ids=frozenset(), now_epoch=1000.0,
    )
    assert out is None and event is None


# --- (b) heavy suppressed when a fitting smaller row exists and fleet busy ----
def test_gate_suppresses_heavy_with_fitting_smaller(monkeypatch, tmp_path):
    monkeypatch.setenv(tw.resource_scheduler.ENV_KILL_SWITCH, "1")
    _patch_state(monkeypatch)
    window = [
        rs.Candidate(item_id="SPX1", reservation_gb=44.0, ea_id="QM5_SP"),
        rs.Candidate(item_id="a", reservation_gb=8.0, ea_id="QM5_A"),
    ]
    monkeypatch.setattr(
        tw, "_resource_scheduler_head_window", lambda root, **kw: (window, 6)
    )
    out, event = tw._resource_scheduler_gate_predrain(
        tmp_path, qualifying=dict(HEAVY), free_ram_gb=30.0,
        multisym_ids=frozenset(), now_epoch=1000.0,
    )
    assert out is None
    assert event["event"] == "resource_scheduler_predrain_suppressed"
    assert event["reason"].startswith("suppressed_fitting_smaller_exists")
    assert event["item_id"] == "SPX1"


# --- (c) heavy allowed in a quiet window with no fitting smaller --------------
def test_gate_allows_heavy_quiet_window(monkeypatch, tmp_path):
    monkeypatch.setenv(tw.resource_scheduler.ENV_KILL_SWITCH, "1")
    _patch_state(monkeypatch)
    window = [rs.Candidate(item_id="SPX1", reservation_gb=44.0, ea_id="QM5_SP")]
    monkeypatch.setattr(
        tw, "_resource_scheduler_head_window", lambda root, **kw: (window, 0)
    )
    out, event = tw._resource_scheduler_gate_predrain(
        tmp_path, qualifying=dict(HEAVY), free_ram_gb=30.0,
        multisym_ids=frozenset(), now_epoch=1000.0,
    )
    assert out == HEAVY
    assert event is None


def test_gate_ignores_non_heavy_candidate(monkeypatch, tmp_path):
    monkeypatch.setenv(tw.resource_scheduler.ENV_KILL_SWITCH, "1")
    light = {"item_id": "L1", "reservation_gb": 8.0, "ea_id": "QM5_L"}
    out, event = tw._resource_scheduler_gate_predrain(
        tmp_path, qualifying=dict(light), free_ram_gb=30.0,
        multisym_ids=frozenset(), now_epoch=1000.0,
    )
    assert out == light and event is None


# --- (d) QM_RAM_TABLE=calibrated flat-reservation override --------------------
def test_calibrated_table_default_off_returns_live():
    # default off -> live flat returned unchanged
    assert tw._calibrated_flat_reservation_gb("single_index_tick", "SP500.DWX", 44.0) == 44.0


def test_calibrated_table_override_by_class_and_base(monkeypatch, tmp_path):
    cfg = tmp_path / "resource_footprints.v1.json"
    cfg.write_text(
        '{"schema":"qm.resource-footprints-proposal/v1",'
        '"reservation_by_ram_class":{"single_index_tick":{"proposed_reservation_gb":18.0},'
        '"ordinary":{"proposed_reservation_gb":20.0}},'
        '"index_reservation_by_symbol_base":{"NDX":{"proposed_reservation_gb":15.0}}}',
        encoding="utf-8",
    )
    monkeypatch.setattr(tw, "_CALIBRATED_RAM_TABLE_PATH", cfg)
    tw._CALIBRATED_RAM_TABLE_CACHE.update({"loaded": False, "by_class": {}, "by_base": {}})
    monkeypatch.setenv(tw.CALIBRATED_RAM_TABLE_ENV, "calibrated")
    # index base override wins for single_index_tick
    assert tw._calibrated_flat_reservation_gb("single_index_tick", "NDX.DWX", 44.0) == 15.0
    # index class fallback when base absent (SP500 not in file)
    assert tw._calibrated_flat_reservation_gb("single_index_tick", "SP500.DWX", 44.0) == 18.0
    # ordinary class override
    assert tw._calibrated_flat_reservation_gb("ordinary", "EURUSD.DWX", 8.0) == 20.0
    # class absent from file -> live kept
    assert tw._calibrated_flat_reservation_gb("two_leg_metal_pair", "XAUUSD.DWX", 24.0) == 24.0


def test_calibrated_table_fail_open_missing_file(monkeypatch, tmp_path):
    monkeypatch.setattr(tw, "_CALIBRATED_RAM_TABLE_PATH", tmp_path / "nope.json")
    tw._CALIBRATED_RAM_TABLE_CACHE.update({"loaded": False, "by_class": {}, "by_base": {}})
    monkeypatch.setenv(tw.CALIBRATED_RAM_TABLE_ENV, "calibrated")
    # missing file -> fail open to live
    assert tw._calibrated_flat_reservation_gb("ordinary", "EURUSD.DWX", 8.0) == 8.0
