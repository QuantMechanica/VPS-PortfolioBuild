"""Track D: first-reward economics model for the FTMO acceleration program.

Read-only, no side effects: no account purchase, no order, no AutoTrading
change, no T_Live/FTMO-demo deployment, no repo state mutation beyond writing
its own JSON output file. Every constant below is sourced from an existing,
hash-bound artifact or a same-day official FTMO page fetch; none is invented.

Sources
-------
- FEE_USD, FEE_REFUND, REWARD_SPLIT_BASE/SCALING, PHASE1/2 targets, daily/total
  loss limits, minimum trading days, no-max-trading-period:
  tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json
  (rulepack_id=FTMO_2S_100K_STANDARD_V2, profile_version=2, as_of=2026-09-04,
  official_sources -> docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json
  sha256 c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905).
  This is the STANDARD account variant, not Swing, per the Track D mandate.
- FIRST_REWARD_ELIGIBLE_DAY, REWARD_REVIEW_BUSINESS_DAYS,
  PAYOUT_TRANSFER_BUSINESS_DAYS, MIN_WITHDRAWAL_USD_BANK/CRYPTO:
  https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/ fetched 2026-09-11.
- Internal (non-provider) risk-budget guardrails: same rulepack file,
  `internal_guardrails[*]`, classification INTERNAL_QM_POLICY_NOT_PROVIDER_RULE,
  status PROPOSED_FOR_CALIBRATION unless noted OWNER_RATIFIED.

No P1 / P2 / P_reward / realized-profit value is assumed anywhere in this
module. The only quantity this script solves for is the BREAK-EVEN joint
success probability as a function of an assumed realized profit at first
Reward request -- it never asserts what that probability or profit actually
is. Naive independent-retry figures are computed for illustration only and
are explicitly labelled non-recommendation, per the correlated-attempts
caveat in docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md
(SS G: "repeated attempts are correlated ... not a licence to re-buy").
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SOURCE_RULEPACK = "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json"
SOURCE_RULEPACK_AS_OF = "2026-09-04"
SOURCE_WITHDRAWAL_URL = "https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/"
SOURCE_WITHDRAWAL_FETCHED_UTC = "2026-09-11"

# --- Provider economics (Standard, USD 100,000, 2-Step) -------------------
FEE_USD = 540.0                     # ftmo_2s_evaluation_fee, list_fee_usd
FEE_REFUND_PERCENT = 1.00           # ftmo_2s_fee_refund, refund_percent=100, trigger=FIRST_REWARD
REWARD_SPLIT_BASE = 0.80            # ftmo_2s_reward_split, base_percent
REWARD_SPLIT_SCALING = 0.90         # ftmo_2s_reward_split, maximum_percent (Scaling/Premium, >=4mo; not available at first reward)

# --- Provider trading objectives / risk limits (Standard, USD 100,000) ----
PHASE1_TARGET_USD = 10000.0         # ftmo_2s_phase1_profit_target
PHASE2_TARGET_USD = 5000.0          # ftmo_2s_verification_profit_target
DAILY_LOSS_LIMIT_USD = 5000.0       # ftmo_2s_max_daily_loss
TOTAL_LOSS_FLOOR_USD = 90000.0      # ftmo_2s_maximum_loss (static)
MIN_TRADING_DAYS_PER_PHASE = 4      # ftmo_2s_minimum_trading_days
NO_MAX_TRADING_PERIOD = True        # ftmo_2s_no_time_limit

# --- Time to cash -----------------------------------------------------------
FIRST_REWARD_ELIGIBLE_DAY = 14      # 14th or later day after first placed trade on funded account
REWARD_REVIEW_BUSINESS_DAYS = (1, 2)
PAYOUT_TRANSFER_BUSINESS_DAYS = (1, 2)
MIN_WITHDRAWAL_USD_BANK = 20.0
MIN_WITHDRAWAL_USD_CRYPTO = 50.0

# --- Internal (non-provider) risk guardrails already on file --------------
INTERNAL_PER_TRADE_RISK_CAP_PCT = 0.01
INTERNAL_CORRELATED_CLUSTER_CAP_PCT = 0.015
INTERNAL_TOTAL_OPEN_STOP_CAP_PCT = 0.025
INTERNAL_DAILY_LOSS_BUDGET_PCT = 0.03     # internal, vs. official 0.05
INTERNAL_TOTAL_DRAWDOWN_BUDGET_PCT = 0.07  # internal, vs. official 0.10 (floor 90,000)

REWARD_PROFIT_GRID_USD = [50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0]
MARGINAL_COST_GRID_USD = [0.0, 200.0]


def breakeven_joint_probability(reward_profit_usd: float, marginal_cost_usd: float = 0.0,
                                 reward_split: float = REWARD_SPLIT_BASE) -> float:
    """Joint P(pass Phase1) x P(pass Phase2|Phase1) x P(reach reward_profit_usd on funded account)
    required for EV=0, given the fee is refunded in full only on reaching the first Reward.

    EV = p_success * (reward_split * reward_profit_usd + FEE_USD) - FEE_USD - marginal_cost_usd
    Breakeven: p_success = (FEE_USD + marginal_cost_usd) / (reward_split * reward_profit_usd + FEE_USD)
    """
    if reward_profit_usd <= 0:
        raise ValueError("reward_profit_usd must be positive")
    inflow_on_success = reward_split * reward_profit_usd + FEE_USD * FEE_REFUND_PERCENT
    return (FEE_USD + marginal_cost_usd) / inflow_on_success


def expected_value(p1: float, p2_given_p1: float, p_reward_given_pass: float,
                    reward_profit_usd: float, marginal_cost_usd: float = 0.0,
                    reward_split: float = REWARD_SPLIT_BASE) -> dict:
    """EV of a single attempt cycle, given EXPLICIT (caller-supplied) probabilities.

    This function never defaults a probability; every argument is required
    so no hidden assumed success rate can enter a call site silently.
    """
    for name, val in (("p1", p1), ("p2_given_p1", p2_given_p1), ("p_reward_given_pass", p_reward_given_pass)):
        if not 0.0 <= val <= 1.0:
            raise ValueError(f"{name} must be a probability in [0,1], got {val}")
    p_success = p1 * p2_given_p1 * p_reward_given_pass
    inflow_on_success = reward_split * reward_profit_usd + FEE_USD * FEE_REFUND_PERCENT
    ev = p_success * inflow_on_success - FEE_USD - marginal_cost_usd
    naive_independent_expected_attempts = (1.0 / p_success) if p_success > 0 else float("inf")
    naive_independent_expected_fee_outlay = FEE_USD * naive_independent_expected_attempts
    return {
        "p1": p1, "p2_given_p1": p2_given_p1, "p_reward_given_pass": p_reward_given_pass,
        "p_success_joint": p_success,
        "reward_profit_usd": reward_profit_usd, "marginal_cost_usd": marginal_cost_usd,
        "reward_split": reward_split,
        "inflow_on_success_usd": inflow_on_success,
        "ev_usd": ev,
        "naive_independent_retry_note": (
            "ILLUSTRATIVE ONLY, NOT A RECOMMENDATION: assumes statistically independent "
            "repeated attempts, which the same-strategy/same-regime caveat in "
            "OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md SS G explicitly rejects."
        ),
        "naive_independent_expected_attempts_to_first_success": naive_independent_expected_attempts,
        "naive_independent_expected_fee_outlay_usd": naive_independent_expected_fee_outlay,
    }


def breakeven_sensitivity_table() -> list[dict]:
    rows = []
    for cost in MARGINAL_COST_GRID_USD:
        for reward in REWARD_PROFIT_GRID_USD:
            p_star = breakeven_joint_probability(reward, cost)
            rows.append({
                "reward_profit_usd": reward,
                "marginal_cost_usd": cost,
                "breakeven_joint_probability": p_star,
                "breakeven_joint_probability_pct": round(p_star * 100, 2),
                "inflow_on_success_usd": reward * REWARD_SPLIT_BASE + FEE_USD,
            })
    return rows


def time_to_cash_floor_days() -> dict:
    """Fastest-possible (floor, not expected) calendar-day path to cash-in-hand.

    Actual Phase1/Phase2 duration is unbounded above (NO_MAX_TRADING_PERIOD)
    and unmeasured for any QM strategy on a Standard FTMO mark-to-market
    simulation; only the provider-side minimums and processing windows are
    known, so this is a lower bound, never an expectation.
    """
    floor_days_to_funded = 2 * MIN_TRADING_DAYS_PER_PHASE  # both phases at their minimum qualifying-day count
    floor_days_to_reward_request = FIRST_REWARD_ELIGIBLE_DAY  # from first LIVE (funded-account) trade
    floor_days_processing = REWARD_REVIEW_BUSINESS_DAYS[0] + PAYOUT_TRANSFER_BUSINESS_DAYS[0]
    return {
        "floor_calendar_days_challenge_to_funded_minimum_qualifying_days": floor_days_to_funded,
        "floor_calendar_days_first_trade_to_reward_eligible": floor_days_to_reward_request,
        "floor_business_days_review_plus_transfer": floor_days_processing,
        "floor_total_calendar_days_illustrative_lower_bound": floor_days_to_funded + floor_days_to_reward_request + floor_days_processing,
        "note": "Lower bound only; Phase1/2 duration is unmeasured and provider-unbounded above.",
    }


def build_report() -> dict:
    return {
        "schema": "qm.ftmo-track-d-economics.v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "account_variant": "FTMO Challenge 2-Step / USD 100000 / Standard",
        "sources": {
            "rulepack": SOURCE_RULEPACK,
            "rulepack_as_of": SOURCE_RULEPACK_AS_OF,
            "withdrawal_terms_url": SOURCE_WITHDRAWAL_URL,
            "withdrawal_terms_fetched": SOURCE_WITHDRAWAL_FETCHED_UTC,
        },
        "provider_constants_usd": {
            "fee": FEE_USD, "fee_refund_percent": FEE_REFUND_PERCENT,
            "reward_split_base": REWARD_SPLIT_BASE, "reward_split_scaling": REWARD_SPLIT_SCALING,
            "phase1_target": PHASE1_TARGET_USD, "phase2_target": PHASE2_TARGET_USD,
            "daily_loss_limit": DAILY_LOSS_LIMIT_USD, "total_loss_floor": TOTAL_LOSS_FLOOR_USD,
            "min_trading_days_per_phase": MIN_TRADING_DAYS_PER_PHASE,
            "no_max_trading_period": NO_MAX_TRADING_PERIOD,
            "min_withdrawal_bank": MIN_WITHDRAWAL_USD_BANK, "min_withdrawal_crypto": MIN_WITHDRAWAL_USD_CRYPTO,
        },
        "internal_risk_guardrails_pct": {
            "per_trade_risk_cap": INTERNAL_PER_TRADE_RISK_CAP_PCT,
            "correlated_cluster_cap": INTERNAL_CORRELATED_CLUSTER_CAP_PCT,
            "total_open_stop_cap": INTERNAL_TOTAL_OPEN_STOP_CAP_PCT,
            "daily_loss_budget": INTERNAL_DAILY_LOSS_BUDGET_PCT,
            "total_drawdown_budget": INTERNAL_TOTAL_DRAWDOWN_BUDGET_PCT,
        },
        "time_to_cash_floor": time_to_cash_floor_days(),
        "breakeven_sensitivity_table": breakeven_sensitivity_table(),
        "no_assumed_probability_asserted": True,
    }


def main() -> None:
    report = build_report()
    out_path = Path(__file__).with_name("track_d_economics_report.json")
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        print(json.dumps(report, indent=2))
        return
    with out_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
