from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA = ROOT / "framework" / "EAs" / "QM5_13206_ftmo-account-governor"
SOURCE = EA / "QM5_13206_ftmo-account-governor.mq5"
POLICY = ROOT / "framework" / "include" / "QM" / "QM_FTMOGovernorPolicy.mqh"
CLIENT = ROOT / "framework" / "include" / "QM" / "QM_FTMOGovernorClient.mqh"


def test_governor_defaults_are_non_deployable_and_need_explicit_state() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    preset = (
        EA / "sets" / "QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_dryrun.set"
    ).read_text(encoding="utf-8")

    for declaration in (
        "expected_account_login              = 0",
        'challenge_id                        = ""',
        "challenge_start_utc                 = 0",
        'allowed_magics_csv                  = ""',
        "governor_dry_run                    = true",
        "challenge_state_bootstrap             = false",
        "bootstrap_no_prior_breach_confirmed   = false",
    ):
        assert declaration in source
    for setting in (
        "expected_account_login=0",
        "challenge_id=\n",
        "challenge_start_utc=0",
        "allowed_magics_csv=\n",
        "governor_dry_run=true",
        "challenge_state_bootstrap=false",
        "bootstrap_no_prior_breach_confirmed=false",
    ):
        assert setting in preset


def test_v1_policy_is_exact_and_fingerprint_bound() -> None:
    policy = POLICY.read_text(encoding="utf-8")
    source = SOURCE.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")

    assert "QM_FTMO_IsExactV1Policy" in policy
    assert "3543540590062.0" in policy
    assert "input double policy_" not in source
    assert 'StateWrite("fingerprint",QM_FTMO_V1_FINGERPRINT_NUMBER)' in source
    assert "fingerprint != QM_FTMO_V1_FINGERPRINT_NUMBER" in client


def test_snapshot_uses_generation_and_ready_last_for_allow() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    publication = source[
        source.index("bool PublishSnapshot(") : source.index("bool PublishFailClosed(")
    ]

    odd = publication.index('StateWrite("generation",(double)odd_generation)')
    lock = publication.index('StateWrite("entry_lock",1.0)')
    heartbeat = publication.index('StateWrite("heartbeat_utc",(double)now_utc)')
    even = publication.index('StateWrite("generation",(double)even_generation)')
    ready = publication.index('StateWrite("ready",1.0)')
    assert odd < lock < heartbeat < even < ready


def test_client_double_reads_generation_and_fails_closed() -> None:
    client = CLIENT.read_text(encoding="utf-8")

    assert "generation_before" in client
    assert "generation_after" in client
    assert "generation_before != generation_after" in client
    for reason in (
        "GOVERNOR_CLIENT_CONFIG_INVALID",
        "GOVERNOR_STATE_MISSING",
        "GOVERNOR_SNAPSHOT_IN_PROGRESS",
        "GOVERNOR_SNAPSHOT_CHANGED",
        "GOVERNOR_NOT_READY",
        "GOVERNOR_POLICY_MISMATCH",
        "GOVERNOR_HEARTBEAT_STALE",
        "GOVERNOR_DAY_MISMATCH",
        "GOVERNOR_ENTRY_LOCKED",
        "GOVERNOR_SCALE_INVALID",
    ):
        assert reason in client


def test_target_capture_cancels_pending_and_flattens_whitelist() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "if(decision.target_reached || decision.target_complete)" in source
    action = source[source.index("if((g_day_lock || g_total_lock || g_target_lock)") :]
    assert action.index("DeleteGovernedPendingOrders()") < action.index(
        "CloseGovernedPositions()"
    )
    assert "g_trading_days >= g_policy.minimum_trading_days" in source
    assert "MagicAllowed(OrderGetInteger(ORDER_MAGIC))" in source
    assert "MagicAllowed(PositionGetInteger(POSITION_MAGIC))" in source


def test_bootstrap_singleton_unknown_exposure_and_account_mode_fail_closed() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "GlobalVariableSetOnCondition" in source
    assert "FTMO_GOVERNOR_SINGLETON_LEASE_UNAVAILABLE" in source
    assert "FTMO_GOVERNOR_BOOTSTRAP_COMPLETE_RESTART_WITH_BOOTSTRAP_FALSE" in source
    assert "FTMO_GOVERNOR_STATE_MISSING_OR_INVALID_EXPLICIT_BOOTSTRAP_REQUIRED" in source
    assert "PoisonInvalidState" in source
    assert "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING" in source
    assert 'AccountInfoString(ACCOUNT_CURRENCY) != "USD"' in source
    assert "FindUnknownExposure" in source
    assert "QM_FTMO_GOVERNOR_UNKNOWN_EXPOSURE" in source
