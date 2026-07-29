from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import prepare_ftmo_book3_q02 as planner  # noqa: E402


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def _create_db(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items(
              id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL, ea_id TEXT NOT NULL,
              symbol TEXT NOT NULL, setfile_path TEXT NOT NULL, status TEXT NOT NULL,
              verdict TEXT, attempt_count INTEGER NOT NULL DEFAULT 0, parent_task_id TEXT,
              evidence_path TEXT, claimed_by TEXT, payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            );
            CREATE TABLE work_item_holds(
              work_item_id TEXT PRIMARY KEY, hold_code TEXT NOT NULL, reason TEXT NOT NULL,
              active INTEGER NOT NULL, release_on_restart INTEGER NOT NULL, created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL, released_at TEXT, release_note TEXT
            );
            """
        )
        for index in range(9):
            conn.execute(
                "INSERT INTO work_item_holds VALUES (?,?,?,?,?,?,?,NULL,NULL)",
                (f"legacy-{index}", "LEGACY", "preexisting", 1, index % 2, "old", "old"),
            )


def _fixture(tmp_path: Path, monkeypatch) -> dict:
    repo = tmp_path / "repo"
    root = tmp_path / "farm"
    artifact_root = tmp_path / "artifacts"
    report_root = tmp_path / "reports" / "work_items"
    common_qm = tmp_path / "common" / "QM"
    t10_bases = tmp_path / "t10" / "bases"
    calendar_source = tmp_path / "calendar-source"
    calendar_common = common_qm.parent
    monkeypatch.setattr(planner, "DEFAULT_ROOT", root)
    monkeypatch.setattr(planner, "DEFAULT_REPO", repo)
    monkeypatch.setattr(planner, "DEFAULT_ARTIFACT_ROOT", artifact_root)
    monkeypatch.setattr(planner, "DEFAULT_REPORT_ROOT", report_root)
    monkeypatch.setattr(planner, "DEFAULT_COMMON_QM", common_qm)
    monkeypatch.setattr(planner, "DEFAULT_T10_BASES", t10_bases)
    monkeypatch.setattr(planner, "DEFAULT_CALENDAR_SOURCE", calendar_source)
    monkeypatch.setattr(planner, "DEFAULT_CALENDAR_COMMON", calendar_common)
    controller = repo / "tools/strategy_farm/prepare_ftmo_book3_q02.py"
    for name in (
        "terminal_worker.py",
        "isolated_work_item_runner.py",
        "compare_joint_replay.py",
        "farmctl.py",
        "factory_mutation_lock.py",
        "qm_tasks.manifest.ps1",
        "factory_process_scope.ps1",
        "ftmo_book3_fidelity_gate.py",
    ):
        path = repo / "tools/strategy_farm" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"# {name}\n", encoding="utf-8")
    controller.write_text("# controller\n", encoding="utf-8")
    prereg = repo / "docs/ops/evidence/2026-07-29_ftmo_book3_execution_preregistration.md"
    prereg.parent.mkdir(parents=True)
    prereg.write_text("# frozen preregistration\n", encoding="utf-8")
    include = repo / "framework/include/QM"
    include.mkdir(parents=True)
    (include / "QM_Common.mqh").write_text("// common\n", encoding="utf-8")
    phase_utils = repo / "framework/scripts/_phase_utils.py"
    phase_utils.parent.mkdir(parents=True, exist_ok=True)
    phase_utils.write_text("# phase utils\n", encoding="utf-8")

    raw_specs = [
        ("R0", "QM5_9936", "USDJPY.DWX", "H1", "EA_9936", "r0.set", (), None),
        ("J0", "QM5_20181", "USDJPY.DWX", "H1", "EA_20181", "j0.set", ("USDJPY.DWX",), "FTMO_BOOK3_20260729_V1_J0"),
        ("R1", "QM5_10145", "XAUUSD.DWX", "D1", "EA_10145", "r1.set", (), None),
        ("J1", "QM5_20181", "USDJPY.DWX", "H1", "EA_20181", "j1.set", ("USDJPY.DWX", "XAUUSD.DWX"), "FTMO_BOOK3_20260729_V1_J1"),
        ("R2", "QM5_13108", "XTIUSD.DWX", "D1", "EA_13108", "r2.set", (), None),
        ("J2", "QM5_20181", "USDJPY.DWX", "H1", "EA_20181", "j2.set", ("USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX"), "FTMO_BOOK3_20260729_V1_J2"),
    ]
    specs = []
    for code, ea_id, symbol, period, ea_dir_name, set_name, basket_symbols, evidence_run_id in raw_specs:
        ea_dir = repo / "framework/EAs" / ea_dir_name
        sets = ea_dir / "sets"
        sets.mkdir(parents=True, exist_ok=True)
        (ea_dir / f"{ea_dir_name}.mq5").write_text(f"// {ea_dir_name}\n", encoding="utf-8")
        values = ["RISK_FIXED=1000", "RISK_PERCENT=0", "PORTFOLIO_WEIGHT=1"]
        if code.startswith("J"):
            values.extend([
                f"qm_evidence_run_id={evidence_run_id}",
                "qm_stress_reject_probability=0.0",
            ])
            for slot in range(3):
                values.extend([
                    f"s{slot}_enabled={'1' if slot < len(basket_symbols) else '0'}",
                    f"s{slot}_risk_fixed=1000",
                ])
        (sets / set_name).write_text("\n".join(values) + "\n", encoding="utf-8")
        staged = artifact_root / "canonical_staged_ex5" / f"{ea_dir_name}.ex5"
        staged.parent.mkdir(parents=True, exist_ok=True)
        if not staged.exists():
            staged.write_bytes(f"compiled:{ea_dir_name}".encode())
        log = artifact_root / "canonical_compile_logs" / f"{ea_dir_name}.compile.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("Result: 0 errors, 0 warnings\n", encoding="utf-8")
        specs.append({
            "code": code, "ea_id": ea_id, "symbol": symbol, "period": period,
            "ea_dir": ea_dir_name, "set_name": set_name, "ex5_sha256": _sha(staged),
            "evidence_run_id": evidence_run_id,
            "basket_symbols": basket_symbols,
        })
    monkeypatch.setattr(planner, "RUN_SPECS", tuple(specs))
    joint_ex5_sha256 = next(
        spec["ex5_sha256"] for spec in specs if spec["ea_id"] == "QM5_20181"
    )
    registry = repo / "framework/registry/magic_numbers.csv"
    registry.parent.mkdir(parents=True)
    registry.write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "20181,ftmo-joint-multisym-timer,0,USDJPY.DWX,201810000,now,test,active\n"
        "20181,ftmo-joint-multisym-timer,1,XAUUSD.DWX,201810001,now,test,active\n"
        "20181,ftmo-joint-multisym-timer,2,XTIUSD.DWX,201810002,now,test,active\n",
        encoding="utf-8",
    )
    resolver = include / "QM_MagicResolver.mqh"
    resolver.write_text(f'#define QM_MAGIC_REGISTRY_SHA256 "{_sha(registry).upper()}"\n', encoding="utf-8")

    repo_inputs = {
        "framework/scripts/run_smoke.ps1": "# smoke\n",
        "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt": "Spread=0\n",
        "framework/registry/live_commission.json": '{"commission":0}\n',
        "framework/registry/venue_cost_model.json": '{"venue":"Darwinex-Live"}\n',
        "framework/registry/dwx_symbol_matrix.csv": "symbol,venue\nUSDJPY.DWX,Darwinex-Live\n",
    }
    for relative, content in repo_inputs.items():
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    official_snapshot = repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json"
    official_snapshot.parent.mkdir(parents=True, exist_ok=True)
    official_snapshot.write_text('{"schema":"qm.ftmo-official-rules-snapshot/v1"}\n', encoding="utf-8")
    rulepack = repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json"
    rulepack.parent.mkdir(parents=True, exist_ok=True)
    rulepack.write_text(
        json.dumps({
            "official_sources": [{
                "snapshot_path": "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
                "snapshot_sha256": _sha(official_snapshot),
            }]
        }) + "\n",
        encoding="utf-8",
    )

    t10_bases.mkdir(parents=True)
    (t10_bases.parent / "terminal64.exe").write_bytes(b"terminal64")
    (t10_bases.parent / "metatester64.exe").write_bytes(b"metatester64")
    (t10_bases / "symbols.custom.dat").write_bytes(b"symbols")
    for symbol in planner.DATA_SYMBOLS:
        history = t10_bases / "Custom" / "history" / symbol
        ticks = t10_bases / "Custom" / "ticks" / symbol
        history.mkdir(parents=True)
        ticks.mkdir(parents=True)
        for year in range(2018, 2026):
            (history / f"{year}.hcc").write_bytes(f"{symbol}:{year}".encode())
            first_month = 7 if year == 2018 else 1
            for month in range(first_month, 13):
                (ticks / f"{year}{month:02d}.tkc").write_bytes(
                    f"{symbol}:{year}{month:02d}".encode()
                )
    calendar_source.mkdir(parents=True)
    calendar_common.mkdir(parents=True, exist_ok=True)
    for name in planner.CALENDAR_FILES:
        content = f"timestamp,currency,event\n2018-07-02T00:00:00Z,USD,{name}\n"
        (calendar_source / name).write_text(content, encoding="utf-8")
        (calendar_common / name).write_text(content, encoding="utf-8")

    _git(repo, "init")
    _git(repo, "config", "user.email", "tests@example.invalid")
    _git(repo, "config", "user.name", "Tests")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "fixture")
    commit = _git(repo, "rev-parse", "HEAD")

    state = root / "state"
    state.mkdir(parents=True)
    flag = state / "FACTORY_OFF.flag"
    flag.write_bytes(b"intentional-off\n")
    db = state / "farm_state.sqlite"
    _create_db(db)
    monkeypatch.setattr(planner, "_factory_processes", lambda: [])
    monkeypatch.setattr(
        planner, "_calendar_preflight",
        lambda source_dir, common_dir: {"ok": True, "status": "PASS", "source_dir": str(source_dir), "common_dir": str(common_dir)},
    )
    plan = planner.build_prepare_plan(
        source_commit=commit, joint_ex5_sha256=joint_ex5_sha256,
        root=root, repo=repo, artifact_root=artifact_root, report_root=report_root,
        common_qm=common_qm, controller_path=controller,
        t10_bases=t10_bases, calendar_source=calendar_source,
        calendar_common=calendar_common,
    )
    return {
        "repo": repo, "root": root, "artifact_root": artifact_root, "report_root": report_root,
        "common_qm": common_qm, "controller": controller, "commit": commit,
        "joint_ex5_sha256": joint_ex5_sha256,
        "t10_bases": t10_bases, "calendar_source": calendar_source,
        "calendar_common": calendar_common, "flag": flag, "db": db, "plan": plan,
    }


def _write_plan(path: Path, plan: dict) -> str:
    planner._write_new_json(path, plan)
    return _sha(path)


def _apply_prepare(env: dict, tmp_path: Path) -> dict:
    manifest = tmp_path / "prepare-plan.json"
    manifest_sha = _write_plan(manifest, env["plan"])
    return planner.apply_prepare(
        manifest_path=manifest, expected_manifest_sha256=manifest_sha,
        confirm_plan_id=env["plan"]["plan_id"],
        expected_factory_off_sha256=env["plan"]["factory_off"]["sha256"],
        expected_db_state_sha256=env["plan"]["db"]["logical_state_sha256"],
        expected_source_commit=env["commit"], snapshot_path=tmp_path / "prepare.sqlite",
        receipt_path=tmp_path / "prepare-receipt.json",
    )


def _terminalize(env: dict) -> None:
    with sqlite3.connect(env["db"]) as conn:
        conn.executemany(
            "UPDATE work_items SET status='done',verdict='PASS',claimed_by=NULL,updated_at='terminal' WHERE id=?",
            [(operation["work_item_id"],) for operation in env["plan"]["operations"]],
        )


def _fidelity_receipt_value(env: dict, stage: int) -> dict:
    artifacts = {item["role"]: item for item in env["plan"]["artifacts"]}
    pair = env["plan"]["operations"][stage * 2: stage * 2 + 2]
    gate_artifact = artifacts["fidelity_gate"]
    comparator_artifact = artifacts["fidelity_comparator"]
    result = {
        "schema": planner.SCHEMA_FIDELITY,
        "generated_at_utc": f"2026-07-29T12:0{stage}:00+00:00",
        "stage": stage,
        "verdict": "PASS",
        "work_item_ids": {
            "standalone": pair[0]["work_item_id"],
            "joint": pair[1]["work_item_id"],
        },
        "source_commit": env["commit"],
        "execution_input_artifacts_sha256": env["plan"]["execution_input_artifacts_sha256"],
        "controller_path": str(Path(gate_artifact["path"]).resolve()),
        "controller_sha256": gate_artifact["sha256"],
        "controller_bytes": gate_artifact["bytes"],
        "isolated_runner_sha256": artifacts["isolated_runner"]["sha256"],
        "preparation_controller_sha256": artifacts["preparation_controller"]["sha256"],
        "comparator_sha256": comparator_artifact["sha256"],
        "comparator": {
            "path": str(Path(comparator_artifact["path"]).resolve()),
            "sha256": comparator_artifact["sha256"],
            "bytes": comparator_artifact["bytes"],
        },
        "errors": [],
        "contract": {
            "measurement_contract": planner.FIDELITY_MEASUREMENT_CONTRACT,
            "expected_execution_input_count": 307,
            "match_rate_required": 1.0,
            "unmatched_required": 0,
            "both_operands_nonempty": True,
            "money_tolerance": 0.005,
            "volume_tolerance": 0.005,
        },
        "safety": {
            "read_only_inputs": True,
            "create_only_output": True,
            "opens_factory_db": False,
            "runs_mt5": False,
            "mutates_factory_state": False,
            "touches_live_scope": False,
            "touches_autotrading": False,
        },
        "comparison": {
            "algorithm": "maximum_bipartite_exact_time_tolerant_money_volume/v1",
            "money_tolerance": 0.005,
            "volume_tolerance": 0.005,
            "standalone_trades": stage + 1,
            "joint_trades": stage + 1,
            "matched": stage + 1,
            "unmatched_standalone": 0,
            "unmatched_joint": 0,
            "match_rate": 1.0,
            "unmatched_standalone_sample": [],
            "unmatched_joint_sample": [],
        },
        "operands": {
            "standalone": {"work_item_id": pair[0]["work_item_id"]},
            "joint": {"work_item_id": pair[1]["work_item_id"]},
        },
    }
    result["adjudication_id"] = planner._fidelity_adjudication_id(result)
    return result


def _fidelity_receipts(
    env: dict,
    directory: Path,
    *,
    mutate=None,
    prefix: str = "",
) -> list[tuple[int, Path]]:
    directory.mkdir(parents=True, exist_ok=True)
    supplied = []
    for stage in planner.FIDELITY_STAGES:
        value = _fidelity_receipt_value(env, stage)
        if mutate is not None:
            mutate(stage, value)
        path = (directory / f"{prefix}stage-{stage}.fidelity.json").resolve()
        path.write_bytes(planner.canonical_bytes(value))
        supplied.append((stage, path))
    return supplied


def test_prepare_plan_is_exact_six_item_t10_contract(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    plan = env["plan"]
    assert plan["valid"] is True, plan["errors"]
    assert [row["code"] for row in plan["operations"]] == ["R0", "J0", "R1", "J1", "R2", "J2"]
    assert len({row["work_item_id"] for row in plan["operations"]}) == 6
    assert len(plan["artifacts"]) == len({item["role"] for item in plan["artifacts"]})
    assert len(plan["artifacts"]) == len({item["path"].casefold() for item in plan["artifacts"]})
    for row in plan["operations"]:
        assert str(uuid.UUID(row["work_item_id"])) == row["work_item_id"]
        payload = json.loads(row["payload_json"])
        assert payload["terminal"] == "T10"
        assert "T5" in payload["avoid_terminals"] and "T_LIVE" in payload["avoid_terminals"]
        assert payload["model"] == 4
        assert payload["from_date"] == "2018.07.02" and payload["to_date"] == "2025.12.31"
        assert payload["auto_enqueue"] is False and payload["auto_promote"] is False
        expected_evidence_run_id = (
            f"FTMO_BOOK3_20260729_V1_{row['code']}"
            if row["code"].startswith("J")
            else None
        )
        assert payload["evidence_run_id"] == expected_evidence_run_id
        expected_fidelity_stage = (
            None if payload["measurement_sequence"] < 2
            else (payload["measurement_sequence"] // 2) - 1
        )
        assert payload["required_fidelity_stage"] == expected_fidelity_stage
        inputs = payload["execution_input_artifacts"]
        assert len(inputs) == 307
        assert payload["execution_input_artifacts_sha256"] == planner.canonical_sha(inputs)
        assert payload["execution_input_artifacts_sha256"] == plan["execution_input_artifacts_sha256"]
        assert {item["role"] for item in inputs} == planner._required_execution_input_roles()
        assert payload["t10_terminal_binary_path"] == str(env["t10_bases"].parent / "terminal64.exe")
        assert payload["t10_metatester_binary_path"] == str(env["t10_bases"].parent / "metatester64.exe")
        assert payload["live_commission_path"].endswith("live_commission.json")
        assert payload["dwx_symbol_matrix_path"].endswith("dwx_symbol_matrix.csv")
        assert payload["ftmo_official_rules_snapshot_path"].endswith(
            "2026-07-29_ftmo_official_rules_snapshot.json"
        )
        assert payload["isolated_runner_sha256"] == plan["controller_artifacts"]["isolated_runner"]["sha256"]
        assert payload["terminal_worker_sha256"] == plan["controller_artifacts"]["terminal_worker"]["sha256"]
        assert payload["preparation_controller_sha256"] == plan["controller_artifacts"]["preparation_controller"]["sha256"]
        assert [item["role"] for item in payload["runtime_source_artifacts"]] == sorted(
            planner.RUNTIME_SOURCE_ROLES
        )
        assert payload["runtime_source_artifacts_sha256"] == planner.canonical_sha(
            payload["runtime_source_artifacts"]
        )
        assert row["report_root"] == str(env["report_root"] / row["work_item_id"])
        assert row["hold"]["release_on_restart"] == 0


def test_prepare_cli_requires_explicit_source_and_joint_ex5_bindings() -> None:
    with pytest.raises(planner.ContractError, match="--source-commit and --joint-ex5-sha256"):
        planner.main([])
    with pytest.raises(planner.ContractError, match="64 lowercase hexadecimal"):
        planner._bound_run_specs("A" * 64)


def test_joint_payload_uses_legacy_trade_plus_equity_batch_contract(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    for row in env["plan"]["operations"]:
        payload = json.loads(row["payload_json"])
        assert payload["post_run_file_common_source"].endswith(".jsonl")
        if row["code"].startswith("J"):
            assert payload["post_run_file_common_streams"] == [{
                "stream_type": "q08_equity",
                "source": str(env["common_qm"] / "q08_equity" / "20181_USDJPY_DWX.jsonl"),
            }]
        else:
            assert payload["post_run_file_common_streams"] == []


def test_prepare_apply_creates_only_six_pending_rows_and_nonreleasing_holds(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    flag_before = env["flag"].read_bytes()
    receipt = _apply_prepare(env, tmp_path)
    assert receipt["factory_remains_off"] is True
    assert Path(receipt["mutation_intent"]["path"]).is_file()
    assert _sha(Path(receipt["mutation_intent"]["path"])) == receipt["mutation_intent"]["sha256"]
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 6
        assert conn.execute("SELECT COUNT(*) FROM work_items WHERE status='pending' AND verdict IS NULL AND claimed_by IS NULL").fetchone()[0] == 6
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=1 AND release_on_restart=0", (planner.HOLD_CODE,)).fetchone()[0] == 6
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE hold_code='LEGACY' AND active=1").fetchone()[0] == 9
    assert env["flag"].read_bytes() == flag_before


def test_prepare_apply_rejects_artifact_drift_before_database_mutation(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    manifest = tmp_path / "prepare-plan.json"
    manifest_sha = _write_plan(manifest, env["plan"])
    Path(env["plan"]["operations"][0]["setfile_path"]).write_text("drift\n", encoding="utf-8")
    with pytest.raises(
        planner.ContractError,
        match="artifact drift|R0 RISK_FIXED|execution source differs",
    ):
        planner.apply_prepare(
            manifest_path=manifest, expected_manifest_sha256=manifest_sha,
            confirm_plan_id=env["plan"]["plan_id"],
            expected_factory_off_sha256=env["plan"]["factory_off"]["sha256"],
            expected_db_state_sha256=env["plan"]["db"]["logical_state_sha256"],
            expected_source_commit=env["commit"], snapshot_path=tmp_path / "snapshot.sqlite",
            receipt_path=tmp_path / "receipt.json",
        )
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0


def test_prepare_plan_fails_closed_on_existing_content_addressed_row(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    first = env["plan"]["operations"][0]
    with sqlite3.connect(env["db"]) as conn:
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,'now','now')",
            (first["work_item_id"], "backtest", "Q02", first["ea_id"], first["symbol"], first["setfile_path"], first["payload_json"]),
        )
    plan = planner.build_prepare_plan(
        source_commit=env["commit"], joint_ex5_sha256=env["joint_ex5_sha256"],
        root=env["root"], repo=env["repo"], artifact_root=env["artifact_root"],
        report_root=env["report_root"], common_qm=env["common_qm"],
        controller_path=env["controller"],
        t10_bases=env["t10_bases"], calendar_source=env["calendar_source"],
        calendar_common=env["calendar_common"],
    )
    assert plan["valid"] is False
    assert any("already exist" in error for error in plan["errors"])


def test_release_plan_requires_every_row_terminal(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    release = planner.build_release_plan(env["plan"])
    assert release["valid"] is False
    assert len([error for error in release["errors"] if "not done/PASS" in error]) == 6


def test_release_apply_deactivates_only_own_six_holds(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    fidelity_receipts = _fidelity_receipts(env, tmp_path / "fidelity")
    release = planner.build_release_plan(env["plan"], fidelity_receipts)
    assert release["valid"] is True, release["errors"]
    assert [item["stage"] for item in release["fidelity_adjudications"]] == [0, 1, 2]
    manifest = tmp_path / "release-plan.json"
    manifest_sha = _write_plan(manifest, release)
    receipt = planner.apply_release(
        manifest_path=manifest, expected_manifest_sha256=manifest_sha,
        confirm_plan_id=release["plan_id"], expected_factory_off_sha256=release["factory_off"]["sha256"],
        expected_db_state_sha256=release["db"]["logical_state_sha256"],
        snapshot_path=tmp_path / "release.sqlite", receipt_path=tmp_path / "release-receipt.json",
    )
    assert len(receipt["released_holds"]) == 6
    assert receipt["fidelity_adjudications"] == release["fidelity_adjudications"]
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=0", (planner.HOLD_CODE,)).fetchone()[0] == 6
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE hold_code='LEGACY' AND active=1").fetchone()[0] == 9


def test_rehashed_release_manifest_cannot_target_a_preexisting_hold(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    release = planner.build_release_plan(
        env["plan"], _fidelity_receipts(env, tmp_path / "fidelity")
    )
    release["operations"][0]["work_item_id"] = "legacy-0"
    release["authorized_work_item_ids"][0] = "legacy-0"
    planner._assign_plan_id(release)
    planner._validate_plan_id(release)
    with pytest.raises(planner.ContractError, match="authorized work-item IDs"):
        planner._validate_release_operations(release)


def test_release_apply_rejects_db_drift_and_releases_nothing(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    release = planner.build_release_plan(
        env["plan"], _fidelity_receipts(env, tmp_path / "fidelity")
    )
    manifest = tmp_path / "release-plan.json"
    manifest_sha = _write_plan(manifest, release)
    with sqlite3.connect(env["db"]) as conn:
        conn.execute("UPDATE work_items SET updated_at='drift' WHERE id=(SELECT id FROM work_items LIMIT 1)")
    with pytest.raises(planner.ContractError, match="DB logical state"):
        planner.apply_release(
            manifest_path=manifest, expected_manifest_sha256=manifest_sha,
            confirm_plan_id=release["plan_id"], expected_factory_off_sha256=release["factory_off"]["sha256"],
            expected_db_state_sha256=release["db"]["logical_state_sha256"],
            snapshot_path=tmp_path / "release.sqlite", receipt_path=tmp_path / "release-receipt.json",
        )
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=1", (planner.HOLD_CODE,)).fetchone()[0] == 6


def test_release_plan_requires_exactly_three_receipts_in_stage_order(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    receipts = _fidelity_receipts(env, tmp_path / "fidelity")

    missing = planner.build_release_plan(env["plan"], receipts[:2])
    assert missing["valid"] is False
    assert any("exactly three fidelity receipts" in error for error in missing["errors"])

    duplicate = planner.build_release_plan(
        env["plan"], [receipts[0], receipts[1], (1, receipts[2][1])]
    )
    assert duplicate["valid"] is False
    assert any("stage order 0,1,2" in error for error in duplicate["errors"])

    reordered = planner.build_release_plan(
        env["plan"], [receipts[1], receipts[0], receipts[2]]
    )
    assert reordered["valid"] is False
    assert any("stage order 0,1,2" in error for error in reordered["errors"])


def test_release_plan_independently_rejects_invalid_adjudication_identity(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)

    cases = [
        (
            "fail",
            lambda stage, value: value.update({"verdict": "FAIL", "errors": ["mismatch"]})
            if stage == 0 else None,
            "verdict mismatch",
        ),
        (
            "work-id",
            lambda stage, value: value["work_item_ids"].update({"joint": str(uuid.uuid4())})
            if stage == 1 else None,
            "work_item_ids mismatch",
        ),
        (
            "source",
            lambda stage, value: value.update({"source_commit": "f" * 40})
            if stage == 2 else None,
            "source_commit mismatch",
        ),
        (
            "controller-hash",
            lambda stage, value: value.update({"controller_sha256": "f" * 64})
            if stage == 0 else None,
            "controller_sha256 mismatch",
        ),
        (
            "runner-hash",
            lambda stage, value: value.update({"isolated_runner_sha256": "e" * 64})
            if stage == 1 else None,
            "isolated_runner_sha256 mismatch",
        ),
        (
            "comparator-hash",
            lambda stage, value: value.update({"comparator_sha256": "d" * 64})
            if stage == 2 else None,
            "comparator_sha256 mismatch",
        ),
        (
            "comparison",
            lambda stage, value: value["comparison"].update({"unmatched_joint": 1})
            if stage == 0 else None,
            "comparison.unmatched_joint mismatch",
        ),
        (
            "adjudication-id",
            lambda stage, value: value.update({"adjudication_id": "0" * 64})
            if stage == 1 else None,
            "adjudication_id mismatch",
        ),
    ]
    for prefix, mutate, expected_error in cases:
        receipts = _fidelity_receipts(
            env, tmp_path / "invalid-fidelity", mutate=mutate, prefix=f"{prefix}-"
        )
        release = planner.build_release_plan(env["plan"], receipts)
        assert release["valid"] is False, prefix
        assert any(expected_error in error for error in release["errors"]), release["errors"]
        assert release["fidelity_adjudications"] == []


def test_release_plan_rejects_duplicate_json_and_aliased_paths(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)

    duplicate_json = _fidelity_receipts(
        env, tmp_path / "duplicate-json", prefix="duplicate-"
    )
    duplicate_json[0][1].write_bytes(b'{"schema":"first","schema":"second"}')
    release = planner.build_release_plan(env["plan"], duplicate_json)
    assert release["valid"] is False
    assert any("duplicate JSON key: schema" in error for error in release["errors"])

    relative = _fidelity_receipts(env, tmp_path / "relative", prefix="relative-")
    relative[0] = (0, Path(relative[0][1].name))
    release = planner.build_release_plan(env["plan"], relative)
    assert release["valid"] is False
    assert any("path must be absolute" in error for error in release["errors"])

    hardlinked = _fidelity_receipts(env, tmp_path / "hardlink", prefix="hardlink-")
    alias = hardlinked[0][1].with_name("stage-0-alias.json")
    alias.hardlink_to(hardlinked[0][1])
    try:
        release = planner.build_release_plan(env["plan"], hardlinked)
        assert release["valid"] is False
        assert any("exactly one filesystem link" in error for error in release["errors"])
    finally:
        alias.unlink()


def test_release_apply_revalidates_receipt_bytes_before_any_hold_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    fidelity_receipts = _fidelity_receipts(env, tmp_path / "fidelity")
    release = planner.build_release_plan(env["plan"], fidelity_receipts)
    assert release["valid"] is True, release["errors"]
    manifest = tmp_path / "release-plan.json"
    manifest_sha = _write_plan(manifest, release)
    fidelity_receipts[2][1].write_bytes(fidelity_receipts[2][1].read_bytes() + b"\n")

    with pytest.raises(planner.ContractError, match="bindings drifted"):
        planner.apply_release(
            manifest_path=manifest,
            expected_manifest_sha256=manifest_sha,
            confirm_plan_id=release["plan_id"],
            expected_factory_off_sha256=release["factory_off"]["sha256"],
            expected_db_state_sha256=release["db"]["logical_state_sha256"],
            snapshot_path=tmp_path / "release.sqlite",
            receipt_path=tmp_path / "release-receipt.json",
        )
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=1",
            (planner.HOLD_CODE,),
        ).fetchone()[0] == 6


def test_release_plan_id_and_runtime_validator_bind_full_normalized_receipt(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    _apply_prepare(env, tmp_path)
    _terminalize(env)
    release = planner.build_release_plan(
        env["plan"], _fidelity_receipts(env, tmp_path / "fidelity")
    )
    assert release["valid"] is True, release["errors"]
    release["fidelity_adjudications"][0]["normalized_identity"]["contract"][
        "money_tolerance"
    ] = 0.006
    with pytest.raises(planner.ContractError, match="plan_id mismatch"):
        planner._validate_plan_id(release)
    planner._assign_plan_id(release)
    with pytest.raises(planner.ContractError, match="bindings drifted"):
        planner._validate_release_operations(release)


def test_plan_id_detects_manifest_tampering(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    env["plan"]["operations"][0]["symbol"] = "EURUSD.DWX"
    with pytest.raises(planner.ContractError, match="plan_id mismatch"):
        planner._validate_plan_id(env["plan"])


def test_plan_id_binds_validity_and_diagnostics(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    env["plan"]["valid"] = False
    env["plan"]["errors"] = ["tampered"]
    with pytest.raises(planner.ContractError, match="plan_id mismatch"):
        planner._validate_plan_id(env["plan"])


def test_rehashed_manifest_cannot_pair_canonical_db_with_fake_off_flag(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    fake_flag = tmp_path / "fake" / "FACTORY_OFF.flag"
    fake_flag.parent.mkdir()
    fake_flag.write_bytes(env["flag"].read_bytes())
    env["plan"]["factory_off"] = {
        "path": str(fake_flag),
        "sha256": _sha(fake_flag),
    }
    planner._assign_plan_id(env["plan"])
    with pytest.raises(planner.ContractError, match="canonical topology mismatch for flag"):
        planner._validate_prepare_operations(env["plan"])


def test_preexisting_receipt_blocks_before_prepare_db_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    manifest = tmp_path / "prepare-plan.json"
    manifest_sha = _write_plan(manifest, env["plan"])
    receipt_path = tmp_path / "receipt.json"
    receipt_path.write_text("preexisting\n", encoding="utf-8")
    with pytest.raises(planner.ContractError, match="reserved output target already exists"):
        planner.apply_prepare(
            manifest_path=manifest,
            expected_manifest_sha256=manifest_sha,
            confirm_plan_id=env["plan"]["plan_id"],
            expected_factory_off_sha256=env["plan"]["factory_off"]["sha256"],
            expected_db_state_sha256=env["plan"]["db"]["logical_state_sha256"],
            expected_source_commit=env["commit"],
            snapshot_path=tmp_path / "snapshot.sqlite",
            receipt_path=receipt_path,
        )
    with sqlite3.connect(env["db"]) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0


def test_rehashed_manifest_cannot_enable_auto_enqueue(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    payload = json.loads(env["plan"]["operations"][0]["payload_json"])
    payload["auto_enqueue"] = True
    env["plan"]["operations"][0]["payload_json"] = json.dumps(
        payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    planner._assign_plan_id(env["plan"])
    planner._validate_plan_id(env["plan"])
    with pytest.raises(planner.ContractError, match="auto_enqueue"):
        planner._validate_prepare_operations(env["plan"])


def test_invalid_set_plan_cannot_be_made_applicable_by_flipping_valid(
    tmp_path: Path, monkeypatch
) -> None:
    env = _fixture(tmp_path, monkeypatch)
    set_path = Path(env["plan"]["operations"][0]["setfile_path"])
    set_path.write_text(
        "RISK_FIXED=4000\nRISK_PERCENT=0\nPORTFOLIO_WEIGHT=1\n",
        encoding="utf-8",
    )
    invalid = planner.build_prepare_plan(
        source_commit=env["commit"],
        joint_ex5_sha256=env["joint_ex5_sha256"],
        root=env["root"], repo=env["repo"], artifact_root=env["artifact_root"],
        report_root=env["report_root"], common_qm=env["common_qm"],
        controller_path=env["controller"], t10_bases=env["t10_bases"],
        calendar_source=env["calendar_source"],
        calendar_common=env["calendar_common"],
    )
    assert invalid["valid"] is False
    assert invalid["operations"] == []
    invalid["valid"] = True
    invalid["errors"] = []
    planner._assign_plan_id(invalid)
    with pytest.raises(planner.ContractError, match="exact six-item"):
        planner._validate_prepare_operations(invalid)


def test_rehashed_manifest_cannot_change_execution_input_list(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    payload = json.loads(env["plan"]["operations"][0]["payload_json"])
    payload["execution_input_artifacts"][0]["bytes"] += 1
    payload["execution_input_artifacts_sha256"] = planner.canonical_sha(
        payload["execution_input_artifacts"]
    )
    env["plan"]["operations"][0]["payload_json"] = json.dumps(
        payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    planner._assign_plan_id(env["plan"])
    with pytest.raises(planner.ContractError, match="execution_input_artifacts"):
        planner._validate_prepare_operations(env["plan"])


def test_prepare_plan_fails_closed_when_one_t10_tick_is_missing(tmp_path: Path, monkeypatch) -> None:
    env = _fixture(tmp_path, monkeypatch)
    missing = env["t10_bases"] / "Custom/ticks/USDJPY.DWX/201807.tkc"
    missing.unlink()
    plan = planner.build_prepare_plan(
        source_commit=env["commit"], joint_ex5_sha256=env["joint_ex5_sha256"],
        root=env["root"], repo=env["repo"], artifact_root=env["artifact_root"],
        report_root=env["report_root"], common_qm=env["common_qm"],
        controller_path=env["controller"],
        t10_bases=env["t10_bases"], calendar_source=env["calendar_source"],
        calendar_common=env["calendar_common"],
    )
    assert plan["valid"] is False
    assert plan["operations"] == []
    assert any("ticks:USDJPY.DWX:201807" in error for error in plan["errors"])
