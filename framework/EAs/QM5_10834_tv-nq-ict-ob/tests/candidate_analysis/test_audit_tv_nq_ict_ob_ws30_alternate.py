from __future__ import annotations

import copy
import importlib.util
import inspect
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = (
    EA_ROOT
    / "tools"
    / "candidate_analysis"
    / "audit_tv_nq_ict_ob_ws30_alternate.py"
)


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


subject = _load("audit_tv_nq_ict_ob_ws30_alternate_test", TOOL)


def _git_result(
    returncode: int, stdout: str = "", stderr: str = ""
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=["git"], returncode=returncode, stdout=stdout, stderr=stderr
    )


def test_alternate_contract_is_hash_bound_and_semantically_valid() -> None:
    contract = subject.validate_alternate_contract()
    assert contract["status"] == (
        "IMPLEMENTED_NOT_MATERIALIZED_NOT_AUTHORIZED_NOT_LAUNCHED"
    )
    assert contract["attempt"] == {
        "type": "PREREGISTERED_SINGLE_INFRASTRUCTURE_ALTERNATE",
        "attempt_number": 2,
        "maximum_total_attempts": 2,
        "further_attempts_forbidden": True,
        "execution_lane": "DEV2",
        "resume_forbidden": True,
        "terminal_hopping_forbidden": True,
    }
    assert contract["identical_evidence_contract"]["gate_relaxation_forbidden"] is True
    assert contract["outcome_fence"][
        "primary_controller_stderr_content_must_not_be_read"
    ] is True
    assert contract["immutable_runtime"][
        "runtime_relocation_requires_byte_identical_repository_relative_files"
    ] is True
    assert contract["immutable_runtime"][
        "alternate_pre_and_worker_must_not_open_main_worktree_evidence_files"
    ] is True


