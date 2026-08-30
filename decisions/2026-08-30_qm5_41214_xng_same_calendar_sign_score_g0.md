# QM5_41214 XNG Same-Calendar Bernoulli Sign-Score - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41214_xng-samecal-signscore_card.md`,
SHA-256
`64D838D307378117A3FB76781D4A7F05DCA16E02E99E1AF15087F65A893DBF8F`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41214`
- slug: `xng-samecal-signscore`
- strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01`
- source ID:
  `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XNGUSD.DWX`, D1
- intended magic: `412140000`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41214`
after `41213` and wrote exactly one active registry row. The decision did not
guess, hand-edit, or reuse an identity. Magic allocation remains a separate
governed build prerequisite and is not claimed by this decision.

## Source And Traceability

The durable source approval was committed as
`e74d496413d2a9ebaaab9979e85bc8e1806c0df3` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026/source.md`,
SHA-256
`B526454AE66190B5CC3288C709E946F1656ED56DF3B847F04F6C46A02F4617EE`,
committed as `e0fb5ddb24da5c98f0b3968fa09c13f5411950da` before this G0
decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, explicit natural-gas membership,
monthly renewal, and a five-year floor. Papailias, Liu, and Thomakos (2021),
*Journal of Banking & Finance*, provide the nonnegative return-sign map,
equal binary weighting, explicit natural-gas membership, and monthly
lifecycle. Commit-pinned R Core source provides only the null-half
uncorrected proportion-score implementation precedent. The exact single-gas
gate and CFD execution are untested QM translation choices; no performance or
correlation claim transfers.

## Locked Approved Rule

At the first executable normalized `XNGUSD.DWX` D1 broker-month transition,
reconstruct the upcoming calendar month's XNG log return in exact years
`Y-1..Y-10`, skipping missing years and requiring at least five valid
observations. Map each return to one when nonnegative and zero when negative.
For nonnegative count `x`, observation count `n`, and null `p0=0.5`, compute
without continuity correction:

```text
denominator = sqrt(n*p0*(1-p0)) = 0.5*sqrt(n)
score       = (x-n*p0)/denominator = (2*x-n)/sqrt(n)
```

Buy XNG only when `score > +1.0+1e-10`; sell XNG only when
`score < -1.0-1e-10`; consume flat otherwise. Use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen
`3.5*ATR(20,D1)` hard stop, no target, a nonnegative 3,000-point spread cap,
one durable attempt per broker month, next-month renewal, and 40-day stale
repair. Both news axes, legacy news, and Friday close are OFF.

## Reputable-Source Gate

- R1:
  `PASS_WITH_COMPOSITE_STATISTIC_SINGLE_CARRIER_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`.
  Two complete-read peer-reviewed sources cover same-calendar commodities,
  binary signs, and explicit natural-gas membership; pinned primary software
  fixes only the statistic; the exact conjunction and threshold are untested.
- R2: `PASS`. Calendar, normalized endpoints, sample, binary map, null,
  denominator, no-correction rule, strict band, side, attempt, fixed risk,
  stop, spread cap, and lifecycle are locked.
- R3:
  `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native XNG D1 data supply runtime inputs, with label, roll,
  financing, gap, and translation risks explicit.
- R4: `PASS`. Deterministic native arithmetic and framework execution only;
  no trained signal, banned signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned `ok` on
the exact approved card before this decision.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xng_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`F6E5C50549A7A43C7BD047CAA44303A699F2DDF139ACD599EBD5090CFFD80AF4`,
scanned 4,713 registry identities, 1,359 cards, and 45 Strategy Wiki nodes. It
found no exact collision and surfaced only the expected WTI sign-score,
raw-mean XNG, and XAU/XAG sign-score fuzzy neighbors.

Manual review establishes that `QM5_20100` uses the metric XNG return mean,
while this card uses only binary XNG signs and can select the opposite side.
`QM5_41205` uses an even median, MAD scale, and fixed-step Huber location.
`QM5_12567` uses a daily cumulative-RSI(2) pullback under a long trend context
and a short holding lifecycle; this card uses no RSI, oscillator, contiguous
pullback, or intramonth renewal. `QM5_41212` uses the same transparent score
but reads and trades WTI. `QM5_41213` scores synchronized relative
gold-minus-silver returns and owns two opposite metal legs.

For `[0.09,-0.01,-0.01,-0.01,-0.01]`, raw mean buys XNG while this card has
`z=-3/sqrt(5)<-1` and sells. The exact XNG information object, null variance,
sample-size-aware abstention band, durable monthly attempt state, and
single-gas position jointly change direction, participation, and exposure
relative to the incumbent XNG logic.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Build Authorization And Kill Boundary

This G0 decision authorizes deterministic slot-0 magic allocation, one V5 EA
source/binary, one fixed-risk backtest setfile, strict compile/Q01 checks, and
one paced Q02 enqueue when CPU admission is clear. It authorizes no manual
tester run or phase advancement.

Q02 must retire the unchanged card on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any clock, endpoint, sample, binary map, null, denominator,
score, threshold, side, attempt, risk, stop, spread, lifecycle, or determinism
defect. Failure may not be rescued through threshold, sample, tie map,
direction, carrier, stop, hold, spread, or filter changes.

The monthly binary-seasonal XNG clock is structurally different from the
certified daily pullback but realized independence is unproven and remains an
unchanged Q09 decision. No live/demo/shadow/stress/optimization preset,
terminal control, AutoTrading, `T_Live`, deploy/live manifest, portfolio gate,
portfolio admission, correlation waiver, or certification action is
authorized.
