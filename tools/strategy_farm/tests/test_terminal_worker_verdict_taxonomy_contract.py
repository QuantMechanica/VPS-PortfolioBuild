from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

from tools.strategy_farm import farmctl, terminal_worker
from artifact_identity import VerdictTaxonomyContractError


def _active_item(root: Path, item_id: str, terminal: str = "T1") -> None:
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                claimed_by,payload_json,created_at,updated_at
            ) VALUES(?,?,?,?,?,'fixture.set','active',NULL,0,?,?,?,?)
            """,
            (
                item_id,
                "backtest",
                "Q02",
                "QM5_10001",
                "EURUSD.DWX",
                terminal,
                json.dumps({"verdict_taxonomy": "unsupported"}),
                now,
                now,
            ),
        )
        conn.commit()


def _raise_taxonomy(*args, **kwargs):
    raise VerdictTaxonomyContractError("taxonomy 'unsupported' is not canonical")


def _assert_landed(root: Path, item_id: str) -> None:
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status,verdict,verdict_taxonomy,evidence_path,payload_json "
            "FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds WHERE work_item_id=?",
            (item_id,),
        ).fetchone()
    assert tuple(row[:3]) == ("failed", "INFRA_FAIL", "infra")
    payload = json.loads(row[4])
    assert payload["verdict_reason"] == "verdict_taxonomy_contract"
    assert payload["offending_verdict_taxonomy"] == "strategy"
    assert row[3] == "EVIDENCE_UNAVAILABLE:verdict_taxonomy_contract"
    assert tuple(hold) == (
        terminal_worker.VERDICT_TAXONOMY_CONTRACT_HOLD_CODE,
        1,
        0,
    )


def test_finish_path_lands_typed_taxonomy_error_as_infra_hold(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    _active_item(root, "finish-taxonomy")
    summary = (tmp_path / "summary.json").resolve()
    with patch.object(
        terminal_worker,
        "_find_work_item_summary_data",
        return_value=(summary, {"verdict": "PASS", "runs": []}),
    ), patch.object(terminal_worker, "_derive_worker_run_verdict", return_value=("PASS", "ok")), patch.object(
        terminal_worker, "prepare_completion", side_effect=_raise_taxonomy
    ):
        result = terminal_worker._finish_work_item(root, "finish-taxonomy", 0)
    assert result["hold_code"] == "VERDICT_TAXONOMY_CONTRACT"
    _assert_landed(root, "finish-taxonomy")


def test_stranded_claim_recovery_uses_same_typed_taxonomy_path(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    _active_item(root, "recovery-taxonomy", terminal="T2")
    summary = (tmp_path / "summary.json").resolve()
    with patch.object(
        terminal_worker,
        "_find_work_item_summary_data",
        return_value=(summary, {"verdict": "PASS", "runs": []}),
    ), patch.object(terminal_worker, "_derive_worker_run_verdict", return_value=("PASS", "ok")), patch.object(
        terminal_worker, "prepare_completion", side_effect=_raise_taxonomy
    ):
        result = terminal_worker._recover_completed_claim_for_terminal(root, "T2")
    assert result["hold_code"] == "VERDICT_TAXONOMY_CONTRACT"
    _assert_landed(root, "recovery-taxonomy")
