"""Regression: the poison-pill seal must bind evidence on its TERMINAL write.

P55 / task 145b20a4. The pump stage ``poison_pill_refresh`` aborted on every
cycle with::

    IntegrityError('terminal work_item requires evidence_path or
                    EVIDENCE_UNAVAILABLE sentinel')

(see ``D:/QM/strategy_farm/logs/pump_task_20260902T19*.log`` and
``pump_task_20260903T01*.log``). ``_seal_summary_missing_pending`` wrote
``status='failed', verdict='INVALID'`` and left ``evidence_path`` untouched
(NULL on a pending row), which the DB's terminal-evidence trigger correctly
refuses. Because the seal runs inside the same transaction as the
``poison_pill_quarantine`` upserts, the abort also rolled those back -- the
quarantine table had no operator at all while this was broken.

The fix binds the canonical ``EVIDENCE_UNAVAILABLE:<reason>`` sentinel (or keeps
an already-bound real path) instead of a silent NULL. The trigger is never
touched.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import poison_pill_quarantine as pp  # noqa: E402


# The live farm_state.sqlite enforces a BROADER evidence rule than the repo
# schema ships. In-repo MNT-009 is deliberately scoped to verdict='INFRA_FAIL'
# (docs/ops/evidence/2026-08-21_mnt009_infra_fail_evidence_binding.md), but the
# live DB additionally carries trg_work_items_terminal_requires_evidence_{insert,
# update} covering EVERY non-null terminal verdict -- including the 'INVALID'
# this seal writes. Read off the live DB read-only (sqlite3 URI mode=ro,
# sqlite_master) on 2026-09-03; its RAISE message is verbatim the one in the
# failing pump logs. Reproduced here so the regression test exercises the
# constraint that actually fires in production rather than a weaker local one.
LIVE_TERMINAL_EVIDENCE_TRIGGERS = """
CREATE TRIGGER IF NOT EXISTS trg_work_items_terminal_requires_evidence_insert
BEFORE INSERT ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict IS NOT NULL
     AND (NEW.evidence_path IS NULL OR trim(NEW.evidence_path) = '')
BEGIN
    SELECT RAISE(ABORT, 'terminal work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel');
END;
CREATE TRIGGER IF NOT EXISTS trg_work_items_terminal_requires_evidence_update
BEFORE UPDATE OF status, verdict ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict IS NOT NULL
     AND (NEW.evidence_path IS NULL OR trim(NEW.evidence_path) = '')
BEGIN
    SELECT RAISE(ABORT, 'terminal work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel');
