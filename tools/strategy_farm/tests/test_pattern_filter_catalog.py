"""Tests: pattern & filter catalog (§22/§40) — inventory, census join, determinism."""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import pattern_filter_catalog as pfc  # noqa: E402

_FIXED_NOW = dt.datetime(2026, 9, 15, 12, 0, 0, tzinfo=dt.timezone.utc)

MQH = pfc.DEFAULT_MQH  # the real framework header (read-only)


# --- inventory ---------------------------------------------------------------
def test_parses_all_implemented_predicates_with_category():
    text = MQH.read_text(encoding="utf-8")
    preds = pfc.parse_pattern_predicates(text)
    # 77 implemented predicates (QM_PP_NONE excluded).
    assert len(preds) == 77
    # Every predicate must be classified — no UNCLASSIFIED leaks (§40 taxonomy).
    unclassified = [p["predicate_id"] for p in preds if p["category"] == "UNCLASSIFIED"]
    assert unclassified == [], f"unmapped predicate ids: {unclassified}"
    # Categories are drawn only from the §40 taxonomy.
    allowed = {"price-action", "trend", "volatility", "news", "session", "regime", "time"}
    assert {p["category"] for p in preds} <= allowed


def test_category_map_covers_every_enum_id():
    """Pin: CATEGORY_MAP has an entry for every implemented enum id and no extras."""
    text = MQH.read_text(encoding="utf-8")
    preds = pfc.parse_pattern_predicates(text)
    enum_ids = {p["predicate_id"] for p in preds}
    assert enum_ids == set(pfc.CATEGORY_MAP), (
        f"map drift: only_in_enum={sorted(enum_ids - set(pfc.CATEGORY_MAP))} "
        f"only_in_map={sorted(set(pfc.CATEGORY_MAP) - enum_ids)}"
    )


def test_unger_ids_are_real_predicates():
    text = MQH.read_text(encoding="utf-8")
    ids = {p["predicate_id"] for p in pfc.parse_pattern_predicates(text)}
    assert pfc.UNGER_RELATED_IDS <= ids


def test_filter_modules_present_and_mechanical():
    for m in pfc.FILTER_MODULE_INVENTORY:
        assert m["mechanical"] is True
        assert m["category"] in {"news", "regime", "volatility", "price-action"}
        assert m["parameters"]


# --- census join -------------------------------------------------------------
def _build_db(path: Path) -> Path:
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE work_items (id TEXT PRIMARY KEY, kind TEXT, phase TEXT, "
        "ea_id TEXT, symbol TEXT, status TEXT, verdict TEXT, payload_json TEXT)"
    )
    conn.execute(
        "CREATE TABLE ea_metrics (work_item_id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, "
        "symbol TEXT, verdict TEXT, status TEXT, net_profit REAL, profit_factor REAL, "
        "trades INTEGER, drawdown_money REAL, drawdown_pct REAL)"
    )

    def _cell(wid, prog, year, arm, direction, pid, net, trades, dd, verdict="MEASURED"):
        payload = json.dumps(
            {"program_id": prog, "year": year, "arm": arm, "direction": direction, "predicate_id": pid}
        )
        conn.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, status, verdict, payload_json) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (wid, "backtest", "OPT_CENSUS", prog, "USDJPY.DWX", "done", verdict, payload),
        )
        conn.execute(
            "INSERT INTO ea_metrics (work_item_id, ea_id, phase, symbol, verdict, status, "
            "net_profit, profit_factor, trades, drawdown_money, drawdown_pct) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (wid, prog, "OPT_CENSUS", "USDJPY.DWX", verdict, "done", net, 1.2, trades, dd, 5.0),
        )

    # One program, one year, a baseline + two predicate arms.
    # baseline: net 1000, 100 trades, dd 500  -> rtmdd = 2.0, exp = 10
    _cell("b1", "PROG_A", 2020, "baseline", "NONE", 0, 1000.0, 100, 500.0)
    # buy_003: net 1200, 80 trades, dd 500 -> rtmdd 2.4 (rel +20% -> improved), trd red 20%
    _cell("a1", "PROG_A", 2020, "buy_003", "BUY", 3, 1200.0, 80, 500.0)
    # sell_006: net 900, 90 trades, dd 500 -> rtmdd 1.8 (rel -10% -> no_change_or_worse)
    _cell("a2", "PROG_A", 2020, "sell_006", "SELL", 6, 900.0, 90, 500.0)
    # a SKIPPED cell must be ignored by the join.
    _cell("s1", "PROG_A", 2020, "buy_004", "BUY", 4, 0.0, 0, 0.0, verdict="SKIPPED_EXCLUDED")
    conn.commit()
    conn.close()
    return path


