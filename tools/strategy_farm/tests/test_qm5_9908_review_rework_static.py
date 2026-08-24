from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
LABEL = "QM5_9908_bandy-psar-flip-trend"
EA_DIR = REPO_ROOT / "framework" / "EAs" / LABEL
SOURCE_PATH = EA_DIR / f"{LABEL}.mq5"
IDENTITY_PATH = EA_DIR / "build_identity.json"
APPROVED_SYMBOL_SLOTS = {
    "NDX.DWX": 1,
    "SP500.DWX": 2,
    "WS30.DWX": 4,
    "XAUUSD.DWX": 5,
    "EURUSD.DWX": 6,
    "GBPUSD.DWX": 7,
    "USDJPY.DWX": 8,
    "USDCHF.DWX": 9,
    "AUDUSD.DWX": 10,
    "USDCAD.DWX": 11,
    "NZDUSD.DWX": 12,
    "XTIUSD.DWX": 13,
}


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_card_mechanism_uses_d1_psar_risk_and_restart_safe_trail() -> None:
    source = _source()
    entry = source[source.index("bool Strategy_EntrySignal(") : source.index("void Strategy_ManageOpenPosition()")]
    management = source[source.index("void Strategy_ManageOpenPosition()") : source.index("bool Strategy_ExitSignal()")]

    assert "QM_FrameworkDeclareExecutionContract(" in source
    assert "PERIOD_D1," in source
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in source
    assert "QM_IsNewBar()" not in source
    assert "req.sl = normalized_psar;" in entry
    assert "QM_StopATR(_Symbol, QM_BUY" in entry
    assert "QM_StopATR(_Symbol, QM_SELL" in entry
    assert "req.sl = QM_StopATR" not in entry
    assert "Strategy_EntryReason(true, catastrophe)" in entry
    assert "Strategy_EntryReason(false, catastrophe)" in entry
    assert "PositionGetString(POSITION_COMMENT)" in management
    assert "QM_TM_MoveSL(ticket, target_sl, \"BANDY_PSAR_TRAIL\")" in management
    assert "QM_TM_HeldPeriods(_Symbol, PERIOD_D1, open_time)" in management
    assert "QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP)" in management
    assert "QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY)" in management


def test_management_is_reachable_before_all_entry_only_guards() -> None:
    source = _source()
    on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]

    manage_at = on_tick.index("Strategy_ManageOpenPosition();")
    for guard in (
        "QM_KillSwitchCheck()",
        "Strategy_NewsFilterHook(broker_now)",
        "QM_FrameworkHandleFridayClose()",
        "QM_NewsAllowsTrade2(",
        "QM_IsNewBar(_Symbol, PERIOD_D1)",
        "Strategy_NoTradeFilter()",
    ):
        assert manage_at < on_tick.index(guard), guard

    assert "strategy_spread_max_atr" not in source
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick


def test_series_reads_are_bounded_and_framework_conformant() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "ArrayResize(closed_bars, 2)" in source
    assert "ArraySize(closed_bars) < 2" in source
    assert "CopyRates(_Symbol, PERIOD_D1, 1, 2, closed_bars)" in source
    raw_series_lines = [
        line
        for line in source.splitlines()
        if re.search(r"\b(?:Bars|CopyRates|iOpen|iHigh|iLow|iClose|iTime|iBarShift)\s*\(", line)
    ]
    assert raw_series_lines
    assert all("perf-allowed" in line for line in raw_series_lines)
    assert "CopyBuffer(" not in source
    assert not re.search(r"(?i)\b(tensorflow|torch|sklearn|keras|onnx)\b", source)
    assert "OrderSend(" not in source
    assert "PositionModify(" not in source


def test_every_strategy_input_is_wired_and_sealed_in_approved_sets() -> None:
    source = _source()
    strategy_inputs = re.findall(r"(?m)^input\s+\S+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert strategy_inputs
    assert len(strategy_inputs) == len(set(strategy_inputs))
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == len(APPROVED_SYMBOL_SLOTS)
    observed: dict[str, int] = {}
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8")
        symbol_match = re.search(r"(?m)^; symbol:\s*(\S+)$", text)
        slot_match = re.search(r"(?m)^qm_magic_slot_offset=(\d+)$", text)
        assert symbol_match and slot_match
        symbol = symbol_match.group(1)
        observed[symbol] = int(slot_match.group(1))
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert f"; build_hash:   {_sha256(SOURCE_PATH)}" in text
        for name in strategy_inputs:
            assert re.search(rf"(?m)^{re.escape(name)}=", text), f"{setfile.name}: {name}"
        assert "strategy_spread_max_atr" not in text

    assert observed == APPROVED_SYMBOL_SLOTS
    assert "GDAXI.DWX" not in observed
    assert "UK100.DWX" not in observed


def test_oil_registry_row_and_generated_resolver_are_exact() -> None:
    registry = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    with registry.open(encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "9908"]

    oil_rows = [row for row in rows if row["symbol"] == "XTIUSD.DWX"]
    assert len(oil_rows) == 1
    assert oil_rows[0]["symbol_slot"] == "13"
    assert oil_rows[0]["magic"] == "99080013"
    assert oil_rows[0]["status"] == "active"

    resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
        encoding="utf-8"
    )
    assert '"XTIUSD.DWX"' in resolver
    assert "99080013" in resolver


def test_build_identity_is_schema_complete_and_hash_bound() -> None:
    identity = json.loads(IDENTITY_PATH.read_text(encoding="utf-8"))
    binary = EA_DIR / f"{LABEL}.ex5"
    required = {
        "task_id",
        "ea_id",
        "ea_dir",
        "mq5_path",
        "ex5_path",
        "magic_base",
        "symbols_registered",
        "setfiles_generated",
        "spec_md_path",
        "build_check_passed",
        "compile_succeeded",
        "smoke_result",
        "smoke_report_path",
    }

    assert required <= identity.keys()
    assert identity["task_id"] == "ce7ef250-d7c0-418a-aa51-fff4f7a8136e"
    assert identity["rework_task_id"] == "9bd88385-fdac-4b6d-9437-0cdc14fb3f25"
    assert identity["ea_id"] == "QM5_9908"
    assert identity["magic_base"] == 99080000
    assert identity["symbols_registered"] == list(APPROVED_SYMBOL_SLOTS)
    assert identity["mq5_sha256"] == _sha256(SOURCE_PATH)
    assert identity["ex5_sha256"] == _sha256(binary)
    assert identity["build_check_passed"] is False
    assert identity["build_check_component_checks_passed"] is True
    assert identity["build_check_blocked_reason"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["compile_succeeded"] is True
    assert identity["compile_errors"] == 0
    assert identity["compile_warnings"] == 0
    assert identity["smoke_result"] == "framework_error"
    assert identity["smoke_report_path"] is None
    assert "worker-bound work item" in identity["smoke_blocked_reason"]
