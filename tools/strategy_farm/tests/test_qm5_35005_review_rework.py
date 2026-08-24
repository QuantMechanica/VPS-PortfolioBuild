from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_35005_sma-crossover-pullback-system"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
EX5_PATH = EA_DIR / f"{EA_LABEL}.ex5"
SETS_DIR = EA_DIR / "sets"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_ID_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
MAGIC_RESOLVER = REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
STALE_EX5_SHA256 = "28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59"


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def compact(text: str) -> str:
    return re.sub(r"\s+", "", text)


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing {name}"
    opening = source.index("{", match.start())
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated {name}")


def test_card_mechanism_and_entry_only_filters_are_preserved() -> None:
    source = source_text()
    entry = compact(function_body(source, "Strategy_EntrySignal"))
    no_trade = compact(function_body(source, "Strategy_NoTradeFilter"))
    daily_halt = compact(function_body(source, "StrategyDailyEntryHalt"))
    rollover = compact(function_body(source, "StrategyInRolloverWindow"))
    on_tick = compact(function_body(source, "OnTick"))

    assert "sma_fast>sma_slow" in entry
    assert "stoch_k_2<=strategy_stoch_oversold" in entry
    assert "stoch_k_1>stoch_d_1" in entry
    assert "sma_fast<sma_slow" in entry
    assert "stoch_k_2>=strategy_stoch_overbought" in entry
    assert "stoch_k_1<stoch_d_1" in entry
    assert "QM_StopFixedPips(_Symbol,QM_BUY,exec_price,strategy_sl_pips)" in entry
    assert "QM_TakeFixedPips(_Symbol,QM_SELL,exec_price,strategy_tp_pips)" in entry

    assert "QM_BrokerToUTC(broker_now)" in no_trade
    assert "hhmm>=2355||hhmm<=5" in rollover
    assert "QM_ChartUITodayPnL(0,closed_trades)" in daily_halt
    assert "ACCOUNT_BALANCE" in daily_halt
    assert "realized_pnl<=-loss_limit" in daily_halt

    management = on_tick.index("Strategy_ManageOpenPosition();")
    news = on_tick.index("if(Strategy_NewsFilterHook(broker_now))return;")
    entry_filter = on_tick.index("if(Strategy_NoTradeFilter())return;")
    entry_call = on_tick.index("if(Strategy_EntrySignal(req))")
    assert management < news < entry_filter < entry_call


def test_framework_wiring_uses_pooled_data_and_all_strategy_inputs() -> None:
    source = source_text()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset" in source
    assert "QM_KillSwitchInit(qm_ea_id" in source
    assert "QM_FrameworkMagic()" in source
    for helper in ("QM_SMA(", "QM_Stoch_K(", "QM_Stoch_D(", "QM_ATR(", "QM_IsNewBar("):
        assert helper in source
    for forbidden in ("iClose(", "iMA(", "iATR(", "iStochastic(", "CopyBuffer("):
        assert forbidden not in source
    for forbidden in ("tensorflow", "torch", "sklearn", "keras", "onnx"):
        assert forbidden not in source.lower()

    strategy_inputs = re.findall(r"(?m)^input\s+\w+\s+(strategy_\w+)\s*=", source)
    assert len(strategy_inputs) == 17
    assert len(set(strategy_inputs)) == len(strategy_inputs)
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name


def test_registry_setfiles_and_fresh_binary_identity() -> None:
    with EA_ID_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        ea_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "35005"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "sma-crossover-pullback-system"
    assert ea_rows[0]["status"] == "active"

    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        magic_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "35005"]
    expected = {
        ("0", "EURUSD.DWX", "350050000"),
        ("1", "GBPUSD.DWX", "350050001"),
        ("2", "EURJPY.DWX", "350050002"),
    }
    assert {(row["symbol_slot"], row["symbol"], row["magic"]) for row in magic_rows} == expected
    assert all(row["status"] == "active" for row in magic_rows)

    resolver = MAGIC_RESOLVER.read_text(encoding="utf-8-sig")
    for magic in ("350050000", "350050001", "350050002"):
        assert magic in resolver

    setfiles = sorted(SETS_DIR.glob("*_backtest.set"))
    assert len(setfiles) == 3
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8-sig")
        assert "; environment:  backtest" in text
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text

    assert EX5_PATH.is_file()
    ex5_sha256 = hashlib.sha256(EX5_PATH.read_bytes()).hexdigest()
    assert ex5_sha256 != STALE_EX5_SHA256
