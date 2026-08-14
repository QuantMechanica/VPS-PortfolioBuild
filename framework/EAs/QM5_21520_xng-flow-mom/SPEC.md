# QM5_21520_xng-flow-mom — Strategy Spec

**EA ID:** QM5_21520  
**Slug:** `xng-flow-mom`  
**Strategy ID:** `ZHAO-ST-MOMREV-2026_XNG_S04`  
**Source ID:** `ZHAO-XNG-QUIETFLOW-2026`  
**Last revised:** 2026-08-14

## 1. Strategy Logic

At the first D1 bar in each framework broker-week bucket, compute the latest
completed five-D1 XNG close return and native tick-volume sum. Rank that
volume sum against 40 earlier, non-overlapping five-bar volume sums. A rank at
or below 25% permits a position in the return's direction; a higher rank or
zero return consumes the week flat.

The week key is persisted before history, signal, news, spread, quote, sizing,
or order gates, so a blocked attempt cannot retry. An accepted entry receives
a frozen ATR hard stop and no take-profit. Exit after five completed D1 bars,
at the hard stop, or through framework Friday close.

This is a disclosed native tick-volume proxy for a quiet, residual-dominated
week, not a reproduction of the source's investor-position decomposition.

## 2. Parameters

| parameter | default | authorized range | meaning |
|---|---:|---|---|
| `strategy_vol_lookback` | 40 | 26, 40, 60 | earlier disjoint five-bar volume windows |
| `strategy_vol_percentile_cap` | 25.0 | 15, 25, 33 | maximum empirical quiet-volume rank |
| `strategy_atr_period` | 14 | 10, 14, 20 | completed-D1 ATR period |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.0, 3.5 | frozen hard-stop distance |
| `strategy_max_hold_bars` | 5 | 3, 5, 7 | completed D1 bars before time exit |
| `strategy_max_spread_points` | 600 | 300, 600, 1000 | entry spread ceiling |

The five-bar formation, non-overlapping baseline, native tick-volume input,
lower-tail admission, continuation direction, and one-attempt-per-week rule
are locked.

## 3. Symbol Universe

- `XNGUSD.DWX` only, slot 0, magic `215200000`.
- No external feed, secondary symbol, or basket leg.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision gate: framework `PERIOD_W1` transition evaluated on new D1 bars.
- All return, volume, ATR, and time-exit inputs use completed D1 bars.

## 5. Expected Behaviour

- Approximately 10-14 entries/year is a prior, not test evidence.
- Q02 retires below five completed trades per full post-warm-up year.
- Direction is symmetric continuation of the latest five-D1 return.
- Eligible regime is bottom-quartile native tick volume.
- Hold is at most five completed D1 bars, with hard-stop and Friday-close
  authority.

## 6. Source Citation

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026, DOI
`10.2139/ssrn.6425598`,
`https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.

The bounded packet contains metadata and accessible abstract/methodology
summaries, not inaccessible full text. The source supplies the weekly
residual-component momentum direction; it does not supply the XNG
tick-volume proxy, thresholds, lifecycle, performance, or correlation claim.

## 7. Risk Model

| phase | risk mode | value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Backtest percentage risk | `RISK_PERCENT` | 0 |
| Backtest portfolio weight | `PORTFOLIO_WEIGHT` | 1 |

The EA owns at most one position per magic, uses V5 sizing and kill switch,
and fails closed on invalid history, volume, ATR, spread, quote, stop, host,
or parameter state. No live/demo/shadow/stress setfile, manual backtest,
deploy action, `T_Live`, AutoTrading change, portfolio-gate edit, or portfolio
admission is authorized.
