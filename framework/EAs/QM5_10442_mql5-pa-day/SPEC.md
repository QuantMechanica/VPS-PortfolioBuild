# QM5_10442_mql5-pa-day - Strategy Spec

**EA ID:** QM5_10442
**Slug:** `mql5-pa-day`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed M15 candles during the 07:00-20:00 broker-time session. It trades long only when EMA(20) is above EMA(50), and short only when EMA(20) is below EMA(50). A long entry requires a bullish pin bar near 50-bar support, a bullish engulfing candle, or an inside-bar breakout above the mother bar; short entries mirror those rules at resistance. Stops use the larger of the fixed stop input and 1.2 * ATR(14,M15), are skipped when wider than 3.0 * ATR(14,H1), and the take-profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_M15 | M15 required | Signal timeframe from the card. |
| `strategy_fast_ema_period` | 20 | >0 | Fast EMA trend filter. |
| `strategy_slow_ema_period` | 50 | > fast EMA | Slow EMA trend filter. |
| `strategy_sr_lookback` | 50 | >=3 | Bars used for support and resistance. |
| `strategy_atr_period` | 14 | >0 | ATR period for proximity and stops. |
| `strategy_stop_loss_pips` | 30 | >0 | Source fixed stop baseline in pips. |
| `strategy_atr_stop_mult` | 1.2 | >0 | ATR multiplier used as minimum stop distance. |
| `strategy_h1_atr_stop_cap` | 3.0 | >0 | Skip trades whose stop exceeds this H1 ATR multiple. |
| `strategy_rr` | 2.0 | >0 | Take-profit reward-to-risk multiple. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour session start. |
| `strategy_session_end_hour` | 20 | 0-23 | Broker-hour session end and EOD close boundary. |
| `strategy_spread_max_points` | 35 | >=0 | Maximum allowed spread in points; 0 disables. |
| `strategy_close_eod_enabled` | true | true/false | Close open EA positions outside the session. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card R3 basket and present in the DWX matrix.
- `GBPUSD.DWX` - listed in the card R3 basket and present in the DWX matrix.
- `XAUUSD.DWX` - listed in the card R3 basket and present in the DWX matrix.
- `USDJPY.DWX` - listed in the card target symbols and present in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX` - not part of this FX/metals price-action card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` ATR stop cap |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday, normally minutes to hours. |
| Expected drawdown profile | Pattern strategy with fixed 2R exits and session flattening. |
| Regime preference | Intraday candlestick trend-following with support/resistance context. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/68704`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10442_mql5-pa-day.md`

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
| v1 | 2026-05-28 | Initial build from card | ec95e705-4fdf-42f8-94c3-84b9385decb7 |
