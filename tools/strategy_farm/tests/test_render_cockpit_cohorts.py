from __future__ import annotations

import sqlite3
from pathlib import Path

from tools.strategy_farm import render_cockpit


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    status TEXT,
    verdict TEXT
);
CREATE TABLE work_item_dependencies (
    child_work_item_id TEXT NOT NULL,
    dependency_role TEXT NOT NULL,
    parent_work_item_id TEXT NOT NULL
);
"""


def _insert(
    connection: sqlite3.Connection,
    row_id: str,
    phase: str,
    ea_id: str,
    *,
    status: str = "done",
    verdict: str | None = "PASS",
) -> None:
    connection.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?)",
        (row_id, phase, ea_id, "EURUSD.DWX", status, verdict),
    )


def _fixture_database(path: Path) -> None:
    with sqlite3.connect(path) as connection:
        connection.executescript(WORK_ITEMS_DDL)

        # Q02 strict-PASS cohort exercises all buckets and PASS precedence.
        for suffix in "ABCDEFG":
            _insert(connection, f"q02-{suffix}", "Q02", f"QM5_{suffix}")
        _insert(connection, "q03-B", "Q03", "QM5_B", status="pending", verdict=None)
        _insert(connection, "q03-C", "Q03", "QM5_C", status="failed", verdict="INFRA_FAIL")
        _insert(connection, "q03-D", "Q03", "QM5_D", verdict="PASS_SOFT")
        _insert(connection, "q03-E", "Q03", "QM5_E", verdict="FAIL")
        _insert(connection, "q03-F", "Q03", "QM5_F", verdict="PASS")
        _insert(connection, "q03-G-old", "Q03", "QM5_G", verdict="FAIL_HARD")
        _insert(connection, "q03-G-pass", "Q03", "QM5_G", verdict="PASS")

        # Six Q08 PASS pairs exercise both Q09 arms and their paired-success count.
        for index in range(1, 7):
            _insert(connection, f"q08-{index}", "Q08", f"QM5_N{index}")
        _insert(connection, "news-1", "Q09_NEWS", "QM5_N1", verdict="CONFIG_LOCKED")
        _insert(connection, "news-2", "Q09_NEWS", "QM5_N2", verdict="REVIEW_REQUIRED")
        _insert(connection, "news-2-old", "Q09_NEWS", "QM5_N2", status="failed", verdict="INFRA_FAIL")
        _insert(connection, "news-3", "Q09_NEWS", "QM5_N3", status="failed", verdict="INFRA_FAIL")
        _insert(connection, "news-5", "Q09_NEWS", "QM5_N5", status="failed", verdict="INVALID_EVIDENCE")
        _insert(connection, "news-6", "Q09_NEWS", "QM5_N6", status="pending", verdict=None)

        _insert(connection, "portfolio-1", "Q09_PORTFOLIO", "QM5_N1", verdict="PASS_PORTFOLIO")
        _insert(connection, "portfolio-2", "Q09_PORTFOLIO", "QM5_N2", verdict="FAIL_PORTFOLIO")
        _insert(connection, "portfolio-3", "Q09_PORTFOLIO", "QM5_N3", verdict="NEED_MORE_DATA")
        _insert(connection, "portfolio-5", "Q09_PORTFOLIO", "QM5_N5", status="failed", verdict="INFRA_FAIL")
        _insert(connection, "portfolio-6", "Q09_PORTFOLIO", "QM5_N6", status="pending", verdict=None)

        # Historical Q10 has two distinct PASS pairs; only one has both roles.
        _insert(connection, "q10-historical", "Q10", "QM5_HIST")
        _insert(connection, "q10-bound", "Q10", "QM5_BOUND")
        _insert(connection, "q10-bound-repeat", "Q10", "QM5_BOUND")
        connection.executemany(
            "INSERT INTO work_item_dependencies VALUES (?,?,?)",
            [
                ("q10-bound", "Q09_NEWS", "news-parent"),
                ("q10-bound", "Q09_PORTFOLIO", "portfolio-parent"),
            ],
        )


def test_pipeline_cohort_queries_are_exclusive_and_contract_bound(
    tmp_path: Path, monkeypatch
) -> None:
    database = tmp_path / "farm.sqlite"
    _fixture_database(database)
    monkeypatch.setattr(render_cockpit, "DB", database)

    snapshot = render_cockpit.pipeline_cohort_snapshot()

    assert snapshot["available"] is True
    assert snapshot["schema_version"] == "qm.cockpit-adjacent-cohort/v1"
    assert snapshot["buckets"] == ["NO_ROW", "OPEN", "INFRA", "SOFT", "HARD", "PASS"]

    q02_q03 = snapshot["transitions"][0]
    assert q02_q03["upstream_pass"] == 7
    assert q02_q03["counts"] == {
        "NO_ROW": 1,
        "OPEN": 1,
        "INFRA": 1,
        "SOFT": 1,
        "HARD": 1,
        "PASS": 2,
    }
    # The two Q03 PASS pairs form the next upstream cohort and have no Q04 row.
    assert snapshot["transitions"][1]["upstream_pass"] == 2
    assert snapshot["transitions"][1]["counts"]["NO_ROW"] == 2

    arms = {row["label"]: row for row in snapshot["q09_arms"]}
    assert arms["Q09_NEWS"]["upstream_pass"] == 6
    assert arms["Q09_NEWS"]["counts"] == {
        "NO_ROW": 1,
        "OPEN": 2,
        "INFRA": 2,
        "SOFT": 0,
        "HARD": 0,
        "PASS": 1,
    }
    assert arms["Q09_PORTFOLIO"]["counts"] == {
        "NO_ROW": 1,
        "OPEN": 1,
        "INFRA": 1,
        "SOFT": 1,
        "HARD": 1,
        "PASS": 1,
    }
    assert snapshot["q09_both_authenticated"] == 1
    assert snapshot["q10_historical_visible"] == 2
    assert snapshot["q10_current_contract_bound"] == 1


def test_cohort_renderer_labels_mixed_era_chips_and_q09_q10_contracts(
    tmp_path: Path, monkeypatch
) -> None:
    database = tmp_path / "farm.sqlite"
    _fixture_database(database)
    monkeypatch.setattr(render_cockpit, "DB", database)

    page = render_cockpit.render_pipeline_cohorts(
        render_cockpit.pipeline_cohort_snapshot()
    )

    assert render_cockpit.LIFETIME_PASS_CHIP_LABEL == (
        "Q02-Q10 // LIFETIME DISTINCT PASS (MIXED ERAS)"
    )
    assert "qm.cockpit-adjacent-cohort/v1" in page
    assert "Q08 -&gt; Q09 NEWS" in page
    assert "Q08 -&gt; Q09 PORTFOLIO" in page
    assert "Q09 BOTH AUTHENTICATED" in page
    assert "Q10 HISTORICAL VISIBLE" in page
    assert "Q10 CURRENT CONTRACT BOUND" in page
    assert "execution-time hash verification remains" in page
    source = Path(render_cockpit.__file__).read_text(encoding="utf-8")
    assert "{e(LIFETIME_PASS_CHIP_LABEL)}" in source
