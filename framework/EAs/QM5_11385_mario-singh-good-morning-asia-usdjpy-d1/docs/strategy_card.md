---
ea_id: QM5_11385
slug: mario-singh-good-morning-asia-usdjpy-d1
type: strategy
source_id: 3c141158-8aca-5961-8e09-afd081ef32ee
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/momentum-continuation]]"
  - "[[concepts/session-momentum]]"
  - "[[concepts/price-action]]"
indicators:
  - "[[indicators/price-action]]"
  - "[[indicators/time-filter]]"
period: D1
source_citation: "Mario Singh, 17 Proven Currency Trading Strategies (Wiley, 2013), Strategy 17: Good Morning Asia, pp.228-233"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_scale: D1
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 250
g0_approval_reasoning: "R1 PASS single source_id/Wiley book attribution; R2 PASS deterministic previous D1 candle direction entry/SL/TP with plausible daily ~250 trades/year on USDJPY; R3 PASS USDJPY.DWX; R4 PASS deterministic no ML/HR14 issues."
---

# QM5_11385 Mario Singh Good Morning Asia — USD/JPY D1 Prev-Candle Direction Momentum (D1)

## Quelle
- Source: "17 Proven Currency Trading Strategies" by Mario Singh, John Wiley & Sons, 2013, Strategy 17: "Good Morning Asia", pp. 228-233
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\17 Proven Currency Trading Strategies-pages-250-255.pdf`
- Author: Mario Singh (Director of Training, First Prudential Markets, Singapore; CNBC contributor). R1 PASS.

## Mechanik

Pure price action on D1. If previous daily candle is BULLISH (Close > Open), enter LONG at open of next daily candle. If bearish, enter SHORT. SL = previous candle Low (LONG) / High (SHORT), minimum 30 pips. TP = half of SL distance (2:1 risk-to-reward with 50% win rate = breakeven, so needs >50% win rate). Enter at 5:00 PM New York time (Darwinex server: same as start of new daily candle).

### Entry

**LONG**:
1. Previous D1 candle is a **bull candle**: Close > Open.
2. Enter BUY at open of next D1 candle (5:00 PM NY time / server candle open).

**SHORT**:
1. Previous D1 candle is a **bear candle**: Close < Open.
2. Enter SELL at open of next D1 candle.

### Exit
- TP: half the SL distance from entry.
  - If SL = entry - prev_low: TP = entry + (entry - prev_low) / 2
  - Minimum SL = 30 pips (if prev candle range smaller, extend SL to 30 pips)
- SL: previous candle Low (LONG) / High (SHORT). If < 30 pips from entry, use 30 pips.

### Stop Loss
- LONG: previous candle Low. Minimum 30 pips from entry.
- SHORT: previous candle High. Minimum 30 pips from entry.
- P2 cap: 80 pips max (D1 candles can have large range; source allows up to 80+ pip SL).

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.
- Note: 2:1 risk-to-reward (TP = 0.5 × SL) means high win rate required. Source claims suitable for USD/JPY daily momentum.

### Zusaetzliche Filter
- Timeframe: D1
- Instrument: USDJPY.DWX only (per author's rationale: US+Japan largest economies, highest JPY liquidity)
- Entry time: new daily candle open (00:00 server time on Darwinex = 5:00 PM NY equivalent)
- Skip if previous candle is a Doji (Close == Open ± 3 pips) — no clear direction
- News filter: skip on major US/JP news days (optional for P2)

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Mario Singh — named professional (Director of Training FPM, published Wiley 2013, CNBC contributor). |
| R2 Mechanical | PASS | Previous candle bullish/bearish + SL at prev Low/High + TP = SL/2 — all deterministic from D1 OHLC data. |
| R3 Data Available | PASS | D1 USDJPY.DWX available from 2017+. |
| R4 No ML | PASS | Pure price action, no indicators. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 -- drafted from Mario Singh "17 Proven Currency Trading Strategies" pp. 228-233

## Implementation Notes for Codex (P1)
- D1 candle open = server time 00:00 (Darwinex NY-close candles open at 00:00 server)
- `prev_bull = (iClose(NULL,PERIOD_D1,1) > iOpen(NULL,PERIOD_D1,1))`
- `prev_low = iLow(NULL,PERIOD_D1,1)`; `prev_high = iHigh(NULL,PERIOD_D1,1)`
- Entry LONG: enter at open of current D1 candle (bar[0] open) when `prev_bull == true`
- SL_distance_long = max(entry_price - prev_low, 30 pips)
- TP_long = entry_price + SL_distance_long / 2.0
- SL_long = entry_price - SL_distance_long
- Doji filter: skip if `Abs(prev_close - prev_open) < 3 pips`
- P3 sweeps: TP ratio (0.5x vs 0.75x vs 1.0x SL), Doji filter threshold (2 vs 5 pips), additional USD/JPY pairs (EURUSD, GBPUSD -- source says USDJPY only)

## Verwandte Strategien
- Related: QM5_11373 (100pips-daily-range-bracket-usdjpy) -- both target USDJPY with daily-level entries
- Differentiator: Previous candle direction (momentum continuation) vs. prior 24h H/L range bracket

## Lessons Learned
- *(populated as pipeline progresses)*