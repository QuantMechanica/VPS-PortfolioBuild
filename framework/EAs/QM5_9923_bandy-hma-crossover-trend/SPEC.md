# QM5_9923_bandy-hma-crossover-trend — Strategy Spec

**EA ID:** QM5_9923
**Slug:** `bandy-hma-crossover-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Gemini Orchestration
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Mechanical trend-following strategy based on Howard Bandy's Quantitative Technical Analysis (2015).
On each daily bar close, HMA(9) and HMA(21) are computed along with a 200-period SMA regime filter.
A long position is opened on the next bar open when HMA(9) crosses above HMA(21) and the closing price is above the 200-period SMA.
A short position is opened on the next bar open when HMA(9) crosses below HMA(21) and the closing price is below the 200-period SMA.
Positions are managed with a Chandelier trailing stop (22-bar highest high / lowest low +/- 2.5 * ATR(14)), an opposite HMA crossover exit, and a 60-day time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hma_fast` | 9 | 7 .. 14 | Fast HMA period |
| `strategy_hma_slow` | 21 | 18 .. 26 | Slow HMA period |
| `strategy_regime_sma_period` | 200 | 100 .. 300 | 200-period SMA regime filter period |
| `strategy_chandelier_lookback` | 22 | 15 .. 30 | Chandelier stop lookback in bars |
| `strategy_atr_period` | 14 | 10 .. 20 | ATR period for Chandelier stop |
| `strategy_chandelier_atr_mult` | 2.5 | 2.0 .. 3.5 | ATR multiplier for Chandelier stop |
| `strategy_time_stop_days` | 60 | 45 .. 90 | Maximum holding period in trading days |
| `strategy_warmup_bars` | 250 | 200 .. 300 | Minimum bars required before trading |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `UK100.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

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
| Trades / year / symbol | 16 |
| Cadence note | see card body |
| Typical hold time | 10 to 45 days |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Trending |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Pointer:** `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_9923_bandy-hma-crossover-trend.md`

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
| v1 | 2026-08-23 | Initial build from card | d2b4cd24-ae0d-4cbb-92fb-a8ffcf328003 |
