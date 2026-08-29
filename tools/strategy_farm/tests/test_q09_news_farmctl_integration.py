import hashlib
import inspect
import json
import sqlite3
import sys
import types
from pathlib import Path
from unittest import mock

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import build_q09_include_closure  # noqa: E402
import q09_news_runner  # noqa: E402
import q09_news_schema as schema  # noqa: E402
import terminal_worker  # noqa: E402

NEWS_GATE = farmctl.ACTIVE_GATE_MANIFEST.gate_for_role("NEWS")
NEWS_PHASE = farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "NEWS")
PORTFOLIO_PHASE = farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role(
    "NEWS", "PORTFOLIO"
)
INCUMBENT_PHASE = farmctl.ACTIVE_GATE_MANIFEST.gate_for_role("INCUMBENT")
NEWS_ROLE = farmctl.ACTIVE_GATE_MANIFEST.dependency_role("Q09_NEWS")
PORTFOLIO_ROLE = farmctl.ACTIVE_GATE_MANIFEST.dependency_role("Q09_PORTFOLIO")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _insert_work_item(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    phase: str,
    verdict: str | None,
    evidence_path: Path,
    setfile_path: Path,
    status: str = "done",
    payload: dict | None = None,
) -> None:
    now = "2026-07-29T00:00:00Z"
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
            attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
            created_at,updated_at
        ) VALUES(?, 'backtest', ?, 'QM5_9999', 'EURUSD.DWX', ?, ?, ?,
                 1, NULL, ?, NULL, '{}', ?, ?)
        """,
        (
            item_id,
            phase,
            str(setfile_path),
            status,
            verdict,
            str(evidence_path),
            now,
            now,
        ),
    )
    if payload is not None:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), item_id),
        )


def _insert_locked_q09(conn: sqlite3.Connection, q09_path: Path) -> None:
    h = lambda value: hashlib.sha256(value.encode("utf-8")).hexdigest()
    conn.execute(
        """
        INSERT INTO news_calendar_bundles(
            bundle_id,schema_version,manifest_path,manifest_sha256,content_sha256,
            coverage_from_utc,coverage_to_utc,event_from_utc,event_to_utc,row_count,
            publisher_evidence_path,publisher_evidence_sha256,correction_reason,
            approved_by,approved_at,created_at
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            "bundle-v2", "q09-news-calendar-bundle/v2", "calendar.json",
            h("manifest"), h("content"), "2019-01-01T00:00:00Z",
            "2026-01-01T00:00:00Z", "2019-01-01T00:00:00Z",
            "2025-12-31T23:59:59Z", 1, "publisher.json", h("publisher"),
            None, None, None, "2026-07-29T00:00:00Z",
        ),
    )
    conn.execute(
        """
        INSERT INTO q09_news_tests(
            work_item_id,contract_version,deployment_target,target_compliance,q08_work_item_id,
            calendar_bundle_id,paired_base_identity_sha256,baseline_setfile_sha256,ex5_sha256,
            include_closure_sha256,selection_from_utc,selection_to_utc,holdout_from_utc,
            holdout_to_utc,complete_months,holdout_complete_months,matrix_scope,verdict,
            chosen_temporal,chosen_compliance,aggregate_path,aggregate_sha256,created_at
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            "q09n", schema.CONTRACT_VERSION, "DXZ", "DXZ", "q08", "bundle-v2",
            h("base"), h("baseline"), h("ex5"), h("include"),
            "2020-01-01T00:00:00Z", "2022-12-31T23:59:59Z",
            "2023-01-01T00:00:00Z", "2025-12-31T23:59:59Z", 60, 24,
            "7x1_target_compliance", "CONFIG_LOCKED", "PRE30", "DXZ",
            str(q09_path), _sha(q09_path), "2026-07-29T00:00:01Z",
        ),
    )
    seeds = (42, 17, 99, 7, 2026)
    for arm, temporal, compliance in (
        ("CONTROL_OFF", "OFF", "NONE"),
        ("POLICY_ON", "PRE30", "DXZ"),
    ):
        for seed in seeds:
            identity = f"{arm}/{seed}"
            conn.execute(
                """
                INSERT INTO q09_news_cells(
                    q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed,
                    requested_seed,effective_seed,paired_base_identity_sha256,
                    run_identity_sha256,setfile_sha256,evidence_sha256,report_sha256,
                    selection_metrics_json,holdout_metrics_json,full_metrics_json,
                    q07_seed_stability_pass,flat_at_event_receipt_sha256,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    "q09n", arm, temporal, compliance, seed, seed, seed, h("base"),
                    h("run/" + identity), h("set/" + identity), h("evidence/" + identity),
                    h("report/" + identity), "{}", "{}", "{}", 1, None,
                    "2026-07-29T00:00:02Z",
                ),
            )
        conn.execute(
            """
            INSERT INTO q09_news_arms(
                q09_news_work_item_id,arm,temporal_mode,compliance_mode,
                seed_set_json,setfile_hashes_json,evidence_hashes_json,created_at
            ) VALUES(?,?,?,?,?,?,?,?)
            """,
            (
                "q09n", arm, temporal, compliance, json.dumps(seeds), "{}", "{}",
                "2026-07-29T00:00:03Z",
            ),
        )


def test_init_activates_additive_q09_schema_without_enabling_foreign_keys(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    farmctl.init_db(tmp_path)
    with farmctl.connect(tmp_path) as conn:
        names = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
            ).fetchall()
        }
        assert "work_item_dependencies" in names
        assert "q09_news_tests" in names
        assert "portfolio_candidates_eligible" in names
        assert conn.execute("PRAGMA foreign_keys").fetchone()[0] == 0


