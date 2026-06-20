# QM5_9935_bandy-mn1-rsi-setup-w1-rsi-trigger-mr-index - Strategy Spec

**EA ID:** QM5_9935
**Slug:** `bandy-mn1-rsi-setup-w1-rsi-trigger-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA is a long-only weekly mean-reversion strategy for index CFDs. On each closed W1 bar it enters long when the D1 monthly-proxy RSI is at or below 35, the W1 RSI is at or below 25, and the W1 close is above the 50-week SMA regime filter. The catastrophic stop is 4.0 times W1 ATR(14) below entry. The position closes when W1 RSI reaches 55 or higher, or after an 8-week time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_monthly_proxy_rsi_days` | 126 | 2+ | D1 RSI period used as the 6-month MN1 proxy for DWX tester compatibility. |
| `strategy_monthly_rsi_max` | 35.0 | 0-100 | Maximum monthly-proxy RSI allowed for long setup. |
| `strategy_weekly_rsi_period` | 4 | 2+ | W1 RSI trigger and exit period. |
| `strategy_weekly_rsi_entry_max` | 25.0 | 0-100 | Maximum W1 RSI allowed for long entry. |
| `strategy_weekly_rsi_exit_min` | 55.0 | 0-100 | W1 RSI level that exits the long position. |
| `strategy_weekly_regime_sma` | 50 | 2+ | W1 SMA period used as the long-term regime filter. |
| `strategy_atr_period_w1` | 14 | 2+ | W1 ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 4.0 | >0 | ATR multiple below entry for the stop loss. |
| `strategy_time_stop_weeks` | 8 | 1+ | Maximum holding period in weeks. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy named in the card R3 section; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index proxy named in the card R3 section for portable validation.
- `WS30.DWX` - Dow 30 index proxy named in the card R3 section for portable validation.

**Explicitly NOT for:**
- Forex, metals, energies, and non-US country index CFDs - the card specifies long-only US index mean reversion.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` - not canonical DWX matrix symbols for S&P 500 exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `W1` |
| Multi-timeframe refs | `PERIOD_D1` RSI(126) as MN1 proxy; `PERIOD_W1` RSI(4), SMA(50), ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `6` |
| Typical hold time | Up to 8 weeks; earlier exit when W1 RSI reaches 55 or higher. |
| Expected drawdown profile | Wide ATR stop with multi-week mean-reversion drawdowns possible. |
| Regime preference | Mean-reversion after multi-month index sell-offs while W1 close remains above the 50-week SMA. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850, URL https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9935_bandy-mn1-rsi-setup-w1-rsi-trigger-mr-index.md`

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
| v1 | 2026-06-20 | Initial build from card | c0b7a6d1-27ba-480b-a301-29956a6f75df |
