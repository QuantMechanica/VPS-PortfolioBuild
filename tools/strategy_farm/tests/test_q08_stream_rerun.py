from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import q08_stream_rerun as service


class Farm:
    """Real temporary DB and evidence; only the governed enqueue is substituted."""
    def __init__(self, root):
        self.root = root
        self.calls = []

    def _assert_canonical_checkout(self):
        pass

    def _preferred_ea_dir(self, ea):
        return self.root / "repo" / "framework" / "EAs" / f"{ea}_fixture"

    def connect(self, root):
        con = sqlite3.connect(root / "state" / "farm_state.sqlite")
        con.row_factory = sqlite3.Row
        return con

    def enqueue_cascade_backtest_for_ea(self, root, **kwargs):
        self.calls.append(kwargs)
        wid = f"rerun_{len(self.calls)}"
        with self.connect(root) as con:
            con.execute(
                "INSERT INTO work_items(id,ea_id,symbol,phase,status,updated_at,payload_json) "
                "VALUES (?,?,?,'Q08','pending',?,?)",
                (wid, kwargs["ea_id"], "EURUSD.DWX", "2026-09-04T12:00:00Z", json.dumps({
                    "rerun_reason": kwargs["rerun_reason"],
                    "expected_current_ex5_sha256": kwargs["expected_current_ex5_sha256"],
                })),
            )
        return {"enqueued": True, "created": [{"id": wid}], "requeued": [], "skipped": []}

    def event(self, con, kind, entity, name, detail):
        con.execute("INSERT INTO events VALUES (?, ?, ?)", (entity, name, json.dumps(detail)))


@pytest.fixture
def layout(tmp_path, monkeypatch):
    monkeypatch.delenv(service.DISABLE_ENV, raising=False)
    root = tmp_path / "farm"
    (root / "state").mkdir(parents=True)
    farm = Farm(root)
    with farm.connect(root) as con:
        con.executescript("""
            CREATE TABLE work_items(id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT,
                phase TEXT, status TEXT, verdict TEXT, updated_at TEXT,
                ex5_sha256 TEXT, payload_json TEXT, evidence_path TEXT);
            CREATE TABLE events(entity_id TEXT, event TEXT, detail_json TEXT);
        """)
    seed(farm)
    return root, farm


def seed(farm, ea="QM5_9001", symbol="EURUSD.DWX", q14="q14", q07="q07", q08="q08",
         digest=None, target_verdict="PASS"):
    directory = farm._preferred_ea_dir(ea)
    directory.mkdir(parents=True, exist_ok=True)
    binary = directory / f"{directory.name}.ex5"
    binary.write_bytes(b"fixture-binary")
    digest = digest or hashlib.sha256(binary.read_bytes()).hexdigest()
    with farm.connect(farm.root) as con:
        for wid, phase, verdict, timestamp in [
            (q07, "Q07", "PASS", "2026-09-04T09:00:00Z"),
            (q08, "Q08", target_verdict, "2026-09-04T10:00:00Z"),
            (q14, "Q14", "KEEP_INCUMBENT", "2026-09-04T11:00:00Z"),
        ]:
            con.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
                (wid, ea, symbol, phase, "done", verdict, timestamp, digest, "{}", None))
    return digest


def run(layout, **kwargs):
    root, farm = layout
    return service.service(root, farm_module=farm, **kwargs)


def bind(layout):
    root, farm = layout
    with farm.connect(root) as con:
        digest = con.execute("SELECT ex5_sha256 FROM work_items WHERE id='q14'").fetchone()[0]
        evidence = root / "aggregate.json"
        evidence.write_text(json.dumps({"portfolio_stream": {
            "source_ex5_sha256": digest, "content_sha256": "a" * 64}}))
        con.execute("UPDATE work_items SET evidence_path=? WHERE id='q08'", (str(evidence),))


