from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_12954_pring-coppock-h4-variant"
SOURCE = EA_DIR / "QM5_12954_pring-coppock-h4-variant.mq5"
CARD_COPY = EA_DIR / "docs" / "strategy_card.md"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("GDAXI.DWX", 129540000),
    1: ("NDX.DWX", 129540001),
    2: ("SP500.DWX", 129540002),
    3: ("UK100.DWX", 129540003),
    4: ("WS30.DWX", 129540004),
    5: ("XAUUSD.DWX", 129540005),
    6: ("EURUSD.DWX", 129540006),
    7: ("GBPUSD.DWX", 129540007),
    8: ("USDJPY.DWX", 129540008),
    9: ("USDCHF.DWX", 129540009),
    10: ("AUDUSD.DWX", 129540010),
    11: ("USDCAD.DWX", 129540011),
    12: ("NZDUSD.DWX", 129540012),
}


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_approved_card_copy_and_identity_are_bound() -> None:
    card = CARD_COPY.read_text(encoding="utf-8")
    assert re.search(r"(?m)^ea_id:\s*QM5_12954\s*$", card)
    assert re.search(r"(?m)^slug:\s*pring-coppock-h4-variant\s*$", card)
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)
    for gate in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden"):
        assert re.search(rf"(?m)^{gate}:\s*PASS\s*$", card)


def test_source_implements_the_approved_mechanical_contract() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "TODO" not in source
    assert "Unknown Strategy" not in source
    assert "Strategy_CoppockROC" in source
    assert "Strategy_CoppockValue" in source
    assert "(g_coppock_prev <= 0.0 && g_coppock_last > 0.0)" in source
    assert "(g_coppock_prev >= 0.0 && g_coppock_last < 0.0)" in source
    assert "MathMin(strategy_sl_atr_mult, strategy_sl_atr_cap)" in source
    assert "strategy_time_stop_bars      = 200" in source
    assert "strategy_warmup_bars         = 35" in source
    assert "strategy_max_spread_atr      = 0.25" in source
    assert "strategy_be_trigger_atr      = 2.0" in source
    assert "req.tp = 0.0" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "ZeroMemory(req);" in source
    assert "_Period != PERIOD_H4" in source
    assert "qm_news_stale_max_hours > 336" in source


def test_magic_registry_matches_the_exact_build_universe() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "12954" and row["status"].lower() == "active"
        ]

    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS


def test_backtest_sets_bind_source_hash_risk_news_and_slots() -> None:
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    set_paths = sorted(SETS.glob("*.set"))
    assert len(set_paths) == len(EXPECTED_SLOTS)

    expected_names: set[str] = set()
    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        name = f"QM5_12954_pring-coppock-h4-variant_{symbol}_H4_backtest.set"
        expected_names.add(name)
        path = SETS / name
        assert path.is_file()

        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert "; timeframe:    H4" in text
        assert "; environment:  backtest" in text
        assert values["qm_ea_id"] == "12954"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert float(values["RISK_FIXED"]) > 0.0
        assert float(values["RISK_PERCENT"]) == 0.0
        assert values["qm_news_temporal"] == "3"
        assert values["qm_news_compliance"] == "1"
        assert int(values["qm_news_stale_max_hours"]) == 336
        assert values["strategy_roc_short_period"] == "11"
        assert values["strategy_roc_long_period"] == "14"
        assert values["strategy_wma_period"] == "10"
        assert values["strategy_atr_period"] == "20"

    assert {path.name for path in set_paths} == expected_names
