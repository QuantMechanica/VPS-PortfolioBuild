# QM5_1538_aa-tsmom-1-3-12 — Strategy Spec

**EA ID:** QM5_1538
**Slug:** `aa-tsmom-1-3-12`
**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md`
**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first D1 bar of each calendar month, calculate raw price returns over
21, 63, and 252 closed daily bars as deterministic broker-data proxies for
one, three, and twelve months. Each positive return contributes `+1`, each
negative return `-1`, and an unavailable or exactly zero return contributes
`0`.

- Enter long when the aggregate is at least `+2`.
- Enter short when the aggregate is at most `-2`.
- Hold cash for aggregate values `-1`, `0`, or `+1`.
- At each monthly rebalance, close a long below `+2` and close a short above
  `-2`; reverse only after the existing position closes successfully.
- Initial stop distance is `3.0 * ATR(20,D1)`.
- There is no intramonth strategy exit or take-profit; the position is
  revalidated monthly, subject to framework safety exits.

The 21/63/252-day mapping and raw-return calculation are the documented DWX
broker-data approximation authorized by the card. No risk-free series,
volatility scaling, dynamic leverage, ML, grid, or martingale logic is used.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_tf` | `PERIOD_D1` | Strategy and rebalance timeframe |
| `strategy_atr_period` | `20` | D1 ATR period |
| `strategy_lookback_1_days` | `21` | One-month daily-bar proxy |
| `strategy_lookback_3_days` | `63` | Three-month daily-bar proxy |
| `strategy_lookback_12_days` | `252` | Twelve-month daily-bar proxy |
| `strategy_min_history_bars` | `260` | Fail-closed history minimum |
| `strategy_stop_atr` | `3.0` | Initial stop distance in ATR |

## 3. Symbol Universe

The 13 active magic-registry symbols are `GDAXI.DWX`, `NDX.DWX`,
`SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`,
`GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`,
and `NZDUSD.DWX`. SP500 is research/backtest-only until the card's parallel
NDX/WS30 validation condition is satisfied.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Decision cadence | First D1 bar of each calendar month |
| Signal data | Closed D1 bars only |
| History minimum | 260 closed D1 bars |

## 5. Expected Behaviour

The EA should make at most one directional rebalance decision per symbol per
month. It holds an existing qualifying trend, exits a signal that no longer
has two agreeing horizons, and reverses only after a successful close. It
remains in cash when no two horizons agree. Intramonth price movement cannot
change the strategy signal; only framework safety controls remain active.

### Framework alignment

| Card rule | Implementation surface |
|---|---|
| Monthly rebalance | `Strategy_IsMonthlyRebalance` on the D1 new-bar path |
| 1/3/12 return votes | `Strategy_PrepareMonthlySignal` |
| Long/short/cash thresholds | `Strategy_EntrySignal` and `Strategy_ExitSignal` |
| 3 ATR initial stop | `Strategy_EntrySignal` using the D1 ATR handle |
| One position per symbol/magic | `Strategy_SelectOurPosition` plus framework entry checks |
| Fixed-risk backtest | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| News and operational safety | V5 framework news, kill-switch, Friday-close override, and execution contract |

## 6. Source Citation

The approved card attributes the mechanic to Larry Swedroe's Alpha Architect
summary of Hurst, Ooi, and Pedersen's long-run trend-following evidence. The
durable source/card identity is `ede348b4-0fa7-5be1-baa8-09e9089b67b7` and
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md`.

## 7. Risk Model

This build is for compile and non-live testing only. Backtest setfiles use
`RISK_FIXED=1000` and `RISK_PERCENT=0`. Any live risk setting, portfolio
division, SP500 substitution, or deployment requires the later governed
pipeline and OWNER approval. Build success is not a pipeline or live verdict.
