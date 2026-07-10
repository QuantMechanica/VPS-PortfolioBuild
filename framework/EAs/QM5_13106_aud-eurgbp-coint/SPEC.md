# QM5_13106_aud-eurgbp-coint - Strategy Spec

**EA ID:** QM5_13106  
**Slug:** aud-eurgbp-coint  
**Source:** AI-CLAUDE-FX-COINT66-20260609-AUDUSD-EURGBP  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

The EA trades the fixed AUDUSD.DWX/EURGBP.DWX D1 log spread
`ln(AUDUSD) - beta * ln(EURGBP)` with beta `-0.0545763736541407`. A 60-bar
rolling z-score opens a short-spread package above `+2.0`, a long-spread
package below `-2.0`, and closes both legs inside `abs(z) < 0.5`.

Because beta is negative, long spread buys both legs and short spread sells
both. Fixed risk is divided in `1:abs(beta)` weight. Every leg has a hard
`2.0 * ATR(20, D1)` stop; an orphaned leg is closed immediately. There is no
adaptive beta, grid, martingale, averaging, pyramiding, or trailing stop.

The all-sign 66-pair rerun measured DEV net Sharpe `0.5536`, OOS net Sharpe
`1.0472`, OOS return `10.8647%`, 25 OOS state changes, and a 112.50-day
half-life. The small hedge is an explicit directional-risk caveat.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_z_lookback_d1 | 60 | rolling spread mean/std window |
| strategy_beta | -0.0545763736541407 | fixed DEV regression hedge |
| strategy_entry_z | 2.0 | absolute entry threshold |
| strategy_exit_z | 0.5 | mean-reversion exit band |
| strategy_atr_period_d1 | 20 | per-leg hard-stop ATR period |
| strategy_atr_sl_mult | 2.0 | per-leg hard-stop multiplier |
| strategy_deviation_points | 20 | basket market-order deviation |

## 3. Symbol Universe

- AUDUSD.DWX: host and traded spread numerator, magic slot 0.
- EURGBP.DWX: traded beta-weighted leg, magic slot 1.
- GBPUSD.DWX: USD tester conversion/history dependency only; never traded.
- All other symbols are out of scope.

## 4. Timeframe

- D1 base timeframe, evaluated once per closed host bar.

## 5. Expected Behaviour

- Expected 3-5 logical packages per year.
- Expected holding period is weeks to months; Friday close remains enabled.
- Expected drawdown is high because the fixed hedge is small and the measured
  half-life is long.
- Q02/Q04 must determine whether the residual survives real spread, conversion,
  commission, and swap costs.

## 6. Source Citation

Single lineage source:
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

Reproduction uses `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`
on `D:/QM/mt5/T_Export/MQL5/Files` with the positive-hedge exclusion removed so
all 66 pair orientations remain in the ranked result.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Q02-Q10 backtest | RISK_FIXED | USD 1,000 per package |
| Live | not authorized | no live setfile or manifest |

The Q02 manifest pins tester currency to USD and deposit to 100,000. The
logical setfile has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## 8. Pipeline Handoff

The logical-basket Q02 run passed on 2026-07-10 with real ticks: PF `1.15`,
138 tester trades, net profit `2222.95`, and `3.37%` drawdown. No ONINIT or
log-bomb condition was detected. Evidence:
`D:/QM/reports/work_items/78e5573f-9b83-42fc-8cbc-04125c4e42f1/QM5_13106/20260710_045016/summary.json`.

The paced pump already created Q03 work item
`1e2f36e1-a88c-4ee1-b23d-0b2aa2027cc6` and Q04 early-probe work item
`a33683ca-ddff-4291-93c7-df149fb5a324`. Only the existing Q03 row was moved
to the priority track; no duplicate row or manual tester run was created.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-10 | Initial all-sign 66-pair strict-survivor basket build |
| v2 | 2026-07-10 | Record Q02 PASS and priority handoff to the existing Q03 continuation |
