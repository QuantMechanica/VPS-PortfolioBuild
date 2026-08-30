# QM5_41210 XAU/XAG same-calendar t-statistic build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41210_xauxag-samecal-tstat` is a low-frequency,
market-neutral-style precious-metals relative-value candidate. At the first
normalized `XAUUSD.DWX` D1 broker-month transition it scans the same
calendar month in exact years `Y-1..Y-10`, retains at least five
synchronized XAU-minus-XAG log-return pairs, and computes:

```text
mean     = sum(d) / n
variance = sum((d - mean)^2) / (n - 1)
se       = sqrt(variance / n)
t        = mean / se
```

It buys XAU and sells XAG only above `+1.0+1e-10`, reverses the legs only
below `-1.0-1e-10`, and otherwise consumes the month flat. An opened
package closes on the next normalized broker-month boundary, with a 40-day
stale repair and frozen per-leg `3.5*ATR(20,D1)` stops.

This is structurally different from the outright XAU, SP500, NDX, and XNG
book: the information object is studentized relative metal seasonality and
the exposure has opposite XAU/XAG legs. That construction does not prove
dollar, beta, volatility, factor, market, or portfolio neutrality. Unchanged
Q09 remains the only realized-correlation authority.

Canonical preallocation dedup scanned 4,709 registry identities, 1,355 cards,
and 45 wiki nodes. It found no exact identity and surfaced only the expected
raw-mean fuzzy neighbor. On the locked vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]`, raw mean, signed rank, and Huber
location are positive while the locked t-score remains inside `[-1,+1]`;
those siblings buy XAU/sell XAG while QM5_41210 abstains.

## Governance and implementation

- Reputable lineages: Keloharju, Linnainmaa, and Nyberg (2016), *Journal of
  Finance*; Fuertes, Miffre, and Rallis (2010), *Journal of Banking &
  Finance*; commit-pinned R Core one-sample t-test arithmetic.
- Durable source approval commit: `ba45caf7c`.
- Bounded source packet commit: `1b4994396`.
- Approved G0 card and deterministic identity commit: `e4eaf7858`.
- EA, magics, resolver, logical basket manifest, fixtures, spec, and fixed-risk
  preset commit: `2213944c5`.
- Card-v2 heading-only alignment and standard preset fixture commit:
  `73d716c36`; formula, risk, source, EA, binary, and Q02 payload were
  unchanged.
- Active slots: XAU slot 0 / magic `412100000`; XAG slot 1 / magic
  `412100001`.
- Sole Q02 package risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split into two equal fixed stop-risk halves.

The executable normalizes either native or uniform prior-day metal D1 labels,
requires the current normalized host date to match broker date, applies that
same offset to historical endpoints, and matches prior/target/following
timestamps across both legs. Missing exact years are skipped without
substitution; fewer than five pairs, nonpositive sample variance, invalid
standard error, or an inclusive threshold-band score consumes the month.

The independent suite passed nine deterministic label, endpoint,
synchronization, exact-year, t-arithmetic, disagreement, attempt, card,
setfile, registry, resolver, and basket-manifest fixtures. Card schema, G0
section profile, spec, and basket symbol-scope checks passed.

## Governed compile

Build task `e093739d-227e-4116-966c-c7ef4f375536` records compile item
`2818aa9d-830f-4db2-964c-4cd479edca3d`. A source-hash-exact bounded release
allowed one resident T8 worker to compile without launching a trading
terminal or changing AutoTrading.

The worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 4 nonfatal static warnings;
- EX5 SHA-256:
  `54a9e9ed77de7f9c5051f3a13cd2b5229486c522f52986a88529a2f0972a0e1b`;
- evidence:
  `D:/QM/reports/work_items/2818aa9d-830f-4db2-964c-4cd479edca3d/QM5_41210/COMPILE_EA/compile_evidence.json`.

The four build-check warnings were nonfatal: one call-graph-insensitive
`CopyRates` performance warning for a helper invoked only from the new-bar
month-transition path, plus three card-discovery undecidable warnings caused
by the approved card and its local build copy both being present. The
compiler itself emitted no warning.

The worker generated standard per-symbol compilation presets in addition to
the logical basket preset. They are fixed-risk build artifacts only: neither
component was enqueued or treated as a standalone strategy.

## Q02 enqueue and CPU boundary

Immediately before recording the build, five one-second whole-host CPU
samples averaged `61.56%` and peaked at `67.19%`, below the hard `97%`
ceiling. Recording the successful build atomically created exactly one
logical-basket Q02 item:

- work item: `ae2b6391-f985-4906-9f6a-0a79eb31c463`;
- symbol/timeframe: `QM5_41210_XAU_XAG_SAMECAL_TSTAT_D1` / D1;
- logical setfile:
  `framework/EAs/QM5_41210_xauxag-samecal-tstat/sets/QM5_41210_xauxag-samecal-tstat_QM5_41210_XAU_XAG_SAMECAL_TSTAT_D1_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed;
- component Q02 items: zero.

The immediate post-enqueue CPU window averaged `81.16%` and peaked at
`83.60%`, also below the ceiling. This mission performed no manual dispatch,
tester launch, retry, terminal reservation, or later pipeline action.

## Remaining falsification risks

- The five-pair floor can still produce zero or sub-floor Q02 activity if
  synchronized history is incomplete.
- Small samples and unstable standard errors can move months between package
  entry and abstention.
- Continuous-CFD session labels, financing, roll construction, legging,
  asymmetric stops, and futures/CFD basis remain empirical translation risks.
- Opposite legs are market-neutral-style plumbing, not proof of low portfolio
  correlation. Q09 must reject excessive overlap.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress/optimization preset,
`T_Live` control or manifest, deploy manifest, portfolio gate, portfolio
admission, or correlation waiver was touched. Neither certification nor
diversification is claimed before downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41210_build_q02_enqueue_20260830.json`.

