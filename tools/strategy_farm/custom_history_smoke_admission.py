#!/usr/bin/env python3
"""Fail-closed Custom-history gate and farm reservation for run_smoke.ps1."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Callable

try:
    import custom_history_gate
    import farmctl
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm import custom_history_gate, farmctl


PASS_STATUSES = frozenset({"PASS_ISOLATED", "PASS_SERIALIZED_ROLLBACK"})


class SmokeAdmissionError(RuntimeError):
    """The requested smoke terminal cannot be reserved safely."""


def _active_claims(root: Path, terminal: str) -> list[dict[str, Any]]:
    try:
        with farmctl.connect(root) as conn:
            rows = conn.execute(
                """
                SELECT id, ea_id, phase, symbol, claimed_by
                FROM work_items
                WHERE status='active' AND UPPER(COALESCE(claimed_by, ''))=?
                ORDER BY updated_at ASC, id ASC
                """,
                (terminal,),
            ).fetchall()
    except Exception as exc:
        raise SmokeAdmissionError(
            f"cannot prove terminal claim state for {terminal}: {exc}"
        ) from exc
    return [dict(row) for row in rows]


def reserve_smoke_terminal(
    root: Path,
    *,
    terminal: str,
    reserved_by: str,
    minutes: int,
    expected_work_item_id: str | None = None,
    gate_runner: Callable[..., dict[str, Any]] = custom_history_gate.run_worker_gate,
) -> dict[str, Any]:
    """Check isolation/ramp state and claim the farm reservation fail-closed."""

    target = str(terminal or "").strip().upper()
    owner = str(reserved_by or "").strip()
    expected_claim = str(expected_work_item_id or "").strip()
    if not farmctl.is_factory_terminal_name(target):
        raise SmokeAdmissionError(f"not a factory terminal: {target}")
    if not owner:
        raise SmokeAdmissionError("reserved_by is required")
    if int(minutes) <= 0:
        raise SmokeAdmissionError("reservation minutes must be positive")

    try:
        gate = gate_runner(root, terminal=target)
    except Exception as exc:
        raise SmokeAdmissionError(
            f"Custom-history isolation gate raised for {target}: {exc}"
        ) from exc
    if gate.get("required") and (
        gate.get("status") not in PASS_STATUSES
        or gate.get("admission_allowed") is False
    ):
        raise SmokeAdmissionError(
            "Custom-history isolation gate holds "
            f"{target}: status={gate.get('status')} reason={gate.get('reason')}"
        )
    if gate.get("required") and not expected_claim:
        raise SmokeAdmissionError(
            "active Custom-history isolation requires a worker-bound work item "
            "whose archives were privatized before run_smoke"
        )

    existing = farmctl.terminal_reservation(root, target)
    if existing is not None:
        raise SmokeAdmissionError(
            f"terminal {target} already reserved by {existing.get('reserved_by')} "
            f"until {existing.get('until_utc')}"
        )
    active_before = _active_claims(root, target)
    if expected_claim:
        active_ids = {str(row["id"]) for row in active_before}
        if active_ids != {expected_claim}:
            raise SmokeAdmissionError(
                f"terminal {target} active-claim binding mismatch: "
                f"expected={expected_claim} observed={sorted(active_ids)}"
            )
    elif active_before:
        raise SmokeAdmissionError(
            f"terminal {target} has an active farm claim: {active_before[0]['id']}"
        )

    reservation = farmctl.set_terminal_reservation(
        root,
        target,
        owner,
        minutes=int(minutes),
        reason="run_smoke_custom_history_admission",
    )
    observed = farmctl.terminal_reservation(root, target)
    if observed is None or observed.get("reserved_by") != owner:
        raise SmokeAdmissionError(
            f"terminal {target} reservation ownership could not be verified"
        )

    # Close the claim/reservation race: a worker that began its transaction
    # just before the reservation write may already have claimed the slot.
    active_after = _active_claims(root, target)
    active_after_ids = {str(row["id"]) for row in active_after}
    active_after_valid = (
        active_after_ids == {expected_claim} if expected_claim else not active_after_ids
    )
    if not active_after_valid:
        release_smoke_terminal(root, terminal=target, reserved_by=owner)
        raise SmokeAdmissionError(
            f"terminal {target} claim changed while being reserved: "
            f"expected={expected_claim or '<none>'} observed={sorted(active_after_ids)}"
        )
    return {
        "status": "PASS_RESERVED",
        "terminal": target,
        "reserved_by": owner,
        "expected_work_item_id": expected_claim or None,
        "reservation": reservation,
        "custom_history_gate": gate,
    }


def release_smoke_terminal(
    root: Path,
    *,
    terminal: str,
    reserved_by: str,
) -> dict[str, Any]:
    """Release only the reservation owned by this run_smoke invocation."""

    target = str(terminal or "").strip().upper()
    owner = str(reserved_by or "").strip()
    existing = farmctl.terminal_reservation(root, target)
    if existing is None:
        return {"status": "ALREADY_RELEASED", "terminal": target, "released": False}
    if existing.get("reserved_by") != owner:
        raise SmokeAdmissionError(
            f"refusing to release {target}; reservation belongs to "
            f"{existing.get('reserved_by')}, not {owner}"
        )
    result = farmctl.release_terminal_reservation(root, target)
    return {"status": "RELEASED", **result}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--farm-root", type=Path, default=farmctl.DEFAULT_ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    reserve = sub.add_parser("reserve")
    reserve.add_argument("--terminal", required=True)
    reserve.add_argument("--reserved-by", required=True)
    reserve.add_argument("--minutes", type=int, required=True)
    reserve.add_argument("--expected-work-item-id")
    release = sub.add_parser("release")
    release.add_argument("--terminal", required=True)
    release.add_argument("--reserved-by", required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "reserve":
            payload = reserve_smoke_terminal(
                args.farm_root,
                terminal=args.terminal,
                reserved_by=args.reserved_by,
                minutes=args.minutes,
                expected_work_item_id=args.expected_work_item_id,
            )
        else:
            payload = release_smoke_terminal(
                args.farm_root,
                terminal=args.terminal,
                reserved_by=args.reserved_by,
            )
    except SmokeAdmissionError as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(payload, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
