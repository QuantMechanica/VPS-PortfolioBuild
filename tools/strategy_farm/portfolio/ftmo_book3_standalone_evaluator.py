"""SHA-pinned, research-only FTMO Book-3 evaluation from standalone MT5 runs.

The evaluator is intentionally narrower than a release or money gate.  It binds
the exact R0/R1/R2 runner receipts, native MT5 summaries, Q08 lifecycle streams,
M15 bars, the official-symbol cost snapshot, the FTMO rulepack, and strict
qualification evidence by SHA-256.  Only after every binding and every native
stream/report reconciliation passes does it reuse the synchronized M15 account
model from :mod:`ftmo_bar_joint_book_sim`.

The resulting first-passage estimates are research diagnostics.  M15 OHLC plus
Q08 lifetime MAE is not an event-complete joint account-equity trace, so this
module always leaves ``money_gate_authorized``, ``deployment_allowed``, and
``factory_action_authorized`` false.  Strict Q08/qualification readiness is
reported independently and is never weakened by a favourable simulation.
"""

from __future__ import annotations

import argparse
import ast
import collections
import datetime as dt
import hashlib
import json
import math
import os
import random
import re
import statistics
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_bar_joint_book_sim as joint
    from . import ftmo_stream_reconciliation as reconciliation
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_joint_book_sim as joint  # type: ignore
    import ftmo_stream_reconciliation as reconciliation  # type: ignore

reconcile_case = reconciliation.reconcile_case


MANIFEST_SCHEMA = "qm.ftmo-book3-standalone-evaluation-manifest/v1"
RECEIPT_SCHEMA = "qm.ftmo-book3-standalone-readiness-receipt/v1"
COST_SNAPSHOT_SCHEMA = "qm.ftmo-book3-symbol-cost-snapshot/v1"
BOOK_ID = "FTMO_BOOK3_STANDALONE_R0_R1_R2"
LADDER_MEASUREMENT_CONTRACT = "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET"
DIAGNOSTIC_MEASUREMENT_CONTRACT = "FTMO_BOOK3_STANDALONE_DIAGNOSTIC_V1"
DIAGNOSTIC_CODE = "D13108"
DIAGNOSTIC_HOLD_CODE = "FTMO_BOOK3_STANDALONE_DIAGNOSTIC_ISOLATED_ONLY"
DIAGNOSTIC_HOLD_REASON = (
    "OWNER-authorized FTMO Book-3 QM5_13108 standalone diagnostic; isolated T10 "
    "execution only; no ladder progression or release authority"
)
EXCLUDED_V2_R2_HOLD_CODE = "FTMO_BOOK3_Q02_ISOLATED_ONLY"
EXCLUDED_V2_R2_HOLD_REASON = (
    "OWNER-preregistered FTMO Book-3 Q02 fidelity ladder; isolated T10 execution only"
)
EXCLUDED_V2_R2_ROW_FIELDS = frozenset(
    {
        "id",
        "kind",
        "phase",
        "ea_id",
        "symbol",
        "setfile_path",
        "status",
        "verdict",
        "attempt_count",
        "parent_task_id",
        "evidence_path",
        "claimed_by",
        "payload_json",
        "created_at",
        "updated_at",
    }
)
HOLD_FIELDS = frozenset(
    {
        "work_item_id",
        "hold_code",
        "reason",
        "active",
        "release_on_restart",
        "created_at",
        "updated_at",
        "released_at",
        "release_note",
    }
)
FULL_LIFECYCLE_MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
R0_R1_AUTHORITATIVE_SOURCE_COMMIT = "40573cd720d524ffe3035930da9337a7328086b8"
BASE_SUCCESS_CHECK_KEYS = frozenset(
    {
        "worker_exit_code_zero",
        "work_item_done",
        "work_item_pass",
        "work_item_unclaimed",
        "work_item_evidence_valid",
        "post_run_stream_valid",
        "execution_inputs_unchanged",
        "runtime_sources_unchanged",
        "payload_contract_revalidated",
        "fidelity_receipt_unchanged",
        "process_tree_quiescent",
    }
)
DIAGNOSTIC_SUCCESS_CHECK_KEYS = BASE_SUCCESS_CHECK_KEYS | {
    "diagnostic_q08_valid",
    "diagnostic_v2_r2_unchanged",
    "diagnostic_hold_unchanged",
}
REPO_ROOT = Path(__file__).resolve().parents[3]
EVALUATOR_SOURCE_PATHS = {
    "standalone_evaluator": Path(__file__).resolve(),
    "joint_m15_account_model": Path(joint.__file__).resolve(),
    "native_stream_reconciliation": Path(reconciliation.__file__).resolve(),
    "report_cost_reconciliation": Path(__file__).with_name("ftmo_report_cost_reconcile.py").resolve(),
    "intraday_candidate_screen": Path(__file__).with_name("ftmo_intraday_candidate_screen.py").resolve(),
    "phase1_mae": Path(__file__).with_name("ftmo_phase1_mae.py").resolve(),
    "prop_challenge_optimizer": Path(__file__).with_name("prop_challenge_optimizer.py").resolve(),
    "commission": Path(__file__).with_name("commission.py").resolve(),
    "portfolio_common": Path(__file__).with_name("portfolio_common.py").resolve(),
    "prop_challenge_sim": Path(__file__).with_name("prop_challenge_sim.py").resolve(),
    "portfolio_package": Path(__file__).with_name("__init__.py").resolve(),
}

DEFAULT_COST_SNAPSHOT_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-07-30_ftmo_book3_symbol_cost_snapshot.json"
)
DEFAULT_COST_SNAPSHOT_SHA256 = (
    "7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280"
)
DEFAULT_RULEPACK_PATH = Path(
    r"C:\QM\repo\tools\strategy_farm\config\target_rulepacks\FTMO_2S_100K_SWING_V1.json"
)
DEFAULT_RULEPACK_SHA256 = (
    "c7c8cc5312552576dd6af118599d5404e68b9e279a9be679dcba8021ec4b8686"
)

STARTING_BALANCE = 100_000.0
PHASE1_TARGET = 110_000.0
PHASE2_TARGET = 105_000.0
DAILY_LOSS_AMOUNT = 5_000.0
MAXIMUM_LOSS_FLOOR = 90_000.0
MINIMUM_TRADING_DAYS = 4
PHASE1_CAPTURE_BALANCE = 110_250.0
PHASE2_CAPTURE_BALANCE = 105_150.0
PHASE2_RISK_MULTIPLIER = 0.75
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
MAX_STRICT_JSON_BYTES = 32 * 1024 * 1024

EXPECTED_BOOK: dict[str, tuple[int, str, str]] = {
    "R0": (9936, "USDJPY.DWX", "USD/JPY"),
    "R1": (10145, "XAUUSD.DWX", "XAU/USD"),
    "R2": (13108, "XTIUSD.DWX", "USOIL.cash"),
}

OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH = Path(
    "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json"
)
OFFICIAL_RULE_SNAPSHOT_SHA256 = (
    "60f94e0d1d3ff5f64582c6274ef1cffe25383806b9a718104f3a34ad89384b72"
)
EXPECTED_OFFICIAL_SOURCE_IDS = frozenset(
    {
        "ftmo_trading_objectives_official",
        "ftmo_2_step_challenge_official",
        "ftmo_news_official",
        "ftmo_weekend_official",
        "ftmo_ea_official",
        "ftmo_forbidden_practices_official",
    }
)

EXPECTED_OFFICIAL_RULE_SEMANTICS: dict[str, dict[str, Any]] = {
    "ftmo_2s_phase1_profit_target": {
        "category": "OBJECTIVE",
        "scope": ["FTMO_2_STEP_PHASE1", "USD_100000"],
        "parameters": {
            "percent_of_initial_simulated_capital": "10",
            "amount_usd": "10000",
            "balance_usd": "110000",
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_verification_profit_target": {
        "category": "OBJECTIVE",
        "scope": ["FTMO_2_STEP_VERIFICATION", "USD_100000"],
        "parameters": {
            "percent_of_initial_simulated_capital": "5",
            "amount_usd": "5000",
            "balance_usd": "105000",
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_max_daily_loss": {
        "category": "RISK_LIMIT",
        "scope": [
            "FTMO_2_STEP_PHASE1",
            "FTMO_2_STEP_VERIFICATION",
            "FTMO_ACCOUNT_2_STEP",
            "USD_100000",
        ],
        "parameters": {
            "percent_of_initial_simulated_capital": "5",
            "amount_usd": "5000",
            "timezone": "Europe/Prague",
            "reset_local_time": "00:00:00",
            "limit_basis": "MIDNIGHT_BALANCE_MINUS_FIXED_AMOUNT",
            "tested_quantity": "EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS",
            "breach_operator": "STRICTLY_BELOW_LIMIT",
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_maximum_loss": {
        "category": "RISK_LIMIT",
        "scope": [
            "FTMO_2_STEP_PHASE1",
            "FTMO_2_STEP_VERIFICATION",
            "FTMO_ACCOUNT_2_STEP",
            "USD_100000",
        ],
        "parameters": {
            "model": "STATIC_INITIAL",
            "percent_of_initial_simulated_capital": "10",
            "amount_usd": "10000",
            "floor_usd": "90000",
            "tested_quantity": "EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS",
            "breach_operator": "STRICTLY_BELOW_LIMIT",
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_minimum_trading_days": {
        "category": "OBJECTIVE",
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION"],
        "parameters": {
            "days": 4,
            "timezone": "Europe/Prague",
            "qualifying_action": "POSITION_OPENED",
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_no_time_limit": {
        "category": "TRADING_CONDITION",
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION"],
        "parameters": {"maximum_trading_period_days": None},
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_2s_pass_condition": {
        "category": "OBJECTIVE",
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION"],
        "parameters": {
            "balance_operator": "STRICTLY_GREATER_THAN_TARGET",
            "positions_open": 0,
        },
        "source_ids": ["ftmo_trading_objectives_official"],
    },
    "ftmo_swing_news": {
        "category": "TRADING_CONDITION",
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION", "FTMO_ACCOUNT_SWING"],
        "parameters": {
            "evaluation_restricted": False,
            "ftmo_account_swing_restricted": False,
        },
        "source_ids": ["ftmo_news_official"],
    },
    "ftmo_swing_weekend": {
        "category": "TRADING_CONDITION",
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION", "FTMO_ACCOUNT_SWING"],
        "parameters": {
            "evaluation_restricted": False,
            "ftmo_account_swing_restricted": False,
        },
        "source_ids": ["ftmo_weekend_official"],
    },
    "ftmo_ea_server_limits": {
        "category": "OPERATIONAL_LIMIT",
        "scope": ["FTMO_EVALUATION", "FTMO_ACCOUNT", "EA"],
        "parameters": {
            "ea_allowed": True,
            "simultaneous_orders": 200,
            "positions_per_day": 2000,
            "server_requests_per_day_hyperactive_above": 2000,
        },
        "source_ids": ["ftmo_ea_official", "ftmo_forbidden_practices_official"],
    },
    "ftmo_replicable_trading_requirement": {
        "category": "TRADING_CONDITION",
        "scope": ["FTMO_EVALUATION", "FTMO_ACCOUNT", "EA"],
        "parameters": {
            "latency_or_feed_exploitation_allowed": False,
            "server_manipulation_allowed": False,
            "non_replicable_risk_allowed": False,
        },
        "source_ids": ["ftmo_forbidden_practices_official"],
    },
}

EXPECTED_INTERNAL_GUARDRAIL_SEMANTICS: dict[str, dict[str, Any]] = {
    "qm_ftmo_initial_balance_risk_anchor": {
        "scope": ["FTMO_2_STEP_PHASE1", "FTMO_2_STEP_VERIFICATION", "SIZING"],
        "parameters": {
            "reference_balance_usd": "100000",
            "live_equity_compounding_allowed": False,
        },
    },
    "qm_ftmo_per_trade_risk_cap": {
        "scope": ["FTMO_BOOK", "SLEEVE", "TRADE"],
        "parameters": {
            "maximum_percent_of_initial_balance": "1",
            "maximum_usd": "1000",
        },
    },
    "qm_ftmo_correlated_cluster_risk": {
        "scope": ["FTMO_BOOK", "CORRELATED_CLUSTER"],
        "parameters": {
            "maximum_percent_of_initial_balance": "1.5",
            "maximum_usd": "1500",
        },
    },
    "qm_ftmo_total_open_stop_risk": {
        "scope": ["FTMO_BOOK"],
        "parameters": {
            "maximum_percent_of_initial_balance": "2.5",
            "maximum_usd": "2500",
        },
    },
    "qm_ftmo_projected_daily_loss_budget": {
        "scope": ["FTMO_BOOK", "ENTRY_GOVERNOR"],
        "parameters": {
            "quantile": "0.999",
            "maximum_percent_of_initial_balance": "3",
            "official_buffer_percent": "2",
        },
    },
    "qm_ftmo_total_drawdown_budget": {
        "scope": ["FTMO_BOOK", "ENTRY_GOVERNOR", "EVALUATION"],
        "parameters": {
            "maximum_percent_of_initial_balance": "7",
            "official_buffer_percent": "3",
        },
    },
    "qm_ftmo_phase1_target_capture_buffer": {
        "scope": ["FTMO_2_STEP_PHASE1", "ACCOUNT_GOVERNOR"],
        "parameters": {
            "capture_equity_percent": "10.25",
            "capture_equity_usd": "110250",
            "official_pass_balance_usd_exclusive": "110000",
            "cancel_pending_orders": True,
            "flatten_positions": True,
        },
    },
    "qm_ftmo_phase2_target_capture_buffer": {
        "scope": ["FTMO_2_STEP_VERIFICATION", "ACCOUNT_GOVERNOR"],
        "parameters": {
            "capture_equity_percent": "5.15",
            "capture_equity_usd": "105150",
            "official_pass_balance_usd_exclusive": "105000",
            "maximum_phase1_risk_multiplier": "0.75",
            "cancel_pending_orders": True,
            "flatten_positions": True,
        },
    },
    "qm_ftmo_midnight_entry_window": {
        "scope": ["FTMO_BOOK", "ENTRY_GOVERNOR"],
        "parameters": {
            "timezone": "Europe/Prague",
            "block_from_local": "23:50:00",
            "block_until_local": "00:10:00",
            "position_management_continues": True,
        },
    },
}

EXPECTED_SOURCE_CONTRACT_SIZES = {
    "USDJPY.DWX": 100_000.0,
    "XAUUSD.DWX": 100.0,
    "XTIUSD.DWX": 1_000.0,
}
EXPECTED_PROVIDER_PROFIT_CURRENCIES = {
    "USDJPY.DWX": "JPY",
    "XAUUSD.DWX": "USD",
    "XTIUSD.DWX": "USD",
}
EXPECTED_COST_RESPONSE_SHA256 = (
    "35c33835453dd6004787561c5a5d0d912269c02ca91ea3dbb855fa57b5becb78"
)
EXPECTED_COST_AUTHORIZATION = {
    "deployment_allowed": False,
    "money_gate_authorized": False,
    "factory_action_authorized": False,
    "purpose": "Research-only FTMO Book-3 cost input",
}
EXPECTED_QUALIFICATION_AUTHORIZATION = {
    "money_gate_authorized": False,
    "deployment_allowed": False,
    "factory_action_authorized": False,
    "paid_challenge_purchase_authorized": False,
}
EXPECTED_COST_MATRIX: dict[str, dict[str, Any]] = {
    "USDJPY.DWX": {
        "provider_symbol": "USD/JPY",
        "source_contract_size": 100_000.0,
        "contract_size": 100_000.0,
        "commission_model": "flat_round_trip_per_target_lot_usd",
        "flat_round_trip_commission_per_lot": 5.0,
        "commission_percent_per_side": 0.0,
        "swap_long_points": 0.92,
        "swap_short_points": -19.78,
        "digits": 3,
        "profit_currency_to_account_rate": 0.0066666667,
        "derive_profit_currency_rate_from_pnl": True,
        "triple_weekday": 2,
    },
    "XAUUSD.DWX": {
        "provider_symbol": "XAU/USD",
        "source_contract_size": 100.0,
        "contract_size": 100.0,
        "commission_model": "percent_of_notional_per_side",
        "flat_round_trip_commission_per_lot": 0.0,
        "commission_percent_per_side": 0.0014,
        "swap_long_points": -66.21,
        "swap_short_points": -23.55,
        "digits": 2,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": False,
        "triple_weekday": 2,
    },
    "XTIUSD.DWX": {
        "provider_symbol": "USOIL.cash",
        "source_contract_size": 1_000.0,
        "contract_size": 100.0,
        "commission_model": "commission_free",
        "flat_round_trip_commission_per_lot": 0.0,
        "commission_percent_per_side": 0.0,
        "swap_long_points": 4.22,
        "swap_short_points": -26.8,
        "digits": 3,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": False,
        "triple_weekday": 2,
    },
}
EXPECTED_PROVIDER_COST_MATRIX: dict[str, dict[str, Any]] = {
    "USD/JPY": {
        "active": True,
        "assetClass": "Forex",
        "commission": 5.0,
        "commissionType": "flat_USD",
        "contractSize": 100_000.0,
        "digits": 3,
        "profitCurrency": "JPY",
        "swapLong": 0.92,
        "swapShort": -19.78,
        "swapType": "points",
    },
    "XAU/USD": {
        "active": True,
        "assetClass": "Metals CFD",
        "commission": 0.0014,
        "commissionType": "percent",
        "contractSize": 100.0,
        "digits": 2,
        "profitCurrency": "USD",
        "swapLong": -66.21,
        "swapShort": -23.55,
        "swapType": "points",
    },
    "USOIL.cash": {
        "active": True,
        "assetClass": "Cash CFD",
        "commission": 0.0,
        "commissionType": "percent",
        "contractSize": 100.0,
        "digits": 3,
        "profitCurrency": "USD",
        "swapLong": 4.22,
        "swapShort": -26.8,
        "swapType": "points",
    },
}

EXPECTED_EVALUATION_OBJECTIVE = (
    "Pass the first FTMO 2-Step Swing Challenge with a rule-faithful book while "
    "preserving enough risk margin to complete Verification and operate the later "
    "Swing FTMO Account."
)
EXPECTED_METRIC_SEMANTICS: dict[str, dict[str, Any]] = {
    "phase1_first_passage_probability": {
        "direction": "MAXIMIZE",
        "description": "Probability of satisfying all Phase-1 objectives on a sealed, rule-faithful mark-to-market simulation.",
        "parameters": {"target_percent": "10", "all_rules_concurrent": True},
    },
    "phase2_conditional_pass_probability": {
        "direction": "MAXIMIZE",
        "description": "Conditional probability of passing Verification after a Phase-1 pass with the lower-risk Phase-2 profile.",
        "parameters": {"target_percent": "5", "all_rules_concurrent": True},
    },
    "joint_two_phase_pass_probability": {
        "direction": "MAXIMIZE",
        "description": "Probability of completing both phases rather than optimizing only the first purchase milestone.",
        "parameters": {"phase_dependence_preserved": True},
    },
    "official_rule_breach_probability": {
        "direction": "MINIMIZE",
        "description": "Probability of breaching either official equity loss limit before completion.",
        "parameters": {"intratrade_mark_to_market": True, "prague_midnight": True},
    },
}
EXPECTED_GO_CRITERION_SEMANTICS: dict[str, dict[str, Any]] = {
    "ftmo_rule_snapshot_fresh": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "Refresh and hash-bind the official FTMO rule snapshot shortly before any purchase decision.",
        "parameters": {"maximum_age_days": 7, "all_sources_official": True},
    },
    "ftmo_execution_fidelity_closed": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "Exact candidate binaries and sets have complete standalone-to-book entry, exit, timer, and ownership fidelity or an explicit predeclared adjudication.",
        "parameters": {"unadjudicated_mismatches": 0},
    },
    "ftmo_complete_mtm_evidence": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "Simulation uses tick- or event-complete interval minimum equity, Prague day anchors, FTMO symbols, costs, swap, margin, and pending-order state.",
        "parameters": {
            "closed_pnl_daily_proxy_allowed": False,
            "intratrade_equity_required": True,
        },
    },
    "ftmo_phase1_probability_gate": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "Phase-1 pass probability and its uncertainty satisfy the internal purchase threshold on a once-sealed holdout.",
        "parameters": {
            "point_estimate_min_percent": "80",
            "lower_95_percent_bound_min_percent": "70",
        },
    },
    "ftmo_breach_probability_gate": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "The upper uncertainty bound for any official loss-rule breach remains within the internal budget.",
        "parameters": {"upper_95_percent_bound_max_percent": "10"},
    },
    "ftmo_two_phase_probability_gate": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "Verification and joint completion probabilities are decision-grade before buying Phase 1.",
        "parameters": {
            "phase2_conditional_min_percent": "85",
            "joint_two_phase_min_percent": "65",
        },
    },
    "ftmo_free_trial_gate": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "At least one exact-profile Free Trial or shadow run completes without a rule, governor, identity, or execution defect and remains inside preregistered prediction bands.",
        "parameters": {
            "minimum_runs": 1,
            "must_reach_profit_target": False,
            "operational_defects_allowed": 0,
        },
    },
    "ftmo_owner_purchase_gate": {
        "classification": "INTERNAL_DECISION_CRITERION",
        "description": "A paid Challenge requires a separate signed OWNER decision after all evidence criteria pass.",
        "parameters": {
            "owner_signature_required": True,
            "automatic_purchase_allowed": False,
        },
    },
}
EXPECTED_DEPLOYMENT_BOUNDARY = {
    "runtime_integration": "NOT_IMPLEMENTED",
    "deploy_authorization": "OWNER_ONLY",
    "factory_action_authorized": False,
    "mt5_action_authorized": False,
    "notes": [
        "This rulepack does not modify or configure QM_PropFirm, QM_FTMOGovernorPolicy, an EA, a terminal, or AutoTrading.",
        "Swing news and weekend facts are provider rules; every numeric safety buffer and probability gate in internal_guardrails or evaluation_profile is QuantMechanica policy.",
        "A future runtime integration requires a new reviewed version and explicit OWNER authorization.",
    ],
}


