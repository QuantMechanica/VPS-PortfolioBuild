# QM5_11741_rfs-ema200-ao-h1 - Strategy Spec

**EA ID:** QM5_11741
**Slug:** rfs-ema200-ao-h1
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades an H1 trend-following rule using EMA(200) for direction and Awesome Oscillator momentum for confirmation. A long entry is allowed when the last closed H1 close is above EMA(200), AO is above zero, and AO is rising versus the prior closed bar. A short entry is allowed when the last closed H1 close is below EMA(200), AO is below zero, and AO is falling versus the prior closed bar. Exits are handled by the initial 2 x ATR(14) stop loss, 2 x ATR(14) take profit, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 200 | 1+ | EMA trend-filter period on H1 close |
| strategy_ao_fast_period | 5 | 1+ | Fast SMA period for AO on median price |
| strategy_ao_slow_period | 34 | greater than fast period | Slow SMA period for AO on median price |
| strategy_atr_period | 14 | 1+ | ATR period used for SL and TP distance |
| strategy_atr_mult | 2.0 | greater than 0 | ATR multiplier for both SL and TP |
| strategy_deadband_points | 0.0 | 0+ | Optional point deadband around EMA(200) |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with DWX H1 data.
- GBPUSD.DWX - card-listed major FX pair with DWX H1 data.
- USDJPY.DWX - card-listed major FX pair with DWX H1 data.
- USDCHF.DWX - card-listed major FX pair with DWX H1 data.
- AUDUSD.DWX - card-listed major FX pair with DWX H1 data.

**Explicitly NOT for:**
- Non-FX `.DWX` indices and commodities - card source targets major FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 60 |
| Typical hold time | SL/TP-bound H1 trades, usually intraday to multi-day |
| Expected drawdown profile | trend-following whipsaw risk around EMA(200) and AO zero-line transitions |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** website/PDF compilation
**Pointer:** Anonymous, "EMA + Awesome Oscillator", Robo-forex Strategy Compilation, `362359657-Robo-forex-strategy.pdf`, pages 52-53; approved card at `artifacts/cards_approved/QM5_11741_rfs-ema200-ao-h1.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11741_rfs-ema200-ao-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | e9fb80ab-cda2-4745-a4b3-9171c3199a12 |