END;
"""

EA_ID = "QM5_9001"
SYMBOL = "GBPUSD.DWX"
PHASE = "Q02"
PENDING_ID = "wi-poison-pending"
EXPECTED_SENTINEL = "EVIDENCE_UNAVAILABLE:poison_pill:summary_missing_retries_exhausted"

_INSERT = """
INSERT INTO work_items(
  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
  parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
) VALUES (?, 'backtest', ?, ?, ?, 'test.set', ?, ?, 0, NULL, ?, NULL, ?, ?, ?)
"""


def _seed(
    db: Path,
    *,
    live_triggers: bool = True,
    pending_evidence_path: str | None = None,
    infra_rows: int = 5,
) -> None:
    """One (EA, symbol, phase) triple: N sealed INFRA_FAILs + one pending heir."""
    with sqlite3.connect(db) as conn:
        if live_triggers:
            conn.executescript(LIVE_TERMINAL_EVIDENCE_TRIGGERS)
        infra_payload = json.dumps(
            {
                "verdict_reason": pp.SUMMARY_MISSING_EXHAUSTED,
                "verdict_taxonomy": "infra",
            },
            sort_keys=True,
        )
        for index in range(infra_rows):
            stamp = f"2026-09-0{index + 1}T00:00:00+00:00"
            conn.execute(
                _INSERT,
                (
                    f"wi-poison-infra-{index}", PHASE, EA_ID, SYMBOL,
                    "failed", "INFRA_FAIL",
                    farmctl._evidence_unavailable_sentinel("test_fixture"),
                    infra_payload, stamp, stamp,
                ),
            )
        now = "2026-09-03T00:00:00+00:00"
        conn.execute(
            _INSERT,
            (
                PENDING_ID, PHASE, EA_ID, SYMBOL, "pending", None,
                pending_evidence_path, "{}", now, now,
            ),
        )
        conn.commit()


@pytest.fixture()
def db(tmp_path: Path) -> Path:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    return root / farmctl.DB_REL


def _connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def test_triple_is_scan_eligible(db: Path) -> None:
    """Guard the fixture: without eligibility the other cases prove nothing."""
    _seed(db)
    with _connect(db) as conn:
        found = pp.scan(conn)
    assert [(item["ea_id"], item["symbol"], item["phase"]) for item in found] == [
        (EA_ID, SYMBOL, PHASE)
    ]
    assert found[0]["verdict_reason"] == pp.SUMMARY_MISSING_EXHAUSTED


def test_old_seal_statement_without_evidence_path_aborts(db: Path) -> None:
    """The pre-fix write site, verbatim: no evidence_path -> IntegrityError."""
    _seed(db)
    payload = json.dumps({"verdict_taxonomy": "invalid"}, sort_keys=True)
    with _connect(db) as conn, pytest.raises(
        sqlite3.IntegrityError,
        match="terminal work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel",
    ):
        conn.execute(
            """UPDATE work_items
               SET status='failed',verdict='INVALID',payload_json=?,updated_at=?
               WHERE id=? AND status='pending'""",
            (payload, "2026-09-03T01:00:00+00:00", PENDING_ID),
        )


def test_refresh_pending_binds_evidence_unavailable_sentinel(db: Path) -> None:
    _seed(db)
    with _connect(db) as conn:
        found = pp.refresh_pending(conn)
        conn.commit()
        row = conn.execute(
            "SELECT status,verdict,evidence_path,payload_json FROM work_items WHERE id=?",
            (PENDING_ID,),
        ).fetchone()
    assert found[0]["sealed_pending_rows"] == 1
    assert row["status"] == "failed"
    assert row["verdict"] == "INVALID"
    assert row["evidence_path"] == EXPECTED_SENTINEL
    disposition = json.loads(row["payload_json"])["poison_pill_disposition"]
    assert disposition["evidence_path"] == EXPECTED_SENTINEL
    assert disposition["evidence_binding"] == "sentinel"
    assert disposition["verdict"] == "INVALID"


def test_refresh_pending_keeps_an_already_bound_evidence_path(db: Path) -> None:
    """Append-only: a real path on the heir row is never overwritten."""
    real = r"D:\QM\reports\pipeline\QM5_9001\GBPUSD.DWX\Q02\run.log"
    _seed(db, pending_evidence_path=real)
    with _connect(db) as conn:
        pp.refresh_pending(conn)
        conn.commit()
        row = conn.execute(
            "SELECT evidence_path,payload_json FROM work_items WHERE id=?", (PENDING_ID,)
        ).fetchone()
    assert row["evidence_path"] == real
    disposition = json.loads(row["payload_json"])["poison_pill_disposition"]
    assert disposition["evidence_binding"] == "existing"
    assert disposition["evidence_path"] == real


def test_quarantine_upsert_survives_the_seal(db: Path) -> None:
    """Blast radius: the abort used to roll back the upserts in the same tx."""
    _seed(db)
    with _connect(db) as conn:
        pp.refresh_pending(conn)
        conn.commit()
        row = conn.execute(
            "SELECT active,verdict_reason,consecutive_failures FROM poison_pill_quarantine "
            "WHERE ea_id=? AND symbol=? AND phase=?",
            (EA_ID, SYMBOL, PHASE),
        ).fetchone()
    assert row is not None
    assert row["active"] == 1
    assert row["verdict_reason"] == pp.SUMMARY_MISSING_EXHAUSTED
    assert row["consecutive_failures"] == 5


def test_seal_binds_sentinel_on_the_repo_only_schema_too(db: Path) -> None:
    """Fail-closed regardless of which evidence trigger the DB happens to carry."""
    _seed(db, live_triggers=False)
    with _connect(db) as conn:
        pp.refresh_pending(conn)
        conn.commit()
        row = conn.execute(
            "SELECT verdict,evidence_path FROM work_items WHERE id=?", (PENDING_ID,)
        ).fetchone()
    assert row["verdict"] == "INVALID"
    assert row["evidence_path"] == EXPECTED_SENTINEL


def test_seal_evidence_reason_matches_the_stamped_verdict_reason(db: Path) -> None:
    """The sentinel reason and the payload verdict_reason are one string."""
    _seed(db)
    with _connect(db) as conn:
        pp.refresh_pending(conn)
        conn.commit()
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (PENDING_ID,)
            ).fetchone()["payload_json"]
        )
    assert payload["verdict_reason"] == pp.SEAL_EVIDENCE_REASON
    assert payload["final_failure"] == pp.SUMMARY_MISSING_EXHAUSTED
    assert (
        pp._evidence_unavailable_sentinel(pp.SEAL_EVIDENCE_REASON)
        == farmctl._evidence_unavailable_sentinel(pp.SEAL_EVIDENCE_REASON)
        == EXPECTED_SENTINEL
    )


def test_non_summary_missing_triples_are_not_sealed(db: Path) -> None:
    """Only the terminal graveyard class is sealed; other poison stays pending."""
    _seed(db)
    with _connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id LIKE 'wi-poison-infra-%'",
            (json.dumps({"verdict_reason": "ACTIVE_TIMEOUT", "verdict_taxonomy": "infra"},
                        sort_keys=True),),
        )
        conn.commit()
        found = pp.refresh_pending(conn)
        conn.commit()
        row = conn.execute(
            "SELECT status,verdict,evidence_path FROM work_items WHERE id=?", (PENDING_ID,)
        ).fetchone()
    assert found[0]["sealed_pending_rows"] == 0
    assert row["status"] == "pending"
    assert row["verdict"] is None
    assert row["evidence_path"] is None
