# QM5_10799_tv-mtf-pullback - Strategy Spec

**EA ID:** QM5_10799
**Slug:** `tv-mtf-pullback`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades M15 pullback continuations in the direction of an H4 EMA trend. A long entry requires the last completed H4 close to be above a rising H4 EMA, price to remain above that EMA while pulling back from a recent H4 swing high, RSI to turn up from oversold/pullback territory or show bullish divergence, and a bullish engulfing candle to appear on the execution timeframe. Short entries mirror the same logic below a falling H4 EMA, with RSI turning down or bearish divergence and a bearish engulfing candle. Exits use the card's fixed 2.0 percent target and 2.0 x ATR(14) stop, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_tf` | `PERIOD_H4` | H1-H4 tested | Higher timeframe used for EMA trend and swing pullback context. |
| `strategy_ema_period` | `50` | 50-100 | EMA period for the higher-timeframe trend filter. |
| `strategy_rsi_period` | `14` | 7-28 | RSI period for pullback reversal and divergence checks. |
| `strategy_rsi_oversold` | `30.0` | 20-40 | Deep oversold threshold for long pullback reversal. |
| `strategy_rsi_pullback` | `40.0` | 30-50 | Softer long pullback threshold from the card. |
| `strategy_rsi_overbought` | `70.0` | 60-80 | Deep overbought threshold for short pullback reversal. |
| `strategy_rsi_rally` | `60.0` | 50-70 | Softer short pullback threshold from the card. |
| `strategy_atr_period` | `14` | 7-28 | ATR period used for stop distance. |
| `strategy_atr_sl_mult` | `2.0` | 1.5-2.5 | Stop distance multiplier applied to ATR. |
| `strategy_take_profit_pct` | `2.0` | 1.0-3.0 | Fixed percentage target from entry price. |
| `strategy_swing_lookback` | `12` | 6-24 | Completed H4 bars used to define the recent swing high or swing low. |
| `strategy_div_lookback` | `8` | 4-16 | Completed execution-timeframe bars used for RSI divergence comparison. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major forex pair from the card's portable P2 basket.
- `GBPUSD.DWX` - Major forex pair from the card's portable P2 basket.
- `USDJPY.DWX` - Major forex pair from the card's portable P2 basket.
- `XAUUSD.DWX` - Canonical DWX form of card-stated `XAUUSD`.
- `GDAXI.DWX` - Canonical DAX DWX symbol used in place of card-stated `GER40.DWX`.
- `NDX.DWX` - Nasdaq 100 index from the card's portable P2 basket.
- `WS30.DWX` - Dow 30 index from the card's portable P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `XAUUSD` - Missing `.DWX` suffix; backtests must use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | H4 EMA(50), H4 swing high/low; H1/H4 variants are parameter-test candidates |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Intraday to multi-day, bounded by ATR stop, fixed target, and Friday close |
| Expected drawdown profile | Moderate; continuation entries can lose during choppy pullbacks and failed reversals |
| Regime preference | Trend pullback continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy script`
**Pointer:** `https://www.tradingview.com/script/KQlCorH0-DANI-MTF-Pullback-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10799_tv-mtf-pullback.md`

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
| v1 | 2026-06-05 | Initial build from card | 5c07576f-639f-4615-bd1f-ccd5f52589c5 |
