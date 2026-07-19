from __future__ import annotations

import csv
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
REGISTRY = REPO / "framework" / "registry" / "ea_id_registry.csv"
MAGICS = REPO / "framework" / "registry" / "magic_numbers.csv"
EAS = REPO / "framework" / "EAs"
RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def test_intraday_engine_is_rekeyed_without_reusing_progo_identity() -> None:
    registry = _rows(REGISTRY)
    active_12784 = {
        row["slug"]
        for row in registry
        if row["ea_id"] == "12784" and row["status"].lower() == "active"
    }
    active_20007 = {
        row["slug"]
        for row in registry
        if row["ea_id"] == "20007" and row["status"].lower() == "active"
    }
    assert active_12784 == {"progo-xti"}
    assert active_20007 == {"intraday-config-engine"}

    magics = _rows(MAGICS)
    active_old = {
        (row["ea_slug"], row["symbol_slot"], row["magic"])
        for row in magics
        if row["ea_id"] == "12784" and row["status"].lower() == "active"
    }
    active_new = {
        (row["symbol"], row["symbol_slot"], row["magic"])
        for row in magics
        if row["ea_id"] == "20007" and row["status"].lower() == "active"
    }
    assert active_old == {("progo-xti", "0", "127840000")}
    assert active_new == {
        ("GDAXI.DWX", "0", "200070000"),
        ("NDX.DWX", "1", "200070001"),
        ("SP500.DWX", "2", "200070002"),
        ("XAUUSD.DWX", "3", "200070003"),
    }


def test_rekey_preserves_old_binary_but_new_identity_has_no_stale_ex5() -> None:
    obsolete = EAS / "_obsolete_QM5_12784_intraday-config-engine_pre-rekey"
    current = EAS / "QM5_20007_intraday-config-engine"
    assert (obsolete / "QM5_12784_intraday-config-engine.ex5").is_file()
    assert not (current / "QM5_20007_intraday-config-engine.ex5").exists()

    source = (current / "QM5_20007_intraday-config-engine.mq5").read_text(
        encoding="utf-8"
    )
    assert re.search(r"qm_ea_id\s*=\s*20007;", source)
    assert '"ea":"QM5_20007"' in source.replace("\\\"", '"')

    expected_slots = {
        "GDAXI.DWX": 0,
        "NDX.DWX": 1,
        "SP500.DWX": 2,
        "XAUUSD.DWX": 3,
    }
    for symbol, slot in expected_slots.items():
        setfile = current / "sets" / (
            f"QM5_20007_intraday-config-engine_{symbol}_M15_backtest.set"
        )
        content = setfile.read_text(encoding="utf-8")
        assert "; ea_id:        20007" in content
        assert f"; magic_slot:   {slot}" in content
        assert f"qm_magic_slot_offset={slot}" in content


def test_generated_resolver_contains_only_new_intraday_magic_block() -> None:
    source = RESOLVER.read_text(encoding="utf-8")
    assert "200070000" in source
    assert "200070001" in source
    assert "200070002" in source
    assert "200070003" in source
    assert "127840000" in source
    for retired in range(127840001, 127840005):
        assert str(retired) not in source
