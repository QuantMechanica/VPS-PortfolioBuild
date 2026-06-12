# QM5_10273_ltz-ghost - Strategy Spec

**EA ID:** QM5_10273
**Slug:** ltz-ghost
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see approved card source links)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA evaluates D1 closed bars. A long setup exists when EMA(3) is above EMA(21), RSI(9) is below 70, and the last closed bar makes a higher high than the prior bar; the first setup records a ghost long at that bar close, and a later long setup opens a market buy only if the close is below the ghost price. A short setup mirrors the rule with EMA(3) below EMA(21), RSI(9) above 30, and a lower low than the prior bar; it opens a market sell only after a later short setup closes above the ghost price. Long positions exit when the last closed close is at or below the prior 21-bar Donchian low; short positions exit when the last closed high is at or above the prior 21-bar Donchian high.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 3 | 1+ | Fast EMA period for trend direction. |
| strategy_slow_ema_period | 21 | 1+ | Slow EMA period for trend direction. |
| strategy_rsi_period | 9 | 1+ | RSI period used as an overbought/oversold gate. |
| strategy_rsi_overbought | 70.0 | 0-100 | Maximum RSI allowed for long setups. |
| strategy_rsi_oversold | 30.0 | 0-100 | Minimum RSI allowed for short setups. |
| strategy_donchian_exit | 21 | 1+ | Prior-bar Donchian exit window. |
| strategy_atr_period | 14 | 1+ | ATR period for the catastrophic stop. |
| strategy_atr_stop_mult | 2.0 | >0 | ATR multiplier for the catastrophic stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 port of the source SPX universe; valid for backtest-only Custom Symbol use.
- NDX.DWX - Nasdaq 100 provides a liquid US large-cap index validation target.
- WS30.DWX - Dow 30 provides a live-tradable US large-cap index validation target.
- XAUUSD.DWX - Gold is listed in the card R3 basket for validation.

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
| Trades / year / symbol | 15 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following whipsaws when EMA direction changes without sustained follow-through, controlled by 2x ATR catastrophic stop. |
| Regime preference | trend-following with Donchian exits |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/letianzj/QuantResearch/blob/master/backtest/ghost_trader.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10273_ltz-ghost.md`

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
| v1 | 2026-06-12 | Initial build from card | fbae3c9d-5f1d-439d-8159-a34b19d9755c |
