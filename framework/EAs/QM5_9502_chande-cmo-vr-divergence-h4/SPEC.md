# QM5_9502 Chande CMO VR Divergence H4

**EA ID:** QM5_9502

## 1. Strategy Logic

H4 reversal strategy using Chande Momentum Oscillator divergence only after a Chande volatility-ratio trending gate. On each new H4 bar the EA evaluates the latest closed signal bar and the immediately preceding pivot candidate. A sell setup requires a confirmed price pivot high, a prior pivot high 6 to 30 H4 bars earlier, a price higher high, a CMO lower high, prior CMO above +35, CMO turning down, and the signal close below the pivot close. A buy setup mirrors this with pivot lows, price lower low, CMO higher low, prior CMO below -35, and upside confirmation.

Stops are placed at the signal pivot extreme plus or minus 0.5 ATR(14). Exits occur on CMO zero-cross in the trade direction or after 20 H4 bars. The framework provides magic resolution, position opening and closing, risk sizing, kill-switch, Friday close, and central news filtering.

## 2. Parameters

- `strategy_cmo_period = 14`
- `strategy_vr_fast_atr = 7`
- `strategy_vr_slow_atr = 28`
- `strategy_vr_min = 1.30`
- `strategy_pivot_left_bars = 5`
- `strategy_pivot_sep_min = 6`
- `strategy_pivot_sep_max = 30`
- `strategy_cmo_extreme_level = 35.0`
- `strategy_atr_period = 14`
- `strategy_sl_atr_mult = 0.50`
- `strategy_time_stop_bars = 20`
- `strategy_spread_atr_frac_max = 0.20`
- `strategy_shorts_enabled = true`

## 3. Symbol Universe

Registered portable DWX symbols from the approved card:

`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`.

The card also lists `FRA40.DWX` and `JP225.DWX`; both are omitted because they are absent from `framework/registry/dwx_symbol_matrix.csv` at build time.

## 4. Timeframe

Primary timeframe is H4. The EA blocks trading when attached to any other chart period. All signal reads use closed H4 bars.

## 5. Expected Behaviour

Expected cadence from the card is approximately 20 trades per year per symbol. The build is low-frequency relative to intraday scalpers and is intended to add price-only FX/commodity/index diversity to the Q02 funnel. It uses one open position per magic slot, no pyramiding, no grid, no martingale, and no adaptive or ML component.

## 6. Source Citation

Tushar Chande and Stanley Kroll, *The New Technical Trader*, Wiley 1994, chapters 5 and 6, plus the approved strategy card `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9502_chande-cmo-vr-divergence-h4.md`.

## 7. Risk Model

Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Live risk input remains available as `RISK_PERCENT` per V5 HR4, but no live deployment or T_Live manifest was touched in this build.
