# QM5_9643_bandy-rsi2-atr-regime-filter-mr-index — Strategy Spec

**EA ID:** QM5_9643
**Slug:** `bandy-rsi2-atr-regime-filter-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (Howard Bandy, *Quantitative Technical Analysis*)
**Author of this spec:** Codex
**Last revised:** 2026-08-09

---

## 1. Strategy Logic

On each closed D1 bar, the EA buys at the next available session tick when RSI(2) is at or below 5, the close is above SMA(200), and ATR(14) divided by close is no higher than its rolling 50th percentile over 252 bars. The initial stop is two ATR(14) below entry, with framework risk sizing from that stop distance. The position closes after a closed-bar RSI reading at or above 70, after five completed D1 trading bars, at the hard stop, or through the framework Friday-close and kill-switch protections.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 2 | fixed | Wilder RSI period on D1 closes. |
| `strategy_rsi_entry_threshold` | 5.0 | 2 / 5 / 10 | Maximum RSI value that permits a long entry. |
| `strategy_rsi_exit_threshold` | 70.0 | 60 / 70 / 80 | Minimum closed-bar RSI value that triggers the take-profit exit. |
| `strategy_trend_sma_period` | 200 | 100 / 200 / 300 | D1 SMA period for the long-term uptrend filter. |
| `strategy_atr_period` | 14 | 10 / 14 / 20 | D1 ATR period used by the regime gate and initial stop. |
| `strategy_atr_percentile_bars` | 252 | fixed | Number of closed D1 bars in the normalized-volatility distribution. |
| `strategy_atr_percentile_cutoff` | 50.0 | 25 / 50 / 75 | Percentile of ATR/close that current normalized volatility must not exceed. |
| `strategy_atr_sl_mult` | 2.0 | fixed | Initial stop distance in ATR multiples. |
| `strategy_time_exit_bars` | 5 | 3 / 5 / 8 | Completed D1 trading bars before the time exit. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 custom-symbol proxy for the card's broad US large-cap universe.
- `NDX.DWX` — liquid Nasdaq 100 index proxy suitable for the same daily long-only equity-index mean reversion.
- `WS30.DWX` — liquid Dow 30 index proxy that completes the card's portable US index basket.

**Explicitly NOT for:**

- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` — unavailable non-canonical aliases; `SP500.DWX` is the sole approved S&P 500 backtest symbol.
- Non-index symbols — the card's long-only uptrend and volatility-regime thesis is specifically for equity indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in the canonical framework wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Expected trade frequency | roughly one trade every two months per symbol |
| Typical hold time | one to five trading days, capped at five completed D1 bars |
| Expected drawdown profile | approximately 18% card-level expectation, with losses clustering when index mean reversion degrades |
| Regime preference | low-to-median normalized volatility while price remains above its long-term trend average |
| Win rate target (qualitative) | not specified by the approved card; Q02 establishes the observed rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard Bandy, *Quantitative Technical Analysis*, Blue Owl Press, 2015, ISBN 978-0-9791037-7-1; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9643_bandy-rsi2-atr-regime-filter-mr-index.md`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9643_bandy-rsi2-atr-regime-filter-mr-index.md`.

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
| v1 | 2026-08-09 | Initial build from card | 9f7a3082-abdc-466a-bee6-722eac2a2076 |
