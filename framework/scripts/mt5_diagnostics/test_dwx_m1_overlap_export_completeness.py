"""Unit tests for the 2026-09-15 export-fix ticket's completeness classification:
expected-minutes floor (P1 manifest minus session-closure allowance), the
per-chunk journal, and the additive SHORT_READ gate on the export receipt.

Run: python -m pytest -q framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py
"""

from __future__ import annotations

import csv
import datetime as dt
from pathlib import Path

import pytest

from framework.scripts.mt5_diagnostics import dwx_m1_overlap_export as export
from tools.dukascopy import common as dukascopy_common
from tools.strategy_farm import dwx_m1_overlap_export_work_item as work_item


UTC = dt.timezone.utc


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _raw_bar(instant: dt.datetime, price: float = 1.1) -> dict[str, object]:
    return {
        "time": dukascopy_common.broker_epoch_seconds_for_utc(instant),
        "open": price,
        "high": price + 0.0002,
        "low": price - 0.0002,
        "close": price + 0.0001,
        "tickvol": 42,
    }


def _price_scale_fixture(path: Path) -> None:
    _write_csv(
        path,
        dukascopy_common.NONFX_METADATA_HEADER,
        [
            {"symbol": symbol, "digits": 2, "point": "0.01", "price_scale": 100}
            for symbol in sorted(dukascopy_common.NON_FX_INSTRUMENTS)
        ],
    )


def test_instrument_class_splits_index_commodity_from_fx() -> None:
    assert export.instrument_class("GDAXI.DWX") == "index_commodity"
    assert export.instrument_class("XAUUSD.DWX") == "index_commodity"
    assert export.instrument_class("EURUSD.DWX") == "fx"
    assert set(export.INDEX_COMMODITY_SYMBOLS) <= set(dukascopy_common.CANONICAL_SYMBOLS)


def test_load_expected_minutes_matches_p1_manifest_with_documented_allowance() -> None:
    """Source is the P1 manifest's downloaded_hours (state which, per the
    ticket's acceptance criterion), not a live Dukascopy-side recount."""

    expected = export.load_expected_minutes()
    assert set(expected) == set(dukascopy_common.CANONICAL_SYMBOLS)

    import json

    payload = json.loads(
        export.P1_WINDOW_MANIFEST_RECEIPT.read_text(encoding="utf-8-sig")
    )
    by_symbol = {str(row["symbol"]): row for row in payload["symbols"]}

    fx_row = by_symbol["EURUSD.DWX"]
    assert export.instrument_class("EURUSD.DWX") == "fx"
    expected_fx_floor = int(
        int(fx_row["downloaded_hours"]) * 60 * (1.0 - export.SESSION_CLOSURE_ALLOWANCE_FRACTION["fx"])
    )
    assert expected["EURUSD.DWX"] == expected_fx_floor

    index_row = by_symbol["GDAXI.DWX"]
    expected_index_floor = int(
        int(index_row["downloaded_hours"])
        * 60
        * (1.0 - export.SESSION_CLOSURE_ALLOWANCE_FRACTION["index_commodity"])
    )
    assert expected["GDAXI.DWX"] == expected_index_floor
    # The index/commodity allowance must be strictly larger than the FX one
    # (documented session-hours difference), not merely a different number.
    assert (
        export.SESSION_CLOSURE_ALLOWANCE_FRACTION["index_commodity"]
        > export.SESSION_CLOSURE_ALLOWANCE_FRACTION["fx"]
    )


def test_classify_completeness_is_a_hard_floor_not_a_rounded_threshold() -> None:
    expected_minutes = {"EURUSD.DWX": 100}
    at_floor = export.classify_completeness("EURUSD.DWX", 100, expected_minutes)
    assert at_floor["status"] == "COMPLETE"
    assert at_floor["expected_minutes"] == 100
    assert at_floor["completeness_ratio"] == pytest.approx(1.0)

    one_below = export.classify_completeness("EURUSD.DWX", 99, expected_minutes)
    assert one_below["status"] == "SHORT_READ"
    assert one_below["completeness_ratio"] == pytest.approx(0.99)


