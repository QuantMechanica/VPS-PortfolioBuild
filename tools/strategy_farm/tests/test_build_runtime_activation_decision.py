from __future__ import annotations

import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_runtime_activation_decision as builder  # noqa: E402
import factory_runtime_activation as fra  # noqa: E402


NOW = dt.datetime(2026, 7, 30, 12, 0, tzinfo=dt.UTC)
TEMPLATE_PATH = HERE.parent / "factory_runtime_activation.v1.template.json"
TEST_RESTART_HOLD_IDS = (
    "3746e558-6eff-436b-9365-cfec9b7f1a63",
    "ded31f32-92fb-45a7-b318-aa00c2f3f41c",
)


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(repo), *args),
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return result.stdout.strip()


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _write_json(path: Path, value: object) -> bytes:
    raw = (json.dumps(value, indent=2) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def _seed_repo(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    expires_at: dt.datetime = NOW + dt.timedelta(hours=1),
    crlf_smudge_source: bool = False,
    restart_hold_ids: tuple[str, ...] = TEST_RESTART_HOLD_IDS,
) -> tuple[Path, Path]:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "builder-tests@example.invalid")
    _git(repo, "config", "user.name", "Builder Tests")
    _git(
        repo,
        "config",
        "core.autocrlf",
        "true" if crlf_smudge_source else "false",
    )
    (repo / ".gitattributes").write_text(
        "*.ps1 text\n*.py text\n",
        encoding="ascii",
    )

    task_map = {f"QM_Test_Task_{index:02d}": index % 2 == 0 for index in range(21)}
    task_map_sha256 = _sha256(
        json.dumps(task_map, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    preparation = {
        "schema_version": "qm.factory-restart-owner-preparation-decision/v1",
        "authorized_at_utc": "2026-07-30T06:00:00Z",
        "authorization_expires_at_utc": expires_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "restore_intent": {
            "factory_on_authorized": False,
            "runtime_flag_upgrade_authorized": False,
            "manifest_creation_authorized_after_prerequisites": True,
            "task_enabled_before": task_map,
        },
        "restart_holds": {
            "authorized_release_count": len(restart_hold_ids),
            "authorized_work_item_ids": list(restart_hold_ids),
        },
        "explicit_exclusions": {"hold_release_now": False},
    }
    preparation_path = repo / fra.PREPARATION_DECISION_RELATIVE_PATH
    preparation_raw = _write_json(preparation_path, preparation)

    template = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    template["restore_intent"]["task_enabled_before_sha256"] = task_map_sha256
    _write_json(repo / builder.TEMPLATE_RELATIVE_PATH, template)

    source_bytes: dict[str, bytes] = {}
    for label, relative_path in fra.SOURCE_BINDING_PATHS.items():
        raw = f"synthetic source binding: {label}\n".encode("utf-8")
        path = repo / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(
            raw.replace(b"\n", b"\r\n")
            if crlf_smudge_source and label == "factory_on"
            else raw
        )
        source_bytes[label] = raw

    _git(repo, "add", "--all")
    _git(repo, "commit", "-q", "-m", "seed builder prerequisites")
    commit = _git(repo, "rev-parse", "HEAD")
    preparation_blob = _git(
        repo,
        "rev-parse",
        f"HEAD:{fra.PREPARATION_DECISION_RELATIVE_PATH.as_posix()}",
    )
    monkeypatch.setattr(fra, "PREPARATION_DECISION_SHA256", _sha256(preparation_raw))
    monkeypatch.setattr(fra, "PREPARATION_DECISION_COMMIT", commit)
    monkeypatch.setattr(fra, "PREPARATION_DECISION_BLOB", preparation_blob)
    template["preparation_decision"] = {
        "relative_path": fra.PREPARATION_DECISION_RELATIVE_PATH.as_posix(),
        "sha256": _sha256(preparation_raw),
        "git_commit": commit,
        "git_blob": preparation_blob,
    }
    _write_json(repo / builder.TEMPLATE_RELATIVE_PATH, template)
    _git(repo, "add", builder.TEMPLATE_RELATIVE_PATH.as_posix())
    _git(repo, "commit", "-q", "-m", "bind synthetic preparation")

    if crlf_smudge_source:
        source_relative = fra.SOURCE_BINDING_PATHS["factory_on"]
        source_path = repo / source_relative
        assert source_path.read_bytes() == source_bytes["factory_on"].replace(
            b"\n", b"\r\n"
        )
        assert _git(repo, "status", "--porcelain", "--untracked-files=all") == ""

    flag = {
        "schema_version": 2,
        "state": "OFF",
        "task_enabled_before": task_map,
    }
    flag_path = tmp_path / "FACTORY_OFF.flag"
    _write_json(flag_path, flag)
    return repo, flag_path


def test_builder_parses_required_cli_contract() -> None:
    args = builder.build_parser().parse_args(
        [
            "--repo-root",
            "X:/repo",
            "--flag",
            "Y:/FACTORY_OFF.flag",
            "--decision-id",
            "OWNER_GO_001",
        ]
    )
    assert args.repo_root == Path("X:/repo")
    assert args.flag == Path("Y:/FACTORY_OFF.flag")
    assert args.decision_id == "OWNER_GO_001"


def test_builder_main_returns_classified_precondition_exit_code(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    exit_code = builder.main(
        [
            "--repo-root",
            str(tmp_path),
            "--flag",
            str(tmp_path / "missing.flag"),
            "--decision-id",
            "invalid decision id",
        ]
    )
    error = json.loads(capsys.readouterr().err)
    assert exit_code == builder.EXIT_PRECONDITION
    assert error["exit_code"] == builder.EXIT_PRECONDITION
    assert error["category"] == "PRECONDITION"
    assert error["built"] is False


def test_builder_self_verifies_candidate_and_preserves_crlf_normalization(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, flag_path = _seed_repo(
        tmp_path,
        monkeypatch,
        crlf_smudge_source=True,
    )
    validator_calls: list[tuple[Path, Path]] = []
    real_validator = fra.validate_runtime_activation_candidate

    def recording_validator(**kwargs: object) -> dict:
        validator_calls.append(
            (Path(kwargs["decision_path"]), Path(kwargs["digest_path"]))
        )
        return real_validator(**kwargs)

    monkeypatch.setattr(
        fra,
        "validate_runtime_activation_candidate",
        recording_validator,
    )
    result = builder.build_runtime_activation_decision(
        repo_root=repo,
        flag_path=flag_path,
        decision_id="OWNER_GO_001",
        now_utc=NOW,
    )

    decision_path = repo / fra.DECISION_RELATIVE_PATH
    digest_path = repo / fra.DIGEST_RELATIVE_PATH
    assert result["built"] is True
    assert result["candidate_validated"] is True
    assert result["published_validated"] is True
    assert len(validator_calls) == 2
    assert validator_calls[0][0].parent != decision_path.parent
    assert validator_calls[1] == (decision_path, digest_path)
    assert (
        repo / fra.SOURCE_BINDING_PATHS["factory_on"]
    ).read_bytes() == b"synthetic source binding: factory_on\n"
    decision = json.loads(decision_path.read_text(encoding="utf-8"))
    assert decision["decision_id"] == "OWNER_GO_001"
    assert decision["worker_policy"] == {
        "disabled_terminals": [],
        "expected_worker_count": 10,
        "expected_terminals": list(fra.WORKER_TERMINALS),
    }
    assert decision["restart_holds"] == {
        "authorized_release_count": len(TEST_RESTART_HOLD_IDS),
        "authorized_work_item_ids": list(TEST_RESTART_HOLD_IDS),
    }
    assert decision["restore_intent"]["factory_off_flag_sha256"] == _sha256(
        flag_path.read_bytes()
    )
    assert digest_path.read_text(encoding="ascii") == (
        f"{_sha256(decision_path.read_bytes())}  {decision_path.name}\n"
    )

    with pytest.raises(
        fra.RuntimeActivationError,
        match="no canonical commit provenance",
    ):
        fra.validate_runtime_activation_decision(
            repo_root=repo,
            factory_off_flag=flag_path,
            now_utc=NOW,
        )


def test_builder_carries_empty_declared_plan_forward(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, flag_path = _seed_repo(
        tmp_path,
        monkeypatch,
        restart_hold_ids=(),
    )

    builder.build_runtime_activation_decision(
        repo_root=repo,
        flag_path=flag_path,
        decision_id="OWNER_GO_EMPTY_PLAN",
        now_utc=NOW,
    )

    decision = json.loads(
        (repo / fra.DECISION_RELATIVE_PATH).read_text(encoding="utf-8")
    )
    assert decision["restart_holds"] == {
        "authorized_release_count": 0,
        "authorized_work_item_ids": [],
    }


def test_builder_rejects_dirty_repository_before_writing_artifacts(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, flag_path = _seed_repo(tmp_path, monkeypatch)
    (repo / "untracked.txt").write_text("dirty\n", encoding="utf-8")

    with pytest.raises(builder.DecisionBuildError) as error:
        builder.build_runtime_activation_decision(
            repo_root=repo,
            flag_path=flag_path,
            decision_id="OWNER_GO_002",
            now_utc=NOW,
        )

    assert error.value.exit_code == builder.EXIT_PRECONDITION
    assert "repository is dirty" in str(error.value)
    assert not (repo / fra.DECISION_RELATIVE_PATH).exists()
    assert not (repo / fra.DIGEST_RELATIVE_PATH).exists()


def test_builder_rejects_expired_preparation_window(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, flag_path = _seed_repo(
        tmp_path,
        monkeypatch,
        expires_at=NOW,
    )

    with pytest.raises(builder.DecisionBuildError) as error:
        builder.build_runtime_activation_decision(
            repo_root=repo,
            flag_path=flag_path,
            decision_id="OWNER_GO_003",
            now_utc=NOW,
        )

    assert error.value.exit_code == builder.EXIT_PRECONDITION
    assert "window is not active" in str(error.value)
    assert not (repo / fra.DECISION_RELATIVE_PATH).exists()


def test_builder_classifies_candidate_validation_failure_without_publication(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, flag_path = _seed_repo(tmp_path, monkeypatch)

    def reject_candidate(**_: object) -> dict:
        raise fra.RuntimeActivationError("synthetic candidate rejection")

    monkeypatch.setattr(
        fra,
        "validate_runtime_activation_candidate",
        reject_candidate,
    )
    with pytest.raises(builder.DecisionBuildError) as error:
        builder.build_runtime_activation_decision(
            repo_root=repo,
            flag_path=flag_path,
            decision_id="OWNER_GO_004",
            now_utc=NOW,
        )

    assert error.value.exit_code == builder.EXIT_SELF_VERIFICATION
    assert error.value.category == "SELF_VERIFICATION"
    assert "synthetic candidate rejection" in str(error.value)
    assert not (repo / fra.DECISION_RELATIVE_PATH).exists()
    assert not (repo / fra.DIGEST_RELATIVE_PATH).exists()
