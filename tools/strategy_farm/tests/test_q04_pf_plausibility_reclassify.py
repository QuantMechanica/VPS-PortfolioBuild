from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import farmctl
from tools.strategy_farm import q04_pf_plausibility_reclassify as reclassify


def _insert_pass(
    root: Path,
    *,
    item_id: str,
    evidence_path: Path,
    payload: dict,
) -> None:
    now = "2026-08-17T13:42:25+00:00"
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
               attempt_count,parent_task_id,evidence_path,claimed_by,
               payload_json,created_at,updated_at)
            VALUES (?, 'backtest', 'Q04', 'QM5_1001', 'EURUSD.DWX',
                    'input.set', 'done', 'PASS', 0, NULL, ?, NULL, ?, ?, ?)
            """,
            (
                item_id,
                str(evidence_path),
                json.dumps(payload, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()


def test_hash_bound_plan_and_apply_reclassifies_without_rerun(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    evidence = tmp_path / "evidence" / "aggregate.json"
    evidence.parent.mkdir(parents=True)
    evidence.write_text(
        json.dumps({
            "phase": "Q04",
            "evidence_key": "wi-evidence",
            "verdict": "PASS",
            "folds": [
                {"id": "F1", "pf_net": 1.2, "trades": 20},
                {"id": "F2", "pf_net": 999.0, "trades": 4},
                {"id": "F3", "pf_net": 1.1, "trades": 18},
            ],
        }),
        encoding="utf-8",
    )
    _insert_pass(root, item_id="wi-evidence", evidence_path=evidence, payload={})
    missing = tmp_path / "evidence" / "missing.json"
    _insert_pass(
        root,
        item_id="wi-missing",
        evidence_path=missing,
        payload={
            "promotion_source": "pump_q04_early_probe",
            "q04_default_probe": True,
            "verdict_reason": "F1:pf_net=999.000;F2:pf_net=999.000;F3:pf_net=999.000",
        },
    )

    plan = reclassify.build_plan(
        db,
        expected_ids=["wi-evidence", "wi-missing"],
        authority_task_id="task-1",
        evidence_doc="docs/ops/evidence/task-1.md",
        planned_at_utc="2026-08-17T14:00:00+00:00",
    )
    by_id = {row["id"]: row for row in plan["rows"]}
    assert by_id["wi-evidence"]["to_verdict"] == "FAIL"
    assert by_id["wi-evidence"]["evidence_exists"] is True
    assert by_id["wi-missing"]["to_verdict"] == "INFRA_FAIL"
    assert by_id["wi-missing"]["evidence_exists"] is False

    receipt = reclassify.apply_plan(
        plan,
        expected_plan_sha256=reclassify.plan_sha256(plan),
        db=db,
        backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "FACTORY_MUTATION.lock",
    )

    assert receipt["work_items_enqueued_or_rerun"] == 0
    assert receipt["downstream_q10_or_live_roster_rows_mutated"] == 0
    with farmctl.connect(root) as conn:
        rows = conn.execute(
            "SELECT id,status,verdict FROM work_items ORDER BY id"
        ).fetchall()
        ledger = conn.execute(
            "SELECT count(*) FROM work_item_transition_ledger "
            "WHERE action='reclassify_q04_unusable_pf'"
        ).fetchone()[0]
    assert [tuple(row) for row in rows] == [
        ("wi-evidence", "done", "FAIL"),
        ("wi-missing", "done", "INFRA_FAIL"),
    ]
    assert ledger == 2
