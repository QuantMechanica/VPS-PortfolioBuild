from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_DIR = REPO_ROOT / "framework" / "EAs" / "QM5_9467_connors-crsi-pullback-d1"
SOURCE = EA_DIR / "QM5_9467_connors-crsi-pullback-d1.mq5"
APPROVED_SYMBOLS = {"SP500.DWX", "NDX.DWX", "WS30.DWX"}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    start = source.index(name)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def test_package_is_restricted_to_approved_index_port() -> None:
    symbols = {
        path.name.removeprefix("QM5_9467_connors-crsi-pullback-d1_").removesuffix(
            "_D1_backtest.set"
        )
        for path in (EA_DIR / "sets").glob("*.set")
    }
    assert symbols == APPROVED_SYMBOLS

    source = _source()
    approved_body = _function_body(source, "bool Strategy_IsApprovedSymbol()")
    assert APPROVED_SYMBOLS == set(re.findall(r'"([A-Z0-9]+\.DWX)"', approved_body))
    approved_slots = _function_body(source, "int Strategy_ApprovedMagicSlot()")
    assert all(
        f'if(_Symbol == "{symbol}")\n      return {slot};' in approved_slots
        for symbol, slot in {"NDX.DWX": 1, "SP500.DWX": 2, "WS30.DWX": 4}.items()
    )
    on_init = _function_body(source, "int OnInit()")
    assert "qm_magic_slot_offset != Strategy_ApprovedMagicSlot()" in on_init
    assert "INIT_PARAMETERS_INCORRECT" in on_init

    identity = json.loads((EA_DIR / "build_identity.json").read_text(encoding="utf-8"))
    assert identity["setfiles_generated"] == [
        f"framework/EAs/{EA_DIR.name}/sets/{path.name}"
        for path in sorted((EA_DIR / "sets").glob("*.set"))
    ]
    assert identity["mq5_sha256"] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert identity["build_check_passed"] is False
    assert identity["compile_blocked_reason"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["ex5_status"] == "STALE_PRE_REWORK_BINARY_NOT_RESUBMITTED"


def test_d1_snapshot_expiry_and_exit_order_are_fail_closed() -> None:
    source = _source()
    on_tick = _function_body(source, "void OnTick()")
    ordered_markers = [
        "QM_IsNewBar(_Symbol, STRATEGY_TIMEFRAME)",
        "Strategy_ReconcilePendingAtD1Boundary()",
        "Strategy_RefreshClosedD1Snapshot()",
        "Strategy_ManageOpenPosition()",
        "Strategy_ExitSignal()",
        "QM_NewsAllowsTrade2",
        "Strategy_NoTradeFilter()",
        "Strategy_EntrySignal(req)",
    ]
    positions = [on_tick.index(marker) for marker in ordered_markers]
    assert positions == sorted(positions)

    assert source.count("Strategy_ComputeCRSI(1)") == 1
    assert "Strategy_ComputeCRSI" not in _function_body(source, "bool Strategy_ExitSignal()")
    assert "expiration_seconds = 86400" not in source
    assert "req.expiration_seconds = 0" in source
    assert "QM_TM_RemovePendingOrder" in _function_body(
        source, "bool Strategy_ReconcilePendingAtD1Boundary()"
    )


def test_fill_relative_stop_and_execution_contract_are_wired() -> None:
    source = _source()
    transaction = _function_body(source, "void OnTradeTransaction(")
    ensure_stop = _function_body(source, "bool Strategy_EnsureFillRelativeStop(")
    on_init = _function_body(source, "int OnInit()")

    assert "POSITION_PRICE_OPEN" in ensure_stop
    assert "fill_price - stop_distance" in ensure_stop
    assert "QM_TM_SendSLTPModify" in ensure_stop
    assert "Strategy_EnsureFillRelativeStop(trans.position)" in transaction
    assert "QM_TM_ClosePosition(trans.position, QM_EXIT_KILLSWITCH)" in transaction
    assert "QM_FrameworkOnTradeTransaction" in transaction
    assert "QM_FrameworkDeclareExecutionContract(STRATEGY_TIMEFRAME" in on_init
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in on_init
    assert "QM_IsNewBar(_Symbol, STRATEGY_TIMEFRAME)" in source


def test_every_declared_input_has_a_use_site_and_series_reads_are_bounded() -> None:
    source = _source()
    input_names = re.findall(
        r"^input\s+(?:\w+\s+)+(\w+)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert input_names
    assert not [name for name in input_names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]

    raw_series = re.compile(r"\b(?:CopyRates|CopyBuffer|iBars|iTime|iBarShift|iOpen|iHigh|iLow|iClose|iVolume)\s*\(")
    offending = [
        f"{line_number}: {line.strip()}"
        for line_number, line in enumerate(source.splitlines(), start=1)
        if raw_series.search(line) and "perf-allowed:" not in line
    ]
    assert offending == []

    for buffer_name in ("rates", "closes", "streaks", "setup_rates"):
        assert f"ArraySize({buffer_name})" in source
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)
