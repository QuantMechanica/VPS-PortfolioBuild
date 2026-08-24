from __future__ import annotations

import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38003_codetrading-bollinger-engulfing-reversal"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SET_PATHS = sorted((EA_DIR / "sets").glob("*_backtest.set"))


def source() -> str:
    return EA_PATH.read_text(encoding="utf-8-sig")


def function_body(code: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", code)
    assert match is not None, f"missing function {name}"
    start = match.end() - 1
    depth = 0
    for offset in range(start, len(code)):
        if code[offset] == "{":
            depth += 1
        elif code[offset] == "}":
            depth -= 1
            if depth == 0:
                return code[start + 1 : offset]
    raise AssertionError(f"unterminated function {name}")


def assignments(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def test_management_and_exit_hooks_precede_every_entry_only_gate() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")

    management = on_tick.index("Strategy_ManageOpenPosition();")
    strategy_exit = on_tick.index("Strategy_ExitSignal()")
    news = on_tick.index("Strategy_NewsFilterHook(broker_now)")
    no_trade = on_tick.index("Strategy_NoTradeFilter()")
    framework_news = on_tick.index("QM_NewsAllowsTrade2")

    assert management < strategy_exit < news < no_trade < framework_news
    assert on_tick.index("AdvanceState_OnNewBar();") < no_trade
    assert "QM_TM_OpenPositionCount(magic) >= 1" in function_body(
        code, "Strategy_NoTradeFilter"
    )


def test_spread_is_fail_closed_and_rechecked_at_order_boundary() -> None:
    code = source()
    spread = function_body(code, "StrategySpreadAllowsEntry")
    no_trade = function_body(code, "Strategy_NoTradeFilter")
    on_tick = function_body(code, "OnTick")

    assert "ask <= 0.0 || bid <= 0.0 || ask < bid || g_last_atr <= 0.0" in spread
    assert "spread <= g_last_atr * strategy_spread_filter_mult" in spread
    assert "return !StrategySpreadAllowsEntry();" in no_trade
    assert (
        "Strategy_EntrySignal(req) && StrategySpreadAllowsEntry()" in on_tick
    )
    assert on_tick.index("StrategySpreadAllowsEntry()") < on_tick.index(
        "QM_TM_OpenPosition(req, out_ticket);"
    )


def test_middle_band_exit_is_exact_once_and_restart_safe() -> None:
    code = source()
    manage = function_body(code, "Strategy_ManageOpenPosition")
    load_state = function_body(code, "StrategyLoadMidExitState")
    transaction = function_body(code, "OnTradeTransaction")

    assert "volume * strategy_mid_exit_fraction" in manage
    assert "QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL)" in manage
    assert "g_mid_exit_completed = true;" in manage
    assert "StrategyMidExitState(position_id, mid_exit_completed)" in manage
    assert "HistorySelectByPosition((ulong)position_id)" in load_state
    assert "DEAL_ENTRY_OUT" in load_state
    assert "DEAL_ENTRY_OUT_BY" in load_state
    assert "DEAL_ENTRY_INOUT" in load_state
    assert "g_mid_exit_state_known = false;" in transaction
    assert "QM_TM_MoveSL(" not in code
    assert "QM_TM_MoveToBreakEven(" not in code


def test_card_entry_stop_target_and_risk_rails_are_preserved() -> None:
    code = source()
    refresh = function_body(code, "AdvanceState_OnNewBar")
    entry = function_body(code, "Strategy_EntrySignal")
    on_init = function_body(code, "OnInit")

    assert "(close2 < open2) && (close1 > open1)" in refresh
    assert "(close1 > open2) && (open1 < close2)" in refresh
    assert "(close2 > open2) && (close1 < open1)" in refresh
    assert "(close1 < open2) && (open1 > close2)" in refresh
    assert "low1 <= g_bb_lower" in refresh
    assert "high1 >= g_bb_upper" in refresh
    assert "g_last_low1 - buffer" in entry
    assert "g_last_high1 + buffer" in entry
    assert entry.count("strategy_tp_rr * sl_dist") == 2
    assert "QM_LotsForRiskAtEntry" in entry
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_per_trade_risk_cap_pct" in on_init


def test_every_input_is_wired_and_all_backtest_sets_bind_current_source() -> None:
    code = source()
    source_hash = hashlib.sha256(EA_PATH.read_bytes()).hexdigest()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []

    assert len(SET_PATHS) == 3
    for set_path in SET_PATHS:
        text = set_path.read_text(encoding="utf-8-sig")
        values = assignments(set_path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "38003"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert set(input_names) - {
            "qm_rng_seed",
            "qm_news_temporal",
            "qm_news_compliance",
            "qm_news_stale_max_hours",
            "qm_news_min_impact",
            "qm_news_mode_legacy",
            "qm_friday_close_enabled",
            "qm_friday_close_hour_broker",
            "qm_stress_reject_probability",
        } <= set(values)


def test_framework_chain_magic_mae_performance_and_forbidden_surfaces() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "QM_FrameworkMagic()" in code
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert "QM_FrameworkInit(qm_ea_id" in re.sub(r"\s+", " ", code)
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)
    assert "OrderSend(" not in code
    assert "CopyBuffer(" not in code

    raw_series = re.compile(r"\b(?:iOpen|iClose|iHigh|iLow|iTime|CopyRates)\s*\(")
    for line in code.splitlines():
        if raw_series.search(line):
            assert "perf-allowed:" in line
