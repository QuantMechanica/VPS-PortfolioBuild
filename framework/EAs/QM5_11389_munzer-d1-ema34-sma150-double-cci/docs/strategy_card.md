---
ea_id: QM5_11389
slug: munzer-d1-ema34-sma150-double-cci
type: strategy
source_id: dfd32799-2055-5ef8-b99b-dcbfa51daba0
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/cci-reversal]]"
  - "[[concepts/ma-trend-filter]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
  - "[[indicators/cci]]"
  - "[[indicators/stochastic]]"
period: D1
source_citation: "Mohammed Munzer (South Lebanon), Complex System #7, forex-strategies-revealed.com compilation, local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named author Mohammed Munzer via forex-strategies-revealed.com compilation fully satisfies R1."
r2_mechanical: PASS
r2_reasoning: "EMA/SMA position, CCI sign, Stochastic level, and pending stop at candle extreme ±10 pips are all binary deterministic rules."
r3_data_available: PASS
r3_reasoning: "Targets EURUSD.DWX/GBPUSD.DWX/USDJPY.DWX on D1, all available DWX instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Standard EMA, SMA, CCI, and Stochastic indicators; no ML, no adaptive parameters, single pending stop per symbol."
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 30
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 PASS single source_id and local PDF attribution; R2 PASS deterministic D1 MA/CCI/Stoch pending-stop rules with plausible ~30 trades/year/symbol; R3 PASS on DWX forex D1 symbols; R4 PASS deterministic non-ML one-position strategy."
---

# QM5_11389 Mohammed Munzer D1 — EMA(34)/SMA(150) + Double CCI(50,14) + Stoch(5,3,3) (D1)

## Quelle

- Source: "Complex Trading System #7 (Mohammed Munzer Forex System)" in
  "Simple, Complex and Advanced Forex Trading Strategies" compilation by forex-strategies-revealed.com
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
- Citation captured 2026-05-23; URL/local archive: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
- Author: Mohammed Munzer (South Lebanon) — named individual. R1 PASS.

## Mechanik

D1 trend system using EMA(34) and SMA(150) as trend structure. Price must be on the
correct side of the MA pair. Double CCI (slow=50, fast=14) and Full Stochastic(5,3,3) provide
entry timing. Entry is a pending stop order placed 10 pips beyond the signal candle's extreme.

### Entry

**Do Not Trade Zone**:
- Price is **between** EMA(34) and SMA(150) → no trade.

**LONG**:
1. EMA(34) is **above** SMA(150) (uptrend structure).
2. Daily candle **closes above** EMA(34) (price confirms trend side).
3. CCI(50) is **above** zero AND CCI(14) is **above** zero.
4. Stochastic(5,3,3) is **not** overbought (below 80).
5. Place a BUY STOP order 10 pips above the signal candle's High.
6. Cancel if not triggered on the next daily bar.

**SHORT**:
1. EMA(34) is **below** SMA(150).
2. Daily candle closes below EMA(34).
3. CCI(50) < 0 AND CCI(14) < 0.
4. Stochastic(5,3,3) not oversold (above 20).
5. Place a SELL STOP order 10 pips below signal candle's Low.

### Exit

- SL: 10 pips beyond signal candle's opposite extreme.
  LONG: stop at signal candle Low − 10 pips.
  SHORT: stop at signal candle High + 10 pips.
- TP: ATR(14) × 2.0 (source specifies "next pivot or 50–100 pip target"; ATR-based in P2).
- Trail: move SL to breakeven at +1× ATR.

### Stop Loss

- Signal candle opposite extreme ± 10 pips.
- P2 cap: 60 pips max SL (D1 candles can be large).

### Position Sizing

- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter

- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX
- Spread cap: 30 pips (D1 spread not critical)
- News filter: off in P2

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Mohammed Munzer, named individual, contributed to forex-strategies-revealed.com. |
| R2 Mechanical | PASS | EMA vs SMA position checks binary. CCI sign checks binary. Stoch level checks binary. Pending stop 10 pips beyond candle extreme — fully deterministic. |
| R3 Data Available | PASS | D1 DWX data. No minimum history gap issue on D1 (2017–present). |
| R4 No ML | PASS | EMA, SMA, CCI, Stochastic — all standard, no ML. |

G0 APPROVE eligible.

## Pipeline-Verlauf

- G0: 2026-05-23 — drafted from Mohammed Munzer, Complex System #7 in forex-strategies-revealed.com compilation

## Implementation Notes for Codex (P1)

- Timeframe: D1
- DWX symbols: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX**
- EMA(34): `iMA(NULL,0,34,0,MODE_EMA,PRICE_CLOSE,i)`
- SMA(150): `iMA(NULL,0,150,0,MODE_SMA,PRICE_CLOSE,i)`
- CCI(50): `iCCI(NULL,0,50,PRICE_TYPICAL,i)`; CCI(14): `iCCI(NULL,0,14,PRICE_TYPICAL,i)`
- Stoch(5,3,3): `iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,i)`
- No-trade zone: `(ema34[0] > sma150[0] && Close[0] < sma150[0]) || (ema34[0] < sma150[0] && Close[0] > sma150[0])` → skip
- LONG trigger: `ema34[0] > sma150[0] && Close[0] > ema34[0] && cci50[0] > 0 && cci14[0] > 0 && stoch[0] < 80`
- Pending stop: `OrderSend` with OP_BUYSTOP at `High[0] + 10*Point`; expiry = next bar
- SL LONG: `Low[0] - 10*Point`; SL cap: 60 pips from entry
- TP: `entry + iATR(NULL,0,14,0) * 2.0`
- P3 sweeps: EMA period (21 vs 34), CCI periods (14/50 vs 20/100), Stoch (5,3,3 vs 14,3,3).

## Verwandte Strategien

- Related: QM5_11310 (tc20-h1-7-ema-cascade-rsi21) — also EMA cascade + momentum filter, but H1
- Differentiator: D1 frame + pending stop entry (not market); double CCI (fast+slow) rather than RSI;
  EMA(34)/SMA(150) pair creates explicit no-trade zone between MAs.

## Lessons Learned

- *(populated as pipeline progresses)*
