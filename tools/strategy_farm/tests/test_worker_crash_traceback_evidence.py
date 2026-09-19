"""Regression: a worker-crash INFRA_FAIL must preserve the FULL traceback.

Ticket c73ed341 (2026-09-19). The oos-2026-confirmation-v1 diagnostic-backfill
campaign carries 72/125 INFRA_FAIL rows since 2026-08-05, all landed by
``_fail_item_after_worker_crash`` (the generic run_item crash guard added
2026-08-22). Every one of them stamped the same generic ``_write``/
``sqlite3.IntegrityError`` tail into ``worker_crash_traceback_tail`` -- that
tail is the catch site, not the origin, so the real defect that keeps
crashing this campaign was unrecoverable from historical evidence alone.

This test locks in the fix: the full traceback is now also written to a
durable file under ``<root>/artifacts/ops/worker_crash_traceback/`` and the
path is recorded in the payload, without changing the verdict/evidence_path
sentinel contract the MNT-009 trigger enforces.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402

ITEM_ID = "wi-crash-fixture-1"
TERMINAL = "T4"
_INSERT = """
INSERT INTO work_items(
  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
  parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
) VALUES (?, 'backtest', 'Q09_NEWS', 'QM5_13128', 'NDX.DWX', 'test.set',
          'active', NULL, 0, NULL, NULL, ?, ?, ?, ?)
"""


def _seed_active_row(root: Path, *, payload: dict) -> None:
    now = "2026-09-19T09:35:52+00:00"
    with farmctl.connect(root) as conn:
        conn.execute(
            _INSERT,
            (ITEM_ID, TERMINAL, json.dumps(payload, sort_keys=True), now, now),
        )
        conn.commit()


def _fetch(root: Path) -> tuple[dict, dict]:
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status,verdict,verdict_taxonomy,evidence_path,payload_json "
            "FROM work_items WHERE id=?",
            (ITEM_ID,),
        ).fetchone()
    return dict(row), json.loads(row["payload_json"])


def test_full_traceback_persisted_to_a_durable_file(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    _seed_active_row(root, payload={"diagnostic_contract": "q09-live-news-backfill/v1"})

    long_tb = "\n".join(
        [
            "Traceback (most recent call last):",
            '  File "terminal_worker.py", line 9700, in _run_claimed_item',
            "    <the real origin frame the 6-line tail always discarded>",
            '  File "terminal_worker.py", line 14200, in _record_active_payload',
            "    return operation()",
            '  File "terminal_worker.py", line 12633, in _write',
            "    cursor = conn.execute(",
            "sqlite3.IntegrityError: terminal work_item requires evidence_path or"
            " EVIDENCE_UNAVAILABLE sentinel",
        ]
    )

    item_row = {"id": ITEM_ID}
    terminal_worker._fail_item_after_worker_crash(root, item_row, TERMINAL, long_tb)

    row, payload = _fetch(root)
    assert row["status"] == "failed"
    assert row["verdict"] == "INFRA_FAIL"
    assert row["verdict_taxonomy"] == "infra"
    assert row["evidence_path"] == farmctl._evidence_unavailable_sentinel(
        "worker_crashed_handling_item"
    )

    # Tail stays for backward compatibility with existing consumers.
    assert payload["worker_crash_traceback_tail"] == long_tb.strip().splitlines()[-6:]

    traceback_path = payload["worker_crash_traceback_path"]
    assert traceback_path is not None
    full_text = Path(traceback_path).read_text(encoding="utf-8")
    assert full_text == long_tb
    assert "_run_claimed_item" in full_text  # the frame the tail alone discards


def test_traceback_file_write_failure_does_not_block_the_infra_fail_landing(
    tmp_path: Path, monkeypatch
) -> None:
    """A forensics-file failure must never re-introduce the bare-write crash."""
    root = tmp_path / "farm"
    farmctl.init_db(root)
    _seed_active_row(root, payload={})

    def _boom(self, *args, **kwargs):  # noqa: ANN001 - Path.write_text signature
        raise OSError("disk full (simulated)")

    monkeypatch.setattr(Path, "write_text", _boom)

    terminal_worker._fail_item_after_worker_crash(root, {"id": ITEM_ID}, TERMINAL, "tb")

    row, payload = _fetch(root)
    assert row["status"] == "failed"
    assert row["verdict"] == "INFRA_FAIL"
    assert row["evidence_path"] == farmctl._evidence_unavailable_sentinel(
        "worker_crashed_handling_item"
    )
    assert payload["worker_crash_traceback_path"] is None
