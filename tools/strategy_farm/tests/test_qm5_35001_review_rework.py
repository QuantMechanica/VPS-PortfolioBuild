from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_35001_cowabunga-multi-timeframe-trend-system"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_PATH = EA_DIR / f"{EA_LABEL}.mq5"
CARD_PATH = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_35001_cowabunga-multi-timeframe-trend-system.md"
)
SET_PATHS = sorted((EA_DIR / "sets").glob("*_M15_backtest.set"))
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


def test_card_is_approved_and_macd_requires_exact_zero_transition() -> None:
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    entry = function_body(source(), "Strategy_EntrySignal")

    assert "g0_status: APPROVED" in card
    assert "macd_hist_1 > 0.0 && macd_hist_2 <= 0.0" in entry
    assert "macd_hist_1 < 0.0 && macd_hist_2 >= 0.0" in entry
    assert "macd_hist_1 > macd_hist_2" not in entry
    assert "macd_hist_1 < macd_hist_2" not in entry


def test_swing_stop_is_not_replaced_by_an_atr_corridor() -> None:
    entry = function_body(source(), "Strategy_EntrySignal")

    assert "const double sl_price = swing_low - swing_buffer;" in entry
    assert "const double sl_price = swing_high + swing_buffer;" in entry
    assert "const double sl_dist = exec_price - sl_price;" in entry
    assert "const double sl_dist = sl_price - exec_price;" in entry
    assert "min_sl_dist" not in entry
    assert "max_sl_dist" not in entry
    assert "0.5 * atr_1" not in entry
    assert "3.5 * atr_1" not in entry


def test_management_and_exit_precede_entry_only_filters() -> None:
    on_tick = function_body(source(), "OnTick")

    management = on_tick.index("Strategy_ManageOpenPosition();")
    strategy_exit = on_tick.index("Strategy_ExitSignal()")
    custom_news = on_tick.index("Strategy_NewsFilterHook(broker_now)")
    framework_news = on_tick.index("QM_NewsAllowsTrade2")
    no_trade = on_tick.index("Strategy_NoTradeFilter()")
    new_bar = on_tick.index("QM_IsNewBar()")

    assert management < strategy_exit < custom_news < framework_news < no_trade < new_bar


def test_gmt_loss_limits_and_slippage_are_wired() -> None:
    code = source()
    no_trade = function_body(code, "Strategy_NoTradeFilter")
    daily_halt = function_body(code, "Strategy_DailyRealizedLossHalt")
    on_init = function_body(code, "OnInit")

    assert "QM_BrokerToUTC(TimeCurrent())" in no_trade
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "QM_ChartUITodayPnL(0, closed_trades)" in daily_halt
    assert "strategy_daily_loss_halt_pct" in daily_halt
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_slippage_ticks * tick_size / point" in on_init
    assert "QM_KillSwitchInit" in on_init
    assert "QM_EntryConfigure" in on_init


def test_inputs_sets_and_source_hash_are_bound() -> None:
    code = source()
    source_hash = hashlib.sha256(EA_PATH.read_bytes()).hexdigest()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    strategy_inputs = [name for name in input_names if name.startswith("strategy_")]

    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []
    assert re.search(r"(?m)^input double RISK_PERCENT\s+= 0\.0;", code)

    assert len(SET_PATHS) == 2
    for set_path in SET_PATHS:
        text = set_path.read_text(encoding="utf-8-sig")
        values = assignments(set_path)
        assert re.search(rf"(?m)^; build_hash:\s+{source_hash}$", text)
        assert values["qm_ea_id"] == "35001"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert set(strategy_inputs) <= set(values)


def test_framework_magic_mae_bounded_series_and_forbidden_surfaces() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")
    entry = function_body(code, "Strategy_EntrySignal")
    config = function_body(code, "Strategy_ConfigValid")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "QM_FrameworkInit(qm_ea_id" in re.sub(r"\s+", " ", code)
    assert "QM_FrameworkMagic()" in code
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert "strategy_swing_lookback > MathMin(20, STRATEGY_MAX_SWING_LOOKBACK)" in config
    assert "MathMin(strategy_swing_lookback, STRATEGY_MAX_SWING_LOOKBACK)" in entry
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
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "35001"]
    assert len(rows) == 2
    assert [row["symbol_slot"] for row in rows] == ["0", "1"]
    assert {row["status"] for row in rows} == {"active"}