def test_parse_chunk_journal_and_short_chunks_extraction(tmp_path: Path) -> None:
    path = tmp_path / "EURUSD.DWX_M1_chunks.csv"
    _write_csv(
        path,
        export.CHUNK_JOURNAL_HEADER,
        [
            {
                "symbol": "EURUSD.DWX", "chunk_start_epoch": 1000, "chunk_end_epoch": 2000,
                "phase": "sync", "attempt": 1, "copied": 500, "error_code": 0, "status": "ATTEMPT",
            },
            {
                "symbol": "EURUSD.DWX", "chunk_start_epoch": 1000, "chunk_end_epoch": 2000,
                "phase": "final", "attempt": 0, "copied": 500, "error_code": 0, "status": "OK",
            },
            {
                "symbol": "EURUSD.DWX", "chunk_start_epoch": 2000, "chunk_end_epoch": 3000,
                "phase": "sync", "attempt": 1, "copied": 0, "error_code": 0, "status": "ATTEMPT",
            },
            {
                "symbol": "EURUSD.DWX", "chunk_start_epoch": 2000, "chunk_end_epoch": 3000,
                "phase": "zero_retry", "attempt": 3, "copied": 0, "error_code": 0, "status": "ATTEMPT",
            },
            {
                "symbol": "EURUSD.DWX", "chunk_start_epoch": 2000, "chunk_end_epoch": 3000,
                "phase": "final", "attempt": 0, "copied": 0, "error_code": 0, "status": "ZERO_TICK_CHUNK",
            },
        ],
    )
    rows = export.parse_chunk_journal(path)
    assert len(rows) == 5
    assert rows[0]["copied"] == 500 and rows[0]["chunk_start_epoch"] == 1000

    short_chunks = export.short_chunks_from_journal(rows)
    assert short_chunks == [{"chunk_start_epoch": 2000, "chunk_end_epoch": 3000}]


def test_canonicalize_export_set_flags_short_read_symbol_and_surfaces_chunk_journal(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stamp = "20260915_120000"
    export_root = tmp_path / "exports"
    output_dir = export_root / stamp
    raw_dir = tmp_path / "terminal_raw"
    output_dir.mkdir(parents=True)
    raw_dir.mkdir()
    price_scale = tmp_path / "price_scale.csv"
    _price_scale_fixture(price_scale)
    monkeypatch.setattr(work_item, "EXPORT_ROOT", export_root)
    monkeypatch.setattr(work_item, "PRICE_SCALE", price_scale)

    symbols = sorted(dukascopy_common.CANONICAL_SYMBOLS)
    short_symbol = "AUDCAD.DWX"
    assert short_symbol in symbols
    # Every symbol gets a floor of 3 minutes so the fixture can stay tiny;
    # the short symbol gets exactly 1 row, one below its floor.
    monkeypatch.setattr(
        export, "load_expected_minutes", lambda: {symbol: 3 for symbol in symbols}
    )

    instant = dt.datetime(2026, 1, 5, 10, 0, tzinfo=UTC)
    for index, symbol in enumerate(symbols):
        row_count = 1 if symbol == short_symbol else 3
        rows = [
            _raw_bar(instant + dt.timedelta(minutes=minute), 1.0 + index)
            for minute in range(row_count)
        ]
        _write_csv(raw_dir / f"{symbol}_M1.csv", export.RAW_HEADER, rows)

    _write_csv(
        raw_dir / f"{short_symbol}_M1_chunks.csv",
        export.CHUNK_JOURNAL_HEADER,
        [
            {
                "symbol": short_symbol, "chunk_start_epoch": 1000, "chunk_end_epoch": 2000,
                "phase": "final", "attempt": 0, "copied": 0, "error_code": 0,
                "status": "ZERO_TICK_CHUNK",
            },
        ],
    )

    binding = export.canonicalize_export_set(raw_dir, output_dir)
    assert binding["canonicalization_status"] == "COMPLETE"  # parse succeeded for all 37
    assert binding["short_read_symbols"] == [short_symbol]
    assert binding["short_read_symbol_count"] == 1

    manifest_files = {row["symbol"]: row for row in
                       __import__("json").loads(Path(binding["path"]).read_text(encoding="utf-8"))["files"]}
    short_row = manifest_files[short_symbol]
    assert short_row["status"] == "SHORT_READ"
    assert short_row["expected_minutes"] == 3
    assert short_row["short_chunks"] == [
        {"chunk_start_epoch": 1000, "chunk_end_epoch": 2000}
    ]

    complete_symbol = next(s for s in symbols if s != short_symbol)
    complete_row = manifest_files[complete_symbol]
    assert complete_row["status"] == "COMPLETE"
    assert complete_row["short_chunks"] == []

    # SHORT_READ must never be hidden by a COMPLETE canonicalization_status --
    # it is a separate, additive gate (see run()'s overall status check).
    assert binding["canonicalization_status"] == "COMPLETE"
    assert binding["short_read_symbol_count"] > 0
