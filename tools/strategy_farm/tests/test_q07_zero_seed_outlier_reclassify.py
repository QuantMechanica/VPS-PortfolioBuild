from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import farmctl
from tools.strategy_farm import q07_zero_seed_outlier_reclassify as reclassify


def _insert_row(
    root: Path,
    *,
    item_id: str,
    ea_id: str,
    symbol: str,
    verdict: str,
    evidence_path: Path,
    updated_at: str,
) -> None:
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
               attempt_count,parent_task_id,evidence_path,claimed_by,
               payload_json,created_at,updated_at)
            VALUES (?, 'backtest', 'Q07', ?, ?, 'input.set', 'done', ?,
                    0, NULL, ?, NULL, '{}', ?, ?)
            """,
            (item_id, ea_id, symbol, verdict, str(evidence_path), updated_at, updated_at),
        )
        conn.commit()


def _write_aggregate(
    path: Path,
    *,
    ea_id: int,
    symbol: str,
    trades: list[int],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    seeds = [42, 17, 99, 7, 2026]
    path.write_text(
        json.dumps({
            "phase": "Q07",
            "ea_id": ea_id,
            "symbol": symbol,
            "verdict": "INVALID",
            "reason": "historical_invalid_reason",
            "per_seed_detail": [
                {
                    "seed": seed,
                    "pf": None if count == 0 else 1.1,
                    "trades": count,
                    "summary_path": str(path.parent / f"missing_{seed}.json"),
                }
                for seed, count in zip(seeds, trades)
            ],
        }),
        encoding="utf-8",
    )


def test_hash_bound_apply_corrects_target_and_preserves_cohort(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    target_evidence = tmp_path / "target" / "aggregate.json"
    preserved_evidence = tmp_path / "preserved" / "aggregate.json"
    _write_aggregate(
        target_evidence,
        ea_id=1116,
        symbol="EURJPY.DWX",
        trades=[602, 612, 0, 612, 607],
    )
    _write_aggregate(
        preserved_evidence,
        ea_id=20004,
        symbol="NDX.DWX",
        trades=[56, 54, 54, 0, 53],
    )
    _insert_row(
        root,
        item_id="target-row",
        ea_id="QM5_1116",
        symbol="EURJPY.DWX",
        verdict="FAIL",
        evidence_path=target_evidence,
        updated_at="2026-08-17T13:00:51+00:00",
    )
    _insert_row(
        root,
        item_id="preserved-row",
        ea_id="QM5_20004",
        symbol="NDX.DWX",
        verdict="INFRA_FAIL",
        evidence_path=preserved_evidence,
        updated_at="2026-07-25T22:18:45+00:00",
    )

    target_evidence_sha = reclassify.sha256_file(target_evidence)
    preserved_evidence_sha = reclassify.sha256_file(preserved_evidence)
    plan = reclassify.build_plan(
        db,
        expected_ids=["target-row"],
        preserve_ids=["preserved-row"],
        authority_task_id="task-q07",
        evidence_doc="docs/ops/evidence/task-q07.md",
        planned_at_utc="2026-08-17T15:00:00+00:00",
    )

    assert plan["rows"][0]["aggregate_verdict"] == "INVALID"
    assert plan["rows"][0]["to_verdict"] == "INFRA_FAIL"
    assert plan["rows"][0]["reason"] == (
        "seed_zero_trades_outlier:seeds=[99]:median=607:floor=20"
    )
    preserved_preimage = plan["preserved_rows"][0]["preimage_state_sha256"]

    receipt = reclassify.apply_plan(
        plan,
        expected_plan_sha256=reclassify.plan_sha256(plan),
        db=db,
        backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "FACTORY_MUTATION.lock",
    )

    assert receipt["work_items_enqueued_or_rerun"] == 0
    assert receipt["preservation_rows_mutated"] == 0
    assert receipt["database_quick_check"] == "ok"
    assert Path(receipt["backup_path"]).is_file()
    assert reclassify.sha256_file(target_evidence) == target_evidence_sha
    assert reclassify.sha256_file(preserved_evidence) == preserved_evidence_sha
    assert receipt["preserved_rows"][0]["state_sha256"] == preserved_preimage

    with farmctl.connect(root) as conn:
        rows = conn.execute(
            "SELECT id,status,verdict,attempt_count,updated_at "
            "FROM work_items ORDER BY id"
        ).fetchall()
        ledger = conn.execute(
            "SELECT action,from_verdict,to_verdict FROM work_item_transition_ledger"
        ).fetchall()
    assert [tuple(row) for row in rows] == [
        ("preserved-row", "done", "INFRA_FAIL", 0, "2026-07-25T22:18:45+00:00"),
        ("target-row", "done", "INFRA_FAIL", 0, "2026-08-17T15:00:00+00:00"),
    ]
    assert [tuple(row) for row in ledger] == [
        ("reclassify_q07_zero_seed_outlier", "FAIL", "INFRA_FAIL")
    ]
