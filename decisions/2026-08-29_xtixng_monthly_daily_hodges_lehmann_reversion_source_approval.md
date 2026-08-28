# XTI/XNG completed-month daily Hodges-Lehmann reversion - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical-basket Q02 enqueue if the governed compile
and factory CPU guards permit. This decision does not authorize a manual
tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requires one new, non-duplicate, structural
low-frequency commodity or energy edge; identifies WTI and a genuinely
different XNG logic as acceptable missing exposure; requires reputable-source
criteria and `RISK_FIXED` backtests; and excludes live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xtixng-mdaily-hl-rv`
- proposed strategy ID: `VILLAR-HL-XTIXNG-MDAILY-RV-2026_S01`
- proposed source ID: `VILLAR-HL-XTIXNG-MDAILY-RV-2026`
- carrier: exact synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 opposite-leg basket
- state: the Hodges-Lehmann-style pseudomedian of every inclusive pairwise
  average of the immediately completed broker month's daily oil-minus-gas
  relative log returns
- action: fade the strict pseudomedian sign with equal target absolute USD
  notionals
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval.
Their exact bytes, line counts, hashes, and roles are preserved in
`artifacts/qm5_xtixng_mdaily_hl_rv_source_provenance_20260829.json`.

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves a complete read of Jose A. Villar and Frederick L. Joutz
   (2006), *The Relationship Between Crude Oil and Natural Gas Prices*, U.S.
   Energy Information Administration, 43 pages, plus a complete read of David
   J. Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and
   Oil Prices*, *The Energy Journal* 33(2), 13-35, DOI
   `10.5547/01956574.33.2.2`. The record supports physical and economic oil/gas
   linkage through substitution, co-production, drilling, finance, transport,
   and LNG while making structural breaks, regional gas drivers, and a weak,
   state-dependent tie load-bearing adverse evidence.
2. `strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`, SHA-256
   `E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C`.
   This governed method precedent fixes inclusive self/cross-pair enumeration,
   pairwise averaging, ascending sort, and exact odd/even central-median
   handling for a Hodges-Lehmann-style return-location estimator. Its outright
   WTI carrier, twelve monthly observations, momentum direction, and source
   performance boundary do not transfer.
3. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   This governed two-leg precedent fixes synchronized completed-month daily
   relative returns, an adjacent older boundary pair, dynamic inclusive-pair
   counts, equal-target-notional aggregate risk, atomic repair, and monthly
   renewal. Its precious-metal carrier and economic thesis do not transfer.

The bounded child extraction will be
`strategy-seeds/sources/VILLAR-HL-XTIXNG-MDAILY-RV-2026/source.md`. It is the
card's single canonical `source_id`; the records above remain its governed
lineage. No new online route was required or used. No blocked content or
unread source is represented as evidence.

Villar/Joutz and Ramberg/Parsons support testing an unstable oil/gas relative
relationship. They do not test an inclusive pairwise-average pseudomedian of
synchronized daily relative returns inside one broker month, contrarian
direction, Darwinex continuous CFDs, equal-notional sizing, fixed cash risk,
ATR stops, or the QM portfolio. Those are transparent QM falsification
choices. No source return, alpha, probability, density, risk, cost, hedge
ratio, neutrality, CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX` host and `XNGUSD.DWX` companion, D1, slots zero
   and one, fixed-risk backtest inputs, both news axes OFF, and Friday close
   OFF.
2. On the first synchronized D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw host-bar open, reconstruct every synchronized D1
   close pair in the immediately preceding calendar month plus one adjacent
   older synchronized pair proving the left boundary. Require 17 through 23
   completed-month timestamps in strict chronological order. Exclude every
   current-month price.
3. Starting from the older boundary pair, define one relative return ending on
   every completed-month session:
   `r[j]=(ln(XTI[j])-ln(XNG[j]))-(ln(XTI[j-1])-ln(XNG[j-1]))`.
   Verify the chronological sum against the direct older-boundary-to-final
   log-ratio displacement within `1e-10`.
4. For every inclusive pair `(i,j)` with `0 <= i <= j < n`, append exactly
   `(r[i]+r[j])/2` once. Require exactly `m=n*(n+1)/2` finite pairwise
   averages: 153 through 276 values for 17 through 23 daily returns. Require
   each self-pair to reproduce its source return within numerical tolerance.
