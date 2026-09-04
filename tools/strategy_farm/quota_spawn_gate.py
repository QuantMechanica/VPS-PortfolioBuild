#!/usr/bin/env python3
"""Config-driven pre-spawn quota gate for Codex and Claude agent work.

This gate controls only LLM spawn volume. It never changes model depth and it
never applies to MT5 backtests or other deterministic work. Both the router and
the 15-minute orchestration wrapper call this module before assigning/spawning
Codex or Claude work.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import uuid
from pathlib import Path
from typing import Any

# Model routing doctrine 2026-09-04 (section 5): the Codex model TIER contract
# lives in its own module so the resolution/ledger arithmetic stays pure and
# unit-testable. Dual import keeps both package and bare-script execution
# working, exactly like the other strategy_farm modules.
try:  # pragma: no cover - import shape depends on the caller
    from tools.strategy_farm import codex_model_tiers
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import codex_model_tiers  # type: ignore


CONFIG_PATH = Path(__file__).with_name("config") / "agent_quota_gate.v1.json"
GOVERNOR_STATE_PATH = Path(r"D:\QM\reports\state\quota_governor_state.json")
HEADROOM_SUMMARY_PATH = Path(r"D:\QM\reports\state\quota_headroom_summary.json")
GATED_AGENTS = {"codex", "claude"}


def _intrinsic_deterministic(task_type: str) -> bool:
    """Hard invariant independent of the optional policy file."""
    normalized = str(task_type or "").strip().lower()
    return normalized in {"backtest", "deterministic", "pipeline_deterministic"} or normalized.startswith(
        ("backtest_", "deterministic_")
    )


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _parse_time(value: Any) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def _read_json(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, "missing"
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as exc:
        return None, f"unreadable:{type(exc).__name__}"
    if not isinstance(value, dict):
        return None, "not_object"
    return value, None


def load_policy(path: Path | None = None) -> tuple[dict[str, Any] | None, str | None]:
    policy, error = _read_json(path or CONFIG_PATH)
    if error:
        return None, error
    assert policy is not None
    required = {
        "state_max_age_minutes",
        "owner_priority_min",
        "hard_exhaustion",
        "model_matrix",
        "task_classes",
        "default_task_class",
    }
    missing = sorted(required - set(policy))
    if missing:
        return None, f"missing_keys:{','.join(missing)}"
    hard = policy.get("hard_exhaustion") or {}
    missing_hard = sorted({"weekly_used_pct", "five_hour_used_pct"} - set(hard))
    if missing_hard:
        return None, f"missing_hard_exhaustion_keys:{','.join(missing_hard)}"
    class_required = {
        "task_types",
        "max_weekly_used_pct",
        "max_pace_ahead_points",
        "max_five_hour_used_pct",
        "allow_on_pace_surplus",
        "missing_or_stale_state",
    }
    classes = policy.get("task_classes") or {}
    if str(policy.get("default_task_class")) not in classes:
        return None, "default_task_class_missing"
    for class_name, class_policy in classes.items():
        missing_class = sorted(class_required - set(class_policy or {}))
        if missing_class:
            return None, f"class_{class_name}_missing_keys:{','.join(missing_class)}"
    matrix = policy.get("model_matrix") or {}
    codex_matrix = matrix.get("codex") or {}
    claude_matrix = matrix.get("claude") or {}
    if not {
        "model",
        "default_reasoning_effort",
        "allowed_reasoning_efforts",
        "explicit_payload_field",
        "max",
        "high",
        "medium",
    }.issubset(codex_matrix):
        return None, "codex_model_matrix_incomplete"
    # Doctrine 2026-09-04 section 5: while tiers are active the tier block is
    # part of the same fail-closed matrix. Under the QM_CODEX_MODEL_TIERS=0
    # rollback the pre-doctrine matrix above is the whole contract again.
    if codex_model_tiers.tiers_enabled():
        if not {"plan_tier", "tiers", "explicit_tier_payload_field"}.issubset(codex_matrix):
            return None, "codex_model_matrix_incomplete"
        tier_error = codex_model_tiers.validate_matrix(codex_matrix)
        if tier_error:
            return None, tier_error
    if not {"default_model", "allowed_models", "explicit_payload_field", "sonnet", "opus"}.issubset(
        claude_matrix
    ):
        return None, "claude_model_matrix_incomplete"
    return policy, None


def load_governor_state(
    path: Path | None = None,
    *,
    max_age_minutes: float,
    now: dt.datetime | None = None,
) -> tuple[dict[str, Any] | None, str]:
    state, error = _read_json(path or GOVERNOR_STATE_PATH)
    if error:
        return state, error
    assert state is not None
    state_at = _parse_time(state.get("ts"))
    if state_at is None:
        return state, "timestamp_missing_or_invalid"
    age_minutes = ((_utc_now() if now is None else now) - state_at).total_seconds() / 60.0
    if age_minutes < -5:
        return state, "timestamp_in_future"
    if age_minutes > max_age_minutes:
        return state, f"stale:{age_minutes:.1f}m"
    return state, "fresh"


def _is_deterministic(task_type: str, policy: dict[str, Any]) -> bool:
    normalized = str(task_type or "").strip().lower()
    exact = {str(item).lower() for item in policy.get("never_gate_task_types", [])}
    prefixes = tuple(str(item).lower() for item in policy.get("never_gate_task_type_prefixes", []))
    return _intrinsic_deterministic(task_type) or normalized in exact or bool(
        prefixes and normalized.startswith(prefixes)
    )


def _classify(task_type: str, policy: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    normalized = str(task_type or "").strip().lower()
    classes = policy.get("task_classes") or {}
    for class_name, class_policy in classes.items():
        task_types = {str(item).lower() for item in (class_policy or {}).get("task_types", [])}
        if normalized in task_types:
            return str(class_name), dict(class_policy or {})
    default_name = str(policy.get("default_task_class"))
    return default_name, dict(classes.get(default_name) or {})


def _metrics(state: dict[str, Any] | None, agent: str) -> dict[str, float | None] | None:
    if not state:
        return None
    node = (state.get("agents") or {}).get(agent) or {}
    try:
        weekly = float(node["used_pct"])
        elapsed = float(node["elapsed_pct"])
    except (KeyError, TypeError, ValueError):
        return None
    five_hour_raw = node.get("five_hour_used_pct", node.get("hour_pct"))
    try:
        five_hour = None if five_hour_raw is None else float(five_hour_raw)
    except (TypeError, ValueError):
        five_hour = None
    return {
        "weekly_used_pct": weekly,
        "weekly_elapsed_pct": elapsed,
        "pace_diff_points": weekly - elapsed,
        "five_hour_used_pct": five_hour,
    }


def _safe_policy_failure(task_type: str) -> bool:
    """Keep incident/review continuity if the repo policy itself is unreadable."""
    normalized = str(task_type or "").lower()
    return normalized == "ops_issue" or normalized.startswith("review_") or normalized in {
        "card_review",
        "triage_failure",
        "q02_infra_repair",
        "q08_infra_repair",
    }


def _payload_rule_matches(rule: dict[str, Any], payload: dict[str, Any], payload_text: str) -> bool:
    for field in rule.get("payload_boolean_fields", []):
        if payload.get(str(field)) is True:
            return True
    return any(str(marker).lower() in payload_text for marker in rule.get("payload_markers", []))


def _codex_tier_view(
    codex_matrix: dict[str, Any],
    payload: dict[str, Any],
    task_type: str,
    effort: str,
    *,
    effort_explicit: bool,
    now: dt.datetime | None = None,
    ledger_path: Path | None = None,
) -> dict[str, Any]:
    """Tier fields for one Codex invocation ({} under the tier rollback).

    Model routing doctrine 2026-09-04 section 5. The effort CLASS is unchanged;
    the tier only decides which model id serves that class and whether the
    rolling 5h window still has messages for it.
    """
    if not codex_model_tiers.tiers_enabled():
        return {}
    return codex_model_tiers.select_dispatch(
        codex_matrix,
        payload,
        task_type,
        effort,
        effort_explicit=effort_explicit,
        now=now,
        path=ledger_path,
    )


def invocation_profile(
    agent: str,
    task_type: str,
    payload: dict[str, Any] | None = None,
    *,
    policy: dict[str, Any] | None = None,
    config_path: Path | None = None,
    now: dt.datetime | None = None,
    ledger_path: Path | None = None,
    with_tiers: bool = True,
) -> dict[str, Any] | None:
    """Resolve the OWNER-approved model/effort tier from the same gate policy.

    ``with_tiers=False`` returns the pre-doctrine effort-class profile only (no
    tier resolution, no ledger READ). It exists for callers that need a cheap,
    time-independent default snapshot - see the module-level fallbacks in
    ``run_agent_orchestration_task`` - because a tier profile is only valid for
    the instant its 5h window was measured (model routing doctrine 2026-09-04
    section 3.1) and must therefore never be frozen at import time.
    """
    normalized_agent = str(agent or "").strip().lower()
    task_payload = payload or {}
    if policy is None:
        policy, _ = load_policy(config_path)
    if policy is None:
        if normalized_agent == "codex":
            return {
                "model": None,
                "reasoning_effort": "max",
                "selection_reason": "policy_unavailable_ops_safe_depth",
            }
        if normalized_agent == "claude":
            return {
                "model": "sonnet",
                "reasoning_effort": None,
                "selection_reason": "policy_unavailable_claude_default",
            }
        return None

    matrix = policy["model_matrix"]
    if normalized_agent == "codex":
        codex = matrix["codex"]
        allowed = {str(item) for item in codex["allowed_reasoning_efforts"]}
        explicit_field = str(codex["explicit_payload_field"])
        explicit = str(task_payload.get(explicit_field) or "").strip().lower()
        normalized_type = str(task_type or "").strip().lower()
        # Router-owned audit records describe the previous decision and must not
        # themselves turn every recycled task into a max-class task merely
        # because the key is named ``quota_gate``.
        classification_payload = {
            key: value
            for key, value in task_payload.items()
            if key not in {"quota_gate", "quota_tier_escalation"}
        }
        payload_text = json.dumps(classification_payload, sort_keys=True, default=str).lower()
        if explicit in allowed:
            effort = explicit
            reason = f"explicit_payload:{explicit_field}"
        else:
            max_rule = codex["max"]
            max_types = {str(item).lower() for item in max_rule.get("task_types", [])}
            if normalized_type in max_types or _payload_rule_matches(max_rule, task_payload, payload_text):
                effort = "max"
                reason = "max_class_contract_failclosed_decision_rootcause_or_adjudication"
            elif _payload_rule_matches(codex["medium"], task_payload, payload_text):
                effort = "medium"
                reason = "medium_class_mechanical_report_or_doc_mirror"
            else:
                effort = str(codex["default_reasoning_effort"])
                reason = "high_class_ordinary_code_build_or_evidence_tooling"
        profile = {
            "model": str(codex["model"]),
            "reasoning_effort": effort,
            "selection_reason": reason,
        }
        # Doctrine 2026-09-04 section 5: tier resolution rides on top of the
        # effort class and may replace `model` (and, for an explicitly
        # requested tier, the effort) without touching the class logic above.
        tier_view = (
            _codex_tier_view(
                codex,
                task_payload,
                task_type,
                effort,
                effort_explicit=explicit in allowed,
                now=now,
                ledger_path=ledger_path,
            )
            if with_tiers
            else {}
        )
        if tier_view:
            profile.update(tier_view)
            profile["selection_reason"] = f"{reason};{tier_view.get('model_tier_reason')}"
        return profile

    if normalized_agent == "claude":
        claude = matrix["claude"]
        explicit_field = str(claude["explicit_payload_field"])
        explicit = str(task_payload.get(explicit_field) or "").strip().lower()
        allowed_models = {str(item).lower() for item in claude["allowed_models"]}
        if explicit in allowed_models:
            model = explicit
            reason = f"explicit_payload:{explicit_field}"
        else:
            model = str(claude["default_model"])
            reason = "sonnet_default_deliberate_opus_only"
        return {"model": model, "reasoning_effort": None, "selection_reason": reason}
    return None


def _nonnegative_int(value: Any) -> int:
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        return 0


def _prior_invocation(payload: dict[str, Any]) -> dict[str, Any]:
    gate = payload.get("quota_gate")
    if not isinstance(gate, dict):
        return {}
    invocation = gate.get("invocation")
    return dict(invocation) if isinstance(invocation, dict) else {}


def _prior_escalation(payload: dict[str, Any]) -> dict[str, Any]:
    direct = payload.get("quota_tier_escalation")
    if isinstance(direct, dict):
        return dict(direct)
    gate = payload.get("quota_gate")
    if isinstance(gate, dict) and isinstance(gate.get("tier_escalation"), dict):
        return dict(gate["tier_escalation"])
    return {}


def _apply_recycle_escalation(
    agent: str,
    payload: dict[str, Any],
    invocation: dict[str, Any] | None,
    policy: dict[str, Any],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """Raise a rejected run exactly one configured tier, once per recycle.

    ``recycle_count`` is advanced by the router's bounded RECYCLE -> TODO
    transition. ``quota_tier_escalation.recycle_count`` records the last count
    already consumed, preventing a stale-lease reroute from escalating twice.
    """
    if invocation is None:
        return None, None
    recycle_count = _nonnegative_int(payload.get("recycle_count"))
    if recycle_count <= 0:
        return invocation, None

    normalized_agent = str(agent or "").strip().lower()
    matrix = policy["model_matrix"]
    if normalized_agent == "codex":
        tiers = [str(item).lower() for item in matrix["codex"]["allowed_reasoning_efforts"]]
        field = "reasoning_effort"
    elif normalized_agent == "claude":
        tiers = [str(item).lower() for item in matrix["claude"]["allowed_models"]]
        field = "model"
    else:
        return invocation, None
    if not tiers:
        return invocation, None

    base_tier = str(invocation.get(field) or "").strip().lower()
    prior = _prior_invocation(payload)
    prior_tier = str(prior.get(field) or base_tier).strip().lower()
    if base_tier not in tiers:
        base_tier = tiers[0]
    if prior_tier not in tiers:
        prior_tier = base_tier

    previous_escalation = _prior_escalation(payload)
    handled_count = _nonnegative_int(previous_escalation.get("recycle_count"))
    is_new_recycle = recycle_count > handled_count
    base_index = tiers.index(base_tier)
    prior_index = tiers.index(prior_tier)
    if is_new_recycle:
        selected_index = max(base_index, min(prior_index + 1, len(tiers) - 1))
        disposition = "escalated_exactly_one" if prior_index < len(tiers) - 1 else "stayed_capped"
    else:
        # A lease-expiry reroute is still the same attempt. Preserve its selected
        # depth, but do not consume another tier without another review reject.
        selected_index = max(base_index, prior_index)
        disposition = "preserved_already_applied"
    selected_tier = tiers[selected_index]

    adjusted = dict(invocation)
    adjusted[field] = selected_tier
    if is_new_recycle:
        adjusted["selection_reason"] = (
            f"recycle_{disposition}:{prior_tier}_to_{selected_tier};"
            f"base={base_tier};{invocation.get('selection_reason') or 'class_policy'}"
        )
    escalation = {
        "schema": "qm.quota_tier_escalation.v1",
        "agent": normalized_agent,
        "recycle_count": recycle_count,
        "previous_handled_recycle_count": handled_count,
        "new_recycle": is_new_recycle,
        "base_tier": base_tier,
        "prior_run_tier": prior_tier,
        "selected_tier": selected_tier,
        "disposition": disposition,
        "capped": selected_index == len(tiers) - 1,
    }
    return adjusted, escalation


def _reapply_codex_tier(
    agent: str,
    task_type: str,
    payload: dict[str, Any],
    invocation: dict[str, Any] | None,
    policy: dict[str, Any],
    *,
    now: dt.datetime | None = None,
) -> dict[str, Any] | None:
    """Re-map the model tier after the effort class was escalated."""
    if invocation is None or str(agent or "").lower() != "codex":
        return invocation
    if not codex_model_tiers.tiers_enabled() or not invocation.get("model_tier"):
        return invocation
    view = _codex_tier_view(
        policy["model_matrix"]["codex"],
        payload,
        task_type,
        str(invocation.get("reasoning_effort") or ""),
        effort_explicit=True,
        now=now,
    )
    if not view:
        return invocation
    merged = dict(invocation)
    merged.update(view)
    return merged


def _codex_tier_block(agent: str, invocation: dict[str, Any] | None) -> dict[str, Any] | None:
    """Structured spawn refusal from the tier contract, or ``None``.

    Doctrine 2026-09-04 section 5: an unknown tier fails closed, an exhausted
    5h window refuses with `codex_tier_window_exhausted` (tier/model/count/
    budget travel in the invocation so the router and the headroom summary can
    show WHY without re-deriving it).
    """
    if str(agent or "").lower() != "codex" or not invocation:
        return None
    error = invocation.get("model_tier_error")
    if isinstance(error, dict):
        return {"reason": str(error.get("code") or codex_model_tiers.UNKNOWN_TIER_REASON), "detail": error}
    refusal = invocation.get("model_tier_refusal")
    if isinstance(refusal, dict):
        return {
            "reason": str(refusal.get("code") or codex_model_tiers.WINDOW_EXHAUSTED_REASON),
            "detail": refusal,
        }
    return None


def _decision(
    *,
    allowed: bool,
    agent: str,
    task_type: str,
    priority: int,
    reason: str,
    task_class: str | None,
    state_status: str,
    metrics: dict[str, float | None] | None = None,
    violations: list[str] | None = None,
    hard_exhaustion: bool = False,
    policy_schema: str | None = None,
    invocation: dict[str, Any] | None = None,
    tier_escalation: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "allowed": allowed,
        "agent": agent,
        "task_type": task_type,
        "task_class": task_class,
        "priority": int(priority),
        "reason": reason,
        "state_status": state_status,
        "hard_exhaustion": hard_exhaustion,
        "metrics": metrics,
        "violations": violations or [],
        "policy_schema": policy_schema,
        "invocation": invocation,
        "tier_escalation": tier_escalation,
        "decided_at": _utc_now().replace(microsecond=0).isoformat(),
    }


def evaluate_spawn(
    agent: str,
    task_type: str,
    priority: int,
    *,
    config_path: Path | None = None,
    state_path: Path | None = None,
    summary_path: Path | None = None,
    payload: dict[str, Any] | None = None,
    now: dt.datetime | None = None,
    write_summary: bool = True,
) -> dict[str, Any]:
    """Return a serializable allow/deny decision for one prospective spawn."""
    normalized_agent = str(agent or "").strip().lower()
    if _intrinsic_deterministic(task_type):
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="deterministic_no_llm_never_gated",
            task_class="deterministic",
            state_status="not_required",
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result
    policy, policy_error = load_policy(config_path)
    if policy is None:
        allowed = normalized_agent not in GATED_AGENTS or _safe_policy_failure(task_type)
        invocation = invocation_profile(
            normalized_agent,
            task_type,
            payload,
            policy=policy,
            config_path=config_path,
        )
        result = _decision(
            allowed=allowed,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="policy_unavailable_fail_open_continuity" if allowed else "policy_unavailable_fail_closed",
            task_class=None,
            state_status=f"policy_{policy_error}",
            invocation=invocation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    schema = str(policy.get("schema") or "")
    if normalized_agent not in GATED_AGENTS:
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="agent_not_quota_gated",
            task_class=None,
            state_status="not_required",
            policy_schema=schema,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    if _is_deterministic(task_type, policy):
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="deterministic_no_llm_never_gated",
            task_class="deterministic",
            state_status="not_required",
            policy_schema=schema,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    task_class, class_policy = _classify(task_type, policy)
    task_payload = payload or {}
    invocation = invocation_profile(
        normalized_agent,
        task_type,
        task_payload,
        policy=policy,
        now=now,
    )
    invocation, tier_escalation = _apply_recycle_escalation(
        normalized_agent,
        task_payload,
        invocation,
        policy,
    )
    # A recycle escalation raises the effort CLASS; the model tier follows it
    # (doctrine 2026-09-04 section 2 maps max/high/medium to sol/terra/luna).
    invocation = _reapply_codex_tier(
        normalized_agent,
        task_type,
        task_payload,
        invocation,
        policy,
        now=now,
    )
    # OWNER burn window (quota_governor._burn_authorized, fail-closed flag
    # contract): while a valid CODEX/CLAUDE_BURN_AUTHORIZED.flag is present,
    # weekly/5h exhaustion and class caps are suspended for that agent —
    # OWNER 2026-08-22: "Codex derzeit ohne Ruecksicht auf Token oder 5h oder
    # Wochenlimit einfach nutzen". Lazy import avoids a module cycle
    # (quota_governor imports this module at top level).
    try:
        from tools.strategy_farm.quota_governor import _burn_authorized
    except ModuleNotFoundError:  # pragma: no cover - direct script execution
        from quota_governor import _burn_authorized  # type: ignore
    burn, burn_why = _burn_authorized(
        normalized_agent, now or dt.datetime.now(dt.timezone.utc))
    if burn:
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason=f"owner_burn_authorization_active:{burn_why}",
            task_class=task_class,
            state_status="burn_bypass",
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    # Model-tier window refusal (doctrine 2026-09-04 section 3.1). Placed AFTER
    # the OWNER burn bypass on purpose: the 5h message budget is our own
    # conservative planning figure, and an explicit OWNER burn authorization
    # still outranks it, exactly like the weekly/5h quota caps above.
    tier_block = _codex_tier_block(normalized_agent, invocation)
    if tier_block is not None:
        result = _decision(
            allowed=False,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason=str(tier_block["reason"]),
            task_class=task_class,
            state_status="model_tier_window",
            violations=[str(tier_block["reason"])],
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    max_age = float(policy["state_max_age_minutes"])
    state, state_status = load_governor_state(state_path, max_age_minutes=max_age, now=now)
    metrics = _metrics(state, normalized_agent)
    if state_status == "fresh" and metrics is None:
        state_status = "metrics_unavailable"
    state_usable = state_status == "fresh" and metrics is not None
    owner_priority = int(priority) >= int(policy["owner_priority_min"])

    if not state_usable:
        fallback = str(class_policy.get("missing_or_stale_state") or "deny").lower()
        allowed = owner_priority or fallback == "allow"
        if owner_priority:
            reason = "owner_priority_bypass_metrics_unavailable"
        else:
            reason = f"governor_state_{state_status}_{fallback}"
        result = _decision(
            allowed=allowed,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason=reason,
            task_class=task_class,
            state_status=state_status,
            metrics=metrics,
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    assert metrics is not None
    hard = policy.get("hard_exhaustion") or {}
    weekly_hard = metrics["weekly_used_pct"] >= float(hard["weekly_used_pct"])
    five_hour = metrics["five_hour_used_pct"]
    five_hour_hard = five_hour is not None and five_hour >= float(hard["five_hour_used_pct"])
    if weekly_hard or five_hour_hard:
        violations = []
        if weekly_hard:
            violations.append("weekly_hard_exhaustion")
        if five_hour_hard:
            violations.append("five_hour_hard_exhaustion")
        result = _decision(
            allowed=False,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="hard_exhaustion",
            task_class=task_class,
            state_status=state_status,
            metrics=metrics,
            violations=violations,
            hard_exhaustion=True,
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    if owner_priority:
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="owner_priority_bypass",
            task_class=task_class,
            state_status=state_status,
            metrics=metrics,
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    if bool(class_policy.get("allow_on_pace_surplus")) and metrics["pace_diff_points"] <= 0:
        result = _decision(
            allowed=True,
            agent=normalized_agent,
            task_type=task_type,
            priority=priority,
            reason="pace_surplus_continuity",
            task_class=task_class,
            state_status=state_status,
            metrics=metrics,
            policy_schema=schema,
            invocation=invocation,
            tier_escalation=tier_escalation,
        )
        if write_summary:
            record_gate_decision(result, state_path=state_path, summary_path=summary_path)
        return result

    violations: list[str] = []
    if metrics["weekly_used_pct"] > float(class_policy["max_weekly_used_pct"]):
        violations.append("weekly_class_threshold")
    if metrics["pace_diff_points"] > float(class_policy["max_pace_ahead_points"]):
        violations.append("weekly_pace_threshold")
    class_five_hour_max = float(class_policy["max_five_hour_used_pct"])
    if five_hour is not None and five_hour > class_five_hour_max:
        violations.append("five_hour_class_threshold")
    result = _decision(
        allowed=not violations,
        agent=normalized_agent,
        task_type=task_type,
        priority=priority,
        reason="within_class_thresholds" if not violations else "class_threshold_exceeded",
        task_class=task_class,
        state_status=state_status,
        metrics=metrics,
        violations=violations,
        policy_schema=schema,
        invocation=invocation,
        tier_escalation=tier_escalation,
    )
    if write_summary:
        record_gate_decision(result, state_path=state_path, summary_path=summary_path)
    return result


def _agent_headroom(state: dict[str, Any] | None, agent: str) -> dict[str, float | None]:
    metrics = _metrics(state, agent)
    if metrics is None:
        return {
            "weekly_used_pct": None,
            "weekly_remaining_pct": None,
            "weekly_elapsed_pct": None,
            "five_hour_used_pct": None,
        }
    weekly = float(metrics["weekly_used_pct"] or 0.0)
    return {
        "weekly_used_pct": weekly,
        "weekly_remaining_pct": max(0.0, 100.0 - weekly),
        "weekly_elapsed_pct": metrics["weekly_elapsed_pct"],
        "five_hour_used_pct": metrics["five_hour_used_pct"],
    }


def write_headroom_summary(
    governor_state: dict[str, Any] | None,
    decision: dict[str, Any] | None,
    *,
    path: Path | None = None,
    preserve_last_gate: bool = True,
) -> dict[str, Any]:
    """Atomically write the one-line cockpit/briefing quota contract."""
    target = path or HEADROOM_SUMMARY_PATH
    previous: dict[str, Any] = {}
    if preserve_last_gate and decision is None:
        loaded, _ = _read_json(target)
        previous = loaded or {}
    last_gate = decision if decision is not None else previous.get("last_gate")
    summary = {
        "schema": "qm.quota_headroom.v1",
        "updated_at": _utc_now().replace(microsecond=0).isoformat(),
        "codex": _agent_headroom(governor_state, "codex"),
        "claude": _agent_headroom(governor_state, "claude"),
        "last_gate": last_gate,
    }
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(f"{target.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    tmp.write_text(json.dumps(summary, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    os.replace(tmp, target)
    return summary


def record_gate_decision(
    decision: dict[str, Any],
    *,
    state_path: Path | None = None,
    summary_path: Path | None = None,
) -> dict[str, Any]:
    state, _ = _read_json(state_path or GOVERNOR_STATE_PATH)
    compact = {
        key: decision.get(key)
        for key in (
            "allowed",
            "agent",
            "task_type",
            "task_class",
            "priority",
            "reason",
            "hard_exhaustion",
            "invocation",
            "tier_escalation",
            "decided_at",
        )
    }
    try:
        return write_headroom_summary(state, compact, path=summary_path, preserve_last_gate=False)
    except OSError as exc:
        return {
            "schema": "qm.quota_headroom.v1",
            "write_error": f"{type(exc).__name__}:{exc}",
            "last_gate": compact,
        }


def record_codex_dispatch(
    *,
    task_id: str,
    contract: dict[str, Any] | None,
    config_path: Path | None = None,
    ledger_path: Path | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Append one real Codex dispatch to the rolling 5h model ledger.

    Doctrine 2026-09-04 section 3.1. Called at the actual CLI spawn (never for
    a dry run and never for a merely suggested command), so the window count
    reflects messages that were really spent. No-op under
    ``QM_CODEX_MODEL_TIERS=0`` and never raises into the dispatch path.
    """
    invocation = contract or {}
    if not codex_model_tiers.tiers_enabled():
        return {"recorded": False, "reason": "codex_model_tiers_disabled"}
    policy, _error = load_policy(config_path)
    if policy is None:
        # An unresolvable policy means an UNCOUNTED message. Surfaced instead of
        # silently skipped so the ledger gap is visible in the spawn payload.
        return {"recorded": False, "reason": f"policy_unavailable:{_error}"}
    codex_matrix = ((policy or {}).get("model_matrix") or {}).get("codex") or {}
    # Fix round 2026-09-04: the booking is the fail-closed choke point, so it
    # gets the WHOLE fallback chain. Between the preview and this call another
    # slot may have filled the preferred model; the commit then lands one tier
    # lower instead of dispatching over budget. For the scalpel tier the chain
    # is a single entry, so an exhausted Astra window still refuses (hold).
    chain = invocation.get("model_tier_chain_detail")
    if not isinstance(chain, list):
        chain = None
    return codex_model_tiers.record_dispatch(
        task_id=str(task_id or ""),
        tier=str(invocation.get("model_tier") or ""),
        model=str(invocation.get("model") or ""),
        path=ledger_path,
        now=now,
        codex_matrix=codex_matrix,
        chain=chain,
    )


