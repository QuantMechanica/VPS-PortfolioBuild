# QM5_11782_sma520-cross-scalp-m15 - Strategy Spec

**EA ID:** QM5_11782
**Slug:** `sma520-cross-scalp-m15`
**Source:** `83b41d71-f371-5e5f-aed0-df9f9d01a565` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a simple SMA(5) and SMA(20) crossover on M15 forex-major charts. A long entry is opened when the last closed bar has SMA(5) above SMA(20) after being at or below it on the prior bar. A short entry is opened when the last closed bar has SMA(5) below SMA(20) after being at or above it on the prior bar. Each trade uses a fixed 5-pip stop and a 1:1 take-profit; there is no trailing stop or discretionary close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_fast_period` | 5 | 2-50 | Fast SMA period used in the crossover trigger. |
| `strategy_sma_slow_period` | 20 | 5-200 | Slow SMA period used in the crossover trigger. |
| `strategy_sl_pips` | 5 | 1-100 | Fixed stop-loss distance in pips. |
| `strategy_tp_rr` | 1.0 | 0.1-10.0 | Take-profit multiple of stop distance; 1.0 is the card's fixed 5-pip TP. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source example and tight-spread forex major.
- `GBPUSD.DWX` - card-listed M15 DWX forex major.
- `USDJPY.DWX` - card-listed M15 DWX forex major.
- `USDCHF.DWX` - card-listed M15 DWX forex major.
- `AUDUSD.DWX` - card-listed M15 DWX forex major.
- `USDCAD.DWX` - card-listed M15 DWX forex major.

**Explicitly NOT for:**
- Non-DWX symbols - outside the QuantMechanica backtest symbol matrix for this build.
- Wide-spread exotic FX symbols - the card notes the 5-pip TP/SL is spread-sensitive.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | minutes to a few M15 bars; fixed 5-pip TP/SL scalp |
| Expected drawdown profile | many small losses during sideways periods, capped by fixed 5-pip stops |
| Regime preference | trend-following scalp; source warns sideways markets are poor |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `83b41d71-f371-5e5f-aed0-df9f9d01a565`
**Source type:** `PDF / retail strategy note`
**Pointer:** `481460064-Top3ScalpingStrategies.pdf`, pages 2-4
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11782_sma520-cross-scalp-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | 62f6c1c1-21be-4758-8f46-4c6640ba5895 |
