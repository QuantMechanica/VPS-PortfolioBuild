# XTI/XNG Fixed Fractional-Difference Reversion - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical-basket Q02 enqueue if the governed compile
and factory CPU guards permit. This decision does not authorize a manual
tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requires one new, non-duplicate, structural
low-frequency commodity or energy edge, permits a market-neutral basket,
requires reputable-source criteria and `RISK_FIXED` backtests, and excludes
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xtixng-fracd-rv`
- proposed strategy ID: `VILLAR-YAYA-XTIXNG-FRACD-RV-2026_S01`
- proposed source ID: `VILLAR-YAYA-XTIXNG-FRACD-RV-2026`
- carrier: exact synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 opposite-leg basket
- state: fixed `(1-L)^0.40`, truncated at 64 coefficients, applied to 316
  synchronized completed oil-minus-gas log-ratio observations
- action: fade a held-out filtered output when its z-score against the prior
  252 filtered outputs reaches an inclusive absolute `0.50`
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval.
Their bytes, line counts, hashes, roles, and the canonical dedup receipt are
preserved in
`artifacts/qm5_xtixng_fracd_rv_source_provenance_20260829.json`.

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves a complete read of Jose A. Villar and Frederick L. Joutz
   (2006), *The Relationship Between Crude Oil and Natural Gas Prices*, a
   43-page U.S. Energy Information Administration report, and David J.
   Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and
   Oil Prices*, *The Energy Journal* 33(2), 13-35, DOI
   `10.5547/01956574.33.2.2`. The packet supports physical and economic
   oil/gas linkage while making structural breaks, regional gas drivers, and
   a weak state-dependent tie load-bearing adverse evidence.
2. `strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md`, SHA-256
   `CEC08E0FB0C040227A52053A7051F64CF5D530B2D68C67B8DD87851970B7E4DE`.
   This governed method precedent fixes the finite coefficient recurrence,
   exact truncation, held-out standardization, inclusive threshold, consumed
   month, equal-target-notional aggregate risk, atomic repair, and monthly
   lifecycle. Its gold/silver relationship evidence and carrier finding do
   not transfer.

The bounded child extraction will be
`strategy-seeds/sources/VILLAR-YAYA-XTIXNG-FRACD-RV-2026/source.md`. It is the
card's single canonical `source_id`; the records above remain its governed
lineage. No new online route, blocked content, unread source, performance
table, or external runtime series is used.

Villar/Joutz and Ramberg/Parsons support testing an unstable oil/gas relative
relationship. They do not establish fractional cointegration between the
registered CFDs. The method precedent does not establish that `d=0.40`, 64
terms, 316 observations, a `0.50` threshold, or contrarian next-month
direction works for oil/gas. Those are transparent, pre-result QM
falsification choices. No source return, alpha, coefficient, memory estimate,
significance, density, risk, cost, neutrality, CFD equivalence, or portfolio
correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX` host and `XNGUSD.DWX` companion, D1, slots zero
   and one, fixed-risk backtest inputs, both news axes OFF, and Friday close
   OFF.
2. On the first executable synchronized D1 tick of a genuine new broker
   month, no later than 180 elapsed minutes after the raw host-bar open,
   persist the decision `yyyymm` before every fallible gate.
3. Exact-join 316 completed D1 close pairs by timestamp, oldest to newest.
   Require positive finite closes, strictly increasing joined times, exact
   newest timestamps on both legs, and a newest endpoint no more than ten
   calendar days old.
4. Define `s[t]=ln(XTI[t])-ln(XNG[t])`, `d=0.40`, `K=64`, `w[0]=1`, and
   `w[k]=w[k-1]*(k-1-d)/k` for `k=1..63`. Compute exactly 253 finite filtered
   outputs `fd[t]=sum(w[k]*s[t-k], k=0..63)`.
5. Use only the first 252 outputs for the arithmetic mean and sample standard
   deviation with denominator 251. Hold the latest output out. Reject a
   non-finite state or standard deviation at or below `1e-12`.
6. Compute `z=(fd_latest-mean)/sd`. At `z>=+0.50`, sell XTI and buy XNG. At
   `z<=-0.50`, buy XTI and sell XNG. Interior, exact invalid, or missing
   states consume the month flat. Magnitude never changes risk.
7. Open at most one opposite-leg package with equal target absolute USD
   notionals, no more than 20% realized notional mismatch, aggregate
   `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` hard stops, no targets, and
   entry-spread ceilings of 1,500 XTI points and 3,000 XNG points.
