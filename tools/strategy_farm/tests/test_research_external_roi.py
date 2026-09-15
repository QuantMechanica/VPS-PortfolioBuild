"""Tests: external-source programme ROI + origin derivation (§20/§49)."""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import external_roi as roi  # noqa: E402

_FIXED_NOW = dt.datetime(2026, 9, 15, 12, 0, 0, tzinfo=dt.timezone.utc)


# --- origin derivation (pure function) ---------------------------------------

def test_origin_precedence_card_beats_slug():
    # A card citing an external URL wins even for an internal-looking slug default.
    o, b = roi.derive_origin("some-idea", "Research", "source_citation: https://forexfactory.com/x")
    assert o == "external_source" and b == "card:external_source"
    # A card referencing QM-RESEARCH -> internal_discovery.
    o, b = roi.derive_origin("author-idea", "Research", "sources: [[sources/qm-research-2026-0002]]")
    assert o == "internal_discovery" and b == "card:internal_marker"
    # A rebuild marker in the card.
    o, b = roi.derive_origin("goldreaper", "Research", "source_citation: faithful rebuild of commercial ea")
    assert o == "commercial_rebuild" and b == "card:rebuild_marker"


def test_origin_slug_fallbacks_when_no_card():
    assert roi.derive_origin("edgelab-xsec-fx-momentum", "Research", "")[0] == "internal_discovery"
    assert roi.derive_origin("claude_cross_asset_discovery_v1", "claude", "")[0] == "internal_discovery"
    # Author-named external default.
    o, b = roi.derive_origin("carter-london-open-box", "Development", "")
    assert o == "external_source" and b == "slug:default_external"
    # OWNER mission label with no other signal.
    o, b = roi.derive_origin("", "Research+Development (OWNER commodity/energy sleeve mission)", "")
    assert o == "owner_mission" and b == "owner:mission_label"
    # No signal at all.
    assert roi.derive_origin("", "", "")[0] == "unknown"


# --- fixtures for the funnel -------------------------------------------------

def _build_db(path: Path) -> Path:
    conn = sqlite3.connect(path)
    try:
        conn.execute(
            "CREATE TABLE work_items (id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, "
            "symbol TEXT, setfile_path TEXT, status TEXT, verdict TEXT, payload_json TEXT, "
            "created_at TEXT, updated_at TEXT, data_window_start TEXT, data_window_end TEXT, "
            "evidence_path TEXT)"
        )
        rows = [
            # ext1 external, reaches Q14
            ("a1", "Q02", "QM5_2001", "PASS"),
            ("a2", "Q08", "QM5_2001", "PASS"),
            ("a3", "Q14", "QM5_2001", "MULTI_SEED_PASS"),
            # ext2 external, reaches Q08
            ("b1", "Q02", "QM5_2002", "PASS"),
            ("b2", "Q08", "QM5_2002", "PASS"),
            # int1 internal, reaches Q02 only
            ("c1", "Q02", "QM5_2003", "PASS"),
        ]
        for wid, phase, ea, verdict in rows:
            conn.execute(
                "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, status, "
                "verdict, payload_json, created_at, updated_at, data_window_start, data_window_end, "
                "evidence_path) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (wid, "backtest", phase, ea, "EURUSD.DWX", "x.set", "done", verdict, "{}",
                 "2026-01-01", "2026-01-01", "2015.01.01", "2019.12.31", ""),
            )
        conn.commit()
    finally:
        conn.close()
    return path


def _build_registry(path: Path) -> Path:
    path.write_text(
        "ea_id,slug,strategy_id,status,owner,created_at,retired_at,retired_reason,retired_evidence\n"
        "2001,carter-breakout,u1,active,Development,2026-01-01,,,\n"
        "2002,mql5-momo,u2,active,Development,2026-01-01,,,\n"
        "2003,edgelab-xsec-fx,u3,active,Research,2026-01-01,,,\n",
        encoding="utf-8",
    )
    return path


def _build_books(tmp_path):
    dxz = tmp_path / "book_dxz.json"
    ftmo = tmp_path / "book_ftmo.json"
    dxz.write_text(json.dumps({"incumbent": {"sleeves": [{"ea_id": 2001, "symbol": "EURUSD.DWX"}]}}), encoding="utf-8")
    ftmo.write_text(json.dumps({"incumbent": {"sleeves": []}}), encoding="utf-8")
    return dxz, ftmo


