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


def invocation_profile(
    agent: str,
    task_type: str,
    payload: dict[str, Any] | None = None,
    *,
    policy: dict[str, Any] | None = None,
    config_path: Path | None = None,
) -> dict[str, Any] | None:
    """Resolve the OWNER-approved model/effort tier from the same gate policy."""
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
        return {
            "model": str(codex["model"]),
            "reasoning_effort": effort,
            "selection_reason": reason,
        }

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
    invocation = invocation_profile(normalized_agent, task_type, task_payload, policy=policy)
    invocation, tier_escalation = _apply_recycle_escalation(
        normalized_agent,
        task_payload,
        invocation,
        policy,
    )
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


def read_headroom_summary(path: Path | None = None) -> dict[str, Any] | None:
    value, _ = _read_json(path or HEADROOM_SUMMARY_PATH)
    return value
