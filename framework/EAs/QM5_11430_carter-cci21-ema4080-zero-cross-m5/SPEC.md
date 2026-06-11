# QM5_11430_carter-cci21-ema4080-zero-cross-m5 - Strategy Spec

**EA ID:** QM5_11430
**Slug:** carter-cci21-ema4080-zero-cross-m5
**Source:** ec63ff86-b6dd-522b-ac8e-d90de82e2dee (see `strategy-seeds/sources/ec63ff86-b6dd-522b-ac8e-d90de82e2dee/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the M5 CCI(21) zero line cross only in the direction of the EMA trend filter. It buys when EMA40 is above EMA80 and CCI(21) moves from below zero on bar 2 to zero or higher on bar 1. It sells when EMA40 is below EMA80 and CCI(21) moves from above zero on bar 2 to zero or lower on bar 1. Each entry uses fixed 12-pip stop loss and 12-pip take profit orders.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_cci_period | 21 | 1+ | CCI lookback used for the zero-cross signal. |
| strategy_ema_fast_period | 40 | 1+ | Fast EMA period for trend direction. |
| strategy_ema_slow_period | 80 | 1+ | Slow EMA period for trend direction. |
| strategy_sl_pips | 12 | 1-15 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 12 | 1-15 | Fixed take-profit distance in pips. |
| strategy_max_spread_pips | 10.0 | >0 | Maximum allowed entry spread in pips. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid FX major with M5 DWX data.
- GBPUSD.DWX - Card-listed liquid FX major with M5 DWX data.
- USDJPY.DWX - Card-listed liquid FX major with M5 DWX data.
- AUDUSD.DWX - Card-listed liquid FX major with M5 DWX data.

**Explicitly NOT for:**
- Non-card symbols - The card names only the four FX pairs above for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | High-frequency fixed 1:1 scalp drawdowns; losses cluster in choppy zero-cross regimes. |
| Regime preference | intraday momentum with EMA trend alignment |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ec63ff86-b6dd-522b-ac8e-d90de82e2dee
**Source type:** book
**Pointer:** John Carter, "20 Strategies for the 5-Minute Timeframe", local PDF in strategy archive.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11430_carter-cci21-ema4080-zero-cross-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | b903db38-8a79-439a-a531-8ab711f64cc0 |
