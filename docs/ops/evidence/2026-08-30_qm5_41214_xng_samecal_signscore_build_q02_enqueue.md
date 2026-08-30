# QM5_41214 XNG same-calendar sign-score build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41214_xng-samecal-signscore` is a low-frequency natural-gas calendar
candidate. At the first normalized `XNGUSD.DWX` D1 broker-month transition it
scans the same calendar month in exact years `Y-1..Y-10`, skips missing years,
requires at least five completed log returns, maps each nonnegative return to
one and each negative return to zero, and computes the no-continuity-correction
Bernoulli null-half score:

```text
score = (x - n*0.5) / sqrt(n*0.5*0.5) = (2*x - n) / sqrt(n)
```

The EA buys only above `+1.0+1e-10`, sells only below `-1.0-1e-10`, and
otherwise consumes the month flat. An opened position closes on the next
normalized broker-month boundary, with a 40-day stale repair and a frozen
`3.5*ATR(20,D1)` hard stop.

This differs from certified `QM5_12567_cum-rsi2-commodity`: that strategy uses
a daily cumulative-RSI2 pullback, while QM5_41214 uses exact prior-year
calendar observations, discards return magnitude, participates only outside a
sample-size-aware sign band, and renews monthly. That is a structural
non-duplicate distinction, not proof of low realized correlation. Q09 remains
the sole authority for portfolio overlap and diversification.

Canonical preallocation dedup scanned 4,713 registry identities, 1,359 cards,
and 45 Strategy Wiki nodes. It found no exact collision and surfaced the
expected WTI sign-score, XNG raw-mean, and XAU/XAG relative sign-score
neighbors. On `[0.09,-0.01,-0.01,-0.01,-0.01]`, the XNG raw mean buys while
this binary sign score sells, locking an executable disagreement rather than a
renamed copy.

## Governance and implementation

The reputable lineages are Keloharju, Linnainmaa, and Nyberg (2016), *Journal
of Finance*; Papailias, Liu, and Thomakos (2021), *Journal of Banking &
Finance*; and commit-pinned R Core primary-software arithmetic. The exact XNG
CFD conjunction, threshold, and risk translation are QM specifications; no
source performance claim transfers.

- Source approval commit: `e74d49641`.
- Bounded source packet commit: `e0fb5ddb2`.
- Approved G0 card and deterministic identity commit: `a60ed41d3`.
- Governed magic allocation commit: `248dabd21`.
- EA, spec, fixtures, and fixed-risk preset commit: `166b85ecb`.
- Active slot 0 / magic: `412140000` for `XNGUSD.DWX`.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The implementation normalizes completed XNG D1 labels under one broker-date
offset, uses exact prior-year month endpoints without substitution, excludes
the current incomplete month, and consumes each monthly attempt even when the
score is flat or an execution guard rejects entry. Fewer than five valid
returns, invalid prices, a nonpositive denominator, or an inclusive threshold
band produces no trade.

Eleven deterministic reference tests cover label normalization, exact-year
bounds, missing-year skips, score arithmetic, disagreement cases, threshold
tolerance, attempt state, fixed-risk preset, registry, and resolver bindings.
Card schema, G0 structure, spec, entry contract, build guardrails, and raw-MQ5
quarantine checks passed.

## Governed compile

Build task `f7e1791b-0da4-4a5e-810a-ed6637f6d9b6` was bound to compile item
`293839ff-dd85-4bd5-9406-3961564fc0b8`. A source-hash-exact bounded release
allowed the resident T8 worker to compile without any manual terminal launch,
tester run, or AutoTrading action.

The worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `c028c921680d11cc8f47981f33843e8d305b4ec2200b37b25356934d1d66664d`;
- evidence:
  `D:/QM/reports/work_items/293839ff-dd85-4bd5-9406-3961564fc0b8/QM5_41214/COMPILE_EA/compile_evidence.json`.

The worker refreshed the sole backtest preset to build hash
`b46c2277d036b40d5abed43f41fcbeb883637d4a8efe193a1be8e9532db10ad4`.
It remains a fixed-risk build artifact; no live, demo, shadow, stress, or
optimization preset was created.

## Q02 enqueue and CPU boundary

Immediately before `record-build`, five one-second whole-host CPU samples
averaged `84.56%` and peaked at `89.84%`, below the hard `97%` ceiling.
Recording the successful build atomically created exactly one Q02 item:

- work item: `13545dab-34f6-4147-bef6-cf0f4495a2eb`;
- symbol/timeframe: `XNGUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41214_xng-samecal-signscore/sets/QM5_41214_xng-samecal-signscore_XNGUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed, priority-track;
- additional or skipped items: zero.

The immediate post-enqueue CPU window averaged `92.44%` and peaked at
`94.05%`, also below the ceiling. This mission performed no manual dispatch,
tester launch, retry, terminal reservation, or later pipeline action.

## Remaining falsification risks

- The five-observation floor can still produce zero or sub-floor Q02 activity.
- Binary signs discard magnitude, and one observation can move a small sample
  across the participation or direction boundary.
- Continuous-CFD labels, financing, rolls, gaps, and futures-to-CFD basis
  remain empirical translation risks.
- Structural distinction from the daily XNG pullback does not establish
  realized independence; Q09 must reject excessive overlap.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress/optimization preset, `T_Live`
control or manifest, deploy manifest, portfolio gate, portfolio admission, or
correlation waiver was touched. Neither certification nor diversification is
claimed before downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41214_build_q02_enqueue_20260830.json`.
