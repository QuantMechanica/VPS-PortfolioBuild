from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36004_nnfx-alma-qqe-volume-flow-sniper"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SET_PATHS = sorted((EA_DIR / "sets").glob("*_D1_backtest.set"))
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


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
            values[key.strip()] = value.strip()
    return values


def test_qqe_entry_and_runner_exit_require_real_crossovers() -> None:
    code = source()
    crossover = function_body(code, "Strategy_QQECross")
    entry = function_body(code, "Strategy_EntrySignal")
    exit_signal = function_body(code, "Strategy_ExitSignal")

    assert "state_now == 1 && state_prev != 1" in crossover
    assert "state_now == -1 && state_prev != -1" in crossover
    assert "const int qqe_cross = Strategy_QQECross(_Symbol, 1);" in entry
    assert "const int qqe_cross = Strategy_QQECross(_Symbol, 1);" in exit_signal
    assert "qqe_cross < 0" in exit_signal
    assert "qqe_cross > 0" in exit_signal
    assert "Strategy_ALMA" not in exit_signal
    assert "Strategy_QQEState" not in exit_signal


def test_tp1_is_exact_once_restart_safe_and_leaves_a_runner() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    manage = function_body(code, "Strategy_ManageOpenPosition")
    load_state = function_body(code, "Strategy_LoadTp1State")
    transaction = function_body(code, "OnTradeTransaction")

    assert entry.count("req.tp = 0.0;") >= 3
    assert entry.count("Strategy_EntryVolumeSupportsTp1") == 2
    assert "MathAbs(close_lots - runner_lots) <= tolerance" in function_body(
        code, "Strategy_VolumeCanSplitTp1"
    )
    assert "HistorySelectByPosition((ulong)position_id)" in load_state
    assert "DEAL_ENTRY_OUT" in load_state
    assert "DEAL_ENTRY_OUT_BY" in load_state
    assert "DEAL_ENTRY_INOUT" in load_state
    assert "Strategy_Tp1State(position_id, tp1_completed)" in manage
    assert "QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL)" in manage
    assert "g_tp1_completed = true;" in manage
    assert "if(tp1_completed)" in manage
    assert "QM_TM_MoveSL" in manage
    assert "g_tp1_state_known = false;" in transaction


def test_utc_realized_loss_hard_stops_and_slippage_match_card() -> None:
    code = source()
    no_trade = function_body(code, "Strategy_NoTradeFilter")
    daily_halt = function_body(code, "Strategy_DailyRealizedLossHalt")
    on_init = function_body(code, "OnInit")

    assert "QM_BrokerToUTC(TimeCurrent())" in no_trade
    assert "hhmm >= 2355 || hhmm < 5" in no_trade
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "QM_ChartUITodayPnL(0, closed_trades)" in daily_halt
    assert "strategy_daily_loss_halt_pct" in daily_halt
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_per_trade_risk_cap_pct" in on_init
    assert "strategy_slippage_ticks * tick_size / point" in on_init
    assert "QM_EntryConfigure" in on_init


def test_management_and_exit_precede_entry_only_filters() -> None:
    on_tick = function_body(source(), "OnTick")

    management = on_tick.index("Strategy_ManageOpenPosition();")
    strategy_exit = on_tick.index("Strategy_ExitSignal()")
    custom_news = on_tick.index("Strategy_NewsFilterHook(broker_now)")
    framework_news = on_tick.index("QM_NewsAllowsTrade2")
    no_trade = on_tick.index("Strategy_NoTradeFilter()")

    assert management < strategy_exit < custom_news < framework_news < no_trade
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in on_tick


def test_buffer_is_bounded_every_input_is_wired_and_sets_bind_source() -> None:
    code = source()
    qqe = function_body(code, "Strategy_QQEValue")
    source_hash = hashlib.sha256(EA_PATH.read_bytes()).hexdigest()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    strategy_inputs = [name for name in input_names if name.startswith("strategy_")]

    assert "n > STRATEGY_MAX_INDICATOR_BARS" in qqe
    assert "ArrayResize(rsi_ma, n) != n" in qqe
    assert "ArraySize(rsi_ma) < n" in qqe
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []

    assert len(SET_PATHS) == 4
    for set_path in SET_PATHS:
        text = set_path.read_text(encoding="utf-8-sig")
        values = assignments(set_path)
        assert re.search(rf"(?m)^; build_hash:\s+{source_hash}$", text)
        assert values["qm_ea_id"] == "36004"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert set(strategy_inputs) <= set(values)


def test_framework_magic_mae_performance_and_forbidden_surfaces() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "QM_FrameworkInit(qm_ea_id" in re.sub(r"\s+", " ", code)
    assert "QM_FrameworkMagic()" in code
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)
    assert "OrderSend(" not in code
    assert "CopyBuffer(" not in code

    raw_series = re.compile(
        r"\b(?:iOpen|iClose|iHigh|iLow|iTime|iHighest|iLowest|CopyRates|CopyClose)\s*\("
    )
    for line in code.splitlines():
        if raw_series.search(line):
            assert "perf-allowed:" in line

    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36004"]
    assert len(rows) == 4
    assert [row["symbol_slot"] for row in rows] == ["0", "1", "2", "3"]
    assert {row["status"] for row in rows} == {"active"}
