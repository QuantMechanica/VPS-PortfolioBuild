from __future__ import annotations

import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Callable

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import factory_runtime_activation as fra  # noqa: E402


NOW = dt.datetime(2026, 7, 30, 12, 0, tzinfo=dt.UTC)
ROOT = Path(__file__).resolve().parents[3]
SCHEMA_PATH = HERE.parent / "factory_runtime_activation.v1.schema.json"
TEMPLATE_PATH = HERE.parent / "factory_runtime_activation.v1.template.json"


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
    raw = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def _z(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _build_repo(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    authorized_at: dt.datetime = NOW - dt.timedelta(minutes=1),
    expires_at: dt.datetime = NOW + dt.timedelta(hours=1),
    mutate_decision: Callable[[dict], None] | None = None,
    mutate_flag: Callable[[dict], None] | None = None,
    raw_decision_factory: Callable[[dict], bytes] | None = None,
) -> tuple[Path, Path, dict]:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "factory-tests@example.invalid")
    _git(repo, "config", "user.name", "Factory Tests")
    _git(repo, "config", "core.autocrlf", "false")

    task_map = {f"QM_Test_Task_{index:02d}": index % 3 != 0 for index in range(21)}
    preparation = {
        "schema_version": "qm.factory-restart-owner-preparation-decision/v1",
        "restore_intent": {
            "factory_on_authorized": False,
            "runtime_flag_upgrade_authorized": False,
            "task_enabled_before": task_map,
        },
        "explicit_exclusions": {"hold_release_now": False},
    }
    prep_path = repo / fra.PREPARATION_DECISION_RELATIVE_PATH
    prep_raw = _write_json(prep_path, preparation)

    source_raw: dict[str, bytes] = {}
    for label, relative_path in fra.SOURCE_BINDING_PATHS.items():
        raw = f"test source binding: {label}\n".encode("utf-8")
        path = repo / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        source_raw[label] = raw

    _git(repo, "add", "--all")
    _git(repo, "commit", "-q", "-m", "seed pinned preparation and sources")
    source_commit = _git(repo, "rev-parse", "HEAD")
    prep_blob = _git(
        repo,
        "rev-parse",
        f"HEAD:{fra.PREPARATION_DECISION_RELATIVE_PATH.as_posix()}",
    )
    monkeypatch.setattr(fra, "PREPARATION_DECISION_SHA256", _sha256(prep_raw))
    monkeypatch.setattr(fra, "PREPARATION_DECISION_COMMIT", source_commit)
    monkeypatch.setattr(fra, "PREPARATION_DECISION_BLOB", prep_blob)

    flag_payload = {
        "schema_version": 2,
        "state": "OFF",
        "task_enabled_before": dict(task_map),
    }
    if mutate_flag is not None:
        mutate_flag(flag_payload)
    flag_path = tmp_path / "FACTORY_OFF.flag"
    flag_raw = _write_json(flag_path, flag_payload)

    task_map_sha = _sha256(
        json.dumps(task_map, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    source_bindings = {}
    for label, relative_path in fra.SOURCE_BINDING_PATHS.items():
        source_bindings[label] = {
            "relative_path": relative_path.as_posix(),
            "sha256": _sha256(source_raw[label]),
            "git_commit": source_commit,
            "git_blob": _git(repo, "rev-parse", f"HEAD:{relative_path.as_posix()}"),
        }
    decision = {
        "schema_version": fra.SCHEMA_VERSION,
        "decision_id": "OWNER_RUNTIME_ACTIVATION_TEST",
        "activation_nonce": "a" * 32,
        "authority": "OWNER",
        "status": "APPROVED",
        "authorized_at_utc": _z(authorized_at),
        "expires_at_utc": _z(expires_at),
        "preparation_decision": {
            "relative_path": fra.PREPARATION_DECISION_RELATIVE_PATH.as_posix(),
            "sha256": _sha256(prep_raw),
            "git_commit": source_commit,
            "git_blob": prep_blob,
        },
        "authorizations": {
            "factory_on": True,
            "release_seven_restart_holds": True,
            "runtime_flag_upgrade_authorized": False,
        },
        "restart_holds": {
            "authorized_release_count": 7,
            "authorized_work_item_ids": list(fra.RESTART_HOLD_IDS),
        },
        "worker_policy": {
            "disabled_terminals": ["T5"],
            "expected_worker_count": 9,
            "expected_terminals": list(fra.WORKER_TERMINALS),
        },
        "restore_intent": {
            "factory_off_flag_sha256": _sha256(flag_raw),
            "factory_off_schema_version": 2,
            "factory_off_state": "OFF",
            "task_enabled_before_sha256": task_map_sha,
        },
        "source_bindings": source_bindings,
    }
    if mutate_decision is not None:
        mutate_decision(decision)
    decision_path = repo / fra.DECISION_RELATIVE_PATH
    decision_path.parent.mkdir(parents=True, exist_ok=True)
    decision_raw = (
        raw_decision_factory(decision)
        if raw_decision_factory is not None
        else (json.dumps(decision, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    decision_path.write_bytes(decision_raw)
    digest_path = repo / fra.DIGEST_RELATIVE_PATH
    digest_path.write_text(
        f"{_sha256(decision_raw)}  {fra.DECISION_RELATIVE_PATH.name}\n",
        encoding="ascii",
    )
    _git(repo, "add", "--all")
    _git(repo, "commit", "-q", "-m", "add one-time runtime activation decision")
    return repo, flag_path, decision


def _validate(repo: Path, flag_path: Path) -> dict:
    return fra.validate_runtime_activation_decision(
        repo_root=repo,
        factory_off_flag=flag_path,
        now_utc=NOW,
    )


def test_strict_committed_runtime_activation_decision_passes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo, flag_path, decision = _build_repo(tmp_path, monkeypatch)

    result = _validate(repo, flag_path)

    assert result["authorized"] is True
    assert result["decision_id"] == decision["decision_id"]
    assert result["activation_nonce"] == "a" * 32
    assert result["restart_hold_ids"] == list(fra.RESTART_HOLD_IDS)
    assert result["worker_terminals"] == list(fra.WORKER_TERMINALS)
    assert set(result["source_bindings"]) == set(fra.SOURCE_BINDING_PATHS)
    assert len(result["task_enabled_before"]) == 21


def test_missing_runtime_decision_hard_blocks(tmp_path: Path) -> None:
    with pytest.raises(fra.RuntimeActivationError, match="remains hard-blocked"):
        fra.validate_runtime_activation_decision(repo_root=tmp_path, now_utc=NOW)


def test_consumed_canonical_runtime_decision_expires_fail_closed() -> None:
    decision_path = ROOT / fra.DECISION_RELATIVE_PATH
    digest_path = ROOT / fra.DIGEST_RELATIVE_PATH
    decision_raw = decision_path.read_bytes()
    decision = json.loads(decision_raw.decode("utf-8"))
    digest = digest_path.read_text(encoding="ascii")
    assert digest == f"{_sha256(decision_raw)}  {decision_path.name}\n"
    expires_at = dt.datetime.fromisoformat(
        decision["expires_at_utc"].replace("Z", "+00:00")
    )
    with pytest.raises(fra.RuntimeActivationError, match="expired"):
        fra.validate_runtime_activation_decision(
            repo_root=ROOT,
            now_utc=expires_at,
        )


def test_preparation_decision_is_never_runtime_authority() -> None:
    prep_path = (
        Path(__file__).resolve().parents[3]
        / fra.PREPARATION_DECISION_RELATIVE_PATH
    )
    prep = json.loads(prep_path.read_text(encoding="utf-8"))
    assert prep["restore_intent"]["factory_on_authorized"] is False
    assert prep["restore_intent"]["runtime_flag_upgrade_authorized"] is False
    assert prep["explicit_exclusions"]["hold_release_now"] is False
    with pytest.raises(fra.RuntimeActivationError, match="cannot authorize"):
        fra._require_runtime_authorizations(prep)


@pytest.mark.parametrize(
    ("authorized_at", "expires_at", "message"),
    [
        (NOW - dt.timedelta(hours=2), NOW, "expired"),
        (NOW + dt.timedelta(minutes=6), NOW + dt.timedelta(hours=1), "future-dated"),
        (NOW - dt.timedelta(minutes=1), NOW + dt.timedelta(hours=25), "exceeds 24 hours"),
    ],
)
def test_runtime_decision_rejects_bad_time_window(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    authorized_at: dt.datetime,
    expires_at: dt.datetime,
    message: str,
) -> None:
    repo, flag_path, _ = _build_repo(
        tmp_path,
        monkeypatch,
        authorized_at=authorized_at,
        expires_at=expires_at,
    )
    with pytest.raises(fra.RuntimeActivationError, match=message):
        _validate(repo, flag_path)


def test_runtime_decision_rejects_off_task_map_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def drift(flag: dict) -> None:
        flag["task_enabled_before"]["QM_Test_Task_00"] = True

    repo, flag_path, _ = _build_repo(tmp_path, monkeypatch, mutate_flag=drift)
    with pytest.raises(fra.RuntimeActivationError, match="approved exact 21-task map"):
        _validate(repo, flag_path)


def test_runtime_decision_rejects_source_worktree_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo, flag_path, _ = _build_repo(tmp_path, monkeypatch)
    source_path = repo / fra.SOURCE_BINDING_PATHS["farmctl"]
    source_path.write_text("post-authorization source drift\n", encoding="utf-8")
    with pytest.raises(fra.RuntimeActivationError, match="SHA-256 mismatch"):
        _validate(repo, flag_path)


def test_runtime_decision_rejects_sidecar_mismatch(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo, flag_path, _ = _build_repo(tmp_path, monkeypatch)
    (repo / fra.DIGEST_RELATIVE_PATH).write_text(
        f"{'0' * 64}  {fra.DECISION_RELATIVE_PATH.name}\n", encoding="ascii"
    )
    with pytest.raises(fra.RuntimeActivationError, match="sidecar mismatch"):
        _validate(repo, flag_path)


def test_runtime_decision_rejects_duplicate_json_key(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def duplicate_key(decision: dict) -> bytes:
        raw = json.dumps(decision, sort_keys=True, separators=(",", ":"))
        return raw.replace(
            '"authority":"OWNER"',
            '"authority":"OWNER","authority":"OWNER"',
            1,
        ).encode("utf-8")

    repo, flag_path, _ = _build_repo(
        tmp_path, monkeypatch, raw_decision_factory=duplicate_key
    )
    with pytest.raises(fra.RuntimeActivationError, match="duplicate JSON key"):
        _validate(repo, flag_path)


def test_schema_and_template_pin_exact_restart_and_source_contracts() -> None:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    template = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    properties = schema["properties"]

    assert properties["preparation_decision"]["const"] == template[
        "preparation_decision"
    ]
    assert properties["restart_holds"]["properties"][
        "authorized_work_item_ids"
    ]["const"] == list(fra.RESTART_HOLD_IDS)
    assert properties["worker_policy"]["properties"]["disabled_terminals"][
        "const"
    ] == ["T5"]
    assert properties["worker_policy"]["properties"]["expected_terminals"][
        "const"
    ] == list(fra.WORKER_TERMINALS)
    assert set(properties["source_bindings"]["required"]) == set(
        fra.SOURCE_BINDING_PATHS
    )
    assert set(template["source_bindings"]) == set(fra.SOURCE_BINDING_PATHS)
    assert fra.SOURCE_BINDING_PATHS["public_snapshot_task_wrapper"] == Path(
        "scripts/run_public_snapshot_task.ps1"
    )
    assert fra.SOURCE_BINDING_PATHS["public_snapshot_incident_guard"] == Path(
        "tools/strategy_farm/public_snapshot_incident_guard.py"
    )
    assert properties["restore_intent"]["properties"][
        "task_enabled_before_sha256"
    ]["const"] == template["restore_intent"]["task_enabled_before_sha256"]
