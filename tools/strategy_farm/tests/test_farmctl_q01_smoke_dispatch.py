"""Tests for ``farmctl.append_q01_smoke_work_item`` (ops_issue task 7267e593).

Generalizes ``q01_basket_smoke_recovery.py`` (hard-scoped to a literal
``TARGETS`` tuple of three basket EAs) into a bounded, EA-agnostic route that
appends exactly one governed ``q01_smoke`` work item for a build that went
through the newer ``agent_tasks`` capability-router pipeline instead of the
legacy ``tasks``/``ea_review`` pipeline ``q01_basket_smoke_recovery.py`` and
``record_q01_smoke_successor`` assume.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.strategy_farm import farmctl
from tools.strategy_farm.setfile_build_hash import (
    PENDING_BUILD_HASH_LINE,
    authenticate_setfile_build_hash_transition,
)

EA_ID = "QM5_90001"
SYMBOL = "EURUSD.DWX"
BUILD_TASK_ID = "9a1b2c3d-0000-4000-8000-000000000001"


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _generated_setfile_bytes(*, risk_fixed: str = "1000") -> bytes:
    lines = [
        ";==========================================================",
        "; QM5 Set File",
        "; ea_id:        90001",
        "; ea_slug:      synthetic-smoke-dispatch",
        "; ea_version:   v5.0",
        "; set_version:  v1",
        f"; symbol:       {SYMBOL}",
        "; timeframe:    H1",
        "; environment:  backtest",
        "; magic_slot:   0",
        "; risk_mode:    FIXED",
        "; portfolio_weight: 1",
        PENDING_BUILD_HASH_LINE,
        "; author:       Development",
        "; date:         2026-09-22",
        ";==========================================================",
        "qm_ea_id=90001",
        "qm_magic_slot_offset=0",
        f"RISK_FIXED={risk_fixed}",
        "RISK_PERCENT=0",
        "PORTFOLIO_WEIGHT=1",
        "strategy_period=14",
    ]
    return ("\n".join(lines) + "\n").encode("utf-8")


def _build_check_stamp(generated: bytes) -> bytes:
    lines = generated.decode("utf-8").splitlines()
    normalized = ("\r\n".join(lines) + "\r\n").encode("utf-8")
    stamp = _sha_bytes(normalized)
    lines[lines.index(PENDING_BUILD_HASH_LINE)] = f"; build_hash:   {stamp}"
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def _authenticated_ex5_restamp(generated: bytes, ex5_sha256: str) -> bytes:
    lines = generated.decode("utf-8").splitlines()
    lines[lines.index(PENDING_BUILD_HASH_LINE)] = (
        f"; build_hash:   {ex5_sha256}"
    )
    return ("\n".join(lines) + "\n").encode("utf-8")


def _seed(
    tmp_path: Path,
    *,
    build_state: str = "TODO",
    artifact_path_override: str | None = None,
    final_lifecycle_evidence: bool = False,
    authenticated_ex5_restamp: bool = False,
):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()

    ea_dir = tmp_path / "repo" / "framework" / "EAs" / f"{EA_ID}_synthetic-smoke-dispatch"
    (ea_dir / "sets").mkdir(parents=True, exist_ok=True)
    mq5 = ea_dir / f"{EA_ID}_synthetic-smoke-dispatch.mq5"
    ex5 = ea_dir / f"{EA_ID}_synthetic-smoke-dispatch.ex5"
    setf = ea_dir / "sets" / f"{EA_ID}_synthetic-smoke-dispatch_{SYMBOL}_H1_backtest.set"
    mq5.write_bytes(b"// mq5 source bytes\n")
    ex5.write_bytes(b"\x00EX5-COMPILED-BYTES\x01")
    generated_setfile = _generated_setfile_bytes()
    build_check_setfile = _build_check_stamp(generated_setfile)
    final_setfile = (
        _authenticated_ex5_restamp(
            generated_setfile, _sha_bytes(ex5.read_bytes())
        )
        if authenticated_ex5_restamp
        else build_check_setfile
    )
    setf.write_bytes(final_setfile)
    transition = authenticate_setfile_build_hash_transition(
        _sha_bytes(generated_setfile), build_check_setfile
    )
    assert transition["ok"] is True

    setfile_generation = {
        "symbol": SYMBOL,
        "setfile_path": str(setf),
        # Historical evidence captured the generator hash. New producer
        # evidence seals final bytes and preserves this value separately.
        "setfile_sha256": (
            _sha_bytes(build_check_setfile)
            if final_lifecycle_evidence
            else _sha_bytes(generated_setfile)
        ),
        "setfile_exists": True,
        "exit_code": 0,
    }
    if final_lifecycle_evidence:
        setfile_generation.update({
            "generated_setfile_sha256": _sha_bytes(generated_setfile),
            "setfile_sha256_after_build_check": _sha_bytes(final_setfile),
            "build_hash_transition": transition,
        })

    compile_work_item_id = "5f5f5f5f-1111-4000-8000-000000000099"
    evidence_dir = root / "reports" / "work_items" / compile_work_item_id / EA_ID / "COMPILE_EA"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence_path = evidence_dir / "compile_evidence.json"
    evidence = {
        "ea_id": EA_ID,
        "ex5_path": str(ex5),
        "mq5_path": str(mq5),
        "ex5_sha256": _sha_bytes(ex5.read_bytes()),
        "mq5_sha256": _sha_bytes(mq5.read_bytes()),
        "success": True,
        "compile_result": "PASS",
        "setfile_generation": [setfile_generation],
    }
    evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8")

    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items("
            "id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "evidence_path,payload_json,created_at,updated_at,mq5_sha256,ex5_sha256"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                compile_work_item_id, "compile", "COMPILE_EA", EA_ID, "", "",
                "done", "COMPILE_OK", 0, str(evidence_path), "{}", now, now,
                evidence["mq5_sha256"], evidence["ex5_sha256"],
            ),
        )
        # Minimal agent_tasks table (owned by agent_router.py, not farmctl's own
        # init_db); DDL mirrors agent_router.init_schema without pulling in its
        # registry-writer SQL function dependency, which a plain farmctl.connect()
        # connection does not register.
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS agent_tasks (
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                state TEXT NOT NULL,
                priority INTEGER NOT NULL DEFAULT 50,
                required_capabilities_json TEXT NOT NULL,
                required_skills_json TEXT NOT NULL DEFAULT '[]',
                assigned_agent TEXT,
                budget_class TEXT NOT NULL DEFAULT 'standard',
                parent_id TEXT,
                artifact_path TEXT,
                verdict TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        conn.execute(
            "INSERT INTO agent_tasks("
            "id,task_type,state,priority,required_capabilities_json,required_skills_json,"
            "assigned_agent,budget_class,parent_id,artifact_path,verdict,payload_json,"
            "created_at,updated_at"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                BUILD_TASK_ID, "build_ea", build_state, 30, "[]", "[]",
                "claude", "standard", None,
                artifact_path_override if artifact_path_override is not None else str(evidence_path),
                "seeded for test", "{}", now, now,
            ),
        )
        conn.commit()
    return root, {
        "evidence_path": evidence_path,
        "ex5": ex5,
        "mq5": mq5,
        "setf": setf,
        "generated_setfile": generated_setfile,
        "build_check_setfile": build_check_setfile,
        "final_setfile": final_setfile,
        "compile_work_item_id": compile_work_item_id,
    }


def _append(root: Path, art: dict, **kwargs):
    return farmctl.append_q01_smoke_work_item(
        root,
        ea_id=EA_ID,
        symbol=SYMBOL,
        build_task_id=BUILD_TASK_ID,
        compile_evidence_path=str(art["evidence_path"]),
        **kwargs,
    )


def test_happy_path_appends_pending_work_item(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    res = _append(root, art)
    assert res["appended"] is True, res
    assert res["status"] == "pending"
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (res["work_item_id"],)
        ).fetchone()
    assert row is not None
    assert row["kind"] == "q01_smoke"
    assert row["phase"] == "Q01"
    assert row["ea_id"] == EA_ID
    assert row["symbol"] == SYMBOL
    assert row["status"] == "pending"
    payload = json.loads(row["payload_json"])
    assert payload["q01_smoke_contract"] == farmctl.Q01_SMOKE_WORK_ITEM_CONTRACT
    assert payload["build_task_id"] == BUILD_TASK_ID
    assert payload["compile_work_item_id"] == art["compile_work_item_id"]
    assert payload["from_date"] == farmctl.Q01_SMOKE_DISPATCH_DEFAULT_FROM_DATE
    assert payload["to_date"] == farmctl.Q01_SMOKE_DISPATCH_DEFAULT_TO_DATE
    assert payload["window_source"] == "farmctl.append_q01_smoke_work_item"
    assert payload["expected_setfile_sha256"] == _sha_bytes(art["final_setfile"])
    assert payload["setfile_binding_mode"] == "historical_pre_stamp_exact_transition"
    receipt = Path(payload["setfile_binding_receipt_path"])
    assert receipt.is_file()
    assert _sha_bytes(receipt.read_bytes()) == payload["setfile_binding_receipt_sha256"]
    receipt_doc = json.loads(receipt.read_text(encoding="utf-8"))
    assert receipt_doc["historical_compile_evidence_rewritten"] is False
    assert receipt_doc["setfile_binding_provenance"]["transition"][
        "input_assignments_unchanged"
    ] is True


def test_dry_run_never_writes(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    res = _append(root, art, dry_run=True)
    assert res["appended"] is False
    assert res["would_append"] is True
    with farmctl.connect(root) as conn:
        n = conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]
    assert n == 1  # only the seeded compile row
    assert not Path(res["setfile_binding_receipt_path"]).exists()


def test_idempotent_on_exact_repeat(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    first = _append(root, art)
    second = _append(root, art)
    assert first["appended"] is True
    assert second["appended"] is False
    assert second["already_applied"] is True
    assert second["work_item_id"] == first["work_item_id"]
    with farmctl.connect(root) as conn:
        n = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE kind='q01_smoke'"
        ).fetchone()[0]
    assert n == 1


def test_refuses_second_identity_while_one_is_pending(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    first = _append(root, art)
    assert first["appended"] is True
    # A distinct identity (different build_task_id) targeting the same
    # (ea_id, symbol) must be refused while the first row is still pending.
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE agent_tasks SET id=? WHERE id=?", (BUILD_TASK_ID + "-alt", BUILD_TASK_ID)
        )
        conn.commit()
    res = farmctl.append_q01_smoke_work_item(
        root,
        ea_id=EA_ID,
        symbol=SYMBOL,
        build_task_id=BUILD_TASK_ID + "-alt",
        compile_evidence_path=str(art["evidence_path"]),
    )
    assert res["appended"] is False
    assert res["reason"] == "q01_smoke_already_pending_for_target"


def test_refuses_unknown_symbol(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    res = farmctl.append_q01_smoke_work_item(
        root,
        ea_id=EA_ID,
        symbol="GBPUSD.DWX",
        build_task_id=BUILD_TASK_ID,
        compile_evidence_path=str(art["evidence_path"]),
    )
    assert res["appended"] is False
    assert res["reason"] == "symbol_not_in_compile_evidence"


def test_refuses_on_ex5_drift_since_compile(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    art["ex5"].write_bytes(b"\x00DRIFTED-BYTES-AFTER-COMPILE\x01")
    res = _append(root, art)
    assert res["appended"] is False
    assert res["reason"] == "artifact_drift_since_compile"


def test_refuses_changed_setfile_input_even_when_restamped(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    # A self-consistent new build_hash cannot authenticate a changed strategy
    # or risk input against the historical generator seal.
    art["setf"].write_bytes(
        _build_check_stamp(_generated_setfile_bytes(risk_fixed="999"))
    )
    res = _append(root, art)
    assert res["appended"] is False
    assert res["reason"] == "artifact_drift_since_compile"
    assert res["detail"]["transition_refusal"]["reason"] == (
        "generated_setfile_bytes_not_exact_preimage"
    )


def test_accepts_new_post_build_lifecycle_evidence(tmp_path: Path) -> None:
    root, art = _seed(tmp_path, final_lifecycle_evidence=True)
    res = _append(root, art)
    assert res["appended"] is True, res
    assert res["setfile_binding_provenance"]["mode"] == (
        "compile_evidence_final_hash"
    )
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT setfile_sha256,payload_json FROM work_items WHERE id=?",
            (res["work_item_id"],),
        ).fetchone()
    payload = json.loads(row["payload_json"])
    assert row["setfile_sha256"] == _sha_bytes(art["final_setfile"])
    assert payload["expected_setfile_sha256"] == row["setfile_sha256"]


def test_accepts_historical_evidence_with_exact_ex5_restamp(tmp_path: Path) -> None:
    root, art = _seed(tmp_path, authenticated_ex5_restamp=True)
    res = _append(root, art)
    assert res["appended"] is True, res
    assert res["setfile_binding_provenance"]["mode"] == (
        "historical_pre_stamp_exact_transition"
    )
    assert res["setfile_binding_provenance"]["transition"][
        "transition_mode"
    ] == "authenticated_ex5_hash_restamp"


def test_accepts_new_lifecycle_then_exact_ex5_restamp(tmp_path: Path) -> None:
    root, art = _seed(
        tmp_path,
        final_lifecycle_evidence=True,
        authenticated_ex5_restamp=True,
    )
    res = _append(root, art)
    assert res["appended"] is True, res
    provenance = res["setfile_binding_provenance"]
    assert provenance["mode"] == "compile_final_to_authenticated_ex5_restamp"
    assert provenance["compile_final_setfile_sha256"] == _sha_bytes(
        art["build_check_setfile"]
    )
    assert provenance["transition"]["transition_mode"] == (
        "authenticated_ex5_hash_restamp"
    )


def test_refuses_when_build_task_artifact_path_does_not_bind(tmp_path: Path) -> None:
    root, art = _seed(tmp_path, artifact_path_override="D:\\QM\\reports\\some\\other\\evidence.json")
    res = _append(root, art)
    assert res["appended"] is False
    assert res["reason"] == "build_task_artifact_path_mismatch"


def test_refuses_when_build_task_is_disqualified_state(tmp_path: Path) -> None:
    root, art = _seed(tmp_path, build_state="FAILED")
    res = _append(root, art)
    assert res["appended"] is False
    assert res["reason"] == "build_task_state_disqualified"


def test_refuses_malformed_window(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    res = _append(root, art, from_date="2024.12.31", to_date="2024.01.01")
    assert res["appended"] is False
    assert res["reason"] == "q01_smoke_dispatch_window_invalid"


def test_no_targets_hardcoding_arbitrary_ea_id_accepted(tmp_path: Path) -> None:
    """The route must not special-case any specific EA id, unlike TARGETS."""
    root, art = _seed(tmp_path)
    assert EA_ID not in {"QM5_12512", "QM5_10050", "QM5_12507"}
    res = _append(root, art)
    assert res["appended"] is True
