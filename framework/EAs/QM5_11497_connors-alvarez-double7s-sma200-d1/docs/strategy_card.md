---
ea_id: QM5_11497
slug: connors-alvarez-double7s-sma200-d1
type: strategy
source_id: e2807d63-4109-5824-8d44-1800ee8fe7eb
sources:
  - "[[sources/connors-alvarez-short-term-trading-strategies-2009]]"
concepts:
  - "[[concepts/mean-reversion-short-term]]"
  - "[[concepts/donchian-n-day-low]]"
  - "[[concepts/sma200-trend-filter]]"
indicators:
  - SMA(200)
  - iLowest(7)
  - iHighest(7)
period: D1
source_citation: "Larry Connors and Cesar Alvarez, 'Short-Term Trading Strategies That Work', TradingMarkets Publishing LLC, 2009. R1 CONDITIONAL — named professionals (TradingMarkets.com, Wall Street), self-published. Originally for US stocks/ETFs; adapted to Forex daily pairs."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 25
g0_approval_reasoning: "R1 PASS single source_id Connors/Alvarez book; R2 PASS mechanical SMA200 plus 7-day close extreme entry/exit with plausible daily mean-reversion cadence >2 trades/year/symbol; R3 PASS DWX D1 FX/index port testable; R4 PASS deterministic no ML one-position."
---

# QM5_11497 Connors-Alvarez — Double 7's Mean Reversion (D1)

## Quelle
- Source: Larry Connors and Cesar Alvarez, "Short-Term Trading Strategies That Work", TradingMarkets Publishing LLC, 2009. URL/locator: local bibliographic book source page `[[sources/connors-alvarez-short-term-trading-strategies-2009]]`. Chapter: "Double 7's Strategy".
- R1: CONDITIONAL — named professionals, self-published (TradingMarkets Publishing LLC). Originally for stocks (SPY/S&P 500); QM adapts to Forex daily pairs.

## Mechanik

**Concept**: When price is above its 200-day SMA (bull trend), a 7-day closing low signals a short-term over-sold condition within the larger trend. Mean reversion to the 7-day high is the expected move. Entry at the 7-day low, exit at the 7-day high. The strategy captures short-term reversion moves within a longer-term trend.

**Logic**: SMA(200) acts as a trend confirmation — only buy pullbacks in a bullish context. The 7-day lowest close is a pure price-action definition of short-term exhaustion in the direction opposite to the trend. No oscillator confirmation needed; the definition is entirely price-arithmetic.

**Note on original**: Connors/Alvarez tested this on SPY (S&P 500 ETF) from 1995–2007. QM applies to Forex daily pairs as a hypothesis — the edge (7-day reversion within SMA(200) context) may transfer, but no Forex-specific evidence from the source.

**Caveat**: Source has no SL defined ("stops hurt" is a book theme). QM adds ATR-based SL for risk control. Source has no explicit TP rule other than the 7-day highest close exit.

### Entry

**LONG:**
1. **Trend filter**: `iClose(NULL,PERIOD_D1,1) > iMA(NULL,PERIOD_D1,200,0,MODE_SMA,PRICE_CLOSE,1)` (close above SMA(200))
2. **7-day low signal**: `iClose(NULL,PERIOD_D1,1) == iLowest(NULL,PERIOD_D1,MODE_CLOSE,7,1)` (today's close = 7-day lowest close)
   - More precisely: `iClose[1] <= iClose[k] for all k in {1..7}` on the prior 7 bars
3. Enter BUY at open of next bar (D1)

**SHORT (mirror — adapted for Forex):**
1. `iClose[1] < iMA(NULL,PERIOD_D1,200,...,1)` (close below SMA200)
2. `iClose[1] == iHighest(NULL,PERIOD_D1,MODE_CLOSE,7,1)` (7-day highest close)
3. Enter SELL at open of next bar

### Exit
- **Primary**: Close at open of next bar when `iClose[1] == iHighest(NULL,PERIOD_D1,MODE_CLOSE,7,1)` for long (or 7-day lowest close for short)
- **SL** (QM-added): `entry - 2 * iATR(NULL,PERIOD_D1,14,0)` for long; source specifies no SL
- **Max hold**: 10 D1 bars (QM-added; if 7-day high exit not triggered in 10 bars, exit at close)
- P2 cap: SL = 2×ATR(14); max hold = 10 bars

### Stop Loss
- `SL = entry - 2 * iATR(NULL,PERIOD_D1,14,0)` (QM-added; not in source)
- P2 cap: 100 pips (skip trade if ATR-based SL > 100 pips)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 30 pips
- No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Connors/Alvarez: named professionals (TradingMarkets), self-published. Stock strategies adapted to Forex — no Forex evidence in source. |
| R2 Mechanical | PASS | SMA(200): iMA(200,SMA). 7-day low: iLowest(MODE_CLOSE,7). 7-day high: iHighest(MODE_CLOSE,7). ATR: iATR(14). All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. All MT5-native. |
| R4 No ML | PASS | Pure price arithmetic (N-day extremes, SMA comparison). No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. Source-tested on equities only — P2 Forex backtest is the real evidence gate. SL is QM-added.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Connors & Alvarez, TradingMarkets 2009, "Double 7's Strategy"

## Implementation Notes for Codex (P1)
- `double sma200 = iMA(NULL,PERIOD_D1,200,0,MODE_SMA,PRICE_CLOSE,1)`
- `double lowest7 = iLowest(NULL,PERIOD_D1,MODE_CLOSE,7,1)` — returns BAR INDEX of lowest; compare `iClose[lowest7] == iClose[1]`
  - Alternative: iterate `for(int k=1;k<=7;k++) if(iClose[k] < iClose[1]) is_7day_low=false`
- `double highest7 = iHighest(NULL,PERIOD_D1,MODE_CLOSE,7,1)`
- LONG entry: `iClose[1] > sma200 AND is_7day_low`
- LONG exit: close is 7-day high OR 10 bars elapsed OR SL hit
- `double atr14 = iATR(NULL,PERIOD_D1,14,0)`
- SL: `entry - 2*atr14`; TP: dynamic (7-day high exit)
- P3 sweeps: N-day lookback (5/7/10), SMA period (100/200/300), ATR SL multiplier (1.5/2/3), max hold (7/10/15 days)

## Verwandte Strategien
- Related: QM5_11498 (connors-alvarez-cumulative-rsi2-sma200-d1) — same source, RSI(2) cumulative variant
- Related: QM5_11455 (davey-donchian-close-breakout) — Donchian N-day breakout (opposite direction — momentum not mean reversion)

## Lessons Learned
- *(populated as pipeline progresses)*
