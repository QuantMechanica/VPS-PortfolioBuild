import datetime as dt
import os
import sqlite3
from pathlib import Path

from tools.strategy_farm import farmctl, health


def make_db(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.execute("CREATE TABLE probe(value INTEGER)")
    connection.commit()
    connection.close()


def age(path: Path, minutes: float) -> None:
    stamp = dt.datetime.now(dt.UTC).timestamp() - minutes * 60
    os.utime(path, (stamp, stamp))


def test_pre_mutation_snapshot_does_not_satisfy_hourly_guard(tmp_path: Path) -> None:
    state = tmp_path / "state"
    backups = state / "backups"
    backups.mkdir(parents=True)
    make_db(state / "farm_state.sqlite")
    old_hourly = backups / "farm_state_20260905_1800.sqlite"
    old_hourly.write_bytes(b"old")
    age(old_hourly, 180)
    before = backups / "farm_state_before_claim_20260906T030000Z.sqlite"
    before.write_bytes(b"fresh")

    created = farmctl._hourly_db_backup(tmp_path)

    assert created is not None
    assert Path(created).is_file()
    assert before.is_file()
    assert Path(created).name in {
        path.name for path in farmctl._hourly_db_backup_paths(backups)
    }


def test_health_reports_stale_hourly_even_when_before_snapshot_is_fresh(
    tmp_path: Path, monkeypatch
) -> None:
    backups = tmp_path / "state" / "backups"
    backups.mkdir(parents=True)
    hourly = backups / "farm_state_20260905_1800.sqlite"
    hourly.write_bytes(b"old")
    age(hourly, 180)
    (backups / "farm_state_before_apply_20260906T030000Z.sqlite").write_bytes(b"fresh")
    monkeypatch.setattr(health, "ROOT", tmp_path)

    result = health.chk_db_backup_fresh()

    assert result["status"] == "FAIL"
    assert result["value"] >= 179
    assert "1 hourly snapshots" in result["detail"]


def test_health_rejects_before_only_snapshot_family(tmp_path: Path, monkeypatch) -> None:
    backups = tmp_path / "state" / "backups"
    backups.mkdir(parents=True)
    (backups / "farm_state_before_apply_20260906T030000Z.sqlite").write_bytes(b"fresh")
    monkeypatch.setattr(health, "ROOT", tmp_path)

    result = health.chk_db_backup_fresh()

    assert result["status"] == "FAIL"
    assert "no scheduled" in result["detail"]
