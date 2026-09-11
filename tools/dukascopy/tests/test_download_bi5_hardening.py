from __future__ import annotations

import datetime as dt
import lzma
import struct
import threading
import time
from pathlib import Path, PureWindowsPath

import pytest

from tools.dukascopy import common, download_bi5


def test_atomic_replace_retries_then_succeeds(tmp_path, monkeypatch) -> None:
    target = tmp_path / "progress.json"
    real_replace = common.os.replace
    calls = {"count": 0}
    def locked_once(source, destination):
        calls["count"] += 1
        if calls["count"] == 1:
            raise PermissionError(5, "share lock")
        return real_replace(source, destination)
    monkeypatch.setattr(common.os, "replace", locked_once)
    monkeypatch.setattr(common.time, "sleep", lambda _: None)
    monkeypatch.setattr(common.random, "uniform", lambda _a, _b: 0.0)
    common.atomic_write_bytes(target, b"ok")
    assert calls["count"] == 2 and target.read_bytes() == b"ok"


UTC = dt.timezone.utc


def _bi5() -> bytes:
    return lzma.compress(struct.pack(">IIIff", 1000, 110002, 110000, 1.0, 1.0))


def _unthrottled_limiter() -> download_bi5.RequestRateLimiter:
    return download_bi5.RequestRateLimiter(
        10, clock=lambda: 0.0, sleeper=lambda _seconds: None
    )


def test_containment_compares_equally_resolved_extended_windows_paths() -> None:
    """A long-path prefix is safe when both sides use the same resolution."""

    raw_root = PureWindowsPath(r"\\?\D:\QM\reports\dukascopy\backfill\raw")
    destination = raw_root / "EURAUD" / "2025" / "09" / "19" / "23h_ticks.bi5"
    download_bi5.assert_contained_destination(raw_root, destination)


def test_containment_still_refuses_a_genuine_escape() -> None:
    raw_root = PureWindowsPath(r"\\?\D:\QM\reports\dukascopy\backfill\raw")
    escaped = PureWindowsPath(r"\\?\D:\QM\reports\outside\23h_ticks.bi5")
    with pytest.raises(ValueError, match="escaped raw root"):
        download_bi5.assert_contained_destination(raw_root, escaped)


def test_retries_with_jitter_ledger_and_failed_only_resume(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5()
    attempts: dict[str, int] = {}
    sleeps: list[float] = []

    def first_fetcher(url: str, _timeout: float):
        attempts[url] = attempts.get(url, 0) + 1
        if url.endswith("00h_ticks.bi5") and attempts[url] == 1:
            raise OSError("transient")
        if url.endswith("01h_ticks.bi5"):
            raise OSError("still unavailable")
        return 200, {}, content

    result = download_bi5.run_download(
        out_dir=tmp_path / "download",
        symbols=["EURUSD.DWX"],
        start_utc=hour,
        end_utc=hour + dt.timedelta(hours=2),
        retries=2,
        concurrency=1,
        fetcher=first_fetcher,
        limiter=_unthrottled_limiter(),
        sleeper=sleeps.append,
        randomizer=lambda: 0.5,
    )
    assert result["status"] == "FAIL"
    assert result["downloaded"] == 1
    assert result["errors"] == 1
    assert sleeps == [pytest.approx(1.0), pytest.approx(1.0)]
    ledger = common.load_json_lines(Path(result["ledger_path"]))
    assert [row["state"] for row in ledger] == ["done", "failed"]

    resumed_calls: list[str] = []

    def recovery_fetcher(url: str, _timeout: float):
        resumed_calls.append(url)
        return 200, {}, content

    recovered = download_bi5.run_download(
        out_dir=tmp_path / "download",
        symbols=["EURUSD.DWX"],
        start_utc=hour,
        end_utc=hour + dt.timedelta(hours=2),
        retries=1,
        concurrency=1,
        fetcher=recovery_fetcher,
        limiter=_unthrottled_limiter(),
    )
    assert recovered["status"] == "PASS"
    assert recovered["resumed"] == 1
    assert recovered["downloaded"] == 1
    assert len(resumed_calls) == 1
    assert resumed_calls[0].endswith("01h_ticks.bi5")


def test_measurement_is_bounded_and_concurrent(tmp_path: Path) -> None:
    hour = dt.datetime(2026, 1, 5, tzinfo=UTC)
    content = _bi5()
    lock = threading.Lock()
    active = 0
    maximum_active = 0
    calls = 0

    def fetcher(_url: str, _timeout: float):
        nonlocal active, maximum_active, calls
        with lock:
            active += 1
            calls += 1
            maximum_active = max(maximum_active, active)
        time.sleep(0.02)
        with lock:
            active -= 1
        return 200, {}, content

    result = download_bi5.run_download(
        out_dir=tmp_path / "measure",
        symbols=["EURUSD.DWX"],
        start_utc=hour,
        end_utc=hour + dt.timedelta(hours=12),
        retries=1,
        concurrency=3,
        measure_files=6,
        projection_hours=304621,
        fetcher=fetcher,
        limiter=_unthrottled_limiter(),
    )
    assert result["status"] == "MEASURED"
    assert result["sample_files"] == 6
    assert result["full_plan_hours"] == 12
    assert result["projected_target_hours"] == 304621
    assert result["success_rate"] == 1.0
    assert result["projected_wall_seconds"] > 0
    assert calls == 6
    assert 1 < maximum_active <= 3
