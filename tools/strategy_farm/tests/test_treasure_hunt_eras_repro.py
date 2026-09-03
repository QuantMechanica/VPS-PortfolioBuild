"""Unit tests for docs/ops/evidence/2026-09-03_treasure_hunt_eras_repro.py.

They pin the four defects the 2026-09-03 revision exists to fix:

  1. the verdict classifier is the production one (CONFIG_LOCKED / NO_FILTER_CHANGE /
     NO_PARAMETER_CHANGE are PASS, and Q08 FAIL_SOFT is PASS only at Q08);
  2. successorship is ordinal, so a next-gate row seeded minutes BEFORE the standing
     PASS still counts as seeded (the QM5_12710 / QM5_21507 duplicate-enqueue trap);
  3. ``evidence_present`` answers "does this path exist", and the canonical-setfile
     question gets its own column;
  4. an OWNER disposition is a non-null ``owner_decision_id``, not a payload substring.

The repro script is read-only against the live DB; these tests touch no DB at all and
write only into pytest's ``tmp_path``.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "docs" / "ops" / "evidence" / "2026-09-03_treasure_hunt_eras_repro.py"


@pytest.fixture(scope="module")
def repro():
    if str(REPO_ROOT) not in sys.path:
        sys.path.insert(0, str(REPO_ROOT))
    spec = importlib.util.spec_from_file_location("treasure_repro", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FakeRow:
    """Minimal stand-in for repro.Row (the detectors only touch these attributes)."""

    def __init__(self, rid, gate, status="done", verdict="PASS", updated_at="",
                 phase="", portfolio=False):
        self.id = rid
        self.gate = gate
        self.status = status
        self.verdict = verdict
        self.updated_at = updated_at
        self.phase = phase or (gate or "")
        self.portfolio = portfolio


# --------------------------------------------------------------------------
# 1. classifier
# --------------------------------------------------------------------------

def test_vclass_is_the_production_one(repro):
    from tools.strategy_farm.rebaseline_census import vclass
    assert repro.vclass is vclass
    assert vclass("CONFIG_LOCKED") == "PASS"
    assert vclass("NO_FILTER_CHANGE") == "PASS"
    assert vclass("NO_PARAMETER_CHANGE") == "PASS"


def test_fail_soft_is_pass_only_at_q08(repro):
    assert repro.vclass("FAIL_SOFT", "Q08") == "PASS"
    assert repro.vclass("FAIL_SOFT", "Q09") == "ECON_FAIL"
    assert repro.vclass("FAIL_SOFT") == "ECON_FAIL"


def test_gate_scoped_pass_contract_is_gate_scoped(repro):
    assert repro.GATE_SCOPED_PASS == {"Q08": {"FAIL_SOFT"}}


# --------------------------------------------------------------------------
# 2. gate axis
# --------------------------------------------------------------------------

@pytest.mark.parametrize("phase,expected", [
    ("Q02", "Q02"),
    ("P2", "Q02"),          # LEGACY_ALIAS, not "Q04"
    ("P3.5", "Q03"),
    ("P7", "Q08"),
    ("Q09", "Q09"),
    ("Q11", "Q11"),
    ("COMPILE_EA", None),
    ("OPT_CENSUS", None),
    ("", None),
])
def test_storage_gate_mapping(repro, phase, expected):
    assert repro.storage_gate(phase) == expected


def test_news_lanes_resolve_to_the_active_news_gate(repro):
    from tools.strategy_farm.rebaseline_census import NEWS_GATE
    assert repro.storage_gate("Q09_NEWS") == NEWS_GATE
    assert repro.storage_gate("Q10_NEWS") == NEWS_GATE
    # a pending news row must rank DEEPER than a standing Q09 pass, otherwise an
    # already-seeded gate reads as unseeded
    assert repro.GATE_RANK[repro.storage_gate("Q09_NEWS")] > repro.GATE_RANK["Q09"]


def test_portfolio_lane_keeps_its_parent_gate_and_is_informational(repro):
    assert repro.storage_gate("Q09_PORTFOLIO") == "Q09"
    assert repro.is_portfolio_lane("Q09_PORTFOLIO") is True
    assert repro.is_portfolio_lane("Q09_NEWS") is False


# --------------------------------------------------------------------------
# 3. successorship (the duplicate-enqueue defect)
# --------------------------------------------------------------------------

def test_successor_seeded_before_the_pass_is_still_a_successor(repro):
    """QM5_12710/XTIUSD: Q09 PASS 20:38:36, Q10_NEWS row 17:43:40 the same day."""
    standing = FakeRow("a", "Q09", updated_at="2026-08-29 20:38:36")
    seeded = FakeRow("b", "Q10", status="pending", verdict="",
                     updated_at="2026-08-29 17:43:40", phase="Q10_NEWS")
    rec = {"rows": [standing, seeded]}
    succ = repro.successor_rows(rec, standing)
    assert [r.id for r in succ] == ["b"]
    assert repro.frontier_state(standing, succ) == "SUCCESSOR_PENDING"


def test_no_successor_when_nothing_deeper_exists(repro):
    standing = FakeRow("a", "Q09", updated_at="2026-08-30 02:14:32")
    rec = {"rows": [standing]}
    assert repro.frontier_state(standing, repro.successor_rows(rec, standing)) \
        == "NO_SUCCESSOR"


def test_closed_successor_older_than_the_pass_is_stalled_not_answered(repro):
    """QM5_9510/XAUUSD: Q10_NEWS REVIEW_REQUIRED 2026-08-25, Q09 PASS 2026-08-30."""
    standing = FakeRow("a", "Q09", updated_at="2026-08-30 02:14:32")
    older = FakeRow("b", "Q10", status="done", verdict="REVIEW_REQUIRED",
                    updated_at="2026-08-25 16:50:35", phase="Q10_NEWS")
    rec = {"rows": [standing, older]}
    succ = repro.successor_rows(rec, standing)
    assert repro.frontier_state(standing, succ) == "SUCCESSOR_TERMINAL_BEFORE_PASS"


def test_closed_successor_after_the_pass_means_the_gate_answered(repro):
    standing = FakeRow("a", "Q09", updated_at="2026-08-24 05:08:20")
    newer = FakeRow("b", "Q10", status="done", verdict="REVIEW_REQUIRED",
                    updated_at="2026-09-02 21:06:36", phase="Q10_NEWS")
    rec = {"rows": [standing, newer]}
    succ = repro.successor_rows(rec, standing)
    assert repro.frontier_state(standing, succ) == "SUCCESSOR_TERMINAL_AFTER_PASS"


def test_later_row_at_a_shallower_gate_is_rework_not_a_successor(repro):
    standing = FakeRow("a", "Q09", updated_at="2026-08-20 00:00:00")
    rework = FakeRow("b", "Q02", status="done", verdict="PASS",
                     updated_at="2026-09-03 03:38:48")
    rec = {"rows": [standing, rework]}
    assert repro.successor_rows(rec, standing) == []
    assert [r.id for r in repro.later_activity_rows(rec, standing)] == ["b"]


# --------------------------------------------------------------------------
# 4. evidence flags
# --------------------------------------------------------------------------

def test_path_exists_is_literal(repro, tmp_path):
    real = tmp_path / "aggregate.json"
    real.write_text("{}", encoding="utf-8")
    assert repro.path_exists(str(real)) is True
    assert repro.path_exists(str(tmp_path / "gone.json")) is False
    assert repro.path_exists("") is False
    assert repro.path_exists(None) is False


def test_canonical_setfile_rewrite_and_existence(repro, tmp_path):
    canonical = tmp_path / "canon"
    target = canonical / "framework" / "EAs" / "QM5_10069_x" / "sets" / "a.set"
    target.parent.mkdir(parents=True)
    target.write_text("strategy_a=1\nstrategy_b=2\nrisk_mode=FIXED\n", encoding="utf-8")

    dead = r"C:\QM\worktrees\rb-universe-expansion\framework\EAs\QM5_10069_x\sets\a.set"
    path, exists = repro.canonical_setfile_for(dead, canonical)
    assert exists is True
    assert Path(path) == target
    # the dead path itself must NOT be reported as present
    assert repro.path_exists(dead) is False

    missing = (r"C:\QM\worktrees\rb-universe-expansion\framework\EAs\QM5_99999_y"
               r"\sets\a.set")
    _p, exists2 = repro.canonical_setfile_for(missing, canonical)
    assert exists2 is False

    # a path that is not inside a removed worktree yields no canonical candidate
    assert repro.canonical_setfile_for(r"D:\QM\reports\x.set", canonical) == ("", False)


def test_count_strategy_params(repro, tmp_path):
    f = tmp_path / "x.set"
    f.write_text("strategy_a=1\nstrategy_b=2\nrisk_mode=FIXED\n", encoding="utf-8")
    assert repro.count_strategy_params(str(f)) == 2
    empty = tmp_path / "y.set"
    empty.write_text("risk_mode=FIXED\n", encoding="utf-8")
    assert repro.count_strategy_params(str(empty)) == 0
    assert repro.count_strategy_params(str(tmp_path / "nope.set")) is None


# --------------------------------------------------------------------------
# 5. OWNER disposition
# --------------------------------------------------------------------------

def test_owner_decision_requires_a_non_null_id(repro):
    assert repro.owner_decision_of('{"owner_decision_id": "OWNER-DEC-STRANDED-182"}') \
        == "OWNER-DEC-STRANDED-182"
    assert repro.owner_decision_of('{"owner_decision_id": null}') == ""
    # the substring trap that mis-tagged QM5_9510/XAUUSD as OWNER-disposed
    assert repro.owner_decision_of('{"progress_evidence": "owner_approved"}') == ""
    assert repro.owner_decision_of("not json at all") == ""
    assert repro.owner_decision_of(None) == ""


# --------------------------------------------------------------------------
# 6. misc invariants
# --------------------------------------------------------------------------

def test_norm_ts_normalises_both_stored_spellings(repro):
    assert repro.norm_ts("2026-08-29T17:43:40+00:00") == "2026-08-29 17:43:40"
    assert repro.norm_ts("2026-08-29 17:43:40.123456+00:00") == "2026-08-29 17:43:40"
    assert repro.norm_ts(None) == ""


def test_era_of_boundaries(repro):
    assert repro.era_of("2026-05-31") == "PRE_JUNE"
    assert repro.era_of("2026-06-01") == "JUNE"
    assert repro.era_of("2026-06-30") == "JUNE"
    assert repro.era_of("2026-08-01") == "AUGUST"
    assert repro.era_of("2026-09-01") == "SEPTEMBER"
    assert repro.era_of("") is None


def test_dl071_constants_come_from_the_runner(repro):
    assert repro.PF_NET_FLOOR_PER_FOLD == 1.0
    assert repro.Q04_SOFT_MEAN_FLOOR == 1.10
    assert repro.Q04_SOFT_MIN_FOLD_FLOOR == 0.80
    assert repro.Q04_SOFT_MIN_POS_FRACTION == pytest.approx(2.0 / 3.0)
    # the 999.0 zero-gross-loss sentinel can never rescue a soft pass
    assert repro.pf_measurement_issue(999.0, 1) is not None


def test_metric_best_rejects_implausible_pf(repro):
    rows = [{"profit_factor": 666.0, "trades": 3},
            {"profit_factor": 1.75, "trades": 157}]
    assert repro.metric_best(rows)["pf"] == 1.75
    assert repro.metric_best(rows, plausible_only=False)["pf"] == 666.0
