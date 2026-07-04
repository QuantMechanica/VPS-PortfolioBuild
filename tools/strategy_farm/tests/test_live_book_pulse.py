import os
from datetime import datetime, timedelta
from pathlib import Path

import sys


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import live_book_pulse  # noqa: E402


def _local_tz():
    return datetime.now().astimezone().tzinfo


def _fmt_terminal_time(dt: datetime) -> str:
    return dt.strftime("%H:%M:%S.") + f"{dt.microsecond // 1000:03d}"


def _write_scan_log(root: Path, scan_dt_local: datetime, mtime_utc: datetime | None = None) -> Path:
    log_dir = root / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    path = log_dir / f"{scan_dt_local:%Y%m%d}.log"
    path.write_text(
        f"AA\t0\t{_fmt_terminal_time(scan_dt_local)}\tNetwork\t'4000090541': scanning network finished\n",
        encoding="utf-8",
    )
    if mtime_utc is not None:
        os.utime(path, (mtime_utc.timestamp(), mtime_utc.timestamp()))
    return path


def test_normalize_timeframe_aliases_daily_to_d1() -> None:
    assert live_book_pulse.normalize_timeframe("Daily") == "D1"
    assert live_book_pulse.normalize_timeframe("PERIOD_D1") == "D1"
    assert live_book_pulse.normalize_timeframe("H1") == "H1"


def test_compare_loaded_charts_to_presets_flags_tf_mismatch() -> None:
    presets = [
        {
            "slot": 12,
            "ea_id": 12567,
            "symbol": "XNGUSD",
            "symbol_norm": "XNGUSD",
            "preset_tf": "D1",
            "preset_tf_norm": "D1",
            "magic": 125670002,
            "path": "slot12_XNGUSD_D1_QM5_12567_cum-rsi2-commodity_magic125670002.set",
        }
    ]
    loaded = [
        {
            "ea_id": 12567,
            "symbol": "XNGUSD",
            "tf": "H1",
            "source_file": "20260701.log",
            "ts_terminal": "2026-07-01T09:00:00",
        }
    ]

    result = live_book_pulse.compare_loaded_charts_to_presets(presets, loaded)

    assert result["mismatch_count"] == 1
    assert result["mismatches"][0]["status"] == "TF_MISMATCH"
    assert result["mismatches"][0]["loaded_tf_norm"] == "H1"
    assert result["mismatches"][0]["preset_tf_norm"] == "D1"


def test_compare_loaded_charts_to_presets_accepts_daily_alias() -> None:
    presets = [
        {
            "slot": 12,
            "ea_id": 12567,
            "symbol": "XNGUSD",
            "symbol_norm": "XNGUSD",
            "preset_tf": "D1",
            "preset_tf_norm": "D1",
            "magic": 125670002,
            "path": "slot12_XNGUSD_D1_QM5_12567_cum-rsi2-commodity_magic125670002.set",
        }
    ]
    loaded = [
        {
            "ea_id": 12567,
            "symbol": "XNGUSD",
            "tf": "Daily",
            "source_file": "20260703.log",
            "ts_terminal": "2026-07-03T07:00:00",
        }
    ]

    result = live_book_pulse.compare_loaded_charts_to_presets(presets, loaded)

    assert result["ok_count"] == 1
    assert result["mismatch_count"] == 0


def test_heartbeat_flat_allows_normal_three_hour_journal_gap(tmp_path: Path) -> None:
    now = datetime(2026, 7, 3, 12, 0, tzinfo=_local_tz())
    root = tmp_path / "terminal"
    _write_scan_log(root, now.replace(tzinfo=None) - timedelta(hours=3), now.astimezone() - timedelta(hours=3))

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        {"last_terminal_sync": {"positions": 0}},
        {"active_trade_manager_entry_count": 0},
    )

    assert hb["position_exposed"] is False
    assert hb["alarm"] is False
    assert hb["journal_stale_threshold_minutes"] == 450


def test_heartbeat_open_position_keeps_120m_rule(tmp_path: Path) -> None:
    now = datetime(2026, 7, 3, 12, 0, tzinfo=_local_tz())
    root = tmp_path / "terminal"
    _write_scan_log(root, now.replace(tzinfo=None) - timedelta(minutes=121), now.astimezone() - timedelta(minutes=121))

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        {"last_terminal_sync": {"positions": 1}},
        {"active_trade_manager_entry_count": 0},
    )

    assert hb["position_exposed"] is True
    assert hb["alarm"] is True
    assert "journal_stale_gt_120m_open_position" in hb["alarm_reason"]


def test_heartbeat_flags_stale_scan_when_flat(tmp_path: Path) -> None:
    now = datetime(2026, 7, 3, 12, 0, tzinfo=_local_tz())
    root = tmp_path / "terminal"
    _write_scan_log(root, now.replace(tzinfo=None) - timedelta(minutes=391), now.astimezone() - timedelta(minutes=391))

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        {"last_terminal_sync": {"positions": 0}},
        {"active_trade_manager_entry_count": 0},
    )

    assert hb["position_exposed"] is False
    assert hb["alarm"] is True
    assert "scan_heartbeat_stale_gt_390m" in hb["alarm_reason"]


def test_heartbeat_flags_missing_today_log_after_first_scan(tmp_path: Path) -> None:
    now = datetime(2026, 7, 4, 2, 0, tzinfo=_local_tz())
    root = tmp_path / "terminal"
    yesterday_late = datetime(2026, 7, 3, 23, 50)
    _write_scan_log(root, yesterday_late, now.astimezone() - timedelta(hours=2))

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        {"last_terminal_sync": {"positions": 0}},
        {"active_trade_manager_entry_count": 0},
    )

    assert hb["today_broker_journal_check_due"] is True
    assert hb["today_broker_journal_file_exists"] is False
    assert "today_broker_date_journal_missing_after_first_scan" in hb["alarm_reason"]
