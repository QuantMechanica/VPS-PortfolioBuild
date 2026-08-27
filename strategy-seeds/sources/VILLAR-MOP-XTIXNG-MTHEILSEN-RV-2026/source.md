---
source_id: VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026
title: XTI/XNG thirteen-month Theil-Sen ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of government and peer-reviewed research
source_type: government_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-28_xtixng_monthly_theilsen_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-WTI-THEILSEN-2026
  - SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-WTI-THEILSEN-2026: F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E
  SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026: 69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA
created: 2026-08-28
created_by: Research+Development
cards_extracted:
  - xtixng-mtheilsen-rv
---

# XTI/XNG Thirteen-Month Theil-Sen Ratio-Slope Reversion Source Packet

## Approved Sources Of Record

The oil/gas relationship evidence is preserved in
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It records
complete reads of:

- Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between
  Crude Oil and Natural Gas Prices*, U.S. Energy Information Administration,
  43 pages; and
- David J. Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural
  Gas and Oil Prices*, *The Energy Journal* 33(2), 13–35, DOI
  `10.5547/01956574.33.2.2`.

The reports support physical and economic linkage through substitution,
co-production, drilling, finance, transport, and LNG while documenting large
unexplained gas variation, structural breaks, and a weak, state-dependent
tie. They reject a permanently fixed ratio and do not prescribe this trade.

The arithmetic precedent is
`strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`. Its peer-reviewed
parent is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012),
*Time Series Momentum*, *Journal of Financial Economics* 104(2), 228–250,
DOI `10.1016/j.jfineco.2011.11.003`. The packet fixes an exact bounded robust
slope calculation over thirteen completed month ends: enumerate all 78
forward pairs, divide by positive month-index distance, sort without
rounding, and average central indexes 38 and 39. Its outright-WTI carrier,
trend-following direction, and source performance context do not transfer.

The governed two-leg lifecycle precedent is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`.
It supplies already reviewed synchronization, equal-target-notional risk,
atomic order, repair, and month-renewal mechanics. Its precious-metal
carrier, economic thesis, and any signal result do not transfer.

All three parent packets were read completely before the durable OWNER source
approval at
`decisions/2026-08-28_xtixng_monthly_theilsen_reversion_source_approval.md`,
commit `1c171e0ff`. No new online route, blocked content, inferred source table,
or external runtime series is used.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons support only a falsifiable, unstable
oil/gas-relative-price hypothesis. Their results do not establish a constant
hedge ratio, center, convergence speed, or profitable contrarian rule. Their
adverse evidence is load bearing: the two markets can decouple and gas can be
driven by regional fundamentals that oil does not share.

Moskowitz/Ooi/Pedersen support a broad structural hypothesis that persistent
own-price commodity paths may contain directional information and confirm
WTI membership in their futures universe. The governed child packet supplies
the exact robust-slope arithmetic only. Neither the paper nor the child
packet tests an oil-minus-gas ratio or a contrarian direction.

The exact calendar, synchronization, log-ratio orientation, thirteen-month
formation, contrarian side mapping, equal-notional construction, fixed risk,
ATR stops, spread limits, atomic order sequence, and persistent no-retry state
are transparent QM translations. No source return, alpha, probability,
density, Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD
equivalence, or book-correlation statistic transfers.

## Bounded QM Mechanization

On the first synchronized executable D1 tick of a new broker month, exclude
the current month and reconstruct exactly thirteen consecutive completed
broker calendar months ending with the immediately prior month. Retain the
latest exactly timestamp-matched `XTIUSD.DWX` and `XNGUSD.DWX` close pair in
each month. Missing or duplicate months, unmatched timestamps,
nonchronological pairs, nonpositive closes, or stale endpoints are invalid.

For chronological month-end pairs `i=0..12`:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i])

k = 0
for i = 0..11:
  for j = i+1..12:
    slope[k] = (s[j] - s[i]) / (j - i)
    k += 1

require k == 78
sorted = ascending(slope[0], ..., slope[77])
theilsen = (sorted[38] + sorted[39]) / 2

theilsen > 0 => SELL XTI, BUY XNG
theilsen < 0 => BUY XTI, SELL XNG
otherwise    => FLAT
```

Every denominator is an integer month-index distance from 1 through 12. The
ratio is oil minus gas in logs; reversing it and retaining the same side
mapping is not equivalent. All 13 ratios, all 78 slopes, both central values,
and their sum must be finite. The raw endpoint displacement is diagnostic
only and cannot gate the signal. Exact zero or invalid state consumes the
month flat. Signal magnitude never changes risk.

## Exact Event And Execution Contract

1. Require exact host `XTIUSD.DWX`, exact companion `XNGUSD.DWX`, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw current host
   D1 bar open in a genuine new broker month.