def test_q09_news_is_writable_canonical_phase_and_q09_alias_is_read_only(tmp_path: Path) -> None:
    assert NEWS_PHASE in farmctl.CASCADE_BACKTEST_PHASES
    assert NEWS_PHASE in farmctl.REAL_PHASE_RUNNER_PHASES
    assert NEWS_GATE not in farmctl.CASCADE_BACKTEST_PHASES
    assert NEWS_GATE not in farmctl.REAL_PHASE_RUNNER_PHASES
    assert farmctl._normalize_phase(NEWS_GATE) == "P6"
    assert farmctl._normalize_phase(NEWS_PHASE) == "P6"
    assert farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", NEWS_GATE)["reason"].endswith(
        f"use {NEWS_PHASE}"
    )
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    evidence = tmp_path / "evidence.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    evidence.write_text("{}", encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        for item_id, phase in (("legacy-q09", NEWS_GATE), ("canonical-q09", NEWS_PHASE)):
            _insert_work_item(
                conn,
                item_id=item_id,
                phase=phase,
                verdict=None,
                evidence_path=evidence,
                setfile_path=setfile,
                status="pending",
            )
        claimable = {row["id"] for row in conn.execute(farmctl.pending_claim_order_sql()).fetchall()}
        bound_payload = {
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": str(tmp_path / "run_plan.json"),
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='canonical-q09'",
            (json.dumps(bound_payload),),
        )
        bound_claimable = {
            row["id"] for row in conn.execute(farmctl.pending_claim_order_sql()).fetchall()
        }
    assert "canonical-q09" not in claimable
    assert "canonical-q09" in bound_claimable
    assert "legacy-q09" not in claimable


def test_q09_enqueue_installs_explicit_plan_hold_before_row_is_claimable(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn,
            item_id="q08",
            phase="Q08",
            verdict="PASS",
            evidence_path=q08_path,
            setfile_path=setfile,
        )
        predecessor_id = "q08"
        predecessor_phase = farmctl.prev_phase(NEWS_PHASE)
        if predecessor_phase != "Q08":
            predecessor_id = "baseline-full-run"
            _insert_work_item(
                conn,
                item_id=predecessor_id,
                phase=str(predecessor_phase),
                verdict="PASS",
                evidence_path=q08_path,
                setfile_path=setfile,
                payload={"promoted_from_work_item": "q08"},
            )
        conn.commit()

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(
            tmp_path,
            "QM5_9999",
            NEWS_PHASE,
            predecessor_work_item_id=predecessor_id,
        )

    assert len(result["created"]) == 1
    q09_id = result["created"][0]["id"]
    with farmctl.connect(tmp_path) as conn:
        row = conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (q09_id,)
        ).fetchone()
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds WHERE work_item_id=?",
            (q09_id,),
        ).fetchone()
        claimable = {
            item["id"] for item in conn.execute(farmctl.pending_claim_order_sql()).fetchall()
        }
    payload = json.loads(row[0])
    assert payload["q09_activation_state"] == farmctl.Q09_ACTIVATION_AWAITING_PLAN
    assert tuple(hold) == (schema.ACTIVATION_HOLD_CODE, 1, 0)
    assert q09_id not in claimable


def test_repair_activates_schema_before_running_repair(tmp_path: Path) -> None:
    fake_repair = types.ModuleType("repair")
    fake_repair.run_all = lambda: {"repaired": True}
    with (
        mock.patch.dict(sys.modules, {"repair": fake_repair}),
        mock.patch.object(farmctl, "_assert_canonical_checkout"),
        mock.patch.object(farmctl, "print_json"),
    ):
        assert farmctl.main(["--root", str(tmp_path), "repair"]) == 0
    with farmctl.connect(tmp_path) as conn:
        assert conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='q09_news_tests'"
        ).fetchone() is not None


