---
ea_id: QM5_10311
slug: hf-momo-buffer
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/inventory-risk]]"
  - "[[concepts/high-frequency-trading]]"
indicators:
  - "[[indicators/short-horizon-return]]"
  - "[[indicators/bid-ask-spread]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
expected_trades_per_year_per_symbol: 250
g0_approval_reasoning: "R1 SSRN/Mathematical Finance source linked; R2 deterministic M1 momentum/spread-buffer entries with ATR/time exits and ~250 trades/year/symbol; R3 testable on DWX M1 OHLC/spread/tick-volume symbols; R4 fixed-parameter no-ML one-position."
---

# High-Frequency Momentum Buffer

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://ssrn.com/abstract=2010417
- Paper: "Risk Metrics and Fine Tuning of High Frequency Trading Strategies", Alvaro Cartea and Sebastian Jaimungal, Mathematical Finance, 2013.
- Page / Timestamp: SSRN abstract and citation page. The abstract describes high-frequency strategies that earn realized spread, manage inventory risk, incorporate a buffer for adverse selection costs, and exploit market momentum from price-impact jumps.

## Mechanik

### Entry
On M1 bars for a liquid DWX symbol:
- Compute short-horizon return `mom = close[0] / close[5] - 1`.
- Compute volatility-normalized momentum `mom_z = mom / ATR(14, M1)`.
- Compute live spread in points.
- Long entry: `mom_z >= +0.75` and expected move to the 10-bar momentum target exceeds `2.0 * current_spread`.
- Short entry: `mom_z <= -0.75` and expected move to the 10-bar momentum target exceeds `2.0 * current_spread`.
- Adverse-selection buffer: do not enter if current spread is above its rolling 80th percentile or if the last M1 bar is a large opposite wick.
- One position per magic number; no inventory stacking.

### Exit
- Exit at 10 M1 bars after entry.
- Exit earlier when 5-bar momentum flips sign.
- Take profit at `1.0 * ATR(14, M1)` from entry if reached before time exit.

### Stop Loss
- Stop at `0.75 * ATR(14, M1)` from entry.
- Daily kill switch after 3 stopped trades per symbol.

### Position Sizing
Fixed $1,000 P2 risk equivalent using stop distance. Live sizing deferred to V5 risk defaults after pipeline validation.

### Zusätzliche Filter
- Trade only during liquid sessions for the selected symbol.
- Skip high-impact scheduled news windows.
- Skip if M1 bar volume/tick count is below the rolling 20th percentile.

## Concepts (was ist das für eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/inventory-risk]] - secondary
- [[concepts/high-frequency-trading]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named SSRN/Mathematical Finance paper with author and DOI/SSRN links. |
| R2 Mechanical | PASS | Momentum entry, spread buffer, fixed time/ATR exits, and hard inventory cap are deterministic. |
| R3 Data Available | PASS | Uses M1 OHLC, spread, ATR, and tick volume available in the MT5/DWX stack. |
| R4 ML Forbidden | PASS | Fixed thresholds; no ML, no adaptive online parameters, no grid/martingale. |

## R3
Candidate DWX symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`. Avoid illiquid symbols until Q03 sweep proves spread robustness.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN microstructure/HFT batch 1.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10312_obi-thin-taker]] - order-flow / imbalance cousin strategy.

## Lessons Learned (während Pipeline-Lauf)
- TBD