def release_codex_dispatch(
    ledger_result: dict[str, Any] | None,
    *,
    ledger_path: Path | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Give a booked message back when the spawn it was booked for failed.

    Doctrine 2026-09-04 section 3.1. Booking happens BEFORE the launch (that is
    what makes the budget fail-closed), so a launch that never happened must be
    refunded or the window would drift shut on phantom messages.
    """
    result = ledger_result or {}
    if not result.get("recorded"):
        return {"released": False, "reason": "nothing_recorded"}
    record = result.get("record") or {}
    target = Path(ledger_path) if ledger_path is not None else Path(str(result.get("path") or ""))
    try:
        return codex_model_tiers.release_dispatch(
            record_id=str(result.get("record_id") or record.get("id") or ""),
            path=target,
            task_id=str(record.get("task_id") or ""),
            model=str(record.get("model") or ""),
            now=now,
        )
    except Exception as exc:  # pragma: no cover - dispatch must never break
        return {"released": False, "reason": f"release_error:{type(exc).__name__}"}


def codex_invocation_flags(
    task_type: str,
    payload: dict[str, Any] | None = None,
    *,
    config_path: Path | None = None,
    now: dt.datetime | None = None,
    ledger_path: Path | None = None,
) -> tuple[list[str], dict[str, Any]]:
    """``(argv flags, invocation)`` for one real ``codex exec`` command line.

    Model routing doctrine 2026-09-04 section 5: EVERY Codex spawn site uses
    this one contract instead of the account default, so the model id that is
    dispatched is the model id the 5h ledger then counts. The flag order and
    quoting are identical to ``run_agent_orchestration_task.command_for``.

    PREVIEW ONLY - it books nothing. A real spawn site must use
    :func:`codex_spawn_contract` instead; this wrapper stays for rendered
    command strings and tests, and marks a refusing invocation with
    ``model_tier_spawn_refused`` so a caller that ignores the contract emits no
    model flag at all rather than the wrong one.

    Never raises into a dispatch path: on any failure the caller gets empty
    flags, i.e. today's flag-free command and the account default.

    CEO decision D2 (round 3, 2026-09-04): under ``QM_CODEX_MODEL_TIERS=0`` the
    rollback must restore the EXACT pre-patch command line at every spawn and
    render site, so no flags are emitted at all.
    """
    if not codex_model_tiers.tiers_enabled():
        return [], {}
    try:
        invocation = (
            invocation_profile(
                "codex",
                task_type,
                payload or {},
                config_path=config_path,
                now=now,
                ledger_path=ledger_path,
            )
            or {}
        )
    except Exception:  # pragma: no cover - dispatch must never break on this
        return [], {}
    block = _codex_tier_block("codex", invocation)
    if block is not None:
        refused = dict(invocation)
        refused["model_tier_spawn_refused"] = True
        refused["model_tier_spawn_refusal_reason"] = str(block["reason"])
        return [], refused
    return _flags_for(invocation), invocation


def _flags_for(invocation: dict[str, Any]) -> list[str]:
    """`-m <model>` + `-c model_reasoning_effort="<effort>"` for a command line."""
    model = str(invocation.get("model") or "").strip()
    effort = str(invocation.get("reasoning_effort") or "").strip()
    flags: list[str] = []
    if model:
        flags += ["-m", model]
    if effort:
        flags += ["-c", f'model_reasoning_effort="{effort}"']
    return flags


def codex_spawn_contract(
    task_type: str,
    payload: dict[str, Any] | None = None,
    *,
    task_id: str = "",
    config_path: Path | None = None,
    now: dt.datetime | None = None,
    ledger_path: Path | None = None,
    commit: bool = True,
) -> dict[str, Any]:
    """The ONE contract a real ``codex exec`` spawn site must use.

    Fix round 2026-09-04: ``codex_invocation_flags`` returned the tier fields
    but no caller looked at ``model_tier_refusal`` / ``model_tier_hold`` /
    ``model_tier_error``, so an exhausted window still dispatched - and then
    wrote the ledger line that pushed the count further past budget. This
    function makes the refusal the RESULT, not a side-band field, and books the
    message atomically BEFORE the launch:

    ``{"allowed": bool, "flags": [...], "invocation": {...},
    "refusal": {...} | None, "ledger": {...}}``

    On ``allowed is False`` the caller must not spawn. When a spawn that was
    booked then fails, the caller refunds with :func:`release_codex_dispatch`.
    ``commit=False`` yields a pure preview (no ledger write) for rendered
    command strings and dry runs.
    """
    try:
        invocation = (
            invocation_profile(
                "codex",
                task_type,
                payload or {},
                config_path=config_path,
                now=now,
                ledger_path=ledger_path,
            )
            or {}
        )
    except Exception as exc:  # pragma: no cover - dispatch must never break
        # Fail CLOSED on an unusable contract while the tier contract is
        # active; under the rollback the previous flag-free behaviour stands.
        if codex_model_tiers.tiers_enabled():
            return {
                "allowed": False,
                "flags": [],
                "invocation": {},
                "refusal": {"reason": f"model_contract_error:{type(exc).__name__}", "detail": {}},
                "ledger": {"recorded": False, "reason": "contract_unavailable"},
            }
        return {"allowed": True, "flags": [], "invocation": {}, "refusal": None, "ledger": {}}
    block = _codex_tier_block("codex", invocation)
    if block is not None:
        return {
            "allowed": False,
            "flags": [],
            "invocation": invocation,
            "refusal": block,
            "ledger": {"recorded": False, "reason": str(block["reason"])},
        }
    if not codex_model_tiers.tiers_enabled():
        # CEO decision D2 (round 3, 2026-09-04): the rollback restores the EXACT
        # pre-patch argv at every spawn site, which for farmctl/pacer/mailbox
        # and the rendered build command means NO model flags at all (they took
        # the account default, or - for the mailbox intake - its own previously
        # hardcoded pair, which that module restores itself).
        return {
            "allowed": True,
            "flags": [],
            "invocation": invocation,
            "refusal": None,
            "ledger": {"recorded": False, "reason": "codex_model_tiers_disabled"},
        }
    if not commit:
        return {
            "allowed": True,
            "flags": _flags_for(invocation),
            "invocation": invocation,
            "refusal": None,
            "ledger": {"recorded": False, "reason": "preview_only"},
        }
    ledger = record_codex_dispatch(
        task_id=task_id or task_type,
        contract=invocation,
        config_path=config_path,
        ledger_path=ledger_path,
        now=now,
    )
    if not ledger.get("recorded"):
        # CEO decision D4 (round 3, 2026-09-04): ledger I/O fails CLOSED. The
        # previous version treated `codex_ledger_write_error:*` and
        # `policy_unavailable:*` as "not a budget refusal" and dispatched with
        # full flags, so while `D:/QM/reports/state` was unavailable every Codex
        # spawn proceeded unbounded AND uncounted - and the Astra hold
        # evaporated with it. A message that cannot be booked is not spent.
        reason = str(ledger.get("reason") or "") or "codex_dispatch_unbooked"
        return {
            "allowed": False,
            "flags": [],
            "invocation": invocation,
            "refusal": {"reason": reason, "detail": ledger.get("refusal") or ledger},
            "ledger": ledger,
        }
    booked = dict(invocation)
    # The commit may have landed one tier lower than the preview.
    if ledger.get("model"):
        booked["model"] = str(ledger["model"])
        booked["model_tier"] = str(ledger.get("tier") or booked.get("model_tier") or "")
        if ledger.get("downgraded_from"):
            booked["model_tier_downgraded_from"] = str(ledger["downgraded_from"])
    return {
        "allowed": True,
        "flags": _flags_for(booked),
        "invocation": booked,
        "refusal": None,
        "ledger": ledger,
    }


def read_headroom_summary(path: Path | None = None) -> dict[str, Any] | None:
    value, _ = _read_json(path or HEADROOM_SUMMARY_PATH)
    return value
