# XNG Median Same-Calendar Seasonality — Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the OWNER commodity/energy sleeve mission delivered to Codex on
the `agents/board-advisor` branch. The mission authorizes one new structural,
low-frequency commodity/energy carrier, expressly permits a second
`XNGUSD.DWX` edge when its logic differs from `QM5_12567`, requires reputable
sources and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xng-medcal`
- proposed strategy ID: `KELOHARJU-XNG-MEDCAL-2026_S01`
- source ID: `KELOHARJU-RETSEAS-2016`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable D1 tick after a genuine broker-month
  transition
- state: median of five to ten exact prior-year completed XNG log returns for
  the decision calendar month
- lifecycle: trade the median sign through the new month, renew at the next
  month boundary, and repair only a survivor after 35 calendar days

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis

The bounded source-of-record packet
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` was read completely
before this decision. Its SHA-256 is
`54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`, and the
last source-packet commit is `a1dd9e7751f843db82c0b230a46ed7fe6526accd`.

The packet records a complete review of the open 57-page NBER version of
Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The Journal
of Finance* 71(4), 1557–1590, DOI `10.1111/jofi.12398`. The peer-reviewed paper
tests recurring same-calendar-month information in a broad commodity-futures
cross-section that explicitly includes natural gas. Its commodity
construction uses prior matching-calendar returns, requires at least five
years of history, and renews monthly.

The sample median is an explicit, pre-result QM robustness translation. The
paper uses a cross-sectional arithmetic mean and does not test the median, a
single-XNG absolute-sign portfolio, continuous Darwinex CFDs, fixed cash risk,
the governed attempt ledger, an ATR stop, or this lifecycle. No source return,
coefficient, significance, trade count, cost, drawdown, CFD equivalence,
neutrality, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable `XNGUSD.DWX` D1 tick after a genuine normalized
broker-month transition:

1. Close or repair any prior-month owned position before entry-only gates.
2. Persist the current `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates; never retry that month.
3. Reconstruct the completed return for the decision calendar month in each
   exact year `Y-1` through `Y-10` as
   `ln(month_end_close / prior_month_end_close)`.
4. Accept only positive finite endpoints with strict adjacent-month identity,
   one uniform native or `+1` energy-label normalization, and a confirming
   following D1 bar. Skip a missing year without substitution and require
   five to ten valid observations.
5. Sort the valid returns ascending. For odd `n`, use the middle value; for
   even `n`, use the arithmetic mean of the two middle values.
6. Buy when the median is greater than `+1e-12`, sell when it is less than
   `-1e-12`, and consume the month flat otherwise. Signal magnitude never
   changes size.
7. Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5 * ATR(20,D1)` hard stop, a 3,000-point
   spread ceiling, and no target.
8. Close at the first later normalized broker-month boundary. A 35-calendar-
   day stale guard repairs only a survivor.
9. Lock both news axes and legacy news mode OFF, and disable framework Friday
   flatten so the source-aligned monthly package can span weekends.
10. Never retry, scale in, pyramid, grid, martingale, hedge, optimize, or add
    a result-conditioned filter.

Exact year selection, calendar endpoints, sample bounds, median convention,
absolute sign, consumed attempt, fixed risk, hard stop, and month lifecycle
are load-bearing. No arithmetic-mean or Huber fallback, favorable-month list,
recent-trend confirmation, volatility gate, storage/inventory input,
magnitude threshold, or optimizer-selected filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: named-author, peer-reviewed *Journal of
  Finance* lineage with DOI and a durable complete-read record; natural gas is
  explicitly inside the source universe. The median and one-name CFD
  reductions are disclosed QM choices.
- R2 `PASS`: month clock, endpoint normalization, exact years, sample bounds,
  even/odd median arithmetic, direction, attempt state, risk, stop, spread,
  and exits are deterministic and locked.
- R3 `PASS_WITH_HISTORY_WARMUP_RISK`: registered `XNGUSD.DWX` D1 data supplies
  every runtime input. Local history beginning in 2017 makes the five-prior-
  year floor and energy-session labeling binding Q02 risks.
- R4 `PASS`: timestamps, OHLC, logarithms, sorting, ATR risk plumbing, quotes,
  positions, deals, and terminal state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, hedge, or
  pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xng_medcal_preallocation_dedup_20260830.json`, SHA-256
`FE344663C7A937B4EEB2A11939B7C41DE52E33A1FDAF70D51CA42FB244629815`, scanned
4,724 EA-registry rows, 1,362 cards, and 45 Strategy Wiki nodes. It found no
exact identity and the expected fuzzy carrier sibling
`QM5_41055_wti-medcal`.

Manual semantic review resolves the relevant boundaries:

- `QM5_41055_wti-medcal` uses the same locked order statistic on
  `XTIUSD.DWX`. This candidate is an expressly authorized XNG carrier port,
  owns only XNG history/risk/magic, and makes no claim to a globally new
  signal family.
- `QM5_20100_xng-samecal` uses the arithmetic mean of valid historical XNG
  returns. For `[+0.01,+0.01,+0.01,+0.01,-0.20]`, the mean sells while this
  candidate's median buys.
- `QM5_41205_xng-samecal-huber10` requires all ten years and a positive
  median/MAD scale before 32 Huber updates. This candidate accepts five to ten
  years and uses the sample median directly; it has no scale or iteration.
- `QM5_41214_xng-samecal-signscore` discards magnitudes and applies a strict
  sample-size-aware Bernoulli score band. For
  `[+0.001,-0.20,-0.20,+0.20,+0.20]`, this candidate buys on the positive
  median while the sign-score sleeve abstains.
- `QM5_12567_cum-rsi2-commodity` uses a 200-D1 trend filter, cumulative RSI(2)
  pullback state, and a short holding period. It shares neither the
  information horizon, statistic, side map, nor lifecycle of this monthly
  structural rule.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAME_CALENDAR_MEDIAN_SIGN_MONTHLY_CARRIER_PORT`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 retires on zero trades, fewer than five completed
positions in any full scored year, nonpositive governed economics, wrong
calendar endpoints, use of current-month prices, mean/Huber/sign-score
substitution, late or repeated entry, wrong lifecycle, nondeterminism,
invalid risk mode, or unusable local history. Failure may not be rescued by
changing the estimator, sample, threshold, direction, carrier, stop, spread,
hold, or attempt policy.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the exact-path tester count and host CPU are below the governed ceilings.
At the ceiling, stop before queue mutation and record a non-live handoff.
