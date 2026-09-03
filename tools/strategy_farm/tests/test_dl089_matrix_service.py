from __future__ import annotations

import hashlib
import json
import sqlite3
from unittest.mock import patch
from pathlib import Path

import pytest

from tools.strategy_farm import dl089_matrix_service as service
from tools.strategy_farm import farmctl
from tools.strategy_farm import opt_census_pruning as pruning
from tools.strategy_farm import optimization_fork_driver as routing


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _sibling(repo: Path) -> dict[str, Path]:
    label = "QM5_41161_tv-mon-ls-opt"
    ea_dir = repo / "framework" / "EAs" / label
    sets = ea_dir / "sets"
    docs = ea_dir / "docs"
    sets.mkdir(parents=True)
    docs.mkdir()
    source = ea_dir / f"{label}.mq5"
    source.write_text(
        "\n".join(
            [
                "input int opt_pp_buy1 = 0;",
                "input int opt_pp_buy2 = 0;",
                "input int opt_pp_buy3 = 0;",
                "input int opt_pp_sell1 = 0;",
                "input int opt_pp_sell2 = 0;",
                "input int opt_pp_sell3 = 0;",
                "// QM_PatternPermission",
                "bool gate = QM_PatternPermissionEvaluate();",
            ]
        ),
        encoding="utf-8",
    )
    binary = ea_dir / f"{label}.ex5"
    binary.write_bytes(b"compiled-fixture")
    setfile = sets / f"{label}_GBPUSD.DWX_H1_backtest.set"
    setfile.write_text(
        "\n".join(
            [
                "; environment: backtest",
                "qm_ea_id=41161",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "qm_news_stale_max_hours=336",
                "",
            ]
        ),
        encoding="utf-8",
    )
    card = docs / "strategy_card.md"
    card.write_text(
        """---
ea_id: QM5_41161
slug: tv-mon-ls-opt
parent_ea_id: QM5_10706
g0_status: APPROVED
period: H1
target_symbols: [GBPUSD.DWX]
---
""",
        encoding="utf-8",
    )
    return {
        "ea_dir": ea_dir,
        "source": source,
        "binary": binary,
        "setfile": setfile,
        "card": card,
    }


def _insert_fixture_rows(
    db: Path, files: dict[str, Path], tmp_path: Path, artifact_root: Path
) -> str:
    compile_evidence = tmp_path / "compile_evidence.json"
    compile_evidence.write_text('{"verdict":"COMPILE_OK"}\n', encoding="utf-8")
    q02_evidence = tmp_path / "q02_summary.json"
    q02_evidence.write_text("{}\n", encoding="utf-8")
    harness_evidence = tmp_path / "harness.csv"
    harness_evidence.write_text("case,status\nfixture,PASS\n", encoding="utf-8")

    declaration = routing._pattern_candidate_declaration(
        parent={"ea_id": "QM5_10706", "symbol": "GBPUSD.DWX"},
        parent_bindings={
            "source": {"path": str(files["source"])},
            "setfile": {"path": str(files["setfile"])},
        },
    )
    payload = {
        "schema": routing.SCHEMA,
        "role": "PATTERN",
        "phase": "Q12",
        "gate_contract_version": "v4",
        "routing_revision": routing.PATTERN_DECLARATION_REVISION,
        "execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
        "activation_state": "READY",
        "machine_reason": "PREREQUISITES_GREEN",
        "pattern_filter_sweep": declaration,
    }
    neutral_text = service._neutral_matrix_setfile(files["setfile"], "QM5_41161")
    neutral_sha = hashlib.sha256(neutral_text.encode("utf-8")).hexdigest()
    q02_setfile = (
        artifact_root
        / declaration["program_id"]
        / "base_setfiles"
        / f"QM5_41161_tv-mon-ls-opt_GBPUSD.DWX_H1_{neutral_sha[:16]}.set"
    )
    now = "2026-08-26T10:00:00+00:00"
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              payload_json,created_at,updated_at,gate_contract_version
            ) VALUES(?,?,?,?,?,?,'pending',NULL,0,?,?,?,'v4')
            """,
            (
                "q12-declared",
                "analytic",
                "Q12",
                "QM5_10706",
                "GBPUSD.DWX",
                str(files["setfile"]),
                json.dumps(payload, sort_keys=True),
                now,
                now,
            ),
        )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version,
              ex5_sha256,mq5_sha256
            ) VALUES(?,?,?,?,?,?,'done','COMPILE_OK',0,?, '{}',?,?,'v4',?,?)
            """,
            (
                "compile-ok",
                "utility",
                "COMPILE_EA",
                "QM5_41161",
                "",
                str(files["source"]),
                str(compile_evidence),
                now,
                now,
                _sha(files["binary"]),
                _sha(files["source"]),
            ),
        )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES(?,?,?,?,?,?,'done','PASS',0,?,'{}',?,?,'v4')
            """,
            (
                "q02-pass",
                "backtest",
                "Q02",
                "QM5_41161",
                "GBPUSD.DWX",
                str(q02_setfile),
                str(q02_evidence),
                now,
                now,
            ),
        )
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES(?,?,?,?,?,?,'done','HARNESS_OK',0,?,'{}',?,?,'legacy')
            """,
            (
                routing.HARNESS_ROOT_WORK_ITEM_ID,
                "harness",
                routing.HARNESS_PHASE,
                routing.HARNESS_EA_ID,
                "EURUSD.DWX",
                str(files["setfile"]),
                str(harness_evidence),
                now,
                now,
            ),
        )
        conn.commit()
    return declaration["declaration_sha256"]


