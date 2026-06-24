# QM5_12381_btc-minmax10 - Strategy Spec

**EA ID:** QM5_12381
**Slug:** btc-minmax10
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see `strategy-seeds/sources/b7832a20-938e-5f24-b9d7-e0b2ab63b623/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA evaluates D1 bars after the prior D1 bar has closed. It goes long when the latest completed D1 close equals either the highest close or the lowest close in the last 10 completed D1 bars, treating the high as continuation and the low as rebound. It does not add while already long. The emergency stop is 2.5 times ATR(20) from entry, and the discretionary exit closes the position after one D1 holding bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_days` | 10 | 2+ | Number of completed D1 closes used for local maximum/minimum detection. |
| `strategy_hold_bars` | 1 | 1+ | Number of D1 bars to hold before the time exit. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple used to place the emergency stop. |
| `strategy_min_warmup_bars` | 40 | >= lookback | Minimum D1 history required before entries are allowed. |
| `strategy_spread_median_days` | 60 | 1+ | D1 spread lookback used for the 2x median spread entry guard. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Liquid index CFD for ported high-volatility continuation/rebound testing.
- `WS30.DWX` - Liquid index CFD for ported high-volatility continuation/rebound testing.
- `GER40.DWX` - Liquid European index CFD for ported high-volatility continuation/rebound testing.
- `XAUUSD.DWX` - Volatile metal CFD for ported price-action testing.
- `EURUSD.DWX` - Liquid FX major for ported price-action testing.
- `GBPJPY.DWX` - Volatile FX cross for ported price-action testing.

**Explicitly NOT for:**
- Native BTC symbols - no approved DWX BTC symbol is available in the build matrix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol tick data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | 1 D1 bar |
| Expected drawdown profile | High-turnover long-only rule with meaningful whipsaw risk on quiet symbols. |
| Regime preference | Breakout-continuation and mean-reversion rebound states. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** paper / public strategy page
**Pointer:** https://paperswithbacktest.com/strategies/seasonality-trend-following-and-mean-reversion-in-bitcoin
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12381_btc-minmax10.md`

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
| v1 | 2026-06-25 | Initial build from card | 47b840fd-2dc6-4167-a9f4-92658542f0d2 |
