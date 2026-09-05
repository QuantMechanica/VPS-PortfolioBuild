"""Strict loader for the versioned FTMO probability/correlation contract."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping

from tools.strategy_farm import target_rulepacks


DEFAULT_CONTRACT_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "ftmo_probability_contract.v1.json"
)
DEFAULT_RULEPACK_PATH = (
    Path(__file__).resolve().parents[1]
    / "config" / "target_rulepacks" / "FTMO_2S_100K_SWING_V2.json"
)


class FtmoProbabilityContractError(ValueError):
    pass


@dataclass(frozen=True)
class FtmoProbabilityContract:
    path: Path
    sha256: str
    raw_sha256: str
    payload: Mapping[str, Any]

    @property
    def probability(self) -> Mapping[str, Any]:
        return self.payload["probability"]

    @property
    def correlation(self) -> Mapping[str, Any]:
        return self.payload["correlation"]

    @property
    def tail(self) -> Mapping[str, Any]:
        return self.payload["tail"]


def _reject_constant(token: str) -> None:
    raise FtmoProbabilityContractError(f"non-finite JSON constant: {token}")


def _lf_normalize(raw: bytes) -> bytes:
    """Return a checkout-portable byte representation without altering content."""
    return raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def _no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise FtmoProbabilityContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _percent_fraction(value: Any, label: str) -> Decimal:
    if not isinstance(value, str):
        raise FtmoProbabilityContractError(f"{label} must remain a decimal percent string")
    return Decimal(value) * Decimal("0.01")


def _criteria(rulepack: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    profile = rulepack.get("evaluation_profile")
    if not isinstance(profile, Mapping):
        raise FtmoProbabilityContractError("rulepack evaluation_profile missing")
    rows = profile.get("go_criteria")
    if not isinstance(rows, list):
        raise FtmoProbabilityContractError("rulepack go_criteria missing")
    return {str(row["criterion_id"]): row["parameters"] for row in rows}


def _expect_fraction(actual: Any, expected: Decimal, label: str) -> None:
    try:
        observed = Decimal(str(actual))
    except Exception as exc:
        raise FtmoProbabilityContractError(f"{label} must be numeric") from exc
    if observed != expected:
        raise FtmoProbabilityContractError(f"{label} parity mismatch: {observed} != {expected}")


def load_probability_contract(
    path: Path | str = DEFAULT_CONTRACT_PATH,
    *,
    rulepack_path: Path | str = DEFAULT_RULEPACK_PATH,
) -> FtmoProbabilityContract:
    contract_path = Path(path).resolve()
    raw = contract_path.read_bytes()
    try:
        payload = json.loads(
            raw.decode("utf-8-sig"), object_pairs_hook=_no_duplicates,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise FtmoProbabilityContractError(f"invalid contract JSON: {exc}") from exc
    if not isinstance(payload, Mapping):
        raise FtmoProbabilityContractError("contract root must be an object")
    required = {
        "schema", "status", "class", "auffangregel", "supersedes", "binds_vorlage",
        "construction_rule", "probability", "correlation", "tail", "change_control",
        "open_owner_choices",
    }
    if set(payload) != required:
        raise FtmoProbabilityContractError("contract root fields differ from v1 schema")
    if payload["schema"] != "qm.ftmo-probability-correlation-contract/v1":
        raise FtmoProbabilityContractError("unsupported probability contract schema")
    if payload["class"] != "ROT" or payload["auffangregel"] is not False:
        raise FtmoProbabilityContractError("v1 must remain ROT with no fallback")

    probability = payload["probability"]
    correlation = payload["correlation"]
    tail = payload["tail"]
    if not all(isinstance(item, Mapping) for item in (probability, correlation, tail)):
        raise FtmoProbabilityContractError("contract sections must be objects")
    gates = probability["gates"]
    for gate in ("breach", "two_phase"):
        if gates[gate]["enforcement_status"] != "INERT_UNTIL_C6_ENGINE_OWNER_APPROVED":
            raise FtmoProbabilityContractError(f"{gate} must remain INERT pending C-6")
    if Decimal(str(gates["p1_pass"]["lower_95_min"])) != Decimal("0.80"):
        raise FtmoProbabilityContractError("binding P1 lower bound must be 0.80")
    if probability["dsr_correction"]["fleet_default_trial_count_N"] != 369:
        raise FtmoProbabilityContractError("DSR fleet N must be 369, not census 154")

    pack = target_rulepacks.load_rulepack_path(rulepack_path).as_dict()
    criteria = _criteria(pack)
    p1 = criteria["ftmo_phase1_probability_gate"]
    breach = criteria["ftmo_breach_probability_gate"]
    two_phase = criteria["ftmo_two_phase_probability_gate"]
    fresh = criteria["ftmo_rule_snapshot_fresh"]
    shadow = criteria["ftmo_free_trial_gate"]
    _expect_fraction(gates["p1_pass"]["point_min"], _percent_fraction(p1["point_estimate_min_percent"], "rulepack p1 point"), "p1 point")
    proposed_lower = _percent_fraction(p1["lower_95_percent_bound_min_percent"], "rulepack p1 lower")
    if Decimal(str(gates["p1_pass"]["lower_95_min"])) < proposed_lower:
        raise FtmoProbabilityContractError("binding P1 lower cannot be weaker than rulepack")
    _expect_fraction(gates["breach"]["upper_95_max"], _percent_fraction(breach["upper_95_percent_bound_max_percent"], "rulepack breach"), "breach upper")
    _expect_fraction(gates["two_phase"]["p2_conditional_min"], _percent_fraction(two_phase["phase2_conditional_min_percent"], "rulepack p2"), "p2 conditional")
    _expect_fraction(gates["two_phase"]["joint_min"], _percent_fraction(two_phase["joint_two_phase_min_percent"], "rulepack joint"), "joint")
    if gates["snapshot_freshness_days_max"]["value"] != fresh["maximum_age_days"]:
        raise FtmoProbabilityContractError("snapshot freshness parity mismatch")
    if gates["shadow_run"]["minimum_runs"] != shadow["minimum_runs"] or gates["shadow_run"]["operational_defects_allowed"] != shadow["operational_defects_allowed"]:
        raise FtmoProbabilityContractError("shadow-run parity mismatch")

    return FtmoProbabilityContract(
        path=contract_path,
        sha256=hashlib.sha256(_lf_normalize(raw)).hexdigest(),
        raw_sha256=hashlib.sha256(raw).hexdigest(),
        payload=payload,
    )