def test_matrix_service_materializes_declared_cells_with_bounded_window(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    files = _sibling(repo)
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    artifact_root = tmp_path / "matrix_artifacts"
    declaration_sha = _insert_fixture_rows(db, files, tmp_path, artifact_root)

    with farmctl.connect(root) as conn:
        result = service.service_pending(
            conn,
            db_path=db,
            repo_root=repo,
            artifact_root=artifact_root,
            apply=True,
            q12_work_item_ids=["q12-declared"],
            window=8,
        )

    assert result["materialized"][0]["enqueue"]["inserted"] == 1085
    assert result["materialized"][0]["measurement_ea_id"] == "QM5_41161"
    registration = Path(result["materialized"][0]["registration_path"])
    assert registration.is_file()
    registration_payload = json.loads(registration.read_text(encoding="utf-8"))
    assert registration_payload["declaration_sha256"] == declaration_sha
    neutral_setfile = Path(registration_payload["measurement_bindings"]["setfile"]["path"])
    neutral_text = neutral_setfile.read_text(encoding="utf-8")
    assert neutral_setfile.is_file()
    for key in service.census.SET_KEYS:
        assert f"{key}=0" in neutral_text
    assert "RISK_FIXED=1000" in neutral_text
    assert "RISK_PERCENT=0" in neutral_text
    assert "qm_news_stale_max_hours=336" in neutral_text

    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        cells = conn.execute(
            "SELECT * FROM work_items WHERE phase='OPT_CENSUS' ORDER BY created_at,id"
        ).fetchall()
        assert len(cells) == 1085
        assert {row["ea_id"] for row in cells} == {"QM5_41161"}
        assert {row["parent_task_id"] for row in cells} == {"q12-declared"}
        flagged = 0
        for row in cells:
            payload = json.loads(row["payload_json"])
            assert payload["q12_work_item_id"] == "q12-declared"
            assert payload["q12_declaration_sha256"] == declaration_sha
            if payload.get("priority_track") is True:
                flagged += 1
        # Default rollback still permits only one executable lane, while a
        # G-sized authenticated frontier buffer keeps that lane supplied
        # between matrix-service pump cycles.
        assert flagged == 6
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds "
            "WHERE work_item_id='q12-declared'"
        ).fetchone()
        assert tuple(hold) == (service.ROLLOUT_HOLD_CODE, 1, 1)

    # Drain one current marker without changing the Q12 owner.  The early
    # refill-only path must restore the G-sized frontier without invoking the
    # comprehensive sibling/Q02/materialization service.
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        marked = conn.execute(
            "SELECT id,payload_json FROM work_items WHERE phase='OPT_CENSUS' "
            "AND status='pending' ORDER BY created_at,id"
        ).fetchall()
        drained = next(
            row for row in marked
            if json.loads(row["payload_json"]).get(
                service.census.FRONTIER_PRIORITY_MARKER
            ) is True
        )
        payload = json.loads(drained["payload_json"])
        payload.pop(service.census.FRONTIER_PRIORITY_MARKER, None)
        payload.pop(service.census.FRONTIER_PRIORITY_AT, None)
        payload.pop("priority_track", None)
        payload.pop("boost_authority", None)
        payload.pop("boosted_at_utc", None)
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), drained["id"]),
        )
        conn.commit()

    with farmctl.connect(root) as conn:
        refill = service.refill_existing_frontiers(
            conn,
            db_path=db,
            worker_count=10,
            apply=True,
            window=8,
        )
    assert len(refill["refilled"]) == 1
    assert refill["refilled"][0]["boost"]["boosted_now"] == 1
    with sqlite3.connect(db) as conn:
        restored = sum(
            json.loads(row[0]).get(service.census.FRONTIER_PRIORITY_MARKER) is True
            for row in conn.execute(
                "SELECT payload_json FROM work_items "
                "WHERE phase='OPT_CENSUS' AND status='pending'"
            )
        )
    assert restored == 6


