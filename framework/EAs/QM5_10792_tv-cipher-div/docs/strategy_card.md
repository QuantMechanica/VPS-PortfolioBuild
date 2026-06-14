---
ea_id: QM5_10792
slug: tv-cipher-div
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Cherepanov_V, Cipher B divergencies for Crypto (Finandy support), TradingView open-source strategy, published 2022-06-19, https://www.tradingview.com/script/iYHnmIQB-Cipher-B-divergencies-for-Crypto-Finandy-support/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/divergence-reversal]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/vumanchu-cipher-b]]"
  - "[[indicators/simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; exact TradingView URL and author handle Cherepanov_V are cited."
r2_mechanical: PASS
r2_reasoning: "VuManChu Cipher B divergence/buy-sell signals plus local SMA and global trend filter give clear mechanical entry/exit rules; BTC global filter replaced with same-symbol EMA at build time."
r3_data_available: PASS
r3_reasoning: "OHLC-based Cipher B oscillator and SMA/trend indicators are portable to all DWX symbols; BTC global trend proxy replaced with same-symbol EMA or NDX risk proxy."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed oscillator and SMA/trend filters; no ML, grid, martingale, or adaptive runtime parameters."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL cited; R2 PASS Cipher/divergence entries plus SMA/global trend filters and fixed TP/SL support ~70 trades/year/symbol; R3 PASS OHLC oscillator logic portable to DWX with same-symbol or proxy trend filter; R4 PASS fixed rules no ML/grid/martingale."
---

# TradingView Cipher B Divergence Trend Filter

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Cipher B divergencies for Crypto (Finandy support)`, author handle `Cherepanov_V`, open-source strategy, published 2022-06-19, accessed 2026-05-22, https://www.tradingview.com/script/iYHnmIQB-Cipher-B-divergencies-for-Crypto-Finandy-support/

## Mechanik

### Entry
Use M5/M15 baseline after porting from crypto to DWX CFDs.

- Compute VuManChu Cipher B buy/sell or divergence signals with fixed settings.
- Compute local trend SMA.
- Compute benchmark/global trend filter. For DWX port, replace BTC global trend with same-symbol H4 EMA200 or NDX.DWX risk proxy.
- Long setup:
  - Cipher B emits buy signal or bullish divergence signal.
  - Price is above local SMA.
  - Background/global trend state is bullish.
  - No existing position.
- Short setup:
  - Cipher B emits sell signal or bearish divergence signal.
  - Price is below local SMA.
  - Background/global trend state is bearish.
  - No existing position.

### Exit
- Fixed source TP/SL from the script inputs.
- Optional trailing stop: cancel long if price crosses below local SMA; cancel short if price crosses above local SMA.

### Stop Loss
- Source says fixed stop losses and take profits are used.
- V5 baseline: ATR-normalized fixed stop, default ATR(14) * 1.5, with target at 2.0R.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Source preference: `Only divergencies` enabled for more selective signals.
- Optional global-risk proxy filter can be disabled for non-index DWX symbols in ablation.

## Concepts (was ist das fur eine Strategie)
- [[concepts/divergence-reversal]] - oscillator divergence is the entry trigger.
- [[concepts/trend-filter]] - local and global trend states gate signal direction.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Cherepanov_V` are cited. |
| R2 Mechanical | PASS | Source gives buy/sell or divergence signals plus local/global trend filters and fixed TP/SL. |
| R3 Data Available | UNKNOWN | Core OHLC indicators are portable; crypto-specific BTC global trend filter must be replaced or disabled for DWX symbols. |
| R4 ML Forbidden | PASS | Fixed oscillator and SMA/trend filters; no ML, grid, martingale, or adaptive runtime parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy uses Cipher B buy/sell and divergence signals with fixed stop losses and take profits.
- Source says trades are filtered by local trend and by the global trend of Bitcoin.
- Source says enabling only divergences gives more reliable but rarer signals.

## Parameters To Test
- Signal mode: all Cipher B buy/sell signals, divergences only.
- Local SMA length: 50, 100, 200.
- Global trend proxy: off, H4 EMA200 same-symbol, NDX.DWX EMA200.
- Stop: ATR(14) * 1.0, 1.5, 2.0.
- Target: 1.5R, 2.0R, 3.0R.
- Timeframe: M5, M15.

## Initial Risk Profile
Crypto-origin divergence strategy. Keep R3 UNKNOWN until the benchmark trend proxy is nailed down; otherwise mechanically testable and ML-free.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10046 ff-momentum-div-h4
- QM5_10161 tv-mtf-macd-confirm

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
