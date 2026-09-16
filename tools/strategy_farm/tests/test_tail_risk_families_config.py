"""Schema test for config/tail_risk_families.v1.json — TAIL_RISK programme slice.

Hermetic: loads only the config file and the stdlib-only, runtime-disconnected
strategy_risk_contract module. No farm DB, no terminal, no network, no writes.

Authority: OWNER-DEC-D3-20260915 (directive 3 sections 17-21) + interim
directive sections 7-8. Design doc: docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md.
Companion doctrine: docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md and
docs/research/STRATEGY_ELIGIBILITY_V2.md.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "strategy_risk_contract.py"
SPEC = importlib.util.spec_from_file_location("strategy_risk_contract_tail_families", MODULE_PATH)
assert SPEC and SPEC.loader
rc = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = rc
SPEC.loader.exec_module(rc)

CONFIG_PATH = Path(__file__).resolve().parents[1] / "config" / "tail_risk_families.v1.json"

FAMILY_IDS = [
    "positive_pyramiding",
    "negative_pyramiding",
    "bounded_martingale",
    "bounded_grid_recovery",
]
TAIL_AMPLIFYING_BY_FAMILY = {
    "positive_pyramiding": False,  # doctrine section 9/21: NOT tail-amplifying
    "negative_pyramiding": True,
    "bounded_martingale": True,
    "bounded_grid_recovery": True,
}


def _load() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def _families(cfg: dict) -> dict[str, dict]:
    return {f["family_id"]: f for f in cfg["families"]}


def test_config_loads_and_container_schema_is_const():
    cfg = _load()
    assert cfg["schema"] == "qm.tail-risk-families/v1"
    assert cfg["status"] == "RESEARCH_SPECIFICATION__NO_VERDICT_NO_DEPLOYMENT_NO_DB_WRITES"
    assert cfg["thresholds_status"].startswith("PROPOSED_PENDING_OWNER_RATIFICATION")


def test_exactly_four_expected_families_present():
    fams = _families(_load())
    assert sorted(fams) == sorted(FAMILY_IDS)
    for fam in fams.values():
        assert fam["schema"] == "qm.research-tail-risk-family/v1"
        assert fam["research_status"] == "SPECIFICATION_ONLY_NO_EA"
        assert fam["evidence_status"] == "SPECIFICATION_ONLY"


def test_mechanism_flags_are_canonical_and_tail_amplifying_alignment_holds():
    fams = _families(_load())
    for fid, fam in fams.items():
        valid, unknown = rc.normalize_flags(fam["mechanism_flags"])
        assert unknown == [], f"{fid}: unknown mechanism flags {unknown}"
        assert valid == sorted(fam["mechanism_flags"])
        tail_flags = rc.tail_amplifying_flags(fam["mechanism_flags"])
        assert fam["tail_amplifying"] == TAIL_AMPLIFYING_BY_FAMILY[fid]
        assert fam["contract"]["tail_amplifying"] == fam["tail_amplifying"]
        if TAIL_AMPLIFYING_BY_FAMILY[fid]:
            assert tail_flags, f"{fid} must declare at least one tail-amplifying flag"
            assert fam["tail_amplifying"] is True
        else:
            assert tail_flags == [], f"{fid} must not be tail-amplifying"


def test_positive_and_negative_pyramiding_are_distinct_families():
    fams = _families(_load())
    pos = fams["positive_pyramiding"]
    neg = fams["negative_pyramiding"]
    assert "positive_pyramiding" in pos["mechanism_flags"]
    assert "negative_pyramiding" not in pos["mechanism_flags"]
    assert "negative_pyramiding" in neg["mechanism_flags"]
    assert "positive_pyramiding" not in neg["mechanism_flags"]
    assert pos["tail_amplifying"] is not neg["tail_amplifying"]


def test_every_embedded_contract_is_structurally_valid_and_bounded():
    # Reuse the machine gate's own validator: a family contract that would fail
    # intake must fail here (fail closed, identical semantics).
    for fid, fam in _families(_load()).items():
        errors = rc.validate_contract(fam["contract"])
        assert errors == [], f"{fid}: contract errors {errors}"
        assert rc.is_unbounded(fam["contract"]) is False, f"{fid}: contract declares unbounded recovery"


def test_no_infinite_levels_anywhere():
    for fid, fam in _families(_load()).items():
        contract = fam["contract"]
        assert isinstance(contract["max_levels"], int) and contract["max_levels"] >= 1
        assert contract.get("levels_unbounded") is not True
        assert contract["max_open_positions"] >= 1


def test_progression_shapes_match_family_semantics():
    fams = _families(_load())
    a_prog = fams["positive_pyramiding"]["mechanics"]["size_progression"]
    b_prog = fams["negative_pyramiding"]["mechanics"]["size_progression"]
    c_prog = fams["bounded_martingale"]["mechanics"]["size_progression"]
    d_prog = fams["bounded_grid_recovery"]["mechanics"]["size_progression"]
    # A and B: decreasing scale-in (1.0 -> 0.75 -> 0.5); B averages in SMALLER increments.
    assert a_prog == [1.0, 0.75, 0.5]
    assert b_prog == [1.0, 0.75, 0.5]
    assert all(x > y for x, y in zip(b_prog, b_prog[1:]))
    # C: geometric martingale within the finite 3..5 level envelope, multiplier 2.
    c_contract = fams["bounded_martingale"]["contract"]
    assert 3 <= c_contract["max_levels"] <= 5
    assert c_contract["sizing_progression"]["type"] == "geometric"
    assert float(c_contract["sizing_progression"]["multiplier"]) == 2.0
    assert c_prog == [1.0, 2.0, 4.0, 8.0]
    assert len(c_prog) == c_contract["max_levels"]
    # D: flat equal-unit grid.
    assert d_prog == [1.0] * fams["bounded_grid_recovery"]["contract"]["max_levels"]


def test_loss_and_margin_bounds_are_positive_and_sane_against_book_budgets():
    # Per-sleeve worst case (0.55% planned) and venue budget (4% effective) bound
    # what a family basket may declare; a bound above 5% could not fit the book.
    for fid, fam in _families(_load()).items():
        contract = fam["contract"]
        loss = contract["max_basket_loss_pct"]
        margin = contract["max_margin_pct"]
        assert 0 < loss <= 5.0, f"{fid}: max_basket_loss_pct {loss} outside (0, 5]"
        assert 0 < margin <= 25.0, f"{fid}: max_margin_pct {margin} outside (0, 25]"
        stop = contract["emergency_exit"].get("equity_stop_pct")
        assert stop is not None and 0 < stop <= loss, f"{fid}: equity stop must be positive and <= basket loss bound"


def test_every_family_declares_invalidation_criteria():
    for fid, fam in _families(_load()).items():
        criteria = fam["invalidation_criteria"]
        assert isinstance(criteria, list) and len(criteria) >= 3, f"{fid}: needs >=3 invalidation criteria"
        assert all(isinstance(c, str) and c.strip() for c in criteria)


def test_every_family_has_expected_mechanism_regime_of_failure_and_portfolio_role():
    for fid, fam in _families(_load()).items():
        assert fam["expected_mechanism"].strip()
        assert fam["regime_of_failure"].strip()
        role = fam["portfolio_role"]
        assert set(role) == {"ftmo", "dxz"}, f"{fid}: portfolio_role must cover ftmo and dxz"
        assert all(role[k].strip() for k in role)


def test_stress_matrix_scenarios_are_well_formed():
    cfg = _load()
    matrix = cfg["stress_matrix"]
    scenarios = matrix["scenarios"]
    ids = [s["id"] for s in scenarios]
    assert len(ids) == len(set(ids)), "scenario ids must be unique"
    fam_ids = set(FAMILY_IDS)
    covered: set[str] = set()
    gap_mults: set[float] = set()
    spread_mults: set[float] = set()
    for s in scenarios:
        p = s["parameters"]
        assert p["gap_mult"] >= 1 and p["spread_mult"] >= 1 and p["margin_mult"] >= 1
        gap_mults.add(p["gap_mult"])
        spread_mults.add(p["spread_mult"])
        assert set(s["applies_to"]) <= fam_ids
        covered |= set(s["applies_to"])
        assert len(s["pass_criteria"]) >= 1
        assert all(isinstance(c, str) and c.strip() for c in s["pass_criteria"])
    assert covered == fam_ids, "every family must be covered by >= 1 stress scenario"
    assert {1, 2, 3} <= gap_mults, "gap ladder must cover x1/x2/x3"
    assert {1, 2, 3} <= spread_mults, "spread ladder must cover x1/x2/x3"
    # The combined-worst scenario applies to all four families.
    combined = next(s for s in scenarios if s["id"] == "s08_combined_worst")
    assert set(combined["applies_to"]) == fam_ids
    # Family-declared scenario references resolve.
    for fid, fam in _families(cfg).items():
        for ref in fam["stress_scenarios"]:
            assert ref in ids, f"{fid}: unknown stress scenario reference {ref}"


def test_slippage_allowance_is_declared_for_every_family():
    cfg = _load()
    allowances = cfg["stress_matrix"]["slippage_allowance_pct_by_family"]
    for fid in FAMILY_IDS:
        assert fid in allowances, f"{fid}: slippage allowance missing"
        assert 0 < allowances[fid] <= 1.0


def test_family_references_match_risk_contract_schema_family():
    # sizing_progression types and per-level tables must be internally consistent.
    for fid, fam in _families(_load()).items():
        contract = fam["contract"]
        sizing = contract["sizing_progression"]
        assert sizing["type"] in {"flat", "linear", "geometric", "custom"}
        table = fam["mechanics"]["size_progression"]
        assert len(table) == contract["max_levels"]
        assert all(isinstance(x, (int, float)) and x > 0 for x in table)


def test_joint_tail_protocol_is_read_only_and_statistically_specified():
    cfg = _load()
    jtp = cfg["joint_tail_protocol"]
    assert jtp["read_only"] is True
    assert len(jtp["data_inputs"]) >= 4
    assert all(isinstance(i, str) and i.strip() for i in jtp["data_inputs"])
    assert "never a live source" in jtp["data_inputs"][3], "news calendar must be factory-evidence-only"
    methods = jtp["methods"]
    for required in (
        "empirical_joint_tails",
        "lower_tail_dependence_lambda_L",
        "worst_day_overlap",
        "correlation_convergence",
        "block_bootstrap_joint_worst_sequence",
        "drawdown_clustering",
        "joint_basket_escalation",
        "common_symbol_exposure",
        "margin_escalation_path",
        "gaussian_copula_tail_comparison",
        "simultaneous_recovery_escalation",
    ):
        assert required in methods, f"joint-tail protocol missing method {required}"
    # Gaussian copula is a baseline diagnostic, never a safety argument.
    assert "NOT A SAFETY ARGUMENT" in methods["gaussian_copula_tail_comparison"]
    # Bootstrap discipline mirrors the book-evolution convention (block 10d, >=1000 reps).
    bb = methods["block_bootstrap_joint_worst_sequence"]
    assert "block = 10 days" in bb and "2000" in bb
    acceptance = jtp["acceptance_rule"]
    assert set(acceptance) >= {
        "part_1_joint_tail_bound",
        "part_2_no_hidden_common_ruin_mode",
        "part_3_additive_not_illusory",
        "part_4_every_sleeve_bounded",
    }
    thresholds = jtp["proposed_thresholds"]
    assert thresholds["_status"].startswith("PROPOSED_PENDING_OWNER_RATIFICATION")
    assert 0 < thresholds["lambda_L_max_at_alpha_0.05"] < 1
    assert 0 < thresholds["joint_escalation_max_prob_per_quarter_sim"] < 1
    assert thresholds["joint_worst_day_max_pct_of_equity"] <= cfg["budgets_reference"]["effective_joint_daily_loss_budget_pct"]


def test_budgets_reference_matches_ratified_concentration_tail_limits():
    cfg = _load()
    ref = cfg["budgets_reference"]
    assert ref["venue_daily_loss_limit_pct"] == 5.0
    assert ref["maximum_fraction_of_daily_limit"] == 0.8
    assert ref["effective_joint_daily_loss_budget_pct"] == 4.0
    assert ref["stop_risk_budget_pct"] == 11.0
    assert ref["per_sleeve_worst_fraction"] == 0.05


def test_no_verdict_or_gate_semantics_in_config():
    # Research specification only: the config must not carry verdict/gate/deploy keys.
    cfg = _load()
    blob = json.dumps(cfg).lower()
    for forbidden in ('"verdict"', '"gate_decision"', '"deploy"', '"autotrading"'):
        assert forbidden not in blob, f"forbidden key present: {forbidden}"
