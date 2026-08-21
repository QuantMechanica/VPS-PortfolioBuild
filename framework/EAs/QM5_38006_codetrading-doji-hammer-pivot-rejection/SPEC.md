# QM5_38006_codetrading-doji-hammer-pivot-rejection — Strategy Spec

**EA ID:** QM5_38006
**Slug:** codetrading-doji-hammer-pivot-rejection
**Source:** codetrading-doji-hammer-pivot-rejection-official-source (see `strategy-seeds/sources/codetrading-doji-hammer-pivot-rejection/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is an hourly candlestick reversal system that trades Hammer, Shooting Star, and Dragonfly Doji candlestick rejections occurring near a 50-period Exponential Moving Average (EMA 50) support/resistance zone. All pattern and indicator evaluations are performed strictly on the close of bar [1] (Shift = 1).

A Long entry is triggered when a Hammer candle is identified (Body <= 0.25 × Range, Lower Rejection Wick >= 0.60 × Range, bullish close: Close > Open), and the candle's Low is within dynamic proximity to EMA(50) (|Low - EMA(50)| <= 0.50 × ATR(14)).

A Short entry is triggered when a Shooting Star candle is identified (Body <= 0.25 × Range, Upper Rejection Wick >= 0.60 × Range, bearish close: Close < Open), and the candle's High is within dynamic proximity to EMA(50) (|High - EMA(50)| <= 0.50 × ATR(14)).

Stop Loss is set 2.0 pips beyond the candle extreme (below Hammer Low for Long, above Shooting Star High for Short). Take Profit is set at 1.8× the Stop Loss distance (1:1.8 Risk-to-Reward ratio). Open positions are moved to Break-Even (+2 points buffer) once floating profit reaches +1.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `M15-H4` | Base execution and indicator timeframe |
| `strategy_ema_period` | `50` | `20-100` | Dynamic support/resistance EMA period |
| `strategy_max_body_ratio` | `0.25` | `0.15-0.35` | Maximum candle body to range ratio |
| `strategy_min_wick_ratio` | `0.60` | `0.50-0.75` | Minimum rejection wick to range ratio |
| `strategy_zone_atr_mult` | `0.50` | `0.25-1.00` | Maximum distance from extreme to EMA(50) in ATR units |
| `strategy_atr_period` | `14` | `10-20` | ATR period for volatility distance & spread filter |
| `strategy_sl_buffer_pips` | `2.0` | `1.0-5.0` | Buffer in pips beyond candlestick extreme for SL |
| `strategy_tp_rr_mult` | `1.8` | `1.0-3.0` | Risk:Reward multiplier for take profit |
| `strategy_be_enabled` | `true` | `true/false` | Enable moving stop loss to break-even |
| `strategy_be_trigger_r` | `1.0` | `0.5-2.0` | Profit in R-multiples to trigger break-even move |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX major with stable EMA conformance on H1
- `GBPUSD.DWX` — High volatility FX major offering distinct candlestick wick rejections
- `USDJPY.DWX` — Major FX pair suitable for H1 trend pullback rejections

**Explicitly NOT for:**
- Illiquid exotic pairs or high-spread instruments where spread expansion exceeds candle reversal margins

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 4 hours to 24 hours |
| Expected drawdown profile | Low, < 5% Max Drawdown with tight structural SL |
| Regime preference | Trending Pullback / Support-Resistance Reversion |
| Win rate target (qualitative) | High (60-70%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-doji-hammer-pivot-rejection-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2022). A Simple Beginner Friendly Candle Pattern Backtested On Stocks and FX. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38006_codetrading-doji-hammer-pivot-rejection.md`

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
| v1 | 2026-08-18 | Initial build from card | Task 9b992eb5-9773-40ff-b4f3-ef03719e373e |
