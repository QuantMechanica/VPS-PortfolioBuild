# QM5_41059 Q40 Identity Amendment

Date: 2026-08-18

Decision: `APPROVED`; this record supersedes only the signal-boundary clauses
in the earlier same-date source-approval and G0 records for `QM5_41059`.
Their authority, carrier, source lineage, risk contract, lifecycle, kill
criteria, non-live scope, and safety exclusions remain in force.

## Reason For Amendment

Pre-build semantic review found that a strict-majority sign rule is almost
algebraically equivalent to the already-built sample-median sign rule in
`QM5_41055`: away from zero returns and even-sample ties, both choose the sign
held by more than half the observations. Treating that as a genuinely new
edge would violate the mission's non-duplicate requirement.

The rejected `0.5` formulation was never implemented, compiled, tested, or
enqueued. This amendment occurs before Q01 and fixes the card-of-record.

## Corrected Locked Identity

For five to ten exact prior-year returns of the decision calendar month:

1. map each non-negative return to one and each negative return to zero;
2. calculate equal-weight `positive_frequency = positive_count / n`;
3. BUY when `positive_frequency >= 0.40` and SELL otherwise; and
4. renew at the next normalized broker-month boundary.

The fixed `0.40` threshold is defined by Papailias, Liu, and Thomakos (2021)
for their WTI return-sign-momentum rule. Applying it across historical
occurrences of the same named calendar month is the disclosed composite QM
translation. It is not fitted on QM results and has no optimization surface.

This boundary is materially different from the median: with five observations
`[-0.04, -0.03, -0.02, +0.001, +0.001]`, positive frequency is exactly `0.40`
and this card is long, while both arithmetic mean and sample median are
negative. Q02 must falsify the economic value of that asymmetric state.

## Dedup And Gates

A post-allocation probe using a fresh temporary slug/strategy ID and mechanic
`prior-ten-year-same-calendar-month-log-return-positive-frequency-q40-direction-monthly-wti-renewal`
scanned 4,547 registry rows and 625 cards and returned `CLEAN`, with no fuzzy
match. Manual review distinguishes:

- `QM5_41055`, whose median boundary is approximately the rejected majority;
- `QM5_20099`, which uses the sign of same-calendar return magnitudes;
- `QM5_13150`, which applies `q=0.40` to the twelve immediately preceding
  months rather than matching months across years; and
- `QM5_20251`, which uses a magnitude-based same-calendar mean plus a separate
  recent sign state and requires their agreement.

R1 remains `PASS_WITH_COMPOSITE_TRANSLATION_RISK`; R2 remains `PASS` under the
corrected fixed `0.40` boundary; R3 and R4 are unchanged. The current approved
card is
`strategy-seeds/cards/approved/QM5_41059_wti-samecal-hit_card.md` and this
amendment is its controlling G0 record.

Q02 must additionally retire the identity on any threshold inequality defect
or any attempt to replace `0.40` after results. All prohibitions on manual
backtests, live/demo/shadow/stress/optimization presets, terminal control,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers remain.
