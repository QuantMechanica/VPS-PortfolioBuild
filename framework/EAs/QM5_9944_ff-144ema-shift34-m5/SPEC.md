# QM5_9944_ff-144ema-shift34-m5 - Strategy Spec

**EA ID:** QM5_9944
**Slug:** ff-144ema-shift34-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the M5 close crossing a 34-period EMA displaced 16 bars forward. A long entry requires the prior completed M5 close to be at or below that shifted EMA, the latest completed close to break above it, price to be above EMA(144), and the EMA(144) slope over 12 bars to be non-negative. A short entry mirrors the same conditions below the shifted EMA and below EMA(144), with non-positive EMA(144) slope. Exits occur through the fixed 17-pip target, the EMA(144)-based stop, a close back across the shifted EMA, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M5 | M5 | Signal timeframe from the card. |
| strategy_shifted_ema_period | 34 | 1+ | Entry trigger EMA period. |
| strategy_shifted_ema_forward_shift | 16 | 0+ | Forward displacement of the trigger EMA. |
| strategy_boundary_ema_period | 144 | 1+ | Trend and stop-boundary EMA period. |
| strategy_boundary_slope_bars | 12 | 1+ | Bars used to test EMA(144) slope direction. |
| strategy_target_pips | 17 | 1+ | Fixed target in pips. |
| strategy_stop_buffer_pips | 2 | 0+ | Extra stop buffer beyond EMA(144). |
| strategy_max_initial_stop_pips | 17 | 1+ | P2 cap for initial EMA-based risk. |
| strategy_max_stop_target_r | 1.8 | 0.1+ | Card hard cap versus the 17-pip target. |
| strategy_session_start_hour | 7 | 0-23 | Broker-time session start. |
| strategy_session_end_hour | 17 | 0-23 | Broker-time session end, exclusive. |
| strategy_max_hold_bars | 24 | 1+ | Maximum M5 bars to hold a trade. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed FX major with DWX M5 data.
- GBPUSD.DWX - Card-listed FX major with DWX M5 data.
- USDJPY.DWX - Card-listed FX major with DWX M5 data.
- AUDUSD.DWX - Card-listed FX major with DWX M5 data.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the card specifies FX majors and fixed pip targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Up to 24 M5 bars, approximately 2 hours maximum |
| Expected drawdown profile | Scalping fixed-target profile with stop capped to 17 pips in P2 baseline |
| Regime preference | M5 shifted-EMA breach scalper during 07:00-17:00 broker time |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/1348501-144-ema-method
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9944_ff-144ema-shift34-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 5e83b247-e048-4a59-8442-edf8e186e1c4 |
