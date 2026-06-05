# QM5_10820_tv-real-strength - Strategy Spec

**EA ID:** QM5_10820
**Slug:** `tv-real-strength`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the TradingView Real Strength Scalper on the close of each M5 bar. It builds a signed Real Strength histogram from price ROC direction, tick-volume ratio versus its moving average, ADX strength scaling, and EMA smoothing. Long entries require the histogram to be above the strength threshold and rising, ADX and +DI to confirm bullish trend strength, volume ratio above threshold, and optional SMA alignment; shorts mirror those rules. Exits wait at least three bars, then close on a histogram flip through zero beyond the flip threshold while SMA still confirms, or on a 25% adverse pullback from the best favorable histogram value after the SMA filter reverses.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_strength_threshold` | 1.0 | 0.8-1.2 | Absolute Real Strength histogram threshold for entry. |
| `strategy_hist_ema_period` | 5 | 1-50 | EMA smoothing period for the fixed histogram formula. |
| `strategy_roc_period` | 1 | 1-20 | Closed-bar ROC lookback used only for momentum direction sign. |
| `strategy_adx_period` | 14 | 2-50 | ADX and DMI period. |
| `strategy_adx_min` | 14.0 | 14.0-22.0 | Minimum ADX value for trend-strength confirmation. |
| `strategy_volume_ma_period` | 20 | 2-100 | Tick-volume moving-average lookback for participation ratio. |
| `strategy_volume_ratio_min` | 1.2 | 1.0-1.5 | Minimum tick-volume ratio for entry. |
| `strategy_sma_filter_enabled` | true | true/false | Enables the SMA trend alignment filter. |
| `strategy_sma_fast_period` | 30 | 20-30 | Fast SMA period for trend alignment. |
| `strategy_sma_slow_period` | 60 | 50-60 | Slow SMA period for trend alignment. |
| `strategy_min_hold_bars` | 3 | 0-20 | Minimum hold before strategy exits are allowed. |
| `strategy_flip_threshold` | 0.8 | 0.1-2.0 | Opposite-zone histogram threshold for flip exits. |
| `strategy_best_hist_pullback` | 0.25 | 0.0-1.0 | Adverse pullback fraction from best favorable histogram after SMA reversal. |
| `strategy_stop_mode` | `STRATEGY_STOP_FIXED_PERCENT` | fixed percent / ATR | Selects source fixed-percent stop or ATR-normalized stop. |
| `strategy_fixed_stop_pct` | 1.0 | 0.1-5.0 | Static source stop distance as percent of entry price. |
| `strategy_atr_period` | 14 | 2-50 | ATR period for ATR stop mode. |
| `strategy_atr_stop_mult` | 1.2 | 1.2-1.8 | ATR multiple for ATR stop mode. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with M5 tick volume and ADX/DMI coverage.
- `GBPUSD.DWX` - card-listed liquid FX major with M5 tick volume and ADX/DMI coverage.
- `USDJPY.DWX` - card-listed liquid FX major with M5 tick volume and ADX/DMI coverage.
- `XAUUSD.DWX` - canonical DWX form of the card's `XAUUSD` metal symbol.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's unavailable `GER40.DWX`.
- `NDX.DWX` - card-listed liquid US index proxy.
- `WS30.DWX` - card-listed liquid US index proxy.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - unsuffixed research/backtest symbol name; use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `220` |
| Typical hold time | `at least 3 M5 bars; scalping hold profile` |
| Expected drawdown profile | `high-cadence momentum scalper; sensitive to spread, slippage, and stop distance` |
| Regime preference | `momentum-continuation with volume and trend-strength confirmation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/iCRFM0LS/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10820_tv-real-strength.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 107bca8a-d6c4-4fb3-a12e-aacdcb50ae6f |
