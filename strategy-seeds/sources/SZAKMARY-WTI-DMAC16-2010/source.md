---
source_id: SZAKMARY-WTI-DMAC16-2010
title: Szakmary commodity trend following and CME WTI market packet
publisher: Journal of Banking and Finance / CME Group
source_type: peer_reviewed_paper_plus_exchange_reference
status: approved
approved_by: mission-directed fleet assignment
approved_at: 2026-07-09
primary_url: https://doi.org/10.1016/j.jbankfin.2009.08.004
---

# Szakmary Commodity Trend Following - WTI DMAC Source

## Primary source

Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010), "Trend-following
trading strategies in commodity futures: A re-examination", *Journal of
Banking & Finance*, 34(2), 409-426:

https://doi.org/10.1016/j.jbankfin.2009.08.004

The peer-reviewed study uses 48 years of monthly data across 28 commodity
futures markets. Its dual-moving-average family compares the latest monthly
unit value with a longer monthly average and stays flat inside a neutral band.
The source parameterization selected for this card is:

- short-term moving average: latest end-of-month value (one month);
- long-term moving average: six monthly end values;
- neutral band: 2.5% around the long-term moving average;
- long above the upper band, short below the lower band, flat inside it.

The paper reports broad commodity-level evidence rather than a guaranteed WTI
result. Q02 and later gates therefore test the `XTIUSD.DWX` CFD port without
importing a performance number into the approval decision.

## Supplemental market source

CME Group, "WTI Crude Oil Futures":

https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html

CME identifies WTI as a leading oil benchmark and provides the exchange-market
lineage for the paper's crude-oil futures universe. This supplement establishes
the target exposure; it does not alter the trading rule.

## Mechanization boundary

The V5 expression samples `XTIUSD.DWX` D1 closes only when the broker calendar
opens a new month. It reconstructs the six latest completed month-end closes,
uses the newest as the one-month value, averages all six for the long mean, and
applies the source's 2.5% band.

The CFD port necessarily differs from the paper's rolled nearby-futures unit
value series. That basis risk is explicit and falsifiable. Runtime reads only
Darwinex MT5 OHLC, ATR, spread, broker calendar, and framework state. It does
not read futures curves, contract rolls, inventory, volume, open interest,
CSV, API, news forecasts, or analyst input.

An ATR hard stop is the only V5 risk-contract addition. There is no take-profit,
daily indicator crossover, event gate, volatility optimizer, parameter fit,
grid, martingale, pyramiding, or machine-learning component. Friday close is
disabled because the source is a month-to-month holding rule; forcing a weekly
flat would destroy the tested exposure and is documented on the card.

## Reputable-source criteria

- R1: PASS. The primary source is a peer-reviewed Journal of Banking & Finance
  article with a DOI; CME is the official derivatives exchange reference.
- R2: PASS. The selected 1/6-month, 2.5%-band rule is deterministic and
  independently reproducible from completed D1 bars.
- R3: PASS. `XTIUSD.DWX` exists in the local DWX matrix and magic registry.
- R4: PASS. No ML, adaptive fitting, grid, martingale, external runtime feed,
  or multi-position magic is used.

## Dedup boundary

This is not the existing M15 30/140 crude crossover, a D1 Donchian breakout,
12-month return-sign TSMOM, 3/9-month confirmation, 6/12-month return
alignment, 52-week high/low anchor, weekly momentum, RSI pullback, or any WTI
calendar/event strategy. The source-defined monthly neutral band is the entry,
exit, and stand-aside mechanism.
