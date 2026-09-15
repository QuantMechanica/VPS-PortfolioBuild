"""FTMO Demo-cycle ledger + material-change contract (slice f1_ftmo_validation_readiness).

Covers directive follow-up sections 13-14: roster identity, cycle-start stability,
the NEW->RUNNING->REPRESENTATIVE state machine, and deterministic material-change
classification. See docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md.
"""
from __future__ import annotations

import datetime as dt

from tools.strategy_farm.ftmo import demo_cycle as dc
from tools.strategy_farm.ftmo import policy_config


def _roster(*rows):
    out = []
    for ea_id, symbol, risk, sha in rows:
        out.append(
            {
                "ea_id": ea_id,
                "ea_name": f"QM5_{ea_id}_x",
                "symbol": symbol,
                "slot": 0,
                "magic": ea_id * 10000,
                "risk_pct": risk,
                "ex5_sha": sha,
            }
        )
    return out


def _obs(roster, product=None, compliance=None):
    return {
        "roster": roster,
        "roster_source": "chart_profile",
        "product": product or policy_config.DEFAULT_ACCOUNT_LABEL,
        "compliance": compliance or {"rulepack": "STANDARD_V2"},
    }


T0 = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)


def test_roster_hash_is_composition_only():
    a = _roster((100, "EURUSD", 0.3, "sha1"))
    # same composition, different risk + ex5 -> same identity hash
    b = _roster((100, "EURUSD", 0.9, "sha2"))
    assert dc.roster_hash(a) == dc.roster_hash(b)
    # different symbol -> different hash
    c = _roster((100, "GBPUSD", 0.3, "sha1"))
    assert dc.roster_hash(a) != dc.roster_hash(c)


def test_state_machine_new_running_representative():
    roster = _roster((100, "EURUSD", 0.3, "sha1"), (200, "GBPUSD", 0.3, "sha1"))
    # first observation -> NEW, cycle_start = now
    l0 = dc.build_demo_cycle(_obs(roster), None, T0)
    assert l0["state"] == "NEW"
    assert l0["is_new_cycle_this_observation"] is True
    assert l0["cycle_start_utc"] == "2026-09-01T00:00:00Z"

    # 5 days later, same roster -> RUNNING
    l1 = dc.build_demo_cycle(_obs(roster), l0, T0 + dt.timedelta(days=5))
    assert l1["state"] == "RUNNING"
    assert l1["cycle_start_utc"] == l0["cycle_start_utc"]

    # 15 days later, same roster, no material change -> REPRESENTATIVE
    l2 = dc.build_demo_cycle(_obs(roster), l1, T0 + dt.timedelta(days=15))
    assert l2["state"] == "REPRESENTATIVE"
    assert l2["representative"] is True
    assert l2["validation_days"] >= policy_config.VALIDATION_MIN_DAYS


def test_sleeve_add_resets_cycle():
    roster = _roster((100, "EURUSD", 0.3, "sha1"))
    l0 = dc.build_demo_cycle(_obs(roster), None, T0)
    l1 = dc.build_demo_cycle(_obs(roster), l0, T0 + dt.timedelta(days=15))
    assert l1["state"] == "REPRESENTATIVE"
    # add a sleeve -> representative-breaking -> back to NEW, clock resets
    roster2 = _roster((100, "EURUSD", 0.3, "sha1"), (200, "GBPUSD", 0.3, "sha1"))
    l2 = dc.build_demo_cycle(_obs(roster2), l1, T0 + dt.timedelta(days=16))
    assert l2["state"] == "NEW"
    assert l2["cycle_start_utc"] == "2026-09-17T00:00:00Z"
    assert l2["material_changes"] == []  # new cycle starts clean


def test_small_risk_change_is_logged_not_material():
    roster = _roster((100, "EURUSD", 0.30, "sha1"), (200, "GBPUSD", 0.30, "sha1"))
    roster_small = _roster((100, "EURUSD", 0.31, "sha1"), (200, "GBPUSD", 0.30, "sha1"))
    res = dc.classify_material_change(roster, roster_small)
    # delta 0.01 on book risk 0.60 -> share 0.0167 < X (0.20)
    assert res["material"] is False
    assert res["resets_cycle"] is False
    assert any(c["type"] == "RISK_CHANGED" for c in res["changes"])


def test_large_risk_change_is_material():
    roster = _roster((100, "EURUSD", 0.30, "sha1"), (200, "GBPUSD", 0.30, "sha1"))
    roster_big = _roster((100, "EURUSD", 0.60, "sha1"), (200, "GBPUSD", 0.30, "sha1"))
    res = dc.classify_material_change(roster, roster_big)
    # delta 0.30 on book risk 0.60 -> share 0.5 > X
    assert res["material"] is True
    assert res["representative_breaking"] is True


def test_mechanics_change_material_but_representative_gated_by_Y():
    # tiny risk share sleeve changes ex5 -> material for sleeve, NOT rep-breaking
    roster = _roster((100, "EURUSD", 0.95, "sha1"), (200, "GBPUSD", 0.05, "sha1"))
    roster_mech = _roster((100, "EURUSD", 0.95, "sha1"), (200, "GBPUSD", 0.05, "shaX"))
    res = dc.classify_material_change(roster, roster_mech)
    mech = [c for c in res["changes"] if c["type"] == "MECHANICS_CHANGED"][0]
    assert mech["material"] is True
    # affected risk 0.05 / book 1.0 = 0.05 < Y (0.10) -> not rep-breaking
    assert mech["representative_breaking"] is False
    assert res["representative_breaking"] is False

    # now the large sleeve changes ex5 -> rep-breaking
    roster_mech2 = _roster((100, "EURUSD", 0.95, "shaZ"), (200, "GBPUSD", 0.05, "sha1"))
    res2 = dc.classify_material_change(roster, roster_mech2)
    mech2 = [c for c in res2["changes"] if c["type"] == "MECHANICS_CHANGED"][0]
    assert mech2["representative_breaking"] is True


def test_product_change_is_material_new_cycle():
    roster = _roster((100, "EURUSD", 0.3, "sha1"))
    res = dc.classify_material_change(
        roster, roster, prev_product="Standard 100k", curr_product="Swing 100k"
    )
    assert res["resets_cycle"] is True
    assert any(c["type"] == "PRODUCT_CHANGED" for c in res["changes"])


def test_compliance_change_is_material():
    roster = _roster((100, "EURUSD", 0.3, "sha1"))
    res = dc.classify_material_change(
        roster, roster, prev_compliance={"news": False}, curr_compliance={"news": True}
    )
    assert res["material"] is True
    assert any(c["type"] == "COMPLIANCE_CHANGED" for c in res["changes"])


def test_empty_roster_is_evidence_missing():
    l0 = dc.build_demo_cycle(_obs([]), None, T0)
    assert l0["roster_hash"] == "EVIDENCE_MISSING"
    assert l0["sleeve_count"] == 0


def test_reproducible_from_frozen_inputs():
    roster = _roster((100, "EURUSD", 0.3, "sha1"))
    l_a = dc.build_demo_cycle(_obs(roster), None, T0)
    l_b = dc.build_demo_cycle(_obs(roster), None, T0)
    assert l_a == l_b
