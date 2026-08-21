from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio.book_builder_common import (
    BookBuildError,
    capped_inverse_vol,
    resolve_roster,
    validate_dual_book_manifest,
)
from tools.strategy_farm.portfolio.build_book_dxz import _gate
from tools.strategy_farm.portfolio.build_book_ftmo import (
    M1_BOOTSTRAP_LINEAGE_COMMIT,
    _bootstrap,
    _cost_coverage,
    load_fund_scores,
    select_under_aggregate_control,
)


def _write(path: Path, payload: object) -> Path:
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def test_q16_roster_promote_and_admit_both_are_deterministic(tmp_path: Path) -> None:
    roster = _write(tmp_path / "roster.json", {
        "schema": "qm.dual-book-roster/v1",
        "q10_pass": [
            {"ea_id": 1, "symbol": "EURUSD.DWX", "q10_verdict": "PASS"},
            {"ea_id": 2, "symbol": "GBPUSD.DWX", "q10_verdict": "PASS"},
        ],
        "q16_outcomes": [
            {
                "verdict": "PROMOTE_CHALLENGER",
                "parent": {"ea_id": 1, "symbol": "EURUSD.DWX"},
                "challenger": {"ea_id": 3, "symbol": "EURUSD.DWX"},
                "challenger_q10_verdict": "PASS",
            },
            {
                "verdict": "ADMIT_BOTH",
                "parent": {"ea_id": 2, "symbol": "GBPUSD.DWX"},
                "challenger": {"ea_id": 4, "symbol": "USDJPY.DWX"},
                "challenger_q10_verdict": "PASS",
            },
        ],
    })
    first, provenance = resolve_roster(roster)
    second, _ = resolve_roster(roster)
    assert first == second == [(2, "GBPUSD.DWX"), (3, "EURUSD.DWX"), (4, "USDJPY.DWX")]
    assert [row["verdict"] for row in provenance["q16_outcomes_applied"]] == [
        "PROMOTE_CHALLENGER", "ADMIT_BOTH"
    ]


def test_q16_roster_fails_closed_without_challenger_q10_pass(tmp_path: Path) -> None:
    roster = _write(tmp_path / "roster.json", {
        "schema": "qm.dual-book-roster/v1",
        "q10_pass": [{"ea_id": 1, "symbol": "EURUSD.DWX"}],
        "q16_outcomes": [{
            "verdict": "PROMOTE_CHALLENGER",
            "parent": {"ea_id": 1, "symbol": "EURUSD.DWX"},
            "challenger": {"ea_id": 3, "symbol": "EURUSD.DWX"},
            "challenger_q10_verdict": "FAIL",
        }],
    })
    with pytest.raises(BookBuildError, match="lacks declared Q10 PASS"):
        resolve_roster(roster)


def test_capped_inverse_vol_exhausts_budget_without_exceeding_cap() -> None:
    keys = [(1, "A.DWX"), (2, "B.DWX"), (3, "C.DWX")]
    matrix = [[1.0, 5.0, 10.0], [-1.0, -5.0, -10.0], [2.0, 1.0, -2.0]]
    weights = capped_inverse_vol(keys, matrix, total=2.4, cap=1.0)
    assert sum(weights.values()) == pytest.approx(2.4)
    assert max(weights.values()) <= 1.0


def test_dxz_not_worse_gate_requires_every_metric() -> None:
    incumbent = {"return_to_maxdd": 2.0, "worst_day_pct": -1.0, "max_drawdown_pct": 4.0}
    assert _gate({"return_to_maxdd": 2.1, "worst_day_pct": -0.9, "max_drawdown_pct": 3.9}, incumbent)["passed"]
    result = _gate({"return_to_maxdd": 2.1, "worst_day_pct": -1.1, "max_drawdown_pct": 3.9}, incumbent)
    assert not result["passed"]
    assert result["checks"]["worst_day_not_worse"] is False


def test_fund_score_formula_is_recomputed(tmp_path: Path) -> None:
    scores = _write(tmp_path / "scores.json", {
        "metric": "FUND_SCORE",
        "rows": [{
            "sleeve": "1:EURUSD", "status": "SCORED", "med60_1x": 10,
            "worst_day_1x": -2, "wdd_p90_1x": 5, "fund_score": 9,
        }],
    })
    with pytest.raises(BookBuildError, match="formula mismatch"):
        load_fund_scores(scores)


