# XAU/XAG Monthly Centered-CUSUM Reversion — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded market-neutral-style gold/silver
Strategy Card, deterministic EA-ID and two-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced logical Q02
enqueue only while the governed whole-host CPU ceiling remains clear. This
decision does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission asks for one new structural,
low-frequency commodity sleeve outside the certified directional
XAU/SP500/NDX/XNG book, expressly permits an `XAUUSD`/`XAGUSD` gold/silver
ratio-reversion basket, requires reputable-source criteria and a
`RISK_FIXED` backtest preset, and forbids live, AutoTrading, portfolio-gate,
and `T_Live` manifest changes.

## Candidate Identity

- proposed slug: `xauxag-mcusum-rv`
- proposed strategy ID: `AI-CODEX-XAUXAG-MCUSUM-RV-20260831_S01`
- source ID: `AI-CODEX-XAUXAG-MCUSUM-RV-20260831`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- signal: twelve synchronized completed-month gold-minus-silver log returns,
  one unique central maximum in their mean-centered cumulative-sum path, and
  a contrarian position against the post-split relative-return mean
- lifecycle: one consumed broker-month attempt, one atomic opposite-leg
  equal-notional package, next-month renewal, and forty-calendar-day stale
  repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single Governed Source And Supporting Evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUSUM-RV-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` permits AI-originated sources when
the prompt/output trail, claim boundary, and one source ID are durable.

The packet was synthesized only after these bounded repository sources were
read completely and their hashes verified:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It preserves Karsten Schweikert (2018), “Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,”
   *Journal of Banking & Finance* 88, 44–51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and bounds the evidence to a
   state-dependent relationship rather than one universal equilibrium.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME Group defines gold divided by silver as an intermarket ratio spread
   and distinguishes gold's monetary/safe-haven drivers from silver's larger
   industrial-cycle exposure.
3. `strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md`, SHA-256
   `109CD229E8BAC6A26F56132C8FC9CA2CFA0925BB2FC9C0948C8C3F5F6114E73C`.
   It preserves E. S. Page's peer-reviewed CUSUM bibliographic lineage and a
   complete official NIST/SEMATECH method-page read. NIST defines cumulative
   deviations from an estimated mean and explains that a sustained mean
   shift drives the path directionally away from zero.

The first two records support testing a gold/silver relative-value carrier.
The third supports the centered cumulative-sum diagnostic. None tests the
exact conjunction below, its finite split band, contrarian translation,
continuous Darwinex CFDs, equal-notional construction, fixed cash risk, ATR
stops, or QM portfolio. Those are disclosed pre-result QM choices. No source
return, alpha, probability, p-value, significance, density, cost, hedge ratio,
neutrality, decorrelation, or portfolio statistic transfers.

## Locked Mechanic

At the first synchronized executable D1 tick of each genuine broker month:

1. Persist the broker `yyyymm` attempt before history, arithmetic, news,
   spread, quote, stop, sizing, margin, or order checks. Never retry that
   month.
2. Reconstruct the latest synchronized XAU/XAG D1 close pair in each of the
   immediately prior thirteen consecutive broker months, oldest to newest.
   Require exact month continuity, strict timestamp order, positive finite
   closes, and no endpoint more than ten calendar days before its month end.
3. Define `L[i]=ln(XAU[i])-ln(XAG[i])` for `i=0..12`, then define twelve
   adjacent relative returns `r[i]=L[i+1]-L[i]`. Require every intermediate
   value finite.
4. Define `mean=sum(r[0..11])/12`. For split counts `k=1..11`, compute
   `S[k]=sum(r[0..k-1])-k*mean`. Exclude the identically zero terminal sum.
5. Find the maximum absolute `|S[k]|`. Qualify only when one and only one
   split lies within `1e-12` of that maximum, the maximum exceeds `1e-12`,
   and `4 <= k <= 8`.
6. Compute the arithmetic mean of `r[k..11]`. When it is positive beyond
   `1e-12`, sell XAU and buy XAG. When it is negative beyond `1e-12`, buy XAU
   and sell XAG. This fades the post-shift relative displacement; CUSUM
   magnitude and post-mean magnitude never scale risk.
7. Open one atomic opposite-leg package with equal target absolute USD
   notionals, at most 20% realized notional mismatch, aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each leg
   receives a frozen `3.5*ATR(20,D1)` broker hard stop; no target exists.
   Entry spread ceilings are 1,500 XAU points and 500 XAG points.
8. Close both legs on the first tick of a later broker month or after forty
   calendar days. Malformed, orphaned, duplicated, same-side, wrong-magic,
   stopless, or notional-invalid ownership flattens immediately.

Both news axes, legacy news, and Friday close remain off. There is no
same-month retry, target, trail, break-even, partial, grid, scale-in,
martingale, pyramid, external runtime feed, or fitted/adaptive parameter.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_METHOD_TRANSLATION_RISK`: exactly one
  durable AI-originated source ID; peer-reviewed state-dependent gold/silver
  evidence, official-exchange carrier evidence, named peer-reviewed CUSUM
  lineage, a complete official NIST method page, and exact access boundaries.
- R2 `PASS`: symbols, synchronization, month clock, endpoints, relative
  returns, centering, all eleven sums, uniqueness tolerance, split band,
  contrarian sides, attempt, risk, hard stops, atomicity, spread caps, and
  exits are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history plus MT5 state supply every
  runtime input. Holiday alignment, financing, CFD basis, gaps, spreads, and
  fills remain Q02 falsification items.
- R4 `PASS`: timestamps, completed prices, logarithms, finite arithmetic,
  comparisons, ATR risk control, quotes, positions, deals, and persistent
  terminal state only; no ML, trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_mcusum_rv_preallocation_dedup_20260831.json`, SHA-256
`165C8CC9BCE9C560D2BF889DE1CBF5E3BA9A110147B921EF982D8CD8808D6C95`,
scanned 4,746 registry identities, 1,384 card files, and all 45 Strategy Wiki
nodes. It found no exact identity and raised one expected fuzzy neighbor:
`QM5_41245_wti-mcusum-shift-tr` at score 0.67.

Manual mechanic review resolves the fuzzy match as a deliberate carrier and
execution translation, not an alias:

- `QM5_41245` centers twelve outright WTI returns, follows the post-split
  mean, and owns one directional crude-oil position. This candidate centers
  synchronized gold-minus-silver relative returns, fades the post-split
  mean, and owns an atomic opposite-leg equal-notional package.
- XAU/XAG Pettitt, Mann-Whitney, KS, Kendall, Spearman, turning-point, and
  runs systems keep ranks, pair counts, ECDF gaps, local comparisons, or sign
  runs. This candidate retains return magnitudes in a mean-centered
  cumulative path and chooses an endogenous unique split.
- XAU/XAG z-score, OLS, CADF, MAD, quantile, and variance-ratio systems fit a
  level center, beta, scale, crossing, or fixed-horizon memory statistic.
  This candidate fits none and uses no significance boundary.
- certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_CENTERED_RELATIVE_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Kill And Safety Boundary

The central-band design is expected to admit roughly five to nine packages
per year before execution gates; that is a design prior, not market evidence.
Q02 retires the unchanged baseline on zero packages, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, or any synchronization, arithmetic, side, risk, atomicity,
attempt, lifecycle, or determinism defect. No failed result may be rescued by
changing the sample, split band, tolerance, direction, carrier, stop, hold,
notional tolerance, or retry contract.

Opposite equal-notional legs reduce common outright-metal direction by
construction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone may evaluate realized overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; correlation claims;
and correlation waivers.

