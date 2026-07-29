#!/usr/bin/env python3
"""Versioned, research-only target rulepacks for portfolio research.

The rulepacks in :mod:`tools.strategy_farm.config.target_rulepacks` deliberately
do not drive a terminal, deployment, or farm state.  They provide a canonical,
hashable contract that keeps provider-published rules separate from
QuantMechanica's internal risk guardrails and research go-criteria.

This module is stdlib-only.  The adjacent JSON Schema is the portable structural
contract; the checks below add cross-field and target-specific invariants without
introducing a runtime ``jsonschema`` dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import urlparse


DEFAULT_RULEPACK_DIR = Path(__file__).resolve().parent / "config" / "target_rulepacks"
DEFAULT_SCHEMA_PATH = Path(__file__).resolve().parent / "schemas" / "target_rulepack_v1.schema.json"

SCHEMA_VERSION = "target-rulepack/v1"
CANONICALIZATION_ALGORITHM = "QM_CANONICAL_JSON_V1"
HASH_ALGORITHM = "SHA-256"
INTERNAL_CLASSIFICATION = "INTERNAL_QM_POLICY_NOT_PROVIDER_RULE"
RUNTIME_INTEGRATION_STATE = "NOT_IMPLEMENTED"

RULEPACK_ID_RE = re.compile(r"^[A-Z][A-Z0-9_]{2,95}_V(?P<version>[1-9][0-9]*)$")
IDENTIFIER_RE = re.compile(r"^[a-z][a-z0-9_]{2,95}$")

ROOT_KEYS = {
    "schema_version",
    "schema_ref",
    "rulepack_id",
    "profile_version",
    "target",
    "account_or_program",
    "as_of",
    "lifecycle_status",
    "canonicalization",
    "official_sources",
    "official_rules",
    "internal_guardrails",
    "q08_evidence_policy",
    "evaluation_profile",
    "deployment_boundary",
}
SOURCE_KEYS = {"source_id", "title", "url", "authority", "retrieved_on"}
RULE_KEYS = {"rule_id", "category", "description", "scope", "parameters", "source_ids"}
GUARDRAIL_KEYS = {
    "guardrail_id",
    "classification",
    "status",
    "description",
    "scope",
    "parameters",
    "rationale",
    "decision_refs",
}
Q08_POLICY_KEYS = {
    "policy_id",
    "hard_block_dimensions",
    "soft_evidence_debt_dimensions",
    "not_applicable_requires_declared_archetype",
    "soft_admission_status",
    "compensation_requirements",
}
EVALUATION_KEYS = {"objective", "metrics", "go_criteria"}
METRIC_KEYS = {"metric_id", "direction", "description", "parameters"}
CRITERION_KEYS = {
    "criterion_id",
    "classification",
    "description",
    "parameters",
}
DEPLOYMENT_KEYS = {
    "runtime_integration",
    "deploy_authorization",
    "factory_action_authorized",
    "mt5_action_authorized",
    "notes",
}


class RulepackValidationError(ValueError):
    """The rulepack cannot be treated as a canonical target contract."""


@dataclass(frozen=True)
class TargetRulepack:
    """An immutable view of one validated canonical rulepack payload."""

    rulepack_id: str
    profile_version: int
    target: str
    as_of: str
    source_path: Path
    canonical_payload: bytes
    canonical_sha256: str

    def as_dict(self) -> dict[str, Any]:
        """Return a detached mutable copy without invalidating the stored hash."""

        return json.loads(self.canonical_payload.decode("utf-8"))


def _fail(path: str, message: str) -> None:
    raise RulepackValidationError(f"{path}: {message}")


def _reject_float(raw: str) -> None:
    raise RulepackValidationError(
        f"numeric literal {raw!r} is forbidden; encode non-integral values as decimal strings"
    )


def _unique_object(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RulepackValidationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def parse_rulepack_json(text: str) -> dict[str, Any]:
    """Parse JSON while rejecting duplicate keys and non-integral JSON numbers."""

    try:
        payload = json.loads(
            text,
            object_pairs_hook=_unique_object,
            parse_float=_reject_float,
            parse_constant=lambda raw: _fail("$", f"invalid numeric constant {raw}"),
        )
    except json.JSONDecodeError as exc:
        raise RulepackValidationError(f"invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        _fail("$", "root must be an object")
    return payload


def _assert_json_types(value: Any, path: str = "$") -> None:
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        _fail(path, "float values are forbidden; use a decimal string")
    if isinstance(value, Mapping):
        for key, child in value.items():
            if not isinstance(key, str):
                _fail(path, "object keys must be strings")
            _assert_json_types(child, f"{path}.{key}")
        return
    if isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _assert_json_types(child, f"{path}[{index}]")
        return
    _fail(path, f"unsupported JSON value type {type(value).__name__}")


def canonical_json_bytes(payload: Mapping[str, Any]) -> bytes:
    """Return the repository's v1 canonical JSON representation.

    V1 is UTF-8, Unicode-preserving, lexicographically sorted object keys, no
    insignificant whitespace, and no floating-point JSON literals.  Integers are
    allowed; fractional quantities must be decimal strings.
    """

    _assert_json_types(payload)
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def canonical_sha256(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_json_bytes(payload)).hexdigest()


def _require_exact_keys(obj: Mapping[str, Any], expected: set[str], path: str) -> None:
    missing = sorted(expected - set(obj))
    extra = sorted(set(obj) - expected)
    if missing or extra:
        fragments: list[str] = []
        if missing:
            fragments.append(f"missing={missing}")
        if extra:
            fragments.append(f"extra={extra}")
        _fail(path, "; ".join(fragments))


def _require_string(value: Any, path: str, *, nonempty: bool = True) -> str:
    if not isinstance(value, str) or (nonempty and not value.strip()):
        _fail(path, "must be a non-empty string")
    return value


def _require_identifier(value: Any, path: str) -> str:
    token = _require_string(value, path)
    if not IDENTIFIER_RE.fullmatch(token):
        _fail(path, "must be a lowercase snake_case identifier")
    return token


def _require_string_list(value: Any, path: str, *, nonempty: bool = True) -> list[str]:
    if not isinstance(value, list) or (nonempty and not value):
        _fail(path, "must be a non-empty array")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(_require_string(item, f"{path}[{index}]"))
    if len(result) != len(set(result)):
        _fail(path, "must not contain duplicates")
    return result


def _require_iso_date(value: Any, path: str) -> str:
    text = _require_string(value, path)
    try:
        parsed = date.fromisoformat(text)
    except ValueError as exc:
        raise RulepackValidationError(f"{path}: must be YYYY-MM-DD") from exc
    if parsed.isoformat() != text:
        _fail(path, "must use canonical YYYY-MM-DD form")
    return text


def _require_object(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    return value


def _require_array(value: Any, path: str, *, nonempty: bool = True) -> list[Any]:
    if not isinstance(value, list) or (nonempty and not value):
        _fail(path, "must be a non-empty array")
    return value


def _index_unique(records: Iterable[Mapping[str, Any]], key: str, path: str) -> dict[str, Mapping[str, Any]]:
    result: dict[str, Mapping[str, Any]] = {}
    for index, record in enumerate(records):
        token = _require_identifier(record.get(key), f"{path}[{index}].{key}")
        if token in result:
            _fail(path, f"duplicate {key} {token!r}")
        result[token] = record
    return result


def _validate_source(source: Mapping[str, Any], path: str, as_of: str) -> None:
    _require_exact_keys(source, SOURCE_KEYS, path)
    _require_identifier(source["source_id"], f"{path}.source_id")
    _require_string(source["title"], f"{path}.title")
    if source["authority"] != "OFFICIAL_PROVIDER":
        _fail(f"{path}.authority", "must equal OFFICIAL_PROVIDER")
    retrieved = _require_iso_date(source["retrieved_on"], f"{path}.retrieved_on")
    if retrieved > as_of:
        _fail(f"{path}.retrieved_on", "cannot be later than rulepack as_of")
    url = _require_string(source["url"], f"{path}.url")
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        _fail(f"{path}.url", "must be a credential-free HTTPS URL")


def _validate_rule(rule: Mapping[str, Any], path: str, source_ids: set[str]) -> None:
    _require_exact_keys(rule, RULE_KEYS, path)
    _require_identifier(rule["rule_id"], f"{path}.rule_id")
    if rule["category"] not in {
        "OBJECTIVE",
        "RISK_LIMIT",
        "RISK_ENGINE",
        "ELIGIBILITY",
        "TRADING_CONDITION",
        "OPERATIONAL_LIMIT",
    }:
        _fail(f"{path}.category", "unknown official-rule category")
    _require_string(rule["description"], f"{path}.description")
    _require_string_list(rule["scope"], f"{path}.scope")
    _require_object(rule["parameters"], f"{path}.parameters")
    refs = _require_string_list(rule["source_ids"], f"{path}.source_ids")
    missing = sorted(set(refs) - source_ids)
    if missing:
        _fail(f"{path}.source_ids", f"unknown official sources {missing}")


def _validate_guardrail(guardrail: Mapping[str, Any], path: str) -> None:
    _require_exact_keys(guardrail, GUARDRAIL_KEYS, path)
    _require_identifier(guardrail["guardrail_id"], f"{path}.guardrail_id")
    if guardrail["classification"] != INTERNAL_CLASSIFICATION:
        _fail(
            f"{path}.classification",
            f"must equal {INTERNAL_CLASSIFICATION}; provider rules belong in official_rules",
        )
    if guardrail["status"] not in {"OWNER_RATIFIED", "PROPOSED_FOR_CALIBRATION"}:
        _fail(f"{path}.status", "unknown internal-guardrail status")
    _require_string(guardrail["description"], f"{path}.description")
    _require_string_list(guardrail["scope"], f"{path}.scope")
    _require_object(guardrail["parameters"], f"{path}.parameters")
    _require_string(guardrail["rationale"], f"{path}.rationale")
    refs = _require_string_list(
        guardrail["decision_refs"],
        f"{path}.decision_refs",
        nonempty=guardrail["status"] == "OWNER_RATIFIED",
    )
    for index, ref in enumerate(refs):
        if ref.startswith(("http://", "https://")):
            _fail(
                f"{path}.decision_refs[{index}]",
                "internal decision_refs must be repository references, not provider URLs",
            )


def _validate_q08_policy(policy: Mapping[str, Any], path: str) -> None:
    _require_exact_keys(policy, Q08_POLICY_KEYS, path)
    _require_identifier(policy["policy_id"], f"{path}.policy_id")
    hard = set(_require_string_list(policy["hard_block_dimensions"], f"{path}.hard_block_dimensions"))
    soft = set(
        _require_string_list(
            policy["soft_evidence_debt_dimensions"],
            f"{path}.soft_evidence_debt_dimensions",
        )
    )
    overlap = sorted(hard & soft)
    if overlap:
        _fail(path, f"dimensions cannot be both hard and soft: {overlap}")
    if policy["not_applicable_requires_declared_archetype"] is not True:
        _fail(
            f"{path}.not_applicable_requires_declared_archetype",
            "must be true; NOT_APPLICABLE cannot be an unqualified pass",
        )
    if policy["soft_admission_status"] != "TARGET_ELIGIBLE_WITH_EVIDENCE_DEBT":
        _fail(f"{path}.soft_admission_status", "unexpected soft-admission status")
    _require_string_list(
        policy["compensation_requirements"],
        f"{path}.compensation_requirements",
    )


def _validate_evaluation(profile: Mapping[str, Any], path: str) -> None:
    _require_exact_keys(profile, EVALUATION_KEYS, path)
    _require_string(profile["objective"], f"{path}.objective")
    metrics = _require_array(profile["metrics"], f"{path}.metrics")
    for index, metric_value in enumerate(metrics):
        metric_path = f"{path}.metrics[{index}]"
        metric = _require_object(metric_value, metric_path)
        _require_exact_keys(metric, METRIC_KEYS, metric_path)
        _require_identifier(metric["metric_id"], f"{metric_path}.metric_id")
        if metric["direction"] not in {"MAXIMIZE", "MINIMIZE", "TARGET_RANGE", "CONSTRAINT"}:
            _fail(f"{metric_path}.direction", "unknown metric direction")
        _require_string(metric["description"], f"{metric_path}.description")
        _require_object(metric["parameters"], f"{metric_path}.parameters")
    _index_unique(metrics, "metric_id", f"{path}.metrics")

    criteria = _require_array(profile["go_criteria"], f"{path}.go_criteria")
    for index, criterion_value in enumerate(criteria):
        criterion_path = f"{path}.go_criteria[{index}]"
        criterion = _require_object(criterion_value, criterion_path)
        _require_exact_keys(criterion, CRITERION_KEYS, criterion_path)
        _require_identifier(criterion["criterion_id"], f"{criterion_path}.criterion_id")
        if criterion["classification"] != "INTERNAL_DECISION_CRITERION":
            _fail(
                f"{criterion_path}.classification",
                "must equal INTERNAL_DECISION_CRITERION",
            )
        _require_string(criterion["description"], f"{criterion_path}.description")
        _require_object(criterion["parameters"], f"{criterion_path}.parameters")
    _index_unique(criteria, "criterion_id", f"{path}.go_criteria")


def _validate_deployment_boundary(boundary: Mapping[str, Any], path: str) -> None:
    _require_exact_keys(boundary, DEPLOYMENT_KEYS, path)
    if boundary["runtime_integration"] != RUNTIME_INTEGRATION_STATE:
        _fail(
            f"{path}.runtime_integration",
            f"must remain {RUNTIME_INTEGRATION_STATE} in additive rulepack v1",
        )
    if boundary["deploy_authorization"] != "OWNER_ONLY":
        _fail(f"{path}.deploy_authorization", "must equal OWNER_ONLY")
    if boundary["factory_action_authorized"] is not False:
        _fail(f"{path}.factory_action_authorized", "must be false")
    if boundary["mt5_action_authorized"] is not False:
        _fail(f"{path}.mt5_action_authorized", "must be false")
    _require_string_list(boundary["notes"], f"{path}.notes")


def _expect_parameters(
    rules: Mapping[str, Mapping[str, Any]], rule_id: str, expected: Mapping[str, Any]
) -> None:
    rule = rules.get(rule_id)
    if rule is None:
        _fail("$.official_rules", f"required rule {rule_id!r} is missing")
    actual = rule["parameters"]
    for key, value in expected.items():
        if actual.get(key) != value:
            _fail(
                f"$.official_rules[{rule_id}].parameters.{key}",
                f"must equal {value!r}, got {actual.get(key)!r}",
            )


def _require_guardrail(
    guardrails: Mapping[str, Mapping[str, Any]], guardrail_id: str
) -> Mapping[str, Any]:
    guardrail = guardrails.get(guardrail_id)
    if guardrail is None:
        _fail("$.internal_guardrails", f"required guardrail {guardrail_id!r} is missing")
    return guardrail


def _validate_dxz(
    payload: Mapping[str, Any],
    sources: Mapping[str, Mapping[str, Any]],
    rules: Mapping[str, Mapping[str, Any]],
    guardrails: Mapping[str, Mapping[str, Any]],
) -> None:
    if payload["account_or_program"] != "Darwinex Zero / DarwinIA SILVER and GOLD":
        _fail("$.account_or_program", "unexpected DXZ program identity")
    allowed_domains = {"www.darwinexzero.com", "darwinexzero.com", "help.darwinex.com"}
    for source_id, source in sources.items():
        if urlparse(source["url"]).hostname not in allowed_domains:
            _fail(
                f"$.official_sources[{source_id}].url",
                "DXZ official sources must use darwinexzero.com or help.darwinex.com",
            )

    _expect_parameters(
        rules,
        "dxz_darwin_target_var",
        {"confidence_percent": "95", "minimum_monthly_percent": "3.25", "maximum_monthly_percent": "6.5"},
    )
    _expect_parameters(
        rules,
        "dxz_dleverage_duration_caps",
        {"under_30m": "16.25", "from_30m_to_60m": "13", "over_60m": "9.75"},
    )
    _expect_parameters(
        rules,
        "dxz_risk_engine_lookback",
        {"strategy_var_exposed_days": 45, "target_var_max_months": 6, "max_var_ratio": "2"},
    )
    _expect_parameters(rules, "dxz_silver_rating", {"minimum_rating": "75"})
    _expect_parameters(
        rules,
        "dxz_silver_rating_weights",
        {"current_month_return_percent": "22", "six_month_return_percent": "67", "six_month_max_drawdown_percent": "11"},
    )
    _expect_parameters(
        rules,
        "dxz_silver_correlation",
        {"same_user_max_exclusive": "0.5", "other_user_max_exclusive": "0.95"},
    )
    _expect_parameters(
        rules,
        "dxz_gold_eligibility",
        {"minimum_history_months_exclusive": 8, "minimum_return_drawdown_ratio_exclusive": "2.5"},
    )

    forbidden_provider_claims = {"dxz_daily_loss_limit", "dxz_total_loss_limit"}
    leaked = sorted(forbidden_provider_claims & set(rules))
    if leaked:
        _fail(
            "$.official_rules",
            f"unverified local loss limits cannot be provider rules: {leaked}",
        )
    daily = _require_guardrail(guardrails, "qm_dxz_daily_loss_guardrail")
    total = _require_guardrail(guardrails, "qm_dxz_total_loss_guardrail")
    if daily["parameters"].get("percent_of_reference_equity") != "5":
        _fail("$.internal_guardrails.qm_dxz_daily_loss_guardrail", "must retain 5% internal value")
    if total["parameters"].get("percent_of_reference_equity") != "20":
        _fail("$.internal_guardrails.qm_dxz_total_loss_guardrail", "must retain 20% internal value")


def _validate_ftmo(
    payload: Mapping[str, Any],
    sources: Mapping[str, Mapping[str, Any]],
    rules: Mapping[str, Mapping[str, Any]],
    guardrails: Mapping[str, Mapping[str, Any]],
) -> None:
    if payload["account_or_program"] != "FTMO Challenge 2-Step / USD 100000 / Swing":
        _fail("$.account_or_program", "unexpected FTMO product identity")
    for source_id, source in sources.items():
        hostname = urlparse(source["url"]).hostname or ""
        if hostname != "ftmo.com" and not hostname.endswith(".ftmo.com"):
            _fail(f"$.official_sources[{source_id}].url", "FTMO sources must use ftmo.com")

    _expect_parameters(
        rules,
        "ftmo_2s_phase1_profit_target",
        {"percent_of_initial_simulated_capital": "10", "balance_usd": "110000"},
    )
    _expect_parameters(
        rules,
        "ftmo_2s_verification_profit_target",
        {"percent_of_initial_simulated_capital": "5", "balance_usd": "105000"},
    )
    _expect_parameters(
        rules,
        "ftmo_2s_max_daily_loss",
        {"percent_of_initial_simulated_capital": "5", "amount_usd": "5000", "timezone": "Europe/Prague", "reset_local_time": "00:00:00"},
    )
    _expect_parameters(
        rules,
        "ftmo_2s_maximum_loss",
        {"model": "STATIC_INITIAL", "percent_of_initial_simulated_capital": "10", "floor_usd": "90000"},
    )
    _expect_parameters(rules, "ftmo_2s_minimum_trading_days", {"days": 4, "qualifying_action": "POSITION_OPENED"})
    _expect_parameters(rules, "ftmo_2s_no_time_limit", {"maximum_trading_period_days": None})
    _expect_parameters(
        rules,
        "ftmo_2s_pass_condition",
        {"balance_operator": "STRICTLY_GREATER_THAN_TARGET", "positions_open": 0},
    )
    _expect_parameters(
        rules,
        "ftmo_swing_news",
        {"evaluation_restricted": False, "ftmo_account_swing_restricted": False},
    )
    _expect_parameters(
        rules,
        "ftmo_swing_weekend",
        {"evaluation_restricted": False, "ftmo_account_swing_restricted": False},
    )
    _expect_parameters(
        rules,
        "ftmo_ea_server_limits",
        {"simultaneous_orders": 200, "positions_per_day": 2000, "server_requests_per_day_hyperactive_above": 2000},
    )
    _require_guardrail(guardrails, "qm_ftmo_initial_balance_risk_anchor")
    _require_guardrail(guardrails, "qm_ftmo_phase1_target_capture_buffer")
    _require_guardrail(guardrails, "qm_ftmo_phase2_target_capture_buffer")


def validate_rulepack(payload: Mapping[str, Any]) -> None:
    """Validate structure, separation of authority, and target invariants."""

    _assert_json_types(payload)
    _require_exact_keys(payload, ROOT_KEYS, "$")
    if payload["schema_version"] != SCHEMA_VERSION:
        _fail("$.schema_version", f"must equal {SCHEMA_VERSION}")
    if payload["schema_ref"] != "tools/strategy_farm/schemas/target_rulepack_v1.schema.json":
        _fail("$.schema_ref", "must point to the repository v1 schema")

    rulepack_id = _require_string(payload["rulepack_id"], "$.rulepack_id")
    id_match = RULEPACK_ID_RE.fullmatch(rulepack_id)
    if not id_match:
        _fail("$.rulepack_id", "must be uppercase and end in _V<positive integer>")
    profile_version = payload["profile_version"]
    if not isinstance(profile_version, int) or isinstance(profile_version, bool) or profile_version <= 0:
        _fail("$.profile_version", "must be a positive integer")
    if int(id_match.group("version")) != profile_version:
        _fail("$.profile_version", "must match rulepack_id version suffix")
    if payload["target"] not in {"DARWINEX_ZERO", "FTMO"}:
        _fail("$.target", "must be DARWINEX_ZERO or FTMO")
    _require_string(payload["account_or_program"], "$.account_or_program")
    as_of = _require_iso_date(payload["as_of"], "$.as_of")
    if payload["lifecycle_status"] != "RESEARCH_CONTRACT_ONLY":
        _fail("$.lifecycle_status", "must equal RESEARCH_CONTRACT_ONLY")

    canonicalization = _require_object(payload["canonicalization"], "$.canonicalization")
    _require_exact_keys(
        canonicalization,
        {"algorithm", "hash_algorithm", "numeric_encoding"},
        "$.canonicalization",
    )
    if canonicalization != {
        "algorithm": CANONICALIZATION_ALGORITHM,
        "hash_algorithm": HASH_ALGORITHM,
        "numeric_encoding": "NON_INTEGRAL_AS_DECIMAL_STRING",
    }:
        _fail("$.canonicalization", "unsupported canonicalization contract")

    source_values = _require_array(payload["official_sources"], "$.official_sources")
    for index, source_value in enumerate(source_values):
        source = _require_object(source_value, f"$.official_sources[{index}]")
        _validate_source(source, f"$.official_sources[{index}]", as_of)
    sources = _index_unique(source_values, "source_id", "$.official_sources")

    rule_values = _require_array(payload["official_rules"], "$.official_rules")
    for index, rule_value in enumerate(rule_values):
        rule = _require_object(rule_value, f"$.official_rules[{index}]")
        _validate_rule(rule, f"$.official_rules[{index}]", set(sources))
    rules = _index_unique(rule_values, "rule_id", "$.official_rules")

    guardrail_values = _require_array(payload["internal_guardrails"], "$.internal_guardrails")
    for index, guardrail_value in enumerate(guardrail_values):
        guardrail = _require_object(guardrail_value, f"$.internal_guardrails[{index}]")
        _validate_guardrail(guardrail, f"$.internal_guardrails[{index}]")
    guardrails = _index_unique(guardrail_values, "guardrail_id", "$.internal_guardrails")

    _validate_q08_policy(
        _require_object(payload["q08_evidence_policy"], "$.q08_evidence_policy"),
        "$.q08_evidence_policy",
    )
    _validate_evaluation(
        _require_object(payload["evaluation_profile"], "$.evaluation_profile"),
        "$.evaluation_profile",
    )
    _validate_deployment_boundary(
        _require_object(payload["deployment_boundary"], "$.deployment_boundary"),
        "$.deployment_boundary",
    )

    if payload["target"] == "DARWINEX_ZERO":
        if not rulepack_id.startswith("DXZ_"):
            _fail("$.rulepack_id", "DARWINEX_ZERO rulepacks must use DXZ_ prefix")
        _validate_dxz(payload, sources, rules, guardrails)
    else:
        if not rulepack_id.startswith("FTMO_"):
            _fail("$.rulepack_id", "FTMO rulepacks must use FTMO_ prefix")
        _validate_ftmo(payload, sources, rules, guardrails)


def load_rulepack_path(path: Path | str) -> TargetRulepack:
    source_path = Path(path).resolve()
    payload = parse_rulepack_json(source_path.read_text(encoding="utf-8"))
    validate_rulepack(payload)
    canonical = canonical_json_bytes(payload)
    return TargetRulepack(
        rulepack_id=payload["rulepack_id"],
        profile_version=payload["profile_version"],
        target=payload["target"],
        as_of=payload["as_of"],
        source_path=source_path,
        canonical_payload=canonical,
        canonical_sha256=hashlib.sha256(canonical).hexdigest(),
    )


def write_rulepack(
    payload: Mapping[str, Any],
    *,
    rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR,
) -> TargetRulepack:
    """Create a validated rulepack without ever replacing an existing version.

    The on-disk document is deterministic, human-readable JSON.  Identity is
    still computed over :func:`canonical_json_bytes`, so formatting never
    changes the payload hash.  Callers must allocate a new ``_V<n>`` identity
    for revisions; an existing path raises :class:`FileExistsError`.
    """

    validate_rulepack(payload)
    rulepack_id = payload["rulepack_id"]
    directory = Path(rulepack_dir).resolve()
    if not directory.is_dir():
        raise FileNotFoundError(directory)
    path = (directory / f"{rulepack_id}.json").resolve()
    if path.parent != directory:
        _fail("$.rulepack_id", "resolved outside rulepack directory")

    document = json.dumps(
        payload,
        indent=2,
        sort_keys=True,
        ensure_ascii=False,
        allow_nan=False,
    ) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(document)
    return load_rulepack(rulepack_id, rulepack_dir=directory)


def load_rulepack(
    rulepack_id: str, *, rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR
) -> TargetRulepack:
    if not RULEPACK_ID_RE.fullmatch(rulepack_id):
        _fail("rulepack_id", "invalid identifier")
    directory = Path(rulepack_dir).resolve()
    path = (directory / f"{rulepack_id}.json").resolve()
    if path.parent != directory:
        _fail("rulepack_id", "resolved outside rulepack directory")
    if not path.is_file():
        raise FileNotFoundError(path)
    loaded = load_rulepack_path(path)
    if loaded.rulepack_id != rulepack_id:
        _fail("$.rulepack_id", f"filename requested {rulepack_id}, payload contains {loaded.rulepack_id}")
    return loaded


def list_rulepack_ids(*, rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR) -> tuple[str, ...]:
    directory = Path(rulepack_dir)
    if not directory.is_dir():
        return ()
    return tuple(sorted(path.stem for path in directory.glob("*.json") if RULEPACK_ID_RE.fullmatch(path.stem)))


def validate_all(*, rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR) -> list[TargetRulepack]:
    return [load_rulepack(rulepack_id, rulepack_dir=rulepack_dir) for rulepack_id in list_rulepack_ids(rulepack_dir=rulepack_dir)]


def _cli() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rulepack_id", nargs="?", help="validate one rulepack; omit to validate all")
    parser.add_argument("--json", action="store_true", help="emit machine-readable summary")
    args = parser.parse_args()
    packs = [load_rulepack(args.rulepack_id)] if args.rulepack_id else validate_all()
    rows = [
        {
            "rulepack_id": pack.rulepack_id,
            "target": pack.target,
            "as_of": pack.as_of,
            "canonical_sha256": pack.canonical_sha256,
            "source_path": str(pack.source_path),
        }
        for pack in packs
    ]
    if args.json:
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        for row in rows:
            print(f"{row['rulepack_id']} PASS {row['canonical_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli())