def test_q09_portfolio_pass_cannot_directly_create_q12_candidate(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    evidence = tmp_path / "q09p.json"
    setfile = tmp_path / "base.set"
    evidence.write_text("{}", encoding="utf-8")
    setfile.write_text("x=1\n", encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn,
            item_id="q09p",
            phase=PORTFOLIO_PHASE,
            verdict="PASS_PORTFOLIO",
            evidence_path=evidence,
            setfile_path=setfile,
        )
        changed = farmctl._admit_q09_portfolio_passes(
            conn, {"q09_portfolio_admissions": []}
        )
        assert changed == 0
        assert conn.execute("SELECT count(*) FROM portfolio_candidates").fetchone()[0] == 0


def test_q10_enqueue_requires_news_only_and_leaves_portfolio_nullable(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    q09_path = tmp_path / "q09.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}', encoding="utf-8")
    q09_path.write_text('{"verdict":"CONFIG_LOCKED"}', encoding="utf-8")

    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn, item_id="q08", phase="Q08", verdict="PASS",
            evidence_path=q08_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09n", phase=NEWS_PHASE, verdict="CONFIG_LOCKED",
            evidence_path=q09_path, setfile_path=setfile,
        )
        schema.add_dependency(
            conn,
            child_work_item_id="q09n",
            dependency_role="Q08_INPUT",
            parent_work_item_id="q08",
            parent_evidence_sha256=_sha(q08_path),
            required_verdicts=["PASS"],
        )
        _insert_locked_q09(conn, q09_path)

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", INCUMBENT_PHASE)
    assert len(result["created"]) == 1
    q10_id = result["created"][0]["id"]
    with farmctl.connect(tmp_path) as conn:
        roles = {
            row[0]
            for row in conn.execute(
                "SELECT dependency_role FROM work_item_dependencies WHERE child_work_item_id=?",
                (q10_id,),
            ).fetchall()
        }
        assert roles == {NEWS_ROLE}
        gate = schema.assert_q10_dependency_gate(conn, q10_id)
        assert gate.q09_news_work_item_id == "q09n"
        assert gate.q09_portfolio_work_item_id is None
        assert gate.q09_portfolio_evidence_sha256 is None


def test_q10_binds_newest_terminal_portfolio_sibling_as_information(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    q09_path = tmp_path / "q09.json"
    q09p_path = tmp_path / "q09p.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}', encoding="utf-8")
    q09_path.write_text('{"verdict":"CONFIG_LOCKED"}', encoding="utf-8")
    q09p_path.write_text('{"verdict":"FAIL_PORTFOLIO"}', encoding="utf-8")

    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn, item_id="q08", phase="Q08", verdict="PASS",
            evidence_path=q08_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09n", phase=NEWS_PHASE, verdict="CONFIG_LOCKED",
            evidence_path=q09_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09p", phase=PORTFOLIO_PHASE, verdict="FAIL_PORTFOLIO",
            evidence_path=q09p_path, setfile_path=setfile,
        )
        for child in ("q09n", "q09p"):
            schema.add_dependency(
                conn,
                child_work_item_id=child,
                dependency_role="Q08_INPUT",
                parent_work_item_id="q08",
                parent_evidence_sha256=_sha(q08_path),
                required_verdicts=["PASS"],
            )
        _insert_locked_q09(conn, q09_path)

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", INCUMBENT_PHASE)
    assert len(result["created"]) == 1
    q10_id = result["created"][0]["id"]
    with farmctl.connect(tmp_path) as conn:
        edge = conn.execute(
            """
            SELECT parent_work_item_id,required_verdicts_json
            FROM work_item_dependencies
            WHERE child_work_item_id=? AND dependency_role=?
            """,
            (q10_id, PORTFOLIO_ROLE),
        ).fetchone()
        gate = schema.assert_q10_dependency_gate(conn, q10_id)

    assert edge["parent_work_item_id"] == "q09p"
    assert json.loads(edge["required_verdicts_json"]) == [
        "PASS_PORTFOLIO", "FAIL_PORTFOLIO", "FAIL_SYSTEM"
    ]
    assert gate.q09_portfolio_work_item_id == "q09p"


def test_q10_fails_closed_when_present_terminal_portfolio_evidence_is_unreadable(
    tmp_path: Path,
) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    q09_path = tmp_path / "q09.json"
    missing_portfolio_path = tmp_path / "missing-q09p.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}', encoding="utf-8")
    q09_path.write_text('{"verdict":"CONFIG_LOCKED"}', encoding="utf-8")

    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn, item_id="q08", phase="Q08", verdict="PASS",
            evidence_path=q08_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09n", phase=NEWS_PHASE, verdict="CONFIG_LOCKED",
            evidence_path=q09_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09p", phase=PORTFOLIO_PHASE, verdict="FAIL_SYSTEM",
            evidence_path=missing_portfolio_path, setfile_path=setfile,
        )
        for child in ("q09n", "q09p"):
            schema.add_dependency(
                conn,
                child_work_item_id=child,
                dependency_role="Q08_INPUT",
                parent_work_item_id="q08",
                parent_evidence_sha256=_sha(q08_path),
                required_verdicts=["PASS"],
            )
        _insert_locked_q09(conn, q09_path)

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", INCUMBENT_PHASE)

    assert not result["created"]
    assert result["skipped"][0]["reason"] == (
        "latest_terminal_sibling_evidence_missing_or_unreadable"
    )


def test_q10_rejects_plain_news_pass_and_names_exact_governed_verdict(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q09_path = tmp_path / "q09.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    q09_path.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn,
            item_id="plain-pass",
            phase=NEWS_PHASE,
            verdict="PASS",
            evidence_path=q09_path,
            setfile_path=setfile,
        )
        conn.commit()

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(
            tmp_path,
            "QM5_9999",
            INCUMBENT_PHASE,
            predecessor_work_item_id="plain-pass",
        )

    assert farmctl.Q09_NEWS_SUCCESS_VERDICTS == frozenset({"CONFIG_LOCKED"})
    assert not result["enqueued"]
    assert f"{NEWS_PHASE} CONFIG_LOCKED" in result["reason"]


def test_q09_news_verdict_taxonomy_is_preserved() -> None:
    for verdict in ("CONFIG_LOCKED", "REVIEW_REQUIRED", "INVALID_EVIDENCE"):
        actual, _ = farmctl._derive_verdict_from_summary(
            {"verdict": verdict}, phase=NEWS_PHASE
        )
        assert actual == verdict


