from __future__ import annotations

import csv
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Callable

import pytest

from tools.strategy_farm import agent_router, farmctl


EA_ID = "QM5_9001"
EA_SLUG = "fixture"
COMPILE_ID = "compile-fixture"


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _fixture(tmp_path: Path) -> dict[str, object]:
    root = tmp_path / "farm"
    repo = tmp_path / "repo"
    farmctl.init_db(root)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.row_factory = sqlite3.Row
        agent_router.init_schema(conn)

    ea_dir = repo / "framework" / "EAs" / f"{EA_ID}_{EA_SLUG}"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    ex5.write_bytes(b"fixture-ex5\n")
    ex5_sha = hashlib.sha256(ex5.read_bytes()).hexdigest()
    setfiles: dict[str, Path] = {}
    for symbol in ("EURUSD.DWX", "GBPUSD.DWX"):
        path = sets_dir / f"{ea_dir.name}_{symbol}_H1_backtest.set"
        path.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        setfiles[symbol] = path

    registry_dir = repo / "framework" / "registry"
    _write_csv(
        registry_dir / "ea_id_registry.csv",
        ["ea_id", "slug", "status"],
        [{"ea_id": "9001", "slug": EA_SLUG, "status": "active"}],
    )
    _write_csv(
        registry_dir / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "status"],
        [
            {
                "ea_id": "9001", "ea_slug": EA_SLUG, "symbol_slot": index,
                "symbol": symbol, "magic": 90010000 + index, "status": "active",
            }
            for index, symbol in enumerate(("EURUSD.DWX", "GBPUSD.DWX"))
        ],
    )
    _write_csv(
        registry_dir / "dwx_symbol_matrix.csv",
        ["symbol", "canonical_name_verified"],
        [
            {"symbol": symbol, "canonical_name_verified": "true"}
            for symbol in ("EURUSD.DWX", "GBPUSD.DWX")
        ],
    )

    evidence_path = tmp_path / "compile_evidence.json"
    evidence = {
        "schema_version": "qm.compile-ea-evidence/v1",
        "work_item_id": COMPILE_ID,
        "ea_id": EA_ID,
        "phase": "COMPILE_EA",
        "success": True,
        "compile_result": "PASS",
        "build_check_result": "PASS",
        "ex5_sha256": ex5_sha,
        "candidate_recheck": {
            "eligible": True,
            "reason": "ELIGIBLE",
            "symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        },
    }
    evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
    payload = {
        "symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "PASS",
            "ex5_sha256": ex5_sha,
        },
    }
    now = "2026-09-06T00:00:00+00:00"
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.create_function(
            "qm_router_writer_generation",
            0,
            lambda: agent_router.ROUTER_WRITER_GENERATION,
        )
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "evidence_path,payload_json,created_at,updated_at,ex5_sha256) VALUES "
            "(?,'compile','COMPILE_EA',?,'','','done','COMPILE_OK',1,?,?,?,?,?)",
            (COMPILE_ID, EA_ID, str(evidence_path), json.dumps(payload), now, now, ex5_sha),
        )
        conn.execute(
            "INSERT INTO agent_tasks "
            "(id,task_type,state,priority,required_capabilities_json,required_skills_json,"
            "payload_json,created_at,updated_at) VALUES "
            "('review-fixture','review_ea','PASSED',50,'[]','[]',?,?,?)",
            (json.dumps({"ea_id": EA_ID}), now, now),
        )
        conn.commit()
    return {
        "root": root,
        "repo": repo,
        "ea_dir": ea_dir,
        "ex5": ex5,
        "setfiles": setfiles,
        "evidence_path": evidence_path,
        "evidence": evidence,
    }


def _plan(fixture: dict[str, object], compile_id: str = COMPILE_ID) -> dict[str, object]:
    return farmctl.intake_first_q02(
        fixture["root"],  # type: ignore[arg-type]
        compile_id,
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )


def _db_execute(fixture: dict[str, object], sql: str, params: tuple[object, ...] = ()) -> None:
    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        conn.create_function(
            "qm_router_writer_generation",
            0,
            lambda: agent_router.ROUTER_WRITER_GENERATION,
        )
        conn.execute(sql, params)
        conn.commit()


