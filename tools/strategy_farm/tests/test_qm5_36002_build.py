from __future__ import annotations

import csv
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36002_nnfx-kijunsen-absolute-strength-damiani"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SET_PATHS = sorted((EA_DIR / "sets").glob("*_D1_backtest.set"))
CARD_PATH = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / f"{EA_LABEL}.md"
)
MIRROR_PATH = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
MAGIC_RESOLVER = REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"


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


def test_approved_card_is_mirrored_content_equivalent() -> None:
    def normalized_card(path: Path) -> str:
        return "\n".join(
            line.rstrip()
            for line in path.read_text(encoding="utf-8-sig").splitlines()
        )

    assert normalized_card(MIRROR_PATH) == normalized_card(CARD_PATH)


def test_framework_corset_and_execution_contract_are_wired() -> None:
    code = source()
    on_init = function_body(code, "OnInit")
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkInit(qm_ea_id" in re.sub(r"\s+", " ", on_init)
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in re.sub(
        r"\s+", " ", on_init
    )
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in on_init
    assert on_tick.lstrip().startswith("QM_FrameworkTrackOpenPositionMae();")
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert "CopyBuffer(" not in code
    assert "OrderSend(" not in code
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)

    raw_series = re.compile(
        r"\b(?:iOpen|iClose|iHigh|iLow|iTime|iHighest|iLowest|CopyRates|CopyClose)\s*\("
    )
    for line in code.splitlines():
        if raw_series.search(line):
            assert "perf-allowed:" in line


def test_card_entry_exit_filters_and_loss_contract_are_present() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    exit_signal = function_body(code, "Strategy_ExitSignal")
    damiani = function_body(code, "Strategy_DamianiTrade")
    no_trade = function_body(code, "Strategy_NoTradeFilter")
    daily_halt = function_body(code, "Strategy_DailyRealizedLossHalt")
    on_init = function_body(code, "OnInit")

    for token in (
        "g_closed_close_1 > g_closed_kijun_1",
        "aso_bulls > aso_bears",
        "aroon_up >= strategy_aroon_threshold",
        "g_closed_close_1 < g_closed_kijun_1",
        "aso_bears > aso_bulls",
        "aroon_down >= strategy_aroon_threshold",
    ):
        assert token in entry
    assert "return (vol > anti);" in damiani
    assert "vol >=" not in damiani
    assert "QM_BrokerToUTC(TimeCurrent())" in no_trade
    assert "hhmm >= 2355 || hhmm < 5" in no_trade
    assert "strategy_spread_atr_mult * atr_pts" in no_trade
    assert "Strategy_HasOpenPosition()" in no_trade
    assert "QM_ChartUITodayPnL(0, closed_trades)" in daily_halt
    assert "strategy_daily_loss_halt_pct" in daily_halt
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_per_trade_risk_cap_pct" in on_init
    assert "strategy_slippage_ticks * tick_size / point" in on_init
    assert "POSITION_TYPE_BUY" in exit_signal
    assert "g_closed_close_1 < g_closed_kijun_1" in exit_signal
    assert "g_closed_close_1 > g_closed_kijun_1" in exit_signal


def test_tp1_is_exact_once_restart_safe_and_leaves_a_runner() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    manage = function_body(code, "Strategy_ManageOpenPosition")
    split = function_body(code, "Strategy_VolumeCanSplitTp1")
    load_state = function_body(code, "Strategy_LoadTp1State")
    transaction = function_body(code, "OnTradeTransaction")

    assert entry.count("req.tp = 0.0;") >= 3
    assert entry.count("Strategy_EntryVolumeSupportsTp1") == 2
    assert "MathAbs(close_lots - runner_lots) <= tolerance" in split
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


def test_all_inputs_are_used_and_backtest_sets_are_complete() -> None:
    code = source()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    strategy_inputs = [name for name in input_names if name.startswith("strategy_")]

    assert input_names
    assert strategy_inputs
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []
    assert "strategy_kijun_period < 20 || strategy_kijun_period > 35" in code
    assert "strategy_aso_period < 7 || strategy_aso_period > 14" in code
    assert "strategy_aroon_threshold < 60.0 || strategy_aroon_threshold > 80.0" in code
    assert "RISK_PERCENT - strategy_risk_percent" in code

    assert len(SET_PATHS) == 4
    for set_path in SET_PATHS:
        text = set_path.read_text(encoding="utf-8-sig")
        values = assignments(set_path)
        assert re.search(r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$", text)
        assert values["qm_ea_id"] == "36002"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert set(strategy_inputs) <= set(values)


def test_registry_rows_are_unique_formula_correct_and_resolver_backed() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        all_rows = list(csv.DictReader(handle))
    rows = [row for row in all_rows if row["ea_id"] == "36002"]
    assert len(rows) == 4
    assert [row["symbol_slot"] for row in rows] == ["0", "1", "2", "3"]
    assert {row["symbol"] for row in rows} == {
        "EURUSD.DWX",
        "GBPJPY.DWX",
        "AUDCAD.DWX",
        "NZDUSD.DWX",
    }
    assert {row["status"] for row in rows} == {"active"}
    for row in rows:
        assert int(row["magic"]) == 36002 * 10000 + int(row["symbol_slot"])

    active_magics = [row["magic"] for row in all_rows if row["status"] == "active"]
    assert len(active_magics) == len(set(active_magics))

    with EA_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        ea_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36002"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "nnfx-kijunsen-absolute-strength-damiani"

    resolver = MAGIC_RESOLVER.read_text(encoding="utf-8-sig")
    for row in rows:
        assert row["magic"] in resolver
