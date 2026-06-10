# QM5_9968_ff-ema-band-scalp-m1 - Strategy Spec

**EA ID:** QM5_9968
**Slug:** `ff-ema-band-scalp-m1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `artifacts/cards_approved/QM5_9968_ff-ema-band-scalp-m1.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades M1 pullbacks into an EMA(50) high/low/close band when the full band is on the same side of EMA(100) close. A long entry requires the last closed bar to pull back into the band and Stochastic(14,3,3) %K to cross above %D after %K was at or below 30 within the last three bars; shorts mirror the rule after an overbought cross down. The EA enters on the new M1 bar, places the stop 3 pips beyond the EMA50 band with spread and M15 ATR bounds, takes profit at 10 pips, and exits early on an opposite stochastic cross or after 20 M1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_band_period` | 50 | 1+ | EMA period for high, low, and close band. |
| `strategy_ema_trend_period` | 100 | 1+ | EMA period for close trend gate. |
| `strategy_stoch_k_period` | 14 | 1+ | Stochastic %K period. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing value. |
| `strategy_stoch_zone_lookback` | 3 | 1+ | Closed bars checked for recent 30/70 zone touch. |
| `strategy_stoch_oversold` | 30.0 | 0-100 | Long setup requires recent %K at or below this level. |
| `strategy_stoch_overbought` | 70.0 | 0-100 | Short setup requires recent %K at or above this level. |
| `strategy_stop_buffer_pips` | 3.0 | 0+ | Pip buffer beyond EMA50 band for initial stop. |
| `strategy_take_profit_pips` | 10.0 | 0+ | Fixed baseline take profit in pips. |
| `strategy_max_spread_pips` | 1.2 | 0+ | Absolute spread cap in pips. |
| `strategy_spread_stop_fraction` | 0.15 | 0-1 | Alternative spread cap as fraction of stop distance. |
| `strategy_atr_period` | 14 | 1+ | M15 ATR period for maximum stop bound. |
| `strategy_max_stop_atr_mult` | 1.2 | 0+ | Maximum stop distance as a multiple of M15 ATR. |
| `strategy_max_hold_bars` | 20 | 1+ | Maximum M1 holding period before time exit. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker-hour start of London/New York liquid session filter. |
| `strategy_session_end_hour` | 22 | 0-23 | Broker-hour end of London/New York liquid session filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary ForexFactory pair named by the card and present in the DWX FX matrix.
- `GBPUSD.DWX` - card-listed GBP major with the same M1 EMA-band scalp mechanics.
- `AUDUSD.DWX` - card-listed AUD major with the same M1 EMA-band scalp mechanics.

**Explicitly NOT for:**
- `SP500.DWX` - the card is FX-specific and does not describe index CFD behaviour.
- `XAUUSD.DWX` - not part of the card's stated FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `M15` ATR(14) for maximum stop distance |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `240` |
| Typical hold time | `1-20 minutes` |
| Expected drawdown profile | Frequent small scalps with capped stop distance and fixed 10-pip target. |
| Regime preference | EMA-band trend pullback scalp during liquid London/New York FX sessions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/1140599-emas-band-scalp-trading-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9968_ff-ema-band-scalp-m1.md`

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
| v1 | 2026-06-10 | Initial build from card | 985cd563-1f23-4729-8bdb-2b430865ce47 |
