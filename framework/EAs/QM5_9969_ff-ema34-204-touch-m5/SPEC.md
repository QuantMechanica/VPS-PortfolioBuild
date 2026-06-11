# QM5_9969_ff-ema34-204-touch-m5 - Strategy Spec

**EA ID:** QM5_9969
**Slug:** `ff-ema34-204-touch-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA watches GBPUSD.DWX on M5 for an EMA(34) and EMA(204) cross. After a bullish cross it waits for the first later closed candle that touches EMA(34) or EMA(204), closes back above EMA(34), and passes the UK/US session, stop-distance, and spread checks; the short side mirrors this after a bearish cross. The stop is placed beyond the most recent 5-bar swing with a 1-pip buffer, TP is 2R, the stop moves to breakeven at +1R, and positions close on the opposite EMA cross or after 36 M5 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 34 | 1-500 | Fast EMA period used for cross direction and close-back confirmation. |
| `strategy_slow_ema_period` | 204 | 2-1000 | Slow EMA period used for cross direction. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for the 0.5-2.0 ATR stop-distance gate. |
| `strategy_swing_lookback_bars` | 5 | 1-50 | Closed bars used to find the swing high or low for the stop. |
| `strategy_sl_buffer_pips` | 1.0 | 0.0-10.0 | Pip buffer beyond the 5-bar swing stop. |
| `strategy_reward_r` | 2.0 | 0.5-10.0 | Fixed take-profit multiple of initial risk. |
| `strategy_min_stop_atr` | 0.5 | 0.0-5.0 | Minimum stop distance as a multiple of ATR(14). |
| `strategy_max_stop_atr` | 2.0 | 0.1-10.0 | Maximum stop distance as a multiple of ATR(14). |
| `strategy_max_spread_stop_frac` | 0.12 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |
| `strategy_session_start_hour` | 9 | 0-23 | Broker-hour start of the 07:00 London equivalent entry window. |
| `strategy_session_end_hour` | 19 | 0-23 | Broker-hour end of the 17:00 London equivalent entry window. |
| `strategy_time_stop_bars` | 36 | 1-500 | Maximum position age in M5 bars before strategy close. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - the source and card specify GBPUSD M5 as the primary and only P2 baseline symbol.

**Explicitly NOT for:**
- `EURUSD.DWX` - listed only as an optional P3 port, not part of the card's P2 basket.
- `AUDUSD.DWX` - listed only as an optional P3 port, not part of the card's P2 basket.

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
| Trades / year / symbol | `70` |
| Typical hold time | intraday, capped at 36 M5 bars |
| Expected drawdown profile | swing-trend pullback losses are bounded by one fixed-risk stop per EMA cross-state |
| Regime preference | trend pullback during UK/US liquidity |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** ForexFactory thread "EMA swing system" by `petras`, 2012.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9969_ff-ema34-204-touch-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | aa61ae47-86b7-4d2a-815a-73296283576e |
