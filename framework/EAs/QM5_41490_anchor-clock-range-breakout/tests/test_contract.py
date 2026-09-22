from __future__ import annotations

import csv
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE = EA_DIR / "QM5_41490_anchor-clock-range-breakout.mq5"
SETS_DIR = EA_DIR / "sets"


EXPECTED_CELLS = {
    "QM5_41490_anchor-clock-range-breakout_NZDJPY.DWX_M30_A2_backtest.set": {
        "cell": "A2",
        "symbol": "NZDJPY.DWX",
        "qm_magic_slot_offset": "1",
        "strategy_range_start_hour": "4",
        "strategy_range_bars": "2",
    },
    "QM5_41490_anchor-clock-range-breakout_USDJPY.DWX_M30_A3_backtest.set": {
        "cell": "A3",
        "symbol": "USDJPY.DWX",
        "qm_magic_slot_offset": "0",
        "strategy_range_start_hour": "3",
        "strategy_range_bars": "3",
    },
    "QM5_41490_anchor-clock-range-breakout_USDJPY.DWX_M30_A4_backtest.set": {
        "cell": "A4",
        "symbol": "USDJPY.DWX",
        "qm_magic_slot_offset": "0",
        "strategy_range_start_hour": "2",
        "strategy_range_bars": "4",
    },
}


COMMON_INPUTS = {
    "qm_ea_id": "41490",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "PORTFOLIO_WEIGHT": "1",
    "qm_news_temporal": "3",
    "qm_news_compliance": "1",
    "qm_news_stale_max_hours": "336",
    "anchor_clock": "1",
    "strategy_range_start_minute": "0",
    "strategy_range_end_hour": "6",
    "strategy_range_end_minute": "0",
    "strategy_flat_hour": "18",
    "strategy_flat_minute": "0",
    "strategy_grid_offset_minutes": "0",
    "strategy_news_retry_window_minutes": "60",
    "strategy_atr_period": "14",
    "strategy_min_range_atr_mult": "0.4",
    "strategy_max_range_atr_mult": "2.5",
    "strategy_trail_trigger_r": "1.0",
    "strategy_range_scan_bars": "36",
}


def _parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    metadata: dict[str, str] = {}
    inputs: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if line.startswith(";") and ":" in line:
            key, value = line[1:].split(":", 1)
            metadata[key.strip()] = value.strip()
        elif line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            inputs[key.strip()] = value.strip()
    return metadata, inputs


def _first_sunday(year: int, month: int) -> datetime:
    first = datetime(year, month, 1, tzinfo=timezone.utc)
    # Python Monday=0; MQL Sunday=0. This expression returns days to Sunday.
    return first + timedelta(days=(6 - first.weekday()) % 7)


def _second_sunday(year: int, month: int) -> datetime:
    return _first_sunday(year, month) + timedelta(days=7)


def _broker_offset_hours_for_utc(utc_time: datetime) -> int:
    # Exact policy in QM_DSTAware.mqh: US DST from 07:00 UTC on the second
    # Sunday in March to 06:00 UTC on the first Sunday in November.
    start = _second_sunday(utc_time.year, 3).replace(hour=7)
    end = _first_sunday(utc_time.year, 11).replace(hour=6)
    return 3 if start <= utc_time < end else 2


def _gmt3_clock_to_broker(clock_time: datetime) -> datetime:
    utc_time = clock_time - timedelta(hours=3)
    return utc_time + timedelta(hours=_broker_offset_hours_for_utc(utc_time))


def test_exact_three_cell_presets_and_safety_rails() -> None:
    actual = {path.name for path in SETS_DIR.glob("*.set")}
    assert actual == set(EXPECTED_CELLS)

    for filename, expected in EXPECTED_CELLS.items():
        metadata, inputs = _parse_setfile(SETS_DIR / filename)
        assert metadata["cell"] == expected["cell"]
        assert metadata["symbol"] == expected["symbol"]
        assert re.fullmatch(r"[0-9a-f]{64}", metadata["build_hash"])
        for key, value in COMMON_INPUTS.items():
            assert inputs[key] == value, f"{filename}: {key}"
        for key in ("qm_magic_slot_offset", "strategy_range_start_hour", "strategy_range_bars"):
            assert inputs[key] == expected[key], f"{filename}: {key}"


def test_clock_enum_uses_framework_utc_helpers_without_cell_freeze() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    assert "SERVER_RAW = 0" in source
    assert "GMT3_EQUIVALENT = 1" in source
    assert "UTC = 2" in source
    assert "QM_BrokerToUTC(broker_time)" in source
    assert "QM_UTCToBroker(utc_time)" in source
    assert 'QM_LogEvent(QM_INFO, "INIT_OK", "{}")' in source
    assert "qm_news_stale_max_hours > 336" in source
    assert ".DWX" not in source

    on_init = source.split("int OnInit()", 1)[1].split("void OnDeinit", 1)[0]
    assert "GMT3_EQUIVALENT" not in on_init
    for field in (
        "strategy_range_start_hour",
        "strategy_range_start_minute",
        "strategy_range_end_hour",
        "strategy_range_end_minute",
        "strategy_flat_hour",
        "strategy_flat_minute",
        "strategy_grid_offset_minutes",
        "strategy_range_bars",
    ):
        assert field in on_init


def test_gmt3_projection_matches_dxz_winter_and_summer() -> None:
    winter_anchor = datetime(2024, 1, 15, 6, tzinfo=timezone.utc)
    winter_flat = winter_anchor.replace(hour=18)
    summer_anchor = datetime(2024, 7, 15, 6, tzinfo=timezone.utc)
    summer_flat = summer_anchor.replace(hour=18)

    assert _gmt3_clock_to_broker(winter_anchor).hour == 5
    assert _gmt3_clock_to_broker(winter_flat).hour == 17
    assert _gmt3_clock_to_broker(summer_anchor).hour == 6
    assert _gmt3_clock_to_broker(summer_flat).hour == 18


def test_identity_and_magic_registry_bindings() -> None:
    with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        identities = [row for row in csv.DictReader(handle) if row["ea_id"] == "41490"]
    assert len(identities) == 1
    assert identities[0]["slug"] == "anchor-clock-range-breakout"
    assert identities[0]["strategy_id"] == "QM-RESEARCH-2026-0013"
    assert identities[0]["status"] == "active"

    with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "41490"]
    actual = {
        (int(row["symbol_slot"]), row["symbol"], int(row["magic"]), row["status"])
        for row in rows
    }
    assert actual == {
        (0, "USDJPY.DWX", 414900000, "active"),
        (1, "NZDJPY.DWX", 414900001, "active"),
        (2, "EURUSD.DWX", 414900002, "active"),
    }
