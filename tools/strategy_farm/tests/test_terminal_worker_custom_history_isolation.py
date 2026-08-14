from __future__ import annotations

from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


def _failing_gate(terminal: str, **extra) -> dict:
    return {
        "required": True,
        "status": "FAIL_CLOSED",
        "terminal": terminal,
        "activation_sha256": "a" * 64,
        **extra,
    }


def test_benign_gate_failure_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    # DL-085: torn link counts and master-repairable manifest gaps self-heal;
    # they defer the claim attempt but must not stop the fleet.
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: _failing_gate(
            terminal,
            findings=[
                {"code": "ARCHIVE_LINK_COUNT_TOO_LOW", "terminal": "T7"},
                {"code": "MANIFEST_ARCHIVE_FILE_MISSING", "terminal": "T2"},
                {"code": "TERMINAL_MANIFEST_INCOMPLETE", "terminal": "T2"},
            ],
            master_repair={"status": "REPAIRED", "failed_count": 0},
        ),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T3")

    assert gate["status"] == "FAIL_CLOSED"
    assert calls == []


def test_master_repair_failure_reengages_containment(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: _failing_gate(
            terminal,
            findings=[{"code": "MANIFEST_ARCHIVE_FILE_MISSING", "terminal": "T2"}],
            master_repair={"status": "PARTIAL", "failed_count": 1},
        ),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T3")

    assert gate["status"] == "FAIL_CLOSED"
    assert calls == [
        (
            tmp_path,
            {
                "reason": "custom_history_isolation_gate_failure",
                "activation_sha256": "a" * 64,
            },
        )
    ]


def test_non_benign_finding_reengages_containment(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: _failing_gate(
            terminal,
            findings=[
                {"code": "ARCHIVE_LINK_COUNT_TOO_LOW", "terminal": "T7"},
                {"code": "ARCHIVE_RUNNER_WRITE_NOT_DENIED", "terminal": "T4"},
            ],
        ),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T3")

    assert gate["status"] == "FAIL_CLOSED"
    assert len(calls) == 1


def test_runtime_history_stop_conditions_are_fail_safe() -> None:
    assert terminal_worker._custom_history_stop_condition(
        {"detail": "history synchronization error"}
    ) == "history_sync_error"
    assert terminal_worker._custom_history_stop_condition(
        {"detail": "ERROR_SHARING_VIOLATION"}
    ) == "history_error_32"
    assert terminal_worker._custom_history_stop_condition(
        {"detail": "missing_real_ticks_marker"}
    ) == "missing_real_ticks_marker"
    assert terminal_worker._custom_history_stop_condition(
        {"detail": "ordinary strategy fail"}
    ) is None


def test_gate_defer_result_does_not_trip_stop_condition() -> None:
    # The defer's own reason string carries the fail-closed token; scanning
    # it re-tripped containment on every benign self-heal (2026-08-14 11:18Z).
    for action in sorted(terminal_worker.CUSTOM_HISTORY_GATE_DEFER_ACTIONS):
        assert terminal_worker._custom_history_stop_condition(
            {
                "action": action,
                "reason": "CUSTOM_HISTORY_ISOLATION_FAIL_CLOSED",
                "custom_history_gate": {"status": "FAIL_CLOSED"},
            }
        ) is None
    # A real run result with eater evidence still stops the fleet.
    assert terminal_worker._custom_history_stop_condition(
        {"action": "finished", "detail": "History 'CADCHF.DWX' error [32]"}
    ) == "history_error_32"


def test_transient_copy_on_claim_error_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    def raise_sharing_violation(root):
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "load_activation", raise_sharing_violation
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path,
        {"id": "item-1", "payload_json": "{}", "ea_id": "QM5_1", "symbol": "EURUSD.DWX"},
        "T3",
        {"required": True, "status": "PASS_ISOLATED", "activation_sha256": "a" * 64},
    )

    assert result["status"] == "FAIL_CLOSED"
    assert result["reason"] == "custom_history_copy_on_claim_failure"
    assert calls == []


def test_non_transient_copy_on_claim_error_engages_containment(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "load_activation", lambda root: None
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path,
        {"id": "item-1", "payload_json": "{}", "ea_id": "QM5_1", "symbol": "EURUSD.DWX"},
        "T3",
        {"required": True, "status": "PASS_ISOLATED", "activation_sha256": "a" * 64},
    )

    assert result["status"] == "FAIL_CLOSED"
    assert len(calls) == 1


def test_claim_history_scope_includes_host_conversion_and_basket_dependencies(
    monkeypatch,
) -> None:
    monkeypatch.setattr(
        terminal_worker,
        "_payload_basket_manifest",
        lambda payload, ea_id: {
            "host_symbol": "EURUSD.DWX",
            "basket_symbols": ["GBPUSD.DWX", "AUDUSD.DWX"],
            "conversion_symbols": ["USDJPY.DWX"],
        },
    )
    symbols = terminal_worker._work_item_history_symbols(
        {"ea_id": "QM5_99999", "symbol": "EURUSD.DWX"},
        {
            "host_symbol": "EURUSD.DWX",
            "portfolio_scope": "basket",
            "basket_symbols": ["GBPUSD.DWX"],
            "conversion_symbols": ["USDCHF.DWX"],
        },
    )

    assert symbols == [
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "USDCHF.DWX",
        "AUDUSD.DWX",
        "USDJPY.DWX",
    ]


def test_gate_and_lease_precede_claim_and_spawn_boundaries() -> None:
    source = Path(terminal_worker.__file__).read_text(encoding="utf-8")
    loop = source[source.index("def run_loop"):source.index("def _acquire_instance_mutex")]
    assert loop.index("_custom_history_gate(root, terminal)") < loop.index(
        "_acquire_custom_history_lease(root, terminal)"
    ) < loop.index("claim_atomic(root, terminal)")

    run = source[source.index("def _run_claimed_item"):source.index("def _disk_free_gb")]
    pre_gate = run.index("history_gate = _custom_history_gate(root, terminal)")
    copy = run.index("copy_on_claim = _privatize_custom_history_claim")
    post_gate = run.index("post_copy_gate = _custom_history_gate(root, terminal)")
    launch = run.index("_acquire_launch_slot(terminal)")
    spawn = run.index("farmctl._spawn_work_item_runner")
    assert pre_gate < copy < post_gate < launch < spawn
    assert "_defer_custom_history_gate" in run


def test_transient_gate_io_error_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    def raise_sharing_violation(root, terminal):
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        raise_sharing_violation,
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T9")

    assert gate["status"] == "FAIL_CLOSED"
    assert gate["reason"] == "custom_history_gate_transient_io"
    assert calls == []


def test_wrapped_transient_cause_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    def raise_wrapped(root, terminal):
        try:
            raise FileNotFoundError(2, "The system cannot find the file specified")
        except FileNotFoundError as exc:
            raise terminal_worker.custom_history_gate.CustomHistoryGateError(
                "ramp receipt unreadable"
            ) from exc

    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "run_worker_gate", raise_wrapped
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T4")

    assert gate["reason"] == "custom_history_gate_transient_io"
    assert calls == []


def test_non_transient_gate_exception_still_engages_containment(
    monkeypatch, tmp_path: Path
) -> None:
    def raise_value_error(root, terminal):
        raise ValueError("activation record corrupt")

    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "run_worker_gate", raise_value_error
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T2")

    assert gate["reason"] == "custom_history_gate_exception"
    assert len(calls) == 1
    assert calls[0][1]["reason"] == "custom_history_gate_exception:ValueError"
