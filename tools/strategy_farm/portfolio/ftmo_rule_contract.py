"""Validated evaluator projection of the canonical FTMO target rulepack.

Provider rules remain in ``FTMO_2S_100K_SWING_V2.json``.  This module contains
no duplicated numerical thresholds; it validates that rulepack through
``target_rulepacks`` and projects only the fields needed by evaluation engines.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path
import sys
from typing import Any, Mapping

try:
    from tools.strategy_farm import target_rulepacks
except ModuleNotFoundError:  # pragma: no cover - direct sibling-script execution
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm import target_rulepacks


DEFAULT_RULEPACK_PATH = (
    Path(__file__).resolve().parents[1]
    / "config"
    / "target_rulepacks"
    / "FTMO_2S_100K_SWING_V2.json"
)


@dataclass(frozen=True)
class FtmoTwoStepContract:
    rulepack_id: str
    rulepack_as_of: str
    canonical_sha256: str
    initial_equity: Decimal
    phase1_target_fraction: Decimal
    phase2_target_fraction: Decimal
    maximum_daily_loss_fraction: Decimal
    maximum_total_loss_fraction: Decimal
    minimum_trading_days: int
    timezone: str
    daily_reset_local_time: str
    trading_day_qualifier: str
    breach_operator: str
    target_operator: str
    maximum_loss_model: str
    phase_reset_to_initial_equity: bool
    live_equity_compounding_allowed: bool


def _by_id(rows: list[dict[str, Any]], key: str) -> dict[str, Mapping[str, Any]]:
    return {str(row[key]): row for row in rows}


def _fraction(parameters: Mapping[str, Any], key: str) -> Decimal:
    return Decimal(str(parameters[key])) / Decimal(100)


def load_two_step_contract(
    path: Path | str = DEFAULT_RULEPACK_PATH,
) -> FtmoTwoStepContract:
    """Load, schema-validate, and project the 2-Step evaluation contract."""

    pack = target_rulepacks.load_rulepack_path(path)
    payload = pack.as_dict()
    if pack.rulepack_id != "FTMO_2S_100K_SWING_V2" or pack.target != "FTMO":
        raise target_rulepacks.RulepackValidationError(
            "evaluator requires FTMO_2S_100K_SWING_V2"
        )
    rules = _by_id(payload["official_rules"], "rule_id")
    guardrails = _by_id(payload["internal_guardrails"], "guardrail_id")
    p1 = rules["ftmo_2s_phase1_profit_target"]["parameters"]
    p2 = rules["ftmo_2s_verification_profit_target"]["parameters"]
    daily = rules["ftmo_2s_max_daily_loss"]["parameters"]
    total = rules["ftmo_2s_maximum_loss"]["parameters"]
    minimum = rules["ftmo_2s_minimum_trading_days"]["parameters"]
    passing = rules["ftmo_2s_pass_condition"]["parameters"]
    anchor = guardrails["qm_ftmo_initial_balance_risk_anchor"]["parameters"]
    initial = Decimal(str(anchor["reference_balance_usd"]))
    return FtmoTwoStepContract(
        rulepack_id=pack.rulepack_id,
        rulepack_as_of=pack.as_of,
        canonical_sha256=pack.canonical_sha256,
        initial_equity=initial,
        phase1_target_fraction=_fraction(p1, "percent_of_initial_simulated_capital"),
        phase2_target_fraction=_fraction(p2, "percent_of_initial_simulated_capital"),
        maximum_daily_loss_fraction=_fraction(
            daily, "percent_of_initial_simulated_capital"
        ),
        maximum_total_loss_fraction=_fraction(
            total, "percent_of_initial_simulated_capital"
        ),
        minimum_trading_days=int(minimum["days"]),
        timezone=str(minimum["timezone"]),
        daily_reset_local_time=str(daily["reset_local_time"]),
        trading_day_qualifier=str(minimum["qualifying_action"]),
        breach_operator=str(daily["breach_operator"]),
        target_operator=str(passing["balance_operator"]),
        maximum_loss_model=str(total["model"]),
        phase_reset_to_initial_equity=True,
        live_equity_compounding_allowed=bool(
            anchor["live_equity_compounding_allowed"]
        ),
    )
