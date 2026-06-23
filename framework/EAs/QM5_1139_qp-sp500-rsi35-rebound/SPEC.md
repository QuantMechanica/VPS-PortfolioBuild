# QM5_1139_qp-sp500-rsi35-rebound - Strategy Spec

**EA ID:** QM5_1139
**Slug:** qp-sp500-rsi35-rebound
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a long-only SP500.DWX daily RSI rebound. On each completed D1 bar it reads RSI(14); if RSI crosses below 35 from above, the EA opens one long position on the next tradable D1 tester bar. It closes the position when closed-bar RSI(14) is above 55, or after 10 trading days if the RSI exit has not fired. The initial hard stop is 2.0 times D1 ATR(20) below the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 2-100 | D1 RSI period used for entry and exit. |
| `strategy_entry_rsi` | 35.0 | 1.0-99.0 | Long entry trigger threshold; RSI must cross below this level. |
| `strategy_exit_rsi` | 55.0 | 1.0-99.0 | Strategy exit threshold; closed-bar RSI above this level closes the position. |
| `strategy_min_d1_closes` | 60 | 3-500 | Minimum D1 history proxy required before first signal. |
| `strategy_time_stop_days` | 10 | 1-60 | Maximum weekday trading-day hold if RSI exit has not fired. |
| `strategy_atr_period` | 20 | 2-200 | D1 ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-20.0 | ATR multiple for the initial stop distance. |
| `strategy_spread_median_mult` | 3.0 | 0.0-20.0 | Blocks only when current spread is above this multiple of the prior M30 median spread. |
| `strategy_spread_lookback_days` | 20 | 1-252 | M30 spread median lookback in trading-day units. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - The approved card maps the source SPY/SP500 exposure to the canonical S&P 500 custom symbol.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - These are not the canonical available DWX S&P 500 symbol.
- `NDX.DWX`, `WS30.DWX` - The card body documents these only as possible T6 live-promotion validation routes, not as this EA's Q02 baseline universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `M30` spread median only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `500` from card frontmatter |
| Typical hold time | Up to 10 trading days |
| Expected drawdown profile | Mean-reversion losses are controlled by a 2.0 x ATR hard stop. |
| Regime preference | Mean-revert / equity-index timing |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** Quantpedia encyclopedia article
**Pointer:** https://quantpedia.com/automated-trading-edge-analysis/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1139_qp-sp500-rsi35-rebound.md`

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
| v1 | 2026-06-23 | Initial build from card | 2bc5e4d6-31e3-4767-b180-3475ee815b48 |
