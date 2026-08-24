from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_12943_robopip-hlhb-trend-catcher-h1"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"
AUTHORIZED_SYMBOLS = {
    "EURUSD.DWX": 6,
    "GBPUSD.DWX": 7,
    "USDJPY.DWX": 8,
    "XAUUSD.DWX": 5,
}


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def function_body(source: str, function_name: str) -> str:
    match = re.search(
        rf"\b{re.escape(function_name)}\s*\([^)]*\)\s*\{{(?P<body>.*?)\n\}}",
        source,
        flags=re.DOTALL,
    )
    assert match is not None, function_name
    return match.group("body")


def test_qm5_12943_source_hardening_is_clean() -> None:
    result = hardening.analyze_file(SOURCE_PATH, hardening.find_card(REPO_ROOT, EA_LABEL))
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_12943_card_faithful_signal_and_time_stop() -> None:
    source = source_text()
    management = function_body(source, "Strategy_ManageOpenPosition")

    assert "const double atr_daily = atr_h1 * 24.0;" in source
    assert "QM_ATR(_Symbol, PERIOD_D1" not in source
    assert "iBarShift(_Symbol, PERIOD_H1, open_time); // perf-allowed" in management
    assert "bars_open >= strategy_time_stop_bars" in management
    assert "POSITION_PRICE_OPEN" in management
    assert "SYMBOL_BID" in management
    assert "SYMBOL_ASK" in management
    assert "close_price >= entry_price" in management
    assert "close_price <= entry_price" in management
    assert management.index("if(at_or_beyond_break_even)") < management.index(
        "QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP)"
    )
    assert "TimeCurrent() - open_time" not in management


def test_qm5_12943_framework_corset_and_input_wiring() -> None:
    raw = source_text()
    source = hardening.strip_comments_preserve_lines(raw)
    on_tick = function_body(raw, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in raw
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert "QM_FrameworkMagic()" in raw
    assert re.search(r"\bqm_ea_id\s*\*", source) is None
    assert "CopyBuffer(" not in source
    for raw_indicator in ("iATR", "iMA", "iRSI", "iMACD", "iADX", "iBands"):
        assert re.search(rf"\b{raw_indicator}\s*\(", source) is None
    for line in raw.splitlines():
        if "iClose(" in line or "iBarShift(" in line:
            assert "// perf-allowed" in line

    input_names = re.findall(r"(?m)^\s*input\s+\S+\s+(\w+)\s*=", source)
    assert input_names
    source_without_declarations = re.sub(
        r"(?m)^\s*input\s+\S+\s+\w+\s*=.*?;\s*$", "", source
    )
    unused = [
        name
        for name in input_names
        if re.search(rf"\b{re.escape(name)}\b", source_without_declarations) is None
    ]
    assert unused == []


def test_qm5_12943_delivers_only_the_card_symbols_with_fixed_risk() -> None:
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == len(AUTHORIZED_SYMBOLS)

    delivered: dict[str, int] = {}
    for setfile in setfiles:
        payload = setfile.read_text(encoding="utf-8")
        symbol = re.search(r"(?m)^; symbol:\s*(\S+)\s*$", payload)
        slot = re.search(r"(?m)^qm_magic_slot_offset=(\d+)\s*$", payload)
        assert symbol is not None
        assert slot is not None
        delivered[symbol.group(1)] = int(slot.group(1))
        assert "RISK_FIXED=1000" in payload
        assert "RISK_PERCENT=0" in payload

    assert delivered == AUTHORIZED_SYMBOLS

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        active_rows = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "12943" and row["status"] == "active"
        }
    for symbol, slot in AUTHORIZED_SYMBOLS.items():
        assert active_rows.get(symbol) == slot
