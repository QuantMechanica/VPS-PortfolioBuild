---
ea_id: QM5_10133
slug: tv-ema80-scalp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "Macketing1337, Macketings 1min Scalping, TradingView, 2025-11-20, https://www.tradingview.com/script/UDNlq5ow-Macketings-1min-Scalping/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/scalping]]"
  - "[[concepts/ema-trend-filter]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX]
period: M1
expected_trade_frequency: "M1 four-EMA trend scalper with cooldown/session filters; conservative estimate 160-280 trades/year/symbol after spread filters."
expected_trades_per_year_per_symbol: 200
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source TradingView URL/title/date; R2 deterministic EMA band scalper entries/exits with ~200 trades/year/symbol; R3 ports to DWX FX/gold/DAX CFDs; R4 fixed non-ML one-position rules."
---

# TradingView Macketings EMA Band Scalper

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: Macketing1337, "Macketings 1min Scalping", TradingView, 2025-11-20, URL https://www.tradingview.com/script/UDNlq5ow-Macketings-1min-Scalping/.
- Author / handle: `Macketing1337`.
- Source location: public page describes strict EMA 80/90/340/500 hierarchy, retest or breakout of the 80/90 band, tight initial stop, breakeven/secured-profit management, and EMA-band/trend-reversal exits.

## Mechanik

### Entry
- Baseline parameters:
  - EMA lengths 80, 90, 340, 500.
  - Initial stop 0.2% of entry price, as source default.
  - Breakeven trigger 0.3% profit; secured-profit level +0.2%.
  - Take-profit target 2.5%.
  - Cooldown 100 bars after exit if using the Dec 2025 update.
  - Signal timeframe M1.
- Long entry when all conditions are true:
  - EMA(80) > EMA(90) > EMA(340) > EMA(500).
  - Price retests or enters the EMA(80)/EMA(90) band.
  - Candle closes upward out of the band with close above EMA(80).
  - Optional safety filter from update: close > SMA(325).
- Short entry when all conditions are true:
  - EMA(80) < EMA(90) < EMA(340) < EMA(500).
  - Price retests or enters the EMA(80)/EMA(90) band.
  - Candle closes downward out of the band with close below EMA(80).
  - Optional safety filter from update: close < SMA(325).

### Exit
- Move long stop to secure +0.2% once profit reaches +0.3%; equivalent mirrored rule for shorts.
- Close at +2.5% target.
- Close long when EMA(80)/EMA(90) band breaks down after minimum profit activation or EMA(340) crosses below EMA(500).
- Close short when EMA(80)/EMA(90) band breaks up after minimum profit activation or EMA(340) crosses above EMA(500).

### Stop Loss
- Long stop: entry price * 0.998.
- Short stop: entry price * 1.002.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Trade only high-liquidity sessions: London and New York overlap for FX/gold; Frankfurt/London morning for DAX.
- Skip if spread > 8% of stop distance.
- Use cooldown 100 bars after an exit.

## Concepts
- [[concepts/scalping]] - primary
- [[concepts/ema-trend-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle `Macketing1337`. |
| R2 Mechanical | PASS | EMA hierarchy, band retest/breakout entry, percent stop/target, breakeven, cooldown, and EMA exits are deterministic. |
| R3 DWX-testbar | PASS | EMA/ATR/OHLC scalping logic ports to liquid DWX FX, gold, and DAX CFDs. |
| R4 No ML | PASS | Fixed EMA/ATR rules; no ML, grid, martingale, or adaptive online parameter updates. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10115_tv-ma-scalper-relief]] - related moving-average scalper; this card uses a four-EMA hierarchy and fast band retest/breakout entries.

## Lessons Learned
- TBD during pipeline run.
