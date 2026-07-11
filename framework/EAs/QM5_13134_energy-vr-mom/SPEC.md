# QM5_13134_energy-vr-mom - Strategy Spec

**EA ID:** QM5_13134
**Slug:** `energy-vr-mom`
**Strategy ID:** `MEHLITZ-AUER-MEM-2024_XTI_S01`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

## 1. Strategy Logic

This EA implements the source's monthly `R1-q2` memory-enhanced momentum rule
on the native WTI proxy `XTIUSD.DWX`. On the first D1 bar of a broker month it
groups completed D1 bars into month-end closes, forms the latest 32 monthly log
returns, and calculates the q=2 heteroskedasticity-robust Lo-MacKinlay variance
ratio statistic.

The latest one-month return is continued when the statistic shows significant
persistence and reversed when it shows significant anti-persistence. The EA is
flat when the two-sided 10% test is insignificant. It opens at most once per
broker month and renews only at the next month transition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | 32 only | Source robust-test window |
| `strategy_vr_q` | 2 | 2 only | Source leading `R1-q2` order |
| `strategy_significance_z` | 1.64485362695147 | locked | Two-sided 10% normal critical value |
| `strategy_history_bars_d1` | 1200 | 900-1600 | D1 buffer for 33 completed month ends |
| `strategy_atr_period_d1` | 20 | 14-30 | Frozen hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Hard-stop distance |
| `strategy_max_hold_days` | 35 | 35 only | Stale-position guard |
| `strategy_max_spread_points` | 1500 | 1000-2500 | XTI entry spread ceiling |

The signal sample, q, significance threshold, direction matrix, monthly
cadence, and same-month re-entry prohibition are locked.

## 3. Symbol Universe

- Designed and registered for `XTIUSD.DWX`, magic slot 0.
- No XNG, index, metal, curve, inventory, news, or external factor input.
- WTI is explicitly included in the source commodity universe and appendix.

## 4. Timeframe

- Host timeframe: D1.
- Signal interval: monthly returns derived from completed D1 month-end closes.
- Rebalance: first D1 bar whose broker month differs from the prior D1 bar.
- Native MN1 bars are deliberately not required because custom-symbol tester
  histories may not expose MN1 bars reliably.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades/year/symbol | approximately 6-10 after 33-month warm-up; Q02 floor 5 |
| Typical hold | until next broker month, hard stop, or 35-day stale guard |
| Direction | symmetric long/short; continuation or reversal by significant VR sign |
| Inactive regime | insignificant q=2 variance ratio |
| Backtest risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

## 6. Source Citation

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum in
commodity futures markets," *The European Journal of Finance* 30(8), 773-802,
DOI `10.1080/1351847X.2023.2220118`. The complete open precursor is Chapter 3
of Mehlitz's 2021 doctoral thesis, pp. 51-74 with Appendix C pp. 110-113.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02-Q10 backtest | RISK_FIXED | 1000 |
| Live | not authorized | no live setfile |

Every entry receives a frozen D1 `ATR(20) * 3.0` hard stop. There is no TP,
trail, break-even, partial close, scale-in, grid, martingale, or pyramiding.
News compliance gates entries only; month and stale exits always remain active.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-11 | Initial source-backed WTI `R1-q2` build |
