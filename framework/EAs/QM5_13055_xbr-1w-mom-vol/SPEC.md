# QM5_13055_xbr-1w-mom-vol - Strategy Spec

**EA ID:** QM5_13055
**Slug:** `xbr-1w-mom-vol`
**Source:** `ZHAO-ST-MOMREV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency structural Brent one-week low-volatility
momentum sleeve on `XBRUSD.DWX` D1. On each new D1 bar, it computes the prior
five closed-D1 return and a 20-D1 realized-volatility percentile versus the
prior 120 observations. It enters with the five-day return direction only when
the absolute move clears threshold and realized volatility is not elevated.

The strategy is intentionally not a duplicate of the existing energy family:
`QM5_13049_xti-1w-mom-vol` tests WTI, `QM5_13050_xti-1w-rev-vol` tests the
high-volatility reversal branch, and Brent calendar/TOM/trend/anchor/spread
cards use different signal families.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_days` | 5 | fixed | Completed-D1 return lookback |
| `strategy_min_week_return_pct` | 1.25 | 1.0-2.5 | Minimum absolute five-day return |
| `strategy_vol_window_d1` | 20 | 14-30 | Realized-volatility window |
| `strategy_vol_rank_lookback_d1` | 120 | 80-180 | Volatility rank observations |
| `strategy_max_vol_pctile` | 55.0 | 45-65 | Maximum allowed realized-volatility percentile |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 2.50 | 2.0-3.0 | ATR stop distance multiplier |
| `strategy_hold_days` | 7 | 5-9 | Calendar-day time exit |
| `strategy_exit_reverse_pct` | 0.50 | 0.25-0.75 | Opposite-return exit threshold |
| `strategy_max_spread_points` | 1200 | 800-1800 | Brent entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: up to one calendar week.
- Regime preference: short-term Brent continuation after large low-volatility
  five-day moves.
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
