---
source_id: SCHWEIKERT-CME-XAUXAG-MAD-2026
title: Robust gold-silver ratio reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-07_qm5_20263_xauxag_mad_rv_g0.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
created: 2026-08-07
created_by: Research+Development
cards_extracted:
  - xauxag-mad-rv
---

# Robust XAU/XAG Ratio-Reversion Source Packet

## Approved Source Of Record

The complete repository packets reviewed for this bounded extraction are:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering:
   - Karsten Schweikert (2018), "Are gold and silver cointegrated? New
     evidence from quantile cointegrating regressions," *Journal of Banking &
     Finance* 88, 44-51, DOI
     https://doi.org/10.1016/j.jbankfin.2017.11.010; and
   - OlaOluwa S. Yaya, Xuan Vinh Vo, and Hammed A. Olayinka (2021), "Gold and
     silver prices, their stocks and market fear gauges: Testing fractional
     cointegration using a robust approach," *Resources Policy* 72, 102045,
     DOI https://doi.org/10.1016/j.resourpol.2021.102045.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread," and its precious-metals spread supplements.

The durable source approval is the OWNER commodity/energy portfolio mission,
which explicitly names a gold/silver ratio-reversion basket as an allowed
candidate and requires reputable-source criteria. Both parent packets were
read completely for this extraction.

## Source Findings Used

- The peer-reviewed lineage supports a long-run but potentially time-varying
  relationship between gold and silver prices. It does not support assuming a
  universal constant equilibrium or guaranteed reversion.
- CME defines the gold/silver ratio as gold price divided by silver price per
  troy ounce and presents it as a tradable intermarket spread.
- CME identifies shared precious-metals exposure alongside different monetary,
  safe-haven, industrial, and business-cycle drivers.

These findings support testing a relative-price reversion package. They do not
establish the candidate statistic, thresholds, CFD mapping, trade frequency,
profitability, neutrality, or portfolio decorrelation.

## Bounded QM Mechanization

On each new `XAUUSD.DWX` D1 bar, align 64 completed D1 closes for XAU and XAG
by timestamp and form `r_i = ln(XAU_i) - ln(XAG_i)`. Compute two independent
63-observation robust scores: the current score from shifts 1-63 and the prior
score from shifts 2-64. Each window uses its own median and median absolute
deviation (MAD):

```text
median = middle(sorted(r_0..r_62))
MAD    = middle(sorted(abs(r_i - median), i=0..62))
robust_z = 0.6744897501960817 * (latest_ratio - median) / MAD
```

Enter only on a fresh threshold crossing. A current score above `+2.0` after a
prior score at or below `+2.0` sells XAU and buys XAG. A current score below
`-2.0` after a prior score at or above `-2.0` buys XAU and sells XAG. Close the
package after convergence to `abs(robust_z) <= 0.5`, an invalid package/state,
or 45 calendar days. Each leg receives a frozen `3.5*ATR(20,D1)` hard stop and
half of one aggregate fixed-cash risk budget.

The 63-bar window, normal-consistency constant, MAD statistic, entry and exit
bands, crossing rule, Darwinex CFD carrier, equal risk split, ATR stop, spread
caps, Friday-close exception, and lifecycle rules are transparent QM choices.
They are not author or CME rules. No cited result transfers to this build.

## Non-Duplicate Boundary

The pre-allocation scan covered 4,320 EA-registry rows and all 840 card files.
It found no `xauxag-mad-rv` slug, `QM5_20263` allocation, strategy-ID collision,
or card using a gold/silver rolling median plus MAD robust score. Manual review
separates the closest systems:

- `QM5_12577_cme-xauxag-ratio` and `QM5_20157_xau-xag-ratio` standardize a
  fixed log ratio with an arithmetic mean and standard deviation;
- `QM5_20161_xauxag-ols-rv` estimates a rolling OLS hedge ratio and standardizes
  regression residuals with a mean and standard deviation;
- `QM5_13205_xau-xag-qc` mechanizes quantile-cointegration state rather than a
  rolling robust location/scale excursion;
- `QM5_20254_xauxag-vr-fade` gates a conventional ratio z-score with a monthly
  variance-ratio anti-persistence test; and
- `QM5_20249_xauxag-vr-spread` trades monthly relative-memory direction rather
  than daily ratio convergence.

The rolling median, rolling MAD, fixed normal-consistency scaling, independent
current/prior windows, fresh-cross entry, and no re-entry inside one excursion
are jointly load-bearing. Replacing median/MAD with mean/standard deviation
would collapse the candidate into an existing ratio-z family. Verdict:
`CLEAN_AFTER_EXPECTED_FAMILY_AND_MANUAL_REVIEW`.

## R1-R4

- R1: PASS. Two named peer-reviewed journal papers with DOI records plus a CME
  exchange carrier packet; durable source approval is recorded in-repository.
- R2: PASS. Alignment, ratio orientation, median, MAD, score, crossing, sides,
  sizing, stops, exits, and retry boundary are fixed and mechanical.
- R3: PASS. Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 history plus native MT5
  quote, ATR, spread, position, and deal state supply every runtime input.
- R4: PASS. Deterministic sorting and arithmetic only; no trained model,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Safety Boundary

This packet supports one card, deterministic allocation, a non-live V5 build,
strict Q01 validation, and one paced Q02 handoff. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate edit, portfolio admission, correlation waiver, or claim of
neutrality or decorrelation before governed evidence.
