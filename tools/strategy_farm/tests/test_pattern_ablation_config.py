"""Tests: PATTERN_ABLATION programme config (qm.pattern-ablation/v1) — hermetic schema pin.

Research+specification deliverable only: this test validates the machine-readable
trial plan at tools/strategy_farm/config/pattern_ablation.v1.json. Hermetic: no DB,
no network, no D:/ drive — only repo files (the config, the design doc, and the
framework pattern-permission header via the catalog module).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import pattern_filter_catalog as pfc  # noqa: E402

CONFIG_PATH = SF / "config" / "pattern_ablation.v1.json"
DESIGN_DOC = (
    Path(__file__).resolve().parents[3]
    / "docs" / "research" / "PATTERN_ABLATION_PROGRAMME_2026-09-16.md"
)

SCHEMA = "qm.pattern-ablation/v1"
LEDGER_FAMILIES = {
    "pattern_filter.price-action",
    "pattern_filter.trend",
    "pattern_filter.volatility",
    "pattern_filter.news",
    "pattern_filter.session",
    "pattern_filter.regime",
    "pattern_filter.time",
}
# DL-089 sealed protocol constants (pinned textually; opt_census.py is not
# imported here to keep the test hermetic of farm scheduling modules).
SEALED_YEARS = list(range(2019, 2026))
SEALED_WF_WINDOWS = (
    {"step": 1, "select_years": [2019, 2020, 2021], "test_year": 2022},
    {"step": 2, "select_years": [2019, 2020, 2021, 2022], "test_year": 2023},
    {"step": 3, "select_years": [2019, 2020, 2021, 2022, 2023], "test_year": 2024},
    {"step": 4, "select_years": [2019, 2020, 2021, 2022, 2023, 2024], "test_year": 2025},
)


def _load() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


# --- programme envelope ------------------------------------------------------
def test_schema_and_status_pins():
    cfg = _load()
    assert cfg["schema"] == SCHEMA
    assert cfg["status"] == "DESIGN_ONLY_NOT_COMMISSIONED"
    assert "Fable" in cfg["commissioned_by"]
    # Boundaries: this slice never writes state; it is allowed to add new files.
    never = {k: v for k, v in cfg["boundaries"].items() if k != "new_files_only"}
    for key, value in never.items():
        assert value is False, f"boundary {key} must be False in the design slice"
    assert cfg["boundaries"]["new_files_only"] is True


def test_runs_inside_the_sealed_q12_contract():
    cfg = _load()
    q12 = cfg["q12_contract"]
    assert q12["gate"] == "Q12"
    assert q12["selection_contract"].startswith("DL-089")
    assert "ROT" in q12["selection_contract"]
    assert q12["phase"] == "OPT_CENSUS"
    assert q12["semantics"].startswith("BLACKLIST_v1")
    assert q12["years"] == SEALED_YEARS
    assert [dict(w) for w in q12["walk_forward_windows"]] == [dict(w) for w in SEALED_WF_WINDOWS]
    assert q12["activity_floor_trade_days_per_year"] == 10
    assert q12["relative_improvement_min"] == 0.05
    assert q12["selection_year_quorum"] == "2/3"
    assert q12["filter_cap_per_direction"] == 3
    assert "sole authority" in q12["adoption_rule"]


# --- non-combinatorial structure ----------------------------------------------
def test_trial_count_within_cap_and_no_combinations():
    cfg = _load()
    trials = cfg["trials"]
    assert 8 <= len(trials) <= 12
    tpl = cfg["trial_template"]
    assert tpl["filters_per_trial"] == 1
    assert tpl["combinations"] == []
    assert tpl["null_control"].startswith("baseline")
    assert tpl["arms"] == ["baseline", "buy_{predicate_id}", "sell_{predicate_id}"]
    assert tpl["direction_policy"] == "BOTH"


def test_kill_criteria_present_and_sane():
    cfg = _load()
    kill = cfg["trial_template"]["kill_criteria"]
    assert 0 < kill["expectancy_drop_max_pct"] <= 20
    assert 0 < kill["trade_reduction_max_pct_without_pf_gain"] <= 50
    assert kill["activity_floor_breach_inadmissible"] is True
    assert kill["wf_subset_stability_failure_inadmissible"] is True
    assert "full DL-089 census" in kill["positive_readout_rule"]


# --- per-trial integrity -------------------------------------------------------
def test_trials_are_unique_single_predicate_each():
    cfg = _load()
    trials = cfg["trials"]
    ids = [t["trial_id"] for t in trials]
    assert len(ids) == len(set(ids))
    pairs = [(t["base"]["ea_id"], t["predicate"]["predicate_id"]) for t in trials]
    assert len(pairs) == len(set(pairs)), "duplicate (base, predicate) trial"
    for t in trials:
        pred = t["predicate"]
        assert isinstance(pred["predicate_id"], int) and pred["predicate_id"] > 0
        assert t["family"] == f"pattern_filter.{pred['category']}"


def test_predicates_exist_and_match_catalog_taxonomy():
    text = pfc.DEFAULT_MQH.read_text(encoding="utf-8")
    known = {p["predicate_id"]: p for p in pfc.parse_pattern_predicates(text)}
    cfg = _load()
    for t in cfg["trials"]:
        pred = t["predicate"]
        pid = pred["predicate_id"]
        assert pid in known, f"predicate {pid} not implemented in the framework enum"
        row = known[pid]
        assert pred["category"] == row["category"]
        assert pred["subfamily"] == row["subfamily"]
        assert pred["unger_related"] == row["unger_related"]
        # Census citation fields are present and honestly labeled descriptive.
        cen = pred["census"]
        assert cen["cells_with_baseline"] > 0
        assert 0 <= cen["improved_cells"] <= cen["cells_with_baseline"]


def test_bases_are_qualified_pool_members_or_declared_conditional():
    cfg = _load()
    for t in cfg["trials"]:
        base = t["base"]
        assert base["ea_id"].startswith("QM5_")
        assert base["symbol"].endswith(".DWX")
        assert base["timeframe"] in {"M15", "H1", "H4", "D1"}
        status = base["pipeline_status"]
        assert status in {"QUALIFIED_Q02_Q14", "CONDITIONAL_G0"}
        if status == "CONDITIONAL_G0":
            assert "Q02" in t["activation_precondition"], (
                "conditional trial must name its Q02 activation gate"
            )
        else:
            assert "Q02" in t["activation_precondition"]


def test_trade_reduction_bands_sane():
    cfg = _load()
    for t in cfg["trials"]:
        lo, hi = t["expected_trade_reduction_band_pct"]
        assert 0 <= lo < hi <= 100, f"bad band in {t['trial_id']}"


# --- multiple-testing control ---------------------------------------------------
def test_declared_trial_count_math_and_fdr():
    cfg = _load()
    mtc = cfg["multiple_testing_control"]
    assert mtc["fdr_method"] == "benjamini-hochberg"
    assert set(mtc["pre_registered_families"]) == LEDGER_FAMILIES
    n = len(cfg["trials"])
    assert mtc["declared_trial_count_total"] == 2 * n, (
        "each hypothesis spans BOTH directions = 2 declared direction-trials"
    )
    assert mtc["declared_before_measurement"] is True
    for t in cfg["trials"]:
        assert t["family"] in LEDGER_FAMILIES


def test_explicit_non_selections_cover_the_qualified_pool():
    cfg = _load()
    selected = {t["base"]["ea_id"] for t in cfg["trials"]}
    non = {n["ea_id"] for n in cfg["explicit_non_selections"]}
    # The 26-pair qualified pool + 3 frontier rows must each be either selected
    # or explicitly dispositioned (canonical list: candidate_universe.csv).
    pool = {
        "QM5_10145", "QM5_10403", "QM5_10513", "QM5_10700", "QM5_10706",
        "QM5_11421", "QM5_11422", "QM5_11660", "QM5_11708", "QM5_11881",
        "QM5_11910", "QM5_12710", "QM5_12849", "QM5_12855", "QM5_13013",
        "QM5_13054", "QM5_13213", "QM5_1537", "QM5_20048", "QM5_20266",
        "QM5_21501", "QM5_21505", "QM5_21507", "QM5_41219", "QM5_41221",
        "QM5_9641", "QM5_10911", "QM5_11294", "QM5_1354",
    }
    assert selected <= pool | {"QM5_41475"}
    # Qualified-pool members are each selected or dispositioned; the one
    # conditional base (H-CW) is by definition not in the pool yet.
    qualified_selected = selected & pool
    assert pool - qualified_selected <= non, (
        f"qualified-pool members neither selected nor dispositioned: {sorted(pool - qualified_selected - non)}"
    )
    assert not (selected & non)


# --- doc/config consistency ------------------------------------------------------
def test_design_doc_exists_and_names_every_trial():
    assert DESIGN_DOC.is_file(), f"design doc missing: {DESIGN_DOC}"
    text = DESIGN_DOC.read_text(encoding="utf-8")
    cfg = _load()
    for t in cfg["trials"]:
        assert t["trial_id"] in text
        assert t["base"]["slug"] in text
        assert str(t["predicate"]["predicate_id"]) in text
