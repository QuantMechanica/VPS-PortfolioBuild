---
ea_id: QM5_11739
slug: rfs-alligator-sma144-m15
type: strategy
source_id: b5a932a2-40b6-5628-840b-d5069ac35c4a
sources:
  - "[[sources/rfs-robo-forex-strategy-compilation]]"
concepts:
  - "[[concepts/alligator-indicator]]"
  - "[[concepts/sma-trend-filter]]"
  - "[[concepts/trend-following]]"
indicators:
  - Alligator(13,8,5)
  - SMA(144)
period: M15
source_citation: "Anonymous, 'Alligator', Robo-forex Strategy Compilation, robofx.com, ~2015."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD
expected_trades_per_year_per_symbol: 80
g0_approval_reasoning: "R1 PASS one source_id/source attribution; R2 PASS mechanical Alligator+SMA144 entries/exits with plausible M15 cadence ~80 trades/year/symbol; R3 PASS DWX FX M15 testable; R4 PASS deterministic non-ML 1-position compatible."
---

## Quelle

Anonymous, *Alligator*, Robo-forex Strategy Compilation (robofx.com), ~2015. Source PDF: `362359657-Robo-forex-strategy.pdf`, pages 34–35. URL: `robofx.com`.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX.

## Mechanik

**Konzept**: Trend following using Bill Williams' Alligator indicator (three shifted SMAs) combined with a 144-period SMA as a macro trend filter. Entry when price clears the SMA(144) and all three Alligator lines align in the same direction.

**Alligator indicator components** (standard MT5 Alligator):
- Jaw (blue): SMA(13) shifted 8 bars forward
- Teeth (red): SMA(8) shifted 5 bars forward
- Lips (green): SMA(5) shifted 3 bars forward

**Entry (Long)**:
1. Price (Close) is ABOVE SMA(144) — bullish long-term trend
2. Alligator Lips (green) crosses ABOVE Alligator Teeth (red): `lips[1] <= teeth[1] AND lips[0] > teeth[0]`
3. Alligator Teeth (red) crosses ABOVE Alligator Jaw (blue): `teeth[1] <= jaw[1] AND teeth[0] > jaw[0]` — ideally both cross occur close together
4. Enter at next bar open after conditions are met

**Entry (Short)**:
1. Price BELOW SMA(144)
2. Lips crosses BELOW Teeth: `lips[1] >= teeth[1] AND lips[0] < teeth[0]`
3. Teeth crosses BELOW Jaw
4. Enter at next bar open

**Stop Loss**: 1 pip below SMA(144) for long; 1 pip above SMA(144) for short. Source: "placed 1 point lower/higher than SMA 144 (all the time)."

**Exit**:
- Long: close when Lips crosses BELOW Teeth (Alligator signals reversal)
- Short: close when Lips crosses ABOVE Teeth

**Take Profit**: No fixed TP — ride trend until exit signal. Factory safety: add hard TP at 3×ATR(14).

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Single source_id and one source attribution present |
| R2 Mechanical | PASS | Alligator line crosses + SMA filter — fully mechanical |
| R3 Data Available | PASS | M15 DWX data available |
| R4 ML Forbidden | PASS | Standard indicators only |

## Implementation Notes for Codex (P1)

- Alligator in MT5: Use `iAlligator(symbol, M15, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN, <buffer>, shift)`
  - Buffers: 0=Jaw (blue/13), 1=Teeth (red/8), 2=Lips (green/5)
  - Note: Alligator uses PRICE_MEDIAN = (High+Low)/2, applied to SMMA not SMA
- SMA(144): `iMA(symbol, M15, 144, 0, MODE_SMA, PRICE_CLOSE, 0)`
- Lips cross up Teeth: `alligator_lips[1] <= alligator_teeth[1] AND alligator_lips[0] > alligator_teeth[0]`
- Teeth cross up Jaw: `alligator_teeth[1] <= alligator_jaw[1] AND alligator_teeth[0] > alligator_jaw[0]`
- Both cross conditions may not happen simultaneously — require Lips>Teeth>Jaw (ordered state) rather than simultaneous cross
- Factory implementation: enter when `lips > teeth > jaw AND close > SMA144` (ordered alignment state)
- SL long: `SMA144[0] - 1 * _Point`; may be wide — ATR(14) cap at 2×ATR
- Exit: `lips[0] < teeth[0]` (Lips drops below Teeth) → close long

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
