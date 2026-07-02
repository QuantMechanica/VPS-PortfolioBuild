# QM5_9575 Pring KST Monthly

**EA ID:** QM5_9575
**Slug:** pring-kst-monthly
**Source Card:** docs/strategy_card.md

## 1. Strategy Logic

Monthly long-cycle momentum using Martin Pring KST. Because .DWX tester coverage is unreliable on native MN1 bars, the EA computes monthly closes from D1 bars using a 21-trading-day proxy. It enters long when KST crosses above its signal, price is above the 18-month long-cycle average, and KST is below +20. It enters short on the mirrored cross below signal, below the long-cycle average, and KST above -20.

Positions exit on the opposite KST cross, opposite long-cycle average break, or a 12-month time stop.

## 2. Parameters

`strategy_proxy_days_per_month=21`; ROC windows `6,9,12,18` months; smoothing windows `6,6,9,9` months; signal window `9` months; long-cycle average `18` months; KST chase level `20`; stop `3.0 * ATR(14,W1)`; spread filter `0.20 * ATR(14,W1)`; time stop `12` months.

## 3. Symbol Universe

Registered DWX symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX.

The approved card also named FRA40.DWX and JP225.DWX, but those symbols are not present in `framework/registry/dwx_symbol_matrix.csv`; they are excluded from build registration.

## 4. Timeframe

Backtest setfiles use D1. Monthly cadence is derived from D1 calendar-month rollover and D1 proxy closes.

## 5. Expected Behaviour

Low-frequency trend-following behavior, roughly four trades per year per symbol. One position per symbol/magic, no pyramiding, no fixed take-profit. Entry is skipped during news blackout or excessive spread; open-position management and exits continue through news windows.

## 6. Source Citation

Martin J. Pring, *Martin Pring on Market Momentum* (McGraw-Hill, 1993), KST chapters; Martin J. Pring, *Technical Analysis Explained*, 5th ed. (McGraw-Hill, 2014), chapter 22; ForexFactory strategy thread cluster cited in the approved card.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live/demo/shadow setfiles must use `RISK_PERCENT` with `RISK_FIXED=0`. Stop loss is `3.0 * ATR(14,W1)` at entry, sized by the V5 framework.
