# QM5_10871_sysls-ct-mom - Strategy Spec

**EA ID:** QM5_10871
**Slug:** `sysls-ct-mom`
**Source:** `66a6c726-c456-5899-be49-561e86612e8a` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades D1 trend persistence using four rate-of-change estimators: ROC(5), ROC(10), ROC(15), and ROC(20). Each estimator is normalized with a rolling 252-bar z-score, clipped to -3 through +3, mapped to -1 through +1 with a fixed tanh-equivalent transform, and combined by taking the median. The EA opens long when the combined score is above +0.35 and opens short when it is below -0.35; it exits longs when the score falls below zero and exits shorts when the score rises above zero. A 20-day time stop, 2.5 ATR(20) initial stop, low-volatility ATR/close percentile filter, spread filter, and 3.0 ATR trailing stop after 1.5R profit are applied.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc_1` | 5 | 1-252 | First rate-of-change lookback in D1 bars. |
| `strategy_roc_2` | 10 | 1-252 | Second rate-of-change lookback in D1 bars. |
| `strategy_roc_3` | 15 | 1-252 | Third rate-of-change lookback in D1 bars. |
| `strategy_roc_4` | 20 | 1-252 | Fourth rate-of-change lookback in D1 bars. |
| `strategy_zscore_window` | 252 | 20-504 | Rolling sample window for ROC z-score and ATR/close percentile. |
| `strategy_entry_threshold` | 0.35 | 0.01-1.00 | Median score threshold for long and short entries. |
| `strategy_atr_period` | 20 | 2-100 | ATR period used for initial stop and trailing stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | Initial stop distance in ATR multiples. |
| `strategy_trail_atr_mult` | 3.0 | 0.1-10.0 | Trailing stop distance in ATR multiples. |
| `strategy_trail_trigger_r` | 1.5 | 0.1-10.0 | Profit threshold, measured in initial ATR stop multiples, before trailing starts. |
| `strategy_time_stop_days` | 20 | 1-252 | Maximum holding period in calendar-day approximation of D1 trading days. |
| `strategy_atr_percentile_pct` | 20.0 | 0.0-100.0 | Blocks new entries when ATR(20)/close is below this rolling percentile. |
| `strategy_spread_stop_frac` | 0.08 | 0.0-1.0 | Blocks new entries when spread exceeds this fraction of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Liquid trend market for gold exposure from the card basket.
- `XTIUSD.DWX` - Liquid trend market for crude oil exposure from the card basket.
- `NDX.DWX` - Liquid equity-index trend market from the card basket.
- `GDAXI.DWX` - Canonical DAX custom symbol in `dwx_symbol_matrix.csv`; used as the available DWX port for card-stated `GER40.DWX`.
- `EURUSD.DWX` - Liquid FX trend market from the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated DAX symbol is not present in `dwx_symbol_matrix.csv`; this build registers `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Expected trade frequency | Medium-cadence daily trend following; approx 30 trades/year/symbol. |
| Typical hold time | Up to 20 D1 bars by card time stop. |
| Expected drawdown profile | Medium; main risk is whipsaw and trend decay outside crypto. |
| Regime preference | Trend / momentum. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `66a6c726-c456-5899-be49-561e86612e8a`
**Source type:** Substack article
**Pointer:** Systematic Long Short, `How To Create a Profitable, Scalable Trend Signal in Crypto`, Jan 14 2026, https://www.systematiclongshort.com/p/how-to-create-a-profitable-scalable
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10871_sysls-ct-mom.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | a83f5332-eb79-4164-8b6e-15682d8966c2 |
