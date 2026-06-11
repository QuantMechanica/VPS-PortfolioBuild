# QM5_12450_ea31337-matrend - Strategy Spec

**EA ID:** QM5_12450
**Slug:** ea31337-matrend
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (see `strategy-seeds/sources/041e0d5c-bf76-501d-bee2-31c0f4a6e233/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the EA31337 MA Trend rule using a LWMA(22) on typical price by default. A long entry requires the chart-timeframe MA and D1 MA to rise on the closed bar, D1 MA change to exceed 7 pips, and the current closed chart MA to be the highest of the last four MA values. A short entry mirrors that logic with falling MAs and the current closed chart MA at the lowest of the last four values. Exits use fixed protective orders, a 30-bar time stop, and early close on an opposite MA trend signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 22 | >= 1 | Moving-average period from the EA31337 source MA defaults. |
| `strategy_ma_method` | `MODE_LWMA` | `ENUM_MA_METHOD` | Moving-average method; default is source LWMA. |
| `strategy_ma_price` | `PRICE_TYPICAL` | `ENUM_APPLIED_PRICE` | Applied price for the MA; default is source typical price. |
| `strategy_signal_open_level_pips` | 7.0 | > 0 | Minimum D1 MA change in pips required for entry. |
| `strategy_extreme_lookback_bars` | 4 | >= 4 | Confirms current closed chart MA is a four-value high or low. |
| `strategy_max_spread_pips` | 4.0 | > 0 | Maximum spread allowed before entries are blocked. |
| `strategy_fixed_sl_pips` | 80 | > 0 | Fixed-pip fallback stop when the D1 MA stop is not feasible. |
| `strategy_fixed_tp_pips` | 80 | > 0 | Fixed-pip take profit from source close-profit default. |
| `strategy_source_stop_offset_pips` | 2.0 | >= 0 | Offset around the D1 MA for the source-style protective stop. |
| `strategy_atr_period` | 14 | > 0 | ATR period for final protective-stop fallback. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiplier for final protective-stop fallback. |
| `strategy_time_exit_bars` | 30 | > 0 | Maximum holding time in chart bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX forex baseline symbol.
- `GBPUSD.DWX` - card-listed liquid DWX forex baseline symbol.
- `USDJPY.DWX` - card-listed liquid DWX forex baseline symbol.
- `XAUUSD.DWX` - card-listed DWX metal baseline symbol.
- `GDAXI.DWX` - available DWX DAX equivalent; the card names unavailable `DAX.DWX`.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` MA slope and threshold gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `up to 30 H1 bars` |
| Expected drawdown profile | Trend-following losses should be bounded by fixed SL or D1-MA protective stop. |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub repository
**Pointer:** `https://github.com/EA31337/Strategy-MA_Trend/blob/master/Stg_MA_Trend.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12450_ea31337-matrend.md`

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
| v1 | 2026-06-11 | Initial build from card | c476b756-b2d3-4151-8cf1-0e92dc5cf565 |
