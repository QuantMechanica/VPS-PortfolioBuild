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


def _write_journal(path, lines):
    text = "\n".join(lines) + "\n"
    path.write_text(text, encoding="utf-16")


def test_unambiguous_symbol_ea_ids_skips_shared_symbols():
    roster = _roster(
        (100, "EURUSD", 0.3, "sha1"),
        (200, "EURUSD", 0.3, "sha2"),
        (300, "GBPUSD", 0.3, "sha3"),
    )
    assert dc._unambiguous_symbol_ea_ids(roster) == {"GBPUSD": 300}


def test_observe_journal_placements_counts_trades_lines_for_unambiguous_symbol(tmp_path):
    roster = _roster((21505, "XAGUSD", 0.3, "sha1"))
    journal_dir = tmp_path / "Logs"
    journal_dir.mkdir()
    _write_journal(journal_dir / "20260918.log", [
        "EL\t0\t00:05:00.203\tTrades\t'1514536732': market buy 0.01 XAGUSD sl: 59.216",
        "JG\t0\t00:05:00.247\tTrades\t'1514536732': accepted market buy 0.01 XAGUSD sl: 59.216",
        "AB\t0\t00:05:00.500\tNetwork\t'1514536732': scanning network for access points",
    ])

    counts = dc.observe_journal_placements(journal_dir, roster)

    assert counts == {21505: 2}


def test_observe_journal_placements_skips_ambiguous_shared_symbol(tmp_path):
    """The journal has no magic number, so a symbol shared by two sleeves
    (matching QM5_1537 and QM5_21505 both trading XAGUSD on the live demo
    chart profile today) must not be attributed to either one."""
    roster = _roster((1537, "XAGUSD", 0.3, "shaA"), (21505, "XAGUSD", 0.3, "shaB"))
    journal_dir = tmp_path / "Logs"
    journal_dir.mkdir()
    _write_journal(journal_dir / "20260918.log", [
        "EL\t0\t00:05:00.203\tTrades\t'1514536732': market buy 0.01 XAGUSD sl: 59.216",
    ])

    counts = dc.observe_journal_placements(journal_dir, roster)

    assert counts == {}


def test_observe_journal_placements_missing_dir_is_evidence_missing(tmp_path):
    roster = _roster((21505, "XAGUSD", 0.3, "sha1"))
    counts = dc.observe_journal_placements(tmp_path / "does_not_exist", roster)
    assert counts == {}


def test_observe_placements_promotes_zero_when_journal_shows_real_fills(tmp_path):
    """Router ops_issue 57bfd3af (2026-09-18, GAPS G7): reproduces the exact
    QM5_21505 case -- its own EA log has zero TM_OPEN/ENTRY_ACCEPTED lines
    (an untracked alias rebuild that doesn't log its own fills) but the
    terminal's native journal proves it placed real orders. attached_dark
    must not be able to fire on that false negative."""
    files_dir = tmp_path / "Files" / "QM"
    files_dir.mkdir(parents=True)
    (files_dir / "QM5_21505_ea-21505.log").write_text(
        '{"event":"INIT_OK"}\n{"event":"FRIDAY_CLOSE"}\n', encoding="utf-8"
    )
    journal_dir = tmp_path / "Logs"
    journal_dir.mkdir()
    _write_journal(journal_dir / "20260918.log", [
        "EL\t0\t00:05:00.203\tTrades\t'1514536732': market buy 0.01 XAGUSD sl: 59.216",
    ])
    roster = _roster((21505, "XAGUSD", 0.3, "sha1"))

    counts = dc.observe_placements(files_dir, journal_dir=journal_dir, roster=roster)

    assert counts == {21505: 1}


def test_observe_placements_never_lowers_a_count_the_ea_log_already_proved(tmp_path):
    files_dir = tmp_path / "Files" / "QM"
    files_dir.mkdir(parents=True)
    (files_dir / "QM5_1537_ea-1537.log").write_text(
        "\n".join(['{"event":"TM_OPEN"}'] * 4), encoding="utf-8"
    )
    journal_dir = tmp_path / "Logs"
    journal_dir.mkdir()
    _write_journal(journal_dir / "20260918.log", [
        "EL\t0\t00:05:00.203\tTrades\t'1514536732': market buy 0.01 XAGUSD sl: 59.216",
    ])
    roster = _roster((1537, "XAGUSD", 0.3, "sha1"))

    counts = dc.observe_placements(files_dir, journal_dir=journal_dir, roster=roster)

    assert counts == {1537: 4}


def test_observe_placements_without_journal_args_is_unchanged(tmp_path):
    files_dir = tmp_path / "Files" / "QM"
    files_dir.mkdir(parents=True)
    (files_dir / "QM5_13054_ea-13054.log").write_text(
        '{"event":"INIT_OK"}\n', encoding="utf-8"
    )

    assert dc.observe_placements(files_dir) == {13054: 0}


def test_attached_dark_fires_once_journal_corroborated_evidence_still_shows_zero(tmp_path):
    """QM5_13054 is genuinely dark (host symbol gate refuses before any order):
    neither its own EA log nor the terminal journal for its unique symbol shows
    a placement, so attached_dark must still fire once enough trading days
    elapse. This proves the journal cross-check does not block a real dark
    determination -- it only prevents a false one."""
    files_dir = tmp_path / "Files" / "QM"
    files_dir.mkdir(parents=True)
    (files_dir / "QM5_13054_ea-13054.log").write_text(
        '{"event":"INIT_OK"}\n', encoding="utf-8"
    )
    journal_dir = tmp_path / "Logs"
    journal_dir.mkdir()
    _write_journal(journal_dir / "20260918.log", [
        "EL\t0\t00:05:00.203\tTrades\t'1514536732': market buy 0.01 XAGUSD sl: 59.216",
    ])
    roster = _roster((13054, "USOIL.cash", 0.3, "sha1"))

    counts = dc.observe_placements(files_dir, journal_dir=journal_dir, roster=roster)
    annotated = dc.flag_attached_dark(roster, counts, trading_days=5)

    assert counts == {13054: 0}
    assert annotated[0]["attached_dark"] is True
