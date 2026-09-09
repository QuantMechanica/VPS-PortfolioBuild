# XAU/XAG Monthly Median-Return Reversion — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency market-neutral-style XAU/XAG card,
  deterministic allocation, branch-only non-live build, strict Q01, and one
  paced Q02 enqueue only below the hard CPU ceiling
- Proposed slug: `xauxag-medret-rv`
- Strategy ID: `SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909_S01`
- Dedup receipt:
  `artifacts/qm5_xauxag_medret_rv_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current explicit OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build and explicitly names
a market-neutral gold/silver ratio-reversion basket as an acceptable sleeve.
The bounded extraction preserves three completely read governed records:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, recording
   Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and its state-dependent gold/silver
   relationship warning.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, the exchange-defined
   gold-price divided by silver-price spread and opposed-leg carrier.
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, recording the complete
   23-page published paper by Moskowitz, Ooi, and Pedersen (2012), *Journal of
   Financial Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`, its
   author-hosted retrieval hash, monthly return horizon, and commodity scope.

Schweikert and CME support the relative-value carrier. Moskowitz, Ooi, and
Pedersen support only monthly own-return information and do not prescribe a
median or contrarian direction. The ordinary median of relative returns,
continuous-CFD translation, and execution contract are untested QM
mechanizations. No source or sibling efficacy, density, neutrality, cost, or
portfolio-decorrelation result transfers.

## Locked Mechanic

At the first executable `XAUUSD.DWX` D1 tick of broker month `M`:

1. Repair malformed owned exposure, close a surviving prior-month package,
   and persist month `M` before every fallible entry gate. Never retry `M`.
2. Reconstruct exactly thirteen consecutive synchronized completed broker-
   month closes for both `XAUUSD.DWX` and `XAGUSD.DWX`, oldest first.
3. For each endpoint calculate `q[i]=ln(XAU_close[i]/XAG_close[i])`; calculate
   the twelve adjacent changes `r[i]=q[i+1]-q[i]`.
4. Sort all twelve individual changes ascending and define the ordinary even
   median `m=(sorted_r[5]+sorted_r[6])/2`.
5. If `m>1e-12`, sell XAU and buy XAG. If `m<-1e-12`, buy XAU and sell XAG.
   Equality and the epsilon interior consume the month flat. Magnitude never
   changes risk.
6. Target equal absolute USD notionals within a 20% mismatch ceiling. Split
   one aggregate `RISK_FIXED=1000` budget across frozen
   `3.5*ATR(20,D1)` server stops; if leg two fails, flatten leg one.
7. Close both legs at the next genuine broker-month boundary; 40 elapsed days
   is stale repair only. Spread ceilings are 1,500 XAU points and 500 XAG
   points.

Both news axes, legacy news, and Friday close are OFF in the backtest setfile.
They are framework inputs and must not be equality-pinned by the EA. No ratio-
level z-score, block aggregation, old/recent comparison, current-month data,
fallback estimator, outright-metal trade, trained component, banned signal,
external feed, target, trail, scale-in, grid, martingale, pyramid, or retry is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_MEDIAN_DIRECTION_AND_CFD_TRANSLATION_RISK`: peer-reviewed
  gold/silver relationship evidence, an official exchange carrier, and a
  complete-read peer-reviewed monthly-return lineage support a bounded test;
  the median and contrarian conjunction remain untested.
- R2 `PASS`: clock, synchronized endpoints, ratio orientation, twelve
  adjacent changes, full sort, even-median indexes, epsilon, side, attempt,
  equal notional, aggregate fixed risk, stops, spread, rollover, atomicity,
  and repair are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data plus MT5 state supply every runtime
  field.
- R4 `PASS`: timestamps, completed prices, logarithms, sorting, arithmetic,
  ATR risk plumbing, and execution state only; no ML or prohibited signal.

## Duplicate Decision

The canonical checker scanned 4,879 registry rows and 1,490 cards. The
configured Strategy Wiki root was unavailable and is recorded in the receipt.
It raised three expected fuzzy neighbors:

- `QM5_41389` forms four chronological three-change means and sorts only
  those four block means; this candidate sorts all twelve raw changes.
- `QM5_41356` replaces two observations per tail before averaging all twelve;
  this candidate discards magnitude outside the two central order statistics.
- `QM5_41357` applies that Winsorized statistic to the XTI/XNG carrier.

Manual review also separates `QM5_20263` (current ratio level versus rolling
median/MAD), `QM5_41104` (recent versus old block medians), and `QM5_20269`
(ordinary median-return continuation on outright WTI). The XAU/XAG carrier,
ordinary median of twelve individual ratio changes, contrarian side, opposed
legs, and monthly package lifecycle are jointly load-bearing. Verdict:
`DISTINCT_XAUXAG_ORDINARY_MONTHLY_RETURN_MEDIAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Authorization Boundary

This approval permits one bounded source packet, approved card and G0
decision, deterministic identity/magic allocation, branch-only V5 build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, and one
paced Q02 enqueue below the CPU ceiling. It excludes manual backtests,
optimization, portfolio admission, correlation waivers, portfolio-gate edits,
deployment, live manifests, `T_Live`, AutoTrading, and live use.
