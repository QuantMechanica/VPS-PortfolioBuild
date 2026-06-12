# QM5_10272_ltz-turtle20 - Strategy Spec

**EA ID:** QM5_10272
**Slug:** ltz-turtle20
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see approved card source links)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the long side only on D1 bars. It opens a market buy when the most recent closed bar closes above the highest high of the prior 20 bars, excluding the signal bar. It sets the initial stop at entry price minus 2 times ATR(14). It closes an open long when the most recent closed bar closes below the lowest low of the prior 10 bars, excluding the signal bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_lookback | 20 | 1+ | Donchian high breakout lookback in closed bars. |
| strategy_exit_lookback | 10 | 1+ | Donchian low exit lookback in closed bars. |
| strategy_atr_period | 14 | 1+ | ATR period used for the initial stop. |
| strategy_atr_stop_mult | 2.0 | >0 | ATR multiplier for the initial long stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 port of the source SPX universe; valid for backtest-only Custom Symbol use.
- NDX.DWX - Nasdaq 100 provides a liquid US large-cap index trend-following validation target.
- WS30.DWX - Dow 30 provides a live-tradable US large-cap index validation target.
- XAUUSD.DWX - Gold is listed in the card R3 basket for trend-following validation.

**Explicitly NOT for:**
- SPX500.DWX - not present in the DWX symbol matrix.
- SPY.DWX - not present in the DWX symbol matrix.
- ES.DWX - not present in the DWX symbol matrix.

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
| Trades / year / symbol | 10 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following whipsaws during range-bound markets, controlled by 2x ATR initial stop. |
| Regime preference | breakout / trend |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/letianzj/QuantResearch/blob/master/backtest/turtle.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10272_ltz-turtle20.md`

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
| v1 | 2026-06-12 | Initial build from card | 2a18daec-29b0-4ed4-9bc4-8ba943216c90 |
