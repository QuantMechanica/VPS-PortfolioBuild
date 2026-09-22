from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import (
    compile_work_items,
    dsr_cohort,
    farmctl,
    q08_promotion_repair,
    q08_window,
)


SHA_EX5 = "a" * 64
SHA_MQ5 = "b" * 64
SHA_SET = "c" * 64
SHA_CLOSURE = "d" * 64


def _window_fixture(tmp_path: Path, *, first_year: int = 2017) -> tuple[Path, Path]:
    repo = tmp_path / "repo"
    registry = repo / "framework" / "registry" / "dwx_symbol_history_ranges.csv"
    registry.parent.mkdir(parents=True)
    registry.write_text(
        "symbol,period,first_year,last_year,source_terminals\n"
        f"XTIUSD.DWX,D1,{first_year},2025,T1\n",
        encoding="utf-8",
    )
    setfile = repo / "framework" / "EAs" / "QM5_1_test" / "sets" / (
        "QM5_1_test_XTIUSD.DWX_D1_backtest.set"
    )
    setfile.parent.mkdir(parents=True)
    setfile.write_text("; environment: backtest\n", encoding="utf-8")
    return repo, setfile


def test_q08_window_resolver_matches_runner_contract(tmp_path: Path) -> None:
    repo, setfile = _window_fixture(tmp_path, first_year=2017)
    result = q08_window.resolve_q08_window(repo, setfile, "XTIUSD.DWX")
    assert result["from_date"] == "2017.01.01"
    assert result["to_date"] == "2025.12.31"
    assert result["timeframe"] == "D1"

    repo, setfile = _window_fixture(tmp_path / "late", first_year=2018)
    result = q08_window.resolve_q08_window(repo, setfile, "XTIUSD.DWX")
    assert result["from_date"] == "2018.07.02"

    repo, setfile = _window_fixture(tmp_path / "later", first_year=2021)
    result = q08_window.resolve_q08_window(repo, setfile, "XTIUSD.DWX")
    assert result["from_date"] == "2018.07.02"


def test_q08_window_resolver_fails_closed_without_registry_row(tmp_path: Path) -> None:
    repo, setfile = _window_fixture(tmp_path)
    (repo / "framework" / "registry" / "dwx_symbol_history_ranges.csv").write_text(
        "symbol,period,first_year,last_year,source_terminals\n",
        encoding="utf-8",
    )
    with pytest.raises(q08_window.Q08WindowError, match="RANGE_UNAVAILABLE"):
        q08_window.resolve_q08_window(repo, setfile, "XTIUSD.DWX")


def test_q08_window_resolver_fails_closed_on_invalid_registry_years(
    tmp_path: Path,
) -> None:
    repo, setfile = _window_fixture(tmp_path)
    (repo / "framework" / "registry" / "dwx_symbol_history_ranges.csv").write_text(
        "symbol,period,first_year,last_year,source_terminals\n"
        "XTIUSD.DWX,D1,,2025,T1\n",
        encoding="utf-8",
    )
    with pytest.raises(q08_window.Q08WindowError, match="RANGE_INVALID"):
        q08_window.resolve_q08_window(repo, setfile, "XTIUSD.DWX")


