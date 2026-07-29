import datetime as dt
import hashlib
import json
import os
import sys
from pathlib import Path
from unittest import mock

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import news_calendar_gate as gate  # noqa: E402


NOW = dt.datetime(2026, 7, 29, 12, 0, tzinfo=dt.UTC)


def _calendar_bytes(tag: str) -> tuple[bytes, bytes]:
    primary = (
        "datetime,currency,event_name,impact\n"
        f"2026-07-28 08:30:00,USD,CPI {tag},high\n"
        "2026-07-28 12:00:00,EUR,ECB Press Conference,medium\n"
    ).encode()
    secondary = (
        "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous\n"
        f"2026.07.28,2026.07.28 08:30,2026.07.28 10:30,USD,High,CPI {tag},,,\n"
        "2026.07.28,2026.07.28 12:00,2026.07.28 14:00,EUR,Medium,ECB Press Conference,,,\n"
    ).encode()
    return primary, secondary


def _write_pair(root: Path, tag: str = "BASE") -> None:
    root.mkdir(parents=True, exist_ok=True)
    primary, secondary = _calendar_bytes(tag)
    (root / gate.PRIMARY_NAME).write_bytes(primary)
    (root / gate.SECONDARY_NAME).write_bytes(secondary)


def _set_mtime(root: Path, when: dt.datetime) -> None:
    timestamp = when.timestamp()
    for name in gate.CALENDAR_NAMES:
        os.utime(root / name, (timestamp, timestamp))


def _snapshot(root: Path) -> list[tuple[str, bytes, int]]:
    return [
        (str(path.relative_to(root)), path.read_bytes(), path.stat().st_mtime_ns)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    ]


@pytest.mark.parametrize(
    ("fault", "expected"),
    [
        ("missing_source", gate.STATUS_MISSING_SOURCE),
        ("missing_common", gate.STATUS_MISSING_COMMON),
        ("stale", gate.STATUS_STALE_COMMON),
        ("mismatch", gate.STATUS_COMMON_MISMATCH),
        ("parse_invalid", gate.STATUS_PARSE_INVALID),
    ],
)
def test_preflight_fault_taxonomy_is_side_effect_free(
    tmp_path: Path, fault: str, expected: str
) -> None:
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(source)
    _write_pair(common)
    _set_mtime(common, NOW - dt.timedelta(hours=2))

    if fault == "missing_source":
        (source / gate.PRIMARY_NAME).unlink()
    elif fault == "missing_common":
        (common / gate.SECONDARY_NAME).unlink()
    elif fault == "stale":
        _set_mtime(common, NOW - dt.timedelta(hours=gate.MAX_AGE_HOURS + 1))
    elif fault == "mismatch":
        _, secondary = _calendar_bytes("DRIFT")
        (common / gate.SECONDARY_NAME).write_bytes(secondary)
    elif fault == "parse_invalid":
        (source / gate.PRIMARY_NAME).write_text("wrong,header\n1,2\n", encoding="utf-8")

    before = _snapshot(tmp_path)
    result = gate.preflight_news_calendar(
        source,
        common,
        now=NOW,
        use_cache=False,
    )
    after = _snapshot(tmp_path)

    assert result.status == expected
    assert result.ok is False
    assert result.common_dir == str(common)
    assert result.principal
    assert before == after


def test_preflight_accepts_valid_legacy_flat_pair(tmp_path: Path) -> None:
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(source)
    _write_pair(common)
    _set_mtime(common, NOW - dt.timedelta(hours=2))

    result = gate.preflight_news_calendar(source, common, now=NOW, use_cache=False)

    assert result.ok is True
    assert result.status == gate.STATUS_OK
    assert result.legacy_flat_files is True
    assert result.bundle_id is None
    assert result.age_hours == 2.0


def _factory_off(root: Path) -> tuple[Path, str]:
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.parent.mkdir(parents=True)
    flag.write_text('{"reason":"intentional maintenance"}\n', encoding="utf-8")
    return flag, hashlib.sha256(flag.read_bytes()).hexdigest()


