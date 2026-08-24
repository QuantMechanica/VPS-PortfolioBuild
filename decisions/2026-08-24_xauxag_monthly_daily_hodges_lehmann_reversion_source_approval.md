# XAU/XAG completed-month daily Hodges-Lehmann reversion - Source Approval

Date: 2026-08-24

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical-basket Q02 enqueue if the governed compile
and host/tester CPU guards permit. This decision does not authorize a manual
tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-24. The mission
requires one new, non-duplicate, structural low-frequency commodity edge and
expressly permits an `XAUUSD`/`XAGUSD` market-neutral-style basket. It also
requires reputable-source criteria and `RISK_FIXED` backtests and excludes
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mdaily-hl-rv`
- proposed strategy ID:
  `SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 opposite-leg basket
- state: the Hodges-Lehmann-style pseudomedian of every inclusive pairwise
  average of the immediately completed broker month's daily gold-minus-silver
  relative log returns
- action: fade the strict pseudomedian sign with equal target absolute USD
  notionals
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
3. `strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`, SHA-256
   `E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C`.
   This already governed method precedent fixes inclusive pair enumeration,
   self-pair inclusion, pairwise averaging, ascending sort, and exact odd/even
   median handling for a Hodges-Lehmann-style return-location estimator. Its
   WTI monthly carrier, twelve-observation sample, momentum direction, and
   source-performance boundary do not transfer to this candidate.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`.
It is the card's single canonical `source_id`; the records above remain its
governed lineage.

The QM source router classified two attempted new generic public routes
`DEFERRED:SOURCE_POLICY`. Evidence is
`artifacts/qm5_xauxag_mdaily_hl_rv_source_route_20260824.json`. Neither page
was used or paraphrased. This approval relies only on the three completely
read governed packets and their durable hashes.

Schweikert and CME support testing a relative-value gold/silver carrier. They
do not test an inclusive pairwise-average pseudomedian of synchronized daily
relative returns inside one broker month, contrarian direction, Darwinex
continuous CFDs, equal-notional sizing, fixed cash risk, ATR stops, or the QM
portfolio. Those are transparent QM falsification choices. No source return,
alpha, probability, density, risk, cost, hedge ratio, neutrality, CFD
equivalence, or portfolio-correlation result transfers.

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
   Verify the chronological sum against the direct older-boundary-to-final
   log-ratio displacement within `1e-10`.
4. For every inclusive pair `(i,j)` with `0 <= i <= j < n`, append exactly
   `(r[i]+r[j])/2` once. Require exactly `m=n*(n+1)/2` finite pairwise
   averages: 153 through 276 values for 17 through 23 daily returns.
5. Sort all `m` pairwise averages ascending without rounding. If `m` is odd,
   use `sorted[floor(m/2)]`; if `m` is even, use the arithmetic mean of
   `sorted[m/2-1]` and `sorted[m/2]`. Require a finite result.
6. A strictly positive pseudomedian sells gold and buys silver. A strictly
   negative pseudomedian buys gold and sells silver. Exact zero, invalid
   history, invalid arithmetic, or unsynchronized state consumes the month
   flat. Neither pseudomedian nor raw endpoint magnitude alters risk.
7. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, atomic repair, order failure, stop-out, or
   restart cannot retry that broker month.
8. Open one opposite-leg package with equal target absolute USD notionals,
   maximum 20% realized notional mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5 * ATR(20,D1)` hard stops on both legs, no target, and entry-spread
   ceilings of 1,500 XAU points and 500 XAG points.
9. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

The pseudomedian is a fixed robust-location translation, not a fitted
threshold. It tests whether the central pairwise location of the completed
month's relative daily-return distribution reverts during the following
month. It is not claimed by either gold/silver source and is load bearing.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,637 registry identities, 1,305 repository cards, and 45 Strategy
Wiki nodes. It found no exact identity and surfaced only the expected fuzzy
neighbor `QM5_41135_xauxag-mdaily-iqrmean-rv`. Evidence:
`artifacts/qm5_xauxag_mdaily_hl_rv_preallocation_dedup_20260824.json`.

Manual semantic review resolves the fuzzy neighbor and the broader family:

- `QM5_41135` sorts the `n` observed relative returns, deletes
  `floor(n/4)` observations from each tail, and averages only the retained
  9-13 observations. This candidate deletes no observed return and instead
  forms all 153-276 inclusive self/cross-pair averages before taking their
  exact median. These are different robust-location functionals.
- `QM5_20276_wti-hl-mom` supplies the arithmetic precedent but uses twelve
  completed monthly outright-WTI returns, follows the estimator's sign, owns
  one WTI position, and holds one month. This candidate uses 17-23 daily
  intermetal returns from one completed month, fades the estimator's sign,
  and owns an atomic two-leg XAU/XAG package.
- rolling ratio, OLS, quantile, and MAD cards fit a center, coefficient,
  scale, or threshold crossing. This candidate fits none.
- sign-breadth, fixed-block, sequence, path-efficiency, RMS-coherence, and
  persistence cards count, partition, order, normalize, or correlate the raw
  path. None enumerates inclusive Walsh averages or estimates their median.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback, not a completed-month precious-metals basket.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, inclusive self/cross-pair enumeration, dynamic
pair count, exact median, contrarian sides, durable attempt, equal-notional
aggregate-risk package, and next-month exit are jointly load bearing. Manual
verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK`: a peer-reviewed
  gold/silver-relation paper with DOI and an official exchange spread-carrier
  record are preserved with complete-read evidence and durable hashes. The
  exact daily pseudomedian and contrarian next-month direction are explicitly
  untested translations; the governed H-L packet is method precedent only.
- R2 `PASS`: exact synchronization, month membership, return endpoints,
  endpoint identity, inclusive pairs, pair count, ascending sort, odd/even
  median, zero handling, sides, attempt, risk, stops, atomicity, spread gates,
  and lifecycle are fixed before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide
  every runtime input. Q02 owns history, holiday attrition, costs, financing,
  density, fills, and CFD-basis sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, addition,
  division, sorting, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Frequency, Portfolio Claim, And Falsification

Every valid nonzero pseudomedian can qualify, giving a pre-result density
prior near twelve packages per year. This is not market evidence. Q02 must
retire below five completed packages in any full scored post-warm-up year, at
zero trades, with nonpositive governed economics, or on any synchronization,
arithmetic, side, attempt, risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio finding.

No weak result may be rescued by changing the pair convention, median rule,
direction, return inclusion, carrier, hold, risk, or by adding endpoint
agreement, a fitted center or scale, sign count, block vote, sequence,
seasonality, event, external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. Per-leg presets may exist only as
explicit non-gating diagnostics required by basket plumbing; Q02 must target
the logical symbol and combined package ledger. No live, demo, shadow, stress,
or optimization preset is authorized. This approval forbids manual
backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest
mutation, portfolio-gate changes, portfolio admission, decorrelation claims,
and correlation waivers. Strict Q01 must precede one Q02 enqueue, and the
fresh tester/host-CPU ceiling remains fail closed.
