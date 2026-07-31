from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

import pytest

from tools.strategy_farm import farmctl
from tools.strategy_farm import set_priority_track as controller


TARGET_ID = "6dce5d90-4a59-4753-9830-9eebdaeed397"
OTHER_ID = "11111111-1111-4111-8111-111111111111"


def _write_registry(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "schema_version": "qm.owner-priority-tracks/v1",
                "policy": "EXPLICIT_OWNER_ORDERING_PRIOR_NOT_PIPELINE_EVIDENCE",
                "entries": [
                    {
                        "ea_id": "QM5_20007",
                        "priority_track": True,
                        "asset_class": "index_metal",
                        "timeframe": "M5/M15",
                        "target_symbols": ["GDAXI.DWX", "NDX.DWX", "XAUUSD.DWX"],
                        "excluded_symbols": ["SP500.DWX"],
                        "owner_reference": controller.OWNER_REFERENCE,
                        "decision_date": "2026-07-31",
                        "reason": "fixture",
                        "decision_source": {
                            "path": "decision.md",
                            "sha256": "a" * 64,
                            "commit_sha": "b" * 40,
                        },
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return path


def _provenance(registry: Path) -> dict[str, Any]:
    return {
        "head_commit": "c" * 40,
        "controller": {
            "path": str(Path(controller.__file__).resolve()),
            "sha256": controller.normalized_text_sha256(Path(controller.__file__)),
            "sha256_basis": "UTF8_TEXT_LF_NORMALIZED",
        },
        "registry": {
            "path": str(registry.resolve()),
            "sha256": controller.normalized_text_sha256(registry),
            "sha256_basis": "UTF8_TEXT_LF_NORMALIZED",
        },
        "source_scope_clean": True,
    }


def _insert_row(
    conn: sqlite3.Connection,
    work_item_id: str,
    *,
    ea_id: str = "QM5_20007",
    symbol: str = "NDX.DWX",
    phase: str = "Q02",
    status: str = "pending",
    verdict: str | None = None,
    claimed_by: str | None = None,
    payload: dict[str, Any] | None = None,
    updated_at: str = "2026-07-31T12:00:00Z",
) -> str:
    raw = json.dumps(payload or {}, sort_keys=True, separators=(",", ":"))
    conn.execute(
        """
        INSERT INTO work_items(
          id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
          attempt_count, parent_task_id, evidence_path, claimed_by,
          payload_json, created_at, updated_at
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            work_item_id,
            "backtest",
            phase,
            ea_id,
            symbol,
            f"{ea_id}_{symbol}_{phase}.set",
            status,
            verdict,
            0,
            None,
            None,
            claimed_by,
            raw,
            "2026-07-31T12:00:00Z",
            updated_at,
        ),
    )
    return raw


def _fixture(tmp_path: Path, *, target_kwargs: dict[str, Any] | None = None) -> dict[str, Any]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = farmctl.db_path(root)
    with farmctl.connect(root) as conn:
        raw = _insert_row(conn, TARGET_ID, **(target_kwargs or {}))
        for index, phase in enumerate(("Q04", "Q04", "Q03"), start=1):
            _insert_row(
                conn,
                f"00000000-0000-4000-8000-{index:012d}",
                ea_id=f"QM5_{30000 + index}",
                symbol="EURUSD.DWX",
                phase=phase,
                updated_at=f"2026-07-31T11:0{index}:00Z",
            )
        conn.commit()
    registry = _write_registry(tmp_path / "repo" / "owner_priority_tracks.json")
    expectations_path = tmp_path / "expectations.json"
    expectations_path.write_text(
        json.dumps(
            {
                "schema_version": controller.EXPECTATIONS_SCHEMA,
                "owner_reference": controller.OWNER_REFERENCE,
                "mode": "EXACT_ID_NO_WAVE_NO_BULK",
                "rows": [
                    {
                        "work_item_id": TARGET_ID,
                        "expected_status": "pending",
                        "expected_phase": "Q02",
                        "expected_payload_sha256": controller.payload_sha256(raw),
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    expectations_doc, expectations_sha = controller.load_json(
        expectations_path, "expectations"
    )
    expectations = controller.validate_expectations(expectations_doc, (TARGET_ID,))
    return {
        "root": root,
        "db": db,
        "repo": tmp_path / "repo",
        "registry": registry,
        "expectations_path": expectations_path,
        "expectations": expectations,
        "expectations_sha": expectations_sha,
        "provenance": _provenance(registry),
        "lock": tmp_path / "FACTORY_MUTATION.lock",
        "journal": tmp_path / "journal.json",
    }


def _plan(fixture: dict[str, Any]) -> dict[str, Any]:
    conn = controller.connect_ro(fixture["db"])
    try:
        conn.execute("BEGIN")
        plan = controller.build_plan(
            conn,
            (TARGET_ID,),
            fixture["expectations"],
            fixture["expectations_path"],
            fixture["expectations_sha"],
            fixture["repo"],
            fixture["registry"],
            provenance=fixture["provenance"],
        )
        conn.rollback()
        return plan
    finally:
        conn.close()


def test_validate_exact_ids_requires_full_canonical_uuid() -> None:
    assert controller.validate_exact_ids((TARGET_ID,)) == (TARGET_ID,)
    with pytest.raises(controller.PriorityTrackError, match="full canonical UUID"):
        controller.validate_exact_ids((TARGET_ID[:8],))
    with pytest.raises(controller.PriorityTrackError, match="duplicate"):
        controller.validate_exact_ids((TARGET_ID, TARGET_ID))


def test_dry_run_is_exact_and_measures_canonical_displacement(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)

    plan = _plan(fixture)

    assert plan["status"] == "READY_FOR_APPLY"
    assert plan["exact_ids"] == [TARGET_ID]
    assert plan["mutation_performed"] is False
    delta = plan["claim_order_displacement"]
    assert delta["targets"][TARGET_ID]["before_rank"] == 4
    assert delta["targets"][TARGET_ID]["after_rank"] == 1
    assert delta["displaced_rows"] == 3
    assert delta["displaced_q04_plus"] == 2


@pytest.mark.parametrize(
    ("target_kwargs", "blocker"),
    [
        ({"status": "failed", "verdict": "INFRA_FAIL"}, "status actual='failed'"),
        ({"claimed_by": "T1"}, "claimed_by is 'T1'"),
        ({"payload": {"priority_track": True}}, "priority_track already true"),
        ({"payload": {"recovery_class": "LOCK_STORM"}}, "recovery-class"),
        ({"symbol": "SP500.DWX"}, "explicitly excluded"),
    ],
)
def test_plan_fails_closed_for_ineligible_rows(
    tmp_path: Path, target_kwargs: dict[str, Any], blocker: str
) -> None:
    fixture = _fixture(tmp_path, target_kwargs=target_kwargs)

    plan = _plan(fixture)

    assert plan["status"] == "BLOCKED"
    assert any(blocker in item for item in plan["blockers"])
    assert plan["claim_order_displacement"] is None


def test_payload_sha_cas_drift_blocks_without_journal(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    with sqlite3.connect(fixture["db"]) as conn:
        conn.execute("UPDATE work_items SET payload_json='{} ' WHERE id=?", (TARGET_ID,))

    plan = _plan(fixture)

    assert plan["status"] == "BLOCKED"
    assert any("payload_sha256 actual=" in item for item in plan["blockers"])
    assert not fixture["journal"].exists()


def test_apply_journals_exact_cas_event_and_guarded_revert(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path)
    monkeypatch.setattr(controller, "_git_provenance", lambda *_args: fixture["provenance"])

    applied = controller.apply_plan(
        fixture["db"],
        (TARGET_ID,),
        fixture["expectations"],
        fixture["expectations_path"],
        fixture["expectations_sha"],
        fixture["expectations_sha"],
        fixture["repo"],
        fixture["registry"],
        controller.normalized_text_sha256(fixture["registry"]),
        fixture["lock"],
        fixture["journal"],
    )

    assert applied["status"] == "APPLIED"
    assert applied["changed_rows"] == 1
    assert applied["exact_ids"] == [TARGET_ID]
    assert not fixture["lock"].exists()
    journal, journal_sha = controller.load_json(fixture["journal"], "journal")
    assert journal["state"] == "committed"
    assert journal_sha == applied["journal_sha256"]
    with sqlite3.connect(fixture["db"]) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (TARGET_ID,)).fetchone()
        events = conn.execute(
            "SELECT event FROM events WHERE entity_id=? ORDER BY id", (TARGET_ID,)
        ).fetchall()
    payload = json.loads(row["payload_json"])
    assert payload["priority_track"] is True
    assert payload["priority_track_backfill"]["pipeline_verdict_changed"] is False
    assert [event[0] for event in events] == ["priority_track_backfill_applied"]

    reverted = controller.revert_journal(
        fixture["db"], fixture["journal"], journal_sha, fixture["lock"]
    )

    assert reverted["status"] == "REVERTED"
    with sqlite3.connect(fixture["db"]) as conn:
        restored = conn.execute(
            "SELECT payload_json, updated_at FROM work_items WHERE id=?", (TARGET_ID,)
        ).fetchone()
        events = conn.execute(
            "SELECT event FROM events WHERE entity_id=? ORDER BY id", (TARGET_ID,)
        ).fetchall()
    assert restored == ("{}", "2026-07-31T12:00:00Z")
    assert [event[0] for event in events] == [
        "priority_track_backfill_applied",
        "priority_track_backfill_reverted",
    ]


def test_guarded_revert_refuses_post_apply_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path)
    monkeypatch.setattr(controller, "_git_provenance", lambda *_args: fixture["provenance"])
    applied = controller.apply_plan(
        fixture["db"],
        (TARGET_ID,),
        fixture["expectations"],
        fixture["expectations_path"],
        fixture["expectations_sha"],
        fixture["expectations_sha"],
        fixture["repo"],
        fixture["registry"],
        controller.normalized_text_sha256(fixture["registry"]),
        fixture["lock"],
        fixture["journal"],
    )
    with sqlite3.connect(fixture["db"]) as conn:
        conn.execute("UPDATE work_items SET updated_at='drifted' WHERE id=?", (TARGET_ID,))

    with pytest.raises(controller.PriorityTrackError, match="drifted"):
        controller.revert_journal(
            fixture["db"],
            fixture["journal"],
            applied["journal_sha256"],
            fixture["lock"],
        )

    assert not fixture["lock"].exists()


def test_apply_refuses_expectation_or_registry_hash_mismatch(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    with pytest.raises(controller.PriorityTrackError, match="expectations SHA-256 mismatch"):
        controller.apply_plan(
            fixture["db"],
            (TARGET_ID,),
            fixture["expectations"],
            fixture["expectations_path"],
            fixture["expectations_sha"],
            "f" * 64,
            fixture["repo"],
            fixture["registry"],
            controller.normalized_text_sha256(fixture["registry"]),
            fixture["lock"],
            fixture["journal"],
        )
    assert not fixture["journal"].exists()
    assert not fixture["lock"].exists()
