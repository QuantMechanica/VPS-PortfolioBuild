# QM5_9236_mql5-hm-divergence - Strategy Spec

**EA ID:** QM5_9236
**Slug:** `mql5-hm-divergence`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA computes harmonic mean divergence from closed-bar high and low windows using the article formula: the change in reflected harmonic mean of highs minus the change in harmonic mean of lows. A long opens on the next bar when the prior signal bar has positive HM divergence and the latest closed bar closes above the previous close. A short opens when the same positive divergence is followed by a lower close. The EA exits when divergence falls to non-positive, when two consecutive closed bars move against the position direction, or after 30 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_hm_fast_period` | 6 | >= 1 | Arithmetic-mean lookback used in the reflected HM calculation. |
| `strategy_hm_slow_period` | 30 | >= 3 | Harmonic-mean lookback for high and low windows. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for volatility filter and initial stop. |
| `strategy_atr_sl_mult` | 1.7 | > 0 | ATR multiple for the initial stop distance. |
| `strategy_take_profit_rr` | 2.0 | > 0 | Initial take-profit as an R multiple from the stop. |
| `strategy_atr_median_lookback` | 50 | >= 1 | Number of prior ATR values used for the median volatility filter. |
| `strategy_max_hold_bars` | 30 | >= 1 | Failsafe time exit in H1 bars. |
| `strategy_max_spread_points` | 0.0 | >= 0 | Optional non-zero spread cap; 0 disables the strategy-specific cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated live-tradable DWX forex symbol with H1 OHLC and ATR data.
- `GBPJPY.DWX` - card-stated live-tradable DWX forex symbol with H1 OHLC and ATR data.
- `XAUUSD.DWX` - card-stated DWX metals symbol with H1 OHLC and ATR data.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest path requires registered `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified tester data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | H1 swing trades, capped at 30 bars |
| Expected drawdown profile | Medium; ATR-gated momentum continuation with fixed 2.0R targets |
| Regime preference | momentum-confirmation with range-expansion filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 24): Moving Averages", 2024-06-26, https://www.mql5.com/en/articles/15135
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9236_mql5-hm-divergence.md`

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
| v1 | 2026-06-20 | Initial build from card | f0fabcce-2166-4492-ac8e-ef99f1b41982 |
