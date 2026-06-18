# QM5_10975_ftmo-rsi-trend - Strategy Spec

**EA ID:** QM5_10975
**Slug:** `ftmo-rsi-trend`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10975_ftmo-rsi-trend.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H4 RSI pullbacks inside a trend range. For longs, RSI(14) must be mostly inside 40-80 over the last 20 closed bars, price must close above EMA(100), the prior RSI bar must pull below 50 while staying above 40, and the trigger bar must close back above RSI 50 while also closing above the prior candle high. Shorts mirror the rule with a 20-60 RSI range, price below EMA(100), prior RSI above 50 but below 60, and a trigger close back below RSI 50 and below the prior candle low.

Exits use a 2.0R target, a breakeven SL move after 1.0R is touched, RSI failure exits below 40 for longs or above 60 for shorts, and an 18 H4-bar time exit. Initial stops use the recent 8-bar swing low or high plus a 0.25 ATR(14) buffer.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI period for regime, pullback, trigger, and exit checks. |
| `strategy_ema_period` | 100 | 10-300 | EMA trend filter period. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop buffer and volatility floor. |
| `strategy_regime_lookback` | 20 | 5-100 | Closed bars used for the RSI trend-range count. |
| `strategy_regime_min_in_band` | 14 | 1-100 | Minimum bars that must be inside the RSI range. |
| `strategy_long_band_lo` | 40.0 | 0-100 | Lower RSI bound for long trend-range regime. |
| `strategy_long_band_hi` | 80.0 | 0-100 | Upper RSI bound for long trend-range regime. |
| `strategy_short_band_lo` | 20.0 | 0-100 | Lower RSI bound for short trend-range regime. |
| `strategy_short_band_hi` | 60.0 | 0-100 | Upper RSI bound for short trend-range regime. |
| `strategy_rsi_cross_level` | 50.0 | 0-100 | RSI re-entry trigger level. |
| `strategy_long_pb_floor` | 40.0 | 0-100 | Long pullback RSI must remain above this level. |
| `strategy_short_pb_ceil` | 60.0 | 0-100 | Short pullback RSI must remain below this level. |
| `strategy_swing_lookback` | 8 | 2-50 | Bars used to find the swing low or swing high stop anchor. |
| `strategy_swing_atr_buffer` | 0.25 | 0.0-5.0 | ATR buffer beyond the swing stop anchor. |
| `strategy_tp_rr` | 2.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_be_trigger_rr` | 1.0 | 0.5-5.0 | Profit multiple that triggers breakeven SL movement. |
| `strategy_long_exit_rsi` | 40.0 | 0-100 | Close long positions below this RSI level. |
| `strategy_short_exit_rsi` | 60.0 | 0-100 | Close short positions above this RSI level. |
| `strategy_time_exit_bars` | 18 | 1-200 | Time exit after this many H4 bars. |
| `strategy_atr_pctile_window` | 100 | 20-300 | ATR samples used for the volatility percentile floor. |
| `strategy_atr_pctile` | 25.0 | 0-100 | ATR percentile floor; entries below this are skipped. |
| `strategy_stop_min_atr_mult` | 0.5 | 0.0-10.0 | Minimum initial stop distance as a multiple of ATR. |
| `strategy_stop_max_atr_mult` | 2.5 | 0.1-20.0 | Maximum initial stop distance as a multiple of ATR. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Reject genuinely wide spread above this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with H4 DWX history.
- `GBPUSD.DWX` - card-listed major FX pair with H4 DWX history.
- `USDJPY.DWX` - card-listed major FX pair with H4 DWX history.
- `XAUUSD.DWX` - card-listed liquid metal symbol with H4 DWX history.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts require the canonical `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | H4 signal holds, capped at 18 H4 bars |
| Expected drawdown profile | Trend-pullback losses limited by swing-plus-ATR stop and fixed-risk sizing |
| Regime preference | trend-following momentum pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/en/blog/technical-analysis-whats-the-magic-of-rsi/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10975_ftmo-rsi-trend.md`

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
|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 1a6aa0de-716a-4560-bcfd-56f8a9bebabc |
