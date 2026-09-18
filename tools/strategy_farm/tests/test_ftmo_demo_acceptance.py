"""FTMO Demo acceptance decision rule (docs/ftmo/FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md).

Directive OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 section 51: the acceptance
criteria are defined before the demo is judged. These tests pin the decision rule of
contract section 6 - exactly one of BUY_RECOMMENDED / EXTEND_DEMO / RECOMPOSE / NOT_READY -
and the UNMEASURED semantics (missing evidence never counts as a pass).
"""
from __future__ import annotations

from tools.strategy_farm.ftmo import demo_acceptance as da


def _cycle(**kw):
    base = {
        "roster_hash": da.FROZEN_ROSTER_HASH,
        "total_book_risk_pct": da.FROZEN_BOOK_RISK_PCT,
        "validation_days": 15.0,
        "state": "REPRESENTATIVE",
    }
    base.update(kw)
    return base


def _metrics(**kw):
    lc = {
        "closed_trades": 13,
        "entry_trading_days": 9,
        "net_usd": 210.0,
        "worst_day_usd": -400.0,
        "realized_max_dd_usd": -900.0,
        "swap_total_usd": -70.0,
    }
    lc.update(kw)
    return {"status": "OK", "latest_cycle": lc}


def _fp(lcb=0.8839, roster_label=da.FROZEN_ROSTER_LABEL):
    return {"roster_label": roster_label,
            "compact_for_readiness": {"p_first_net_ftmo_payout_lcb": lcb}}


_HEALTHY = dict(
    rules_age_days=1.0,
    sleeve_entries={13213: 8, 10706: 2, 10700: 2, 11422: 1, 10403: 0, 41219: 0},
    joint={"max_concurrent_sleeves": 3, "max_joint_risk_pct": 1.09375},
    runtime_stable=True,
)


def _decide(cycle=None, metrics=None, fp=None, **kw):
    opts = dict(_HEALTHY)
    opts.update(kw)
    checks = da.evaluate(cycle or _cycle(), metrics or _metrics(), fp or _fp(), **opts)
    return da.decide(checks, (cycle or _cycle()).get("state")), checks


def test_healthy_representative_cycle_recommends_buy():
    d, _ = _decide()
    assert d["verdict"] == "BUY_RECOMMENDED"


def test_verdict_is_always_exactly_one_of_four():
    for kwargs in ({}, {"cycle": _cycle(validation_days=3.0)},
                   {"metrics": {"status": "EVIDENCE_MISSING"}},
                   {"fp": _fp(0.5)}):
        d, _ = _decide(**kwargs)
        assert d["verdict"] in ("BUY_RECOMMENDED", "EXTEND_DEMO", "RECOMPOSE", "NOT_READY")


def test_short_cycle_extends_never_buys():
    d, _ = _decide(cycle=_cycle(validation_days=0.3, state="RUNNING"))
    assert d["verdict"] == "EXTEND_DEMO"
    assert any(r.startswith("A1") for r in d["reasons"])


def test_realised_breach_is_not_ready_and_outranks_everything():
    d, _ = _decide(metrics=_metrics(worst_day_usd=-5200.0))
    assert d["verdict"] == "NOT_READY"
    d, _ = _decide(metrics=_metrics(realized_max_dd_usd=-10400.0))
    assert d["verdict"] == "NOT_READY"


def test_drawdown_worse_than_any_modelled_path_recomposes():
    d, _ = _decide(metrics=_metrics(realized_max_dd_usd=-4200.0))
    assert d["verdict"] == "RECOMPOSE"


def test_density_collapse_recomposes_but_mild_shortfall_extends():
    d, _ = _decide(metrics=_metrics(closed_trades=6))
    assert d["verdict"] == "RECOMPOSE"  # at/below the Poisson rejection point
    d, _ = _decide(metrics=_metrics(closed_trades=8))
    assert d["verdict"] == "EXTEND_DEMO"  # under-evidenced, time can fix it


def test_low_lcb_recomposes_and_mid_band_extends():
    assert _decide(fp=_fp(0.55))[0]["verdict"] == "RECOMPOSE"
    assert _decide(fp=_fp(0.75))[0]["verdict"] == "EXTEND_DEMO"


def test_roster_drift_unbinds_the_contract():
    d, _ = _decide(cycle=_cycle(roster_hash="deadbeef"))
    assert d["verdict"] == "NOT_READY"
    assert any(r.startswith("A14") for r in d["reasons"])


def test_unmeasured_decision_critical_check_blocks_buy_and_names_an_unblocker():
    d, checks = _decide(joint=None)
    assert d["verdict"] == "EXTEND_DEMO"
    assert any(c["id"] == "A11" and c["status"] == da.UNMEASURED for c in checks)
    assert d["unblockers"]


def test_missing_journal_never_passes_a_check():
    d, checks = _decide(metrics={"status": "EVIDENCE_MISSING"})
    assert d["verdict"] in ("EXTEND_DEMO", "NOT_READY")
    for cid in ("A2", "A5", "A6a", "A7a"):
        c = next(c for c in checks if c["id"] == cid)
        assert c["status"] == da.UNMEASURED


def test_per_sleeve_density_is_unmeasured_without_the_pulse_repin():
    _, checks = _decide(sleeve_entries=None)
    for cid in ("A3", "A4"):
        c = next(c for c in checks if c["id"] == cid)
        assert c["status"] == da.UNMEASURED and not c["decision_critical"]


def test_losing_fortnight_alone_does_not_block_purchase():
    """Modelled P(14d net < 0) = 0.434 - a negative cycle is not an acceptance failure."""
    d, checks = _decide(metrics=_metrics(net_usd=-900.0))
    assert d["verdict"] == "BUY_RECOMMENDED"
    assert next(c for c in checks if c["id"] == "A8")["escalation"] is None


def test_three_attention_checks_downgrade_buy():
    d, _ = _decide(
        metrics=_metrics(closed_trades=9, entry_trading_days=6, worst_day_usd=-820.0),
        sleeve_entries={13213: 4, 10706: 1, 10700: 1, 11422: 0, 10403: 0, 41219: 0},
    )
    assert d["verdict"] == "EXTEND_DEMO"
    assert len(d["attention"]) >= 3


def test_runtime_instability_and_stale_rules_are_not_ready():
    assert _decide(runtime_stable=False)[0]["verdict"] == "NOT_READY"
    assert _decide(rules_age_days=45.0)[0]["verdict"] == "NOT_READY"


def test_first_passage_for_another_roster_never_scores_this_book():
    """The live read-model was still roster_label=demo_8 at cutover - it must not leak in."""
    d, checks = _decide(fp=_fp(0.99, roster_label="demo_8"))
    c = next(c for c in checks if c["id"] == "A15")
    assert c["status"] == da.UNMEASURED and c["observed"] is None
    assert "demo_8" in c["note"]
    assert d["verdict"] == "EXTEND_DEMO"


def test_partial_window_never_fails_a_count_check():
    """A 14-day count statistic cannot be failed on day 3 - only UNMEASURED."""
    _, checks = _decide(cycle=_cycle(validation_days=3.0, state="RUNNING"),
                        metrics=_metrics(closed_trades=1, entry_trading_days=1))
    for cid in ("A2", "A5"):
        assert next(c for c in checks if c["id"] == cid)["status"] == da.UNMEASURED


def test_non_representative_state_cannot_buy():
    d, _ = _decide(cycle=_cycle(state="NEW"))
    assert d["verdict"] == "EXTEND_DEMO"
