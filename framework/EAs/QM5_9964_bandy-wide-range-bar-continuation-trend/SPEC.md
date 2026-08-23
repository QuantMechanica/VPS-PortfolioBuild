# QM5_9964_bandy-wide-range-bar-continuation-trend — Strategy Spec

**EA ID:** QM5_9964
**Slug:** `bandy-wide-range-bar-continuation-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On each completed D1 bar, go long when three-way true range is at least
`2.0 * ATR(14)`, the close is in the upper quarter of the bar, and the close is
above SMA(200); reverse those directional tests for a short. Suppress a signal
when a same-direction entry occurred in the prior three trading bars or a
high-impact calendar event occurred during the signal bar, then enter at the
next bar's first available price. Exit at the next bar after the close crosses
the 22-bar Chandelier (`2.5 * ATR(14)`), after 30 completed bars, or through the
server-side catastrophic stop at `2.5 * ATR(14)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 only | Signal, regime, and exit timeframe |
| `strategy_atr_period` | 14 | fixed by card | Wilder ATR period |
| `strategy_wide_range_atr_mult` | 2.0 | 1.5–2.5 | Minimum true range in ATR units |
| `strategy_close_position_level` | 0.75 | 0.70–0.85 | Directional close-position threshold |
| `strategy_regime_sma_period` | 200 | 100–300 | Trend-regime SMA period |
| `strategy_chandelier_lookback` | 22 | 14–30 | Highest-high / lowest-low exit window |
| `strategy_chandelier_atr_mult` | 2.5 | 2.0–3.0 | Chandelier ATR offset |
| `strategy_stop_atr_mult` | 2.5 | 2.0–3.0 | Catastrophic server-side stop distance |
| `strategy_anti_cluster_days` | 3 | fixed by card | Same-direction entry suppression window |
| `strategy_max_hold_bars` | 30 | 20–45 | Completed bars before the time stop |

---

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, and `WS30.DWX` — liquid index CFDs suited to daily volatility-expansion continuation.
- `XAUUSD.DWX` — liquid metal with persistent daily expansion regimes.
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, and `NZDUSD.DWX` — governed liquid FX-major slots with daily history.

**Explicitly NOT for:**

- `XTIUSD.DWX` — the card says oil is portable, but no active QM5_9964 magic row exists; governed allocation is required before a setfile can be added.
- Symbols outside the 13 active magic-registry rows — no ad-hoc or alias allocation is permitted.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 |
| Typical hold time | days to one month |
| Expected drawdown profile | clustered false expansions and Chandelier whipsaws in choppy regimes |
| Regime preference | directional volatility expansion aligned with the long-term trend |
| Win rate target (qualitative) | medium-low, offset by trend payoff asymmetry |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`

**Source type:** book

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9964_bandy-wide-range-bar-continuation-trend.md` (Howard B. Bandy, *Quantitative Technical Analysis*, 2015, ISBN 978-0-9791037-7-1)

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per the approved card; card SHA-256 `568d4ea5704fb39ccfaf2cfd6f9b05a2b58c7b7de96efbfbf5b87527c892605`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The governed backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours=336`; no live or AutoTrading authorization is granted.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from card | router task `037f7a25-4931-4fe9-a5f5-1eef6bacd073` |
