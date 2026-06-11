---
ea_id: QM5_11555
slug: carter-t-m5-wma5-sma11-psar-adx14
type: strategy
source_id: 42530cb3-0265-534a-89cc-150f80733ff5
sources:
  - "[[sources/carter-thomas-20-forex-strategies-5min]]"
concepts:
  - "[[concepts/wma-sma-cross-trend]]"
  - "[[concepts/parabolic-sar-entry]]"
  - "[[concepts/adx-directional-filter]]"
indicators:
  - WMA(5)
  - SMA(11)
  - ParabolicSAR(0.01,0.1)
  - ADX(14)
period: M5
source_citation: "Thomas Carter, '20 Forex Trading Strategies (5 Minute Time Frame)', self-published 2014 (System #16). R1 CONDITIONAL."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 250
g0_approval_reasoning: "R1 PASS single source_id; R2 PASS deterministic M5 WMA/SMA/PSAR/ADX entry and PSAR/swing exit, cadence 250/yr plausible for M5 trend state rules; R3 PASS DWX M5 forex testable; R4 PASS no ML/adaptive/martingale."
---

# QM5_11555 Carter-T M5 — WMA(5) + SMA(11) + PSAR + ADX(14) Directional (M5)

## Quelle
- Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #16, self-published 2014, local archive URL/source note.

## Mechanik

**Concept**: WMA(5) > SMA(11) defines trend. Parabolic SAR below price confirms uptrend momentum. ADX +DI > -DI confirms directional bias. Exit when PSAR flips to opposite signal.

**PSAR parameter note**: Source lists (0.1, 0.01) — step=0.1 > max=0.01 is physically invalid. Likely intended as (0.01, 0.1): step=0.01 (slow PSAR) or (0.1, 0.2) (fast). P2 tests with (0.01, 0.1); P3 sweeps include (0.02, 0.2) and (0.1, 0.2).

### Entry
**LONG**: `iMA(M5,5,WMA,1) > iMA(M5,11,SMA,1)` AND `iSAR(M5,0.01,0.1,1) < iLow[1]` AND `iADX(M5,14,PLUSDI,1) > iADX(M5,14,MINUSDI,1)`
**SHORT**: WMA < SMA AND PSAR above price AND ADX -DI > +DI

### Exit
- **Indicator exit**: PSAR flips (PSAR previously below, now above price)
- **SL**: previous swing low (iLowest 5 bars) capped at 25 pips

### Stop Loss
- `iLowest(M5,MODE_LOW,5,1)` capped at 25 pips

### Position Sizing
- `RISK_FIXED = $1000` for P2. `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: M5; Instruments: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDCHF.DWX; Spread cap: 5p; No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Self-published. |
| R2 Mechanical | PASS | WMA(5): iMA(MODE_LINEAR_WEIGHTED). SMA(11): iMA(MODE_SMA). PSAR: iSAR. ADX: iADX. All MT5-native. |
| R3 Data Available | PASS | M5 DWX. |
| R4 No ML | PASS | Threshold only. |

## Pipeline-Verlauf
- G0: 2026-05-23 — from Carter M5 book, System #16

## Implementation Notes for Codex (P1)
- `double wma5 = iMA(NULL,PERIOD_M5,5,0,MODE_LINEAR_WEIGHTED,PRICE_CLOSE,1)`
- `double sma11 = iMA(NULL,PERIOD_M5,11,0,MODE_SMA,PRICE_CLOSE,1)`
- `double sar = iSAR(NULL,PERIOD_M5,0.01,0.1,1)` (P2 default: step=0.01, max=0.1)
- `double plusdi = iADX(NULL,PERIOD_M5,14,PRICE_CLOSE,MODE_PLUSDI,1)`
- `double minusdi = iADX(NULL,PERIOD_M5,14,PRICE_CLOSE,MODE_MINUSDI,1)`
- Exit: `sar_cur > iLow[0]` where previously sar < iLow
- P3 sweeps: PSAR (0.01,0.1) vs (0.02,0.2) vs (0.1,0.2), SL lookback (3/5/8 bars)

## Verwandte Strategien
- Related: QM5_11544 (carter-t-h1-psar02-adx50) — PSAR+ADX H1
- Related: QM5_11535 (carter-t-h1-psar01-ema5-12-34) — PSAR+EMA H1

## Lessons Learned
- *(populated as pipeline progresses)*
