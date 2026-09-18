from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA = ROOT / "framework/EAs/QM5_13206_ftmo-account-governor/QM5_13206_ftmo-account-governor.mq5"
SETS = EA.parent / "sets"
HARNESS = ROOT / "framework/tests/mql5/QM_FTMO_AccountControlAcceptance.mq5"


def _set(path: Path) -> dict[str, str]:
    return {
        line.split("=", 1)[0]: line.split("=", 1)[1].split("||", 1)[0]
        for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith(";") and "=" in line
    }


def test_runtime_is_bound_to_m13_identity_and_fail_closed_controls():
    source = EA.read_text(encoding="utf-8")
    assert 'expected_account_login != 1514536732' in source
    assert 'expected_account_server != "FTMO-Demo"' in source
    assert "AccountInfoString(ACCOUNT_SERVER) != expected_account_server" in source
    assert "qm_news_stale_max_hours > 336" in source
    assert "QM_NewsAllowsTrade2" in source
    assert 'StringFormat("QM\\\\halt\\\\%d.halt",ea_id)' in source
    assert "g_halt_latched=true" in source
    assert 'StateWrite("halt_latched"' in source
    assert "FileDelete(target)" not in source


def test_install_presets_bind_exact_account_policy_and_sleeves():
    names = [
        "QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_bootstrap.set",
        "QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set",
    ]
    values = [_set(SETS / name) for name in names]
    for item in values:
        assert item["signed_policy_id"] == "FTMO_2S_P1_100K_V2"
        assert item["expected_account_login"] == "1514536732"
        assert item["expected_account_server"] == "FTMO-Demo"
        assert item["qm_news_stale_max_hours"] == "336"
        assert item["qm_news_temporal"] == "3"
        assert item["qm_news_compliance"] == "2"
        assert item["qm_friday_close_hour_broker"] == "21"
        assert item["qm_friday_flat_lead_minutes"] == "5"
        assert item["governor_dry_run"] == "false"
        # Roster-driven since the demo book v3 (D2g6) cutover: `governor_rebind`
        # rewrites these CSVs from the active roster, so the sleeve COUNT is a
        # book property, not a contract constant (it was 8 under the 2026-09-06
        # M13 book, 6 under D2g6). What the contract fixes is the shape: both
        # presets agree, every magic obeys ea_id*10000+slot, and every governed
        # ea_id has at least one magic.
        magics = [int(m) for m in item["allowed_magics_csv"].split(",")]
        ea_ids = [int(e) for e in item["governed_ea_ids_csv"].split(",")]
        assert magics and ea_ids
        assert magics == sorted(magics) and len(set(magics)) == len(magics)
        assert ea_ids == sorted(ea_ids) and len(set(ea_ids)) == len(ea_ids)
        assert {m // 10000 for m in magics} == set(ea_ids)
    assert values[0]["allowed_magics_csv"] == values[1]["allowed_magics_csv"]
    assert values[0]["governed_ea_ids_csv"] == values[1]["governed_ea_ids_csv"]
    assert values[0]["challenge_state_bootstrap"] == "true"
    assert values[1]["challenge_state_bootstrap"] == "false"


def test_native_acceptance_covers_all_mandated_cases():
    source = HARNESS.read_text(encoding="utf-8")
    for case in (
        "daily_breach_prague_midnight",
        "static_total_breach",
        "friday_cutoff",
        "mandatory_news_blackout",
        "restart_halt_persistence",
    ):
        assert f'"{case}"' in source
    assert "MQLInfoInteger(MQL_TESTER)" in source
    assert "qm.ftmo-governor-native-acceptance/v1" in source
