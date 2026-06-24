# QM5_11823_carter-m5-s13-cci14-macd-m5 - Strategy Spec

**EA ID:** QM5_11823
**Slug:** carter-m5-s13-cci14-macd-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see `strategy-seeds/sources/f4430cee-7efb-592e-bf0f-e469ef156b2d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the M5 chart when CCI(14) breaks out through the +/-100 levels and MACD(12,26,9) confirms momentum on the same closed bar. It opens long when CCI(14) closes above +100 after being at or below +100 on the prior closed bar and the MACD histogram is positive. It opens short when CCI(14) closes below -100 after being at or above -100 on the prior closed bar and the MACD histogram is negative. Positions exit only through the fixed stop loss, fixed take profit, or framework Friday/news/kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 2-200 | CCI lookback period. |
| `strategy_cci_level` | 100.0 | 1.0-300.0 | Positive CCI breakout threshold; the short side uses the negative value. |
| `strategy_macd_fast` | 12 | 2-100 | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | 3-200 | Slow EMA period for MACD. |
| `strategy_macd_signal` | 9 | 2-100 | Signal EMA period for MACD. |
| `strategy_sl_pips` | 13 | 1-100 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 10 | 1-100 | Fixed take-profit distance in pips. |
| `strategy_spread_pct_of_stop` | 25.0 | 0.0-100.0 | Blocks entries only when modeled spread is wider than this percent of the stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated target FX symbol with M5 DWX data available.
- GBPUSD.DWX - card-stated target FX symbol with M5 DWX data available.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the approved card names only EURUSD.DWX and GBPUSD.DWX.

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
| Trades / year / symbol | 150 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Frequent small fixed-pip losses with asymmetric 10-pip targets against 13-pip stops. |
| Regime preference | momentum / breakout |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** book / PDF
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, Strategy 13; local PDF `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11823_carter-m5-s13-cci14-macd-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 407ecfed-b5ef-4680-b11b-53e767b33c14 |
