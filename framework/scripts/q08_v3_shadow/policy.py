"""Loader and strict validator for the Q08 v3 archetype policy manifest."""

from __future__ import annotations

import json
import hashlib
import re
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping

from .contracts import FailureEffect, RequirementLevel


POLICY_SCHEMA_VERSION = "q08_archetype_policy/v1"
DEFAULT_POLICY_PATH = Path(__file__).with_name("archetype_policy_v1.json")
_TOKEN_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_TOP_LEVEL_KEYS = {
    "schema_version",
    "policy_version",
    "unknown_archetype_verdict",
    "universal_tests",
    "portfolio_only_tests",
    "archetypes",
}
_TEST_KEYS = {"test_id", "requirement", "fail_verdict", "description"}
_ARCHETYPE_KEYS = {"aliases", "cluster_unit", "tests"}


class PolicyValidationError(ValueError):
    pass


def _duplicate_key_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise PolicyValidationError(f"duplicate policy JSON key: {key}")
        result[key] = value
    return result


def _reject_float(value: str) -> None:
    raise PolicyValidationError(f"floating-point policy value rejected: {value}")


def _reject_constant(value: str) -> None:
    raise PolicyValidationError(f"non-finite policy value rejected: {value}")


def _require_exact_keys(value: Mapping[str, Any], expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        raise PolicyValidationError(
            f"{context}: key set mismatch "
            f"(missing={sorted(expected - actual)!r}, extra={sorted(actual - expected)!r})"
        )


def _normalise_token(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(value or "").strip().lower()).strip("_")


@dataclass(frozen=True, slots=True)
class PolicyTest:
    test_id: str
    requirement: RequirementLevel
    fail_verdict: FailureEffect
    description: str


@dataclass(frozen=True, slots=True)
class ArchetypePolicy:
    name: str
    aliases: tuple[str, ...]
    cluster_unit: str
    tests: tuple[PolicyTest, ...]


@dataclass(frozen=True, slots=True)
class PolicyManifest:
    schema_version: str
    policy_version: str
    policy_sha256: str
    unknown_archetype_verdict: str
    universal_tests: tuple[PolicyTest, ...]
    portfolio_only_tests: tuple[str, ...]
    archetypes: Mapping[str, ArchetypePolicy]
    alias_index: Mapping[str, str]

    def resolve_archetype(self, value: str) -> ArchetypePolicy | None:
        canonical = self.alias_index.get(_normalise_token(value))
        return self.archetypes.get(canonical) if canonical else None

    @property
    def declared_archetype_test_ids(self) -> frozenset[str]:
        return frozenset(
            test.test_id
            for archetype in self.archetypes.values()
            for test in archetype.tests
        )


def _canonical_policy_sha256(payload: Mapping[str, Any]) -> str:
    """Hash semantic JSON content, independent of whitespace and object key order."""

    try:
        canonical = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(f"policy is not canonical JSON: {exc}") from exc
    return hashlib.sha256(canonical).hexdigest()


def _parse_test(raw: Any, *, context: str) -> PolicyTest:
    if not isinstance(raw, Mapping):
        raise PolicyValidationError(f"{context}: test entry must be an object")
    _require_exact_keys(raw, _TEST_KEYS, context)
    test_id = raw.get("test_id")
    if not isinstance(test_id, str):
        raise PolicyValidationError(f"{context}: test_id must be a string")
    if not _TOKEN_RE.fullmatch(test_id):
        raise PolicyValidationError(f"{context}: invalid test_id {test_id!r}")
    try:
        requirement = RequirementLevel(raw.get("requirement"))
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(
            f"{context}.{test_id}: unsupported requirement {raw.get('requirement')!r}"
        ) from exc
    try:
        fail_verdict = FailureEffect(raw.get("fail_verdict"))
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(
            f"{context}.{test_id}: unsupported fail_verdict {raw.get('fail_verdict')!r}"
        ) from exc
    description = raw.get("description")
    if (
        not isinstance(description, str)
        or not description
        or description != description.strip()
    ):
        raise PolicyValidationError(f"{context}.{test_id}: description is required")
    return PolicyTest(test_id, requirement, fail_verdict, description)


def _parse_test_list(raw: Any, *, context: str) -> tuple[PolicyTest, ...]:
    if not isinstance(raw, list) or not raw:
        raise PolicyValidationError(f"{context}: tests must be a non-empty array")
    tests = tuple(_parse_test(item, context=context) for item in raw)
    ids = [item.test_id for item in tests]
    if len(ids) != len(set(ids)):
        raise PolicyValidationError(f"{context}: duplicate test_id")
    return tests


def parse_policy(payload: Mapping[str, Any]) -> PolicyManifest:
    """Validate a decoded manifest and return an immutable policy object."""

    if not isinstance(payload, Mapping):
        raise PolicyValidationError("policy payload must be an object")
    _require_exact_keys(payload, _TOP_LEVEL_KEYS, "policy")
    schema_version = payload.get("schema_version")
    if schema_version != POLICY_SCHEMA_VERSION:
        raise PolicyValidationError(
            f"unsupported policy schema {schema_version!r}; expected {POLICY_SCHEMA_VERSION!r}"
        )
    policy_version = payload.get("policy_version")
    if (
        not isinstance(policy_version, str)
        or not policy_version
        or policy_version != policy_version.strip()
    ):
        raise PolicyValidationError("policy_version is required")
    unknown = payload.get("unknown_archetype_verdict")
    if unknown != "INSUFFICIENT":
        raise PolicyValidationError(
            "unknown_archetype_verdict must be INSUFFICIENT in shadow v1"
        )

    universal = _parse_test_list(payload.get("universal_tests"), context="universal_tests")
    raw_portfolio_only = payload.get("portfolio_only_tests")
    if not isinstance(raw_portfolio_only, list):
        raise PolicyValidationError("portfolio_only_tests must be an array")
    if any(not isinstance(item, str) for item in raw_portfolio_only):
        raise PolicyValidationError("portfolio_only_tests must contain only strings")
    portfolio_only_tests = tuple(raw_portfolio_only)
    if any(not _TOKEN_RE.fullmatch(item) for item in portfolio_only_tests):
        raise PolicyValidationError("portfolio_only_tests contains an invalid test_id")
    if len(portfolio_only_tests) != len(set(portfolio_only_tests)):
        raise PolicyValidationError("portfolio_only_tests contains duplicate test_id")

    raw_archetypes = payload.get("archetypes")
    if not isinstance(raw_archetypes, Mapping) or not raw_archetypes:
        raise PolicyValidationError("archetypes must be a non-empty object")

    archetypes: dict[str, ArchetypePolicy] = {}
    alias_index: dict[str, str] = {}
    universal_ids = {test.test_id for test in universal}
    portfolio_ids = set(portfolio_only_tests)
    overlap = universal_ids & portfolio_ids
    if overlap:
        raise PolicyValidationError(
            f"portfolio_only_tests duplicate universal ids {sorted(overlap)!r}"
        )
    archetype_test_owners: dict[str, str] = {}
    for raw_name, raw_policy in raw_archetypes.items():
        if not isinstance(raw_name, str):
            raise PolicyValidationError("archetype names must be strings")
        name = raw_name
        if not _TOKEN_RE.fullmatch(name):
            raise PolicyValidationError(f"invalid archetype name {name!r}")
        if not isinstance(raw_policy, Mapping):
            raise PolicyValidationError(f"archetypes.{name}: value must be an object")
        _require_exact_keys(raw_policy, _ARCHETYPE_KEYS, f"archetypes.{name}")
        raw_aliases = raw_policy.get("aliases")
        if not isinstance(raw_aliases, list):
            raise PolicyValidationError(f"archetypes.{name}.aliases must be an array")
        if any(not isinstance(alias, str) for alias in raw_aliases):
            raise PolicyValidationError(f"archetypes.{name}: aliases must be strings")
        aliases = tuple(_normalise_token(alias) for alias in raw_aliases)
        if any(not alias for alias in aliases):
            raise PolicyValidationError(f"archetypes.{name}: alias cannot be empty")
        if len(set((name, *aliases))) != len((name, *aliases)):
            raise PolicyValidationError(f"archetypes.{name}: aliases must be unique")
        cluster_unit = raw_policy.get("cluster_unit")
        if not isinstance(cluster_unit, str) or not _TOKEN_RE.fullmatch(cluster_unit):
            raise PolicyValidationError(f"archetypes.{name}.cluster_unit is required")
        tests = _parse_test_list(raw_policy.get("tests"), context=f"archetypes.{name}.tests")
        overlap = universal_ids & {test.test_id for test in tests}
        if overlap:
            raise PolicyValidationError(
                f"archetypes.{name}: tests duplicate universal ids {sorted(overlap)!r}"
            )
        portfolio_overlap = portfolio_ids & {test.test_id for test in tests}
        if portfolio_overlap:
            raise PolicyValidationError(
                f"archetypes.{name}: tests duplicate portfolio-only ids "
                f"{sorted(portfolio_overlap)!r}"
            )
        for test in tests:
            owner = archetype_test_owners.get(test.test_id)
            if owner is not None and owner != name:
                raise PolicyValidationError(
                    f"archetype test {test.test_id!r} is shared by {owner!r} and {name!r}"
                )
            archetype_test_owners[test.test_id] = name
        archetype = ArchetypePolicy(name, aliases, cluster_unit, tests)
        archetypes[name] = archetype
        for alias in (name, *aliases):
            token = _normalise_token(alias)
            owner = alias_index.get(token)
            if owner is not None and owner != name:
                raise PolicyValidationError(
                    f"archetype alias {token!r} is shared by {owner!r} and {name!r}"
                )
            alias_index[token] = name

    return PolicyManifest(
        schema_version=schema_version,
        policy_version=policy_version,
        policy_sha256=_canonical_policy_sha256(payload),
        unknown_archetype_verdict=unknown,
        universal_tests=universal,
        portfolio_only_tests=portfolio_only_tests,
        archetypes=MappingProxyType(archetypes),
        alias_index=MappingProxyType(alias_index),
    )


def load_policy(path: Path | str = DEFAULT_POLICY_PATH) -> PolicyManifest:
    policy_path = Path(path)
    try:
        payload = json.loads(
            policy_path.read_text(encoding="utf-8"),
            object_pairs_hook=_duplicate_key_guard,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except PolicyValidationError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise PolicyValidationError(f"cannot load policy {policy_path}: {exc}") from exc
    return parse_policy(payload)
