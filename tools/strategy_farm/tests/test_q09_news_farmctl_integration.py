import hashlib
import json
import sqlite3
import sys
import types
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import q09_news_schema as schema  # noqa: E402
import terminal_worker  # noqa: E402


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
        (item_id, phase, str(setfile_path), status, verdict, str(evidence_path), now, now),
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
    assert "Q09_NEWS" in farmctl.CASCADE_BACKTEST_PHASES
    assert "Q09_NEWS" in farmctl.REAL_PHASE_RUNNER_PHASES
    assert "Q09" not in farmctl.CASCADE_BACKTEST_PHASES
    assert "Q09" not in farmctl.REAL_PHASE_RUNNER_PHASES
    assert farmctl._normalize_phase("Q09") == "P6"
    assert farmctl._normalize_phase("Q09_NEWS") == "P6"
    assert farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", "Q09")["reason"].endswith(
        "use Q09_NEWS"
    )
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    evidence = tmp_path / "evidence.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    evidence.write_text("{}", encoding="utf-8")
    with farmctl.connect(tmp_path) as conn:
        for item_id, phase in (("legacy-q09", "Q09"), ("canonical-q09", "Q09_NEWS")):
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
    assert "canonical-q09" in claimable
    assert "legacy-q09" not in claimable


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
            phase="Q09_PORTFOLIO",
            verdict="PASS_PORTFOLIO",
            evidence_path=evidence,
            setfile_path=setfile,
        )
        changed = farmctl._admit_q09_portfolio_passes(
            conn, {"q09_portfolio_admissions": []}
        )
        assert changed == 0
        assert conn.execute("SELECT count(*) FROM portfolio_candidates").fetchone()[0] == 0


def test_q10_enqueue_requires_and_binds_both_q09_dependencies(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    setfile = tmp_path / "base.set"
    q08_path = tmp_path / "q08.json"
    q09_path = tmp_path / "q09.json"
    q09p_path = tmp_path / "q09p.json"
    setfile.write_text("x=1\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}', encoding="utf-8")
    q09_path.write_text('{"verdict":"CONFIG_LOCKED"}', encoding="utf-8")
    q09p_path.write_text('{"verdict":"PASS_PORTFOLIO"}', encoding="utf-8")

    with farmctl.connect(tmp_path) as conn:
        _insert_work_item(
            conn, item_id="q08", phase="Q08", verdict="PASS",
            evidence_path=q08_path, setfile_path=setfile,
        )
        _insert_work_item(
            conn, item_id="q09n", phase="Q09_NEWS", verdict="CONFIG_LOCKED",
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
        first = farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", "Q10")
    assert not first["created"]
    assert first["skipped"][0]["reason"] == "matching_q09_portfolio_pass_missing"
    with farmctl.connect(tmp_path) as conn:
        assert conn.execute("SELECT count(*) FROM work_items WHERE phase='Q10'").fetchone()[0] == 0
        _insert_work_item(
            conn, item_id="q09p", phase="Q09_PORTFOLIO", verdict="PASS_PORTFOLIO",
            evidence_path=q09p_path, setfile_path=setfile,
        )
        schema.add_dependency(
            conn,
            child_work_item_id="q09p",
            dependency_role="Q08_INPUT",
            parent_work_item_id="q08",
            parent_evidence_sha256=_sha(q08_path),
            required_verdicts=["PASS"],
        )

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        second = farmctl.enqueue_cascade_backtest_for_ea(tmp_path, "QM5_9999", "Q10")
    assert len(second["created"]) == 1
    q10_id = second["created"][0]["id"]
    with farmctl.connect(tmp_path) as conn:
        roles = {
            row[0]
            for row in conn.execute(
                "SELECT dependency_role FROM work_item_dependencies WHERE child_work_item_id=?",
                (q10_id,),
            ).fetchall()
        }
        assert roles == {"Q09_NEWS", "Q09_PORTFOLIO"}
        gate = schema.assert_q10_dependency_gate(conn, q10_id)
        assert gate.q09_news_work_item_id == "q09n"
        assert gate.q09_portfolio_work_item_id == "q09p"


def test_q09_news_verdict_taxonomy_is_preserved() -> None:
    for verdict in ("CONFIG_LOCKED", "REVIEW_REQUIRED", "INVALID_EVIDENCE"):
        actual, _ = farmctl._derive_verdict_from_summary(
            {"verdict": verdict}, phase="Q09_NEWS"
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
            connection, item_id="q09n", phase="Q09_NEWS", verdict="CONFIG_LOCKED",
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
    setfile = tmp_path / "base.set"
    plan = tmp_path / "run_plan.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    plan.write_text("{}\n", encoding="utf-8")
    payload = {
        "q09_run_plan_path": str(plan),
        "q09_run_plan_file_sha256": _sha(plan),
        "q09_dispatch_binding_sha256": "a" * 64,
    }
    connection = farmctl.connect(tmp_path)
    try:
        now = farmctl.utc_now()
        connection.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
                payload_json,created_at,updated_at
            ) VALUES('q09-exec', 'backtest', 'Q09_NEWS', 'QM5_9999',
                     'EURUSD.DWX', ?, 'active', 0, ?, ?, ?)
            """,
            (str(setfile), json.dumps(payload), now, now),
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
    assert Path(command[command.index("--output-root") + 1]) == (
        report_root / "QM5_9999" / "Q09_NEWS" / "EURUSD_DWX"
    )
    assert farmctl._phase_runner_cmd_for_work_item(
        tmp_path, row, report_root, None, REPO
    ) is None
