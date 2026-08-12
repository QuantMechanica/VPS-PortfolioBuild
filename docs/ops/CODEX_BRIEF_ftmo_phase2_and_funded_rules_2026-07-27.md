# Codex brief — FTMO Phase 2 and funded-account rules, exact and cited

Date: 2026-07-27
Requested by: Claude, on OWNER's instruction

## Why this matters

OWNER has set new campaign KPIs: Phase 1 within ~60 days, Phase 2 within ~30 days,
then a funded account producing payouts roughly every two weeks. Claude is
rebuilding the measurement around those KPIs. Every number below feeds directly
into that model, so a wrong or invented value silently corrupts the result.

OWNER has confirmed from experience that **FTMO blocks an account after 30 days
without a trade**. Treat that as established; your job is to find the exact
wording and scope so it can be modelled correctly.

## What is needed — official ftmo.com sources preferred, mark any secondary source

Answer each with a citation. Where FTMO distinguishes account types (Normal vs
Swing, 2-Step vs Instant Funding), state which one the answer applies to. Assume
a **$100,000 2-Step Normal** account unless the rule differs.

### A. Phase 2 (Verification)

1. Profit target (%).
2. Maximum daily loss and maximum total loss (%), and whether they differ from
   Phase 1.
3. Minimum trading days.
4. Maximum trading period, if any.
5. Whether the balance-above-target-with-all-positions-closed condition is the
   same as Phase 1.

### B. The inactivity / dormancy rule

6. Exact wording and the exact threshold. Calendar days or trading days?
7. Does it apply to the Challenge, the Verification, the funded account, or all
   three? Are the thresholds the same for each?
8. What counts as activity — opening a position, closing one, or either? Does a
   position held open across the window count as activity?
9. What is the consequence: account breach, account closure, or a warning first?
   Is it recoverable?

### C. Funded account ("FTMO Account")

10. Maximum daily loss and maximum total loss (%).
11. **Critical for the payout model:** is the maximum-loss floor static at 10%
    below the *initial* balance, or does it move with the account balance or
    equity high-water mark? State this precisely - the whole withdrawal-policy
    question turns on it.
12. **When a payout is withdrawn, what happens to the loss floor?** If the floor
    is static on the initial balance, a withdrawal reduces the buffer above it;
    if the floor rebases on withdrawal, it does not. Which is it?
13. Profit split, and whether it scales.
14. Payout schedule: the default cadence, the minimum interval between payouts,
    whether on-demand payouts are available, and any first-payout waiting period.
15. Whether a payout requires a minimum profit amount.
16. Any consistency, minimum-trading-day, or activity requirement that applies to
    the funded account specifically.

### D. Prohibited practices

17. List the practices FTMO prohibits (the ones that void a funded account), with
    the official wording. We run mechanical MT5 EAs on H1/D1 timeframes holding
    positions from minutes to days, several EAs on separate accounts.
18. Specifically: is running the same or a correlated strategy across multiple
    FTMO accounts restricted? We had considered several parallel accounts each
    running one sleeve. State the rule on copy trading / account correlation
    between accounts held by the same customer.
19. Is there any restriction on EA use, or on holding positions over the weekend
    or over news releases, for a Normal account?

## Hard constraints

- Do **NOT** run `Factory_OFF` or `Factory_ON`.
- Do **NOT** interrupt active T1-T10 backtests.
- Read-only; write only your artifact.
- **Citations mandatory.** Official ftmo.com pages preferred. Mark any secondary
  source clearly as secondary. If a value cannot be found on an official source,
  write `NOT ESTABLISHED` rather than inferring it - an invented number here is
  worse than a gap, because it will be modelled as fact.
- Do not invent commission, swap or DST values.

## Deliverable

`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`, structured as the
sections above, with a summary table at the top of every numeric limit and its
source. Flag explicitly any place where our existing repo documents contradict
the official source.
