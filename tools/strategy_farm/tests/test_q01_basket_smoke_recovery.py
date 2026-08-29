from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import q01_basket_smoke_recovery as recovery  # noqa: E402


def _fixture(tmp_path: Path) -> tuple[Path, Path, recovery.Target]:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    target = recovery.Target(
        ea_id="QM5_42",
        ea_label="QM5_42_test-basket",
        logical_symbol="QM5_42_TEST_BASKET_H1",
        review_task_id="review-42",
        setfile_name="QM5_42_test-basket_QM5_42_TEST_BASKET_H1_H1_backtest.set",
    )
    ea_dir = repo_root / "framework" / "EAs" / target.ea_label
    sets = ea_dir / "sets"
    sets.mkdir(parents=True)
    (ea_dir / "basket_manifest.json").write_text(
        json.dumps(
            {
                "logical_symbol": target.logical_symbol,
                "host_symbol": "EURUSD.DWX",
                "host_timeframe": "H1",
                "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
            }
        ),
        encoding="utf-8",
    )
    (ea_dir / f"{target.ea_label}.mq5").write_text("// source\n", encoding="utf-8")
    (ea_dir / f"{target.ea_label}.ex5").write_bytes(b"compiled-binary")
    (sets / target.setfile_name).write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )
    farmctl.init_db(farm_root)
    with farmctl.connect(farm_root) as conn:
        now = farmctl.utc_now()
        conn.execute(
            """
            INSERT INTO tasks(id,kind,status,source_id,card_id,payload_json,created_at,updated_at)
            VALUES(?, 'ea_review', 'done', NULL, ?, ?, ?, ?)
            """,
            (
                target.review_task_id,
                target.ea_id,
                json.dumps(
                    {
                        "ea_id": target.ea_id,
                        "verdict": {"verdict": "APPROVE_FOR_BACKTEST"},
                    }
                ),
                now,
                now,
            ),
        )
        conn.commit()
    return farm_root, repo_root, target


def test_apply_is_append_only_and_idempotent(tmp_path: Path) -> None:
    farm_root, repo_root, target = _fixture(tmp_path)

    first = recovery.apply(farm_root, repo_root, (target,))
    assert first["inserted_work_item_ids"] == [recovery._work_item_id(target)]
    second = recovery.apply(farm_root, repo_root, (target,))
    assert second["inserted_work_item_ids"] == []
    assert second["existing_work_item_ids"] == [recovery._work_item_id(target)]

    with farmctl.connect(farm_root) as conn:
        row = conn.execute(
            "SELECT kind,phase,ea_id,symbol,status,payload_json FROM work_items WHERE id=?",
            (recovery._work_item_id(target),),
        ).fetchone()
    assert row is not None
    payload = json.loads(row["payload_json"])
    assert (row["kind"], row["phase"], row["status"]) == (
        "q01_smoke",
        "Q01",
        "pending",
    )
    assert row["symbol"] == target.logical_symbol
    assert payload["priority_track"] is True
    assert payload["q01_min_trades"] == 1
    assert payload["q01_smoke_contract"] == recovery.CONTRACT


def test_apply_refuses_artifact_drift_after_enqueue(tmp_path: Path) -> None:
    farm_root, repo_root, target = _fixture(tmp_path)
    recovery.apply(farm_root, repo_root, (target,))
    ex5 = (
        repo_root
        / "framework"
        / "EAs"
        / target.ea_label
        / f"{target.ea_label}.ex5"
    )
    ex5.write_bytes(b"different-binary")
    with pytest.raises(recovery.RecoveryError, match="deterministic work-item collision"):
        recovery.apply(farm_root, repo_root, (target,))


def test_finalize_appends_authenticated_pass_receipt(tmp_path: Path) -> None:
    farm_root, repo_root, target = _fixture(tmp_path)
    recovery.apply(farm_root, repo_root, (target,))
    work_item_id = recovery._work_item_id(target)
    with farmctl.connect(farm_root) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        payload = json.loads(row["payload_json"])
    payload.update(
        {
            "evidence_binding_required": True,
            "expected_from_date": recovery.FROM_DATE,
            "expected_to_date": recovery.TO_DATE,
            "expected_symbol": "EURUSD.DWX",
            "expected_period": "H1",
            "expected_expert": r"QM\QM5_42_test-basket",
        }
    )
    summary = {
        "evidence_schema": "run_smoke/v2",
        "result": "PASS",
        "from_date": recovery.FROM_DATE,
        "to_date": recovery.TO_DATE,
        "symbol": "EURUSD.DWX",
        "period": "H1",
        "expert": r"QM\QM5_42_test-basket",
        "model4_log_marker_detected": True,
        "runs": [{"total_trades": 7}],
        "test_window": {
            "from_date": recovery.FROM_DATE,
            "to_date": recovery.TO_DATE,
            "source": "generated_tester_ini",
            "tester_ini_files": [
                {
                    "sha256": "4" * 64,
                    "from_date": recovery.FROM_DATE,
                    "to_date": recovery.TO_DATE,
                    "symbol": "EURUSD.DWX",
                    "period": "H1",
                    "expert": r"QM\QM5_42_test-basket",
                }
            ],
        },
        "execution_identity": {
            "stable_during_run": True,
            "expert_binary": {
                "deployed": {"sha256": payload["expected_ex5_sha256"]},
                "stable_during_run": True,
            },
            "setfile": {
                "source": {"sha256": payload["expected_setfile_sha256"]},
                "stable_during_run": True,
            },
            "mq5_source": {"sha256": payload["expected_mq5_sha256"]},
        },
    }
    evidence = tmp_path / "summary.json"
    evidence.write_text(json.dumps(summary), encoding="utf-8")
    with farmctl.connect(farm_root) as conn:
        conn.execute(
            """
            UPDATE work_items
            SET status='done', verdict='PASS', evidence_path=?, payload_json=?, updated_at=?
            WHERE id=?
            """,
            (str(evidence), json.dumps(payload), farmctl.utc_now(), work_item_id),
        )
        conn.commit()

    result = recovery.finalize(farm_root, repo_root, (target,))
    assert result["waiting"] == []
    assert result["finalized"][0]["smoke_result"] == "passed"
    receipt_task_id = recovery._receipt_task_id(work_item_id)
    with farmctl.connect(farm_root) as conn:
        task = conn.execute("SELECT * FROM tasks WHERE id=?", (receipt_task_id,)).fetchone()
    assert task is not None
    task_payload = json.loads(task["payload_json"])
    assert task["kind"] == "build_ea"
    assert task["status"] == "done"
    assert task_payload["codex_result"]["smoke_result"] == "passed"
    assert task_payload["q01_recovery_receipt"]["summary_total_trades"] == 7