def test_missing_stream_enqueues_once_with_exact_sources_and_event(layout):
    first = run(layout, apply=True)
    assert first["created_count"] == 1
    root, farm = layout
    call = farm.calls[0]
    assert call["predecessor_work_item_id"] == "q07"
    assert call["append_only_rerun_of"] == "q08"
    assert call["phase"] == "Q08"
    assert call["expected_current_ex5_sha256"] == hashlib.sha256(b"fixture-binary").hexdigest()
    assert call["rerun_reason"] == (
        "Q08 sealed-stream re-emission after Q14 KEEP_INCUMBENT 2026-09-04T11:00:00Z: "
        "current-identity daily-PnL bytes missing from sleeve_streams; append-only "
        "rerun to reproduce the seal for the book-path bundle (D4)."
    )
    assert run(layout, apply=True)["items"] == []
    assert len(farm.calls) == 1
    with farm.connect(root) as con:
        event = con.execute("SELECT * FROM events").fetchone()
        assert event["event"] == "q08_stream_rerun_auto_minted"
        assert json.loads(event["detail_json"])["q14_work_item_id"] == "q14"
        assert con.execute("SELECT verdict FROM work_items WHERE id='q08'").fetchone()[0] == "PASS"


def test_bound_pair_never_enqueues(layout):
    bind(layout)
    assert run(layout, apply=True)["items"][0]["reason"] == "stream_already_bound"
    assert not layout[1].calls


@pytest.mark.parametrize("status", ["pending", "active"])
def test_existing_open_q08_suppresses_enqueue(layout, status):
    root, farm = layout
    with farm.connect(root) as con:
        con.execute("INSERT INTO work_items(id,ea_id,symbol,phase,status) VALUES ('open','QM5_9001','EURUSD.DWX','Q08',?)", (status,))
    assert run(layout, apply=True)["items"][0]["reason"] == "q08_pending_or_active"
    assert not farm.calls


def test_kill_switch_has_no_filesystem_or_enqueue_effect(tmp_path, monkeypatch):
    monkeypatch.setenv(service.DISABLE_ENV, "1")
    root = tmp_path / "absent"
    answer = service.service(root, apply=True, farm_module=Farm(root))
    assert answer["reason"] == "disabled_by_environment"
    assert not root.exists()


def test_factory_off_blocks_state_and_queue(layout):
    root, farm = layout
    (root / "FACTORY_OFF.flag").touch()
    assert run(layout, apply=True)["reason"] == "factory_off"
    assert not (root / "state" / service.STATE_NAME).exists()
    assert not farm.calls


def test_dry_run_writes_neither_queue_nor_watermark(layout):
    root, farm = layout
    answer = run(layout)
    assert answer["would_enqueue_count"] == 1
    assert answer["created_count"] == 0
    assert not farm.calls
    assert not (root / "state" / service.STATE_NAME).exists()
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()


def test_malformed_watermark_is_not_reset(layout):
    root, farm = layout
    path = root / "state" / service.STATE_NAME
    path.write_text("{broken")
    assert run(layout, apply=True)["reason"] == "q08_stream_service_deferred"
    assert path.read_text() == "{broken"
    assert not farm.calls


def test_q14_binary_drift_defers_and_retries(layout):
    root, farm = layout
    directory = farm._preferred_ea_dir("QM5_9001")
    binary = directory / f"{directory.name}.ex5"
    binary.write_bytes(b"different")
    first = run(layout, apply=True)
    assert first["items"][0]["reason"] == "current_binary_differs_from_q14_identity"
    assert first["watermark_after"]["retry_q14_ids"] == ["q14"]
    binary.write_bytes(b"fixture-binary")
    assert run(layout, apply=True)["created_count"] == 1


