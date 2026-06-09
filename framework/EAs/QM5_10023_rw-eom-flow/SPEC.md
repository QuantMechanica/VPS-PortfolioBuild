# QM5_10023_rw-eom-flow — Strategy Spec

**EA ID:** QM5_10023
**Slug:** `rw-eom-flow`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (see `strategy-seeds/sources/dcbac84f-6ecf-5d21-9630-50faa69306ec/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Enters long on SP500.DWX, NDX.DWX, and WS30.DWX at the close of the trading day that is exactly three trading days before the end of the calendar month, provided the 20-day realized annualized volatility is below its 252-day rolling median. The rationale is to capture price-insensitive month-end equity rebalancing flow before it prints. The position exits at the close of the first trading day of the following month. An initial hard stop of 1.5 × ATR(14, D1) protects against catastrophic loss; there is no take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_days_before_eom` | 3 | 1–5 | Trading days before month-end at which to enter long |
| `strategy_rv_days` | 20 | 5–60 | Rolling window for realized volatility (log-return std dev) |
| `strategy_rv_median_days` | 252 | 60–504 | Lookback for computing the RV median threshold |
| `strategy_use_vol_filter` | true | true/false | Enable/disable the 252-day RV median volatility filter |
| `strategy_atr_period` | 14 | 5–30 | ATR period for initial stop-loss distance |
| `strategy_atr_stop_mult` | 1.5 | 0.5–4.0 | ATR multiplier for initial stop distance |
| `strategy_max_spread_points` | 0 | 0–500 | Maximum allowed spread in points; 0 = disabled |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 broad equity index; directly exposed to US institutional month-end rebalancing flow; backtest-only
- `NDX.DWX` — Nasdaq 100 large-cap tech; correlated US index with live-tradable routing
- `WS30.DWX` — Dow Jones 30 blue-chip; correlated US index with live-tradable routing

**Explicitly NOT for:**
- Forex pairs — flow effect is equity-index-specific
- Commodities — no structural month-end equity-bond rebalancing analog

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one candidate per month, filtered by vol regime) |
| Typical hold time | 1–3 calendar days (entry T-3 to exit T+1 of next month) |
| Expected drawdown profile | Low trade count; wide ATR stop; drawdowns event-driven |
| Regime preference | Flow-driven seasonality; best in low-volatility up-trending regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** blog / public strategy article
**Pointer:** Robot Wealth / Kris Longmore, "If your edge is so good, why share it?", https://robotwealth.com/if-your-edge-is-so-good-why-share-it/; Robot Wealth Index of Strategies, End-of-Month Flow Effects section, https://robotwealth.com/index-of-strategies/#end-of-month-flow-effects
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10023_rw-eom-flow.md`

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
| v1 | 2026-06-10 | Initial build from card | eb82250f-6174-4274-9673-69aebd11c924 |
