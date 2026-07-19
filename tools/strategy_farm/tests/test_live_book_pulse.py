import os
import json
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


def test_load_live_presets_accepts_deployment_suffix(tmp_path: Path) -> None:
    root = tmp_path / "terminal"
    preset_dir = root / "MQL5" / "Presets"
    preset_dir.mkdir(parents=True)
    preset = preset_dir / (
        "slot01_NDX_H1_QM5_10440_tm-cum-rsi2_"
        "magic104400003_d2d_s3_live.set"
    )
    preset.write_text("RISK_FIXED=250\n", encoding="ascii")

    rows = live_book_pulse.load_live_presets([root])

    assert len(rows) == 1
    assert rows[0]["slot"] == 1
    assert rows[0]["ea_id"] == 10440
    assert rows[0]["magic"] == 104400003
    assert rows[0]["preset_tf_norm"] == "H1"
    assert rows[0]["risk_fixed"] == "250"


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


def test_manifest_reconcile_uses_manifest_count_keys_magic_and_timeframe(tmp_path: Path) -> None:
    path = tmp_path / "dxz_book.json"
    path.write_text(
        json.dumps(
            {
                "book": "DXZ",
                "status": "FROZEN",
                "n_sleeves": 2,
                "sleeves": [
                    {
                        "ea_id": 10403,
                        "symbol": "XAUUSD.DWX",
                        "magic_number": 104030002,
                        "backtest_set": "QM5_10403_XAUUSD.DWX_D1_backtest.set",
                    },
                    {
                        "ea_id": 10706,
                        "symbol": "GBPUSD.DWX",
                        "magic_number": 107060001,
                        "timeframe": "H1",
                    },
                ],
            }
        ),
        encoding="utf-8",
    )
    manifest = live_book_pulse.load_book_manifest(path)
    presets = [
        {
            "ea_id": 10403,
            "symbol": "XAUUSD",
            "magic": 999,
            "preset_tf": "H1",
            "path": "wrong.set",
        }
    ]
    loaded = [{"ea_id": 10403, "symbol": "XAUUSD", "tf": "D1"}]

    result = live_book_pulse.reconcile_manifest_to_live(manifest, presets, loaded)

    assert manifest["expected_sleeve_count"] == 2
    assert manifest["sha256"]
    assert result["expected_count"] == 2
    assert [row["key"] for row in result["missing_loaded"]] == ["10706|GBPUSD"]
    assert [row["key"] for row in result["missing_presets"]] == ["10706|GBPUSD"]
    assert result["magic_mismatches"][0]["expected_magic"] == 104030002
    assert result["timeframe_mismatches"][0]["expected_tf"] == "D1"


def test_build_alarms_uses_manifest_expected_count_not_static_fallback() -> None:
    snapshot = {
        "heartbeat": {"alarm": False, "alarm_details": []},
        "terminal_journals": {"loaded_sleeve_count": 2, "account_id": "123456"},
        "book_manifest": {
            "enabled": True,
            "loaded": True,
            "status": "FROZEN",
            "declared_sleeve_count": 2,
            "actual_manifest_sleeve_count": 2,
            "expected_sleeve_count": 2,
            "duplicate_key_count": 0,
        },
        "manifest_reconcile": {
            "expected_count": 2,
            "missing_loaded": [],
            "unexpected_loaded": [],
            "missing_presets": [],
            "unexpected_presets": [],
            "magic_mismatches": [],
            "timeframe_mismatches": [],
        },
        "preset_consistency": {"mismatches": []},
    }

    alarms = live_book_pulse.build_alarms(snapshot)

    assert not [alarm for alarm in alarms if alarm["metric"] == "loaded_sleeve_count"]


def test_manifest_preset_selection_chooses_newest_matching_magic() -> None:
    manifest = {
        "loaded": True,
        "sleeves": [
            {
                "key": "10440|NDX",
                "ea_id": 10440,
                "symbol_norm": "NDX",
                "magic": 104400003,
                "live_preset_path": None,
            }
        ],
    }
    presets = [
        {
            "ea_id": 10440,
            "symbol": "NDX",
            "magic": 104400003,
            "path": "old.set",
            "modified_time_ns": 1,
            "slot": 3,
        },
        {
            "ea_id": 10440,
            "symbol": "NDX",
            "magic": 104400003,
            "path": "dxz23_live.set",
            "modified_time_ns": 2,
            "slot": 3,
        },
    ]

    result = live_book_pulse.select_manifest_presets(manifest, presets)

    assert result["selected_count"] == 1
    assert result["selected"][0]["path"] == "dxz23_live.set"
    assert result["ambiguous"][0]["chosen"] == "dxz23_live.set"
