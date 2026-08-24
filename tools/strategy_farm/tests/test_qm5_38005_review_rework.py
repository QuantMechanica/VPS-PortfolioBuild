from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38005_codetrading-ascending-triangle-breakout"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SOURCE = SOURCE_PATH.read_text(encoding="utf-8-sig")


def _code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


CODE = _code_without_comments(SOURCE)
COMPACT = re.sub(r"\s+", "", CODE)


def test_card_geometry_volume_and_exit_contract_are_locked_closed() -> None:
    assert re.search(r"strategy_pivot_window\s*=\s*5\s*;", CODE)
    assert "resistance_price_slope / g_last_atr" in CODE
    assert "support_price_slope / g_last_atr" in CODE
    assert "MathAbs(resistance_slope) <= strategy_max_res_slope" in CODE
    assert "support_slope >= strategy_min_trend_slope" in CODE
    assert "MathAbs(support_slope) <= strategy_max_res_slope" in CODE
    assert "resistance_slope <= -strategy_min_trend_slope" in CODE

    assert "volume <= 0.0" in CODE
    assert "signal_volume > strategy_vol_mult * average_volume" in CODE
    assert "avg_vol <= 0.0" not in CODE
    assert "signal_volume >=" not in CODE

    assert "g_last_triangle_height * strategy_triangle_height_mult" in CODE
    assert "target_distance < strategy_tp_rr * risk_distance" in CODE
    assert "g_last_atr * 1.5" not in CODE
    assert "TRIANGLE_SWING_LOW_TRAIL" in CODE
    assert "TRIANGLE_SWING_HIGH_TRAIL" in CODE


def test_framework_ordering_risk_time_and_bounded_data_are_locked_closed() -> None:
    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", CODE)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", CODE)
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1" in COMPACT
    assert "QM_FrameworkTrackOpenPositionMae" in CODE
    assert "StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent()))" in COMPACT

    assert "CopyRates" in CODE and "perf-allowed" in SOURCE
    assert "ArrayResize(rates, required)" in CODE
    assert "ArraySize(rates)" in CODE
    assert not re.search(r"\bi(?:Close|Open|High|Low|Time|Volume)\s*\(", CODE)

    on_tick = re.search(r"void\s+OnTick\s*\(\s*\)\s*\{(?P<body>.*?)\n\}", CODE, re.DOTALL)
    assert on_tick is not None
    body = on_tick.group("body")
    assert body.index("AdvanceState_OnNewBar();") < body.index(
        "Strategy_ManageOpenPosition();"
    )
    assert body.index("Strategy_ManageOpenPosition();") < body.index(
        "Strategy_NoTradeFilter()"
    )
    assert body.index("Strategy_ManageOpenPosition();") < body.index(
        "QM_NewsAllowsTrade2"
    )

    for required in (
        "strategy_daily_loss_halt_pct",
        "strategy_daily_hard_stop_pct",
        "strategy_total_dd_halt_pct",
        "strategy_per_trade_risk_cap_pct",
        "strategy_max_slippage_ticks",
        "QM_RiskSizerSetCapPct(strategy_per_trade_risk_cap_pct)",
        "QM_KillSwitchInit",
        "QM_EntryConfigure",
        "SYMBOL_TRADE_TICK_SIZE",
    ):
        assert required in CODE

    on_init = re.search(r"int\s+OnInit\s*\(\s*\)\s*\{(?P<body>.*?)\n\}", CODE, re.DOTALL)
    assert on_init is not None
    assert "AdvanceState_OnNewBar();" in on_init.group("body")


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
            if row["ea_id"] == "38005" and row["status"] == "active"
        ]
    assert [
        (row["symbol_slot"], row["symbol"], row["magic"])
        for row in rows
    ] == [
        ("0", "XAUUSD.DWX", "380050000"),
        ("1", "SP500.DWX", "380050001"),
        ("2", "EURUSD.DWX", "380050002"),
    ]


def test_backtest_setfiles_keep_fixed_risk_and_all_strategy_inputs() -> None:
    source_strategy_inputs = set(
        re.findall(
            r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+"
            r"(strategy_[A-Za-z0-9_]*)\s*=",
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
