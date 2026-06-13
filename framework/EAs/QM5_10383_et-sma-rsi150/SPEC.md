# QM5_10383_et-sma-rsi150 - Strategy Spec

**EA ID:** QM5_10383
**Slug:** `et-sma-rsi150`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades M5 index bars using a 150-period simple moving average as the regime filter and RSI(5) as the entry and exit trigger. It enters long on the next bar when the last closed bar is above SMA(150) and RSI(5) crosses below 30, and it enters short when the last closed bar is below SMA(150) and RSI(5) crosses above 70. Long positions close when RSI(5) crosses above 70, short positions close when RSI(5) crosses below 30, and any open position also closes at the configured broker-time session close. Initial stop loss is 0.75 times ATR(20) on M5, with entries skipped when the stop distance is less than four current spreads.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 150 | 100-200 tested | SMA regime length. |
| `strategy_rsi_period` | 5 | 3-7 tested | RSI signal length. |
| `strategy_rsi_oversold` | 30.0 | 25.0-35.0 tested | Long-entry and short-exit RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | 65.0-75.0 tested | Short-entry and long-exit RSI threshold. |
| `strategy_atr_period` | 20 | positive integer | ATR period for the initial stop. |
| `strategy_atr_stop_mult` | 0.75 | 0.75-1.0 tested | ATR multiplier for the initial stop distance. |
| `strategy_min_stop_spreads` | 4.0 | positive number | Skip entries where stop distance is below this many current spreads. |
| `strategy_session_close_hhmm` | 2200 | 0000-2359 | Broker-time session close used for flat-at-close exits. |
| `strategy_no_entry_last_min` | 30 | non-negative integer | Blocks new entries in the final minutes before session close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Direct S&P 500 / ES-equivalent backtest port from the source strategy.
- `NDX.DWX` - Liquid US large-cap index CFD analog for live-eligible validation.
- `WS30.DWX` - Liquid US large-cap index CFD analog for live-eligible validation.
- `GDAXI.DWX` - Matrix-verified DAX 40 proxy for the card's `GER40.DWX` basket member.

**Explicitly NOT for:**
- `GER40.DWX` - Card-listed symbol is not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPY.DWX`, `ES.DWX`, `SPX500.DWX` - Not canonical DWX symbols for this framework.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Intraday, from RSI threshold entry until opposite RSI threshold or session close. |
| Expected drawdown profile | High-turnover intraday mean reversion with source-reported negative backtest risk. |
| Regime preference | RSI mean reversion under SMA trend filter on liquid index data. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/backtest-this-strategy.32674/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10383_et-sma-rsi150.md`

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
| v1 | 2026-06-13 | Initial build from card | a4f96e85-ee76-4318-8926-638888fa0d60 |