def test_primary_contract_absolute_origin_paths_are_parser_only_and_restored(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime_ea = tmp_path / "runtime" / "framework" / "EAs" / "candidate"
    runtime_build = (
        runtime_ea / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
    )
    monkeypatch.setattr(subject, "EA_ROOT", runtime_ea)
    monkeypatch.setattr(subject.W, "EA_ROOT", runtime_ea)
    monkeypatch.setattr(subject.W, "BUILD_RECEIPT_PATH", runtime_build)
    monkeypatch.setattr(subject, "validate_alternate_contract", lambda: {})
    monkeypatch.setattr(
        subject, "validate_frozen_gate_and_auditor_identity", lambda: None
    )
    bound_paths: list[Path] = []

    def fake_binding(path: Path, _expected: str | None = None):
        bound_paths.append(Path(path))
        return {"path": str(path), "size": 1, "sha256": "0" * 64}

    def fake_primary_parser(path: Path):
        assert subject.W.EA_ROOT == subject.MAIN_EA_ROOT
        assert subject.W.BUILD_RECEIPT_PATH == (
            subject.MAIN_EA_ROOT
            / "docs"
            / "candidate-analysis"
            / "build_receipt_20260720.json"
        )
        assert path == subject.W.CONTRACT_PATH
        return {"status": "PREREGISTERED_UNTOUCHED_EVIDENCE"}

    monkeypatch.setattr(subject.B, "file_binding", fake_binding)
    monkeypatch.setattr(subject.W, "validate_transport_contract", fake_primary_parser)
    result = subject.validate_relocated_primary_transport_contract()
    assert result["status"] == "PREREGISTERED_UNTOUCHED_EVIDENCE"
    assert bound_paths == [
        runtime_build,
        runtime_ea
        / "sets"
        / "QM5_10834_tv-nq-ict-ob_WS30.DWX_M5_backtest.set",
    ]
    assert subject.W.EA_ROOT == runtime_ea
    assert subject.W.BUILD_RECEIPT_PATH == runtime_build


def test_frozen_merit_and_auditor_identity_is_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    subject.validate_frozen_gate_and_auditor_identity()
    changed = copy.deepcopy(subject.B.MERIT_GATES)
    changed["dev"]["minimum_trades"] += 1
    monkeypatch.setattr(subject.B, "MERIT_GATES", changed)
    with pytest.raises(subject.B.InvalidEvidence, match="merit contract drift"):
        subject.validate_frozen_gate_and_auditor_identity()


def test_actual_frozen_data_receipt_projects_only_six_approved_repo_bindings() -> None:
    raw = subject.B.load_json(subject.W.FUTURE_DATA_RECEIPT_PATH)
    projected = subject._project_data_receipt_repo_bindings(raw)
    assert projected["artifact_type"] == raw["artifact_type"]
    assert projected["factory_evidence"]["matrix"]["sha256"] == (
        raw["factory_evidence"]["matrix"]["sha256"]
    )
    assert projected["cost_schedule"]["supplemental_stress"]["slippage"][
        "source"
    ]["sha256"] == raw["cost_schedule"]["supplemental_stress"]["slippage"][
        "source"
    ]["sha256"]


def test_relocated_data_validator_binds_exact_attempt001_receipt() -> None:
    validated = subject.validate_relocated_backtest_data_receipt(
        subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
    )
    assert validated["receipt"] == {
        "path": str(subject.W.FUTURE_DATA_RECEIPT_PATH.resolve()),
        "size": subject.EXPECTED_DATA_RECEIPT_SIZE,
        "sha256": subject.EXPECTED_DATA_RECEIPT_SHA256,
    }


def test_relocated_data_validator_rejects_receipt_toctou(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        subject,
        "_BASE_VALIDATE_BACKTEST_DATA_RECEIPT",
        lambda *_args, **_kwargs: {
            "receipt": {
                "path": str(subject.W.FUTURE_DATA_RECEIPT_PATH.resolve()),
                "size": subject.EXPECTED_DATA_RECEIPT_SIZE,
                "sha256": "1" * 64,
            }
        },
    )
    with pytest.raises(subject.B.InvalidEvidence, match="changed during"):
        subject.validate_relocated_backtest_data_receipt(
            subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
        )


def test_data_receipt_validator_accepts_only_byte_identical_detached_projection(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = tmp_path / "runtime"
    relative_paths = (
        Path("framework/V5_FRAMEWORK_DESIGN.md"),
        Path("framework/registry/execution_symbol_aliases_v1.json"),
        Path("framework/registry/venue_cost_model.json"),
        Path("framework/registry/dwx_symbol_matrix.csv"),
        Path("framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"),
    )
    for relative in relative_paths:
        target = runtime / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(subject.MAIN_WORKTREE_ROOT / relative, target)
    monkeypatch.setattr(subject, "REPO_ROOT", runtime)
    monkeypatch.setattr(
        subject.B, "V5_FRAMEWORK_PATH", runtime / relative_paths[0]
    )
    monkeypatch.setattr(subject.B, "ALIASES_PATH", runtime / relative_paths[1])
    monkeypatch.setattr(subject.B, "COST_PATH", runtime / relative_paths[2])
    monkeypatch.setattr(subject.B, "MATRIX_PATH", runtime / relative_paths[3])
    monkeypatch.setattr(
        subject.W, "SLIPPAGE_CALIBRATION_PATH", runtime / relative_paths[4]
    )
    validated = subject.validate_relocated_backtest_data_receipt(
        subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
    )
    assert Path(validated["factory_evidence"]["matrix"]["path"]) == (
        runtime / relative_paths[3]
    )
    assert Path(
        validated["cost_schedule"]["supplemental_stress"]["slippage"][
            "source"
        ]["path"]
    ) == (runtime / relative_paths[4])

    (runtime / relative_paths[3]).write_bytes(b"tampered")
    with pytest.raises(subject.B.InvalidEvidence):
        subject.validate_relocated_backtest_data_receipt(
            subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
        )


def test_data_receipt_projection_rejects_unapproved_main_repo_path() -> None:
    raw = subject.B.load_json(subject.W.FUTURE_DATA_RECEIPT_PATH)
    raw["unexpected_binding"] = {
        "path": str(subject.MAIN_WORKTREE_ROOT / "unexpected.txt"),
        "size": 1,
        "sha256": "0" * 64,
    }
    with pytest.raises(subject.B.InvalidEvidence, match="unapproved"):
        subject._project_data_receipt_repo_bindings(raw)


def test_bound_repository_byte_overlay_preserves_mixed_eol_exactly(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    runtime = tmp_path / "runtime"
    source.mkdir()
    runtime.mkdir()
    (source / "a.txt").write_bytes(b"one\r\ntwo\r\n")
    (source / "b.txt").write_bytes(b"three\nfour\n")
    (runtime / "a.txt").write_bytes(b"one\ntwo\n")
    (runtime / "b.txt").write_bytes(b"three\r\nfour\r\n")
    relatives = ("a.txt", "b.txt")
    subject._overlay_exact_repository_binding_bytes(source, runtime, relatives)
    assert (runtime / "a.txt").read_bytes() == (source / "a.txt").read_bytes()
    assert (runtime / "b.txt").read_bytes() == (source / "b.txt").read_bytes()
    ledger = subject._build_repository_byte_identity_ledger(
        source, runtime, relatives
    )
    assert [row["relative_path"] for row in ledger] == list(relatives)

    monkeypatch.setattr(subject, "REPO_ROOT", runtime)
    monkeypatch.setattr(
        subject,
        "_repository_binding_relative_paths",
        lambda _root=runtime: relatives,
    )
    subject._validate_runtime_repository_binding_ledger(ledger)
    (runtime / "a.txt").write_bytes(b"one\ntwo\n")
    with pytest.raises(subject.B.InvalidEvidence):
        subject._validate_runtime_repository_binding_ledger(ledger)


def test_runtime_dependency_closure_includes_all_pre_and_recursive_include_roles() -> None:
    relatives = subject._repository_binding_relative_paths()
    assert len(relatives) == 53
    assert (
        "framework/EAs/QM5_10834_tv-nq-ict-ob/tools/candidate_analysis/"
        "audit_tv_nq_ict_ob_ws30_alternate.py"
    ) in relatives
    assert "framework/include/QM/QM_Common.mqh" in relatives
    assert "framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json" in relatives


def test_materializer_overlays_exact_bound_bytes_before_sealing_ledger() -> None:
    source = inspect.getsource(subject.materialize_runtime)
    checkout = source.index('"worktree"')
    overlay = source.index("_overlay_exact_repository_binding_bytes")
    final_clean = source.index(
        '"alternate runtime worktree after exact byte overlay"'
    )
    ledger = source.index("_build_repository_byte_identity_ledger")
    receipt = source.index("B.atomic_json")
    assert checkout < overlay < final_clean < ledger < receipt
    assert "core.autocrlf=false" not in source


@pytest.mark.skipif(
    not subject.PRIMARY_STATE_PATH.is_file(), reason="VPS primary control state absent"
)
def test_primary_invalid_infra_closure_revalidates_without_opening_any_log(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    opened_json: list[Path] = []
    original = subject.B.load_json

    def guarded_load_json(path: Path):
        observed = Path(path)
        if observed.suffix.casefold() == ".log":
            raise AssertionError("controller/probe log content must remain opaque")
        opened_json.append(observed.resolve())
        return original(path)

    monkeypatch.setattr(subject.B, "load_json", guarded_load_json)
    closure = subject.validate_primary_invalid_infra_closure()
    assert closure["status"] == "PRIMARY_INVALID_INFRA_CLOSED_NO_OUTCOME_READ"
    assert closure["allowed_alternate_cause_class"] == (
        "DEV2_CONTROLLER_FAILED_BEFORE_NATIVE_REPORT"
    )
    assert closure["directory_metadata_closure"]["native_report_file_count"] == 0
    assert closure["directory_metadata_closure"]["native_outcome_file_count"] == 0
    assert opened_json == [
        subject.PRIMARY_CLOSURE_PATH.resolve(),
        subject.PRIMARY_STATE_PATH.resolve(),
    ]


def test_primary_closure_implementation_never_semantically_reads_logs() -> None:
    source = inspect.getsource(subject.validate_primary_invalid_infra_closure)
    assert ".read_text(" not in source
    assert ".read_bytes(" not in source
    assert ".open(" not in source
    assert "B.load_json(PRIMARY_STATE_PATH)" in source
    assert "controller.stderr.log" not in source


def test_primary_closed_file_ledger_contains_only_control_and_opaque_logs() -> None:
    paths = [row[0] for row in subject.PRIMARY_EXPECTED_FILE_LEDGER]
    assert len(paths) == 9
    assert not any(Path(path).suffix.casefold() in {".htm", ".html"} for path in paths)
    assert not any(Path(path).name.casefold() == "summary.json" for path in paths)
    native = [path for path in paths if path.startswith("native\\")]
    assert native == [
        r"native\DEV\controller.stderr.log",
        r"native\DEV\controller.stdout.log",
    ]


def test_alternate_has_separate_one_shot_namespace_and_claim_profile() -> None:
    assert subject.ALTERNATE_RUN_ROOT != subject.W.PRIMARY_RUN_ROOT
    assert subject.ALTERNATE_PRE_RECEIPT_PATH.parent == subject.ALTERNATE_RUN_ROOT
    assert subject.ALTERNATE_CLAIM_PATH != subject.PRIMARY_CLAIM_PATH
    assert subject.ALTERNATE_CLAIM_PATH.name.endswith("ATTEMPT_002.json")
    assert subject.ALTERNATE_AUTHORIZATION_PATH.parent == subject.ALTERNATE_RUN_ROOT
    assert subject.B.CURRENT_CLAIM_SEQUENCE == 2
    assert subject.B.PRIOR_CLAIM_SEQUENCES == 1
    assert subject.B.PRIOR_COUNTED_ALTERNATE_ATTEMPTS == 0
    assert subject.B.AUTHORIZATION_SCOPE == subject.ALTERNATE_AUTHORIZATION_SCOPE
    contract = subject.execution_contract()
    assert contract["current_attempt_type"] == (
        "PREREGISTERED_INFRA_ALTERNATE_ONE_SHOT"
    )
    assert contract["current_attempt_number"] == 2
    assert contract["maximum_total_counted_attempts"] == 2
    assert contract["resume_permitted"] is False
    assert contract["further_attempts_forbidden"] is True


def test_alternate_runtime_binds_every_imported_and_execution_dependency() -> None:
    paths = subject._expected_binding_paths("WS30.DWX")
    for role in (
        "tool",
        "base_tool",
        "ws30_primary_adapter",
        "alternate_contract",
        "primary_invalid_infra_closure",
        "alternate_runtime_materialization_receipt",
        "runner",
        "runner_child",
        "scheduled_task_helper",
    ):
        assert role in subject.B.REQUIRED_BINDING_ROLES
        assert role in paths
    assert paths["tool"].resolve() == subject.TOOL_PATH.resolve()
    assert paths["ws30_primary_adapter"].resolve() == (
        subject.PRIMARY_ADAPTER_PATH.resolve()
    )


def test_runtime_clean_head_rejects_dirty_or_attached_worktree(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()
    head = "a" * 40

    def dirty_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("status", "--porcelain=v1", "--untracked-files=all"):
            return _git_result(0, " M moving_runtime.py\n")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", dirty_git)
    with pytest.raises(subject.B.InvalidEvidence, match="dirty"):
        subject._clean_head(root, "runtime", detached_required=True)

    def attached_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("status", "--porcelain=v1", "--untracked-files=all"):
            return _git_result(0)
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args == ("symbolic-ref", "-q", "HEAD"):
            return _git_result(0, "refs/heads/main\n")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", attached_git)
    with pytest.raises(subject.B.InvalidEvidence, match="detached"):
        subject._clean_head(root, "runtime", detached_required=True)


def test_runtime_clean_head_accepts_only_clean_detached_exact_root(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()
    head = "b" * 40

    def fake_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("status", "--porcelain=v1", "--untracked-files=all"):
            return _git_result(0)
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args == ("symbolic-ref", "-q", "HEAD"):
            return _git_result(1)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", fake_git)
    assert subject._clean_head(root, "runtime", detached_required=True) == head


def test_pre_fails_on_dirty_main_before_runtime_or_base_preflight(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    called = {"runtime": False, "base": False}

    def dirty(_stage: str):
        raise subject.B.InvalidEvidence("main worktree at alternate PRE is dirty")

    def forbidden_runtime():
        called["runtime"] = True
        raise AssertionError("runtime inspection must follow clean-main gate")

    def forbidden_base(*_args, **_kwargs):
        called["base"] = True
        raise AssertionError("base PRE must follow clean-main gate")

    monkeypatch.setattr(subject, "assert_main_worktree_clean", dirty)
    monkeypatch.setattr(subject, "_assert_runtime_location", forbidden_runtime)
    monkeypatch.setattr(subject, "_BASE_PREFLIGHT", forbidden_base)
    with pytest.raises(subject.B.InvalidEvidence, match="dirty"):
        subject.preflight(
            "WS30.DWX",
            subject.W.FUTURE_DATA_RECEIPT_PATH,
            subject.W.BUILD_RECEIPT_PATH,
            subject.ALTERNATE_RUN_ROOT,
        )
    assert called == {"runtime": False, "base": False}


def test_pre_readiness_failure_does_not_consume_canonical_receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    run_root = tmp_path / "alternate-run"
    receipt = run_root / "pre_receipt.json"
    data_receipt = tmp_path / "data.json"
    build_receipt = tmp_path / "build.json"
    monkeypatch.setattr(subject, "ALTERNATE_RUN_ROOT", run_root)
    monkeypatch.setattr(subject, "ALTERNATE_PRE_RECEIPT_PATH", receipt)
    monkeypatch.setattr(subject.W, "FUTURE_DATA_RECEIPT_PATH", data_receipt)
    monkeypatch.setattr(subject.W, "BUILD_RECEIPT_PATH", build_receipt)

    def fail_closed(*_args, **_kwargs):
        raise subject.B.InvalidEvidence("main worktree is dirty")

    monkeypatch.setattr(subject, "preflight", fail_closed)
    code = subject.main(
        [
            "pre",
            "--symbol",
            "WS30.DWX",
            "--data-receipt",
            str(data_receipt),
            "--build-receipt",
            str(build_receipt),
            "--run-root",
            str(run_root),
            "--receipt",
            str(receipt),
        ]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert "dirty" in captured.err
    assert not receipt.exists()
    assert not run_root.exists()


def test_materialization_refuses_dirty_main_before_git_worktree_add(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(subject, "RUNTIME_WORKTREE_ROOT", tmp_path / "runtime")
    monkeypatch.setattr(subject, "RUNTIME_RECEIPT_PATH", tmp_path / "receipt.json")

    def dirty(_stage: str):
        raise subject.B.InvalidEvidence("main worktree is dirty")

    def forbidden_run(*_args, **_kwargs):
        raise AssertionError("git worktree add must not run")

    monkeypatch.setattr(subject, "assert_main_worktree_clean", dirty)
    monkeypatch.setattr(subject.subprocess, "run", forbidden_run)
    with pytest.raises(subject.B.InvalidEvidence, match="dirty"):
        subject.materialize_runtime()
    assert not (tmp_path / "runtime").exists()
    assert not (tmp_path / "receipt.json").exists()


def test_launch_resume_is_rejected_before_any_main_or_native_action(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        subject,
        "assert_main_worktree_clean",
        lambda _stage: (_ for _ in ()).throw(AssertionError("must not inspect")),
    )
    monkeypatch.setattr(
        subject,
        "_BASE_LAUNCH_DETACHED",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("must not launch")
        ),
    )
    with pytest.raises(subject.B.AuthorizationError, match="never permits resume"):
        subject.launch_detached(
            subject.ALTERNATE_PRE_RECEIPT_PATH,
            "0" * 64,
            subject.ALTERNATE_AUTHORIZATION_PATH,
            subject.ALTERNATE_STATE_PATH,
            resume=True,
        )


@pytest.mark.parametrize(
    "arguments",
    [
        ["status", "--state", "{primary_state}"],
        [
            "launch",
            "--pre-receipt",
            "{primary_pre}",
            "--pre-sha256",
            "0" * 64,
            "--authorization",
            "{primary_auth}",
            "--state",
            "{primary_state}",
        ],
        ["_run-plan", "--job", "{primary_job}"],
    ],
)
def test_primary_control_paths_are_rejected_before_read_or_dispatch(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    arguments: list[str],
) -> None:
    rendered = [
        value.format(
            primary_state=subject.W.PRIMARY_STATE_PATH,
            primary_pre=subject.W.PRIMARY_PRE_RECEIPT_PATH,
            primary_auth=subject.W.PRIMARY_AUTHORIZATION_PATH,
            primary_job=subject.W.PRIMARY_JOB_PATH,
        )
        for value in arguments
    ]
    called = {"load": False, "dispatch": False}

    def forbidden_load(*_args, **_kwargs):
        called["load"] = True
        raise AssertionError("primary control file must not be opened")

    def forbidden_dispatch(*_args, **_kwargs):
        called["dispatch"] = True
        raise AssertionError("invalid path must not dispatch")

    monkeypatch.setattr(subject.B, "load_json", forbidden_load)
    monkeypatch.setattr(subject.B, "main", forbidden_dispatch)
    code = subject.main(rendered)
    captured = capsys.readouterr()
    assert code == 2
    assert called == {"load": False, "dispatch": False}
    assert "lexically exact" in captured.err


def test_cli_exposes_no_gate_parameter_cost_or_attempt_override() -> None:
    parser = subject.B.build_parser()
    help_text = parser.format_help()
    assert "--minimum-trades" not in help_text
    assert "--profit-factor" not in help_text
    assert "--commission" not in help_text
    launch = next(
        action for action in parser._actions if action.dest == "command"
    ).choices["launch"]
    option_strings = {
        option for action in launch._actions for option in action.option_strings
    }
    assert option_strings == {
        "-h",
        "--help",
        "--pre-receipt",
        "--pre-sha256",
        "--authorization",
        "--state",
        "--resume",
    }
    assert subject.B.MERIT_GATES == subject.W.B.MERIT_GATES
