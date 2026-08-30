from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm.canonical_hash import canonical_blob_sha256


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_36005_nnfx-coral-trendlord-woodies-harvester"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
CARD = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_36005_nnfx-coral-trendlord-woodies-harvester.md"
)
SETS = {
    "GBPJPY.DWX": (0, EA_DIR / "sets" / f"{LABEL}_GBPJPY.DWX_D1_backtest.set"),
    "EURJPY.DWX": (1, EA_DIR / "sets" / f"{LABEL}_EURJPY.DWX_D1_backtest.set"),
    "AUDNZD.DWX": (2, EA_DIR / "sets" / f"{LABEL}_AUDNZD.DWX_D1_backtest.set"),
}


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source)
    assert match, name
    start = source.index("{", match.start())
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def test_approved_card_and_registry_identity_are_intact() -> None:
    card = CARD.read_text(encoding="utf-8")
    assert re.search(r"^g0_status:\s*APPROVED$", card, re.MULTILINE)
    assert re.search(r"^ea_id:\s*QM5_36005$", card, re.MULTILINE)
    assert re.search(
        r"^slug:\s*nnfx-coral-trendlord-woodies-harvester$", card, re.MULTILINE
    )

    with (REPO / "framework" / "registry" / "ea_id_registry.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        ea_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36005"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "nnfx-coral-trendlord-woodies-harvester"
    assert ea_rows[0]["status"] == "active"

    with (REPO / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        magic_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36005"]
    assert [(row["symbol_slot"], row["symbol"], row["status"]) for row in magic_rows] == [
        ("0", "GBPJPY.DWX", "active"),
        ("1", "EURJPY.DWX", "active"),
        ("2", "AUDNZD.DWX", "active"),
    ]


def test_card_signal_uses_smma_and_woodies_only_as_entry_confirmation() -> None:
    source = _source()
    entry = _compact(_function_body(source, "Strategy_EntrySignal"))
    exit_body = _compact(_function_body(source, "Strategy_ExitSignal"))

    assert "QM_SMMA(_Symbol,PERIOD_D1,strategy_coral_period,1,PRICE_CLOSE)" in entry
    assert "QM_LWMA(_Symbol,PERIOD_D1,strategy_trendlord_period,1,PRICE_CLOSE)" in entry
    assert "QM_CCI(_Symbol,PERIOD_D1,strategy_woodies_cci_period,1,PRICE_TYPICAL)" in entry
    assert "wae_value<=explosion_line" in entry
    assert "woodies_cci_1>0.0" in entry
    assert "woodies_cci_1<0.0" in entry
    assert "QM_CCI(" not in exit_body
    assert "strategy_woodies_cci_period" not in exit_body
    assert "trendlord_color<0" in exit_body
    assert "trendlord_color>0" in exit_body
    assert not re.search(r"\b(?:e1|e2|e3|e4|e5|e6)\s*\[", source)
    assert "strategy_coral_coeff" not in source


def test_tp1_is_one_partial_close_with_a_durable_runner_marker() -> None:
    source = _source()
    entry = _compact(_function_body(source, "Strategy_EntrySignal"))
    manage = _compact(_function_body(source, "Strategy_ManageOpenPosition"))

    assert "req.tp=0.0;" in entry
    assert "g_strategy_tp1_initial_volume*strategy_tp1_fraction" in manage
    assert manage.count("QM_TM_PartialClose(") == 1
    assert "GlobalVariableSet(g_strategy_tp1_marker_key,1.0)" in manage
    assert "if(g_strategy_tp1_done)" in manage
    assert "NNFX_TP1_BE_PROTECTION_RETRY" in manage
    assert "QM_TM_MoveSL(" in manage


def test_loss_limits_gmt_rollover_and_slippage_contract_are_wired() -> None:
    source = _source()
    compact = _compact(source)
    no_trade = _compact(_function_body(source, "Strategy_NoTradeFilter"))
    total_dd = _compact(_function_body(source, "Strategy_TotalDrawdownHalt"))
    on_init = _compact(_function_body(source, "OnInit"))

    assert "QM_BrokerToUTC(broker_now)" in no_trade
    assert "utc_parts.hour==23&&utc_parts.min>=55" in no_trade
    assert "utc_parts.hour==0&&utc_parts.min<=5" in no_trade
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "strategy_daily_hard_stop_pct,strategy_total_dd_halt_pct" in on_init
    assert "g_strategy_initial_equity*(1.0-strategy_total_dd_halt_pct/100.0)" in total_dd
    assert "Strategy_CloseOwnedPositions(QM_EXIT_KILLSWITCH)" in total_dd
    assert "GlobalVariableSet(g_strategy_total_dd_halt_key,1.0)" in total_dd
    assert "strategy_max_slippage_ticks*tick_size/point" in compact
    assert "QM_EntryConfigure(qm_ea_id,qm_news_mode_legacy,max_slippage_points" in on_init


def test_management_and_exit_precede_entry_only_filters() -> None:
    on_tick = _compact(_function_body(_source(), "OnTick"))

    management = on_tick.index("Strategy_ManageOpenPosition();")
    exit_signal = on_tick.index("if(Strategy_ExitSignal())")
    news_gate = on_tick.index("if(!news_allows)return;")
    new_bar = on_tick.index("if(!QM_IsNewBar(_Symbol,PERIOD_D1))return;")
    no_trade = on_tick.index("if(Strategy_NoTradeFilter())return;")

    assert management < news_gate
    assert exit_signal < news_gate
    assert news_gate < new_bar < no_trade


def test_framework_corset_and_bounded_indicator_access_remain_intact() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "req.symbol_slot=0;" in compact
    assert "QM_IsNewBar(_Symbol,PERIOD_D1)" in compact
    assert "QM_KillSwitchCheck()" in source
    assert "QM_FrameworkOnTradeTransaction(" in source
    assert not re.search(r"\b(?:iClose|iOpen|iHigh|iLow|iTime|CopyRates|CopyBuffer)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_every_declared_strategy_input_has_a_non_declaration_use_site() -> None:
    source = _source()
    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert strategy_inputs == [
        "strategy_coral_period",
        "strategy_trendlord_period",
        "strategy_woodies_cci_period",
        "strategy_wae_fast",
        "strategy_wae_slow",
        "strategy_wae_signal",
        "strategy_wae_bb_period",
        "strategy_wae_bb_deviation",
        "strategy_wae_sensitivity",
        "strategy_atr_period",
        "strategy_sl_atr_mult",
        "strategy_tp1_atr_mult",
        "strategy_tp1_fraction",
        "strategy_be_buffer_pips",
        "strategy_spread_atr_mult",
        "strategy_daily_loss_halt_pct",
        "strategy_daily_hard_stop_pct",
        "strategy_total_dd_halt_pct",
        "strategy_max_slippage_ticks",
    ]
    for input_name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(input_name)}\b", source)) >= 2, input_name


def test_backtest_sets_bind_registered_slots_fixed_risk_and_all_inputs() -> None:
    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        _source(),
        flags=re.MULTILINE,
    )

    for symbol, (slot, set_path) in SETS.items():
        content = set_path.read_text(encoding="utf-8-sig")
        assert f"; symbol:       {symbol}" in content
        assert "; timeframe:    D1" in content
        assert "; environment:  backtest" in content
        assert f"; magic_slot:   {slot}" in content
        assert f"qm_magic_slot_offset={slot}" in content
        assert "RISK_FIXED=1000" in content
        assert "RISK_PERCENT=0" in content
        canonical_source_hash = canonical_blob_sha256(EA, repo_root=REPO)
        assert f"; build_hash:   {canonical_source_hash}" in content
        for input_name in strategy_inputs:
            assert re.search(rf"^{re.escape(input_name)}=", content, re.MULTILINE), input_name
