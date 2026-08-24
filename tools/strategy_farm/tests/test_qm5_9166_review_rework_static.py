from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_9166_aa-vol-ma-timing"
MQ5 = EA_DIR / "QM5_9166_aa-vol-ma-timing.mq5"
SOURCE = MQ5.read_text(encoding="utf-8")


EXPECTED_SLOTS = [
    "GDAXI.DWX",
    "NDX.DWX",
    "SP500.DWX",
    "UK100.DWX",
    "WS30.DWX",
    "XAUUSD.DWX",
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "USDJPY.DWX",
    "USDCHF.DWX",
    "AUDUSD.DWX",
    "USDCAD.DWX",
    "NZDUSD.DWX",
]


def function_body(name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", SOURCE)
    assert match, f"missing function {name}"
    depth = 1
    index = match.end()
    while index < len(SOURCE) and depth:
        if SOURCE[index] == "{":
            depth += 1
        elif SOURCE[index] == "}":
            depth -= 1
        index += 1
    assert depth == 0, f"unbalanced function {name}"
    return SOURCE[match.end() : index - 1]


def test_card_registry_manifest_and_host_slot_order_are_aligned() -> None:
    card = (EA_DIR / "docs" / "strategy_card.md").read_text(encoding="utf-8")
    assert "ea_id: QM5_9166" in card
    assert "slug: aa-vol-ma-timing" in card
    assert "g0_status: APPROVED" in card

    manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
    assert manifest["basket_symbols"] == EXPECTED_SLOTS
    assert manifest["selection"]["primary_rule"] == "ceil(valid_count * 0.20)"
    assert manifest["selection"]["fallback_rule"] == "top_3_when_3_to_9_available"

    basket_block = re.search(
        r"string\s+g_strategy_basket\[13\]\s*=\s*\{(?P<body>.*?)\};",
        SOURCE,
        re.DOTALL,
    )
    assert basket_block
    assert re.findall(r'"([A-Z0-9.]+\.DWX)"', basket_block.group("body")) == EXPECTED_SLOTS
    assert "QM_SymbolGuardInit(g_strategy_basket);" in SOURCE
    assert "QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1, warmup);" in SOURCE

    magic_rows = []
    for line in (ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(
        encoding="utf-8"
    ).splitlines():
        fields = line.split(",")
        if fields and fields[0] == "9166" and fields[-1] == "active":
            magic_rows.append((int(fields[2]), fields[3]))
    assert magic_rows == list(enumerate(EXPECTED_SLOTS))


def test_monthly_snapshot_ranks_every_available_basket_member_and_seals_membership() -> None:
    body = function_body("Strategy_BuildMonthlySnapshot")
    assert "slot < basket_count" in body
    assert "Strategy_CalculateRealizedVol(g_strategy_basket[slot]" in body
    assert "valid_count++" in body
    assert "ArraySize(volatility) != basket_count" in body
    assert "host_available = available[slot]" in body
    assert "host_volatility = volatility[slot]" in body
    assert "volatility[slot] > host_volatility" in body
    assert "slot < host_slot" in body
    assert "g_host_selected = (host_rank < selected_count);" in body
    assert "g_snapshot_month_key = month_key;" in body

    selector = function_body("Strategy_ActiveSleeveCount")
    assert "(valid_count + 4) / 5" in selector
    assert "valid_count < 10" in selector
    assert "count = 3" in selector
    assert "valid_count < 3" in selector

    exit_body = function_body("Strategy_ExitSignal")
    assert "if(!g_host_selected)" in exit_body
    assert "return true;" in exit_body


def test_realized_volatility_and_month_end_sma_use_exact_bounded_completed_data() -> None:
    vol = function_body("Strategy_CalculateRealizedVol")
    assert "required = strategy_vol_lookback_days + 1" in vol
    assert "copied != required || ArraySize(rates) != required" in vol
    assert "month_start - 1" in vol
    assert "strategy_vol_lookback_days - 1" in vol
    assert "MathSqrt(252.0)" in vol

    month_ends = function_body("Strategy_ReadCompletedMonthEnds")
    assert "strategy_sma_months * 32 + 5" in month_ends
    assert "observation_month == previous_month_key" in month_ends
    assert "found != strategy_sma_months" in month_ends
    assert "sma_month_end = sum / (double)strategy_sma_months" in month_ends
    assert "completed_month_close = rates[i].close" in month_ends

    assert "strategy_sma_months * 21" not in SOURCE
    assert "QM_SMA(" not in SOURCE
    assert SOURCE.count("CopyRates(") == 3
    for match in re.finditer(r"CopyRates\(", SOURCE):
        prefix = SOURCE[max(0, match.start() - 260) : match.start()]
        assert "perf-allowed" in prefix


def test_basket_risk_budget_is_divided_before_framework_weighting() -> None:
    body = function_body("Strategy_OpenWithDistributedRisk")
    assert "RISK_FIXED > 0.0 && RISK_PERCENT == 0.0" in body
    assert "RISK_PERCENT > 0.0 && RISK_FIXED == 0.0" in body
    assert "basket_budget /" in body
    assert "(double)g_active_sleeve_count" in body
    assert re.search(
        r"QM_TM_OpenPosition\(req,\s*out_ticket,\s*QM_FrameworkMagic\(\),\s*mode,\s*sleeve_budget\)",
        body,
        re.DOTALL,
    )
    assert "PORTFOLIO_WEIGHT" in function_body("OnInit")


def test_monthly_action_state_comes_from_confirmed_trade_history() -> None:
    assert "g_last_entry_rebalance_key" not in SOURCE
    assert "g_last_exit_rebalance_key" not in SOURCE
    history = function_body("Strategy_MonthHasConfirmedEntry")
    assert "HistorySelect(month_start, now)" in history
    assert "DEAL_MAGIC" in history
    assert "DEAL_SYMBOL" in history
    assert "DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT" in history

    entry = function_body("Strategy_EntrySignal")
    assert "Strategy_MonthHasConfirmedEntry" in entry
    assert "has_confirmed_entry" in entry
    assert "QM_TM_OpenPosition" not in entry

    exit_body = function_body("Strategy_ExitSignal")
    assert "g_last" not in exit_body
    assert "Strategy_HasOpenPosition" in exit_body


def test_exits_and_friday_close_precede_entry_news_and_spread_filters() -> None:
    on_tick = function_body("OnTick")
    mae = on_tick.index("QM_FrameworkTrackOpenPositionMae();")
    friday = on_tick.index("QM_FrameworkHandleFridayClose()")
    manage = on_tick.index("Strategy_ManageOpenPosition();")
    exit_signal = on_tick.index("Strategy_ExitSignal()")
    news = on_tick.index("QM_NewsAllowsTrade2")
    entry_filter = on_tick.index("Strategy_NoTradeFilter()")
    entry_signal = on_tick.index("Strategy_EntrySignal(req)")
    assert mae < friday < manage < exit_signal < news < entry_filter < entry_signal

    on_init = function_body("OnInit")
    assert "_Period != PERIOD_D1" in on_init
    assert "return INIT_FAILED;" in on_init


def test_spread_evidence_fails_closed_on_partial_zero_or_invalid_samples() -> None:
    median = function_body("Strategy_MedianSpreadD1")
    assert "lookback != 20" in median
    assert "copied != lookback || ArraySize(rates) != lookback" in median
    assert "rates[i].spread <= 0" in median
    assert "ArraySize(spreads) != lookback" in median
    assert "spreads[lookback / 2 - 1]" in median
    assert "spreads[lookback / 2]" in median

    spread = function_body("Strategy_SpreadAllowsEntry")
    assert "!(ask > bid)" in spread
    assert "current_spread <= 0.0" in spread
    assert "median_spread <= 0.0" in spread
    assert "current_spread <= 2.5 * median_spread" in spread
    assert "return true" not in spread


def test_framework_chain_and_every_declared_strategy_input_are_live() -> None:
    assert "#include <QM/QM_Common.mqh>" in SOURCE
    assert "QM_FrameworkTrackOpenPositionMae();" in SOURCE
    assert "QM_FrameworkMagic()" in SOURCE
    assert "RISK_FIXED                 = 1000.0" in SOURCE
    assert "RISK_PERCENT               = 0.0" in SOURCE
    forbidden = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert not any(token in SOURCE.lower() for token in forbidden)

    declared = re.findall(r"input\s+(?:int|double|bool)\s+(strategy_[A-Za-z0-9_]+)", SOURCE)
    assert declared == [
        "strategy_sma_months",
        "strategy_vol_lookback_days",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_min_warmup_bars",
        "strategy_enable_shorts",
    ]
    for name in declared:
        assert len(re.findall(rf"\b{re.escape(name)}\b", SOURCE)) >= 2, name
