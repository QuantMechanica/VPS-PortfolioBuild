from __future__ import annotations

import json
from pathlib import Path
import sqlite3
import sys

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


@pytest.fixture(autouse=True)
def _isolate_copy_failure_log(monkeypatch, tmp_path):
    """Redirect the forensic JSONL off the real ops path during tests."""

    monkeypatch.setattr(
        terminal_worker,
        "CUSTOM_HISTORY_COPY_FAILURE_LOG",
        tmp_path / "custom_history_copy_on_claim_failures.jsonl",
    )


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


def test_master_repair_partial_transient_io_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    # Every repair failure a copy race / resource artifact while the master
    # vouches -> defer this claim only (2026-08-14 21:49Z over-containment).
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: _failing_gate(
            terminal,
            findings=[{"code": "MANIFEST_ARCHIVE_FILE_MISSING", "terminal": "T8"}],
            master_repair={
                "status": "PARTIAL_TRANSIENT_IO",
                "failed_count": 1,
                "failed_transient_io_count": 1,
            },
        ),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T8")

    assert gate["status"] == "FAIL_CLOSED"
    assert calls == []


def test_master_repair_error_transient_io_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        lambda root, terminal: _failing_gate(
            terminal,
            findings=[{"code": "MANIFEST_ARCHIVE_FILE_MISSING", "terminal": "T2"}],
            master_repair={"status": "ERROR_TRANSIENT_IO", "error": "OSError(22, ...)"},
        ),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T2")

    assert gate["status"] == "FAIL_CLOSED"
    assert calls == []


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


def test_resource_exhaustion_oserror_defers_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    def raise_no_system_resources(root, terminal):
        exc = OSError(
            22, "Insufficient system resources exist to complete the requested service"
        )
        exc.winerror = 1450
        raise exc

    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "run_worker_gate",
        raise_no_system_resources,
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T1")

    assert gate["status"] == "FAIL_CLOSED"
    assert gate["reason"] == "custom_history_gate_transient_io"
    assert calls == []


def test_enomem_oserror_defers_without_containment(monkeypatch, tmp_path: Path) -> None:
    import errno as _errno

    def raise_enomem(root, terminal):
        raise OSError(_errno.ENOMEM, "Not enough space")

    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "run_worker_gate", raise_enomem
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T7")

    assert gate["reason"] == "custom_history_gate_transient_io"
    assert calls == []


def test_unlisted_oserror_still_engages_containment(monkeypatch, tmp_path: Path) -> None:
    def raise_crc_error(root, terminal):
        exc = OSError(5, "Data error (cyclic redundancy check)")
        exc.winerror = 23
        raise exc

    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "run_worker_gate", raise_crc_error
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append((root, kwargs)),
    )

    gate = terminal_worker._custom_history_gate(tmp_path, "T3")

    assert gate["reason"] == "custom_history_gate_exception"
    assert len(calls) == 1
    assert calls[0][1]["reason"] == "custom_history_gate_exception:OSError"


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


# --- Copy-on-claim failure blast-radius classification (2026-09-02) --------
# INTEGRITY -> fleet-wide containment; CLAIM_LOCAL / TRANSIENT -> quarantine this
# terminal only. Four claim-local copy failures serialized the whole fleet for
# ~12h on 01./02.09, and the 07:02Z trip left no log line anywhere.

_COC = terminal_worker.custom_history_copy_on_claim

_CLAIM_ROW = {
    "id": "item-x",
    "payload_json": "{}",
    "ea_id": "QM5_1",
    "symbol": "EURUSD.DWX",
}
_PASS_GATE = {"required": True, "status": "PASS_ISOLATED", "activation_sha256": "a" * 64}


def _force_copy_failure(monkeypatch, tmp_path, raiser) -> None:
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(
        terminal_worker.custom_history_gate,
        "load_activation",
        lambda root: {"manifest_path": str(manifest_path)},
    )
    monkeypatch.setattr(
        terminal_worker.custom_history_contract,
        "load_manifest",
        lambda path, require_owner_approval=True: {"files": []},
    )
    monkeypatch.setattr(
        terminal_worker.custom_history_copy_on_claim,
        "privatize_terminal_archives",
        raiser,
    )


