from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "update_magic_resolver.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("update_magic_resolver_symbol_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _rows() -> list[dict]:
    # ea_id 1001 slot 0 is registered for EURUSD.DWX; ea_id 1002 slot 0 for
    # GBPUSD.DWX. This is the host-slot conflation shape from ops task
    # 18954866: two different EAs/symbols both resolving via slot 0.
    return [
        {"ea_id": 1001, "slot": 0, "symbol": "EURUSD.DWX", "magic": 10010000},
        {"ea_id": 1002, "slot": 0, "symbol": "GBPUSD.DWX", "magic": 10020000},
    ]


def test_generated_resolver_declares_symbol_lookup_and_fail_closed_branch() -> None:
    module = _load_module()
    rendered = module.render_mqh(_rows())

    assert "string QM_MagicRegisteredSymbol(const int ea_id, const int symbol_slot)" in rendered
    assert "EA_MAGIC_RESOLUTION_FAILED" in rendered
    # The fail-closed branch must compare against expected_symbol before ever
    # reaching the open-position collision check, so a foreign-symbol slot
    # never silently returns a live-tradable magic.
    assert rendered.index("registered_symbol != expected_symbol") < rendered.index(
        "QM_MagicCollisionWithForeignOpenPositions(magic, expected_symbol)"
    )


def _mql_registered_symbol(rows: list[dict], ea_id: int, slot: int) -> str:
    """Pure-Python mirror of the generated QM_MagicRegisteredSymbol loop."""
    for row in rows:
        if row["ea_id"] == ea_id and row["slot"] == slot:
            return row["symbol"]
    return ""


def _mql_magic_checked_would_reject_on_symbol_mismatch(
    rows: list[dict], ea_id: int, slot: int, expected_symbol: str
) -> bool:
    """Mirrors the new QM_MagicChecked branch: reject iff the slot is
    registered for a DIFFERENT symbol than expected_symbol. An unregistered
    slot (registered_symbol == "") is left to the existing
    QM_MagicRegistered() gate, not this check."""
    registered_symbol = _mql_registered_symbol(rows, ea_id, slot)
    if expected_symbol == "" or registered_symbol == "":
        return False
    return registered_symbol != expected_symbol


def test_reference_reject_on_slot_registered_for_a_different_symbol() -> None:
    rows = _rows()
    # ea_id 1001 slot 0 is EURUSD.DWX's slot; calling with expected_symbol
    # GBPUSD.DWX (the host-slot conflation scenario) must reject.
    assert _mql_magic_checked_would_reject_on_symbol_mismatch(rows, 1001, 0, "GBPUSD.DWX") is True


def test_reference_accepts_matching_symbol() -> None:
    rows = _rows()
    assert _mql_magic_checked_would_reject_on_symbol_mismatch(rows, 1001, 0, "EURUSD.DWX") is False


def test_reference_unregistered_slot_is_not_this_checks_concern() -> None:
    rows = _rows()
    # slot 7 is not registered for ea_id 1001 at all; QM_MagicRegistered()
    # already fails this before the new check would ever run, so the new
    # check itself must not misreport it as a symbol mismatch.
    assert _mql_magic_checked_would_reject_on_symbol_mismatch(rows, 1001, 7, "EURUSD.DWX") is False


def test_reference_empty_expected_symbol_skips_the_check() -> None:
    rows = _rows()
    # Legacy callers that never pass expected_symbol get no new behavior
    # change (matches the existing QM_MagicCollisionWithForeignOpenPositions
    # default-arg contract).
    assert _mql_magic_checked_would_reject_on_symbol_mismatch(rows, 1001, 0, "") is False
