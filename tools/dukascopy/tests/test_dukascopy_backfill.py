from __future__ import annotations

import csv
import datetime as dt
import json
import lzma
import struct
from pathlib import Path

import pytest

from tools.dukascopy import common, convert_to_import, download_bi5, reconcile_overlap


UTC = dt.timezone.utc


def _bi5(records: list[tuple[int, int, int, float, float]]) -> bytes:
    raw = b"".join(struct.pack(">IIIff", *record) for record in records)
    return lzma.compress(raw)


def _write_header_m1(path: Path, rows: list[tuple[int, float, int, float]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["time", "open", "high", "low", "close", "tickvol", "spread"])
        for timestamp, close, volume, spread in rows:
            writer.writerow([
                timestamp,
                close,
                close + 0.00002,
                close - 0.00002,
                close,
                volume,
                spread,
            ])


def _write_nonfx_metadata(path: Path) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=common.NONFX_METADATA_HEADER, lineterminator="\n")
        writer.writeheader()
        for index, symbol in enumerate(sorted(common.NON_FX_INSTRUMENTS), start=1):
            # Synthetic contract fixtures deliberately do not encode or guess
            # any broker's actual per-symbol values.
            digits = index % 6
            writer.writerow({
                "symbol": symbol,
                "digits": digits,
                "point": format(10.0 ** -digits, ".12g"),
                "price_scale": 10 ** digits,
            })


def test_symbol_mapping_is_exactly_the_37_row_dwx_universe() -> None:
    assert len(common.CANONICAL_SYMBOLS) == 37
    assert common.canonical_instrument("EURUSD.DWX") == "EURUSD"
    assert common.canonical_instrument("GDAXI.DWX") == "DEU.IDX/EUR"
    assert common.canonical_instrument("SP500.DWX") == "USA500.IDX/USD"
    assert common.canonical_instrument("NDX.DWX") == "USATECH.IDX/USD"
    assert common.canonical_instrument("WS30.DWX") == "USA30.IDX/USD"
    assert common.canonical_instrument("UK100.DWX") == "GBR.IDX/GBP"
    assert common.canonical_instrument("XTIUSD.DWX") == "LIGHT.CMD/USD"
    assert common.canonical_instrument("XNGUSD.DWX") == "GAS.CMD/USD"
    assert common.instrument_url_key("USA500.IDX/USD") == "USA500IDXUSD"
    with pytest.raises(ValueError, match="outside the 37-row"):
        common.canonical_instrument("BTCUSD.DWX")
    assert common.default_price_scale("EURUSD.DWX") == 100000
    assert common.default_point_size("EURUSD.DWX") == pytest.approx(0.00001)
    assert common.default_price_scale("XTIUSD.DWX") is None
    assert common.default_point_size("XTIUSD.DWX") is None


@pytest.mark.parametrize(
    ("instant", "offset"),
    [
        ("2025-03-09T06:59:59Z", 2),
        ("2025-03-09T07:00:00Z", 3),
        ("2025-11-02T05:59:59Z", 3),
        ("2025-11-02T06:00:00Z", 2),
        ("2026-03-08T06:59:59Z", 2),
        ("2026-03-08T07:00:00Z", 3),
        ("2026-11-01T05:59:59Z", 3),
        ("2026-11-01T06:00:00Z", 2),
    ],
)
def test_darwinex_us_dst_boundaries(instant: str, offset: int) -> None:
    value = common.parse_utc(instant)
    assert common.darwinex_broker_offset_hours(value) == offset
    assert common.utc_to_broker_wall(value) == (value + dt.timedelta(hours=offset)).replace(
        tzinfo=None
    )


def test_synthetic_hourly_bi5_decode_and_schema() -> None:
    content = _bi5([
        (1, 110002, 110000, 1.5, 2.5),
        (3599999, 110012, 110010, 3.5, 4.5),
    ])
    inspection = common.inspect_hourly_bi5(content)
    assert inspection == {
        "records": 2,
        "raw_bytes": 40,
        "first_offset_msc": 1,
        "last_offset_msc": 3599999,
    }
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    ticks = list(common.decode_hourly_bi5(content, hour, 100000))
    assert ticks[0].utc_time_msc == int(hour.timestamp() * 1000) + 1
    assert ticks[0].bid == pytest.approx(1.1)
    assert ticks[0].ask == pytest.approx(1.10002)


def test_hourly_bi5_rejects_daily_offset() -> None:
    content = _bi5([(3_600_000, 110002, 110000, 1.0, 1.0)])
    with pytest.raises(ValueError, match="outside the hour"):
        common.inspect_hourly_bi5(content)


