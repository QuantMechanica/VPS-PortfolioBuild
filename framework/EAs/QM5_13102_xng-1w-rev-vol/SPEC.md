# QM5_13102_xng-1w-rev-vol - Strategy Spec

**EA ID:** QM5_13102
**Slug:** `xng-1w-rev-vol`
**Source:** `ZHAO-ST-MOMREV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency natural-gas short-term reversal sleeve on
`XNGUSD.DWX`. On each new D1 bar it computes the previous five-closed-bar
return and ranks current 20-D1 realized volatility against the prior 120
rolling observations. It fades only large moves in an elevated-volatility
regime.

A long setup requires a negative five-D1 return below threshold and a
volatility percentile at or above the floor. A short setup uses the symmetric
positive return. The EA permits at most one accepted entry per broker week,
uses an ATR hard stop, and exits by time, return normalization, standard V5
news handling, and Friday close. Runtime uses broker D1 OHLC and calendar state
only.

The signal parameters are locked to `QM5_13050` and `QM5_13056`; only the XNG
execution spread cap differs. The edge uses no RSI and is deliberately distinct
from `QM5_12567` and the low-volatility continuation branch in `QM5_13101`.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reversal_lookback_days` | 5 | locked | Closed D1 bars used for the short-term return signal |
| `strategy_min_week_return_pct` | 2.00 | locked | Minimum absolute five-D1 return for reversal entry |
| `strategy_vol_window_d1` | 20 | locked | Closed D1 returns used for realized volatility |
| `strategy_vol_rank_lookback_d1` | 120 | locked | Rolling volatility observations used for percentile rank |
| `strategy_min_vol_pctile` | 65.0 | locked | Minimum realized-volatility percentile for entry |
| `strategy_atr_period` | 20 | locked | ATR period for stop sizing |
| `strategy_atr_sl_mult` | 2.25 | locked | ATR hard-stop distance |
| `strategy_hold_days` | 5 | locked | Calendar-day stale-position exit |
| `strategy_exit_neutral_pct` | 0.25 | locked | Return-neutral band for signal exit |
| `strategy_max_spread_points` | 2500 | execution guard | XNG entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- W1 calendar key is used only for one-entry-per-week gating.
- All signal inputs are completed D1 bars; `QM_IsNewBar()` gates evaluation.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-18.
- Direction: symmetric long/short, opposite the prior five-D1 move.
- Hold: capped by five calendar days, normalization, stop, or Friday close.
- Regime: short-term XNG mean reversion after high-volatility weekly shocks.
- Q02 risk mode: `RISK_FIXED`.

## 6. Source Citation

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026, DOI
10.2139/ssrn.6425598.

The paper uses investor-position decomposition unavailable in the Darwinex
runtime. This EA tests an explicitly disclosed OHLC-only proxy and inherits no
performance evidence from the WTI or Brent carriers.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13102_build_result.json`.
- Q02 handoff is recorded in the build result and farm work-item state.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Mission-directed XNG one-week high-volatility reversal | Enqueue to Q02 |

