# QM5_20152_sma-cross-pullback-h1 - Strategy Spec

**EA ID:** QM5_20152
**Slug:** `sma-cross-pullback-h1`
**Source:** `BP-AOA-SMACROSSPULL-20150605`
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-08-05

The authoritative reconciled source rules remain in
`docs/ops/source_harvest/strategies/STR-143-sma-cross-pullback-h1/04_spec_final.md`.
This document maps those approved rules into the mandatory Q01 SPEC schema.

## 1. Strategy Logic

The EA is a closed-bar H1 trend-pullback strategy with three states:
`IDLE`, `ARMED_LONG`, and `ARMED_SHORT`.

- A bullish SMA cross arms long when `SMA100[1] > SMA200[1]` and
  `SMA100[2] <= SMA200[2]`; a bearish cross mirrors the rule. An opposite
  cross replaces the current arm, while equality after arming cancels it
  until a fresh cross.
- The first strictly later completed bar whose stochastic K line crosses up
  through 25 triggers a long while the bullish SMA order persists. A cross
  down through 75 triggers the mirrored short. The trigger consumes the arm
  whether the common gates accept or reject the order.
- Entry is at the next bar's market price, with at most one position per
  strategy magic. The stochastic is `(14,3,3, MODE_SMA, STO_LOWHIGH)` and the
  K-line level cross is used, not a K/D cross.
- Initial server-side protection is 150 pips of stop loss and 300 pips of
  take profit from the actual fill. Invalid geometry is rejected rather than
  widened.
- After a completed bar reaches +150 favorable pips, break-even is latched
  and the stop moves to normalized fill on the next bar, tighten-only and
  once. There is no recross, stochastic, or time exit; no partial close; and
  no trailing rule beyond break-even.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_sma_fast` | 100 | Fast simple moving average of H1 closes. |
| `strategy_sma_slow` | 200 | Slow simple moving average of H1 closes. |
| `strategy_stoch_k` | 14 | Stochastic K lookback. |
| `strategy_stoch_d` | 3 | Stochastic D smoothing. |
| `strategy_stoch_slowing` | 3 | K-line slowing. |
| `strategy_os_level` | 25.0 | Long pullback boundary. |
| `strategy_ob_level` | 75.0 | Short pullback boundary. |
| `strategy_sl_pips` | 150.0 | Fixed initial stop distance. |
| `strategy_tp_pips` | 300.0 | Fixed take-profit distance. |
| `strategy_be_trigger_pips` | 150.0 | Completed-bar favorable excursion that arms break-even. |

The Q02 baseline is fixed. Any later parameter variation requires its own
predeclared research authorization; this recovery does not authorize one.

## 3. Symbol Universe

The approved baseline trades only `EURUSD.DWX`. The source illustrates
EUR/USD H1 but supplies no tested multi-pair cohort, so any additional symbol
is a separately labelled strategy variant. Magic slot 0 resolves to
`201520000` for `EURUSD.DWX`.

## 4. Timeframe

The execution and signal timeframe is H1. All arming, signal, and break-even
decisions use completed H1 bars. Warm-up requires at least 202 bars for the
SMA200 and stochastic readers. Restart reconstruction is bounded and leaves
bar 1 eligible for the current evaluation.

## 5. Expected Behaviour

The approved farm expectation is approximately 20 trades per year on
`EURUSD.DWX`, with one eligible pullback per fresh 100/200 SMA crossover
episode. Typical holding time is hours to weeks, bounded by the 150/300-pip
server protection rather than a time exit. Q02 remains the economic and
cadence judge.

## 6. Source Citation

The durable local source extract is
`docs/ops/source_harvest/strategies/STR-143-sma-cross-pullback-h1/00_source.md`,
captured from the archived BabyPips article *Forex Mechanical System: SMA
Crossover Pullback* (Art of Automation, 2015-06-05). The independent specs,
reconciliation, final build authority, and G0 closure are retained in the same
`STR-143-sma-cross-pullback-h1` directory. G0 was cross-approved by Codex with
Claude as builder.

## 7. Risk Model

Backtests use the canonical fixed-risk contract:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`
- `qm_magic_slot_offset=0`

The framework enforces magic, news, kill-switch, Friday-close, and one-position
guards. The strategy adds exact fill-relative server SL/TP and a tighten-only
break-even move. No grid, martingale, pyramiding, ML, external data API, live
setfile, or live-trading authorization is part of this build or recovery.

## Revision History

- 2026-07-25 - Initial reconciled build specification.
- 2026-08-05 - Normalized the approved rules into the mandatory seven-section
  Q01 schema; no strategy or runtime behavior changed.
