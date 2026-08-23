# XAU/XAG completed-month daily-return interquartile-mean reversion - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
requires one new, non-duplicate, structural low-frequency commodity edge and
expressly permits an `XAUUSD`/`XAGUSD` gold/silver-ratio reversion basket. It
also requires reputable-source criteria and `RISK_FIXED` backtests and excludes
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mdaily-iqrmean-rv`
- proposed strategy ID:
  `SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 opposite-leg basket
- state: the immediately completed broker-calendar month's gold-minus-silver
  daily log-ratio returns, after an exact integer-quartile trim of both tails
- action: fade the strict sign of the retained central-band arithmetic mean
  with equal target absolute USD notionals
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It preserves Karsten Schweikert (2018), "Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,"
   *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   research. The record supports testing a related, state-dependent
   gold/silver relation rather than assuming one universal equilibrium.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME Group defines the gold/silver ratio, presents it as an intermarket
   spread, and distinguishes gold's monetary/safe-haven drivers from silver's
   industrial-cycle exposure.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026/source.md`.
It is the card's single canonical `source_id`; the records above remain its
governed lineage.

Schweikert and CME support testing a relative-value gold/silver carrier. They
do not test an integer-quartile-trimmed mean of synchronized daily relative
returns inside one broker month, contrarian direction, Darwinex continuous
CFDs, equal-notional sizing, fixed cash risk, ATR stops, or the QM portfolio.
Those are transparent QM falsification choices. No source return, alpha,
probability, density, risk, cost, hedge ratio, neutrality, CFD equivalence, or
portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, slots zero
   and one, fixed-risk backtest inputs, both news axes OFF, and Friday close
   OFF.
2. On the first synchronized D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw host-bar open, reconstruct every synchronized D1
   close pair in the immediately preceding calendar month plus one adjacent
   older synchronized pair proving the left boundary. Require 17 through 23
   completed-month timestamps in strict chronological order. Exclude all
   current-month prices.
3. Starting from the older boundary pair, define one relative return ending
   on every completed-month session:
   `r[j]=(ln(XAU[j])-ln(XAG[j]))-(ln(XAU[j-1])-ln(XAG[j-1]))`.
   Sort all `n` finite returns ascending without rounding. Define
   `k=floor(n/4)`, retain the closed index interval `[k,n-k-1]`, and average
   each retained return exactly once. With 17 through 23 sessions, remove
   exactly four or five returns from each tail and retain exactly 9 through 13.
4. Verify the unsorted chronological return sum against the direct
   older-boundary-to-final log-ratio displacement within `1e-10`. The raw
   endpoint is an identity diagnostic only and never confirms or vetoes the
   central mean.
5. A strictly positive central mean sells gold and buys silver. A strictly
   negative central mean buys gold and sells silver. Exact zero, invalid
   history, invalid arithmetic, or unsynchronized state consumes the month
   flat. Neither the central mean nor raw endpoint magnitude alters risk.
6. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, atomic repair, order failure, stop-out, or
   restart cannot retry that broker month.
7. Open one opposite-leg package with equal target absolute USD notionals,
   maximum 20% realized notional mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5 * ATR(20,D1)` hard stops on both legs, no target, and entry-spread
   ceilings of 1,500 XAU points and 500 XAG points.
8. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

The central-band statistic is a fixed robust-location translation, not a
fitted threshold. It tests whether the ordinary relative movement, after
removing both extreme daily tails, reverts during the following month. It is
not claimed by either source and is load-bearing.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,634 registry identities, 1,302 repository cards, and 45 Strategy
Wiki nodes, found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_xauxag_mdaily_iqrmean_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_12577_cme-xauxag-ratio`, `QM5_20157_xau-xag-ratio`,
  `QM5_20161_xauxag-ols-rv`, and `QM5_20263_xauxag-mad-rv` fit a rolling
  center, beta, scale, or threshold crossing. This candidate fits none.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily relative-return signs;
  fixed-block cards aggregate halves or thirds; and `QM5_41121` uses ordered
  state transitions. This candidate sorts all daily magnitudes and averages
  the exact central band, with no sign count, block, vote, or sequence gate.
- `QM5_41123_xauxag-mpath-eff-rv` uses a net-to-L1 path quotient,
  `QM5_41125_xauxag-mrms-coherence-rv` uses a net-to-L2 quotient, and
  `QM5_41128_xauxag-mdaily-persist-rv` uses adjacent demeaned-return products.
  None sorts returns or selects the dynamic central 9-to-13 observation band.
- `QM5_41134_wti-mdaily-iqrmean-mom` uses the same robust-location family on
  one outright WTI leg and follows the retained mean. This candidate applies
  the statistic to a synchronized gold-minus-silver relative series, fades
  it, and owns an atomic equal-notional two-leg package.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback, not a completed-month precious-metals basket.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, full ascending sort, dynamic integer-quartile
tail removal, central-band arithmetic mean, contrarian sides, durable attempt,
equal-notional aggregate-risk package, and next-month exit are jointly load-
bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WITHIN_MONTH_IQR_LOCATION_TRANSLATION_RISK`: a peer-reviewed
  gold/silver relation paper with DOI and an official exchange spread-carrier
  record are preserved with complete-read evidence and durable hashes. The
  within-month central-band statistic and contrarian direction are explicitly
  untested translations.
- R2 `PASS`: exact synchronization, month membership, return endpoints,
  endpoint identity, ascending sort, integer tail count, retained indexes,
  arithmetic mean, zero handling, sides, attempt, risk, stops, atomicity,
  spread gates, and lifecycle are fixed before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide
  every runtime input. Q02 owns history, holiday attrition, costs, financing,
  density, fills, and CFD-basis sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, addition,
  sorting, integer division, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Frequency, Portfolio Claim, And Falsification

Every valid nonzero central mean can qualify, giving a pre-result density
prior near twelve packages per year. This is not market evidence. Q02 must
retire below five completed packages in any full scored post-warm-up year, at
zero trades, with nonpositive governed economics, or on any synchronization,
arithmetic, side, attempt, risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio finding.

No weak result may be rescued by changing the trim, direction, return
inclusion, carrier, hold, risk, or by adding endpoint agreement, a fitted
center or scale, sign count, block vote, sequence, seasonality, event,
external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
