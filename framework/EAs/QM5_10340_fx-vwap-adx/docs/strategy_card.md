---
ea_id: QM5_10340
slug: fx-vwap-adx
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
source_citation: "Amaanullah Bhatti, Momentum Exhaustion and Fair Value Reversion: An ADX-conditioned VWAP Strategy in FX Markets, SSRN abstract 6454659, 2026, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6454659"
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/vwap-reversion]]"
  - "[[concepts/momentum-exhaustion]]"
  - "[[concepts/session-extreme-fade]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX]
period: M15
expected_trade_frequency: "Prior-session extreme plus VWAP deviation and ADX rollover is selective; conservative estimate 80 trades/year/symbol."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN source URL and attribution; R2 PASS deterministic M15 VWAP/ADX exhaustion rules with exits/stops and 80 trades/year/symbol estimate; R3 PASS FX-native on DWX major pairs; R4 PASS fixed rules no ML/grid/martingale."
---

# FX VWAP ADX Exhaustion Reversion

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6454659
- Paper: Amaanullah Bhatti, "Momentum Exhaustion and Fair Value Reversion: An ADX-conditioned VWAP Strategy in FX Markets", SSRN, 2026.
- Source location: SSRN abstract. The abstract defines short signals at prior-session highs with large positive VWAP deviations and turning-over ADX, and long signals at prior-session lows with large negative VWAP deviations and turning-over ADX.

## Mechanik

### Entry
- Evaluate M15 closed bars during liquid FX sessions.
- Compute prior-session high and low from the previous broker day or configured FX session.
- Compute session VWAP proxy from typical price and tick volume since broker day open.
- Compute `vwap_dev_atr = (close - session_vwap) / ATR(14,M15)`.
- Compute ADX(14) and require ADX to be turning over: `ADX[1] > 25` and `ADX[0] < ADX[1]`.
- Short if price touches or exceeds prior-session high, `vwap_dev_atr >= +0.75`, and ADX is turning over.
- Long if price touches or falls below prior-session low, `vwap_dev_atr <= -0.75`, and ADX is turning over.
- Take only the first valid signal per symbol per session.

### Exit
- Exit at session VWAP touch.
- Exit after 6 M15 bars.
- Exit early if ADX rises above its entry value and price extends beyond the session extreme by another `0.50 * ATR(14,M15)`.

### Stop Loss
- Stop at `1.00 * ATR(14,M15)` beyond entry.
- Skip if stop distance is less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- No scaling in or averaging down.

### Zusaetzliche Filter
- Skip if current spread is above rolling 80th percentile.
- Skip high-impact news windows.
- Skip first 30 minutes after broker day/session open.

## Concepts
- [[concepts/vwap-reversion]] - primary
- [[concepts/momentum-exhaustion]] - primary
- [[concepts/session-extreme-fade]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | SSRN URL plus named author and institution. |
| R2 Mechanical | PASS | Prior-session extremes, VWAP deviation, ADX rollover, fixed exits, and ATR stops are deterministic. |
| R3 DWX-testbar | PASS | Source is FX-native and DWX has major FX pairs. |
| R4 No ML | PASS | Fixed technical-regime rules only; no ML, adaptive online parameters, grid, or martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`.

## Author Claims
- The source says the framework exploits intraday reversion toward a volume-weighted fair value benchmark under momentum exhaustion (SSRN abstract).
- The abstract states that the strategy generates short and long signals from prior-session extremes, VWAP deviations, and turning-over ADX.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10339_fx-zscore-mr]] - same broad FX mean-reversion family but z-score based.
- [[strategies/QM5_1205_bhatti-gold-vwap-ema]] - same author, gold continuation rather than FX exhaustion fade.

## Lessons Learned
- TBD during pipeline run.
