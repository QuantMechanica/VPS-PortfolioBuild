from __future__ import annotations

import json
from pathlib import Path

from framework.scripts.resolve_logger_sample import resolve_latest_logger_sample


def _event(event: str = "INIT") -> dict:
    return {
        "sv": 1,
        "ts_utc": "2026-07-20T10:00:00.000Z",
        "ts_broker": "2026-07-20T12:00:00",
        "level": "INFO",
        "ea_id": 1234,
        "slug": "ea-1234",
        "symbol": "EURUSD.DWX",
        "tf": "H1",
        "magic": 12340000,
        "event": event,
        "payload": {},
    }


def _smoke(report_root: Path, tag: str, timestamp: str, *, valid: bool = True) -> tuple[Path, Path]:
    report_dir = report_root / "QM5_1234" / tag
    report_dir.mkdir(parents=True)
    sample = report_dir / "logger_sample.jsonl"
    row = _event()
    if not valid:
        row.pop("sv")
    sample.write_text(json.dumps(row) + "\n", encoding="utf-8")
    summary = report_dir / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "timestamp_utc": timestamp,
                "report_dir": str(report_dir),
                "logger_sample_path": str(sample),
            }
        ),
        encoding="utf-8",
    )
    return summary, sample


def test_resolves_latest_valid_summary_link(tmp_path: Path) -> None:
    _, older = _smoke(tmp_path, "20260720_100000", "2026-07-20T10:00:00Z")
    _smoke(tmp_path, "20260720_110000", "2026-07-20T11:00:00Z", valid=False)
    newest_summary, newest = _smoke(
        tmp_path, "20260720_120000", "2026-07-20T12:00:00Z"
    )

    resolved = resolve_latest_logger_sample(tmp_path)

    assert resolved is not None
    assert resolved.sample_path == newest.resolve()
    assert resolved.summary_path == newest_summary.resolve()
    assert resolved.sample_path != older.resolve()


def test_rejects_unlinked_or_escaping_sample(tmp_path: Path) -> None:
    report_dir = tmp_path / "QM5_1234" / "20260720_120000"
    report_dir.mkdir(parents=True)
    outside = tmp_path / "outside.jsonl"
    outside.write_text(json.dumps(_event()) + "\n", encoding="utf-8")
    (report_dir / "summary.json").write_text(
        json.dumps(
            {
                "timestamp_utc": "2026-07-20T12:00:00Z",
                "logger_sample_path": str(outside),
            }
        ),
        encoding="utf-8",
    )

    assert resolve_latest_logger_sample(tmp_path) is None
