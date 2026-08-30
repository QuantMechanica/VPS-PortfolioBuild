# QM5_41212 WTI Same-Calendar Bernoulli Sign-Score Seasonality - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41212_wti-samecal-signscore_card.md`,
SHA-256
`E68BC2CA5BEADCB53AFF74945EB3D4120E9B82B777B9C923D29E8088534CBE26`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41212`
- slug: `wti-samecal-signscore`
- strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026_S01`
- source ID:
  `KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412120000`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41212`
after `41211` and wrote exactly one active registry row. The decision did not
guess, hand-edit, or reuse an identity. Magic allocation remains a separate
governed build prerequisite and is not claimed by this decision.

## Source And Traceability

The durable source approval was committed as
`34edd1f6e1d39c6721f4b1e9aff63c24e2b7ca4f` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026/source.md`,
SHA-256
`147874FE17B0531E02E49AD5D97910EA47B0CD6F0FA88E2811EEF52B009E9795`,
committed as `ac93ee1b9bf11c1bfd6fb1cfb80a83fce28e582b` before this G0
decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, explicit crude-oil membership,
monthly renewal, and a five-year floor. Papailias, Liu, and Thomakos (2021),
*Journal of Banking & Finance*, provide the nonnegative return-sign map,
equal binary weighting, explicit WTI membership, and monthly lifecycle.
Commit-pinned R Core source provides only the null-half uncorrected proportion-
score implementation precedent. The exact single-WTI gate and CFD execution
are untested QM translation choices; no performance or correlation claim
transfers.

## Locked Approved Rule

At the first executable normalized `XTIUSD.DWX` D1 broker-month transition,
reconstruct the upcoming calendar month's WTI log return in exact years
`Y-1..Y-10`, skipping missing years and requiring at least five valid
observations. Map each return to one when nonnegative and zero when negative.
For nonnegative count `x`, sample count `n`, and null `p0=0.5`, compute without
continuity correction:

```text
denominator = sqrt(n*p0*(1-p0)) = 0.5*sqrt(n)
score       = (x-n*p0)/denominator = (2*x-n)/sqrt(n)
```

Buy WTI only when `score > +1.0+1e-10`; sell only when
`score < -1.0-1e-10`; consume flat otherwise. Use one fixed-risk position
with `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a nonnegative 1,500-point spread cap,
one durable attempt per broker month, next-month renewal, and 40-day stale
repair. Both news axes, legacy news, and Friday close are OFF.

## Reputable-Source Gate

- R1: `PASS_WITH_COMPOSITE_TRANSLATION_AND_SMALL_SAMPLE_RISK`. Two complete-
  read peer-reviewed sources explicitly cover same-calendar commodities,
  binary signs, and WTI; pinned primary software fixes only the statistic;
  the exact conjunction and fixed threshold remain untested.
- R2: `PASS`. Calendar, normalized endpoints, sample, binary map, null,
  denominator, no-correction rule, strict band, side, attempt, fixed risk,
  stop, spread, and lifecycle are locked.
- R3: `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native WTI D1 data supplies runtime inputs, with label, roll,
  financing, and translation risks explicit.
- R4: `PASS`. Deterministic native arithmetic and framework execution only;
  no trained signal, banned signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned `ok` on
the exact approved card before this decision.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`2DDE757731CADAA6E29949741C2E7E9075E59764F402022BF435B7EBC592EBD6`,
scanned 4,711 registry identities, 1,357 cards, and 45 Strategy Wiki nodes.
It found no exact collision and surfaced only the expected raw-mean WTI fuzzy
neighbor.

Manual review establishes that `QM5_20099` uses magnitude mean, while this
card uses only binary signs and may choose the opposite side. `QM5_41059`
uses the same sign count but applies an asymmetric 40-percent always-in rule;
at three successes in six observations it buys while this card stays flat.
Signed-rank and robust-location siblings preserve magnitude order or metric
distance; `QM5_41209` forecasts a just-realized residual; `QM5_41211` uses
mean standard error and can remain flat when this card trades. The fixed
fixtures in the card prove both direction and participation disagreements.

The binary information object, null variance, sample-size-aware score, and
symmetric abstention band are jointly load bearing rather than a threshold
rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

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

Direct WTI is economically different from the stated XAU/SP500/NDX/XNG book,
but realized decorrelation is unproven and remains an unchanged Q09 decision.
No live/demo/shadow/stress/optimization preset, terminal control, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, portfolio admission,
correlation waiver, or certification action is authorized.
