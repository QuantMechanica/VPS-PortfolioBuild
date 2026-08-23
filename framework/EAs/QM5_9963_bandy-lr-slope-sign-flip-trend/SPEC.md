# QM5_9963_bandy-lr-slope-sign-flip-trend — Strategy Spec

**EA ID:** QM5_9963
**Slug:** `bandy-lr-slope-sign-flip-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Fit a closed-form OLS line to the latest 20 completed D1 closes, with the most
recent close at `x=0` and older closes at negative x. Go long when slope flips
from non-positive to positive while the close is above SMA(200), or short on the
opposite flip below SMA(200), provided absolute slope is at least
`0.05 * ATR(14)`. Exit on the opposite slope flip, after 45 completed bars, or
through the server-side catastrophic stop at `2.5 * ATR(14)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 only | Signal, regime, and exit timeframe |
| `strategy_slope_window` | 20 | 10–50 | Completed closes in each OLS fit |
| `strategy_regime_sma_period` | 200 | 100–300 | Long-term trend-regime SMA period |
| `strategy_min_slope_atr_mult` | 0.05 | 0.0–0.10 | Minimum absolute slope in ATR units per bar |
| `strategy_atr_period` | 14 | fixed by card | Wilder ATR period |
| `strategy_stop_atr_mult` | 2.5 | 2.0–3.0 | Catastrophic server-side stop distance |
| `strategy_max_hold_bars` | 45 | 30–60 | Completed bars before the time stop |

---

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, and `WS30.DWX` — liquid index CFDs with persistent daily trends.
- `XAUUSD.DWX` — liquid metal with meaningful daily slope regimes.
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, and `NZDUSD.DWX` — governed FX-major slots with sufficient D1 history.

**Explicitly NOT for:**

- `XTIUSD.DWX` — the card says oil is portable, but no active QM5_9963 magic row exists; governed allocation is required before a setfile can be added.
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
| Trades / year / symbol | approximately 10 |
| Typical hold time | days to 45 trading days |
| Expected drawdown profile | delayed reversals during abrupt trend changes, bounded by the ATR stop |
| Regime preference | established directional trend after a slope transition |
| Win rate target (qualitative) | medium-low, offset by trend payoff asymmetry |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`

**Source type:** book

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9963_bandy-lr-slope-sign-flip-trend.md` (Howard B. Bandy, *Quantitative Technical Analysis*, 2015, ISBN 978-0-9791037-7-1)

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per the approved card; card SHA-256 `32f26b99f2b5c8f5c02059a70c9251c504aaf8e8ea083088af7387172892fc6`.

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
| v1 | 2026-08-23 | Initial build from card | router task `8b3cc484-dc8e-494d-a3b8-3a5d0d8e5e56` |
