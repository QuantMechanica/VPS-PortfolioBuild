# QM5_10258_tv-rsi-macd-mtf - Strategy Spec

**EA ID:** QM5_10258
**Slug:** `tv-rsi-macd-mtf`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5` (TradingView script page cited by the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA is a long-only multi-timeframe reversal strategy. It opens a market buy on a closed H4 execution bar when the latest closed D1 RSI(14) is below 30 and the H4 MACD(12,26,9) line crosses above its signal line. It closes the long when the latest closed D1 RSI is above 70 and the H4 MACD line crosses below its signal line, or when the position has been open for 60 H4 bars. The protective stop is set at entry to 2.5 times H4 ATR(14), with position size delegated to the V5 framework risk model.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_execution_tf` | `PERIOD_H4` | H4 expected | Timeframe used for MACD confirmation, ATR stop, and max-hold bar count. |
| `strategy_rsi_tf` | `PERIOD_D1` | D1 expected | Higher timeframe used for the RSI exhaustion filter. |
| `strategy_rsi_period` | `14` | `1+` | RSI lookback period. |
| `strategy_rsi_oversold` | `30.0` | `0-100` | Daily RSI must be below this level for long entry. |
| `strategy_rsi_overbought` | `70.0` | `0-100` | Daily RSI must be above this level for signal exit. |
| `strategy_macd_fast` | `12` | `1+` | Fast EMA period for H4 MACD. |
| `strategy_macd_slow` | `26` | `fast+1+` | Slow EMA period for H4 MACD. |
| `strategy_macd_signal` | `9` | `1+` | Signal EMA period for H4 MACD. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | Multiplier applied to H4 ATR for the initial stop. |
| `strategy_max_hold_h4_bars` | `60` | `0+` | Emergency time stop in H4 bars; `0` disables this stop. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary card symbol and liquid Nasdaq 100 index port for the source index strategy.
- `WS30.DWX` - liquid Dow 30 index port from the card's portable DWX basket.
- `GDAXI.DWX` - canonical local DAX symbol; used in place of the card text `GER40.DWX`, which is not in `dwx_symbol_matrix.csv`.
- `XAUUSD.DWX` - card-listed liquid gold CFD port with DWX history in the matrix.
- `EURUSD.DWX` - card-listed liquid FX port with DWX history in the matrix.

**Explicitly NOT for:**
- Symbols outside the registered set above - this EA has no symbol-agnostic universe expansion.
- `GER40.DWX` - not present in the local DWX matrix; `GDAXI.DWX` is the registered canonical DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` RSI(14), `H4` MACD(12,26,9), `H4` ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; H4 closed-bar cadence for exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | Up to `60` H4 bars, with signal exits expected earlier when RSI and MACD reverse. |
| Expected drawdown profile | Single-position fixed-risk exposure bounded by the 2.5 x ATR protective stop and V5 risk controls. |
| Regime preference | Momentum-reversal after daily oversold exhaustion and H4 momentum turn. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** TradingView public Pine script
**Pointer:** `https://www.tradingview.com/script/Epqb0L8C-RSI-MACD-Multi-Timeframe-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10258_tv-rsi-macd-mtf.md`

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
| v1 | 2026-06-10 | Initial build from card | 04d4a671-70ba-45ed-941e-cb7c5de76295 |
