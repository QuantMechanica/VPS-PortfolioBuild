from __future__ import annotations

from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


def test_gate_failure_reengages_containment(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: {
            "required": True,
            "status": "FAIL_CLOSED",
            "terminal": terminal,
            "activation_sha256": "a" * 64,
        },
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
