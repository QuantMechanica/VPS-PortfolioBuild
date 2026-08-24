from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38001_codetrading-vwap-bollinger-rsi-scalper"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"
CARD_PATH = (
    ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / f"{EA_LABEL}.md"
)
EXPECTED_SLOTS = {
    "EURUSD.DWX": 0,
    "GBPUSD.DWX": 1,
    "USDJPY.DWX": 2,
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


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_card_registry_and_hardening_contracts_are_clean() -> None:
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    assert re.search(r"(?m)^ea_id:\s*QM5_38001\s*$", card)
    assert re.search(
        r"(?m)^slug:\s*codetrading-vwap-bollinger-rsi-scalper\s*$", card
    )
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)

    with (ROOT / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        ea_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "38001"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "codetrading-vwap-bollinger-rsi-scalper"

    with (ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        magic_rows = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "38001" and row["status"] == "active"
        }
    assert magic_rows == EXPECTED_SLOTS
    resolver = (
        ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    ).read_text(encoding="utf-8-sig")
    for slot in EXPECTED_SLOTS.values():
        assert str(38001 * 10000 + slot) in resolver

    result = hardening.analyze_file(SOURCE_PATH, hardening.find_card(ROOT, EA_LABEL))
    assert result["failures"] == []
    assert result["warnings"] == []


def test_review_repairs_keep_management_reachable_and_spread_current() -> None:
    source = _source()
    on_tick = _function(source, "OnTick")
    entry = _function(source, "Strategy_EntrySignal")

    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert entry.index("StrategyCurrentQuoteAndSpreadAllowed(ask, bid)") < entry.index(
        "const double entry"
    )
    assert "const double entry = (side == QM_BUY) ? ask : bid;" in entry


def test_session_vwap_is_restart_safe_and_rate_arrays_are_bounded() -> None:
    source = _source()
    rebuild = _function(source, "StrategyRebuildSessionVwap")
    refresh = _function(source, "AdvanceState_OnNewBar")
    on_init = _function(source, "OnInit")

    assert "session_rebuild_bars = 400" in rebuild
    assert "CopyRates(_Symbol," in rebuild and "// perf-allowed" in rebuild
    assert "QM_BrokerToUTC(history[i].time)" in rebuild
    assert "history_size = ArraySize(history)" in rebuild
    assert "MathMin(copied, history_size)" in rebuild
    assert "ArraySize(latest) < 1" in refresh
    assert "StrategyRebuildSessionVwap(day_key)" in refresh
    assert "AdvanceState_OnNewBar();" in on_init


def test_framework_risk_magic_mae_and_every_declared_input_are_wired() -> None:
    raw = _source()
    source = hardening.strip_comments_preserve_lines(raw)

    assert "#include <QM/QM_Common.mqh>" in raw
    assert "input double RISK_PERCENT               = 0.0;" in raw
    assert "input double RISK_FIXED                 = 1000.0;" in raw
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert re.search(r"\bqm_ea_id\s*\*", source) is None
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)
    assert "CopyBuffer(" not in source

    for line in raw.splitlines():
        if "CopyRates(" in line:
            assert "// perf-allowed" in line or line.rstrip().endswith("CopyRates(_Symbol,")

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

    spec = (EA_DIR / "SPEC.md").read_text(encoding="utf-8-sig")
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec


def test_backtest_sets_cover_only_authorized_symbols_and_all_strategy_inputs() -> None:
    source = _source()
    normalized_source = SOURCE_PATH.read_bytes().replace(b"\r\n", b"\n").replace(
        b"\r", b"\n"
    )
    source_hash = hashlib.sha256(normalized_source).hexdigest()
    strategy_inputs = re.findall(
        r"(?m)^\s*input\s+\S+\s+(strategy_\w+)\s*=", source
    )
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == len(EXPECTED_SLOTS)

    for symbol, slot in EXPECTED_SLOTS.items():
        path = SETS_DIR / f"{EA_LABEL}_{symbol}_M5_backtest.set"
        assert path in setfiles
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert (
            "; card_defaults_source=strategy-seeds/cards/approved/"
            f"{EA_LABEL}.md"
        ) in text
        assert values["qm_ea_id"] == "38001"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert all(name in values for name in strategy_inputs)
