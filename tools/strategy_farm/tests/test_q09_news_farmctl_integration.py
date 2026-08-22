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
import build_q09_include_closure  # noqa: E402
import q09_news_runner  # noqa: E402
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
        conn.commit()

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(
            tmp_path,
            "QM5_9999",
            "Q09_NEWS",
            predecessor_work_item_id="q08",
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
            phase="Q09_NEWS",
            verdict="PASS",
            evidence_path=q09_path,
            setfile_path=setfile,
        )
        conn.commit()

    with mock.patch.object(farmctl, "_ea_build_artifact_failure", return_value=None):
        result = farmctl.enqueue_cascade_backtest_for_ea(
            tmp_path,
            "QM5_9999",
            "Q10",
            predecessor_work_item_id="plain-pass",
        )

    assert farmctl.Q09_NEWS_SUCCESS_VERDICTS == frozenset({"CONFIG_LOCKED"})
    assert not result["enqueued"]
    assert "Q09_NEWS CONFIG_LOCKED" in result["reason"]


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
    setfile = tmp_path / "QM5_9999_demo_EURUSD.DWX_H1_backtest.set"
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
    assert command[command.index("--period") + 1] == "H1"
    parsed = q09_news_runner.build_parser().parse_args(command[2:])
    assert parsed.command == "execute"
    assert parsed.period == "H1"
    assert Path(command[command.index("--output-root") + 1]) == (
        report_root / "QM5_9999" / "Q09_NEWS" / "EURUSD_DWX"
    )
    assert farmctl._phase_runner_cmd_for_work_item(
        tmp_path, row, report_root, None, REPO
    ) is None


def test_paired_portfolio_rescue_creates_exact_held_news_arm(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    q08_path = tmp_path / "q08.json"
    portfolio_path = tmp_path / "portfolio.json"
    setfile = tmp_path / "baseline.set"
    q08_path.write_text('{"verdict":"FAIL_SOFT"}\n', encoding="utf-8")
    portfolio_path.write_text('{"verdict":"PASS_PORTFOLIO"}\n', encoding="utf-8")
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,evidence_path,payload_json,created_at,updated_at
            ) VALUES('q08-soft','backtest','Q08','QM5_20266','EURUSD.DWX',?,
                     'done','FAIL_SOFT',0,?,'{}',?,?)
            """,
            (str(setfile), str(q08_path), now, now),
        )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,evidence_path,payload_json,created_at,updated_at
            ) VALUES('portfolio-pass','backtest','Q09_PORTFOLIO','QM5_20266',
                     'EURUSD.DWX',?,'done','PASS_PORTFOLIO',0,?,'{}',?,?)
            """,
            (str(setfile), str(portfolio_path), now, now),
        )
        result: dict[str, object] = {}
        promoted = farmctl._promote_paired_q09_portfolio_passes_to_news(
            conn, result
        )
        conn.commit()
        news = conn.execute(
            "SELECT id,status,payload_json FROM work_items WHERE phase='Q09_NEWS'"
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
    assert payload["q09_portfolio_work_item_id"] == "portfolio-pass"
    assert payload["q09_portfolio_evidence_sha256"] == _sha(portfolio_path)
    assert hold["active"] == 1
    assert hold["hold_code"] == schema.ACTIVATION_HOLD_CODE
    assert {(row["child_work_item_id"], row["parent_work_item_id"]) for row in dependencies} == {
        ("portfolio-pass", "q08-soft"),
        (news["id"], "q08-soft"),
    }


def test_q09_autopilot_uses_oracle_standard_v2_semantics(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    ea_id = "QM5_20266"
    symbol = "XTIUSD.DWX"
    q08_id = "87731bac-29cc-4846-ac26-b348b13af59b"
    q09_id = "4263d6b3-1418-47c4-afe1-de7cb6bf61d4"
    setfile = tmp_path / "baseline.set"
    q08_path = tmp_path / "q08.json"
    ea_dir = tmp_path / "QM5_20266_collins-66mom"
    ex5 = ea_dir / "QM5_20266_collins-66mom.ex5"
    closure = tmp_path / "closures" / f"{ea_id}_include_closure.json"
    plan_path = tmp_path / "reports" / q09_id / "run_plan.json"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    q08_path.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    ea_dir.mkdir()
    ex5.write_bytes(b"compiled")
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
            ) VALUES(?, 'backtest','Q09_NEWS',?,?,?,'pending',0,?, ?,?)
            """,
            (
                q09_id,
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
        mock.patch.object(farmctl, "_preferred_ea_dir", return_value=ea_dir),
        mock.patch.object(farmctl, "Q09_AUTOPILOT_INCLUDE_CLOSURE_ROOT", closure.parent),
        mock.patch.object(farmctl, "Q09_AUTOPILOT_REPORT_ROOT", plan_path.parents[1]),
        mock.patch.object(
            build_q09_include_closure,
            "validate_include_closure",
            return_value={"generated_source_drift": []},
        ),
        mock.patch.object(q09_news_runner, "build_run_plan", return_value={
            "plan_path": str(plan_path), "plan_sha256": "p" * 64,
            "candidate_lineage_key": expected_lineage, "cell_count": 40,
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
    assert kwargs["calendar_common_relative_path"] == (
        "QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv"
    )
    assert {key: kwargs[key] for key in farmctl.Q09_AUTOPILOT_WINDOWS} == (
        farmctl.Q09_AUTOPILOT_WINDOWS
    )
    assert bind_plan.call_args.kwargs["cell_timeout_sec"] == 10800
    with farmctl.connect(tmp_path) as conn:
        payload = json.loads(conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (q09_id,)
        ).fetchone()[0])
    assert "q09_autoseal_failure" not in payload
    assert "q09_activation_next_action" not in payload


def test_q09_autopilot_derivation_gap_stays_held_with_machine_reason(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
              payload_json,created_at,updated_at
            ) VALUES('q09-gap','backtest','Q09_NEWS','QM5_1','EURUSD.DWX',
                     'missing.set','pending',0,'{}',?,?)
            """,
            (now, now),
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


def test_q09_config_locked_auto_cascade_is_exact_predecessor_bound(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,payload_json,created_at,updated_at
            ) VALUES('q09-done','backtest','Q09_NEWS','QM5_9','EURUSD.DWX',
                     'base.set','done','CONFIG_LOCKED',0,'{}',?,?)
            """,
            (now, now),
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
        tmp_path, "QM5_9", "Q10", predecessor_work_item_id="q09-done"
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
