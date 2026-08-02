---
ea_id: QM5_11514
slug: carter-t-macd3916-adx16-d1
type: strategy
source_id: 8794b680-f6f4-5142-b12c-e5e0057e7bcf
sources:
  - "[[sources/carter-thomas-20-forex-trend-following-systems]]"
concepts:
  - "[[concepts/macd-signal-cross]]"
  - "[[concepts/adx-directional-filter]]"
  - "[[concepts/daily-bar-pattern]]"
indicators:
  - MACD(3,9,16)
  - ADX(16)
period: D1
source_citation: "Thomas Carter, 'Forex Trend Following Strategies: 20 Trend Following Systems', self-published 2014 (System #9). R1 CONDITIONAL — named individual, self-published ebook."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Thomas Carter self-published ebook is a valid source per R1 (author track record not required).
r2_mechanical: PASS
r2_reasoning: Non-standard MACD(3,9,16) signal cross and ADX(16) +DI/-DI directional check are fully mechanical MT5-native iMACD/iADX calls.
r3_data_available: PASS
r3_reasoning: Targets EURUSD.DWX and GBPUSD.DWX — live-tradable DWX FX instruments with D1 history available.
r4_ml_forbidden: PASS
r4_reasoning: Indicator threshold comparisons only; no ML, no adaptive PnL parameters, one position per magic.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 40
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 PASS single source_id Carter ebook; R2 PASS mechanical D1 MACD cross + ADX direction with fixed SL/TP and plausible >2 trades/year/symbol; R3 PASS DWX FX D1; R4 PASS deterministic no ML 1-pos compatible."
---

# QM5_11514 Carter-T — MACD(3,9,16) + ADX(16) Directional (D1)

## Quelle
- Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #9, self-published 2014.
- Source URL/record: [[sources/carter-thomas-20-forex-trend-following-systems]]
- R1: CONDITIONAL — named author, self-published ebook.

## Mechanik

**Concept**: Non-standard MACD(3,9,16) — very short EMA(3) and EMA(9) with a 16-bar signal line. This produces a faster MACD than standard (12,26,9). ADX(16) +DI > -DI provides directional confirmation. MACD signal cross AND +DI > -DI required together. TP: 2×SL.

**Logic**: The short MACD periods (3,9) on D1 make this responsive to multi-day trend shifts. The 16-bar signal line is longer than standard (9), smoothing out the signal line and reducing noise. ADX(16) +DI/-DI provides a separate directional confirmation. Together: fast MACD catches the turn, ADX confirms the direction has strength.

**Note**: Source specifies EUR/USD and GBP/USD.

### Entry

**LONG:**
1. **MACD buy signal**: MACD(3,9,16) main line crossed above signal line: `iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_MAIN,1) > iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_SIGNAL,1)` AND crossed in bar[1] or bar[2]
2. **ADX directional**: `iADX(NULL,PERIOD_D1,16,PRICE_CLOSE,MODE_PLUSDI,1) > iADX(NULL,PERIOD_D1,16,PRICE_CLOSE,MODE_MINUSDI,1)`
3. Enter BUY at open of next bar

**SHORT:**
1. MACD main crosses below signal line (sell signal)
2. ADX -DI > +DI
3. Enter SELL at next D1 bar open

### Exit
- **TP**: 2×SL distance (source-specified 2:1 R/R)
- **SL**: Source unspecified exact value. QM P2: 100 pips fixed (D1). Test variants.
- `TP_long = entry + 2*100*pip = entry + 200*pip`

### Stop Loss
- `SL_long = entry - 100*pip`
- `SL_short = entry + 100*pip`
- P2 cap: 100 pips

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX (source-specified), GBPUSD.DWX (source-specified)
- Spread cap: 30 pips
- No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Thomas Carter, self-published ebook. No verifiable credentials. |
| R2 Mechanical | PASS | MACD(3,9,16): iMACD with non-standard periods (valid MT5-native). ADX(16): iADX. All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. MT5-native. |
| R4 No ML | PASS | Threshold comparisons only. No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. Non-standard MACD(3,9,16) periods are still valid iMACD parameters in MT5. The fast MACD + ADX directional combination is mechanically clean. SL magnitude is the main uncertainty — P2 must tune.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Thomas Carter, "Forex Trend Following Strategies", System #9, 2014

## Implementation Notes for Codex (P1)
- `double macd_main1 = iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_MAIN,1)`
- `double macd_sig1 = iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_SIGNAL,1)`
- `double macd_main2 = iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_MAIN,2)`
- `double macd_sig2 = iMACD(NULL,PERIOD_D1,3,9,16,PRICE_CLOSE,MODE_SIGNAL,2)`
- Cross: `macd_main1 > macd_sig1 && macd_main2 <= macd_sig2` (just crossed up)
- Directional: `iADX(NULL,PERIOD_D1,16,PRICE_CLOSE,MODE_PLUSDI,1) > iADX(NULL,PERIOD_D1,16,PRICE_CLOSE,MODE_MINUSDI,1)`
- SL: 100 pips; TP: 200 pips
- P3 sweeps: MACD periods (3,9,16 vs 5,12,9 vs 3,9,9), ADX period (14/16/20), SL (75/100/150 pips)

## Verwandte Strategien
- Related: QM5_11513 (carter-t-ema4-11-adx13-d1) — same source, EMA+ADX D1
- Related: QM5_11522 (carter-t-ema4-10-adx28-macd5104-h4) — same source, EMA+ADX+MACD H4
- Related: QM5_11487 (carter-t-50-100-ema-macd-breakout-m5) — Carter M5 book, MACD confirmation

## Lessons Learned
- *(populated as pipeline progresses)*
