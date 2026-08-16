from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_1537_aa-vol-sma10.mq5"
LOADER = EA_DIR / "QM5_1537_MonthlySleeveCalendar.mqh"
CALENDAR = EA_DIR / "calendar" / "QM5_1537_monthly_sleeves_v1.csv"
MANIFEST = EA_DIR / "calendar" / "QM5_1537_monthly_sleeves_v1.manifest.json"
EQUIVALENCE = EA_DIR / "calendar" / "QM5_1537_equivalence_201807_202212.json"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def test_generated_artifacts_are_hash_bound_and_equivalent() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    equivalence = json.loads(EQUIVALENCE.read_text(encoding="utf-8"))
    assert _sha(CALENDAR) == manifest["calendar_sha256"]
    assert equivalence["status"] == "PASS"
    assert equivalence["failure_count"] == 0
    assert equivalence["host_months_compared"] == 1986
    assert equivalence["calendar_sha256"] == manifest["calendar_sha256"]
    assert equivalence["legacy_source_sha256"] == (
        "97E76AA58FA00F61360A9F6F251E36D6338474F3DE333351C7A7C3997526A073"
    )


def test_calendar_has_unique_host_month_rows_and_consistent_selection() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    seen: set[tuple[int, str]] = set()
    rows = 0
    with CALENDAR.open(encoding="ascii", newline="") as handle:
        for row in csv.DictReader(handle):
            key = (int(row["month_key"]), row["host_symbol"])
            assert key not in seen
            seen.add(key)
            assert row["contract_sha256"] == manifest["ranking_contract_sha256"]
            assert row["input_bundle_sha256"] == manifest["input_bundle_sha256"]
            selected = row["host_symbol"] in {
                row["selected_1"], row["selected_2"], row["selected_3"]
            }
            assert int(row["selected"]) == int(selected)
            rows += 1
    assert rows == manifest["row_count"] == 3546


def test_runtime_source_has_no_foreign_history_fanout_and_fails_closed() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    loader = LOADER.read_text(encoding="utf-8-sig")
    assert "CopyClose(" not in source
    assert "SymbolSelect(" not in source
    assert "QM_BasketWarmupHistory" not in source
    assert "QM_SymbolGuardInit(g_strategy_basket)" not in source
    assert "Strategy_LoadBoundMonthlySleeveCalendar" in source
    assert "return INIT_FAILED" in source
    assert "FILE_COMMON" in loader
    assert "runtime_calendar_sha256_mismatch" in loader
    assert "ranking_contract_sha256_mismatch" in loader
    assert "runtime_calendar_row_binding_mismatch" in loader
    assert "MONTHLY_SLEEVE_STATE" in source
    assert "SLEEVE_REJECTION_SUMMARY" in source


def test_every_ranking_input_is_part_of_runtime_contract_payload() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    loader = LOADER.read_text(encoding="utf-8-sig")
    ranking_inputs = {
        "strategy_min_daily_bars",
        "strategy_vol_lookback_days",
        "strategy_vol_annualization_days",
        "strategy_top_symbols",
    }
    for name in ranking_inputs:
        assert re.search(rf"\b{name}\b", loader)
    assert "universe += g_strategy_basket[i]" in loader
    assert "basket_slot_ascending" in loader
    assert "first_host_d1_bar_of_calendar_month" in loader
    assert "req.symbol_slot = qm_magic_slot_offset" in source
