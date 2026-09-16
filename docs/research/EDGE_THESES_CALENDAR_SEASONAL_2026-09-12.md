# Edge Lab direction 3 — calendar and seasonal flow thesis bank

Task: `3941072e-a79c-42f3-8210-b3cbbe28f687`  
Status: PAPER SCREEN COMPLETE; two survive, one underpowered reserve; no MT5 run  
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

## Measurement contract

`tools/strategy_farm/research/calendar_seasonal_falsification.py` reads only the
existing `D:/QM/mt5/T_Export/MQL5/Files/*_M5.csv` exports. The available span is
2017-10-02..2025-12-31 for EURUSD, GBPUSD, USDJPY and XAUUSD. Statistics are
gross BID-to-BID signed returns: no spread, commission, stop, intrabar path or
multiple-testing correction. `IS` ends in 2022; `OOS` starts in 2023. A thesis
survives this cheap screen only when IS and OOS means have the hypothesised
sign, combined `n >= 20`, and combined `t >= 1.0`. That is permission to draft,
not evidence of a tradable edge and never a pipeline verdict.

Reproduce:

```powershell
python -X utf8 tools/strategy_farm/research/calendar_seasonal_falsification.py
```

Evidence: `docs/research/edge_lab/calendar_seasonal_falsification.csv` (39
summary rows from 8,736 event trials).

## Sources anchoring structural causes

- Melvin and Prins, *Equity hedging and exchange rates*: month-end hedgers
  concentrate orders around the London 16:00 fix and the paper reports
  subsequent reversion. ECB-hosted author manuscript:
  https://www.ecb.europa.eu/events/pdf/conferences/131216/Third_FX_Workshop_MELVIN_PRINS_Equity%20hedging%20and%20exchange%20rates%20Nov%202013.pdf
- Bank of England, *How fair and effective are the FICC markets?*: index
  tracking creates incentives to transact at WM/Reuters fixes:
  https://www.bankofengland.co.uk/-/media/boe/files/paper/2014/how-fair-and-effective-are-the-fixed-income-foreign-exchange-and-commodities-markets.pdf
- Refinitiv presentation to the ECB FX Contact Group: GBPUSD activity remains
  concentrated in the WM/R benchmark window:
  https://www.ecb.europa.eu/paym/groups/pdf/fxcg/2019/20191119/2_WMR_FX_spot_fixing_Refinitiv.pdf
- LBMA: the gold benchmark is set at 10:30 and 15:00 London time:
  https://www.lbma.org.uk/prices-and-data/about-lbma-daily-auction-prices
- CME: US index futures customarily roll on the Monday before the third Friday
  of quarterly expiry: https://www.cmegroup.com/trading/equity-index/rolldates.html
- EIA: the petroleum status report normally releases Wednesday 10:30 ET, with
  holiday exceptions: https://www.eia.gov/petroleum/supply/weekly/schedule.php

The sources establish recurring flow clocks, not profitability. Profitability
is the claim falsified below.

## Thesis bank

## Paper verdict and bank-disposition rule

The CSV keeps the mechanical screen’s raw rule: any thesis with combined
`n < 20` is `UNDERPOWERED`, so no thin sample can be `PAPER_SURVIVES`. The
thesis-bank disposition then records whether a thin sample remains a reserve:
a thin sample whose preregistered in-sample sign is already wrong is folded
into `PAPER_REFUTED` (CAL-05: `n=8`, IS mean `-25.03 bp`), while a thin sample
whose in-sample sign agrees remains `UNDERPOWERED RESERVE` pending the required
20 independent years (CAL-06: `n=8`, IS mean `+108.51 bp`; the three-point OOS
split is retained as a warning, not promoted evidence). This is a reporting
disposition over the CSV’s raw `UNDERPOWERED` label; the falsification script
and gate thresholds are unchanged.

The resulting thesis-bank tally is **PAPER_SURVIVES=2, UNDERPOWERED
RESERVE=1, PAPER_REFUTED=9, DATA GAP=3** (15 thesis IDs total), matching the
39 CSV summary rows and the three unavailable exports.

### CAL-01 — EURUSD month-turn foreign-currency rebound

- **Structural cause:** month-end international portfolio hedge rebalancing.
- **Price signature:** long EURUSD from final trading-day 16:00 UTC to next
  trading-day 16:00 UTC.
- **Persistence:** benchmark mandates recur even when speculators anticipate them.
- **Falsification:** IS or OOS signed mean <= 0, or combined t < 1.
- **Q08/Q11 risk:** crisis rebalancing can reverse sign; mandatory news blackout.
- **FTMO fit:** one-day swing, fixed risk, no averaging; target <=5% daily and
  <=10% total DD. **Result: REFUTED**, -4.83 bp, n=94, t=-0.96.

### CAL-02 — GBPUSD month-turn rebound

