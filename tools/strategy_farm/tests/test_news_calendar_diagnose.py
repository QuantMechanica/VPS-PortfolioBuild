from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

from tools.strategy_farm.news_calendar_diagnose import (
    CalendarRow,
    compare_native,
    diagnose_anchors,
    diagnose_coverage,
    eastern_local_to_utc,
    is_us_dst_utc,
    us_dst_end_utc,
    us_dst_start_utc,
)


def _row(source: str, stamp: str, event: str) -> CalendarRow:
    return CalendarRow(
        source=source,
        instant=datetime.fromisoformat(stamp).replace(tzinfo=timezone.utc),
        currency="USD",
        impact="high",
        event=event,
        raw={},
    )


def test_qm_dst_rule_boundaries_and_release_conversion() -> None:
    start = us_dst_start_utc(2024)
    end = us_dst_end_utc(2024)
    assert start.isoformat() == "2024-03-10T07:00:00+00:00"
    assert end.isoformat() == "2024-11-03T06:00:00+00:00"
    assert not is_us_dst_utc(start - timedelta(minutes=1))
    assert is_us_dst_utc(start)
    assert is_us_dst_utc(end - timedelta(minutes=1))
    assert not is_us_dst_utc(end)
    assert eastern_local_to_utc(datetime(2024, 1, 5).date(), 8, 30).hour == 13
    assert eastern_local_to_utc(datetime(2024, 7, 5).date(), 8, 30).hour == 12


def test_synthetic_calendar_detects_minus_17h_shift_dst_seam_and_coverage_hole(
    tmp_path: Path,
) -> None:
    good = _row("secondary", "2024-01-05T13:30:00", "Non-Farm Employment Change")
    shifted = _row("secondary", "2024-02-01T20:30:00", "Non-Farm Employment Change")
    dst_seam = _row("secondary", "2024-03-15T13:30:00", "CPI m/m")

    anchor_detail, _ = diagnose_anchors([good, shifted, dst_seam])
    by_stamp = {row["stored_utc"]: row for row in anchor_detail}
    assert by_stamp[good.instant.isoformat()]["status"] == "PASS"
    assert by_stamp[shifted.instant.isoformat()]["status"] == "FAIL"
    assert by_stamp[shifted.instant.isoformat()]["schedule_rule_ok"] is False
    assert by_stamp[dst_seam.instant.isoformat()]["delta_minutes"] == 60

    # Native broker_time is true UTC.  The same event is stored 17 hours early.
    native_epoch = int(datetime(2024, 2, 2, 13, 30, tzinfo=timezone.utc).timestamp())
    for currency in ("USD", "EUR", "GBP", "JPY"):
        path = tmp_path / f"T_EXPORT_{currency}_HIGH_2018_2025_NATIVE.csv"
        path.write_text(
            "broker_time,event_id,event_code,event_name,importance\n"
            + (
                f"{native_epoch},1,nfp,Nonfarm Payrolls,high\n"
                if currency == "USD"
                else f"{native_epoch},1,x,Unmapped {currency},high\n"
            ),
            encoding="utf-8",
        )
    native_detail, native_summary, _ = compare_native([shifted], tmp_path)
    assert len(native_detail) == 1
    assert native_detail[0]["delta_minutes_stored_minus_native"] == -1020
    assert native_summary["delta_histogram_minutes"] == {"-1020": 1}

    coverage, zero = diagnose_coverage(
        {"secondary": [good, dst_seam]}, start="2024-01", end="2024-03"
    )
    assert zero == {"secondary": ["2024-02"]}
    assert next(row for row in coverage if row["month"] == "2024-02")["zero_month"] is True
