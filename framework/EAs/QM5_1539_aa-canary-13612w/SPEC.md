# QM5_1539_aa-canary-13612w — Strategy Spec

**EA ID:** QM5_1539
**Slug:** `aa-canary-13612w`
**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1539_aa-canary-13612w.md`
**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first D1 bar of each calendar month, calculate the card's 13612W
momentum score from closed daily bars:

`M = 12*r_1m + 4*r_3m + 2*r_6m + r_12m`

The DWX month proxies are 21, 63, 126, and 252 daily bars. The card names four
proxy observations across its risk-appetite and macro-stress canary groups;
this build evaluates all four: `NDX.DWX`, `GDAXI.DWX`, `USDJPY.DWX`, and
`XAUUSD.DWX`. A canary is bad when `M <= 0`. With the approved threshold
`B=1`, the regime is risk-on only when all four scores are positive.

- Risk-on: choose the highest positive score from `SP500.DWX`, `NDX.DWX`,
  `WS30.DWX`, and `GDAXI.DWX`.
- Defensive: choose the highest positive score from `XAUUSD.DWX`,
  `EURUSD.DWX`, and `USDJPY.DWX`.
- Hold cash when every candidate in the active sleeve is non-positive.
- Equal positive scores resolve deterministically to the first listed symbol.
- Each symbol-hosted instance enters long only when its chart symbol is the
  selected global winner. At the next monthly rebalance it holds, closes, or
  rotates according to the new winner.
- Initial stop distance is `3.0 * ATR(20,D1)`; there is no take-profit or
  intramonth strategy exit.

Missing history for any required canary or active-sleeve candidate fails the
whole monthly decision closed. No proxy substitution, leveraged bond sleeve,
shorting, ML, grid, martingale, or dynamic leverage is added.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_tf` | `PERIOD_D1` | Signal, ATR, and rebalance timeframe |
| `strategy_bad_canary_threshold` | `1` | Defensive when this many canaries have `M <= 0` |
| `strategy_lookback_1_days` | `21` | One-month daily-bar proxy |
| `strategy_lookback_3_days` | `63` | Three-month daily-bar proxy |
| `strategy_lookback_6_days` | `126` | Six-month daily-bar proxy |
| `strategy_lookback_12_days` | `252` | Twelve-month daily-bar proxy |
| `strategy_min_history_bars` | `260` | Fail-closed history minimum per referenced symbol |
| `strategy_atr_period` | `20` | D1 ATR period |
| `strategy_stop_atr` | `3.0` | Initial stop distance in ATR |

The four canary symbols, four risk-sleeve candidates, and three defensive
candidates are explicit string inputs with the defaults listed above.

## 3. Symbol Universe

The active selection universe is the seven unique sleeve candidates
`SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`,
`EURUSD.DWX`, and `USDJPY.DWX`. The 13 active magic-registry symbols also
include `UK100.DWX`, `GBPUSD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`,
`USDCAD.DWX`, and `NZDUSD.DWX`; those hosts remain in cash under the approved
default sleeve mapping. SP500 is research/backtest-only pending the card's
parallel NDX/WS30 validation condition.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Decision cadence | First D1 bar of each calendar month |
| Signal data | Closed D1 bars only |
| History minimum | 260 closed D1 bars per referenced symbol |

## 5. Expected Behaviour

Every symbol instance derives the same regime and winner from the same closed
cross-symbol D1 observations. Only the instance whose chart symbol equals the
winner may enter. Existing positions are revalidated monthly and a losing
host closes before it can make any further entry. Cash is explicit when no
active-sleeve candidate has positive momentum.

### Framework alignment

| Card rule | Implementation surface |
|---|---|
| Monthly rebalance | `Strategy_IsMonthlyRebalance` on the D1 new-bar path |
| 13612W score | `Strategy_Momentum13612W` using 21/63/126/252 closed bars |
| Bad-canary threshold | `Strategy_PrepareMonthlySelection` with `M <= 0` and `B=1` |
| Best-one sleeve selection | Strict positive maximum with declared tie order |
| 3 ATR initial stop | `Strategy_EntrySignal` using the D1 ATR handle |
| One position per symbol/magic | `Strategy_SelectOurPosition` plus framework entry checks |
| Fixed-risk backtest | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Operational safety | Framework news blackout, kill switch, Friday-close override, execution contract, and MAE tracking |

The card metadata says 100 expected trades per year per symbol, but its
approved monthly rebalance mechanic permits at most twelve strategy decisions
per year. The executable follows the mechanical monthly rule; the metadata is
not converted into unapproved intramonth trading.

## 6. Source Citation

The approved card cites Wouter Keller, “Trend Following on Steroids,” Alpha
Architect, 2018-12-07, and carries durable source ID
`ede348b4-0fa7-5be1-baa8-09e9089b67b7`. The governed implementation source is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1539_aa-canary-13612w.md`.

## 7. Risk Model

This build is for compile and non-live testing only. Backtest setfiles use
`RISK_FIXED=1000` and `RISK_PERCENT=0`. Any live risk setting, proxy change,
portfolio division, SP500 substitution, or deployment requires the later
governed pipeline and OWNER approval. Build success is not a pipeline or live
verdict.
