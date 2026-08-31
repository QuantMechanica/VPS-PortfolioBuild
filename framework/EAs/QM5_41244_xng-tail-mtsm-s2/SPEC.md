# QM5_41244 XNG Tail-MTSM S2 — Strategy Spec

**EA ID:** QM5_41244

**Source ID:** LIU-MTSM-2021_XNG_S02

**Registered magic:** 412440000

## 1. Strategy Logic

On each new exact `XNGUSD.DWX` D1 bar, the EA loads completed closes and sums
the latest 30 simple daily returns. It separately averages the squares of the
positive and negative returns in the latest five-return window to form upper
and lower partial moments. Each current moment is compared with its own
nearest-rank 80th percentile from 252 older five-return observations; the
current observation is excluded from both reference samples.

The locked MTSM-S2 target map is:

- both current moments at or above their references: flat;
- only the lower partial moment in its tail: long;
- only the upper partial moment in its tail: short;
- neither in its tail: long when the 30-return sum is positive, short
  otherwise, including an exactly zero sum.

No trained signal, external runtime feed, banned signal indicator, parameter
adaptation, or portfolio-state input is used.

## 2. Parameters

| input | locked value |
|---|---:|
| `strategy_momentum_days` | 30 |
| `strategy_partial_moment_days` | 5 |
| `strategy_percentile_history` | 252 |
| `strategy_tail_percentile` | 80.0 |
| `strategy_atr_period` | 20 |
| `strategy_atr_sl_mult` | 3.0 |
| `strategy_max_hold_days` | 8 |
| `strategy_max_spread_points` | 1500 |

The current news axes are locked to `PRE30_POST30` and `DXZ`; legacy news mode
is OFF. Friday close is locked on at broker hour 21. Q02 has no optimization
surface.

## 3. Symbol Universe

The exact host and traded symbol is `XNGUSD.DWX`, D1, slot 0. The active magic
registry row maps this tuple to `412440000`. Any position carrying this magic
on another symbol is malformed and is closed; positions with unrelated magic
numbers are never adopted or altered by strategy ownership logic.

This is a single natural-gas CFD carrier port of a diversified Chinese
commodity-futures study. It is not a source replication claim and does not
inherit the paper's portfolio results.

## 4. Timeframe And Decision Contract

Host, signal, ATR, and execution timeframe are D1. A target is calculated once
per new D1 label from completed data only. The bounded history load contains
258 closes: enough for 30 returns, the current five-return partial moments,
and 252 older overlapping five-return reference observations.

A valid nonzero target observed while flat is persisted against the D1 label
before quote, spread, ATR, news, sizing, or order submission. A blocked,
rejected, stopped, or failed attempt never retries that label, including after
a terminal restart. A nonzero decision encountered with existing owned
exposure is also persisted so same-side retention and any repair/transition
remain restart-safe.

## 5. Expected Behaviour

Entry requires a positive finite non-crossed quote. A modeled zero spread is
valid; a positive spread above 1,500 points is rejected. The position receives
one frozen normalized `3.0 * ATR(20,D1)` broker stop and no target.

On every tick the EA repairs duplicate-magic, wrong-symbol, invalid-side,
invalid-volume, invalid-open-price, future-open-time, or stopless exposure and
closes positions after eight elapsed calendar days. On a new D1 decision it
retains the same side and closes unknown, flat, or opposed exposure. An
opposed close consumes that label and cannot reverse until a later D1 label.
Framework kill-switch, news, and Friday-close behavior remain authoritative.

No pending order, same-label retry, same-label reversal, scale-in, pyramid,
grid, martingale, trailing stop, break-even move, partial exit, or
signal-magnitude sizing is authorized.

## 6. Source Citation

Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021), “Asymmetry, tail risk and
time series momentum,” *International Review of Financial Analysis* 78,
101938, DOI `10.1016/j.irfa.2021.101938`.

The governed complete-read packet is
`strategy-seeds/sources/LIU-MTSM-2021/source.md`. It supports the 30-day base
momentum, five-day upper/lower partial moments, separate recursive
80th-percentile regions, and exact S2 map. Natural gas, the Darwinex CFD,
fixed-dollar risk, bounded 252-observation references, ATR stop, spread cap,
and Friday packaging are explicit QM translations.

## 7. Risk Model

The only authorized preset is the backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Q02 retires the unchanged baseline
on zero positions, fewer than five completed positions in any full scored
year, nonpositive governed economics, invalid fixed-risk mode, future leakage,
wrong partial-moment or percentile arithmetic, wrong S2 state, duplicate
attempt, same-label reversal, missing stop, malformed lifecycle, or
nondeterminism.

Passing Q02 would establish executable baseline evidence only. It would not
establish source-to-XNG transport, profitability, robustness, low correlation,
or portfolio admission. Certified `QM5_12567` is mechanically different: it
is a long-only cumulative-RSI2 pullback under a 200-D1 trend state, while this
EA is symmetric and can reverse or flatten momentum from asymmetric squared
return tails. Realized overlap remains a downstream Q09 question.

No live, demo, shadow, stress, or optimization preset; terminal control;
AutoTrading action; `T_Live`; deploy manifest; portfolio-gate edit; portfolio
admission; decorrelation claim; or correlation waiver is authorized.

## 8. Framework Alignment

- No-trade: exact host, slot, identity, fixed risk, news, Friday, stress, and
  signal-parameter locks.
- Entry: completed-data 30/5/252/80 S2 target, excluded-current nearest-rank
  references, durable one-shot label, quote/spread gates, and frozen ATR stop.
- Management: exact-magic malformed/stale repair, new-D1 flat/opposed closure,
  same-side retention, and restart-safe no-same-label reversal.
- Close: all owned closes route through the framework transaction manager;
  the broker stop and framework Friday closure are backstops.

## 9. Pipeline History

| phase | date | verdict | next |
|---|---|---|---|
| Source approval | 2026-08-31 | APPROVED_SOURCE | G0 |
| G0 | 2026-08-31 | APPROVED | Q01 |
| Q01 | 2026-08-31 | pending strict compile | Q02 |
| Q02 | 2026-08-31 | not enqueued | requires Q01 PASS and CPU admission |
