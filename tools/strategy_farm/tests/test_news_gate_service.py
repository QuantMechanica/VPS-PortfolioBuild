import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path
from unittest import mock

from tools.strategy_farm import farmctl, health, news_gate_service, q09_news_schema


NEWS_PHASE = farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "NEWS")
HISTORICAL_NEWS_PHASE = farmctl.ACTIVE_GATE_MANIFEST.equivalent_gate(
    NEWS_PHASE, "v4", "v3"
)
FROZEN_BASELINE_PHASE = farmctl.prev_phase(farmctl.prev_phase(NEWS_PHASE))


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_only_authenticated_single_reason_requests_expand(tmp_path: Path) -> None:
    aggregate = tmp_path / "aggregate.json"
    payload = {
        "verdict": "REVIEW_REQUIRED",
        "reason_codes": [news_gate_service.EXPANSION_REASON],
    }
    aggregate.write_text(json.dumps(payload), encoding="utf-8")

    assert news_gate_service.verified_expansion_adjudication(
        aggregate, _sha(aggregate)
    ) == payload
    assert news_gate_service.verified_expansion_adjudication(
        aggregate, "0" * 64
    ) is None

    payload["reason_codes"].append("unrelated_review")
    aggregate.write_text(json.dumps(payload), encoding="utf-8")
    assert news_gate_service.verified_expansion_adjudication(
        aggregate, _sha(aggregate)
    ) is None


def test_conclusive_verdicts_exclude_disposition_only_rows() -> None:
    """A disposition_only CONFIG_LOCKED row must not count as a real conclusion.

    Forensics 2026-08-24 §1: raw verdict rows include OWNER-DEC administrative
    dispositions; the service rate must publish the execution-only count.
    """
    connection = sqlite3.connect(":memory:")
    connection.row_factory = sqlite3.Row
    connection.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,
          status TEXT,verdict TEXT,payload_json TEXT,created_at TEXT,updated_at TEXT,
          gate_contract_version TEXT
        );
        CREATE TABLE q09_news_tests(
          work_item_id TEXT,aggregate_path TEXT,aggregate_sha256 TEXT,contract_version TEXT
        );
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,active INTEGER
        );
        """
    )
    now = dt.datetime(2026, 8, 24, 12, tzinfo=dt.timezone.utc)
    recent = (now - dt.timedelta(hours=2)).isoformat()
    rows = (
        ("real", NEWS_PHASE, "QM5_1", "EURUSD.DWX", "a.set", "done",
         "CONFIG_LOCKED", "{}", recent, recent, "v4"),
        ("dispo", NEWS_PHASE, "QM5_2", "GBPUSD.DWX", "b.set", "done",
         "CONFIG_LOCKED",
         json.dumps({"disposition_only": True, "owner_decision_id": "OWNER-DEC-X"}),
         recent, recent, "v4"),
    )
    connection.executemany(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?)", rows
    )
    metrics = news_gate_service.service_metrics(
        connection, news_phases=(NEWS_PHASE,), now=now
    )
    assert metrics["conclusive_verdicts_per_day"] == 1


def test_service_rate_exposes_conclusions_expansions_and_placeholders(
    tmp_path: Path,
) -> None:
    connection = sqlite3.connect(":memory:")
    connection.row_factory = sqlite3.Row
    connection.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,
          status TEXT,verdict TEXT,payload_json TEXT,created_at TEXT,updated_at TEXT,
          gate_contract_version TEXT
        );
        CREATE TABLE q09_news_tests(
          work_item_id TEXT,aggregate_path TEXT,aggregate_sha256 TEXT,contract_version TEXT
        );
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,active INTEGER
        );
        """
    )
    now = dt.datetime(2026, 8, 23, 20, tzinfo=dt.timezone.utc)
    recent = (now - dt.timedelta(hours=2)).isoformat()
    old = (now - dt.timedelta(days=3)).isoformat()
    rows = (
        ("locked", NEWS_PHASE, "QM5_1", "EURUSD.DWX", "a.set", "done", "CONFIG_LOCKED", "{}", recent, recent, "v4"),
        ("placeholder", HISTORICAL_NEWS_PHASE, "QM5_2", "GBPUSD.DWX", "b.set", "done", "PENDING_RUNNER", "{}", old, old, "legacy"),
        ("request", NEWS_PHASE, "QM5_3", "XAUUSD.DWX", "c.set", "done", "REVIEW_REQUIRED", "{}", recent, recent, "v4"),
        ("child", NEWS_PHASE, "QM5_3", "XAUUSD.DWX", "c.set", "pending", None, json.dumps({
            "news_expansion_of_work_item": "request",
            "q09_autoseal_failure": {
                "reason_code": "Q09_AUTOSEAL_BIND_PLAN_FAILED",
                "detail": "RunnerError: bound Q07 seed-stability evidence is missing",
            },
        }), recent, recent, "v4"),
    )
    connection.executemany(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?)", rows
    )
    aggregate = tmp_path / "aggregate.json"
    aggregate.write_text(
        json.dumps({
            "verdict": "REVIEW_REQUIRED",
            "reason_codes": [news_gate_service.EXPANSION_REASON],
        }),
        encoding="utf-8",
    )
    connection.execute(
        "INSERT INTO q09_news_tests VALUES(?,?,?,?)",
        ("request", str(aggregate), _sha(aggregate), "evidence-v3"),
    )
    connection.execute(
        "INSERT INTO work_item_holds VALUES(?,?,1)",
        ("child", "Q09_AWAITING_SEALED_PLAN"),
    )

    metrics = news_gate_service.service_metrics(
        connection,
        news_phases=(NEWS_PHASE, HISTORICAL_NEWS_PHASE),
        now=now,
    )

    assert metrics["conclusive_verdicts_per_day"] == 1
    assert metrics["expansions_pending"] == 1
    assert metrics["pending_runner_count"] == 1
    assert metrics["active_hold_count"] == 1
    assert metrics["hold_cause_counts"] == {"Q07_EVIDENCE_MISSING": 1}
    assert metrics["expansion_pending_rows"][0]["children"][0]["id"] == "child"