def test_promotion_replaces_q02_canary_with_q08_phase_window(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo, setfile = _window_fixture(tmp_path)
    monkeypatch.setattr(farmctl, "CANONICAL_REPO_ROOT", repo)
    payload = {
        "from_date": "2018.07.02",
        "to_date": "2022.12.31",
        "from_year": 2017,
        "to_year": 2022,
    }
    ok, detail = farmctl._carry_q08_candidate_window(
        {
            "id": "q07",
            "symbol": "XTIUSD.DWX",
            "setfile_path": str(setfile),
        },
        payload,
    )
    assert ok
    assert detail["source"] == "q08_phase_contract"
    assert payload["from_date"] == payload["expected_from_date"] == "2017.01.01"
    assert payload["to_date"] == payload["expected_to_date"] == "2025.12.31"
    assert payload["from_year"] == 2017
    assert payload["to_year"] == 2025
    assert payload["q08_candidate_window_binding"]["inherited_window_replaced"] == {
        "from_date": "2018.07.02",
        "to_date": "2022.12.31",
        "from_year": 2017,
        "to_year": 2022,
    }


def test_dsr_prefers_phase_expected_window_over_legacy_alias() -> None:
    conn = sqlite3.connect(":memory:")
    window, source = dsr_cohort._candidate_window(
        conn,
        {"ea_id": "QM5_1", "symbol": "XTIUSD.DWX"},
        {
            "from_date": "2018.07.02",
            "to_date": "2022.12.31",
            "expected_from_date": "2017.01.01",
            "expected_to_date": "2025.12.31",
        },
    )
    assert window == {"from": "2017-01-01", "to": "2025-12-31"}
    assert source == "payload.expected_from_date/expected_to_date"


def test_q08_promotion_identity_requires_predecessor_and_compile_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    predecessor = {
        "id": "q07",
        "ea_id": "QM5_1",
        "symbol": "XTIUSD.DWX",
        "payload_json": json.dumps({
            "artifact_identity": {
                "ex5_sha256": SHA_EX5,
                "mq5_sha256": SHA_MQ5,
            }
        }),
        "ex5_sha256": SHA_EX5,
        "mq5_sha256": SHA_MQ5,
    }
    current = {
        "artifact_sha256": {
            "expected_ex5_sha256": SHA_EX5,
            "expected_mq5_sha256": SHA_MQ5,
            "expected_setfile_sha256": SHA_SET,
        },
        "expected_symbol": "XTIUSD.DWX",
        "expected_period": "D1",
        "expected_expert": "QM\\QM5_1_test",
    }
    monkeypatch.setattr(
        farmctl,
        "_expected_current_execution_bindings",
        lambda *_args, **_kwargs: (True, current),
    )
    monkeypatch.setattr(
        farmctl,
        "_q02_rebind_compile_provenance",
        lambda *_args, **_kwargs: ({
            "work_item_id": "compile",
            "evidence_path": "compile.json",
            "evidence_sha256": "e" * 64,
            "include_closure_sha256": SHA_CLOSURE,
            "build_id": "build-1",
        }, []),
    )
    monkeypatch.setattr(
        compile_work_items,
        "_current_include_closure_sha256",
        lambda _repo: SHA_CLOSURE,
    )
    payload: dict[str, object] = {}
    ok, detail = farmctl._q08_promotion_execution_binding(
        sqlite3.connect(":memory:"), predecessor, payload
    )
    assert ok
    assert detail["compile_record"]["work_item_id"] == "compile"
    assert payload["expected_setfile_sha256"] == SHA_SET
    assert payload["artifact_identity"] == {
        "ex5_sha256": SHA_EX5,
        "mq5_sha256": SHA_MQ5,
        "setfile_sha256": SHA_SET,
        "include_closure_sha256": SHA_CLOSURE,
        "build_id": "build-1",
    }


def test_q08_promotion_identity_refuses_partial_predecessor_without_compile(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    predecessor = {
        "id": "q07",
        "ea_id": "QM5_1",
        "symbol": "XTIUSD.DWX",
        "payload_json": json.dumps({
            "artifact_identity": {
                "ex5_sha256": SHA_EX5,
                "mq5_sha256": SHA_MQ5,
            }
        }),
        "ex5_sha256": SHA_EX5,
        "mq5_sha256": SHA_MQ5,
    }
    current = {
        "artifact_sha256": {
            "expected_ex5_sha256": SHA_EX5,
            "expected_mq5_sha256": SHA_MQ5,
            "expected_setfile_sha256": SHA_SET,
        },
        "expected_symbol": "XTIUSD.DWX",
        "expected_period": "D1",
        "expected_expert": "QM\\QM5_1_test",
    }
    monkeypatch.setattr(
        farmctl,
        "_expected_current_execution_bindings",
        lambda *_args, **_kwargs: (True, current),
    )
    monkeypatch.setattr(
        farmctl,
        "_q02_rebind_compile_provenance",
        lambda *_args, **_kwargs: (None, []),
    )
    monkeypatch.setattr(
        compile_work_items,
        "_current_include_closure_sha256",
        lambda _repo: SHA_CLOSURE,
    )
    ok, detail = farmctl._q08_promotion_execution_binding(
        sqlite3.connect(":memory:"), predecessor, {}
    )
    assert not ok
    assert detail["reason"] == "q08_current_build_compile_provenance_unavailable"
    assert detail["source_include_closure_identity_error"] == {
        "reason": "source_include_closure_sha256_missing"
    }


def _repair_db() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
          setfile_path TEXT,status TEXT,verdict TEXT,claimed_by TEXT,
          payload_json TEXT,created_at TEXT,ex5_sha256 TEXT,setfile_sha256 TEXT,
          mq5_sha256 TEXT,include_closure_sha256 TEXT,build_id TEXT,
          data_window_start TEXT,data_window_end TEXT
        );
        CREATE TABLE work_item_supersedes(work_item_id TEXT);
        """
    )
    predecessor_payload = json.dumps({
        "artifact_identity": {"ex5_sha256": SHA_EX5, "mq5_sha256": SHA_MQ5}
    })
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "q07", "backtest", "Q07", "QM5_1", "XTIUSD.DWX", "x.set",
            "done", "PASS", None, predecessor_payload, "1", SHA_EX5, SHA_SET,
            SHA_MQ5, SHA_CLOSURE, None, "2017.01.01", "2025.12.31",
        ),
    )
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "q08", "backtest", "Q08", "QM5_1", "XTIUSD.DWX", "x.set",
            "pending", None, None,
            json.dumps({
                "promoted_from_work_item": "q07",
                "promotion_source": "pump_cascade",
                "from_date": "2018.07.02",
                "to_date": "2022.12.31",
            }),
            "2", None, None, None, None, None, None, None,
        ),
    )
    return conn


def test_repair_planner_targets_only_unclaimed_pending_rows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    conn = _repair_db()

    def bind_window(_predecessor, payload):
        payload.update({
            "from_date": "2017.01.01",
            "to_date": "2025.12.31",
            "from_year": 2017,
            "to_year": 2025,
            "expected_from_date": "2017.01.01",
            "expected_to_date": "2025.12.31",
        })
        return True, {"source": "test"}

    def bind_identity(_conn, _predecessor, payload):
        payload.update({
            "expected_ex5_sha256": SHA_EX5,
            "expected_mq5_sha256": SHA_MQ5,
            "expected_setfile_sha256": SHA_SET,
            "include_closure_sha256": SHA_CLOSURE,
            "artifact_identity": {
                "ex5_sha256": SHA_EX5,
                "mq5_sha256": SHA_MQ5,
                "setfile_sha256": SHA_SET,
                "include_closure_sha256": SHA_CLOSURE,
            },
        })
        return True, {"compile_record": {"work_item_id": "compile"}}

    monkeypatch.setattr(farmctl, "_carry_q08_candidate_window", bind_window)
    monkeypatch.setattr(farmctl, "_q08_promotion_execution_binding", bind_identity)
    plan = q08_promotion_repair.plan_repairs(
        conn,
        task_id="task",
        reason="repair",
        journal_path=Path("journal.json"),
    )
    assert plan["candidate_count"] == 1
    assert plan["eligible_count"] == 1
    assert plan["refused_count"] == 0
    assert plan["eligible"][0]["after_window"]["expected_to_date"] == "2025.12.31"
    assert plan["eligible"][0]["after_identity"]["ex5_sha256"] == SHA_EX5


def test_refused_repair_installs_typed_item_hold(tmp_path: Path) -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,status TEXT,verdict TEXT,claimed_by TEXT,
          payload_json TEXT
        );
        CREATE TABLE work_item_supersedes(work_item_id TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT
        );
        INSERT INTO work_items VALUES('q08','pending',NULL,NULL,'{"x":1}');
        """
    )
    item = {
        "work_item_id": "q08",
        "reason": "identity_binding_refused",
        "detail": {"reason": "q08_current_build_compile_provenance_unavailable"},
        "before_payload_raw": '{"x":1}',
        "before_payload_sha256": q08_promotion_repair._sha256_text('{"x":1}'),
    }
    installed, detail = q08_promotion_repair._install_refusal_hold(
        conn,
        item,
        task_id="task",
        repair_reason="repair",
        journal_path=tmp_path / "journal.json",
        now="2026-09-22T00:00:00Z",
    )
    assert installed
    assert detail["schema"] == q08_promotion_repair.REFUSAL_SCHEMA
    hold = conn.execute("SELECT * FROM work_item_holds").fetchone()
    assert hold["hold_code"] == q08_promotion_repair.REFUSAL_HOLD_CODE
    assert json.loads(hold["reason"])["refusal_reason"] == (
        "identity_binding_refused"
    )


