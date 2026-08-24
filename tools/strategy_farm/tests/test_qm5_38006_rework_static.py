from __future__ import annotations

import hashlib
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38006_codetrading-doji-hammer-pivot-rejection"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
APPROVED_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / f"{EA_LABEL}.md"
)


def _source() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{re.escape(name)}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing function {name}"
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError(f"unterminated function {name}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_current_hardening_passes_against_approved_card() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, APPROVED_CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_management_and_exit_are_reachable_before_entry_filters() -> None:
    on_tick = _function_body(_source(), "OnTick")

    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )
    assert on_tick.index("if(Strategy_ExitSignal())") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )


def test_live_spread_is_rechecked_at_execution_boundary() -> None:
    source = _source()
    spread = _function_body(source, "StrategyCurrentSpreadAllowsEntry")
    no_trade = _function_body(source, "Strategy_NoTradeFilter")
    on_tick = _function_body(source, "OnTick")

    assert "g_last_atr * strategy_spread_filter_mult" in spread
    assert "ask <= 0.0 || bid <= 0.0 || ask < bid || g_last_atr <= 0.0" in spread
    assert "return !StrategyCurrentSpreadAllowsEntry();" in no_trade

    signal_index = on_tick.index("if(Strategy_EntrySignal(req))")
    recheck_index = on_tick.index("if(!StrategyCurrentSpreadAllowsEntry())", signal_index)
    open_index = on_tick.index("QM_TM_OpenPosition(req, out_ticket);", recheck_index)
    assert signal_index < recheck_index < open_index


def test_card_stops_take_profit_and_original_r_break_even_are_exact() -> None:
    source = _source()
    entry = _function_body(source, "Strategy_EntrySignal")
    management = _function_body(source, "Strategy_ManageOpenPosition")

    assert "g_last_low1 - buffer" in entry
    assert "g_last_high1 + buffer" in entry
    assert "sl_dist * strategy_tp_rr_mult" in entry
    assert "entry - g_last_atr" not in entry
    assert "entry + g_last_atr" not in entry
    assert "initial_risk * strategy_be_trigger_r" in management
    assert '"BE_AT_ORIGINAL_1R"' in management
    assert "QM_StopRulesNormalizePrice(_Symbol, open_price)" in management


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = _source()
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert names
    unused = [
        name
        for name in names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ]
    assert unused == []


def test_framework_magic_mae_perf_and_backtest_set_contract() -> None:
    source = _source()
    refresh = _function_body(source, "AdvanceState_OnNewBar")
    spec = SPEC.read_text(encoding="utf-8")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "380060000" not in source
    assert "QM_TM_OpenPosition(req, out_ticket);" in source
    assert "CopyBuffer(" not in source
    assert "iMA(" not in source
    assert "iATR(" not in source

    raw_series_lines = [
        line
        for line in refresh.splitlines()
        if re.search(r"\bi(?:Open|Close|High|Low)\s*\(", line)
    ]
    assert len(raw_series_lines) == 4
    assert all("perf-allowed:" in line for line in raw_series_lines)

    forbidden_ml_tokens = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert all(token not in source.lower() for token in forbidden_ml_tokens)
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec

    source_hash = hashlib.sha256(EA_SOURCE.read_bytes()).hexdigest()
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 3
    for setfile in setfiles:
        set_text = setfile.read_text(encoding="utf-8-sig")
        values = _set_values(setfile)
        build_hash = re.search(
            r"^;\s*build_hash:\s*([0-9a-f]{64})\s*$",
            set_text,
            flags=re.MULTILINE,
        )
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert build_hash is not None
        assert build_hash.group(1) == source_hash