- **Structural cause:** the same benchmark hedge flow, tested independently in GBP.
- **Price signature:** long GBPUSD over the CAL-01 window.
- **Persistence:** repeated institutional benchmark matching.
- **Falsification:** same sealed paper rule as CAL-01.
- **Q08/Q11 risk:** UK/US releases and crisis flow; mandatory blackout.
- **FTMO fit:** one-day swing, single position, bounded fixed risk. **REFUTED**,
  -4.00 bp, n=95, t=-0.69.

### CAL-03 — USDJPY month-turn USD reversal

- **Structural cause:** dollar hedge demand around global asset rebalancing.
- **Price signature:** short USDJPY over final-to-first trading-day 16:00 UTC.
- **Persistence:** non-discretionary hedge clocks.
- **Falsification:** same sign/stability rule.
- **Q08/Q11 risk:** JPY safe-haven discontinuities; blackout all high impact news.
- **FTMO fit:** one-day swing and fixed risk. **REFUTED**, -0.46 bp, n=96;
  IS negative and OOS positive.

### CAL-04 — XAUUSD turn-of-month continuation

- **Structural cause:** benchmark allocation and commodity-fund subscription or
  redemption flows cluster at accounting month turn.
- **Price signature:** long XAUUSD from final trading-day 16:00 UTC to next
  trading-day 16:00 UTC.
- **Persistence:** calendar-constrained flows recur and cannot all move earlier.
- **Falsification:** either split mean <=0, n<20 or combined t<1.
- **Q08/Q11 risk:** USD liquidity crises and central-bank news; hard blackout and
  Q08 crisis slices remain binding.
- **FTMO fit:** one-day swing; one fixed-risk position; <=5% daily, <=10% total.
  **PAPER_SURVIVES**, +12.01 bp, n=98, t=1.17; IS +2.44, OOS +29.24 bp.

### CAL-05 — XAUUSD January first-week strength

- **Structural cause:** annual allocation reset and physical-season demand.
- **Source status:** **UNSOURCED for this thesis-specific mechanism**; the
  benchmark sources listed above do not establish January first-week XAUUSD
  performance or this exact flow claim.
- **Price signature:** long first through sixth trading-day open in January.
- **Persistence:** annual mandates and physical calendars recur.
- **Falsification:** require 20 independent years and same-sign holdout.
- **Q08/Q11 risk:** thin New-Year liquidity and scheduled releases; blackout.
- **FTMO fit:** multi-day swing, fixed risk. **PAPER_REFUTED (thin-sample
  directional failure; raw CSV label UNDERPOWERED)**, +10.49 bp, n=8; IS
  mean -25.03 bp and OOS mean +69.69 bp.

### CAL-06 — XAUUSD August first-week strength

- **Structural cause:** recurring late-summer allocation and physical demand.
- **Source status:** **UNSOURCED for this thesis-specific mechanism**; the
  benchmark sources listed above do not establish August first-week XAUUSD
  performance or this exact flow claim.
- **Price signature:** long first through sixth trading-day open in August.
- **Persistence:** calendar demand cannot be fully time-shifted.
- **Falsification:** 20 independent years plus same-sign holdout; current sample
  cannot decide.
- **Q08/Q11 risk:** summer illiquidity and payroll releases; blackout.
- **FTMO fit:** multi-day swing, fixed risk. **UNDERPOWERED RESERVE**, +57.55 bp,
  n=8, t=0.50.

### CAL-07 — EURUSD quarter-turn rebound

- **Structural cause:** regulatory and benchmark rebalancing is larger at quarter-end.
- **Price signature:** long EURUSD over the CAL-01 window only in Mar/Jun/Sep/Dec.
- **Persistence:** reporting dates are immovable.
- **Falsification:** same split-sign/t rule.
- **Q08/Q11 risk:** quarter-end funding stress; mandatory blackout.
- **FTMO fit:** one-day swing and fixed risk. **REFUTED**, -8.00 bp, n=29.

### CAL-08 — GBPUSD London-open continuation

- **Structural cause:** European price discovery absorbs overnight inventory.
- **Price signature:** sign 07:00-08:00 UTC; follow it 08:00-12:00 UTC.
- **Persistence:** geographic hand-off recurs each trading day.
- **Falsification:** split sign failure or combined t<1.
- **Q08/Q11 risk:** DST and UK/US releases; use a DST-aware session clock and blackout.
- **FTMO fit:** four-hour swing, fixed risk. **REFUTED/NEAR MISS**, +0.43 bp,
  n=2,098, t=0.76; below friction before costs.

### CAL-09 — USDJPY Tokyo impulse fade

- **Structural cause:** opening inventory imbalances are supplied after the first hour.
- **Source status:** **UNSOURCED for the specific dealer-inventory-transfer
  mechanism**; this paper screen supplies the price evidence, not an
  independent structural citation.
- **Price signature:** fade the 00:00-01:00 UTC direction from 01:00 to 03:00 UTC.
- **Persistence:** daily dealer inventory transfer; compensation is small and capacity-limited.
- **Falsification:** either split mean <=0, combined n<20 or t<1.
- **Q08/Q11 risk:** BoJ intervention/regime shifts and Asian releases; mandatory blackout.
- **FTMO fit:** two-hour scalping horizon (not HFT), one fixed-risk position.
  **PAPER_SURVIVES**, +0.57 bp, n=1,563, t=1.70; IS +0.40, OOS +0.85 bp.