def _raiser(exc):
    def _run(**kwargs):
        raise exc

    return _run


def _row(item_id: str) -> dict:
    return {**_CLAIM_ROW, "id": item_id}


def test_claim_local_copy_error_quarantines_terminal_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    _force_copy_failure(
        monkeypatch,
        tmp_path,
        _raiser(_COC.CustomHistoryCopyOnClaimError("boom", reason_code=_COC.CLAIM_LOCAL)),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append(kwargs),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-cl"), "T3", _PASS_GATE
    )

    assert result["status"] == "FAIL_CLOSED"
    assert result["reason_code"] == "CLAIM_LOCAL"
    assert result["fleet_containment_engaged"] is False
    assert result["terminal_quarantined"] is True
    assert calls == []
    marker = terminal_worker._custom_history_quarantine_active(tmp_path, "T3")
    assert marker is not None
    assert marker["reason_code"] == "CLAIM_LOCAL"
    assert marker["item_id"] == "item-cl"
    lines = (
        terminal_worker.CUSTOM_HISTORY_COPY_FAILURE_LOG.read_text(encoding="utf-8")
        .strip()
        .splitlines()
    )
    assert len(lines) == 1
    event = json.loads(lines[0])
    assert event["reason_code"] == "CLAIM_LOCAL"
    assert event["fleet_containment_engaged"] is False
    assert event["terminal_quarantined"] is True
    assert event["item_id"] == "item-cl"


@pytest.mark.parametrize(
    "message",
    [
        "manifest has no archive rows for claimed symbols: XCUUSD.DWX",
        "claim declares no .DWX host/conversion/basket history symbols",
    ],
)
def test_item_bound_copy_error_holds_item_without_terminal_quarantine(
    monkeypatch, tmp_path: Path, message: str
) -> None:
    _force_copy_failure(
        monkeypatch,
        tmp_path,
        _raiser(
            _COC.CustomHistoryCopyOnClaimError(
                message, reason_code=_COC.CLAIM_LOCAL
            )
        ),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-poison"), "T3", _PASS_GATE
    )

    assert result["status"] == "FAIL_CLOSED"
    assert result["item_hold_code"] == "CUSTOM_HISTORY_SYMBOL_NOT_IN_MANIFEST"
    assert result["terminal_quarantined"] is False
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T3") is None


def test_custom_history_item_hold_is_durable_non_restart_and_audited() -> None:
    conn = sqlite3.connect(":memory:")
    conn.executescript(
        """
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY, hold_code TEXT, reason TEXT,
          active INTEGER, release_on_restart INTEGER, created_at TEXT,
          updated_at TEXT, released_at TEXT, release_note TEXT
        );
        CREATE TABLE events(
          ts TEXT, entity_type TEXT, entity_id TEXT, event TEXT, detail_json TEXT
        );
        """
    )
    payload: dict = {}

    terminal_worker._hold_custom_history_item(
        conn,
        {"id": "poison-1"},
        payload,
        "2026-09-02T10:00:00+00:00",
        "manifest has no archive rows for claimed symbols: XCUUSD.DWX",
    )

    hold = conn.execute("SELECT * FROM work_item_holds").fetchone()
    event = conn.execute("SELECT event,detail_json FROM events").fetchone()
    assert hold[1] == "CUSTOM_HISTORY_SYMBOL_NOT_IN_MANIFEST"
    assert hold[3] == 1
    assert hold[4] == 0
    assert event[0] == "custom_history_item_held"
    assert json.loads(event[1])["release_on_restart"] is False
    assert payload["custom_history_item_hold"]["hold_code"] == hold[1]


def test_transient_copy_race_error_quarantines_without_containment(
    monkeypatch, tmp_path: Path
) -> None:
    _force_copy_failure(
        monkeypatch,
        tmp_path,
        _raiser(_COC.CustomHistoryCopyOnClaimError("race", reason_code=_COC.TRANSIENT)),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append(kwargs),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-tr"), "T5", _PASS_GATE
    )

    assert result["reason_code"] == "TRANSIENT"
    assert result["terminal_quarantined"] is True
    assert calls == []


