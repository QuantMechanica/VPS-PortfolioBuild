# FTMO 2-Step rule recheck, 2026-09-22

Read-only verification; does not amend frozen simulations or execution policy.

The current [official objectives](https://ftmo.com/en/trading-objectives/) retain
10% then 5% targets, 5% daily equity loss, 10% static overall equity loss and four
entry days in each evaluation phase. Daily resets use CE(S)T, including open P/L
and costs. Do not import the 1-Step trailing-loss or Best Day rules into 2-Step.

The [reward FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/) permits
requests from day 14 after the first funded-account trade, with all positions and
pending orders closed. Review and sending each typically take 1–2 business days;
these are not a guaranteed bank-receipt date. Standard 2-Step share is 80%.

Clarification against the frozen `results/PAYOUT80.md`: the FAQ describes the
method threshold as a **closed profit** minimum ($20 bank wire, $50 crypto), not
explicitly a minimum net reward. Thus that report's division by .80 to infer
$25/$62.50 gross is not supported by the current wording. Preserve the historical
report; treat that inference as superseded. The engine has payment method null
and does not bind either threshold, so this correction does not change its
reported first-positive diagnostic or establish withdrawal eligibility.

[News restrictions](https://ftmo.com/en/faq/can-i-trade-news/) must be verified for
the funded account type and affected instruments. A generic entry blackout does
not itself establish funded-account compliance for later stop/target executions.
