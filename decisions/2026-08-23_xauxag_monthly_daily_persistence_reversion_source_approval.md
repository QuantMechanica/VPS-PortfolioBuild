# XAU/XAG completed-month daily-persistence reversion - Source Approval

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

- proposed slug: `xauxag-mdaily-persist-rv`
- proposed strategy ID:
  `SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 opposite-leg basket
- state: the immediately completed broker-calendar month's gold-minus-silver
  daily log-ratio returns have a strictly positive bias-neutralized lag-one
  persistence score
- action: fade the completed relative displacement with equal target absolute
  USD notionals
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
3. `strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`,
   SHA-256
   `62FB3C500F4176047667F5194A446BFA7C53B0D1F4D3E523F226449416D398F4`,
   plus its completely read parent
   `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`, SHA-256
   `A422025CE4C7FA2F9BEB995F496103D0FCCCED899C143771F58DB7E2222D3AC8`.
   The parent preserves the canonical peer-reviewed article by Julia S.
   Mehlitz and Benjamin R. Auer (2024), "Memory-enhanced momentum in
   commodity futures markets," *The European Journal of Finance* 30(8),
   773-802, DOI `10.1080/1351847X.2023.2220118`. The bounded WTI child fixes
   the auditable within-month lag-one persistence formula, endpoint identity,
   and numerical-validity contract.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026/source.md`.
It is the card's single canonical `source_id`; the records above remain its
governed lineage.

Schweikert and CME support testing a relative-value gold/silver carrier.
Mehlitz and Auer support conditioning commodity momentum or reversal on return
memory, while the governed WTI child supplies a closed-form, fixed-parameter
daily persistence score. None of the sources tests within-month daily XAU/XAG
ratio persistence, contrarian direction, Darwinex continuous CFDs,
equal-notional sizing, fixed cash risk, ATR stops, or the QM portfolio. Those
are transparent QM falsification choices. No source return, alpha,
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
   `r[j]=(ln(XAU[j])-ln(XAG[j]))-(ln(XAU[j-1])-ln(XAG[j-1]))`. For `n`
   returns define:

   ```text
   N   = sum(r[j])
   mu  = N / n
   S   = sum((r[j] - mu)^2)
   A   = sum((r[j] - mu) * (r[j-1] - mu)), j=1..n-1
   rho = A / S
   J   = rho + 1/(n-1)
   ```

   Require positive finite closes; finite ratios, returns, and sums; `S>0`;
   finite `rho` and `J`; and `rho` in `[-1,1]` within `1e-10`. Verify that
   `N` equals the direct older-boundary-to-final ratio displacement within
   `1e-10`.
4. Qualify only when `J>0` and `N!=0`. If `N>0`, sell gold and buy silver. If
   `N<0`, buy gold and sell silver. A zero net move, zero variance,
   nonpositive score, invalid history, or unsynchronized package consumes the
   month flat. Score and displacement magnitude never alter risk.
5. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, atomic repair, order failure, stop-out, or
   restart cannot retry that broker month.
6. Open one opposite-leg package with equal target absolute USD notionals,
   maximum 20% realized notional mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5 * ATR(20,D1)` hard stops on both legs, no target, and entry-spread
   ceilings of 1,500 XAU points and 500 XAG points.
7. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

The `1/(n-1)` term fixes the conventional short-sample negative center of a
demeaned lag-one autocorrelation before any market result is observed. It is
not fitted to gold or silver and has no tunable threshold. Its use on one
broker month of relative returns, followed by a contrarian package, is an
untested QM translation and is load-bearing.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,627 registry identities, 1,296 repository cards, and 45 Strategy
Wiki nodes, found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_xauxag_mdaily_persist_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_12577_cme-xauxag-ratio`, `QM5_20157_xau-xag-ratio`,
  `QM5_20161_xauxag-ols-rv`, and `QM5_20263_xauxag-mad-rv` fit a rolling
  center, beta, scale, or threshold crossing. This candidate fits none.
- `QM5_20249_xauxag-vr-spread` estimates serial dependence across 32 monthly
  relative returns and switches between continuation and reversal. This
  candidate estimates one completed month's 17-23 daily relative returns,
  uses only a fixed positive-memory gate, and is always contrarian.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily relative-return signs;
  `QM5_41113`, `QM5_41116`, and `QM5_41118` aggregate fixed calendar blocks;
  and `QM5_41121` uses ordered state transitions. This candidate uses centered
  adjacent cross-products and no count, block, vote, or extreme state.
- `QM5_41123_xauxag-mpath-eff-rv` uses a net-to-L1 path quotient and
  `QM5_41125_xauxag-mrms-coherence-rv` uses a net-to-L2 quotient. Neither
  multiplies adjacent demeaned returns or applies the fixed short-sample
  neutralization.
- `QM5_41127_wti-mdaily-persist-mom` uses the same governed statistic on one
  outright WTI leg and follows the endpoint. This candidate applies it to a
  synchronized gold-minus-silver relative path, fades the endpoint, and owns
  an atomic equal-notional two-leg package.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback, not a completed-month precious-metals basket.

The exact paired carrier, immediately completed calendar month, older boundary
pair, every relative return ending in the month, centered variance, adjacent
cross-product sum, fixed `1/(n-1)` neutralization, strict positive gate,
contrarian sides, consumed monthly attempt, equal-notional aggregate-risk
package, and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_PERSISTENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`: one canonical
  governed child preserves a peer-reviewed gold/silver DOI, official CME
  spread-carrier research, peer-reviewed commodity-memory lineage, complete-
  read evidence, and durable hashes. The daily relative-path score and
  contrarian direction are explicitly untested translations.
- R2 `PASS`: exact synchronization, month membership, return endpoints,
  centering, denominator, adjacent-product inclusion, fixed correction,
  endpoint identity, zero and numerical handling, sides, attempt, risk,
  stops, atomicity, spread gates, and lifecycle are fixed before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide
  every runtime input. Q02 owns history, holiday attrition, costs, financing,
  density, fills, and CFD-basis sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, addition,
  multiplication, division, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Frequency, Portfolio Claim, And Falsification

The fixed positive-score gate is designed to admit approximately half of
otherwise valid broker months, or roughly six decisions per year. This is a
pre-result density prior, not market evidence. Q02 must retire below five
completed packages in any full scored post-warm-up year, at zero trades, with
nonpositive governed economics, or on any synchronization, arithmetic, side,
attempt, risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio finding.

No weak result may be rescued by changing the correction, gate, direction,
return inclusion, carrier, hold, risk, or by adding a fitted center, scale,
sign count, block vote, sequence, range location, seasonality, event,
external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
