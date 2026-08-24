from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_9468_connors-rsi4-3day-d1"
SOURCE_PATH = EA_DIR / "QM5_9468_connors-rsi4-3day-d1.mq5"
SPEC_PATH = EA_DIR / "SPEC.md"
IDENTITY_PATH = EA_DIR / "build_identity.json"

APPROVED_SETFILES = {
    "QM5_9468_connors-rsi4-3day-d1_NDX.DWX_D1_backtest.set": 1,
    "QM5_9468_connors-rsi4-3day-d1_SP500.DWX_D1_backtest.set": 2,
    "QM5_9468_connors-rsi4-3day-d1_WS30.DWX_D1_backtest.set": 4,
}

STRATEGY_INPUTS = (
    "strategy_rsi_period",
    "strategy_rsi_entry_thresh",
    "strategy_sma_period",
    "strategy_hold_bars",
    "strategy_atr_period",
    "strategy_sl_atr_mult",
    "strategy_spread_max_atr",
    "strategy_cooldown_bars",
    "strategy_warmup_bars",
)


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def test_d1_execution_and_framework_contracts_are_explicit() -> None:
    source = _source()
    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1," in source
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req, out_ticket);" in source


def test_management_precedes_every_entry_only_filter() -> None:
    source = _source()
    on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]
    management = on_tick.index("Strategy_ManageOpenPosition();")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol, PERIOD_D1)")
    strategy_news = on_tick.index("Strategy_NewsFilterHook(broker_now)")
    news = on_tick.index("QM_NewsAllowsTrade")
    spread_and_warmup = on_tick.index("Strategy_NoTradeFilter()")
    entry = on_tick.index("Strategy_EntrySignal(req)")
    assert on_tick.index("QM_FrameworkHandleFridayClose()") < management
    assert management < new_bar < strategy_news < news < spread_and_warmup < entry


def test_cooldown_is_restart_safe_and_covers_every_owned_exit() -> None:
    source = _source()
    assert "HistorySelect(0, TimeCurrent())" in source
    assert "Strategy_RestoreLastExit()" in source
    assert "if(!Strategy_RestoreLastExit())\n      return INIT_FAILED;" in source
    assert "Strategy_RecordExitTransaction(t);" in source
    assert "DEAL_ENTRY_OUT_BY" in source
    assert "DEAL_ENTRY_INOUT" in source
    assert "g_exit_history_ready = false;" in source
    assert "QM_TM_HeldPeriods(_Symbol, PERIOD_D1, g_last_exit_time)" in source
    assert "QM_TM_HeldPeriods(_Symbol, PERIOD_D1, open_time)" in source


def test_every_strategy_input_is_declared_validated_and_used() -> None:
    source = _source()
    for name in STRATEGY_INPUTS:
        assert re.search(rf"\binput\s+(?:int|double)\s+{name}\b", source)
        assert source.count(name) >= 3, f"{name} lacks declaration/validation/mechanism use-sites"


def test_no_raw_indicator_or_series_calls_escape_the_framework() -> None:
    source = _source()
    forbidden = re.compile(
        r"\b(?:iATR|iMA|iRSI|iMACD|iADX|iBands|CopyBuffer|"
        r"iOpen|iHigh|iLow|iClose|iTime|iVolume|iBars|iBarShift|Bars)\s*\("
    )
    assert forbidden.findall(source) == []
    assert "QM_ReadBar(" in source
    assert "QM_RSI(" in source
    assert "QM_SMA(" in source
    assert "QM_ATR(" in source


def test_package_and_spec_match_the_approved_index_port() -> None:
    actual = {path.name for path in (EA_DIR / "sets").glob("*.set")}
    assert actual == set(APPROVED_SETFILES)
    for filename, slot in APPROVED_SETFILES.items():
        text = (EA_DIR / "sets" / filename).read_text(encoding="utf-8")
        assert f"qm_magic_slot_offset={slot}" in text
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text

    spec = SPEC_PATH.read_text(encoding="utf-8")
    assert "| Base timeframe | `D1` |" in spec
    assert "`QM_IsNewBar(_Symbol, PERIOD_D1)`" in spec
    for name in STRATEGY_INPUTS:
        assert f"`{name}`" in spec
    for forbidden_symbol in ("GDAXI.DWX", "UK100.DWX", "XAUUSD.DWX", "EURUSD.DWX"):
        assert forbidden_symbol not in spec


def test_build_identity_lists_only_files_that_exist() -> None:
    identity = json.loads(IDENTITY_PATH.read_text(encoding="utf-8"))
    listed = {Path(value.replace("\\", "/")).name for value in identity["setfiles_generated"]}
    assert listed == set(APPROVED_SETFILES)
    assert all((EA_DIR / "sets" / filename).is_file() for filename in listed)
