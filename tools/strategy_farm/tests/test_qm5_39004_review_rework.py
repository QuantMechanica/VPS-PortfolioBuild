from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_39004_forexfactory-thv-cobra-trix-scalper"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SOURCE = SOURCE_PATH.read_text(encoding="utf-8-sig")


def _code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


CODE = _code_without_comments(SOURCE)


def test_review_findings_are_locked_closed() -> None:
    compact = re.sub(r"\s+", "", CODE)

    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", CODE)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", CODE)
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M5" in compact
    assert "QM_FrameworkTrackOpenPositionMae" in CODE

    assert "StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent()))" in compact
    assert "g_cached_atr_1 * strategy_spread_filter_mult" in CODE
    assert "StrategyDailyRealizedLossHalt()" in CODE
    assert re.search(
        r"QM_TM_OpenPositionCount\s*\(\s*magic\s*\)\s*>=\s*1", CODE
    )

    assert "strategy_sl_buffer_pips * 10" not in CODE
    assert re.search(
        r"QM_StopRulesPipsToPriceDistance\s*\(\s*_Symbol\s*,\s*"
        r"\(int\)MathRound\(strategy_sl_buffer_pips\)\s*\)",
        CODE,
    )
    assert "strategy_tp_rr" in CODE

    assert "g_pos_direction" not in CODE
    assert "PositionSelectByTicket" in CODE
    assert "POSITION_TYPE_BUY" in CODE and "POSITION_TYPE_SELL" in CODE
    assert CODE.index("if(Strategy_ExitSignal())") < CODE.index(
        "if(Strategy_NoTradeFilter())"
    )

    kill_switch_call = re.search(
        r"QM_KillSwitchInit\s*\(.*?\)\s*;", CODE, flags=re.DOTALL
    )
    assert kill_switch_call is not None
    assert "strategy_daily_hard_stop_pct" in kill_switch_call.group(0)
    assert "strategy_total_dd_halt_pct" in kill_switch_call.group(0)
    assert "strategy_per_trade_risk_cap_pct" in kill_switch_call.group(0)

    assert "ArraySize(rates)" in CODE
    assert "CopyRates" in CODE and "perf-allowed" in SOURCE
    assert re.search(r"\biClose\s*\(", CODE)
    assert "perf-allowed: single closed bar" in SOURCE


def test_every_declared_input_has_an_executable_use_site() -> None:
    names = re.findall(
        r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*=",
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
            if row["ea_id"] == "39004" and row["status"] == "active"
        ]
    assert [
        (row["symbol_slot"], row["symbol"], row["magic"])
        for row in rows
    ] == [
        ("0", "EURUSD.DWX", "390040000"),
        ("1", "USDJPY.DWX", "390040001"),
        ("2", "GBPUSD.DWX", "390040002"),
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
        assert source_strategy_inputs <= values.keys()