def test_census_join_computes_deltas(tmp_path):
    db = _build_db(tmp_path / "farm.sqlite")
    conn = pfc._connect_ro(db)
    try:
        census = pfc.load_census_join(conn)
    finally:
        conn.close()
    assert census["status"] == "OK"
    assert census["measured_cells_total"] == 2  # buy_003 + sell_006 (SKIPPED excluded)
    assert census["baseline_cells_total"] == 1
    pp = census["per_predicate"]
    assert pp["3"]["improved_cells_ge_5pct_rtmdd"] == 1
    assert pp["3"]["mean_trade_reduction_pct"] == 20.0
    assert pp["3"]["mean_expectancy_delta"] == 5.0  # 15 - 10
    assert pp["6"]["no_change_or_worse_cells"] == 1


def test_census_missing_is_explicit(tmp_path):
    # Empty DB (tables exist, no rows) -> EVIDENCE_MISSING, not a crash.
    db = tmp_path / "empty.sqlite"
    conn = sqlite3.connect(db)
    conn.execute("CREATE TABLE work_items (id TEXT, phase TEXT, status TEXT, payload_json TEXT)")
    conn.execute("CREATE TABLE ea_metrics (work_item_id TEXT, verdict TEXT)")
    conn.commit()
    conn.close()
    conn = pfc._connect_ro(db)
    try:
        census = pfc.load_census_join(conn)
    finally:
        conn.close()
    assert census["status"] == "EVIDENCE_MISSING"


# --- selection receipts ------------------------------------------------------
def test_selection_receipts_tally(tmp_path):
    art = tmp_path / "opt_census"
    p1 = art / "DL089_QM5_1_USDJPY_DWX_2019_2025"
    p2 = art / "DL089_QM5_2_EURUSD_DWX_2019_2025"
    p1.mkdir(parents=True)
    p2.mkdir(parents=True)
    (p1 / "q12_selection_receipt.json").write_text(
        json.dumps({"verdict": "NO_FILTER_CHANGE", "final_selection": {"BUY": [], "SELL": []}}),
        encoding="utf-8",
    )
    (p2 / "q12_selection_receipt.json").write_text(
        json.dumps({"verdict": "FILTER_SELECTED", "final_selection": {"BUY": [3], "SELL": [6, 10]}}),
        encoding="utf-8",
    )
    sel = pfc.load_selection_receipts(art)
    assert sel["status"] == "OK"
    assert sel["programs_evaluated"] == 2
    assert sel["verdict_distribution"]["NO_FILTER_CHANGE"] == 1
    assert sel["per_predicate_selected"]["3"]["times_selected_buy"] == 1
    assert sel["per_predicate_selected"]["6"]["times_selected_sell"] == 1


def test_selection_missing_is_explicit(tmp_path):
    sel = pfc.load_selection_receipts(tmp_path / "nope")
    assert sel["status"] == "EVIDENCE_MISSING"


# --- full model + determinism ------------------------------------------------
def test_build_and_render_deterministic(tmp_path):
    db = _build_db(tmp_path / "farm.sqlite")
    kw = dict(mqh_path=MQH, db_path=db, census_artifacts=tmp_path / "no_art", now=_FIXED_NOW)
    m1 = pfc.build_catalog(**kw)
    m2 = pfc.build_catalog(**kw)
    assert json.dumps(m1, sort_keys=True) == json.dumps(m2, sort_keys=True)
    assert m1["counts"]["predicates_total"] == 77
    assert m1["pattern_filter_cap_per_direction"] == 3
    # census present, selection missing -> explicit token on rows
    assert m1["historical_census"]["status"] == "OK"
    assert m1["historical_selection"]["status"] == "EVIDENCE_MISSING"
    doc = pfc.render_doc(m1)
    assert "Pattern & Filter Catalog" in doc
    assert "max N filters" in doc
    vault = pfc.render_vault(m1)
    assert "generated: true" in vault
    # write_outputs skips vault cleanly when told NONE
    written = pfc.write_outputs(
        m1, tmp_path / "out.json", tmp_path / "out.md", None
    )
    assert any(w.endswith("out.json") for w in written)


def test_max_n_disposition_is_selection_not_hard_rule(tmp_path):
    m = pfc.build_catalog(
        mqh_path=MQH, db_path=tmp_path / "absent.sqlite",
        census_artifacts=tmp_path / "absent", now=_FIXED_NOW,
    )
    d = m["max_n_filters_disposition"]
    assert "SELECTION rule" in d["classification"]
    assert "§30" in d["recommendation"]
    # DB absent -> census EVIDENCE_MISSING, not a crash
    assert m["historical_census"]["status"] == "EVIDENCE_MISSING"