def test_matrix_service_refuses_q12_rebind_for_existing_program_cells(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    files = _sibling(repo)
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    artifact_root = tmp_path / "matrix_artifacts"
    _insert_fixture_rows(db, files, tmp_path, artifact_root)

    with farmctl.connect(root) as conn:
        first = service.service_pending(
            conn,
            db_path=db,
            repo_root=repo,
            artifact_root=artifact_root,
            apply=True,
            q12_work_item_ids=["q12-declared"],
        )
    ledger_path = Path(first["materialized"][0]["ledger_path"])
    before = ledger_path.read_bytes()

    with sqlite3.connect(db) as conn:
        owner = conn.execute(
            "SELECT payload_json FROM work_items WHERE id='q12-declared'"
        ).fetchone()
        shadow_payload = json.loads(owner[0])
        shadow_payload["parent_work_item_id"] = "ablation-parent"
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('q12-ablation-shadow','analytic','Q12','QM5_10706','GBPUSD.DWX',
                     'ablation.set','pending',NULL,0,?,?,?,'v4')
            """,
            (
                json.dumps(shadow_payload, sort_keys=True),
                "2026-08-29T10:00:00+00:00",
                "2026-08-29T10:00:00+00:00",
            ),
        )
        conn.commit()

    with farmctl.connect(root) as conn:
        result = service.service_pending(
            conn,
            db_path=db,
            repo_root=repo,
            artifact_root=artifact_root,
            apply=True,
            q12_work_item_ids=["q12-ablation-shadow"],
        )

    assert result["materialized"] == []
    assert result["maintained"] == []
    assert len(result["deferred"]) == 1
    assert result["deferred"][0]["work_item_id"] == "q12-ablation-shadow"
    assert result["deferred"][0]["machine_reason"].startswith(
        "PROGRAM_Q12_REBIND_REFUSED:"
    )
    assert ledger_path.read_bytes() == before
    ledger = json.loads(before)
    assert ledger["q12_work_item_id"] == "q12-declared"
    with sqlite3.connect(db) as conn:
        owners = conn.execute(
            "SELECT DISTINCT parent_task_id,json_extract(payload_json,'$.q12_work_item_id') "
            "FROM work_items WHERE phase='OPT_CENSUS'"
        ).fetchall()
    assert owners == [("q12-declared", "q12-declared")]

    corrupted = json.loads(before)
    corrupted["q12_work_item_id"] = "q12-ablation-shadow"
    corrupted["q12_declaration_sha256"] = "shadow-declaration"
    ledger_path.write_text(
        json.dumps(corrupted, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    with farmctl.connect(root) as conn:
        repaired = service.service_pending(
            conn,
            db_path=db,
            repo_root=repo,
            artifact_root=artifact_root,
            apply=True,
            q12_work_item_ids=["q12-declared"],
        )
    reconciliation = repaired["maintained"][0]["binding_reconciliation"]
    assert reconciliation["action"] == "RESTAMPED_FROM_CELL_OWNER"
    assert reconciliation["previous_ledger_q12_work_item_id"] == (
        "q12-ablation-shadow"
    )
    restamped = json.loads(ledger_path.read_text(encoding="utf-8"))
    assert restamped["q12_work_item_id"] == "q12-declared"
    assert restamped["q12_declaration_sha256"] == (
        json.loads(owner[0])["pattern_filter_sweep"]["declaration_sha256"]
    )


def test_pump_refills_existing_frontiers_before_budget_heavy_stages() -> None:
    source = Path(farmctl.__file__).read_text(encoding="utf-8")
    pump = source.split("def _pump_unlocked(", 1)[1].split("\ndef pump(", 1)[0]
    dispatch = pump.index('"dispatch_tick"')
    refill = pump.index('result["dl089_frontier_refill"] = cycle_budget.run(')
    queue_maintenance = pump.index("queue_stage_started = time.monotonic()")
    first_budget_return = pump.index(
        'result["build_dispatch"] = {"skipped": "cycle_budget_exhausted"}'
    )
    # 2026-09-02 (CEO): the full matrix service, the fork driver and the fork
    # service are census-critical and run right after the cheap refill, BEFORE
    # the budget-heavy intake/build/review stages (dispatch overruns starved them).
    full_service = pump.index('result["dl089_matrix_service"] = cycle_budget.run(')
    fork_driver = pump.index('result["optimization_fork"] = cycle_budget.run(')
    fork_service = pump.index('result["optimization_fork_service"] = cycle_budget.run(')
    assert dispatch < refill < fork_driver < full_service < fork_service
    assert fork_service < queue_maintenance < first_budget_return


def test_program_slots_default_override_and_bounds() -> None:
    with patch.dict("os.environ", {}, clear=True):
        assert service.program_slots() == 4
    with patch.dict("os.environ", {"DL089_PROGRAM_SLOTS": "1"}, clear=True):
        assert service.program_slots() == 1
    with patch.dict("os.environ", {"DL089_PROGRAM_SLOTS": "999"}, clear=True):
        assert service.program_slots() == 10
    with patch.dict("os.environ", {"DL089_PROGRAM_SLOTS": "invalid"}, clear=True):
        assert service.program_slots() == 4


def test_same_program_limits_default_off_and_worker_bounded() -> None:
    with patch.dict("os.environ", {}, clear=True):
        assert service.scheduling.lanes_per_program() == 1
        assert service.scheduling.same_program_parallel_allowlist() == frozenset()
        assert service.scheduling.effective_limits(3) == (3, 1, 3)
    with patch.dict(
        "os.environ",
        {
            "DL089_PROGRAM_SLOTS": "4",
            "DL089_LANES_PER_PROGRAM": "2",
            "DL089_CELL_SLOTS": "6",
            "DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST": "program-a, program-b",
        },
        clear=True,
    ):
        assert service.scheduling.effective_limits(3) == (3, 2, 3)
        assert service.scheduling.same_program_parallel_allowlist() == {
            "program-a",
            "program-b",
        }
def test_measurement_source_setfile_uses_exact_sibling_rebind_lineage(
    tmp_path: Path,
) -> None:
    ea_dir = tmp_path / "QM5_41195_aa-vol-sma10-opt"
    selected = service._measurement_source_base_setfile(
        ea_dir,
        "QM5_41195_aa-vol-sma10-opt",
        "XAGUSD.DWX",
        "D1",
    )
    assert selected == (
        ea_dir
        / "sets"
        / "sibling_rebind_6b66b181_r2"
        / "QM5_41195_aa-vol-sma10-opt_XAGUSD.DWX_D1_backtest.set"
    )


def test_measurement_source_setfile_keeps_default_for_unrelated_sibling(
    tmp_path: Path,
) -> None:
    ea_dir = tmp_path / "QM5_41161_tv-mon-ls-opt"
    selected = service._measurement_source_base_setfile(
        ea_dir,
        "QM5_41161_tv-mon-ls-opt",
        "GBPUSD.DWX",
        "H1",
    )
    assert selected == (
        ea_dir
        / "sets"
        / "QM5_41161_tv-mon-ls-opt_GBPUSD.DWX_H1_backtest.set"
    )


def test_superseded_q02_hold_is_append_only_and_refuses_claimed_rows(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        now = "2026-08-30T12:00:00+00:00"
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('stale-q02','backtest','Q02','QM5_41195','XAGUSD.DWX',
                     'legacy.set','pending',NULL,0,'{}',?,?,'v4')
            """,
            (now, now),
        )
        row = conn.execute(
            "SELECT * FROM work_items WHERE id='stale-q02'"
        ).fetchone()
        service._hold_superseded_pending_q02(conn, row, apply=True)
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds "
            "WHERE work_item_id='stale-q02'"
        ).fetchone()
        assert tuple(hold) == (service.SUPERSEDED_Q02_HOLD_CODE, 1, 0)

        conn.execute(
            "UPDATE work_items SET claimed_by='T1' WHERE id='stale-q02'"
        )
        claimed = conn.execute(
            "SELECT * FROM work_items WHERE id='stale-q02'"
        ).fetchone()
        with pytest.raises(service.MatrixServiceError, match="not safely holdable"):
            service._hold_superseded_pending_q02(conn, claimed, apply=False)


