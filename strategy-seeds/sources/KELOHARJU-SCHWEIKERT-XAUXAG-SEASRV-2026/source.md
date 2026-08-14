---
source_id: KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026
title: XAU/XAG same-calendar seasonal-surprise reversion composite
publisher: Journal of Finance / Journal of Banking & Finance / CME Group
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21517_xauxag_seas_rv_g0.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - xauxag-seas-rv
---

# XAU/XAG Seasonal-Surprise Reversion Source Packet

## Approved sources of record

This bounded extraction uses only three already approved repository packets,
all of which were read completely before mechanization:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, covering
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, with a complete 57-page NBER review.
2. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Schweikert (2018), "Are gold and silver cointegrated?" *Journal of
   Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, and Olayinka (2021),
   *Resources Policy* 72, 102045, DOI
   `10.1016/j.resourpol.2021.102045`.
3. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME
   Group's gold/silver ratio-spread definition and precious-metal driver
   discussion.

The durable source approvals in those packets and the OWNER commodity/energy
portfolio mission dated 2026-08-14 authorize one structural, non-live card,
allocation, build, and paced Q02 handoff. No new blocked page, inferred table,
or unreviewed online claim is used.

## Findings used

- Keloharju, Linnainmaa, and Nyberg define a commodity expectation from the
  average return in the same calendar month over prior years, with at least
  five historical observations. Their result is cross-sectional and broad;
  it does not test a two-metal residual surprise.
- The gold/silver papers support a long-run but potentially time-varying
  relative-price relationship and explicitly warn against treating one
  constant equilibrium as universal.
- CME defines gold divided by silver as a tradable intermarket relationship
  and records the metals' shared precious-metal exposure alongside different
  monetary, safe-haven, industrial, and business-cycle drivers.

Together these findings support a falsifiable question: after removing the
recurring same-calendar expectation, does an unusually large completed
gold-minus-silver monthly return converge over the next month? The sources do
not test this conjunction or prescribe its threshold, standardization, CFD
mapping, fixed-risk sizing, stops, or holding contract.

## Bounded mechanization

At the first tradable `XAUUSD.DWX` D1 bar of broker month `M`, reconstruct the
just-completed broker month `J=M-1` for synchronized XAU and XAG. Define its
relative log return:

```text
realized_J = ln(XAU_end_J / XAU_end_(J-1))
           - ln(XAG_end_J / XAG_end_(J-1))
```

For the same calendar month as `J`, load up to exactly ten earlier years,
excluding `realized_J`. Retain only samples whose two legs and both month-end
timestamps match exactly; require at least five. Compute the arithmetic mean
and sample standard deviation with denominator `n-1`:

```text
seasonal_mean = mean(relative_return_y)
seasonal_sd   = sqrt(sum((relative_return_y-seasonal_mean)^2)/(n-1))
surprise_z    = (realized_J-seasonal_mean)/seasonal_sd
```

Require positive variance. At a strict `surprise_z > +0.50 + 1e-10`, sell
XAU and buy XAG. At a strict `surprise_z < -0.50 - 1e-10`, buy XAU and sell
XAG. Otherwise consume the decision month flat. One aggregate
`RISK_FIXED=1000` budget is divided equally by per-leg stop risk; each leg has
a frozen `3.5*ATR(20,D1)` hard stop. Close and reconsider at the next genuine
broker-month transition, repair malformed packages immediately, and enforce a
40-calendar-day stale guard.

The ten-year cap, five-sample floor, sample-standard-deviation convention,
0.50 band, tolerance, contrarian direction, continuous Darwinex CFD carrier,
equal stop-risk split, stop, spread caps, attempt ledger, and lifecycle are
transparent QM hypotheses. No cited result transfers to this candidate.

## Non-duplicate boundary

The canonical pre-allocation checker returned `CLEAN` for slug
`xauxag-seas-rv`, strategy ID
`KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026_S01`, and the complete mechanic
across 4,389 EA-registry rows and 485 intake cards.

Manual family review separates the nearest builds:

- `QM5_20186_xauxag-samecal` follows the historical same-calendar relative
  mean for the decision month. It never observes the realized-minus-expected
  surprise and never reverses its sign.
- `QM5_20189_xauxag-calmom1` follows only when the seasonal sign agrees with
  the immediately completed relative return. This candidate subtracts the
  seasonal mean, divides by its historical sample scale, and trades against a
  sufficiently large residual.
- `QM5_20057_xauxag-xmom1` follows the raw completed relative month without a
  recurring calendar expectation or standardization.
- `QM5_12862_xauxag-rspread` fades a rolling ten-D1 return-spread z-score; it
  has no completed-month or same-calendar sample.
- Ratio-level, OLS, quantile, C-MTAR, median/MAD, empirical-tail, channel, run,
  variance-ratio, moment-rank, and long-horizon reversal baskets use different
  formation objects and clocks.

The just-completed month, same-calendar historical sample, surprise
subtraction, sample scaling, strict contrarian band, and monthly opposite-leg
package are jointly load-bearing. Replacing the surprise with either source
state alone recreates a built parent.

## Reputable-source criteria

- R1: PASS. The primary seasonal lineage is a peer-reviewed *Journal of
  Finance* paper with DOI and complete open-paper review; the relative-value
  lineage contains two named peer-reviewed papers plus a governed CME carrier.
- R2: PASS. Calendar mapping, timestamp alignment, return orientation, sample,
  estimator, band, directions, aggregate risk, stops, attempt state, renewal,
  and repair are fixed mechanically.
- R3: PASS. Registered synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 history
  plus native MT5 trade state supply every runtime input.
- R4: PASS. Runtime uses calendar, OHLC, logarithms, arithmetic, ATR, spread,
  quote, position, and deal state only; no trained output or prohibited signal
  component is required.

## Claim, kill, and safety boundary

No source profit factor, return, significance, drawdown, cost, trade count,
CFD equivalence, hedge ratio, neutrality, or portfolio-correlation statistic
is imported. Narrow two-name breadth, ten-year same-calendar sampling,
standard-deviation instability, common-metal exposure, silver industrial
beta, CFD financing/rolls, gaps, legging, hard-stop asymmetry, and lot
granularity are first-order risks.

Q02 must retire the card below five completed packages per full post-warm-up
year or on nonpositive governed economics. Downstream gates alone own
robustness and correlation. Failure may not be rescued by changing the sample,
estimator, threshold, direction, carrier, stop, hold, spreads, or retry rule.

This packet authorizes research, deterministic allocation, one V5 build,
strict compile/Q01, one logical-basket `RISK_FIXED` setfile, and one paced
non-live Q02 handoff. It does not authorize a manual backtest, live/demo/shadow
artifact, AutoTrading, `T_Live`, a deploy manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
