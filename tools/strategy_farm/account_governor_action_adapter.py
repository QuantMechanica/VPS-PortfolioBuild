#!/usr/bin/env python3
"""Account/portfolio governor action adapter (SP-C1 gap G6, MISSING 2).

This is the DISABLED decision->instruction boundary that gap G6 requires
before the GOVERNOR-HARDENING freeze-lift condition can even be evaluated
(``docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md``:352-355;
``risk_freeze.py`` LIFT_CONDITIONS ``GOVERNOR-HARDENING``). It sits downstream
of the read-only evaluator ``account_portfolio_governor.evaluate()`` and turns
one staged decision into one atomic account-wide instruction:

- the level-1 entry freeze becomes an account-wide pre-trade gate signal that
  every EA/slot consults before opening an order (the account is shared across
  T1-T10 + T_Live, CLAUDE.md OQ-17), analogous to the existing
  ``portfolio_dd.signal`` convention (``live_book_dd_guard.py``:53-55); and
- the level-2 pending-cancel and level-3 flatten ticket lists are handed to an
  injected order-management executor.

Safety boundary (this file never relaxes it):

- The adapter never connects to MT5 and never sends/cancels/closes an order.
  The order-management executor is a separate ROT MQL-side / MT5-bridge
  component (contract ``ACCOUNT_PORTFOLIO_GOVERNOR_CONTRACT_2026-08-22.md``:125
  "a separate ROT implementation and review; none exists here"). The CLI never
  wires one, so enforce mode from the command line always refuses.
- ENFORCE MODE SHIPS DISABLED. It is unreachable unless BOTH a SHA-256-bound
  ``status: OWNER_SIGNED`` policy is bound (the same policy the evaluator
  consumes) AND a separate OWNER enforce-activation artifact is present and
  bound to that exact policy hash. No such activation artifact exists today, so
  every code path fails closed to a dry-run plan.
- Dry-run is the default. It produces receipts only; it never touches the
  executor or the live account, and it writes receipt files only to a
  caller-supplied ``--out`` directory (or, with the explicit
  ``--apply-dry-run-receipts`` flag, the live state dir named by a constant).
- No risk threshold is embedded here. Leverage / free-margin / stop-loss limits
  live only in the SHA-256-bound OWNER policy consumed by the evaluator. The
  only tolerance in this file is a decision-freshness age bound to the
  contract's equity-freshness backstop (contract:104-113, 180 s).
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:  # package import (tools.strategy_farm.X) preferred; bare fallback for CLI
    from tools.strategy_farm import account_portfolio_governor as governor
except ImportError:  # pragma: no cover - standalone script path
    import account_portfolio_governor as governor  # type: ignore[no-redef]


ADAPTER_SCHEMA = "qm.account-governor.action-adapter-receipt/v1"
ACTIVATION_SCHEMA = "qm.account-governor.enforce-activation/v1"

# The machine env that names the OWNER enforce-activation artifact and its
# trusted SHA-256. Absent in production, so enforce mode is structurally
# unreachable from the CLI (ships DISABLED). A signed ``decisions/`` artifact is
# the canonical activation source; this env only points the adapter at it.
ACTIVATION_ENV = "QM_ACCOUNT_GOVERNOR_ENFORCE_ACTIVATION"
ACTIVATION_SHA_ENV = "QM_ACCOUNT_GOVERNOR_ENFORCE_ACTIVATION_SHA256"

# Account-wide pre-trade entry-freeze signal target. Named constant only: the
# adapter never writes it directly. In enforce mode the injected ROT executor
# writes it; no production executor exists. Mirrors the terminal-local halt-dir
# convention of ``live_book_dd_guard.py``:53-55.
DEFAULT_ENTRY_FREEZE_SIGNAL = Path(
    r"C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/halt/account_entry_freeze.signal"
)

# Receipt sink used ONLY when --apply-dry-run-receipts is passed (default off).
# Named constant referencing the live state dir; nothing is written here on the
# default dry-run path.
DEFAULT_RECEIPT_DIR = Path(r"D:/QM/reports/state")

# Decision-freshness tolerance. Bound to the contract's equity-freshness
# backstop (ACCOUNT_PORTFOLIO_GOVERNOR_CONTRACT_2026-08-22.md:104-113, 180 s max
# observation age). This is NOT a risk threshold; risk limits are supplied only
# by the SHA-256-bound OWNER policy consumed by the evaluator.
DEFAULT_MAX_DECISION_AGE_SECONDS = 180.0

# T1-T10 + T_Live shared account (CLAUDE.md OQ-17); matches the guard default
# (live_book_dd_guard.py:60-61). Identity, not a limit.
DEFAULT_ACCOUNT_LOGIN = 4000090541

MODE_DRY_RUN = "dry_run"
MODE_ENFORCE = "enforce"


@dataclass(frozen=True)
class ActivationGrant:
    """A validated, SHA-256-bound OWNER enforce-activation artifact."""

    raw: dict[str, Any]
    path: Path
    sha256: str


class AccountActionExecutor:
    """Interface for the ROT order-management executor.

    No production implementation exists (contract:125). ``run_adapter`` refuses
    enforce mode whenever this is ``None``. An implementation MUST be idempotent
    on ``instruction['decision_id']``: applying the same decision twice performs
    the account-wide action at most once and reports ``idempotent_skip`` on the
    repeat.
    """

    def apply(self, instruction: dict[str, Any]) -> dict[str, Any]:  # pragma: no cover
        raise NotImplementedError(
            "no production account-action executor exists; enforce mode is ROT-gated"
        )


def _decision_id(decision: dict[str, Any]) -> str:
    """Deterministic id for one governor decision.

    Stable across re-runs of the same decision (idempotency) but distinct once a
    new snapshot observation or a different escalation is produced (one action
    per tick). Includes the snapshot observation time so a fresh tick against an
    unchanged book is still a new atomic decision.
    """
    plan = decision.get("action_plan") or {}
    inner = decision.get("decision") or {}
    analysis = decision.get("analysis") or {}
    payload = {
        "level": inner.get("level"),
        "name": inner.get("name"),
        "reasons": sorted(inner.get("reasons") or []),
        "cancel": sorted(plan.get("would_cancel_pending_order_tickets") or []),
        "flatten": sorted(plan.get("would_flatten_position_tickets") or []),
        "entry_freeze": bool(plan.get("entry_freeze")),
        "account_login": analysis.get("account_login"),
        "snapshot_observed_at_utc": analysis.get("snapshot_observed_at_utc"),
    }
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()


def build_instruction(
    decision: dict[str, Any],
    *,
    entry_freeze_signal_path: Path = DEFAULT_ENTRY_FREEZE_SIGNAL,
) -> dict[str, Any]:
    """Project one governor decision onto one atomic account-wide instruction.

    Reads only the evaluator's own ``action_plan`` ticket lists; it never
    invents a ticket or a threshold.
    """
    plan = decision.get("action_plan") or {}
    inner = decision.get("decision") or {}
    return {
        "decision_id": _decision_id(decision),
        "entry_freeze": bool(plan.get("entry_freeze")),
        "entry_freeze_signal_path": str(entry_freeze_signal_path),
        "cancel_order_tickets": list(plan.get("would_cancel_pending_order_tickets") or []),
        "flatten_position_tickets": list(plan.get("would_flatten_position_tickets") or []),
        "decision_level": inner.get("level"),
        "decision_name": inner.get("name"),
    }


def check_freshness(
    decision: dict[str, Any],
    *,
    now_utc: dt.datetime,
    max_age_seconds: float,
) -> dict[str, Any]:
    """Refuse-input gate: is this decision recent and time-fresh enough to act on?"""
    reasons: list[str] = []
    age_seconds: float | None
    try:
        generated_at = governor._parse_ts(
            decision.get("generated_at_utc"), "decision.generated_at_utc"
        )
        age_seconds = (now_utc - generated_at).total_seconds()
        if age_seconds < -5:
            reasons.append(f"decision_from_future:age_seconds={age_seconds:.3f}")
        elif age_seconds > max_age_seconds:
            reasons.append(
                f"decision_stale:age_seconds={age_seconds:.3f}:max={max_age_seconds:.3f}"
            )
    except governor.GovernorError as exc:
        age_seconds = None
        reasons.append(str(exc))
    analysis = decision.get("analysis") or {}
    if analysis.get("snapshot_fresh") is not True:
        reasons.append("snapshot_not_fresh")
    return {
        "stale": bool(reasons),
        "reasons": reasons,
        "decision_age_seconds": round(age_seconds, 3) if age_seconds is not None else None,
    }


def load_activation(
    path: Path,
    trusted_sha256: str | None,
    *,
    now_utc: dt.datetime,
    expected_login: int,
    trigger_policy_sha256: str,
    label: str = "enforce_activation",
) -> ActivationGrant:
    """Load and validate the OWNER enforce-activation artifact.

    Reuses the evaluator's own SHA-256/OWNER/validity binding, then adds the
    enforce-specific checks: it must explicitly authorize enforcement, bind the
    exact SHA-256 of the triggering stage-2 policy, and cite the ``decisions/``
    artifact that ratifies it.
    """
    bound = governor._load_bound_policy(
        path,
        str(trusted_sha256 or ""),
        schema=ACTIVATION_SCHEMA,
        now_utc=now_utc,
        expected_login=expected_login,
        label=label,
    )
    raw = bound.raw
    if raw.get("enforce_authorized") is not True:
        raise governor.GovernorError(f"{label}_enforce_not_authorized")
    if str(raw.get("trigger_policy_sha256") or "") != trigger_policy_sha256:
        raise governor.GovernorError(f"{label}_trigger_policy_binding_mismatch")
    if not str(raw.get("activation_decision_ref") or "").strip():
        raise governor.GovernorError(f"{label}_decision_ref_missing")
    return ActivationGrant(raw, bound.path, bound.sha256)


def resolve_activation(
    *,
    activation_path: Path | None,
    trusted_sha256: str | None,
    now_utc: dt.datetime,
    expected_login: int,
    policy: "governor.BoundPolicy | None",
) -> tuple[ActivationGrant | None, str | None]:
    """Return ``(grant, None)`` when enforcement is activated, else ``(None, reason)``.

    Fails closed: the default (no policy, no activation artifact) yields a
    structured reason and no grant.
    """
    if policy is None:
        return None, "enforce_requires_bound_owner_policy"
    if activation_path is None:
        return None, "enforce_activation_artifact_absent"
    try:
        grant = load_activation(
            activation_path,
            trusted_sha256,
            now_utc=now_utc,
            expected_login=expected_login,
            trigger_policy_sha256=policy.sha256,
        )
    except governor.GovernorError as exc:
        return None, str(exc)
    return grant, None


def run_adapter(
    decision: dict[str, Any],
    *,
    mode: str,
    now_utc: dt.datetime,
    activation_grant: ActivationGrant | None = None,
    activation_reason: str | None = None,
    executor: AccountActionExecutor | None = None,
    max_decision_age_seconds: float = DEFAULT_MAX_DECISION_AGE_SECONDS,
    entry_freeze_signal_path: Path = DEFAULT_ENTRY_FREEZE_SIGNAL,
) -> dict[str, Any]:
    """Produce one adapter receipt for one governor decision.

    Dry-run mode never touches ``executor`` and always reports
    ``actions_executed: []``. Enforce mode performs at most one atomic action
    (a single ``executor.apply`` call) and only when enforcement is activated,
    an executor is injected, and the decision is fresh; otherwise it refuses
    with a structured reason.
    """
    if mode not in (MODE_DRY_RUN, MODE_ENFORCE):
        raise ValueError(f"unknown_mode:{mode!r}")

    instruction = build_instruction(decision, entry_freeze_signal_path=entry_freeze_signal_path)
    freshness = check_freshness(
        decision, now_utc=now_utc, max_age_seconds=max_decision_age_seconds
    )
    inner = decision.get("decision") or {}

    outcome: str
    refusal_reason: str | None = None
    actions_executed: list[dict[str, Any]] = []
    executed = False

    if mode == MODE_DRY_RUN:
        outcome = "DRY_RUN_PLAN"
    else:  # enforce
        if activation_grant is None:
            outcome = "ENFORCE_REFUSED"
            refusal_reason = activation_reason or "enforce_activation_artifact_absent"
        elif executor is None:
            outcome = "ENFORCE_REFUSED"
            refusal_reason = "no_execution_adapter_present"
        elif freshness["stale"]:
            outcome = "ENFORCE_REFUSED"
            refusal_reason = "input_stale:" + ",".join(freshness["reasons"])
        else:
            applied = executor.apply(dict(instruction))
            actions_executed = [applied]
            executed = True
            outcome = (
                "ENFORCE_APPLIED_IDEMPOTENT_NOOP"
                if applied.get("idempotent_skip")
                else "ENFORCE_APPLIED"
            )

    return {
        "schema": ADAPTER_SCHEMA,
        "generated_at_utc": now_utc.isoformat(),
        "mode": mode,
        "enforcement_activated": activation_grant is not None,
        "execution_adapter_present": executor is not None,
        "decision_level": inner.get("level"),
        "decision_name": inner.get("name"),
        "decision_id": instruction["decision_id"],
        "instruction": instruction,
        "freshness": freshness,
        "activation": {
            "bound": activation_grant is not None,
            "path": str(activation_grant.path) if activation_grant else None,
            "sha256": activation_grant.sha256 if activation_grant else None,
            "reason": activation_reason,
        },
        "outcome": outcome,
        "refusal_reason": refusal_reason,
        "executed": executed,
        "actions_executed": actions_executed,
        "dry_run": mode == MODE_DRY_RUN,
    }


def write_receipt(
    receipt: dict[str, Any],
    *,
    out_dir: Path | None,
    apply_dry_run_receipts: bool = False,
) -> Path | None:
    """Write one receipt atomically and idempotently.

    Destination precedence: an explicit ``out_dir`` (scratch in tests); else the
    live state dir constant only when ``apply_dry_run_receipts`` is set; else no
    file is written. The filename keys on ``decision_id`` so re-running the same
    decision overwrites the same receipt (idempotent), via tmp+rename (atomic).
    """
    if out_dir is not None:
        target_dir = Path(out_dir)
    elif apply_dry_run_receipts:
        target_dir = DEFAULT_RECEIPT_DIR
    else:
        return None
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"account_governor_action_receipt_{receipt['decision_id']}.json"
    tmp = target.with_suffix(".tmp")
    tmp.write_text(json.dumps(receipt, indent=2, sort_keys=True), encoding="utf-8")
    tmp.replace(target)
    return target


def _maybe_load_policy(
    path: Path | None,
    trusted_sha256: str | None,
    *,
    schema: str,
    now_utc: dt.datetime,
    expected_login: int,
    label: str,
) -> "governor.BoundPolicy | None":
    if path is None:
        return None
    return governor._load_bound_policy(
        path.resolve(),
        str(trusted_sha256 or ""),
        schema=schema,
        now_utc=now_utc,
        expected_login=expected_login,
        label=label,
    )


def _resolve_decision(
    args: argparse.Namespace, *, now_utc: dt.datetime
) -> tuple[dict[str, Any], "governor.BoundPolicy | None", int]:
    """Load a pre-computed decision, or compute one from a live snapshot."""
    if args.decision is not None:
        decision = governor._read_json(Path(args.decision).resolve(), "decision")
        analysis = decision.get("analysis") or {}
        login = args.expected_login or governor._positive_int(
            analysis.get("account_login"), "decision.analysis.account_login"
        )
        policy = _maybe_load_policy(
            args.policy,
            args.trusted_policy_sha256,
            schema=governor.POLICY_SCHEMA,
            now_utc=now_utc,
            expected_login=login,
            label="policy",
        )
        return decision, policy, login
    if args.snapshot is not None:
        snapshot = governor._read_json(Path(args.snapshot).resolve(), "snapshot")
        login = args.expected_login or governor._positive_int(
            snapshot.get("account_login"), "account_login"
        )
        policy = _maybe_load_policy(
            args.policy,
            args.trusted_policy_sha256,
            schema=governor.POLICY_SCHEMA,
            now_utc=now_utc,
            expected_login=login,
            label="policy",
        )
        emergency = _maybe_load_policy(
            args.emergency_policy,
            args.trusted_emergency_sha256,
            schema=governor.EMERGENCY_SCHEMA,
            now_utc=now_utc,
            expected_login=login,
            label="emergency_policy",
        )
        decision = governor.evaluate(
            snapshot,
            now_utc=now_utc,
            expected_login=login,
            max_age_seconds=args.max_age_seconds,
            policy=policy,
            emergency_policy=emergency,
        )
        return decision, policy, login
    raise governor.GovernorError("no_decision_or_snapshot_input")


def _env_activation_path() -> Path | None:
    raw = os.environ.get(ACTIVATION_ENV)
    return Path(raw).resolve() if raw else None


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    src = parser.add_mutually_exclusive_group()
    src.add_argument("--decision", type=Path, help="Pre-computed governor decision JSON.")
    src.add_argument(
        "--snapshot",
        type=Path,
        default=governor.DEFAULT_SNAPSHOT,
        help="Account snapshot JSON to evaluate inline.",
    )
    parser.add_argument("--expected-login", type=int)
    parser.add_argument("--max-age-seconds", type=float, default=90.0)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--trusted-policy-sha256")
    parser.add_argument("--emergency-policy", type=Path)
    parser.add_argument("--trusted-emergency-sha256")
    parser.add_argument("--activation", type=Path, help="OWNER enforce-activation artifact.")
    parser.add_argument("--trusted-activation-sha256")
    parser.add_argument(
        "--max-decision-age-seconds", type=float, default=DEFAULT_MAX_DECISION_AGE_SECONDS
    )
    parser.add_argument(
        "--entry-freeze-signal", type=Path, default=DEFAULT_ENTRY_FREEZE_SIGNAL
    )
    parser.add_argument("--out", type=Path, help="Directory to write the receipt into.")
    parser.add_argument(
        "--apply-dry-run-receipts",
        action="store_true",
        help="Permit writing the receipt to the live state dir (default off).",
    )
    parser.add_argument(
        "--enforce",
        action="store_true",
        help="Request enforce mode; refused unless OWNER activation is bound (ships disabled).",
    )
    parser.add_argument("--now-utc")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Explicit dry-run acknowledgement (default mode; no apply exists here).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    now_utc = governor._parse_ts(args.now_utc, "now_utc") if args.now_utc else governor._now_utc()
    mode = MODE_ENFORCE if args.enforce else MODE_DRY_RUN
    try:
        decision, policy, login = _resolve_decision(args, now_utc=now_utc)
    except Exception as exc:  # noqa: BLE001 - structured error, never a traceback
        print(
            json.dumps(
                {
                    "schema": ADAPTER_SCHEMA,
                    "status": "ERROR",
                    "error_type": type(exc).__name__,
                    "reason": str(exc),
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2

    activation_grant: ActivationGrant | None = None
    activation_reason: str | None = None
    if mode == MODE_ENFORCE:
        activation_path = (
            Path(args.activation).resolve() if args.activation else _env_activation_path()
        )
        trusted = args.trusted_activation_sha256 or os.environ.get(ACTIVATION_SHA_ENV)
        activation_grant, activation_reason = resolve_activation(
            activation_path=activation_path,
            trusted_sha256=trusted,
            now_utc=now_utc,
            expected_login=login,
            policy=policy,
        )

    # PRODUCTION SAFETY: the CLI never wires a live order executor. Enforce mode
    # therefore always refuses at latest at "no_execution_adapter_present" even
    # if an activation artifact were present. A live executor is a separate ROT
    # component (contract:125) injected only through run_adapter().
    executor: AccountActionExecutor | None = None

    receipt = run_adapter(
        decision,
        mode=mode,
        now_utc=now_utc,
        activation_grant=activation_grant,
        activation_reason=activation_reason,
        executor=executor,
        max_decision_age_seconds=args.max_decision_age_seconds,
        entry_freeze_signal_path=Path(args.entry_freeze_signal),
    )
    written = write_receipt(
        receipt, out_dir=args.out, apply_dry_run_receipts=args.apply_dry_run_receipts
    )
    receipt = dict(receipt, receipt_path=str(written) if written else None)
    print(json.dumps(receipt, indent=2, sort_keys=True))
    if mode == MODE_ENFORCE and receipt["outcome"] == "ENFORCE_REFUSED":
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