def test_terminal_worker_requires_matching_q09_sidecar(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    q09_path = tmp_path / "q09.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    q09_path.write_text('{"verdict":"CONFIG_LOCKED"}\n', encoding="utf-8")
    connection = farmctl.connect(tmp_path)
    try:
        _insert_work_item(
            connection, item_id="q08", phase="Q08", verdict="PASS",
            evidence_path=q08_path, setfile_path=setfile,
        )
        _insert_work_item(
            connection, item_id="q09n", phase=NEWS_PHASE, verdict="CONFIG_LOCKED",
            evidence_path=q09_path, setfile_path=setfile,
        )
        schema.add_dependency(
            connection,
            child_work_item_id="q09n",
            dependency_role="Q08_INPUT",
            parent_work_item_id="q08",
            parent_evidence_sha256=_sha(q08_path),
            required_verdicts=["PASS"],
        )
        _insert_locked_q09(connection, q09_path)
        connection.commit()
        item = connection.execute(
            "SELECT * FROM work_items WHERE id='q09n'"
        ).fetchone()
    finally:
        connection.close()

    aggregate = json.loads(q09_path.read_text(encoding="utf-8"))
    assert terminal_worker._q09_sidecar_matches(tmp_path, item, q09_path, aggregate)
    q09_path.write_text('{"verdict":"REVIEW_REQUIRED"}\n', encoding="utf-8")
    assert not terminal_worker._q09_sidecar_matches(
        tmp_path,
        item,
        q09_path,
        json.loads(q09_path.read_text(encoding="utf-8")),
    )


def test_q09_phase_builder_executes_bound_plan_in_reserved_slot(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "QM5_9999_demo_EURUSD.DWX_H1_backtest.set"
    plan = tmp_path / "run_plan.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    plan.write_text("{}\n", encoding="utf-8")
    payload = {
        "q09_run_plan_path": str(plan),
        "q09_run_plan_file_sha256": _sha(plan),
        "q09_dispatch_binding_sha256": "a" * 64,
        "q09_cell_sharding": {
            "helper_terminals": ["T4", "T5"],
            "reserved_by": "q09_cell_shard:123:fixture",
        },
    }
    connection = farmctl.connect(tmp_path)
    try:
        now = farmctl.utc_now()
        connection.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
                payload_json,created_at,updated_at
            ) VALUES('q09-exec', 'backtest', ?, 'QM5_9999',
                     'EURUSD.DWX', ?, 'active', 0, ?, ?, ?)
            """,
            (NEWS_PHASE, str(setfile), json.dumps(payload), now, now),
        )
        connection.commit()
        row = connection.execute(
            "SELECT * FROM work_items WHERE id='q09-exec'"
        ).fetchone()
    finally:
        connection.close()
    report_root = tmp_path / "reports"
    command = farmctl._phase_runner_cmd_for_work_item(
        tmp_path, row, report_root, "T3", REPO
    )
    assert command is not None
    assert command[2] == "execute"
    assert "collect" not in command
    assert command[command.index("--terminal") + 1] == "T3"
    assert command[command.index("--work-item-id") + 1] == "q09-exec"
    assert command[command.index("--work-item-symbol") + 1] == "EURUSD.DWX"
    assert command[command.index("--expert") + 1] == r"QM\QM5_9999"
    assert command[command.index("--expected-plan-file-sha256") + 1] == _sha(plan)
    assert command[command.index("--period") + 1] == "H1"
    parsed = q09_news_runner.build_parser().parse_args(command[2:])
    assert parsed.command == "execute"
    assert parsed.period == "H1"
    assert parsed.helper_terminals == ["T4", "T5"]
    assert parsed.helper_reserved_by == "q09_cell_shard:123:fixture"
    assert Path(command[command.index("--output-root") + 1]) == (
        report_root / "QM5_9999" / NEWS_PHASE / "EURUSD_DWX"
    )
    assert farmctl._phase_runner_cmd_for_work_item(
        tmp_path, row, report_root, None, REPO
    ) is None


def test_q08_pass_and_fail_soft_create_held_news_arms_without_portfolio(tmp_path: Path) -> None:
    for verdict in ("PASS", "FAIL_SOFT"):
        root = tmp_path / verdict.lower()
        farmctl.init_db(root)
        q08_path = root / "q08.json"
        setfile = root / "baseline.set"
        q08_path.write_text(json.dumps({"verdict": verdict}) + "\n", encoding="utf-8")
        setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        now = farmctl.utc_now()
        q08_id = f"q08-{verdict.lower()}"
        with farmctl.connect(root) as conn:
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                  attempt_count,evidence_path,payload_json,created_at,updated_at
                ) VALUES(?,'backtest','Q08','QM5_20266','EURUSD.DWX',?,
                         'done',?,0,?,'{}',?,?)
                """,
                (q08_id, str(setfile), verdict, str(q08_path), now, now),
            )
            result: dict[str, object] = {}
            promoted = farmctl._promote_paired_q09_portfolio_passes_to_news(
                conn, result
            )
            conn.commit()
            news = conn.execute(
                "SELECT id,status,payload_json FROM work_items WHERE phase=?",
                (NEWS_PHASE,),
            ).fetchone()
            dependencies = conn.execute(
                """
                SELECT child_work_item_id,parent_work_item_id,parent_evidence_sha256
                FROM work_item_dependencies ORDER BY child_work_item_id
                """
            ).fetchall()
            hold = conn.execute(
                "SELECT active,hold_code FROM work_item_holds WHERE work_item_id=?",
                (news["id"],),
            ).fetchone()

        assert promoted == 1
        assert news["status"] == "pending"
        payload = json.loads(news["payload_json"])
        assert "q09_portfolio_work_item_id" not in payload
        assert "q09_portfolio_evidence_sha256" not in payload
        assert hold["active"] == 1
        assert hold["hold_code"] == schema.ACTIVATION_HOLD_CODE
        assert [
            (row["child_work_item_id"], row["parent_work_item_id"])
            for row in dependencies
        ] == [(news["id"], q08_id)]


