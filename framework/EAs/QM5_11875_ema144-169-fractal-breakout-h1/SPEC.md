# QM5_11875_ema144-169-fractal-breakout-h1 - Strategy Spec

**EA ID:** QM5_11875
**Slug:** ema144-169-fractal-breakout-h1
**Source:** 22e3d41e-5d8f-526f-8327-ca08425be191 (see local PDF archive cited by the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 trend breakouts using an EMA(144/169) channel and confirmed Williams-style five-bar fractals. A buy-stop is placed when the confirmed fractal high is at or above the channel top and the fractal bar closes above both EMAs; a sell-stop is placed when the confirmed fractal low is at or below the channel bottom and the fractal bar closes below both EMAs. The stop loss is 2x ATR(14), the take profit is 4x ATR(14), and the stop is moved to breakeven once price has travelled half the TP distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 144 | >0 | Lower-period EMA used as one side of the channel. |
| strategy_ema_slow_period | 169 | >0 | Higher-period EMA used as one side of the channel. |
| strategy_fractal_side_bars | 2 | >=1 | Bars on each side of the middle bar for the Williams fractal test. |
| strategy_atr_period | 14 | >0 | ATR period for SL and TP distance. |
| strategy_sl_atr_mult | 2.0 | >0 | Stop-loss distance in ATR multiples. |
| strategy_tp_atr_mult | 4.0 | >0 | Take-profit distance in ATR multiples. |
| strategy_be_trigger_fraction | 0.50 | >0 | Fraction of TP distance required before moving SL to breakeven. |
| strategy_be_buffer_points | 0 | >=0 | Points beyond entry to use as the breakeven SL buffer. |
| strategy_session_start_utc_hour | 7 | 0-23 | UTC entry-session start for EURUSD.DWX and GBPUSD.DWX. |
| strategy_session_end_utc_hour | 18 | 0-24 | UTC entry-session end for EURUSD.DWX and GBPUSD.DWX. |
| strategy_max_spread_points | 0 | >=0 | Optional spread guard; 0 disables it because the card does not specify a spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major forex pair, session-filtered to 07:00-18:00 UTC.
- GBPUSD.DWX - card-listed major forex pair, session-filtered to 07:00-18:00 UTC.
- GBPJPY.DWX - card-listed cross-rate forex pair, allowed any time by the card.
- EURGBP.DWX - card-listed cross-rate forex pair, allowed any time by the card.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - the approved card is a forex EMA-channel and fractal-breakout strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | hours to days |
| Expected drawdown profile | Trend-breakout profile with losses during channel chop and reversals. |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 22e3d41e-5d8f-526f-8327-ca08425be191
**Source type:** local PDF archive
**Pointer:** Unknown author, Forex Strategy Vegas-Wave, local PDF archive
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11875_ema144-169-fractal-breakout-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 42494e39-aec6-4177-900e-9e715e6c4156 |
