"""FTMO paid-Challenge policy constants and material-change thresholds.

OWNER-DEC-CBE-20260915 (master directive 2026-09-15, sections 13, 14, 15, 63).

Every constant here is an OWNER policy value. AI seats may READ these to shape
recommendations and observability. They may NOT change them: any edit is an
OWNER-only decision and must cite a dated OWNER decision record. There is
deliberately no code path in this package that acts on a paid FTMO Challenge -
the paid decision is executed by the OWNER by hand (directive sections 13-14,
64). See tools/strategy_farm/tests/test_ftmo_no_purchase_guard.py.
"""
from __future__ import annotations

# --- Paid-Challenge product policy (OWNER-only; directive sections 13-14) --------
# Default target product. Fable may EVALUATE other current FTMO products and
# prepare a recommendation, but the default is fixed here and the paid decision
# stays with the OWNER.
DEFAULT_ACCOUNT_SIZE_USD = 100_000
DEFAULT_PRODUCT = "2-Step"
DEFAULT_ACCOUNT_TYPE = "Standard"
DEFAULT_ACCOUNT_LABEL = "FTMO Challenge 2-Step / USD 100000 / Standard"

# Exactly one active paid Challenge at a time (directive section 14). A second
# simultaneous paid Challenge requires a future OWNER decision. This is a policy
# flag consumed by observability; nothing in code provisions an account.
ONE_PAID_CHALLENGE_AT_A_TIME = True
MAX_CONCURRENT_PAID_CHALLENGES = 1

# The paid decision is OWNER-only and cannot be taken by automation.
PAID_DECISION_AUTHORITY = "OWNER"

# OWNER priority for FTMO: probability of success first, speed second
# (directive sections 15, 57).
FTMO_PRIORITY = "SUCCESS_PROBABILITY_OVER_SPEED"

# --- Two-week Demo validation policy (directive section 12) ----------------------
# Minimum representative evidence period before a paid decision. It is a MINIMUM
# evidence window, NOT an "auto-buy after 14 days" trigger.
VALIDATION_MIN_DAYS = 14

# --- Rule-snapshot freshness policy (directive section 63) -----------------------
# The official rule snapshot must be re-verified shortly before any paid decision.
RULE_SNAPSHOT_MAX_AGE_DAYS = 7          # go-criterion (matches rulepack)
RULE_SNAPSHOT_BLOCKER_AGE_DAYS = 30     # older than this -> hard readiness blocker

# --- Material-change semantics (directive follow-up sections 13-14) --------------
# See docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md for the full reasoning.
#
# X = the fraction of prior total book risk whose change makes a risk edit
# material. Book risk today is ~2.5% (8 sleeves x 0.3125%); one sleeve is 12.5%
# of book. X=0.20 means a risk delta touching more than a fifth of deployed book
# risk resets/extends validation, while sub-sleeve tweaks are logged only.
RISK_MATERIAL_BOOK_SHARE_X = 0.20

# Y = the book-risk share below which a mechanics (ex5 hash) change to some
# sleeves is treated as sleeve-material but NOT representative-breaking at the
# portfolio level. Y=0.10 means changing the mechanics of <10% of book risk does
# not invalidate the ~90% of evidence unaffected by the change.
MECHANICS_REPRESENTATIVE_BOOK_SHARE_Y = 0.10

# Absolute floor so a book with tiny total risk cannot make every change "material".
RISK_MATERIAL_ABS_PCT_FLOOR = 0.10  # absolute book-risk-percent points


# --- No paid-transaction code path ----------------------------------------------
# There is deliberately no function in this package that acts on a paid FTMO
# Challenge or touches a money rail. The recommendation enum value
# BUY_100K_2STEP_RECOMMENDED and the "would_fable_buy_today" field are advisory
# OWNER-facing text and use the word "buy", which is fine; what is banned is
# transaction execution and money-rail integration. The banned-token registry
# lives in tests/test_ftmo_no_purchase_guard.py (kept out of the package so the
# guard does not flag its own definition), and the guard scans every module here.
