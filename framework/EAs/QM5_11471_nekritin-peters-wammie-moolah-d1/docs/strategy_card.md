---
ea_id: QM5_11471
slug: nekritin-peters-wammie-moolah-d1
type: strategy
source_id: 7f773fbb-884e-54c9-a5d8-3f4087497622
sources:
  - "[[sources/nekritin-peters-naked-forex-wiley]]"
concepts:
  - "[[concepts/double-bottom]]"
  - "[[concepts/double-top]]"
  - "[[concepts/support-resistance-zone]]"
  - "[[concepts/stop-order-entry]]"
  - "[[concepts/second-touch-entry]]"
indicators: []
period: D1
source_citation: "Alex Nekritin and Walter Peters PhD, Naked Forex: High-Probability Techniques for Trading without Indicators, Chapter 7 (Wiley Trading, 2012). R1 PASS — Wiley-published, two named authors."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 8
g0_approval_reasoning: "R1 source_id + Wiley Naked Forex citation; R2 mechanical D1 double-touch reversal entries/exits with expected ~8 trades/year/symbol plausible; R3 DWX FX D1 testable; R4 deterministic no ML"
---

# QM5_11471 Nekritin/Peters — Wammie (Double Bottom) / Moolah (Double Top) D1

## Quelle
- Source: Alex Nekritin & Walter Peters PhD, "Naked Forex" Ch7 (Wiley, 2012)
- R1: PASS — John Wiley & Sons, Wiley Trading series, two named authors.

## Mechanik

**Concept**: A "Wammie" is Nekritin/Peters' term for a double bottom at a support zone. A "Moolah" is a double top at a resistance zone. The pattern requires two touches of the same S/R zone — with the second touch generating a strong reversal candle. Entry is via stop order above/below the reversal candle on the second touch. The SL goes below the lowest Low of both touches (for Wammie), ensuring that a genuine new downtrend invalidates the trade.

**Distinction from standard double bottoms**: The zone must be a meaningful S/R zone (defined by multiple prior touches), not just any two lows at the same price. The second touch must print a strong catalyst candle (not just any close above/below the zone).

### Pattern Identification

**WAMMIE (Double Bottom at Support Zone):**
1. First touch: a bar's Low reaches the support zone (within ZONE_BUFFER pips of the zone level)
2. Rally: price moves away from zone (at least 30 pips above zone)
3. Second touch: a bar's Low returns to the same support zone area (within ZONE_BUFFER pips)
4. Second touch triggers a strong bullish candle: `Close[second_touch] > Open[second_touch]` AND body size > 50% of bar range
5. Pattern window: second touch must occur within 20 D1 bars of first touch

**MOOLAH (Double Top at Resistance Zone):**
1. First touch: bar's High reaches resistance zone
2. Sell-off: at least 30 pips below zone
3. Second touch: High returns to resistance zone
4. Strong bearish candle on second touch: `Close[second_touch] < Open[second_touch]` AND body > 50% range
5. Pattern window: within 20 D1 bars

### Entry

**LONG (Wammie):**
1. All pattern conditions met
2. After second-touch bar closes: place BUYSTOP at `High[second_touch_bar] + 1pip`
3. SL = `Low[lowest_of_two_touches] - 1pip` (the lowest Low of first and second touch)
4. Cancel BUYSTOP if not filled within 3 D1 bars

**SHORT (Moolah):**
1. Pattern confirmed
2. SELLSTOP at `Low[second_touch_bar] - 1pip`
3. SL = `High[highest_of_two_touches] + 1pip`
4. Cancel within 3 bars if unfilled

### Exit
- **TP**: nearest S/R zone above entry (Wammie) / below entry (Moolah)
  - Fractal scan: first swing high above entry for long TP; first swing low below entry for short TP
- **SL**: below lowest Low of both touches (Wammie) / above highest High (Moolah)

### Stop Loss
- Beyond extreme of both touch lows (Wammie) / highs (Moolah) + 1 pip
- P2 cap: 120 pips (if distance from entry to SL > 120 pips, skip)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- Zone buffer: 10 pips (both touches within 10 pips of the same zone level)
- Minimum rally between touches: 30 pips
- Maximum pattern window: 20 D1 bars between first and second touch

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Wiley Trading series (2012), Alex Nekritin + Walter Peters PhD. |
| R2 Mechanical | PASS | Zone touches: Low vs zone level (OHLC + pip threshold). Bullish catalyst: Close>Open + body ratio (OHLC arithmetic). Double bottom structure: bar index tracking. |
| R3 Data Available | PASS | D1 DWX FX. iHigh/iLow/iClose/iOpen MT5-native. |
| R4 No ML | PASS | Fixed ZONE_BUFFER (10 pips), min rally (30 pips), pattern window (20 bars). |

G0 APPROVE — R1 PASS (Wiley).

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Naked Forex Ch7 (Nekritin & Peters, Wiley 2012)

## Implementation Notes for Codex (P1)
- State machine: IDLE → ZONE_DEFINED → FIRST_TOUCH → RALLY → AWAITING_SECOND_TOUCH → CATALYST → ORDER_PLACED → IN_TRADE
- Zone level: externally defined (not auto-detected in P2 — use ATR-based dynamic zones or user input; P3 can test auto-detection via iFractals)
- P2 simplification: zone = iLowest(D1, MODE_LOW, 50, 5) area — find lowest point in recent 50 bars (excl last 5), use it as the zone level
- First touch: `iLow(D1,i) <= zone_level + ZONE_BUFFER_pips`; record first_touch_bar, first_touch_low
- Rally check: `iHighest(D1,MODE_HIGH,first_touch_bar,1) - zone_level > MIN_RALLY_pips`
- Second touch: rescan after first touch; when `iLow(D1,j) <= zone_level + ZONE_BUFFER_pips` AND `j > first_touch_bar+3` AND `j < first_touch_bar+20`
- Catalyst check on second touch bar: `iClose(D1,second_touch_bar) > iOpen(D1,second_touch_bar)` AND `(iClose(D1,second_touch_bar) - iOpen(D1,second_touch_bar)) > 0.5*(iHigh(D1,second_touch_bar)-iLow(D1,second_touch_bar))`
- SL = `MathMin(first_touch_low, second_touch_bar_low) - pip_offset`
- P3 sweeps: ZONE_BUFFER (5/10/20 pips), MIN_RALLY (20/30/50 pips), max_pattern_bars (10/20/30), catalyst body ratio (33%/50%/66%), zone detection method (manual/fractal/iLowest)

## Verwandte Strategien
- Related: QM5_11466 (samuels-123-pattern-fractal-d1) — similar second-touch entry logic; 123 pattern uses 3 swing points + 50% retracement; Wammie uses 2 equal zone touches with catalyst
- Related: QM5_11470 (nekritin-peters-kangaroo-tail-d1) — same source; single candle reversal vs. two-touch zone confirmation

## Lessons Learned
- *(populated as pipeline progresses)*
