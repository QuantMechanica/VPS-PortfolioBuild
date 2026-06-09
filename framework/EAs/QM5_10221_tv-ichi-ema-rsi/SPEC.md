# QM5_10221_tv-ichi-ema-rsi - Strategy Spec

**EA ID:** QM5_10221
**Slug:** `tv-ichi-ema-rsi`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long-only H4 cloud breakouts. It opens a long when the active Ichimoku Senkou Span A is above Senkou Span B, the last closed H4 candle is bullish and closes above Senkou Span A, EMA fast is above EMA slow, and Stochastic RSI K is above D. It closes the long when a bearish closed H4 candle finishes below Senkou Span A. The protective stop is the lower of the recent swing low or 2.5 ATR below entry; no take-profit, trailing stop, partial close, or short entry is added.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Base timeframe for all strategy signals. |
| `strategy_tenkan_period` | 9 | >= 1 | Ichimoku Tenkan lookback. |
| `strategy_kijun_period` | 26 | >= 1 | Ichimoku Kijun lookback. |
| `strategy_senkou_b_period` | 52 | >= 1 | Ichimoku Senkou Span B lookback. |
| `strategy_displacement` | 26 | >= 0 | Standard Ichimoku forward displacement used to read the active cloud. |
| `strategy_ema_fast_period` | 50 | >= 1 | EMA1 period for the baseline-on EMA filter. |
| `strategy_ema_slow_period` | 200 | >= 1 | EMA2 period for the baseline-on EMA filter. |
| `strategy_rsi_period` | 14 | >= 1 | RSI period used by Stochastic RSI. |
| `strategy_stoch_rsi_period` | 14 | >= 2 | RSI min/max lookback for Stochastic RSI. |
| `strategy_stoch_rsi_smooth_k` | 3 | >= 1 | Smoothing length for Stochastic RSI K. |
| `strategy_stoch_rsi_smooth_d` | 3 | >= 1 | Smoothing length for Stochastic RSI D. |
| `strategy_swing_lookback` | 10 | >= 1 | Recent-bar low lookback for the structure stop. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the volatility stop. |
| `strategy_atr_sl_mult` | 2.5 | > 0 | ATR multiple used for the protective stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair suitable for H4 trend/cloud signals.
- `GBPJPY.DWX` - liquid FX cross with sustained directional H4 moves.
- `XAUUSD.DWX` - liquid gold CFD explicitly called out by the card as a preferred port.
- `NDX.DWX` - liquid US index CFD suitable for the trend-following concept.
- `GDAXI.DWX` - DWX matrix DAX symbol used as the available port for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | H4 multi-bar trend holds; exact hold time not specified by card |
| Expected drawdown profile | Volatility and structure-stop bounded trend-following losses |
| Regime preference | trend / cloud breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** TradingView script `Ichimoku EMA RSI - Crypto only long Strategy`, author `TradingStrategyCheck`, https://www.tradingview.com/script/IYQMk5fS/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10221_tv-ichi-ema-rsi.md`

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
| v1 | 2026-06-09 | Initial build from card | 1703ea45-cb86-4502-a04a-4bc3389e4a51 |
