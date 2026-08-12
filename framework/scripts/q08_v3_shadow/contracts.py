"""Versioned, side-effect-free contracts for the Q08 v3 shadow evaluator."""

from __future__ import annotations

import re
from dataclasses import dataclass
from enum import Enum
from typing import Any, Mapping


DECISION_SCHEMA_VERSION = "q08_shadow_decision/v1"


class _StringEnum(str, Enum):
    def __str__(self) -> str:
        return self.value


class SubtestStatus(_StringEnum):
    """Observed state of one Q08 v3 evidence test.

    ``INSUFFICIENT`` and ``NOT_APPLICABLE`` are evidence states, never passes.
    ``INVALID`` is reserved for evidence whose integrity cannot be trusted.
    """

    PASS = "PASS"
    FAIL = "FAIL"
    INSUFFICIENT = "INSUFFICIENT"
    NOT_APPLICABLE = "NOT_APPLICABLE"
    INVALID = "INVALID"


class EvidenceVerdict(_StringEnum):
    SUPPORTED = "SUPPORTED"
    CONDITIONAL = "CONDITIONAL"
    INSUFFICIENT = "INSUFFICIENT"
    CONTRADICTED = "CONTRADICTED"
    INVALID = "INVALID"


class ShadowRoute(_StringEnum):
    """Advisory route only; no member of this enum mutates pipeline state."""

    PORTFOLIO_EVALUATION = "PORTFOLIO_EVALUATION"
    PORTFOLIO_EVALUATION_CONDITIONAL = "PORTFOLIO_EVALUATION_CONDITIONAL"
    SHADOW_EVIDENCE = "SHADOW_EVIDENCE"
    REJECT = "REJECT"
    RETRY = "RETRY"


class RequirementLevel(_StringEnum):
    REQUIRED = "REQUIRED"
    DIAGNOSTIC = "DIAGNOSTIC"


class FailureEffect(_StringEnum):
    """Aggregate effect of a computed FAIL for a policy test."""

    CONDITIONAL = "CONDITIONAL"
    CONTRADICTED = "CONTRADICTED"
    INVALID = "INVALID"


VERDICT_ROUTE = {
    EvidenceVerdict.SUPPORTED: ShadowRoute.PORTFOLIO_EVALUATION,
    EvidenceVerdict.CONDITIONAL: ShadowRoute.PORTFOLIO_EVALUATION_CONDITIONAL,
    EvidenceVerdict.INSUFFICIENT: ShadowRoute.SHADOW_EVIDENCE,
    EvidenceVerdict.CONTRADICTED: ShadowRoute.REJECT,
    EvidenceVerdict.INVALID: ShadowRoute.RETRY,
}


@dataclass(frozen=True, slots=True)
class SubtestResult:
    """One shadow subtest result.

    Mapping input has the exact allowed keyset ``test_id``, ``status`` and
    optional ``detail``.  ``test_id`` and ``status`` are required strings
    (``SubtestStatus`` is also accepted in Python); omitted ``detail`` means
    the empty string.  Explicit nulls, non-strings and extra keys are invalid.
    """

    test_id: str
    status: SubtestStatus
    detail: str = ""

    def __post_init__(self) -> None:
        if not isinstance(self.test_id, str) or not re.fullmatch(
            r"[a-z][a-z0-9_]*", self.test_id
        ):
            raise ValueError("subtest result test_id must be a lower_snake_case token")
        raw_status = self.status
        if not isinstance(raw_status, (str, SubtestStatus)):
            raise ValueError("subtest result status must be a string")
        try:
            status = (
                raw_status
                if isinstance(raw_status, SubtestStatus)
                else SubtestStatus(raw_status.strip().upper())
            )
        except ValueError as exc:
            raise ValueError(
                f"subtest {self.test_id!r} has unsupported status {raw_status!r}"
            ) from exc
        if not isinstance(self.detail, str):
            raise ValueError("subtest result detail must be a string when provided")
        object.__setattr__(self, "status", status)

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "SubtestResult":
        if not isinstance(value, Mapping):
            raise ValueError("subtest result must be an object")
        allowed_keys = {"test_id", "status", "detail"}
        required_keys = {"test_id", "status"}
        actual_keys = set(value.keys())
        extra_keys = actual_keys - allowed_keys
        if extra_keys:
            raise ValueError(
                f"subtest result has unsupported keys {sorted(str(k) for k in extra_keys)!r}"
            )
        missing_keys = required_keys - actual_keys
        if missing_keys:
            raise ValueError(
                f"subtest result is missing keys {sorted(missing_keys)!r}"
            )
        raw_test_id = value["test_id"]
        if not isinstance(raw_test_id, str):
            raise ValueError("subtest result test_id must be a string")
        test_id = raw_test_id.strip()
        if not test_id:
            raise ValueError("subtest result requires a non-empty test_id")
        if not re.fullmatch(r"[a-z][a-z0-9_]*", test_id):
            raise ValueError("subtest result test_id must be a lower_snake_case token")
        raw_status = value["status"]
        if not isinstance(raw_status, (str, SubtestStatus)):
            raise ValueError("subtest result status must be a string")
        try:
            status = (
                raw_status
                if isinstance(raw_status, SubtestStatus)
                else SubtestStatus(str(raw_status or "").strip().upper())
            )
        except ValueError as exc:
            raise ValueError(
                f"subtest {test_id!r} has unsupported status {raw_status!r}"
            ) from exc
        raw_detail = value.get("detail", "")
        if not isinstance(raw_detail, str):
            raise ValueError("subtest result detail must be a string when provided")
        return cls(test_id=test_id, status=status, detail=raw_detail)


@dataclass(frozen=True, slots=True)
class AggregateDecision:
    """Deterministic Q08 v3 shadow decision.

    Tuples are used throughout so a caller cannot mutate an already-issued
    decision.  ``to_dict`` emits the versioned JSON-schema representation.
    """

    policy_version: str
    policy_sha256: str
    verdict: EvidenceVerdict
    route: ShadowRoute
    archetype_requested: str
    archetype_resolved: str | None
    required_test_ids: tuple[str, ...]
    supported_test_ids: tuple[str, ...]
    conditional_test_ids: tuple[str, ...]
    insufficient_test_ids: tuple[str, ...]
    contradicted_test_ids: tuple[str, ...]
    invalid_test_ids: tuple[str, ...]
    missing_test_ids: tuple[str, ...]
    diagnostic_test_ids: tuple[str, ...]
    ignored_test_ids: tuple[str, ...]
    reasons: tuple[str, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": DECISION_SCHEMA_VERSION,
            "policy_version": self.policy_version,
            "policy_sha256": self.policy_sha256,
            "verdict": self.verdict.value,
            "route": self.route.value,
            "archetype_requested": self.archetype_requested,
            "archetype_resolved": self.archetype_resolved,
            "required_test_ids": list(self.required_test_ids),
            "supported_test_ids": list(self.supported_test_ids),
            "conditional_test_ids": list(self.conditional_test_ids),
            "insufficient_test_ids": list(self.insufficient_test_ids),
            "contradicted_test_ids": list(self.contradicted_test_ids),
            "invalid_test_ids": list(self.invalid_test_ids),
            "missing_test_ids": list(self.missing_test_ids),
            "diagnostic_test_ids": list(self.diagnostic_test_ids),
            "ignored_test_ids": list(self.ignored_test_ids),
            "reasons": list(self.reasons),
        }
