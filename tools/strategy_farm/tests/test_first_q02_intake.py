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
        path.write_text(
            "RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_fixture_period=20\n",
            encoding="utf-8",
        )
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


def test_signal_only_manifest_matches_compile_execution_symbols(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    ea_dir = Path(fixture["ea_dir"])
    logical_symbol = "QM5_9001_EURUSD_GBPUSD_SIGNAL_BASKET_H1"
    manifest = {
        "logical_symbol": logical_symbol,
        "host_symbol": "EURUSD.DWX",
        "host_timeframe": "H1",
        "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        "execution_symbols": ["EURUSD.DWX"],
        "signal_only_symbols": ["GBPUSD.DWX"],
    }
    (ea_dir / "basket_manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    source_setfile = Path(fixture["setfiles"]["EURUSD.DWX"])  # type: ignore[index]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical_symbol}_H1_backtest.set"
    logical_setfile.write_bytes(source_setfile.read_bytes())

    evidence_path = Path(fixture["evidence_path"])
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    evidence["candidate_recheck"]["symbols"] = ["EURUSD.DWX"]
    evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
    repo = Path(fixture["repo"])
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "status"],
        [{
            "ea_id": "9001", "ea_slug": EA_SLUG, "symbol_slot": 0,
            "symbol": "EURUSD.DWX", "magic": 90010000, "status": "active",
        }],
    )
    with sqlite3.connect(Path(fixture["root"]) / farmctl.DB_REL) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps({
                "symbols": ["EURUSD.DWX"],
                "compile_result": {
                    "compile_result": "PASS",
                    "build_check_result": "PASS",
                    "ex5_sha256": hashlib.sha256(Path(fixture["ex5"]).read_bytes()).hexdigest(),
                },
            }), COMPILE_ID),
        )
        conn.commit()

    result = _plan(fixture)

    assert result["eligible"] is True
    assert result["would_enqueue"] is True
    assert result["target_symbols"] == ["EURUSD.DWX"]
    assert result["canary"]["symbol"] == logical_symbol  # type: ignore[index]
    assert result["deferred"] == []


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


