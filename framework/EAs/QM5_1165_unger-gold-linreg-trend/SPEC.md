# QM5_1165_unger-gold-linreg-trend - Strategy Spec

**EA ID:** QM5_1165
**Slug:** `unger-gold-linreg-trend`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades XAUUSD.DWX on H1 when the last completed close breaks out of a linear-regression channel. It fits a line to the last `strategy_lr_period` completed H1 closes, computes the residual standard deviation, then sets upper and lower trigger levels at `line +/- strategy_lr_dev * residual_stdev`. A long entry fires when the completed close crosses above the upper trigger; a short entry fires when it crosses below the lower trigger. Exits are the ATR stop/target, a close back across the regression line, or the maximum hold time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 expected | Signal timeframe from the card. |
| `strategy_lr_period` | 40 | >=5 | Completed H1 closes used for linear regression. |
| `strategy_lr_dev` | 1.0 | >0 | Residual standard-deviation multiplier for upper/lower trigger levels. |
| `strategy_atr_period` | 14 | >=1 | ATR period for stop and target distance. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for stop loss. |
| `strategy_atr_tp_mult` | 4.0 | >0 | ATR multiplier for take profit. |
| `strategy_max_hold_bars` | 72 | >=1 | Time stop in H1 bars, matching the card's few-session horizon. |
| `strategy_trade_start_hour_broker` | 1 | 0-23 | Start of broker-hour entry window for liquid gold trading. |
| `strategy_trade_end_hour_broker` | 23 | 0-23 | End of broker-hour entry window; open positions remain managed outside it. |
| `strategy_max_spread_points` | 250 | >=0 | Wide-spread block in points; zero modeled spread is allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - directly available Darwinex gold CFD and the card's R3 PASS instrument for the gold futures source idea.

**Explicitly NOT for:**
- Index, FX, energy, and equity symbols - the card is gold-specific and does not authorize cross-asset expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with H1 setfile/chart period |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Expected trade frequency | Frequent H1 breakout strategy on gold; roughly multiple trades per week. |
| Typical hold time | Up to 72 H1 bars; earlier on regression-line re-cross or SL/TP. |
| Expected drawdown profile | Trend-breakout losses cluster during choppy sideways gold regimes. |
| Regime preference | Gold trend-following and volatility expansion. |
| Win rate target (qualitative) | Medium-low with larger ATR target than stop. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** Unger Academy article and supporting book
**Pointer:** `https://ungeracademy.com/blog/strategy-of-the-month-march-2025-a-trend-following-strategy-on-gold-futures`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1165_unger-gold-linreg-trend.md`

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
| v1 | 2026-06-23 | Initial build from card | 49f419cd-8c70-46c4-a5d3-40f18ac178e3 |
