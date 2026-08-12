---
source_id: MEHLITZ-AUER-WTI-R6Q7-2026
title: Mehlitz-Auer memory-enhanced momentum - WTI R6-q7 extraction
publisher: The European Journal of Finance / Brandenburg University of Technology
source_type: peer_reviewed_paper_with_complete_open_precursor
status: approved
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-07
primary_url: https://doi.org/10.1080/1351847X.2023.2220118
open_precursor_url: https://www.researchgate.net/publication/357152829_Risk_and_return_of_passive_and_active_commodity_futures_strategies
strategy_ids:
  - MEHLITZ-AUER-MEM-2024_XTI_R6Q7_S03
---

# Mehlitz-Auer WTI R6-q7 Source Packet

## Source Identity And Complete-Read Record

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced
momentum in commodity futures markets," *The European Journal of Finance*
30(8), 773-802, DOI `10.1080/1351847X.2023.2220118`.

The complete openly readable precursor is Chapter 3, pp. 51-74, with Appendix
C, pp. 110-113, of Julia Sophia Mehlitz (2021), *Risk and return of passive
and active commodity futures strategies*, Brandenburg University of
Technology Cottbus-Senftenberg. The parent repository packet
`strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md` records an end-to-end
review of the chapter's data, methodology, results, robustness sections,
conclusion, and appendix. That completely reviewed packet is the bounded
source for this extraction.

The source universe explicitly contains WTI crude oil. Section 3.3.1 defines
ranking returns over `R={1,3,6,12}` months. Sections 3.3.2.1-3.3.2.2 define
the heteroskedasticity-robust Lo-MacKinlay variance-ratio state, link the
matching orders `q={2,4,7,13}` to those horizons, use the latest 32 monthly
returns, require a two-sided 10% significant deviation from one, and map
persistent winners/losers to continuation and anti-persistent winners/losers
to reversal. This extraction selects the source-declared `R6-q7` pair.

No ranking period, lag order, memory window, or significance threshold was
selected from Darwinex results. The source's cross-commodity evidence is not a
standalone WTI track record, and no performance statistic is imported into a
QM gate.

## Locked R6-q7 Rule

At the first tradable bar of each broker month, reconstruct 33 consecutive
completed WTI month-end closes and form 32 chronological log returns
`r[0]..r[31]`. Let `d[t]=r[t]-mean(r)` and
`SSE=sum(d[t]^2)`.

For lags `k=1..6`:

```text
rho[k]   = sum(d[t] * d[t-k], t=k..31) / SSE
delta[k] = sum(d[t]^2 * d[t-k]^2, t=k..31) / SSE^2
w[k]     = 2 * (7-k) / 7

VR(7)    = 1 + sum(w[k] * rho[k], k=1..6)
theta(7) = sum(w[k]^2 * delta[k], k=1..6)
z_vr     = (VR(7)-1) / sqrt(theta(7))
```

The fixed weights are therefore:

```text
w = [12/7, 10/7, 8/7, 6/7, 4/7, 2/7]
```

Require `abs(z_vr) > 1.64485362695147`. Let `R6` be the sum of the latest six
monthly log returns. The source direction matrix is:

```text
direction = sign(R6) * sign(z_vr)
```

- positive direction: long WTI;
- negative direction: short WTI;
- insignificant `z_vr`, zero `R6`, or invalid arithmetic: flat.

The position is renewed at the next month boundary. This is the published
memory-enhanced momentum construction applied to one source-universe member,
not a fitted crossover or an oscillator.

## Bounded QM Mechanization

The V5 carrier derives completed broker-month endpoints from bounded
`XTIUSD.DWX` D1 history because native MN1 data is not guaranteed in the
tester. It evaluates only at a genuine D1 broker-month transition, applies the
locked `R6-q7` rule, and allows at most one consumed entry attempt per broker
month. A frozen `3.5 * ATR(20,D1)` hard stop, 35-calendar-day stale guard,
spread cap, fixed-risk sizing, and restart-safe month ledger are explicit QM
risk and execution controls; they do not alter the signal.

The source uses monthly collateralized futures-index returns, whereas
`XTIUSD.DWX` is a continuous Darwinex CFD proxy. Roll construction, basis,
financing, gaps, contract metadata, costs, and single-instrument concentration
are unproven. Q02 must falsify density and economics. Q09 alone may measure
realized overlap with the certified XAU/SP500/NDX/XNG book.

Runtime reads only native MT5 D1 time/close, ATR, quotes, spread, broker
calendar, positions, deal history, and V5 framework state. It does not read a
futures curve, external file or API, inventory series, analyst input, volume,
open interest, or trained output.

## Reputable-Source Criteria

- R1: PASS. The primary citation is a peer-reviewed journal article with a DOI
  and a completely reviewed open precursor; WTI and `R6-q7` are explicit in
  the source lineage.
- R2: PASS. The 33 endpoints, 32 returns, six-month ranking return, six lag
  terms, fixed weights, robust statistic, critical value, direction matrix,
  holding clock, hard stop, and attempt policy are deterministic.
- R3: PASS. `XTIUSD.DWX` D1 is registered and has an established T1-T5 tester
  route; no external runtime data is required.
- R4: PASS. Native logarithm, calendar, variance-ratio, and ATR arithmetic
  only; no adaptive fit, banned signal indicator, grid, martingale,
  pyramiding, or multiple positions per magic.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,313 registry rows and 430
cards, found no exact collision, and surfaced only the expected source-family
fuzzy neighbors. Manual review fixes the boundary:

- `QM5_13134_energy-vr-mom` implements `R1-q2`, with one-month direction and
  one autocorrelation lag.
- `QM5_20253_wti-vr3-mom` implements `R3-q4`, with three-month direction,
  three lags, and weights `1.5/1.0/0.5`.
- This extraction implements `R6-q7`, with six-month direction, six lags,
  weights `12/7` through `2/7`, and six squared robust weights.
- `QM5_20059_wti-tsmom6m` is plain six-month sign momentum without a memory
  estimator, significance gate, or anti-persistence reversal.
- `QM5_20245_wti-vr-rsm` applies `q=2` memory to twelve binary monthly signs,
  not the source's cumulative `R6-q7` pair.

The ranking interval, lag set, weight vector, robust variance, direction path,
and resulting flat months all differ. They are jointly load-bearing; this is
not authorization to optimize adjacent horizons after Q02.

## Safety Boundary

This packet authorizes one `RISK_FIXED` research/backtest carrier only. It does
not authorize a live/demo/shadow setfile, manual backtest, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, portfolio-gate edit,
or correlation waiver.
