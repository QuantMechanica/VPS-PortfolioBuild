from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_34003_triple-timeframe-williams-r-champion"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
CARD = REPO / "strategy-seeds" / "cards" / f"{LABEL}.md"
SETS = sorted((EA_DIR / "sets").glob("*_backtest.set"))
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"


def _source(path: Path = EA) -> str:
    return path.read_text(encoding="utf-8-sig")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function_slice(source: str, start: str, end: str) -> str:
    return source[source.index(start) : source.index(end)]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in _source(path).splitlines():
        line = raw_line.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def _set_headers(path: Path) -> dict[str, str]:
    headers: dict[str, str] = {}
    for raw_line in _source(path).splitlines():
        match = re.match(r"^\s*;\s*([A-Za-z0-9_]+)\s*:\s*(.*?)\s*$", raw_line)
        if match:
            headers[match.group(1).lower()] = match.group(2)
    return headers


def _strategy_inputs(source: str) -> list[str]:
    strategy_group = source.split('input group "Strategy"', 1)[1].split(
        "double g_initial_equity", 1
    )[0]
    return re.findall(
        r"\binput\s+(?:bool|double|int|string|uint)\s+([A-Za-z_]\w*)\s*=",
        strategy_group,
    )


def test_card_signal_geometry_is_mechanical_on_closed_bars() -> None:
    source = _source()
    compact = _compact(source)

    assert "g0_status: APPROVED" in _source(CARD)
    assert "QM_WPR(_Symbol,PERIOD_H4,strategy_wpr_period,1)" in compact
    assert "QM_WPR(_Symbol,PERIOD_H1,strategy_wpr_period,1)" in compact
    assert "QM_WPR(_Symbol,PERIOD_M15,strategy_wpr_period,1)" in compact
    assert "QM_ATR(_Symbol,PERIOD_M15,strategy_atr_period,1)" in compact
    assert (
        "wpr_h4>=strategy_h4_trend_long&&"
        "wpr_h1>=strategy_h1_trend_mid&&"
        "wpr_m15<=strategy_m15_pullback_long"
    ) in compact
    assert (
        "wpr_h4<=strategy_h4_trend_short&&"
        "wpr_h1<=strategy_h1_trend_mid&&"
        "wpr_m15>=strategy_m15_pullback_short"
    ) in compact
    assert "sl_dist=strategy_sl_atr_mult*atr_m15" in compact
    assert "tp_dist=strategy_tp_rr_mult*sl_dist" in compact


def test_gmt_rollover_loss_limits_and_slippage_are_executable() -> None:
    source = _source()
    compact = _compact(source)
    no_trade = _compact(
        _function_slice(source, "bool Strategy_NoTradeFilter", "bool Strategy_EntrySignal")
    )
    on_init = _compact(_function_slice(source, "int OnInit", "void OnDeinit"))

    assert "QM_BrokerToUTC(TimeCurrent())" in no_trade
    assert "hhmm>=2355||hhmm<=5" in no_trade
    assert "QM_ChartUITodayPnL(0,closed_trades)" in compact
    assert "day_start_balance=balance_now-realized_pnl" in compact
    assert "strategy_daily_loss_halt_pct/100.0" in compact
    assert "StrategyTotalDrawdownBreached()" in no_trade
    assert "StrategyTotalDrawdownBreached();" in _function_slice(
        source, "bool Strategy_ExitSignal", "bool Strategy_NewsFilterHook"
    )
    assert "strategy_max_slippage_ticks*tick_size/point" in compact
    assert "QM_EntryConfigure(qm_ea_id" in on_init
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_hard_stop_pct,strategy_total_dd_stop_pct,1.0)"
    ) in on_init


def test_management_and_hard_exits_precede_entry_only_filters() -> None:
    on_tick = _function_slice(_source(), "void OnTick", "void OnTimer")

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NewsFilterHook"
    )
    assert on_tick.index("Strategy_NoTradeFilter()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )


def test_every_strategy_input_is_used_and_sealed_in_every_setfile() -> None:
    source = _source()
    inputs = _strategy_inputs(source)

    assert len(inputs) == 16
    assert len(inputs) == len(set(inputs))
    assert len(SETS) == 3
    for name in inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name
        assert all(name in _set_values(path) for path in SETS), name


def test_framework_corset_risk_magic_and_callbacks_are_conformant() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "#include<Trade/Trade.mqh>" not in compact
    assert "RISK_PERCENT=0.0" in compact
    assert "RISK_FIXED=1000.0" in compact
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M15" in compact
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req,out_ticket)" in compact
    assert "ZeroMemory(req)" in compact
    assert "voidOnTradeTransaction(constMqlTradeTransaction&t,constMqlTradeRequest&r,constMqlTradeResult&res)" in compact
    assert "QM_FrameworkOnTradeTransaction(t,r,res)" in compact
    assert not re.search(
        r"\b(?:iOpen|iHigh|iLow|iClose|iMA|iATR|iWPR|CopyBuffer|CopyRates)\s*\(",
        source,
    )
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_registered_slots_fixed_risk_sets_and_hardening_are_clean() -> None:
    expected_slots = {"EURUSD.DWX": 0, "GBPUSD.DWX": 1, "USDCHF.DWX": 2}
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "34003"]

    assert len(rows) == 3
    assert {row["status"] for row in rows} == {"active"}
    assert {row["symbol"]: int(row["symbol_slot"]) for row in rows} == expected_slots
    assert {int(row["magic"]) for row in rows} == {340030000, 340030001, 340030002}

    observed: dict[str, int] = {}
    required_headers = {
        "ea_id",
        "ea_slug",
        "ea_version",
        "set_version",
        "symbol",
        "timeframe",
        "environment",
        "magic_slot",
        "risk_mode",
        "portfolio_weight",
        "build_hash",
        "author",
        "date",
    }
    for path in SETS:
        values = _set_values(path)
        assert required_headers <= set(_set_headers(path)), path
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert "; build_hash:   pending" in _source(path)
        symbol = next(symbol for symbol in expected_slots if symbol in path.name)
        observed[symbol] = int(values["qm_magic_slot_offset"])
    assert observed == expected_slots

    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
