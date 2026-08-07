# QM5_9912_bandy-zscore-returns-5d-mr-index — Strategy Spec

**EA ID:** QM5_9912
**Slug:** `bandy-zscore-returns-5d-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-04

---

## 1. Strategy Logic

On each completed D1 bar, the EA calculates the latest five-day log return and compares it with the distribution of the latest 20 overlapping five-day log returns. It buys at the next bar open when that return has a z-score at or below -2.0 and the completed close remains above its 200-day simple moving average. It exits at the next bar open when the z-score reaches zero, after eight completed trading bars, or through the catastrophic stop placed 2.5 times ATR(14) below entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_window` | 5 | 3 / 5 / 7 / 10 | Trading days in each overlapping log return. |
| `strategy_zscore_lookback` | 20 | 10 / 20 / 30 | Number of rolling return observations used for the mean and population standard deviation. |
| `strategy_entry_z` | -2.0 | -2.5 / -2.0 / -1.5 | Maximum z-score that permits a long entry. |
| `strategy_exit_z` | 0.0 | -0.5 / 0.0 / 0.5 | Z-score recovery level that closes the position. |
| `strategy_regime_sma_period` | 200 | 100 / 200 / 300 | D1 simple-moving-average regime lookback. |
| `strategy_atr_period` | 14 | fixed | D1 ATR period for the catastrophic stop. |
| `strategy_atr_stop_mult` | 2.5 | fixed | ATR multiple placed below the entry price. |
| `strategy_time_stop_bars` | 8 | 5 / 8 / 12 | Maximum completed D1 trading bars held. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 backtest alias for the card's primary US large-cap index exposure.
- `NDX.DWX` — liquid Nasdaq 100 index proxy included in the card's portable R3 basket.
- `WS30.DWX` — liquid Dow 30 index proxy included in the card's portable R3 basket.

**Explicitly NOT for:**

- Individual equities, forex, and commodities — the baseline is the card's long-only broad US-index mean-reversion rule; broader cross-asset testing is outside this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewCalendarPeriod(PERIOD_D1)` for restart-safe D1 exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 32 |
| Expected trade frequency | approximately 2–3 entries per month per symbol, clustered during index pullbacks |
| Typical hold time | up to 8 trading days; usually shorter when the return z-score recovers to zero |
| Expected drawdown profile | clustered losses during persistent selloffs that continue through the 2.5×ATR backstop |
| Regime preference | mean reversion during pullbacks while price remains above the 200-day bull-regime average |
| Win rate target (qualitative) | medium to high, with occasional larger catastrophic-stop losses |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9912_bandy-zscore-returns-5d-mr-index.md`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9912_bandy-zscore-returns-5d-mr-index.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-04 | Initial build from card | e4e171e1-b5e4-4257-9f54-92a2c4e98a86 |
