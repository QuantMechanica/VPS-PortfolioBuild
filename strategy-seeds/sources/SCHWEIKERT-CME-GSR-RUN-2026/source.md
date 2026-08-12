---
source_id: SCHWEIKERT-CME-GSR-RUN-2026
title: Gold-silver fresh relative-return run exhaustion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20275_gsr_runfade_g0.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - gsr-runfade
---

# XAU/XAG Fresh-Run Fade Source Packet

## Approved Source Of Record

This bounded extraction uses only two already governed repository packets,
both read completely after the durable mission decision was recorded:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, and Olayinka
   (2021), *Resources Policy* 72, 102045, DOI
   `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread" and its governed related material.

The durable OWNER approval is
`decisions/2026-08-11_qm5_20275_gsr_runfade_g0.md`. No new online page,
blocked content, inferred table value, or unrecorded source is used.

## Source Findings Used

The peer-reviewed lineage supports testing a potentially state-dependent
long-run gold/silver relationship rather than assuming one immutable
equilibrium. The CME lineage defines the gold/silver ratio as gold price
divided by silver price and supports treating the two instruments as one
intermarket relative-value carrier. Gold and silver share precious-metals
drivers while differing in monetary, safe-haven, and industrial sensitivity.

These findings justify a falsifiable relative-price hypothesis. They do not
establish that a run of relative returns is exhausted, that an inverse basket
will converge, or that a Darwinex CFD package is neutral or uncorrelated.

## Bounded QM Mechanization

On each new `XAUUSD.DWX` D1 host bar, align seven completed XAU/XAG closes and
form `r[k]=ln(XAU_close[k])-ln(XAG_close[k])`, newest completed shift `k=1`.
Define six chronological relative returns `d[k]=r[k]-r[k+1]`.

A fresh upper run has five strictly positive newest returns and a nonpositive
sixth return. A fresh lower run has five strictly negative newest returns and
a nonnegative sixth return. Fade the upper run with SELL XAU / BUY XAG and the
lower run with BUY XAU / SELL XAG. Close on the first completed relative
return against the original run or after twelve calendar days.

The five-return length, preceding break, strict signs, inverse sides, CFD
carrier, equal stop-risk split, ATR stops, spread caps, consumed-attempt
ledger, counter-return exit, and stale guard are transparent QM choices. They
are not attributed to the sources. No source return, alpha, drawdown, density,
CFD equivalence, neutrality, or portfolio-correlation statistic is imported.

## Exact Event Contract

For positive finite synchronized completed closes:

```text
r[k] = ln(XAU_close[k]) - ln(XAG_close[k]), k=1..7
d[k] = r[k] - r[k+1],                      k=1..6

upper = d[1]>0 and d[2]>0 and d[3]>0 and d[4]>0 and d[5]>0 and d[6]<=0
lower = d[1]<0 and d[2]<0 and d[3]<0 and d[4]<0 and d[5]<0 and d[6]>=0

upper package = SELL XAU, BUY XAG
lower package = BUY XAU, SELL XAG
```

Zero breaks the qualifying run. The sixth return is outside the run and must
break it, which makes the newest completed bar a fresh length-five event
rather than an overlapping continuation. There is no magnitude score,
standardization, regression, order statistic, channel, calendar direction,
external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,339 active
and reserved EA-registry rows and 448 cards. Existing XAU/XAG convergence
systems use arithmetic ratio scores, rolling residuals, conditional
regressions, median/deviation scores, empirical tails, failed channel breaks,
or monthly cross-sectional ranks. None uses an exact fresh run of five daily
relative-return signs followed by an immediate inverse package and a first-
counter-return exit.

The chronological return orientation, five strict signs, sixth-return break,
fresh event timestamp, inverse sides, and counter-return exit are jointly
load-bearing. Removing the fresh-run break or changing the entry to
continuation would define a different strategy.

## Reputable-Source Criteria

- R1: PASS. One bounded `source_id` supplies lineage to two named-author
  peer-reviewed DOI records and one governed CME exchange packet; no
  performance claim transfers.
- R2: PASS. Exact shifts, return orientation, event signs, sides, aggregate
  risk, stops, exit, attempt, and stale guard are fixed and mechanical.
- R3: PASS with disclosed basis risk. Registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 histories plus native MT5 execution state supply every
  runtime input. Q02 is bounded to synchronized history.
- R4: PASS. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The sources support testing a structural relative-value carrier, not the run
fade's efficacy. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics. Downstream gates
alone own robustness and correlation. No failure may be rescued by changing
the run length, preceding-break rule, direction, exit, stop, hold, spread,
retry contract, or carrier.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or neutrality claim.
