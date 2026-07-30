from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODULE = (
    ROOT
    / "framework"
    / "include"
    / "QM"
    / "modules"
    / "QM_Mod_FtmoStandaloneEventComplete.mqh"
)

SLEEVES = (
    (
        9936,
        "USDJPY.DWX",
        "H1",
        "QM5_9936_ff-range-breakout-gmt3-h1",
        0,
    ),
    (10145, "XAUUSD.DWX", "D1", "QM5_10145_tsm-meanret", 34),
    (13108, "XTIUSD.DWX", "D1", "QM5_13108_xti-mtsm-s2", 0),
)


def _module() -> str:
    return MODULE.read_text(encoding="utf-8")


def _ea_source(directory: str) -> str:
    path = ROOT / "framework" / "EAs" / directory / f"{directory}.mq5"
    return path.read_text(encoding="utf-8")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        assert key not in values
        values[key] = value
    return values


def test_module_is_explicit_tester_only_and_has_no_direct_trade_send() -> None:
    source = _module()
    assert "if(!enabled)" in source
    assert "return true; // default path: no file IO" in source
    assert "MQLInfoInteger(MQL_TESTER) == 0" in source
    assert 'StringFind(run_id, "REQUIRED")' in source
    assert "QM_FTMOEC_NoPriorRunArtifacts()" in source
    assert "RUN_ID_ALREADY_HAS_EVIDENCE" in source
    assert "ea_id == 20181" in source
    for forbidden in (
        "OrderSend(",
        "trade.Buy(",
        "trade.Sell(",
        "PositionClose(",
        "OrderDelete(",
    ):
        assert forbidden not in source


def test_five_jsonl_schemas_have_core_required_fields() -> None:
    source = _module()
    required = {
        "FTMO_ORDER_EVENT_V1": (
            "run_id",
            "symbol",
            "magic",
            "time_msc",
            "source_sequence",
            "order_id",
            "position_id",
            "event",
            "type",
            "volume_initial",
            "volume_remaining",
            "price",
            "stop_limit",
            "sl",
            "tp",
        ),
        "FTMO_DEAL_V1": (
            "deal_id",
            "order_id",
            "position_id",
            "entry",
            "side",
            "execution_mode",
            "reason",
            "volume",
            "price",
            "profit",
            "commission",
            "swap",
            "fee",
        ),
        "FTMO_ACCOUNT_EVENT_V1": (
            "event_id",
            "kind",
            "position_id",
            "amount",
        ),
        "FTMO_ACCOUNT_CHECKPOINT_V1": (
            "kind",
            "deal_ids",
            "balance",
            "equity",
            "open_positions",
            "pending_orders",
            "position_swaps",
            "margin",
            "margin_free",
            "margin_level",
            "account_leverage",
            "account_currency",
            "account_margin_mode",
        ),
        "FTMO_POSITION_MODIFICATION_V1": (
            "modification_id",
            "ticket",
            "position_id",
            "old_sl",
            "new_sl",
            "old_tp",
            "new_tp",
            "send_ok",
            "retcode",
            "request_id",
            "request_callback_seen",
            "position_callback_seen",
            "correlated_sl_exit_deal",
        ),
    }
    assert '".jsonl"' in source
    assert "FILE_TXT" in source
    assert "FileWriteString" in source
    for schema, fields in required.items():
        assert schema in source
        for field in fields:
            assert f'\\"{field}\\"' in source


def test_canonical_lifecycle_vocabularies_are_explicit() -> None:
    source = _module()
    for value in (
        "PLACED",
        "MODIFIED",
        "PARTIAL_FILL",
        "FILLED",
        "CANCELLED",
        "EXPIRED",
        "BUY_LIMIT",
        "SELL_LIMIT",
        "BUY_STOP",
        "SELL_STOP",
        "BUY_STOP_LIMIT",
        "SELL_STOP_LIMIT",
        "MARKET",
        "PENDING",
        "EXPERT",
        "SL",
        "TP",
        "STOP_OUT",
        "POSITION_SWAP_MARK",
        "START",
        "DEAL_BOUNDARY",
        "END",
    ):
        assert value in source


