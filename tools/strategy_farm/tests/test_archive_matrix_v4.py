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


def test_manifest_columns_are_active_v4_linear_and_v3_pins_v3_order() -> None:
    # v4 is the ACTIVE contract the factory runs: the ambient columns are the
    # linear Q02..Q17 topology.
    active = archive.build_archive_columns()
    assert [column.gate_id for column in active] == [
        f"Q{i:02d}" for i in range(2, 18)
    ]

    # Pinning the v3 manifest explicitly still yields the v3 fork order — the
    # topology is manifest-derived, not ambient-only.
    v3 = gate_manifest.load_gate_manifest(gate_manifest.V3_MANIFEST)
    assert [column.gate_id for column in archive.build_archive_columns(v3)] == [
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10",
        "Q14", "Q15", "Q16", "Q11", "Q12", "Q13",
    ]
    source = Path(archive.__file__).read_text(encoding="utf-8")
    assert re.search(r"\b(?:COLUMNS|ORDINARY|GATE_IDX)\b", source) is None
    assert "Q10." + "1" not in source


def test_contract_resolution_planner_holes_stop_and_tooltips(
    tmp_path: Path, monkeypatch
) -> None:
    # v4 active: a v3 Q10 (Incumbent) renumbers to v4 Q11; a v4 Q10 is native.
    assert archive.resolved_gate("Q10", "v3") == "Q11"
    assert archive.resolved_gate("Q10", "v4") == "Q10"
    # A legacy/NULL stamp is read under v3 numbering (pre-v4 corpus).
    assert archive.resolved_gate("Q10", "legacy") == "Q11"
    db = _fixture(tmp_path / "farm.sqlite")
    monkeypatch.setattr(archive, "BACKFILL_PLAN", tmp_path / "absent.csv")
    monkeypatch.setattr(archive, "_card_metadata", lambda: {
        "targets": {"QM5_900001": ["EURUSD.DWX", "GBPUSD.DWX"]},
        "universes": {"QM5_900001": ["EURUSD.DWX", "GBPUSD.DWX"]},
        "buckets": {"QM5_900001": "cards_approved"},
    })

    data = archive.collect(db)

    # v4 active: the v3 Incumbent (stored Q10/v3) lands in the v4 Q11 column
    # with explicit (v3:Q10) provenance — never in the v4 Q10 (News) column.
    v3_incumbent = _cell(data, "QM5_900001", "EURUSD.DWX", "Q11")
    v4_news = _cell(data, "QM5_900001", "EURUSD.DWX", "Q10")
    v4_terminal = _cell(data, "QM5_900001", "EURUSD.DWX", "Q17")
    assert "mixed-v3-q10" in v3_incumbent["title"]
    assert "(v3:Q10)" in v3_incumbent["title"]
    # The native v4 rows carry no cross-contract provenance suffix.
    assert "mixed-v4-news" in v4_news["title"]
    assert "(v3:" not in v4_news["title"] and "(v4:" not in v4_news["title"]
    assert "mixed-v4-q17" in v4_terminal["title"]
    assert "(v3:" not in v4_terminal["title"] and "(v4:" not in v4_terminal["title"]
    # The v3 Incumbent must NOT be mislabelled into the v4 Q10 (News) column.
    assert "mixed-v3-q10" not in v4_news["title"]

    # QM5_900002 has Q02..Q08 PASS plus an informational Q09_PORTFOLIO row.
    # Under v4 the first missing prerequisite after Q08 is Q09 (Baseline Full
    # Run); the informational portfolio lane never licenses a successor gap.
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

    # v4 active: the v3 Incumbent row keeps explicit (v3:Q10) provenance under
    # v4 numbering; the native v4 rows render without a provenance suffix.
    assert "Q11 Incumbent Full-History Confirmation (v3:Q10)" in rendered
    assert "Q10_NEWS" in rendered
    assert "(v4:Q10_NEWS)" not in rendered
    assert "Q17 Live Burn-In DXZ" in rendered
    assert "(v4:Q17)" not in rendered


def test_legacy_stamped_incumbent_renders_in_v4_incumbent_column(
    tmp_path: Path, monkeypatch
) -> None:
    """Regression (P0): the live corpus stamps historical rows 'legacy', which
    ``_normalise_contract_version`` maps to None.  Before the fix such a v3 Q10
    (Incumbent) PASS collided with the v4 Q10 (News) column and lost its
    provenance.  With v4 active it MUST render in the v4 Q11 (Incumbent) column
    carrying (v3:Q10) provenance, and NEVER in the v4 Q10 (News) column.
    """
    db = tmp_path / "legacy.sqlite"
    with sqlite3.connect(db) as con:
        con.execute(DDL)
        for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"):
            _insert(con, f"leg-{phase}", "QM5_910001", phase, "PASS", version="legacy")
        # v3 Incumbent Full-History Confirmation, stored under a 'legacy' stamp.
        _insert(con, "leg-incumbent", "QM5_910001", "Q10", "PASS", version="legacy")
    monkeypatch.setattr(archive, "BACKFILL_PLAN", tmp_path / "absent.csv")

    # active manifest is v4 (the factory contract)
    assert gate_manifest.load_gate_manifest().schema_version.endswith("/v4")
    assert archive.resolved_gate("Q10", "legacy") == "Q11"

    data = archive.collect(db)
    incumbent = _cell(data, "QM5_910001", "EURUSD.DWX", "Q11")
    assert "leg-incumbent" in incumbent["title"]
    assert "(v3:Q10)" in incumbent["title"]
    assert incumbent["state"] == archive.ST_PASS

    # The News column (v4 Q10) must not carry the incumbent row.
    news_cells = next(
        card for card in data["cards"] if card["ea"] == "QM5_910001"
    )["cells"].get("Q10", [])
    assert all("leg-incumbent" not in cell["title"] for cell in news_cells)


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
