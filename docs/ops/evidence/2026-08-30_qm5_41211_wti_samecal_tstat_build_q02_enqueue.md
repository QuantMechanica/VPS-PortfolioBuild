# QM5_41211 WTI same-calendar t-stat build and Q02 enqueue

Date: 2026-08-30  
Branch: `agents/board-advisor`  
Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41211_wti-samecal-tstat` is a low-frequency direct-WTI calendar edge.
At the first normalized D1 broker-month transition it reads the completed log
return of that same calendar month in exact years `Y-1..Y-10`, skips missing
years, and requires at least five observations. It computes the arithmetic
mean, `n-1` sample variance, standard error, and `t=mean/se`.

- BUY only for `t > 1.0 + 1e-10`.
- SELL only for `t < -1.0 - 1e-10`.
- The inclusive interior band is flat.
- One durable attempt is consumed per broker month.
- Positions hold to the next month behind a frozen `3.5*ATR(20,D1)` hard
  stop, with a 40-day stale repair guard.
- The only preset is `XTIUSD.DWX` D1 with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The carrier and information clock differ from the XAU/SP500/NDX/XNG book,
but this is not a correlation claim. Only unchanged Q09 may establish realized
portfolio diversification.

## Governance and non-duplication

The approved card is
`strategy-seeds/cards/approved/QM5_41211_wti-samecal-tstat_card.md`, with G0
decision `decisions/2026-08-30_qm5_41211_wti_same_calendar_tscore_g0.md`.
The source packet combines peer-reviewed same-calendar crude-oil evidence with
a commit-pinned complete read of the R Core one-sample t-statistic arithmetic.

Canonical dedup receipt
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json` found no
exact identity. The load-bearing disagreement vector
`[0.020, 0.015, 0.010, 0.005, 0.001, -0.040]` has a positive raw mean while
this score remains inside the flat band, separating it from
`QM5_20099_wti-samecal`. Rank, robust-location, residual-momentum, and paired
XAU/XAG t-score siblings use different mechanics or carriers.

## Q01 evidence

- EA/magic registry: one active slot-0 row, `412110000`, resolver present.
- Independent reference suite: PASS, 10 tests.
- Card-v2 schema lint: PASS.
- G0 card lint: PASS.
- SPEC validation: PASS.
- Governed compile item:
  `8e6dc8fc-7d41-48ea-b53e-913f30176fb8`.
- Strict compile: `COMPILE_OK`, 0 errors, 0 warnings.
- Static build gate: PASS, 0 failures, 0 warnings.
- MQ5 SHA-256:
  `60645caf436e34288b811ae47e03f44d111e1d9615bc5f5f0df8c4a3a14ccc7b`.
- EX5 SHA-256:
  `470fcc3f8721531901d99fcce7af5c8fa8b7a93e3bab7a56cab9f376b8387fb7`.
- Build result:
  `artifacts/qm5_41211_build_result_20260830.json`.

No manual smoke test, tester, or backtest was launched in the build lane; Q02
owns the full-history execution evidence.

## CPU admission and Q02

Immediately before build recording, five whole-host samples were
`51.59, 68.33, 61.43, 58.70, 55.02` percent: average `59.01%`, peak
`68.33%`, both below the hard `97%` ceiling. Build recording therefore
auto-enqueued exactly one Q02 item:

- work item: `60f186f8-2c34-4099-a6c7-f6e5e5d889a8`
- symbol/timeframe: `XTIUSD.DWX`, D1
- first readback: pending, unclaimed, attempt 0
- final readback: automatically claimed by T4, active, attempt 0
- manual dispatch: false

A second five-sample read after automatic activation averaged `50.12%` and
peaked at `54.31%`; the ceiling remained clear. No further item was enqueued
or dispatched manually.

## Safety boundary

This work created no live/demo/shadow/stress/optimization preset, toggled no
AutoTrading control, touched no `T_Live` or deploy manifest, and changed no
portfolio gate. It claims neither certification nor decorrelation.

Machine-readable receipt:
`artifacts/qm5_41211_build_q02_enqueue_20260830.json`.
