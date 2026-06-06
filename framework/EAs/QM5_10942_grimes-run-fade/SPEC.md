# QM5_10942_grimes-run-fade - Strategy Spec

**EA ID:** QM5_10942
**Slug:** grimes-run-fade
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA fades a five-day directional run on D1 bars. It buys after five consecutive lower D1 closes when the last close is at least 1.5 ATR(20) below EMA(20), and sells after five consecutive higher D1 closes when the last close is at least 1.5 ATR(20) above EMA(20). It skips oversized signal bars and strong ADX trend continuation, then exits at an EMA(20) touch, the 1.5R target, a close beyond the signal-bar extreme by 0.5 ATR(20), or after five D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_run_closes | 5 | 2-20 | Number of consecutive D1 closes in one direction required for the fade setup. |
| strategy_atr_period | 20 | 1-200 | ATR period for extension, crash-bar, stop, and extreme-break rules. |
| strategy_ema_period | 20 | 1-200 | EMA period for extension and EMA-touch exit. |
| strategy_adx_period | 14 | 1-100 | ADX period for the strong-trend skip. |
| strategy_extension_atr_mult | 1.5 | 0.1-10.0 | Required distance from EMA(20) in ATR multiples. |
| strategy_max_range_atr_mult | 2.75 | 0.1-10.0 | Maximum signal-bar range in ATR multiples. |
| strategy_adx_skip_threshold | 35.0 | 1.0-100.0 | ADX threshold above which aligned EMA slope blocks new fades. |
| strategy_stop_atr_mult | 1.5 | 0.1-10.0 | Stop distance in ATR multiples. |
| strategy_tp_r_mult | 1.5 | 0.1-10.0 | Secondary target in R multiples. |
| strategy_extreme_exit_atr_mult | 0.5 | 0.1-10.0 | Closed-bar adverse move beyond signal extreme that exits the trade. |
| strategy_time_exit_d1_bars | 5 | 1-30 | Maximum holding period in D1 bars. |
| strategy_cooldown_d1_bars | 10 | 0-60 | Same-direction cooldown after an exit. |
| strategy_spread_stop_pct | 5.0 | 0.0-50.0 | Maximum spread as a percentage of stop distance for new entries. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair with D1 OHLC, EMA, ATR, and ADX coverage.
- GBPUSD.DWX - liquid major FX pair with the same daily mean-reversion mechanics.
- USDJPY.DWX - liquid major FX pair with D1 data and portable run-fade structure.
- XAUUSD.DWX - liquid metal symbol included by the approved card basket.
- GDAXI.DWX - DWX matrix-confirmed DAX exposure used in place of card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DWX equivalent.

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
| Trades / year / symbol | 24 |
| Typical hold time | Intraday to five D1 bars, depending on EMA touch, 1.5R target, or adverse close. |
| Expected drawdown profile | Mean-reversion drawdowns cluster during strong directional trend continuation. |
| Regime preference | Mean-revert after stretched five-day directional runs. |
| Win rate target (qualitative) | Medium |

Expected trade frequency from the card: Five-day directional run fade with extension filter; conservative estimate 15-35 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "The Two Forces", 2013-10-29, https://www.adamhgrimes.com/the-two-forces/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10942_grimes-run-fade.md`

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
| v1 | 2026-06-06 | Initial build from card | 1dd8568b-9076-4aa2-b06c-5f90ea2122ae |
