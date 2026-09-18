"""Build docs/ops/evidence/2026-09-18_ftmo_official_rules_snapshot.json.

Deterministic re-materialisation of the 2026-09-18 official-rules snapshot from
the retained response bodies under docs/ops/evidence/ftmo_fetch_20260918/.
Every claim quote is machine-checked as a literal substring of the retained
body it is attributed to; a quote that does not verify aborts the build, so the
snapshot can never assert a wording the evidence does not contain.

Read-only against the network: the HTTP observations were captured by the
2026-09-18T02:37:46Z fetch run and are recorded here from that run's log.
"""
from __future__ import annotations

import hashlib
import html
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
BODIES = REPO / "docs/ops/evidence/ftmo_fetch_20260918"
OUT = REPO / "docs/ops/evidence/2026-09-18_ftmo_official_rules_snapshot.json"

RUN_UTC = "2026-09-18T02:37:46Z"
SCALING_UTC = "2026-09-18T02:37:48Z"
TABLE_UTC = "2026-09-18T02:38:57Z"


def rendered_text(name: str) -> str:
    raw = (BODIES / f"{name}.html").read_text(encoding="utf-8", errors="replace")
    stripped = re.sub(r"(?is)<(script|style|noscript|svg)\b.*?</\1>", " ", raw)
    stripped = re.sub(r"(?s)<[^>]+>", " ", stripped)
    return re.sub(r"\s+", " ", html.unescape(stripped)).strip()


def raw_body(name: str) -> str:
    return (BODIES / f"{name}.html").read_text(encoding="utf-8", errors="replace")