def test_publisher_fsyncs_and_installs_immutable_two_file_bundle(tmp_path: Path) -> None:
    candidates = tmp_path / "candidates"
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(candidates, "NEW")
    flag, flag_sha = _factory_off(tmp_path / "farm")
    plan = gate.build_publication_plan(
        candidates / gate.PRIMARY_NAME,
        candidates / gate.SECONDARY_NAME,
        generated_at="2026-07-29T10:00:00Z",
    )

    real_fsync = os.fsync
    fsync_calls: list[int] = []

    def tracking_fsync(fd: int) -> None:
        fsync_calls.append(fd)
        real_fsync(fd)

    with mock.patch.object(gate.os, "fsync", side_effect=tracking_fsync):
        result = gate.publish_calendar_bundle(
            plan,
            source_dir=source,
            common_dir=common,
            factory_off_flag=flag,
            expected_factory_off_sha256=flag_sha,
        )

    manifest = plan["manifest"]
    assert result["published"] is True
    assert result["bundle_id"] == manifest["bundle_id"]
    assert fsync_calls
    for root in (source, common):
        assert (root / gate.PRIMARY_NAME).read_bytes() == (
            candidates / gate.PRIMARY_NAME
        ).read_bytes()
        assert (root / gate.SECONDARY_NAME).read_bytes() == (
            candidates / gate.SECONDARY_NAME
        ).read_bytes()
        active_manifest = json.loads(
            (root / gate.ACTIVE_MANIFEST_NAME).read_text(encoding="utf-8")
        )
        assert active_manifest == manifest
        bundle = root / gate.BUNDLE_DIRECTORY_NAME / manifest["bundle_id"]
        assert (bundle / gate.PRIMARY_NAME).is_file()
        assert (bundle / gate.SECONDARY_NAME).is_file()
        assert (bundle / gate.ACTIVE_MANIFEST_NAME).is_file()
    assert not [
        path
        for path in tmp_path.rglob("*")
        if ".tmp" in path.name or path.name.startswith(".stg-")
    ]

    verified = gate.preflight_news_calendar(source, common, use_cache=False)
    assert verified.ok is True
    assert verified.bundle_id == manifest["bundle_id"]
    assert verified.manifest_sha256 == manifest["manifest_sha256"]

    # The same exact plan is idempotent and verifies, never overwrites, its
    # immutable version directory.
    again = gate.publish_calendar_bundle(
        plan,
        source_dir=source,
        common_dir=common,
        factory_off_flag=flag,
        expected_factory_off_sha256=flag_sha,
    )
    assert again["bundle_id"] == result["bundle_id"]


def test_publisher_requires_hash_bound_factory_off_before_target_writes(
    tmp_path: Path,
) -> None:
    candidates = tmp_path / "candidates"
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(candidates)
    plan = gate.build_publication_plan(
        candidates / gate.PRIMARY_NAME,
        candidates / gate.SECONDARY_NAME,
        generated_at="2026-07-29T10:00:00Z",
    )

    with pytest.raises(gate.NewsCalendarError, match="FACTORY_OFF flag missing"):
        gate.publish_calendar_bundle(
            plan,
            source_dir=source,
            common_dir=common,
            factory_off_flag=tmp_path / "farm" / "state" / "FACTORY_OFF.flag",
            expected_factory_off_sha256="0" * 64,
        )

    assert not source.exists()
    assert not common.exists()


def test_interrupted_pair_publish_is_detected_fail_closed_and_recoverable(
    tmp_path: Path,
) -> None:
    candidates_old = tmp_path / "old"
    candidates_new = tmp_path / "new"
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(candidates_old, "OLD")
    _write_pair(candidates_new, "NEW")
    flag, flag_sha = _factory_off(tmp_path / "farm")
    old_plan = gate.build_publication_plan(
        candidates_old / gate.PRIMARY_NAME,
        candidates_old / gate.SECONDARY_NAME,
        generated_at="2026-07-29T09:00:00Z",
    )
    new_plan = gate.build_publication_plan(
        candidates_new / gate.PRIMARY_NAME,
        candidates_new / gate.SECONDARY_NAME,
        generated_at="2026-07-29T10:00:00Z",
    )
    gate.publish_calendar_bundle(
        old_plan,
        source_dir=source,
        common_dir=common,
        factory_off_flag=flag,
        expected_factory_off_sha256=flag_sha,
    )

    with pytest.raises(gate.InjectedPublishFailure, match="SOURCE_PRIMARY_REPLACED"):
        gate.publish_calendar_bundle(
            new_plan,
            source_dir=source,
            common_dir=common,
            factory_off_flag=flag,
            expected_factory_off_sha256=flag_sha,
            fault_after="SOURCE_PRIMARY_REPLACED",
        )

    interrupted = gate.preflight_news_calendar(source, common, use_cache=False)
    assert interrupted.ok is False
    assert interrupted.status == gate.STATUS_COMMON_MISMATCH
    assert not [path for path in tmp_path.rglob("*") if ".tmp" in path.name]

    recovered = gate.publish_calendar_bundle(
        new_plan,
        source_dir=source,
        common_dir=common,
        factory_off_flag=flag,
        expected_factory_off_sha256=flag_sha,
    )
    assert recovered["published"] is True
    assert gate.preflight_news_calendar(source, common, use_cache=False).ok is True
