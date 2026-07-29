"""Strict, content-addressed Strategy Card V3 contracts.

This module is intentionally runtime-disconnected.  It does not open the farm
database, enqueue work, change a pipeline verdict, or interpret a card as G0
approval.  OWNER/agent G0 decisions remain separate governance records.

The implementation uses only the Python standard library.  The JSON Schema is
the portable shape contract; this module adds cross-field and cryptographic
validation that JSON Schema alone cannot express.
"""

from __future__ import annotations

import copy
import hashlib
import hmac
import json
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping


CARD_SCHEMA_VERSION = "qm.strategy-card/v3"
Q08_POLICY_SCHEMA_VERSION = "q08_archetype_policy/v1"

DEFAULT_SCHEMA_PATH = Path(__file__).with_name("schemas") / "strategy_card_v3.schema.json"
DEFAULT_Q08_POLICY_PATH = (
    Path(__file__).resolve().parents[2]
    / "framework"
    / "scripts"
    / "q08_v3_shadow"
    / "archetype_policy_v1.json"
)

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$")
_TOKEN_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_SYMBOL_RE = re.compile(r"^[A-Z0-9][A-Z0-9._-]{0,31}$")
_TIMEFRAME_RE = re.compile(r"^(?:M[1-9][0-9]*|H[1-9][0-9]*|D1|W1|MN1)$")
_UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$")
_DECIMAL_RE = re.compile(r"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")

_TOP_LEVEL_KEYS = {
    "schema_version",
    "card_id",
    "card_version",
    "source_authorization_id",
    "source_sha256",
    "contract_bindings",
    "mechanism",
    "falsifiable_prediction",
    "falsifier",
    "kill_criteria",
    "assumptions",
    "primary_archetype",
    "independent_cluster_unit",
    "degrees_of_freedom",
    "trial_budget",
    "parameter_space",
    "symbol",
    "timeframe",
    "data_cut",
    "dev_seal",
    "oos_seal",
    "execution_assumptions",
    "execution_dependencies",
    "author",
    "card_sha256",
}
_DRAFT_KEYS = _TOP_LEVEL_KEYS - {"contract_bindings", "card_sha256"}
_CONTRACT_BINDING_KEYS = {
    "strategy_card_schema_sha256",
    "q08_policy_version",
    "q08_policy_sha256",
}
_DOF_KEYS = {"declared_count", "components"}
_DOF_COMPONENT_KEYS = {"name", "count"}
_TRIAL_BUDGET_KEYS = {
    "budget_id",
    "max_independent_trials",
    "max_parameter_cells",
}
_PARAMETER_SPACE_KEYS = {"domains", "cells"}
_PARAMETER_DOMAIN_KEYS = {"name", "value_type", "values"}
_PARAMETER_CELL_KEYS = {"cell_id", "assignments", "cell_sha256"}
_PARAMETER_CELL_DRAFT_KEYS = {"cell_id", "assignments"}
_DATA_CUT_KEYS = {"cut_id", "dataset_sha256", "cut_at_utc"}
_DATA_SEAL_KEYS = {
    "seal_id",
    "partition_sha256",
    "range_start_utc",
    "range_end_utc",
    "sealed_at_utc",
}
_DEPENDENCY_KEYS = {"dependency_id", "kind", "version", "sha256"}
_AUTHOR_KEYS = {"authority", "identity", "authored_at_utc"}
_DEPENDENCY_KINDS = {
    "CALENDAR",
    "COST_MODEL",
    "EXECUTION_MODEL",
    "EXTERNAL_DATA",
    "FRAMEWORK",
    "OTHER",
    "SESSION_CLOCK",
    "SYMBOL_SPEC",
}
_PARAMETER_VALUE_TYPES = {"BOOLEAN", "DECIMAL", "ENUM", "INTEGER"}


class StrategyCardError(ValueError):
    """The card or one of its bound contracts is invalid."""


@dataclass(frozen=True, slots=True)
class ContractBindings:
    strategy_card_schema_sha256: str
    q08_policy_version: str
    q08_policy_sha256: str
    archetype_cluster_units: Mapping[str, str]

    def as_dict(self) -> dict[str, str]:
        return {
            "strategy_card_schema_sha256": self.strategy_card_schema_sha256,
            "q08_policy_version": self.q08_policy_version,
            "q08_policy_sha256": self.q08_policy_sha256,
        }


