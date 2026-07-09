
# QM5_13101_xng-1w-mom-vol - Strategy Spec

**EA ID:** QM5_13101
**Slug:** `xng-1w-mom-vol`
**Source:** `ZHAO-ST-MOMREV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency natural gas short-term momentum sleeve on
`XNGUSD.DWX`. On each new D1 bar it inspects the previous completed D1 closes,
computes a 5-D1 return, ranks current 20-D1 realized volatility against the
prior 120 rolling observations, and enters only when the move is directional
and volatility is not elevated.

A long setup requires a positive 5-D1 return above threshold and a volatility
percentile at or below cap. A short setup uses the symmetric negative return.
The EA allows at most one entry per broker week, uses a fixed ATR hard stop,
and exits by time, opposite return, standard V5 news handling, and Friday
close. Runtime uses broker D1 OHLC and calendar state only. The signal parameters are locked to the existing XTI/Brent source-proxy builds; only the XNG execution spread cap changes.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_days` | 5 | 3-10 | Closed D1 bars used for the short-term return signal |
| `strategy_min_week_return_pct` | 1.25 | 0.50-3.00 | Minimum absolute 5-D1 return for entry |
| `strategy_vol_window_d1` | 20 | 10-40 | Closed D1 returns used for realized volatility |
| `strategy_vol_rank_lookback_d1` | 120 | 60-240 | Rolling realized-vol observations used for percentile rank |
| `strategy_max_vol_pctile` | 55.0 | 35.0-70.0 | Maximum current realized-volatility percentile for entry |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop sizing |
| `strategy_atr_sl_mult` | 2.50 | 1.75-3.50 | ATR hard-stop distance |
| `strategy_hold_days` | 7 | 4-10 | Calendar-day stale-position exit |
| `strategy_exit_reverse_pct` | 0.50 | 0.25-1.50 | Opposite 5-D1 return threshold for signal reversal exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: W1 calendar key only for one-entry-per-week gating.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by 7 calendar days, reversal, stop,
  or Friday close.
- Regime preference: short-term natural gas directional continuation when recent
  realized volatility is not elevated.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation\n\nThe academic paper uses investor-position flow decomposition. This EA does not reproduce the unavailable `R_nonQ` factor; it tests an explicitly declared OHLC-only proxy and must be falsified independently by Q02.\n\nNon-duplicate boundary: unlike QM5_12567, this EA follows a five-D1 move in low volatility and uses no RSI. Unlike QM5_12817, it rejects high volatility and does not fade shocks. QM5_13049 and QM5_13055 use the same proxy on crude carriers, but neither supplies XNG pipeline evidence.\n

Academic working paper:

- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13101_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13101_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Mission-directed natural gas short-term low-vol momentum build | Enqueue to Q02 |


