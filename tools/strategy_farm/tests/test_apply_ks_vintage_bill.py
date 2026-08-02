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

import apply_ks_vintage_bill as subject  # noqa: E402


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
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
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
            parent_task_id,evidence_path,payload_json,created_at,updated_at
        ) VALUES(
            :id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,
            :attempt_count,:parent_task_id,:evidence_path,:payload_json,
            :created_at,:updated_at
        )
        """,
        row,
    )


def _base_overlay_event() -> dict[str, object]:
    event: dict[str, object] = {
        "schema": subject.OVERLAY_SCHEMA,
        "tool": subject.TOOL_ID,
        "reviewer": "fixture-reviewer",
        "observed_at_utc": "2026-08-01T00:00:00+00:00",
        "work_item_id": "prior-work-item",
        "raw_row_sha256": "1" * 64,
        "phase": "Q06",
        "ea_id": "QM5_1",
        "symbol": "PRIOR.DWX",
        "original_status": "done",
        "original_verdict": "PASS",
        "effective_admission_status": "PROVENANCE_UNVERIFIED",
        "reason_classes": ["PRIOR_TEST_EVENT"],
        "priority": "P0_ADMISSION",
        "live_action": "NO_AUTOMATIC_LIVE_ACTION",
        "adjudication_fingerprint_sha256": "2" * 64,
        "event_id": "3" * 64,
        "previous_event_sha256": None,
    }
    event["event_sha256"] = subject.canonical_sha256(event)
    return event


def _fixture(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> dict[str, object]:
    repo_root = tmp_path / "repo"
    ea_root = repo_root / "framework" / "EAs"
    ea_root.mkdir(parents=True)

    ea_ids = [f"QM5_{10000 + index}" for index in range(7)]
    replacements: list[dict[str, object]] = []
    binary_paths: list[Path] = []
    for index, ea_id in enumerate(ea_ids):
        ea_dir = ea_root / f"{ea_id}_fixture-{index}"
        ea_dir.mkdir()
        ex5_path = ea_dir / f"{ea_id}_fixture-{index}.ex5"
        ex5_path.write_bytes(f"adopted-binary-{ea_id}\n".encode("ascii"))
        binary_paths.append(ex5_path)
        replacements.append(
            {
                "ea_id": ea_id,
                "new_ex5_sha256": subject.sha256_file(ex5_path),
                "historical_repo_ex5_reference_sha256": hashlib.sha256(
                    f"historical-{ea_id}".encode("ascii")
                ).hexdigest(),
                "historical_hash_authority": "fixture",
            }
        )

    db_path = tmp_path / "farm.sqlite"
    connection = sqlite3.connect(db_path)
    connection.executescript(WORK_ITEMS_SCHEMA)
    bill_events: list[dict[str, object]] = []
    for index in range(26):
        ea_index = index % len(ea_ids)
        ea_id = ea_ids[ea_index]
        phase = "Q06" if index % 2 == 0 else "Q07"
        work_item_id = f"work-item-{index:02d}"
        symbol = f"SYMBOL{index:02d}.DWX"
        row: dict[str, object] = {
            "id": work_item_id,
            "kind": "backtest",
            "phase": phase,
            "ea_id": ea_id,
            "symbol": symbol,
            "setfile_path": f"sets/{ea_id}_{symbol}.set",
            "status": "done",
            "verdict": "PASS",
            "attempt_count": 1,
            "parent_task_id": None,
            "evidence_path": None,
            "payload_json": "{}",
            "created_at": "2026-07-01T00:00:00+00:00",
            "updated_at": "2026-07-01T01:00:00+00:00",
        }
        _insert_work_item(connection, row)
        bill_events.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "phase": phase,
                "work_item_id": work_item_id,
                "priority": "P0_ADMISSION" if index < 22 else "P1_HISTORY",
                "raw_row_sha256": subject.canonical_sha256(
                    subject.work_item_snapshot(row)
                ),
                "original_verdict": "PASS",
                "current_effective_status": "PROVENANCE_UNVERIFIED",
                "current_reason_classes": ["MISSING_FILE"],
                "new_ex5_sha256": replacements[ea_index]["new_ex5_sha256"],
                "required_rerun": phase,
            }
        )
    connection.commit()
    connection.close()

    bill = {
        "schema_version": subject.BILL_SCHEMA,
        "status": subject.APPROVED_BILL_STATUS,
        "created_utc": "2026-07-31T17:31:17+00:00",
        "source_commit": subject.EXPECTED_SOURCE_COMMIT,
        "read_only_scan": {"target_historical_pass_rows": 26},
        "binary_replacements": replacements,
        "proposed_effective_status": subject.EXPECTED_EFFECTIVE_STATUS,
        "proposed_reason_class": subject.EXPECTED_REASON_CLASS,
        "events": bill_events,
        "append_only_overlay_write_performed": False,
        "work_item_rows_modified": False,
        "pipeline_verdict_created": False,
        "live_action_performed": False,
    }
    bill_path = tmp_path / "bill.json"
    bill_sha256 = _write_json(bill_path, bill)
    monkeypatch.setattr(subject, "APPROVED_BILL_SHA256", bill_sha256)

    overlay_path = tmp_path / "overlay" / "adjudications.jsonl"
    overlay_path.parent.mkdir()
    base = _base_overlay_event()
    overlay_path.write_bytes(subject.canonical_json_bytes(base) + b"\n")
    monkeypatch.setattr(subject, "EXPECTED_OVERLAY_EVENT_COUNT", 1)

    return {
        "repo_root": repo_root,
        "binary_paths": binary_paths,
        "db": db_path,
        "bill": bill_path,
        "bill_sha256": bill_sha256,
        "overlay": overlay_path,
        "overlay_sha256": subject.sha256_file(overlay_path),
        "overlay_tail": base["event_sha256"],
        "receipt": tmp_path / "receipt.json",
    }


def _run(
    fixture: dict[str, object],
    *,
    apply: bool,
    receipt_path: Path | None = None,
    expected_bill_sha256: str | None = None,
) -> dict[str, object]:
    return subject.apply_bill(
        bill_path=fixture["bill"],
        expected_bill_sha256=expected_bill_sha256 or fixture["bill_sha256"],
        db_path=fixture["db"],
        repo_root=fixture["repo_root"],
        overlay_path=fixture["overlay"],
        expected_overlay_sha256=fixture["overlay_sha256"],
        expected_tail_event_sha256=fixture["overlay_tail"],
        reviewer="claude:MNT-043-fixture",
        observed_at_utc="2026-08-02T08:00:00+00:00",
        apply=apply,
        receipt_path=receipt_path,
    )


def test_dry_run_happy_path_is_zero_write(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    before = fixture["overlay"].read_bytes()

    result = _run(fixture, apply=False)

    assert result["status"] == "DRY_RUN_VERIFIED_NO_MUTATION"
    assert result["database_rows_verified"] == 26
    assert len(result["adopted_binaries_verified"]) == 7
    assert result["overlay"]["before_event_count"] == 1
    assert result["overlay"]["planned_append_count"] == 26
    assert result["overlay"]["planned_after_event_count"] == 27
    assert len(result["candidate_event_ids"]) == 26
    assert len(set(result["candidate_event_ids"])) == 26
    assert result["overlay_writes"] == 0
    assert result["receipt_writes"] == 0
    assert fixture["overlay"].read_bytes() == before
    assert not fixture["receipt"].exists()
    assert not fixture["overlay"].with_name(
        fixture["overlay"].name + ".lock"
    ).exists()


def test_wrong_bill_sha_refuses(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)

    with pytest.raises(subject.ApplyError, match="not the approved MNT-043 bill"):
        _run(fixture, apply=False, expected_bill_sha256="f" * 64)


def test_tampered_raw_row_refuses(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    connection = sqlite3.connect(fixture["db"])
    connection.execute(
        "UPDATE work_items SET updated_at=? WHERE id=?",
        ("2026-08-02T09:00:00+00:00", "work-item-00"),
    )
    connection.commit()
    connection.close()

    with pytest.raises(subject.ApplyError, match="raw row hash drift"):
        _run(fixture, apply=False)


def test_missing_adoption_refuses(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    fixture["binary_paths"][0].unlink()

    with pytest.raises(subject.ApplyError, match="adopted repo-tree EX5"):
        _run(fixture, apply=False)


def test_apply_appends_26_chained_events_and_receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    before = fixture["overlay"].read_bytes()

    receipt = _run(fixture, apply=True, receipt_path=fixture["receipt"])

    events, tail = subject.validate_overlay_chain(fixture["overlay"])
    assert receipt["status"] == "APPLIED"
    assert receipt["database_rows_reverified_unchanged"] == 26
    assert receipt["overlay"]["appended_event_count"] == 26
    assert receipt["overlay"]["after_event_count"] == 27
    assert len(events) == 27
    assert tail == receipt["overlay"]["after_tail_event_sha256"]
    assert fixture["overlay"].read_bytes().startswith(before)
    assert all(
        event["effective_admission_status"] == "EVIDENCE_VINTAGE_STALE"
        for event in events[-26:]
    )
    assert all(
        event["reason_class"] == "BINARY_VINTAGE_MISMATCH"
        for event in events[-26:]
    )
    assert all(event["bill_sha256"] == fixture["bill_sha256"] for event in events[-26:])
    assert not fixture["overlay"].with_name(
        fixture["overlay"].name + ".lock"
    ).exists()

    persisted = json.loads(fixture["receipt"].read_text(encoding="utf-8"))
    assert persisted == receipt
    unsigned = dict(persisted)
    fingerprint = unsigned.pop("receipt_fingerprint_sha256")
    assert fingerprint == subject.canonical_sha256(unsigned)


def test_second_apply_refuses_on_bound_tail_drift(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _run(fixture, apply=True, receipt_path=fixture["receipt"])
    event_count = len(subject.validate_overlay_chain(fixture["overlay"])[0])

    with pytest.raises(subject.ApplyError, match="overlay tail drift"):
        _run(
            fixture,
            apply=True,
            receipt_path=tmp_path / "second-receipt.json",
        )

    assert len(subject.validate_overlay_chain(fixture["overlay"])[0]) == event_count
    assert not (tmp_path / "second-receipt.json").exists()


def test_receipt_is_create_only_before_overlay_append(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    before = fixture["overlay"].read_bytes()
    fixture["receipt"].write_text("sentinel\n", encoding="utf-8")

    with pytest.raises(subject.ApplyError, match="receipt path already exists"):
        _run(fixture, apply=True, receipt_path=fixture["receipt"])

    assert fixture["overlay"].read_bytes() == before
    assert fixture["receipt"].read_text(encoding="utf-8") == "sentinel\n"
