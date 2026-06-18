# QM5_1228_carver-volatten-ewmac - Strategy Spec

**EA ID:** QM5_1228
**Slug:** carver-volatten-ewmac
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades the D1 EWMAC trend direction from Rob Carver's rule: EMA(close, Fast) minus EMA(close, Slow), with Slow fixed at 4 x Fast by default. The raw EWMAC forecast is divided by recent daily percentage volatility, multiplied by a fixed forecast scalar, and then attenuated by a volatility-percentile factor that reduces exposure when current volatility is high versus its own history. It opens long when the final forecast is above +4 and short when it is below -4. It closes a long when the EWMAC forecast sign is no longer positive, closes a short when the sign is no longer negative, and uses a 2.5 x ATR(20, D1) emergency stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_period | 16 | 8-64 P3 sweep | EWMAC fast EMA period. |
| strategy_slow_multiplier | 4 | fixed by card | Multiplies Fast to derive Slow. |
| strategy_vol_period | 25 | fixed by card | Daily percentage-return volatility window. |
| strategy_vol_history_bars | 2500 | >=500 for P1 smoke | Lookback used for volatility percentile rank. |
| strategy_attenuation_ema | 10 | fixed by card | EMA smoothing period for the attenuation factor. |
| strategy_forecast_scalar | 10.0 | positive | User-visible scalar for the card's "usual EWMAC forecast scalar". |
| strategy_entry_threshold | 4.0 | fixed by card | Forecast threshold for new long/short entries. |
| strategy_forecast_cap | 20.0 | fixed by card | Absolute forecast clamp. |
| strategy_attenuation_min | 0.25 | fixed by card | Lower attenuation bound. |
| strategy_attenuation_max | 2.0 | fixed by card | Upper attenuation bound. |
| strategy_atr_period | 20 | fixed by card | ATR period for emergency stop. |
| strategy_atr_stop_mult | 2.5 | 2.0-3.0 P3 sweep | ATR multiple for emergency stop distance. |
| strategy_min_bars | 500 | >= max(Slow+50,500) | Minimum history before trading. |
| strategy_spread_median_days | 20 | fixed by card | D1 spread median window. |
| strategy_spread_cap_mult | 2.0 | fixed by card | Skip entries when spread exceeds this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- AUDCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- AUDJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- AUDNZD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- AUDUSD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- CADCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- CADJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- CHFJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURAUD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURCAD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURGBP.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURNZD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- EURUSD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPAUD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPCAD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPNZD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GBPUSD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- GDAXI.DWX - DWX index OHLC series fits the card's price-only trend and volatility inputs.
- NDX.DWX - DWX index OHLC series fits the card's price-only trend and volatility inputs.
- NZDCAD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- NZDCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- NZDJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- NZDUSD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- SP500.DWX - DWX custom S&P 500 OHLC series fits the card's price-only trend and volatility inputs for backtest.
- UK100.DWX - DWX index OHLC series fits the card's price-only trend and volatility inputs.
- USDCAD.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- USDCHF.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- USDJPY.DWX - DWX forex OHLC series fits the card's price-only trend and volatility inputs.
- WS30.DWX - DWX index OHLC series fits the card's price-only trend and volatility inputs.
- XAGUSD.DWX - DWX metals OHLC series fits the card's price-only trend and volatility inputs.
- XAUUSD.DWX - DWX metals OHLC series fits the card's price-only trend and volatility inputs.
- XNGUSD.DWX - DWX energy OHLC series fits the card's price-only trend and volatility inputs.
- XTIUSD.DWX - DWX energy OHLC series fits the card's price-only trend and volatility inputs.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX tick data for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | multi-day to multi-week trend-following holds |
| Expected drawdown profile | Trend-following whipsaws in range-bound or volatility-spike regimes. |
| Regime preference | trend with volatility-regime attenuation |
| Win rate target (qualitative) | medium-low, with payoff skew expected from trend following |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** https://qoppac.blogspot.com/2021/03/does-it-make-sense-to-change-your.html and https://qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1228_carver-volatten-ewmac.md`

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
| v1 | 2026-06-18 | Initial build from card | 1fc621cf-2625-4426-acdf-32ebbc834284 |
