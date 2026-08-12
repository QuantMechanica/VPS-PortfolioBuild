import csv
import json
import os
import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import retire_approved_cards as subject  # noqa: E402


def _write_card(path: Path, spec: subject.RetirementSpec) -> None:
    fields = ["---", f"ea_id: {spec.ea_id}"]
    if spec.ea_id != "QM5_3005":
        fields.append("g0_status: APPROVED")
    if spec.reason_code == "R1_FAIL":
        fields.extend(
            [
                "r1_track_record: FAIL",
                'r1_reasoning: "fixture lineage failure"',
            ]
        )
    else:
        fields.append("r1_track_record: PASS")
    if spec.expected_trades_per_year is not None:
        fields.append(
            f"expected_trades_per_year_per_symbol: {spec.expected_trades_per_year:g}"
        )
    fields.extend(["---", "", f"# {spec.ea_id}", ""])
    path.write_text("\n".join(fields), encoding="utf-8")


def _write_reason_evidence(path: Path) -> None:
    fieldnames = [
        "ea_id",
        "expected_trades_per_year",
        "freq_note",
        "dead_family_confidence",
        "dead_family_reason",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for spec in subject.RETIREMENT_COHORT:
            if spec.reason_code == "TD_COUNTDOWN_OFF_EURUSD":
                writer.writerow(
                    {
                        "ea_id": spec.ea_id,
                        "dead_family_confidence": "HIGH",
                        "dead_family_reason": (
                            "TD-Reverse-Sequential/Countdown off-EURUSD "
                            "eliminated 2026-07-19 book decision"
                        ),
                    }
                )
            elif spec.reason_code == "BELOW_FIVE_TRADES_PER_YEAR":
                writer.writerow(
                    {
                        "ea_id": spec.ea_id,
                        "expected_trades_per_year": spec.expected_trades_per_year,
                        "freq_note": "BELOW_FLOOR(<5/yr, Q02 economics RETIRE-eligible)",
                    }
                )


def _make_db(path: Path) -> None:
    with sqlite3.connect(path) as connection:
        connection.executescript(
            """
            CREATE TABLE agent_tasks (
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                state TEXT NOT NULL,
                assigned_agent TEXT,
                artifact_path TEXT,
                verdict TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE work_items (
                id TEXT PRIMARY KEY,
                phase TEXT NOT NULL,
                ea_id TEXT NOT NULL,
                status TEXT NOT NULL,
                verdict TEXT,
                claimed_by TEXT,
                evidence_path TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )


def _authorization_payload(approved: Path, rejected: Path) -> dict:
    return {
        "operation": subject.AUTH_OPERATION,
        "allow_card_move": True,
        "allow_pending_work_retirement": True,
        "card_ids": list(subject.COHORT_IDS),
        "approved_root": str(approved),
        "rejected_root": str(rejected),
    }


def _insert_authorization(db: Path, approved: Path, rejected: Path) -> str:
    task_id = "authorized-ops-task"
    with sqlite3.connect(db) as connection:
        connection.execute(
            "INSERT INTO agent_tasks VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                task_id,
                "ops_issue",
                "IN_PROGRESS",
                "codex",
                None,
                None,
                json.dumps(_authorization_payload(approved, rejected)),
                "2026-07-20T00:00:00+00:00",
            ),
        )
    return task_id


@pytest.fixture
def cohort(tmp_path: Path) -> dict[str, Path]:
    approved = tmp_path / "cards_approved"
    rejected = tmp_path / "cards_rejected"
    approved.mkdir()
    rejected.mkdir()
    for spec in subject.RETIREMENT_COHORT:
        _write_card(approved / f"{spec.ea_id}_fixture.md", spec)
    evidence = tmp_path / "build_backlog_priority_v1.csv"
    _write_reason_evidence(evidence)
    db = tmp_path / "farm_state.sqlite"
    _make_db(db)
    return {
        "approved": approved,
        "rejected": rejected,
        "evidence": evidence,
        "db": db,
        "manifest": tmp_path / "retirement.json",
    }


def _config(cohort: dict[str, Path], **overrides) -> subject.RunConfig:
    values = {
        "approved_root": cohort["approved"],
        "rejected_root": cohort["rejected"],
        "db_path": cohort["db"],
        "reason_evidence_path": cohort["evidence"],
        "manifest_path": cohort["manifest"],
        "now_utc": "2026-07-20T00:00:00+00:00",
    }
    values.update(overrides)
    return subject.RunConfig(**values)


def test_dry_run_validates_exact_cohort_hashes_and_db_snapshots(
    cohort: dict[str, Path],
) -> None:
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO agent_tasks VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "closed-task",
                "build_ea",
                "RECYCLE",
                "codex",
                "artifact.json",
                "retired",
                json.dumps({"ea_id": "QM5_12941"}),
                "2026-07-19T00:00:00+00:00",
            ),
        )
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "closed-work",
                "Q02",
                "QM5_12702_xngusd",
                "done",
                "FAIL",
                None,
                "evidence.json",
                "{}",
                "2026-07-19T00:00:00+00:00",
                "2026-07-19T00:00:00+00:00",
            ),
        )

    before = {
        path.name: subject.sha256_file(path)
        for path in cohort["approved"].glob("*.md")
    }
    result = subject.run(_config(cohort))

    assert result["status"] == "DRY_RUN"
    assert [card["ea_id"] for card in result["cards"]] == list(subject.COHORT_IDS)
    assert all(card["move_state"] == "PLANNED" for card in result["cards"])
    assert all(
        card["source_sha256"] == card["expected_destination_sha256"]
        for card in result["cards"]
    )
    assert len(result["database_snapshot"]["agent_tasks"]) == 1
    assert len(result["database_snapshot"]["work_items"]) == 1
    assert result["scope_guards"]["database_write_scope"] == "none_dry_run"
    assert result["scope_guards"]["ea_ex5_mt5_touched"] is False
    assert not list(cohort["rejected"].glob("*.md"))
    assert before == {
        path.name: subject.sha256_file(path)
        for path in cohort["approved"].glob("*.md")
    }
    assert json.loads(cohort["manifest"].read_text(encoding="utf-8")) == result


@pytest.mark.parametrize("failure", ["missing", "duplicate", "rejected_collision"])
def test_refuses_missing_ambiguous_or_already_rejected_cards(
    cohort: dict[str, Path], failure: str
) -> None:
    source = cohort["approved"] / "QM5_12941_fixture.md"
    if failure == "missing":
        source.unlink()
    elif failure == "duplicate":
        (cohort["approved"] / "QM5_12941_second.md").write_bytes(source.read_bytes())
    else:
        (cohort["rejected"] / source.name).write_bytes(source.read_bytes())

    with pytest.raises(subject.RetirementError, match="QM5_12941"):
        subject.run(_config(cohort))
    assert not cohort["manifest"].exists()


def test_preserves_and_records_differently_named_rejected_card_with_same_id(
    cohort: dict[str, Path],
) -> None:
    historical = cohort["rejected"] / "QM5_1650_historical-other-strategy.md"
    historical.write_text("historical evidence", encoding="utf-8")

    result = subject.run(_config(cohort))

    card = next(card for card in result["cards"] if card["ea_id"] == "QM5_1650")
    assert card["preexisting_rejected_same_id_paths"] == [
        historical.resolve().as_posix()
    ]
    assert historical.read_text(encoding="utf-8") == "historical evidence"


def test_refuses_reason_drift(cohort: dict[str, Path]) -> None:
    card = cohort["approved"] / "QM5_1650_fixture.md"
    card.write_text(
        card.read_text(encoding="utf-8").replace(
            "r1_track_record: FAIL", "r1_track_record: PASS"
        ),
        encoding="utf-8",
    )
    with pytest.raises(subject.RetirementError, match="r1_track_record=FAIL"):
        subject.run(_config(cohort))


def test_execute_requires_exact_ops_authorization(cohort: dict[str, Path]) -> None:
    with pytest.raises(subject.RetirementError, match="--ops-task-id"):
        subject.run(_config(cohort, execute=True))
    assert not cohort["manifest"].exists()


def test_authorization_must_allow_pending_work_retirement(
    cohort: dict[str, Path],
) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    payload = _authorization_payload(cohort["approved"], cohort["rejected"])
    payload.pop("allow_pending_work_retirement")
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "UPDATE agent_tasks SET payload_json=? WHERE id=?",
            (json.dumps(payload), task_id),
        )

    with pytest.raises(
        subject.RetirementError, match="allow_pending_work_retirement=true"
    ):
        subject.run(_config(cohort, execute=True, ops_task_id=task_id))
    assert not cohort["manifest"].exists()


def test_dry_run_plans_unclaimed_pending_retirement_without_db_change(
    cohort: dict[str, Path],
) -> None:
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "pending-plan",
                "Q02",
                "QM5_12740_eia-wti-postdrive",
                "pending",
                None,
                None,
                None,
                json.dumps({"original": True}),
                "2026-07-20T00:01:00+00:00",
                "2026-07-20T00:01:00+00:00",
            ),
        )

    result = subject.run(_config(cohort))

    mutation = result["database_mutation"]
    assert result["status"] == "DRY_RUN"
    assert result["open_work_blockers"] == []
    assert mutation["state"] == "DRY_RUN_PLANNED"
    assert mutation["planned_work_item_ids"] == ["pending-plan"]
    assert mutation["before_rows"][0]["status"] == "pending"
    assert mutation["planned_after_rows"][0]["status"] == "done"
    assert mutation["planned_after_rows"][0]["verdict"] == "RETIRED_WITHOUT_BUILD"
    with sqlite3.connect(cohort["db"]) as connection:
        row = connection.execute(
            "SELECT status, verdict, payload_json FROM work_items "
            "WHERE id='pending-plan'"
        ).fetchone()
    assert row == ("pending", None, '{"original": true}')


def test_claimed_pending_work_is_a_hard_blocker(cohort: dict[str, Path]) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "claimed-pending",
                "Q02",
                "QM5_12740_eia-wti-postdrive",
                "pending",
                None,
                "T4",
                None,
                "{}",
                "2026-07-20T00:01:00+00:00",
                "2026-07-20T00:01:00+00:00",
            ),
        )

    result = subject.run(_config(cohort, execute=True, ops_task_id=task_id))

    assert result["status"] == "BLOCKED_ACTIVE_WORK"
    assert result["open_work_blockers"][0]["claimed_by"] == "T4"
    assert result["database_mutation"]["planned_work_item_ids"] == []
    assert len(list(cohort["approved"].glob("*.md"))) == 10


def test_active_work_blocks_execute_without_moving_cards(cohort: dict[str, Path]) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "active-q02",
                "Q02",
                "QM5_12740_eia-wti-postdrive",
                "active",
                None,
                "T4",
                None,
                "{}",
                "2026-07-20T00:01:00+00:00",
                "2026-07-20T00:01:00+00:00",
            ),
        )

    result = subject.run(_config(cohort, execute=True, ops_task_id=task_id))

    assert result["status"] == "BLOCKED_ACTIVE_WORK"
    assert result["open_work_blockers"] == [
        {
            "kind": "work_item",
            "id": "active-q02",
            "status": "active",
            "phase": "Q02",
            "claimed_by": "T4",
            "matched_ea_ids": ["QM5_12740"],
        }
    ]
    assert len(list(cohort["approved"].glob("*.md"))) == 10
    assert not list(cohort["rejected"].glob("*.md"))


def test_execute_moves_only_cards_and_records_destination_hashes(
    cohort: dict[str, Path], tmp_path: Path
) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "pending-q02",
                "Q02",
                "QM5_12740_eia-wti-postdrive",
                "pending",
                None,
                None,
                None,
                json.dumps({"fixture": True}),
                "2026-07-20T00:01:00+00:00",
                "2026-07-20T00:01:00+00:00",
            ),
        )
    ea_dir = tmp_path / "framework" / "EAs" / "QM5_3005_alpha-inst-magnet"
    ea_dir.mkdir(parents=True)
    mq5 = ea_dir / "QM5_3005_alpha-inst-magnet.mq5"
    ex5 = ea_dir / "QM5_3005_alpha-inst-magnet.ex5"
    mq5.write_bytes(b"source sentinel")
    ex5.write_bytes(b"binary sentinel")
    sentinels = {mq5: subject.sha256_file(mq5), ex5: subject.sha256_file(ex5)}

    result = subject.run(_config(cohort, execute=True, ops_task_id=task_id))

    assert result["status"] == "COMPLETE"
    assert not list(cohort["approved"].glob("*.md"))
    assert len(list(cohort["rejected"].glob("*.md"))) == 10
    for card in result["cards"]:
        assert card["move_state"] == "MOVED"
        assert card["destination_sha256"] == card["source_sha256"]
    assert {path: subject.sha256_file(path) for path in sentinels} == sentinels
    assert result["database_mutation"]["state"] == "COMMITTED"
    assert result["database_mutation"]["planned_work_item_ids"] == ["pending-q02"]
    with sqlite3.connect(cohort["db"]) as connection:
        connection.row_factory = sqlite3.Row
        retired = dict(
            connection.execute(
                "SELECT * FROM work_items WHERE id='pending-q02'"
            ).fetchone()
        )
    assert retired["status"] == "done"
    assert retired["verdict"] == "RETIRED_WITHOUT_BUILD"
    assert retired["claimed_by"] is None
    assert retired["evidence_path"] == cohort["manifest"].resolve().as_posix()
    audit = json.loads(retired["payload_json"])["retirement_audit"]
    assert audit["operation"] == subject.AUTH_OPERATION
    assert audit["ops_task_id"] == task_id


def test_partial_failure_rolls_back_every_completed_move(
    cohort: dict[str, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    with sqlite3.connect(cohort["db"]) as connection:
        connection.execute(
            "INSERT INTO work_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "pending-rollback",
                "Q02",
                "QM5_12740_eia-wti-postdrive",
                "pending",
                None,
                None,
                None,
                "{}",
                "2026-07-20T00:01:00+00:00",
                "2026-07-20T00:01:00+00:00",
            ),
        )
    real_move = os.replace
    calls = 0

    def fail_third_move(source: Path, destination: Path) -> None:
        nonlocal calls
        calls += 1
        if calls == 3:
            raise OSError("injected move failure")
        real_move(source, destination)

    monkeypatch.setattr(subject, "_atomic_move", fail_third_move)
    with pytest.raises(subject.RetirementError, match="ROLLED_BACK"):
        subject.run(_config(cohort, execute=True, ops_task_id=task_id))

    manifest = json.loads(cohort["manifest"].read_text(encoding="utf-8"))
    assert manifest["status"] == "ROLLED_BACK"
    assert len(list(cohort["approved"].glob("*.md"))) == 10
    assert not list(cohort["rejected"].glob("*.md"))
    assert [card["move_state"] for card in manifest["cards"][:2]] == [
        "ROLLED_BACK",
        "ROLLED_BACK",
    ]
    assert manifest["database_mutation"]["state"] == "ROLLED_BACK"
    with sqlite3.connect(cohort["db"]) as connection:
        row = connection.execute(
            "SELECT status, verdict, payload_json FROM work_items "
            "WHERE id='pending-rollback'"
        ).fetchone()
    assert row == ("pending", None, "{}")


def test_snapshot_drift_is_refused_under_write_lock(
    cohort: dict[str, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    task_id = _insert_authorization(
        cohort["db"], cohort["approved"], cohort["rejected"]
    )
    original = subject._database_snapshot_from_connection
    calls = 0

    def drift_on_locked_snapshot(connection, db_path, *, read_only):
        nonlocal calls
        calls += 1
        snapshot = original(connection, db_path, read_only=read_only)
        if calls == 2:
            snapshot["snapshot_sha256"] = "0" * 64
        return snapshot

    monkeypatch.setattr(
        subject, "_database_snapshot_from_connection", drift_on_locked_snapshot
    )
    with pytest.raises(subject.RetirementError, match="BLOCKED_DB_DRIFT"):
        subject.run(_config(cohort, execute=True, ops_task_id=task_id))

    manifest = json.loads(cohort["manifest"].read_text(encoding="utf-8"))
    assert manifest["status"] == "BLOCKED_DB_DRIFT"
    assert manifest["database_mutation"]["state"] == "ROLLED_BACK"
    assert len(list(cohort["approved"].glob("*.md"))) == 10
    assert not list(cohort["rejected"].glob("*.md"))