@dataclass(frozen=True, slots=True)
class CardWriteReceipt:
    path: Path
    card_id: str
    card_version: int
    card_sha256: str
    size_bytes: int


def _duplicate_key_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise StrategyCardError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_json_constant(value: str) -> None:
    raise StrategyCardError(f"non-finite JSON number rejected: {value}")


def _validate_json_value(value: Any, path: str = "$") -> None:
    if value is None or isinstance(value, (str, bool)):
        return
    if isinstance(value, float):
        raise StrategyCardError(f"floating-point JSON value rejected at {path}")
    if isinstance(value, int):
        return
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                raise StrategyCardError(f"non-string object key rejected at {path}")
            _validate_json_value(child, f"{path}.{key}")
        return
    if isinstance(value, list):
        for index, child in enumerate(value):
            _validate_json_value(child, f"{path}[{index}]")
        return
    raise StrategyCardError(
        f"non-JSON value of type {type(value).__name__} rejected at {path}"
    )


def canonical_json_bytes(value: Any, *, file_form: bool = False) -> bytes:
    """Return deterministic UTF-8 JSON, optionally with one trailing LF."""

    _validate_json_value(value)
    try:
        encoded = json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise StrategyCardError(f"value is not canonical-JSON compatible: {exc}") from exc
    return encoded + (b"\n" if file_form else b"")


def semantic_json_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def canonical_card_hash(card: Mapping[str, Any]) -> str:
    if not isinstance(card, Mapping):
        raise StrategyCardError("card root must be an object")
    unsigned = copy.deepcopy(dict(card))
    unsigned.pop("card_sha256", None)
    return semantic_json_sha256(unsigned)