def test_dry_run_is_eligible_and_has_no_mutation(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = _plan(fixture)

    assert result["eligible"] is True
    assert result["would_enqueue"] is True
    assert result["dry_run"] is True
    assert result["priority_boost"] is False
    assert result["canary"]["symbol"] == "EURUSD.DWX"  # type: ignore[index]
    assert [row["symbol"] for row in result["deferred"]] == ["GBPUSD.DWX"]  # type: ignore[index]
    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        assert conn.execute("SELECT COUNT(*) FROM work_items WHERE phase='Q02'").fetchone()[0] == 0
    assert not (root / "artifacts" / "receipts" / "first_q02_intake").exists()  # type: ignore[operator]


def test_apply_appends_one_unboosted_canary_deferral_and_receipt(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = farmctl.intake_first_q02(
        fixture["root"],  # type: ignore[arg-type]
        COMPILE_ID,
        apply=True,
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )

    assert result["applied"] is True
    assert result["priority_boost"] is False
    receipt_path = Path(result["receipt_path"])
    assert receipt_path.is_file()
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert receipt["schema"] == farmctl.FIRST_Q02_INTAKE_RECEIPT_SCHEMA
    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        rows = conn.execute(
            "SELECT symbol,payload_json FROM work_items WHERE phase='Q02'"
        ).fetchall()
    assert len(rows) == 1
    assert rows[0][0] == "EURUSD.DWX"
    payload = json.loads(rows[0][1])
    assert payload["risk_fixed"] == 1000
    assert payload["risk_percent"] == 0
    assert "priority_track" not in payload
    deferred = json.loads(
        (root / "state" / "q02_deferred_symbols.json").read_text(encoding="utf-8")  # type: ignore[operator]
    )
    assert [row["symbol"] for row in deferred[EA_ID]["setfiles"]] == ["GBPUSD.DWX"]
    second = _plan(fixture)
    assert second["reason"] == "existing_q02_row"


def _bad_row_contract(fixture: dict[str, object]) -> None:
    _db_execute(fixture, "UPDATE work_items SET status='failed' WHERE id=?", (COMPILE_ID,))


def _bad_payload(fixture: dict[str, object]) -> None:
    _db_execute(fixture, "UPDATE work_items SET payload_json='{' WHERE id=?", (COMPILE_ID,))


def _missing_evidence(fixture: dict[str, object]) -> None:
    Path(fixture["evidence_path"]).unlink()


def _invalid_evidence(fixture: dict[str, object]) -> None:
    Path(fixture["evidence_path"]).write_text("{", encoding="utf-8")


def _failed_evidence(fixture: dict[str, object]) -> None:
    evidence = dict(fixture["evidence"])
    evidence["success"] = False
    Path(fixture["evidence_path"]).write_text(json.dumps(evidence), encoding="utf-8")


def _failed_candidate_recheck(fixture: dict[str, object]) -> None:
    evidence = dict(fixture["evidence"])
    evidence["candidate_recheck"] = {"eligible": False, "reason": "FIXTURE_BLOCK"}
    Path(fixture["evidence_path"]).write_text(json.dumps(evidence), encoding="utf-8")


def _retired_identity(fixture: dict[str, object]) -> None:
    repo = Path(fixture["repo"])
    _write_csv(
        repo / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "status"],
        [{"ea_id": "9001", "slug": EA_SLUG, "status": "retired"}],
    )


def _missing_ex5(fixture: dict[str, object]) -> None:
    Path(fixture["ex5"]).unlink()


def _changed_ex5(fixture: dict[str, object]) -> None:
    Path(fixture["ex5"]).write_bytes(b"changed\n")


def _bad_risk(fixture: dict[str, object]) -> None:
    Path(fixture["setfiles"]["EURUSD.DWX"]).write_text(  # type: ignore[index]
        "RISK_FIXED=0\nRISK_PERCENT=1\n", encoding="utf-8"
    )


def _missing_matrix_symbol(fixture: dict[str, object]) -> None:
    repo = Path(fixture["repo"])
    _write_csv(
        repo / "framework" / "registry" / "dwx_symbol_matrix.csv",
        ["symbol", "canonical_name_verified"],
        [{"symbol": "EURUSD.DWX", "canonical_name_verified": "true"}],
    )


def _bad_magic(fixture: dict[str, object]) -> None:
    repo = Path(fixture["repo"])
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "status"],
        [{
            "ea_id": "9001", "ea_slug": EA_SLUG, "symbol_slot": 0,
            "symbol": "EURUSD.DWX", "magic": 90010000, "status": "active",
        }],
    )


def _review_blocked(fixture: dict[str, object]) -> None:
    _db_execute(fixture, "UPDATE agent_tasks SET state='FAILED' WHERE id='review-fixture'")


def _existing_q02(fixture: dict[str, object]) -> None:
    now = "2026-09-06T00:00:00+00:00"
    _db_execute(
        fixture,
        "INSERT INTO work_items "
        "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,"
        "created_at,updated_at) VALUES "
        "('existing','backtest','Q02',?,'EURUSD.DWX','fixture.set','pending',0,'{}',?,?)",
        (EA_ID, now, now),
    )


@pytest.mark.parametrize(
    ("mutator", "reason"),
    [
        (_bad_row_contract, "compile_work_item_not_done_compile_ok"),
        (_bad_payload, "compile_payload_invalid"),
        (_missing_evidence, "compile_evidence_missing"),
        (_invalid_evidence, "compile_evidence_invalid"),
        (_failed_evidence, "compile_evidence_not_pass_bound"),
        (_failed_candidate_recheck, "compile_candidate_recheck_not_eligible"),
        (_retired_identity, "ea_registry_identity_not_exactly_one_active"),
        (_missing_ex5, "canonical_ex5_not_exactly_one"),
        (_changed_ex5, "compile_ex5_sha256_mismatch"),
        (_bad_risk, "canonical_setfile_risk_contract_invalid"),
        (_missing_matrix_symbol, "compile_symbols_not_in_dwx_matrix"),
        (_bad_magic, "active_magic_registry_contract_invalid"),
        (_review_blocked, "review_entry_gate_blocked"),
        (_existing_q02, "existing_q02_row"),
    ],
)
def test_refusal_branches_are_explicit_and_nonmutating(
    tmp_path: Path,
    mutator: Callable[[dict[str, object]], None],
    reason: str,
) -> None:
    fixture = _fixture(tmp_path)
    mutator(fixture)
    result = _plan(fixture)
    assert result["eligible"] is False
    assert result["would_enqueue"] is False
    assert result["reason"] == reason
    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        q02 = conn.execute("SELECT COUNT(*) FROM work_items WHERE phase='Q02'").fetchone()[0]
    assert q02 == (1 if reason == "existing_q02_row" else 0)


def test_missing_compile_id_is_explicit(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = _plan(fixture, "not-present")
    assert result["reason"] == "compile_work_item_not_found"


def test_archive_admission_failure_is_explicit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path)
    monkeypatch.setattr(
        farmctl,
        "custom_history_archive_admission",
        lambda *args, **kwargs: {"ok": False, "reason": "FIXTURE_ARCHIVE_BLOCK"},
    )
    result = _plan(fixture)
    assert result["reason"] == "custom_history_archive_admission_failed"
