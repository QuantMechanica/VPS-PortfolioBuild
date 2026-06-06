---
ea_id: QM5_10979
slug: ftmo-macd-div
type: strategy
source_id: c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
source_citation: "FTMO, Technical Analysis - Moving Average Convergence/Divergence, 2022-11-18, https://ftmo.com/en/blog/technical-analysis-moving-average-convergence-divergence/"
sources:
  - "[[sources/ftmo-blog]]"
concepts:
  - "[[concepts/divergence]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "MACD swing divergence on H4 is lower cadence than simple oscillator crosses; conservative estimate 8-20 trades/year/symbol."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 FTMO source URL cited; R2 deterministic MACD swing divergence entry with exits/stops and plausible 8-20 trades/year/symbol on H4; R3 DWX FX/metals testable; R4 fixed rules one-position no ML/grid/martingale."
---

# FTMO MACD Swing Divergence Reversal

## Quelle
- Source: [[sources/ftmo-blog]]
- Citation: FTMO, "Technical Analysis - Moving Average Convergence/Divergence", 2022-11-18, URL https://ftmo.com/en/blog/technical-analysis-moving-average-convergence-divergence/.
- Author / institution: FTMO.
- Source location: "Divergence" section; source describes lower price lows with higher MACD lows as bullish reversal evidence and higher price highs with lower MACD highs as bearish reversal evidence.

## Mechanik

### Entry
- Calculate MACD(12,26,9) on closed H4 bars.
- Define confirmed swing lows/highs using a 3-left / 3-right fractal rule.
- Long setup:
  - Price forms a lower confirmed swing low versus the prior confirmed swing low within the last 60 H4 bars.
  - MACD line at the newer swing low is higher than MACD line at the prior swing low.
  - MACD line crosses above the signal line within 5 H4 bars after the newer swing low.
  - Enter long at market on the confirmation close.
- Short setup:
  - Price forms a higher confirmed swing high versus the prior confirmed swing high within the last 60 H4 bars.
  - MACD line at the newer swing high is lower than MACD line at the prior swing high.
  - MACD line crosses below the signal line within 5 H4 bars after the newer swing high.
  - Enter short at market on the confirmation close.

### Exit
- Primary TP = 2.0R.
- Secondary TP = nearest opposite 20-bar swing level if reached before 2.0R.
- Exit long if MACD crosses back below the signal line.
- Exit short if MACD crosses back above the signal line.
- Time exit after 40 H4 bars.

### Stop Loss
- Long SL = newer divergence swing low - 0.5 * ATR(14,H4).
- Short SL = newer divergence swing high + 0.5 * ATR(14,H4).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip if the two swing points are fewer than 8 H4 bars apart.
- Skip if stop distance > 3.0 * ATR(14,H4).
- Skip high-impact news windows.

## Concepts
- [[concepts/divergence]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full FTMO URL, article title, date, and institution are cited. |
| R2 Mechanical | PASS | Swing detection, divergence, confirmation, stop, target, and time exit are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC-derived MACD and ATR on DWX FX/metals. |
| R4 No ML | PASS | Fixed indicator rules, one position, no ML/grid/martingale/adaptive logic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10955_ftmo-mr-div]] - also uses divergence; this card isolates MACD swing divergence without Bollinger/RSI requirements.

## Lessons Learned
- TBD during pipeline run.
