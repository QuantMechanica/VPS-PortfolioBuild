# QM5_41211 WTI Same-Calendar One-Standard-Error Seasonality - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41211_wti-samecal-tstat_card.md`, SHA-256
`0FCE18D5321A159D304F3B260C0AFBA217B711807CA2D9DC1F09A42B0267EDEE`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41211`
- slug: `wti-samecal-tstat`
- strategy ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01`
- source ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412110000`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41211`
after `41210` and wrote exactly one active registry row. The decision did not
guess, hand-edit, or reuse an identity. Magic allocation remains a separate
governed build prerequisite and is not claimed by this decision.

## Source And Traceability

The durable source approval was committed as
`a2be522599b3e48f87a295af3aa9447e9a3d44d6` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026/source.md`,
SHA-256
`B8D1DAEE2336DC0504642AE630137E5603F1BCA1662E7D5F2A0455B3A2AD7846`,
committed as `256cfebaa` before this G0 decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, explicit crude-oil membership,
monthly renewal, and a five-year floor. Commit-pinned R Core source provides
only the arithmetic mean, `n-1` sample variance, standard error, and t-score
implementation precedent. The exact single-WTI gate and CFD execution are
untested QM translation choices; no performance or correlation claim
transfers.

## Locked Approved Rule

At the first executable normalized `XTIUSD.DWX` D1 broker-month transition,
reconstruct the upcoming calendar month's WTI log return in exact years
`Y-1..Y-10`, skipping missing years and requiring at least five valid
observations. Compute:

```text
mean     = sum(r) / n
variance = sum((r-mean)^2) / (n-1)
se       = sqrt(variance/n)
t        = mean/se
```

Buy WTI only when `t > +1.0+1e-10`; sell only when
`t < -1.0-1e-10`; consume flat otherwise. Use one fixed-risk position with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a nonnegative 1,500-point spread cap,
one durable attempt per broker month, next-month renewal, and 40-day stale
repair. Both news axes, legacy news, and Friday close are OFF.

## Reputable-Source Gate

- R1: `PASS_WITH_SINGLE_CFD_AND_LOCKED_THRESHOLD_RISK`. The peer-reviewed
  source explicitly includes crude oil; pinned primary software fixes only
  the statistic; the exact conjunction remains untested.
- R2: `PASS`. Calendar, normalized endpoints, sample, mean, `n-1` variance,
  standard error, strict band, side, attempt, fixed risk, stop, spread, and
  lifecycle are locked.
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
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json`, SHA-256
`DB72E22F089B1BAB6AD22C1C597DC35D4D98AED64E7D8C96DA51550A8D1596BF`,
scanned 4,710 registry identities, 1,356 cards, and 45 Strategy Wiki nodes.
It found no exact collision and surfaced only the expected raw-mean WTI and
paired-metals t-score fuzzy neighbors.

Manual review establishes that `QM5_20099` trades every nonzero raw WTI
same-calendar mean, while this card scales that mean by its sample standard
error and abstains inside a strict band. Rank, trimmed, Hodges-Lehmann,
Winsorized, and Huber WTI siblings use different estimators; `QM5_41209`
forecasts a just-realized residual; `QM5_41210` applies the statistic to
paired XAU-minus-XAG returns and owns two metals legs. The fixed vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]` makes raw mean positive but leaves
this score inside the no-trade band.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_MEAN_STANDARD_ERROR_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Build Authorization And Kill Boundary

This G0 decision authorizes deterministic slot-0 magic allocation, one V5 EA
source/binary, one fixed-risk backtest setfile, strict compile/Q01 checks, and
one paced Q02 enqueue when CPU admission is clear. It authorizes no manual
tester run or phase advancement.

Q02 must retire the unchanged card on zero positions, fewer than five
completed positions in a full post-warm-up year, nonpositive governed
economics, or any clock, endpoint, sample, mean, variance, standard-error,
threshold, side, attempt, risk, stop, spread, lifecycle, or determinism defect.
Failure may not be rescued through threshold, sample, direction, carrier,
stop, hold, spread, or filter changes.

Direct WTI is economically different from the stated XAU/SP500/NDX/XNG book,
but realized decorrelation is unproven and remains an unchanged Q09 decision.
No live/demo/shadow/stress/optimization preset, terminal control, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, portfolio admission,
correlation waiver, or certification action is authorized.
