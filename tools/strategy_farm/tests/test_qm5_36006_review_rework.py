from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36006_nnfx-halftrend-jurik-coppock-engine"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
CARD_PATH = ROOT / "strategy-seeds" / "cards" / "approved" / f"{EA_LABEL}.md"
SETS_DIR = EA_DIR / "sets"
EXPECTED_SLOTS = {"EURUSD.DWX": 0, "GBPUSD.DWX": 1, "USDJPY.DWX": 2}


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def _function(source: str, name: str) -> str:
    match = re.search(rf"(?m)^\s*\w+\s+{re.escape(name)}\s*\(", source)
    assert match, f"function not found: {name}"
    brace = source.index("{", match.start())
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[match.start() : index + 1]
    raise AssertionError(f"unterminated function: {name}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_approved_card_registry_resolver_and_hardening_are_clean() -> None:
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    assert re.search(r"(?m)^ea_id:\s*QM5_36006\s*$", card)
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)

    with (ROOT / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36006"]
    assert len(rows) == 1
    assert rows[0]["slug"] == "nnfx-halftrend-jurik-coppock-engine"

    with (ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        slots = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "36006" and row["status"] == "active"
        }
    assert slots == EXPECTED_SLOTS

    resolver = (
        ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    ).read_text(encoding="utf-8-sig")
    for slot in EXPECTED_SLOTS.values():
        assert str(36006 * 10000 + slot) in resolver

    result = hardening.analyze_file(SOURCE_PATH, hardening.find_card(ROOT, EA_LABEL))
    assert result["failures"] == []
    assert result["warnings"] == []


def test_halftrend_jurik_and_custom_series_are_card_faithful_and_bounded() -> None:
    source = _source()
    refresh = _function(source, "Strategy_RefreshClosedBarSignals")

    assert "QM_EMA(_Symbol, PERIOD_D1, strategy_halftrend_amp, 1, PRICE_CLOSE)" in refresh
    assert "strategy_halftrend_atr_mult * halftrend_atr" in refresh
    assert "const double phase_ratio = 1.5;" in refresh
    assert "const double alpha = MathPow(beta, 2.0);" in refresh
    assert "jma_current - jma_previous" in refresh
    assert "3.0 * e1 - 3.0 * e2" not in source

    assert "required > 256" in refresh
    assert "ArraySize(rates) < required" in refresh
    assert "i >= ArraySize(rates)" in refresh
    assert "index >= ArraySize(rates)" in refresh
    raw_calls = [
        line
        for line in source.splitlines()
        if re.search(r"\b(?:CopyRates|iOpen|iHigh|iLow|iClose|iTime|iVolume)\s*\(", line)
    ]
    assert len(raw_calls) == 1
    assert "CopyRates(" in raw_calls[0] and "// perf-allowed:" in raw_calls[0]


def test_tp1_is_partial_once_then_be_protected_and_runner_has_no_broker_tp() -> None:
    source = _source()
    entry = _function(source, "Strategy_EntrySignal")
    management = _function(source, "Strategy_ManageOpenPosition")

    assert entry.count("req.tp = 0.0;") >= 1
    assert "volume * strategy_tp1_fraction" in management
    assert management.count("QM_TM_PartialClose(") == 1
    assert "if(!g_tp1_done" in management
    assert "g_tp1_done = true;" in management
    assert management.index("g_tp1_done = true;") < management.index(
        "if(g_tp1_done && PositionSelectByTicket(ticket))"
    )
    assert "QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips)" in management
    assert '"NNFX_TP1_BE_PROTECTION"' in management


def test_management_exit_risk_clock_and_mae_paths_remain_reachable() -> None:
    source = _source()
    on_tick = _function(source, "OnTick")
    no_trade = _function(source, "Strategy_NoTradeFilter")
    on_init = _function(source, "OnInit")

    management = on_tick.index("Strategy_ManageOpenPosition();")
    assert management < on_tick.index("QM_IsNewBar(_Symbol, PERIOD_D1)")
    assert management < on_tick.index("QM_NewsAllowsTrade2")
    assert management < on_tick.index("Strategy_NoTradeFilter()")
    assert on_tick.index("Strategy_RefreshClosedBarSignals()") < on_tick.index(
        "Strategy_ExitSignal()"
    )

    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "QM_BrokerToUTC(TimeCurrent())" in no_trade
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "Strategy_TotalDrawdownAllows()" in on_tick
    assert "QM_KillSwitchInit(qm_ea_id" in on_init
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "QM_EntryConfigure(qm_ea_id" in on_init
    assert "strategy_max_slippage_ticks * tick_size / point" in on_init
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in on_init


def test_framework_inputs_and_backtest_sets_are_fully_wired_and_hash_bound() -> None:
    raw = _source()
    source = hardening.strip_comments_preserve_lines(raw)
    assert "#include <QM/QM_Common.mqh>" in raw
    assert "input double RISK_PERCENT                 = 0.0;" in raw
    assert "input double RISK_FIXED                   = 1000.0;" in raw
    assert "QM_FrameworkMagic()" in source
    assert re.search(r"\bqm_ea_id\s*\*", source) is None
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)

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

    normalized = SOURCE_PATH.read_bytes().replace(b"\r\n", b"\n").replace(
        b"\r", b"\n"
    )
    source_hash = hashlib.sha256(normalized).hexdigest()
    strategy_inputs = re.findall(
        r"(?m)^\s*input\s+\S+\s+(strategy_\w+)\s*=", raw
    )
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == len(EXPECTED_SLOTS)

    for symbol, slot in EXPECTED_SLOTS.items():
        path = SETS_DIR / f"{EA_LABEL}_{symbol}_D1_backtest.set"
        assert path in setfiles
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "36006"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["strategy_max_slippage_ticks"] == "3.0"
        assert all(name in values for name in strategy_inputs)

    spec = (EA_DIR / "SPEC.md").read_text(encoding="utf-8-sig")
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec
