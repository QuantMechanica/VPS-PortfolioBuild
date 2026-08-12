---
source_id: SZAKMARY-XNG-MCH3-2010
title: Szakmary monthly commodity channel rule - natural-gas three-month extraction
publisher: Journal of Banking and Finance / author-uploaded working paper
source_type: peer_reviewed_paper_with_author_manuscript
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://doi.org/10.1016/j.jbankfin.2009.08.004
open_manuscript_url: https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf
strategy_ids:
  - SZAKMARY-XNG-MCH3-2010
---

# Szakmary Natural-Gas Monthly Three-Month Channel Source

## Primary source lineage

Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010), "Trend-following
trading strategies in commodity futures: A re-examination", *Journal of
Banking & Finance*, 34(2), 409-426, DOI
https://doi.org/10.1016/j.jbankfin.2009.08.004.

The final peer-reviewed article studies monthly trend rules over 48 years and
28 commodity-futures markets. The full author-uploaded predecessor manuscript,
"Price Momentum and Trading Volume in Commodity Futures Markets", was read in
full for the mechanical extraction. Its commodity table explicitly includes
Natural Gas (`NG`) from April 1990. Section III defines the channel family:

- sample the unit-value series at each calendar month end;
- go long for the following month when the latest month-end value exceeds the
  maximum of the previous `L` month-end values;
- go short when the latest value is below the previous `L`-month minimum;
- remain flat when it lies between those extrema;
- use one-month holding periods; and
- test `L` equal to 3, 6, 9 and 12 months without optimizing a winning case.

The card selects the source-tested `L=3` rule. The article reports broad
commodity evidence; it does not establish a positive standalone Natural Gas
CFD result or low correlation to the current QM book. No historical source
performance number is imported into G0 or Q02.

## Mechanization boundary

The V5 carrier evaluates `XNGUSD.DWX` on the first D1 bar of a new broker
calendar month. It reconstructs four distinct completed month-end closes from
D1 history because `.DWX` MN1 bars are not guaranteed in the tester:

- `C0`: the just-completed month-end close;
- `C1..C3`: the three preceding month-end closes;
- long when `C0 > max(C1,C2,C3)`;
- short when `C0 < min(C1,C2,C3)`; and
- flat otherwise, including equality.

Any prior package is closed at the monthly boundary before the new one-month
package is considered, including when the direction repeats. A frozen D1 ATR
hard stop and 35-day stale guard are V5 risk-contract additions. Runtime uses
only MT5 OHLC, ATR, spread, broker calendar, deal history and framework state.
It does not read a futures curve, storage, weather, production, LNG flows,
volume, open interest, CSV, API, analyst input or news forecast.

The source used rolled nearby futures unit values. `XNGUSD.DWX` is a continuous
Darwinex CFD proxy, so roll, basis and contract-construction equivalence are
explicitly unproven and must be falsified by Q02 and later gates.

## Data and cadence precheck

`XNGUSD.DWX` D1 is registered in the V5 symbol matrix and its local T1 custom
history cache contains annual HCC files for 2017-2026 plus a compiled Daily
cache. The rule can make at most one entry package per month. Six completed
packages per year is the conservative card prior; it is not a backtest result.
The currently saturated tester fleet was not used for a cadence or performance
run, so Q02 is authoritative for both frequency and expectancy.

## Reputable-source criteria

- R1: PASS (Tier A). One source lineage is used: a peer-reviewed Journal of
  Banking & Finance article with a DOI and its complete author manuscript.
- R2: PASS. The latest completed month-end close, prior-three-close extrema,
  one-month hold, flat state and monthly renewal are deterministic.
- R3: PASS. `XNGUSD.DWX` is registered and local D1 cache files cover the
  required lookback; no external runtime data is needed.
- R4: PASS. No ML, adaptive parameter, banned indicator, grid, martingale,
  pyramiding or external runtime feed is used; one position per magic is
  enforced.

## Non-duplicate boundary

This is a new carrier/mechanic combination, not a claim that the abstract rule
family is new. `QM5_20008_wti-month-ch3` carries the same source-defined rule on
WTI. Repository searches found no XNG EA comparing one completed month-end
close with the extrema of the prior three completed month-end closes.

The requested incumbent comparison is materially different:

- `QM5_12567_cum-rsi2-commodity` is a short-horizon cumulative-RSI pullback
  above a 200-day trend filter, with roughly five-day lifecycle logic.
- `QM5_12804_xng-tsmom12m-atr` uses a 12-month return sign and ATR corridor.
- `QM5_20013_xng-2m-contr` is a two-month contrarian return-sign package.
- Daily Donchian and event-window XNG cards use daily extrema or fixed event
  calendars rather than completed month-end closes and one-month renewal.

The selected rule is monthly, symmetric trend continuation and price-only. Its
different signal horizon and payoff direction make it a valid new XNG edge for
testing, but realized book correlation remains an empirical later-phase gate.

## Safety boundary

The source authorizes research and a `RISK_FIXED` backtest carrier only. It
does not authorize live deployment, a live setfile, AutoTrading, `T_Live`, a
deploy manifest, the T_Live manifest, portfolio admission or portfolio-gate
changes.