2. Persist the current broker `yyyymm` as consumed before any history, signal,
   news, spread, quote, ATR, sizing, margin, or order check. A flat result,
   invalid state, broker reject, stop, partial fill, or restart never retries
   the month.
3. From a bounded native D1 buffer, select exactly the latest synchronized
   pair in each of the immediately prior thirteen consecutive broker months.
   The newest pair must be no more than ten calendar days stale.
4. Reverse the selected pairs into strict chronological order, compute the
   thirteen oil-minus-gas log ratios and all 78 forward slopes, sort
   ascending, and use the exact even-sample median. No endpoint, OLS, z-score,
   volatility, event, seasonal, or prior-result filter is allowed.
5. Fade the strict slope sign with opposite legs. A positive ratio slope maps
   to SELL XTI / BUY XNG; a negative slope maps to BUY XTI / SELL XNG.
6. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   aggregate stop-risk budget equally, size each leg against its frozen
   `3.5*ATR(20,D1)` broker hard stop, attach no target, cap entry spread at
   1,500 XTI points and 3,000 XNG points, and require realized absolute
   notional mismatch no greater than 20 percent.
7. Submit XTI first and XNG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg immediately after any second-leg or
   final-package validation failure.
8. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF for the source-
aligned monthly hold. Runtime uses only registered MT5 histories, timestamps,
calendar, logarithms, sorting, quotes, symbol metadata, ATR, positions,
deals, and terminal-persistent state.

## Non-Duplicate Boundary

The canonical checker scanned 4,689 registry identities, 1,340 cards, and 45
Strategy Wiki nodes. It found no exact identity and only the expected
precious-metal sibling `QM5_41157_xauxag-mtheilsen-rv` as a fuzzy match. The
receipt is
`artifacts/qm5_xtixng_mtheilsen_rv_preallocation_dedup_20260828.json`.

Manual semantic review fixes a new mechanic:

- `QM5_41157` applies the statistic to an XAU/XAG ratio under a precious-metal
  thesis; this extraction owns an XTI/XNG ratio under a weak oil/gas-linkage
  thesis. The carrier and exposure are load bearing.
- `QM5_41188_xtixng-mrepmedian-rv` takes a median of thirteen pivot-specific
  slope medians. On ratio vector
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, this extraction's
  Theil-Sen slope is positive (`0.001555...`) while repeated median is negative
  (`-0.0045`), so the fade rules request opposite packages.
- `QM5_41189_xtixng-mlad-rv` minimizes total absolute vertical residual loss
  after profiling an intercept. On ratio vector
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, Theil-Sen is
  positive (`0.003030...`) while LAD is negative (`-0.002`).
- Pettitt, Mann-Whitney, Cox-Stuart, Spearman, and median-runs XTI/XNG cards
  use change-point, ordinal, sign, rank, and transition state rather than a
  global median pairwise slope.
- `QM5_20237_xtixng-ecm-rv` uses daily rolling OLS residuals, a z-score, and a
  convergence exit; `QM5_12578_eia-oilgas-ratio` standardizes a fixed ratio.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and has no paired monthly lifecycle.

The paired energy carrier, thirteen consecutive synchronized month ends,
oil-minus-gas orientation, 78 forward pairs, `j-i` denominators, exact even
median, contrarian sides, durable consumed month, equal-target-notional
aggregate fixed risk, atomic lifecycle, and next-month exit are jointly load
bearing. Verdict:
`CLEAN_XTIXNG_THIRTEEN_MONTH_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_EXPECTED_FAMILY_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`. The lineage
  preserves complete U.S. government and peer-reviewed oil/gas evidence,
  complete peer-reviewed WTI trend evidence, and exact governed robust-slope
  arithmetic. The trading conjunction is untested.
- R2: `PASS`. Clock, synchronization, consecutive-month selection, ratio
  orientation, pair bounds, denominator, count, sort, median, direction,
  attempt, aggregate risk, stops, atomicity, spread gates, and lifecycle are
  fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and native MT5 state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, finite arithmetic,
  sorting, comparisons, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero slope may qualify, giving a pre-result density ceiling
near twelve packages per year after thirteen-month warm-up. This is not
market evidence. Q02 must retire below five completed packages in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any synchronization, month, ratio, slope, denominator, median, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

Opposite equal-target-notional legs reduce some common outright-energy
direction but do not prove dollar, beta, volatility, factor, market, or
portfolio neutrality. Unchanged Q09 alone owns realized book correlation. No
failed result may be rescued by changing the carrier, observation count,
estimator, direction, risk, hold, or by adding endpoint agreement, regression,
scale, event, seasonal, volatility, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one branch-
only V5 build, strict compile/Q01, and one paced non-live logical-basket Q02
handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or decorrelation claim.