def test_history_callback_reconciliation_is_fail_closed() -> None:
    source = _module()
    assert "HistorySelect" in source
    assert "DEAL_TIME_MSC" in source
    assert "ORDER_TIME_SETUP_MSC" in source
    assert "ORDER_TIME_DONE_MSC" in source
    required_failures = {
        "MISSING_DEAL_CALLBACK",
        "DEAL_CALLBACK_HISTORY_CARDINALITY_MISMATCH",
        "DEAL_BOUNDARY_GROUP_CARDINALITY_MISMATCH",
        "DEAL_BOUNDARY_BALANCE_MISMATCH",
        "LATE_OR_NONMONOTONE_DEAL_CALLBACK",
        "INCOMPLETE_ORDER_LIFECYCLE_CALLBACKS",
        "ORDER_MODIFICATION_TIME_UNPROVABLE",
        "ORDER_MODIFICATION_REQUEST_UNCORRELATED",
        "FOREIGN_CASHFLOW_AFTER_START",
        "FOREIGN_POSITION_OR_MAGIC",
        "FOREIGN_ORDER_OR_MAGIC",
        "OPEN_EXPOSURE_OR_PENDING_ORDER_AT_END",
        "NON_CENT_ACCOUNT_MONEY",
        "NON_CENT_DEAL_MONEY",
        "DATA_ARTIFACT_SHA256_FAILED",
        "ONTESTER_COMPLETION_CALLBACK_MISSING",
        "TESTER_TICK_COVERAGE_OUTSIDE_CONTRACT_WINDOW",
        "TRADING_HISTORY_EMPTY_OR_INCOMPLETE",
        "SLTP_INTENT_REQUEST_RECONCILIATION_INCOMPLETE",
        "COMPLETE_RECEIPT_PUBLISH_FAILED",
    }
    for reason in required_failures:
        assert reason in source


def test_complete_receipt_is_post_close_content_addressed_and_strict() -> None:
    source = _module()
    assert "FTMO_STANDALONE_HISTORY_COMPLETE_V1" in source
    assert "CryptEncode(CRYPT_HASH_SHA256" in source
    for field in (
        "orders_sha256",
        "deals_sha256",
        "account_events_sha256",
        "checkpoints_sha256",
        "modifications_sha256",
        "modifications_rows",
        "modifications_file",
        "modification_observation_complete",
        "history_select_complete",
        "end_flat",
        "normal_deinit_complete",
        "execution_manifest_sha256",
        "prague_midnight_proof_sha256",
        "expected_broker_wall_start_msc",
        "expected_broker_wall_end_msc",
        "init_clock_broker_wall_msc",
        "actual_first_tick_broker_wall_msc",
        "actual_last_tick_broker_wall_msc",
        "raw_evidence_window_semantics",
        "prague_boundary_day_policy",
        "producer_window_transform",
        "external_completed_tester_report_required",
        "external_completed_tester_report_verified_by_producer",
        "swap_effective_timing_complete",
        "account_currency",
        "account_margin_mode",
        "expected_account_leverage",
        "time_basis",
    ):
        assert f'\\"{field}\\"' in source
    close_index = source.index("QM_FTMOEC_CloseDataFiles();", source.index("void QM_FTMOEC_Shutdown"))
    hash_index = source.index("QM_FTMOEC_CommonFileSha256", close_index)
    complete_index = source.index("g_qm_ftmoec_complete =", hash_index)
    receipt_index = source.index("QM_FTMOEC_WriteTerminalStatus(true", complete_index)
    assert close_index < hash_index < complete_index < receipt_index
    assert "FileIsExist(path, FILE_COMMON)" in source
    assert "FileMove(temp_path,FILE_COMMON,path,FILE_COMMON)" in source
    assert "FILE_REWRITE" not in source
    assert "DARWINEX_US_DST_BROKER_WALL_EPOCH" in source
    assert "EXACT_BROKER_WALL_TESTER_DATE_RANGE" in source
    assert "PARTIAL_BOUNDARY_DAYS_PRESERVED_IN_RAW_EVIDENCE" in source
    assert "producer_window_transform" in source
    assert "g_qm_ftmoec_on_tester_seen" in source
    assert "TIMECURRENT_AT_ONINIT_NOT_A_TICK_BOUNDARY" in source
    assert "g_qm_ftmoec_actual_first_tick_msc = tick.time_msc" in source
    assert "effective_time_msc\\\":null" in source
    assert "UNRESOLVED_EXTERNAL_PRAGUE_RECONCILIATION_REQUIRED" in source


