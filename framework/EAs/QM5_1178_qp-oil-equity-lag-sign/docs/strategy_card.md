---
ea_id: QM5_1178
slug: qp-oil-equity-lag-sign
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/market-timing]]"
  - "[[concepts/cross-asset-signal]]"
indicators:
  - "[[indicators/monthly-return]]"
  - "[[indicators/oil-signal]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "Quantpedia Driesprong-Jacobsen-Maat 2008 JFE 89(2) oil-predicts-equity monthly sign-rule; R1 PASS Quantpedia URL + Driesprong/Jacobsen/Maat 2008 JFE DOI 10.1016/j.jfineco.2007.07.008 + SSRN 460500; R2 PASS deterministic prev-month oil-return threshold + monthly rebalance + ATR/safety stops; R3 P"
---

# Quantpedia Oil-Lag Equity Timing Sign Rule

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Crude Oil Predicts Equity Returns"
- URL: quantpedia.com/strategies/crude-oil-predicts-equity-returns (Quantpedia 2024 summary accessed 2026)
- Named source authors: Driesprong, Jacobsen, and Maat 2008 "Striking Oil: Another Puzzle?", Journal of Financial Economics 89(2) DOI 10.1016/j.jfineco.2007.07.008 (SSRN 460500); Quantpedia summary page.
- Location: "Simple trading strategy" section; source says lagged monthly oil returns predict equity returns.

## Mechanik

### Entry
On the first tradable day of each month:
1. Compute the previous completed calendar month's return for `XTIUSD.DWX` if available, otherwise the approved oil signal CSV proxy.
2. If previous-month oil return is below `OilReturnThreshold`, open LONG `SP500.DWX`.
3. Default `OilReturnThreshold = 0.0`; P3 sweep may test -2%, 0%, +2%.
4. If previous-month oil return is above or equal to the threshold, stay flat.

### Exit
- Close at the next month-end.
- Re-enter/roll only if the next monthly oil signal remains bullish for equities.

### Stop Loss
- Initial stop: 2.5x ATR(20) on D1.
- Safety stop: close if SP500.DWX loses 10% from entry before scheduled exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- The source paper uses a monthly regression. This draft intentionally uses a fixed sign/threshold port of the documented negative oil-to-equity relation to avoid online re-estimation under R4.
- Oil signal data must be deterministic and checked in; no live web calls.
- No short equity leg in the default version; bearish oil signal means cash.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
