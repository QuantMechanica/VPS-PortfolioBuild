from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
QM = ROOT / "framework" / "include" / "QM"
ENTRY = (QM / "QM_Entry.mqh").read_text(encoding="utf-8")
BASKET = (QM / "QM_BasketOrder.mqh").read_text(encoding="utf-8")
COMMON = (QM / "QM_Common.mqh").read_text(encoding="utf-8")
RESOLVER = (QM / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
SHARED_REBUILD = (
    ROOT / "framework" / "EAs" / "_mql5_codebase_rebuild_common.mqh"
).read_text(encoding="utf-8")
QM5_10571 = (
    ROOT
    / "framework"
    / "EAs"
    / "QM5_10571_mql5-pchan-stop"
    / "QM5_10571_mql5-pchan-stop.mq5"
).read_text(encoding="utf-8")


def _body(source: str, function: str) -> str:
    match = re.search(rf"\b{function}\s*\([^)]*\)\s*\{{", source, re.S)
    assert match, function
    start = match.end() - 1
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(function)


def _compact(source: str) -> str:
    return "".join(source.split())


def test_framework_binds_absolute_host_magic_into_entry_context() -> None:
    init = _body(COMMON, "QM_FrameworkInitCoreAfterRuntimeStateArmed")
    assert "g_qm_fw_magic = QM_MagicChecked(ea_id, magic_slot_offset, _Symbol)" in init
    assert (
        "QM_EntryConfigure(ea_id, news_mode, 20, stress_reject_probability,"
        in init
    )
    assert "news_temporal, news_compliance, g_qm_fw_magic);" in init
    assert init.index("g_qm_fw_magic = QM_MagicChecked") < init.index(
        "QM_EntryConfigure("
    )


def test_entry_slot_zero_uses_configured_host_magic_not_absolute_zero() -> None:
    resolve = _compact(_body(ENTRY, "QM_EntryResolveRequestMagic"))
    assert "if(explicit_magic!=0)returnexplicit_magic;" in resolve
    assert "if(req.symbol_slot==0)" in resolve
    assert (
        "returnQM_EntryConfiguredHostMagic(g_qm_entry_ea_id,_Symbol);" in resolve
    )
    assert "returnQM_MagicChecked(g_qm_entry_ea_id,req.symbol_slot,_Symbol);" in resolve
    assert resolve.index("if(req.symbol_slot==0)") < resolve.index(
        "returnQM_MagicChecked("
    )


def test_basket_only_treats_actual_framework_host_as_relative_slot_zero() -> None:
    basket = _compact(_body(BASKET, "QM_BasketOpenPosition"))
    assert (
        "constboolhost_slot_request=(req.symbol_slot==0&&"
        "ea_id==g_qm_entry_ea_id&&req.symbol==_Symbol);"
    ) in basket
    assert "?QM_EntryConfiguredHostMagic(ea_id,req.symbol)" in basket
    assert ":QM_MagicChecked(ea_id,req.symbol_slot,req.symbol);" in basket


def test_magic_resolver_rejects_registered_slot_for_foreign_symbol() -> None:
    checked = _compact(_body(RESOLVER, "QM_MagicChecked"))
    assert "QM_MagicRegisteredSymbol(ea_id,symbol_slot)" in checked
    assert "registered_symbol!=expected_symbol" in checked
    mismatch = checked.index("registered_symbol!=expected_symbol")
    collision = checked.index("QM_MagicCollisionWithForeignOpenPositions")
    assert mismatch < checked.index("return-1;", mismatch) < collision
    assert "EA_MAGIC_RESOLUTION_FAILED" in checked


def test_qm5_10571_is_wired_by_shared_helper_not_v3_contract() -> None:
    # This is the false-positive that exposed the old detector's blind spot:
    # the main .mq5 has no assignment, while its reachable EA-local include
    # writes the actual per-symbol slot before submission.
    assert "_mql5_codebase_rebuild_common.mqh" in QM5_10571
    assert "QM_FrameworkInitV3" not in QM5_10571
    assert "req.symbol_slot = Strategy_SymbolSlot();" in SHARED_REBUILD
    assert "return qm_magic_slot_offset;" in SHARED_REBUILD