def test_q09_autopilot_uses_approved_contract_v3_semantics(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    ea_id = "QM5_20266"
    symbol = "XTIUSD.DWX"
    q08_id = "87731bac-29cc-4846-ac26-b348b13af59b"
    q09_id = "4263d6b3-1418-47c4-afe1-de7cb6bf61d4"
    q08_path = tmp_path / "q08.json"
    ea_dir = tmp_path / "QM5_20266_collins-66mom"
    setfile = ea_dir / "sets" / "baseline.set"
    ex5 = ea_dir / "QM5_20266_collins-66mom.ex5"
    decoy_dir = tmp_path / "worktree" / "QM5_20266_collins-66mom"
    decoy_ex5 = decoy_dir / "QM5_20266_collins-66mom.ex5"
    closure = tmp_path / "closures" / f"{ea_id}_include_closure.json"
    plan_path = tmp_path / "reports" / q09_id / "run_plan.json"
    q08_path.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    ea_dir.mkdir()
    setfile.parent.mkdir()
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    ex5.write_bytes(b"compiled")
    decoy_dir.mkdir(parents=True)
    decoy_ex5.write_bytes(b"wrong-worktree-binary")
    closure.parent.mkdir()
    closure.write_text("{}\n", encoding="utf-8")
    plan_path.parent.mkdir(parents=True)
    plan_path.write_text("{}\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,evidence_path,payload_json,created_at,updated_at
            ) VALUES(?, 'backtest','Q08',?,?,?,'done','PASS',0,?,'{}',?,?)
            """,
            (q08_id, ea_id, symbol, str(setfile), str(q08_path), now, now),
        )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
              payload_json,created_at,updated_at
            ) VALUES(?, 'backtest',?,?,?,?,'pending',0,?, ?,?)
            """,
            (
                q09_id,
                NEWS_PHASE,
                ea_id,
                symbol,
                str(setfile),
                json.dumps({
                    "q09_autoseal_failure": {"reason_code": "STALE_TEST_FAILURE"},
                    "q09_activation_next_action": (
                        "resolve q09_autoseal_failure; derivation is fail-closed"
                    ),
                }),
                now,
                now,
            ),
        )
        schema.add_dependency(
            conn, child_work_item_id=q09_id, dependency_role="Q08_INPUT",
            parent_work_item_id=q08_id, parent_evidence_sha256=_sha(q08_path),
            required_verdicts=["PASS"],
        )
        schema.hold_until_plan_bound(conn, q09_id, now=now)
        conn.commit()

    expected_lineage = "581415e9911f21ed2aae70f95c0d0c0d3a150f2de70235c8588deb0b601c239d"
    with (
        mock.patch.object(farmctl, "_preferred_ea_dir", return_value=decoy_dir),
        mock.patch.object(farmctl, "Q09_AUTOPILOT_INCLUDE_CLOSURE_ROOT", closure.parent),
        mock.patch.object(farmctl, "Q09_AUTOPILOT_REPORT_ROOT", plan_path.parents[1]),
        mock.patch.object(
            build_q09_include_closure,
            "validate_include_closure",
            return_value={"generated_source_drift": []},
        ),
        mock.patch.object(q09_news_runner, "validate_q08_source_vintage") as validate_vintage,
        mock.patch.object(q09_news_runner, "build_run_plan", return_value={
            "plan_path": str(plan_path), "plan_sha256": "p" * 64,
            "candidate_lineage_key": expected_lineage, "cell_count": 8,
        }) as build_plan,
        mock.patch.object(q09_news_runner, "bind_plan_to_work_item", return_value={
            "activation_hold_released": True,
        }) as bind_plan,
    ):
        result = farmctl.auto_seal_pending_q09_news(tmp_path)

    assert result["sealed_count"] == 1
    kwargs = build_plan.call_args.kwargs
    assert kwargs["candidate_lineage_key"] == expected_lineage
    assert kwargs["deployment_target"] == "DXZ"
    assert kwargs["tester_model"] == "REAL_TICKS"
    assert kwargs["cost_profile"] == "DXZ_CANONICAL_REAL_TICKS_V1"
    assert kwargs["contract_version"] == q09_news_runner.contract.SCHEMA_VERSION_V3
    assert kwargs["force_expanded_matrix"] is False
    assert kwargs["ex5_path"] == ex5
    assert Path(kwargs["output_root"]).name == "q09_contract_v3"
    assert kwargs["calendar_common_relative_path"] == (
        "QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv"
    )
    assert {key: kwargs[key] for key in farmctl.Q09_AUTOPILOT_WINDOWS} == (
        farmctl.Q09_AUTOPILOT_WINDOWS
    )
    assert bind_plan.call_args.kwargs["cell_timeout_sec"] == 10800
    validate_vintage.assert_called_once_with(
        q08_path,
        baseline_setfile_path=setfile.resolve(),
        ex5_path=ex5,
    )
    with farmctl.connect(tmp_path) as conn:
        payload = json.loads(conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (q09_id,)
        ).fetchone()[0])
    assert "q09_autoseal_failure" not in payload
    assert "q09_activation_next_action" not in payload


def test_pump_retries_autoseal_after_regenerated_q08_promotion() -> None:
    """A fresh Q08 identity must be promoted before the same-cycle seal retry."""
    source = inspect.getsource(farmctl._pump_unlocked)

    promotion = source.index("_promote_paired_q09_portfolio_passes_to_news")
    # The late autoseal retry is now wrapped in the pump cycle budget (latency
    # rebaseline 2026-08-23) but must still run AFTER the paired-Q09 promotion so
    # a freshly promoted Q08 identity is sealable in the same cycle.
    post_cascade_retry = source.index('result["q09_autoseal"] = cycle_budget.run(')

    assert promotion < post_cascade_retry


def test_pump_authors_news_expansions_before_build_dispatch_can_exhaust_budget() -> None:
    """A slow build stage must not starve authenticated expansion requests."""
    source = inspect.getsource(farmctl._pump_unlocked)

    expansion = source.index('result["news_expansions"] = cycle_budget.run(')
    build_dispatch = source.index(
        'cycle_budget.record_elapsed(\n        "build_dispatch"'
    )

    assert expansion < build_dispatch


