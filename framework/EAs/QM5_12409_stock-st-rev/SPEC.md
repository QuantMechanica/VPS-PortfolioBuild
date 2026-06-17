# QM5_12409_stock-st-rev - Strategy Spec

**EA ID:** QM5_12409
**Slug:** `stock-st-rev`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates a cross-sectional basket once per week on the D1 bar after the prior week has closed. It computes each eligible symbol's prior-week return as the last closed D1 close divided by the close five D1 bars earlier, and its prior-month return as the last closed D1 close divided by the close twenty-one D1 bars earlier. It goes long the weakest prior-week symbol and short the strongest prior-month symbol, excluding any symbol already selected long. Positions are closed on the next weekly rebalance if the symbol is no longer selected, if its side changes, or if basket open drawdown reaches 5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_weekly_return_bars` | 5 | 1+ | D1 lookback for prior-week return ranking. |
| `strategy_monthly_return_bars` | 21 | 2+ | D1 lookback for prior-month return ranking. |
| `strategy_bucket_size` | 1 | 1-3 planned for P3 | Number of long and short symbols selected at each rebalance. |
| `strategy_min_d1_bars` | 30 | 23+ | Minimum D1 history required before a symbol is eligible. |
| `strategy_min_eligible` | 6 | 2-7 | Minimum eligible basket members required to trade. |
| `strategy_atr_period_d1` | 20 | 1+ | D1 ATR period for per-leg emergency stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for per-leg emergency stop. |
| `strategy_spread_days` | 60 | 1-128 | D1 spread sample used for the relative spread guard. |
| `strategy_spread_mult` | 2.0 | >0 | Blocks only when current spread is above this multiple of median spread. |
| `strategy_basket_stop_r` | 5.0 | >0 | Combined open drawdown threshold in units of active per-leg risk. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 large-cap equity proxy named in the card and present in the matrix.
- `NDX.DWX` - Nasdaq 100 large-cap equity proxy named in the card and present in the matrix.
- `WS30.DWX` - Dow 30 large-cap equity proxy named in the card and present in the matrix.
- `GDAXI.DWX` - DAX 40 matrix symbol used as the card's `GER40.DWX` port.
- `UK100.DWX` - FTSE 100 index proxy named in the card and present in the matrix.
- `XAUUSD.DWX` - Gold CFD named in the card and present in the matrix.
- `XTIUSD.DWX` - Oil CFD named in the card and present in the matrix.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `JP225.DWX` - not present in `dwx_symbol_matrix.csv`; no matrix-valid Japan equivalent was registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 52 |
| Typical hold time | about one week between rebalances |
| Expected drawdown profile | Short-term reversal can draw down in persistent momentum regimes; 2x ATR per-leg stop plus 5R basket stop. |
| Regime preference | mean-reversion / weekly-rebalance |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public GitHub / Quantpedia implementation
**Pointer:** `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/short-term-reversal-in-stocks.py`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12409_stock-st-rev.md`

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
| v1 | 2026-06-18 | Initial build from card | ffba2115-3c84-48f1-9d67-f9c30f9fc1c5 |
