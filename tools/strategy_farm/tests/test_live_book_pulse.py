from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import live_book_pulse  # noqa: E402


def make_terminal_root(tmp_path: Path) -> Path:
    root = tmp_path / "MT5_Base"
    (root / "logs").mkdir(parents=True)
    return root


def write_scan_log(root: Path, now: datetime, minutes_old: float, date_name: str | None = None) -> Path:
    scan_time = datetime.fromtimestamp((now - timedelta(minutes=minutes_old)).timestamp())
    if date_name is None:
        date_name = scan_time.strftime("%Y%m%d")
    path = root / "logs" / f"{date_name}.log"
    path.write_text(
        f"MK\t0\t{scan_time.strftime('%H:%M:%S.%f')[:-3]}\tNetwork\t"
        "'4000090541': scanning network finished\n",
        encoding="utf-8",
    )
    mtime = now - timedelta(minutes=minutes_old)
    os.utime(path, (mtime.timestamp(), mtime.timestamp()))
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


def test_heartbeat_allows_flat_terminal_between_six_hour_scans(tmp_path: Path) -> None:
    now = datetime(2026, 7, 4, 12, 0, tzinfo=timezone.utc)
    root = make_terminal_root(tmp_path)
    write_scan_log(root, now, minutes_old=150)

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        terminal={"last_terminal_sync": {"positions": 0}},
        ea_logs={"active_trade_manager_entry_count": 0},
        tail_bytes=4096,
    )

    assert hb["alarm"] is False
    assert hb["alarm_reasons"] == []
    assert hb["minutes_since_last_journal_write"] == 150
    assert hb["minutes_since_last_network_scan_write"] == 150


def test_heartbeat_keeps_two_hour_rule_when_position_is_open(tmp_path: Path) -> None:
    now = datetime(2026, 7, 4, 12, 0, tzinfo=timezone.utc)
    root = make_terminal_root(tmp_path)
    write_scan_log(root, now, minutes_old=121)

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        terminal={"last_terminal_sync": {"positions": 1}},
        ea_logs={"active_trade_manager_entry_count": 0},
        tail_bytes=4096,
    )

    assert hb["alarm"] is True
    assert hb["alarm_reasons"] == ["journal_stale_gt_120m_open_position"]


def test_heartbeat_warns_when_scan_heartbeat_is_stale_while_flat(tmp_path: Path) -> None:
    now = datetime(2026, 7, 4, 12, 0, tzinfo=timezone.utc)
    root = make_terminal_root(tmp_path)
    write_scan_log(root, now, minutes_old=391)

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        terminal={"last_terminal_sync": {"positions": 0}},
        ea_logs={"active_trade_manager_entry_count": 0},
        tail_bytes=4096,
    )

    assert hb["alarm"] is True
    assert hb["alarm_reasons"] == ["network_scan_stale_gt_390m"]


def test_heartbeat_warns_when_today_broker_log_missing_after_first_scan(tmp_path: Path) -> None:
    now = datetime(2026, 7, 4, 12, 0, tzinfo=timezone.utc)
    root = make_terminal_root(tmp_path)
    today = datetime.strptime(live_book_pulse.broker_date_yyyymmdd(now), "%Y%m%d").date()
    yesterday = (today - timedelta(days=1)).strftime("%Y%m%d")
    write_scan_log(root, now, minutes_old=30, date_name=yesterday)

    hb = live_book_pulse.heartbeat(
        [root],
        now,
        terminal={"last_terminal_sync": {"positions": 0}},
        ea_logs={"active_trade_manager_entry_count": 0},
        tail_bytes=4096,
    )

    assert hb["alarm"] is True
    assert "today_broker_journal_missing_after_first_scan" in hb["alarm_reasons"]
