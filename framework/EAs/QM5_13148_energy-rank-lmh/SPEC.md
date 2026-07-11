# QM5_13148_energy-rank-lmh - Strategy Spec

**EA ID:** QM5_13148
**Slug:** energy-rank-lmh
**Strategy ID:** FERNHOLZ-KOCH-RANK-2016_XTI_XNG_S01
**Source:** Fernholz and Koch (2016), Federal Reserve Bank of Dallas Working Paper 1607
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker month, it divides each leg's latest completed close by that leg's
completed close at one locked common 2017-01-03 origin. It buys the lower
normalized-price leg and shorts the higher one.

Fixed package risk is split equally, both legs receive frozen ATR(20) times
3.5 hard stops, and the package closes at the next monthly transition, after
40 days, or immediately on an orphan or invalid composition. The two-CFD,
monthly carrier is a falsification of the source's broad daily futures ranks,
not a replication.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_anchor_date | 2017.01.03 | locked | immutable normalization origin |
| strategy_max_anchor_gap_days | 7 | locked | maximum substitute-bar delay from origin |
| strategy_min_anchor_age_bars | 20 | locked | completed post-anchor warm-up |
| strategy_history_bars | 3000 | 2600-3600 | bounded D1 retrieval buffer |
| strategy_max_endpoint_gap_days | 10 | 7-10 | completed endpoint freshness |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The origin, anchor bound, warm-up, normalized-level comparison, low-minus-high
direction, monthly cadence, equal half-risk carrier, and no same-month re-entry
are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13148_XTI_XNG_RANK_LMH_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131480000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131480001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when completed
host bar dates show that the current D1 bar is the first tradable bar of a new
broker month. Current D1 bars are excluded from normalization.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after the 20-bar warm-up;
  retire below five packages/year.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and equal fixed-risk, not guaranteed dollar,
  beta, volatility, factor, rank, or realized market neutral.
- XNG gaps, legging, the arbitrary but locked origin, two-name concentration,
  daily-to-monthly translation, and continuous-CFD basis make risk high.

## 6. Source Citation And Evidence Boundary

Fernholz, Ricardo T., and Christoffer Koch (2016), "The Rank Effect for
Commodities," Federal Reserve Bank of Dallas Working Paper 1607, revised
March 22, 2026. Institutional paper:
https://www.dallasfed.org/-/media/documents/research/papers/2016/wp1607.pdf.
Approved-card and R1-R4 evidence:
`strategy-seeds/cards/energy-rank-lmh_card.md`.

The source ranks 30 collateralized commodity futures using daily normalized
prices and equal dollar groups. The EA ranks two continuous energy CFDs at a
monthly cadence and adds implementation risk controls. No source return,
drawdown, cost, significance, turnover, or correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls QM_LotsForRisk and applies the 0.5 package share after framework
sizing. It validates broker volume metadata and flattens a failed two-leg
entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked origin/warm-up, bounded history, common
  anchor/endpoint, freshness, finite arithmetic, spread, ATR, lot, magic,
  package, and prior-attempt guards.
- Entry: monthly fixed-origin normalized-price rank, paired orders, equal
  fixed-risk allocation, and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-11 | Initial build from approved card | b4396bff-5c04-4810-a974-ede2d6d2a063 |
