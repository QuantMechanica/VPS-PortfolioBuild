---
source_id: KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026
title: XAU/XAG weekly correlation-break relative-value fade
publisher: Quantitative Methods in Economics / Journal of Banking and Finance / CME Group
source_type: peer_reviewed_exchange_composite_lineage
status: approved_source
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
approved_by: "OWNER commodity/energy portfolio mission 2026-08-30"
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_xauxag_correlation_break_reversion_source_approval.md
strategy_ids:
  - KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01
cards_extracted: []
parent_sources:
  - KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
---

# XAU/XAG Weekly Correlation-Break Relative-Value Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins three already governed repository sources. All three
were read completely before this packet was written; their exact paths, hashes,
byte counts, and line counts are fixed in
`artifacts/qm5_xauxag_corrbreak_rv_source_provenance_20260830.json`.

1. Krawiec and Gorska (2015), "Granger Causality Tests for Precious Metals
   Returns," *Quantitative Methods in Economics* 16(2), 13-22, is preserved in
   `strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md`.
   The complete ten-page paper studies London daily USD closes from 2008-2013,
   reports positive contemporaneous gold/silver log-return correlation of
   0.6061, rejects no-causality from gold returns to silver returns at one,
   five, and ten lags, and does not reject the reverse direction. It supplies
   historical dependence and ordering evidence, not a coefficient sign or
   trading rule.
2. Schweikert (2018), "Are gold and silver cointegrated? New evidence from
   quantile cointegrating regressions," *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, is preserved in
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`. The complete author
   preprint finds a state-dependent and asymmetric relationship and is adverse
   evidence against assuming one stable, automatically profitable linear
   spread. Some important constant-vector and upper-quantile specifications
   fail, the state is not known ex ante, and the estimates are not direct
   forecasts.
3. CME Group's governed packet at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` defines the
   gold/silver ratio as an intermarket spread and records shared precious-metal
   drivers alongside gold's greater monetary/safe-haven sensitivity and
   silver's greater industrial-cycle sensitivity.

The sources establish a related but state-dependent precious-metals carrier.
They do not establish that a correlation break reverts, that a five-session
relative displacement is predictable, or that a Darwinex CFD package is
neutral or profitable. Those are explicit QM hypotheses for Q02 to falsify.

## Bounded Mechanization

`KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01` is one predeclared logical
XAU/XAG D1 package:

- host/traded slot 0 is exact `XAUUSD.DWX`; companion/traded slot 1 is exact
  `XAGUSD.DWX`; both use D1;
- decide only on the first executable host D1 tick of each genuine broker week
  and within 180 minutes of that bar's open;
- persist the broker-week attempt before history, signal, news, spread, quote,
  ATR, sizing, or order gates; a rejected or flat week is never retried;
- load exactly 81 synchronized positive completed close pairs and form 80
  adjacent log returns for each metal, with no current-bar input;
- assign the oldest 60 returns to a baseline block and the newest 20 returns
  to a disjoint recent block;
- compute ordinary sample Pearson correlations `rho_old` and `rho_new`; reject
  zero variance or a non-finite statistic;
- clamp each correlation only for the Fisher transform to
  `[-0.999999999, +0.999999999]`, then compute
  `z_drop=(atanh(rho_old)-atanh(rho_new))/sqrt(1/57+1/17)`;
- require all four locked correlation-break boundaries:
  `rho_old >= 0.50`, `rho_new <= 0.35`,
  `rho_old-rho_new >= 0.25`, and `z_drop >= 1.645`;
- over the same 60-return baseline, compute relative returns
  `d=r_xau-r_xag`, their arithmetic mean `mu_d`, and sample standard deviation
  `sd_d`; reject nonpositive scale;
- compute the newest exact five-session displacement
  `disp5=sum(newest five d)-5*mu_d` and standardized score
  `score5=disp5/(sd_d*sqrt(5))`; require `abs(score5) >= 1.25`;
- if `score5 >= +1.25`, SELL XAU and BUY XAG; if
  `score5 <= -1.25`, BUY XAU and SELL XAG; magnitude never changes size;
- freeze the ratio anchor from five sessions before the signal, the newest
  completed log-ratio, and the exact halfway-retracement target between them;
- open one equal-USD-notional opposite-leg package, round both volumes down,
  reject post-rounding notional mismatch above 20%, and cap combined frozen
  stop loss at one `RISK_FIXED=1000` package budget;
- attach a frozen `3.5*ATR(20,D1)` hard stop per leg, use XAU/XAG spread
  ceilings of 1,500/3,000 points, and set no broker target; and
- close both legs when the newest completed log ratio reaches the frozen
  halfway target, after 15 completed host D1 bars, or after 24 calendar days.
  A missing persisted target, orphan, same-side pair, duplicate leg, or other
  malformed package is flattened immediately.

