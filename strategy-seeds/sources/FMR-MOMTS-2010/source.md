---
source_id: FMR-MOMTS-2010
title: Tactical allocation in commodity futures markets - combining momentum and term structure signals
publisher: Journal of Banking & Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-10
created: 2026-07-10
created_by: Research
uri: https://openaccess.city.ac.uk/id/eprint/6416/
cards_extracted:
  - energy-momcarry
  - xauxag-xmom12
---

# Fuertes-Miffre-Rallis Momentum/Term-Structure Source Packet

## Approval And Review Scope

- Approval basis: the OWNER mission dated 2026-07-10 explicitly directs one
  new structural commodity/energy card, build, and Q02 enqueue.
- The complete 47-page accepted manuscript was read end to end, including the
  methodology, robustness sections, references, tables, figures, and
  appendices.
- Research extraction is bounded to one double-screen strategy: the paper's
  one-month momentum/term-structure portfolio, translated to the two registered
  Darwinex energy carriers XTIUSD.DWX and XNGUSD.DWX.

## Primary Citation

Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010), "Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term Structure
Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
https://doi.org/10.1016/j.jbankfin.2010.04.009.

Open accepted manuscript:
https://openaccess.city.ac.uk/id/eprint/6416/1/Fuertes_Miffre_Rallis_JBF2010%28CRO%29.pdf

## Relevant Source Locations

- pp. 4-6: 37-commodity universe, including crude oil and natural gas, and
  monthly construction from nearby/second-nearby futures.
- pp. 6-7: momentum sorts use average past returns; the one-month ranking and
  one-month holding variant is explicitly tested.
- pp. 12-13: TS1 ranks front-end annualized roll return, buying the highest and
  shorting the lowest term-structure signals for one month.
- pp. 17-18: the double sort buys high-roll-return winners and shorts
  low-roll-return losers; 1-, 3-, and 12-month momentum rankings are tested with
  a one-month hold.
- pp. 21-22 and Table 7: the paper evaluates diversification against equity,
  bond, and FX returns. These source-sample results are context only.
- pp. 22-29 and Tables 8-10: liquidity, data-snooping, alternative-risk-model,
  conditional-risk, and extended-sample checks.
- pp. 44-46: appendix risk models and end-of-month versus mid-month checks.

## Bounded Mechanization

The source has historical futures curves; the Darwinex CFD tester does not.
The card therefore uses the broker's native long-versus-short swap differential
as a falsifiable carry/term-structure proxy. At the first D1 bar of each broker
month it ranks XTI and XNG on the last completed month's return and separately
ranks their current swap differentials. A package opens only when the two ranks
agree: buy the momentum winner/higher-carry leg and short the loser/lower-carry
leg. `.DWX` tester symbols expose zero swap, so the Q02 baseline predeclares a
fixed `+1` carry rank (XTI over XNG) and still requires the independent
completed-month momentum rank to agree. Equal fixed risk is split across the
two legs and the package is renewed monthly.

This is not a replication of the 37-future source portfolio. In particular,
broker swap is not nearby-versus-second-nearby roll return, the cross-section is
only two instruments, and Q02 cannot represent historical swap changes. The
fallback makes Q02 a conditional momentum/carry-prior interaction test, not a
historical carry backtest. No source return, alpha, Sharpe ratio, or correlation
is imported into the QM prior.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI or short pullback.
- Not `QM5_12733_xti-xng-xmom`: raw relative momentum can trade without carry
  agreement and uses a 12-month formation horizon.
- Not `QM5_13089_xti-xng-carry`: carry alone trades weekly with a 12-month
  adverse-return guard; this card requires an independent completed-month
  momentum rank, trades monthly, and renews only on rank agreement. Both make
  the `.DWX` zero-swap limitation explicit rather than claiming historical
  carry observations.
- Not `QM5_13121_energy-tfmom`: that card uses 12-month momentum plus a
  seven-month price-trend overlay and inverse-volatility weights, not swap.
- Not `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, or `QM5_13123`:
  those pair momentum with residual volatility, same-calendar history,
  skewness, long-horizon reversal, or value rather than carry.

Pre-allocation repository dedup verdict: `CLEAN` on 2026-07-10.

## R1-R4

- R1 reputable source: PASS. Peer-reviewed *Journal of Banking & Finance*
  paper, DOI, and complete accepted manuscript in an institutional repository.
- R2 mechanical: PASS. Fixed completed-month return rank, fixed broker-swap
  rank, strict agreement gate, monthly rebalance, equal risk, ATR hard stops,
  stale-package close, and orphan repair.
- R3 data available: PASS with translation risk. XTIUSD.DWX and XNGUSD.DWX D1
  OHLC and symbol swap properties are MT5-native. The Q02 setfile explicitly
  locks the known all-zero tester fallback; nonzero tied or missing metadata
  still stands down.
- R4 no ML/banned logic: PASS. No ML, external runtime feed, grid, martingale,
  pyramiding, or discretionary input.
