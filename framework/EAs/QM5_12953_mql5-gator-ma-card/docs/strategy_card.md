---
ea_id: QM5_12953
slug: mql5-gator-ma-card
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
source_citation: "Mohamed Abdelmaaboud, Learn how to design a trading system by Gator Oscillator, MQL5 Articles, 2023-01-12, https://www.mql5.com/en/articles/11928"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Medium frequency; Gator double-bar phase plus MA side filter, roughly 45-95 trades per year per symbol"
expected_trades_per_year_per_symbol: 70
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
---

# MQL5 Gator MA Phase Signal

## Source

- Source: MQL5 Articles
- Article: "Learn how to design a trading system by Gator Oscillator"
- Author: Mohamed Abdelmaaboud
- Date: 2023-01-12
- URL: https://www.mql5.com/en/articles/11928
- Section: Gator Oscillator strategy section, strategy three, Gator with MA.

## Mechanics

### Target Symbols

- EURUSD.DWX
- GBPUSD.DWX
- XAUUSD.DWX

### Entry

- Calculate Gator Oscillator using Alligator defaults: Jaws 13/8, Teeth 8/5, Lips 5/3, SMMA median price.
- Calculate SMA(50) and ATR(14) on closed H1 bars.
- Long entry requires current upper Gator bar greater than previous upper Gator bar, current lower Gator bar lower than previous lower Gator bar, and close above SMA(50).
- Short entry requires current upper Gator bar lower than previous upper Gator bar, current lower Gator bar greater than previous lower Gator bar, and close below SMA(50).
- Enter at the next bar open, one position per magic number.

### Exit

- Close long when upper Gator value falls while lower Gator value rises, or close falls below SMA(50).
- Close short when upper Gator value rises while lower Gator value falls, or close rises above SMA(50).
- Failsafe time exit after 48 H1 bars.

### Stop Loss

- Long stop: entry minus ATR(14) * 1.7.
- Short stop: entry plus ATR(14) * 1.7.
- Initial take profit: 2.1R.

### Position Sizing

- V5 fixed 1000 USD P2 risk from stop distance.

### Additional Filters

- Closed-bar execution only.
- Require SMA(50) slope over five bars to be nonzero in the trade direction.
- V5 default news and Friday-close controls.

## R1-R4 Evaluation

| Criterion | Status | Reason |
|-----------|--------|--------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Mohamed Abdelmaaboud. |
| R2 Mechanical | PASS | Source defines double green Gator bars plus close above moving average as buy, and double red Gator bars plus close below moving average as sell. |
| R3 Data Available | PASS | Uses OHLC-derived Gator Oscillator, SMA, and ATR data available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator comparisons and one-position-per-magic execution; no ML, adaptive parameters, grid, or martingale. |