def _load_json_object(path: Path, *, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        decoded = raw.decode("utf-8")
        payload = json.loads(
            decoded,
            object_pairs_hook=_duplicate_key_guard,
            parse_constant=_reject_json_constant,
        )
    except StrategyCardError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise StrategyCardError(f"cannot load {label} {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise StrategyCardError(f"{label} root must be an object")
    _validate_json_value(payload)
    return payload, raw


def load_contract_bindings(
    *,
    schema_path: Path | str = DEFAULT_SCHEMA_PATH,
    q08_policy_path: Path | str = DEFAULT_Q08_POLICY_PATH,
) -> ContractBindings:
    """Load and hash the exact local schema and Q08 archetype policy."""

    schema, _ = _load_json_object(Path(schema_path), label="Strategy Card schema")
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        raise StrategyCardError("Strategy Card schema must use JSON Schema draft 2020-12")
    if schema.get("additionalProperties") is not False:
        raise StrategyCardError("Strategy Card schema root must reject additional properties")
    try:
        schema_const = schema["properties"]["schema_version"]["const"]
    except (KeyError, TypeError) as exc:
        raise StrategyCardError("Strategy Card schema lacks schema_version const") from exc
    if schema_const != CARD_SCHEMA_VERSION:
        raise StrategyCardError("Strategy Card schema_version const does not match implementation")

    policy, _ = _load_json_object(Path(q08_policy_path), label="Q08 archetype policy")
    if policy.get("schema_version") != Q08_POLICY_SCHEMA_VERSION:
        raise StrategyCardError("unsupported Q08 archetype policy schema_version")
    policy_version = _string(
        policy.get("policy_version"),
        "$.q08_policy.policy_version",
        max_length=128,
    )
    raw_archetypes = policy.get("archetypes")
    if not isinstance(raw_archetypes, dict) or not raw_archetypes:
        raise StrategyCardError("Q08 archetype policy requires a non-empty archetypes object")
    cluster_units: dict[str, str] = {}
    for raw_name, raw_archetype in raw_archetypes.items():
        name = _token(raw_name, "$.q08_policy.archetypes key")
        if not isinstance(raw_archetype, dict):
            raise StrategyCardError(f"Q08 archetype {name!r} must be an object")
        cluster_units[name] = _token(
            raw_archetype.get("cluster_unit"),
            f"$.q08_policy.archetypes.{name}.cluster_unit",
        )
    return ContractBindings(
        strategy_card_schema_sha256=semantic_json_sha256(schema),
        q08_policy_version=policy_version,
        q08_policy_sha256=semantic_json_sha256(policy),
        archetype_cluster_units=cluster_units,
    )


def _exact_keys(value: Any, required: set[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise StrategyCardError(f"{path} must be an object")
    actual = set(value)
    if actual != required:
        raise StrategyCardError(
            f"{path} key set mismatch; "
            f"missing={sorted(required - actual)}, extra={sorted(actual - required)}"
        )
    return value


def _string(value: Any, path: str, *, max_length: int = 8192) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise StrategyCardError(f"{path} must be a non-blank, trimmed string")
    if len(value) > max_length:
        raise StrategyCardError(f"{path} exceeds {max_length} characters")
    return value


def _identifier(value: Any, path: str) -> str:
    candidate = _string(value, path, max_length=128)
    if _IDENTIFIER_RE.fullmatch(candidate) is None:
        raise StrategyCardError(f"{path} is not a canonical identifier")
    return candidate


def _token(value: Any, path: str) -> str:
    if not isinstance(value, str) or _TOKEN_RE.fullmatch(value) is None:
        raise StrategyCardError(f"{path} must be a lower_snake_case token")
    return value


def _sha256(value: Any, path: str) -> str:
    if not isinstance(value, str) or _SHA256_RE.fullmatch(value) is None:
        raise StrategyCardError(f"{path} must be a lowercase SHA-256 hex digest")
    return value


def _integer(
    value: Any,
    path: str,
    *,
    minimum: int = 0,
    maximum: int = 1_000_000,
) -> int:
    if (
        isinstance(value, bool)
        or not isinstance(value, int)
        or value < minimum
        or value > maximum
    ):
        raise StrategyCardError(
            f"{path} must be an integer between {minimum} and {maximum}"
        )
    return value


def _utc(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or _UTC_RE.fullmatch(value) is None:
        raise StrategyCardError(f"{path} must be an RFC3339 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise StrategyCardError(f"{path} is not a real timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise StrategyCardError(f"{path} must be UTC")
    return parsed


def _sorted_unique_strings(value: Any, path: str) -> tuple[str, ...]:
    if not isinstance(value, list) or not value:
        raise StrategyCardError(f"{path} must be a non-empty array")
    strings = tuple(
        _string(item, f"{path}[{index}]") for index, item in enumerate(value)
    )
    if len(strings) != len(set(strings)):
        raise StrategyCardError(f"{path} must not contain duplicates")
    if list(strings) != sorted(strings):
        raise StrategyCardError(f"{path} must use canonical lexical order")
    return strings


def _canonical_decimal(value: Any, path: str) -> str:
    if not isinstance(value, str) or _DECIMAL_RE.fullmatch(value) is None:
        raise StrategyCardError(
            f"{path} must be a canonical fixed-point decimal string"
        )
    try:
        decimal_value = Decimal(value)
    except InvalidOperation as exc:
        raise StrategyCardError(f"{path} is not a valid decimal") from exc
    normalized = format(decimal_value.normalize(), "f")
    if normalized == "-0":
        normalized = "0"
    if value != normalized:
        raise StrategyCardError(
            f"{path} is not canonical; expected decimal string {normalized!r}"
        )
    return value


def _domain_value_key(value: Any, value_type: str, path: str) -> tuple[Any, ...]:
    if value_type == "BOOLEAN":
        if not isinstance(value, bool):
            raise StrategyCardError(f"{path} must be boolean")
        return (int(value),)
    if value_type == "INTEGER":
        if isinstance(value, bool) or not isinstance(value, int):
            raise StrategyCardError(f"{path} must be an integer, not boolean or decimal")
        return (value,)
    if value_type == "DECIMAL":
        canonical = _canonical_decimal(value, path)
        return (Decimal(canonical),)
    if value_type == "ENUM":
        return (_string(value, path, max_length=256),)
    raise StrategyCardError(f"unsupported parameter value_type {value_type!r} at {path}")


def _validate_contract_bindings(
    value: Any,
    expected: ContractBindings,
) -> None:
    bindings = _exact_keys(value, _CONTRACT_BINDING_KEYS, "$.contract_bindings")
    schema_sha = _sha256(
        bindings["strategy_card_schema_sha256"],
        "$.contract_bindings.strategy_card_schema_sha256",
    )
    policy_version = _string(
        bindings["q08_policy_version"],
        "$.contract_bindings.q08_policy_version",
        max_length=128,
    )
    policy_sha = _sha256(
        bindings["q08_policy_sha256"],
        "$.contract_bindings.q08_policy_sha256",
    )
    if not hmac.compare_digest(schema_sha, expected.strategy_card_schema_sha256):
        raise StrategyCardError("Strategy Card schema hash binding mismatch")
    if policy_version != expected.q08_policy_version:
        raise StrategyCardError("Q08 policy version binding mismatch")
    if not hmac.compare_digest(policy_sha, expected.q08_policy_sha256):
        raise StrategyCardError("Q08 policy hash binding mismatch")


def _validate_degrees_of_freedom(value: Any) -> int:
    degrees = _exact_keys(value, _DOF_KEYS, "$.degrees_of_freedom")
    declared = _integer(
        degrees["declared_count"],
        "$.degrees_of_freedom.declared_count",
    )
    raw_components = degrees["components"]
    if not isinstance(raw_components, list) or not raw_components:
        raise StrategyCardError("$.degrees_of_freedom.components must be a non-empty array")
    names: list[str] = []
    total = 0
    for index, raw in enumerate(raw_components):
        path = f"$.degrees_of_freedom.components[{index}]"
        component = _exact_keys(raw, _DOF_COMPONENT_KEYS, path)
        names.append(_token(component["name"], f"{path}.name"))
        total += _integer(component["count"], f"{path}.count")
    if len(names) != len(set(names)):
        raise StrategyCardError("degrees_of_freedom component names must be unique")
    if names != sorted(names):
        raise StrategyCardError("degrees_of_freedom components must use canonical name order")
    if total != declared:
        raise StrategyCardError(
            f"declared degrees_of_freedom {declared} does not equal component sum {total}"
        )
    return declared


def _validate_trial_budget(value: Any) -> tuple[int, int]:
    budget = _exact_keys(value, _TRIAL_BUDGET_KEYS, "$.trial_budget")
    _identifier(budget["budget_id"], "$.trial_budget.budget_id")
    trials = _integer(
        budget["max_independent_trials"],
        "$.trial_budget.max_independent_trials",
        minimum=1,
    )
    cells = _integer(
        budget["max_parameter_cells"],
        "$.trial_budget.max_parameter_cells",
        minimum=1,
    )
    return trials, cells


def _validate_parameter_space(
    value: Any,
    *,
    declared_degrees_of_freedom: int,
    max_independent_trials: int,
    max_parameter_cells: int,
) -> None:
    parameter_space = _exact_keys(value, _PARAMETER_SPACE_KEYS, "$.parameter_space")
    raw_domains = parameter_space["domains"]
    raw_cells = parameter_space["cells"]
    if not isinstance(raw_domains, list) or not raw_domains:
        raise StrategyCardError("$.parameter_space.domains must be a non-empty array")
    if not isinstance(raw_cells, list) or not raw_cells:
        raise StrategyCardError("$.parameter_space.cells must be a non-empty array")

    domains: dict[str, tuple[str, tuple[Any, ...], frozenset[bytes]]] = {}
    domain_names: list[str] = []
    variable_domain_count = 0
    for index, raw in enumerate(raw_domains):
        path = f"$.parameter_space.domains[{index}]"
        domain = _exact_keys(raw, _PARAMETER_DOMAIN_KEYS, path)
        name = _token(domain["name"], f"{path}.name")
        value_type = domain["value_type"]
        if value_type not in _PARAMETER_VALUE_TYPES:
            raise StrategyCardError(f"{path}.value_type is unsupported")
        values = domain["values"]
        if not isinstance(values, list) or not values:
            raise StrategyCardError(f"{path}.values must be a non-empty array")
        sort_keys = [
            _domain_value_key(item, value_type, f"{path}.values[{value_index}]")
            for value_index, item in enumerate(values)
        ]
        if len(sort_keys) != len(set(sort_keys)):
            raise StrategyCardError(f"{path}.values must not contain duplicates")
        if sort_keys != sorted(sort_keys):
            raise StrategyCardError(f"{path}.values must use canonical value order")
        if name in domains:
            raise StrategyCardError(f"duplicate parameter domain {name!r}")
        encoded_values = frozenset(canonical_json_bytes(item) for item in values)
        domains[name] = (value_type, tuple(values), encoded_values)
        domain_names.append(name)
        if len(values) > 1:
            variable_domain_count += 1

    if domain_names != sorted(domain_names):
        raise StrategyCardError("parameter domains must use canonical name order")
    if declared_degrees_of_freedom < variable_domain_count:
        raise StrategyCardError(
            "declared degrees_of_freedom is smaller than the variable parameter-domain count"
        )

    cell_ids: list[str] = []
    assignment_hashes: set[str] = set()
    expected_names = set(domains)
    for index, raw in enumerate(raw_cells):
        path = f"$.parameter_space.cells[{index}]"
        cell = _exact_keys(raw, _PARAMETER_CELL_KEYS, path)
        cell_id = _identifier(cell["cell_id"], f"{path}.cell_id")
        assignments = _exact_keys(cell["assignments"], expected_names, f"{path}.assignments")
        for name, assigned in assignments.items():
            value_type, _, allowed = domains[name]
            _domain_value_key(assigned, value_type, f"{path}.assignments.{name}")
            if canonical_json_bytes(assigned) not in allowed:
                raise StrategyCardError(
                    f"{path}.assignments.{name} is outside its declared domain"
                )
        supplied_hash = _sha256(cell["cell_sha256"], f"{path}.cell_sha256")
        expected_hash = semantic_json_sha256(
            {"cell_id": cell_id, "assignments": assignments}
        )
        if not hmac.compare_digest(supplied_hash, expected_hash):
            raise StrategyCardError(f"{path}.cell_sha256 mismatch")
        assignment_hash = semantic_json_sha256(assignments)
        if assignment_hash in assignment_hashes:
            raise StrategyCardError("parameter cells must not duplicate assignments")
        assignment_hashes.add(assignment_hash)
        cell_ids.append(cell_id)

    if len(cell_ids) != len(set(cell_ids)):
        raise StrategyCardError("parameter cell IDs must be unique")
    if cell_ids != sorted(cell_ids):
        raise StrategyCardError("parameter cells must use canonical cell_id order")
    if len(raw_cells) > max_parameter_cells:
        raise StrategyCardError("declared parameter cells exceed max_parameter_cells")
    if len(raw_cells) > max_independent_trials:
        raise StrategyCardError("declared parameter cells exceed max_independent_trials")


def _validate_data_cut(value: Any) -> datetime:
    cut = _exact_keys(value, _DATA_CUT_KEYS, "$.data_cut")
    _identifier(cut["cut_id"], "$.data_cut.cut_id")
    _sha256(cut["dataset_sha256"], "$.data_cut.dataset_sha256")
    return _utc(cut["cut_at_utc"], "$.data_cut.cut_at_utc")


def _validate_data_seal(value: Any, path: str) -> tuple[datetime, datetime, datetime]:
    seal = _exact_keys(value, _DATA_SEAL_KEYS, path)
    _identifier(seal["seal_id"], f"{path}.seal_id")
    _sha256(seal["partition_sha256"], f"{path}.partition_sha256")
    start = _utc(seal["range_start_utc"], f"{path}.range_start_utc")
    end = _utc(seal["range_end_utc"], f"{path}.range_end_utc")
    sealed = _utc(seal["sealed_at_utc"], f"{path}.sealed_at_utc")
    if start >= end:
        raise StrategyCardError(f"{path} range_start_utc must precede range_end_utc")
    if sealed < end:
        raise StrategyCardError(f"{path} cannot be sealed before its range_end_utc")
    return start, end, sealed


def _validate_execution_dependencies(value: Any) -> None:
    if not isinstance(value, list) or not value:
        raise StrategyCardError("$.execution_dependencies must be a non-empty array")
    dependency_ids: list[str] = []
    for index, raw in enumerate(value):
        path = f"$.execution_dependencies[{index}]"
        dependency = _exact_keys(raw, _DEPENDENCY_KEYS, path)
        dependency_ids.append(
            _identifier(dependency["dependency_id"], f"{path}.dependency_id")
        )
        if dependency["kind"] not in _DEPENDENCY_KINDS:
            raise StrategyCardError(f"{path}.kind is unsupported")
        _string(dependency["version"], f"{path}.version", max_length=128)
        _sha256(dependency["sha256"], f"{path}.sha256")
    if len(dependency_ids) != len(set(dependency_ids)):
        raise StrategyCardError("execution dependency IDs must be unique")
    if dependency_ids != sorted(dependency_ids):
        raise StrategyCardError(
            "execution dependencies must use canonical dependency_id order"
        )


def _validate_author(value: Any) -> datetime:
    author = _exact_keys(value, _AUTHOR_KEYS, "$.author")
    if author["authority"] not in {"AGENT", "OWNER"}:
        raise StrategyCardError("$.author.authority must be AGENT or OWNER")
    _string(author["identity"], "$.author.identity", max_length=128)
    return _utc(author["authored_at_utc"], "$.author.authored_at_utc")


def validate_card(
    card: Mapping[str, Any],
    *,
    schema_path: Path | str = DEFAULT_SCHEMA_PATH,
    q08_policy_path: Path | str = DEFAULT_Q08_POLICY_PATH,
) -> None:
    """Validate one sealed card, including all hash and policy bindings."""

    if not isinstance(card, Mapping):
        raise StrategyCardError("card root must be an object")
    candidate = copy.deepcopy(dict(card))
    _validate_json_value(candidate)
    _exact_keys(candidate, _TOP_LEVEL_KEYS, "$")
    if candidate["schema_version"] != CARD_SCHEMA_VERSION:
        raise StrategyCardError("unsupported Strategy Card schema_version")
    _identifier(candidate["card_id"], "$.card_id")
    _integer(candidate["card_version"], "$.card_version", minimum=1)
    _identifier(candidate["source_authorization_id"], "$.source_authorization_id")
    _sha256(candidate["source_sha256"], "$.source_sha256")

    expected_bindings = load_contract_bindings(
        schema_path=schema_path,
        q08_policy_path=q08_policy_path,
    )
    _validate_contract_bindings(candidate["contract_bindings"], expected_bindings)

    _string(candidate["mechanism"], "$.mechanism")
    _string(candidate["falsifiable_prediction"], "$.falsifiable_prediction")
    _string(candidate["falsifier"], "$.falsifier")
    _sorted_unique_strings(candidate["kill_criteria"], "$.kill_criteria")
    _sorted_unique_strings(candidate["assumptions"], "$.assumptions")

    archetype = _token(candidate["primary_archetype"], "$.primary_archetype")
    cluster_unit = _token(
        candidate["independent_cluster_unit"],
        "$.independent_cluster_unit",
    )
    expected_cluster_unit = expected_bindings.archetype_cluster_units.get(archetype)
    if expected_cluster_unit is None:
        raise StrategyCardError(
            "primary_archetype must be a canonical archetype in the bound Q08 policy"
        )
    if cluster_unit != expected_cluster_unit:
        raise StrategyCardError(
            f"independent_cluster_unit {cluster_unit!r} does not match Q08 policy "
            f"value {expected_cluster_unit!r} for {archetype!r}"
        )

    declared_dof = _validate_degrees_of_freedom(candidate["degrees_of_freedom"])
    max_trials, max_cells = _validate_trial_budget(candidate["trial_budget"])
    _validate_parameter_space(
        candidate["parameter_space"],
        declared_degrees_of_freedom=declared_dof,
        max_independent_trials=max_trials,
        max_parameter_cells=max_cells,
    )

    symbol = candidate["symbol"]
    if not isinstance(symbol, str) or _SYMBOL_RE.fullmatch(symbol) is None:
        raise StrategyCardError("$.symbol must use canonical uppercase symbol form")
    timeframe = candidate["timeframe"]
    if not isinstance(timeframe, str) or _TIMEFRAME_RE.fullmatch(timeframe) is None:
        raise StrategyCardError("$.timeframe is not a canonical timeframe")

    cut_at = _validate_data_cut(candidate["data_cut"])
    dev_start, dev_end, dev_sealed_at = _validate_data_seal(
        candidate["dev_seal"], "$.dev_seal"
    )
    oos_start, oos_end, oos_sealed_at = _validate_data_seal(
        candidate["oos_seal"], "$.oos_seal"
    )
    if dev_end > oos_start:
        raise StrategyCardError("DEV and OOS ranges overlap or are out of order")
    if oos_end > cut_at:
        raise StrategyCardError("OOS range exceeds the bound data cut")
    if dev_start >= oos_end:
        raise StrategyCardError("DEV/OOS range chronology is invalid")

    _sorted_unique_strings(
        candidate["execution_assumptions"],
        "$.execution_assumptions",
    )
    _validate_execution_dependencies(candidate["execution_dependencies"])
    authored_at = _validate_author(candidate["author"])
    if dev_sealed_at > authored_at or oos_sealed_at > authored_at:
        raise StrategyCardError("DEV/OOS seals cannot postdate card authorship")

    supplied_hash = _sha256(candidate["card_sha256"], "$.card_sha256")
    expected_hash = canonical_card_hash(candidate)
    if not hmac.compare_digest(supplied_hash, expected_hash):
        raise StrategyCardError(
            f"card_sha256 mismatch: supplied={supplied_hash}, expected={expected_hash}"
        )


def _sort_string_array(value: Any, path: str) -> list[str]:
    if not isinstance(value, list) or not value:
        raise StrategyCardError(f"{path} must be a non-empty array")
    validated = [
        _string(item, f"{path}[{index}]") for index, item in enumerate(value)
    ]
    if len(validated) != len(set(validated)):
        raise StrategyCardError(f"{path} must not contain duplicates")
    return sorted(validated)


def build_card(
    draft: Mapping[str, Any],
    *,
    schema_path: Path | str = DEFAULT_SCHEMA_PATH,
    q08_policy_path: Path | str = DEFAULT_Q08_POLICY_PATH,
) -> dict[str, Any]:
    """Build and seal a deterministic card from an exact hashless draft.

    ``contract_bindings``, per-cell hashes and ``card_sha256`` are derived, not
    accepted as author claims.  Lists whose order has no semantic meaning are
    canonicalized before hashing.
    """

    if not isinstance(draft, Mapping):
        raise StrategyCardError("card draft root must be an object")
    card = copy.deepcopy(dict(draft))
    _validate_json_value(card)
    _exact_keys(card, _DRAFT_KEYS, "$")

    for field in ("kill_criteria", "assumptions", "execution_assumptions"):
        card[field] = _sort_string_array(card[field], f"$.{field}")

    degrees = _exact_keys(card["degrees_of_freedom"], _DOF_KEYS, "$.degrees_of_freedom")
    components = degrees["components"]
    if not isinstance(components, list) or not components:
        raise StrategyCardError("$.degrees_of_freedom.components must be a non-empty array")
    for index, component in enumerate(components):
        _exact_keys(
            component,
            _DOF_COMPONENT_KEYS,
            f"$.degrees_of_freedom.components[{index}]",
        )
        _token(
            component["name"],
            f"$.degrees_of_freedom.components[{index}].name",
        )
    degrees["components"] = sorted(components, key=lambda item: item["name"])

    parameter_space = _exact_keys(
        card["parameter_space"],
        _PARAMETER_SPACE_KEYS,
        "$.parameter_space",
    )
    domains = parameter_space["domains"]
    if not isinstance(domains, list) or not domains:
        raise StrategyCardError("$.parameter_space.domains must be a non-empty array")
    for index, domain in enumerate(domains):
        path = f"$.parameter_space.domains[{index}]"
        _exact_keys(domain, _PARAMETER_DOMAIN_KEYS, path)
        _token(domain["name"], f"{path}.name")
        value_type = domain["value_type"]
        if value_type not in _PARAMETER_VALUE_TYPES:
            raise StrategyCardError(f"{path}.value_type is unsupported")
        values = domain["values"]
        if not isinstance(values, list) or not values:
            raise StrategyCardError(f"{path}.values must be a non-empty array")
        for value_index, item in enumerate(values):
            _domain_value_key(item, value_type, f"{path}.values[{value_index}]")
        domain["values"] = sorted(
            values,
            key=lambda item, kind=value_type: _domain_value_key(
                item, kind, f"{path}.values"
            ),
        )
    parameter_space["domains"] = sorted(domains, key=lambda item: item["name"])

    cells = parameter_space["cells"]
    if not isinstance(cells, list) or not cells:
        raise StrategyCardError("$.parameter_space.cells must be a non-empty array")
    sealed_cells: list[dict[str, Any]] = []
    for index, raw_cell in enumerate(cells):
        path = f"$.parameter_space.cells[{index}]"
        cell = _exact_keys(raw_cell, _PARAMETER_CELL_DRAFT_KEYS, path)
        cell_id = _identifier(cell["cell_id"], f"{path}.cell_id")
        if not isinstance(cell["assignments"], dict):
            raise StrategyCardError(f"{path}.assignments must be an object")
        sealed_cell = copy.deepcopy(cell)
        sealed_cell["cell_sha256"] = semantic_json_sha256(
            {"cell_id": cell_id, "assignments": sealed_cell["assignments"]}
        )
        sealed_cells.append(sealed_cell)
    parameter_space["cells"] = sorted(sealed_cells, key=lambda item: item["cell_id"])

    dependencies = card["execution_dependencies"]
    if not isinstance(dependencies, list) or not dependencies:
        raise StrategyCardError("$.execution_dependencies must be a non-empty array")
    for index, dependency in enumerate(dependencies):
        path = f"$.execution_dependencies[{index}]"
        _exact_keys(dependency, _DEPENDENCY_KEYS, path)
        _identifier(dependency["dependency_id"], f"{path}.dependency_id")
    card["execution_dependencies"] = sorted(
        dependencies,
        key=lambda item: item["dependency_id"],
    )

    bindings = load_contract_bindings(
        schema_path=schema_path,
        q08_policy_path=q08_policy_path,
    )
    card["contract_bindings"] = bindings.as_dict()
    card["card_sha256"] = canonical_card_hash(card)
    validate_card(
        card,
        schema_path=schema_path,
        q08_policy_path=q08_policy_path,
    )
    return card


def load_card(
    path: Path | str,
    *,
    schema_path: Path | str = DEFAULT_SCHEMA_PATH,
    q08_policy_path: Path | str = DEFAULT_Q08_POLICY_PATH,
    require_canonical_bytes: bool = True,
) -> dict[str, Any]:
    source = Path(path)
    card, raw = _load_json_object(source, label="Strategy Card")
    validate_card(
        card,
        schema_path=schema_path,
        q08_policy_path=q08_policy_path,
    )
    if require_canonical_bytes and raw != canonical_json_bytes(card, file_form=True):
        raise StrategyCardError("Strategy Card file is not canonical UTF-8 JSON")
    return card


def write_new_card(
    path: Path | str,
    draft_or_card: Mapping[str, Any],
    *,
    schema_path: Path | str = DEFAULT_SCHEMA_PATH,
    q08_policy_path: Path | str = DEFAULT_Q08_POLICY_PATH,
) -> CardWriteReceipt:
    """Exclusively create one card; existing paths are never overwritten."""

    destination = Path(path)
    if not destination.parent.is_dir():
        raise StrategyCardError(
            f"Strategy Card parent directory does not exist: {destination.parent}"
        )
    if not isinstance(draft_or_card, Mapping):
        raise StrategyCardError("card root must be an object")
    if "card_sha256" in draft_or_card:
        card = copy.deepcopy(dict(draft_or_card))
        validate_card(
            card,
            schema_path=schema_path,
            q08_policy_path=q08_policy_path,
        )
    else:
        card = build_card(
            draft_or_card,
            schema_path=schema_path,
            q08_policy_path=q08_policy_path,
        )
    raw = canonical_json_bytes(card, file_form=True)

    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    try:
        descriptor = os.open(destination, flags, 0o600)
    except FileExistsError as exc:
        raise StrategyCardError(
            f"refusing to overwrite existing Strategy Card: {destination}"
        ) from exc
    try:
        with os.fdopen(descriptor, "wb") as stream:
            descriptor = -1
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        if descriptor >= 0:
            os.close(descriptor)

    # A post-create write/fsync failure deliberately leaves the exclusively
    # claimed path in place. Removing it by pathname after closing the handle
    # could delete a concurrent replacement; retaining it is the fail-closed
    # create-new outcome and requires explicit inspection before retry.

    return CardWriteReceipt(
        path=destination,
        card_id=card["card_id"],
        card_version=card["card_version"],
        card_sha256=card["card_sha256"],
        size_bytes=len(raw),
    )