class StandaloneEvaluationError(ValueError):
    """A fail-closed input, provenance, or model-validation error."""


class CreateOnlyReceiptError(FileExistsError):
    """Raised when a governed receipt target already exists."""


@dataclass(frozen=True)
class DailyObservation:
    day: dt.date
    realized: float
    minimum_equity_delta: float
    opened_positions: int
    flat_at_start: bool
    flat_at_end: bool


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _parse_utc(value: Any, label: str) -> dt.datetime:
    raw = str(value or "").strip()
    if not raw:
        raise StandaloneEvaluationError(f"{label}:timestamp_missing")
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(raw)
    except ValueError as exc:
        raise StandaloneEvaluationError(f"{label}:timestamp_invalid") from exc
    if parsed.tzinfo is None:
        raise StandaloneEvaluationError(f"{label}:timestamp_timezone_missing")
    return parsed.astimezone(dt.UTC)


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise StandaloneEvaluationError(f"{label}:not_numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise StandaloneEvaluationError(f"{label}:not_numeric") from exc
    if not math.isfinite(number):
        raise StandaloneEvaluationError(f"{label}:nonfinite")
    return number


def _integer(value: Any, label: str) -> int:
    if isinstance(value, bool):
        raise StandaloneEvaluationError(f"{label}:not_integer")
    if isinstance(value, int):
        return value
    if isinstance(value, str) and re.fullmatch(r"-?[0-9]+", value.strip()):
        return int(value)
    raise StandaloneEvaluationError(f"{label}:not_integer")


def _positive_int(value: Any, label: str) -> int:
    number = _integer(value, label)
    if number <= 0:
        raise StandaloneEvaluationError(f"{label}:not_positive")
    return number


def _ea_identifier(value: Any, label: str) -> int:
    token = str(value or "").strip().upper()
    match = re.fullmatch(r"(?:QM5_)?([0-9]+)", token)
    if match is None:
        raise StandaloneEvaluationError(f"{label}:invalid")
    number = int(match.group(1))
    if number <= 0:
        raise StandaloneEvaluationError(f"{label}:not_positive")
    return number


def _normalized_path(path: Path) -> str:
    return os.path.normcase(os.path.abspath(str(path.resolve(strict=False))))


def _same_path(left: Any, right: Path) -> bool:
    if not left:
        return False
    return _normalized_path(Path(str(left))) == _normalized_path(right)


def _pinned_spec(
    raw: Any,
    label: str,
    *,
    default_path: Path | None = None,
    default_sha256: str | None = None,
) -> tuple[Path, dict[str, Any]]:
    if raw is None and default_path is not None and default_sha256 is not None:
        raw = {"path": str(default_path), "sha256": default_sha256}
    if not isinstance(raw, Mapping):
        raise StandaloneEvaluationError(f"{label}:pinned_spec_missing")
    path_token = raw.get("path")
    expected = str(raw.get("sha256") or "").strip().lower()
    if not isinstance(path_token, str) or not path_token.strip():
        raise StandaloneEvaluationError(f"{label}:path_missing")
    if not SHA256_RE.fullmatch(expected):
        raise StandaloneEvaluationError(f"{label}:sha256_invalid")
    path = Path(path_token)
    if not path.is_absolute():
        raise StandaloneEvaluationError(f"{label}:path_not_absolute")
    if not path.is_file():
        raise StandaloneEvaluationError(f"{label}:file_missing:{path}")
    actual = sha256_file(path)
    if actual != expected:
        raise StandaloneEvaluationError(
            f"{label}:sha256_mismatch:expected={expected}:actual={actual}"
        )
    stat = path.stat()
    declared_bytes = raw.get("bytes")
    if declared_bytes is not None and (
        isinstance(declared_bytes, bool)
        or not isinstance(declared_bytes, int)
        or declared_bytes != stat.st_size
    ):
        raise StandaloneEvaluationError(f"{label}:declared_bytes_mismatch")
    declared_identity = raw.get("file_identity")
    observed_identity = {"device": stat.st_dev, "inode": stat.st_ino}
    if declared_identity is not None and declared_identity != observed_identity:
        raise StandaloneEvaluationError(f"{label}:declared_file_identity_mismatch")
    record = {
        "path": str(path.resolve()),
        "sha256": actual,
        "bytes": stat.st_size,
        "file_identity": observed_identity,
    }
    if "lines" in raw:
        lines = _positive_int(raw.get("lines"), f"{label}:lines")
        record["lines"] = lines
    return path, record


def _reject_nonfinite_json(value: Any, label: str) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        raise StandaloneEvaluationError(f"{label}:nonfinite_json_number")
    if isinstance(value, Mapping):
        for child in value.values():
            _reject_nonfinite_json(child, label)
    elif isinstance(value, list):
        for child in value:
            _reject_nonfinite_json(child, label)


def _loads_strict_json(raw: bytes, label: str) -> Any:
    if len(raw) > MAX_STRICT_JSON_BYTES:
        raise StandaloneEvaluationError(f"{label}:json_too_large")
    def object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        output: dict[str, Any] = {}
        for key, value in pairs:
            if key in output:
                raise StandaloneEvaluationError(f"{label}:duplicate_key:{key}")
            output[key] = value
        return output

    def reject_constant(token: str) -> Any:
        raise StandaloneEvaluationError(f"{label}:nonfinite_json_constant:{token}")

    try:
        value = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=object_pairs,
            parse_constant=reject_constant,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise StandaloneEvaluationError(f"{label}:json_invalid:{type(exc).__name__}") from exc
    _reject_nonfinite_json(value, label)
    return value


def _load_json(path: Path, label: str) -> Any:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise StandaloneEvaluationError(f"{label}:json_unreadable:{type(exc).__name__}") from exc
    return _loads_strict_json(raw, label)


def _copy_verified_file(
    source: Path,
    destination: Path,
    *,
    expected_sha256: str,
    expected_bytes: int,
    expected_lines: int | None = None,
    label: str,
) -> dict[str, Any]:
    """Copy one opened source handle to a create-only destination and verify it.

    Downstream code consumes only the destination.  A source mutation during the
    copy therefore either changes the copied digest/size or the source-handle
    metadata, and the evaluation is refused even if the original path is later
    restored (the classic change/read/restore ABA race).
    """

    digest = hashlib.sha256()
    copied = 0
    newlines = 0
    last_byte: bytes | None = None
    try:
        descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400)
    except FileExistsError as exc:
        raise StandaloneEvaluationError(f"{label}:staging_target_exists") from exc
    try:
        with source.open("rb") as reader, os.fdopen(descriptor, "wb") as writer:
            before = os.fstat(reader.fileno())
            while True:
                chunk = reader.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
                copied += len(chunk)
                newlines += chunk.count(b"\n")
                last_byte = chunk[-1:]
                writer.write(chunk)
            writer.flush()
            os.fsync(writer.fileno())
            after = os.fstat(reader.fileno())
    except BaseException:
        # Partial create-only staging evidence is intentionally retained.
        raise
    actual = digest.hexdigest()
    lines = newlines + (1 if copied and last_byte != b"\n" else 0)
    if copied != expected_bytes or actual != expected_sha256:
        raise StandaloneEvaluationError(
            f"{label}:staged_content_mismatch:expected={expected_sha256}/{expected_bytes}:"
            f"actual={actual}/{copied}"
        )
    if expected_lines is not None and lines != expected_lines:
        raise StandaloneEvaluationError(
            f"{label}:staged_line_count_mismatch:expected={expected_lines}:actual={lines}"
        )
    before_identity = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
    after_identity = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
    if before_identity != after_identity:
        raise StandaloneEvaluationError(f"{label}:source_changed_during_staging")
    destination_stat = destination.stat()
    return {
        "path": str(destination.resolve()),
        "sha256": actual,
        "bytes": copied,
        "lines": lines,
        "file_identity": {
            "device": destination_stat.st_dev,
            "inode": destination_stat.st_ino,
        },
    }


class ContentAddressedStager:
    """Create-only snapshot used as the sole semantic input to an evaluation."""

    def __init__(self, root: Path, manifest_sha256: str, manifest_bytes: bytes) -> None:
        if not root.is_absolute():
            raise StandaloneEvaluationError("manifest:staging_root_not_absolute")
        root = root.resolve()
        if not root.is_dir():
            raise StandaloneEvaluationError("manifest:staging_root_missing")
        self.directory = root / manifest_sha256
        try:
            self.directory.mkdir(mode=0o700, exist_ok=False)
        except FileExistsError as exc:
            raise StandaloneEvaluationError("manifest:staging_snapshot_already_exists") from exc
        self._by_original: dict[str, Path] = {}
        # The parent directory is already the complete content hash.  A short
        # filename keeps create-only staging usable under Windows MAX_PATH.
        manifest_destination = self.directory / "manifest.json"
        descriptor = os.open(
            manifest_destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400
        )
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(manifest_bytes)
            handle.flush()
            os.fsync(handle.fileno())
        self.manifest_path = manifest_destination
        self._sequence = 0
        self._original_file_identities: set[tuple[int, int]] = set()

    def stage(
        self,
        original: Path,
        pin: Mapping[str, Any],
        label: str,
    ) -> tuple[Path, dict[str, Any]]:
        normalized = _normalized_path(original)
        if normalized in self._by_original:
            raise StandaloneEvaluationError(f"{label}:artifact_path_reused")
        original_stat = original.stat()
        original_identity = (original_stat.st_dev, original_stat.st_ino)
        if original_identity in self._original_file_identities:
            raise StandaloneEvaluationError(f"{label}:original_file_identity_reused")
        suffix = "".join(original.suffixes)[-32:]
        self._sequence += 1
        # Keep Windows paths below the legacy MAX_PATH boundary while retaining
        # the full digest in the immutable binding record.
        destination = self.directory / (
            f"{self._sequence:02d}-{str(pin['sha256'])[:24]}{suffix}"
        )
        staged = _copy_verified_file(
            original,
            destination,
            expected_sha256=str(pin["sha256"]),
            expected_bytes=_positive_int(pin["bytes"], f"{label}:bytes"),
            expected_lines=(
                _positive_int(pin["lines"], f"{label}:lines")
                if "lines" in pin
                else None
            ),
            label=label,
        )
        self._by_original[normalized] = destination
        self._original_file_identities.add(original_identity)
        return destination, {**dict(pin), "staged": staged}


def _revalidate_pinned_record(record: Any, label: str) -> None:
    if not isinstance(record, Mapping):
        raise StandaloneEvaluationError(f"{label}:binding_missing")
    path_token = record.get("path")
    expected = str(record.get("sha256") or "").lower()
    if not isinstance(path_token, str) or not path_token or not SHA256_RE.fullmatch(expected):
        raise StandaloneEvaluationError(f"{label}:binding_invalid")
    path = Path(path_token)
    if not path.is_file():
        raise StandaloneEvaluationError(f"{label}:file_missing:{path}")
    actual = sha256_file(path)
    if actual != expected:
        raise StandaloneEvaluationError(
            f"{label}:sha256_changed_during_evaluation:expected={expected}:actual={actual}"
        )
    expected_bytes = record.get("bytes")
    if not isinstance(expected_bytes, int) or path.stat().st_size != expected_bytes:
        raise StandaloneEvaluationError(f"{label}:size_changed_during_evaluation")
    expected_identity = record.get("file_identity")
    stat = path.stat()
    if isinstance(expected_identity, Mapping) and expected_identity != {
        "device": stat.st_dev,
        "inode": stat.st_ino,
    }:
        raise StandaloneEvaluationError(f"{label}:file_identity_changed_during_evaluation")