def test_integrity_copy_error_engages_containment_and_logs(
    monkeypatch, tmp_path: Path
) -> None:
    _force_copy_failure(
        monkeypatch,
        tmp_path,
        _raiser(_COC.CustomHistoryCopyOnClaimError("breach", reason_code=_COC.INTEGRITY)),
    )
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append(kwargs),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-int"), "T7", _PASS_GATE
    )

    assert result["status"] == "FAIL_CLOSED"
    assert result["reason_code"] == "INTEGRITY"
    assert result["fleet_containment_engaged"] is True
    assert len(calls) == 1
    # An integrity breach contains the whole fleet; it does NOT quarantine one seat.
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T7") is None
    lines = (
        terminal_worker.CUSTOM_HISTORY_COPY_FAILURE_LOG.read_text(encoding="utf-8")
        .strip()
        .splitlines()
    )
    assert json.loads(lines[0])["fleet_containment_engaged"] is True


def test_unclassified_non_transient_error_fails_safe_to_containment(
    monkeypatch, tmp_path: Path
) -> None:
    _force_copy_failure(monkeypatch, tmp_path, _raiser(ValueError("activation corrupt")))
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append(kwargs),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-u"), "T2", _PASS_GATE
    )

    assert result["reason_code"] == "UNCLASSIFIED"
    assert result["fleet_containment_engaged"] is True
    assert len(calls) == 1


def test_wrapped_claim_local_cause_is_not_contained(
    monkeypatch, tmp_path: Path
) -> None:
    def _raise_wrapped(**kwargs):
        try:
            raise _COC.CustomHistoryCopyOnClaimError(
                "custom root missing", reason_code=_COC.CLAIM_LOCAL
            )
        except Exception as exc:
            raise RuntimeError("privatization wrapper") from exc

    _force_copy_failure(monkeypatch, tmp_path, _raise_wrapped)
    calls = []
    monkeypatch.setattr(
        terminal_worker.custom_history_lease,
        "engage_emergency_mode",
        lambda root, **kwargs: calls.append(kwargs),
    )

    result = terminal_worker._privatize_custom_history_claim(
        tmp_path, _row("item-w"), "T4", _PASS_GATE
    )

    assert result["reason_code"] == "CLAIM_LOCAL"
    assert result["terminal_quarantined"] is True
    assert calls == []


def test_quarantine_marker_active_then_expires(tmp_path: Path) -> None:
    from datetime import datetime, timezone

    marker = terminal_worker._write_custom_history_quarantine(
        tmp_path, "T6", reason_code="CLAIM_LOCAL", item_id="i1", error="boom"
    )
    assert marker is not None
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T6") is not None
    record = json.loads(marker.read_text(encoding="utf-8"))
    record["expires_at_utc"] = datetime(2000, 1, 1, tzinfo=timezone.utc).isoformat()
    marker.write_text(json.dumps(record), encoding="utf-8")
    # An expired marker is treated as absent and self-clears (no operator needed).
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T6") is None
    assert not marker.exists()


def test_absent_or_corrupt_marker_is_fail_open(tmp_path: Path) -> None:
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T8") is None
    path = terminal_worker._custom_history_quarantine_path(tmp_path, "T8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("{not json", encoding="utf-8")
    assert terminal_worker._custom_history_quarantine_active(tmp_path, "T8") is None


def test_run_loop_skips_quarantined_terminal_before_claim() -> None:
    source = Path(terminal_worker.__file__).read_text(encoding="utf-8")
    loop = source[
        source.index("def run_loop") : source.index("def _fail_item_after_worker_crash")
    ]
    assert "_custom_history_quarantine_active(root, terminal)" in loop
    assert loop.index("_custom_history_quarantine_active(root, terminal)") < loop.index(
        "claim_atomic(root, terminal)"
    )
