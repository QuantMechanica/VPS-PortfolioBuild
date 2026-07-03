# QM5_12980_brent-6m-rev - Strategy Spec

**EA ID:** QM5_12980
**Slug:** `brent-6m-rev`
**Source:** `BIANCHI-COMM-52W-2016` plus `YANG-COMM-REVERSAL-2017`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency Brent overextension fade on `XBRUSD.DWX`.
On the first D1 bar of each broker-calendar month, it measures the completed
120-D1-bar return. If the return is above the configured positive threshold
and price is stretched above SMA(20) by the configured ATR multiple, the EA
sells. If the return is below the negative threshold and price is stretched
below SMA(20), the EA buys.

The strategy is intentionally not a duplicate of `QM5_12567`: that EA trades
short-horizon cumulative RSI2 pullbacks. It is also distinct from
`QM5_12979`, which trades WTI instead of Brent, `QM5_12859`, which follows a
Brent 52-week anchor momentum rule, and the Brent weekday/month cards whose
entries are fixed calendar anomalies.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_days` | 120 | 90-160 | Completed D1 close lookback for the overextension return |
| `strategy_sma_period` | 20 | 10-40 | Mean reference used for stretch confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stretch and stop calculations |
| `strategy_fade_threshold_pct` | 15.0 | 12-20 | Absolute 120-bar return needed before fading |
| `strategy_stretch_atr_mult` | 1.25 | 1.0-1.75 | ATR stretch from SMA required for confirmation |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance |
| `strategy_max_hold_days` | 45 | 30-60 | Stale-position time exit |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Typical hold: multi-week, bounded by return zero-cross or 45-day max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Bianchi, R. J., Drew, M. E. and Fan, J. H. "Commodities momentum: A behavioural
perspective." Journal of Banking and Finance, 2016.
DOI: https://doi.org/10.1016/j.jbankfin.2016.06.010.

Yang, Goncu, and Pantelous. "Momentum and Reversal in Commodity Futures." SSRN
working paper. URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from card | Enqueue Q02 |