def _build_seed_sources(tmp_path):
    base = tmp_path / "seeds_sources"
    (base / "forexfactory-systems").mkdir(parents=True)
    (base / "some-blog").mkdir()
    (base / "QM-RESEARCH-2026-0001").mkdir()
    return base


def _inputs(tmp_path):
    db = _build_db(tmp_path / "farm_state.sqlite")
    reg = _build_registry(tmp_path / "reg.csv")
    dxz, ftmo = _build_books(tmp_path)
    seeds = _build_seed_sources(tmp_path)
    return db, reg, dxz, ftmo, seeds


def _build(tmp_path, db, reg, dxz, ftmo, seeds):
    origin_rows = roi.build_origin_table(reg, card_dirs=[tmp_path / "no_cards"])
    return roi.build_roi(
        db, registry_path=reg, card_dirs=[tmp_path / "no_cards"],
        seed_sources_dir=seeds, book_dxz_path=dxz, book_ftmo_path=ftmo,
        origin_rows=origin_rows, now=_FIXED_NOW,
    ), origin_rows


def _model(tmp_path):
    db, reg, dxz, ftmo, seeds = _inputs(tmp_path)
    return _build(tmp_path, db, reg, dxz, ftmo, seeds)


def test_origin_table_and_distribution(tmp_path):
    _, origin_rows = _model(tmp_path)
    by = {r["ea_id"]: r["origin_programme"] for r in origin_rows}
    assert by["QM5_2001"] == "external_source"
    assert by["QM5_2002"] == "external_source"
    assert by["QM5_2003"] == "internal_discovery"


def test_funnel_arithmetic(tmp_path):
    m, _ = _model(tmp_path)
    prog = {p["origin_programme"]: p for p in m["programmes"]}
    ext = prog["external_source"]["funnel"]
    assert ext["registry_eas"] == 2
    assert ext["reached_q02"] == 2
    assert ext["reached_q08"] == 2
    assert ext["reached_q14"] == 1
    assert ext["in_dxz_book"] == 1
    intl = prog["internal_discovery"]["funnel"]
    assert intl["registry_eas"] == 1
    assert intl["reached_q02"] == 1
    assert intl["reached_q08"] == 0
    assert intl["reached_q14"] == 0
    # yield admit/Q02 for external = 1 admitted / 2 q02 = 50%
    assert prog["external_source"]["yield_admit_per_q02_pct"] == 50.0
    # economic contribution honestly EVIDENCE_MISSING
    assert prog["external_source"]["economic_contribution"]["pnl"] == "EVIDENCE_MISSING"


def test_sources_considered(tmp_path):
    m, _ = _model(tmp_path)
    sc = m["sources_considered"]
    assert sc["external_seed_dirs"] == 2
    assert sc["internal_research_artifacts"] == 1


def test_origin_sidecar_written_and_shape(tmp_path):
    m, origin_rows = _model(tmp_path)
    out = tmp_path / "ea_origin.v1.csv"
    roi.write_origin_sidecar(origin_rows, out)
    text = out.read_text(encoding="utf-8")
    assert text.startswith("ea_id,slug,origin_programme,basis,has_card")
    assert "QM5_2003,edgelab-xsec-fx,internal_discovery" in text


def test_idempotent_byte_identical(tmp_path):
    db, reg, dxz, ftmo, seeds = _inputs(tmp_path)
    m1, _ = _build(tmp_path, db, reg, dxz, ftmo, seeds)
    m2, _ = _build(tmp_path, db, reg, dxz, ftmo, seeds)
    assert json.dumps(m1, sort_keys=True) == json.dumps(m2, sort_keys=True)
    assert m1["inputs_sha256"] == m2["inputs_sha256"]


def test_schema_and_totals(tmp_path):
    m, _ = _model(tmp_path)
    assert m["schema"] == "qm.research-roi/v1"
    assert m["totals"]["registry_eas"] == 3
    assert m["totals"]["dxz_book_eas"] == 1