def test_recovery_successor_preserves_declaration_and_not_source_verdict(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    files = _sibling(tmp_path / "repo")
    declaration = routing._pattern_candidate_declaration(
        parent={"ea_id": "QM5_10706", "symbol": "GBPUSD.DWX"},
        parent_bindings={
            "source": {"path": str(files["source"])},
            "setfile": {"path": str(files["setfile"])},
        },
    )
    payload = {
        "schema": routing.SCHEMA,
        "role": "PATTERN",
        "phase": "Q12",
        "routing_revision": routing.PATTERN_DECLARATION_REVISION,
        "execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
        "activation_state": "READY",
        "pattern_filter_sweep": declaration,
        "evidence_provenance": "real_mt5",
    }
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              evidence_path,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES('bad-pass','analytic','Q12','QM5_10706','GBPUSD.DWX',?,
                     'done','PASS',0,'bad-summary.json',?,? ,?,'v4')
            """,
            (str(files["setfile"]), json.dumps(payload, sort_keys=True),
             "2026-08-26T10:00:00+00:00", "2026-08-26T10:04:00+00:00"),
        )
        conn.commit()
    evidence = tmp_path / "owner_template.md"
    evidence.write_text("pending OWNER disposition\n", encoding="utf-8")

    with farmctl.connect(root) as conn:
        result = service.append_recovery_successor(
            conn,
            source_work_item_id="bad-pass",
            evidence_path=evidence,
            apply=True,
        )
        conn.commit()

    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        source = conn.execute("SELECT status,verdict,evidence_path FROM work_items WHERE id='bad-pass'").fetchone()
        successor = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (result["successor_work_item_id"],)
        ).fetchone()
    assert tuple(source) == ("done", "PASS", "bad-summary.json")
    assert (successor["status"], successor["verdict"]) == ("pending", None)
    successor_payload = json.loads(successor["payload_json"])
    assert successor_payload["pattern_filter_sweep"] == declaration
    assert successor_payload["matrix_runner"]["recovery_of_work_item_id"] == "bad-pass"


def test_rollout_hold_is_not_resurrected_after_restart_release(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    with farmctl.connect(root) as conn:
        now = farmctl.utc_now()
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              payload_json,created_at,updated_at
            ) VALUES('released-q12','analytic','Q12','QM5_10706','GBPUSD.DWX','x.set',
                     'pending',NULL,0,'{}',?,?)
            """,
            (now, now),
        )
        conn.execute(
            """
            INSERT INTO work_item_holds(
              work_item_id,hold_code,reason,active,release_on_restart,
              created_at,updated_at,released_at,release_note
            ) VALUES('released-q12',?,'guard loaded',0,1,?,?,?,'worker restart')
            """,
            (service.ROLLOUT_HOLD_CODE, now, now, now),
        )
        conn.commit()

        result = service._ensure_rollout_hold(conn, "released-q12", apply=True)
        conn.commit()

        hold = conn.execute(
            "SELECT active,released_at,release_note FROM work_item_holds "
            "WHERE work_item_id='released-q12'"
        ).fetchone()
    assert result["restart_release_preserved"] is True
    assert tuple(hold) == (0, now, "worker restart")


