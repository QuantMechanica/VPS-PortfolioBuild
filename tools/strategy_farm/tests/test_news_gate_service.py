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
        """
    )
    now = dt.datetime(2026, 8, 23, 20, tzinfo=dt.timezone.utc)
    recent = (now - dt.timedelta(hours=2)).isoformat()
    old = (now - dt.timedelta(days=3)).isoformat()
    rows = (
        ("locked", NEWS_PHASE, "QM5_1", "EURUSD.DWX", "a.set", "done", "CONFIG_LOCKED", "{}", recent, recent, "v4"),
        ("placeholder", HISTORICAL_NEWS_PHASE, "QM5_2", "GBPUSD.DWX", "b.set", "done", "PENDING_RUNNER", "{}", old, old, "legacy"),
        ("request", NEWS_PHASE, "QM5_3", "XAUUSD.DWX", "c.set", "done", "REVIEW_REQUIRED", "{}", recent, recent, "v4"),
        ("child", NEWS_PHASE, "QM5_3", "XAUUSD.DWX", "c.set", "pending", None, json.dumps({"news_expansion_of_work_item": "request"}), recent, recent, "v4"),
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

    metrics = news_gate_service.service_metrics(
        connection,
        news_phases=(NEWS_PHASE, HISTORICAL_NEWS_PHASE),
        now=now,
    )

    assert metrics["conclusive_verdicts_per_day"] == 1
    assert metrics["expansions_pending"] == 1
    assert metrics["pending_runner_count"] == 1
    assert metrics["expansion_pending_rows"][0]["children"][0]["id"] == "child"


def test_expansion_author_is_append_only_held_and_deduplicated(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "baseline.set"
    baseline_evidence = tmp_path / "baseline.json"
    source_aggregate = tmp_path / "source-aggregate.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
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
        second = farmctl.author_news_expansion_continuations(tmp_path, limit=1)

    assert first["created_count"] == 1, json.dumps(first, default=str, sort_keys=True)
    assert second["created_count"] == 0
    assert second["skipped"][0]["reason"] == "expansion_continuation_already_exists"
    child_id = first["created"][0]["work_item_id"]
    with farmctl.connect(tmp_path) as connection:
        source_row = connection.execute(
            "SELECT status,verdict FROM work_items WHERE id='source'"
        ).fetchone()
        child = connection.execute(
            "SELECT phase,status,verdict,payload_json FROM work_items WHERE id=?",
            (child_id,),
        ).fetchone()
        hold = connection.execute(
            "SELECT active,hold_code FROM work_item_holds WHERE work_item_id=?",
            (child_id,),
        ).fetchone()
        dependency = connection.execute(
            "SELECT parent_work_item_id FROM work_item_dependencies WHERE child_work_item_id=?",
            (child_id,),
        ).fetchone()
    child_payload = json.loads(child["payload_json"])
    assert tuple(source_row) == ("done", "REVIEW_REQUIRED")
    assert tuple(child[:3]) == (NEWS_PHASE, "pending", None)
    assert child_payload["news_expansion_of_work_item"] == "source"
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
    }
    with mock.patch.object(
        health.news_gate_service, "service_metrics", return_value=metrics
    ):
        result = health.chk_news_gate_service_rate(mock.Mock())
    assert result["name"] == "news_gate_service_rate"
    assert result["status"] == "WARN"
    assert "expansions_pending=2" in result["detail"]
    assert "PENDING_RUNNER=3" in result["detail"]