8. Submit XTI first and XNG second. If either submission or final composition
   fails, close all owned exposure immediately and never retry that month.
9. Close both legs on the first tick in a later broker month or after forty
   calendar days. Flatten orphaned, duplicated, same-side, wrong-symbol,
   wrong-magic, stopless, or notional-invalid owned exposure immediately.

The fixed fractional operator is a deterministic filter, not a fitted memory
estimate. There is no p-value, stationarity, cointegration, or neutrality
claim. No optimizer output, external feed, grid, martingale, scale-in,
pyramid, retry, trailing stop, partial close, or discretionary rule is
authorized.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,692 registry identities, 1,343 repository cards, and 45 Strategy
Wiki nodes and returned `CLEAN` with no fuzzy match. Evidence:
`artifacts/qm5_xtixng_fracd_rv_preallocation_dedup_20260829.json`.

Manual semantic review fixes the functional boundary:

- `QM5_41185_xauxag-fracd-rv` supplies the governed arithmetic precedent but
  owns a precious-metal ratio, gold/silver evidence, XAU/XAG costs, and metal
  exposure. This candidate owns an energy relative path, explicit weak-tie
  adverse evidence, and XTI/XNG contract and cost state.
- `QM5_41192_xtixng-mdaily-hl-rv` uses one completed month's 17-23 adjacent
  daily relative returns and all inclusive pairwise averages. This candidate
  filters 316 synchronized ratio levels with 64 fixed fractional weights and
  standardizes a held-out 253rd output against 252 prior outputs.
- `QM5_20237_xtixng-ecm-rv` repeatedly fits an intercept, oil beta, and time
  trend by OLS and trades a residual crossing. This candidate fits no hedge
  coefficient, trend, memory order, or threshold.
- XTI/XNG raw-ratio, return-spread, robust-slope, rank, change-point,
  calendar, weekday, and fixed-ratio systems consume different state objects
  and clocks.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback rather than a monthly atomic oil/gas package.

The exact energy carrier, 316 synchronized closes, fixed `d=0.40`, 64-term
recurrence, 253 outputs, held-out 252-output baseline, inclusive
`abs(z)>=0.50` fade, durable attempt, aggregate fixed risk, atomic opposite
legs, and next-month renewal are jointly load bearing. Verdict:
`CLEAN_XTIXNG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_FIXED_FRACDIFF_CROSS_CARRIER_TRANSLATION_RISK`: complete U.S.
  government and peer-reviewed oil/gas evidence supports a weak,
  state-dependent relationship, and a complete governed peer-reviewed method
  packet fixes the arithmetic precedent. Fractional oil/gas integration and
  the trading conjunction are explicitly untested.
- R2 `PASS`: exact synchronization, history, recurrence, truncation, held-out
  baseline, variance denominator, threshold, sides, attempt, aggregate risk,
  stops, atomicity, spread gates, and lifecycle are fixed before testing.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus MT5 state provide
  every runtime input. Q02 owns history, costs, financing, density, fills,
  and CFD-basis sufficiency.
- R4 `PASS`: timestamps, completed prices, logarithms, a fixed linear
  recurrence, sample arithmetic, comparisons, ATR, quotes, positions, deals,
  and persistent terminal state only; no trained logic, banned signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Frequency, Portfolio Claim, And Falsification

Under a standard-normal reference, the inclusive `abs(z)>=0.50` boundary has
two-tail probability near 0.617, or roughly 7.4 opportunities across twelve
monthly decisions. This is only a transparent pre-market density prior. Q02
must retire below five completed packages in any full post-warm-up year, at
zero trades, with nonpositive governed economics, or on any synchronization,
filter, baseline, side, attempt, risk, atomicity, lifecycle, or determinism
defect.

Opposite equal-target-notional XTI/XNG legs are market-neutral-style and
reduce common outright-energy direction. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Unchanged Q09 alone owns
the realized portfolio finding. No weak result may be rescued by changing a
load-bearing rule.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is gating, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. Per-leg presets may exist only as
explicit non-gating diagnostics required by basket plumbing; Q02 must target
the logical symbol and combined package ledger. No live, demo, shadow,
stress, or optimization preset is authorized. This approval forbids manual
backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest
mutation, portfolio-gate changes, portfolio admission, decorrelation claims,
and correlation waivers. Strict Q01 must precede one Q02 enqueue, and the
fresh tester/host-CPU ceiling remains fail closed.