def test_three_eas_have_default_off_minimal_lifecycle_hooks() -> None:
    for _ea_id, _symbol, _timeframe, directory, _slot in SLEEVES:
        source = _ea_source(directory)
        assert "#include <QM/modules/QM_Mod_FtmoStandaloneEventComplete.mqh>" in source
        assert "input bool   qm_ftmo_event_complete_enabled = false;" in source
        assert source.count("QM_FTMOEC_Init(") == 1
        assert source.count("QM_FTMOEC_Shutdown(reason);") == 1
        assert source.count("QM_FTMOEC_OnTick();") == 1
        assert source.count("QM_FTMOEC_OnTimer();") == 1
        assert source.count("QM_FTMOEC_OnTradeTransaction(trans, request, result);") == 1
        assert source.count("QM_FTMOEC_OnTester();") == 1
        on_tester = source.index("double OnTester()")
        refresh = source.index("QM_ChartUI_Refresh();", on_tester)
        objective = source.index("const double objective = QM_DefaultObjective();", refresh)
        completed = source.index("QM_FTMOEC_OnTester();", objective)
        returned = source.index("return objective;", completed)
        assert on_tester < refresh < objective < completed < returned
        deinit = source.index("void OnDeinit")
        assert source.index("QM_FTMOEC_Shutdown(reason);", deinit) < source.index(
            "QM_FrameworkShutdown();", deinit
        )


def test_dedicated_sets_require_unique_content_addressed_materialization() -> None:
    for ea_id, symbol, timeframe, directory, slot in SLEEVES:
        set_path = (
            ROOT
            / "framework"
            / "EAs"
            / directory
            / "sets"
            / f"{directory}_{symbol}_{timeframe}_ftmo_event_complete.set"
        )
        values = _set_values(set_path)
        assert values["qm_ea_id"] == str(ea_id)
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["qm_ftmo_event_complete_enabled"] == "true"
        assert values["qm_ftmo_event_complete_expected_broker_wall_start_msc"] == "0"
        assert values["qm_ftmo_event_complete_expected_broker_wall_end_msc"] == "0"
        assert values["qm_ftmo_event_complete_expected_model"] == "4"
        assert values["qm_ftmo_event_complete_expected_account_currency"] == "USD"
        assert values["qm_ftmo_event_complete_expected_account_margin_mode"] == "2"
        assert values["qm_ftmo_event_complete_expected_account_leverage"] == "100"
        run_id = values["qm_ftmo_event_complete_run_id"]
        assert run_id == "FTMO_EVENT_COMPLETE_UNIQUE_RUN_ID_REQUIRED"
        header = set_path.read_text(encoding="utf-8")
        assert "native_standalone: true" in header
        assert "joint_ea: false" in header
        assert "admission_authority: none" in header
        assert "template_requires_content_addressed_materialization: true" in header
        assert "producer transform NONE" in header


def test_order_events_are_buffered_and_deterministically_materialized() -> None:
    source = _module()
    assert "g_qm_ftmoec_order_buffer_rows" in source
    assert "QM_FTMOEC_WriteBufferedOrderEvents();" in source
    assert "FTMOEC_SEQUENCE_REQUIRED" in source
    assert "ORDER_EVENT_SEQUENCE_MATERIALIZATION_FAILED" in source
    assert "ORDER_EVENT_OUTSIDE_CONTRACT_WINDOW" in source
    assert "g_qm_ftmoec_order_buffer_priorities[j] > priority" in source
    callback = source[source.index("void QM_FTMOEC_RecordOrderCallback") :]
    callback = callback[: callback.index("void QM_FTMOEC_WriteBufferedOrderEvents")]
    assert "FileWriteString(g_qm_ftmoec_order_fh" not in callback


def test_9936_trailing_stop_uses_exactly_one_observed_trade_path() -> None:
    module = _module()
    sleeve_9936 = _ea_source("QM5_9936_ff-range-breakout-gmt3-h1")
    assert module.count("return QM_TM_MoveSL(ticket, new_sl, reason);") == 1
    assert module.count("const bool ok = QM_TM_MoveSL(ticket, new_sl, reason);") == 1
    assert "g_qm_tm_last_sltp_snapshot" not in module
    assert "TRADE_TRANSACTION_REQUEST" in module
    assert "SLTP_REQUEST_CALLBACK_RESULT_MISMATCH" in module
    assert "SLTP_POSITION_CALLBACK_MISSING" in module
    assert "DEAL_REASON_SL" in module
    assert "correlated_sl_exit_deal" in module
    assert "QM_FTMOEC_ReconcileAndWriteSltpModifications();" in module
    assert "QM_FTMOEC_MoveSL(ticket, normalized_sl" in sleeve_9936
    assert "QM_TM_MoveSL(ticket, normalized_sl" not in sleeve_9936