def test_governed_backup_forces_fresh_across_tool_classes_after_dml(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    root = fixture["root"]
    first_path, first_sha = farmctl._governed_state_backup(root, "hold_release")
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        conn.execute(
            "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
            "VALUES('2026-09-06','fixture','one','mutation','{}')"
        )
        conn.commit()
    second_path, second_sha = farmctl._governed_state_backup(root, "first_q02_intake")
    assert second_path != first_path
    assert second_sha != first_sha
    assert len(list((root / "state" / "backups").glob("*.sqlite"))) == 2  # type: ignore[operator]


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


def _empty_strategy_params(fixture: dict[str, object]) -> None:
    Path(fixture["setfiles"]["EURUSD.DWX"]).write_text(  # type: ignore[index]
        "RISK_FIXED=1000\nRISK_PERCENT=0\n"
        "; strategy-specific params from card must be appended below this line\n"
        "; card_defaults_source=not_found\n",
        encoding="utf-8",
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
        (_empty_strategy_params, "empty_strategy_params"),
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


# --- intake-first-q02 --supersede-pending-canary ---------------------------

EXCLUSIVE_RAM_GB = 44.0
CHEAP_RAM_GB = 8.0


def _set_ram_gb(
    monkeypatch: pytest.MonkeyPatch, by_symbol: dict[str, float],
) -> None:
    def fake(symbol: str, ea_id: str = "") -> float:
        return by_symbol[str(symbol).upper()]

    monkeypatch.setattr(farmctl, "_q02_canary_ram_reservation_gb", fake)


def _insert_existing_q02(
    fixture: dict[str, object],
    *,
    work_item_id: str = "existing",
    symbol: str = "EURUSD.DWX",
    status: str = "pending",
    claimed_by: str | None = None,
    verdict: str | None = None,
) -> None:
    now = "2026-09-06T00:00:00+00:00"
    evidence_path = (
        f"{farmctl.EVIDENCE_UNAVAILABLE_PREFIX}fixture" if verdict else None
    )
    _db_execute(
        fixture,
        "INSERT INTO work_items "
        "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,claimed_by,"
        "evidence_path,attempt_count,payload_json,created_at,updated_at) VALUES "
        "(?,'backtest','Q02',?,?,'fixture.set',?,?,?,?,0,'{}',?,?)",
        (work_item_id, EA_ID, symbol, status, verdict, claimed_by, evidence_path, now, now),
    )


def _supersede(
    fixture: dict[str, object], *, apply: bool = False,
) -> dict[str, object]:
    return farmctl.intake_first_q02_supersede_pending_canary(
        fixture["root"],  # type: ignore[arg-type]
        COMPILE_ID,
        apply=apply,
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )


def _q02_rows(fixture: dict[str, object]) -> list[sqlite3.Row]:
    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        conn.row_factory = sqlite3.Row
        return conn.execute(
            "SELECT * FROM work_items WHERE phase='Q02' ORDER BY created_at,id"
        ).fetchall()


def test_supersede_dry_run_eligible_with_cheaper_replan(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path)
    _insert_existing_q02(fixture, symbol="EURUSD.DWX")
    _set_ram_gb(monkeypatch, {"EURUSD.DWX": EXCLUSIVE_RAM_GB, "GBPUSD.DWX": CHEAP_RAM_GB})

    result = _supersede(fixture)

    assert result["eligible"] is True
    assert result["would_enqueue"] is True
    assert result["applied"] is False
    assert result["dry_run"] is True
    assert result["canary"]["symbol"] == "GBPUSD.DWX"  # type: ignore[index]
    predecessors = result["predecessors"]  # type: ignore[index]
    assert len(predecessors) == 1
    assert predecessors[0]["work_item_id"] == "existing"
    assert predecessors[0]["supersede_eligible"] is True
    assert len(_q02_rows(fixture)) == 1  # unchanged: only the predecessor exists


def test_supersede_apply_parks_predecessor_and_appends_successor(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path)
    _insert_existing_q02(fixture, symbol="EURUSD.DWX")
    _set_ram_gb(monkeypatch, {"EURUSD.DWX": EXCLUSIVE_RAM_GB, "GBPUSD.DWX": CHEAP_RAM_GB})

    result = _supersede(fixture, apply=True)

    assert result["applied"] is True
    assert result["dry_run"] is False
    successor_id = result["work_item_id"]
    receipt_path = Path(result["receipt_path"])  # type: ignore[arg-type]
    assert receipt_path.is_file()
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert receipt["schema"] == farmctl.FIRST_Q02_SUPERSEDE_RECEIPT_SCHEMA
    assert receipt["hold_code"] == farmctl.Q02_SUPERSEDED_CANARY_RAM_CLASS_HOLD_CODE

    rows = _q02_rows(fixture)
    assert len(rows) == 2
    predecessor = next(row for row in rows if row["id"] == "existing")
    successor = next(row for row in rows if row["id"] == successor_id)
    # Append-only: the predecessor row itself is never touched.
    assert predecessor["status"] == "pending"
    assert predecessor["verdict"] is None
    assert successor["symbol"] == "GBPUSD.DWX"
    assert successor["status"] == "pending"

    root = fixture["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:  # type: ignore[operator]
        conn.row_factory = sqlite3.Row
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id='existing'"
        ).fetchone()
        supersedes = conn.execute(
            "SELECT * FROM work_item_supersedes WHERE work_item_id='existing'"
        ).fetchone()
    assert hold is not None
    assert hold["hold_code"] == farmctl.Q02_SUPERSEDED_CANARY_RAM_CLASS_HOLD_CODE
    assert hold["active"] == 1
    assert supersedes is not None
    assert supersedes["superseded_by_work_item_id"] == successor_id

    # A plain (non-supersede) intake attempt still sees both rows and refuses.
    plain = _plan(fixture)
    assert plain["reason"] == "existing_q02_row"


def test_supersede_refuses_when_replan_is_also_exclusive_class(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path)
    _insert_existing_q02(fixture, symbol="EURUSD.DWX")
    _set_ram_gb(monkeypatch, {"EURUSD.DWX": EXCLUSIVE_RAM_GB, "GBPUSD.DWX": EXCLUSIVE_RAM_GB})

    result = _supersede(fixture, apply=True)

    assert result["eligible"] is False
    assert result["applied"] is False
    assert result["reason"] == "replan_canary_also_exclusive_class"
    assert len(_q02_rows(fixture)) == 1  # no successor, no mutation


@pytest.mark.parametrize(
    ("kwargs",),
    [
        ({"claimed_by": "worker-1"},),
        ({"verdict": "INFRA_FAIL", "status": "failed"},),
    ],
)
def test_supersede_refuses_when_predecessor_not_fresh_pending(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, kwargs: dict[str, object],
) -> None:
    fixture = _fixture(tmp_path)
    _insert_existing_q02(fixture, symbol="EURUSD.DWX", **kwargs)  # type: ignore[arg-type]
    _set_ram_gb(monkeypatch, {"EURUSD.DWX": EXCLUSIVE_RAM_GB, "GBPUSD.DWX": CHEAP_RAM_GB})

    result = _supersede(fixture, apply=True)

    assert result["eligible"] is False
    assert result["applied"] is False
    assert result["reason"] == "existing_q02_row_not_supersede_eligible"
    assert len(_q02_rows(fixture)) == 1


def test_supersede_refuses_when_predecessor_below_exclusive_threshold(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixture = _fixture(tmp_path)
    _insert_existing_q02(fixture, symbol="EURUSD.DWX")
    _set_ram_gb(monkeypatch, {"EURUSD.DWX": CHEAP_RAM_GB, "GBPUSD.DWX": CHEAP_RAM_GB})

    result = _supersede(fixture, apply=True)

    assert result["eligible"] is False
    assert result["reason"] == "existing_q02_row_not_supersede_eligible"
    assert result["predecessors"][0]["supersede_eligible"] is False  # type: ignore[index]


def test_supersede_passes_through_when_nothing_to_supersede(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = _supersede(fixture)

    assert result["reason"] == "ELIGIBLE"
    assert result["eligible"] is True
    assert result["applied"] is False
    assert result["supersede_pending_canary"] is True


def test_supersede_passes_through_unrelated_refusal(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = farmctl.intake_first_q02_supersede_pending_canary(
        fixture["root"],  # type: ignore[arg-type]
        "not-present",
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )

    assert result["reason"] == "compile_work_item_not_found"
    assert result["eligible"] is False
    assert result["applied"] is False
