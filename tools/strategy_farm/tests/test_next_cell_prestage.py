from __future__ import annotations

import hashlib
from pathlib import Path
import threading

import pytest

from tools.strategy_farm import next_cell_prestage as subject


def _config(tmp_path: Path, *, active: bool = True, max_bytes: int = 1024**2):
    return subject.PrestageConfig(
        root=tmp_path,
        terminal="T1",
        enabled=active,
        terminal_allowlist=["T1"] if active else [],
        ttl_seconds=300,
        max_bytes=max_bytes,
        io_mib_per_second=1024.0,
        min_free_disk_gb=0.0,
        min_free_ram_gb=0.0,
        min_free_commit_gb=0.0,
        max_cpu_percent=100.0,
        cancel_join_seconds=1.0,
    )


def _snapshot(tmp_path: Path, cancel: threading.Event | None = None):
    setfile = tmp_path / "candidate.set"
    binary = tmp_path / "candidate.ex5"
    dependency = tmp_path / "ledger.json"
    setfile.write_bytes(b"set-input")
    binary.write_bytes(b"ex5-input")
    dependency.write_bytes(b'{"sealed":true}')
    return {
        "terminal": "T1",
        "worker_generation": "generation-1",
        "item": {
            "id": "candidate-1",
            "phase": "Q03",
            "ea_id": "QM5_99991",
            "symbol": "EURUSD.DWX",
            "period": "H1",
            "year": 2022,
        },
        "payload_sha256": subject.sha256_text('{"input":1}'),
        "policy_generation": "policy-1",
        "files": [
            subject.file_spec(
                setfile.resolve(),
                role="setfile",
                logical_name=str(setfile.resolve()),
                cancel=cancel,
            ),
            subject.file_spec(
                binary.resolve(),
                role="ex5",
                logical_name=str(binary.resolve()),
                cancel=cancel,
            ),
            subject.file_spec(
                dependency.resolve(),
                role="dependency",
                logical_name=str(dependency.resolve()),
                cache=False,
                cancel=cancel,
            ),
        ],
        "dependencies": {"dl089": {"predecessor_ids": []}},
    }


def test_env_defaults_are_inert_and_require_exact_allowlist(tmp_path: Path) -> None:
    default = subject.PrestageConfig.from_env(tmp_path, "T1", {})
    assert default.enabled is False
    assert default.active is False
    assert default.terminal_allowlist == frozenset()

    enabled_without_terminal = subject.PrestageConfig.from_env(
        tmp_path,
        "T1",
        {subject.FEATURE_ENV: "1", subject.ALLOWLIST_ENV: "T2"},
    )
    assert enabled_without_terminal.enabled is True
    assert enabled_without_terminal.active is False

    exact = subject.PrestageConfig.from_env(
        tmp_path,
        "T1",
        {subject.FEATURE_ENV: "1", subject.ALLOWLIST_ENV: "T1,T3"},
    )
    assert exact.active is True


def test_prepare_and_post_claim_cas_are_exact_and_idempotent(tmp_path: Path) -> None:
    config = _config(tmp_path)
    events: list[tuple[str, dict]] = []
    plan = subject.prepare_snapshot(
        _snapshot(tmp_path),
        config=config,
        cancel=threading.Event(),
        resource_probe=lambda: {"allowed": True, "reason": "test"},
        candidate_is_current=lambda _token: (True, "match"),
        emit=lambda event, detail: events.append((event, dict(detail))),
    )
    assert plan["state"] == "PREPARED"
    assert plan["prepared_bytes"] == len(b"set-input") + len(b"ex5-input")
    assert [event for event, _ in events] == ["prestage_started"]
    for value in plan["files"]:
        if value["cache"]:
            cached = Path(value["cache_path"])
            assert cached.is_file()
            assert hashlib.sha256(cached.read_bytes()).hexdigest() == value["sha256"]

    claim = {
        "claimed": True,
        "preclaim_payload_sha256": plan["payload_sha256"],
        "item": {"id": "candidate-1"},
    }
    adopted, reason = subject.adopt_plan(
        plan,
        config=config,
        claim=claim,
        current_policy_generation="policy-1",
        dependency_validator=lambda _plan: (True, "match"),
    )
    assert reason == "adopted"
    assert adopted is not None and adopted["state"] == "ADOPTED"

    replay, replay_reason = subject.adopt_plan(
        plan,
        config=config,
        claim=claim,
        current_policy_generation="policy-1",
        dependency_validator=lambda _plan: (True, "match"),
    )
    assert replay_reason == "adopted_idempotent"
    assert replay is not None and replay["idempotent"] is True


