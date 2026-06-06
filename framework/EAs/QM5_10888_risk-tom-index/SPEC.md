# QM5_10888_risk-tom-index - Strategy Spec

**EA ID:** QM5_10888
**Slug:** risk-tom-index
**Source:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38 (see `strategy-seeds/sources/8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a long-only turn-of-month window on D1 index symbols. After each closed D1 bar, it opens a market buy at the next D1 open when the closed trading day is two scheduled trading days before the final trading day of that month. It skips entry when ATR(20,D1) is above the 95th percentile of its last 252 D1 samples, uses an initial 1.75 x ATR(20,D1) stop, and exits after the second scheduled trading day of the new month has closed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_days_before_month_end` | 2 | 1-10 | Scheduled trading days remaining in the month after the signal day. |
| `strategy_exit_trading_day_new_month` | 2 | 1-10 | New-month scheduled trading day whose close triggers exit. |
| `strategy_atr_period` | 20 | >=1 | D1 ATR period for stop distance and volatility filter. |
| `strategy_atr_stop_mult` | 1.75 | >0 | Multiplier applied to ATR(20,D1) for the initial stop. |
| `strategy_use_volatility_filter` | true | true/false | Enables the card's high-volatility entry skip. |
| `strategy_volatility_lookback_days` | 252 | >=20 | ATR sample count for the percentile threshold. |
| `strategy_volatility_percentile` | 0.95 | 0.50-0.99 | Percentile threshold; entries require current ATR at or below it. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread block; 0 disables the spread cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - matrix-valid DAX index proxy for the card's `GER40.DWX` target.
- `NDX.DWX` - Nasdaq 100 index proxy in the approved R3 basket.
- `WS30.DWX` - Dow 30 index proxy in the approved R3 basket.
- `SP500.DWX` - S&P 500 custom symbol in the approved R3 basket; backtest-only for live-routing purposes.

**Explicitly NOT for:**
- `GER40.DWX` - card label is not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewBar(_Symbol, PERIOD_D1)` for open-position calendar exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Several trading days across month-end |
| Expected drawdown profile | Gap and overnight risk during a short monthly equity-index exposure window |
| Regime preference | Index seasonality / turn-of-month |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38
**Source type:** article
**Pointer:** John Ferry, "A return to simplicity", Risk.net, 2008-02-01, https://www.risk.net/derivatives/structured-products/1510803/return-simplicity
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10888_risk-tom-index.md`

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
| v1 | 2026-06-06 | Initial build from card | 5e6f9ef2-0db5-45a4-9bca-d7b0654077b0 |
