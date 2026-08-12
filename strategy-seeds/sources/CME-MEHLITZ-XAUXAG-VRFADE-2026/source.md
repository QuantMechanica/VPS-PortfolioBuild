---
source_id: CME-MEHLITZ-XAUXAG-VRFADE-2026
title: Gold-silver ratio displacement gated by relative-return anti-persistence
publisher: The European Journal of Finance / Journal of Banking & Finance / CME Group
source_type: peer_reviewed_composite_with_exchange_carrier
status: cards_ready
approval_basis: decisions/2026-08-06_qm5_20254_xauxag_vr_fade_g0.md
created: 2026-08-06
created_by: Research+Development
strategy_ids:
  - CME-MEHLITZ-XAUXAG-VRFADE-2026_S01
---

# XAU/XAG Anti-Persistent Ratio-Fade Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-06 authorizes one new non-duplicate structural
commodity/energy card, build, and paced Q02 enqueue. The durable source
authorization is
`decisions/2026-08-06_qm5_20254_xauxag_vr_fade_g0.md`.

The following bounded parent packets were read completely for this extraction:

- `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md` records an end-to-end
  review of Chapter 3, pp. 51-74, and Appendix C, pp. 110-113, of the open
  doctoral precursor to Mehlitz and Auer (2024).
- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` records the
  reviewed peer-reviewed publisher evidence for a state-dependent long-run
  gold/silver relationship and corroborating fractional cointegration.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records the exchange's
  definition of the gold/silver ratio and its opposing-leg spread carrier.

Canonical citations:

1. Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum
   in commodity futures markets," *The European Journal of Finance* 30(8),
   773-802, DOI `10.1080/1351847X.2023.2220118`.
2. Schweikert, Karsten (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`.
3. CME Group, "Gold & Silver Ratio Spread,"
   `https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html`.

## Source Findings Used

Mehlitz and Auer define a heteroskedasticity-robust Lo-MacKinlay variance-ratio
state from 32 completed monthly log returns. Their `R1-q2` member uses
`VR(2)=1+rho(1)`, a fixed two-sided 10% critical value, and treats a
significantly negative standardized deviation from one as anti-persistence.
Their universe explicitly contains gold and silver, although their published
rule applies the statistic to each commodity, not to a gold-minus-silver
relative series.

Schweikert reports a nonlinear, state-dependent gold/silver relation and warns
that a constant cointegrating vector can fail. The source supports testing
conditional convergence but does not publish a rolling 60-D1 ratio trading
rule. CME defines the gold/silver price ratio and documents the opposing-leg
relative-value carrier and the metals' overlapping but different economic
drivers.

No source return, Sharpe ratio, drawdown, hit rate, trade count, threshold,
Darwinex CFD statistic, neutrality statistic, or portfolio correlation is
imported.

## Locked Monthly Anti-Persistence Gate

For synchronized completed monthly gold and silver closes, ordered oldest to
newest, form exactly 32 relative log returns:

```text
r[t] = ln(G[t+1] / G[t]) - ln(S[t+1] / S[t]), t=0..31
d[t] = r[t] - mean(r)
SSE  = sum(d[t]^2)
rho1 = sum(d[t] * d[t-1], t=1..31) / SSE
VR2  = 1 + rho1
se   = sqrt(sum(d[t]^2 * d[t-1]^2, t=1..31) / SSE^2)
z_vr = (VR2 - 1) / se
```

The card may consider ratio reversion only when
`z_vr < -1.64485362695147`. Zero variance, zero robust standard error,
non-finite arithmetic, missing endpoints, timestamp mismatch, or any
nonconsecutive month remains flat.

## Bounded QM Mechanization

On each new `XAUUSD.DWX` D1 bar, the EA derives the monthly gate only from
completed synchronized month ends. While that gate is significantly
anti-persistent, it standardizes the latest 60 completed synchronized D1
observations of `ln(XAUUSD close)-ln(XAGUSD close)`.

At a ratio z-score above `+1.5`, it sells XAU and buys XAG. At a ratio z-score
below `-1.5`, it buys XAU and sells XAG. It permits at most one consumed entry
attempt in a broker month. A valid package exits when the completed-D1 ratio
z-score reaches the central band `abs(z)<=0.25`, at the next broker-month
transition, after 35 calendar days, or on malformed composition. Each leg has
a frozen `3.5*ATR(20,D1)` hard stop and half of one aggregate fixed-risk
budget.

The 60-day window, ratio bands, relative-series application of the published
test, aggregate risk, stops, attempt ledger, and exits are disclosed QM
mechanizations. Runtime data are native MT5 D1 OHLC, ATR, spreads, quotes,
calendar, symbol metadata, positions, and deals only. No futures curve,
external file/API, volume, open interest, optimizer result, trained model,
banned signal indicator, grid, martingale, pyramiding, or PnL feedback is
allowed.

## Non-Duplicate Boundary

The deterministic pre-allocation check scanned 4,311 registry rows and 428
cards and returned `CLEAN`. Manual review separates the complete identity:

- Pure ratio-z-score baskets have no robust memory state.
- OLS, conditional-quantile, and C-MTAR baskets define different equilibrium
  residuals and do not require a negative relative-return variance ratio.
- `QM5_20249_xauxag-vr-spread` derives direction from the latest monthly
  relative return and trades both significant memory signs at the monthly
  boundary. This extraction uses only significant anti-persistence as a gate,
  derives direction from a daily ratio-level displacement, and exits on ratio
  convergence.
- Cross-sectional momentum, calendar, tail-risk, jump, and volatility ranks
  neither standardize the ratio level nor estimate its relative-return memory.

The memory-sign restriction, ratio-level state, fade direction, convergence
exit, and monthly attempt ledger are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Reputable-Source Criteria And Safety

- R1: PASS. Two peer-reviewed journal records with DOI, one complete open
  precursor review, and an exchange-defined relative-value carrier.
- R2: PASS. Monthly estimator, critical value, D1 ratio window, bands,
  directions, package risk, stops, cadence, and exits are frozen.
- R3: PASS. Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 history and established
  logical-basket tester support supply every runtime field.
- R4: PASS. Deterministic arithmetic only; no ML, banned signal indicator,
  external feed, grid, martingale, pyramiding, or adaptive fitting.

The narrow two-metal carrier, CFD/futures basis, long monthly warm-up, possible
state sparsity, legging, roll/financing, lot granularity, common precious-metal
beta, and portfolio correlation remain Q02+ falsification risks. This packet
authorizes no live artifact or portfolio change.
