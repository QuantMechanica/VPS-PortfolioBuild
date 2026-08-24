from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1629_ehlers-cybernetic-cycle-h4"
SOURCE = REPO / "framework" / "EAs" / EA_LABEL / f"{EA_LABEL}.mq5"


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def test_cycle_smoother_uses_card_approved_completed_closes() -> None:
    body = _function_body(
        SOURCE.read_text(encoding="utf-8"), "bool ComputeCyberneticCycle("
    )

    for offset in range(4):
        suffix = "" if offset == 0 else f" + {offset}"
        assert f"rates[i{suffix}].close" in body
    assert ".high" not in body
    assert ".low" not in body
    assert "ArraySize(rates) < count" in body
    assert "ArraySize(smooth) < count" in body
    assert "ArraySize(cycle) < count" in body


def test_time_stop_and_cooldown_count_actual_h4_bars() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    time_stop = _function_body(source, "bool TimeStopReached(")
    cooldown = _function_body(source, "bool CooldownAllows(")
    exit_signal = _function_body(source, "bool Strategy_ExitSignal()")

    assert "iBarShift(_Symbol, PERIOD_H4, opened, false)" in time_stop
    assert "opened_bar_shift < 0" in time_stop
    assert "opened_bar_shift >= strategy_time_stop_bars" in time_stop
    assert "TimeCurrent() - opened" not in exit_signal
    assert "TimeStopReached(opened)" in exit_signal

    assert "iBarShift(_Symbol, PERIOD_H4, g_last_trade_time, false)" in cooldown
    assert "bars_since_entry < 0" in cooldown
    assert "bars_since_entry >= strategy_cooldown_bars" in cooldown
    assert "PeriodSeconds(PERIOD_H4)" not in cooldown


def test_break_even_adds_direction_correct_spread_and_checks_broker_distance() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    target = _function_body(source, "bool BreakEvenPlusSpreadTarget(")
    manage = _function_body(source, "void Strategy_ManageOpenPosition()")

    assert "const double spread = ask - bid;" in target
    assert "open_price + spread" in target
    assert "open_price - spread" in target
    assert "QM_TM_NormalizePrice(_Symbol, raw_target)" in target
    assert "SYMBOL_TRADE_STOPS_LEVEL" in target
    assert "SYMBOL_TRADE_FREEZE_LEVEL" in target
    assert "target_sl > bid - broker_distance" in target
    assert "target_sl < ask + broker_distance" in target
    assert 'QM_TM_MoveSL(ticket, target_sl, "MOVE_TO_BE_PLUS_SPREAD")' in manage
    assert 'QM_TM_MoveSL(ticket, open_price, "MOVE_TO_BE")' not in manage


def test_h4_contract_and_entry_success_own_the_cooldown_transition() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    on_init = _function_body(source, "int OnInit()")
    entry = _function_body(source, "bool Strategy_EntrySignal(")
    on_tick = _function_body(source, "void OnTick()")

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H4," in on_init
    assert "QM_IsNewBar(_Symbol, PERIOD_H4)" in on_tick
    assert "g_last_trade_time" not in entry
    assert "g_last_trade_dir" not in entry
    opened = on_tick.index("if(QM_TM_OpenPosition(req, out_ticket))")
    trade_time = on_tick.index("g_last_trade_time = iTime(_Symbol, PERIOD_H4, 0)")
    trade_dir = on_tick.index("g_last_trade_dir = (req.type == QM_BUY) ? 1 : -1")
    assert opened < trade_time < trade_dir


def test_framework_contract_and_every_strategy_input_remain_wired() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(
        r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", strategy_block
    )

    assert len(names) == 11
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "RISK_PERCENT               = 0.0;" in source
    assert "RISK_FIXED                 = 1000.0;" in source
    assert "QM_FrameworkMagic()" in source
    assert "req.symbol_slot = qm_magic_slot_offset;" in source
    assert "CopyRates(_Symbol, tf, 0, bars_needed, rates); // perf-allowed:" in source
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)
