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
        # Default rollback is one executable arm frontier per program. The
        # historical eight-row rolling window remains available only to direct
        # legacy boost callers.
        assert flagged == 1
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds "
            "WHERE work_item_id='q12-declared'"
        ).fetchone()
        assert tuple(hold) == (service.ROLLOUT_HOLD_CODE, 1, 1)


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
