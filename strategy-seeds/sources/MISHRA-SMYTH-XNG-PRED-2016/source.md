---
source_id: MISHRA-SMYTH-XNG-PRED-2016
title: Are Natural Gas Spot and Futures Prices Predictable?
publisher: Economic Modelling / Elsevier
source_type: peer_reviewed_paper_with_author_manuscript
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://doi.org/10.1016/j.econmod.2015.12.034
institutional_record_url: https://research.monash.edu/en/publications/are-natural-gas-spot-and-futures-prices-predictable/
open_manuscript_url: https://www.researchgate.net/profile/Russell-Smyth/publication/288833833_Are_Natural_Gas_Spot_and_Futures_Prices_Predictable/links/5afde06b458515e9a550dd83/Are-Natural-Gas-Spot-and-Futures-Prices-Predictable.pdf
strategy_ids:
  - MISHRA-SMYTH-XNG-2M-2016_S01
  - MISHRA-SMYTH-XNG-1M-2016_S02
---

# Mishra-Smyth Natural-Gas Two-Month Contrarian Source

## Primary source lineage

Mishra, V. and Smyth, R. (2016), "Are Natural Gas Spot and Futures Prices
Predictable?", *Economic Modelling*, 54, 178-186, DOI
https://doi.org/10.1016/j.econmod.2015.12.034.

The complete 36-page author manuscript and the Monash University publication
record were checked against the peer-reviewed citation. Relevant manuscript
locations are printed pages 6-7 for data, page 18 for the trading rule, page 19
for the authors' interpretation, and page 34 for Table 10.

The paper studies EIA daily Henry Hub spot and one- through four-month natural-
gas futures series, with 4,294 observations per series. Section 2 states a
sample from 1 January 1997 to 3 March 2014, while Table 1 states 7 January 1997
to 3 March 2014; that discrepancy is preserved rather than silently resolved.

## Source-defined rule

The trading simulation separately tests fixed holding/trading frequencies from
one day through four months. For a selected two-month frequency:

- the first two-month period is observation only;
- at every later two-month boundary, buy when price fell from the preceding
  two-month endpoint and sell when it rose;
- if price is exactly unchanged, retain the preceding position; and
- liquidate the final position at market.

This is an unconditional sign-contrarian state. It has no return threshold,
RSI, moving average, volatility regime, seasonal estimate, adaptive parameter
or fitted mean. The source begins with hypothetical USD 100, assumes full
investment, and charges no transaction cost or commission.

Table 10 reports positive two-month simulation results for spot and all four
futures series, with four of the five exceeding their own full-sample buy-and-
hold comparator. Those figures have no significance test, risk adjustment,
drawdown, transaction cost, roll specification, margin mechanic or short-
financing model. The authors warn that the unusually strong two-month result
may be sample- or strategy-specific. No reported performance number is used as
an expected return or approval claim for this carrier.

## Mechanization boundary

The source does not define the calendar epoch for its two-month buckets. The V5
carrier therefore locks a deterministic broker-calendar convention before any
test: periods are Jan-Feb, Mar-Apr, May-Jun, Jul-Aug, Sep-Oct and Nov-Dec, and
the decision occurs on the first tradable D1 bar of each odd-numbered month.
It reconstructs three distinct completed month-end closes from D1 history and
compares the latest (`C0`) with the close two months earlier (`C2`):

- `C0 < C2`: BUY, fading the completed two-month decline;
- `C0 > C2`: SELL, fading the completed two-month rise; and
- `C0 == C2`: retain the prior position, or remain flat when no position exists.

For a non-equality decision, the prior package is liquidated and the new fixed
two-month package is opened, including a same-direction renewal. With zero
costs this is economically equivalent to carrying the same directional state;
the explicit renewal makes the source's fixed holding frequency observable and
restart-auditable in V5. A frozen D1 ATR hard stop, a 70-day stale guard, spread
cap, one-position rule and no-reentry-after-stop guard are V5 risk-contract
additions, not claims from the paper.

`XNGUSD.DWX` is a continuous Darwinex CFD carrier. It is not identical to the
paper's Henry Hub spot series or its fixed-maturity NYMEX-labelled futures
series. Basis, roll construction, financing, execution costs and the CFD's
realized two-month behavior are unproven and must be falsified by the pipeline.
Runtime uses only MT5 D1 OHLC, ATR, spread, broker calendar, deal history and
framework position state; it reads no external data feed.

## Reputable-source criteria

- R1: PASS. One peer-reviewed *Economic Modelling* paper, DOI, university
  record and complete author manuscript form one source lineage.
- R2: PASS. Fixed two-month endpoints, unconditional opposite sign, explicit
  equality state and fixed renewal are mechanical. The missing calendar epoch
  is resolved once, ex ante, as an odd-month broker-calendar anchor.
- R3: PASS. `XNGUSD.DWX` is a registered D1 carrier. Six fixed decisions per
  complete calendar year narrowly clear the five-trade Q02 cadence floor;
  stop-outs and unavailable history can reduce realized entries.
- R4: PASS. No ML, banned indicator, adaptive fit, external runtime feed,
  stacking, grid, martingale or pyramiding is present.

## Non-duplicate boundary

Repository-wide source, strategy-id, phrase and mechanic searches found no
Mishra-Smyth extraction and no unconditional fixed two-month XNG sign fade.
The closest systems are materially different:

- `QM5_12567_cum-rsi2-commodity`: two-day cumulative RSI(2), SMA200 alignment
  and a five-bar maximum hold.
- `QM5_12620_comm-reversal-4wk-xngusd`: four-week return with a six-percent
  event threshold and 28-day maximum hold.
- `QM5_12895_xng-6m-reversal`: roughly six-month return with a 20-percent
  threshold plus SMA/ATR stretch conditions.
- `QM5_13102_xng-1w-rev-vol`: five-day return, two-percent threshold and a
  high-volatility percentile gate.
- `QM5_13139_energy-cv-rank`: a bimonthly XTI/XNG market-neutral 36-month
  coefficient-of-variation rank, not an XNG time-series sign contrarian.

This extraction is defined by its source-fixed two-month cadence,
unconditional sign state, no magnitude threshold and explicit renewal. It is
not a renamed short-horizon oscillator or threshold reversal.

## Safety boundary

The source and mission authorize research plus one RISK_FIXED backtest carrier
only. They do not authorize a live setfile, AutoTrading, T_Live access, a
deploy/T_Live manifest, portfolio admission or portfolio-gate changes.

## One-Month Extraction Addendum

The printed-page-18 simulation tests fixed frequencies from one day through
four months. `MISHRA-SMYTH-XNG-1M-2016_S02` selects one month ex ante: at each
new broker month it buys after a negative completed-month return and sells
after a positive one; equality retains state. A 40-day stale guard and frozen
ATR stop make the package auditable. No source performance number is imported.

This monthly state path differs from the existing two-month extraction and
from `QM5_12567`, which uses two-day RSI accumulation, SMA alignment and a
five-bar exit. The 2026-07-23 OWNER commodity-sleeve mission authorizes this
research card, build and Q02 only.