def test_expansion_author_is_append_only_held_and_deduplicated(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    ea_dir = tmp_path / "QM5_1_demo"
    setfile = ea_dir / "sets" / "baseline.set"
    ex5 = ea_dir / "QM5_1_demo.ex5"
    baseline_evidence = tmp_path / "baseline.json"
    source_aggregate = tmp_path / "source-aggregate.json"
    setfile.parent.mkdir(parents=True)
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    ex5.write_bytes(b"canonical-compiled-binary")
    baseline_evidence.write_text('{"verdict":"PASS"}', encoding="utf-8")
    source_aggregate.write_text(
        json.dumps({
            "verdict": "REVIEW_REQUIRED",
            "reason_codes": [news_gate_service.EXPANSION_REASON],
        }),
        encoding="utf-8",
    )
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as connection:
        connection.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('baseline','backtest',?,'QM5_1','EURUSD.DWX',?,'done','PASS',0,
                     ?,'{}',?,?, 'v4')
            """,
            (FROZEN_BASELINE_PHASE, str(setfile), str(baseline_evidence), now, now),
        )
        connection.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('source','backtest',?,'QM5_1','EURUSD.DWX',?,'done',
                     'REVIEW_REQUIRED',0,?,'{}',?,?, 'v4')
            """,
            (NEWS_PHASE, str(setfile), str(source_aggregate), now, now),
        )
        q09_news_schema.add_dependency(
            connection,
            child_work_item_id="source",
            dependency_role="Q08_INPUT",
            parent_work_item_id="baseline",
            parent_evidence_sha256=_sha(baseline_evidence),
            required_verdicts=["PASS"],
        )
        connection.commit()
        source = dict(connection.execute(
            "SELECT * FROM work_items WHERE id='source'"
        ).fetchone())
        source.update({
            "aggregate_path": str(source_aggregate),
            "aggregate_sha256": _sha(source_aggregate),
            "contract_version": "evidence-v3",
            "adjudication": json.loads(source_aggregate.read_text(encoding="utf-8")),
        })

    with mock.patch.object(
        farmctl.news_gate_service, "expansion_requests", return_value=[source]
    ):
        first = farmctl.author_news_expansion_continuations(tmp_path, limit=1)

    assert first["created_count"] == 1, json.dumps(first, default=str, sort_keys=True)
    child_id = first["created"][0]["work_item_id"]
    stale_ex5 = tmp_path / "worktrees" / "removed" / ea_dir.name / ex5.name
    manifest = tmp_path / "failed-child" / "input_manifest.json"
    manifest.parent.mkdir()
    manifest.write_text(
        json.dumps({
            "source_paths": {"ex5": str(stale_ex5)},
            "identities": {"ex5_sha256": _sha(ex5)},
        }),
        encoding="utf-8",
    )
    plan = tmp_path / "failed-child" / "run_plan.json"
    plan.write_text(
        json.dumps({
            "input_manifest_path": str(manifest),
            "input_manifest_sha256": _sha(manifest),
        }),
        encoding="utf-8",
    )
    with farmctl.connect(tmp_path) as connection:
        failed_payload = json.loads(connection.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (child_id,)
        ).fetchone()[0])
        failed_payload.update({
            "failure_subclass": "launch_fault",
            "verdict_reason": "summary_missing:launch_fault",
            "q09_run_plan_path": str(plan),
            "q09_run_plan_file_sha256": _sha(plan),
            "q09_input_manifest_sha256": _sha(manifest),
        })
        connection.execute(
            "UPDATE work_items SET status='failed',verdict='INFRA_FAIL',"
            "evidence_path='EVIDENCE_UNAVAILABLE:launch_fault',payload_json=? "
            "WHERE id=?",
            (json.dumps(failed_payload, sort_keys=True), child_id),
        )
        connection.commit()
        failed_child = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (child_id,)
        ).fetchone()
        assert farmctl._retryable_stale_worktree_news_expansion(
            failed_child, source
        ) is not None
        ex5.write_bytes(b"different-binary")
        assert farmctl._retryable_stale_worktree_news_expansion(
            failed_child, source
        ) is None
        ex5.write_bytes(b"canonical-compiled-binary")

    with mock.patch.object(
        farmctl.news_gate_service, "expansion_requests", return_value=[source]
    ):
        second = farmctl.author_news_expansion_continuations(tmp_path, limit=1)
        third = farmctl.author_news_expansion_continuations(tmp_path, limit=1)

    assert second["created_count"] == 1
    assert second["created"][0]["retry_of_work_item_id"] == child_id
    retry_id = second["created"][0]["work_item_id"]
    assert third["created_count"] == 0
    assert third["skipped"][0]["reason"] == "expansion_continuation_already_exists"
    with farmctl.connect(tmp_path) as connection:
        source_row = connection.execute(
            "SELECT status,verdict FROM work_items WHERE id='source'"
        ).fetchone()
        child = connection.execute(
            "SELECT phase,status,verdict,payload_json FROM work_items WHERE id=?",
            (retry_id,),
        ).fetchone()
        hold = connection.execute(
            "SELECT active,hold_code FROM work_item_holds WHERE work_item_id=?",
            (retry_id,),
        ).fetchone()
        dependency = connection.execute(
            "SELECT parent_work_item_id FROM work_item_dependencies WHERE child_work_item_id=?",
            (retry_id,),
        ).fetchone()
    child_payload = json.loads(child["payload_json"])
    assert tuple(source_row) == ("done", "REVIEW_REQUIRED")
    assert tuple(child[:3]) == (NEWS_PHASE, "pending", None)
    assert child_payload["news_expansion_of_work_item"] == "source"
    assert child_payload["append_only_rerun_of_work_item"] == child_id
    assert child_payload["news_expansion_retry_of_work_item"] == child_id
    assert child_payload["retry_canonical_ex5_sha256"] == _sha(ex5)
    assert farmctl._force_expanded_news_matrix({"payload_json": child["payload_json"]})
    assert tuple(hold) == (1, q09_news_schema.ACTIVATION_HOLD_CODE)
    assert dependency[0] == "baseline"


