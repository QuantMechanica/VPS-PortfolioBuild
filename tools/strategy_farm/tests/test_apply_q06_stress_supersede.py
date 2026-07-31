from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sqlite3
import sys

import pytest


TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import apply_q06_stress_supersede as subject  # noqa: E402


WORK_ITEMS_SCHEMA = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    setfile_path TEXT NOT NULL,
    status TEXT NOT NULL,
    verdict TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY,
    state TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
"""


def _write_json(path: Path, value: object) -> str:
    payload = json.dumps(value, sort_keys=True, indent=2).encode("utf-8") + b"\n"
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


def _insert_work_item(connection: sqlite3.Connection, row: dict[str, object]) -> None:
    connection.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(
            :id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,:attempt_count,
            :parent_task_id,:evidence_path,:claimed_by,:payload_json,:created_at,:updated_at
        )
        """,
        row,
    )


def _base_overlay_event() -> dict[str, object]:
    event: dict[str, object] = {
        "schema": subject.OVERLAY_SCHEMA,
        "tool": subject.TOOL_ID,
        "reviewer": "prior-reviewer",
        "observed_at_utc": "2026-07-30T00:00:00+00:00",
        "work_item_id": "prior-work-item",
        "raw_row_sha256": "1" * 64,
        "phase": "Q06",
        "ea_id": "QM5_1",
        "symbol": "EURUSD.DWX",
        "original_status": "done",
        "original_verdict": "PASS",
        "effective_admission_status": "PROVENANCE_UNVERIFIED",
        "reason_classes": ["PRIOR_TEST_EVENT"],
        "priority": "P0_ADMISSION",
        "live_action": "HOLD_OWNER_REVIEW",
        "evidence_path": "prior.json",
        "evidence_sha256": "2" * 64,
        "adjudication_fingerprint_sha256": "3" * 64,
        "event_id": "4" * 64,
        "previous_event_sha256": None,
    }
    event["event_sha256"] = subject.canonical_sha256(event)
    return event


def _fixture(tmp_path: Path) -> dict[str, object]:
    db_path = tmp_path / "farm.sqlite"
    connection = sqlite3.connect(db_path)
    connection.executescript(WORK_ITEMS_SCHEMA)
    authority_payload = {
        "review_close_state": "APPROVED",
        "review_closed_at": "2026-07-31T22:30:00+00:00",
        "review_close_verdict": (
            "Supersede proposal semantics APPROVED; apply with the "
            "full re-verify/append-atomic/no-UPDATE contract."
        ),
    }
    connection.execute(
        "INSERT INTO agent_tasks VALUES(?,?,?,?)",
        (
            subject.AUTHORITY_TASK_ID,
            "APPROVED",
            json.dumps(authority_payload, sort_keys=True),
            "2026-07-31T22:30:00+00:00",
        ),
    )

    proposal_events: list[dict[str, object]] = []
    historical_rows: dict[str, dict[str, object]] = {}
    evidence_paths: list[Path] = []
    for index in range(13):
        work_item_id = f"historical-{index:02d}"
        replacement_id = f"replacement-{index:02d}"
        ea_id = f"QM5_{1000 + index}"
        symbol = f"SYMBOL_{index:02d}"
        evidence_path = tmp_path / "evidence" / f"{work_item_id}.json"
        evidence_path.parent.mkdir(exist_ok=True)
        evidence_path.write_text(
            json.dumps({"work_item_id": work_item_id}) + "\n",
            encoding="utf-8",
        )
        evidence_paths.append(evidence_path)

        historical: dict[str, object] = {
            "id": work_item_id,
            "kind": "backtest",
            "phase": "Q06",
            "ea_id": ea_id,
            "symbol": symbol,
            "setfile_path": f"sets/{ea_id}.set",
            "status": "done",
            "verdict": "PASS",
            "attempt_count": 1,
            "parent_task_id": None,
            "evidence_path": str(evidence_path),
            "claimed_by": None,
            "payload_json": "{}",
            "created_at": "2026-07-01T00:00:00+00:00",
            "updated_at": "2026-07-01T01:00:00+00:00",
        }
        replacement = dict(historical)
        replacement.update(
            {
                "id": replacement_id,
                "status": "pending",
                "verdict": None,
                "attempt_count": 0,
                "parent_task_id": work_item_id,
                "evidence_path": None,
                "payload_json": json.dumps(
                    {
                        "append_only_rerun": True,
                        "append_only_rerun_of_work_item": work_item_id,
                        "historical_work_item_preserved": True,
                    },
                    sort_keys=True,
                ),
                "created_at": "2026-07-31T22:00:00+00:00",
                "updated_at": "2026-07-31T22:00:00+00:00",
            }
        )
        _insert_work_item(connection, historical)
        _insert_work_item(connection, replacement)
        historical_rows[work_item_id] = historical

        reason = (
            "STRESS_INPUT_NOT_EFFECTIVE"
            if index < 8
            else "BASKET_REJECTION_HOOK_MISSING"
        )
        event: dict[str, object] = {
            "work_item_id": work_item_id,
            "raw_row_sha256": subject.canonical_sha256(
                subject.database_row_snapshot(historical)
            ),
            "phase": "Q06",
            "ea_id": ea_id,
            "symbol": symbol,
            "original_status": "done",
            "original_verdict": "PASS",
            "reason_classes": [reason],
            "evidence_path": str(evidence_path),
            "evidence_sha256": subject.sha256_file(evidence_path),
            "replacement_work_item_id": replacement_id,
            "replacement_state_observed": "pending",
        }
        identity = dict(event)
        identity.pop("replacement_state_observed")
        event["proposal_event_id"] = subject.canonical_sha256(identity)
        proposal_events.append(event)

    connection.commit()
    connection.close()

    proposal = {
        "schema": subject.PROPOSAL_SCHEMA,
        "status": "PROPOSAL_ONLY_NOT_APPLIED",
        "router_task_id": subject.AUTHORITY_TASK_ID,
        "proposed_effective_admission_status": "PROVENANCE_UNVERIFIED",
        "proposed_priority": "P0_ADMISSION",
        "proposed_live_action": "HOLD_OWNER_REVIEW",
        "raw_work_item_mutations": 0,
        "event_count": 13,
        "events": proposal_events,
    }
    proposal_path = tmp_path / "proposal.json"
    proposal_sha256 = _write_json(proposal_path, proposal)
    return {
        "db": db_path,
        "proposal": proposal_path,
        "proposal_sha256": proposal_sha256,
        "historical_rows": historical_rows,
        "evidence_paths": evidence_paths,
    }