Both news axes, legacy news mode, and framework Friday close are OFF. The
package may span a weekend, but lifecycle repair runs every tick. There is no
fallback correlation window, OLS hedge ratio, ratio z-score, conditional
quantile fit, same-calendar estimator, oscillator, current-bar signal,
external feed, result-dependent tuning, grid, martingale, scale-in, or
pyramid.

## Exact Signal Contract

For synchronized completed returns `gx[i]` and `sx[i]`, oldest to newest:

```text
rho_old = corr(gx[0..59],  sx[0..59])
rho_new = corr(gx[60..79], sx[60..79])
z_drop  = (atanh(rho_old)-atanh(rho_new)) / sqrt(1/57+1/17)

break = rho_old >= 0.50
        and rho_new <= 0.35
        and rho_old-rho_new >= 0.25
        and z_drop >= 1.645

d[i]    = gx[i]-sx[i]
mu_d    = mean(d[0..59])
sd_d    = sample_sd(d[0..59])
disp5   = sum(d[75..79])-5*mu_d
score5  = disp5/(sd_d*sqrt(5))

break and score5 >= +1.25 => SELL XAU / BUY XAG
break and score5 <= -1.25 => BUY XAU / SELL XAG
otherwise                 => consume the broker week flat
```

The correlation break and five-session displacement are jointly
load-bearing. Dropping either condition or sliding the disjoint blocks creates
a different strategy. Equalities at locked boundaries qualify exactly as
shown; invalid or degenerate arithmetic consumes the week flat.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATE_TRANSLATION_AND_CFD_RISK`: complete-read
  peer-reviewed daily dependence and state-dependent relation evidence plus a
  governed exchange carrier. The correlation-break fade, thresholds, and CFD
  package are untested QM translations, and adverse source evidence is
  retained.
- R2 `PASS`: the weekly clock, exact synchronized history, disjoint blocks,
  Pearson and Fisher arithmetic, four break boundaries, relative scale,
  five-session score, sides, persisted attempt/target, shared risk, stops,
  atomic repair, retracement, and time exits are deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_CONTINUOUS_CFD_AND_LEGGING_RISK`: registered
  native XAU/XAG D1 history, quotes, contract metadata, positions, deals, and
  terminal-persistent execution state provide every runtime input. Q02 must
  prove density, fills, costs, and package accounting.
- R4 `PASS`: native dates, completed prices, logarithms, ordinary sums,
  products, square roots, `atanh`, comparisons, and ATR risk plumbing only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, pyramid, or random path.

## Non-Duplicate Boundary

The canonical preallocation checker examined 4,706 registry identities and
1,352 card files. The configured Strategy Wiki root was absent and is recorded
as such rather than claimed checked. There was no exact identity; the only
fuzzy family was `QM5_41031_xauxag-goldlead`, expected from the shared source
authors. Manual review resolves it:

- `QM5_41031` uses one completed gold return, a fixed 75-basis-point shock,
  and a bounded silver under-response; it never estimates correlation, never
  compares disjoint dependence blocks, and always exits on the next D1 bar;
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, `QM5_20268`,
  `QM5_21526`, and `QM5_13205` estimate ratio levels, OLS/CADF residuals,
  robust centers, tails, or conditional quantile envelopes; this candidate
  has no equilibrium center or fitted hedge coefficient;
- `QM5_12862` fades a rolling return-spread z-score without requiring a
  high-to-low correlation state transition;
- `QM5_20249` and `QM5_20254` estimate relative-return memory rather than a
  disjoint Pearson/Fisher dependence break; and
- weekly flow, path, run, common-shock, and same-calendar baskets observe
  different information objects and lifecycle clocks.

Receipt:
`artifacts/qm5_xauxag_corrbreak_rv_preallocation_dedup_20260830.json`.
Verdict:
`FUZZY_GOLDLEAD_RESOLVED_DISTINCT_DISJOINT_CORRELATION_BREAK_PLUS_FIVE_SESSION_RELATIVE_DISPLACEMENT_FADE`.

## Safety And Extraction Boundary

The current explicit OWNER mission authorizes one card, deterministic ID and
magic allocation, one branch-only non-live build, strict Q01 validation, one
logical `RISK_FIXED` backtest setfile/manifest, and one paced Q02 enqueue if
the CPU ceiling is not binding. It excludes manual tester dispatch;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; neutrality claims; and correlation waivers.

Expected cadence is approximately five to fifteen completed packages per full
post-warm-up year. Q02 must retire on zero trades, fewer than five completed
packages in any full post-warm-up year, wrong block membership, current-bar
leakage, unsynchronized endpoints, incorrect Pearson/Fisher/scale/score
arithmetic, wrong sides, missing attempt or target state, excess notional
mismatch, orphan survival, wrong lifecycle, nondeterminism, invalid risk mode,
or nonpositive governed economics. No failed baseline may be rescued by
moving a threshold, changing a window, dropping the hedge, or weakening a
gate.
