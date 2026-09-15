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

    short_chunks = export.short_chunks_from_journal("EURUSD.DWX", rows)
    assert short_chunks == [{"chunk_start_epoch": 2000, "chunk_end_epoch": 3000}]


def test_chunk_expected_minutes_matches_weekday_seconds_and_allowance() -> None:
    """A full Mon-Fri weekday chunk (no weekend inside) floors at
    (5 days * 1440 min) * (1 - allowance); the index/commodity allowance
    stays the strictly larger one, matching the whole-window floor."""

    # Chunk epochs are broker epochs treated directly as UTC-day boundaries
    # by _weekday_seconds_in_range (the same coarse proxy
    # reconcile_overlap.longest_weekday_gap uses) -- a raw UTC timestamp, not
    # a broker_epoch_seconds_for_utc conversion.
    monday = int(dt.datetime(2026, 1, 5, tzinfo=UTC).timestamp())  # Monday 00:00 UTC
    saturday = monday + 5 * 86400
    fx_floor = export.chunk_expected_minutes("EURUSD.DWX", monday, saturday)
    assert fx_floor == int(5 * 1440 * (1.0 - export.SESSION_CLOSURE_ALLOWANCE_FRACTION["fx"]))

    index_floor = export.chunk_expected_minutes("GDAXI.DWX", monday, saturday)
    assert index_floor == int(
        5 * 1440 * (1.0 - export.SESSION_CLOSURE_ALLOWANCE_FRACTION["index_commodity"])
    )
    assert index_floor < fx_floor


def test_short_chunks_from_journal_flags_material_shortfall_not_only_zero(
) -> None:
    """The AUDCAD-class defect (2026-09-15 export-fix ticket, F4): 3 of ~26
    chunks starved by a concentrated hole, none of them fully zero. A journal
    carrying only ZERO_TICK_CHUNK rows would miss all three; short_chunks
    must also catch chunks materially under their per-chunk floor."""

    symbol = "EURUSD.DWX"
    monday = int(dt.datetime(2026, 1, 5, tzinfo=UTC).timestamp())  # Monday 00:00 UTC
    week = 7 * 86400
    floor = export.chunk_expected_minutes(symbol, monday, monday + week)
    assert floor > 0

    def _chunk_rows_row(index: int, rows_written: int) -> dict[str, object]:
        start = monday + index * week
        end = start + week
        return {
            "symbol": symbol, "chunk_start_epoch": start, "chunk_end_epoch": end,
            "phase": "bars", "attempt": 0, "copied": rows_written, "error_code": 0,
            "status": "CHUNK_ROWS",
        }

    rows = [
        _chunk_rows_row(0, floor + 500),  # healthy
        _chunk_rows_row(1, floor - 1),  # materially short, not zero
        _chunk_rows_row(2, floor - 1),  # materially short, not zero
        _chunk_rows_row(3, floor - 1),  # materially short, not zero
        _chunk_rows_row(4, floor + 500),  # healthy
    ]
    short_chunks = export.short_chunks_from_journal(symbol, rows)
    assert len(short_chunks) == 3
    flagged_starts = {row["chunk_start_epoch"] for row in short_chunks}
    assert flagged_starts == {monday + week, monday + 2 * week, monday + 3 * week}
    for row in short_chunks:
        assert row["chunk_rows_written"] == floor - 1
        assert row["chunk_expected_minutes"] == floor


def test_compute_receipt_status_fails_on_short_read_symbol_count() -> None:
    """Ticket F7: run()'s receipt status must FAIL on any SHORT_READ symbol
    even when every other PASS condition is otherwise met."""

    base_result: dict[str, object] = {
        "completion": "successes=37 failures=0 terminal=T1 build=1 total_rows=1 elapsed_ms=1",
        "signed_archive_unchanged": True,
        "canonicalization_status": "COMPLETE",
        "failed_symbol_count": 0,
    }
    passing_manifest = {"symbols": 37, "total_rows": 12345, "short_read_symbol_count": 0}
    assert export._compute_receipt_status(base_result, passing_manifest) == "PASS"

    short_read_manifest = {"symbols": 37, "total_rows": 12345, "short_read_symbol_count": 1}
    assert export._compute_receipt_status(base_result, short_read_manifest) == "FAIL"


def test_summary_error_text_names_short_read_symbols() -> None:
    """Ticket F7: summary.json's error field must name the SHORT_READ
    symbol(s), not just report a generic non-PASS status."""

    result = {
        "short_read_symbol_count": 2,
        "short_read_symbols": ["AUDCAD.DWX", "NZDJPY.DWX"],
        "failed_symbol_count": 0,
    }
    error_text = export._summary_error_text(result)
    assert error_text is not None
    assert "AUDCAD.DWX" in error_text
    assert "NZDJPY.DWX" in error_text

    clean_result = {"short_read_symbol_count": 0, "failed_symbol_count": 0}
    assert export._summary_error_text(clean_result) is None


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
