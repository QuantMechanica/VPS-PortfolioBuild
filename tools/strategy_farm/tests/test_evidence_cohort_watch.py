"""Positive and negative controls for the evidence cohort watcher.

The watcher's whole value is that it fires when baselined evidence disappears. A watcher that
reports NO_LOSS unconditionally is indistinguishable from a working one on a healthy farm --
which is precisely the situation it is deployed into, since nothing has vanished yet. So the
firing path must be proven against a planted loss, not assumed.
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "evidence_cohort_watch.py"


def _load(tmp_baseline: Path):
    spec = importlib.util.spec_from_file_location("ecw", MODULE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.BASELINE = tmp_baseline
    mod.LOG = tmp_baseline.with_suffix(".log")
    return mod


def _baseline(entries: dict) -> dict:
    return {"schema": "qm.evidence-cohort-baseline/v1", "entries": entries, "observations": []}


def _entry(path: Path, root: Path, wid="a1b2c3d4-0000-0000-0000-000000000000") -> dict:
    return {
        "work_item_id": wid, "ea_id": "QM5_TEST", "symbol": "XAUUSD.DWX", "phase": "Q02",
        "verdict": "PASS", "row_updated_at": "2026-08-17T00:00:00+00:00",
        "evidence_path": str(path), "report_root": str(root),
        "baselined_at_utc": "2026-08-17T00:00:00Z", "evidence_present_at_baseline": True,
    }


def test_no_loss_when_evidence_survives(tmp_path):
    """NEGATIVE control: intact evidence must NOT be reported as a loss."""
    root = tmp_path / "work_items" / "a1b2c3d4"
    root.mkdir(parents=True)
    ev = root / "summary.json"
    ev.write_text("{}", encoding="utf-8")
    bl = tmp_path / "baseline.json"
    bl.write_text(json.dumps(_baseline({"a1b2c3d4-0000-0000-0000-000000000000":
                                        _entry(ev, root)})), encoding="utf-8")
    mod = _load(bl)
    assert mod.cmd_check(False) == 0
    data = json.loads(bl.read_text(encoding="utf-8"))
    assert data["observations"][-1]["intact"] == 1
    assert data["observations"][-1]["evidence_file_missing"] == 0
    assert "losses" not in data


def test_fires_when_the_whole_report_root_vanishes(tmp_path):
    """POSITIVE control: the exact observed failure mode -- the whole tree gone."""
    root = tmp_path / "work_items" / "a1b2c3d4"
    ev = root / "summary.json"          # never created: root and file both absent
    bl = tmp_path / "baseline.json"
    bl.write_text(json.dumps(_baseline({"a1b2c3d4-0000-0000-0000-000000000000":
                                        _entry(ev, root)})), encoding="utf-8")
    mod = _load(bl)
    assert mod.cmd_check(False) == 3, "a vanished report root must exit 3 (LOSS_OBSERVED)"
    data = json.loads(bl.read_text(encoding="utf-8"))
    assert data["observations"][-1]["whole_report_root_missing"] == 1
    assert data["losses"][0]["report_root_still_present"] is False


def test_fires_when_only_the_evidence_file_vanishes(tmp_path):
    """POSITIVE control: root survives but the summary is gone -- a different mechanism,
    and it must be reported separately so the two are not conflated."""
    root = tmp_path / "work_items" / "a1b2c3d4"
    root.mkdir(parents=True)
    ev = root / "summary.json"          # root exists, file does not
    bl = tmp_path / "baseline.json"
    bl.write_text(json.dumps(_baseline({"a1b2c3d4-0000-0000-0000-000000000000":
                                        _entry(ev, root)})), encoding="utf-8")
    mod = _load(bl)
    assert mod.cmd_check(False) == 3
    data = json.loads(bl.read_text(encoding="utf-8"))
    obs = data["observations"][-1]
    assert obs["evidence_file_missing"] == 1
    assert obs["whole_report_root_missing"] == 0, "must not be counted as a root loss"


def test_empty_baseline_is_an_error_not_a_pass(tmp_path):
    """A watcher with nothing to watch must NOT report success -- that is the failure mode
    where the task 'runs green' for weeks while observing nothing at all."""
    bl = tmp_path / "baseline.json"
    bl.write_text(json.dumps(_baseline({})), encoding="utf-8")
    mod = _load(bl)
    assert mod.cmd_check(False) == 1
