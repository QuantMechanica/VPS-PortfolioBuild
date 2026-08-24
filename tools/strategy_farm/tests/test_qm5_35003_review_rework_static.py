from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_35003_three-ducks-multi-timeframe-system"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
CARD = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_35003_three-ducks-multi-timeframe-system.md"
)
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("EURUSD.DWX", 350030000),
    1: ("GBPUSD.DWX", 350030001),
    2: ("AUDUSD.DWX", 350030002),
    3: ("USDJPY.DWX", 350030003),
}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function(source: str, name: str, next_name: str) -> str:
    start = source.index(name)
    end = source.index(next_name, start)
    return source[start:end]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_approved_card_identity_and_fixed_contracts() -> None:
    card = CARD.read_text(encoding="utf-8")

    assert "ea_id: QM5_35003" in card
    assert "slug: three-ducks-multi-timeframe-system" in card
    assert "g0_status: APPROVED" in card
    assert "23:55` to `00:05` GMT" in card
    assert "daily realized loss" in card
    assert "Maximum Daily Drawdown Hard Stop" in card
    assert "Maximum Total Drawdown Stop" in card
    assert "M5 60-SMA baseline" in card


def test_review_findings_are_fixed_card_faithfully() -> None:
    source = _source()
    compact = _compact(source)
    entry = _function(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    on_tick = _function(source, "void OnTick", "void OnTimer")

    assert "Strategy_GetHhmm(QM_BrokerToUTC(TimeCurrent()))" in source
    assert "const double sl_price = m5_sma_1 - sl_buffer;" in entry
    assert "const double sl_price = m5_sma_1 + sl_buffer;" in entry
    assert "min_sl_dist" not in source
    assert "max_sl_dist" not in source
    assert "0.5 * atr_1" not in source
    assert "3.5 * atr_1" not in source

    assert "strategy_daily_loss_limit_pct=2.0" in compact
    assert "strategy_daily_dd_hard_stop_pct=2.5" in compact
    assert "strategy_total_drawdown_stop_pct=5.0" in compact
    assert "HistorySelect(day_start,now)" in compact
    assert "day_start_balance=balance-realised" in compact
    assert "g_strategy_initial_equity=AccountInfoDouble(ACCOUNT_EQUITY)" in compact
    assert "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),strategy_daily_dd_hard_stop_pct,strategy_total_drawdown_stop_pct,1.0)" in compact

    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_strategy_inputs_are_wired_and_bounded() -> None:
    source = _source()
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(
        r"^input\s+\S+\s+(strategy_[A-Za-z0-9_]+)\s*=",
        strategy_block,
        re.MULTILINE,
    )

    assert names
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    compact = _compact(source)
    assert "strategy_sma_period>=40&&strategy_sma_period<=80" in compact
    assert "strategy_swing_lookback>=5&&strategy_swing_lookback<=20" in compact
    assert "strategy_atr_period==14" in compact
    assert "if(!Strategy_InputsValid())returnINIT_PARAMETERS_INCORRECT;" in compact
    assert "for(inti=2;i<=lookback+1;++i)" in compact


def test_framework_magic_risk_mae_and_series_contracts() -> None:
    source = _source()
    compact = _compact(source)
    on_tick = _function(source, "void OnTick", "void OnTimer")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M5" in source
    assert "QM_EntryConfigure(" in source
    assert "RISK_PERCENT                 = 0.0;" in source
    assert "35003 * 10000" not in source
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)

    raw_series = re.compile(
        r"\b(?:CopyRates|CopyClose|CopyOpen|CopyHigh|CopyLow|CopyTime|CopyBuffer|"
        r"iBars|iBarShift|iOpen|iHigh|iLow|iClose|iTime|iATR|iMA)\s*\("
    )
    matching_lines = [line for line in source.splitlines() if raw_series.search(line)]
    assert len(matching_lines) == 2
    for line in matching_lines:
        assert "perf-allowed" in line, line
    assert "CopyBuffer(" not in source

    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "35003" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS


def test_backtest_sets_bind_strategy_risk_and_build_header() -> None:
    source = _source()
    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )
    set_paths = sorted(SETS.glob(f"{LABEL}_*_M5_backtest.set"))
    assert len(set_paths) == len(EXPECTED_SLOTS)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()

    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        path = SETS / f"{LABEL}_{symbol}_M5_backtest.set"
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "35003"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        for input_name in strategy_inputs:
            assert input_name in values, (path.name, input_name)
