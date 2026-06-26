# QM5_9265_mql5-adx-di-trend - Strategy Spec

**EA ID:** QM5_9265
**Slug:** mql5-adx-di-trend
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved MQL5 article card)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades the ADX directional-movement trend rule from the approved card on closed H1 bars. It opens long when ADX(14) is above 25, ADX is rising versus the prior closed bar, and +DI is above -DI. It opens short when ADX(14) is above 25, ADX is rising, and +DI is below -DI. Positions close when DI dominance reverses, ADX weakens for two consecutive closed bars, ADX falls below 20, or the hold reaches 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 2+ | ADX, +DI, and -DI lookback period. |
| `strategy_adx_entry_min` | 25.0 | >0 | Minimum closed-bar ADX value required for new entries. |
| `strategy_adx_exit_floor` | 20.0 | >0 | Closed-bar ADX value below which open positions close. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback period for initial stop placement. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple used for the initial stop loss. |
| `strategy_take_profit_rr` | 2.4 | >0 | Initial take-profit as an R multiple from the stop. |
| `strategy_adx_weak_bars` | 2 | 1-2 | Consecutive closed ADX weakening bars required for the ADX-weakness exit. |
| `strategy_max_hold_h1_bars` | 72 | 1+ | Failsafe maximum hold measured in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid major FX pair with H1 OHLC, ADX, DI, and ATR data.
- `GBPJPY.DWX` - card target; liquid FX cross with H1 OHLC, ADX, DI, and ATR data.
- `XAUUSD.DWX` - card target; gold CFD with H1 OHLC, ADX, DI, and ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not available in the DWX tester universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Up to 72 H1 bars by failsafe; shorter on DI reversal, ADX weakening, SL, or TP. |
| Expected drawdown profile | Trend-following losses cluster in low-trend or whipsaw conditions. |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/10715
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9265_mql5-adx-di-trend.md`

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
| v1 | 2026-06-26 | Initial build from card | 64c7c693-8fc7-4ebf-ac04-b06ce044e018 |
