from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

from tools.strategy_farm import compile_work_items


def _predecessor(evidence_path: Path) -> dict[str, object]:
    return {
        "id": compile_work_items.QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID,
        "phase": "Q02",
        "status": "done",
        "verdict": "ZERO_TRADES",
        "evidence_path": str(evidence_path),
        "payload_json": json.dumps(
            {
                "verdict_reason": "Q02_ZERO_TRADES",
                "priority_reason": (
                    "board_advisor_fx_existing_market_neutral_q02_after_"
                    "exhausted_66_pair_frontier"
                ),
                "expected_symbol": "USDJPY.DWX",
                "expected_period": "H4",
                "expected_mq5_sha256": (
                    compile_work_items.QM5_10025_Q02_ZERO_TRADE_REJECTED_SOURCE_SHA256
                ),
                "expected_ex5_sha256": (
                    compile_work_items.QM5_10025_Q02_ZERO_TRADE_REJECTED_EX5_SHA256
                ),
                "expected_setfile_sha256": (
                    compile_work_items.QM5_10025_Q02_ZERO_TRADE_REJECTED_SETFILE_SHA256
                ),
            },
            sort_keys=True,
        ),
    }


def test_qm5_10025_zero_trade_compile_authority_is_exact_and_self_expiring(
    tmp_path: Path, monkeypatch,
) -> None:
    evidence = tmp_path / "summary.json"
    evidence.write_text('{"result":"FAIL","total_trades":0}\n', encoding="utf-8")
    repaired_source_sha = "a" * 64
    monkeypatch.setattr(
        compile_work_items,
        "QM5_10025_Q02_ZERO_TRADE_EVIDENCE_SHA256",
        compile_work_items.sha256_file(evidence),
    )
    monkeypatch.setattr(
        compile_work_items,
        "QM5_10025_Q02_ZERO_TRADE_REPAIRED_SOURCE_SHA256",
        repaired_source_sha,
    )
    predecessor = _predecessor(evidence)
    inventory = {"work_rows": {"10025": [predecessor]}}

    def authorized(
        *, source_sha: str = repaired_source_sha,
        current_work_item_id: str | None = None,
        candidate_inventory: dict[str, object] = inventory,
    ) -> bool:
        return compile_work_items._qm5_10025_q02_zero_trade_repair_authorized(
            compile_work_items.QM5_10025_Q02_ZERO_TRADE_REPAIR_EA_LABEL,
            compile_work_items.QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY,
            ea_id="10025",
            source_sha=source_sha,
            inventory=candidate_inventory,
            current_work_item_id=current_work_item_id,
        )

    assert authorized()
    assert not authorized(source_sha="b" * 64)

    altered_inventory = deepcopy(inventory)
    altered_inventory["work_rows"]["10025"][0]["verdict"] = "FAIL"
    assert not authorized(candidate_inventory=altered_inventory)

    compile_id = "compile-successor"
    successor = {
        "id": compile_id,
        "phase": compile_work_items.COMPILE_EA_PHASE,
        "status": "active",
        "verdict": None,
        "evidence_path": None,
        "payload_json": json.dumps(
            {
                "append_only_source_repair": True,
                "compile_source_repair_authority": (
                    compile_work_items.QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY
                ),
                "mq5_sha256": repaired_source_sha,
                "source_repair_predecessor_work_item_ids": [
                    compile_work_items.QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID
                ],
            },
            sort_keys=True,
        ),
    }
    worker_inventory = {
        "work_rows": {"10025": [predecessor, successor]},
    }
    assert authorized(
        current_work_item_id=compile_id,
        candidate_inventory=worker_inventory,
    )

    successor_payload = json.loads(successor["payload_json"])
    successor_payload["source_repair_predecessor_work_item_ids"] = []
    successor["payload_json"] = json.dumps(successor_payload, sort_keys=True)
    assert not authorized(
        current_work_item_id=compile_id,
        candidate_inventory=worker_inventory,
    )
