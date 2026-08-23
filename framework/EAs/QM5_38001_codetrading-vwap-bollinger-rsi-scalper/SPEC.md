# QM5_38001_codetrading-vwap-bollinger-rsi-scalper — Strategy Spec

**EA ID:** QM5_38001
**Slug:** codetrading-vwap-bollinger-rsi-scalper
**Source:** codetrading-vwap-bollinger-rsi-scalper-official-source (see `strategy-seeds/sources/codetrading-vwap-bollinger-rsi-scalper/`)
**Author of this spec:** Development
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The strategy is an intraday mean-reversion scalper on the M5 timeframe combining
UTC-day Session VWAP, Bollinger Bands (20, 2.0), and RSI(14). The EA reconstructs
the closed-bar session VWAP from UTC midnight on initialization, a day change,
or a detected bar gap, and otherwise advances it once per contiguous M5 bar.

A Long entry is triggered when the previous closed bar's Low penetrates or touches the Lower Bollinger Band, the Close is below the Session VWAP, RSI(14) is oversold (<= 30.0), and the candle is bullish (Close > Open). A Short entry is triggered when the previous bar's High penetrates or touches the Upper Bollinger Band, the Close is above Session VWAP, RSI(14) is overbought (>= 70.0), and the candle is bearish (Close < Open). 

Stop Loss is set at 1.5× ATR(14) from entry price. Take Profit targets the
Session VWAP when that line remains favorable at entry, with the card's 1.8R
fallback otherwise. At +1.0 times the original broker-side stop distance, the
stop moves to the exact normalized entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | `PERIOD_M5` | Base execution and indicator timeframe |
| `strategy_bb_period` | `20` | `14-30` | Bollinger Bands moving average period |
| `strategy_bb_dev` | `2.00` | `1.5-2.5` | Bollinger Bands standard deviation multiplier |
| `strategy_rsi_period` | `14` | `7-21` | RSI oscillator period |
| `strategy_rsi_oversold` | `30.0` | `20.0-35.0` | RSI oversold threshold for Long entries |
| `strategy_rsi_overbought` | `70.0` | `65.0-80.0` | RSI overbought threshold for Short entries |
| `strategy_atr_period` | `14` | `10-20` | ATR period for volatility-based SL distance |
| `strategy_atr_sl_mult` | `1.5` | `1.0-2.5` | Multiplier on ATR for stop loss placement |
| `strategy_tp_rr_mult` | `1.8` | `1.0-3.0` | Fallback Risk:Reward multiplier for take profit |
| `strategy_use_vwap_tp` | `true` | `true/false` | Whether to dynamically target Session VWAP for TP |
| `strategy_be_enabled` | `true` | `true/false` | Enable moving stop loss to break-even |
| `strategy_be_trigger_r` | `1.0` | `0.5-2.0` | Profit in R-multiples to trigger break-even move |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |
| `strategy_max_slippage_ticks` | `3` | `1` or greater | Maximum market-order deviation in trade ticks |
| `strategy_daily_loss_halt_pct` | `2.0` | `(0, daily hard stop]` | Account realized-loss entry halt |
| `strategy_daily_hard_stop_pct` | `2.5` | positive | Restart-safe daily equity hard stop |
| `strategy_total_dd_halt_pct` | `5.0` | positive | Account-level total drawdown stop |
| `strategy_per_trade_risk_cap_pct` | `0.5` | `(0, 1.0]` | Framework per-trade risk cap |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary high-liquidity FX major with tight spread and high mean-reverting efficiency on M5
- `GBPUSD.DWX` — Liquid FX major with strong intraday volatility around session VWAP
- `USDJPY.DWX` — Major FX pair suitable for M5 intraday mean-reversion

**Explicitly NOT for:**
- Illiquid exotic currency pairs or wide-spread crypto CFDs where spread expansion degrades scalping expectancy

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` with `PERIOD_M5` enforced at initialization |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | 30 minutes to 4 hours |
| Expected drawdown profile | Low, < 3% Max Drawdown with rapid mean-reversion resolution |
| Regime preference | Mean-reversion / Ranging / Session Volatility |
| Win rate target (qualitative) | High (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-vwap-bollinger-rsi-scalper-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2022). Python Backtest of a Scalping Strategy with VWAP, Bollinger Bands and RSI. YouTube Channel Archive.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38001_codetrading-vwap-bollinger-rsi-scalper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 33322516-1797-4d97-8a74-eb4fd7385953 |
| v2 | 2026-08-23 | Codex remediation of mandatory review | Restart-safe UTC session VWAP, current-bar admission, reachable exact +1R BE, card risk rails and three-tick deviation |