def test_q12_finalization_accepts_authenticated_exclusion_dispositions(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    program_dir = tmp_path / "program"
    program_dir.mkdir()
    ledger_path = program_dir / "ledger.json"
    ledger_path.write_text(
        json.dumps(
            {
                "driver": {
                    "state": service.selector.STATE_PATTERN_READY,
                    "wf": {"final_selection": {"BUY": [], "SELL": []}},
                }
            }
        ),
        encoding="utf-8",
    )
    measured = tmp_path / "measured.json"
    measured.write_text("{}\n", encoding="utf-8")
    skipped = tmp_path / "skipped.json"
    skipped.write_text("{}\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        for values in (
            (
                "q12-owner",
                "analytic",
                "Q12",
                "QM5_PARENT",
                "EURUSD.DWX",
                "pending",
                None,
                None,
                "{}",
            ),
            (
                "cell-measured",
                "backtest",
                "OPT_CENSUS",
                "QM5_OPT",
                "EURUSD.DWX",
                "done",
                "MEASURED",
                str(measured),
                json.dumps(
                    {"q12_work_item_id": "q12-owner", "cell_key": "cell:measured"}
                ),
            ),
            (
                "cell-skipped",
                "backtest",
                "OPT_CENSUS",
                "QM5_OPT",
                "EURUSD.DWX",
                "done",
                pruning.SKIPPED_VERDICT,
                str(skipped),
                json.dumps(
                    {"q12_work_item_id": "q12-owner", "cell_key": "cell:skipped"}
                ),
            ),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,
                  payload_json,created_at,updated_at
                ) VALUES(?,?,?,?,?,'x.set',?,?,?,?,?,?)
                """,
                (*values, now, now),
            )
        q12 = conn.execute(
            "SELECT * FROM work_items WHERE id='q12-owner'"
        ).fetchone()
        result = service._finalize_from_terminal_ledger(
            conn,
            q12_row=q12,
            ledger_path=ledger_path,
            program_dir=program_dir,
            apply=True,
        )
        conn.commit()
        q12_after = conn.execute(
            "SELECT status,verdict,evidence_path FROM work_items WHERE id='q12-owner'"
        ).fetchone()

    assert result["verdict"] == "NO_FILTER_CHANGE"
    assert tuple(q12_after) == (
        "done",
        "NO_FILTER_CHANGE",
        str((program_dir / "q12_selection_receipt.json").resolve()),
    )
    receipt = json.loads(Path(q12_after["evidence_path"]).read_text(encoding="utf-8"))
    assert {row["verdict"] for row in receipt["cell_evidence"]} == {
        "MEASURED",
        pruning.SKIPPED_VERDICT,
    }


def test_q12_finalization_accepts_ready_for_q15_terminal_state(
    tmp_path: Path,
) -> None:
    """READY_FOR_Q15 is a terminal pattern-selection state (EUR pilot 2026-09-02).

    The driver may advance past PATTERN_SELECTION_READY through numeric and
    full-window measuring; the pattern verdict is still determined solely by
    ``wf.final_selection`` and the Q12 owner row must be finalized.
    """

    root = tmp_path / "farm"
    farmctl.init_db(root)
    program_dir = tmp_path / "program"
    program_dir.mkdir()
    ledger_path = program_dir / "ledger.json"
    ledger_path.write_text(
        json.dumps(
            {
                "driver": {
                    "state": service.selector.STATE_READY,
                    "wf": {"final_selection": {"BUY": [], "SELL": []}},
                }
            }
        ),
        encoding="utf-8",
    )
    measured = tmp_path / "measured.json"
    measured.write_text("{}\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        for values in (
            ("q12-owner", "analytic", "Q12", "QM5_PARENT", "EURUSD.DWX", "pending", None, None, "{}"),
            (
                "cell-measured",
                "backtest",
                "OPT_CENSUS",
                "QM5_OPT",
                "EURUSD.DWX",
                "done",
                "MEASURED",
                str(measured),
                json.dumps({"q12_work_item_id": "q12-owner", "cell_key": "cell:measured"}),
            ),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,
                  payload_json,created_at,updated_at
                ) VALUES(?,?,?,?,?,'x.set',?,?,?,?,?,?)
                """,
                (*values, now, now),
            )
        q12 = conn.execute("SELECT * FROM work_items WHERE id='q12-owner'").fetchone()
        result = service._finalize_from_terminal_ledger(
            conn,
            q12_row=q12,
            ledger_path=ledger_path,
            program_dir=program_dir,
            apply=True,
        )
        conn.commit()
        q12_after = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id='q12-owner'"
        ).fetchone()

    assert result is not None
    assert result["verdict"] == "NO_FILTER_CHANGE"
    assert tuple(q12_after) == ("done", "NO_FILTER_CHANGE")
    receipt = json.loads((program_dir / "q12_selection_receipt.json").read_text(encoding="utf-8"))
    assert receipt["driver_state"] == service.selector.STATE_READY


