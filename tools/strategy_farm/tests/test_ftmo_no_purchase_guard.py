"""Policy guard: no paid-Challenge purchase code path in the ftmo package.

Directive section 70: 'paid purchase cannot occur through automation' and 'only
one paid-Challenge policy represented'. The paid decision is OWNER-only (sections
13-14, 64). Slice f1_ftmo_validation_readiness.
"""
from __future__ import annotations

from pathlib import Path

from tools.strategy_farm.ftmo import policy_config

PACKAGE_DIR = Path(policy_config.__file__).resolve().parent

# Transaction-execution / money-rail tokens that must never appear in the package
# source. Defined HERE (not in the package) so the guard does not flag its own
# registry. The word "buy" is intentionally NOT here: the advisory enum
# BUY_100K_2STEP_RECOMMENDED and would_fable_buy_today are OWNER-facing text.
FORBIDDEN = (
    "check" "out",  # split so this test file is not self-flagging if ever scanned
    "pay" "ment",
    "paypal",
    "stripe",
    "add_to_cart",
    "place_order",
    "credit_card",
    "card_number",
    "billing",
    "execute_purchase",
    "make_purchase",
    "do_purchase",
    "submit_payment",
)


def _package_sources():
    return sorted(PACKAGE_DIR.glob("*.py"))


def test_no_transaction_or_payment_tokens_in_package():
    offenders = []
    for path in _package_sources():
        text = path.read_text(encoding="utf-8").lower()
        for token in FORBIDDEN:
            if token in text:
                offenders.append((path.name, token))
    assert not offenders, f"forbidden purchase/payment tokens found: {offenders}"


def test_no_http_post_in_package():
    """No module POSTs anything; rule fetching is read-only GET."""
    offenders = []
    for path in _package_sources():
        text = path.read_text(encoding="utf-8")
        for needle in (".post(", 'method="POST"', "method='POST'", "requests.post"):
            if needle in text:
                offenders.append((path.name, needle))
    assert not offenders, f"unexpected HTTP POST in package: {offenders}"


def test_single_paid_challenge_policy_constants():
    assert policy_config.ONE_PAID_CHALLENGE_AT_A_TIME is True
    assert policy_config.MAX_CONCURRENT_PAID_CHALLENGES == 1
    assert policy_config.DEFAULT_ACCOUNT_SIZE_USD == 100_000
    assert policy_config.DEFAULT_PRODUCT == "2-Step"
    assert policy_config.PAID_DECISION_AUTHORITY == "OWNER"


def test_no_second_conflicting_default_size():
    """Only one paid-challenge default size represented in the package."""
    # grep for a hard-coded competing size default; 200000/50000 may appear only
    # as leverage-exception context, never as a DEFAULT_ACCOUNT_SIZE.
    for path in _package_sources():
        text = path.read_text(encoding="utf-8")
        assert "DEFAULT_ACCOUNT_SIZE_USD = 50_000" not in text
        assert "DEFAULT_ACCOUNT_SIZE_USD = 200_000" not in text
