# QM5_11525_ciurea-stoch1435-bounce-h4 - Strategy Spec

**EA ID:** QM5_11525
**Slug:** ciurea-stoch1435-bounce-h4
**Source:** 0192e348-5570-531c-9110-7954a36caca2 (see `sources/ciurea-cristina-scientific-forex`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a Stochastic(14,3,5) bounce on H4. It enters long when the Stochastic main line closes back above 20 after being at or below 20 on the prior closed bar, and enters short when it closes back below 80 after being at or above 80 on the prior closed bar. The stop is placed 3 pips beyond the most adverse low or high of the last 3 closed H4 bars, capped at 80 pips for P2, and the take-profit is fixed at 2R. Friday entries are skipped.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_stoch_k_period | 14 | >=1 | Stochastic K period from the card. |
| strategy_stoch_d_period | 3 | >=1 | Stochastic D period from the card. |
| strategy_stoch_slowing | 5 | >=1 | Stochastic slowing period from the card. |
| strategy_oversold_level | 20.0 | 0-100 | Long trigger level crossed upward. |
| strategy_overbought_level | 80.0 | 0-100 | Short trigger level crossed downward. |
| strategy_structure_bars | 3 | >=1 | Closed bars used for the stop extreme. |
| strategy_sl_buffer_pips | 3 | >=1 | Pip buffer beyond the 3-bar extreme. |
| strategy_max_sl_pips | 80 | >=1 | P2 maximum stop distance. |
| strategy_tp_rr | 2.0 | >0 | Take-profit multiple of initial risk. |
| strategy_spread_cap_pips | 15 | >=1 | Maximum non-zero spread allowed for entry. |
| strategy_skip_friday_entry | true | true/false | Blocks new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - Source-specified positive H4 result and card primary instrument.
- EURUSD.DWX - Card-listed portable FX comparison instrument for P3 expansion; registered now per P2 saturation rule.

**Explicitly NOT for:**
- Non-DWX symbols - Pipeline and registry require canonical DWX symbols for backtest.
- Non-FX symbols - Card evidence is specific to GBP/USD and EUR/USD H4 FX behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 123 |
| Expected trade frequency | not specified in card frontmatter; source sample implies about 123 trades/year on GBPUSD.DWX |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | Stochastic mean-reversion bounce after oversold or overbought exhaustion |
| Win rate target (qualitative) | low to medium; source reports 34.56 percent on GBP/USD H4 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0192e348-5570-531c-9110-7954a36caca2
**Source type:** self-published article / PDF
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, circa 2012
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11525_ciurea-stoch1435-bounce-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 76fa6557-3ccc-46c1-8844-28eac018ce8b |