def test_request_rate_limiter_stays_inside_governed_rate() -> None:
    clock_value = [0.0]
    sleeps: list[float] = []

    def clock() -> float:
        return clock_value[0]

    def sleep(seconds: float) -> None:
        sleeps.append(seconds)
        clock_value[0] += seconds

    limiter = download_bi5.RequestRateLimiter(5, clock=clock, sleeper=sleep)
    limiter.wait()
    limiter.wait()
    assert sleeps == [pytest.approx(0.2)]
    with pytest.raises(ValueError, match="between 5 and 10"):
        download_bi5.RequestRateLimiter(11)


def test_downloader_writes_checksum_manifest_and_resumes(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5([(1000, 110002, 110000, 1.0, 1.0)])
    calls: list[str] = []

    def fetcher(url: str, _timeout: float):
        calls.append(url)
        return 200, {"content-type": "application/octet-stream"}, content

    fake_limiter = download_bi5.RequestRateLimiter(
        10, clock=lambda: 0.0, sleeper=lambda _seconds: None
    )
    first = download_bi5.run_download(
        out_dir=tmp_path / "download",
        symbols=["EURUSD.DWX"],
        start_utc=hour,
        end_utc=hour + dt.timedelta(hours=1),
        requests_per_second=10,
        timeout_seconds=5,
        retries=1,
        fetcher=fetcher,
        limiter=fake_limiter,
    )
    assert first["status"] == "PASS"
    assert first["downloaded"] == 1
    rows = common.load_json_lines(Path(first["manifest_path"]))
    assert rows[0]["sha256"] == common.sha256_bytes(content)
    assert rows[0]["decoded_records"] == 1

    def forbidden_fetcher(_url: str, _timeout: float):
        raise AssertionError("resume must not perform an HTTP request")

    second = download_bi5.run_download(
        out_dir=tmp_path / "download",
        symbols=["EURUSD.DWX"],
        start_utc=hour,
        end_utc=hour + dt.timedelta(hours=1),
        requests_per_second=10,
        timeout_seconds=5,
        retries=1,
        fetcher=forbidden_fetcher,
        limiter=fake_limiter,
    )
    assert second["status"] == "PASS"
    assert second["resumed"] == 1
    assert len(calls) == 1


def test_converter_enforces_strict_splice_and_prepare_import_schema(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5([
        (0, 110002, 110000, 1.0, 1.0),
        (1000, 110003, 110001, 1.0, 1.0),
        (60000, 110012, 110010, 1.0, 1.0),
    ])
    download_root = tmp_path / "download"
    raw_path = download_root / "raw" / common.hourly_relative_path("EURUSD.DWX", hour)
    common.atomic_write_bytes(raw_path, content)
    manifest = download_root / "download_manifest.jsonl"
    common.append_json_line(manifest, {
        "schema": download_bi5.MANIFEST_SCHEMA,
        "symbol": "EURUSD.DWX",
        "status": "downloaded",
        "url": common.hourly_url(download_bi5.DEFAULT_BASE_URL, "EURUSD.DWX", hour),
        "hour_utc": common.format_utc(hour),
        "relative_path": raw_path.relative_to(download_root / "raw").as_posix(),
        "sha256": common.sha256_file(raw_path),
        "bytes": raw_path.stat().st_size,
    })
    result = convert_to_import.convert_symbol(
        manifest_path=manifest,
        raw_root=download_root / "raw",
        symbol="EURUSD.DWX",
        splice_utc=hour,
        out_dir=tmp_path / "converted",
        reconciliation_from_utc=hour,
    )
    tick_path = Path(result["tick_output"]["path"])
    m1_path = Path(result["m1_output"]["path"])
    tick_rows = list(csv.reader(tick_path.open(encoding="utf-8")))
    m1_rows = list(csv.reader(m1_path.open(encoding="utf-8")))
    assert len(tick_rows) == 2
    assert tick_rows[0][0] == "2026.01.05 02:00:01.000"
    assert len(tick_rows[0]) == 3
    assert len(m1_rows) == 2
    assert len(m1_rows[0]) == 8
    reconciliation_path = Path(result["reconciliation_m1_output"]["path"])
    reconciliation_rows = list(csv.reader(reconciliation_path.open(encoding="utf-8")))
    assert len(reconciliation_rows) == 2
    assert result["reconciliation_m1_output"]["source_ticks"] == 3
    assert result["reconciliation_m1_output"]["import_authorized"] is False
    assert result["tick_output"]["first_source_utc_msc"] > int(hour.timestamp() * 1000)
    sidecar = json.loads(
        (tmp_path / "converted/EURUSD.DWX.dukascopy-source.json").read_text(
            encoding="utf-8"
        )
    )
    assert sidecar["source"] == "dukascopy"
    assert sidecar["production_import"] is False
    with pytest.raises(ValueError, match="already exists"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="EURUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "converted",
            reconciliation_from_utc=hour,
        )


def test_converter_rejects_checksum_drift_and_unproven_cfd_scale(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5([(1000, 110002, 110000, 1.0, 1.0)])
    download_root = tmp_path / "download"
    raw_path = download_root / "raw" / common.hourly_relative_path("XTIUSD.DWX", hour)
    common.atomic_write_bytes(raw_path, content)
    manifest = download_root / "download_manifest.jsonl"
    common.append_json_line(manifest, {
        "symbol": "XTIUSD.DWX",
        "status": "downloaded",
        "url": "fixture",
        "hour_utc": common.format_utc(hour),
        "relative_path": raw_path.relative_to(download_root / "raw").as_posix(),
        "sha256": "0" * 64,
        "bytes": len(content),
    })
    with pytest.raises(ValueError, match="supply --price-scale"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="XTIUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "converted",
        )
    with pytest.raises(ValueError, match="checksum mismatch"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="XTIUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "converted",
            price_scale=1000,
            point_size=0.001,
        )


def test_nonfx_receipt_supplies_converter_and_reconciler_without_silent_defaults(tmp_path: Path) -> None:
    metadata = tmp_path / "price_scale.csv"
    _write_nonfx_metadata(metadata)
    loaded = common.load_nonfx_instrument_metadata(metadata)
    assert set(loaded) == set(common.NON_FX_INSTRUMENTS)
    xti_metadata = loaded["XTIUSD.DWX"]

    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5([(1000, 110002, 110000, 1.0, 1.0)])
    download_root = tmp_path / "download"
    raw_path = download_root / "raw" / common.hourly_relative_path("XTIUSD.DWX", hour)
    common.atomic_write_bytes(raw_path, content)
    manifest = download_root / "download_manifest.jsonl"
    common.append_json_line(manifest, {
        "symbol": "XTIUSD.DWX", "status": "downloaded", "url": "fixture",
        "hour_utc": common.format_utc(hour),
        "relative_path": raw_path.relative_to(download_root / "raw").as_posix(),
        "sha256": common.sha256_file(raw_path), "bytes": len(content),
    })
    converted = convert_to_import.convert_symbol(
        manifest_path=manifest,
        raw_root=download_root / "raw",
        symbol="XTIUSD.DWX",
        splice_utc=hour,
        out_dir=tmp_path / "converted",
        instrument_metadata_path=metadata,
    )
    assert converted["price_scale"] == xti_metadata["price_scale"]
    assert converted["point_size"] == pytest.approx(xti_metadata["point_size"])
    assert converted["instrument_metadata"]["sha256"] == common.sha256_file(metadata)
    with pytest.raises(ValueError, match="conflicts with governed"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="XTIUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "conflicting",
            price_scale=int(xti_metadata["price_scale"]) + 1,
            instrument_metadata_path=metadata,
        )

    candidate, reference = _overlap_rows(close_delta=0.0)
    dukascopy = tmp_path / "duk_nonfx.csv"
    dwx = tmp_path / "dwx_nonfx.csv"
    _write_header_m1(dukascopy, candidate)
    _write_header_m1(dwx, reference)
    reconciled = reconcile_overlap.reconcile_symbol(
        symbol="XTIUSD.DWX",
        dukascopy_csv=dukascopy,
        dwx_csv=dwx,
        instrument_metadata_path=metadata,
    )
    assert reconciled["point_size"] == pytest.approx(xti_metadata["point_size"])
    assert reconciled["instrument_metadata"]["sha256"] == common.sha256_file(metadata)
    with pytest.raises(ValueError, match="conflicts with governed"):
        reconcile_overlap.reconcile_symbol(
            symbol="XTIUSD.DWX",
            dukascopy_csv=dukascopy,
            dwx_csv=dwx,
            point_size=float(xti_metadata["point_size"]) * 2,
            instrument_metadata_path=metadata,
        )

    with pytest.raises(ValueError, match="explicit point_size"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="XTIUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "refused",
            price_scale=1000,
        )


def test_converter_refuses_an_unresolved_manifest_hour(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    download_root = tmp_path / "download"
    (download_root / "raw").mkdir(parents=True)
    manifest = download_root / "download_manifest.jsonl"
    common.append_json_line(manifest, {
        "symbol": "EURUSD.DWX",
        "status": "error",
        "url": common.hourly_url(download_bi5.DEFAULT_BASE_URL, "EURUSD.DWX", hour),
        "hour_utc": common.format_utc(hour),
        "relative_path": common.hourly_relative_path("EURUSD.DWX", hour).as_posix(),
    })
    with pytest.raises(ValueError, match="unresolved download"):
        convert_to_import.convert_symbol(
            manifest_path=manifest,
            raw_root=download_root / "raw",
            symbol="EURUSD.DWX",
            splice_utc=hour,
            out_dir=tmp_path / "converted",
        )


def _overlap_rows(close_delta: float = 0.0) -> tuple[list, list]:
    times: list[int] = []
    for transition in (
        common.us_dst_bounds_utc(2025)[1],
        common.us_dst_bounds_utc(2026)[0],
    ):
        center = common.broker_epoch_seconds_for_utc(transition)
        times.extend(center + minute * 60 for minute in range(-10, 11))
    # Extend the actual overlap bounds so both transition windows are selected.
    times.extend([
        int(dt.datetime(2025, 9, 20, tzinfo=UTC).timestamp()),
        int(dt.datetime(2026, 4, 10, tzinfo=UTC).timestamp()),
    ])
    times = sorted(set(times))
    reference = [(value, 1.10000, 100, 1.0) for value in times]
    candidate = [(value, 1.10000 + close_delta, 90, 1.2) for value in times]
    return candidate, reference


def test_reconciliation_fixed_thresholds_and_dst_zero_offset(tmp_path: Path) -> None:
    candidate, reference = _overlap_rows(close_delta=0.000005)
    dukascopy = tmp_path / "duk.csv"
    dwx = tmp_path / "dwx.csv"
    _write_header_m1(dukascopy, candidate)
    _write_header_m1(dwx, reference)
    result = reconcile_overlap.reconcile_symbol(
        symbol="EURUSD.DWX",
        dukascopy_csv=dukascopy,
        dwx_csv=dwx,
    )
    assert result["status"] == "PASS"
    assert result["close_delta_p95_points"] == pytest.approx(0.5)
    assert result["session_coverage"] == 1.0
    assert result["tick_density_ratio"] == pytest.approx(0.9)
    assert {row["best_offset_seconds"] for row in result["dst_windows"]} == {0}
    assert result["checks"] == {
        "close_delta_p95": True,
        "session_coverage": True,
        "dst_zero_second_offset": True,
        "required_overlap_window": True,
        "compute_budget": True,
    }

    failed_candidate, _ = _overlap_rows(close_delta=0.00002)
    _write_header_m1(tmp_path / "duk_fail.csv", failed_candidate)
    failed = reconcile_overlap.reconcile_symbol(
        symbol="EURUSD.DWX",
        dukascopy_csv=tmp_path / "duk_fail.csv",
        dwx_csv=dwx,
    )
    assert failed["status"] == "FAIL"
    assert failed["close_delta_p95_points"] == pytest.approx(2.0)
    assert failed["checks"]["close_delta_p95"] is False

    sparse_candidate = candidate.copy()
    del sparse_candidate[5]
    _write_header_m1(tmp_path / "duk_sparse.csv", sparse_candidate)
    sparse = reconcile_overlap.reconcile_symbol(
        symbol="EURUSD.DWX",
        dukascopy_csv=tmp_path / "duk_sparse.csv",
        dwx_csv=dwx,
    )
    assert sparse["status"] == "FAIL"
    assert sparse["session_coverage"] < 0.99
    assert sparse["checks"]["session_coverage"] is False

    written = reconcile_overlap.write_results([result], tmp_path / "reconciliation")
    assert written["status"] == "PASS"
    summary = json.loads(
        (tmp_path / "reconciliation/reconciliation_summary.json").read_text(
            encoding="utf-8"
        )
    )
    assert summary["thresholds"] == {
        "close_delta_p95_spread_multiplier": 1.5,
        "maximum_compute_seconds": 7200,
        "minimum_session_coverage": 0.99,
        "required_dst_offset_seconds": 0,
        "required_overlap_end_utc": "2026-04-01T00:00:00Z",
        "required_overlap_start_utc": "2025-10-01T00:00:00Z",
    }
    assert (tmp_path / "reconciliation/EURUSD_DWX_reconciliation.csv").is_file()


def test_reconciliation_detects_one_hour_timestamp_offset() -> None:
    reference = [1_000_000 + minute * 60 for minute in range(20)]
    candidate = [value + 3600 for value in reference]
    offset, matches = reconcile_overlap.estimate_best_offset_seconds(candidate, reference)
    assert offset == -3600
    assert matches == len(reference)