def test_bound_role_resolved_news_row_is_claimable(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    payload = {
        "q09_binding_version": "q09-news-dispatch-binding/v1",
        "q09_run_plan_path": str(tmp_path / "plan.json"),
        "q09_run_plan_file_sha256": "a" * 64,
        "q09_dispatch_binding_sha256": "b" * 64,
    }
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as connection:
        connection.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
              payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('bound','backtest',?,'QM5_1','EURUSD.DWX','base.set',
                     'pending',0,?,?,?,'v4')
            """,
            (NEWS_PHASE, json.dumps(payload), now, now),
        )
        claimable = {
            row["id"]
            for row in connection.execute(farmctl.pending_claim_order_sql()).fetchall()
        }
    assert "bound" in claimable


def test_health_check_warns_when_the_news_service_has_no_conclusion() -> None:
    metrics = {
        "window_hours": 24,
        "conclusive_verdicts_per_day": 0,
        "expansions_pending": 2,
        "expansion_pending_rows": [],
        "pending_runner_count": 3,
        "active_hold_count": 4,
        "hold_cause_counts": {"Q08_VINTAGE": 4},
        "hold_cause_rows": {},
    }
    with mock.patch.object(
        health.news_gate_service, "service_metrics", return_value=metrics
    ):
        result = health.chk_news_gate_service_rate(mock.Mock())
    assert result["name"] == "news_gate_service_rate"
    assert result["status"] == "WARN"
    assert "expansions_pending=2" in result["detail"]
    assert "PENDING_RUNNER=3" in result["detail"]
    assert 'hold_causes={"Q08_VINTAGE": 4}' in result["detail"]