def test_q12_finalization_ignores_intermediate_measuring_states(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    program_dir = tmp_path / "program"
    program_dir.mkdir()
    ledger_path = program_dir / "ledger.json"
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,
              payload_json,created_at,updated_at
            ) VALUES('q12-owner','analytic','Q12','QM5_PARENT','EURUSD.DWX','x.set','pending',NULL,NULL,'{}',?,?)
            """,
            (now, now),
        )
        q12 = conn.execute("SELECT * FROM work_items WHERE id='q12-owner'").fetchone()
        for state in (
            service.selector.STATE_ENQUEUED,
            service.selector.STATE_NUMERIC,
            service.selector.STATE_FINAL_FULLWINDOW,
            service.selector.STATE_WF_COMBO,
        ):
            ledger_path.write_text(
                json.dumps({"driver": {"state": state, "wf": {"final_selection": {"BUY": [], "SELL": []}}}}),
                encoding="utf-8",
            )
            assert (
                service._finalize_from_terminal_ledger(
                    conn, q12_row=q12, ledger_path=ledger_path, program_dir=program_dir, apply=True
                )
                is None
            ), state


def _program_binding_fixture(tmp_path: Path):
    repo = tmp_path / "repo"
    files = _sibling(repo)
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    artifact_root = tmp_path / "matrix_artifacts"
    _insert_fixture_rows(db, files, tmp_path, artifact_root)
    with farmctl.connect(root) as conn:
        first = service.service_pending(
            conn,
            db_path=db,
            repo_root=repo,
            artifact_root=artifact_root,
            apply=True,
            q12_work_item_ids=["q12-declared"],
        )
    assert first["materialized"], first
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        template = conn.execute(
            "SELECT * FROM work_items WHERE upper(phase)='OPT_CENSUS' "
            "ORDER BY created_at,id LIMIT 1"
        ).fetchone()
    return root, db, artifact_root, dict(template)


def _insert_program_row(db: Path, template: dict, *, row_id: str, payload_mutator) -> None:
    payload = json.loads(template["payload_json"])
    payload_mutator(payload)
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,payload_json,created_at,updated_at,gate_contract_version
            ) VALUES(?,?,?,?,?,?,'pending',NULL,0,NULL,?,?,?,'v4')
            """,
            (
                row_id,
                template["kind"],
                template["phase"],
                template["ea_id"],
                template["symbol"],
                template["setfile_path"],
                json.dumps(payload, sort_keys=True),
                "2026-09-02T11:23:00+00:00",
                "2026-09-02T11:23:00+00:00",
            ),
        )
        conn.commit()


def _guard(root: Path, artifact_root: Path, q12_id: str = "q12-declared"):
    with farmctl.connect(root) as conn:
        q12_row = conn.execute("SELECT * FROM work_items WHERE id=?", (q12_id,)).fetchone()
        return service._program_binding_guard(conn, q12_row=q12_row, artifact_root=artifact_root)


