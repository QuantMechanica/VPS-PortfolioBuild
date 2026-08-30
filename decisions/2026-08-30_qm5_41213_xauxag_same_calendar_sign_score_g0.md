# QM5_41213 XAU/XAG Same-Calendar Relative Bernoulli Sign-Score - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41213_xauxag-samecal-signscore_card.md`,
SHA-256
`43271012D2B56CC1409BF488A4957D7FDFD9807CAC765C2E44B023F1F7E9CDF4`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41213`
- slug: `xauxag-samecal-signscore`
- strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026_S01`
- source ID:
  `KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- intended magics: `412130000`, `412130001`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41213`
after `41212` and wrote exactly one active registry row. The decision did not
guess, hand-edit, or reuse an identity. Magic allocation remains a separate
governed build prerequisite and is not claimed by this decision.

## Source And Traceability

The durable source approval was committed as
`3d992f08934f929ddc7883d68beb22b68acc8708` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026/source.md`,
SHA-256
`5BC8F9DCF17BA58CB33B1B7E0437EF2E40E6BCB8C61FAC1AD243BF4B89E3561B`,
committed as `b2839d5a8af0f06ebb60a242a095f4953acc1f95` before this G0
decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, monthly renewal, and a five-year
floor. Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance*,
provide the governed XAU/XAG cross-sectional carrier and one-month
opposite-leg hold. Papailias, Liu, and Thomakos (2021), *Journal of Banking &
Finance*, provide the nonnegative return-sign map and equal binary weighting.
Commit-pinned R Core source provides only the null-half uncorrected
proportion-score implementation precedent. The exact relative two-metal gate
and CFD execution are untested QM translation choices; no performance or
correlation claim transfers.

## Locked Approved Rule

At the first executable normalized `XAUUSD.DWX` D1 broker-month transition,
reconstruct the upcoming calendar month's synchronized XAU-minus-XAG relative
log return in exact years `Y-1..Y-10`, skipping missing years and requiring at
least five valid pairs. Map each relative return to one when nonnegative and
zero when negative. For nonnegative count `x`, paired count `n`, and null
`p0=0.5`, compute without continuity correction:

```text
denominator = sqrt(n*p0*(1-p0)) = 0.5*sqrt(n)
score       = (x-n*p0)/denominator = (2*x-n)/sqrt(n)
```

Buy XAU and sell XAG only when `score > +1.0+1e-10`; sell XAU and buy XAG
only when `score < -1.0-1e-10`; consume flat otherwise. Split one package
budget with `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` into
equal fixed-risk halves, use frozen `3.5*ATR(20,D1)` per-leg hard stops, no
targets, nonnegative 1,500/3,000-point XAU/XAG spread caps, one durable
attempt per broker month, atomic package repair, next-month renewal, and
40-day stale repair. Both news axes, legacy news, and Friday close are OFF.

## Reputable-Source Gate

- R1:
  `PASS_WITH_COMPOSITE_STATISTIC_PAIR_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`.
  Three complete-read peer-reviewed sources cover same-calendar commodities,
  binary signs, and the XAU/XAG cross-sectional carrier; pinned primary
  software fixes only the statistic; the exact conjunction and fixed
  threshold remain untested.
- R2: `PASS`. Calendar, normalized synchronized endpoints, sample, relative
  orientation, binary map, null, denominator, no-correction rule, strict
  band, side, attempt, shared fixed risk, stops, spread caps, atomicity, and
  lifecycle are locked.
- R3:
  `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native XAU/XAG D1 data supply runtime inputs, with label, roll,
  financing, fill, legging, and translation risks explicit.
- R4: `PASS`. Deterministic native arithmetic and framework execution only;
  no trained signal, banned signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned `ok` on
the exact approved card before this decision.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`4F4932048D4AE37D7E9ED6CC691FBAEE9CD418030C71B46C60F4A4A1AF765776`,
scanned 4,712 registry identities, 1,358 cards, and 45 Strategy Wiki nodes. It
found no exact collision and surfaced only the expected raw-mean XAU/XAG and
single-WTI sign-score fuzzy neighbors.

Manual review establishes that `QM5_20186` uses metric relative-return mean,
while this card uses only binary relative signs and can select the opposite
side. `QM5_41212` uses the same transparent score but observes absolute WTI
returns and owns a single WTI position; this card observes synchronized
XAU-minus-XAG returns and requires two opposite metal legs. `QM5_41210` uses a
magnitude mean and sample standard error and can remain flat when this card
trades. Signed-rank and Huber siblings preserve ordering or distance. The
fixed fixtures in the card prove both direction and participation
disagreements.

The relative binary information object, null variance, sample-size-aware
score, symmetric abstention band, two-metal carrier, and atomic package are
jointly load bearing rather than a parameter or symbol rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_BASKET`.

## Build Authorization And Kill Boundary

This G0 decision authorizes deterministic slot-0 and slot-1 magic allocation,
one V5 EA source/binary, one logical-basket fixed-risk backtest setfile, strict
compile/Q01 checks, and one paced Q02 enqueue when CPU admission is clear. It
authorizes no manual tester run or phase advancement.

Q02 must retire the unchanged card on zero packages, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, or any clock, endpoint, synchronization, sample, relative
orientation, binary map, null, denominator, score, threshold, side, attempt,
risk, stop, spread, atomicity, lifecycle, or determinism defect. Failure may
not be rescued through threshold, sample, tie map, direction, carrier, stop,
hold, spread, or filter changes.

Opposite metal legs target relative precious-metal seasonality but realized
decorrelation is unproven and remains an unchanged Q09 decision. No
live/demo/shadow/stress/optimization preset, terminal control, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, portfolio admission,
correlation waiver, or certification action is authorized.
