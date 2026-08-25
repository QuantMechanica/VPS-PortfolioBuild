import csv
import json
from pathlib import Path

import pytest

from tools.strategy_farm import apply_q02_dead16_dispositions as dead16
from tools.strategy_farm import farmctl


def _fixture(tmp_path: Path) -> tuple[Path, Path, Path, list[str]]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    decision = tmp_path / "decision.md"
    decision.write_text(
        "16 deterministisch tote Q02-Paare\n"
        f"{dead16.OWNER_DECISION_ID}\n"
        "disposition_only=true\n",
        encoding="utf-8",
    )
    census = tmp_path / "census.csv"
    fieldnames = [
        "ea_id",
        "symbol",
        "infra_fail_rows",
        "distinct_reasons",
        "classification",
        "terminal_work_item_id",
        "current_repo_ex5_sha256",
    ]
    rows: list[dict[str, str]] = []
    terminal_ids: list[str] = []
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        # The production DB carries the SH-1 cache columns.  farmctl's minimal
        # new-test DB intentionally does not backfill them, so mirror the live
        # schema used by this one-time governed disposition tool.
        conn.execute("ALTER TABLE work_items ADD COLUMN verdict_taxonomy_stored TEXT")
        conn.execute("ALTER TABLE work_items ADD COLUMN clean_status_stored TEXT")
        for pair_index in range(dead16.EXPECTED_DISPOSITION_ROWS):
            ea_id = f"QM5_{12000 + pair_index}"
            symbol = f"SYM{pair_index:02d}.DWX"
            log_bomb = pair_index >= dead16.EXPECTED_ONINIT_ROWS
            classification = dead16.CLASS_LOG_BOMB if log_bomb else dead16.CLASS_ONINIT
            reason = (
                "run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS"
                if log_bomb
                else "run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS"
            )
            for attempt in range(12):
                item_id = f"source-{pair_index:02d}-{attempt:02d}"
                conn.execute(
                    """
                    INSERT INTO work_items(
                      id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                      attempt_count,evidence_path,payload_json,created_at,updated_at,
                      verdict_taxonomy_stored,clean_status_stored,
                      gate_contract_version,verdict_taxonomy
                    ) VALUES(?,'backtest','Q02',?,?,?,'failed','INFRA_FAIL',?,
                             'EVIDENCE_UNAVAILABLE:test',?,?,?,'infra','failed',
                             'legacy','infra')
                    """,
                    (
                        item_id,
                        ea_id,
                        symbol,
                        f"setfiles/{ea_id}/{symbol}.set",
                        attempt,
                        json.dumps({"verdict_reason": reason}, sort_keys=True),
                        now,
                        now,
                    ),
                )
            terminal_id = f"source-{pair_index:02d}-11"
            terminal_ids.append(terminal_id)
            rows.append(
                {
                    "ea_id": ea_id,
                    "symbol": symbol,
                    "infra_fail_rows": "12",
                    "distinct_reasons": reason,
                    "classification": classification,
                    "terminal_work_item_id": terminal_id,
                    "current_repo_ex5_sha256": "a" * 64,
                }
            )
        conn.commit()

    for recoverable_index in range(
        dead16.EXPECTED_CENSUS_ROWS - dead16.EXPECTED_DISPOSITION_ROWS
    ):
        rows.append(
            {
                "ea_id": f"QM5_{20000 + recoverable_index}",
                "symbol": f"REC{recoverable_index:02d}.DWX",
                "infra_fail_rows": "12",
                "distinct_reasons": "mixed transient",
                "classification": "RECOVERABLE_MIXED_TRANSIENT",
                "terminal_work_item_id": f"recoverable-{recoverable_index:02d}",
                "current_repo_ex5_sha256": "b" * 64,
            }
        )
    with census.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return db, census, decision, terminal_ids


def _stranded_count(db: Path) -> int:
    with dead16.connect_ro(db) as conn:
        return len(conn.execute(dead16.STRANDED_COHORT_SQL).fetchall())


def test_plan_apply_appends_exact_16_and_preserves_history(tmp_path: Path) -> None:
    db, census, decision, source_ids = _fixture(tmp_path)
    assert _stranded_count(db) == 16

    plan = dead16.build_plan(db, census, decision)
    assert len(plan["targets"]) == 16
    assert sum(
        target["census_classification"] == dead16.CLASS_ONINIT
        for target in plan["targets"]
    ) == 14
    assert sum(
        target["census_classification"] == dead16.CLASS_LOG_BOMB
        for target in plan["targets"]
    ) == 2
    plan_path = tmp_path / "plan.json"
    plan_sha = dead16.write_new_json(plan_path, plan)
    receipt_path = tmp_path / "receipt.json"
    result = dead16.apply_plan(
        db=db,
        census=census,
        decision=decision,
        plan_path=plan_path,
        expected_plan_sha256=plan_sha,
        receipt_out=receipt_path,
        backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "FACTORY_MUTATION.lock",
    )

    assert result["inserted_count"] == 16
    assert result["historical_verdict_rows_updated"] == 0
    assert result["source_rows_preserved"] == 16
    assert result["health_count_before"] == 16
    assert result["health_count_after"] == 0
    assert result["health_count_delta"] == -16
    assert result["quick_check"] == "ok"
    assert receipt_path.is_file()
    assert Path(result["backup"]["path"]).is_file()
    assert _stranded_count(db) == 0

    with dead16.connect_ro(db) as conn:
        dispositions = conn.execute(
            "SELECT status,verdict,payload_json,verdict_taxonomy_stored,"
            "clean_status_stored FROM work_items "
            "WHERE json_extract(payload_json,?)=? ORDER BY ea_id,symbol",
            ("$.owner_decision_id", dead16.OWNER_DECISION_ID),
        ).fetchall()
        assert len(dispositions) == 16
        for row in dispositions:
            payload = json.loads(row["payload_json"])
            assert row["status"] == "failed"
            assert row["verdict"] == "INVALID"
            assert row["verdict_taxonomy_stored"] == "invalid"
            assert row["clean_status_stored"] == "failed"
            assert payload["disposition_only"] is True
            assert payload["backtest_enqueued"] is False
            assert payload["historical_infra_rows_preserved"] is True
        preserved = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE id IN ("
            + ",".join(["?"] * len(source_ids))
            + ") AND status='failed' AND verdict='INFRA_FAIL'",
            source_ids,
        ).fetchone()[0]
        assert preserved == 16


def test_apply_aborts_if_a_bound_source_payload_drifts(tmp_path: Path) -> None:
    db, census, decision, source_ids = _fixture(tmp_path)
    plan = dead16.build_plan(db, census, decision)
    plan_path = tmp_path / "plan.json"
    plan_sha = dead16.write_new_json(plan_path, plan)
    with dead16.connect_rw(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps({"verdict_reason": "drifted"}), source_ids[0]),
        )
        conn.commit()

    with pytest.raises(dead16.Dead16Error, match="source_payload_drifted"):
        dead16.apply_plan(
            db=db,
            census=census,
            decision=decision,
            plan_path=plan_path,
            expected_plan_sha256=plan_sha,
            receipt_out=tmp_path / "receipt.json",
            backup_dir=tmp_path / "backups",
            mutation_lock=tmp_path / "FACTORY_MUTATION.lock",
        )
    with dead16.connect_ro(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE json_extract(payload_json,?)=?",
            ("$.owner_decision_id", dead16.OWNER_DECISION_ID),
        ).fetchone()[0] == 0