@pytest.mark.parametrize(
    ("claim", "policy", "dependency", "expected"),
    [
        (
            {"claimed": True, "preclaim_payload_sha256": "x", "item": {"id": "candidate-1"}},
            "policy-1",
            (True, "match"),
            "preclaim_payload_changed",
        ),
        (
            {"claimed": True, "preclaim_payload_sha256": "PAYLOAD", "item": {"id": "other"}},
            "policy-1",
            (True, "match"),
            "claimed_different_item",
        ),
        (
            {"claimed": True, "preclaim_payload_sha256": "PAYLOAD", "item": {"id": "candidate-1"}},
            "policy-2",
            (True, "match"),
            "policy_generation_changed",
        ),
    ],
)
def test_adoption_declines_changed_authority_inputs(
    tmp_path: Path, claim: dict, policy: str, dependency: tuple[bool, str], expected: str
) -> None:
    config = _config(tmp_path)
    plan = subject.prepare_snapshot(
        _snapshot(tmp_path),
        config=config,
        cancel=threading.Event(),
        resource_probe=lambda: {"allowed": True},
        candidate_is_current=lambda _token: (True, "match"),
        emit=lambda _event, _detail: None,
    )
    if claim["preclaim_payload_sha256"] == "PAYLOAD":
        claim["preclaim_payload_sha256"] = plan["payload_sha256"]
    adopted, reason = subject.adopt_plan(
        plan,
        config=config,
        claim=claim,
        current_policy_generation=policy,
        dependency_validator=lambda _plan: dependency,
    )
    assert adopted is None
    assert reason == expected


def test_byte_resource_staleness_and_cancellation_decline_without_authority(
    tmp_path: Path,
) -> None:
    snapshot = _snapshot(tmp_path)
    with pytest.raises(subject.PrestageError, match="byte_cap_exceeded"):
        subject.prepare_snapshot(
            snapshot,
            config=_config(tmp_path, max_bytes=1),
            cancel=threading.Event(),
            resource_probe=lambda: {"allowed": True},
            candidate_is_current=lambda _token: (True, "match"),
            emit=lambda _event, _detail: None,
        )
    with pytest.raises(subject.PrestageError, match="resource_decline:cpu_pressure"):
        subject.prepare_snapshot(
            snapshot,
            config=_config(tmp_path),
            cancel=threading.Event(),
            resource_probe=lambda: {"allowed": False, "reason": "cpu_pressure"},
            candidate_is_current=lambda _token: (True, "match"),
            emit=lambda _event, _detail: None,
        )
    with pytest.raises(subject.PrestageError, match="candidate_stale:payload_changed"):
        subject.prepare_snapshot(
            snapshot,
            config=_config(tmp_path),
            cancel=threading.Event(),
            resource_probe=lambda: {"allowed": True},
            candidate_is_current=lambda _token: (False, "payload_changed"),
            emit=lambda _event, _detail: None,
        )
    cancelled = threading.Event()
    cancelled.set()
    with pytest.raises(subject.PrestageCancelled, match="cancelled"):
        subject.prepare_snapshot(
            snapshot,
            config=_config(tmp_path),
            cancel=cancelled,
            resource_probe=lambda: {"allowed": True},
            candidate_is_current=lambda _token: (True, "match"),
            emit=lambda _event, _detail: None,
        )


def test_disabled_controller_never_calls_snapshot_loader_or_writes_cache(
    tmp_path: Path,
) -> None:
    calls: list[str] = []
    telemetry: list[dict] = []
    controller = subject.PrestageController(
        _config(tmp_path, active=False),
        snapshot_loader=lambda _generation, _cancel: calls.append("snapshot"),
        candidate_is_current=lambda _token: (True, "match"),
        resource_probe=lambda: calls.append("resource"),
        policy_generation=lambda: "policy-1",
        dependency_validator=lambda _plan: (True, "match"),
        telemetry=lambda value: telemetry.append(dict(value)),
    )
    controller.child_spawned(item_id="current", pid=123)
    controller.child_finished(item_id="current")
    controller.claim_attempt()
    assert controller.claim_result(
        {"claimed": True, "item": {"id": "candidate-1"}}
    ) is None
    controller.shutdown()
    assert calls == []
    assert not controller.config.cache_root.exists()
    assert {value["stage_event"] for value in telemetry} >= {
        "config",
        "next_child_process_created",
        "current_child_exit",
        "next_claim_attempt",
        "claim_result",
    }
