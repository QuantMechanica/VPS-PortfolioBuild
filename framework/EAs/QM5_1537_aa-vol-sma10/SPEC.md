# QM5_1537_aa-vol-sma10 — Strategy Spec

**EA ID:** QM5_1537
**Slug:** `aa-vol-sma10`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-13

---

## 1. Strategy Logic

Once per calendar month, every EA instance calculates the annualized standard deviation of 252 closed D1 log returns for all 37 portable DWX symbols and ranks them from highest to lowest volatility. The three highest-volatility symbols form the active sleeve, provided each has at least 270 closed D1 bars. An active symbol enters long at the next D1 open after its close crosses above SMA(10), and it exits at the next D1 open after a cross below or when the next monthly rank removes it from the sleeve. Every entry has an initial 2.5 × ATR(14, D1) stop; the source-faithful default has no short position, trailing stop, break-even move, partial close, or pyramiding.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 10 | 5–50 | D1 simple moving-average period for the close-cross trigger. |
| `strategy_min_daily_bars` | 270 | 270–600 | Minimum closed D1 history required before a symbol is eligible. |
| `strategy_vol_lookback_days` | 252 | 60–504 | Number of closed daily log returns used for realized-volatility ranking. |
| `strategy_top_symbols` | 3 | 1–10 | Number of highest-volatility eligible symbols admitted each month. |
| `strategy_atr_period` | 14 | 5–30 | Closed-D1 ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5–5.0 | Initial stop distance in ATR multiples. |
| `strategy_enable_short` | false | false / true | Enables the optional short-on-cross-below test variant; false preserves long/cash. |
| `strategy_max_spread_points` | 0 | 0–500 | Optional per-symbol spread cap; 0 disables it and zero modeled DWX spread remains tradeable. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — liquid gold CFD with complete D1 closes for volatility ranking and SMA timing.
- `XAGUSD.DWX` — liquid silver CFD with complete D1 closes for volatility ranking and SMA timing.
- `XNGUSD.DWX` — natural-gas CFD whose volatility can place it in the monthly high-volatility sleeve.
- `XTIUSD.DWX` — WTI crude-oil CFD whose volatility can place it in the monthly high-volatility sleeve.
- `NDX.DWX` — Nasdaq 100 index proxy with portable daily OHLC history.
- `WS30.DWX` — Dow 30 index proxy with portable daily OHLC history.
- `GDAXI.DWX` — DAX 40 index proxy with portable daily OHLC history.
- `UK100.DWX` — FTSE 100 index proxy with portable daily OHLC history.
- `SP500.DWX` — S&P 500 backtest alias; live routing uses confirmed broker symbol `SP500`.
- `AUDCAD.DWX` — liquid FX cross with portable daily close returns.
- `AUDCHF.DWX` — liquid FX cross with portable daily close returns.
- `AUDJPY.DWX` — liquid FX cross with portable daily close returns.
- `AUDNZD.DWX` — liquid FX cross with portable daily close returns.
- `AUDUSD.DWX` — liquid FX major with portable daily close returns.
- `CADCHF.DWX` — liquid FX cross with portable daily close returns.
- `CADJPY.DWX` — liquid FX cross with portable daily close returns.
- `CHFJPY.DWX` — liquid FX cross with portable daily close returns.
- `EURAUD.DWX` — liquid FX cross with portable daily close returns.
- `EURCAD.DWX` — liquid FX cross with portable daily close returns.
- `EURCHF.DWX` — liquid FX cross with portable daily close returns.
- `EURGBP.DWX` — liquid FX cross with portable daily close returns.
- `EURJPY.DWX` — liquid FX cross with portable daily close returns.
- `EURNZD.DWX` — liquid FX cross with portable daily close returns.
- `EURUSD.DWX` — liquid FX major with portable daily close returns.
- `GBPAUD.DWX` — liquid FX cross with portable daily close returns.
- `GBPCAD.DWX` — liquid FX cross with portable daily close returns.
- `GBPCHF.DWX` — liquid FX cross with portable daily close returns.
- `GBPJPY.DWX` — liquid FX cross with portable daily close returns.
- `GBPNZD.DWX` — liquid FX cross with portable daily close returns.
- `GBPUSD.DWX` — liquid FX major with portable daily close returns.
- `NZDCAD.DWX` — liquid FX cross with portable daily close returns.
- `NZDCHF.DWX` — liquid FX cross with portable daily close returns.
- `NZDJPY.DWX` — liquid FX cross with portable daily close returns.
- `NZDUSD.DWX` — liquid FX major with portable daily close returns.
- `USDCAD.DWX` — liquid FX major with portable daily close returns.
- `USDCHF.DWX` — liquid FX major with portable daily close returns.
- `USDJPY.DWX` — liquid FX major with portable daily close returns.

**Explicitly NOT for:**

- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` — the broker/tester has no sanctioned tick-history contract for it.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` — unavailable aliases; `SP500.DWX` is the sole canonical S&P 500 backtest symbol.
- `XBRUSD.DWX` and `JP225.DWX` — not present in the current 37-symbol DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; monthly cadence is derived from D1 dates rather than untestable MN1 bars |
| Bar gating | `QM_IsNewBar()` for entry and `QM_IsNewCalendarPeriod(PERIOD_D1 / PERIOD_MN1)` for cached state |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 (card frontmatter) |
| Expected trade frequency | Daily signal evaluation; exposure is episodic per symbol because only the monthly top three are eligible. |
| Typical hold time | Several days to several weeks, until the opposite SMA cross or monthly sleeve removal. |
| Expected drawdown profile | Repeated small stop-outs and SMA whipsaws in choppy high-volatility regimes. |
| Regime preference | High-realized-volatility, directionally trending markets. |
| Win rate target (qualitative) | Low to medium; trend timing relies on larger winners rather than a high hit rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog summary of an academic result
**Pointer:** Wesley Gray, PhD, “Technical Analysis may actually work!”, 2010-05-19, https://alphaarchitect.com/technical-analysis-may-actually-work/
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_1537_aa-vol-sma10.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`). For the card's full-live 0.5% sleeve budget, the deployment setfiles divide exposure across the three active selections through `PORTFOLIO_WEIGHT = 1 / 3`; Q01 backtest setfiles retain `RISK_FIXED = 1000` and `PORTFOLIO_WEIGHT = 1.0` per active symbol.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Initial build from card | fa1fd187-eccb-4e11-bd71-a16531a61530 |
