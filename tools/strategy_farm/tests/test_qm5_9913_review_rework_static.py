from __future__ import annotations

import hashlib
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_9913_bandy-rsi3-low-adx-mr-index"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"
AUTHORIZED_SYMBOLS = {
    "AUDUSD.DWX",
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "NDX.DWX",
    "NZDUSD.DWX",
    "SP500.DWX",
    "USDCAD.DWX",
    "USDCHF.DWX",
    "USDJPY.DWX",
    "WS30.DWX",
}


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def _function(source: str, name: str) -> str:
    start = source.index(f"{name}(")
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"unterminated function: {name}")


def _checkout_hash() -> str:
    normalized = SOURCE_PATH.read_bytes().replace(b"\r\n", b"\n").replace(
        b"\r", b"\n"
    )
    return hashlib.sha256(normalized.replace(b"\n", b"\r\n")).hexdigest()


def test_qm5_9913_hardening_gate_is_clean() -> None:
    result = hardening.analyze_file(
        SOURCE_PATH, hardening.find_card(ROOT, EA_LABEL)
    )
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_9913_uses_closed_d1_data_for_cadence_and_stop() -> None:
    source = _source()
    on_init = _function(source, "OnInit")
    on_tick = _function(source, "OnTick")
    entry = _function(source, "Strategy_EntrySignal")

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in on_init
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in on_tick
    assert "QM_IsNewBar()" not in on_tick
    assert "QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar)" in entry
    assert "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1)" in entry
    assert (
        "QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr14, "
        "strategy_sl_atr_mult)" in entry
    )
    assert "QM_StopATR(" not in entry


def test_qm5_9913_entry_filters_cannot_suppress_card_exits() -> None:
    source = _source()
    on_tick = _function(source, "OnTick")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    generic_exit = on_tick.index("Strategy_ExitSignal()")
    entry_edges = [
        on_tick.index("QM_IsNewBar(_Symbol, PERIOD_D1)"),
        on_tick.index("Strategy_NewsFilterHook(broker_now)"),
        on_tick.index("QM_NewsAllowsTrade2"),
        on_tick.index("Strategy_NoTradeFilter()"),
    ]
    assert all(manage < edge for edge in entry_edges)
    assert all(generic_exit < edge for edge in entry_edges)


def test_qm5_9913_declared_inputs_are_wired_and_no_filter_was_invented() -> None:
    raw = _source()
    source = hardening.strip_comments_preserve_lines(raw)
    inputs = re.findall(r"(?m)^\s*input\s+\S+\s+(\w+)\s*=", source)
    without_declarations = re.sub(
        r"(?m)^\s*input\s+\S+\s+\w+\s*=.*?;\s*$", "", source
    )

    assert inputs
    assert [
        name
        for name in inputs
        if re.search(rf"\b{re.escape(name)}\b", without_declarations) is None
    ] == []
    assert "strategy_spread_max_atr" not in raw
    assert "strategy_warmup_bars" not in raw
    assert "CopyBuffer(" not in source
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)

    for line in raw.splitlines():
        if re.search(r"\b(?:iBars|iBarShift|iClose|iOpen|iHigh|iLow|iTime|Copy\w+)\s*\(", line):
            assert "perf-allowed" in line


def test_qm5_9913_package_matches_card_universe_and_backtest_risk() -> None:
    setfiles = sorted(SETS_DIR.glob("*.set"))
    observed_symbols = {
        re.search(r"(?m)^; symbol:\s+(\S+)$", path.read_text(encoding="utf-8-sig"))
        .group(1)
        .strip()
        for path in setfiles
    }

    assert observed_symbols == AUTHORIZED_SYMBOLS
    assert len(setfiles) == len(AUTHORIZED_SYMBOLS)
    source_hash = _checkout_hash()
    for setfile in setfiles:
        payload = setfile.read_text(encoding="utf-8-sig")
        assert f"; build_hash:   {source_hash}" in payload
        assert "RISK_FIXED=1000" in payload
        assert "RISK_PERCENT=0" in payload
        assert "strategy_spread_max_atr" not in payload
        assert "strategy_warmup_bars" not in payload
