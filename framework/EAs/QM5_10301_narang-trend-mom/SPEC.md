# QM5_10301_narang-trend-mom - Strategy Spec

**EA ID:** QM5_10301
**Slug:** narang-trend-mom
**Source:** 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35 (see `strategy-seeds/sources/0f051e46-12b2-51f3-aad5-d6d8bd3e9b35/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades H4 trend breakouts. It enters long when the last completed H4 close breaks above the prior 55 completed H4 highs and is above SMA(200); it enters short when the last completed H4 close breaks below the prior 55 completed H4 lows and is below SMA(200). It places an initial stop at 3.0 * ATR(20,H4), trails that stop with the same ATR distance, and exits on a 20-bar opposite channel break or after 120 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | PERIOD_H4 | H4 intended | Signal timeframe from the card. |
| `strategy_entry_channel` | 55 | 40-80 test range | Donchian breakout lookback in completed H4 bars. |
| `strategy_exit_channel` | 20 | 10-30 test range | Donchian reversal-exit lookback in completed H4 bars. |
| `strategy_sma_period` | 200 | 100-200 test range plus no-filter variant | H4 trend filter period. |
| `strategy_atr_period` | 20 | positive integer | ATR period used for initial and trailing stop distance. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 test range | ATR multiplier for initial and trailing stop. |
| `strategy_time_stop_bars` | 120 | positive integer | Maximum H4 bars to hold before strategy exit. |
| `strategy_max_spread_points` | 80.0 | positive decimal | Fixed emergency spread ceiling in symbol points. |
| `strategy_spread_atr_ratio` | 0.020 | positive decimal | ATR-relative spread proxy used when no percentile feed is available. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with H4 OHLC history.
- `GBPUSD.DWX` - card-listed major FX pair with H4 OHLC history.
- `USDJPY.DWX` - card-listed major FX pair with H4 OHLC history.
- `XAUUSD.DWX` - card-listed liquid metal CFD with H4 OHLC history.
- `GDAXI.DWX` - canonical DWX DAX symbol used in place of card-listed `GER40.DWX`, which is not in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - absent from `dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | H4 trend hold; maximum 120 H4 bars if no reversal exit occurs |
| Expected drawdown profile | Low win rate, positive skew, whipsaw risk in range-bound regimes |
| Regime preference | Trend-following / momentum breakout |
| Win rate target (qualitative) | low |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
**Source type:** book
**Pointer:** Rishi K. Narang, Inside the Black Box, 3rd ed.; Chapter 3 alpha-model taxonomy; `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10301_narang-trend-mom.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10301_narang-trend-mom.md`

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
| v1 | 2026-06-12 | Initial build from card | f68a7962-f709-41ee-b7dc-57ff0b70863a |
