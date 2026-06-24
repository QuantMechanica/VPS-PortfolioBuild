# QM5_9244_mql5-matrix-score - Strategy Spec

**EA ID:** QM5_9244
**Slug:** mql5-matrix-score
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On each closed H1 bar, the EA reads a 50-bar close-price window and calculates a linear-regression slope, window momentum, and sample volatility. The composite score is `0.4 * trend + 0.3 * momentum - 0.3 * volatility`. A long entry fires when the prior score was positive, the current score crosses below -10, price is above EMA(200), and the cooldown has elapsed; a short entry uses the mirrored +10 threshold with price below EMA(200). Long exits occur when the score crosses back above zero or price closes below EMA(200); short exits occur when the score crosses back below zero or price closes above EMA(200), with a 48-bar failsafe time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_score_window | 50 | 3+ | Number of closed H1 closes used in the matrix score. |
| strategy_trend_weight | 0.4 | fixed coefficient | Linear-regression slope coefficient from the card. |
| strategy_momentum_weight | 0.3 | fixed coefficient | Close-window momentum coefficient from the card. |
| strategy_volatility_weight | -0.3 | fixed coefficient | Sample-volatility coefficient from the card. |
| strategy_buy_threshold | -10.0 | real number | Exhaustion threshold for long entries. |
| strategy_sell_threshold | 10.0 | real number | Exhaustion threshold for short entries. |
| strategy_ema_period | 200 | 1+ | EMA trend filter period. |
| strategy_cooldown_bars | 3 | 0+ | Minimum closed bars between entry signals. |
| strategy_atr_period | 14 | 1+ | ATR period for initial stop distance. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for stop placement. |
| strategy_take_rr | 2.4 | >0 | Initial take-profit multiple of stop risk. |
| strategy_max_hold_bars | 48 | 1+ | Failsafe maximum holding time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed forex target with DWX history.
- GBPJPY.DWX - Card-listed forex target with DWX history.
- GDAXI.DWX - DWX matrix-backed DAX instrument used for the card's GER40 exposure.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.

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
| Trades / year / symbol | 75 |
| Typical hold time | Up to 48 H1 bars |
| Expected drawdown profile | Medium, ATR-defined single-position risk with 2.4R take-profit. |
| Regime preference | Momentum exhaustion with EMA trend filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/21837
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9244_mql5-matrix-score.md`

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
| v1 | 2026-06-25 | Initial build from card | 57501d02-89b5-4078-b676-f19be1fc4f7a |
