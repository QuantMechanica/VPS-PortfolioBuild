import sqlite3

from tools.strategy_farm import dsr_cohort, farmctl, terminal_worker


SHA = {
    "mq5_sha256": "a" * 64,
    "ex5_sha256": "b" * 64,
    "setfile_sha256": "c" * 64,
    "include_closure_sha256": "d" * 64,
}


def _claim_db() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,status TEXT,verdict TEXT,payload_json TEXT
        )
        """
    )
    conn.execute(
        "INSERT INTO work_items VALUES('q07','done','PASS','{}')"
    )
    return conn


def _fake_promotion_binding(_conn, _predecessor, payload):
    payload.update(
        {
            "expected_mq5_sha256": SHA["mq5_sha256"],
            "expected_ex5_sha256": SHA["ex5_sha256"],
            "expected_setfile_sha256": SHA["setfile_sha256"],
            "include_closure_sha256": SHA["include_closure_sha256"],
            "artifact_identity": dict(SHA),
            "q08_promotion_identity_binding": {
                "authority": "governed_compile_evidence"
            },
        }
    )
    return True, {"artifact_sha256": dict(SHA)}


def test_claim_binding_fills_unbound_row_from_authenticated_authority(monkeypatch):
    conn = _claim_db()
    monkeypatch.setattr(
        farmctl, "_q08_promotion_execution_binding", _fake_promotion_binding
    )
    candidate = {
        "id": "q08",
        "phase": "Q08",
        "mq5_sha256": None,
        "ex5_sha256": None,
        "setfile_sha256": None,
        "include_closure_sha256": None,
    }
    payload = {"promoted_from_work_item": "q07"}

    ok, detail = farmctl._q08_claim_execution_binding(
        conn, candidate, payload
    )

    assert ok is True
    assert {
        key: detail["typed_identity"][key] for key in SHA
    } == SHA
    assert {
        key: detail["candidate"][key] for key in SHA
    } == SHA
    assert payload["q08_claim_identity_binding"]["authority"] == (
        "governed_compile_evidence"
    )


def test_claim_binding_never_overwrites_a_populated_drifted_hash(monkeypatch):
    conn = _claim_db()
    monkeypatch.setattr(
        farmctl, "_q08_promotion_execution_binding", _fake_promotion_binding
    )
    candidate = {
        "id": "q08",
        "phase": "Q08",
        "mq5_sha256": "f" * 64,
        "ex5_sha256": None,
        "setfile_sha256": None,
        "include_closure_sha256": None,
    }
    payload = {"promoted_from_work_item": "q07"}

    ok, detail = farmctl._q08_claim_execution_binding(
        conn, candidate, payload
    )

    assert ok is False
    assert detail["reason"] == "BUILD_IDENTITY_MISMATCH:mq5"
    assert "q08_claim_identity_binding" not in payload


def test_claim_seal_binds_before_dsr_validation(monkeypatch):
    conn = sqlite3.connect(":memory:")
    item = {
        "id": "q08",
        "phase": "Q08",
        "mq5_sha256": None,
        "ex5_sha256": None,
        "setfile_sha256": None,
        "include_closure_sha256": None,
    }
    payload = {"promoted_from_work_item": "q07"}
    order = []

    monkeypatch.setattr(
        terminal_worker.farmctl,
        "_q08_execution_identity_state",
        lambda *_args: {
            "identity": {},
            "missing_roles": ["mq5", "ex5", "setfile", "include_closure"],
            "conflicts": {},
            "bound": False,
        },
    )

    def bind(_conn, candidate, mutable_payload):
        order.append("bind")
        mutable_payload["artifact_identity"] = dict(SHA)
        return True, {
            "candidate": {**candidate, **SHA},
            "typed_identity": dict(SHA),
        }

    def attach(_conn, candidate, mutable_payload):
        order.append("validate")
        assert {key: candidate[key] for key in SHA} == SHA
        mutable_payload["dsr_context"] = {
            "path": "sealed.json",
            "sha256": "e" * 64,
        }
        return {"status": "SEALED", "reason": None}

    monkeypatch.setattr(
        terminal_worker.farmctl, "_q08_claim_execution_binding", bind
    )
    monkeypatch.setattr(dsr_cohort, "attach", attach)
    monkeypatch.setenv(terminal_worker.Q08_DSR_CONTEXT_PREFLIGHT_ENV, "1")
    monkeypatch.setenv("QM_DSR_V2", "1")

    result = terminal_worker._seal_q08_dsr_at_claim(conn, item, payload)

    assert order == ["bind", "validate"]
    assert result["claimable"] is True
    assert result["bound_identity"] == SHA


def test_source_refusal_is_parked_with_typed_hold(monkeypatch):
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_item_holds(
          work_item_id TEXT,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT
        )
        """
    )
    events = []
    monkeypatch.setattr(
        farmctl,
        "event",
        lambda _conn, entity_type, entity_id, action, detail: events.append(
            (entity_type, entity_id, action, detail)
        ),
    )

    held = farmctl._hold_q08_promotion_binding_refusal(
        conn,
        work_item_id="q08",
        predecessor_work_item_id="q07",
        detail={"reason": "q08_predecessor_mq5_identity_mismatch"},
        now="2026-09-22T00:00:00Z",
    )

    row = conn.execute("SELECT * FROM work_item_holds").fetchone()
    assert held is True
    assert row["hold_code"] == farmctl.Q08_PROMOTION_BINDING_REFUSED
    assert row["active"] == 1
    assert row["release_on_restart"] == 0
    assert events[0][2] == "q08_promotion_binding_refusal_held"