def test_binding_guard_admits_driver_derived_rows_and_reruns(tmp_path: Path) -> None:
    """2026-09-03 regression: WF-combo/numeric rows and driver INFRA_FAIL reruns
    share the program id but never transfer ownership; the guard must not
    freeze a program at PATTERN_SELECTION_READY (live case QM5_13054/XTIUSD)."""
    root, db, artifact_root, template = _program_binding_fixture(tmp_path)
    program_id = json.loads(template["payload_json"])["program_id"]
    baseline = _guard(root, artifact_root)
    assert baseline["declared_cell_count"] == 1085
    assert baseline["requires_restamp"] is False

    def wf_combo(payload):
        payload["cell_key"] = f"{program_id}:wf1:combo:2022"
        payload["arm"] = "wf1_combo"
        payload.pop("q12_work_item_id", None)
        payload.pop("q12_declaration_sha256", None)

    def numeric(payload):
        payload["cell_key"] = f"{program_id}:numeric:baseline:2019"
        payload["arm"] = "baseline"

    def rerun(payload):
        payload["append_only_rerun_of"] = template["id"]
        payload["rerun_attempt"] = 1

    _insert_program_row(db, template, row_id="wf1-combo-2022", payload_mutator=wf_combo)
    _insert_program_row(db, template, row_id="numeric-baseline-2019", payload_mutator=numeric)
    _insert_program_row(db, template, row_id="rerun-of-declared", payload_mutator=rerun)
    binding = _guard(root, artifact_root)
    assert binding["cell_count"] == 1088
    assert binding["declared_cell_count"] == 1085
    assert binding["rerun_row_count"] == 1
    assert binding["derived_row_count"] == 2
    assert binding["requires_restamp"] is False


def test_binding_guard_still_refuses_foreign_or_unexplained_rows(tmp_path: Path) -> None:
    root, db, artifact_root, template = _program_binding_fixture(tmp_path)
    program_id = json.loads(template["payload_json"])["program_id"]

    def foreign_numeric(payload):
        payload["cell_key"] = f"{program_id}:numeric:baseline:2020"
        payload["q12_work_item_id"] = "q12-ablation-shadow"

    _insert_program_row(db, template, row_id="numeric-foreign", payload_mutator=foreign_numeric)
    with pytest.raises(service.MatrixServiceError, match="PROGRAM_Q12_REBIND_REFUSED"):
        _guard(root, artifact_root)
    with sqlite3.connect(db) as conn:
        conn.execute("DELETE FROM work_items WHERE id='numeric-foreign'")
        conn.commit()

    def duplicate_without_lineage(payload):
        payload.pop("append_only_rerun_of", None)

    _insert_program_row(
        db, template, row_id="duplicate-no-lineage", payload_mutator=duplicate_without_lineage
    )
    with pytest.raises(service.MatrixServiceError, match="PROGRAM_CELL_IDENTITY_MISMATCH"):
        _guard(root, artifact_root)


def test_finalize_commits_before_the_next_program_takes_its_own_write_lock(
    tmp_path: Path,
) -> None:
    """2026-09-03: the Q12 completion must be durable (and its RESERVED lock
    released) before the service moves on - the next program's ``boost`` opens a
    separate ``BEGIN IMMEDIATE`` connection and otherwise self-deadlocks."""
    root, db, artifact_root, template = _program_binding_fixture(tmp_path)
    program_id = json.loads(template["payload_json"])["program_id"]
    program_dir = artifact_root / program_id
    ledger_path = program_dir / "ledger.json"
    now = "2026-09-03T00:00:00+00:00"
    with sqlite3.connect(db) as conn:
        # Resolve every declared cell with sealed evidence on disk.
        rows = conn.execute(
            "SELECT id FROM work_items WHERE upper(phase)='OPT_CENSUS'"
        ).fetchall()
        evidence_dir = tmp_path / "evidence"
        evidence_dir.mkdir()
        for (row_id,) in rows:
            evidence = evidence_dir / f"{row_id}.json"
            evidence.write_text("{}\n", encoding="utf-8")
            conn.execute(
                "UPDATE work_items SET status='done',verdict=?,evidence_path=?,updated_at=? WHERE id=?",
                (pruning.SKIPPED_VERDICT, str(evidence), now, row_id),
            )
        conn.commit()
    ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    ledger["driver"] = {
        "schema": "qm.opt-census-driver.v1",
        "state": service.selector.STATE_PATTERN_READY,
        "wf": {"final_selection": {"selected": []}, "stability": {}},
        "transitions": [],
    }
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with farmctl.connect(root) as conn:
        q12_row = conn.execute("SELECT * FROM work_items WHERE id='q12-declared'").fetchone()
        finalized = service._finalize_from_terminal_ledger(
            conn,
            q12_row=q12_row,
            ledger_path=ledger_path,
            program_dir=program_dir,
            apply=True,
        )
        assert finalized is not None and finalized["applied"] is True
        # A SEPARATE connection must already see the completion and must be able
        # to take the write lock immediately (no lingering RESERVED lock).
        other = sqlite3.connect(db, timeout=0.2)
        try:
            assert other.execute(
                "SELECT status,verdict FROM work_items WHERE id='q12-declared'"
            ).fetchone() == ("done", finalized["verdict"])
            other.execute("BEGIN IMMEDIATE")
            other.rollback()
        finally:
            other.close()
    assert (program_dir / "q12_selection_receipt.json").is_file()


