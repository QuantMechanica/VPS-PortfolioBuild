# QM5_11131_tm-first-pb - Strategy Spec

**EA ID:** QM5_11131
**Slug:** `tm-first-pb`
**Source:** `63b6d09c-d79f-561b-b577-eb5bf5878af1` (see `strategy-seeds/sources/63b6d09c-d79f-561b-b577-eb5bf5878af1/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates D1 closed bars and only trades long. A setup exists when the last close is above SMA(20), SMA(50), SMA(100), and SMA(200), but below SMA(5), which marks a short pullback inside a strong uptrend. On a setup it places a buy limit below the setup close for a fixed number of D1 bars, using 4 percent depth for US indices and 1 ATR for the DAX port. Positions exit when the last close is above SMA(5), when the optional ConnorsRSI exit mode crosses its threshold, or when the maximum holding period is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_exit_period` | 5 | 1-50 | SMA period used by the baseline close exit. |
| `strategy_sma_pullback_period` | 5 | 1-50 | SMA period that the setup close must be below. |
| `strategy_sma_trend_fast` | 20 | 1-250 | Fast trend-stack SMA. |
| `strategy_sma_trend_mid` | 50 | 1-250 | Middle trend-stack SMA. |
| `strategy_sma_trend_slow` | 100 | 1-300 | Slow trend-stack SMA. |
| `strategy_sma_trend_long` | 200 | 1-400 | Long trend-stack SMA. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop distance and non-US limit depth. |
| `strategy_us_limit_depth_pct` | 4.0 | 0.1-10.0 | Buy-limit depth as percent of setup close for SP500, NDX, and WS30. |
| `strategy_non_us_limit_atr_mult` | 1.0 | 0.1-5.0 | Buy-limit depth in ATR multiples for the DAX port. |
| `strategy_limit_valid_bars` | 3 | 1-10 | Number of D1 bars before the pending limit expires. |
| `strategy_stop_atr_mult` | 2.5 | 0.5-10.0 | Hard stop distance in ATR multiples. |
| `strategy_max_hold_bars` | 7 | 1-30 | Maximum holding period in D1 bars. |
| `strategy_exit_mode` | 0 | 0-2 | Exit selector: 0=SMA5, 1=ConnorsRSI above 50, 2=ConnorsRSI above 70. |
| `strategy_connors_rsi_period` | 3 | 1-20 | Price RSI component period for ConnorsRSI. |
| `strategy_connors_streak_rsi_period` | 2 | 1-20 | Streak RSI component period for ConnorsRSI. |
| `strategy_connors_rank_period` | 100 | 10-250 | Percent-rank lookback for ConnorsRSI. |
| `strategy_max_spread_atr_frac` | 0.25 | 0.0-1.0 | Entry is skipped when spread is above this fraction of D1 ATR; 0 disables the check. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the source universe at index level.
- `NDX.DWX` - Nasdaq 100 liquid US index proxy for the same large-cap pullback logic.
- `WS30.DWX` - Dow 30 liquid US index proxy for the same large-cap pullback logic.
- `GDAXI.DWX` - DAX custom symbol used as the available DWX port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | up to 7 D1 bars |
| Expected drawdown profile | Index-CFD port may trade less often than the source stock-universe tests and uses ATR stops to cap per-trade loss. |
| Regime preference | trend pullback / mean-revert |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `63b6d09c-d79f-561b-b577-eb5bf5878af1`
**Source type:** article
**Pointer:** TradingMarkets article by Matt Radtke, "Learning From The First Pullback Strategy", 2013-05-31
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11131_tm-first-pb.md`

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
| v1 | 2026-06-07 | Initial build from card | 5b8bd5a8-f3e1-4f21-af2c-33c20db2620a |
