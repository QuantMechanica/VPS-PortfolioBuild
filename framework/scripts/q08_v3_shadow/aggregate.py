"""Pure Q08 v3 shadow aggregation and advisory routing."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any

from .contracts import (
    AggregateDecision,
    EvidenceVerdict,
    FailureEffect,
    RequirementLevel,
    SubtestResult,
    SubtestStatus,
    VERDICT_ROUTE,
)
from .policy import PolicyManifest, PolicyTest


def _sorted(values: Iterable[str]) -> tuple[str, ...]:
    return tuple(sorted(set(values)))


def _coerce_results(
    raw_results: Iterable[SubtestResult | Mapping[str, Any]],
) -> tuple[dict[str, SubtestResult], list[str], list[str]]:
    results: dict[str, SubtestResult] = {}
    duplicates: list[str] = []
    contract_errors: list[str] = []
    for index, raw in enumerate(raw_results):
        try:
            result = raw if isinstance(raw, SubtestResult) else SubtestResult.from_mapping(raw)
        except (TypeError, ValueError) as exc:
            contract_errors.append(f"result[{index}]:{exc}")
            continue
        if result.test_id in results:
            duplicates.append(result.test_id)
            continue
        results[result.test_id] = result
    return results, duplicates, contract_errors


def aggregate_shadow(
    *,
    archetype: str,
    results: Iterable[SubtestResult | Mapping[str, Any]],
    policy: PolicyManifest,
) -> AggregateDecision:
    """Aggregate evidence without I/O or pipeline mutation.

    Precedence is deliberately fail-closed:
    INVALID > CONTRADICTED > INSUFFICIENT > CONDITIONAL > SUPPORTED.
    Only REQUIRED PASS results contribute support.  Missing, insufficient, or
    not-applicable REQUIRED evidence can therefore never synthesize a pass.
    """

    requested = str(archetype or "").strip()
    archetype_policy = policy.resolve_archetype(requested)
    observed, duplicates, contract_errors = _coerce_results(results)

    expected: list[PolicyTest] = list(policy.universal_tests)
    if archetype_policy is not None:
        expected.extend(archetype_policy.tests)

    required = [
        item.test_id for item in expected if item.requirement is RequirementLevel.REQUIRED
    ]
    supported: list[str] = []
    conditional: list[str] = []
    insufficient: list[str] = []
    contradicted: list[str] = []
    invalid: list[str] = []
    missing: list[str] = []
    diagnostic: list[str] = []
    reasons: list[str] = []

    if duplicates:
        invalid.extend(f"duplicate:{test_id}" for test_id in duplicates)
        reasons.extend(f"duplicate_result:{test_id}" for test_id in duplicates)
    if contract_errors:
        invalid.extend(f"contract:{index}" for index, _ in enumerate(contract_errors))
        reasons.extend(f"invalid_result_contract:{message}" for message in contract_errors)

    for test in expected:
        result = observed.get(test.test_id)
        if result is None:
            if test.requirement is RequirementLevel.REQUIRED:
                missing.append(test.test_id)
                reasons.append(f"missing_required:{test.test_id}")
            continue

        if result.status is SubtestStatus.PASS:
            if test.requirement is RequirementLevel.REQUIRED:
                supported.append(test.test_id)
            else:
                diagnostic.append(test.test_id)
            continue

        if result.status is SubtestStatus.FAIL:
            if test.fail_verdict is FailureEffect.INVALID:
                invalid.append(test.test_id)
                reasons.append(f"computed_invalidating_failure:{test.test_id}")
            elif test.fail_verdict is FailureEffect.CONTRADICTED:
                contradicted.append(test.test_id)
                reasons.append(f"computed_contradiction:{test.test_id}")
            else:
                conditional.append(test.test_id)
                reasons.append(f"computed_conditional_weakness:{test.test_id}")
            continue

        if result.status is SubtestStatus.INVALID:
            if test.requirement is RequirementLevel.REQUIRED:
                invalid.append(test.test_id)
                reasons.append(f"invalid_required_evidence:{test.test_id}")
            else:
                diagnostic.append(test.test_id)
            continue

        # INSUFFICIENT and NOT_APPLICABLE are deliberately evidence gaps.
        if test.requirement is RequirementLevel.REQUIRED:
            insufficient.append(test.test_id)
            reasons.append(
                f"required_evidence_{result.status.value.lower()}:{test.test_id}"
            )
        else:
            diagnostic.append(test.test_id)

    if archetype_policy is None:
        insufficient.append("archetype_policy")
        reasons.append(f"unknown_archetype:{requested or '<empty>'}")

    expected_ids = {item.test_id for item in expected}
    deliberately_ignored_ids = (
        set(policy.portfolio_only_tests)
        | (set(policy.declared_archetype_test_ids) - expected_ids)
    )
    ignored = [
        test_id
        for test_id in observed
        if test_id not in expected_ids and test_id in deliberately_ignored_ids
    ]
    unknown_result_ids = [
        test_id
        for test_id in observed
        if test_id not in expected_ids and test_id not in deliberately_ignored_ids
    ]
    for test_id in unknown_result_ids:
        invalid.append(f"unknown:{test_id}")
        reasons.append(f"unknown_result_test_id:{test_id}")

    if invalid:
        verdict = EvidenceVerdict.INVALID
    elif contradicted:
        verdict = EvidenceVerdict.CONTRADICTED
    elif missing or insufficient:
        verdict = EvidenceVerdict.INSUFFICIENT
    elif conditional:
        verdict = EvidenceVerdict.CONDITIONAL
    else:
        verdict = EvidenceVerdict.SUPPORTED

    return AggregateDecision(
        policy_version=policy.policy_version,
        policy_sha256=policy.policy_sha256,
        verdict=verdict,
        route=VERDICT_ROUTE[verdict],
        archetype_requested=requested,
        archetype_resolved=archetype_policy.name if archetype_policy else None,
        required_test_ids=_sorted(required),
        supported_test_ids=_sorted(supported),
        conditional_test_ids=_sorted(conditional),
        insufficient_test_ids=_sorted(insufficient),
        contradicted_test_ids=_sorted(contradicted),
        invalid_test_ids=_sorted(invalid),
        missing_test_ids=_sorted(missing),
        diagnostic_test_ids=_sorted(diagnostic),
        ignored_test_ids=_sorted(ignored),
        reasons=tuple(sorted(reasons)),
    )
