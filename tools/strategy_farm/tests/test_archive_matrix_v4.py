from __future__ import annotations

import re
import sqlite3
from pathlib import Path

from tools.strategy_farm import gate_manifest
from tools.strategy_farm import operator_surfaces
from tools.strategy_farm.dashboards import archive_matrix as archive


DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
    setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
    parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT, payload_json TEXT,
    created_at TEXT, updated_at TEXT, gate_contract_version TEXT
)
"""


def _insert(
    con: sqlite3.Connection,
    row_id: str,
    ea: str,
    phase: str,
    verdict: str,
    *,
    version: str = "v3",
    symbol: str = "EURUSD.DWX",
    updated: str = "2026-08-23T10:00:00Z",
) -> None:
    status = "failed" if verdict in {"INFRA_FAIL", "INVALID", "SUPERSEDED"} else "done"
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (row_id, "backtest", phase, ea, symbol, "x.set", status, verdict, 0,
         None, None, None, "{}", updated, updated, version),
    )


def _fixture(path: Path) -> Path:
    with sqlite3.connect(path) as con:
        con.execute(DDL)
        for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"):
            _insert(con, f"mixed-{phase}", "QM5_900001", phase, "PASS")
        _insert(con, "mixed-v3-q10", "QM5_900001", "Q10", "PASS")
        _insert(con, "mixed-v4-news", "QM5_900001", "Q10_NEWS", "PASS", version="v4")
        _insert(con, "mixed-v4-q17", "QM5_900001", "Q17", "PASS", version="v4")

        for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"):
            _insert(con, f"portfolio-{phase}", "QM5_900002", phase, "PASS")
        _insert(con, "portfolio-only", "QM5_900002", "Q09_PORTFOLIO", "PASS_PORTFOLIO")

        _insert(con, "econ-q02", "QM5_900003", "Q02", "PASS")
        _insert(con, "econ-q03", "QM5_900003", "Q03", "FAIL")

        _insert(con, "latest-pass", "QM5_900004", "Q02", "PASS", updated="2026-08-22T09:00:00Z")
        _insert(con, "latest-stale", "QM5_900004", "Q02", "SUPERSEDED")

        _insert(con, "infra-q02", "QM5_900005", "Q02", "INFRA_FAIL")
        _insert(con, "na-q02", "QM5_900006", "Q02", "OBSOLETE_NON_DWX_SYMBOL")
    return path


def _cell(data: dict, ea: str, symbol: str, gate: str) -> dict:
    card = next(item for item in data["cards"] if item["ea"] == ea)
    symbol_index = card["symbols"].index(symbol)
    return next(item for item in card["cells"][gate]
                if item["symbol_index"] == symbol_index)


def test_manifest_columns_preserve_active_v3_order_and_render_v4_terminal() -> None:
    active = archive.build_archive_columns()
    assert [column.gate_id for column in active] == [
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10",
        "Q14", "Q15", "Q16", "Q11", "Q12", "Q13",
    ]

    v4 = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    assert [column.gate_id for column in archive.build_archive_columns(v4)] == [
        f"Q{i:02d}" for i in range(2, 18)
    ]
    source = Path(archive.__file__).read_text(encoding="utf-8")
    assert re.search(r"\b(?:COLUMNS|ORDINARY|GATE_IDX)\b", source) is None
    assert "Q10." + "1" not in source


def test_contract_resolution_planner_holes_stop_and_tooltips(
    tmp_path: Path, monkeypatch
) -> None:
    assert archive.resolved_gate("Q10", "v3") == "Q10"
    assert archive.resolved_gate("Q10", "v4") == "Q09"
    db = _fixture(tmp_path / "farm.sqlite")
    monkeypatch.setattr(archive, "BACKFILL_PLAN", tmp_path / "absent.csv")
    monkeypatch.setattr(archive, "_card_metadata", lambda: {
        "targets": {"QM5_900001": ["EURUSD.DWX", "GBPUSD.DWX"]},
        "universes": {"QM5_900001": ["EURUSD.DWX", "GBPUSD.DWX"]},
        "buckets": {"QM5_900001": "cards_approved"},
    })

    data = archive.collect(db)

    v3_incumbent = _cell(data, "QM5_900001", "EURUSD.DWX", "Q10")
    v4_news = _cell(data, "QM5_900001", "EURUSD.DWX", "Q09")
    v4_terminal = _cell(data, "QM5_900001", "EURUSD.DWX", "Q13")
    assert "mixed-v3-q10" in v3_incumbent["title"]
    assert "(v4:Q10_NEWS)" in v4_news["title"]
    assert "(v4:Q17)" in v4_terminal["title"]

    news_gap = _cell(data, "QM5_900002", "EURUSD.DWX", "Q09")
    assert news_gap["state"] == archive.ST_HOLE
    assert news_gap["action"] == "FILL_MISSING"
    assert not any(
        item["state"] == archive.ST_HOLE
        for item in next(card for card in data["cards"] if card["ea"] == "QM5_900002")
        ["cells"].get("Q10", [])
    )

    economic = _cell(data, "QM5_900003", "EURUSD.DWX", "Q03")
    assert economic["state"] == archive.ST_FAIL
    assert economic["action"] == "STOP_ECONOMIC_FAIL"

    latest_row_gap = _cell(data, "QM5_900004", "EURUSD.DWX", "Q03")
    assert latest_row_gap["state"] == archive.ST_HOLE
    assert latest_row_gap["action"] == "FILL_MISSING"
    assert next(card for card in data["cards"] if card["ea"] == "QM5_900004")["hp"] == 0

    infra = _cell(data, "QM5_900005", "EURUSD.DWX", "Q02")
    assert infra["state"] == archive.ST_HOLE
    assert infra["action"] == "RERUN_INFRA"
    assert all(token in infra["title"] for token in (
        "verdict=INFRA_FAIL", "date=2026-08-23", "work_item_id=infra-q02",
        "action=RERUN_INFRA",
    ))

    card_target = _cell(data, "QM5_900001", "GBPUSD.DWX", "Q02")
    assert card_target["state"] == archive.ST_CARD_HOLE
    assert "nie getestet (Card-Ziel)" in card_target["title"]

    not_applicable = next(card for card in data["cards"] if card["ea"] == "QM5_900006")
    assert not not_applicable["cells"].get("Q02")
    assert not_applicable["empty_reasons"]["Q02"][0]["reason"] == (
        "not applicable under the planner contract"
    )

    rendered = archive.render_matrix_page(data)
    owner_gates = {column.gate_id for column in data["columns"] if column.owner_manual}
    assert not any(
        cell["state"] == archive.ST_HOLE
        for card in data["cards"] for gate in owner_gates
        for cell in card["cells"].get(gate, [])
    )
    assert "Buch/Betrieb (OWNER)" in rendered
    assert "OWNER/manual · no gap chips" in rendered
    assert "nie getestet (Card-Ziel): no work_items row" in rendered
    assert re.search(r"\bP[0-9]", rendered) is None
    assert "verdict=INFRA_FAIL" in rendered
    assert "work_item_id=infra-q02" in rendered


def test_detail_page_gate_labels_keep_contract_provenance(
    tmp_path: Path, monkeypatch
) -> None:
    db = _fixture(tmp_path / "farm.sqlite")
    monkeypatch.setattr(archive, "_RUNS_BY_DB", {})
    monkeypatch.setattr(archive, "reports_for", lambda _work_item_id: [])

    items = archive.runs_for_ea("QM5_900001", db)
    rendered = archive.render_backtests_section(items)

    assert "Q09_NEWS (v4:Q10_NEWS)" in rendered
    assert "Q13 Live Burn-In DXZ (v4:Q17)" in rendered
    assert "Q10 Incumbent Full-History Confirmation" in rendered


def test_shared_frontier_model_uses_governed_plan_action(tmp_path: Path) -> None:
    db = _fixture(tmp_path / "farm.sqlite")
    plan = tmp_path / "plan.csv"
    plan.write_text(
        "record_type,ea_id,symbol,action,reason,target_gate,highest_contiguous_valid_gate\n"
        "PAIR,QM5_900005,EURUSD.DWX,REBIND_STALE,governed-fixture,Q02,\n",
        encoding="utf-8",
    )

    rows = operator_surfaces.build_pair_frontier_rows(db, backfill_plan_path=plan)
    row = next(item for item in rows if item["ea_id"] == "QM5_900005")

    assert row["backfill_action"] == "REBIND_STALE"
    assert row["backfill_action_reason"] == "governed-fixture"
    assert row["earliest_missing_prerequisite"] == "Q02"
