from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm import custom_history_smoke_admission as admission


def test_ramp_hold_refuses_before_reservation(monkeypatch, tmp_path: Path) -> None:
    calls: list[object] = []
    monkeypatch.setattr(
        admission.farmctl,
        "set_terminal_reservation",
        lambda *args, **kwargs: calls.append((args, kwargs)),
    )

    with pytest.raises(admission.SmokeAdmissionError, match="custom_history_ramp_hold"):
        admission.reserve_smoke_terminal(
            tmp_path,
            terminal="T5",
            reserved_by="run-smoke-test",
            minutes=30,
            gate_runner=lambda root, terminal: {
                "required": True,
                "status": "PASS_ISOLATED",
                "admission_allowed": False,
                "reason": "custom_history_ramp_hold",
            },
        )

    assert calls == []


def test_active_isolation_refuses_unbound_direct_factory_smoke(
    monkeypatch, tmp_path: Path
) -> None:
    calls: list[object] = []
    monkeypatch.setattr(
        admission.farmctl,
        "set_terminal_reservation",
        lambda *args, **kwargs: calls.append((args, kwargs)),
    )

    with pytest.raises(admission.SmokeAdmissionError, match="worker-bound"):
        admission.reserve_smoke_terminal(
            tmp_path,
            terminal="T1",
            reserved_by="direct-smoke",
            minutes=30,
            gate_runner=lambda root, terminal: {
                "required": True,
                "status": "PASS_ISOLATED",
                "admission_allowed": True,
            },
        )
    assert calls == []


def test_worker_bound_smoke_reserves_and_releases_its_terminal(
    monkeypatch, tmp_path: Path
) -> None:
    state: dict[str, dict | None] = {"reservation": None}
    work_item_id = "work-item-1"
    monkeypatch.setattr(
        admission,
        "_active_claims",
        lambda root, terminal: [{"id": work_item_id}],
    )
    monkeypatch.setattr(
        admission.farmctl,
        "terminal_reservation",
        lambda root, terminal: state["reservation"],
    )

    def set_reservation(root, terminal, owner, minutes, reason):
        state["reservation"] = {
            "terminal": terminal,
            "reserved_by": owner,
            "until_utc": "2099-01-01T00:00:00+00:00",
            "reason": reason,
        }
        return dict(state["reservation"])

    def release_reservation(root, terminal):
        old = state["reservation"]
        state["reservation"] = None
        return {"released": True, "terminal": terminal, "reservation": old}

    monkeypatch.setattr(admission.farmctl, "set_terminal_reservation", set_reservation)
    monkeypatch.setattr(
        admission.farmctl, "release_terminal_reservation", release_reservation
    )

    receipt = admission.reserve_smoke_terminal(
        tmp_path,
        terminal="T1",
        reserved_by="run-smoke-owner",
        minutes=90,
        expected_work_item_id=work_item_id,
        gate_runner=lambda root, terminal: {
            "required": True,
            "status": "PASS_ISOLATED",
            "admission_allowed": True,
        },
    )
    assert receipt["status"] == "PASS_RESERVED"
    assert receipt["expected_work_item_id"] == work_item_id

    released = admission.release_smoke_terminal(
        tmp_path, terminal="T1", reserved_by="run-smoke-owner"
    )
    assert released["status"] == "RELEASED"
    assert state["reservation"] is None


def test_release_never_removes_another_owners_reservation(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(
        admission.farmctl,
        "terminal_reservation",
        lambda root, terminal: {"reserved_by": "someone-else"},
    )
    calls: list[object] = []
    monkeypatch.setattr(
        admission.farmctl,
        "release_terminal_reservation",
        lambda *args, **kwargs: calls.append((args, kwargs)),
    )

    with pytest.raises(admission.SmokeAdmissionError, match="someone-else"):
        admission.release_smoke_terminal(
            tmp_path, terminal="T2", reserved_by="run-smoke-owner"
        )
    assert calls == []
