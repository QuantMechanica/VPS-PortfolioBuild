# QM5_11879_turtle-20day-breakout - Strategy Spec

**EA ID:** QM5_11879
**Slug:** turtle-20day-breakout
**Source:** 52da6bcf-0837-5552-9464-2a81d0424ac8 (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the Turtle 20-day channel breakout on D1 bars. A long signal fires when the last closed D1 bar closes above the highest high of the prior 20 D1 bars; a short signal fires when it closes below the lowest low of the prior 20 D1 bars. Entries are market orders on the next D1 bar after confirmation. Each trade receives a 2x ATR(14) stop loss and a 4x ATR(14) take profit; there is no discretionary strategy exit beyond those exits and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_donchian_period | 20 | >=1 | Number of prior D1 bars used for the breakout channel. |
| strategy_sl_atr_period | 14 | >=1 | ATR period used for stop-loss distance. |
| strategy_sl_atr_mult | 2.0 | >0 | Stop-loss distance in ATR multiples from entry. |
| strategy_tp_atr_period | 14 | >=1 | ATR period used for take-profit distance. |
| strategy_tp_atr_mult | 4.0 | >0 | Take-profit distance in ATR multiples from entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major forex pair with DWX matrix availability.
- GBPUSD.DWX - Card-listed major forex pair with DWX matrix availability.
- USDJPY.DWX - Card-listed major forex pair with DWX matrix availability.
- AUDUSD.DWX - Card-listed major forex pair with DWX matrix availability.
- USDCHF.DWX - Card-listed major forex pair with DWX matrix availability.
- USDCAD.DWX - Card-listed major forex pair with DWX matrix availability.

**Explicitly NOT for:**
- Index, metal, energy, crypto, and equity symbols - the card specifies a forex major-pair universe only.
- Forex pairs not registered for this EA - they are outside the approved card target set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Multi-day trend-following holds; exact hold-time metric is not supplied in card frontmatter. |
| Expected drawdown profile | Low win-rate breakout profile with losses capped at 2x ATR and winners targeted at 4x ATR. |
| Regime preference | Trend-following breakout / volatility expansion. |
| Win rate target (qualitative) | Low; card notes 30-40% characteristic win rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 52da6bcf-0837-5552-9464-2a81d0424ac8
**Source type:** marketing eBook / local PDF archive
**Pointer:** Unknown author, "Top 10 Best Forex Trading Strategies PDF", local PDF archive
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11879_turtle-20day-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 8b506174-d59c-4422-9be3-aff52aa0993f |
