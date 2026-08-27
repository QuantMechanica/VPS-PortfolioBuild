# XTI/XNG Monthly Theil-Sen Ratio Reversion — Source Approval

Date: 2026-08-28

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced logical-basket Q02 enqueue. Enqueue does not authorize manual tester
execution or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely different structural,
low-frequency commodity or energy edge, expressly permits a market-neutral
basket, requires reputable-source criteria and `RISK_FIXED` backtests, and
excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xtixng-mtheilsen-rv`
- proposed strategy ID: `VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026_S01`
- proposed source ID: `VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026`
- proposed host / traded slot 0: `XTIUSD.DWX`, D1
- proposed companion / traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of each genuine new
  broker month
- signal: fade the exact even Theil-Sen median slope of thirteen synchronized
  completed monthly oil-minus-gas log ratios

The canonical allocator owns the EA ID. This record neither predicts nor
reserves an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves complete reads of Jose A. Villar and Frederick L. Joutz
   (2006), U.S. EIA, *The Relationship Between Crude Oil and Natural Gas
   Prices*, and David J. Ramberg and John E. Parsons (2012), *The Energy
   Journal* 33(2), 13–35, DOI `10.5547/01956574.33.2.2`. The sources document
   physical and economic oil/gas links, error correction, large unexplained
   gas variation, and material regime instability. They reject a permanently
   tight or fixed oil/gas tie.
2. `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
   `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
   It preserves the complete governed reduction of the peer-reviewed
   Moskowitz, Ooi, and Pedersen (2012) WTI time-series-momentum lineage to an
   exact thirteen-endpoint robust slope: enumerate all 78 forward slopes,
   divide by month-index distance, sort, and average indexes 38 and 39. Its
   outright-WTI trend direction does not transfer.
3. `strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
   SHA-256
   `69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
   This governed packet supplies a fully specified, already reviewed two-leg
   synchronized Theil-Sen month-end lifecycle precedent. Its precious-metal
   carrier, economic thesis, signal result, and performance do not transfer.

No new public URL, blocked source body, or inferred table value is used. The
sources do not publish this exact trading rule, the thirteen-month oil/gas
ratio sample, the contrarian direction, Darwinex continuous CFDs,
equal-target-notional construction, risk, stops, or lifecycle. Those are
transparent QM falsification choices. No source return, coefficient,
significance, density, cost, neutrality, CFD-equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate. One month
   may produce at most one consumed attempt.
2. Exclude the current month. Reconstruct the latest synchronized D1 close
   pair from each of exactly thirteen immediately prior consecutive completed
   broker months. Require one common latest timestamp per month, strict
   chronology, no missing or duplicate month, positive finite closes, and a
   newest endpoint no more than ten calendar days stale.
3. Form thirteen chronological oil-minus-gas log ratios
   `s[i]=ln(XTI[i])-ln(XNG[i])`, with integer month indexes `i=0..12`.
4. Enumerate all 78 forward slopes
   `b(i,j)=(s[j]-s[i])/(j-i)` for `0<=i<j<=12`; require finite arithmetic,
   sort ascending without rounding, and compute
   `b_TS=(sorted[38]+sorted[39])/2`.
5. If `b_TS>0`, SELL XTI and BUY XNG. If `b_TS<0`, BUY XTI and SELL XNG.
   Exact zero or invalid state consumes the month flat. Signal magnitude never
   changes size.
6. Open at most one opposite-side equal-target-absolute-USD-notional package
   under one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, reject XTI/XNG entry spreads above
   1,500/3,000 points, and reject more than 20 percent rounded target-notional
   mismatch.
7. Submit XTI first and XNG second. Retain only one valid stopped position per
   registered slot in the required opposite directions. Close all owned legs
   immediately after any submission or final-composition failure.
8. Close the package on the first tick in a later broker month or after forty
   calendar days. Immediately repair any orphan, duplicate, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package.

There is no endpoint gate, repeated-median or LAD fallback, OLS, fitted
coefficient, z-score, oscillator, seasonal state, external series, or
prior-result filter. Both news axes, legacy news mode, and Friday close are
OFF. Runtime uses only registered MT5 history, timestamps, logarithms,
sorting, ATR, quotes, contract metadata, position/deal state, and persistent
terminal state.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research, including adverse regime evidence, plus
  a complete governed peer-reviewed WTI trend source and exact robust-slope
  reduction. The exact conjunction is untested.
- R2 `PASS`: synchronization, month selection, ratio orientation, all 78
  slopes, denominators, sort, even median, contrarian sides, attempt state,
  aggregate fixed risk, atomicity, and lifecycle are fixed before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and MT5-native state
  supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, finite
  arithmetic, comparisons, ATR risk controls, and execution state only; no
  trained output, ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Pre-Result Density Boundary

Every valid nonzero slope may qualify, producing at most one package per
broker month after thirteen completed monthly endpoints. The pre-result
ceiling is about twelve packages per full post-warm-up year, above the
unchanged five-trades/year Q02 floor. This is a design-density bound, not a
market probability or performance claim.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,689 registry identities, 1,340
cards, and 45 current Strategy Wiki nodes. It found no exact identity and two
copies of one expected fuzzy sibling, `QM5_41157_xauxag-mtheilsen-rv`, at
score 0.84. Evidence is
`artifacts/qm5_xtixng_mtheilsen_rv_preallocation_dedup_20260828.json`,
SHA-256
`FDAC2C5D78722C1C891F1638F7716D84781225B81630210B47362470E3C612D2`.

Manual semantic review resolves the fuzzy result and fixes the boundary:

- `QM5_41157` owns synchronized XAU/XAG precious-metal legs under a
  gold/silver economic thesis. This candidate owns only XTI/XNG energy legs
  under the documented weak, state-dependent oil/gas relation. Carrier,
  source thesis, contract metadata, costs, and portfolio exposure are all
  load bearing; this is a family sibling, not the same strategy deployment.
- `QM5_41188_xtixng-mrepmedian-rv` computes thirteen pivot-specific slope
  medians and then their median. This candidate computes one global median of
  the 78 forward slopes. On ratio vector
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  positive (`0.001555...`) while repeated median is negative (`-0.0045`), so
  the locked fade mappings request opposite packages from identical state.
- `QM5_41189_xtixng-mlad-rv` profiles a residual-median intercept for every
  candidate and selects slopes by minimum absolute vertical loss. On ratio
  vector `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`,
  Theil-Sen is positive (`0.003030...`) while LAD is negative (`-0.002`), so
  those locked fade mappings also request opposite packages.
- Pettitt, Mann-Whitney, Cox-Stuart, Spearman, and median-runs XTI/XNG cards
  use change-point, ordinal-win, paired-sign, time-rank, and dichotomized-run
  state functions rather than a median pairwise slope.
- `QM5_20237_xtixng-ecm-rv` fits a daily rolling OLS residual, z-score, and
  convergence exit; `QM5_12578_eia-oilgas-ratio` standardizes a fixed ratio.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback, not a symmetric monthly paired-energy package.

The XTI/XNG carrier, thirteen synchronized endpoints, oil-minus-gas ratio,
all 78 forward slopes, month-index denominators, exact even median,
contrarian sides, consumed month, equal-target-notional aggregate fixed risk,
atomic lifecycle, and next-month exit are jointly load bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_EXPECTED_FAMILY_FUZZY_REVIEW`.

## Kill And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any month,
endpoint, synchronization, ratio, slope, denominator, median, direction,
attempt, risk, atomicity, lifecycle, or determinism defect. No failed result
may be rescued by changing the sample, estimator, carrier, direction, risk,
hold, spread cap, or by adding another gate.

Opposite equal-target-notional legs reduce outright energy direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This approval excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; correlation waivers; terminal control; and component-
leg Q02 rows. Q02 may be enqueued once only after current strict
compile/review PASS and only below the factory CPU ceiling.