def test_ftmo_aggregate_control_admits_two_low_corr_eas_on_same_symbol() -> None:
    # Ratified FTMO policy (OWNER 2026-08-21): multiple EAs on the same symbol are
    # allowed; concentration is controlled at the aggregate (correlation) level. Two
    # LOW-correlation EURUSD sleeves must BOTH be admitted — the old per-symbol cap
    # would have dropped the lower-scoring one as ONE_EA_PER_SYMBOL_LOWER_SCORE.
    roster = [(1, "EURUSD.DWX"), (2, "EURUSD.DWX"), (3, "USDJPY.DWX")]
    scores = {
        roster[0]: {"status": "SCORED", "fund_score": 1.2},
        roster[1]: {"status": "SCORED", "fund_score": 1.4},
        roster[2]: {"status": "SCORED", "fund_score": 0.9},
    }
    correlation = {frozenset({(1, "EURUSD.DWX"), (2, "EURUSD.DWX")}): 0.05}
    selected, rows, control = select_under_aggregate_control(
        roster, scores, correlation, max_pairwise_correlation=0.50,
    )
    assert selected == [(1, "EURUSD.DWX"), (2, "EURUSD.DWX")]
    reasons = {(row["ea_id"], row["symbol"]): row["reason"] for row in rows}
    assert reasons[(1, "EURUSD.DWX")] == "ADMITTED_AGGREGATE_CONTROL"
    assert reasons[(2, "EURUSD.DWX")] == "ADMITTED_AGGREGATE_CONTROL"
    assert reasons[(3, "USDJPY.DWX")] == "FUND_SCORE_BELOW_1"
    assert control["max_admitted_pairwise_correlation"] == 0.05


def test_ftmo_aggregate_control_excludes_high_corr_ea_with_explicit_reason() -> None:
    # Two EURUSD sleeves that are highly correlated: the lower-scoring one is rejected
    # with an explicit CLUSTER_CORRELATION_EXCLUDED reason, never dropped silently.
    roster = [(1, "EURUSD.DWX"), (2, "EURUSD.DWX")]
    scores = {
        roster[0]: {"status": "SCORED", "fund_score": 1.2},
        roster[1]: {"status": "SCORED", "fund_score": 1.4},
    }
    correlation = {frozenset({(1, "EURUSD.DWX"), (2, "EURUSD.DWX")}): 0.92}
    selected, rows, control = select_under_aggregate_control(
        roster, scores, correlation, max_pairwise_correlation=0.50,
    )
    assert selected == [(2, "EURUSD.DWX")]  # highest score admitted first
    excluded = {(row["ea_id"], row["symbol"]): row for row in rows if not row["eligible"]}
    assert excluded[(1, "EURUSD.DWX")]["reason"] == "CLUSTER_CORRELATION_EXCLUDED"
    assert excluded[(1, "EURUSD.DWX")]["aggregate_control"]["correlation"] == 0.92
    assert control["excluded"][0]["reason"] == "CLUSTER_CORRELATION_EXCLUDED"


def test_ftmo_aggregate_control_fails_closed_on_missing_correlation() -> None:
    # Without a correlation datum for the pair, the second sleeve cannot be certified
    # decorrelated and is rejected fail-closed with an explicit reason.
    roster = [(1, "EURUSD.DWX"), (2, "EURUSD.DWX")]
    scores = {
        roster[0]: {"status": "SCORED", "fund_score": 1.4},
        roster[1]: {"status": "SCORED", "fund_score": 1.2},
    }
    selected, rows, _control = select_under_aggregate_control(roster, scores, {})
    assert selected == [(1, "EURUSD.DWX")]
    reasons = {(row["ea_id"], row["symbol"]): row["reason"] for row in rows}
    assert reasons[(2, "EURUSD.DWX")] == "CLUSTER_CORRELATION_UNVERIFIED"