5. Sort all `m` pairwise averages ascending without rounding. If `m` is odd,
   use `sorted[floor(m/2)]`; if `m` is even, use the arithmetic mean of
   `sorted[m/2-1]` and `sorted[m/2]`. Require a finite result.
6. A strictly positive pseudomedian sells XTI and buys XNG. A strictly
   negative pseudomedian buys XTI and sells XNG. Exact zero, invalid history,
   invalid arithmetic, or unsynchronized state consumes the month flat.
   Neither pseudomedian nor raw endpoint magnitude alters risk.
7. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, atomic repair, order failure, stop-out, or
   restart cannot retry that broker month.
8. Open one opposite-leg package with equal target absolute USD notionals,
   maximum 20% realized notional mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5 * ATR(20,D1)` hard stops on both legs, no target, and entry-spread
   ceilings of 1,500 XTI points and 3,000 XNG points.
9. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

The pseudomedian is a fixed robust-location translation, not a fitted
threshold. It tests whether the central pairwise location of the completed
month's oil-minus-gas daily-return distribution reverts during the following
month. It is not claimed by either oil/gas source and is load bearing.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,691 registry identities, 1,342 repository cards, and 45 Strategy
Wiki nodes. It found no exact identity and surfaced only the expected fuzzy
neighbor `QM5_20276_wti-hl-mom`. Evidence:
`artifacts/qm5_xtixng_mdaily_hl_rv_preallocation_dedup_20260829.json`.

Manual semantic review resolves that hit and the broader family:

- `QM5_20276` uses twelve completed monthly outright-WTI returns, follows the
  estimator sign, owns one WTI position, and holds one month. This candidate
  uses 17-23 daily oil-minus-gas returns from one completed month, fades the
  estimator sign, and owns an atomic two-leg XTI/XNG package.
- `QM5_41138_xauxag-mdaily-hl-rv` is the arithmetic and basket-lifecycle
  sibling but owns a precious-metal ratio under a gold/silver thesis. This
  candidate owns an energy relative path under adverse oil/gas-linkage
  evidence and uses XTI/XNG spread/risk contracts.
- `QM5_41190_xtixng-mtheilsen-rv` enumerates 78 forward slopes between
  thirteen consecutive monthly oil-minus-gas log-ratio levels, divides by
  month-index distance, and takes the slope median. This candidate enumerates
  inclusive pairwise averages of 17-23 adjacent daily relative returns from
  one completed month and takes their location pseudomedian. The state,
  horizon, pair convention, denominator, and central object all differ.
- `QM5_41188_xtixng-mrepmedian-rv` and `QM5_41189_xtixng-mlad-rv` estimate
  robust slopes on thirteen monthly ratio levels. Mann-Whitney, Wilcoxon,
  Cox-Stuart, Spearman, Pettitt, median-runs, OLS, fixed-ratio, return-spread,
  calendar, and weekday cards use different observations and state functions.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback, not a completed-month paired energy reversion basket.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, inclusive self/cross-pair enumeration, dynamic
pair count, exact median, contrarian sides, durable attempt, equal-notional
aggregate-risk package, and next-month exit are jointly load bearing. Manual
verdict:
`CLEAN_XTIXNG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK`: a complete U.S.
  government report and a complete peer-reviewed Energy Journal paper with
  DOI preserve the oil/gas relation and adverse regime evidence. The exact
  daily pseudomedian and contrarian next-month direction are explicitly
  untested translations; the governed H-L packet is method precedent only.
- R2 `PASS`: exact synchronization, month membership, return endpoints,
  endpoint identity, inclusive pairs, pair count, ascending sort, odd/even
  median, zero handling, sides, attempt, risk, stops, atomicity, spread gates,
  and lifecycle are fixed before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus MT5 state provide
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

Opposite equal-notional legs are intended to reduce common outright-energy
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio finding.

No weak result may be rescued by changing the pair convention, median rule,
direction, return inclusion, carrier, hold, risk, or by adding endpoint
agreement, a fitted center or scale, sign count, block vote, sequence,
seasonality, event, external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is gating, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. Per-leg presets may exist only as
explicit non-gating diagnostics required by basket plumbing; Q02 must target
the logical symbol and combined package ledger. No live, demo, shadow, stress,
or optimization preset is authorized. This approval forbids manual
backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest
mutation, portfolio-gate changes, portfolio admission, decorrelation claims,
and correlation waivers. Strict Q01 must precede one Q02 enqueue, and the
fresh tester/host-CPU ceiling remains fail closed.