def test_refused_repair_is_noop_when_typed_hold_is_already_active(
    tmp_path: Path,
) -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,status TEXT,verdict TEXT,claimed_by TEXT,
          payload_json TEXT
        );
        CREATE TABLE work_item_supersedes(work_item_id TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT
        );
        INSERT INTO work_items VALUES('q08','pending',NULL,NULL,'{"x":1}');
        INSERT INTO work_item_holds VALUES(
          'q08','Q08_PROMOTION_BINDING_REFUSED','original',1,0,
          '2026-09-21T00:00:00Z','2026-09-21T00:00:00Z',NULL,NULL
        );
        """
    )
    item = {
        "work_item_id": "q08",
        "reason": "identity_binding_refused",
        "detail": {"reason": "q08_current_build_compile_provenance_unavailable"},
        "before_payload_raw": '{"x":1}',
        "before_payload_sha256": q08_promotion_repair._sha256_text('{"x":1}'),
    }

    installed, detail = q08_promotion_repair._install_refusal_hold(
        conn,
        item,
        task_id="second-task",
        repair_reason="repeat repair",
        journal_path=tmp_path / "journal.json",
        now="2026-09-22T00:00:00Z",
    )

    assert installed is False
    assert detail == {
        "reason": "refusal_hold_already_active",
        "existing_hold_code": q08_promotion_repair.REFUSAL_HOLD_CODE,
    }
    hold = conn.execute("SELECT reason,updated_at FROM work_item_holds").fetchone()
    assert tuple(hold) == ("original", "2026-09-21T00:00:00Z")