def test_autoseal_replaces_immutable_predecessor_after_append_only_q08(
    tmp_path: Path,
) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "baseline.set"
    old_evidence = tmp_path / "q08-old.json"
    new_evidence = tmp_path / "q08-new.json"
    replacement_plan = tmp_path / "replacement-run-plan.json"
    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
    old_evidence.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    new_evidence.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    replacement_plan.write_text('{"sealed":true}\n', encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        for row_id, evidence, created, payload in (
            ("q08-old", old_evidence, "2026-08-01T00:00:00Z", {}),
            (
                "q08-new", new_evidence, "2026-08-02T00:00:00Z",
                {"append_only_rerun": True, "append_only_rerun_of_work_item": "q08-old"},
            ),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                  attempt_count,evidence_path,payload_json,created_at,updated_at
                ) VALUES(?,'backtest','Q08','QM5_1','EURUSD.DWX',?,'done','PASS',
                         0,?,?,?,?)
                """,
                (
                    row_id, str(setfile), str(evidence), json.dumps(payload),
                    created, created,
                ),
            )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
              payload_json,created_at,updated_at
            ) VALUES('q09-old','backtest',?,'QM5_1','EURUSD.DWX',?,
                     'pending',0,'{}','2026-08-01T01:00:00Z','2026-08-01T01:00:00Z')
            """,
            (NEWS_PHASE, str(setfile)),
        )
        schema.add_dependency(
            conn, child_work_item_id="q09-old", dependency_role="Q08_INPUT",
            parent_work_item_id="q08-old", parent_evidence_sha256=_sha(old_evidence),
            required_verdicts=["PASS"],
        )
        schema.hold_until_plan_bound(conn, "q09-old", now="2026-08-01T01:00:00Z")
        conn.commit()

    spawned = farmctl._spawn_q09_replacements_for_regenerated_q08(tmp_path, limit=10)

    assert len(spawned) == 1
    replacement_id = spawned[0]["replacement_q09_work_item_id"]
    assert spawned[0]["replacement_q08_work_item_id"] == "q08-new"
    with farmctl.connect(tmp_path) as conn:
        replacement_payload = json.loads(conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (replacement_id,)
        ).fetchone()[0])
        replacement_payload.update({
            "q09_run_plan_path": str(replacement_plan),
            "q09_run_plan_file_sha256": _sha(replacement_plan),
        })
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps(replacement_payload), replacement_id),
        )
        dependency = conn.execute(
            """
            SELECT parent_work_item_id FROM work_item_dependencies
            WHERE child_work_item_id=? AND dependency_role='Q08_INPUT'
            """,
            (replacement_id,),
        ).fetchone()
        replacement_hold = conn.execute(
            "SELECT active FROM work_item_holds WHERE work_item_id=?",
            (replacement_id,),
        ).fetchone()
        assert farmctl._supersede_stale_q09_holds_after_rebind(
            conn,
            replacement_q09_id="q09-old",
            replacement_q08_id="q08-old",
            now="2026-08-02T00:30:00Z",
        ) == []
        superseded = farmctl._supersede_stale_q09_holds_after_rebind(
            conn,
            replacement_q09_id=replacement_id,
            replacement_q08_id="q08-new",
            now="2026-08-02T01:00:00Z",
        )
        conn.commit()
        old = conn.execute(
            "SELECT status,verdict,evidence_path,payload_json "
            "FROM work_items WHERE id='q09-old'"
        ).fetchone()
        old_hold = conn.execute(
            "SELECT active,release_note FROM work_item_holds WHERE work_item_id='q09-old'"
        ).fetchone()

    assert dependency[0] == "q08-new"
    assert replacement_hold[0] == 1
    assert superseded == ["q09-old"]
    assert tuple(old[:3]) == ("done", "SUPERSEDED", str(replacement_plan))
    old_payload = json.loads(old[3])
    assert old_payload["supersession_evidence_path"] == str(replacement_plan)
    assert old_payload["supersession_evidence_sha256"] == _sha(replacement_plan)
    assert old_hold[0] == 0
    assert "regenerated Q08" in old_hold[1]


