from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_35004_babypips-asian-box-london-breakout"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
CARD = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_35004_babypips-asian-box-london-breakout.md"
)
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


def _strategy_inputs(source: str) -> list[str]:
    strategy_group = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------\n"
        "// Helpers",
        1,
    )[0]
    return re.findall(
        r"\binput\s+(?:bool|double|int|string|uint)\s+([A-Za-z_]\w*)\s*=",
        strategy_group,
    )


def test_card_session_box_and_shift_one_signal_are_mechanical_and_bounded() -> None:
    source = _source()
    compact = _compact(source)

    assert "g0_status: APPROVED" in _source(CARD)
    assert source.count("CopyRates(") == 1
    assert "CopyRates(_Symbol,PERIOD_M15,1,96,rates)" in compact
    assert "perf-allowed:onebounded96-barsnapshot" in compact
    assert "copied<=0||ArraySize(rates)<copied" in compact
    assert "bar_count!=24" in compact
    assert "QM_BrokerToUTC(rates[0].time)" not in compact
    assert "QM_BrokerToUTC(t_1)" in compact
    assert "close_1>box_high+buffer" in compact
    assert "close_1<box_low-buffer" in compact
    assert not re.search(r"\b(?:iTime|iOpen|iHigh|iLow|iClose)\s*\(", source)


def test_daily_entry_halt_uses_utc_day_realized_deals_not_floating_equity() -> None:
    source = _source()
    ledger = _function_slice(
        source, "bool StrategyDailyRealizedNet", "bool StrategyDailyEntryHalt"
    )
    halt = _function_slice(
        source, "bool StrategyDailyEntryHalt", "bool CalculateAsianBox"
    )
    compact_ledger = _compact(ledger)
    compact_halt = _compact(halt)

    assert "QM_UTCToBroker(StructToTime(utc_day))" in compact_ledger
    assert "HistorySelect(broker_day_start,TimeCurrent())" in compact_ledger
    assert "DEAL_TYPE_BUY" in ledger and "DEAL_TYPE_SELL" in ledger
    for field in ("DEAL_PROFIT", "DEAL_SWAP", "DEAL_COMMISSION", "DEAL_FEE"):
        assert field in ledger
    assert "ACCOUNT_EQUITY" not in halt
    assert "g_qm_ks_day_start_equity" not in source
    assert "if(!StrategyDailyRealizedNet(realized_net))" in halt
    assert "AccountInfoDouble(ACCOUNT_BALANCE)-realized_net" in compact_halt
    assert "realized_loss_pct>=strategy_daily_loss_halt_pct" in compact_halt


def test_management_does_not_invent_undefined_break_even_or_trailing_rules() -> None:
    source = _source()
    management = _function_slice(
        source, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal"
    )

    assert "no numeric BE trigger" in management
    assert "QM_TM_MoveSL" not in source
    assert "QM_TM_MoveToBreakEven" not in source
    assert "QM_TM_Trail" not in source
    assert "asian_box_be_plus_1" not in source
    assert "20.0 * pip_size" not in source


def test_force_close_deadline_is_anchored_to_entry_day_and_stays_due() -> None:
    source = _source()
    exit_signal = _function_slice(
        source, "bool Strategy_ExitSignal", "bool Strategy_NewsFilterHook"
    )
    compact = _compact(exit_signal)

    assert "PositionGetInteger(POSITION_TIME)" in compact
    assert "TimeToStruct(QM_BrokerToUTC(broker_open),utc_deadline)" in compact
    assert "utc_deadline.hour=strategy_force_close_hhmm/100" in compact
    assert "utc_deadline.min=strategy_force_close_hhmm%100" in compact
    assert "utc_now>=StructToTime(utc_deadline)" in compact
    assert "2355" not in exit_signal


def test_management_and_forced_exit_precede_entry_only_filters() -> None:
    source = _source()
    on_tick = _function_slice(source, "void OnTick", "void OnTimer")

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NewsFilterHook"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_every_strategy_input_is_used_and_sealed_in_each_backtest_set() -> None:
    source = _source()
    inputs = _strategy_inputs(source)

    assert len(inputs) == 14
    assert len(inputs) == len(set(inputs))
    assert len(SETS) == 3
    for name in inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name
        assert all(name in _set_values(path) for path in SETS), name


def test_framework_risk_magic_registry_and_hardening_are_conformant() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "RISK_PERCENT=0.0" in compact
    assert "RISK_FIXED=1000.0" in compact
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_TM_OpenPosition(req,out_ticket)" in compact
    assert not re.search(r"\b(?:iMA|iATR|iRSI|iMACD|iADX|iBands)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)

    expected_slots = {"GBPUSD.DWX": 0, "EURUSD.DWX": 1, "USDCHF.DWX": 2}
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "35004"]
    assert len(rows) == 3
    assert {row["status"] for row in rows} == {"active"}
    assert {row["symbol"]: int(row["symbol_slot"]) for row in rows} == expected_slots
    assert {int(row["magic"]) for row in rows} == {350040000, 350040001, 350040002}

    observed: dict[str, int] = {}
    for path in SETS:
        values = _set_values(path)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        symbol = next(symbol for symbol in expected_slots if symbol in path.name)
        observed[symbol] = int(values["qm_magic_slot_offset"])
    assert observed == expected_slots

    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
