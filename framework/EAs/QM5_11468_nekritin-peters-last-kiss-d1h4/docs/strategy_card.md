---
ea_id: QM5_11468
slug: nekritin-peters-last-kiss-d1h4
type: strategy
source_id: 7f773fbb-884e-54c9-a5d8-3f4087497622
sources:
  - "[[sources/nekritin-peters-naked-forex-wiley]]"
concepts:
  - "[[concepts/consolidation-breakout]]"
  - "[[concepts/last-kiss-retouch]]"
  - "[[concepts/support-resistance-zone]]"
  - "[[concepts/stop-order-entry]]"
indicators: []
period: D1
source_citation: "Alex Nekritin and Walter Peters PhD, Naked Forex: High-Probability Techniques for Trading without Indicators, Chapter 5 (Wiley Trading, 2012). R1 PASS — Wiley-published, two named authors."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1 one source_id/source; R2 D1 box breakout-retouch entry/SL/TP mechanical with plausible >2 trades/year/symbol; R3 DWX FX D1 testable; R4 deterministic no ML/HR14 issues."
---

# QM5_11468 Nekritin/Peters — The Last Kiss (D1/H4)

## Quelle
- Source: Alex Nekritin & Walter Peters PhD, "Naked Forex" Ch5 (Wiley, 2012)
- R1: PASS — John Wiley & Sons, Wiley Trading series, two named authors.

## Mechanik

**Concept**: A consolidation box (bounded by a support zone and a resistance zone) forms when the market ranges between two S/R levels for multiple bars. The market then breaks out of this box. After the breakout, instead of entering immediately on the initial break, we wait for price to return and "kiss" the edge of the box — the zone it just broke through. This retouch signals that the former resistance is now support (or vice versa), and we enter on a stop order above the strong retouch candle. This filters out fake breakouts and enters with confirmation.

**Consolidation box identification**: A range of bars where the market repeatedly touches both a support zone and a resistance zone. Mechanizable as: last N bars' highest-close and lowest-close are within MAX_BOX_PIPS of each other, sustained for MIN_BOX_BARS bars. Or: iFractals at both extremes within a lookback window.

**Breakout**: The first D1 bar to close beyond the resistance zone (for bullish) or support zone (for bearish) — the bar that "escapes" the box.

### Entry

**LONG (bullish breakout + retouch):**
1. Identify consolidation box: `box_high` and `box_low` using iHighest/iLowest over 5-30 bar consolidation period
2. Breakout confirmed: `Close[breakout_bar] > box_high` (bullish) — bar that first closes above the top of the box
3. Retouch: a subsequent bar (typically within 1-5 bars after breakout) trades back near `box_high` — `Low[i] ≤ box_high + ZONE_BUFFER` (within a few pips of the box top)
4. Retouch bar must be bullish: `Close[i] > Open[i]` (confirms bullish intent on the retouch)
5. Entry: BUYSTOP at `High[retouch_bar] + 1pip`; valid for 1 bar; cancel if not filled by close of next bar
6. If filled: SL = midpoint of consolidation box: `(box_high + box_low) / 2`

**SHORT (bearish breakout + retouch):**
1. Breakout: `Close[breakout_bar] < box_low` (bearish)
2. Retouch: price revisits `box_low`, retouch bar is bearish (`Close < Open`)
3. SELLSTOP at `Low[retouch_bar] - 1pip`
4. SL = midpoint of box

### Exit
- **TP**: nearest S/R zone on the chart in the trade direction (beyond the breakout, NOT the box boundary)
  - Mechanization: identify next swing high/low using iHighest(N=30) / iLowest(N=30) beyond the box on the trade-direction side
  - If no identifiable next zone: TP = `box_height × 1.5` from entry
- **SL Option 2 (secondary)**: if price closes back inside the consolidation box after entry → exit at market (close back inside box = invalidation)
- **Time stop**: if not in TP within 20 D1 bars, exit at market

### Stop Loss
- Midpoint of consolidation box: `(box_high + box_low) / 2`
- P2 cap: 120 pips (if midpoint-to-entry distance > 120 pips, skip)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1 (primary)
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- Consolidation box minimum width: 30 pips
- Consolidation box minimum duration: 5 D1 bars
- Retouch must occur within 10 bars of breakout

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Wiley Trading series (2012), Alex Nekritin + Walter Peters PhD. |
| R2 Mechanical | PASS | Box defined by iHighest/iLowest rolling window. Breakout = close vs box extreme. Retouch = price proximity + bar direction. All OHLC arithmetic. |
| R3 Data Available | PASS | D1 DWX FX. iHighest/iLowest/iOpen/iClose MT5-native. |
| R4 No ML | PASS | Fixed window parameters, pip buffers. No optimization function. |

G0 APPROVE — R1 PASS (Wiley).

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Naked Forex Ch5 (Nekritin & Peters, Wiley 2012)

## Implementation Notes for Codex (P1)
- Box detection state machine: count bars where `iHigh(D1,i) < potential_box_high + ZONE_BUFFER` AND `iLow(D1,i) > potential_box_low - ZONE_BUFFER` for MIN_BOX_BARS consecutive bars
- Breakout detection: first D1 bar where `iClose(D1,i) > box_high` (after MIN_BOX_BARS confirmed)
- Retouch detection: scan bars after breakout; when `iLow(D1,i) <= box_high + ZONE_BUFFER` AND `iClose(D1,i) > iOpen(D1,i)` → retouch candle found
- BUYSTOP: `iHigh(D1,retouch_shift) + pip_offset`; cancel at close of next bar if not triggered
- SL_invalidation: monitor `iClose(D1,0) < box_high` (closed back inside box) → close trade
- TP_zone: use `iHighest(NULL,PERIOD_D1,MODE_HIGH,30,breakout_shift+10)` as first approximation for next resistance level
- P3 sweeps: MIN_BOX_BARS (3/5/8), MAX_BOX_PIPS (50/80/120), retouch ZONE_BUFFER (5/10/15 pips), TP method (next-zone/1.5×box/2×box)

## Verwandte Strategien
- Related: QM5_11470 (nekritin-peters-kangaroo-tail-d1) — same source; single-candle pattern at zone vs. multi-bar consolidation
- Related: QM5_11460 (sachs-consolidation-breakout-sma50-ema15) — also consolidation breakout; uses SMA50 trend filter vs. pure price zones

## Lessons Learned
- *(populated as pipeline progresses)*
