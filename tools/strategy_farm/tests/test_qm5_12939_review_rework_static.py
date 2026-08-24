from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_12939_carney-alternate-bat-h4"
SOURCE = EA_DIR / "QM5_12939_carney-alternate-bat-h4.mq5"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("GDAXI.DWX", 129390000),
    1: ("NDX.DWX", 129390001),
    2: ("SP500.DWX", 129390002),
    3: ("UK100.DWX", 129390003),
    4: ("WS30.DWX", 129390004),
    5: ("XAUUSD.DWX", 129390005),
    6: ("EURUSD.DWX", 129390006),
    7: ("GBPUSD.DWX", 129390007),
    8: ("USDJPY.DWX", 129390008),
    9: ("USDCHF.DWX", 129390009),
    10: ("AUDUSD.DWX", 129390010),
    11: ("USDCAD.DWX", 129390011),
    12: ("NZDUSD.DWX", 129390012),
}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_card_zigzag_contract_is_real_bounded_and_newest_first() -> None:
    source = _source()
    compact = _compact(source)

    assert "strategy_zigzag_depth=12" in compact
    assert "strategy_zigzag_deviation=5" in compact
    assert "strategy_zigzag_backstep=3" in compact
    assert '"Examples\\\\ZigZag"' in source
    assert "strategy_fractal_wing_bars" not in source
    assert "CopyBuffer(g_zigzag_handle,0,1,requested,zigzag)" in compact
    assert "CopyRates(_Symbol,_Period,1,requested,rates)" in compact
    assert "ArraySize(zigzag)<available||ArraySize(rates)<available" in compact
    assert "i>=rates_copied||i>=ArraySize(zigzag)||i>=ArraySize(rates)" in compact
    assert "constStrategyPivotd_piv=pivots[0];" in compact
    assert "constStrategyPivotx_piv=pivots[4];" in compact


def test_entry_cooldown_and_partial_state_commit_only_after_acceptance() -> None:
    source = _source()
    compact = _compact(source)
    entry_start = source.index("bool Strategy_EntrySignal")
    entry_end = source.index("void Strategy_ManageOpenPosition", entry_start)
    entry = source[entry_start:entry_end]

    assert "g_bars_since_last_long = 0" not in entry
    assert "g_bars_since_last_short = 0" not in entry
    assert "if(QM_TM_OpenPosition(req,ticket))" in compact
    assert compact.index("if(QM_TM_OpenPosition(req,ticket))") < compact.index(
        "g_bars_since_last_long=0"
    )
    assert compact.count(
        "QM_TM_PartialClose(ticket,half_vol,QM_EXIT_STRATEGY)){g_trade_state.t1_hit=true;Strategy_PersistTradeState();}"
    ) == 2
    assert source.count("g_trade_state.t1_hit = true;") == 2


def test_restart_state_t2_trail_time_stop_and_opposite_exit_are_wired() -> None:
    source = _source()
    compact = _compact(source)

    assert "Strategy_RestoreTradeState(ticket);" in source
    assert 'GlobalVariableSet(Strategy_TradeStateKey(g_trade_state.ticket, "t1")' in source
    assert 'GlobalVariableSet(Strategy_TradeStateKey(g_trade_state.ticket, "t2")' in source
    assert 'GlobalVariableSet(Strategy_TradeStateKey(g_trade_state.ticket, "t1hit")' in source
    assert "req.tp=NormalizeDouble(g_long_t2,_Digits);" in compact
    assert "req.tp=NormalizeDouble(g_short_t2,_Digits);" in compact
    assert "strategy_atr_trail_mult" in source
    assert "bars_open>=strategy_max_hold_bars" in compact
    assert "ptype==POSITION_TYPE_BUY&&g_short_signal" in compact
    assert "ptype==POSITION_TYPE_SELL&&g_long_signal" in compact
    assert compact.index("if(Strategy_ExitSignal())") < compact.index(
        "if(QM_TM_OpenPositionCount(QM_FrameworkMagic())==0)"
    )


def test_framework_corset_and_all_strategy_inputs_are_wired() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "ZeroMemory(req);" in source
    assert "RISK_PERCENT" in source and "RISK_FIXED" in source
    assert "tensorflow" not in source.lower()
    assert "torch" not in source.lower()
    assert "sklearn" not in source.lower()
    assert "onnx" not in source.lower()

    raw_series = re.compile(r"\bi(?:Bars|BarShift|Open|High|Low|Close|Time)\s*\(")
    for line in source.splitlines():
        if raw_series.search(line):
            assert "perf-allowed" in line, line

    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert strategy_inputs
    for input_name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(input_name)}\b", source)) >= 2, input_name


def test_registry_and_all_backtest_sets_bind_the_reworked_source() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "12939" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS

    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    set_paths = sorted(SETS.glob("*.set"))
    assert len(set_paths) == len(EXPECTED_SLOTS)
    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        path = SETS / f"QM5_12939_carney-alternate-bat-h4_{symbol}_H4_backtest.set"
        assert path.is_file()
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "12939"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert float(values["RISK_FIXED"]) == 1000.0
        assert float(values["RISK_PERCENT"]) == 0.0
        assert values["strategy_zigzag_depth"] == "12"
        assert values["strategy_zigzag_deviation"] == "5"
        assert values["strategy_zigzag_backstep"] == "3"
        assert values["strategy_tp1_ad_retracement"] == "0.382"
        assert values["strategy_tp2_ad_retracement"] == "0.618"
        assert values["strategy_atr_trail_mult"] == "1.0"