def test_q09_autopilot_derivation_gap_stays_held_with_machine_reason(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
              payload_json,created_at,updated_at
            ) VALUES('q09-gap','backtest',?,'QM5_1','EURUSD.DWX',
                     'missing.set','pending',0,'{}',?,?)
            """,
            (NEWS_PHASE, now, now),
        )
        schema.hold_until_plan_bound(conn, "q09-gap", now=now)
        conn.commit()
    result = farmctl.auto_seal_pending_q09_news(tmp_path)
    assert result["failed_count"] == 1
    with farmctl.connect(tmp_path) as conn:
        row = conn.execute(
            "SELECT payload_json FROM work_items WHERE id='q09-gap'"
        ).fetchone()
        hold = conn.execute(
            "SELECT active FROM work_item_holds WHERE work_item_id='q09-gap'"
        ).fetchone()
    payload = json.loads(row[0])
    assert payload["q09_autoseal_failure"]["reason_code"] == (
        "Q09_AUTOSEAL_DERIVE_LINEAGE_FAILED"
    )
    assert hold[0] == 1


def test_news_autoseal_can_target_exact_work_items(tmp_path: Path) -> None:
    connection = mock.MagicMock()
    connection.execute.return_value.fetchall.return_value = []
    connection_context = mock.MagicMock()
    connection_context.__enter__.return_value = connection
    connection_context.__exit__.return_value = False
    with (
        mock.patch.object(farmctl, "init_db"),
        mock.patch.object(
            farmctl,
            "_spawn_q09_replacements_for_regenerated_q08",
            return_value={},
        ),
        mock.patch.object(farmctl, "connect", return_value=connection_context),
    ):
        result = farmctl.auto_seal_pending_q09_news(
            tmp_path,
            work_item_ids=["child-b", "child-a", "child-b"],
        )

    sql, parameters = connection.execute.call_args.args
    assert "w.id IN (?,?)" in sql
    assert parameters == [
        NEWS_PHASE,
        farmctl.Q09_ACTIVATION_HOLD_CODE,
        "child-b",
        "child-a",
        100,
    ]
    assert result["attempted_count"] == 0


def test_news_autoseal_preserves_stale_closure_and_builds_scoped_successor(
    tmp_path: Path,
) -> None:
    canonical = tmp_path / "QM5_1_include_closure.json"
    canonical.write_text("{}", encoding="utf-8")
    successor = tmp_path / "child-1" / canonical.name
    builder = mock.MagicMock()
    builder.validate_include_closure.side_effect = [
        RuntimeError("include closure source inventory/hash mismatch"),
        {"generated_source_drift": []},
    ]
    builder.build_include_closure.return_value = successor

    with mock.patch.object(
        farmctl, "Q09_AUTOPILOT_INCLUDE_CLOSURE_ROOT", tmp_path
    ):
        path, validation = farmctl._validated_q09_include_closure(
            builder,
            ea_id="QM5_1",
            ea_dir=tmp_path / "QM5_1_demo",
            work_item_id="child-1",
        )

    assert path == successor
    assert validation == {"generated_source_drift": []}
    assert canonical.read_text(encoding="utf-8") == "{}"
    builder.build_include_closure.assert_called_once_with(
        "QM5_1", tmp_path / "child-1", ea_dir=tmp_path / "QM5_1_demo"
    )
    assert builder.validate_include_closure.call_args_list == [
        mock.call("QM5_1", canonical, ea_dir=tmp_path / "QM5_1_demo"),
        mock.call("QM5_1", successor, ea_dir=tmp_path / "QM5_1_demo"),
    ]


def test_news_autoseal_generates_hash_scoped_closure_after_scoped_drift(
    tmp_path: Path,
) -> None:
    canonical = tmp_path / "QM5_1_include_closure.json"
    canonical.write_text("canonical", encoding="utf-8")
    scoped = tmp_path / "child-1" / canonical.name
    scoped.parent.mkdir()
    scoped.write_text("scoped", encoding="utf-8")
    generation_key = "a" * 64
    generation = (
        tmp_path / "child-1" / "successors" / generation_key / canonical.name
    )
    builder = mock.MagicMock()
    builder.validate_include_closure.side_effect = [
        RuntimeError("include closure source inventory/hash mismatch"),
        RuntimeError("include closure source inventory/hash mismatch"),
        {"generated_source_drift": []},
    ]
    builder.include_closure_generation_key.return_value = generation_key
    builder.build_include_closure.return_value = generation

    with mock.patch.object(
        farmctl, "Q09_AUTOPILOT_INCLUDE_CLOSURE_ROOT", tmp_path
    ):
        path, validation = farmctl._validated_q09_include_closure(
            builder,
            ea_id="QM5_1",
            ea_dir=tmp_path / "QM5_1_demo",
            work_item_id="child-1",
        )

    assert path == generation
    assert validation == {"generated_source_drift": []}
    builder.include_closure_generation_key.assert_called_once_with(
        "QM5_1", ea_dir=tmp_path / "QM5_1_demo"
    )
    builder.build_include_closure.assert_called_once_with(
        "QM5_1", generation.parent, ea_dir=tmp_path / "QM5_1_demo"
    )


def _autoseal_plan_collision_fixture(tmp_path: Path) -> tuple[dict, dict]:
    source_paths = {}
    for name in ("q08", "baseline", "expert", "closure", "calendar"):
        path = tmp_path / f"{name}.bin"
        path.write_bytes(f"{name}-bytes".encode("ascii"))
        source_paths[name] = path
    kwargs = {
        "work_item_id": "q09-child",
        "candidate_lineage_key": "lineage-key",
        "deployment_target": "DXZ",
        "q08_work_item_id": "q08-parent",
        "q08_evidence_path": source_paths["q08"],
        "baseline_setfile_path": source_paths["baseline"],
        "ex5_path": source_paths["expert"],
        "include_closure_path": source_paths["closure"],
        "calendar_manifest_path": source_paths["calendar"],
        "calendar_common_relative_path": "QM/q09_news/events.csv",
        "full_from_utc": "2019-01-01T00:00:00Z",
        "full_to_utc": "2025-12-31T23:59:59Z",
        "selection_from_utc": "2019-01-01T00:00:00Z",
        "selection_to_utc": "2023-12-31T23:59:59Z",
        "holdout_from_utc": "2024-01-01T00:00:00Z",
        "holdout_to_utc": "2025-12-31T23:59:59Z",
        "complete_months": 60,
        "holdout_complete_months": 24,
        "tester_model": "REAL_TICKS",
        "cost_profile": "DXZ_CANONICAL_REAL_TICKS_V1",
        "news_or_event_strategy": False,
        "force_expanded_matrix": False,
        "contract_version": q09_news_runner.contract.SCHEMA_VERSION_V3,
    }
    manifest = {
        "work_item_id": kwargs["work_item_id"],
        "candidate_lineage_key": kwargs["candidate_lineage_key"],
        "contract_version": kwargs["contract_version"],
        "identities": {
            "q08_work_item_id": kwargs["q08_work_item_id"],
            "q08_evidence_sha256": _sha(source_paths["q08"]),
            "baseline_setfile_sha256": _sha(source_paths["baseline"]),
            "ex5_sha256": _sha(source_paths["expert"]),
        },
    }
    return kwargs, manifest


def test_autoseal_plan_collision_builds_authenticated_hash_scoped_successor(
    tmp_path: Path,
) -> None:
    output_root = tmp_path / "q09_contract_v3"
    output_root.mkdir()
    primary_plan = output_root / "run_plan.json"
    primary_plan.write_text("primary-plan\n", encoding="utf-8")
    kwargs, manifest = _autoseal_plan_collision_fixture(tmp_path)
    runner = mock.MagicMock()
    runner.RunnerError = q09_news_runner.RunnerError
    runner.load_authenticated_plan.return_value = (
        {
            "work_item_id": kwargs["work_item_id"],
            "candidate_lineage_key": kwargs["candidate_lineage_key"],
            "contract_version": kwargs["contract_version"],
        },
        manifest,
    )

    def build(**call_kwargs):
        if call_kwargs["output_root"] == output_root:
            raise q09_news_runner.RunnerError(
                "existing planned artifact contradicts immutable content: input_manifest.json"
            )
        return {"plan_path": str(call_kwargs["output_root"] / "run_plan.json")}

    runner.build_run_plan.side_effect = build

    plan, generation = farmctl._build_q09_autoseal_plan(
        runner,
        output_root=output_root,
        **kwargs,
    )

    successor_root = Path(plan["plan_path"]).parent
    assert generation["mode"] == "hash_scoped_successor"
    assert successor_root.parent == output_root / "successors"
    assert successor_root.name == generation["generation_key_sha256"]
    assert len(successor_root.name) == 64
    assert generation["supersedes_plan_path"] == str(primary_plan)
    assert primary_plan.read_text(encoding="utf-8") == "primary-plan\n"


def test_autoseal_plan_collision_refuses_mismatched_primary_identity(
    tmp_path: Path,
) -> None:
    output_root = tmp_path / "q09_contract_v3"
    output_root.mkdir()
    (output_root / "run_plan.json").write_text("primary-plan\n", encoding="utf-8")
    kwargs, manifest = _autoseal_plan_collision_fixture(tmp_path)
    manifest["identities"]["ex5_sha256"] = "0" * 64
    runner = mock.MagicMock()
    runner.RunnerError = q09_news_runner.RunnerError
    runner.build_run_plan.side_effect = q09_news_runner.RunnerError(
        "existing planned artifact contradicts immutable content: input_manifest.json"
    )
    runner.load_authenticated_plan.return_value = (
        {
            "work_item_id": kwargs["work_item_id"],
            "candidate_lineage_key": kwargs["candidate_lineage_key"],
            "contract_version": kwargs["contract_version"],
        },
        manifest,
    )

    with pytest.raises(q09_news_runner.RunnerError, match="not eligible"):
        farmctl._build_q09_autoseal_plan(
            runner,
            output_root=output_root,
            **kwargs,
        )


def test_bind_q09_dry_run_does_not_initialize_or_write_database(tmp_path: Path) -> None:
    dry_args = mock.Mock(command="bind-q09-plan", dry_run=True)
    apply_args = mock.Mock(command="bind-q09-plan", dry_run=False)
    assert farmctl._command_mutates_state(dry_args) is False
    assert farmctl._command_mutates_state(apply_args) is True
    with (
        mock.patch.object(farmctl, "init_db") as init_db,
        mock.patch.object(
            q09_news_runner,
            "bind_plan_to_work_item",
            return_value={"dry_run": True},
        ) as binder,
    ):
        result = farmctl.bind_q09_run_plan(
            tmp_path,
            work_item_id="q09",
            plan_path=tmp_path / "plan.json",
            expected_plan_file_sha256="a" * 64,
            dry_run=True,
        )

    init_db.assert_not_called()
    assert result == {"dry_run": True}
    assert binder.call_args.kwargs["dry_run"] is True


def test_q09_config_locked_auto_cascade_is_exact_predecessor_bound(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,payload_json,created_at,updated_at
            ) VALUES('q09-done','backtest',?,'QM5_9','EURUSD.DWX',
                     'base.set','done','CONFIG_LOCKED',0,'{}',?,?)
            """,
            (NEWS_PHASE, now, now),
        )
        conn.commit()
    with mock.patch.object(
        farmctl, "enqueue_cascade_backtest_for_ea", return_value={"enqueued": True}
    ) as enqueue:
        result = farmctl.auto_enqueue_q10_after_q09_result(
            tmp_path, q09_news_work_item_id="q09-done"
        )
    assert result["enqueued"] is True
    enqueue.assert_called_once_with(
        tmp_path, "QM5_9", INCUMBENT_PHASE, predecessor_work_item_id="q09-done"
    )


def test_terminal_worker_invokes_q10_cascade_after_authenticated_finish(
    tmp_path: Path,
) -> None:
    finished = {
        "finished": True, "status": "done", "verdict": "CONFIG_LOCKED"
    }
    with (
        mock.patch.object(terminal_worker, "_with_sqlite_retry", return_value=finished),
        mock.patch.object(
            farmctl,
            "auto_enqueue_q10_after_q09_result",
            return_value={"enqueued": True, "created": [{"id": "q10"}]},
        ) as cascade,
    ):
        result = terminal_worker._finish_work_item(tmp_path, "q09-done", 0)
    assert result["q10_cascade"]["enqueued"] is True
    cascade.assert_called_once_with(tmp_path, q09_news_work_item_id="q09-done")
