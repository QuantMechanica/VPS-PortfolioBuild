"""Governed DL-089 queue-order tool.

Contract under test (OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 §2,
``docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md``):
``payload_json.queue_order_at`` is the only mutable field, the previous value is
preserved in the ``dl089_queue_order_set`` event, and the demoted programs keep
status, verdict, holds and every other payload key.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import dl089_matrix_service as matrix_service
from tools.strategy_farm import set_dl089_queue_order as queue_order


SCHEMA = """
CREATE TABLE work_items(
  id TEXT PRIMARY KEY,kind TEXT,ea_id TEXT,symbol TEXT,phase TEXT,
  status TEXT,verdict TEXT,claimed_by TEXT,created_at TEXT,updated_at TEXT,
  payload_json TEXT
);
CREATE TABLE work_item_holds(
  work_item_id TEXT PRIMARY KEY,hold_code TEXT NOT NULL,reason TEXT NOT NULL,
  active INTEGER NOT NULL,release_on_restart INTEGER NOT NULL,
  created_at TEXT NOT NULL,updated_at TEXT NOT NULL,released_at TEXT,release_note TEXT
);
CREATE TABLE events(
  id INTEGER PRIMARY KEY,ts TEXT NOT NULL,entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,event TEXT NOT NULL,detail_json TEXT NOT NULL
);
"""

PROGRAMS = [
    # (id, ea_id, symbol, created_at, queue_order_at)
    ("wi-10706", "QM5_10706", "GBPUSD.DWX", "2026-08-26T11:25:34+00:00", "2026-08-26T03:37:39+00:00"),
    ("wi-11422", "QM5_11422", "USDCAD.DWX", "2026-08-26T03:38:07+00:00", None),
    ("wi-21507", "QM5_21507", "XAUUSD.DWX", "2026-08-29T08:01:43+00:00", None),
    ("wi-20048", "QM5_20048", "XTIUSD.DWX", "2026-08-30T23:57:25+00:00", None),
    ("wi-21505", "QM5_21505", "XAGUSD.DWX", "2026-08-31T11:52:31+00:00", None),
]

DEFER_COMMON = {
    "ea_ids": ["QM5_10706", "QM5_11422"],
    "queue_order_at": queue_order.DEFER_QUEUE_ORDER_AT,
    "direction": "defer",
    "reason": "second passes of pairs that already count wait behind Q11-contiguous pairs",
    "owner_decision": "OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903",
}
TARGETS = [("wi-10706", "GBPUSD.DWX"), ("wi-11422", "USDCAD.DWX")]


def _payload(ea_id: str, symbol: str, queue_order_at: str | None) -> str:
    payload = {
        "schema": "qm.work-item.v1",
        "role": "PATTERN",
        "phase": "Q12",
        "routing_revision": matrix_service.PATTERN_DECLARATION_REVISION,
        "expected_symbol": symbol,
        "gate_contract_version": "v4",
        "pattern_filter_sweep": {
            "program_id": f"DL089_{ea_id}_{symbol.split('.')[0]}_DWX_2019_2025",
            "declared_trial_count": 154,
        },
    }
    if queue_order_at is not None:
        payload["queue_order_at"] = queue_order_at
    return json.dumps(payload, sort_keys=True)


def _db(tmp_path: Path, *, program_slots: int = 3) -> Path:
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.executescript(SCHEMA)
        conn.executemany(
            "INSERT INTO work_items VALUES(?,'backtest',?,?,'Q12','pending',NULL,NULL,?,?,?)",
            [
                (wid, ea, sym, created, created, _payload(ea, sym, qoa))
                for wid, ea, sym, created, qoa in PROGRAMS
            ],
        )
        # A non-DL-089 Q12 row must never be ranked or touched.
        conn.execute(
            "INSERT INTO work_items VALUES('wi-plain','backtest','QM5_9999','EURUSD.DWX',"
            "'Q12','pending',NULL,NULL,'2026-08-01T00:00:00+00:00','2026-08-01T00:00:00+00:00',"
            "'{\"role\": \"SINGLE\"}')"
        )
    return db


@pytest.fixture(autouse=True)
def _fixed_program_slots(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DL089_PROGRAM_SLOTS", "3")


def _ranks(order: list[dict]) -> dict[str, int]:
    return {entry["work_item_id"]: entry["rank"] for entry in order}


def test_plan_projects_the_slot_handover_without_writing(tmp_path: Path) -> None:
    db = _db(tmp_path)
    result = queue_order.plan_queue_order(db, TARGETS, **DEFER_COMMON)

    assert result["program_slots"] == 3
    assert [entry["work_item_id"] for entry in result["order_before"]][:3] == [
        "wi-10706", "wi-11422", "wi-21507",
    ]
    assert [entry["work_item_id"] for entry in result["order_after"]][:3] == [
        "wi-21507", "wi-20048", "wi-21505",
    ]
    # The two demoted programs land behind everything and lose their slot.
    after = {entry["work_item_id"]: entry for entry in result["order_after"]}
    assert after["wi-10706"]["slot"] is None
    assert after["wi-11422"]["machine_reason"] == "PROGRAM_SLOT_WAIT:K=3"
    assert result["would_update"] == 2
    assert result["targets"][0]["previous_queue_order_at"] == "2026-08-26T03:37:39+00:00"
    assert result["targets"][1]["previous_queue_order_at"] is None
    assert result["targets"][1]["previous_sort_key"] == "2026-08-26T03:38:07+00:00"
    assert [(t["rank_before"], t["rank_after"]) for t in result["targets"]] == [(1, 4), (2, 5)]
    # plan writes nothing.
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0
        stored = conn.execute("SELECT payload_json FROM work_items WHERE id='wi-11422'").fetchone()[0]
        assert "queue_order_at" not in json.loads(stored)


def test_apply_sets_queue_order_backs_up_and_audits_previous_value(tmp_path: Path) -> None:
    db = _db(tmp_path)
    result = queue_order.apply_queue_order(db, tmp_path / "backups", TARGETS, **DEFER_COMMON)

    assert result["updated"] == 2
    assert result["already_set"] == 0
    assert Path(result["backup"]["path"]).is_file()
    assert len(result["backup"]["sha256"]) == 64
    assert result["work_item_columns_touched"] == ["payload_json"]
    assert [entry["work_item_id"] for entry in result["order_after"]][:3] == [
        "wi-21507", "wi-20048", "wi-21505",
    ]
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        rows = {
            row["id"]: row
            for row in conn.execute("SELECT * FROM work_items WHERE id IN ('wi-10706','wi-11422')")
        }
        for row in rows.values():
            assert json.loads(row["payload_json"])["queue_order_at"] == queue_order.DEFER_QUEUE_ORDER_AT
        events = {
            row["entity_id"]: json.loads(row["detail_json"])
            for row in conn.execute("SELECT * FROM events WHERE event=?", (queue_order.EVENT_NAME,))
        }
    assert set(events) == {"wi-10706", "wi-11422"}
    assert events["wi-10706"]["previous_queue_order_at"] == "2026-08-26T03:37:39+00:00"
    assert events["wi-11422"]["previous_queue_order_at"] is None
    assert events["wi-11422"]["previous_sort_key"] == "2026-08-26T03:38:07+00:00"
    assert events["wi-10706"]["rank_before"] == 1 and events["wi-10706"]["rank_after"] == 4
    assert events["wi-11422"]["backup_sha256"] == result["backup"]["sha256"]
    assert events["wi-11422"]["owner_decision"] == DEFER_COMMON["owner_decision"]


def test_apply_never_touches_status_verdict_holds_or_other_payload_keys(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_item_holds VALUES('wi-10706','Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING',"
            "'rollout',1,1,'old','old',NULL,NULL)"
        )
        before = {
            row[0]: row[1:]
            for row in conn.execute(
                "SELECT id,kind,ea_id,symbol,phase,status,verdict,claimed_by,created_at,updated_at "
                "FROM work_items"
            )
        }
        holds_before = conn.execute("SELECT * FROM work_item_holds").fetchall()
        untouched_before = conn.execute(
            "SELECT payload_json FROM work_items WHERE id IN ('wi-21507','wi-plain')"
        ).fetchall()

    queue_order.apply_queue_order(db, tmp_path / "backups", TARGETS, **DEFER_COMMON)

    with sqlite3.connect(db) as conn:
        after = {
            row[0]: row[1:]
            for row in conn.execute(
                "SELECT id,kind,ea_id,symbol,phase,status,verdict,claimed_by,created_at,updated_at "
                "FROM work_items"
            )
        }
        assert after == before
        assert conn.execute("SELECT * FROM work_item_holds").fetchall() == holds_before
        assert (
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id IN ('wi-21507','wi-plain')"
            ).fetchall()
            == untouched_before
        )
        payload = json.loads(
            conn.execute("SELECT payload_json FROM work_items WHERE id='wi-10706'").fetchone()[0]
        )
    assert payload["role"] == "PATTERN"
    assert payload["routing_revision"] == matrix_service.PATTERN_DECLARATION_REVISION
    assert payload["pattern_filter_sweep"] == {
        "program_id": "DL089_QM5_10706_GBPUSD_DWX_2019_2025",
        "declared_trial_count": 154,
    }
    assert set(payload) == {
        "schema", "role", "phase", "routing_revision", "expected_symbol",
        "gate_contract_version", "pattern_filter_sweep", "queue_order_at",
    }


def test_repeated_apply_is_idempotent(tmp_path: Path) -> None:
    db = _db(tmp_path)
    first = queue_order.apply_queue_order(db, tmp_path / "b1", TARGETS, **DEFER_COMMON)
    second = queue_order.apply_queue_order(db, tmp_path / "b2", TARGETS, **DEFER_COMMON)
    assert (first["updated"], first["already_set"]) == (2, 0)
    assert (second["updated"], second["already_set"]) == (0, 2)
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event=?", (queue_order.EVENT_NAME,)
        ).fetchone()[0] == 2
    assert _ranks(second["order_after"])["wi-21507"] == 1


def test_precondition_mismatch_aborts_without_partial_writes(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE work_items SET claimed_by='T4' WHERE id='wi-11422'")
    with pytest.raises(queue_order.QueueOrderError, match="work_item_precondition:wi-11422"):
        queue_order.apply_queue_order(db, tmp_path / "backups", TARGETS, **DEFER_COMMON)
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0
        stored = json.loads(
            conn.execute("SELECT payload_json FROM work_items WHERE id='wi-10706'").fetchone()[0]
        )
    assert stored["queue_order_at"] == "2026-08-26T03:37:39+00:00"


def test_symbol_mismatch_and_unknown_id_abort(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with pytest.raises(queue_order.QueueOrderError, match="work_item_precondition:wi-10706:symbol"):
        queue_order.plan_queue_order(db, [("wi-10706", "EURUSD.DWX")], **DEFER_COMMON)
    with pytest.raises(queue_order.QueueOrderError, match="work_item_missing:wi-nope"):
        queue_order.plan_queue_order(db, [("wi-nope", "GBPUSD.DWX")], **DEFER_COMMON)


def test_ea_id_set_must_match_the_targets_exactly(tmp_path: Path) -> None:
    db = _db(tmp_path)
    common = {**DEFER_COMMON, "ea_ids": ["QM5_10706", "QM5_99999"]}
    with pytest.raises(queue_order.QueueOrderError, match="ea_id_precondition"):
        queue_order.plan_queue_order(db, TARGETS, **common)


def test_non_dl089_q12_row_is_refused(tmp_path: Path) -> None:
    db = _db(tmp_path)
    common = {**DEFER_COMMON, "ea_ids": ["QM5_9999"]}
    with pytest.raises(queue_order.QueueOrderError, match="not_a_governed_dl089_pattern_row"):
        queue_order.plan_queue_order(db, [("wi-plain", "EURUSD.DWX")], **common)


def test_front_with_now_is_refused_because_it_would_demote(tmp_path: Path) -> None:
    db = _db(tmp_path)
    common = {
        **DEFER_COMMON,
        "ea_ids": ["QM5_20048"],
        "queue_order_at": "2026-09-03T04:00:00+00:00",
        "direction": "front",
    }
    with pytest.raises(queue_order.QueueOrderError, match="front_does_not_advance:wi-20048"):
        queue_order.plan_queue_order(db, [("wi-20048", "XTIUSD.DWX")], **common)
    # An explicit timestamp ahead of the queue head does front the row.
    common["queue_order_at"] = "2026-08-01T00:00:00+00:00"
    result = queue_order.plan_queue_order(db, [("wi-20048", "XTIUSD.DWX")], **common)
    assert result["targets"][0]["rank_before"] == 4
    assert result["targets"][0]["rank_after"] == 1


def test_front_never_demotes_the_current_queue_head(tmp_path: Path) -> None:
    db = _db(tmp_path)
    common = {
        **DEFER_COMMON,
        "ea_ids": ["QM5_10706"],
        "queue_order_at": "2026-09-03T04:00:00+00:00",
        "direction": "front",
    }
    with pytest.raises(queue_order.QueueOrderError, match="front_does_not_advance:wi-10706"):
        queue_order.plan_queue_order(db, [("wi-10706", "GBPUSD.DWX")], **common)
    result = queue_order.plan_queue_order(
        db, [("wi-10706", "GBPUSD.DWX")], **{**common, "allow_no_reorder": True}
    )
    assert (result["targets"][0]["rank_before"], result["targets"][0]["rank_after"]) == (1, 5)


def test_defer_that_would_promote_is_refused(tmp_path: Path) -> None:
    db = _db(tmp_path)
    common = {
        **DEFER_COMMON,
        "ea_ids": ["QM5_21505"],
        "queue_order_at": "2026-08-01T00:00:00+00:00",
    }
    with pytest.raises(queue_order.QueueOrderError, match="defer_does_not_demote:wi-21505"):
        queue_order.plan_queue_order(db, [("wi-21505", "XAGUSD.DWX")], **common)


def test_list_is_read_only_and_reports_cells_and_slots(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        cell = json.dumps(
            {"schema": matrix_service.census.SCHEMA, "q12_work_item_id": "wi-10706"},
            sort_keys=True,
        )
        conn.executemany(
            "INSERT INTO work_items VALUES(?,'backtest','QM5_41000','GBPUSD.DWX','OPT_CENSUS',"
            "?,NULL,NULL,'2026-08-27T00:00:00+00:00','2026-08-27T00:00:00+00:00',?)",
            [("cell-1", "done", cell), ("cell-2", "pending", cell), ("cell-3", "pending", cell)],
        )
        digest_before = conn.execute("SELECT COUNT(*), SUM(LENGTH(payload_json)) FROM work_items").fetchone()

    result = queue_order.list_queue_order(db)

    assert result["program_slots"] == 3
    assert [entry["work_item_id"] for entry in result["slot_owners"]] == [
        "wi-10706", "wi-11422", "wi-21507",
    ]
    assert [entry["work_item_id"] for entry in result["waiting"]] == ["wi-20048", "wi-21505"]
    head = result["slot_owners"][0]
    assert head["ea_id"] == "QM5_10706" and head["symbol"] == "GBPUSD.DWX"
    assert head["sort_key"] == "2026-08-26T03:37:39+00:00"
    assert head["sort_key_source"] == "queue_order_at"
    assert head["cells_exist"] is True
    assert head["cells_pending"] == 2 and head["cells_done"] == 1
    assert result["slot_owners"][1]["sort_key_source"] == "created_at"
    assert result["slot_owners"][1]["cells_exist"] is False
    assert result["waiting"][0]["machine_reason"] == "PROGRAM_SLOT_WAIT:K=3"
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*), SUM(LENGTH(payload_json)) FROM work_items").fetchone() == digest_before


def test_list_exclude_id_models_a_non_candidate_row(tmp_path: Path) -> None:
    db = _db(tmp_path)
    result = queue_order.list_queue_order(db, exclude_ids=["wi-10706", "wi-11422"])
    assert result["excluded_ids"] == ["wi-10706", "wi-11422"]
    assert [entry["work_item_id"] for entry in result["slot_owners"]] == [
        "wi-21507", "wi-20048", "wi-21505",
    ]


def test_cli_plan_then_apply_round_trip(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    db = _db(tmp_path)
    argv = [
        "plan", "--db", str(db),
        "--target", "wi-10706=GBPUSD.DWX", "--target", "wi-11422=USDCAD.DWX",
        "--ea-id", "QM5_10706", "--ea-id", "QM5_11422",
        "--defer", "--reason", "slot order", "--owner-decision", DEFER_COMMON["owner_decision"],
    ]
    assert queue_order.main(argv) == 0
    planned = json.loads(capsys.readouterr().out)
    assert planned["status"] == "ok" and planned["would_update"] == 2

    assert queue_order.main(["apply", "--backup-dir", str(tmp_path / "b")] + argv[1:]) == 0
    applied = json.loads(capsys.readouterr().out)
    assert applied["status"] == "ok" and applied["updated"] == 2
    assert applied["queue_order_at"] == queue_order.DEFER_QUEUE_ORDER_AT

    assert queue_order.main(["list", "--db", str(db)]) == 0
    listed = json.loads(capsys.readouterr().out)
    assert [entry["work_item_id"] for entry in listed["slot_owners"]][0] == "wi-21507"


def test_cli_requires_owner_decision_reason_and_one_direction(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db = _db(tmp_path)
    base = [
        "plan", "--db", str(db), "--target", "wi-10706=GBPUSD.DWX", "--ea-id", "QM5_10706",
    ]
    assert queue_order.main(base + ["--defer", "--reason", "x"]) == 2
    assert "invalid_owner_decision" in capsys.readouterr().out
    assert queue_order.main(base + ["--defer", "--owner-decision", "OWNER-DEC-X-1"]) == 2
    assert "missing_reason" in capsys.readouterr().out
    assert queue_order.main(
        base + ["--reason", "x", "--owner-decision", "OWNER-DEC-X-1"]
    ) == 2
    assert "missing_direction" in capsys.readouterr().out
    assert queue_order.main(
        base + ["--reason", "x", "--owner-decision", "OWNER-DEC-X-1",
                "--queue-order-at", "2026-08-01T00:00:00"]
    ) == 2
    assert "missing_timezone" in capsys.readouterr().out


def test_defer_constant_sorts_behind_every_real_created_at(tmp_path: Path) -> None:
    db = _db(tmp_path)
    result = queue_order.plan_queue_order(db, TARGETS, **DEFER_COMMON)
    ordered = [entry["work_item_id"] for entry in result["order_after"]]
    assert ordered[-2:] == ["wi-10706", "wi-11422"]
    assert queue_order.DEFER_QUEUE_ORDER_AT > "2026-12-31T23:59:59+00:00"
