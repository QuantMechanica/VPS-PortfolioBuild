# QM5_1537_aa-vol-sma10 — Strategy Spec

**EA ID:** QM5_1537
**Slug:** `aa-vol-sma10`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

A high-realized-volatility trend-timing sleeve, ported from Han/Yang/Zhou's
simple-moving-average timing result as summarized by Alpha Architect. Each
registered symbol is admitted to the "sleeve" only while its own trailing
252-day annualized realized volatility (daily log-return stdev, recomputed
once per calendar month) is at or above a floor (default 15% annualized) —
a per-symbol proxy for the paper's cross-sectional "top volatility decile /
top 3" universe selection. While admitted, the EA trades a pure long/cash
10-day SMA timing rule on D1 closes: go long when the D1 close crosses above
SMA(10), exit to cash when the D1 close crosses below SMA(10). A position is
also flattened immediately if the symbol drops out of the volatility sleeve
at a monthly recompute. Initial stop loss is 2.5x ATR(14, D1) from entry;
there is no trailing stop, break-even, or partial close (source-faithful
baseline). One position per symbol/magic — no pyramiding.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 10 | 5-50 | SMA(period, D1) timing MA for entry/exit cross |
| `strategy_min_daily_bars` | 270 | >= `strategy_sma_period` | Minimum D1 history before symbol is eligible (card requirement) |
| `strategy_atr_period` | 14 | 5-30 | ATR(period, D1) used for the initial stop loss |
| `strategy_atr_sl_mult` | 2.5 | 0.5-5.0 | Initial SL = entry -/+ `strategy_atr_sl_mult` x ATR(14, D1) |
| `strategy_vol_lookback_days` | 252 | 60-504 | Trailing daily-return window for the realized-volatility sleeve gate |
| `strategy_min_annualized_vol_pct` | 15.0 | 0-100 | Annualized realized-vol floor (%) a symbol must clear to be in the high-vol sleeve |
| `strategy_max_spread_points` | 0 | 0-500 | Optional spread guard; 0 = disabled (DWX quotes 0 spread in the tester) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `XAUUSD.DWX` — metal, typically high realized volatility; natural high-vol sleeve candidate
- `XAGUSD.DWX` — metal, typically high realized volatility; natural high-vol sleeve candidate
- `XNGUSD.DWX` — energy (natural gas), typically very high realized volatility
- `XTIUSD.DWX` — energy (crude oil), typically high realized volatility
- `NDX.DWX` — Nasdaq 100 index, typically elevated realized volatility among equity indices
- `WS30.DWX` — Dow 30 index, elevated realized volatility
- `GDAXI.DWX` — DAX 40 index, elevated realized volatility
- `UK100.DWX` — FTSE 100 index, elevated realized volatility
- `SP500.DWX` — S&P 500 index (backtest alias; live routes via bare `SP500`), elevated realized volatility

**Explicitly NOT for:**
- FX majors/crosses (e.g. `EURUSD.DWX`, `USDJPY.DWX`) — trailing realized volatility is
  typically well below the sleeve floor, so these were not registered; the runtime
  `strategy_min_annualized_vol_pct` gate would keep them flat by design anyway.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (D1 chart) for entry cadence; `QM_IsNewCalendarPeriod(PERIOD_MN1)` for the monthly volatility-sleeve recompute |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Days (per SMA(10) whipsaw cadence) |
| Expected drawdown profile | Trend-following whipsaw losses in choppy regimes; sleeve gate caps exposure to genuinely high-vol names |
| Regime preference | trend / volatility-expansion |
| Win rate target (qualitative) | low-medium (trend-timing systems typically win < 50% of trades, profit from few large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog (academic summary)
**Pointer:** https://alphaarchitect.com/technical-analysis-may-actually-work/ — Wesley Gray, PhD, "Technical Analysis may actually work!", 2010-05-19, summarizing Han, Yang, and Zhou
**R1–R4 verdict (Q00):** all PASS — R1 lineage recorded and R2-R4 PASS per `artifacts/cards_approved/QM5_1537_aa-vol-sma10.md`

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
| v1 | 2026-08-12 | Initial build from card | fa1fd187-eccb-4e11-bd71-a16531a61530 |
