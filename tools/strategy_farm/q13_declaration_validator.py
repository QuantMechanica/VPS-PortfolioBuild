"""Fail-closed validator for OWNER-sealed Q13 Option M declarations.

This module validates declarations only.  It does not enqueue cells, mutate the
trial ledger, or alter the existing ``NO_PARAMETER_CHANGE`` path.  Admission is
separately guarded by ``QM_ENABLE_Q13_OPTION_M_DECLARATIONS`` (default OFF).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    Path(__file__).resolve().parent
    / "config"
    / "q13_budget_contract_option_m.v1.json"
)
EXPECTED_CONTRACT_SHA256 = (
    "1b38b18eac1995de63460286035c06612357ed1c18d7c1383096b27554060f1b"
)
DECLARATION_SCHEMA = "qm.q13-parameter-declaration/v1"
ACTIVATION_ENV = "QM_ENABLE_Q13_OPTION_M_DECLARATIONS"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_TRUE = frozenset({"1", "true", "yes", "on"})


class ContractError(RuntimeError):
    """The sealed machine contract or one of its pinned authorities drifted."""


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    code: str
    errors: tuple[str, ...] = field(default_factory=tuple)
    contract_sha256: str = EXPECTED_CONTRACT_SHA256
    declared_trial_increment: Optional[int] = None
    physical_q13_cells: Optional[int] = None
    terminal_hours: Optional[float] = None
    activation_enabled: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "code": self.code,
            "errors": list(self.errors),
            "contract_sha256": self.contract_sha256,
            "declared_trial_increment": self.declared_trial_increment,
            "physical_q13_cells": self.physical_q13_cells,
            "terminal_hours": self.terminal_hours,
            "activation_env": ACTIVATION_ENV,
            "activation_enabled": self.activation_enabled,
        }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    """Load and authenticate the Option M contract and its source authorities."""
    path = Path(path)
    if not path.is_file():
        raise ContractError(f"sealed contract missing: {path}")
    actual = _sha256(path)
    if actual != EXPECTED_CONTRACT_SHA256:
        raise ContractError(
            "sealed contract sha256 mismatch: "
            f"expected={EXPECTED_CONTRACT_SHA256} actual={actual}"
        )
    try:
        contract = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"sealed contract unreadable: {exc}") from exc
    if not isinstance(contract, dict):
        raise ContractError("sealed contract root must be an object")
    if contract.get("schema") != "qm.q13-budget-contract/v1":
        raise ContractError("sealed contract schema mismatch")
    if contract.get("status") != "SEALED_NOT_ACTIVE":
        raise ContractError("sealed contract status mismatch")

    for authority_key in ("owner_decision", "draft_source", "parent_contract"):
        authority = contract.get(authority_key)
        if not isinstance(authority, dict):
            raise ContractError(f"sealed authority missing: {authority_key}")
        relative = authority.get("path")
        expected = str(authority.get("sha256") or "").lower()
        if not isinstance(relative, str) or not _SHA256_RE.fullmatch(expected):
            raise ContractError(f"sealed authority malformed: {authority_key}")
        authority_path = (REPO_ROOT / relative).resolve()
        try:
            authority_path.relative_to(REPO_ROOT.resolve())
        except ValueError as exc:
            raise ContractError(
                f"sealed authority escapes repository: {authority_key}"
            ) from exc
        if not authority_path.is_file():
            raise ContractError(f"sealed authority missing: {authority_path}")
        actual_authority = _sha256(authority_path)
        if actual_authority != expected:
            raise ContractError(
                f"sealed authority drift: {authority_key} "
                f"expected={expected} actual={actual_authority}"
            )
    return contract


def declarations_enabled(env: Optional[Mapping[str, str]] = None) -> bool:
    env = os.environ if env is None else env
    return str(env.get(ACTIVATION_ENV, "")).strip().lower() in _TRUE


def canonical_declaration_sha256(declaration: Mapping[str, Any]) -> str:
    payload = dict(declaration)
    payload.pop("declaration_sha256", None)
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _as_finite_decimal(value: Any) -> Optional[Decimal]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if isinstance(value, float) and not math.isfinite(value):
        return None
    try:
        number = Decimal(str(value))
    except InvalidOperation:
        return None
    return number if number.is_finite() else None


def _nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _numeric_key(value: Any) -> Optional[str]:
    number = _as_finite_decimal(value)
    if number is None:
        return None
    return str(number.normalize())


def _validate_fixed_declaration_rules(
    declaration: Mapping[str, Any],
    contract: Mapping[str, Any],
    errors: list[str],
) -> None:
    fixed = contract["fixed_rules"]
    if declaration.get("one_parameter_per_cell") is not True:
        errors.append("one_parameter_per_cell must be true")
    if declaration.get("selection_years") != contract["limits"]["selection_years"]:
        errors.append("selection_years must equal sealed 2019..2025 window")
    if declaration.get("objective") != fixed["objective"]:
        errors.append("objective must equal return_to_maxdd")

    expected_frequency = {
        "entry_trading_days_floor": fixed["entry_trading_days_floor"],
        "per_scored_year": True,
        "partial_year_pro_rata": fixed["partial_year_pro_rata"],
        "evaluated_before_performance_selection": True,
    }
    if declaration.get("activity_floor") != expected_frequency:
        errors.append("activity_floor does not match sealed frequency rule")

    expected_consistency = {
        "min_year_fraction": fixed["consistency_min_year_fraction"],
        "min_relative_improvement_pct": fixed[
            "consistency_min_relative_improvement_pct"
        ],
        "no_frequency_break": True,
        "plateau_median_selection": True,
    }
    if declaration.get("consistency_rule") != expected_consistency:
        errors.append("consistency_rule does not match sealed rule")


def validate_declaration(
    declaration: Any,
    *,
    env: Optional[Mapping[str, str]] = None,
) -> ValidationResult:
    """Validate one declaration without mutating or admitting any Q13 work."""
    enabled = declarations_enabled(env)
    try:
        sealed = load_contract()
    except ContractError as exc:
        return ValidationResult(
            valid=False,
            code="CONTRACT_AUTHENTICATION_FAILED",
            errors=(str(exc),),
            activation_enabled=enabled,
        )
    if not isinstance(declaration, Mapping):
        return ValidationResult(
            valid=False,
            code="DECLARATION_INVALID",
            errors=("declaration root must be an object",),
            activation_enabled=enabled,
        )

    errors: list[str] = []
    required = sealed["required_top_level_fields"]
    for field_name in required:
        if field_name not in declaration:
            errors.append(f"missing required field: {field_name}")

    expected_literals = {
        "schema": DECLARATION_SCHEMA,
        "contract_id": sealed["contract_id"],
        "gate_contract_version": sealed["gate_contract_version"],
        "budget_option": sealed["budget_option"],
        "owner_decision_id": sealed["owner_decision"]["decision_id"],
    }
    for field_name, expected in expected_literals.items():
        if declaration.get(field_name) != expected:
            errors.append(f"{field_name} must equal sealed value {expected!r}")
    for field_name in ("ea_id", "symbol", "timeframe"):
        if not _nonempty_text(declaration.get(field_name)):
            errors.append(f"{field_name} must be non-empty text")

    bindings = declaration.get("bindings")
    if not isinstance(bindings, Mapping):
        errors.append("bindings must be an object")
    else:
        for field_name in sealed["required_binding_fields"]:
            value = bindings.get(field_name)
            if field_name.endswith("_sha256"):
                if not isinstance(value, str) or not _SHA256_RE.fullmatch(
                    value.lower()
                ):
                    errors.append(f"bindings.{field_name} must be sha256")
            elif not _nonempty_text(value):
                errors.append(f"bindings.{field_name} must be non-empty text")

    hashes = declaration.get("hashes")
    if not isinstance(hashes, Mapping):
        errors.append("hashes must be an object")
    else:
        for field_name in sealed["required_hash_fields"]:
            value = hashes.get(field_name)
            if not isinstance(value, str) or not _SHA256_RE.fullmatch(value.lower()):
                errors.append(f"hashes.{field_name} must be sha256")
    freeze_hash = declaration.get("q12_filter_freeze_sha256")
    if not isinstance(freeze_hash, str) or not _SHA256_RE.fullmatch(
        freeze_hash.lower()
    ):
        errors.append("q12_filter_freeze_sha256 must be sha256")

    _validate_fixed_declaration_rules(declaration, sealed, errors)

    parameter_count = declaration.get("parameter_count")
    parameters = declaration.get("parameters")
    if not _is_int(parameter_count) or parameter_count < 0:
        errors.append("parameter_count must be a non-negative integer")
        parameter_count = None
    if not isinstance(parameters, list):
        errors.append("parameters must be an array")
        parameters = []
    if parameter_count is not None and parameter_count != len(parameters):
        errors.append("parameter_count must equal len(parameters)")

    limits = sealed["limits"]
    if parameter_count is not None and parameter_count > limits["max_parameter_count"]:
        errors.append("BUDGET_CONTRACT_EXCEEDED: parameter_count")

    input_names: set[str] = set()
    candidate_count = 0
    trial_increment = 0
    expected_frequency = declaration.get("activity_floor")
    for index, parameter in enumerate(parameters):
        prefix = f"parameters[{index}]"
        if not isinstance(parameter, Mapping):
            errors.append(f"{prefix} must be an object")
            continue
        for field_name in sealed["required_parameter_fields"]:
            if field_name not in parameter:
                errors.append(f"missing required field: {prefix}.{field_name}")

        input_name = parameter.get("input_name")
        if not _nonempty_text(input_name):
            errors.append(f"{prefix}.input_name must be non-empty text")
        elif input_name in input_names:
            errors.append(f"duplicate parameter input_name: {input_name}")
        else:
            input_names.add(input_name)

        input_type = parameter.get("input_type")
        if input_type not in {"int", "float", "double"}:
            errors.append(f"{prefix}.input_type must be int, float, or double")
        parent_key = _numeric_key(parameter.get("parent_value"))
        if parent_key is None:
            errors.append(f"{prefix}.parent_value must be a finite number")

        values = parameter.get("candidate_values")
        if not isinstance(values, list) or not values:
            errors.append(f"{prefix}.candidate_values must be a non-empty array")
            values = []
        if len(values) > limits["max_values_per_parameter_including_parent"]:
            errors.append(f"BUDGET_CONTRACT_EXCEEDED: {prefix}.candidate_values")
        value_keys = [_numeric_key(value) for value in values]
        if any(key is None for key in value_keys):
            errors.append(f"{prefix}.candidate_values must contain finite numbers")
        clean_keys = [key for key in value_keys if key is not None]
        if len(clean_keys) != len(set(clean_keys)):
            errors.append(f"{prefix}.candidate_values must be distinct")
        if parent_key is not None and parent_key not in clean_keys:
            errors.append(f"{prefix}.candidate_values must include parent_value")
        if input_type == "int" and any(
            not _is_int(value) for value in values + [parameter.get("parent_value")]
        ):
            errors.append(f"{prefix} int values must be integers")

        bounds = parameter.get("technical_bounds")
        if not isinstance(bounds, Mapping):
            errors.append(f"{prefix}.technical_bounds must be an object")
        else:
            low = _as_finite_decimal(bounds.get("minimum"))
            high = _as_finite_decimal(bounds.get("maximum"))
            if low is None or high is None or low > high:
                errors.append(f"{prefix}.technical_bounds must have valid min/max")
            else:
                for value in values + [parameter.get("parent_value")]:
                    number = _as_finite_decimal(value)
                    if number is not None and not low <= number <= high:
                        errors.append(f"{prefix} value outside technical_bounds")
                        break

        interactions = parameter.get("interaction_constraints")
        if not isinstance(interactions, (list, str)):
            errors.append(f"{prefix}.interaction_constraints must be list or text")
        for field_name in ("hypothesis", "expected_effect", "refutation_criterion"):
            if not _nonempty_text(parameter.get(field_name)):
                errors.append(f"{prefix}.{field_name} must be non-empty text")
        if parameter.get("frequency_check") != expected_frequency:
            errors.append(f"{prefix}.frequency_check must match activity_floor")

        candidate_count += len(values)
        trial_increment += max(0, len(values) - 1)

    if parameter_count == 0:
        expected_cells = 0
        expected_hours = Decimal("0")
    else:
        expected_cells = 7 * (1 + candidate_count) + 2
        expected_hours = (
            Decimal(expected_cells) * Decimal(str(limits["minutes_per_cell"]))
            / Decimal(60)
        ).quantize(Decimal("0.01"))

    if trial_increment > limits["max_lineage_trial_increment"]:
        errors.append("BUDGET_CONTRACT_EXCEEDED: declared_trial_increment")
    if expected_cells > limits["max_physical_q13_cells"]:
        errors.append("BUDGET_CONTRACT_EXCEEDED: physical_q13_cells")
    if expected_hours > Decimal(str(limits["max_terminal_hours_per_pair"])):
        errors.append("BUDGET_CONTRACT_EXCEEDED: terminal_hours")

    ledger_fields = (
        "declared_trial_count_before",
        "declared_trial_increment",
        "declared_trial_count_effective_after",
        "q13_lineage_trial_increment_before",
        "q13_lineage_trial_increment_effective_after",
    )
    ledger: dict[str, Optional[int]] = {}
    for field_name in ledger_fields:
        value = declaration.get(field_name)
        if not _is_int(value) or value < 0:
            errors.append(f"{field_name} must be a non-negative integer")
            ledger[field_name] = None
        else:
            ledger[field_name] = value
    if ledger["declared_trial_increment"] != trial_increment:
        errors.append("declared_trial_increment does not match candidate grid")
    before = ledger["declared_trial_count_before"]
    after = ledger["declared_trial_count_effective_after"]
    if before is not None and after is not None and after != before + trial_increment:
        errors.append("declared trial ledger arithmetic mismatch")
    lineage_before = ledger["q13_lineage_trial_increment_before"]
    lineage_after = ledger["q13_lineage_trial_increment_effective_after"]
    if (
        lineage_before is not None
        and lineage_after is not None
        and lineage_after != lineage_before + trial_increment
    ):
        errors.append("Q13 lineage trial ledger arithmetic mismatch")
    if (
        lineage_after is not None
        and lineage_after > limits["max_lineage_trial_increment"]
    ):
        errors.append("BUDGET_CONTRACT_EXCEEDED: Q13 lineage trial ledger")

    if declaration.get("physical_q13_cells") != expected_cells:
        errors.append("physical_q13_cells does not match sealed formula")
    terminal_hours = _as_finite_decimal(declaration.get("terminal_hours"))
    if terminal_hours is None or terminal_hours != expected_hours:
        errors.append("terminal_hours does not match sealed formula")

    declared_hash = declaration.get("declaration_sha256")
    if not isinstance(declared_hash, str) or not _SHA256_RE.fullmatch(
        declared_hash.lower()
    ):
        errors.append("declaration_sha256 must be sha256")
    else:
        try:
            calculated_hash = canonical_declaration_sha256(declaration)
        except (TypeError, ValueError):
            errors.append("declaration is not canonically serializable")
        else:
            if declared_hash.lower() != calculated_hash:
                errors.append("declaration_sha256 mismatch")

    return ValidationResult(
        valid=not errors,
        code="VALID_OPTION_M_DECLARATION" if not errors else "DECLARATION_INVALID",
        errors=tuple(errors),
        declared_trial_increment=trial_increment,
        physical_q13_cells=expected_cells,
        terminal_hours=float(expected_hours),
        activation_enabled=enabled,
    )


def admission_decision(
    declaration: Any,
    *,
    env: Optional[Mapping[str, str]] = None,
) -> ValidationResult:
    """Validate, then enforce the separate default-OFF admission flag."""
    result = validate_declaration(declaration, env=env)
    if not result.valid:
        return result
    if not result.activation_enabled:
        return ValidationResult(
            valid=False,
            code="Q13_DECLARATIONS_DISABLED",
            errors=(f"{ACTIVATION_ENV} is not enabled",),
            declared_trial_increment=result.declared_trial_increment,
            physical_q13_cells=result.physical_q13_cells,
            terminal_hours=result.terminal_hours,
            activation_enabled=False,
        )
    return result


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate a sealed Q13 Option M declaration; never enqueue work."
    )
    parser.add_argument("declaration", type=Path)
    parser.add_argument(
        "--require-enabled",
        action="store_true",
        help=f"Also require {ACTIVATION_ENV}=1 (default OFF).",
    )
    args = parser.parse_args(argv)
    try:
        declaration = json.loads(args.declaration.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(
            json.dumps(
                {
                    "valid": False,
                    "code": "DECLARATION_UNREADABLE",
                    "errors": [str(exc)],
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    result = (
        admission_decision(declaration)
        if args.require_enabled
        else validate_declaration(declaration)
    )
    print(json.dumps(result.to_dict(), indent=2, sort_keys=True))
    return 0 if result.valid else 2


if __name__ == "__main__":
    sys.exit(main())
