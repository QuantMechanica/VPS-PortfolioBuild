# QM5_11578_neely-weller-pct-filter-rule-d1 - Strategy Spec

**EA ID:** QM5_11578
**Slug:** neely-weller-pct-filter-rule-d1
**Source:** 577eb0aa-7880-5c0a-a8f9-56cd126c19f9 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA mechanises the Neely & Weller D1 FX percent-filter rule. On each newly opened D1 bar it reads the prior closed-bar close, updates the running trough and peak, and fires a stop-and-reverse signal when the close rises by `strategy_filter_pct` from the tracked trough or falls by `strategy_filter_pct` from the tracked peak. A fresh opposite signal closes the current position before opening the new direction. The position has no fixed take-profit; the next opposite signal is the structural exit. A 2 x ATR(14) safety stop, capped at 150 pips by default, is applied as a hard backstop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_filter_pct` | 0.01 | 0.005-0.03 | Percent move from the tracked trough or peak that triggers a reversal signal. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used only for the safety stop. |
| `strategy_sl_atr_mult` | 2.0 | 1.0-4.0 | ATR multiplier for the safety stop distance. |
| `strategy_sl_cap_pips` | 150.0 | 50.0-300.0 | Maximum allowed safety stop distance in pips. |

Framework-level risk, news and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - approved card R3 PASS FX basket.
- `GBPUSD.DWX` - approved card R3 PASS FX basket.
- `USDJPY.DWX` - approved card R3 PASS FX basket.
- `USDCHF.DWX` - approved card R3 PASS FX basket.

**Explicitly NOT for:**
- Non-FX symbols - the source and approved card are foreign-exchange filter rules.
- Unregistered DWX symbols - this build registers only the four R3 PASS instruments above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | Days to weeks; filter rules have relatively long average trade duration in the source study |
| Expected drawdown profile | Always-in-market stop-and-reverse FX trend/filter exposure with fixed-risk sizing and ATR safety stops |
| Regime preference | Sustained directional FX moves following a percent reversal from a local extreme |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 577eb0aa-7880-5c0a-a8f9-56cd126c19f9
**Source type:** peer-reviewed / Federal Reserve FX strategy research
**Pointer:** Christopher J. Neely and Paul A. Weller, "Lessons from the Evolution of Foreign Exchange Trading Strategies", 2013
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11578_neely-weller-pct-filter-rule-d1.md`

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
| v1 | 2026-07-08 | Initial build from approved card | fe9500c8-442b-455d-8483-c489fa446c9b |
