from __future__ import annotations

import datetime as dt
import os
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from prune_workitem_logs import (  # noqa: E402
    discover_pipeline_roots,
    prune_pipeline_logs,
)


def _write_with_mtime(path: Path, content: bytes, modified: dt.datetime) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    epoch = modified.timestamp()
    os.utime(path, (epoch, epoch))


def test_discover_pipeline_roots_is_top_level_and_name_scoped(tmp_path) -> None:
    expected = [tmp_path / "pipeline", tmp_path / "pipeline_ftmo_joint"]
    for path in (*expected, tmp_path / "smoke", tmp_path / "work_items"):
        path.mkdir()
    (tmp_path / "pipeline_inventory.csv").write_text("not a directory", encoding="utf-8")

    assert discover_pipeline_roots(tmp_path) == expected


def test_pipeline_pruner_deletes_only_aged_logs(tmp_path) -> None:
    now = dt.datetime(2026, 7, 19, 18, 0, tzinfo=dt.UTC)
    old_log = tmp_path / "pipeline" / "EA" / "raw" / "old.log"
    fresh_log = tmp_path / "pipeline_ftmo_joint" / "EA" / "fresh.log"
    evidence = tmp_path / "pipeline" / "EA" / "summary.json"
    outside = tmp_path / "smoke" / "old.log"
    _write_with_mtime(old_log, b"old journal", now - dt.timedelta(days=2))
    _write_with_mtime(fresh_log, b"fresh journal", now - dt.timedelta(hours=2))
    _write_with_mtime(evidence, b"{}", now - dt.timedelta(days=2))
    _write_with_mtime(outside, b"outside", now - dt.timedelta(days=2))

    result = prune_pipeline_logs(
        dry_run=False,
        older_than_days=1,
        reports_parent=tmp_path,
        now=now,
    )

    assert result == {
        "roots": 2,
        "files": 1,
        "bytes": 11,
        "recent": 1,
        "unsafe": 0,
        "errors": 0,
    }
    assert not old_log.exists()
    assert fresh_log.exists()
    assert evidence.exists()
    assert outside.exists()


def test_pipeline_pruner_dry_run_keeps_candidate(tmp_path) -> None:
    now = dt.datetime(2026, 7, 19, 18, 0, tzinfo=dt.UTC)
    old_log = tmp_path / "pipeline" / "EA" / "old.log"
    _write_with_mtime(old_log, b"journal", now - dt.timedelta(days=2))

    result = prune_pipeline_logs(
        dry_run=True,
        older_than_days=1,
        reports_parent=tmp_path,
        now=now,
    )

    assert result["files"] == 1
    assert result["bytes"] == 7
    assert old_log.exists()


def test_pipeline_pruner_rejects_subday_retention(tmp_path) -> None:
    (tmp_path / "pipeline").mkdir()

    try:
        prune_pipeline_logs(
            dry_run=True,
            older_than_days=0,
            reports_parent=tmp_path,
        )
    except ValueError as exc:
        assert "must be >= 1" in str(exc)
    else:
        raise AssertionError("sub-day pipeline retention must be rejected")
