"""Tests for the REQUAL-8 boundary tooling in farmctl.

Two governed subcommands (OWNER-DEC-Q09HOLD-REQUAL-8-20260829):

* ``record_q01_smoke_successor`` authenticates a worker-bound Q01 smoke PASS and
  appends a build-generation successor so Q02 admission (via
  ``_latest_build_smoke_result`` / ``_q01_smoke_admission``) sees
  ``smoke_result=passed`` without ever overwriting generation 0.
* ``release_work_item_hold`` releases exactly one active ``work_item_holds`` row
  under the factory-mutation lock with a fresh backup, an exact CAS, and
  append-only ledger + event records, never touching ``work_items``.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import farmctl
from tools.strategy_farm.factory_mutation_lock import (
    FactoryMutationLock,
    path_for_factory_flag,
)

CONTRACT = farmctl.Q01_SMOKE_WORK_ITEM_CONTRACT
BUILD_TASK_ID = "0f36f1bb-924b-4126-b682-c30ba1edfa41"
SMOKE_WID = "7afddab0-dfc1-5324-bb7d-b585d9ddfa69"
EA_ID = "QM5_41221"
SYMBOL = "EURUSD.DWX"


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _make_artifacts(tmp_path: Path) -> dict[str, object]:
    ea_dir = tmp_path / "repo" / "framework" / "EAs" / f"{EA_ID}_ohlc-daily-squeeze-reversal-d1-requal8"
    (ea_dir / "sets").mkdir(parents=True, exist_ok=True)
    mq5 = ea_dir / f"{EA_ID}_ohlc-daily-squeeze-reversal-d1-requal8.mq5"
    ex5 = ea_dir / f"{EA_ID}_ohlc-daily-squeeze-reversal-d1-requal8.ex5"
    setf = ea_dir / "sets" / f"{EA_ID}_ohlc-daily-squeeze-reversal-d1-requal8_{SYMBOL}_D1_backtest.set"
    spec = ea_dir / "SPEC.md"
    mq5.write_bytes(b"// mq5 source bytes\n")
    ex5.write_bytes(b"\x00EX5-COMPILED-BYTES\x01")
    setf.write_bytes(b"RISK_FIXED=1000\nRISK_PERCENT=0\n")
    spec.write_text("spec\n", encoding="utf-8")
    return {
        "ea_dir": ea_dir,
        "mq5": mq5,
        "ex5": ex5,
        "setf": setf,
        "spec": spec,
        "mq5_sha": _sha_bytes(mq5.read_bytes()),
        "ex5_sha": _sha_bytes(ex5.read_bytes()),
        "set_sha": _sha_bytes(setf.read_bytes()),
    }


def _seed_build_and_smoke(
    tmp_path: Path,
    *,
    smoke_verdict: str = "PASS",
    smoke_status: str = "done",
    artifacts: dict[str, object] | None = None,
) -> tuple[Path, dict[str, object]]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    art = artifacts if artifacts is not None else _make_artifacts(tmp_path)
    now = farmctl.utc_now()

    gen0_result = {
        "task_id": BUILD_TASK_ID,
        "ea_id": EA_ID,
        "ea_dir": str(art["ea_dir"]),
        "mq5_path": str(art["mq5"]),
        "ex5_path": str(art["ex5"]),
        "magic_base": 412210000,
        "symbols_registered": [SYMBOL],
        "setfiles_generated": [str(art["setf"])],
        "spec_md_path": str(art["spec"]),
        "build_check_passed": True,
        "compile_succeeded": True,
        "smoke_result": "deferred_p2_smoke",
        "smoke_report_path": None,
        "blocked_reason": "governed slot census; no smoke terminal was started",
        "open_questions": [],
        "q09_requal8_manifest_sha256": "0b6845c9" + "0" * 56,
    }
    gen0_path = root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.json"
    gen0_bytes = (json.dumps(gen0_result, indent=2, sort_keys=True) + "\n").encode("utf-8")
    gen0_path.parent.mkdir(parents=True, exist_ok=True)
    gen0_path.write_bytes(gen0_bytes)
    gen0_sha = _sha_bytes(gen0_bytes)

    build_payload = {
        "ea_id": EA_ID,
        "build_generation": 0,
        "codex_result": gen0_result,
        "build_result_path": str(gen0_path),
        "build_result_sha256": gen0_sha,
        "build_recorded_at": now,
        "smoke_skipped_reason": "framework_error_during_build_smoke_treated_as_done",
    }
    evidence = root / "reports" / SMOKE_WID / "summary.json"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text('{"result":"PASS"}\n', encoding="utf-8")
    smoke_payload = {
        "q01_smoke_contract": CONTRACT,
        "build_task_id": BUILD_TASK_ID,
        "expected_mq5_sha256": art["mq5_sha"],
        "expected_ex5_sha256": art["ex5_sha"],
        "expected_setfile_sha256": art["set_sha"],
        "expected_ex5_path": str(art["ex5"]),
        "artifact_identity": {
            "mq5_sha256": art["mq5_sha"],
            "ex5_sha256": art["ex5_sha"],
            "setfile_sha256": art["set_sha"],
        },
    }

    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO tasks(id,kind,status,source_id,card_id,payload_json,created_at,updated_at) "
            "VALUES(?,?,?,?,?,?,?,?)",
            (BUILD_TASK_ID, "build_ea", "done", None, EA_ID, json.dumps(build_payload), now, now),
        )
        conn.execute(
            "INSERT INTO work_items("
            "id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "evidence_path,payload_json,created_at,updated_at,mq5_sha256,ex5_sha256,setfile_sha256"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                SMOKE_WID, "q01_smoke", "Q01", EA_ID, SYMBOL, str(art["setf"]),
                smoke_status, smoke_verdict, 0, str(evidence), json.dumps(smoke_payload),
                now, now, art["mq5_sha"], art["ex5_sha"], art["set_sha"],
            ),
        )
        conn.commit()
    return root, art


# --------------------------------------------------------------------------
# record-q01-smoke-successor
# --------------------------------------------------------------------------


def test_successor_happy_path_flips_admission(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path)

    # Before: admission refuses.
    with farmctl.connect(root) as conn:
        before = farmctl._latest_build_smoke_result(conn, EA_ID)
    assert farmctl._q01_smoke_admission(before)["admitted"] is False

    res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert res["recorded"] is True, res
    assert res["from_build_generation"] == 0
    assert res["to_build_generation"] == 1
    assert res["latest_smoke_result_after"] == "passed"
    assert res["q01_smoke_admission_after"]["admitted"] is True
    assert len(res["backup"]["sha256"]) == 64
    assert Path(res["backup"]["path"]).is_file()

    # A new generation artifact was written; generation 0 is byte-identical.
    gen1 = root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen1.json"
    gen0 = root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.json"
    assert gen1.is_file()
    gen1_doc = json.loads(gen1.read_text())
    assert gen1_doc["smoke_result"] == "passed"
    assert gen1_doc["blocked_reason"] == ""
    assert gen1_doc["build_check_passed"] is True
    assert gen1_doc["compile_succeeded"] is True
    assert gen1_doc["q01_smoke_work_item_id"] == SMOKE_WID
    gen0_doc = json.loads(gen0.read_text())
    assert gen0_doc["smoke_result"] == "deferred_p2_smoke"

    # Tasks-row admission now passes end to end.
    with farmctl.connect(root) as conn:
        after = farmctl._latest_build_smoke_result(conn, EA_ID)
        payload = json.loads(
            conn.execute("SELECT payload_json FROM tasks WHERE id=?", (BUILD_TASK_ID,)).fetchone()[0]
        )
    assert farmctl._q01_smoke_admission(after)["admitted"] is True
    assert payload["build_generation"] == 1
    # Append-only history keeps generation 0.
    gens = [g["build_generation"] for g in payload["build_generations"]]
    assert gens == [0, 1]
    assert payload["build_generations"][0]["codex_result"]["smoke_result"] == "deferred_p2_smoke"

    # An audit event was written.
    with farmctl.connect(root) as conn:
        n = conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='q01_smoke_generation_successor_recorded'"
        ).fetchone()[0]
    assert n == 1


def test_successor_is_idempotent(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path)
    first = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert first["recorded"] is True
    second = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert second["recorded"] is False
    assert second["already_recorded"] is True
    assert second["reason"] == "q01_smoke_successor_already_recorded"
    # No second generation, no second event, generation stays 1.
    with farmctl.connect(root) as conn:
        events = conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='q01_smoke_generation_successor_recorded'"
        ).fetchone()[0]
        payload = json.loads(
            conn.execute("SELECT payload_json FROM tasks WHERE id=?", (BUILD_TASK_ID,)).fetchone()[0]
        )
    assert events == 1
    assert payload["build_generation"] == 1
    assert not (root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen2.json").exists()


def test_successor_refuses_on_hash_mismatch(tmp_path: Path) -> None:
    root, art = _seed_build_and_smoke(tmp_path)
    # Drift the current EX5 bytes away from the sealed smoke binding.
    art["ex5"].write_bytes(b"\x00TAMPERED-EX5\x02")
    res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert res["recorded"] is False
    assert res["reason"] == "artifact_sha256_mismatch", res
    # Nothing was written.
    assert not (root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen1.json").exists()
    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute("SELECT payload_json FROM tasks WHERE id=?", (BUILD_TASK_ID,)).fetchone()[0]
        )
    assert payload["build_generation"] == 0
    assert payload["codex_result"]["smoke_result"] == "deferred_p2_smoke"


def test_successor_refuses_when_smoke_not_pass(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path, smoke_verdict="FAIL")
    res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert res["recorded"] is False
    assert res["reason"] == "q01_smoke_not_pass", res
    assert not (root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen1.json").exists()


def test_successor_refuses_on_contract_mismatch(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path)
    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute("SELECT payload_json FROM work_items WHERE id=?", (SMOKE_WID,)).fetchone()[0]
        )
        payload["q01_smoke_contract"] = "qm.q01.some_other_contract.v9"
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?", (json.dumps(payload), SMOKE_WID)
        )
        conn.commit()
    res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert res["recorded"] is False
    assert res["reason"] == "q01_smoke_contract_mismatch", res


def test_successor_dry_run_writes_nothing(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path)
    res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID, dry_run=True)
    assert res["recorded"] is False
    assert res["dry_run"] is True
    assert res["would_record"] is True
    assert res["to_build_generation"] == 1
    assert not (root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen1.json").exists()
    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute("SELECT payload_json FROM tasks WHERE id=?", (BUILD_TASK_ID,)).fetchone()[0]
        )
        events = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
    assert payload["build_generation"] == 0
    assert events == 0


def test_successor_lock_busy_is_reported_not_raised(tmp_path: Path) -> None:
    root, _art = _seed_build_and_smoke(tmp_path)
    lock = FactoryMutationLock(
        path_for_factory_flag(farmctl.factory_off_flag_path(root)),
        owner="test-holder",
    )
    with lock:
        res = farmctl.record_q01_smoke_successor(root, BUILD_TASK_ID, SMOKE_WID)
    assert res["recorded"] is False
    assert res["reason"] == "factory_mutation_lock_busy", res
    assert not (root / "artifacts" / "builds" / f"{BUILD_TASK_ID}.gen1.json").exists()


# --------------------------------------------------------------------------
# release-hold
# --------------------------------------------------------------------------

HOLD_WID = "30584122-b7b3-41eb-8e1a-b03517554d4d"
HOLD_CODE = "Q09_AWAITING_SEALED_PLAN"
RELEASE_NOTE = "OWNER-DEC-Q09HOLD-REQUAL-8-20260829 pair-7 sealed plan release"


def _seed_hold(tmp_path: Path) -> Path:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items("
            "id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,payload_json,created_at,updated_at"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
            (HOLD_WID, "backtest", "Q09", EA_ID, SYMBOL, "/tmp/held.set", "pending",
             None, 0, json.dumps({"held": True}), now, now),
        )
        conn.execute(
            "INSERT INTO work_item_holds("
            "work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note"
            ") VALUES(?,?,?,1,0,?,?,NULL,NULL)",
            (HOLD_WID, HOLD_CODE, "awaiting sealed plan", now, now),
        )
        conn.commit()
    return root


def test_release_hold_happy_path(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    with farmctl.connect(root) as conn:
        wi_before = dict(conn.execute(
            "SELECT status,verdict,payload_json FROM work_items WHERE id=?", (HOLD_WID,)
        ).fetchone())

    res = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, RELEASE_NOTE)
    assert res["released"] is True, res
    assert res["hold_code"] == HOLD_CODE
    assert res["release_note"] == RELEASE_NOTE
    assert res["ledger_written"] is True
    assert isinstance(res["ledger_seq"], int)
    assert res["work_items_untouched"] is True
    assert len(res["backup"]["sha256"]) == 64

    with farmctl.connect(root) as conn:
        hold = dict(conn.execute(
            "SELECT active,released_at,release_note FROM work_item_holds WHERE work_item_id=?",
            (HOLD_WID,),
        ).fetchone())
        ledger = conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger "
            "WHERE work_item_id=? AND action='work_item_hold_released'",
            (HOLD_WID,),
        ).fetchone()[0]
        events = conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='work_item_hold_released' AND entity_id=?",
            (HOLD_WID,),
        ).fetchone()[0]
        wi_after = dict(conn.execute(
            "SELECT status,verdict,payload_json FROM work_items WHERE id=?", (HOLD_WID,)
        ).fetchone())
    assert hold["active"] == 0
    assert hold["released_at"] is not None
    assert hold["release_note"] == RELEASE_NOTE
    assert ledger == 1
    assert events == 1
    # work_items row untouched.
    assert wi_after == wi_before


def test_release_hold_cas_mismatch_refuses(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    res = farmctl.release_work_item_hold(root, HOLD_WID, "WRONG_HOLD_CODE", RELEASE_NOTE)
    assert res["released"] is False
    assert res["reason"] == "hold_code_mismatch", res
    with farmctl.connect(root) as conn:
        hold = dict(conn.execute(
            "SELECT active,released_at FROM work_item_holds WHERE work_item_id=?", (HOLD_WID,)
        ).fetchone())
        events = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
    assert hold["active"] == 1
    assert hold["released_at"] is None
    assert events == 0


def test_release_hold_second_call_refuses_already_inactive(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    first = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, RELEASE_NOTE)
    assert first["released"] is True
    second = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, RELEASE_NOTE)
    assert second["released"] is False
    assert second["reason"] == "hold_not_active", second


def test_release_hold_dry_run_writes_nothing(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    res = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, RELEASE_NOTE, dry_run=True)
    assert res["released"] is False
    assert res["dry_run"] is True
    assert res["would_release"] is True
    with farmctl.connect(root) as conn:
        hold = dict(conn.execute(
            "SELECT active,released_at FROM work_item_holds WHERE work_item_id=?", (HOLD_WID,)
        ).fetchone())
        events = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        ledger = conn.execute("SELECT COUNT(*) FROM work_item_transition_ledger").fetchone()[0]
    assert hold["active"] == 1
    assert hold["released_at"] is None
    assert events == 0
    assert ledger == 0


def test_release_hold_lock_busy_is_reported(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    lock = FactoryMutationLock(
        path_for_factory_flag(farmctl.factory_off_flag_path(root)),
        owner="test-holder",
    )
    with lock:
        res = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, RELEASE_NOTE)
    assert res["released"] is False
    assert res["reason"] == "factory_mutation_lock_busy", res
    with farmctl.connect(root) as conn:
        hold = dict(conn.execute(
            "SELECT active FROM work_item_holds WHERE work_item_id=?", (HOLD_WID,)
        ).fetchone())
    assert hold["active"] == 1


def test_release_hold_missing_note_refuses(tmp_path: Path) -> None:
    root = _seed_hold(tmp_path)
    res = farmctl.release_work_item_hold(root, HOLD_WID, HOLD_CODE, "   ")
    assert res["released"] is False
    assert res["reason"] == "release_note_required", res