def test_q12_finalization_resolves_driver_reruns_to_the_current_cell_row(
    tmp_path: Path,
) -> None:
    """2026-09-03: a declared cell that INFRA-failed and was re-enqueued by the
    driver (append-only reruns, newest last) must be judged on its CURRENT
    rerun row; the dead declared row and superseded reruns are receipt
    evidence, not blockers (QM5_1537/XAGUSD stayed pending at
    PATTERN_SELECTION_READY)."""

    root = tmp_path / "farm"
    farmctl.init_db(root)
    program_dir = tmp_path / "program"
    program_dir.mkdir()
    ledger_path = program_dir / "ledger.json"
    ledger_path.write_text(
        json.dumps(
            {
                "driver": {
                    "state": service.selector.STATE_PATTERN_READY,
                    "wf": {"final_selection": {"BUY": ["buy_001"], "SELL": []}},
                    "reruns": {"P:2021:buy_048": ["rerun-1", "rerun-2"]},
                }
            }
        ),
        encoding="utf-8",
    )
    measured = tmp_path / "measured.json"
    measured.write_text("{}\n", encoding="utf-8")
    now = farmctl.utc_now()
    common = {"q12_work_item_id": "q12-owner"}
    with farmctl.connect(root) as conn:
        for values in (
            ("q12-owner", "analytic", "Q12", "QM5_PARENT", "XAGUSD.DWX", "pending", None, None, "{}"),
            ("cell-ok", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "done", "MEASURED", str(measured),
             json.dumps({**common, "cell_key": "P:2020:buy_001"})),
            ("declared-dead", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "done", "INFRA_FAIL", "EVIDENCE_UNAVAILABLE:test",
             json.dumps({**common, "cell_key": "P:2021:buy_048"})),
            ("rerun-1", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "failed", "INFRA_FAIL", "EVIDENCE_UNAVAILABLE:test",
             json.dumps({**common, "cell_key": "P:2021:buy_048", "append_only_rerun_of": "declared-dead"})),
            ("rerun-2", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "done", "MEASURED", str(measured),
             json.dumps({**common, "cell_key": "P:2021:buy_048", "append_only_rerun_of": "declared-dead"})),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,
                  payload_json,created_at,updated_at
                ) VALUES(?,?,?,?,?,'x.set',?,?,?,?,?,?)
                """,
                (*values, now, now),
            )
        q12 = conn.execute("SELECT * FROM work_items WHERE id='q12-owner'").fetchone()
        result = service._finalize_from_terminal_ledger(
            conn, q12_row=q12, ledger_path=ledger_path, program_dir=program_dir, apply=True,
        )
        conn.commit()
        q12_after = conn.execute("SELECT status,verdict FROM work_items WHERE id='q12-owner'").fetchone()

    assert result is not None
    assert result["verdict"] == "OPT_ELIGIBLE"
    assert tuple(q12_after) == ("done", "OPT_ELIGIBLE")
    receipt = json.loads((program_dir / "q12_selection_receipt.json").read_text(encoding="utf-8"))
    assert {row["work_item_id"] for row in receipt["cell_evidence"]} == {"cell-ok", "rerun-2"}
    assert {row["work_item_id"] for row in receipt["superseded_cell_evidence"]} == {"declared-dead", "rerun-1"}
    assert all(row["superseded_by"] == "rerun-2" for row in receipt["superseded_cell_evidence"])


def test_q12_finalization_still_waits_while_the_current_rerun_is_open(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    program_dir = tmp_path / "program"
    program_dir.mkdir()
    ledger_path = program_dir / "ledger.json"
    ledger_path.write_text(
        json.dumps({"driver": {"state": service.selector.STATE_PATTERN_READY,
                               "wf": {"final_selection": {"BUY": [], "SELL": []}},
                               "reruns": {"P:2021:buy_048": ["rerun-1"]}}}),
        encoding="utf-8",
    )
    now = farmctl.utc_now()
    common = {"q12_work_item_id": "q12-owner"}
    with farmctl.connect(root) as conn:
        for values in (
            ("q12-owner", "analytic", "Q12", "QM5_PARENT", "XAGUSD.DWX", "pending", None, None, "{}"),
            ("declared-dead", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "done", "INFRA_FAIL", "EVIDENCE_UNAVAILABLE:test",
             json.dumps({**common, "cell_key": "P:2021:buy_048"})),
            ("rerun-1", "backtest", "OPT_CENSUS", "QM5_OPT", "XAGUSD.DWX", "pending", None, None,
             json.dumps({**common, "cell_key": "P:2021:buy_048", "append_only_rerun_of": "declared-dead"})),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,
                  payload_json,created_at,updated_at
                ) VALUES(?,?,?,?,?,'x.set',?,?,?,?,?,?)
                """,
                (*values, now, now),
            )
        q12 = conn.execute("SELECT * FROM work_items WHERE id='q12-owner'").fetchone()
        result = service._finalize_from_terminal_ledger(
            conn, q12_row=q12, ledger_path=ledger_path, program_dir=program_dir, apply=True,
        )
    assert result is None
