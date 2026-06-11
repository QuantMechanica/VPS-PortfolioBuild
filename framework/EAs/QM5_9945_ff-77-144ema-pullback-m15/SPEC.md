# QM5_9945_ff-77-144ema-pullback-m15 - Strategy Spec

**EA ID:** QM5_9945
**Slug:** ff-77-144ema-pullback-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see ForexFactory source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades M15 pullbacks to EMA(77) in the direction of the EMA(77) versus shifted EMA(144) trend filter. A long setup requires EMA(77) above EMA(144) shifted by 77 bars, a positive 12-bar EMA(77) slope, at least 5 prior bars without touching EMA(77), then a completed bar that touches or pierces EMA(77) and closes back above it; the short side mirrors these rules. The initial stop is the smaller of the swing-target distance and 1.5 x ATR(14), the target is the recent 20-bar swing high/low unless that is more than 2.0R away, in which case TP is capped at 1.5R. Open trades exit via SL/TP, Friday close, or an adverse completed M15 close across EMA(77).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M15 | PERIOD_M15 | Signal timeframe from the approved card. |
| strategy_fast_ema_period | 77 | > 0 | Pullback EMA and slope line. |
| strategy_slow_ema_period | 144 | > 0 | Trend baseline EMA period. |
| strategy_slow_ema_shift | 77 | >= 0 | Shift applied to the slow EMA comparison. |
| strategy_slope_bars | 12 | > 0 | EMA(77) slope lookback in closed bars. |
| strategy_fresh_touch_bars | 5 | >= 0 | Required prior bars without EMA(77) touch. |
| strategy_swing_lookback | 20 | > 0 | Swing high/low target lookback in closed bars. |
| strategy_atr_period | 14 | > 0 | ATR period for the maximum initial stop distance. |
| strategy_atr_sl_mult | 1.5 | > 0 | Maximum stop width as ATR multiple. |
| strategy_tp_cap_r | 1.5 | > 0 | TP distance when swing target exceeds the cap threshold. |
| strategy_tp_cap_threshold_r | 2.0 | > 0 | Swing target threshold that activates the TP cap. |
| strategy_session_start_hour | 7 | 0-23 | Inclusive broker-time session start hour. |
| strategy_session_end_hour | 18 | 0-23 | Exclusive broker-time session end hour. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M15 major FX pair with DWX data.
- GBPUSD.DWX - card-listed M15 major FX pair with DWX data.
- USDJPY.DWX - card-listed M15 major FX pair with DWX data.
- AUDUSD.DWX - card-listed M15 major FX pair with DWX data.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the approved card is specific to M15 major FX pairs.
- FX pairs outside the R3 basket - not registered for P2 saturation in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Intraday M15 pullback holds; expected minutes to a few hours. |
| Expected drawdown profile | Fixed-risk trend-pullback losses when fresh EMA touches fail to continue. |
| Regime preference | Trend-pullback with clean EMA(77) slope. |
| Win rate target (qualitative) | Medium, because baseline reward is near 1R to 1.5R. |

Frontmatter frequency note: M15 dual-EMA pullback; estimate 80-140 trades/year/symbol after fresh-touch and trend filters.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** jamesagnew, "144 x 77 ema and 77 ema method", ForexFactory, 2025, https://www.forexfactory.com/thread/1323194-144-x-77-ema-and-77-ema-method
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9945_ff-77-144ema-pullback-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 07c5e8d6-5de2-4c5b-b45d-535449a70e5f |