def test_ftmo_aggregate_control_enforces_account_weight_budget() -> None:
    roster = [(1, "EURUSD.DWX"), (2, "USDJPY.DWX"), (3, "GBPUSD.DWX")]
    scores = {
        roster[0]: {"status": "SCORED", "fund_score": 1.4},
        roster[1]: {"status": "SCORED", "fund_score": 1.3},
        roster[2]: {"status": "SCORED", "fund_score": 1.2},
    }
    # Distinct symbols, all decorrelated, but the account budget only funds two sleeves.
    correlation = {
        frozenset({(1, "EURUSD.DWX"), (2, "USDJPY.DWX")}): 0.0,
        frozenset({(1, "EURUSD.DWX"), (3, "GBPUSD.DWX")}): 0.0,
        frozenset({(2, "USDJPY.DWX"), (3, "GBPUSD.DWX")}): 0.0,
    }
    selected, rows, _control = select_under_aggregate_control(
        roster, scores, correlation, account_weight_budget=2.0,
    )
    assert selected == [(1, "EURUSD.DWX"), (2, "USDJPY.DWX")]
    reasons = {(row["ea_id"], row["symbol"]): row["reason"] for row in rows}
    assert reasons[(3, "GBPUSD.DWX")] == "RISK_BUDGET_EXHAUSTED"


def test_ftmo_cost_snapshot_is_hash_bound_and_reports_coverage(tmp_path: Path) -> None:
    snapshot = _write(tmp_path / "cost.json", {
        "book3_normalization": [{"dwx_symbol": "EURUSD.DWX"}]
    })
    digest = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    result, passed, missing = _cost_coverage(
        snapshot, [(1, "EURUSD.DWX"), (2, "USDJPY.DWX")], required_sha256=digest
    )
    assert not passed
    assert missing == ["USDJPY.DWX"]
    assert result["input"]["sha256"] == digest
    with pytest.raises(BookBuildError, match="hash mismatch"):
        _cost_coverage(snapshot, [], required_sha256="0" * 64)


def test_ftmo_bootstrap_is_missing_fail_closed() -> None:
    result = _bootstrap(None, selected_roster_sha256="a" * 64, cost_snapshot_sha256="b" * 64)
    assert not result["passed"]
    assert result["measured_gap"] == 0.8


def test_ftmo_bootstrap_requires_roster_cost_and_lineage_bindings(tmp_path: Path) -> None:
    path = _write(tmp_path / "bootstrap.json", {
        "schema": "qm.ftmo-p1-bootstrap-result/v1",
        "roster_sha256": "a" * 64,
        "cost_snapshot_sha256": "b" * 64,
        "estimated_p_phase1": 0.9,
        "ci_lower_p_phase1": 0.81,
        "replicates": 2000,
        "engine_lineage": {"ftmo_m1_bootstrap_commit": M1_BOOTSTRAP_LINEAGE_COMMIT},
    })
    result = _bootstrap(path, selected_roster_sha256="a" * 64, cost_snapshot_sha256="b" * 64)
    assert result["passed"]
    assert result["measured_gap"] == 0
    with pytest.raises(BookBuildError, match="not bound to the selected"):
        _bootstrap(path, selected_roster_sha256="c" * 64, cost_snapshot_sha256="b" * 64)


def test_dual_book_schema_is_valid_json_schema() -> None:
    jsonschema = pytest.importorskip("jsonschema")
    schema_path = (
        Path(__file__).resolve().parents[3]
        / "tools" / "strategy_farm" / "config" / "dual_book_manifest.v1.schema.json"
    )
    jsonschema.Draft202012Validator.check_schema(json.loads(schema_path.read_text()))


def test_manifest_validator_rejects_any_action_surface() -> None:
    manifest = {
        "schema": "qm.dual-book-manifest/v1", "lane": "Q11_FTMO", "as_of": "2026-08-12",
        "execution_mode": "DRY_RUN", "status": "BAR_NOT_MET", "application_authority": "OWNER_ONLY",
        "deployment_action": "APPLY", "autotrading_action": "NONE", "challenge_recommendation": "NONE",
        "roster_sha256": hashlib.sha256(b"[]").hexdigest(),
        "sleeve_list_sha256": hashlib.sha256(b"[]").hexdigest(), "sleeves": [],
        "fund_score": {}, "density": {}, "ftmo_cost_swap": {}, "phase1_bootstrap": {}, "bar": {},
    }
    with pytest.raises(BookBuildError, match="cannot emit deployment"):
        validate_dual_book_manifest(manifest)
