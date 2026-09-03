"""Tests for the account/portfolio governor action adapter (SP-C1 gap G6).

The adapter ships DISABLED: enforce mode is unreachable without an OWNER
enforce-activation artifact bound to the triggering policy. Dry-run never
touches the live account. These tests assert every one of those boundaries on
a fake account executor, plus atomicity and idempotency of the single enforce
action.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

from tools.strategy_farm import account_portfolio_governor as governor
from tools.strategy_farm import account_governor_action_adapter as adapter


LOGIN = 4000090541
T0 = dt.datetime(2026, 8, 23, 8, 0, tzinfo=dt.UTC)


class FakeAccountExecutor(adapter.AccountActionExecutor):
    """Records apply() calls and enforces idempotency by decision_id.

    ``side_effects`` models the single atomic live-account action (writing the
    account-wide entry-freeze signal + handing over cancel/flatten ticket
    lists). It grows once per distinct decision, never on an idempotent repeat.
    """

    def __init__(self) -> None:
        self.apply_calls: list[dict] = []
        self.applied_ids: set[str] = set()
        self.side_effects: list[dict] = []

    def apply(self, instruction: dict) -> dict:
        self.apply_calls.append(instruction)
        did = instruction["decision_id"]
        if did in self.applied_ids:
            return {"decision_id": did, "idempotent_skip": True}
        self.applied_ids.add(did)
        self.side_effects.append(
            {
                "decision_id": did,
                "wrote_entry_freeze_signal": instruction["entry_freeze"],
                "signal_path": instruction["entry_freeze_signal_path"],
                "cancelled_order_tickets": instruction["cancel_order_tickets"],
                "flattened_position_tickets": instruction["flatten_position_tickets"],
            }
        )
        return {
            "decision_id": did,
            "idempotent_skip": False,
            "applied": True,
            "entry_freeze_written": instruction["entry_freeze"],
            "cancelled_order_tickets": instruction["cancel_order_tickets"],
            "flattened_position_tickets": instruction["flatten_position_tickets"],
        }


def _position(ticket: int, magic: int, symbol: str, side: str, base: str) -> dict:
    return {
        "ticket": ticket,
        "identifier": ticket + 1000,
        "magic": magic,
        "symbol": symbol,
        "type": side,
        "volume": 1.0,
        "price_open": 100.0,
        "price_current": 101.0,
        "sl": 95.0,
        "tp": 110.0,
        "profit": 100.0,
        "swap": 0.0,
        "base_currency": base,
        "profit_currency": "USD",
        "notional_account_ok": True,
        "signed_notional_account": 10_000.0 if side == "BUY" else -10_000.0,
        "stop_loss_account_ok": True,
        "remaining_loss_to_sl_account": 250.0,
    }


def _snapshot(*, positions: list[dict], orders: list[dict], observed_at: str) -> dict:
    return {
        "schema": governor.SNAPSHOT_SCHEMA,
        "account_login": LOGIN,
        "time_utc": observed_at,
        "equity": 100_000.0,
        "balance": 99_500.0,
        "margin": 5_000.0,
        "free_margin": 95_000.0,
        "open_positions": len(positions),
        "pending_orders": len(orders),
        "reconciled_positions": len(positions),
        "reconciled_orders": len(orders),
        "reconciliation_complete": True,
        "gross_notional_account": sum(abs(p["signed_notional_account"]) for p in positions),
        "net_directional_notional_account": sum(
            p["signed_notional_account"] for p in positions
        ),
        "planned_stop_loss_account": sum(
            p["remaining_loss_to_sl_account"] for p in positions
        ),
        "unpriced_positions": 0,
        "positions_without_stop": 0,
        "write_ok": True,
        "positions": positions,
        "orders": orders,
    }


def _write_policy(path: Path, *, gross_ceiling: float) -> tuple[governor.BoundPolicy, str]:
    payload = {
        "schema": governor.POLICY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-23T00:00:00Z",
        "valid_until_utc": "2026-08-24T00:00:00Z",
        "stage2_cancel_pending_authorized": True,
        "thresholds": {
            "min_free_margin_account": 1_000.0,
            "max_gross_leverage": gross_ceiling,
            "max_abs_currency_net_leverage": 5.0,
            "max_planned_stop_loss_account": 10_000.0,
        },
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    bound = governor._load_bound_policy(
        path, sha, schema=governor.POLICY_SCHEMA, now_utc=T0,
        expected_login=LOGIN, label="policy",
    )
    return bound, sha


def _write_activation(
    path: Path, *, trigger_sha: str, valid_until: str = "2026-08-24T00:00:00Z"
) -> tuple[adapter.ActivationGrant, str]:
    payload = {
        "schema": adapter.ACTIVATION_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-23T00:00:00Z",
        "valid_until_utc": valid_until,
        "enforce_authorized": True,
        "trigger_policy_sha256": trigger_sha,
        "activation_decision_ref": "decisions/2026-08-23_TEST_enforce_activation.md",
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    grant = adapter.load_activation(
        path, sha, now_utc=T0, expected_login=LOGIN, trigger_policy_sha256=trigger_sha,
    )
    return grant, sha


def _breach_decision(now: dt.datetime, *, policy: governor.BoundPolicy) -> dict:
    """A fresh level-2 breach decision: one position, one pending order, gross
    leverage above the trivially-low policy ceiling."""
    snapshot = _snapshot(
        positions=[_position(101, 111320000, "EURUSD", "BUY", "EUR")],
        orders=[{"ticket": 201, "magic": 0, "symbol": "EURUSD", "type": "BUY_LIMIT"}],
        observed_at=(now - dt.timedelta(seconds=30)).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )
    decision = governor.evaluate(
        snapshot, now_utc=now, expected_login=LOGIN, max_age_seconds=90, policy=policy,
    )
    assert decision["decision"]["level"] == 2  # guard the fixture
    return decision


# --------------------------------------------------------------------------- #
# activation gate absent -> enforce refused with a structured reason
# --------------------------------------------------------------------------- #
def test_enforce_refused_without_activation_artifact(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    decision = _breach_decision(T0, policy=policy)
    executor = FakeAccountExecutor()

    grant, reason = adapter.resolve_activation(
        activation_path=None, trusted_sha256=None, now_utc=T0,
        expected_login=LOGIN, policy=policy,
    )
    assert grant is None
    assert reason == "enforce_activation_artifact_absent"

    receipt = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=T0,
        activation_grant=grant, activation_reason=reason, executor=executor,
    )
    assert receipt["outcome"] == "ENFORCE_REFUSED"
    assert receipt["refusal_reason"] == "enforce_activation_artifact_absent"
    assert receipt["enforcement_activated"] is False
    assert receipt["executed"] is False
    assert receipt["actions_executed"] == []
    # The live account is never touched when enforcement is not activated.
    assert executor.apply_calls == []
    assert executor.side_effects == []


def test_enforce_refused_without_bound_policy() -> None:
    grant, reason = adapter.resolve_activation(
        activation_path=None, trusted_sha256=None, now_utc=T0,
        expected_login=LOGIN, policy=None,
    )
    assert grant is None
    assert reason == "enforce_requires_bound_owner_policy"


def test_activation_refused_when_bound_to_a_different_policy(tmp_path: Path) -> None:
    policy_a, _ = _write_policy(tmp_path / "policy_a.json", gross_ceiling=0.05)
    policy_b, _ = _write_policy(tmp_path / "policy_b.json", gross_ceiling=0.06)
    # Activation is bound to policy A's hash, but resolve against policy B.
    _write_activation(tmp_path / "activation.json", trigger_sha=policy_a.sha256)
    act_sha = hashlib.sha256((tmp_path / "activation.json").read_bytes()).hexdigest()

    grant, reason = adapter.resolve_activation(
        activation_path=tmp_path / "activation.json", trusted_sha256=act_sha,
        now_utc=T0, expected_login=LOGIN, policy=policy_b,
    )
    assert grant is None
    assert reason == "enforce_activation_trigger_policy_binding_mismatch"


# --------------------------------------------------------------------------- #
# dry-run produces receipts and NO live writes (assert on a fake executor)
# --------------------------------------------------------------------------- #
def test_dry_run_writes_receipt_and_never_touches_the_executor(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    decision = _breach_decision(T0, policy=policy)
    executor = FakeAccountExecutor()

    receipt = adapter.run_adapter(
        decision, mode=adapter.MODE_DRY_RUN, now_utc=T0, executor=executor,
    )
    assert receipt["outcome"] == "DRY_RUN_PLAN"
    assert receipt["dry_run"] is True
    assert receipt["executed"] is False
    assert receipt["actions_executed"] == []
    # Plan is concrete even in dry-run: level-2 lists the pending ticket.
    assert receipt["instruction"]["entry_freeze"] is True
    assert receipt["instruction"]["cancel_order_tickets"] == [201]
    assert receipt["instruction"]["flatten_position_tickets"] == []
    # NO live account write in dry-run, even with an executor injected.
    assert executor.apply_calls == []
    assert executor.side_effects == []

    out_dir = tmp_path / "receipts"
    written = adapter.write_receipt(receipt, out_dir=out_dir)
    assert written is not None and written.exists()
    assert written.parent == out_dir
    reloaded = json.loads(written.read_text(encoding="utf-8"))
    assert reloaded["decision_id"] == receipt["decision_id"]
    assert reloaded["actions_executed"] == []


def test_write_receipt_defaults_to_no_file_without_out_or_apply_flag(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    decision = _breach_decision(T0, policy=policy)
    receipt = adapter.run_adapter(decision, mode=adapter.MODE_DRY_RUN, now_utc=T0)
    # No --out and no --apply-dry-run-receipts -> nothing is written anywhere.
    assert adapter.write_receipt(receipt, out_dir=None, apply_dry_run_receipts=False) is None


# --------------------------------------------------------------------------- #
# stale inputs -> refuse
# --------------------------------------------------------------------------- #
def test_enforce_refuses_stale_decision(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    grant, reason = _grant(tmp_path, policy)
    decision = _breach_decision(T0, policy=policy)  # generated_at == T0
    executor = FakeAccountExecutor()

    # Ten minutes later, past the 180 s decision-age tolerance.
    later = T0 + dt.timedelta(minutes=10)
    receipt = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=later,
        activation_grant=grant, activation_reason=reason, executor=executor,
        max_decision_age_seconds=adapter.DEFAULT_MAX_DECISION_AGE_SECONDS,
    )
    assert receipt["outcome"] == "ENFORCE_REFUSED"
    assert receipt["refusal_reason"].startswith("input_stale:")
    assert "decision_stale" in receipt["refusal_reason"]
    assert receipt["executed"] is False
    assert executor.apply_calls == []
    assert executor.side_effects == []


# --------------------------------------------------------------------------- #
# limit breach in dry-run -> recorded decision, no action
# --------------------------------------------------------------------------- #
def test_limit_breach_dry_run_records_plan_but_no_action(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    decision = _breach_decision(T0, policy=policy)
    receipt = adapter.run_adapter(decision, mode=adapter.MODE_DRY_RUN, now_utc=T0)
    assert receipt["decision_level"] == 2
    assert receipt["decision_name"] == "PENDING_CANCEL_AND_ENTRY_FREEZE"
    assert receipt["outcome"] == "DRY_RUN_PLAN"
    assert receipt["actions_executed"] == []
    assert receipt["instruction"]["cancel_order_tickets"] == [201]


# --------------------------------------------------------------------------- #
# limit breach in mocked enforce mode with a fake adapter -> exactly one action
# --------------------------------------------------------------------------- #
def _grant(tmp_path: Path, policy: governor.BoundPolicy) -> tuple[adapter.ActivationGrant, str]:
    grant, act_sha = _write_activation(tmp_path / "activation.json", trigger_sha=policy.sha256)
    reason = None
    resolved, reason = adapter.resolve_activation(
        activation_path=tmp_path / "activation.json", trusted_sha256=act_sha,
        now_utc=T0, expected_login=LOGIN, policy=policy,
    )
    assert resolved is not None and reason is None
    return resolved, reason


def test_enforce_breach_applies_exactly_one_atomic_action(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    grant, reason = _grant(tmp_path, policy)
    decision = _breach_decision(T0, policy=policy)
    executor = FakeAccountExecutor()

    receipt = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=T0,
        activation_grant=grant, activation_reason=reason, executor=executor,
    )
    assert receipt["outcome"] == "ENFORCE_APPLIED"
    assert receipt["enforcement_activated"] is True
    assert receipt["execution_adapter_present"] is True
    assert receipt["executed"] is True
    # Exactly one atomic action for the tick.
    assert len(executor.apply_calls) == 1
    assert len(executor.side_effects) == 1
    assert len(receipt["actions_executed"]) == 1
    effect = executor.side_effects[0]
    assert effect["wrote_entry_freeze_signal"] is True
    assert effect["cancelled_order_tickets"] == [201]
    assert effect["flattened_position_tickets"] == []  # no emergency policy -> no flatten


def test_enforce_is_idempotent_on_rerun_of_the_same_decision(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    grant, reason = _grant(tmp_path, policy)
    decision = _breach_decision(T0, policy=policy)
    executor = FakeAccountExecutor()

    first = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=T0,
        activation_grant=grant, activation_reason=reason, executor=executor,
    )
    # Re-run the identical decision at a still-fresh time.
    second = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=T0 + dt.timedelta(seconds=30),
        activation_grant=grant, activation_reason=reason, executor=executor,
    )
    assert first["decision_id"] == second["decision_id"]
    assert first["outcome"] == "ENFORCE_APPLIED"
    assert second["outcome"] == "ENFORCE_APPLIED_IDEMPOTENT_NOOP"
    # apply() was called on both ticks, but the live action happened exactly once.
    assert len(executor.apply_calls) == 2
    assert len(executor.side_effects) == 1
    assert executor.applied_ids == {first["decision_id"]}

    # Idempotent receipts: same decision_id overwrites one file, atomically.
    out_dir = tmp_path / "receipts"
    p1 = adapter.write_receipt(first, out_dir=out_dir)
    p2 = adapter.write_receipt(second, out_dir=out_dir)
    assert p1 == p2
    assert len(list(out_dir.glob("account_governor_action_receipt_*.json"))) == 1


def test_no_execution_adapter_present_refuses_even_with_valid_activation(tmp_path: Path) -> None:
    policy, _ = _write_policy(tmp_path / "policy.json", gross_ceiling=0.05)
    grant, reason = _grant(tmp_path, policy)
    decision = _breach_decision(T0, policy=policy)
    # executor is None: the production wiring. Enforce must still refuse.
    receipt = adapter.run_adapter(
        decision, mode=adapter.MODE_ENFORCE, now_utc=T0,
        activation_grant=grant, activation_reason=reason, executor=None,
    )
    assert receipt["outcome"] == "ENFORCE_REFUSED"
    assert receipt["refusal_reason"] == "no_execution_adapter_present"
    assert receipt["executed"] is False


# --------------------------------------------------------------------------- #
# CLI: ships disabled end to end
# --------------------------------------------------------------------------- #
def test_cli_dry_run_writes_receipt_and_returns_zero(monkeypatch, tmp_path: Path) -> None:
    snapshot_path = tmp_path / "snapshot.json"
    snapshot_path.write_text(
        json.dumps(
            _snapshot(
                positions=[_position(101, 111320000, "EURUSD", "BUY", "EUR")],
                orders=[],
                observed_at="2026-08-23T07:59:30Z",
            )
        ),
        encoding="utf-8",
    )
    out_dir = tmp_path / "receipts"
    monkeypatch.setattr(
        sys, "argv",
        [
            "account_governor_action_adapter.py",
            "--snapshot", str(snapshot_path),
            "--expected-login", str(LOGIN),
            "--out", str(out_dir),
            "--now-utc", "2026-08-23T08:00:00Z",
        ],
    )
    assert adapter.main() == 0
    receipts = list(out_dir.glob("account_governor_action_receipt_*.json"))
    assert len(receipts) == 1
    body = json.loads(receipts[0].read_text(encoding="utf-8"))
    assert body["mode"] == "dry_run"
    assert body["actions_executed"] == []


def test_cli_enforce_refused_without_activation(monkeypatch, tmp_path: Path) -> None:
    snapshot_path = tmp_path / "snapshot.json"
    policy_path = tmp_path / "policy.json"
    _write_policy(policy_path, gross_ceiling=0.05)
    policy_sha = hashlib.sha256(policy_path.read_bytes()).hexdigest()
    snapshot_path.write_text(
        json.dumps(
            _snapshot(
                positions=[_position(101, 111320000, "EURUSD", "BUY", "EUR")],
                orders=[{"ticket": 201, "magic": 0, "symbol": "EURUSD", "type": "BUY_LIMIT"}],
                observed_at="2026-08-23T07:59:30Z",
            )
        ),
        encoding="utf-8",
    )
    monkeypatch.delenv(adapter.ACTIVATION_ENV, raising=False)
    monkeypatch.setattr(
        sys, "argv",
        [
            "account_governor_action_adapter.py",
            "--enforce",
            "--snapshot", str(snapshot_path),
            "--policy", str(policy_path),
            "--trusted-policy-sha256", policy_sha,
            "--expected-login", str(LOGIN),
            "--now-utc", "2026-08-23T08:00:00Z",
        ],
    )
    # Ships disabled: enforce from the CLI is refused (return code 3).
    assert adapter.main() == 3
