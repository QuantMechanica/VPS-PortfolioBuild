from __future__ import annotations

import json
import re
import sqlite3
import subprocess
from pathlib import Path

from scripts import build_pipeline_state
from tools.strategy_farm import book_build_guard, operator_surfaces, phase_ids
from tools.strategy_farm import render_cockpit_v2


REPO_ROOT = Path(__file__).resolve().parents[3]
LEGACY_PHASE_RE = re.compile(
    r"\b(?:G0|P(?:1|2|3(?:[._]5)?|4|5[bc]?|6|7|8|9b?|10))\b",
    re.IGNORECASE,
)


def _fixture_db(path: Path) -> Path:
    con = sqlite3.connect(path)
    con.execute(
        "CREATE TABLE work_items ("
        "id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, status TEXT, verdict TEXT, "
        "payload_json TEXT, created_at TEXT, updated_at TEXT, "
        "gate_contract_version TEXT)"
    )

    def add(row_id: str, phase: str, version: str, ea: str, verdict: str = "PASS") -> None:
        con.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                row_id, phase, ea, "EURUSD.DWX", "done", verdict, None,
                "2026-08-23T10:00:00Z", "2026-08-23T10:00:00Z", version,
            ),
        )

    # Mixed history on one pair: the terminal requalification evidence is a v4
    # Q14 row and must render under active v3 semantics with raw provenance.
    for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"):
        add(f"v3-{phase}", phase, "v3", "QM5_900001")
    add("v4-baseline", "Q09", "v4", "QM5_900001")
    add("v4-news", "Q10_NEWS", "v4", "QM5_900001")
    add("v4-incumbent", "Q11", "v4", "QM5_900001")
    add("v4-pattern", "Q12", "v4", "QM5_900001")
    add("v4-freeze", "Q13", "v4", "QM5_900001")
    add("v4-terminal", "Q14", "v4", "QM5_900001", "KEEP_INCUMBENT")

    # A Phase-3 observation proves highest-observed is independent of the
    # contiguous-valid frontier and retains the v4 row stamp.
    add("v4-book", "Q15_DXZ", "v4", "QM5_900002")
    con.commit()
    con.close()
    return path


def test_mixed_contract_frontiers_bands_guard_and_no_legacy_html(
    tmp_path: Path, monkeypatch
) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    monkeypatch.setattr(
        book_build_guard,
        "_count_strategy_families",
        lambda rows: len({row["ea_id"] for row in rows}),
    )

    snapshot = operator_surfaces.build_operator_snapshot(db, order_dir=tmp_path)
    html = render_cockpit_v2.render({
        "schema_version": "qm.mission_control.v2",
        "generated_at": "2026-08-23T10:00:00+00:00",
        "operator_surface": snapshot,
    })

    assert [band["id"] for band in snapshot["phase_bands"]] == [
        "1_STRATEGIEBEWEIS", "2_OPTIMIERUNG", "3_BUCHBEWERTUNG"
    ]
    assert [gate["linear_gate_id"] for gate in snapshot["phase_bands"][0]["gates"]] == [
        f"Q{i:02d}" for i in range(9)
    ]
    pair = next(row for row in snapshot["pairs"] if row["ea_id"] == "QM5_900001")
    terminal = phase_ids.ACTIVE_GATE_MANIFEST.terminal_requalification_gate
    assert pair["highest_contiguous_valid_gate"] == terminal
    assert pair["highest_contiguous_valid_label"] == phase_ids.display_phase(
        "Q14", "v4", include_name=True
    )
    book_pair = next(row for row in snapshot["pairs"] if row["ea_id"] == "QM5_900002")
    assert book_pair["highest_observed_gate"] == "Q15"
    assert "Q15" in book_pair["highest_observed_label"]
    assert snapshot["book_guard"]["qualified_pairs"] == 1
    assert snapshot["book_guard"]["minimum_qualified_pairs"] == 25
    assert len(snapshot["phase_bands"]) == 3
    assert snapshot["path_to_25"]["qualified_pairs"] == 1
    assert snapshot["path_to_25"]["frontier_histogram"]["Q14"] == 1
    assert LEGACY_PHASE_RE.search(html) is None


def test_pipeline_state_adds_v4_block_from_versioned_rows(
    tmp_path: Path, monkeypatch
) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    monkeypatch.setattr(build_pipeline_state, "FARM_DB", db)

    per_ea, ok = build_pipeline_state.load_per_ea_from_db()
    by_gate = build_pipeline_state.db_by_gate_v4(per_ea)

    assert ok is True
    assert list(by_gate) == [f"Q{i:02d}" for i in range(18)]
    assert by_gate["Q10"] == 1  # v4 Q10_NEWS
    assert by_gate["Q11"] == 1  # v4 Q11 incumbent
    assert by_gate["Q14"] == 1  # v4 terminal requalification


def test_main_surface_compacts_frontier_and_full_explorer_keeps_every_pair() -> None:
    rows = []
    for index in range(40):
        rows.append({
            "ea_id": f"QM5_{index:05d}",
            "symbol": "EURUSD.DWX",
            "highest_observed_label": f"Q{index % 15:02d}",
            "highest_contiguous_valid_gate": f"Q{index % 15:02d}",
            "highest_contiguous_valid_label": f"Q{index % 15:02d}",
            "earliest_missing_prerequisite": f"Q{(index + 1) % 15:02d}",
            "backfill_action": (
                "STOP_ECONOMIC_FAIL" if index < 20 else "FILL_MISSING"
            ),
            "disposition": "ECONOMIC_FAIL" if index < 20 else "REUSABLE",
        })
    snapshot = {
        "gate_contract_version": "v4",
        "progress_metric": "highest_contiguous_valid_gate",
        "phase_bands": [],
        "pair_count": len(rows),
        "pairs": rows,
        "book_guard": {"qualified_pairs": 0, "minimum_qualified_pairs": 25,
                       "distinct_eas": 0, "strategy_families": 0, "venues": {}},
    }

    compact = operator_surfaces.compact_operator_snapshot(snapshot, limit=5)
    assert compact["pair_count"] == 40
    assert compact["pair_preview_count"] == 5
    assert compact["pair_detail_truncated"] is True
    assert all(row["backfill_action"] == "FILL_MISSING" for row in compact["pairs"])
    main_html = operator_surfaces.render_operator_surface_html(compact)
    assert "5 handlungsnahe Frontiers" in main_html
    assert "Vollbestand 40 im Drill-down" in main_html
    assert "linear_frontier.html" in main_html
    assert '<details class="op-pairs" open>' not in main_html

    explorer = operator_surfaces.render_frontier_explorer_html(snapshot)
    for row in rows:
        assert row["ea_id"] in explorer
    assert "40 EA/Symbol-Paare" in explorer


def test_checked_public_snapshot_validates_against_schema() -> None:
    schema = REPO_ROOT / "public-data" / "public-snapshot.schema.v2.json"
    snapshot = REPO_ROOT / "public-data" / "public-snapshot.json"
    command = (
        f"Get-Content -Raw -LiteralPath '{snapshot}' | "
        f"Test-Json -SchemaFile '{schema}' -ErrorAction Stop | Out-Null"
    )
    result = subprocess.run(
        ["pwsh", "-NoProfile", "-Command", command],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, result.stderr or result.stdout

    data = json.loads(snapshot.read_text(encoding="utf-8-sig"))
    assert data["schema_version"] == 2
    assert data["pipeline"]["by_gate_v4"]["gate_contract_version"] == "v4"
