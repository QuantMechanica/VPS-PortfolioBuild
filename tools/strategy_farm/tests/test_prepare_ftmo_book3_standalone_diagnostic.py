from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import prepare_ftmo_book3_standalone_diagnostic as planner  # noqa: E402


def _create_db(path: Path, *, v2_id: str = "v2-r2") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    v2_payload = json.dumps(
        {
            "measurement_contract": planner.base.FIDELITY_MEASUREMENT_CONTRACT,
            "measurement_rung": "R2",
            "measurement_sequence": 4,
            "terminal": "T10",
        },
        sort_keys=True,
    )
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items(
              id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
              ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
              status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL DEFAULT 0,
              parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
              payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            );
            CREATE TABLE work_item_holds(
              work_item_id TEXT PRIMARY KEY, hold_code TEXT NOT NULL, reason TEXT NOT NULL,
              active INTEGER NOT NULL, release_on_restart INTEGER NOT NULL,
              created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
              released_at TEXT, release_note TEXT
            );
            """
        )
        conn.execute(
            "INSERT INTO work_items VALUES "
            "(?, 'backtest','Q02','QM5_13108','XTIUSD.DWX','r2.set','pending',NULL,0,NULL,NULL,NULL,?,'old','old')",
            (v2_id, v2_payload),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES (?,?,?,?,?,'old','old',NULL,NULL)",
            (
                v2_id,
                planner.base.HOLD_CODE,
                planner.base.HOLD_REASON,
                1,
                0,
            ),
        )


def _artifact(role: str, path: Path, byte: str = "a") -> dict:
    return {
        "role": role,
        "path": str(path),
        "sha256": byte * 64,
        "bytes": 1,
        "valid": True,
    }


def test_item_contract_is_content_addressed_non_ladder_and_binds_307_inputs(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    artifact_root = tmp_path / "artifacts"
    report_root = tmp_path / "reports" / "work_items"
    common_qm = tmp_path / "common" / "QM"
    t10_bases = tmp_path / "T10" / "bases"
    calendar_source = tmp_path / "calendar"
    calendar_common = tmp_path / "common"
    input_roles = sorted(planner.base._required_execution_input_roles())
    assert len(input_roles) == planner.EXPECTED_EXECUTION_INPUT_COUNT
    artifacts = [
        _artifact(role, tmp_path / "inputs" / f"{index:03d}.bin")
        for index, role in enumerate(input_roles)
    ]
    existing = {item["role"] for item in artifacts}
    for index, role in enumerate(planner.RUNTIME_SOURCE_ROLES):
        if role not in existing:
            artifacts.append(_artifact(role, tmp_path / "runtime" / f"{index:02d}.py", "b"))
    extra_roles = (
        f"mq5:{planner.SPEC['ea_dir']}",
        f"set:{planner.DIAGNOSTIC_CODE}",
        "framework_include_tree",
    )
    for index, role in enumerate(extra_roles):
        artifacts.append(_artifact(role, tmp_path / "extra" / f"{index:02d}.bin", "c"))
    compile_binding = {
        "path": str(artifact_root / "compile_manifest.json"),
        "sha256": "d" * 64,
        "bytes": 100,
        "source_commit": "1" * 40,
        "compile_controller": {
            "path": str(repo / planner.base.COMPILE_CONTROLLER_REL),
            "sha256": "e" * 64,
            "bytes": 10,
        },
    }
    excluded_row = {
        "id": "v2-r2",
        "kind": "backtest",
        "phase": "Q02",
        "ea_id": "QM5_13108",
        "symbol": "XTIUSD.DWX",
        "setfile_path": "r2.set",
        "status": "pending",
        "verdict": None,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": "{}",
        "created_at": "old",
        "updated_at": "old",
    }
    excluded = {
        "id": "v2-r2",
        "payload_sha256": "f" * 64,
        "row": excluded_row,
        "row_sha256": planner._canonical_sha(excluded_row),
        "status": "pending",
        "verdict": None,
        "claimed_by": None,
        "evidence_path": None,
        "hold": {
            "work_item_id": "v2-r2",
            "hold_code": planner.base.HOLD_CODE,
            "reason": planner.base.HOLD_REASON,
            "active": 1,
            "release_on_restart": 0,
            "created_at": "old",
            "updated_at": "old",
            "released_at": None,
            "release_note": None,
        },
    }
    operation = planner._item_contract(
        repo=repo,
        artifact_root=artifact_root,
        report_root=report_root,
        common_qm=common_qm,
        t10_bases=t10_bases,
        calendar_source=calendar_source,
        calendar_common=calendar_common,
        git_identity={
            "authoritative_source_commit": "1" * 40,
            "controller_head_commit": "1" * 40,
        },
        compile_binding=compile_binding,
        ex5_sha256="9" * 64,
        artifacts=artifacts,
        excluded_v2=excluded,
    )
    payload = json.loads(operation["payload_json"])
    assert operation["work_item_id"] == planner._content_uuid(
        operation["execution_bundle_sha256"]
    )
    assert Path(operation["report_root"]).name == operation["work_item_id"]
    assert payload["execution_input_artifact_count"] == 307
    assert len(payload["execution_input_artifacts"]) == 307
    assert payload["measurement_contract"] == planner.MEASUREMENT_CONTRACT
    assert payload["no_ladder_progression"] is True
    assert payload["no_joint_admission"] is True
    assert payload["no_release_authority"] is True
    assert payload["excluded_v2_r2_work_item_id"] == "v2-r2"
    assert payload["excluded_v2_r2_hold_sha256"] == planner._canonical_sha(
        excluded["hold"]
    )
    assert payload["excluded_v2_r2_row_sha256"] == excluded["row_sha256"]
    assert payload["compile_policy"] == planner.COMPILE_POLICY
    assert not {
        "measurement_rung",
        "measurement_sequence",
        "required_fidelity_stage",
        "evidence_run_id",
    } & set(payload)
    assert operation["hold"] == {
        "hold_code": planner.HOLD_CODE,
        "reason": planner.HOLD_REASON,
        "active": 1,
        "release_on_restart": 0,
    }


def test_excluded_v2_r2_requires_pending_unclaimed_exact_rung(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    db = tmp_path / "farm.sqlite"
    _create_db(db)
    monkeypatch.setattr(planner, "V2_R2_WORK_ITEM_ID", "v2-r2")
    with planner.base.connect_ro(db) as conn:
        accepted, accepted_errors = planner._excluded_v2_r2(conn)
    assert accepted_errors == []
    assert accepted is not None
    assert accepted["status"] == "pending"
    assert accepted["row_sha256"] == planner._canonical_sha(accepted["row"])

    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE work_items SET attempt_count=1 WHERE id='v2-r2'")
    with planner.base.connect_ro(db) as conn:
        changed, changed_errors = planner._excluded_v2_r2(conn)
    assert changed_errors != []
    assert any("attempt_count mismatch" in error for error in changed_errors)
    assert changed is not None and changed["row_sha256"] != accepted["row_sha256"]
    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE work_items SET attempt_count=0 WHERE id='v2-r2'")

    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS' WHERE id='v2-r2'"
        )
    with planner.base.connect_ro(db) as conn:
        _rejected, rejected_errors = planner._excluded_v2_r2(conn)
    assert any("status mismatch" in error for error in rejected_errors)
    assert any("verdict mismatch" in error for error in rejected_errors)


def test_transitive_runtime_dependencies_are_source_scoped_and_content_addressed(
    tmp_path: Path,
) -> None:
    repo = (tmp_path / "repo").resolve()
    controller = (
        repo / "tools/strategy_farm/prepare_ftmo_book3_standalone_diagnostic.py"
    )
    scope = {
        path.resolve().relative_to(repo).as_posix()
        for path in planner._source_scope(repo, controller)
    }
    assert "tools/strategy_farm/q09_news_contract.py" in scope
    assert "tools/strategy_farm/phase_runner_allowlist.v1.json" in scope
    assert "framework/registry/tester_defaults.json" in scope

    artifacts = {
        item["role"]: item for item in planner._repo_artifacts(repo, controller)
    }
    assert artifacts["q09_news_contract"]["path"] == str(
        repo / "tools/strategy_farm/q09_news_contract.py"
    )
    assert artifacts["phase_runner_allowlist"]["path"] == str(
        repo / "tools/strategy_farm/phase_runner_allowlist.v1.json"
    )
    assert artifacts["tester_defaults"]["path"] == str(
        repo / "framework/registry/tester_defaults.json"
    )


def test_git_identity_fails_when_transitive_runtime_dependency_is_dirty(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = (tmp_path / "repo").resolve()
    repo.mkdir()
    controller = (
        repo / "tools/strategy_farm/prepare_ftmo_book3_standalone_diagnostic.py"
    )
    commit = "1" * 40

    def fake_git(_repo: Path, *args: str) -> str:
        if args[:2] == ("rev-parse", "HEAD"):
            return commit
        if args and args[0] == "rev-parse":
            return commit
        if args and args[0] == "status":
            return " M framework/registry/tester_defaults.json"
        if args and args[0] == "ls-files":
            return (
                "tools/strategy_farm/q09_news_contract.py\n"
                "tools/strategy_farm/phase_runner_allowlist.v1.json"
                "framework/registry/tester_defaults.json\n"
            )
        raise AssertionError(args)

    monkeypatch.setattr(planner.base, "_git", fake_git)
    identity, errors = planner._git_identity(repo, controller, commit)
    assert any("source scope is not clean" in error for error in errors)
    assert "tester_defaults.json" in identity["source_scope_porcelain"]
    assert "tools/strategy_farm/q09_news_contract.py" in identity["source_scope"]
    assert "tools/strategy_farm/phase_runner_allowlist.v1.json" in identity["source_scope"]
    assert "framework/registry/tester_defaults.json" in identity["source_scope"]


def _apply_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict, dict, Path, Path, str]:
    root = tmp_path / "farm"
    repo = tmp_path / "repo"
    artifact_root = tmp_path / "artifacts"
    report_root = tmp_path / "reports" / "work_items"
    common_qm = tmp_path / "common" / "QM"
    t10_bases = tmp_path / "T10" / "bases"
    calendar_source = tmp_path / "calendar-source"
    calendar_common = tmp_path / "common"
    for path in (repo, artifact_root, report_root.parent, common_qm, t10_bases, calendar_source):
        path.mkdir(parents=True, exist_ok=True)
    state = root / "state"
    state.mkdir(parents=True)
    flag = state / "FACTORY_OFF.flag"
    flag.write_text("intentional-off\n", encoding="utf-8")
    db = state / "farm_state.sqlite"
    _create_db(db)
    monkeypatch.setattr(planner, "V2_R2_WORK_ITEM_ID", "v2-r2")
    for name, value in (
        ("DEFAULT_ROOT", root),
        ("DEFAULT_REPO", repo),
        ("DEFAULT_ARTIFACT_ROOT", artifact_root),
        ("DEFAULT_REPORT_ROOT", report_root),
        ("DEFAULT_COMMON_QM", common_qm),
        ("DEFAULT_T10_BASES", t10_bases),
        ("DEFAULT_CALENDAR_SOURCE", calendar_source),
        ("DEFAULT_CALENDAR_COMMON", calendar_common),
    ):
        monkeypatch.setattr(planner, name, value)
    with planner.base.connect_ro(db) as conn:
        excluded, errors = planner._excluded_v2_r2(conn)
    assert errors == [] and excluded is not None
    payload = json.dumps(
        {
            "measurement_contract": planner.MEASUREMENT_CONTRACT,
            "no_ladder_progression": True,
        },
        sort_keys=True,
    )
    operation = {
        "code": planner.DIAGNOSTIC_CODE,
        "work_item_id": "diagnostic-id",
        "kind": "backtest",
        "phase": "Q02",
        "ea_id": "QM5_13108",
        "symbol": "XTIUSD.DWX",
        "setfile_path": str(tmp_path / "r2.set"),
        "report_root": str(report_root / "diagnostic-id"),
        "execution_bundle_sha256": "a" * 64,
        "payload_json": payload,
        "hold": {
            "hold_code": planner.HOLD_CODE,
            "reason": planner.HOLD_REASON,
            "active": 1,
            "release_on_restart": 0,
        },
    }
    safety = {
        "factory_remains_off": True,
        "runs_mt5": False,
        "auto_enqueue": False,
        "auto_promote": False,
        "no_ladder_progression": True,
        "no_joint_admission": True,
        "no_release_authority": True,
        "pending_v2_r2_mutated": False,
    }
    commit = "1" * 40
    manifest = {
        "schema": planner.SCHEMA_PREPARE,
        "mode": "dry_run",
        "generated_at_utc": "2026-07-30T00:00:00+00:00",
        "root": str(root),
        "repo": str(repo),
        "artifact_root": str(artifact_root),
        "report_root": str(report_root),
        "common_qm": str(common_qm),
        "terminal": "T10",
        "measurement_contract": planner.MEASUREMENT_CONTRACT,
        "t10_bases": str(t10_bases),
        "calendar_source": str(calendar_source),
        "calendar_common": str(calendar_common),
        "factory_off": {"path": str(flag), "sha256": planner._sha(flag)},
        "db": {"path": str(db), "logical_state_sha256": planner.base.sqlite_state_sha256(db)},
        "git": {"authoritative_source_commit": commit},
        "excluded_v2_r2": excluded,
        "operation_count": 1,
        "operations": [operation],
        "execution_input_artifact_count": 307,
        "execution_input_artifacts_sha256": "b" * 64,
        "safety": safety,
        "valid": True,
        "errors": [],
    }
    planner._assign_plan_id(manifest)
    monkeypatch.setattr(planner, "_recompute_operation", lambda _manifest: operation)
    monkeypatch.setattr(planner.base, "_factory_processes", lambda: [])
    monkeypatch.setattr(planner.base, "_git", lambda *_args: commit)
    return manifest, operation, db, flag, commit


def test_apply_is_create_only_and_preserves_excluded_v2_r2(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest, operation, db, flag, commit = _apply_fixture(tmp_path, monkeypatch)
    manifest_path = tmp_path / "plan.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    output_root = Path(manifest["artifact_root"]) / "test-outputs"
    receipt_path = output_root / "prepare-receipt.json"
    snapshot_path = output_root / "before.sqlite"
    receipt = planner.apply_prepare(
        manifest_path=manifest_path,
        expected_manifest_sha256=planner._sha(manifest_path),
        confirm_plan_id=manifest["plan_id"],
        expected_factory_off_sha256=planner._sha(flag),
        expected_db_state_sha256=manifest["db"]["logical_state_sha256"],
        expected_source_commit=commit,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
    )
    assert receipt["no_ladder_progression"] is True
    assert receipt["excluded_v2_r2_before_after"]["unchanged"] is True
    assert snapshot_path.is_file()
    assert receipt_path.is_file()
    with sqlite3.connect(db) as conn:
        created = conn.execute(
            "SELECT status,verdict,claimed_by FROM work_items WHERE id=?",
            (operation["work_item_id"],),
        ).fetchone()
        excluded = conn.execute(
            "SELECT status,verdict,claimed_by,evidence_path FROM work_items WHERE id='v2-r2'"
        ).fetchone()
    assert created == ("pending", None, None)
    assert excluded == ("pending", None, None, None)
    assert not (flag.parent / "FACTORY_MUTATION.lock").exists()
    intent_path = receipt_path.with_name(receipt_path.name + ".intent.json")
    attestation_path = intent_path.with_name(intent_path.name + ".snapshot.json")
    intent = json.loads(intent_path.read_text(encoding="utf-8"))
    assert intent["recovery_policy"] == planner.RECOVERY_POLICY
    assert attestation_path.is_file()

    with pytest.raises(planner.ContractError, match="create-only mutation output"):
        planner.apply_prepare(
            manifest_path=manifest_path,
            expected_manifest_sha256=planner._sha(manifest_path),
            confirm_plan_id=manifest["plan_id"],
            expected_factory_off_sha256=planner._sha(flag),
            expected_db_state_sha256=manifest["db"]["logical_state_sha256"],
            expected_source_commit=commit,
            snapshot_path=snapshot_path,
            receipt_path=receipt_path,
        )


def test_prepare_apply_rejects_relative_outside_and_source_alias_outputs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest, _operation, db, flag, commit = _apply_fixture(tmp_path, monkeypatch)
    manifest_path = tmp_path / "plan.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    allowed = Path(manifest["artifact_root"])
    common = {
        "manifest_path": manifest_path,
        "expected_manifest_sha256": planner._sha(manifest_path),
        "confirm_plan_id": manifest["plan_id"],
        "expected_factory_off_sha256": planner._sha(flag),
        "expected_db_state_sha256": manifest["db"]["logical_state_sha256"],
        "expected_source_commit": commit,
    }
    with pytest.raises(planner.ContractError, match="snapshot path must be absolute"):
        planner.apply_prepare(
            **common,
            snapshot_path=Path("relative.sqlite"),
            receipt_path=(allowed / "out" / "receipt.json").resolve(),
        )
    with pytest.raises(planner.ContractError, match="outside governed"):
        planner.apply_prepare(
            **common,
            snapshot_path=(tmp_path / "outside.sqlite").resolve(),
            receipt_path=(allowed / "out2" / "receipt.json").resolve(),
        )
    protected = (allowed / "bound-input.bin").resolve()
    with pytest.raises(planner.ContractError, match="aliases a source/input"):
        planner._validate_governed_output_paths(
            paths={
                "snapshot": protected,
                "receipt": (allowed / "out3" / "receipt.json").resolve(),
            },
            artifact_root=allowed.resolve(),
            report_root=Path(manifest["report_root"]).resolve(),
            protected_paths=(protected,),
        )
    assert not (flag.parent / "FACTORY_MUTATION.lock").exists()


def test_base_publishers_reject_link_substitution(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    attacker = b'{"attacker":true}\n'

    def substitute_link(_source: object, target: object) -> None:
        Path(target).write_bytes(attacker)

    monkeypatch.setattr(planner.base.os, "link", substitute_link)
    json_target = tmp_path / "target.json"
    with pytest.raises(planner.base.ContractError, match="not the staged file object"):
        planner.base._write_new_json(json_target, {"safe": True})
    assert json_target.read_bytes() == attacker

    source = tmp_path / "source.sqlite"
    with sqlite3.connect(source) as conn:
        conn.execute("CREATE TABLE t(value INTEGER)")
    snapshot = tmp_path / "snapshot.sqlite"
    with pytest.raises(planner.base.ContractError, match="not the staged file object"):
        planner.base.sqlite_snapshot(source, snapshot)
    assert snapshot.read_bytes() == attacker


def test_prepare_snapshot_replacement_before_commit_rolls_back(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest, operation, db, flag, commit = _apply_fixture(tmp_path, monkeypatch)
    manifest_path = tmp_path / "plan.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    output_root = Path(manifest["artifact_root"]) / "guard-test"
    snapshot_path = output_root / "before.sqlite"
    receipt_path = output_root / "receipt.json"
    original = planner._revalidate_snapshot_guard

    def replace_before_commit(handle: object, **kwargs: object) -> None:
        if kwargs.get("checkpoint") == "inside transaction immediately before commit":
            raise planner.ContractError(
                "recovery snapshot binding changed inside transaction immediately before commit"
            )
        original(handle, **kwargs)

    monkeypatch.setattr(planner, "_revalidate_snapshot_guard", replace_before_commit)
    with pytest.raises(planner.ContractError, match="snapshot binding changed"):
        planner.apply_prepare(
            manifest_path=manifest_path,
            expected_manifest_sha256=planner._sha(manifest_path),
            confirm_plan_id=manifest["plan_id"],
            expected_factory_off_sha256=planner._sha(flag),
            expected_db_state_sha256=manifest["db"]["logical_state_sha256"],
            expected_source_commit=commit,
            snapshot_path=snapshot_path,
            receipt_path=receipt_path,
        )
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT 1 FROM work_items WHERE id=?", (operation["work_item_id"],)
        ).fetchone() is None
    assert not receipt_path.exists()


def test_reconcile_prepare_intent_authenticates_committed_state_without_db_write(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest, _operation, db, flag, commit = _apply_fixture(tmp_path, monkeypatch)
    manifest_path = tmp_path / "plan.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    output_root = Path(manifest["artifact_root"]) / "test-outputs"
    receipt_path = output_root / "prepare-receipt.json"
    snapshot_path = output_root / "before.sqlite"
    planner.apply_prepare(
        manifest_path=manifest_path,
        expected_manifest_sha256=planner._sha(manifest_path),
        confirm_plan_id=manifest["plan_id"],
        expected_factory_off_sha256=planner._sha(flag),
        expected_db_state_sha256=manifest["db"]["logical_state_sha256"],
        expected_source_commit=commit,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
    )
    intent_path = receipt_path.with_name(receipt_path.name + ".intent.json")
    attestation_path = intent_path.with_name(intent_path.name + ".snapshot.json")
    receipt_path.unlink()
    post_state = planner.base.sqlite_state_sha256(db)
    physical_before = planner._sha(db)

    reconciled = planner.reconcile_prepare_intent(
        manifest_path=manifest_path,
        expected_manifest_sha256=planner._sha(manifest_path),
        intent_path=intent_path,
        expected_intent_sha256=planner._sha(intent_path),
        expected_snapshot_attestation_sha256=planner._sha(attestation_path),
        confirm_plan_id=manifest["plan_id"],
        expected_factory_off_sha256=planner._sha(flag),
        expected_post_db_state_sha256=post_state,
        expected_source_commit=commit,
        receipt_path=receipt_path,
    )

    assert reconciled["mode"] == "reconcile_only"
    assert reconciled["database_mutated_by_reconcile"] is False
    assert reconciled["post_db_state_sha256"] == post_state
    assert planner.base.sqlite_state_sha256(db) == post_state
    assert planner._sha(db) == physical_before
    assert receipt_path.is_file()
    assert not (flag.parent / "FACTORY_MUTATION.lock").exists()


def test_reconcile_prepare_intent_rejects_intent_hash_or_incomplete_commit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest, operation, db, flag, commit = _apply_fixture(tmp_path, monkeypatch)
    manifest_path = tmp_path / "plan.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    output_root = Path(manifest["artifact_root"]) / "test-outputs"
    receipt_path = output_root / "prepare-receipt.json"
    snapshot_path = output_root / "before.sqlite"
    planner.apply_prepare(
        manifest_path=manifest_path,
        expected_manifest_sha256=planner._sha(manifest_path),
        confirm_plan_id=manifest["plan_id"],
        expected_factory_off_sha256=planner._sha(flag),
        expected_db_state_sha256=manifest["db"]["logical_state_sha256"],
        expected_source_commit=commit,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
    )
    intent_path = receipt_path.with_name(receipt_path.name + ".intent.json")
    attestation_path = intent_path.with_name(intent_path.name + ".snapshot.json")
    intent_sha = planner._sha(intent_path)
    receipt_path.unlink()
    with pytest.raises(planner.ContractError, match="intent SHA-256 mismatch"):
        planner.reconcile_prepare_intent(
            manifest_path=manifest_path,
            expected_manifest_sha256=planner._sha(manifest_path),
            intent_path=intent_path,
            expected_intent_sha256="0" * 64,
            expected_snapshot_attestation_sha256=planner._sha(attestation_path),
            confirm_plan_id=manifest["plan_id"],
            expected_factory_off_sha256=planner._sha(flag),
            expected_post_db_state_sha256=planner.base.sqlite_state_sha256(db),
            expected_source_commit=commit,
            receipt_path=receipt_path,
        )
    with sqlite3.connect(db) as conn:
        conn.execute(
            "DELETE FROM work_item_holds WHERE work_item_id=?",
            (operation["work_item_id"],),
        )
    with pytest.raises(planner.ContractError, match="no complete committed"):
        planner.reconcile_prepare_intent(
            manifest_path=manifest_path,
            expected_manifest_sha256=planner._sha(manifest_path),
            intent_path=intent_path,
            expected_intent_sha256=intent_sha,
            expected_snapshot_attestation_sha256=planner._sha(attestation_path),
            confirm_plan_id=manifest["plan_id"],
            expected_factory_off_sha256=planner._sha(flag),
            expected_post_db_state_sha256=planner.base.sqlite_state_sha256(db),
            expected_source_commit=commit,
            receipt_path=receipt_path,
        )
    assert not receipt_path.exists()


def test_plan_id_binds_validity_and_diagnostics() -> None:
    plan = {
        "schema": planner.SCHEMA_PREPARE,
        "generated_at_utc": "now",
        "valid": False,
        "errors": ["blocked"],
        "operations": [],
    }
    planner._assign_plan_id(plan)
    planner._validate_plan_id(plan)
    plan["valid"] = True
    with pytest.raises(planner.ContractError, match="plan_id mismatch"):
        planner._validate_plan_id(plan)


def test_dry_run_out_is_create_only_and_preserves_existing_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    plan = {
        "schema": planner.SCHEMA_PREPARE,
        "generated_at_utc": "2026-07-30T00:00:00+00:00",
        "valid": True,
        "errors": [],
        "operations": [{"work_item_id": "diagnostic"}],
    }
    planner._assign_plan_id(plan)
    monkeypatch.setattr(planner, "build_prepare_plan", lambda **_kwargs: plan)
    target = (tmp_path / "plan.json").resolve()
    first = planner.main(
        ["--source-commit", "1" * 40, "--out", str(target)]
    )
    assert first == 0
    published = target.read_bytes()
    assert json.loads(published)["plan_id"] == plan["plan_id"]

    second = planner.main(
        ["--source-commit", "1" * 40, "--out", str(target)]
    )
    assert second == 2
    assert target.read_bytes() == published
    assert "JSON target already exists" in capsys.readouterr().err