def _git_source_state(repo_root: Path, paths: Sequence[Path]) -> dict[str, Any]:
    try:
        relative = [str(path.resolve().relative_to(repo_root.resolve())) for path in paths]
    except ValueError as exc:
        raise StandaloneEvaluationError("evaluator_source:path_outside_repo") from exc
    try:
        head_process = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise StandaloneEvaluationError("evaluator_source:git_head_unreadable") from exc
    if head_process.returncode != 0:
        raise StandaloneEvaluationError("evaluator_source:git_head_unreadable")
    try:
        status_process = subprocess.run(
            ["git", "status", "--porcelain=v1", "--untracked-files=all", "--", *relative],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise StandaloneEvaluationError("evaluator_source:git_status_unreadable") from exc
    if status_process.returncode != 0:
        raise StandaloneEvaluationError("evaluator_source:git_status_unreadable")
    return {
        "head": head_process.stdout.strip().lower(),
        "dirty": [line for line in status_process.stdout.splitlines() if line.strip()],
    }


def _assert_static_source_closure(paths: Sequence[Path]) -> None:
    bound = {path.resolve() for path in paths}
    missing: set[Path] = set()
    for path in sorted(bound):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except (OSError, UnicodeError, SyntaxError) as exc:
            raise StandaloneEvaluationError(
                f"evaluator_source:dependency_scan_failed:{path.name}"
            ) from exc
        for node in ast.walk(tree):
            if not isinstance(node, ast.ImportFrom) or node.level != 1 or not node.module:
                continue
            module_path = path.parent.joinpath(*node.module.split(".")).with_suffix(".py")
            if module_path.is_file() and module_path.resolve() not in bound:
                missing.add(module_path.resolve())
    if missing:
        raise StandaloneEvaluationError(
            "evaluator_source:transitive_local_dependency_unbound:"
            + ",".join(path.name for path in sorted(missing))
        )


def _validate_evaluator_source(raw: Any, *, source_commit: str) -> dict[str, Any]:
    _assert_static_source_closure(list(EVALUATOR_SOURCE_PATHS.values()))
    if not isinstance(raw, Mapping):
        raise StandaloneEvaluationError("evaluator_source:binding_missing")
    repo_token = raw.get("repo_root")
    if not isinstance(repo_token, str) or not _same_path(repo_token, REPO_ROOT):
        raise StandaloneEvaluationError("evaluator_source:repo_root_mismatch")
    if str(raw.get("source_commit") or "").lower() != source_commit:
        raise StandaloneEvaluationError("evaluator_source:source_commit_mismatch")
    artifact_rows = raw.get("artifacts")
    if not isinstance(artifact_rows, list):
        raise StandaloneEvaluationError("evaluator_source:artifacts_missing")
    by_role: dict[str, Mapping[str, Any]] = {}
    for row in artifact_rows:
        if not isinstance(row, Mapping):
            raise StandaloneEvaluationError("evaluator_source:artifact_invalid")
        role = str(row.get("role") or "")
        if role in by_role:
            raise StandaloneEvaluationError(f"evaluator_source:duplicate_role:{role}")
        by_role[role] = row
    if set(by_role) != set(EVALUATOR_SOURCE_PATHS):
        raise StandaloneEvaluationError("evaluator_source:role_set_mismatch")
    normalized: list[dict[str, Any]] = []
    for role, expected_path in EVALUATOR_SOURCE_PATHS.items():
        row = by_role[role]
        if not _same_path(row.get("path"), expected_path):
            raise StandaloneEvaluationError(f"evaluator_source:{role}:path_mismatch")
        path, pin = _pinned_spec(row, f"evaluator_source:{role}")
        if not _same_path(path, expected_path) or row.get("bytes") != pin["bytes"]:
            raise StandaloneEvaluationError(f"evaluator_source:{role}:size_or_path_mismatch")
        normalized.append({"role": role, **pin})
    state = _git_source_state(REPO_ROOT, list(EVALUATOR_SOURCE_PATHS.values()))
    if state["head"] != source_commit:
        raise StandaloneEvaluationError(
            f"evaluator_source:git_head_mismatch:expected={source_commit}:actual={state['head']}"
        )
    if state["dirty"]:
        raise StandaloneEvaluationError("evaluator_source:source_scope_dirty")
    return {
        "repo_root": str(REPO_ROOT),
        "source_commit": source_commit,
        "artifacts": normalized,
        "source_scope_clean": True,
    }


def _revalidate_bound_inputs(bindings: Mapping[str, Any]) -> None:
    evaluator_source = bindings.get("evaluator_source")
    source_commit = str(bindings.get("source_commit") or "")
    _validate_evaluator_source(evaluator_source, source_commit=source_commit)
    for key in (
        "cost_snapshot",
        "rulepack",
        "official_rule_snapshot",
        "qualification_artifact",
    ):
        record = bindings.get(key)
        if not isinstance(record, Mapping) or not isinstance(record.get("staged"), Mapping):
            raise StandaloneEvaluationError(f"{key}:staging_binding_missing")
        _revalidate_pinned_record(record, key)
        _revalidate_pinned_record(record["staged"], f"{key}:staged")
    sleeves = bindings.get("sleeves")
    if not isinstance(sleeves, list) or len(sleeves) != len(EXPECTED_BOOK):
        raise StandaloneEvaluationError("bindings:sleeves_invalid")
    for sleeve in sleeves:
        if not isinstance(sleeve, Mapping):
            raise StandaloneEvaluationError("bindings:sleeve_invalid")
        rung = str(sleeve.get("rung") or "UNKNOWN")
        for role in ("receipt", "summary", "stream", "m15", "report"):
            record = sleeve.get(role)
            if not isinstance(record, Mapping) or not isinstance(record.get("staged"), Mapping):
                raise StandaloneEvaluationError(f"{rung}:{role}:staging_binding_missing")
            _revalidate_pinned_record(record, f"{rung}:{role}")
            _revalidate_pinned_record(record["staged"], f"{rung}:{role}:staged")
        strategy_identity = sleeve.get("strategy_identity")
        artifacts = (
            strategy_identity.get("artifacts")
            if isinstance(strategy_identity, Mapping)
            else None
        )
        if not isinstance(artifacts, Mapping):
            raise StandaloneEvaluationError(f"{rung}:strategy_identity_missing")
        for role in ("setfile", "staged_ex5", "mq5"):
            record = artifacts.get(role)
            if not isinstance(record, Mapping) or not isinstance(record.get("staged"), Mapping):
                raise StandaloneEvaluationError(
                    f"{rung}:strategy:{role}:staging_binding_missing"
                )
            _revalidate_pinned_record(record, f"{rung}:strategy:{role}")
            _revalidate_pinned_record(
                record["staged"], f"{rung}:strategy:{role}:staged"
            )


def _validate_official_rule_sources(
    rulepack: Mapping[str, Any], snapshot: Mapping[str, Any], *, now_utc: dt.datetime
) -> dict[str, Any]:
    rows = rulepack.get("official_sources")
    if not isinstance(rows, list):
        raise StandaloneEvaluationError("rulepack:official_sources_missing")
    by_id: dict[str, Mapping[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping) or not isinstance(row.get("source_id"), str):
            raise StandaloneEvaluationError(f"rulepack:official_source_{index}_invalid")
        source_id = row["source_id"]
        if source_id in by_id:
            raise StandaloneEvaluationError(f"rulepack:duplicate_source_id:{source_id}")
        by_id[source_id] = row
    if set(by_id) != EXPECTED_OFFICIAL_SOURCE_IDS:
        raise StandaloneEvaluationError("rulepack:official_source_id_set_invalid")
    expected_path = OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH.as_posix()
    for source_id, row in by_id.items():
        if (
            row.get("authority") != "OFFICIAL_PROVIDER"
            or str(row.get("snapshot_path") or "").replace("\\", "/") != expected_path
            or str(row.get("snapshot_sha256") or "").lower()
            != OFFICIAL_RULE_SNAPSHOT_SHA256
            or row.get("content_identity_basis") != "NORMALIZED_PROVIDER_RULE_SNAPSHOT"
        ):
            raise StandaloneEvaluationError(
                f"rulepack:official_source_binding_invalid:{source_id}"
            )

    if (
        snapshot.get("schema") != "qm.ftmo-official-rules-snapshot/v1"
        or snapshot.get("profile") != "FTMO Challenge 2-Step / USD 100000 / Swing"
        or snapshot.get("freshness_max_age_days") != 7
    ):
        raise StandaloneEvaluationError("rule_snapshot:envelope_invalid")
    retrieved = _parse_utc(snapshot.get("retrieved_at_utc"), "rule_snapshot")
    now = now_utc.astimezone(dt.UTC)
    if retrieved > now:
        raise StandaloneEvaluationError("rule_snapshot:future_timestamp")
    age = now - retrieved
    if age > dt.timedelta(days=7):
        raise StandaloneEvaluationError("rule_snapshot:stale")
    if any(
        row.get("retrieved_at_utc") != snapshot.get("retrieved_at_utc")
        or row.get("retrieved_on") != "2026-07-29"
        for row in by_id.values()
    ):
        raise StandaloneEvaluationError("rulepack:official_source_vintage_invalid")
    snapshot_sources = snapshot.get("sources")
    if not isinstance(snapshot_sources, list):
        raise StandaloneEvaluationError("rule_snapshot:sources_missing")
    snapshot_by_id: dict[str, Mapping[str, Any]] = {}
    for index, row in enumerate(snapshot_sources):
        if not isinstance(row, Mapping) or not isinstance(row.get("source_id"), str):
            raise StandaloneEvaluationError(f"rule_snapshot:source_{index}_invalid")
        source_id = row["source_id"]
        if source_id in snapshot_by_id:
            raise StandaloneEvaluationError(f"rule_snapshot:duplicate_source_id:{source_id}")
        snapshot_by_id[source_id] = row
    if set(snapshot_by_id) != EXPECTED_OFFICIAL_SOURCE_IDS:
        raise StandaloneEvaluationError("rule_snapshot:source_id_set_invalid")
    for source_id in EXPECTED_OFFICIAL_SOURCE_IDS:
        if (
            snapshot_by_id[source_id].get("url") != by_id[source_id].get("url")
            or snapshot_by_id[source_id].get("http_status") != 200
            or isinstance(snapshot_by_id[source_id].get("http_status"), bool)
        ):
            raise StandaloneEvaluationError(
                f"rule_snapshot:source_crosswalk_invalid:{source_id}"
            )
    expected_claims = {
        "phase1_profit_target_percent": "10",
        "verification_profit_target_percent": "5",
        "profit_target_operator": "STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT",
        "maximum_daily_loss_percent_of_initial": "5",
        "maximum_daily_loss_reset_timezone": "Europe/Prague",
        "maximum_daily_loss_reset_local_time": "00:00:00",
        "maximum_daily_loss_basis": "MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT",
        "maximum_daily_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
        "maximum_loss_percent_of_initial": "10",
        "maximum_loss_model": "STATIC_INITIAL_CAPITAL",
        "maximum_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
        "minimum_trading_days_per_phase": 4,
        "trading_day_qualifier": "AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY",
        "maximum_trading_period_days": None,
        "swing_news_restriction_during_evaluation": False,
        "swing_overnight_or_weekend_restriction": False,
        "expert_advisors_allowed_subject_to_rules": True,
        "simultaneous_order_limit": 200,
        "position_limit_per_day": 2000,
        "hyperactive_server_request_threshold_per_day": 2000,
        "real_market_replicability_required": True,
    }
    if canonical_sha256(snapshot.get("normalized_claims")) != canonical_sha256(
        expected_claims
    ):
        raise StandaloneEvaluationError("rule_snapshot:normalized_claims_invalid")
    return {
        "source_ids": sorted(by_id),
        "snapshot_sha256": OFFICIAL_RULE_SNAPSHOT_SHA256,
        "retrieved_at_utc": retrieved.isoformat().replace("+00:00", "Z"),
        "age_seconds": int(age.total_seconds()),
        "maximum_age_days": 7,
        "semantic_scope": "source identity/url/status plus complete normalized claims",
    }


def _official_rules(rulepack: Mapping[str, Any]) -> dict[str, Any]:
    """Validate every model-relevant official rule field as an exact contract."""
    expected_header = {
        "schema_version": "target-rulepack/v1",
        "schema_ref": "tools/strategy_farm/schemas/target_rulepack_v1.schema.json",
        "rulepack_id": "FTMO_2S_100K_SWING_V1",
        "profile_version": 1,
        "target": "FTMO",
        "account_or_program": "FTMO Challenge 2-Step / USD 100000 / Swing",
        "as_of": "2026-07-29",
        "lifecycle_status": "RESEARCH_CONTRACT_ONLY",
        "canonicalization": {
            "algorithm": "QM_CANONICAL_JSON_V1",
            "hash_algorithm": "SHA-256",
            "numeric_encoding": "NON_INTEGRAL_AS_DECIMAL_STRING",
        },
    }
    observed_header = {key: rulepack.get(key) for key in expected_header}
    if canonical_sha256(observed_header) != canonical_sha256(expected_header):
        raise StandaloneEvaluationError("rulepack:header_contract_invalid")
    rows = rulepack.get("official_rules")
    if not isinstance(rows, list):
        raise StandaloneEvaluationError("rulepack:official_rules_missing")
    by_id: dict[str, Mapping[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping) or not isinstance(row.get("rule_id"), str):
            raise StandaloneEvaluationError(f"rulepack:official_rule_{index}_invalid")
        rule_id = row["rule_id"]
        if rule_id in by_id:
            raise StandaloneEvaluationError(f"rulepack:duplicate_rule_id:{rule_id}")
        by_id[rule_id] = row
    if set(by_id) != set(EXPECTED_OFFICIAL_RULE_SEMANTICS):
        raise StandaloneEvaluationError("rulepack:official_rule_id_set_invalid")
    for rule_id, required in EXPECTED_OFFICIAL_RULE_SEMANTICS.items():
        row = by_id[rule_id]
        observed = {
            "category": row.get("category"),
            "scope": row.get("scope"),
            "parameters": row.get("parameters"),
            "source_ids": row.get("source_ids"),
        }
        if canonical_sha256(observed) != canonical_sha256(required):
            raise StandaloneEvaluationError(
                f"rulepack:unsupported_rule_semantics:{rule_id}:"
                f"{canonical_sha256(observed)}"
            )

    return {
        "phase1_target": PHASE1_TARGET,
        "phase2_target": PHASE2_TARGET,
        "daily_loss_amount": DAILY_LOSS_AMOUNT,
        "maximum_loss_floor": MAXIMUM_LOSS_FLOOR,
        "minimum_trading_days": MINIMUM_TRADING_DAYS,
        "timezone": "Europe/Prague",
        "daily_reset_local_time": "00:00:00",
        "daily_limit_basis": "MIDNIGHT_BALANCE_MINUS_FIXED_AMOUNT",
        "daily_tested_quantity": "EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS",
        "daily_breach_operator": "STRICTLY_BELOW_LIMIT",
        "maximum_model": "STATIC_INITIAL",
        "maximum_tested_quantity": "EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS",
        "maximum_breach_operator": "STRICTLY_BELOW_LIMIT",
        "minimum_days_timezone": "Europe/Prague",
        "minimum_days_qualifying_action": "POSITION_OPENED",
        "target_operator": "STRICTLY_GREATER_THAN_TARGET",
        "positions_open_at_pass": 0,
        "maximum_trading_period_days": None,
        "validated_official_rule_ids": sorted(by_id),
        "validated_semantics_scope": "category+scope+parameters+source_ids",
        "validated_not_simulated_rule_ids": [
            "ftmo_ea_server_limits",
            "ftmo_replicable_trading_requirement",
            "ftmo_swing_news",
            "ftmo_swing_weekend",
        ],
    }


def _internal_policy(rulepack: Mapping[str, Any]) -> dict[str, Any]:
    rows = rulepack.get("internal_guardrails")
    if not isinstance(rows, list):
        raise StandaloneEvaluationError("rulepack:internal_guardrails_missing")
    by_id: dict[str, Mapping[str, Any]] = {}
    for index, value in enumerate(rows):
        if not isinstance(value, Mapping) or not isinstance(value.get("guardrail_id"), str):
            raise StandaloneEvaluationError(f"rulepack:guardrail_{index}_invalid")
        guardrail_id = value["guardrail_id"]
        if guardrail_id in by_id:
            raise StandaloneEvaluationError(
                f"rulepack:duplicate_guardrail_id:{guardrail_id}"
            )
        by_id[guardrail_id] = value
    if set(by_id) != set(EXPECTED_INTERNAL_GUARDRAIL_SEMANTICS):
        raise StandaloneEvaluationError("rulepack:guardrail_id_set_invalid")
    for guardrail_id, required_semantics in EXPECTED_INTERNAL_GUARDRAIL_SEMANTICS.items():
        value = by_id[guardrail_id]
        observed_semantics = {
            "scope": value.get("scope"),
            "parameters": value.get("parameters"),
        }
        if (
            value.get("classification") != "INTERNAL_QM_POLICY_NOT_PROVIDER_RULE"
            or value.get("status") != "PROPOSED_FOR_CALIBRATION"
            or canonical_sha256(observed_semantics)
            != canonical_sha256(required_semantics)
        ):
            raise StandaloneEvaluationError(
                f"rulepack:unsupported_guardrail_semantics:{guardrail_id}:"
                f"{canonical_sha256(observed_semantics)}"
            )

    def row(guardrail_id: str) -> Mapping[str, Any]:
        value = by_id.get(guardrail_id)
        if not isinstance(value, Mapping) or not isinstance(value.get("parameters"), Mapping):
            raise StandaloneEvaluationError(f"rulepack:guardrail_missing:{guardrail_id}")
        if (
            value.get("classification") != "INTERNAL_QM_POLICY_NOT_PROVIDER_RULE"
            or value.get("status") != "PROPOSED_FOR_CALIBRATION"
        ):
            raise StandaloneEvaluationError(
                f"rulepack:guardrail_classification_invalid:{guardrail_id}"
            )
        return value

    phase1 = row("qm_ftmo_phase1_target_capture_buffer")["parameters"]
    phase2 = row("qm_ftmo_phase2_target_capture_buffer")["parameters"]

    def exact_bool(parameters: Mapping[str, Any], key: str) -> bool:
        value = parameters.get(key)
        if not isinstance(value, bool):
            raise StandaloneEvaluationError(f"rulepack:{key}:not_boolean")
        return value

    observed = {
        "phase1_capture_balance": _finite(
            phase1.get("capture_equity_usd"), "rulepack:phase1_capture_balance"
        ),
        "phase1_official_pass_balance_exclusive": _finite(
            phase1.get("official_pass_balance_usd_exclusive"),
            "rulepack:phase1_official_pass_balance",
        ),
        "phase2_capture_balance": _finite(
            phase2.get("capture_equity_usd"), "rulepack:phase2_capture_balance"
        ),
        "phase2_official_pass_balance_exclusive": _finite(
            phase2.get("official_pass_balance_usd_exclusive"),
            "rulepack:phase2_official_pass_balance",
        ),
        "phase2_maximum_phase1_risk_multiplier": _finite(
            phase2.get("maximum_phase1_risk_multiplier"),
            "rulepack:phase2_risk_multiplier",
        ),
        "phase1_cancel_pending_orders": exact_bool(phase1, "cancel_pending_orders"),
        "phase1_flatten_positions": exact_bool(phase1, "flatten_positions"),
        "phase2_cancel_pending_orders": exact_bool(phase2, "cancel_pending_orders"),
        "phase2_flatten_positions": exact_bool(phase2, "flatten_positions"),
    }
    required = {
        "phase1_capture_balance": PHASE1_CAPTURE_BALANCE,
        "phase1_official_pass_balance_exclusive": PHASE1_TARGET,
        "phase2_capture_balance": PHASE2_CAPTURE_BALANCE,
        "phase2_official_pass_balance_exclusive": PHASE2_TARGET,
        "phase2_maximum_phase1_risk_multiplier": PHASE2_RISK_MULTIPLIER,
        "phase1_cancel_pending_orders": True,
        "phase1_flatten_positions": True,
        "phase2_cancel_pending_orders": True,
        "phase2_flatten_positions": True,
    }
    if observed != required:
        raise StandaloneEvaluationError(
            "rulepack:unsupported_internal_policy:" + canonical_sha256(observed)
        )
    return {
        **observed,
        "classification": "INTERNAL_QM_POLICY_NOT_PROVIDER_RULE",
        "status": "PROPOSED_FOR_CALIBRATION",
        "validated_guardrail_ids": sorted(by_id),
        "validated_semantics_scope": "classification+status+scope+parameters",
    }


def _evaluation_and_deployment_contract(rulepack: Mapping[str, Any]) -> dict[str, Any]:
    profile = rulepack.get("evaluation_profile")
    if not isinstance(profile, Mapping) or set(profile) != {
        "objective",
        "metrics",
        "go_criteria",
    }:
        raise StandaloneEvaluationError("rulepack:evaluation_profile_field_set_invalid")
    if profile.get("objective") != EXPECTED_EVALUATION_OBJECTIVE:
        raise StandaloneEvaluationError("rulepack:evaluation_objective_invalid")

    def exact_rows(
        raw: Any,
        *,
        id_key: str,
        expected: Mapping[str, Mapping[str, Any]],
        label: str,
    ) -> dict[str, Mapping[str, Any]]:
        if not isinstance(raw, list):
            raise StandaloneEvaluationError(f"rulepack:{label}_missing")
        indexed: dict[str, Mapping[str, Any]] = {}
        for index, row in enumerate(raw):
            if not isinstance(row, Mapping) or not isinstance(row.get(id_key), str):
                raise StandaloneEvaluationError(f"rulepack:{label}_{index}_invalid")
            row_id = row[id_key]
            if row_id in indexed:
                raise StandaloneEvaluationError(f"rulepack:duplicate_{id_key}:{row_id}")
            indexed[row_id] = row
        if set(indexed) != set(expected):
            raise StandaloneEvaluationError(f"rulepack:{label}_id_set_invalid")
        for row_id, required in expected.items():
            observed = {key: indexed[row_id].get(key) for key in required}
            if set(indexed[row_id]) != {id_key, *required} or canonical_sha256(
                observed
            ) != canonical_sha256(required):
                raise StandaloneEvaluationError(
                    f"rulepack:{label}_semantics_invalid:{row_id}"
                )
        return indexed

    metrics = exact_rows(
        profile.get("metrics"),
        id_key="metric_id",
        expected=EXPECTED_METRIC_SEMANTICS,
        label="metric",
    )
    criteria = exact_rows(
        profile.get("go_criteria"),
        id_key="criterion_id",
        expected=EXPECTED_GO_CRITERION_SEMANTICS,
        label="criterion",
    )
    if set(metrics) & set(criteria):
        raise StandaloneEvaluationError("rulepack:metric_criterion_ids_not_disjoint")

    deployment = rulepack.get("deployment_boundary")
    if (
        not isinstance(deployment, Mapping)
        or set(deployment) != set(EXPECTED_DEPLOYMENT_BOUNDARY)
        or canonical_sha256(deployment)
        != canonical_sha256(EXPECTED_DEPLOYMENT_BOUNDARY)
        or any(
            value is not False
            for key, value in deployment.items()
            if key.endswith("action_authorized")
        )
    ):
        raise StandaloneEvaluationError("rulepack:deployment_boundary_invalid")
    return {
        "metric_ids": sorted(metrics),
        "go_criterion_ids": sorted(criteria),
        "metric_criterion_ids_disjoint": True,
        "deployment_boundary": dict(deployment),
        "semantic_scope": "complete evaluation-profile rows and deployment boundary",
    }


def _cost_rows(
    snapshot: Mapping[str, Any],
    *,
    now_utc: dt.datetime,
    maximum_age_days: int,
) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    def json_number(value: Any, label: str) -> float:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise StandaloneEvaluationError(f"{label}:not_json_number")
        return _finite(value, label)

    if snapshot.get("schema") != COST_SNAPSHOT_SCHEMA:
        raise StandaloneEvaluationError("cost_snapshot:unexpected_schema")
    source = snapshot.get("source")
    if not isinstance(source, Mapping):
        raise StandaloneEvaluationError("cost_snapshot:source_missing")
    if source.get("authority") != "OFFICIAL_PROVIDER":
        raise StandaloneEvaluationError("cost_snapshot:source_not_official")
    if source.get("api_url") != "https://ftmo.com/wp-json/ftmo/symbols":
        raise StandaloneEvaluationError("cost_snapshot:unexpected_api_url")
    if source.get("http_status") != 200 or isinstance(source.get("http_status"), bool):
        raise StandaloneEvaluationError("cost_snapshot:http_status_not_200")
    response_sha = str(source.get("response_sha256") or "").lower()
    if not SHA256_RE.fullmatch(response_sha):
        raise StandaloneEvaluationError("cost_snapshot:response_sha256_invalid")
    if response_sha != EXPECTED_COST_RESPONSE_SHA256:
        raise StandaloneEvaluationError("cost_snapshot:unexpected_response_sha256")
    rollover_offset = _integer(
        source.get("platform_utc_offset_hours"),
        "cost_snapshot:platform_utc_offset_hours",
    )
    if not -12 <= rollover_offset <= 14:
        raise StandaloneEvaluationError("cost_snapshot:platform_utc_offset_out_of_range")
    retrieved = _parse_utc(snapshot.get("retrieved_at_utc"), "cost_snapshot")
    inferred_offset = joint.us_dst_broker_wall_offset_hours(pd.Timestamp(retrieved))
    if rollover_offset != inferred_offset:
        raise StandaloneEvaluationError(
            "cost_snapshot:platform_offset_inconsistent_with_us_dst_broker_wall"
        )
    if retrieved > now_utc + dt.timedelta(minutes=5):
        raise StandaloneEvaluationError("cost_snapshot:future_timestamp")
    age = now_utc - retrieved
    if age > dt.timedelta(days=maximum_age_days):
        raise StandaloneEvaluationError(
            f"cost_snapshot:stale:age_seconds={int(age.total_seconds())}"
        )
    authorization = snapshot.get("authorization")
    if (
        not isinstance(authorization, Mapping)
        or set(authorization) != set(EXPECTED_COST_AUTHORIZATION)
        or canonical_sha256(authorization)
        != canonical_sha256(EXPECTED_COST_AUTHORIZATION)
    ):
        raise StandaloneEvaluationError("cost_snapshot:authorization_not_research_only")

    raw_rows = snapshot.get("book3_normalization")
    if not isinstance(raw_rows, list):
        raise StandaloneEvaluationError("cost_snapshot:book3_normalization_missing")
    normalized: dict[str, dict[str, Any]] = {}
    provider_symbols: set[str] = set()
    for index, row in enumerate(raw_rows):
        if not isinstance(row, Mapping):
            raise StandaloneEvaluationError(f"cost_snapshot:row_{index}_invalid")
        symbol = str(row.get("dwx_symbol") or "").upper()
        provider_symbol = str(row.get("provider_symbol") or "")
        if not symbol or symbol in normalized or not provider_symbol:
            raise StandaloneEvaluationError(f"cost_snapshot:row_{index}_identity_invalid")
        if provider_symbol in provider_symbols:
            raise StandaloneEvaluationError(f"cost_snapshot:provider_symbol_duplicate:{provider_symbol}")
        provider_symbols.add(provider_symbol)
        target_contract = json_number(
            row.get("target_contract_size"), f"cost_snapshot:{symbol}:target_contract_size"
        )
        source_contract = json_number(
            row.get("source_contract_size"), f"cost_snapshot:{symbol}:source_contract_size"
        )
        if target_contract <= 0.0 or source_contract <= 0.0:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:contract_size_not_positive")
        if source_contract != EXPECTED_SOURCE_CONTRACT_SIZES.get(symbol):
            raise StandaloneEvaluationError(
                f"cost_snapshot:{symbol}:source_contract_size_mismatch"
            )
        digits = _integer(row.get("digits"), f"cost_snapshot:{symbol}:digits")
        if digits < 0:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:digits_invalid")
        cost = {
            "commission_percent_per_side": json_number(
                row.get("commission_percent_per_side"),
                f"cost_snapshot:{symbol}:commission_percent_per_side",
            ),
            "flat_round_trip_commission_per_lot": json_number(
                row.get("flat_round_trip_commission_per_lot"),
                f"cost_snapshot:{symbol}:flat_round_trip_commission_per_lot",
            ),
            "swap_long_points": json_number(
                row.get("swap_long_points"), f"cost_snapshot:{symbol}:swap_long_points"
            ),
            "swap_short_points": json_number(
                row.get("swap_short_points"), f"cost_snapshot:{symbol}:swap_short_points"
            ),
            "contract_size": target_contract,
            "source_contract_size": source_contract,
            "profit_currency_to_account_rate": json_number(
                row.get("profit_currency_to_account_rate"),
                f"cost_snapshot:{symbol}:profit_currency_to_account_rate",
            ),
            "derive_profit_currency_rate_from_pnl": row.get(
                "derive_profit_currency_rate_from_pnl", False
            ),
            "digits": digits,
            "triple_weekday": _integer(
                row.get("triple_weekday", 2), f"cost_snapshot:{symbol}:triple_weekday"
            ),
            "provider_symbol": provider_symbol,
            "commission_model": str(row.get("commission_model") or ""),
            "rollover_timezone": "US_DST_GMT_PLUS_2_PLUS_3",
            "snapshot_platform_utc_offset_hours": rollover_offset,
        }
        if not isinstance(cost["derive_profit_currency_rate_from_pnl"], bool):
            raise StandaloneEvaluationError(
                f"cost_snapshot:{symbol}:derive_profit_currency_rate_not_bool"
            )
        if cost["commission_percent_per_side"] < 0.0:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:negative_commission")
        if cost["flat_round_trip_commission_per_lot"] < 0.0:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:negative_flat_commission")
        if cost["profit_currency_to_account_rate"] <= 0.0:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:account_rate_not_positive")
        if cost["triple_weekday"] != 2:
            raise StandaloneEvaluationError(f"cost_snapshot:{symbol}:triple_weekday_invalid")
        if symbol == "USDJPY.DWX":
            if (
                cost["derive_profit_currency_rate_from_pnl"] is not True
                or not 0.001 <= cost["profit_currency_to_account_rate"] <= 0.1
                or cost["profit_currency_to_account_rate"] == 1.0
            ):
                raise StandaloneEvaluationError(
                    f"cost_snapshot:{symbol}:profit_currency_rate_contract_invalid"
                )
        elif (
            cost["derive_profit_currency_rate_from_pnl"] is not False
            or cost["profit_currency_to_account_rate"] != 1.0
        ):
            raise StandaloneEvaluationError(
                f"cost_snapshot:{symbol}:profit_currency_rate_contract_invalid"
            )
        normalized[symbol] = cost

    expected_symbols = {symbol for _, symbol, _ in EXPECTED_BOOK.values()}
    if set(normalized) != expected_symbols:
        raise StandaloneEvaluationError(
            f"cost_snapshot:book_symbols_mismatch:{sorted(normalized)}"
        )
    for symbol, required in EXPECTED_COST_MATRIX.items():
        observed = {key: normalized[symbol].get(key) for key in required}
        if observed != required:
            raise StandaloneEvaluationError(
                f"cost_snapshot:{symbol}:absolute_cost_matrix_mismatch"
            )
    for _, symbol, provider_symbol in EXPECTED_BOOK.values():
        if normalized[symbol]["provider_symbol"] != provider_symbol:
            raise StandaloneEvaluationError(
                f"cost_snapshot:{symbol}:provider_symbol_mismatch"
            )
    provider_rows = snapshot.get("selected_provider_rows")
    if not isinstance(provider_rows, list):
        raise StandaloneEvaluationError("cost_snapshot:selected_provider_rows_missing")
    selected: dict[str, Mapping[str, Any]] = {}
    for index, row in enumerate(provider_rows):
        if not isinstance(row, Mapping):
            raise StandaloneEvaluationError(
                f"cost_snapshot:selected_provider_row_{index}_invalid"
            )
        code = row.get("code")
        if not isinstance(code, str) or not code or code in selected:
            raise StandaloneEvaluationError(
                f"cost_snapshot:selected_provider_row_{index}_identity_invalid"
            )
        selected[code] = row
    expected_provider_symbols = {provider for _, _, provider in EXPECTED_BOOK.values()}
    if set(selected) != expected_provider_symbols:
        raise StandaloneEvaluationError("cost_snapshot:selected_provider_symbol_set_mismatch")
    expected_models = {
        "USDJPY.DWX": "flat_round_trip_per_target_lot_usd",
        "XAUUSD.DWX": "percent_of_notional_per_side",
        "XTIUSD.DWX": "commission_free",
    }
    expected_asset_classes = {
        "USDJPY.DWX": "Forex",
        "XAUUSD.DWX": "Metals CFD",
        "XTIUSD.DWX": "Cash CFD",
    }
    for _rung, (_ea_id, symbol, provider_symbol) in EXPECTED_BOOK.items():
        cost = normalized[symbol]
        provider = selected[provider_symbol]
        label = f"cost_snapshot:{symbol}:provider_crosswalk"
        provider_contract = json_number(provider.get("contractSize"), f"{label}:contractSize")
        provider_commission = json_number(provider.get("commission"), f"{label}:commission")
        provider_swap_long = json_number(provider.get("swapLong"), f"{label}:swapLong")
        provider_swap_short = json_number(provider.get("swapShort"), f"{label}:swapShort")
        provider_digits = _integer(provider.get("digits"), f"{label}:digits")
        provider_type = provider.get("commissionType")
        if (
            provider.get("active") is not True
            or provider.get("swapType") != "points"
            or provider.get("profitCurrency")
            != EXPECTED_PROVIDER_PROFIT_CURRENCIES[symbol]
            or provider.get("assetClass") != expected_asset_classes[symbol]
        ):
            raise StandaloneEvaluationError(f"{label}:provider_state_or_swap_type_invalid")
        observed_provider = {
            "active": provider.get("active"),
            "assetClass": provider.get("assetClass"),
            "commission": provider_commission,
            "commissionType": provider_type,
            "contractSize": provider_contract,
            "digits": provider_digits,
            "profitCurrency": provider.get("profitCurrency"),
            "swapLong": provider_swap_long,
            "swapShort": provider_swap_short,
            "swapType": provider.get("swapType"),
        }
        if observed_provider != EXPECTED_PROVIDER_COST_MATRIX[provider_symbol]:
            raise StandaloneEvaluationError(f"{label}:absolute_provider_matrix_mismatch")
        if (
            provider_contract != cost["contract_size"]
            or provider_swap_long != cost["swap_long_points"]
            or provider_swap_short != cost["swap_short_points"]
            or provider_digits != cost["digits"]
            or cost["commission_model"] != expected_models[symbol]
        ):
            raise StandaloneEvaluationError(f"{label}:normalized_fields_mismatch")
        if cost["commission_model"] == "flat_round_trip_per_target_lot_usd":
            valid_commission = (
                provider_type == "flat_USD"
                and cost["flat_round_trip_commission_per_lot"] == provider_commission
                and cost["commission_percent_per_side"] == 0.0
            )
        elif cost["commission_model"] == "percent_of_notional_per_side":
            valid_commission = (
                provider_type == "percent"
                and cost["commission_percent_per_side"] == provider_commission
                and cost["flat_round_trip_commission_per_lot"] == 0.0
                and provider_commission > 0.0
            )
        else:
            valid_commission = (
                provider_type == "percent"
                and provider_commission == 0.0
                and cost["commission_percent_per_side"] == 0.0
                and cost["flat_round_trip_commission_per_lot"] == 0.0
            )
        if not valid_commission:
            raise StandaloneEvaluationError(f"{label}:commission_model_mismatch")
    return normalized, {
        "retrieved_at_utc": retrieved.isoformat().replace("+00:00", "Z"),
        "age_seconds": int(max(0.0, age.total_seconds())),
        "maximum_age_days": maximum_age_days,
        "source_api_url": source["api_url"],
        "source_response_sha256": response_sha,
        "provider_rollover_utc_offset_hours": rollover_offset,
        "provider_rollover_timezone_contract": (
            "US_DST_GMT_PLUS_2_PLUS_3_VALIDATED_AGAINST_DATED_PLATFORM_OFFSET"
        ),
        "raw_response_local_binding": "NOT_AVAILABLE_SNAPSHOT_HASH_ATTESTATION_ONLY",
    }


def _qualification_status(
    document: Mapping[str, Any],
    expected: Mapping[str, tuple[int, str, str]] = EXPECTED_BOOK,
) -> dict[str, Any]:
    if document.get("schema") != "qm.ftmo-book3-strict-qualification-assessment/v1":
        raise StandaloneEvaluationError("qualification:unsupported_artifact_schema")
    if (
        document.get("book_id") != BOOK_ID
        or document.get("status") != "UNVERIFIED"
        or document.get("authority") != "RESEARCH_INPUT_ONLY"
        or document.get("partial_book_approval") is not False
    ):
        raise StandaloneEvaluationError("qualification:research_boundary_invalid")
    _parse_utc(document.get("as_of_utc"), "qualification:as_of_utc")
    authorization = document.get("authorization")
    if (
        not isinstance(authorization, Mapping)
        or set(authorization) != set(EXPECTED_QUALIFICATION_AUTHORIZATION)
        or canonical_sha256(authorization)
        != canonical_sha256(EXPECTED_QUALIFICATION_AUTHORIZATION)
    ):
        raise StandaloneEvaluationError("qualification:authorization_not_fail_closed")
    candidate_rows = document.get("candidates")
    if not isinstance(candidate_rows, list) or len(candidate_rows) != len(expected):
        raise StandaloneEvaluationError("qualification:candidate_set_invalid")
    rows: dict[tuple[int, str], Mapping[str, Any]] = {}
    for index, row in enumerate(candidate_rows):
        if not isinstance(row, Mapping):
            raise StandaloneEvaluationError(f"qualification:candidate_{index}_invalid")
        key = (
            _ea_identifier(row.get("ea_id"), f"qualification:candidate_{index}:ea_id"),
            str(row.get("symbol") or "").upper(),
        )
        if key in rows:
            raise StandaloneEvaluationError("qualification:candidate_duplicate")
        if row.get("challenge_ready") is not False:
            raise StandaloneEvaluationError("qualification:ready_claim_forbidden")
        state_token = str(row.get("state") or "").strip().upper()
        verdict_token = str(row.get("q08_verdict") or "").strip().upper()
        if state_token == "READY" or state_token.endswith("_READY") or verdict_token in {
            "READY",
            "PASS",
        }:
            raise StandaloneEvaluationError("qualification:contradictory_ready_string")
        blockers = row.get("blockers")
        if (
            not isinstance(row.get("state"), str)
            or not row.get("state")
            or not isinstance(row.get("q08_verdict"), str)
            or not row.get("q08_verdict")
            or not isinstance(blockers, list)
            or not blockers
            or any(not isinstance(value, str) or not value for value in blockers)
        ):
            raise StandaloneEvaluationError(f"qualification:candidate_{index}_evidence_invalid")
        rows[key] = row

    expected_keys = {(ea_id, symbol) for ea_id, symbol, _provider in expected.values()}
    if set(rows) != expected_keys:
        raise StandaloneEvaluationError("qualification:candidate_identity_set_mismatch")
    global_blockers = document.get("global_blockers")
    if (
        not isinstance(global_blockers, list)
        or not global_blockers
        or any(not isinstance(value, str) or not value for value in global_blockers)
    ):
        raise StandaloneEvaluationError("qualification:global_blockers_invalid")

    sleeves: list[dict[str, Any]] = []
    for rung, (ea_id, symbol, _provider) in expected.items():
        row = rows.get((ea_id, symbol))
        assert row is not None
        sleeves.append(
            {
                "rung": rung,
                "ea_id": ea_id,
                "symbol": symbol,
                "challenge_ready": False,
                "state": row["state"],
                "blockers": list(row["blockers"]),
                "q08_verdict": row["q08_verdict"],
            }
        )
    return {
        "status": "UNVERIFIED",
        "source_schema": document["schema"],
        "source_status": "UNVERIFIED",
        "authority": "RESEARCH_INPUT_ONLY",
        "global_blockers": list(global_blockers),
        "partial_book_approval": False,
        "reported_ready_count": 0,
        "sleeve_count": len(sleeves),
        "sleeves": sleeves,
        "simulation_cannot_override": True,
        "ready_state_permitted": False,
    }


def _strategy_identity_from_receipt(
    preflight: Mapping[str, Any],
    *,
    label: str,
) -> dict[str, Any]:
    raw_artifacts = preflight.get("artifacts")
    if not isinstance(raw_artifacts, list) or len(raw_artifacts) != 3:
        raise StandaloneEvaluationError(f"{label}:strategy_artifacts_missing")
    artifacts: dict[str, dict[str, Any]] = {}
    for raw in raw_artifacts:
        if not isinstance(raw, Mapping):
            raise StandaloneEvaluationError(f"{label}:strategy_artifact_invalid")
        role = str(raw.get("role") or "")
        if role not in {"setfile", "staged_ex5", "mq5"} or role in artifacts:
            raise StandaloneEvaluationError(f"{label}:strategy_artifact_role_invalid:{role}")
        expected = str(raw.get("expected_sha256") or "").lower()
        actual = str(raw.get("actual_sha256") or "").lower()
        path_token = raw.get("path")
        if (
            raw.get("valid") is not True
            or not isinstance(path_token, str)
            or not Path(path_token).is_absolute()
            or not SHA256_RE.fullmatch(expected)
            or actual != expected
        ):
            raise StandaloneEvaluationError(f"{label}:strategy_artifact_not_bound:{role}")
        path = Path(path_token)
        if not path.is_file():
            raise StandaloneEvaluationError(f"{label}:strategy_artifact_missing:{role}:{path}")
        current = sha256_file(path)
        if current != expected:
            raise StandaloneEvaluationError(
                f"{label}:strategy_artifact_sha256_drift:{role}:"
                f"expected={expected}:actual={current}"
            )
        stat = path.stat()
        artifacts[role] = {
            "path": str(path.resolve()),
            "sha256": current,
            "bytes": stat.st_size,
            "file_identity": {"device": stat.st_dev, "inode": stat.st_ino},
        }
    if set(artifacts) != {"setfile", "staged_ex5", "mq5"}:
        raise StandaloneEvaluationError(f"{label}:strategy_artifact_set_invalid")

    source = preflight.get("source_binding")
    tree = source.get("framework_include_tree") if isinstance(source, Mapping) else None
    if (
        not isinstance(tree, Mapping)
        or not SHA256_RE.fullmatch(str(tree.get("expected_sha256") or ""))
        or tree.get("expected_sha256") != tree.get("actual_sha256")
        or not isinstance(tree.get("file_count"), int)
        or tree.get("file_count") <= 0
    ):
        raise StandaloneEvaluationError(f"{label}:framework_include_tree_invalid")
    return {
        "artifacts": artifacts,
        "framework_include_tree_sha256": tree["actual_sha256"],
        "framework_include_tree_file_count": tree["file_count"],
        "identity_scope": (
            "receipt-authenticated and currently rehashed MQ5/setfile/staged-EX5; "
            "receipt-authenticated run-time framework include-tree fingerprint"
        ),
    }


def _utc_timestamp(value: Any, label: str) -> dt.datetime:
    if not isinstance(value, str) or not (
        value.endswith("Z") or value.endswith("+00:00")
    ):
        raise StandaloneEvaluationError(f"{label}:timestamp_not_explicit_utc")
    return _parse_utc(value, label)


def _validate_hold_row(
    raw: Any,
    *,
    work_item_id: str,
    hold_code: str,
    hold_reason: str,
    label: str,
) -> dict[str, Any]:
    if not isinstance(raw, Mapping) or set(raw) != HOLD_FIELDS:
        raise StandaloneEvaluationError(f"{label}:hold_field_set_invalid")
    if (
        raw.get("work_item_id") != work_item_id
        or raw.get("hold_code") != hold_code
        or raw.get("reason") != hold_reason
        or type(raw.get("active")) is not int
        or raw.get("active") != 1
        or type(raw.get("release_on_restart")) is not int
        or raw.get("release_on_restart") != 0
        or raw.get("released_at") is not None
        or raw.get("release_note") is not None
    ):
        raise StandaloneEvaluationError(f"{label}:hold_state_invalid")
    created = _utc_timestamp(raw.get("created_at"), f"{label}:created_at")
    updated = _utc_timestamp(raw.get("updated_at"), f"{label}:updated_at")
    if updated < created:
        raise StandaloneEvaluationError(f"{label}:hold_timestamp_order_invalid")
    return dict(raw)


def _validate_diagnostic_hold(
    raw: Any,
    *,
    current_work_item_id: str,
    preflight_hold: Any,
    label: str,
) -> dict[str, Any]:
    required = {"requested", "valid", "errors", "pre_hold", "post_hold"}
    if not isinstance(raw, Mapping) or set(raw) != required:
        raise StandaloneEvaluationError(f"{label}:diagnostic_hold_field_set_invalid")
    if raw.get("requested") is not True or raw.get("valid") is not True or raw.get("errors") != []:
        raise StandaloneEvaluationError(f"{label}:diagnostic_hold_envelope_invalid")
    pre_hold = _validate_hold_row(
        raw.get("pre_hold"),
        work_item_id=current_work_item_id,
        hold_code=DIAGNOSTIC_HOLD_CODE,
        hold_reason=DIAGNOSTIC_HOLD_REASON,
        label=f"{label}:pre",
    )
    post_hold = _validate_hold_row(
        raw.get("post_hold"),
        work_item_id=current_work_item_id,
        hold_code=DIAGNOSTIC_HOLD_CODE,
        hold_reason=DIAGNOSTIC_HOLD_REASON,
        label=f"{label}:post",
    )
    preflight = _validate_hold_row(
        preflight_hold,
        work_item_id=current_work_item_id,
        hold_code=DIAGNOSTIC_HOLD_CODE,
        hold_reason=DIAGNOSTIC_HOLD_REASON,
        label=f"{label}:preflight",
    )
    if pre_hold != post_hold or pre_hold != preflight:
        raise StandaloneEvaluationError(f"{label}:diagnostic_hold_changed")
    return {
        "pre_hold": pre_hold,
        "post_hold": post_hold,
        "hold_sha256": canonical_sha256(post_hold),
    }


def _validate_excluded_v2_r2(raw: Any, *, current_work_item_id: str, label: str) -> dict[str, Any]:
    if not isinstance(raw, Mapping):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_missing")
    required = {
        "id",
        "status",
        "verdict",
        "claimed_by",
        "evidence_path",
        "payload_sha256",
        "row",
        "row_sha256",
        "hold",
        "hold_sha256",
    }
    if set(raw) != required:
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_field_set_invalid")
    excluded_id = raw.get("id")
    if not isinstance(excluded_id, str) or not excluded_id or excluded_id == current_work_item_id:
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_id_invalid")
    if (
        raw.get("status") != "pending"
        or raw.get("verdict") is not None
        or raw.get("claimed_by") is not None
        or raw.get("evidence_path") is not None
    ):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_state_invalid")
    row = raw.get("row")
    if not isinstance(row, Mapping) or set(row) != EXCLUDED_V2_R2_ROW_FIELDS:
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_row_invalid")
    row_sha = str(raw.get("row_sha256") or "").lower()
    payload_sha = str(raw.get("payload_sha256") or "").lower()
    if (
        not SHA256_RE.fullmatch(row_sha)
        or row_sha != canonical_sha256(row)
        or not SHA256_RE.fullmatch(payload_sha)
    ):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_row_hash_invalid")
    payload_json = row.get("payload_json")
    if (
        not isinstance(payload_json, str)
        or hashlib.sha256(payload_json.encode("utf-8")).hexdigest() != payload_sha
    ):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_payload_hash_invalid")
    payload = _loads_strict_json(payload_json.encode("utf-8"), f"{label}:excluded_payload")
    if not isinstance(payload, Mapping) or (
        payload.get("measurement_contract") != LADDER_MEASUREMENT_CONTRACT
        or payload.get("measurement_rung") != "R2"
        or payload.get("measurement_sequence") != 4
        or str(payload.get("terminal") or "").upper() != "T10"
    ):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_payload_contract_invalid")
    if (
        row.get("id") != excluded_id
        or row.get("kind") != "backtest"
        or row.get("phase") != "Q02"
        or row.get("ea_id") != "QM5_13108"
        or str(row.get("symbol") or "").upper() != "XTIUSD.DWX"
        or row.get("status") != "pending"
        or row.get("verdict") is not None
        or row.get("attempt_count") != 0
        or row.get("parent_task_id") is not None
        or row.get("evidence_path") is not None
        or row.get("claimed_by") is not None
    ):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_row_state_invalid")
    row_created = _utc_timestamp(row.get("created_at"), f"{label}:row_created_at")
    row_updated = _utc_timestamp(row.get("updated_at"), f"{label}:row_updated_at")
    if row_updated < row_created:
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_row_timestamp_order_invalid")
    hold = raw.get("hold")
    hold_sha = str(raw.get("hold_sha256") or "").lower()
    if not isinstance(hold, Mapping):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_hold_missing")
    if not SHA256_RE.fullmatch(hold_sha) or hold_sha != canonical_sha256(hold):
        raise StandaloneEvaluationError(f"{label}:excluded_v2_r2_hold_hash_invalid")
    _validate_hold_row(
        hold,
        work_item_id=excluded_id,
        hold_code=EXCLUDED_V2_R2_HOLD_CODE,
        hold_reason=EXCLUDED_V2_R2_HOLD_REASON,
        label=f"{label}:excluded_v2_r2",
    )
    return dict(raw)


def _validate_runner_receipt(
    receipt: Mapping[str, Any],
    *,
    rung: str,
    ea_id: int,
    symbol: str,
    work_item_id: str,
    summary_path: Path,
    summary_sha256: str,
    stream_path: Path,
    stream_sha256: str,
    stream_bytes: int,
    stream_lines_expected: int,
    source_commit: str,
) -> dict[str, Any]:
    prefix = f"receipt:{rung}"
    if rung == "R2" and (
        type(receipt.get("schema_version")) is not int
        or receipt.get("schema_version") != 1
        or receipt.get("mode") != "apply"
        or type(receipt.get("worker_exit_code")) is not int
        or receipt.get("worker_exit_code") != 0
    ):
        raise StandaloneEvaluationError(f"{prefix}:envelope_contract_invalid")
    preflight_value = receipt.get("preflight")
    preflight = preflight_value if isinstance(preflight_value, Mapping) else {}
    payload_value = receipt.get("payload_contract_revalidation")
    payload = payload_value if isinstance(payload_value, Mapping) else {}
    input_value = receipt.get("post_execution_inputs")
    post_inputs = input_value if isinstance(input_value, Mapping) else {}
    runtime_value = receipt.get("post_runtime_sources")
    post_runtime = runtime_value if isinstance(runtime_value, Mapping) else {}
    quiescence_value = receipt.get("post_run_quiescence")
    post_quiescence = quiescence_value if isinstance(quiescence_value, Mapping) else {}
    required_true = {
        "success": receipt.get("success"),
        "preflight.valid": preflight.get("valid"),
        "payload_contract_revalidation.valid": payload.get("valid"),
        "post_execution_inputs.valid": post_inputs.get("valid"),
        "post_runtime_sources.valid": post_runtime.get("valid"),
        "post_run_quiescence.valid": post_quiescence.get("valid"),
    }
    failed = [name for name, value in required_true.items() if value is not True]
    if failed:
        raise StandaloneEvaluationError(f"{prefix}:required_checks_failed:{','.join(failed)}")
    success_checks = receipt.get("success_checks")
    expected_success_keys = (
        DIAGNOSTIC_SUCCESS_CHECK_KEYS if rung == "R2" else BASE_SUCCESS_CHECK_KEYS
    )
    if (
        not isinstance(success_checks, Mapping)
        or set(success_checks) != expected_success_keys
        or any(success_checks.get(key) is not True for key in expected_success_keys)
    ):
        raise StandaloneEvaluationError(f"{prefix}:success_checks_keyset_or_value_mismatch")
    if receipt.get("state") != "completed" or receipt.get("terminal") != "T10":
        raise StandaloneEvaluationError(f"{prefix}:state_or_terminal_invalid")
    containment = receipt.get("process_tree_containment")
    if not isinstance(containment, Mapping) or containment.get("valid") is not True:
        raise StandaloneEvaluationError(f"{prefix}:process_tree_containment_invalid")
    if post_quiescence.get("after") != []:
        raise StandaloneEvaluationError(f"{prefix}:post_run_process_census_not_empty")
    if str(receipt.get("work_item_id") or "") != work_item_id:
        raise StandaloneEvaluationError(f"{prefix}:work_item_id_mismatch")
    post_item = receipt.get("post_work_item")
    if not isinstance(post_item, Mapping):
        raise StandaloneEvaluationError(f"{prefix}:post_work_item_missing")
    if (
        post_item.get("status") != "done"
        or post_item.get("verdict") != "PASS"
        or str(post_item.get("id") or "") != work_item_id
    ):
        raise StandaloneEvaluationError(f"{prefix}:post_work_item_not_pass")

    work_core = preflight.get("work_core")
    core = work_core.get("core") if isinstance(work_core, Mapping) else None
    if not isinstance(work_core, Mapping) or not isinstance(core, Mapping):
        raise StandaloneEvaluationError(f"{prefix}:work_core_missing")
    core_ea_id = _ea_identifier(core.get("ea_id"), f"{prefix}:work_core:ea_id")
    if rung == "R2":
        if (
            work_core.get("requested") is not True
            or work_core.get("valid") is not True
            or work_core.get("diagnostic") is not True
            or work_core.get("diagnostic_code") != DIAGNOSTIC_CODE
            or "rung" in work_core
            or core.get("diagnostic_code") != DIAGNOSTIC_CODE
            or core_ea_id != ea_id
            or str(core.get("symbol") or "").upper() != symbol
            or core.get("period") != "D1"
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_work_core_mismatch")
    elif (
        work_core.get("valid") is not True
        or work_core.get("diagnostic") is True
        or work_core.get("rung") != rung
        or core_ea_id != ea_id
        or str(core.get("symbol") or "").upper() != symbol
    ):
        raise StandaloneEvaluationError(f"{prefix}:ladder_work_core_mismatch")
    item = preflight.get("work_item")
    if not isinstance(item, Mapping):
        raise StandaloneEvaluationError(f"{prefix}:preflight_work_item_missing")
    item_ea_id = _ea_identifier(item.get("ea_id"), f"{prefix}:work_item:ea_id")
    if rung == "R2":
        if (
            item.get("measurement_contract") != DIAGNOSTIC_MEASUREMENT_CONTRACT
            or item.get("diagnostic_code") != DIAGNOSTIC_CODE
            or item.get("measurement_rung") is not None
            or item.get("measurement_sequence") is not None
            or item.get("evidence_run_id") is not None
            or str(item.get("symbol") or "").upper() != symbol
            or item_ea_id != ea_id
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_work_item_mismatch")
    else:
        expected_sequence = {"R0": 0, "R1": 2}[rung]
        pre_payload_contract = preflight.get("payload_contract")
        contract_hashes = (
            pre_payload_contract.get("pre_key_value_sha256")
            if isinstance(pre_payload_contract, Mapping)
            else None
        )
        contract_keys = (
            pre_payload_contract.get("pre_keys")
            if isinstance(pre_payload_contract, Mapping)
            else None
        )
        if (
            not isinstance(pre_payload_contract, Mapping)
            or pre_payload_contract.get("requested") is not True
            or pre_payload_contract.get("valid") is not True
            or not isinstance(contract_keys, list)
            or "measurement_contract" not in contract_keys
            or not isinstance(contract_hashes, Mapping)
            or contract_hashes.get("measurement_contract")
            != canonical_sha256(LADDER_MEASUREMENT_CONTRACT)
        ):
            raise StandaloneEvaluationError(
                f"{prefix}:historical_payload_measurement_contract_unproven"
            )
        if (
            item.get("measurement_contract") not in {None, LADDER_MEASUREMENT_CONTRACT}
            or item.get("diagnostic_code") is not None
            or item.get("measurement_rung") != rung
            or item.get("measurement_sequence") != expected_sequence
            or str(item.get("symbol") or "").upper() != symbol
            or item_ea_id != ea_id
        ):
            raise StandaloneEvaluationError(f"{prefix}:ladder_work_item_mismatch")
    source = preflight.get("source_binding")
    if not isinstance(source, Mapping) or source.get("valid") is not True:
        raise StandaloneEvaluationError(f"{prefix}:source_binding_invalid")
    if str(source.get("authoritative_source_commit") or "").lower() != source_commit:
        raise StandaloneEvaluationError(f"{prefix}:source_commit_mismatch")
    if (
        str(source.get("controller_head_commit") or "").lower() != source_commit
        or str(source.get("actual_head_commit") or "").lower() != source_commit
    ):
        raise StandaloneEvaluationError(f"{prefix}:observed_source_commit_mismatch")
    expected_contract = (
        DIAGNOSTIC_MEASUREMENT_CONTRACT if rung == "R2" else LADDER_MEASUREMENT_CONTRACT
    )
    observed_source_contract = source.get("measurement_contract")
    if (
        rung == "R2"
        and observed_source_contract != DIAGNOSTIC_MEASUREMENT_CONTRACT
    ) or (
        rung in {"R0", "R1"}
        and observed_source_contract not in {None, LADDER_MEASUREMENT_CONTRACT}
    ):
        raise StandaloneEvaluationError(f"{prefix}:source_measurement_contract_mismatch")

    post_fidelity = receipt.get("post_fidelity_receipt")
    if not isinstance(post_fidelity, Mapping) or post_fidelity.get("valid") is not True:
        raise StandaloneEvaluationError(f"{prefix}:post_fidelity_receipt_invalid")
    diagnostic_hold_binding: dict[str, Any] | None = None
    if rung == "R2":
        ladder = preflight.get("ladder_order")
        pre_fidelity = preflight.get("fidelity_receipt")
        post_compile = receipt.get("post_compile_binding")
        diagnostic_isolation = receipt.get("diagnostic_isolation")
        diagnostic_q08 = receipt.get("diagnostic_q08")
        diagnostic_hold_binding = _validate_diagnostic_hold(
            receipt.get("diagnostic_hold"),
            current_work_item_id=work_item_id,
            preflight_hold=preflight.get("hold"),
            label=f"{prefix}:diagnostic_hold",
        )
        if (
            not isinstance(ladder, Mapping)
            or ladder.get("requested") is not True
            or ladder.get("valid") is not True
            or ladder.get("diagnostic") is not True
            or ladder.get("errors") != []
            or ladder.get("rungs") != []
            or ladder.get("no_ladder_progression") is not True
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_ladder_isolation_invalid")
        pre_excluded = _validate_excluded_v2_r2(
            ladder.get("excluded_v2_r2"),
            current_work_item_id=work_item_id,
            label=f"{prefix}:preflight_isolation",
        )
        if (
            not isinstance(pre_fidelity, Mapping)
            or pre_fidelity.get("requested") is not True
            or pre_fidelity.get("valid") is not True
            or pre_fidelity.get("required") is not False
            or pre_fidelity.get("prohibited") is not True
            or pre_fidelity.get("errors") != []
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_fidelity_contract_invalid")
        if (
            set(post_fidelity) != {"requested", "required", "valid", "errors"}
            or post_fidelity.get("requested") is not True
            or post_fidelity.get("required") is not False
            or post_fidelity.get("valid") is not True
            or post_fidelity.get("errors") != []
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_post_fidelity_invalid")
        if not isinstance(post_compile, Mapping) or post_compile.get("valid") is not True:
            raise StandaloneEvaluationError(f"{prefix}:post_compile_binding_invalid")
        if (
            not isinstance(diagnostic_isolation, Mapping)
            or diagnostic_isolation.get("requested") is not True
            or diagnostic_isolation.get("valid") is not True
            or diagnostic_isolation.get("diagnostic") is not True
            or diagnostic_isolation.get("errors") != []
            or diagnostic_isolation.get("rungs") != []
            or diagnostic_isolation.get("no_ladder_progression") is not True
        ):
            raise StandaloneEvaluationError(f"{prefix}:post_diagnostic_isolation_invalid")
        post_excluded = _validate_excluded_v2_r2(
            diagnostic_isolation.get("excluded_v2_r2"),
            current_work_item_id=work_item_id,
            label=f"{prefix}:post_isolation",
        )
        if (
            post_excluded != pre_excluded
            or diagnostic_isolation.get("pre_excluded_v2_r2") != pre_excluded
        ):
            raise StandaloneEvaluationError(
                f"{prefix}:diagnostic_excluded_v2_r2_changed"
            )
        if (
            not isinstance(diagnostic_q08, Mapping)
            or diagnostic_q08.get("requested") is not True
            or diagnostic_q08.get("valid") is not True
            or diagnostic_q08.get("errors") != []
            or diagnostic_q08.get("money_basis") != FULL_LIFECYCLE_MONEY_BASIS
            or diagnostic_q08.get("magic") != 131080000
            or str(diagnostic_q08.get("symbol") or "").upper() != symbol
            or _positive_int(
                diagnostic_q08.get("selected_trade_count"),
                f"{prefix}:diagnostic_q08:selected_trade_count",
            )
            <= 0
            or not _same_path(diagnostic_q08.get("target"), stream_path)
            or str(diagnostic_q08.get("target_sha256") or "").lower() != stream_sha256
            or diagnostic_q08.get("target_bytes") != stream_bytes
            or diagnostic_q08.get("target_lines") != stream_lines_expected
        ):
            raise StandaloneEvaluationError(f"{prefix}:diagnostic_q08_invalid")

    evidence = receipt.get("post_evidence")
    if not isinstance(evidence, Mapping) or evidence.get("valid") is not True:
        raise StandaloneEvaluationError(f"{prefix}:post_evidence_invalid")
    if (
        not _same_path(evidence.get("path"), summary_path)
        or str(evidence.get("sha256") or "").lower() != summary_sha256
        or not _same_path(post_item.get("evidence_path"), summary_path)
    ):
        raise StandaloneEvaluationError(f"{prefix}:summary_binding_mismatch")
    stream = receipt.get("post_run_stream")
    harvested = stream.get("harvested") if isinstance(stream, Mapping) else None
    stream_lines = (
        _positive_int(harvested.get("lines"), f"{prefix}:stream_lines")
        if isinstance(harvested, Mapping)
        else None
    )
    if (
        not isinstance(stream, Mapping)
        or stream.get("valid") is not True
        or not isinstance(harvested, Mapping)
        or not _same_path(stream.get("target"), stream_path)
        or str(harvested.get("sha256") or "").lower() != stream_sha256
        or harvested.get("bytes") != stream_bytes
        or harvested.get("lines") != stream_lines_expected
        or stream_lines is None
    ):
        raise StandaloneEvaluationError(f"{prefix}:stream_binding_mismatch")
    completed = _parse_utc(receipt.get("completed_at_utc"), f"{prefix}:completed_at")
    strategy_identity = _strategy_identity_from_receipt(preflight, label=prefix)
    return {
        "work_item_id": work_item_id,
        "rung": rung,
        "ea_id": ea_id,
        "symbol": symbol,
        "terminal": "T10",
        "measurement_contract": expected_contract,
        "source_binding_measurement_contract_observed": observed_source_contract,
        "measurement_role": "STANDALONE_DIAGNOSTIC" if rung == "R2" else "V2_LADDER_RUNG",
        "source_commit": source_commit,
        "completed_at_utc": completed.isoformat().replace("+00:00", "Z"),
        "summary_sha256": summary_sha256,
        "stream_sha256": stream_sha256,
        "stream_lines": stream_lines,
        "strategy_identity": strategy_identity,
        "diagnostic_hold": diagnostic_hold_binding,
    }


def _validate_inputs(
    manifest: Mapping[str, Any],
    *,
    now_utc: dt.datetime,
    stager: ContentAddressedStager,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise StandaloneEvaluationError("manifest:unexpected_schema")
    if manifest.get("book_id") != BOOK_ID:
        raise StandaloneEvaluationError("manifest:unexpected_book_id")
    source_commit = str(manifest.get("source_commit") or "").lower()
    if not COMMIT_RE.fullmatch(source_commit):
        raise StandaloneEvaluationError("manifest:source_commit_invalid")
    if source_commit == R0_R1_AUTHORITATIVE_SOURCE_COMMIT:
        raise StandaloneEvaluationError("manifest:source_commit_must_include_diagnostic_contract")
    evaluator_source = _validate_evaluator_source(
        manifest.get("evaluator_source"), source_commit=source_commit
    )
    evidence_vintage = str(manifest.get("evidence_vintage") or "").strip()
    if not evidence_vintage:
        raise StandaloneEvaluationError("manifest:evidence_vintage_missing")
    if manifest.get("r2_purpose") != "FRESH_STANDALONE_DIAGNOSTIC_ONLY":
        raise StandaloneEvaluationError("manifest:r2_purpose_not_diagnostic")

    maximum_age_days = _positive_int(
        manifest.get("cost_snapshot_max_age_days", 7),
        "manifest:cost_snapshot_max_age_days",
    )
    if maximum_age_days > 30:
        raise StandaloneEvaluationError("manifest:cost_snapshot_max_age_days_too_large")
    cost_path, cost_input = _pinned_spec(
        manifest.get("cost_snapshot"),
        "cost_snapshot",
        default_path=DEFAULT_COST_SNAPSHOT_PATH,
        default_sha256=DEFAULT_COST_SNAPSHOT_SHA256,
    )
    staged_cost_path, cost_input = stager.stage(cost_path, cost_input, "cost_snapshot")
    cost_doc = _load_json(staged_cost_path, "cost_snapshot")
    if not isinstance(cost_doc, Mapping):
        raise StandaloneEvaluationError("cost_snapshot:not_object")
    costs, cost_freshness = _cost_rows(
        cost_doc,
        now_utc=now_utc,
        maximum_age_days=maximum_age_days,
    )

    rulepack_path, rulepack_input = _pinned_spec(
        manifest.get("rulepack"),
        "rulepack",
        default_path=DEFAULT_RULEPACK_PATH,
        default_sha256=DEFAULT_RULEPACK_SHA256,
    )
    staged_rulepack_path, rulepack_input = stager.stage(
        rulepack_path, rulepack_input, "rulepack"
    )
    rulepack_doc = _load_json(staged_rulepack_path, "rulepack")
    if not isinstance(rulepack_doc, Mapping):
        raise StandaloneEvaluationError("rulepack:not_object")
    snapshot_path = (REPO_ROOT / OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH).resolve()
    official_snapshot_path, official_snapshot_input = _pinned_spec(
        {
            "path": str(snapshot_path),
            "sha256": OFFICIAL_RULE_SNAPSHOT_SHA256,
        },
        "official_rule_snapshot",
    )
    staged_official_snapshot_path, official_snapshot_input = stager.stage(
        official_snapshot_path,
        official_snapshot_input,
        "official_rule_snapshot",
    )
    official_snapshot_doc = _load_json(
        staged_official_snapshot_path, "official_rule_snapshot"
    )
    if not isinstance(official_snapshot_doc, Mapping):
        raise StandaloneEvaluationError("official_rule_snapshot:not_object")
    official_sources = _validate_official_rule_sources(
        rulepack_doc, official_snapshot_doc, now_utc=now_utc
    )
    rules = _official_rules(rulepack_doc)
    internal_policy = _internal_policy(rulepack_doc)
    evaluation_contract = _evaluation_and_deployment_contract(rulepack_doc)

    qualification_path, qualification_input = _pinned_spec(
        manifest.get("qualification"), "qualification"
    )
    staged_qualification_path, qualification_input = stager.stage(
        qualification_path, qualification_input, "qualification"
    )
    qualification_doc = _load_json(staged_qualification_path, "qualification")
    if not isinstance(qualification_doc, Mapping):
        raise StandaloneEvaluationError("qualification:not_object")
    qualification = _qualification_status(qualification_doc)

    raw_sleeves = manifest.get("sleeves")
    if not isinstance(raw_sleeves, list) or len(raw_sleeves) != len(EXPECTED_BOOK):
        raise StandaloneEvaluationError("manifest:sleeves_must_be_exactly_three")
    by_rung: dict[str, Mapping[str, Any]] = {}
    for row in raw_sleeves:
        if not isinstance(row, Mapping):
            raise StandaloneEvaluationError("manifest:sleeve_not_object")
        rung = str(row.get("rung") or "")
        if rung in by_rung:
            raise StandaloneEvaluationError(f"manifest:duplicate_rung:{rung}")
        by_rung[rung] = row
    if set(by_rung) != set(EXPECTED_BOOK):
        raise StandaloneEvaluationError("manifest:rung_set_mismatch")

    timestamp_basis = str(manifest.get("timestamp_basis") or "")
    if timestamp_basis not in joint.VALID_TIMESTAMP_BASES:
        raise StandaloneEvaluationError("manifest:timestamp_basis_invalid")
    cases: list[dict[str, Any]] = []
    receipt_rows: list[dict[str, Any]] = []
    pinned_sleeves: list[dict[str, Any]] = []
    work_item_ids: set[str] = set()
    paths_seen: set[str] = set()
    include_tree_hashes: set[str] = set()
    for rung, (ea_id, symbol, provider_symbol) in EXPECTED_BOOK.items():
        raw = by_rung[rung]
        observed_ea = _ea_identifier(raw.get("ea_id"), f"manifest:{rung}:ea_id")
        if observed_ea != ea_id or str(raw.get("symbol") or "").upper() != symbol:
            raise StandaloneEvaluationError(f"manifest:{rung}:book_identity_mismatch")
        if _finite(raw.get("base_risk_fixed"), f"manifest:{rung}:base_risk_fixed") != 1000.0:
            raise StandaloneEvaluationError(f"manifest:{rung}:base_risk_must_equal_1000")
        if str(raw.get("provider_symbol") or "") != provider_symbol:
            raise StandaloneEvaluationError(f"manifest:{rung}:provider_symbol_mismatch")
        work_item_id = str(raw.get("work_item_id") or "").strip()
        if not work_item_id or work_item_id in work_item_ids:
            raise StandaloneEvaluationError(f"manifest:{rung}:work_item_id_invalid_or_duplicate")
        work_item_ids.add(work_item_id)
        sleeve_source_commit = str(raw.get("source_commit") or "").lower()
        if not COMMIT_RE.fullmatch(sleeve_source_commit):
            raise StandaloneEvaluationError(f"manifest:{rung}:source_commit_invalid")
        if (
            rung in {"R0", "R1"}
            and sleeve_source_commit != R0_R1_AUTHORITATIVE_SOURCE_COMMIT
        ):
            raise StandaloneEvaluationError(
                f"manifest:{rung}:historical_source_commit_mismatch"
            )
        if rung == "R2" and sleeve_source_commit != source_commit:
            raise StandaloneEvaluationError("manifest:R2:source_commit_not_evaluator_commit")

        receipt_path, receipt_input = _pinned_spec(raw.get("receipt"), f"{rung}:receipt")
        summary_path, summary_input = _pinned_spec(raw.get("summary"), f"{rung}:summary")
        stream_path, stream_input = _pinned_spec(raw.get("stream"), f"{rung}:stream")
        bar_path, bar_input = _pinned_spec(raw.get("m15"), f"{rung}:m15")
        report_path, report_input = _pinned_spec(raw.get("report"), f"{rung}:report")
        for artifact_path in (receipt_path, summary_path, stream_path, bar_path, report_path):
            normalized = _normalized_path(artifact_path)
            if normalized in paths_seen:
                raise StandaloneEvaluationError(f"manifest:{rung}:artifact_path_reused")
            paths_seen.add(normalized)
        staged_receipt_path, receipt_input = stager.stage(
            receipt_path, receipt_input, f"{rung}:receipt"
        )
        staged_summary_path, summary_input = stager.stage(
            summary_path, summary_input, f"{rung}:summary"
        )
        staged_stream_path, stream_input = stager.stage(
            stream_path, stream_input, f"{rung}:stream"
        )
        staged_bar_path, bar_input = stager.stage(bar_path, bar_input, f"{rung}:m15")
        staged_report_path, report_input = stager.stage(
            report_path, report_input, f"{rung}:report"
        )
        receipt_doc = _load_json(staged_receipt_path, f"{rung}:receipt")
        if not isinstance(receipt_doc, Mapping):
            raise StandaloneEvaluationError(f"{rung}:receipt:not_object")
        validated_receipt = _validate_runner_receipt(
            receipt_doc,
            rung=rung,
            ea_id=ea_id,
            symbol=symbol,
            work_item_id=work_item_id,
            summary_path=summary_path,
            summary_sha256=summary_input["sha256"],
            stream_path=stream_path,
            stream_sha256=stream_input["sha256"],
            stream_bytes=stream_input["bytes"],
            stream_lines_expected=_positive_int(
                stream_input.get("lines"), f"manifest:{rung}:stream_lines"
            ),
            source_commit=sleeve_source_commit,
        )
        receipt_rows.append(validated_receipt)
        strategy_identity = validated_receipt["strategy_identity"]
        staged_strategy_artifacts: dict[str, dict[str, Any]] = {}
        for role, artifact in strategy_identity["artifacts"].items():
            original_artifact = Path(str(artifact["path"]))
            _staged_artifact_path, staged_artifact = stager.stage(
                original_artifact, artifact, f"{rung}:strategy:{role}"
            )
            staged_strategy_artifacts[role] = staged_artifact
        strategy_identity = {
            **strategy_identity,
            "artifacts": staged_strategy_artifacts,
        }
        validated_receipt["strategy_identity"] = strategy_identity
        include_tree_hashes.add(strategy_identity["framework_include_tree_sha256"])
        summary_doc = _load_json(staged_summary_path, f"{rung}:summary")
        if not isinstance(summary_doc, Mapping):
            raise StandaloneEvaluationError(f"{rung}:summary:not_object")
        usable_runs = [
            run
            for run in summary_doc.get("runs") or []
            if isinstance(run, Mapping)
            and str(run.get("status") or "").upper() == "OK"
            and _integer(run.get("total_trades"), f"{rung}:summary:total_trades") > 0
        ]
        if not usable_runs:
            raise StandaloneEvaluationError(f"{rung}:summary:no_usable_run")
        selected_run = usable_runs[-1]
        if (
            not _same_path(selected_run.get("report_canonical_path"), report_path)
            or str(selected_run.get("report_sha256") or "").lower()
            != report_input["sha256"]
            or _positive_int(
                selected_run.get("report_size_bytes"), f"{rung}:summary:report_size_bytes"
            )
            != report_input["bytes"]
        ):
            raise StandaloneEvaluationError(f"{rung}:summary:report_binding_mismatch")
        case = {
            "ea_id": ea_id,
            "symbol": symbol,
            "summary_path": str(staged_summary_path),
            "stream_path": str(staged_stream_path),
            "bar_path": str(staged_bar_path),
            "report_path": str(staged_report_path),
            "base_risk_fixed": 1000.0,
            "cost": dict(costs[symbol]),
        }
        reconciliation = reconcile_case(
            ea_id,
            symbol,
            staged_summary_path,
            stream_path=staged_stream_path,
            report_path=staged_report_path,
        )
        if reconciliation.get("status") != "PASS":
            raise StandaloneEvaluationError(
                f"reconciliation:{rung}:FAIL:{','.join(reconciliation.get('reasons') or [])}"
            )
        case["reconciliation"] = reconciliation
        cases.append(case)
        pinned_sleeves.append(
            {
                "rung": rung,
                "ea_id": ea_id,
                "symbol": symbol,
                "provider_symbol": provider_symbol,
                "work_item_id": work_item_id,
                "source_commit": sleeve_source_commit,
                "receipt": receipt_input,
                "summary": summary_input,
                "stream": stream_input,
                "m15": bar_input,
                "report": report_input,
                "reconciliation": reconciliation,
                "cost_block_sha256": canonical_sha256(costs[symbol]),
                "strategy_identity": strategy_identity,
            }
        )

    if len(include_tree_hashes) != 1:
        raise StandaloneEvaluationError(
            "strategy_identity:framework_include_tree_differs_across_sleeves"
        )

    return cases, {
        "source_commit": source_commit,
        "evaluator_source": evaluator_source,
        "evidence_vintage": evidence_vintage,
        "timestamp_basis": timestamp_basis,
        "cost_snapshot": {**cost_input, **cost_freshness},
        "rulepack": rulepack_input,
        "official_rule_snapshot": official_snapshot_input,
        "official_rule_sources": official_sources,
        "qualification_artifact": qualification_input,
        "qualification": qualification,
        "rules": rules,
        "internal_policy": internal_policy,
        "evaluation_contract": evaluation_contract,
        "runner_receipts": receipt_rows,
        "sleeves": pinned_sleeves,
    }


def _position_states(
    grid: pd.DatetimeIndex,
    cases: Sequence[Mapping[str, Any]],
) -> tuple[np.ndarray, np.ndarray]:
    entries = np.zeros(len(grid), dtype=np.int64)
    exits = np.zeros(len(grid), dtype=np.int64)
    for case in cases:
        timestamp_basis = str(case.get("timestamp_basis") or joint.TIMESTAMP_BASIS_UNIX_UTC)
        for trade in case["trades"]:
            entry_bucket = joint.normalize_timestamp(trade.entry_time, timestamp_basis).floor(
                joint.GRID_FREQUENCY
            )
            exit_bucket = joint.normalize_timestamp(trade.exit_time, timestamp_basis).floor(
                joint.GRID_FREQUENCY
            )
            entry_index = int(grid.get_indexer([entry_bucket])[0])
            exit_index = int(grid.get_indexer([exit_bucket])[0])
            if entry_index < 0 or exit_index < entry_index:
                raise StandaloneEvaluationError("model:position_grid_index_invalid")
            entries[entry_index] += 1
            exits[exit_index] += 1
    active_before = np.zeros(len(grid), dtype=np.int64)
    active_after = np.zeros(len(grid), dtype=np.int64)
    active = 0
    for index in range(len(grid)):
        active_before[index] = active
        active += int(entries[index])
        active -= int(exits[index])
        if active < 0:
            raise StandaloneEvaluationError("model:position_count_negative")
        active_after[index] = active
    if active != 0:
        raise StandaloneEvaluationError("model:positions_not_flat_at_end")
    return active_before, active_after


def _daily_observations(
    grid: pd.DatetimeIndex,
    cases: Sequence[Mapping[str, Any]],
    components: Sequence[joint.SleeveComponents],
) -> list[DailyObservation]:
    weights = {component.key: 1.0 for component in components}
    days, pairs = joint.components_to_daily(
        grid,
        components,
        weights=weights,
        multiplier=1.0,
    )
    active_before, active_after = _position_states(grid, cases)
    local_days = np.asarray(grid.tz_convert(joint.PRAGUE).date, dtype=object)
    starts = np.concatenate(
        (
            np.asarray([0], dtype=np.int64),
            np.flatnonzero(local_days[1:] != local_days[:-1]) + 1,
        )
    )
    ends = np.concatenate((starts[1:] - 1, np.asarray([len(grid) - 1], dtype=np.int64)))
    if len(days) != len(pairs) or len(days) != len(starts):
        raise StandaloneEvaluationError("model:daily_alignment_mismatch")
    output: list[DailyObservation] = []
    for day, pair, start, end in zip(days, pairs, starts, ends):
        realized, minimum_delta, opens = pair
        output.append(
            DailyObservation(
                day=day,
                realized=float(realized),
                minimum_equity_delta=float(minimum_delta),
                opened_positions=int(opens),
                flat_at_start=int(active_before[int(start)]) == 0,
                flat_at_end=int(active_after[int(end)]) == 0,
            )
        )
    return output


def _pearson(left: Sequence[float], right: Sequence[float]) -> float | None:
    if len(left) != len(right) or len(left) < 2:
        return None
    left_mean = statistics.fmean(left)
    right_mean = statistics.fmean(right)
    left_diff = [value - left_mean for value in left]
    right_diff = [value - right_mean for value in right]
    left_norm = math.sqrt(sum(value * value for value in left_diff))
    right_norm = math.sqrt(sum(value * value for value in right_diff))
    if left_norm == 0.0 or right_norm == 0.0:
        return None
    return sum(a * b for a, b in zip(left_diff, right_diff)) / (left_norm * right_norm)


def _correlation_diagnostics(
    grid: pd.DatetimeIndex,
    components: Sequence[joint.SleeveComponents],
) -> dict[str, Any]:
    per_sleeve: dict[str, list[float]] = {}
    days: list[dt.date] | None = None
    for component in components:
        current_days, pairs = joint.components_to_daily(
            grid,
            [component],
            weights={component.key: 1.0},
            multiplier=1.0,
        )
        if days is None:
            days = current_days
        elif current_days != days:
            raise StandaloneEvaluationError("model:correlation_day_grid_mismatch")
        per_sleeve[component.key] = [float(pair[0]) for pair in pairs]
    pairs_out: list[dict[str, Any]] = []
    keys = sorted(per_sleeve)
    for left_index, left_key in enumerate(keys):
        for right_key in keys[left_index + 1 :]:
            left = per_sleeve[left_key]
            right = per_sleeve[right_key]
            active = [(a, b) for a, b in zip(left, right) if a != 0.0 and b != 0.0]
            pairs_out.append(
                {
                    "left": left_key,
                    "right": right_key,
                    "calendar_zero_filled": _pearson(left, right),
                    "joint_active_days_only": _pearson(
                        [value[0] for value in active],
                        [value[1] for value in active],
                    ),
                    "joint_active_days": len(active),
                }
            )
    return {
        "basis": "daily_realized_pnl_ftmo_recosted_from_same_synchronized_grid",
        "gate_eligible": False,
        "reason": "diagnostic_only_not_a_replacement_for_current_Q09_regime_gate",
        "calendar_days": len(days or []),
        "pairs": pairs_out,
    }


def _build_joint_daily_model(
    cases: Sequence[Mapping[str, Any]],
    *,
    timestamp_basis: str,
) -> tuple[list[DailyObservation], dict[str, Any], dict[str, Any]]:
    manifest = {
        "timestamp_basis": timestamp_basis,
        "sleeves": [dict(case) for case in cases],
    }
    loaded_cases, source_bars = joint.load_cases(manifest, bar_paths={})
    grid = joint.common_grid(loaded_cases)
    components: list[joint.SleeveComponents] = []
    for case in loaded_cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = joint.align_bars_to_grid(source_bars[symbol], grid)
        components.append(
            joint.build_sleeve_components(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
            )
        )
    daily = _daily_observations(grid, loaded_cases, components)
    if not daily:
        raise StandaloneEvaluationError("model:no_daily_observations")
    diagnostics = {
        "basis": "report_reconciled_ftmo_costed_synchronized_m15_q08_capped_joint_ohlc_equity",
        "grid_start_utc": grid[0].isoformat(),
        "grid_end_utc": grid[-1].isoformat(),
        "grid_samples": len(grid),
        "calendar_start": daily[0].day.isoformat(),
        "calendar_end": daily[-1].day.isoformat(),
        "calendar_days": len(daily),
        "sleeves": [
            {
                "key": component.key,
                "trades": component.trades,
                "ftmo_net": round(component.ftmo_net, 2),
                "ftmo_commission": round(component.ftmo_commission, 2),
                "ftmo_swap": round(component.ftmo_swap, 2),
                "point_value_fallbacks": component.point_value_fallbacks,
                "q08_mae_capped_trades": component.q08_mae_capped_trades,
                "q08_mae_capped_bars": component.q08_mae_capped_bars,
                "entry_price_outside_bar": component.entry_price_outside_bar,
                "exit_price_outside_bar": component.exit_price_outside_bar,
                "max_q08_cap_adjustment": round(component.max_q08_cap_adjustment, 2),
            }
            for component in components
        ],
    }
    return daily, diagnostics, _correlation_diagnostics(grid, components)


def evaluate_phase(
    sequence: Sequence[DailyObservation],
    *,
    start_index: int,
    target_balance: float,
    risk_multiplier: float = 1.0,
    capture_balance: float | None = None,
) -> dict[str, Any]:
    """Evaluate one no-deadline phase, right-censored only by available history.

    Boundary operators are the literal rulepack operators: loss is a breach only
    when equity is strictly below the floor, and target requires balance strictly
    greater than target while the modeled book is flat.
    """

    multiplier = _finite(risk_multiplier, "phase:risk_multiplier")
    if multiplier <= 0.0:
        raise StandaloneEvaluationError("phase:risk_multiplier_not_positive")
    capture = (
        _finite(capture_balance, "phase:capture_balance")
        if capture_balance is not None
        else None
    )
    if capture is not None and capture <= target_balance:
        raise StandaloneEvaluationError("phase:capture_balance_not_above_official_target")
    if start_index < 0 or start_index >= len(sequence):
        raise StandaloneEvaluationError("phase:start_index_out_of_range")
    if not sequence[start_index].flat_at_start:
        return {
            "outcome": "invalid_start_not_flat",
            "start_index": start_index,
            "end_index": start_index,
            "days": 0,
        }
    balance = STARTING_BALANCE
    trading_days = 0
    for index in range(start_index, len(sequence)):
        row = sequence[index]
        minimum_equity = balance + row.minimum_equity_delta * multiplier
        if minimum_equity < MAXIMUM_LOSS_FLOOR:
            return {
                "outcome": "maximum_loss_breach",
                "start_index": start_index,
                "end_index": index,
                "days": index - start_index + 1,
                "day": row.day.isoformat(),
                "balance_before": balance,
                "minimum_equity": minimum_equity,
                "floor": MAXIMUM_LOSS_FLOOR,
                "trading_days": trading_days + int(row.opened_positions > 0),
            }
        daily_floor = balance - DAILY_LOSS_AMOUNT
        if minimum_equity < daily_floor:
            return {
                "outcome": "daily_loss_breach",
                "start_index": start_index,
                "end_index": index,
                "days": index - start_index + 1,
                "day": row.day.isoformat(),
                "balance_before": balance,
                "minimum_equity": minimum_equity,
                "floor": daily_floor,
                "trading_days": trading_days + int(row.opened_positions > 0),
            }
        if row.opened_positions > 0:
            trading_days += 1
        balance += row.realized * multiplier
        if (
            balance > target_balance
            and (capture is None or balance >= capture)
            and row.flat_at_end
            and trading_days >= MINIMUM_TRADING_DAYS
        ):
            return {
                "outcome": "passed",
                "start_index": start_index,
                "end_index": index,
                "days": index - start_index + 1,
                "day": row.day.isoformat(),
                "balance": balance,
                "trading_days": trading_days,
                "risk_multiplier": multiplier,
                "capture_balance": capture,
            }
    return {
        "outcome": "right_censored",
        "start_index": start_index,
        "end_index": len(sequence) - 1,
        "days": len(sequence) - start_index,
        "day": sequence[-1].day.isoformat(),
        "balance": balance,
        "trading_days": trading_days,
        "risk_multiplier": multiplier,
        "capture_balance": capture,
    }


def evaluate_two_phase_path(
    sequence: Sequence[DailyObservation],
    *,
    start_index: int,
    phase1_capture_balance: float | None = None,
    phase2_capture_balance: float | None = None,
    phase2_risk_multiplier: float = 1.0,
) -> dict[str, Any]:
    phase1 = evaluate_phase(
        sequence,
        start_index=start_index,
        target_balance=PHASE1_TARGET,
        capture_balance=phase1_capture_balance,
    )
    if phase1["outcome"] != "passed":
        return {
            "outcome": f"phase1_{phase1['outcome']}",
            "phase1": phase1,
            "phase2": None,
        }
    phase2_start = int(phase1["end_index"]) + 1
    if phase2_start >= len(sequence):
        return {
            "outcome": "phase2_right_censored",
            "phase1": phase1,
            "phase2": None,
        }
    phase2 = evaluate_phase(
        sequence,
        start_index=phase2_start,
        target_balance=PHASE2_TARGET,
        risk_multiplier=phase2_risk_multiplier,
        capture_balance=phase2_capture_balance,
    )
    return {
        "outcome": "passed" if phase2["outcome"] == "passed" else f"phase2_{phase2['outcome']}",
        "phase1": phase1,
        "phase2": phase2,
    }


def _rates(counts: Mapping[str, int]) -> dict[str, Any]:
    total = int(sum(counts.values()))
    return {
        "starts": total,
        "counts": dict(sorted((str(key), int(value)) for key, value in counts.items())),
        "percent": {
            str(key): (float(value) / total * 100.0 if total else None)
            for key, value in sorted(counts.items())
        },
    }


def historical_first_passage(
    sequence: Sequence[DailyObservation],
    *,
    label: str,
    phase1_capture_balance: float | None = None,
    phase2_capture_balance: float | None = None,
    phase2_risk_multiplier: float = 1.0,
) -> dict[str, Any]:
    phase1_counts: collections.Counter[str] = collections.Counter()
    two_phase_counts: collections.Counter[str] = collections.Counter()
    phase1_days: list[int] = []
    joint_days: list[int] = []
    eligible = [
        index
        for index, row in enumerate(sequence)
        if row.flat_at_start and row.opened_positions > 0
    ]
    for start_index in eligible:
        phase1 = evaluate_phase(
            sequence,
            start_index=start_index,
            target_balance=PHASE1_TARGET,
            capture_balance=phase1_capture_balance,
        )
        phase1_counts[phase1["outcome"]] += 1
        if phase1["outcome"] == "passed":
            phase1_days.append(int(phase1["days"]))
        two_phase = evaluate_two_phase_path(
            sequence,
            start_index=start_index,
            phase1_capture_balance=phase1_capture_balance,
            phase2_capture_balance=phase2_capture_balance,
            phase2_risk_multiplier=phase2_risk_multiplier,
        )
        two_phase_counts[two_phase["outcome"]] += 1
        if two_phase["outcome"] == "passed":
            assert two_phase["phase2"] is not None
            joint_days.append(
                int(two_phase["phase1"]["days"]) + int(two_phase["phase2"]["days"])
            )
    phase1_passes = int(phase1_counts.get("passed", 0))
    joint_passes = int(two_phase_counts.get("passed", 0))
    official_breaches = sum(
        int(count)
        for outcome, count in two_phase_counts.items()
        if outcome in {
            "phase1_daily_loss_breach",
            "phase1_maximum_loss_breach",
            "phase2_daily_loss_breach",
            "phase2_maximum_loss_breach",
        }
    )
    return {
        "label": label,
        "estimator": "overlapping_flat_trade_open_start_historical_first_passage",
        "time_limit": None,
        "censoring": "right_censored_at_bound_sample_end",
        "independence_claim": False,
        "phase_dependence_preserved": True,
        "gate_eligible": False,
        "phase1_capture_balance": phase1_capture_balance,
        "phase2_capture_balance": phase2_capture_balance,
        "phase2_risk_multiplier": phase2_risk_multiplier,
        "start_set": "Prague_days_flat_at_start_with_at_least_one_new_book_position",
        "eligible_flat_trade_open_starts": len(eligible),
        "phase1": {
            **_rates(phase1_counts),
            "median_days_to_pass": statistics.median(phase1_days) if phase1_days else None,
        },
        "two_phase": {
            **_rates(two_phase_counts),
            "median_days_to_complete": statistics.median(joint_days) if joint_days else None,
        },
        "conditional_phase2_pass_given_phase1_pass": {
            "numerator_two_phase_passes": joint_passes,
            "denominator_phase1_passes": phase1_passes,
            "percent": (
                joint_passes / phase1_passes * 100.0 if phase1_passes else None
            ),
            "dependent_phase_sequence": True,
        },
        "any_official_breach": {
            "count": official_breaches,
            "starts": len(eligible),
            "percent": (
                official_breaches / len(eligible) * 100.0 if eligible else None
            ),
            "outcomes_included": [
                "phase1_daily_loss_breach",
                "phase1_maximum_loss_breach",
                "phase2_daily_loss_breach",
                "phase2_maximum_loss_breach",
            ],
        },
    }


def _flat_bounded_blocks(
    sequence: Sequence[DailyObservation],
    block_days: int,
) -> list[list[DailyObservation]]:
    if block_days > len(sequence):
        return []
    return [
        list(sequence[start : start + block_days])
        for start in range(len(sequence) - block_days + 1)
        if sequence[start].flat_at_start and sequence[start + block_days - 1].flat_at_end
    ]


def _wilson(successes: int, total: int) -> list[float] | None:
    if total <= 0:
        return None
    z = 1.959963984540054
    p = successes / total
    denominator = 1.0 + z * z / total
    center = (p + z * z / (2.0 * total)) / denominator
    margin = z * math.sqrt((p * (1.0 - p) + z * z / (4.0 * total)) / total) / denominator
    return [max(0.0, center - margin) * 100.0, min(1.0, center + margin) * 100.0]


def _synthetic_bootstrap_calendar(
    sequence: Sequence[DailyObservation],
) -> list[DailyObservation]:
    """Replace reused source dates with unambiguous consecutive sample labels."""

    epoch = dt.date(2000, 1, 1)
    return [
        DailyObservation(
            day=epoch + dt.timedelta(days=index),
            realized=row.realized,
            minimum_equity_delta=row.minimum_equity_delta,
            opened_positions=row.opened_positions,
            flat_at_start=row.flat_at_start,
            flat_at_end=row.flat_at_end,
        )
        for index, row in enumerate(sequence)
    ]


def block_bootstrap(
    source: Sequence[DailyObservation],
    *,
    runs: int,
    block_days: int,
    minimum_path_days: int,
    seeds: Sequence[int],
    phase1_capture_balance: float | None = None,
    phase2_capture_balance: float | None = None,
    phase2_risk_multiplier: float = 1.0,
) -> dict[str, Any]:
    blocks = _flat_bounded_blocks(source, block_days)
    if not blocks:
        raise StandaloneEvaluationError("bootstrap:no_flat_bounded_blocks")
    phase1_counts: collections.Counter[str] = collections.Counter()
    two_phase_counts: collections.Counter[str] = collections.Counter()
    for seed in seeds:
        rng = random.Random(seed)
        for _ in range(runs):
            sampled: list[DailyObservation] = []
            while len(sampled) < minimum_path_days:
                sampled.extend(rng.choice(blocks))
            sampled = _synthetic_bootstrap_calendar(sampled)
            phase1 = evaluate_phase(
                sampled,
                start_index=0,
                target_balance=PHASE1_TARGET,
                capture_balance=phase1_capture_balance,
            )
            phase1_counts[phase1["outcome"]] += 1
            two_phase_counts[
                evaluate_two_phase_path(
                    sampled,
                    start_index=0,
                    phase1_capture_balance=phase1_capture_balance,
                    phase2_capture_balance=phase2_capture_balance,
                    phase2_risk_multiplier=phase2_risk_multiplier,
                )["outcome"]
            ] += 1
    total = runs * len(seeds)
    phase1_passes = phase1_counts.get("passed", 0)
    joint_passes = two_phase_counts.get("passed", 0)
    official_breaches = sum(
        int(count)
        for outcome, count in two_phase_counts.items()
        if outcome in {
            "phase1_daily_loss_breach",
            "phase1_maximum_loss_breach",
            "phase2_daily_loss_breach",
            "phase2_maximum_loss_breach",
        }
    )
    return {
        "estimator": "finite_path_moving_block_bootstrap_of_joint_daily_vector",
        "source": "IS_only",
        "block_boundary_contract": "every_sampled_block_starts_and_ends_flat",
        "sampled_day_labels": "synthetic_consecutive_days_not_reused_source_dates",
        "phase_dependence_preserved": True,
        "gate_eligible": False,
        "phase1_capture_balance": phase1_capture_balance,
        "phase2_capture_balance": phase2_capture_balance,
        "phase2_risk_multiplier": phase2_risk_multiplier,
        "sleeves_bootstrapped_independently": False,
        "no_deadline_claim": False,
        "finite_path_minimum_days": minimum_path_days,
        "realized_path_days_range": [minimum_path_days, minimum_path_days + block_days - 1],
        "right_censoring_counts_as_right_censored_not_pass": True,
        "runs_per_seed": runs,
        "seeds": list(seeds),
        "flat_bounded_block_count": len(blocks),
        "block_days": block_days,
        "phase1": {
            **_rates(phase1_counts),
            "pass_mc_wilson_95_percent": _wilson(phase1_passes, total),
        },
        "two_phase": {
            **_rates(two_phase_counts),
            "pass_mc_wilson_95_percent": _wilson(joint_passes, total),
        },
        "conditional_phase2_pass_given_phase1_pass": {
            "numerator_two_phase_passes": joint_passes,
            "denominator_phase1_passes": phase1_passes,
            "percent": (
                joint_passes / phase1_passes * 100.0 if phase1_passes else None
            ),
            "mc_wilson_95_percent": _wilson(joint_passes, phase1_passes),
            "dependent_phase_sequence": True,
        },
        "any_official_breach": {
            "count": official_breaches,
            "starts": total,
            "percent": official_breaches / total * 100.0 if total else None,
            "mc_wilson_95_percent": _wilson(official_breaches, total),
            "outcomes_included": [
                "phase1_daily_loss_breach",
                "phase1_maximum_loss_breach",
                "phase2_daily_loss_breach",
                "phase2_maximum_loss_breach",
            ],
        },
        "uncertainty_scope": (
            "Wilson intervals quantify Monte-Carlo sampling precision only; they do not "
            "capture empirical-history reuse, model, vintage, or market-regime uncertainty."
        ),
    }


def _slice_by_date(
    sequence: Sequence[DailyObservation],
    *,
    start: dt.date | None = None,
    end_exclusive: dt.date | None = None,
) -> list[DailyObservation]:
    return [
        row
        for row in sequence
        if (start is None or row.day >= start)
        and (end_exclusive is None or row.day < end_exclusive)
    ]


def evaluate_manifest(
    manifest: Mapping[str, Any],
    *,
    manifest_path: Path,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    now = (now_utc or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    if not manifest_path.is_file():
        raise StandaloneEvaluationError("manifest:path_missing")
    try:
        manifest_bytes = manifest_path.read_bytes()
    except OSError as exc:
        raise StandaloneEvaluationError("manifest:unreadable") from exc
    manifest_sha = hashlib.sha256(manifest_bytes).hexdigest()
    actual_manifest = _loads_strict_json(manifest_bytes, "manifest")
    if actual_manifest != manifest:
        raise StandaloneEvaluationError("manifest:document_does_not_match_path")
    if not isinstance(actual_manifest, Mapping):
        raise StandaloneEvaluationError("manifest:not_object")
    staging_token = actual_manifest.get("staging_root")
    if not isinstance(staging_token, str) or not staging_token.strip():
        raise StandaloneEvaluationError("manifest:staging_root_missing")
    stager = ContentAddressedStager(Path(staging_token), manifest_sha, manifest_bytes)
    manifest = actual_manifest
    cases, bindings = _validate_inputs(manifest, now_utc=now, stager=stager)
    _revalidate_bound_inputs(bindings)
    if sha256_file(manifest_path) != manifest_sha:
        raise StandaloneEvaluationError("manifest:changed_during_input_validation")
    daily, model, correlations = _build_joint_daily_model(
        cases,
        timestamp_basis=bindings["timestamp_basis"],
    )
    _revalidate_bound_inputs(bindings)
    if sha256_file(manifest_path) != manifest_sha:
        raise StandaloneEvaluationError("manifest:changed_during_model_evaluation")
    model = {
        **model,
        "portfolio_contract": {
            "sleeve_weights_by_rung": {rung: 1.0 for rung in EXPECTED_BOOK},
            "base_risk_fixed_usd_per_sleeve": 1000.0,
            "nominal_three_sleeve_risk_fixed_sum_usd": 3000.0,
            "shared_account": True,
        },
    }

    evaluation = manifest.get("evaluation")
    if not isinstance(evaluation, Mapping):
        raise StandaloneEvaluationError("manifest:evaluation_missing")
    split_raw = str(evaluation.get("split_date") or "")
    try:
        split_date = dt.date.fromisoformat(split_raw)
    except ValueError as exc:
        raise StandaloneEvaluationError("manifest:evaluation:split_date_invalid") from exc
    if not daily[0].day < split_date <= daily[-1].day:
        raise StandaloneEvaluationError("manifest:evaluation:split_date_outside_data")
    in_sample = _slice_by_date(daily, end_exclusive=split_date)
    out_of_sample = _slice_by_date(daily, start=split_date)
    if not in_sample or not out_of_sample:
        raise StandaloneEvaluationError("manifest:evaluation:empty_is_or_oos")

    bootstrap_spec = evaluation.get("bootstrap")
    if not isinstance(bootstrap_spec, Mapping):
        raise StandaloneEvaluationError("manifest:evaluation:bootstrap_missing")
    runs = _positive_int(bootstrap_spec.get("runs_per_seed"), "bootstrap:runs_per_seed")
    block_days = _positive_int(bootstrap_spec.get("block_days"), "bootstrap:block_days")
    minimum_path_days = _positive_int(
        bootstrap_spec.get("minimum_path_days"), "bootstrap:minimum_path_days"
    )
    raw_seeds = bootstrap_spec.get("seeds")
    if not isinstance(raw_seeds, list) or not raw_seeds:
        raise StandaloneEvaluationError("bootstrap:seeds_missing")
    seeds = [_integer(value, "bootstrap:seed") for value in raw_seeds]
    if len(seeds) != len(set(seeds)) or any(value < 0 for value in seeds):
        raise StandaloneEvaluationError("bootstrap:seeds_invalid_or_duplicate")
    if runs > 100_000 or len(seeds) > 20:
        raise StandaloneEvaluationError("bootstrap:run_budget_too_large")

    def historical_scenario(
        *,
        scenario: str,
        phase1_capture_balance: float | None,
        phase2_capture_balance: float | None,
        phase2_risk_multiplier: float,
    ) -> dict[str, Any]:
        options = {
            "phase1_capture_balance": phase1_capture_balance,
            "phase2_capture_balance": phase2_capture_balance,
            "phase2_risk_multiplier": phase2_risk_multiplier,
        }
        return {
            "scenario": scenario,
            "full": historical_first_passage(daily, label="FULL_DESCRIPTIVE", **options),
            "in_sample": historical_first_passage(
                in_sample, label="IS_MODEL_DEVELOPMENT", **options
            ),
            "out_of_sample": historical_first_passage(
                out_of_sample,
                label="TEMPORAL_HOLDOUT_DIAGNOSTIC_NOT_SELECTION_SEALED",
                **options,
            ),
        }

    historical = {
        "official_rule_ceiling_1x": historical_scenario(
            scenario="OFFICIAL_RULES_RAW_1X_BOOK",
            phase1_capture_balance=None,
            phase2_capture_balance=None,
            phase2_risk_multiplier=1.0,
        ),
        "internal_policy_eod_surrogate": historical_scenario(
            scenario="QM_CAPTURE_BUFFERS_WITH_PHASE2_0_75X_EOD_SURROGATE",
            phase1_capture_balance=PHASE1_CAPTURE_BALANCE,
            phase2_capture_balance=PHASE2_CAPTURE_BALANCE,
            phase2_risk_multiplier=PHASE2_RISK_MULTIPLIER,
        ),
        "split_date": split_date.isoformat(),
        "selection_contract": (
            "membership, weights, rule semantics, split, and bootstrap parameters are SHA-bound "
            "by the input manifest before this receipt is scored"
        ),
        "scenario_comparison_is_descriptive": True,
        "holdout_contract": {
            "selection_sealed_before_strategy_choice": False,
            "gate_eligible": False,
            "selection_bias_debt": (
                "all three EAs were already observed or selected using the 2018-2025 vintage"
            ),
            "purchase_gate_requires": [
                "new_unseen_or_forward_evidence",
                "exact_profile_free_trial_or_shadow_run",
                "separately_preregistered_selection_seal",
            ],
        },
    }
    bootstrap_options = {
        "runs": runs,
        "block_days": block_days,
        "minimum_path_days": minimum_path_days,
        "seeds": seeds,
    }
    bootstrap = {
        "official_rule_ceiling_1x": block_bootstrap(in_sample, **bootstrap_options),
        "internal_policy_eod_surrogate": block_bootstrap(
            in_sample,
            phase1_capture_balance=PHASE1_CAPTURE_BALANCE,
            phase2_capture_balance=PHASE2_CAPTURE_BALANCE,
            phase2_risk_multiplier=PHASE2_RISK_MULTIPLIER,
            **bootstrap_options,
        ),
        "source": "IS_only",
        "scenario_comparison_is_descriptive": True,
    }
    _revalidate_bound_inputs(bindings)
    if sha256_file(manifest_path) != manifest_sha:
        raise StandaloneEvaluationError("manifest:changed_during_statistical_evaluation")
    evaluation_id = canonical_sha256(
        {
            "manifest_sha256": manifest_sha,
            "source_commit": bindings["source_commit"],
            "evidence_vintage": bindings["evidence_vintage"],
            "inputs": bindings["sleeves"],
            "cost_snapshot_sha256": bindings["cost_snapshot"]["sha256"],
            "rulepack_sha256": bindings["rulepack"]["sha256"],
            "official_rule_snapshot_sha256": bindings["official_rule_snapshot"][
                "sha256"
            ],
            "qualification_sha256": bindings["qualification_artifact"]["sha256"],
            "evaluation": evaluation,
        }
    )
    qualification_status = bindings["qualification"]["status"]
    return {
        "schema": RECEIPT_SCHEMA,
        "evaluation_id": evaluation_id,
        "generated_at_utc": now.isoformat().replace("+00:00", "Z"),
        "book_id": BOOK_ID,
        "staging_snapshot": {
            "path": str(stager.directory.resolve()),
            "manifest_path": str(stager.manifest_path.resolve()),
            "manifest_sha256": manifest_sha,
            "semantic_inputs": "CREATE_ONLY_CONTENT_ADDRESSED_STAGING_ONLY",
        },
        "status": "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED",
        "readiness": {
            "input_integrity": "PASS",
            "native_stream_reconciliation": "PASS",
            "shared_account_model": "COMPLETE_RESEARCH_ONLY",
            "strict_qualification": qualification_status,
            "internal_policy_capture_fidelity": "SETUP_DATA_MISSING",
            "internal_policy_capture_fidelity_reason": (
                "event_complete_target_crossing_pending_order_and_forced_flatten_trace_missing"
            ),
            "complete_internal_governor_policy": "SETUP_DATA_MISSING",
            "money_gate": "SETUP_DATA_MISSING",
            "money_gate_reason": "event_complete_joint_equity_trace_missing",
            "paid_challenge": "NO_GO",
        },
        "authorization": {
            "research_evaluation_complete": True,
            "money_gate_authorized": False,
            "deployment_allowed": False,
            "factory_action_authorized": False,
            "factory_restart_authorized": False,
            "paid_challenge_purchase_authorized": False,
        },
        "manifest": {
            "path": str(manifest_path.resolve()),
            "sha256": manifest_sha,
            "bytes": len(manifest_bytes),
            "schema": MANIFEST_SCHEMA,
        },
        "bindings": bindings,
        "model": model,
        "rule_semantics": {
            **bindings["rules"],
            "internal_policy": bindings["internal_policy"],
            "scenario_contract": {
                "official_rule_ceiling_1x": (
                    "official strict pass/loss boundaries; raw 1x book in both phases"
                ),
                "internal_policy_eod_surrogate": (
                    "phase-1/phase-2 capture buffers enforced at flat Prague-day end; "
                    "phase-2 realized PnL and adverse path scaled linearly to 0.75x"
                ),
                "capture_action_exactly_modeled": False,
                "modeled_policy_subset": [
                    "phase1_capture_balance_as_flat_end_of_day_surrogate",
                    "phase2_capture_balance_as_flat_end_of_day_surrogate",
                    "phase2_linear_0_75x_realized_and_adverse_path_scaling",
                ],
                "unmodeled_policy_controls": [
                    "correlated_cluster_open_stop_risk_cap",
                    "total_open_stop_risk_cap",
                    "projected_daily_loss_entry_budget",
                    "seven_percent_internal_drawdown_stop",
                    "Prague_midnight_entry_blackout",
                    "pending_order_cancellation_and_forced_flatten_execution",
                ],
            },
            "pass_detection": "end_of_prague_day_only_conservative",
            "loss_detection": "synchronized_M15_intrabar_adverse_bound_with_Q08_lifetime_MAE_cap",
        },
        "historical_first_passage": historical,
        "block_bootstrap": bootstrap,
        "correlation_diagnostics": correlations,
        "limitations": [
            "Standalone MT5 runs do not prove shared-account governor, margin, pending-order, or execution parity.",
            "M15 OHLC cannot prove tick ordering or exact sub-bar co-movement and is not event-complete money evidence.",
            "Q08 lifetime MAE caps impossible bar losses but does not locate the exact MAE timestamp.",
            "The current FTMO symbol-cost snapshot is applied to the full historical sample.",
            "Pass recognition occurs only at a flat Prague-day end and can undercount an earlier intraday flat target crossing.",
            "Historical rolling starts overlap and are descriptive; they are not independent Bernoulli observations.",
            "The temporal OOS slice is not selection-sealed because the three EAs were already viewed over this vintage; it is diagnostic and cannot satisfy a purchase gate.",
            "The block bootstrap preserves the joint daily vector and phase sequence but has a finite sampled path, so censoring remains.",
            "Internal capture/flatten actions and pending-order cancellation cannot be replayed from M15 plus lifecycle summaries; the policy scenario is an end-of-day flat surrogate and remains a setup gap.",
            "Phase-2 0.75x is a linear PnL/MAE rescaling assumption; it does not prove lot rounding, margin, slippage, or governor execution parity.",
            "The three 1000 USD sleeve risks sum nominally to 3000 USD; this evaluator cannot prove the internal 2500 USD simultaneous-open-stop cap or 1500 USD correlated-cluster cap without event-complete exposure state.",
            "Strict Q08/qualification NO_GO remains binding independently of every simulation result.",
        ],
    }


def write_create_only_receipt(path: Path, receipt: Mapping[str, Any]) -> None:
    if not path.parent.is_dir():
        raise StandaloneEvaluationError(f"receipt:parent_directory_missing:{path.parent}")
    try:
        rendered = (
            json.dumps(
                receipt,
                indent=2,
                sort_keys=True,
                ensure_ascii=False,
                allow_nan=False,
            )
            + "\n"
        )
    except (TypeError, ValueError) as exc:
        raise StandaloneEvaluationError("receipt:document_not_strict_json") from exc
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise CreateOnlyReceiptError(f"receipt target already exists: {path}") from exc
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(rendered)
            handle.flush()
            os.fsync(handle.fileno())
    except BaseException:
        # A partially written create-only receipt is evidence of an interrupted
        # publication and intentionally remains for operator review.
        raise


def _pin_for_manifest(
    path: Path, label: str, *, include_lines: bool = False
) -> dict[str, Any]:
    if not path.is_absolute():
        raise StandaloneEvaluationError(f"manifest_builder:{label}:path_not_absolute")
    if not path.is_file():
        raise StandaloneEvaluationError(f"manifest_builder:{label}:file_missing:{path}")
    resolved = path.resolve()
    stat = resolved.stat()
    record = {
        "path": str(resolved),
        "sha256": sha256_file(resolved),
        "bytes": stat.st_size,
        "file_identity": {"device": stat.st_dev, "inode": stat.st_ino},
    }
    if include_lines:
        raw = resolved.read_bytes()
        record["lines"] = raw.count(b"\n") + (1 if raw and not raw.endswith(b"\n") else 0)
    return record


def _explicit_builder_path(value: Any, label: str) -> Path:
    if not isinstance(value, (str, os.PathLike)) or not str(value).strip():
        raise StandaloneEvaluationError(f"manifest_builder:{label}:path_missing")
    return Path(value)


def _build_evaluator_source_binding(source_commit: str) -> dict[str, Any]:
    state = _git_source_state(REPO_ROOT, list(EVALUATOR_SOURCE_PATHS.values()))
    if state["head"] != source_commit:
        raise StandaloneEvaluationError(
            "manifest_builder:evaluator_git_head_does_not_match_source_commit"
        )
    if state["dirty"]:
        raise StandaloneEvaluationError("manifest_builder:evaluator_source_scope_dirty")
    return {
        "repo_root": str(REPO_ROOT),
        "source_commit": source_commit,
        "artifacts": [
            {"role": role, **_pin_for_manifest(path, f"evaluator_source:{role}")}
            for role, path in EVALUATOR_SOURCE_PATHS.items()
        ],
        "source_scope_clean": True,
    }


def build_manifest_document(
    *,
    source_commit: str,
    evidence_vintage: str,
    cost_snapshot: Path,
    rulepack: Path,
    qualification: Path,
    staging_root: Path,
    sleeves: Mapping[str, Mapping[str, Any]],
    timestamp_basis: str,
    cost_snapshot_max_age_days: int,
    split_date: str,
    bootstrap_runs_per_seed: int,
    bootstrap_block_days: int,
    bootstrap_minimum_path_days: int,
    bootstrap_seeds: Sequence[int],
) -> dict[str, Any]:
    """Build deterministic manifest bytes from explicit, currently observed files."""

    normalized_commit = str(source_commit).lower()
    if not COMMIT_RE.fullmatch(normalized_commit):
        raise StandaloneEvaluationError("manifest_builder:source_commit_invalid")
    if normalized_commit == R0_R1_AUTHORITATIVE_SOURCE_COMMIT:
        raise StandaloneEvaluationError(
            "manifest_builder:source_commit_must_include_diagnostic_contract"
        )
    vintage = str(evidence_vintage).strip()
    if not vintage:
        raise StandaloneEvaluationError("manifest_builder:evidence_vintage_missing")
    if timestamp_basis not in joint.VALID_TIMESTAMP_BASES:
        raise StandaloneEvaluationError("manifest_builder:timestamp_basis_invalid")
    age_days = _positive_int(
        cost_snapshot_max_age_days, "manifest_builder:cost_snapshot_max_age_days"
    )
    if age_days > 30:
        raise StandaloneEvaluationError("manifest_builder:cost_snapshot_max_age_days_too_large")
    try:
        dt.date.fromisoformat(split_date)
    except ValueError as exc:
        raise StandaloneEvaluationError("manifest_builder:split_date_invalid") from exc
    runs = _positive_int(bootstrap_runs_per_seed, "manifest_builder:bootstrap_runs")
    block_days = _positive_int(bootstrap_block_days, "manifest_builder:bootstrap_block_days")
    path_days = _positive_int(
        bootstrap_minimum_path_days, "manifest_builder:bootstrap_minimum_path_days"
    )
    seeds = [_integer(value, "manifest_builder:bootstrap_seed") for value in bootstrap_seeds]
    if not seeds or len(seeds) != len(set(seeds)) or any(value < 0 for value in seeds):
        raise StandaloneEvaluationError("manifest_builder:bootstrap_seeds_invalid")
    if runs > 100_000 or len(seeds) > 20:
        raise StandaloneEvaluationError("manifest_builder:bootstrap_run_budget_too_large")
    if set(sleeves) != set(EXPECTED_BOOK):
        raise StandaloneEvaluationError("manifest_builder:rung_set_mismatch")
    if not staging_root.is_absolute() or not staging_root.is_dir():
        raise StandaloneEvaluationError("manifest_builder:staging_root_invalid")

    output_sleeves: list[dict[str, Any]] = []
    for rung, (ea_id, symbol, provider_symbol) in EXPECTED_BOOK.items():
        raw = sleeves[rung]
        if not isinstance(raw, Mapping):
            raise StandaloneEvaluationError(f"manifest_builder:{rung}:sleeve_invalid")
        work_item_id = str(raw.get("work_item_id") or "").strip()
        sleeve_commit = str(raw.get("source_commit") or "").lower()
        if not work_item_id:
            raise StandaloneEvaluationError(f"manifest_builder:{rung}:work_item_id_missing")
        if not COMMIT_RE.fullmatch(sleeve_commit):
            raise StandaloneEvaluationError(f"manifest_builder:{rung}:source_commit_invalid")
        if rung in {"R0", "R1"} and sleeve_commit != R0_R1_AUTHORITATIVE_SOURCE_COMMIT:
            raise StandaloneEvaluationError(
                f"manifest_builder:{rung}:historical_source_commit_mismatch"
            )
        if rung == "R2" and sleeve_commit != normalized_commit:
            raise StandaloneEvaluationError(
                "manifest_builder:R2:source_commit_not_evaluator_commit"
            )
        output_sleeves.append(
            {
                "rung": rung,
                "ea_id": ea_id,
                "symbol": symbol,
                "provider_symbol": provider_symbol,
                "work_item_id": work_item_id,
                "source_commit": sleeve_commit,
                "base_risk_fixed": 1000,
                "receipt": _pin_for_manifest(
                    _explicit_builder_path(raw.get("receipt"), f"{rung}:receipt"),
                    f"{rung}:receipt",
                ),
                "summary": _pin_for_manifest(
                    _explicit_builder_path(raw.get("summary"), f"{rung}:summary"),
                    f"{rung}:summary",
                ),
                "stream": _pin_for_manifest(
                    _explicit_builder_path(raw.get("stream"), f"{rung}:stream"),
                    f"{rung}:stream",
                    include_lines=True,
                ),
                "m15": _pin_for_manifest(
                    _explicit_builder_path(raw.get("m15"), f"{rung}:m15"),
                    f"{rung}:m15",
                ),
                "report": _pin_for_manifest(
                    _explicit_builder_path(raw.get("report"), f"{rung}:report"),
                    f"{rung}:report",
                ),
            }
        )
    return {
        "schema": MANIFEST_SCHEMA,
        "book_id": BOOK_ID,
        "source_commit": normalized_commit,
        "staging_root": str(staging_root.resolve()),
        "evaluator_source": _build_evaluator_source_binding(normalized_commit),
        "evidence_vintage": vintage,
        "r2_purpose": "FRESH_STANDALONE_DIAGNOSTIC_ONLY",
        "timestamp_basis": timestamp_basis,
        "cost_snapshot_max_age_days": age_days,
        "cost_snapshot": _pin_for_manifest(cost_snapshot, "cost_snapshot"),
        "rulepack": _pin_for_manifest(rulepack, "rulepack"),
        "qualification": _pin_for_manifest(qualification, "qualification"),
        "sleeves": output_sleeves,
        "evaluation": {
            "split_date": split_date,
            "bootstrap": {
                "runs_per_seed": runs,
                "block_days": block_days,
                "minimum_path_days": path_days,
                "seeds": seeds,
            },
        },
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--manifest", type=Path)
    mode.add_argument("--prepare-manifest", type=Path, metavar="NEW_MANIFEST_JSON")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--source-commit")
    parser.add_argument("--evidence-vintage")
    parser.add_argument("--cost-snapshot", type=Path)
    parser.add_argument("--rulepack", type=Path)
    parser.add_argument("--qualification", type=Path)
    parser.add_argument("--staging-root", type=Path)
    parser.add_argument("--timestamp-basis")
    parser.add_argument("--cost-snapshot-max-age-days", type=int)
    parser.add_argument("--split-date")
    parser.add_argument("--bootstrap-runs-per-seed", type=int)
    parser.add_argument("--bootstrap-block-days", type=int)
    parser.add_argument("--bootstrap-minimum-path-days", type=int)
    parser.add_argument("--bootstrap-seeds", type=int, nargs="+")
    for rung in ("r0", "r1", "r2"):
        parser.add_argument(f"--{rung}-work-item-id")
        parser.add_argument(f"--{rung}-source-commit")
        parser.add_argument(f"--{rung}-receipt", type=Path)
        parser.add_argument(f"--{rung}-summary", type=Path)
        parser.add_argument(f"--{rung}-stream", type=Path)
        parser.add_argument(f"--{rung}-m15", type=Path)
        parser.add_argument(f"--{rung}-report", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.prepare_manifest is not None:
            required = (
                "source_commit",
                "evidence_vintage",
                "cost_snapshot",
                "rulepack",
                "qualification",
                "staging_root",
                "timestamp_basis",
                "cost_snapshot_max_age_days",
                "split_date",
                "bootstrap_runs_per_seed",
                "bootstrap_block_days",
                "bootstrap_minimum_path_days",
                "bootstrap_seeds",
            )
            for rung in ("r0", "r1", "r2"):
                required += tuple(
                    f"{rung}_{suffix}"
                    for suffix in (
                        "work_item_id",
                        "source_commit",
                        "receipt",
                        "summary",
                        "stream",
                        "m15",
                        "report",
                    )
                )
            missing = [name for name in required if getattr(args, name) is None]
            if missing:
                raise StandaloneEvaluationError(
                    "manifest_builder:required_arguments_missing:" + ",".join(missing)
                )
            sleeves = {
                rung.upper(): {
                    suffix: getattr(args, f"{rung}_{suffix}")
                    for suffix in (
                        "work_item_id",
                        "source_commit",
                        "receipt",
                        "summary",
                        "stream",
                        "m15",
                        "report",
                    )
                }
                for rung in ("r0", "r1", "r2")
            }
            document = build_manifest_document(
                source_commit=args.source_commit,
                evidence_vintage=args.evidence_vintage,
                cost_snapshot=args.cost_snapshot,
                rulepack=args.rulepack,
                qualification=args.qualification,
                staging_root=args.staging_root,
                sleeves=sleeves,
                timestamp_basis=args.timestamp_basis,
                cost_snapshot_max_age_days=args.cost_snapshot_max_age_days,
                split_date=args.split_date,
                bootstrap_runs_per_seed=args.bootstrap_runs_per_seed,
                bootstrap_block_days=args.bootstrap_block_days,
                bootstrap_minimum_path_days=args.bootstrap_minimum_path_days,
                bootstrap_seeds=args.bootstrap_seeds,
            )
            write_create_only_receipt(args.prepare_manifest, document)
            print(
                f"wrote create-only deterministic manifest {args.prepare_manifest} "
                f"sha256={sha256_file(args.prepare_manifest)}"
            )
            return 0
        if args.manifest is None or args.out is None:
            raise StandaloneEvaluationError("evaluation:manifest_and_out_required")
        manifest = _load_json(args.manifest, "manifest")
        if not isinstance(manifest, Mapping):
            raise StandaloneEvaluationError("manifest:not_object")
        receipt = evaluate_manifest(manifest, manifest_path=args.manifest)
        write_create_only_receipt(args.out, receipt)
    except (StandaloneEvaluationError, CreateOnlyReceiptError) as exc:
        print(f"FTMO Book3 standalone evaluation refused: {exc}")
        return 2
    print(
        f"wrote create-only research receipt {args.out} "
        f"status={receipt['status']} money_gate={receipt['readiness']['money_gate']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