### CAL-10 — EURUSD WM/R fix fade

- **Structural cause:** benchmark orders temporarily move price into the 16:00 London fix.
- **Price signature:** fade 15:00-16:00 UTC direction during 16:00-17:00 UTC.
- **Persistence:** passive benchmark users accept impact to reduce tracking error.
- **Falsification:** split/t rule and net-of-cost expectancy <=0.
- **Q08/Q11 risk:** DST makes a fixed UTC clock imperfect; blackout and London-local clock required.
- **FTMO fit:** one-hour scalp, fixed risk. **REFUTED**, +0.25 bp, t=0.84 and
  below plausible friction.

### CAL-11 — XAUUSD afternoon benchmark fade

- **Structural cause:** inventory accumulated into the 15:00 London gold auction is unwound.
- **Price signature:** fade 14:00-15:00 UTC direction during 15:00-16:00 UTC.
- **Persistence:** benchmark demand recurs.
- **Falsification:** split sign and net-cost tests.
- **Q08/Q11 risk:** DST mismatch, US news and auction shocks; blackout.
- **FTMO fit:** one-hour scalp, fixed risk. **REFUTED**, +0.20 bp, t=0.29;
  OOS mean is negative.

### CAL-12 — EURUSD Friday inventory fade

- **Structural cause:** dealers and leveraged accounts reduce weekly inventory.
- **Source status:** **UNSOURCED for this thesis-specific Friday inventory
  reduction mechanism**; no independent source is claimed by this paper
  screen.
- **Price signature:** fade 12:00-16:00 direction during 16:00-20:00 UTC Fridays.
- **Persistence:** weekend risk limits recur.
- **Falsification:** split/t rule and costs.
- **Q08/Q11 risk:** Friday US data; mandatory blackout.
- **FTMO fit:** same-day four-hour position, fixed risk. **REFUTED/NEAR MISS**,
  +0.65 bp, n=422, t=0.52.

### CAL-13 — NDX quarterly roll continuation

- **Structural cause:** CME quarterly roll and expiry transfer index exposure.
- **Price signature:** follow Monday-before-third-Friday NDX move for one session.
- **Persistence:** dated contract migration is structural.
- **Falsification:** expiry return must beat matched non-expiry Mondays in IS and OOS.
- **Q08/Q11 risk:** triple-witching volatility and macro news; blackout.
- **FTMO fit:** one-day swing. **DATA GAP:** no `NDX.DWX_M5.csv` export.

### CAL-14 — SP500 quarterly-expiry opening reversal

- **Structural cause:** the Special Opening Quotation concentrates expiry imbalances.
- **Price signature:** fade the expiry opening impulse after the blackout-safe delay.
- **Persistence:** cash settlement recurs on the third Friday.
- **Falsification:** compare to matched non-expiry Fridays, same local-time window.
- **Q08/Q11 risk:** high gap/tail risk; hard DD cap and news blackout.
- **FTMO fit:** intraday scalp, no overnight hold. **DATA GAP:** no SP500 M5 export.

### CAL-15 — XTIUSD post-EIA delayed drift

- **Structural cause:** weekly inventory information is absorbed through physical hedging.
- **Price signature:** after the full news blackout expires, follow the first post-release hour.
- **Persistence:** physical inventory adjustment is slower than the release spike.
- **Falsification:** compare scheduled Wednesdays to non-release controls, honoring holiday dates.
- **Q08/Q11 risk:** this is explicitly news-adjacent; no entry/exit inside the restricted window.
- **FTMO fit:** hours-only scalp and fixed risk. **DATA GAP:** no XTIUSD M5 export.

## Ranked mechanization shortlist

1. **CAL-04 / gold turn-of-month:** only swing thesis with a positive IS and OOS
   mean and the sealed paper-survival threshold. Mechanize 24-hour, 12-hour and
   volatility-normalised same-family variants; do not tune calendar dates.
2. **CAL-09 / Tokyo impulse fade:** strongest t statistic and large sample, but
   its +0.57 bp gross edge is cost-fragile. First gate is realistic spread and
   DST/session handling; a net-negative Q02 kills the family.
3. **CAL-06 / gold August first week:** research reserve, not claimed edge. The
   magnitude is interesting but eight independent events are inadequate. Its
   draft exists to specify the exact extension test; obtain longer history before build.

All drafts stay in `cards_review`. None is approved, allocated an EA identity,
or entitled to a build. Variants remain mechanical; no ML, grid, martingale,
averaging into losers, HFT, or news-window trading.

RESULT task=3941072e verdict=PAPER_SCREEN_COMPLETE survivors=2 reserve=1 refuted=9 data_gaps=3 mt5_runs=0 cards_review=3
