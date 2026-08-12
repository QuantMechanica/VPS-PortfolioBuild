---
source_id: SZAKMARY-WTI-MCH3-2010
title: Szakmary monthly commodity channel rule - WTI three-month extraction
publisher: Journal of Banking and Finance / author-uploaded working paper
source_type: peer_reviewed_paper_with_author_manuscript
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-19
primary_url: https://doi.org/10.1016/j.jbankfin.2009.08.004
open_manuscript_url: https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf
strategy_ids:
  - SZAKMARY-WTI-MCH3-2010
---

# Szakmary WTI Monthly Three-Month Channel Source

## Primary source lineage

Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010), "Trend-following
trading strategies in commodity futures: A re-examination", *Journal of
Banking & Finance*, 34(2), 409-426, DOI
https://doi.org/10.1016/j.jbankfin.2009.08.004.

The final peer-reviewed article studies monthly trend rules over 48 years and
28 commodity-futures markets. The full author-uploaded predecessor manuscript,
"Price Momentum and Trading Volume in Commodity Futures Markets", supplies the
complete mechanical rule and was read in full. Section III defines the channel
family as follows:

- sample the unit-value series at each calendar month end;
- go long for the following month when the latest month-end value exceeds the
  maximum of the previous `L` month-end values;
- go short when the latest value is below the previous `L`-month minimum;
- remain flat when it lies between those extrema;
- use one-month holding periods; and
- test `L` equal to 3, 6, 9 and 12 months without optimization.

The card selects the source-tested `L=3` rule. The article reports broad
commodity evidence, not a guaranteed WTI or CFD result. No historical source
performance number is imported into the approval decision.

## Mechanization boundary

The V5 carrier evaluates `XTIUSD.DWX` on the first D1 bar of a new broker
calendar month. It reconstructs four distinct completed month-end closes from
D1 history because `.DWX` MN1 bars are not guaranteed in the tester:

- `C0`: the just-completed month-end close;
- `C1..C3`: the three preceding month-end closes;
- long when `C0 > max(C1,C2,C3)`;
- short when `C0 < min(C1,C2,C3)`; and
- flat otherwise.

Any prior package is closed at the monthly boundary before the new one-month
package is considered, including when the direction repeats. A frozen D1 ATR
hard stop and a 35-day stale guard are V5 risk-contract additions. Runtime
uses only MT5 OHLC, ATR, spread, broker calendar, deal history and framework
state. It does not read a futures curve, contract-roll file, inventory, volume,
open interest, CSV, API, analyst input or news forecast.

The source used rolled nearby futures unit values. `XTIUSD.DWX` is a continuous
Darwinex CFD proxy, so roll and basis equivalence are explicitly unproven and
must be falsified by Q02 and later gates.

## Data and cadence precheck

A read-only parse of the local T1 `XTIUSD.DWX` D1 history cache (2017-10-02 to
2025-12-31) found 65 non-flat `L=3` month-end signals after warm-up, or 8.21
signals per year. Per-year counts for 2018-2025 were 7, 7, 10, 9, 8, 10, 7 and
7. This is a cadence check only, not a backtest or profitability claim. It
clears the effective Q02 low-frequency floor of five trades per year without
starting an MT5 tester.

## Reputable-source criteria

- R1: PASS. One source lineage is used: a peer-reviewed Journal of Banking &
  Finance article with a DOI and its full author-uploaded predecessor.
- R2: PASS. The latest completed month-end close, prior-three-close extrema,
  one-month hold, flat state and monthly renewal are deterministic.
- R3: PASS. `XTIUSD.DWX` is present in
  `framework/registry/dwx_symbol_matrix.csv`, and its D1 history supports the
  required cadence.
- R4: PASS. No ML, adaptive parameter, banned indicator, grid, martingale,
  pyramiding or external runtime feed is used; one position per magic is
  enforced.

## Non-duplicate boundary

Repository-wide exact-phrase and mechanic searches found no XTI rule comparing
one completed month-end close with the extrema of the prior three completed
month-end closes. The nearest builds are materially different:

- `QM5_13100_wti-dmac16`: latest month end versus a six-month arithmetic mean
  with a 2.5% neutral band; matching states can be held across months.
- `QM5_1226_psaradellis-oil-channel`: D1 55-bar high/low entry and 20-bar exit.
- `QM5_12844_commodity-trend-crude`: D1 Donchian-20 with ADX and ATR trailing.
- `QM5_12780_wti-52w-anchor`: monthly 252-D1 extreme proximity plus a 63-D1
  return confirmation.
- `QM5_12810_wti-month-orb`: breakout of the first five D1 bars of a month.
- `QM5_12616_tsmom-9m-commodity-xtiusd`: 3/9-month cumulative-return agreement.

This extraction is a monthly close-only, source-defined one-month package. It
does not rename a daily Donchian, moving-average, return-sign, event, calendar,
ratio, RSI or relative-value rule.

## Safety boundary

The source authorizes research and a RISK_FIXED backtest carrier only. It does
not authorize live deployment, a live setfile, AutoTrading, `T_Live`, a deploy
manifest, the T_Live manifest, portfolio admission or portfolio-gate changes.