@pytest.mark.parametrize("with_existing_overlay", [False, True])
def test_apply_publishes_one_atomic_hash_chained_batch(
    tmp_path: Path,
    with_existing_overlay: bool,
) -> None:
    fixture = _fixture(tmp_path)
    overlay_path = tmp_path / "overlay" / "adjudications.jsonl"
    overlay_path.parent.mkdir()
    expected_before_tail = None
    if with_existing_overlay:
        base = _base_overlay_event()
        overlay_path.write_bytes(subject.canonical_json_bytes(base) + b"\n")
        expected_before_tail = str(base["event_sha256"])
    receipt_path = tmp_path / "receipt.json"

    receipt = subject.apply_proposal(
        proposal_path=fixture["proposal"],
        db_path=fixture["db"],
        overlay_path=overlay_path,
        receipt_path=receipt_path,
        apply=True,
        observed_at_utc="2026-08-01T00:00:00+00:00",
        expected_proposal_sha256=fixture["proposal_sha256"],
    )

    events, tail = subject.validate_overlay_chain(overlay_path)
    assert receipt["status"] == "APPLIED"
    assert receipt["raw_work_item_mutations"] == 0
    assert receipt["reason_counts"] == dict(subject.EXPECTED_REASON_COUNTS)
    assert receipt["overlay"]["before_existed"] is with_existing_overlay
    assert receipt["overlay"]["before_tail_event_sha256"] == expected_before_tail
    assert receipt["overlay"]["appended_event_count"] == 13
    assert len(events) == 13 + int(with_existing_overlay)
    assert tail == receipt["overlay"]["after_tail_event_sha256"]
    assert receipt["rows"][0]["previous_event_sha256"] == expected_before_tail
    assert all(event.get("apply_task_id") == subject.APPLY_TASK_ID for event in events[-13:])
    assert all(event.get("replacement_lineage_verified") is True for event in events[-13:])
    assert not overlay_path.with_name(overlay_path.name + ".lock").exists()

    persisted = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert persisted == receipt
    fingerprint = persisted.pop("receipt_fingerprint_sha256")
    assert fingerprint == subject.canonical_sha256(persisted)

    connection = sqlite3.connect(fixture["db"])
    connection.row_factory = sqlite3.Row
    for work_item_id, expected in fixture["historical_rows"].items():
        row = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()
        assert subject.database_row_snapshot(row) == subject.database_row_snapshot(
            expected
        )
    connection.close()


def test_apply_aborts_without_artifacts_when_evidence_drifts(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    overlay_path = tmp_path / "overlay" / "adjudications.jsonl"
    overlay_path.parent.mkdir()
    receipt_path = tmp_path / "receipt.json"
    fixture["evidence_paths"][0].write_text("drift\n", encoding="utf-8")

    with pytest.raises(subject.ApplyError, match="historical evidence hash drift"):
        subject.apply_proposal(
            proposal_path=fixture["proposal"],
            db_path=fixture["db"],
            overlay_path=overlay_path,
            receipt_path=receipt_path,
            apply=True,
            observed_at_utc="2026-08-01T00:00:00+00:00",
            expected_proposal_sha256=fixture["proposal_sha256"],
        )

    assert not overlay_path.exists()
    assert not receipt_path.exists()
    assert not overlay_path.with_name(overlay_path.name + ".lock").exists()


def test_dry_run_rejects_missing_claude_authority(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    connection = sqlite3.connect(fixture["db"])
    connection.execute(
        "UPDATE agent_tasks SET state='REVIEW' WHERE id=?",
        (subject.AUTHORITY_TASK_ID,),
    )
    connection.commit()
    connection.close()
    overlay_path = tmp_path / "overlay" / "adjudications.jsonl"
    overlay_path.parent.mkdir()

    with pytest.raises(subject.ApplyError, match="not terminal-approved"):
        subject.apply_proposal(
            proposal_path=fixture["proposal"],
            db_path=fixture["db"],
            overlay_path=overlay_path,
            receipt_path=None,
            apply=False,
            observed_at_utc="2026-08-01T00:00:00+00:00",
            expected_proposal_sha256=fixture["proposal_sha256"],
        )

    assert not overlay_path.exists()
