from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as gate


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_33007_george-pruitt-king-keltner-trend-buster"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("SP500.DWX", 330070000),
    1: ("XTIUSD.DWX", 330070001),
    2: ("EURUSD.DWX", 330070002),
}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _executable_source() -> str:
    source = _source()
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _compact(value: str) -> str:
    return "".join(value.split())


def _slice(source: str, start: str, end: str) -> str:
    return source[source.index(start) : source.index(end)]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_framework_corset_risk_defaults_magic_and_no_ml() -> None:
    source = _source()
    executable = _executable_source()
    includes = re.findall(r"^\s*#include\s+(.+?)\s*$", executable, re.MULTILINE)

    assert includes == ["<QM/QM_Common.mqh>"]
    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", executable)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", executable)
    assert "QM_FrameworkMagic()" in executable
    assert "qm_ea_id * 10000" not in executable
    assert "QM_FrameworkTrackOpenPositionMae();" in executable
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)


def test_every_declared_strategy_input_has_an_executable_use_site() -> None:
    source = _executable_source()
    names = re.findall(r"\binput\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert len(names) == 11
    assert len(names) == len(set(names))
    unused = [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]
    assert unused == []


def test_loss_drawdown_and_slippage_contracts_are_exact_and_wired() -> None:
    compact = _compact(_executable_source())

    assert "strategy_daily_realized_loss_halt_pct=2.0;" in compact
    assert "strategy_daily_drawdown_hard_stop_pct=2.5;" in compact
    assert "strategy_total_drawdown_stop_pct=5.0;" in compact
    assert "strategy_max_slippage_ticks=3.0;" in compact
    assert "HistorySelect(broker_day_start,broker_now)" in compact
    assert "realized_loss_pct>=strategy_daily_realized_loss_halt_pct" in compact
    assert "daily_drawdown_pct>=strategy_daily_drawdown_hard_stop_pct" in compact
    assert "total_drawdown_pct>=strategy_total_drawdown_stop_pct" in compact
    assert "QM_KillSwitchTrip(\"KS_STRATEGY_DAILY_DRAWDOWN\"" in compact
    assert "QM_KillSwitchTrip(\"KS_STRATEGY_TOTAL_DRAWDOWN\"" in compact
    assert "QM_EntryConfigure(qm_ea_id" in compact
    assert "strategy_max_slippage_ticks*tick_size/point" in compact


def test_gmt_spread_and_history_fail_closed_for_entries() -> None:
    source = _compact(
        _slice(_executable_source(), "bool Strategy_NoTradeFilter", "bool Strategy_EntrySignal")
    )

    assert "constdatetimeutc_now=QM_BrokerToUTC(broker_now);" in source
    assert "if(utc_now<=0)returntrue;" in source
    assert "if(hhmm>=2355||hhmm<5)returntrue;" in source
    assert "if(!Strategy_DailyRealizedPnl(" in source
    assert "returntrue;" in source
    assert "ask<=0.0||bid<=0.0||ask<bid||point<=0.0||atr_1<=0.0" in source
    assert "ask<=bid" not in source  # zero-spread DWX bars remain tradeable


def test_entry_blackouts_follow_friday_management_and_strategy_exit() -> None:
    on_tick = _compact(_slice(_executable_source(), "void OnTick", "void OnTimer"))

    friday = on_tick.index("QM_FrameworkHandleFridayClose()")
    manage = on_tick.index("Strategy_ManageOpenPosition();")
    strategy_exit = on_tick.index("if(Strategy_ExitSignal())")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol,PERIOD_H4)")
    news_hook = on_tick.index("Strategy_NewsFilterHook(broker_now)")
    news_gate = on_tick.index("if(!news_allows)return;")
    no_trade = on_tick.index("if(Strategy_NoTradeFilter())return;")
    entry = on_tick.index("if(Strategy_EntrySignal(req))")

    assert friday < manage < strategy_exit < new_bar < news_hook < news_gate < no_trade < entry


def test_h4_identity_parameter_ranges_and_closed_bar_reads_are_fail_closed() -> None:
    source = _source()
    compact = _compact(_executable_source())

    assert "if(_Period!=PERIOD_H4)returnfalse;" in compact
    assert "strategy_ma_period<10||strategy_ma_period>50" in compact
    assert "strategy_atr_period<5||strategy_atr_period>20" in compact
    assert "strategy_atr_multiplier<1.0||strategy_atr_multiplier>2.5" in compact
    assert "QM_IsNewBar(_Symbol,PERIOD_H4)" in compact
    for line in source.splitlines():
        if re.search(r"\bi(?:Open|High|Low|Close|Time)\s*\(", line):
            assert "perf-allowed" in line, line


def test_mechanical_hardening_passes_for_the_reworked_source() -> None:
    result = gate.analyze(REPO, LABEL)

    assert result["files_scanned"] == 1
    assert result["failures"] == []
    assert result["warnings"] == []


def test_registry_and_backtest_sets_bind_all_strategy_defaults() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "33007" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS

    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        setfile = EA_DIR / "sets" / f"{LABEL}_{symbol}_H4_backtest.set"
        assert setfile.is_file()
        text = setfile.read_text(encoding="utf-8-sig")
        values = _set_values(setfile)
        assert re.search(r"(?m)^; build_hash:\s+[0-9a-f]{64}$", text)
        assert values["qm_ea_id"] == "33007"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert float(values["RISK_FIXED"]) == 1000.0
        assert float(values["RISK_PERCENT"]) == 0.0
        assert values["strategy_daily_realized_loss_halt_pct"] == "2.0"
        assert values["strategy_daily_drawdown_hard_stop_pct"] == "2.5"
        assert values["strategy_total_drawdown_stop_pct"] == "5.0"
        assert values["strategy_max_slippage_ticks"] == "3.0"
