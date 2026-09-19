from __future__ import annotations

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
    assert on_tick.index("Strategy_RefreshClosedBarCache();") < no_trade
    assert "QM_TM_OpenPositionCount(QM_FrameworkMagic())" in function_body(
        code, "Strategy_EntrySignal"
    )


def test_spread_is_fail_closed_and_rechecked_at_order_boundary() -> None:
    code = source()
    spread = function_body(code, "Strategy_WideSpread")
    entry = function_body(code, "Strategy_EntrySignal")
    on_tick = function_body(code, "OnTick")

    assert "ask <= 0.0 || bid <= 0.0" in spread
    assert "g_cached_atr > 0.0 && ask > bid" in spread
    assert "(ask - bid) > CARD_SPREAD_ATR_MULT * g_cached_atr" in spread
    assert "g_cached_atr <= 0.0" in entry
    assert "Strategy_WideSpread()" in entry
    assert on_tick.index("Strategy_EntrySignal(req)") < on_tick.index(
        "QM_TM_OpenPosition(req, out_ticket);"
    )


def test_middle_band_exit_is_exact_once_and_restart_safe() -> None:
    code = source()
    manage = function_body(code, "Strategy_ManageOpenPosition")
    load_state = function_body(code, "Strategy_PartialCloseRecorded")

    assert "volume * CARD_MIDDLE_CLOSE_FRACTION" in manage
    assert "QM_TM_NormalizeVolume" in manage
    assert "volume - close_lots < min_lot" in manage
    assert "QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL)" in manage
    assert "g_partial_close_position_id = position_id;" in manage
    assert "Strategy_PartialCloseRecorded(position_id, position_time)" in manage
    assert "HistorySelect(history_from, TimeCurrent())" in load_state
    assert "DEAL_ENTRY_OUT" in load_state
    assert "DEAL_ENTRY_OUT_BY" in load_state
    assert "DEAL_ENTRY_INOUT" in load_state
    assert "return true; // fail closed" in load_state
    assert "QM_TM_MoveSL(" not in code
    assert "QM_TM_MoveToBreakEven(" not in code


def test_card_entry_stop_target_and_risk_rails_are_preserved() -> None:
    code = source()
    refresh = function_body(code, "Strategy_RefreshClosedBarCache")
    entry = function_body(code, "Strategy_EntrySignal")
    on_init = function_body(code, "OnInit")

    assert "QM_ReadBar(_Symbol, PERIOD_H1, 1" in refresh
    assert "QM_ReadBar(_Symbol, PERIOD_H1, 2" in refresh
    assert "g_cached_bar_1.close > g_cached_bar_2.open" in entry
    assert "g_cached_bar_1.open < g_cached_bar_2.close" in entry
    assert "g_cached_bar_1.close < g_cached_bar_2.open" in entry
    assert "g_cached_bar_1.open > g_cached_bar_2.close" in entry
    assert "g_cached_bar_1.low <= g_cached_lower_band" in entry
    assert "g_cached_bar_1.high >= g_cached_upper_band" in entry
    assert "g_cached_bar_1.low - sl_buffer" in entry
    assert "g_cached_bar_1.high + sl_buffer" in entry
    assert entry.count("QM_TakeRR(") == 2
    assert "InpDailyDrawdownStopPct" in on_init
    assert "InpTotalDrawdownStopPct" in on_init
    assert "CARD_PER_TRADE_RISK_CAP_PCT" in on_init


def test_every_input_is_wired_and_all_backtest_sets_bind_current_source() -> None:
    code = source()
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
        assert re.search(r"(?m)^; build_hash:\s+[0-9a-f]{64}$", text)
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
