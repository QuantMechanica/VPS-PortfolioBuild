---
ea_id: QM5_11407
slug: carter-tf17-ema18-adx-pullback
type: strategy
source_id: 29c77a02-59bd-52f7-bcb3-b3108d5f1e79
sources:
  - "[[sources/thomas-carter-20-trend-following-systems-forex]]"
concepts:
  - "[[concepts/ema-pullback]]"
  - "[[concepts/adx-trend-strength]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/stop-order-entry]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
period: H4
source_citation: "Thomas Carter, 20 Trend Following Systems (2014), Strategy #17, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\514732392-Forex-Trend-Following-Strategy.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 40
g0_approval_reasoning: "R1 single source_id/local PDF; R2 mechanical EMA18/ADX pullback stop-order entry with swing/ATR exits, H4 cadence plausible >2 trades/year/symbol; R3 DWX forex H4 testable; R4 deterministic no ML."
---

# QM5_11407 Carter TF#17 — EMA18 + ADX Pullback (H4)

## Quelle
- Source: "20 Trend Following Systems" by Thomas Carter (2014), Strategy #17
- Source citation URL marker: local PDF lineage only.
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\514732392-Forex-Trend-Following-Strategy.pdf`
- R1: PASS — Named author.

## Mechanik

**Concept**: In a strong trend (ADX > 25), use EMA18 as the dynamic support/resistance for pullback entries. When price touches EMA18 during the pullback, AND ADX is still > 25 on that first touch bar (confirming trend strength persists during the correction), enter a stop order above/below the touch bar's high/low.

The ADX filter on the touch bar is the key differentiator: it confirms the market is not losing trend strength during the pullback.

### Entry

**LONG** (uptrend pullback to EMA18 with ADX filter):
1. Market is in uptrend (price generally above EMA18).
2. `ADX(12)[0] > 25` — trend strength confirmed before pullback begins.
3. Price declines and bar i touches EMA18: `iLow(i) <= iEMA18(i)`.
4. At bar i (the first touch): `ADX(12)[i] > 25` — ADX must still be > 25 on this bar.
5. Place BUYSTOP at `iHigh(i) + 1 pip`.
6. Once price breaks above that high, entry is triggered.

**SHORT** (downtrend rally to EMA18):
1. Market in downtrend (price below EMA18).
2. `ADX(12)[0] > 25`.
3. Bar i: price rallies to EMA18: `iHigh(i) >= iEMA18(i)`.
4. `ADX(12)[i] > 25` at touch bar.
5. SELLSTOP at `iLow(i) - 1 pip`.

### Exit
- TP: Last swing high/low (swing before the pullback started) — or use ATR(14) × 2.0.
- SL: Recent swing low for long (swing during the pullback) / high for short.
- BE: Move to breakeven at +1× ATR.

### Stop Loss
- LONG: Most recent swing low before the entry (prior to EMA18 touch).
- SHORT: Most recent swing high.
- P2 cap: 70 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H4 (original: "Any TF")
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX
- Spread cap: 20 pips
- ADX condition applies only to the first bar that touches EMA18; subsequent bars may have ADX < 25

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Thomas Carter, named author, published series. |
| R2 Mechanical | PASS | EMA18 comparison, ADX threshold on specific bar — all arithmetic. Stop order entry fully defined. |
| R3 Data Available | PASS | H4 DWX; EMA and ADX MT5-native. |
| R4 No ML | PASS | Fixed thresholds. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Thomas Carter, Strategy #17

## Implementation Notes for Codex (P1)
- `ema18 = iMA(NULL, PERIOD_H4, 18, 0, MODE_EMA, PRICE_CLOSE, i)`
- `adx = iADX(NULL, PERIOD_H4, 12, PRICE_CLOSE, MODE_MAIN, i)`
- Scan last 3 bars for first EMA touch: `for i=1..3: if iLow(NULL,0,i) <= ema18[i] && adx[i] > 25 → touch_bar = i`
- BUYSTOP: `iHigh(NULL, 0, touch_bar) + Point`
- P3 sweeps: EMA (14/18/21), ADX (12/14/20), ADX threshold (20/25/30)

## Verwandte Strategien
- Related: QM5_11406 (carter-tf16-ema7-21-pullback) — same pullback concept with two EMAs but no ADX filter
- Differentiator: Single EMA18 + ADX > 25 filter ensures trend strength is intact during the pullback. The ADX filter on the touch bar is a key addition not in QM5_11406.

## Lessons Learned
- *(populated as pipeline progresses)*
