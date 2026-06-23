# QM5_11290_tc20-smma55-band-wpr-stoch-h1 - Strategy Spec

**EA ID:** QM5_11290
**Slug:** tc20-smma55-band-wpr-stoch-h1
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades the H1 close crossing a smoothed moving-average price channel. A long setup requires the latest closed bar to cross above SMMA(55) applied to high prices, Williams %R(55) to cross above -25, and Stochastic(5,5,5) %K to be above %D. A short setup mirrors the rule with a close below SMMA(55) applied to low prices, Williams %R(55) crossing below -75, and Stochastic %K below %D. Entries use ATR(14) x 1.5 stop loss and a 2R take-profit; discretionary exits close a long when the latest closed bar falls back below the high-band SMMA and close a short when it rises back above the low-band SMMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_smma_period | 55 | >=2 | Period for the SMMA high/low channel. |
| strategy_wpr_period | 55 | >=2 | Williams Percent Range period. |
| strategy_wpr_long_level | -25.0 | -100.0 to 0.0 | Long threshold crossed upward by WPR. |
| strategy_wpr_short_level | -75.0 | -100.0 to 0.0 | Short threshold crossed downward by WPR. |
| strategy_stoch_k | 5 | >=1 | Stochastic %K period. |
| strategy_stoch_d | 5 | >=1 | Stochastic %D period. |
| strategy_stoch_slowing | 5 | >=1 | Stochastic slowing period. |
| strategy_atr_period | 14 | >=1 | ATR period for stop distance. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiple used for stop loss. |
| strategy_rr_tp | 2.0 | >0 | Take-profit multiple of initial risk. |
| strategy_spread_cap_pips | 20 | >=1 | Maximum modeled spread in pips; zero spread is allowed for DWX tester data. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - this section lists
> only strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 forex pair for the TC20 strategy.
- GBPUSD.DWX - Card-listed H1 forex pair for the TC20 strategy.
- USDJPY.DWX - Card-listed P2 expansion symbol for the same FX H1 setup.

**Explicitly NOT for:**
- Non-FX `.DWX` indices, metals, and energy symbols - the source card defines a forex strategy and names only FX pairs for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Not specified in the card; exits are by 2R TP, ATR stop, Friday close, or closed-bar channel re-entry. |
| Expected drawdown profile | Trend-following FX channel strategy with ATR-normalized per-trade risk. |
| Regime preference | Trend-following / channel-breakout momentum. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book / local PDF archive
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (1 Hour Time Frame)`, Forex Trading Strategy #5, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11290_tc20-smma55-band-wpr-stoch-h1.md`

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
| v1 | 2026-06-23 | Initial build from card | 7d45908a-8730-48b5-b7ee-ec56d6bf6b2a |
