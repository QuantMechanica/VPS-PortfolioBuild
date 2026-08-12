---
ea_id: QM5_11416
slug: ichimoku-tenkan-kijun-cross-cloud-h4
type: strategy
source_id: d45db07a-2928-5ff6-9251-d54170212549
sources:
  - "[[sources/ichimoku-cloud-strategy-anonymous]]"
concepts:
  - "[[concepts/ichimoku]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/cloud-filter]]"
  - "[[concepts/lagging-span-exit]]"
indicators:
  - "[[indicators/ichimoku]]"
period: H4
source_citation: "Anonymous, Ichimoku Cloud Forex Trading Strategy, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\470596299-Ichimoku-Cloud-Forex-Trading-Strategy.pdf"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; anonymous PDF is explicitly allowed per R1 criteria."
r2_mechanical: PASS
r2_reasoning: "Cloud comparison, Tenkan/Kijun cross, and Chikou vs historical price are all arithmetic midpoint/range comparisons implementable in MT5."
r3_data_available: PASS
r3_reasoning: "H4 DWX FX symbols available; Ichimoku is MT5-native."
r4_ml_forbidden: PASS
r4_reasoning: "Standard Ichimoku parameters (9/26/52) with no adaptive or ML components."
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 30
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 single source_id/local PDF; R2 mechanical Ichimoku cloud+cross+Chikou entry/exit with plausible H4 cadence >2 trades/year/symbol; R3 DWX FX H4 testable; R4 deterministic no ML/HR14 conflict."
---

# QM5_11416 Ichimoku — Tenkan/Kijun Cross with Cloud Filter (H4)

## Quelle
- Source: "Ichimoku Cloud Forex Trading Strategy" (anonymous PDF)
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\470596299-Ichimoku-Cloud-Forex-Trading-Strategy.pdf`
- Source citation: Accessed 2026, URL/local PDF: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\470596299-Ichimoku-Cloud-Forex-Trading-Strategy.pdf`
- R1: CONDITIONAL — Anonymous source.

## Mechanik

**Concept**: Ichimoku Kinko Hyo trend-following with four layers of confluence: (1) price above/below Kumo sets the trend, (2) Tenkan/Kijun cross triggers entry, (3) Chikou Span (Lagging Span) not touching historical price confirms clean space ahead, and (4) Chikou touching price triggers exit.

### Ichimoku Parameters (standard)
- **Tenkan-sen (Conversion)**: `(Highest High + Lowest Low) / 2` over 9 periods
- **Kijun-sen (Base)**: `(Highest High + Lowest Low) / 2` over 26 periods
- **Senkou Span A**: `(Tenkan + Kijun) / 2` shifted forward 26 bars
- **Senkou Span B**: `(Highest High + Lowest Low) / 2` over 52 periods, shifted forward 26 bars
- **Chikou Span**: Today's Close plotted 26 bars in the past

**Kumo (Cloud)**: The area between Senkou Span A and Senkou Span B. Price above cloud = bullish; below = bearish.

### Entry

**LONG** (four conditions):
1. **Cloud filter**: `Close[0] > max(SpanA[26], SpanB[26])` — price is above the cloud.
   (Use future cloud values: Span A/B are projected 26 bars forward, so compare current price to cloud 26 bars back in MT5 terms.)
2. **Cross signal**: `Tenkan[1] < Kijun[1]` AND `Tenkan[0] > Kijun[0]` — Tenkan crossed above Kijun on most recent bar.
3. **Chikou filter**: The Chikou Span at current bar (= Close[0] shifted 26 bars back) does NOT overlap price bars from 26 bars ago: `Close[26] < Low[26]` — i.e., historical price was below the current close.
   Mechanized: `Close[0] > High[26]` (Chikou above those historical prices = clear space).
4. Enter BUY at open of next bar.

**SHORT** (four conditions):
1. `Close[0] < min(SpanA[26], SpanB[26])` — price below cloud.
2. Tenkan crossed below Kijun.
3. `Close[0] < Low[26]` — Chikou below historical price range (clear downside space).
4. Enter SELL at open of next bar.

### Exit
- **Chikou touching price**: Exit when Chikou Span (current close) begins overlapping with historical price bars from 26 bars ago.
  Mechanized: LONG exit when `Close[0] <= High[26]` AND `Close[0] >= Low[26]` (Chikou is now inside the historical bar range).
- **Kijun stop**: SL below the Kijun-sen (or below the near cloud edge for longs).

### Stop Loss
- LONG: Most recent swing low before entry, or below Kijun-sen, capped at 60 pips.
- SHORT: Most recent swing high, or above Kijun-sen, capped at 60 pips.
- P2 cap: 60 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H4
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX
- Spread cap: 20 pips
- Do not trade when Tenkan and Kijun are horizontal and price is range-bound (all cloud lines flat)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Anonymous PDF. |
| R2 Mechanical | PASS | All Ichimoku components are arithmetic mid-point/range calculations. Cloud comparison, Tenkan/Kijun cross, Chikou vs historical price — all binary comparisons. |
| R3 Data Available | PASS | H4 DWX; Ichimoku is native MT5 indicator. |
| R4 No ML | PASS | Standard Ichimoku parameters (9/26/52). |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Ichimoku Cloud PDF

## Implementation Notes for Codex (P1)
- `iIchimoku(NULL, PERIOD_H4, 9, 26, 52, MODE_TENKANSEN, i)` — Tenkan
- `iIchimoku(NULL, PERIOD_H4, 9, 26, 52, MODE_KIJUNSEN, i)` — Kijun
- `iIchimoku(NULL, PERIOD_H4, 9, 26, 52, MODE_SENKOUSPANA, i)` — Span A (already shifted in MT5)
- `iIchimoku(NULL, PERIOD_H4, 9, 26, 52, MODE_SENKOUSPANB, i)` — Span B
- In MT5, Span A/B values at index 0 are the CURRENT cloud (26 bars ahead of today); use index 0 for the cloud price is currently inside
- Chikou comparison: `Close[0]` (today's close) vs `High[26]` / `Low[26]` (26 bars back)
- Cross detection: `tenkan[1] < kijun[1] && tenkan[0] > kijun[0]` on bar 1 (most recently closed)
- P3 sweeps: parameters (7/9/14 for Tenkan, 22/26/30 for Kijun), SL method (swing low vs Kijun)

## Verwandte Strategien
- Related: QM5_11413 (wilder-directional-movement-di14-cross-d1) — also a crossover-based trend system with a trend-strength pre-filter
- Differentiator: Ichimoku integrates trend, momentum, support/resistance (cloud), and exit signal (Chikou) in a single self-consistent system. More holistic than the DI-only approach.

## Lessons Learned
- *(populated as pipeline progresses)*
