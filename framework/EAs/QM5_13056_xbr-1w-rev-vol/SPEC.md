# QM5_13056_xbr-1w-rev-vol - Strategy Spec

**EA ID:** QM5_13056
**Slug:** `xbr-1w-rev-vol`
**Source:** `ZHAO-ST-MOMREV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency Brent short-term reversal sleeve on
`XBRUSD.DWX`. On each new D1 bar it inspects the previous completed D1 closes,
computes a 5-D1 return, ranks current 20-D1 realized volatility against the
prior 120 rolling observations, and enters only when the recent move is large
and volatility is elevated.

A long setup requires a negative 5-D1 return below threshold and a volatility
percentile at or above the floor. A short setup uses the symmetric positive
return. The EA allows at most one entry per broker week, uses a fixed ATR hard
stop, and exits by time, return normalization, standard V5 news handling, and
Friday close. Runtime uses broker D1 OHLC and calendar state only.

This is intentionally separate from `QM5_13055_xbr-1w-mom-vol`, which follows
Brent short-term momentum in low-volatility regimes, and from
`QM5_13050_xti-1w-rev-vol`, which tests the reversal branch on WTI rather than
Brent.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reversal_lookback_days` | 5 | 3-10 | Closed D1 bars used for the short-term return signal |
| `strategy_min_week_return_pct` | 2.00 | 1.00-4.00 | Minimum absolute 5-D1 return for reversal entry |
| `strategy_vol_window_d1` | 20 | 10-40 | Closed D1 returns used for realized volatility |
| `strategy_vol_rank_lookback_d1` | 120 | 60-240 | Rolling realized-vol observations used for percentile rank |
| `strategy_min_vol_pctile` | 65.0 | 50.0-85.0 | Minimum current realized-volatility percentile for entry |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop sizing |
| `strategy_atr_sl_mult` | 2.25 | 1.50-3.25 | ATR hard-stop distance |
| `strategy_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_exit_neutral_pct` | 0.25 | 0.00-1.00 | Mean-reversion neutral band for signal exit |
| `strategy_max_spread_points` | 1200 | 700-1800 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: W1 calendar key only for one-entry-per-week gating.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Direction: symmetric long/short, opposite the prior 5-D1 move.
- Typical hold: several D1 bars, capped by 5 calendar days, normalization,
  stop, or Friday close.
- Regime preference: short-term Brent mean reversion after large
  high-volatility weekly moves.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026, DOI
10.2139/ssrn.6425598, URL
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## 8. Build Evidence

| Date | Phase | Verdict | Evidence |
|---|---|---|---|
| 2026-07-08 | Q01 Build Validation | PASS | `artifacts/qm5_13056_build_result.json` |
| 2026-07-08 | Q02 Baseline Screening | QUEUED | `artifacts/qm5_13056_q02_enqueue_20260708.json` |
