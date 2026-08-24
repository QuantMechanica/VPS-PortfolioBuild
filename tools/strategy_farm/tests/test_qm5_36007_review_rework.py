from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36007_nnfx-vidya-trix-fisher-momentum"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"


def source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def function_body(code: str, name: str, next_name: str) -> str:
    return code.split(f"{name}()", 1)[1].split(next_name, 1)[0]


def declared_inputs(code: str) -> dict[str, str]:
    return dict(
        re.findall(
            r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+"
            r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);",
            code,
        )
    )


def test_review_findings_are_locked_closed() -> None:
    text = source()
    code = code_without_comments(text)
    compact = re.sub(r"\s+", "", code)
    manage = function_body(code, "Strategy_ManageOpenPosition", "bool Strategy_ExitSignal")
    exit_signal = function_body(code, "Strategy_ExitSignal", "bool Strategy_NewsFilterHook")
    no_trade = function_body(code, "Strategy_NoTradeFilter", "bool Strategy_EntrySignal")
    on_tick = function_body(code, "OnTick", "void OnTimer")

    # TP1 closes only half and leaves a protected runner for the TRIX recross.
    assert "QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL)" in manage
    assert "volume * 0.5" in manage
    assert "QM_TM_MoveSL" in manage
    assert "g_long_exit_cross" in exit_signal
    assert "g_short_exit_cross" in exit_signal
    assert "Strategy_ComputeClosedBarSignals" not in exit_signal

    # GMT and all three card loss limits are executable, not prose-only.
    assert "QM_BrokerToUTC(TimeCurrent())" in compact
    assert "strategy_daily_loss_limit_pct" in code
    assert "strategy_daily_drawdown_hard_stop_pct" in code
    assert "strategy_total_drawdown_stop_pct" in code
    assert re.search(
        r"QM_KillSwitchInit\s*\(\s*qm_ea_id\s*,\s*QM_FrameworkMagic\(\)\s*,\s*"
        r"strategy_daily_drawdown_hard_stop_pct\s*,\s*"
        r"strategy_total_drawdown_stop_pct\s*,\s*1\.0\s*\)",
        code,
    )
    assert "Strategy_LoadRiskState()" in code
    assert "GlobalVariableCheck" in code
    assert "GlobalVariableGet" in code
    assert "GlobalVariableSet" in code
    assert "GlobalVariablesFlush" in code
    assert "daily_realized_halt" in code
    assert "total_drawdown_halt" in code
    assert "MathAbs(strategy_daily_loss_limit_pct - 2.0)" in code
    assert "MathAbs(strategy_daily_drawdown_hard_stop_pct - 2.5)" in code
    assert "MathAbs(strategy_total_drawdown_stop_pct - 5.0)" in code
    on_init = function_body(code, "OnInit", "void OnDeinit")
    assert on_init.index("Strategy_InputsValid()") < on_init.index(
        "QM_FrameworkInit(qm_ea_id"
    )

    # Entry-only filters keep management and the TRIX runner exit reachable.
    assert "if(open_count == 0)\n      return blocked;\n   return false;" in no_trade
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NewsFilterHook"
    )


def test_framework_risk_magic_mae_and_buffer_contracts() -> None:
    text = source()
    code = code_without_comments(text)
    on_tick = function_body(code, "OnTick", "void OnTimer")

    assert "#include <QM/QM_Common.mqh>" in text
    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", code)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", code)
    assert "QM_FrameworkMagic()" in code
    assert re.search(
        r"QM_FrameworkDeclareExecutionContract\s*\(\s*PERIOD_D1\s*,\s*"
        r"QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE\s*,\s*"
        r'"V5_WEEKEND_RISK_POLICY"\s*\)',
        code,
    )
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in code
    assert not re.search(r"\bQM_IsNewBar\s*\(\s*\)", code)
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert "CopyRates(_Symbol, PERIOD_D1, 1, warmup_bars, rates)" in code
    assert "perf-allowed" in text
    assert "remove_index >= ArraySize(gains)" in code
    assert "remove_index >= ArraySize(losses)" in code
    assert "newest >= ArraySize(rates)" in code

    report = build_gate_hardening.analyze(REPO_ROOT, EA_LABEL)
    assert report["files_scanned"] == 1
    assert report["failures"] == []
    assert report["warnings"] == []


def test_every_declared_input_is_executable_and_strategy_values_are_in_sets() -> None:
    code = code_without_comments(source())
    inputs = declared_inputs(code)
    assert inputs
    unused = [
        name
        for name in inputs
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ]
    assert unused == []

    strategy_inputs = {name for name in inputs if name.startswith("strategy_")}
    setfiles = sorted((EA_DIR / "sets").glob(f"{EA_LABEL}_*_D1_backtest.set"))
    assert len(setfiles) == 3
    for setfile in setfiles:
        values = {
            key.strip(): value.strip()
            for line in setfile.read_text(encoding="utf-8-sig").splitlines()
            if line and not line.startswith(";") and "=" in line
            for key, value in [line.split("=", 1)]
        }
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert strategy_inputs <= values.keys()


def test_magic_registry_rows_are_existing_active_allocations() -> None:
    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "36007" and row["status"] == "active"
        ]

    assert [
        (row["symbol_slot"], row["symbol"], row["magic"])
        for row in rows
    ] == [
        ("0", "EURUSD.DWX", "360070000"),
        ("1", "GBPJPY.DWX", "360070001"),
        ("2", "NZDCAD.DWX", "360070002"),
    ]
