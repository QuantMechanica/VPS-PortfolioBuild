from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_39005_forexfactory-genesis-matrix-scalper"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SOURCE = SOURCE_PATH.read_text(encoding="utf-8-sig")


def _code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


CODE = _code_without_comments(SOURCE)


def test_review_findings_are_locked_closed() -> None:
    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", CODE)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", CODE)
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M5" in re.sub(r"\s+", "", CODE)

    assert "QM_BrokerToUTC(TimeCurrent())" in re.sub(r"\s+", "", CODE)
    assert "QM_EntryConfigure" in CODE
    assert "SYMBOL_TRADE_TICK_SIZE" in CODE
    assert re.search(r"3\.0\s*\*\s*tick_size", CODE)

    assert "ArraySize(rates)" in CODE
    assert "ArraySize(cci_buf)" in CODE
    assert not re.search(r"\bi(?:Close|Open|High|Low|Time|Volume)\s*\(", CODE)
    assert "CopyRates" in CODE and "perf-allowed" in SOURCE

    assert "g_state_valid = false" in CODE
    assert re.search(r"if\s*\(\s*!CalculateTVI", CODE)
    assert re.search(r"if\s*\(\s*!CalculateT3CCI", CODE)
    assert re.search(r"if\s*\(\s*!CalculateGHL", CODE)
    assert re.search(r"for\s*\(\s*int\s+s\s*=\s*warmup", CODE)
    assert re.search(r"int\s+trend\s*=\s*0\s*;", CODE)
    assert re.search(r"if\s*\(\s*trend\s*==\s*0\s*\)\s*return\s+false", CODE)

    assert "strategy_sl_buffer_pips * 10" not in CODE
    assert "strategy_be_trigger_pips * 10" not in CODE
    assert "3.5 * g_cached_atr_1" not in CODE
    assert re.search(r"const\s+double\s+sl\s*=\s*swing_low\s*-\s*buf", CODE)
    assert re.search(r"const\s+double\s+sl\s*=\s*swing_high\s*\+\s*buf", CODE)

    for required in (
        "strategy_daily_loss_halt_pct",
        "strategy_daily_hard_stop_pct",
        "strategy_total_dd_halt_pct",
        "strategy_per_trade_risk_cap_pct",
        "QM_FrameworkTrackOpenPositionMae",
    ):
        assert required in CODE


def test_every_declared_input_has_an_executable_use_site() -> None:
    names = re.findall(
        r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        CODE,
    )
    assert names
    unused = [
        name
        for name in names
        if len(re.findall(rf"\b{re.escape(name)}\b", CODE)) < 2
    ]
    assert unused == []


def test_scoped_hardening_and_magic_contract_pass() -> None:
    report = build_gate_hardening.analyze(REPO_ROOT, EA_LABEL)
    assert report["files_scanned"] == 1
    assert report["failures"] == []
    assert report["warnings"] == []

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "39005" and row["status"] == "active"
        ]
    assert [
        (row["symbol_slot"], row["symbol"], row["magic"])
        for row in rows
    ] == [
        ("0", "EURUSD.DWX", "390050000"),
        ("1", "GBPUSD.DWX", "390050001"),
    ]


def test_backtest_setfiles_keep_fixed_risk_and_strategy_inputs() -> None:
    source_strategy_inputs = set(
        re.findall(
            r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+"
            r"((?:Inp|strategy_)[A-Za-z0-9_]*)\s*=",
            CODE,
        )
    )
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 2
    for setfile in setfiles:
        values = {
            key.strip(): value.strip()
            for line in setfile.read_text(encoding="utf-8-sig").splitlines()
            if line and not line.startswith(";") and "=" in line
            for key, value in [line.split("=", 1)]
        }
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert source_strategy_inputs <= values.keys()