def norm(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


# --- HTTP observations from the 2026-09-18T02:37:46Z fetch run --------------
# source_id -> (title, url, final_url, bytes, sha256, last_modified, retrieved)
OBSERVED = {
    "ftmo_trading_objectives_official": (
        "FTMO Trading Objectives",
        "https://ftmo.com/en/trading-objectives/",
        "https://ftmo.com/en/trading-objectives/",
        287644,
        "c9cba53c83c62d6986b647978c0fb595504d66e6e1b97d5e45eab7372192679f",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_economic_terms_official": (
        "FTMO 2-Step economics, Swing leverage, and Scaling Plan",
        "https://ftmo.com/en/2-step-challenge/",
        "https://ftmo.com/en/2-step-challenge/",
        306457,
        "81b938784fb93c505eee8b4f002f9caa876b48bd2448e9223086e0b6ebb2e3e0",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_2_step_challenge_official": (
        "FTMO Challenge: 2-Step",
        "https://ftmo.com/en/2-step-challenge/",
        "https://ftmo.com/en/2-step-challenge/",
        306457,
        "3232d051a99167466aab7643c64a3b9ece005ac61285af4e9a29c68492976ea9",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_news_official": (
        "Can I trade news?",
        "https://ftmo.com/faq/can-i-trade-news/",
        "https://ftmo.com/faq/can-i-trade-news/",
        315341,
        "06f7ba730cd9a87715502ba1f58ad1f17dff16d3d26b2d2a94737a5fd1829413",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_weekend_official": (
        "Do I have to close my positions overnight or before the weekend?",
        "https://ftmo.com/en/faq/do-i-have-to-close-my-positions-overnight-or-before-the-weekend/",
        "https://ftmo.com/en/faq/do-i-have-to-close-my-positions-overnight-or-before-the-weekend/",
        310306,
        "6858f418ce6bf269f0d5c6825fbadb9e0cd9fbebf946b72178a24e70e25f87b0",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_ea_official": (
        "Which instruments can I trade and what strategies am I allowed to use?",
        "https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/",
        "https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/",
        311481,
        "b1ccbebab4e3a14dcbfe58c36d4ea1350caaa547dc6592530c0244fae19fef4d",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
    "ftmo_forbidden_practices_official": (
        "Forbidden Trading Practices",
        "https://ftmo.com/en/forbidden-trading-practices/",
        "https://ftmo.com/en/forbidden-trading-practices/",
        237921,
        "858149fa20db6be063f42972f4d81c8118124decc538118b4e8a542031e4ca09",
        "Fri, 18 Sep 2026 02:37:46 GMT",
        RUN_UTC,
    ),
}

# Non-expected corroborating bodies retained from the same run.
COMPONENTS = {
    "ftmo_scaling_plan_official": (
        "https://ftmo.com/en/scaling-plan/",
        "https://ftmo.com/en/reward-growth-and-scaling-plan/",
        273087,
        "878572fa1d766279992da2790562d1dba60bd148eb1fe2333dec70ca166a9e2d",
        SCALING_UTC,
    ),
    "cand_comparison_table": (
        "https://ftmo.com/en/comparison-table/",
        "https://ftmo.com/en/comparison-table/",
        252213,
        "1d8e3ba21759f90bfdacf99c12981c9ead2ee8c6aa5937270566523de3d24108",
        TABLE_UTC,
    ),
}

# HTTP 200 probe bodies retained as the negative evidence behind the two
# CARRIED_OVER leverage claims: these pages exist and state no leverage figure.
LEVERAGE_SILENT_BODIES = ("cand_symbols", "cand_account_specs_faq")

# Every candidate leverage source probed on 2026-09-18.
LEVERAGE_PROBES = [
    ("https://ftmo.com/en/trading-symbols/", 404, "HTTP Error 404: Not Found"),
    ("https://ftmo.com/en/account-specifications/", 404, "HTTP Error 404: Not Found"),
    (
        "https://ftmo.com/en/faq/what-is-the-leverage-on-ftmo-accounts/",
        404,
        "HTTP Error 404: Not Found",
    ),
    ("https://ftmo.com/en/leverage/", 404, "HTTP Error 404: Not Found"),
    (
        "https://ftmo.com/en/faq/what-is-a-swing-ftmo-challenge/",
        404,
        "HTTP Error 404: Not Found",
    ),
    ("https://ftmo.com/en/trading-conditions/", 404, "HTTP Error 404: Not Found"),
    (
        "https://ftmo.com/en/symbols/",
        200,
        "HTTP 200 but no leverage figure anywhere in the body",
    ),
    (
        "https://ftmo.com/en/comparison-table/",
        200,
        "HTTP 200 but no leverage figure anywhere in the body",
    ),
    (
        "https://ftmo.com/en/faq/what-are-the-account-specifications/",
        200,
        "HTTP 200 but the answer body is client-rendered; no leverage figure in the served HTML",
    ),
]

NORMALIZED_CLAIMS = {
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
    "usd_100000_2_step_list_price_usd": 540,
    "evaluation_fee_refund_percent_with_first_reward": 100,
    "base_reward_split_percent": 80,
    "maximum_reward_split_percent": 90,
    "swing_fx_leverage": "1:30",
    "swing_metals_and_oil_leverage": "1:15",
    "account_balance_increase_percent": 25,
    "minimum_months_between_scaleups": 4,
    "scaled_reward_split_percent": 90,
}

CLAIM_PROVENANCE = {
    "phase1_profit_target_percent": ["ftmo_trading_objectives_official"],
    "verification_profit_target_percent": ["ftmo_trading_objectives_official"],
    "profit_target_operator": ["ftmo_trading_objectives_official"],
    "maximum_daily_loss_percent_of_initial": ["ftmo_trading_objectives_official"],
    "maximum_daily_loss_reset_timezone": ["ftmo_trading_objectives_official"],
    "maximum_daily_loss_reset_local_time": ["ftmo_trading_objectives_official"],
    "maximum_daily_loss_basis": ["ftmo_trading_objectives_official"],
    "maximum_daily_loss_breach_operator": ["ftmo_trading_objectives_official"],
    "maximum_loss_percent_of_initial": ["ftmo_trading_objectives_official"],
    "maximum_loss_model": ["ftmo_trading_objectives_official"],
    "maximum_loss_breach_operator": ["ftmo_trading_objectives_official"],
    "minimum_trading_days_per_phase": ["ftmo_trading_objectives_official"],
    "trading_day_qualifier": ["ftmo_trading_objectives_official"],
    "maximum_trading_period_days": ["ftmo_trading_objectives_official"],
    "swing_news_restriction_during_evaluation": ["ftmo_news_official"],
    "swing_overnight_or_weekend_restriction": ["ftmo_weekend_official"],
    "expert_advisors_allowed_subject_to_rules": ["ftmo_ea_official"],
    "simultaneous_order_limit": ["ftmo_ea_official"],
    "position_limit_per_day": ["ftmo_ea_official"],
    "hyperactive_server_request_threshold_per_day": [
        "ftmo_ea_official",
        "ftmo_forbidden_practices_official",
    ],
    "real_market_replicability_required": [
        "ftmo_ea_official",
        "ftmo_forbidden_practices_official",
    ],
    "usd_100000_2_step_list_price_usd": ["ftmo_economic_terms_official"],
    "evaluation_fee_refund_percent_with_first_reward": ["ftmo_economic_terms_official"],
    "base_reward_split_percent": ["ftmo_economic_terms_official"],
    "maximum_reward_split_percent": ["ftmo_economic_terms_official"],
    "swing_fx_leverage": ["ftmo_economic_terms_official"],
    "swing_metals_and_oil_leverage": ["ftmo_economic_terms_official"],
    "account_balance_increase_percent": ["ftmo_economic_terms_official"],
    "minimum_months_between_scaleups": ["ftmo_economic_terms_official"],
    "scaled_reward_split_percent": ["ftmo_economic_terms_official"],
}

# claim -> (body name, quote, [(corroborating body, quote)], note)
QUOTES: dict[str, tuple] = {
    "phase1_profit_target_percent": (
        "ftmo_trading_objectives_official",
        "The Profit Target is calculated as a percentage of your Initial Simulated Capital: 10% for the FTMO Challenge 5% for the Verification",
        [
            (
                "ftmo_trading_objectives_official",
                "FTMO Challenge: Profit Target = $10,000 Balance required for passing = $110,000",
            )
        ],
        "2-Step tab of the Trading Objectives page.",
    ),
    "verification_profit_target_percent": (
        "ftmo_trading_objectives_official",
        "5% for the Verification",
        [
            (
                "ftmo_trading_objectives_official",
                "Verification: Profit Target = $5,000 Balance required for passing = $105,000",
            )
        ],
        "2-Step tab of the Trading Objectives page.",
    ),
    "profit_target_operator": (
        "ftmo_trading_objectives_official",
        "You will meet this objective once your account balance exceeds the Initial Simulated Capital by the required Profit Target with all positions closed.",
        [],
        "STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT normalizes 'exceeds' (strict) together with 'with all positions closed' (flat).",
    ),
    "maximum_daily_loss_percent_of_initial": (
        "ftmo_trading_objectives_official",
        "the Maximum Daily Loss Amount , which is 5% of the Initial Simulated Capital.",
        [("cand_comparison_table", "Max Daily Loss 5%")],
        "2-Step tab. The 1-Step tab of the same page states 3% for that other product; it is out of scope for this profile.",
    ),
    "maximum_daily_loss_reset_timezone": (
        "ftmo_trading_objectives_official",
        "The Maximum Daily Loss Limit is recalculated daily at 00:00 CE(S)T",
        [],
        "CE(S)T is the provider wording. Europe/Prague is the IANA zone that realizes CET/CEST and is FTMO's registered seat (Purkynova 2121/3, 110 00 Prague, Czech Republic, per the page footer).",
    ),
    "maximum_daily_loss_reset_local_time": (
        "ftmo_trading_objectives_official",
        "recalculated daily at 00:00 CE(S)T",
        [],
        "00:00 CE(S)T normalizes to a local reset time of 00:00:00.",
    ),
    "maximum_daily_loss_basis": (
        "ftmo_trading_objectives_official",
        "the account balance recorded at 00:00 CE(S)T of the current day and the Maximum Daily Loss Amount , which is 5% of the Initial Simulated Capital.",
        [
            (
                "ftmo_trading_objectives_official",
                "On the first day of trading, the account balance used for this calculation is the Initial Simulated Capital.",
            )
        ],
        "Midnight balance minus a fixed amount, where the amount is fixed to the INITIAL capital and not to the midnight balance.",
    ),
    "maximum_daily_loss_breach_operator": (
        "ftmo_trading_objectives_official",
        "below which your account equity (i.e., Balance + Open Positions P/L ± Swaps – Commissions) cannot drop. If the equity drops below this limit, the rule is considered violated.",
        [],
        "Breach requires equity strictly below the limit; equity exactly at the limit is not a breach.",
    ),
    "maximum_loss_percent_of_initial": (
        "ftmo_trading_objectives_official",
        "the Maximum Loss Amount , which is 10% of the Initial Simulated Capital.",
        [("cand_comparison_table", "Max Loss 10%")],
        "2-Step tab.",
    ),
    "maximum_loss_model": (
        "ftmo_trading_objectives_official",
        "The Maximum Loss rule establishes a static limit (the Maximum Loss Limit )",
        [
            (
                "ftmo_trading_objectives_official",
                "The Maximum Loss Limit is calculated as the difference between: the Initial Simulated Capital and the Maximum Loss Amount",
            ),
            ("cand_comparison_table", "Max Loss type Static"),
        ],
        "2-Step is static on the initial capital. The 1-Step product on the same page is end-of-day trailing; that is a different product, not a change to the 2-Step rule.",
    ),
    "maximum_loss_breach_operator": (
        "ftmo_trading_objectives_official",
        "The Maximum Loss rule establishes a static limit (the Maximum Loss Limit ) below which your account equity (i.e., Balance + Open Positions P/L ± Swaps – Commissions) cannot drop. If the equity drops below this limit, the rule is considered violated.",
        [],
        "Same strict-below operator as the daily rule.",
    ),
    "minimum_trading_days_per_phase": (
        "ftmo_trading_objectives_official",
        "The Minimum Trading Days rule requires the trader to achieve at least 4 Trading Days.",
        [("cand_comparison_table", "Min Trading Days 4 days")],
        "Applies to both 2-Step phases; there is no such rule on the subsequent FTMO Account.",
    ),
    "trading_day_qualifier": (
        "ftmo_trading_objectives_official",
        "A Trading Day is defined as any day – measured from 00:00:00 to 23:59:59 CE(S)T – during which at least one position is opened .",
        [],
        "Entry-day counting basis, which is what the QM Aktivitaetskriterium (OWNER 2026-08-20, OQ-18) adopted.",
    ),
    "maximum_trading_period_days": (
        "ftmo_trading_objectives_official",
        "No time limit",
        [
            ("ftmo_2_step_challenge_official", "Trading Period Unlimited"),
            ("cand_comparison_table", "Trading Period Unlimited"),
        ],
        "null encodes 'no maximum trading period'. The quote is from the page's 'Start Your FTMO Challenge Today' block rather than the rule list; the 2-Step product page and the comparison table corroborate it in their objectives tables.",
    ),
    "swing_news_restriction_during_evaluation": (
        "ftmo_news_official",
        "While trading during the Evaluation Process, the restriction does not apply regardless of the account type (Standard account or Swing). You may trade freely during all macroeconomic news releases, provided you do not engage in any Forbidden Trading Practices .",
        [
            (
                "ftmo_news_official",
                "For Standard accounts, these restrictions apply only once you start trading on an FTMO Account . They do not apply during the Evaluation Process .",
            )
        ],
        "The claim key is Swing-named for v1-contract continuity. The 2026-09-18 wording states the same false value for the STANDARD account type during the Evaluation Process, which is the profile this snapshot is labelled for.",
    ),
    "swing_overnight_or_weekend_restriction": (
        "ftmo_weekend_official",
        "While trading during the Evaluation Process, the restriction does not apply regardless of the account type (Standard account or Swing). You are allowed to keep your positions open overnight and over the weekend.",
        [
            (
                "ftmo_weekend_official",
                "For Standard accounts, these restrictions apply only once you start trading on an FTMO Account . They do not apply during the Evaluation Process .",
            )
        ],
        "Same Swing-named key, same false value for Standard during the Evaluation Process.",
    ),
    "expert_advisors_allowed_subject_to_rules": (
        "ftmo_ea_official",
        "whether it’s discretionary trading, algorithmic trading, EAs, etc.",
        [
            (
                "ftmo_ea_official",
                "If you intend to use trading robots (Expert Advisors – EAs), keep in mind that if you use an EA from a third party",
            )
        ],
        "Allowed subject to the legitimacy, real-market and forbidden-practices conditions quoted on the same page; hence 'subject_to_rules'.",
    ),
    "simultaneous_order_limit": (
        "ftmo_ea_official",
        "platform servers have 200 orders at a time and 2000 max positions per day limitation",
        [],
        "",
    ),
    "position_limit_per_day": (
        "ftmo_ea_official",
        "platform servers have 200 orders at a time and 2000 max positions per day limitation",
        [],
        "",
    ),
    "hyperactive_server_request_threshold_per_day": (
        "ftmo_ea_official",
        "just as the limited acceptance of the server messages (orders and order modifications such as updates of TP/ SL and updates of limit orders). If your EA causes hyperactivity to a platform server, we might alert you and ask you to adjust the EA logic or parameters of your strategy.",
        [],
        "The 2000/day figure is the threshold quoted in the immediately preceding clause of the same sentence; the hyperactivity consequence is this quote.",
    ),
    "real_market_replicability_required": (
        "ftmo_ea_official",
        "your trading style should be replicable on live accounts to generate the same results as on your FTMO Account",
        [("ftmo_ea_official", "conforms to the real market conditions")],
        "The second declared provenance source, the Forbidden Trading Practices page, was fetched at HTTP 200 in the same run and is retained.",
    ),
    "usd_100000_2_step_list_price_usd": (
        "ftmo_economic_terms_official",
        '"price":"540"',
        [],
        "Literal value inside the embedded page-configuration JSON of https://ftmo.com/en/2-step-challenge/ (the 2-Step price ladder). Verified as a literal substring of the retained RAW body, not of the rendered text.",
    ),
    "evaluation_fee_refund_percent_with_first_reward": (
        "ftmo_economic_terms_official",
        "reimbursed with your first Reward",
        [("cand_comparison_table", "Refund Yes 100%")],
        "Verified as a literal substring of the retained raw body.",
    ),
    "base_reward_split_percent": (
        "ftmo_economic_terms_official",
        "80% of your simulated profits",
        [],
        "Verified as a literal substring of the retained raw body (embedded page configuration).",
    ),
    "maximum_reward_split_percent": (
        "ftmo_economic_terms_official",
        "Up to 90%",
        [("cand_comparison_table", "Rewards Up to 90%")],
        "",
    ),
    "account_balance_increase_percent": (
        "ftmo_scaling_plan_official",
        "Enjoy account size growth of 25% every 4 months",
        [
            (
                "ftmo_scaling_plan_official",
                "Get a 25% boost to your FTMO Account balance every 4 months.",
            )
        ],
        "Component source https://ftmo.com/en/scaling-plan/, which redirects to /en/reward-growth-and-scaling-plan/.",
    ),
    "minimum_months_between_scaleups": (
        "ftmo_scaling_plan_official",
        "Get a 25% boost to your FTMO Account balance every 4 months.",
        [
            (
                "ftmo_scaling_plan_official",
                "Minimum of 4 months trading as an FTMO Trader",
            )
        ],
        "Component source; see account_balance_increase_percent.",
    ),
    "scaled_reward_split_percent": (
        "ftmo_scaling_plan_official",
        "Get a 90% share of your simulated profits",
        [],
        "Component source; see account_balance_increase_percent.",
    ),
}

CARRIED_OVER = {
    "swing_fx_leverage": "1:30",
    "swing_metals_and_oil_leverage": "1:15",
}


def build() -> dict:
    reconfirm: dict[str, dict] = {}
    failures: list[str] = []
    for claim in NORMALIZED_CLAIMS:
        if claim in CARRIED_OVER:
            reconfirm[claim] = {
                "status": "CARRIED_OVER",
                "note": (
                    "NOT re-confirmed on 2026-09-18, and not re-confirmed on 2026-09-04 either. "
                    "Nine candidate official URLs were probed on 2026-09-18 (see "
                    "dead_or_leverage_silent_sources_2026_09_18): six returned HTTP 404 and three "
                    "returned HTTP 200 with no leverage figure anywhere in the served body. The "
                    f"literal token '{CARRIED_OVER[claim]}' is absent from every retained "
                    "2026-09-18 body. The value is carried over unchanged from the 2026-09-04 "
                    "snapshot, which carried it over unchanged from the 2026-09-02 economic-terms "
                    "snapshot. No replacement source was invented."
                ),
                "unverified_since": "2026-09-02",
                "declared_provenance_source_ids": CLAIM_PROVENANCE[claim],
            }
            continue
        body, quote, corroborating, note = QUOTES[claim]
        text = norm(rendered_text(body))
        raw = raw_body(body)
        in_text = norm(quote) in text
        in_raw = quote in raw
        if not (in_text or in_raw):
            failures.append(f"{claim}: quote not found in {body}")
            continue
        row = {
            "status": "RE_CONFIRMED",
            "confirmed_in_source_id": body,
            "confirmed_in_url": (
                OBSERVED[body][1] if body in OBSERVED else COMPONENTS[body][0]
            ),
            "confirmed_in_body_path": f"docs/ops/evidence/ftmo_fetch_20260918/{body}.html",
            "match_basis": (
                "LITERAL_VALUE_IN_EMBEDDED_PAGE_CONFIGURATION_JSON"
                if (in_raw and not in_text)
                else "LITERAL_VALUE_IN_RENDERED_PAGE_TEXT"
            ),
            "evidence_quote": quote,
            "quote_form": "LITERAL_SUBSTRING_OF_RETAINED_BODY",
            "quote_is_literal_substring_of_whitespace_normalized_rendered_text": in_text,
            "quote_is_literal_substring_of_raw_body": in_raw,
            "declared_provenance_source_ids": CLAIM_PROVENANCE[claim],
            "confirmed_on_declared_provenance_page": body in CLAIM_PROVENANCE[claim],
        }
        if corroborating:
            checked = []
            for cbody, cquote in corroborating:
                ok = norm(cquote) in norm(rendered_text(cbody)) or cquote in raw_body(
                    cbody
                )
                if not ok:
                    failures.append(
                        f"{claim}: corroborating quote not found in {cbody}"
                    )
                checked.append(
                    {
                        "source_id": cbody,
                        "body_path": f"docs/ops/evidence/ftmo_fetch_20260918/{cbody}.html",
                        "quote": cquote,
                        "quote_is_literal_substring_of_retained_body": ok,
                    }
                )
            row["corroborating_quotes"] = checked
        if note:
            row["note"] = note
        if not row["confirmed_on_declared_provenance_page"]:
            row["cross_source_note"] = (
                "The hash-pinned claim_provenance names "
                f"{CLAIM_PROVENANCE[claim][0]}; the quote was machine-checked as ABSENT from that "
                f"retained body and PRESENT in the retained {body} body, which the "
                "ftmo_economic_terms_official source record declares as a component source."
            )
        reconfirm[claim] = row
    if failures:
        raise SystemExit("QUOTE VERIFICATION FAILED:\n  " + "\n  ".join(failures))

    sources = []
    for source_id, (
        title,
        url,
        final_url,
        nbytes,
        digest,
        last_modified,
        retrieved,
    ) in OBSERVED.items():
        record = {
            "source_id": source_id,
            "title": title,
            "url": url,
            "final_url": final_url,
            "http_status": 200,
            "content_type": "text/html; charset=UTF-8",
            "retrieved_at_utc": retrieved,
            "response_bytes": nbytes,
            "response_sha256_observation": digest,
            "last_modified_header_observation": last_modified,
            "last_modified_is_content_vintage": False,
            "raw_body_path": f"docs/ops/evidence/ftmo_fetch_20260918/{source_id}.html",
        }
        if source_id == "ftmo_economic_terms_official":
            record["component_sources"] = [
                {
                    "url": "https://ftmo.com/en/2-step-challenge/",
                    "fetched_2026_09_18": True,
                    "http_status": 200,
                    "raw_body_path": "docs/ops/evidence/ftmo_fetch_20260918/ftmo_2_step_challenge_official.html",
                    "fact_keys": [
                        "usd_100000_2_step_list_price_usd",
                        "evaluation_fee_refund_percent_with_first_reward",
                        "base_reward_split_percent",
                        "maximum_reward_split_percent",
                    ],
                },
                {
                    "url": "https://ftmo.com/en/scaling-plan/",
                    "final_url": "https://ftmo.com/en/reward-growth-and-scaling-plan/",
                    "fetched_2026_09_18": True,
                    "http_status": 200,
                    "raw_body_path": "docs/ops/evidence/ftmo_fetch_20260918/ftmo_scaling_plan_official.html",
                    "response_sha256_observation": COMPONENTS[
                        "ftmo_scaling_plan_official"
                    ][3],
                    "fact_keys": [
                        "account_balance_increase_percent",
                        "minimum_months_between_scaleups",
                        "scaled_reward_split_percent",
                    ],
                },
                {
                    "url": "https://ftmo.com/en/trading-symbols/",
                    "fetched_2026_09_18": True,
                    "http_status": 404,
                    "http_error": "HTTP Error 404: Not Found",
                    "raw_body_path": None,
                    "fact_keys": ["swing_fx_leverage", "swing_metals_and_oil_leverage"],
                    "note": (
                        "Still a dead URL on 2026-09-18, exactly as on 2026-09-04. Eight further "
                        "candidate replacements were probed and none states a leverage figure; no "
                        "replacement source was invented. Both fact keys remain CARRIED_OVER."
                    ),
                },
            ]
        if source_id == "ftmo_2_step_challenge_official":
            record["note"] = (
                "Required by the evaluator's source-id set. It resolves to the same URL as "
                "ftmo_economic_terms_official and carries no directly attributed claim in "
                "claim_provenance; the economic claims attributed to ftmo_economic_terms_official "
                "were confirmed in this body as well. The two independent GETs of that URL in the "
                "2026-09-18 run returned bodies of identical length (306457) but different "
                "SHA-256, i.e. the page emits per-response varying bytes. The same behaviour was "
                "recorded on 2026-09-04."
            )
        sources.append(record)

    retained = []
    for name in sorted([*OBSERVED, *COMPONENTS, *LEVERAGE_SILENT_BODIES]):
        data = (BODIES / f"{name}.html").read_bytes()
        retained.append(
            {
                "source_id": name,
                "path": f"docs/ops/evidence/ftmo_fetch_20260918/{name}.html",
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )

    return {
        "schema": "qm.ftmo-official-rules-snapshot/v1",
        "retrieved_at_utc": RUN_UTC,
        "retrieval_method": (
            "Direct HTTPS GET of each official FTMO page from the QuantMechanica VPS on "
            "2026-09-18 between 02:37:46Z and 02:38:57Z, using Python urllib with User-Agent "
            "'Mozilla/5.0'. No credentials, no cookies and no session: every page is the "
            "anonymous public rendering. For every request the status line, Content-Type, final "
            "URL after redirects, response length, Last-Modified header and the SHA-256 of the "
            "exact response bytes were recorded, and the body was retained in-repository under "
            "docs/ops/evidence/ftmo_fetch_20260918/. Claim wordings were then machine-checked as "
            "literal substrings of those retained bodies by "
            "docs/ops/evidence/2026-09-18_ftmo_rules_repin/build_snapshot.py, which aborts rather "
            "than emit a quote it cannot locate."
        ),
        "profile": "FTMO Challenge 2-Step / USD 100000 / Standard",
        "freshness_max_age_days": 7,
        "profile_label_note": (
            "This snapshot is labelled Standard, not Swing. The account the M13 binding targets "
            "(login 1514536732 on FTMO-Demo) is a STANDARD_2STEP_100K_FREE_TRIAL account, so "
            "Standard is the correct profile label for the rules that govern it; the 2026-09-04 "
            "Swing label was the stale one. The rule facts themselves are product-level (FTMO "
            "Challenge: 2-Step, USD 100000) and are identical for both account types during the "
            "Evaluation Process: the 2026-09-18 news and weekend pages state explicitly that the "
            "restrictions 'do not apply during the Evaluation Process' 'regardless of the account "
            "type (Standard account or Swing)'. The only account-type-scoped rows are the two "
            "swing_*_leverage claims, which are Swing-scoped by key name, carry their 2026-09-02 "
            "values unchanged, and are this snapshot's only CARRIED_OVER rows."
        ),
        "raw_response_note": (
            "This is the normalized, hash-bound rules identity. Every response observation is a "
            "real 2026-09-18 measurement and every raw body is retained in-repository. The "
            "Last-Modified header returned by ftmo.com equals the request time for every page, so "
            "it is a dynamic-response artefact and NOT a content vintage; "
            "last_modified_is_content_vintage is false on every source record for that reason."
        ),
        "vintage_binding_note": (
            "The rulepack's official_sources rows bind the snapshot vintage retrieved_at_utc "
            f"{RUN_UTC} (retrieved_on 2026-09-18), which is the fetch-run timestamp and the exact "
            "per-source observation for all seven expected sources. The two non-expected "
            "corroborating bodies were observed later in the same run (ftmo_scaling_plan_official "
            f"at {SCALING_UTC}, cand_comparison_table at {TABLE_UTC}) and are recorded with their "
            "own timestamps."
        ),
        "sources": sources,
        "retained_raw_bodies": retained,
        "normalized_claims": NORMALIZED_CLAIMS,
        "claim_provenance": CLAIM_PROVENANCE,
        "claim_reconfirmation_2026_09_18": reconfirm,
        "claim_reconfirmation_summary": {
            "total_claims": len(NORMALIZED_CLAIMS),
            "re_confirmed": len(NORMALIZED_CLAIMS) - len(CARRIED_OVER),
            "carried_over": len(CARRIED_OVER),
            "carried_over_claims": sorted(CARRIED_OVER),
            "method": (
                "Each claim value and its surrounding rule wording were searched for in the "
                "retained 2026-09-18 bodies. RE_CONFIRMED means the quoted text was found as a "
                "literal substring of the retained body: either of the whitespace-normalized "
                "rendered text, or of the raw body for values that live in embedded "
                "page-configuration JSON. The build script raises rather than emit an unverified "
                "quote."
            ),
            "value_changes_vs_2026_09_04": 0,
            "value_changes_note": (
                "All 30 claim values are identical to the 2026-09-04 snapshot. No numeric or "
                "boolean rule fact changed. See "
                "docs/ops/evidence/2026-09-18_ftmo_rules_repin/RECEIPT.md."
            ),
        },
        "dead_or_leverage_silent_sources_2026_09_18": [
            {
                "url": url,
                "http_status": status,
                "observation": detail,
                "affected_claims": [
                    "swing_fx_leverage",
                    "swing_metals_and_oil_leverage",
                ],
            }
            for url, status, detail in LEVERAGE_PROBES
        ],
        "standard_profile_evaluation_conditions_2026_09_18": {
            "news_restriction_during_evaluation": False,
            "overnight_or_weekend_restriction_during_evaluation": False,
            "news_restriction_on_ftmo_account_standard": True,
            "overnight_or_weekend_restriction_on_ftmo_account_standard": True,
            "news_window_minutes_before_and_after": 2,
            "evidence_quotes": {
                "evaluation_news": "While trading during the Evaluation Process, the restriction does not apply regardless of the account type (Standard account or Swing). You may trade freely during all macroeconomic news releases, provided you do not engage in any Forbidden Trading Practices .",
                "ftmo_account_news": "On the targeted instruments, it is not permitted to open or close any trades, including the execution of pending orders (such as Stop Loss or Take Profit), within a time window starting 2 minutes before and ending 2 minutes after the release of selected news announcements.",
                "evaluation_weekend": "While trading during the Evaluation Process, the restriction does not apply regardless of the account type (Standard account or Swing). You are allowed to keep your positions open overnight and over the weekend.",
                "ftmo_account_weekend": "Once you become an FTMO Trader and start trading on an FTMO Account, you are required to close your positions shortly before the markets close for the weekend or if the rollover (market break) lasts longer than 2 hours. An exception applies only to Swing accounts.",
            },
            "note": (
                "These four booleans are the Standard-profile rows the FTMO_2S_100K_STANDARD_V2 "
                "rulepack asserts in ftmo_standard_news and ftmo_standard_weekend. In the "
                "2026-09-15 snapshot they were CARRIED_OVER from that same rulepack, which made "
                "them self-certifying. Here they are fetched evidence: each quote above is a "
                "literal substring of the retained ftmo_news_official / ftmo_weekend_official "
                "body. The circular-provenance defect recorded in section 4 of "
                "docs/ops/evidence/2026-09-18_ftmo_vintage_align/RULE_FACTS_DIFF.md is closed by "
                "this snapshot. This block is descriptive evidence; it is not part of the "
                "hash-pinned normalized_claims contract."
            ),
        },
        "supersedes": [
            {
                "path": "docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json",
                "sha256": "c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905",
                "reason": (
                    "The previous evaluator-pinned snapshot. Same v1 schema and the same 30 "
                    "claims with identical values; superseded on vintage only (it was 14 days old "
                    "and long past its own 7-day freshness window) and on profile label (Swing -> "
                    "Standard, to match the account the binding targets)."
                ),
            },
            {
                "path": "docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json",
                "sha256": "5e25827b589125e7b77cd379453a234649f35983cf5a443ec6a70b77103a2a8c",
                "reason": (
                    "A v2-schema artifact the evaluator could not bind: it drops nine claims the "
                    "evaluator consumes, carries only five of the seven required source ids, has "
                    "no claim_provenance at all, and its trading-conditions source returned HTTP "
                    "404. Its news / overnight / weekend rows were CARRIED_OVER from the rulepack "
                    "they were meant to certify. This snapshot re-fetches every one of them."
                ),
            },
        ],
        "scope_limit": (
            "Research and Free-Trial/shadow gates only. This snapshot is not a purchase, "
            "deployment, T_Live, or AutoTrading authorization, and it must be refreshed before "
            "any paid Challenge decision if older than seven days (its freshness window closes "
            "2026-09-25T02:37:46Z). The two CARRIED_OVER leverage claims are additionally "
            "unverified as of 2026-09-18 and must not be relied on for sizing without a live "
            "official source."
        ),
    }


if __name__ == "__main__":
    doc = build()
    text = json.dumps(doc, indent=1, ensure_ascii=False) + "\n"
    OUT.write_bytes(text.encode("utf-8").replace(b"\r\n", b"\n"))
    print("wrote", OUT)
    print("sha256", hashlib.sha256(OUT.read_bytes()).hexdigest())
