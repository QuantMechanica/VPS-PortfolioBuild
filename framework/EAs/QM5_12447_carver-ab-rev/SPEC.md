# QM5_12447_carver-ab-rev - Strategy Spec

**EA ID:** QM5_12447
**Slug:** carver-ab-rev
**Source:** a43e8317-0d20-5fa2-95fc-8cbdb0835f0e
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed D1 bars and computes the standard deviation of the last 20 close-to-close daily moves. The first valid state enters in the configured initial direction, long by default, using the prior D1 close as the reference price. Profit-taker mode sets a target at 5 sigma and a stop at 20 sigma from that reference; loss-taker mode swaps those multipliers. When a completed D1 close crosses either the stored target or stored stop, the EA closes the open position and reverses direction on the next D1 entry evaluation.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ab_mode | AB_PROFIT_TAKER | AB_PROFIT_TAKER or AB_LOSS_TAKER | Selects A=5/B=20 profit-taker mode or A=20/B=5 loss-taker mode. |
| strategy_vol_lookback | 20 | 10-40 intended P3 range | Number of completed D1 close-to-close moves used for sigma. |
| strategy_min_history_bars | 60 | 60 or higher | Minimum completed D1 bars required before entries and median spread checks. |
| strategy_initial_direction | 1 | 1 or -1 | Initial state direction; 1 enters long, -1 enters short. |
| strategy_atr_period | 20 | 1 or higher | D1 ATR period for the V5 emergency loss stop. |
| strategy_emergency_atr_mult | 3.0 | 0.0 or higher | Mark-to-market emergency close threshold in ATR multiples; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- XTIUSD.DWX - Primary crude oil DWX port matching the source spreadsheet's crude-oil example.
- XAUUSD.DWX - Liquid metal CFD with D1 closes and volatility behaviour suitable for the same sigma reversal rule.
- GDAXI.DWX - Major index CFD listed in the card's robustness basket.
- NDX.DWX - Major US index CFD listed in the card's robustness basket.
- WS30.DWX - Major US index CFD listed in the card's robustness basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data is registered for pipeline use.
- Non-D1 synthetic variants - the card rule is defined on completed D1 closes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Expected trade frequency | Not specified in card frontmatter; card narrative implies low-frequency D1 reversals. |
| Typical hold time | Not specified in card frontmatter; held until target, stop, reversal, Friday close, or emergency ATR close. |
| Expected drawdown profile | Whipsaw risk can be high because this is an always-in-market reversal rule. |
| Regime preference | Reversal / volatility target-stop regime. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a43e8317-0d20-5fa2-95fc-8cbdb0835f0e
**Source type:** book
**Pointer:** Robert Carver, Systematic Trading, Appendix B resource spreadsheet `A and B system`; all R1-R4 PASS per `artifacts/cards_approved/QM5_12447_carver-ab-rev.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12447_carver-ab-rev.md`

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
| v1 | 2026-06-11 | Initial build from card | e3838252-c701-4588-b17a-eb627b0128aa |
