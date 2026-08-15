"""Single-symbol index-tick commit reservation class (2026-08-15).

Dense index tick years privately commit ~46GB (metatester64 on SP500 Q02);
the 8GB ordinary class under-reserved them by 5-6x and let a second heavy
job stack into commit exhaustion.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker  # noqa: E402


def _classify(symbol: str, multisymbol: bool = False) -> str:
    return terminal_worker._multisymbol_commit_class(
        {"symbol": symbol, "ea_id": "QM5_9999"}, {}, multisymbol
    )


def test_index_symbols_classify_as_index_tick():
    for symbol in ("SP500.DWX", "GDAXI.DWX", "WS30.DWX", "NDX.DWX", "UK100.DWX"):
        assert _classify(symbol) == terminal_worker.COMMIT_CLASS_SINGLE_INDEX_TICK, symbol


def test_fx_and_metal_singles_stay_ordinary():
    for symbol in ("EURUSD.DWX", "AUDNZD.DWX", "XAUUSD.DWX", "XTIUSD.DWX"):
        assert _classify(symbol) == terminal_worker.MULTISYMBOL_COMMIT_CLASS_ORDINARY, symbol


def test_index_tick_reservation_serializes_against_commit_limit():
    gb = terminal_worker._commit_reservation_gb(
        terminal_worker.COMMIT_CLASS_SINGLE_INDEX_TICK
    )
    assert gb == terminal_worker.SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB == 44.0
    # Two reservations plus the effective-headroom floor must exceed the
    # box's 122.6GB commit limit so index monsters can never stack.
    assert 2 * gb + terminal_worker.COMMIT_MIN_FREE_GB > 105.0


def test_multisymbol_items_keep_their_existing_classes():
    # An index HOST on a multisymbol item must not be downgraded to the
    # single-index class; the multisymbol taxonomy stays authoritative.
    assert (
        _classify("GDAXI.DWX", multisymbol=True)
        == terminal_worker.MULTISYMBOL_COMMIT_CLASS_HEAVY
    )