def test_crash_after_enqueue_does_not_mint_a_second_rerun(layout, monkeypatch):
    root, farm = layout
    original = service._write_state
    monkeypatch.setattr(service, "_write_state", lambda *args: (_ for _ in ()).throw(OSError("simulated crash")))
    assert run(layout, apply=True).get("error")
    monkeypatch.setattr(service, "_write_state", original)
    with farm.connect(root) as con:
        con.execute("UPDATE work_items SET status='done', verdict='INFRA_FAIL' WHERE id='rerun_1'")
    second = run(layout, apply=True)
    assert second["items"][0]["reason"] == "trigger_rerun_already_recorded"
    assert len(farm.calls) == 1


def test_enqueue_true_without_created_row_remains_retryable(layout, monkeypatch):
    monkeypatch.setattr(layout[1], "enqueue_cascade_backtest_for_ea", lambda *a, **kw: {"enqueued": True, "created": [], "skipped": [{"reason": "missing_setfile"}]})
    answer = run(layout, apply=True)
    assert answer["created_count"] == 0
    assert answer["watermark_after"]["retry_q14_ids"] == ["q14"]


def test_equal_timestamp_rows_are_not_lost_across_bounded_cycles(layout):
    root, farm = layout
    seed(farm, ea="QM5_9002", q14="q14_b", q07="q07_b", q08="q08_b")
    assert run(layout, apply=True, limit=1)["created_count"] == 1
    second = run(layout, apply=True, limit=1)
    assert second["created_count"] == 1
    assert second["watermark_after"]["q14_work_item_id"] == "q14_b"


def test_fail_soft_target_is_allowed_but_fail_hard_is_not(layout):
    root, farm = layout
    with farm.connect(root) as con:
        con.execute("UPDATE work_items SET verdict='FAIL_SOFT' WHERE id='q08'")
    assert run(layout)["would_enqueue_count"] == 1
    with farm.connect(root) as con:
        con.execute("UPDATE work_items SET verdict='FAIL_HARD' WHERE id='q08'")
    assert run(layout)["items"][0]["action"] == "defer"


def test_old_retries_do_not_starve_new_terminal_pairs(layout):
    root, farm = layout
    with farm.connect(root) as con:
        con.execute("DELETE FROM work_items WHERE phase='Q07'")
    assert run(layout, apply=True)["watermark_after"]["retry_q14_ids"] == ["q14"]
    seed(farm, ea="QM5_9002", q14="q14_b", q07="q07_b", q08="q08_b")
    answer = run(layout, apply=True, limit=1)
    assert answer["created_count"] == 1
    assert answer["watermark_after"]["retry_q14_ids"] == ["q14"]


def test_pump_wrapper_passes_its_module_and_deadline(monkeypatch):
    from tools.strategy_farm import farmctl
    calls = []
    def fake(root, **kwargs):
        calls.append((root, kwargs))
        return {"created_count": 0}
    monkeypatch.setattr(service, "service", fake)
    root = Path("unused-test-root")
    assert farmctl.auto_enqueue_q08_stream_reruns(root, deadline_monotonic=123)["created_count"] == 0
    assert calls == [(root, {"apply": True, "deadline_monotonic": 123, "farm_module": farmctl})]


PRECEDENTS = json.loads((Path(__file__).parent / "fixtures" / "q08_stream_reruns_20260904.json").read_text())


@pytest.mark.parametrize("precedent", PRECEDENTS, ids=lambda p: p["ea_id"])
def test_enqueue_arguments_match_recorded_manual_precedents(layout, precedent, monkeypatch):
    root, farm = layout
    with farm.connect(root) as con:
        con.execute("DELETE FROM work_items")
    seed(farm, ea=precedent["ea_id"], symbol=precedent["symbol"],
        q07=precedent["predecessor_work_item_id"], q08=precedent["append_only_rerun_of"],
        digest=precedent["expected_current_ex5_sha256"])
    monkeypatch.setattr(service.bundle, "sha256_file", lambda p: precedent["expected_current_ex5_sha256"])
    call = run(layout)["items"][0]["enqueue_kwargs"]
    for key in ("ea_id", "predecessor_work_item_id", "append_only_rerun_of", "expected_current_ex5_sha256"):
        assert call[key] == precedent[key]
