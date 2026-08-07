---
ea_id: QM5_11513
slug: carter-t-ema4-11-adx13-d1
type: strategy
source_id: 8794b680-f6f4-5142-b12c-e5e0057e7bcf
sources:
  - "[[sources/carter-thomas-20-forex-trend-following-systems]]"
concepts:
  - "[[concepts/ema-cross-entry]]"
  - "[[concepts/adx-trend-strength-filter]]"
  - "[[concepts/daily-bar-pattern]]"
indicators:
  - EMA(4)
  - EMA(11)
  - ADX(13)
period: D1
source_citation: "Thomas Carter, 'Forex Trend Following Strategies: 20 Trend Following Systems', self-published 2014 (System #8). R1 CONDITIONAL — named individual, self-published ebook."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Thomas Carter self-published ebook is a valid source per R1 (author track record not required).
r2_mechanical: PASS
r2_reasoning: EMA(4/11) cross, ADX(13) strength and +DI/-DI checks, EMA reversal exit — all deterministic MT5-native iMA/iADX calls.
r3_data_available: PASS
r3_reasoning: Targets EURUSD.DWX and GBPUSD.DWX — live-tradable DWX FX instruments with D1 history available.
r4_ml_forbidden: PASS
r4_reasoning: Indicator threshold comparisons only; no ML, no adaptive PnL parameters, one position per magic.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 35
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 PASS single source_id Carter ebook; R2 PASS mechanical D1 EMA cross + ADX entry/EMA reversal exit with plausible multi-year FX cadence >2 trades/year/symbol; R3 PASS DWX FX D1; R4 PASS deterministic no ML 1-pos compatible."
---

# QM5_11513 Carter-T — EMA(4/11) + ADX(13) Trend Strength (D1)

## Quelle
- Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #8, self-published 2014.
- Source URL/record: [[sources/carter-thomas-20-forex-trend-following-systems]]
- R1: CONDITIONAL — named author, self-published ebook.

## Mechanik

**Concept**: EMA(4) crosses EMA(11) on D1 (fast cross signal). ADX(13) +DI > -DI AND ADX > 22 confirms the trend has sufficient strength. Exit when EMAs reverse — holding until a counter-signal rather than using fixed TP.

**Logic**: ADX > 22 means the trend is trending (not ranging). +DI > -DI directionally confirms the trend is bullish (buyers stronger than sellers). The EMA(4/11) cross is the entry trigger within a confirmed trending market. ADX(13) is a short-period ADX — responsive to emerging trends.

**Note**: Source specifies EUR/USD. QM expands to GBP/USD as well.

### Entry

**LONG:**
1. **EMA cross**: `iMA(NULL,PERIOD_D1,4,...,1) > iMA(NULL,PERIOD_D1,11,...,1)` AND crossed in bar[1]
2. **ADX +DI > -DI**: `iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_PLUSDI,1) > iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_MINUSDI,1)`
3. **ADX trend strength**: `iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_MAIN,1) > 22`
4. Enter BUY at open of next bar

**SHORT:**
1. EMA(4) crosses below EMA(11)
2. ADX -DI > +DI AND ADX > 22
3. Enter SELL at next D1 bar open

### Exit
- **Exit**: EMA(4) crosses EMA(11) in opposite direction (indicator-driven exit, no fixed TP)
- **SL**: QM-added fallback: 100 pips fixed (D1 wide stop to allow trend to breathe)
- P2 will test fixed TP variants (200/300 pips) vs indicator-driven exit

### Stop Loss
- `SL_long = entry - 100*pip` (QM-added fallback; source uses EMA cross exit)
- `SL_short = entry + 100*pip`
- P2 cap: 100 pips

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX (source-specified), GBPUSD.DWX (QM expansion)
- Spread cap: 30 pips
- No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Thomas Carter, self-published ebook. No verifiable credentials. |
| R2 Mechanical | PASS | EMA(4/11): iMA. ADX(13): iADX(MODE_MAIN/PLUSDI/MINUSDI). All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. MT5-native. |
| R4 No ML | PASS | Threshold comparisons only. No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. ADX > 22 filter is a well-established trend-strength gate. EMA(4/11) is responsive on D1. Indicator-driven exit means variable hold periods — P2 must test both exit modes.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Thomas Carter, "Forex Trend Following Strategies", System #8, 2014

## Implementation Notes for Codex (P1)
- `double ema4_1 = iMA(NULL,PERIOD_D1,4,0,MODE_EMA,PRICE_CLOSE,1)`
- `double ema11_1 = iMA(NULL,PERIOD_D1,11,0,MODE_EMA,PRICE_CLOSE,1)`
- `double adx = iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_MAIN,1)`
- `double plusdi = iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_PLUSDI,1)`
- `double minusdi = iADX(NULL,PERIOD_D1,13,PRICE_CLOSE,MODE_MINUSDI,1)`
- LONG: cross up on bar[1] AND plusdi > minusdi AND adx > 22
- Exit: EMA cross reversal check each bar; SL fallback 100 pips
- P3 sweeps: ADX threshold (18/22/25), EMA periods (4/11 vs 5/10 vs 8/21), TP (100/200/300 pips vs indicator exit)

## Verwandte Strategien
- Related: QM5_11514 (carter-t-macd3916-adx16-d1) — same source, D1 MACD+ADX
- Related: QM5_11515 (carter-t-adx14-prev-day-range-h1) — same source, ADX filter H1
- Related: QM5_11522 (carter-t-ema4-10-adx28-macd5104-h4) — same source, EMA+ADX on H4

## Lessons Learned
- *(populated as pipeline progresses)*
