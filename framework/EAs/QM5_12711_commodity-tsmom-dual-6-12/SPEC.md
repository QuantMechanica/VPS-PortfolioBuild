# QM5_12711_commodity-tsmom-dual-6-12 - Strategy Spec

**EA ID:** QM5_12711
**Slug:** `commodity-tsmom-dual-6-12`
**Source:** `MOP-TSMOM-2012`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency WTI crude-oil trend sleeve on
`XTIUSD.DWX`. On the first D1 bar of each broker-calendar month, it computes
the prior six-month and twelve-month log returns from completed D1 closes. It
opens a long package only when both horizons are positive beyond the neutral
band, and a short package only when both horizons are negative beyond the
neutral band.

The strategy is not an inventory, hurricane, refinery, OPEC, expiry, weekday,
month-of-year, ratio, or reversal setup. It differs from
`QM5_12603_wti-tsmom12m` by requiring six-month confirmation, from
`QM5_12616_tsmom-9m-commodity-xtiusd` by using 6m/12m agreement instead of a
9m primary with 3m confirmation, and from `QM5_12708_commodity-tsmom-6m` by
rejecting trades when the slower twelve-month trend disagrees.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_lookback_d1` | 126 | 105-147 | Completed D1 bars used for the six-month return leg |
| `strategy_slow_lookback_d1` | 252 | 210-294 | Completed D1 bars used for the twelve-month return leg |
| `strategy_min_abs_return_pct` | 1.5 | 0.5-3.0 | Neutral band applied to both trend legs |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude-oil CFD proxy in the DWX symbol matrix.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural-gas exposure has separate XNG cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves are outside this WTI card.
- Equity indices - the mission is a different energy commodity sleeve.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 5-9 |
| Typical hold time | one monthly package, capped at 31 calendar days |
| Expected drawdown profile | medium-high crude-oil trend reversals bounded by ATR stop |
| Regime preference | persistent WTI trends with intermediate and long horizons aligned |
| Win rate target | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012`
**Source type:** `paper`
**Pointer:** `strategy-seeds/sources/MOP-TSMOM-2012/`
**R1-R4 verdict (Q00):** all PASS / see
`strategy-seeds/cards/approved/QM5_12711_commodity-tsmom-dual-6-12_card.md`

The source is Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
"Time Series Momentum", Journal of Financial Economics, 2012, URL
https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV mode validation is enforced by `QM_FrameworkInit`. No live manifest,
`T_Live` file, portfolio gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | branch-local build |
