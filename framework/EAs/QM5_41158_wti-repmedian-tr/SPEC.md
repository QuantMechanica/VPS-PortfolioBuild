# QM5_41158_wti-repmedian-tr - Strategy Spec

**EA ID:** QM5_41158

**Slug:** `wti-repmedian-tr`

**Strategy ID:** `MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01`

**Source:** `MOP-SIEGEL-WTI-REPMEDIAN-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-25

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close in each of the immediately prior thirteen
consecutive broker months. Require positive finite closes, strictly increasing
endpoint timestamps, an immediately prior newest endpoint, and a newest
endpoint no more than ten calendar days old. One label convention, raw or
raw-plus-one-day, applies to the current bar and the full history package.

Take natural logs of the thirteen chronological closes. For every pivot
`i=0..12`, form one slope to every other pivot `j`: orient the pair from the
earlier month to the later month and divide by the positive month-index
distance. Sort the twelve pivot-specific slopes and average zero-based indexes
5 and 6. Sort the resulting thirteen pivot medians and select index 6. A
strictly positive repeated median buys WTI, a strictly negative value sells,
and exact zero consumes the month flat.

The decision month is persisted before history, signal, news, spread, quote,
ATR, sizing, margin, or order gates. A valid direction owns one fixed-risk
position until the first later normalized broker month, protected by a frozen
ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_price_points` | 13 | consecutive completed month-end closes |
| `strategy_history_bars_d1` | 800 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for the single Q02 baseline. There is no optimization
surface and signal magnitude cannot alter position size.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411580000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen immediately preceding completed broker months.
- Estimator: 13 pivot groups, 12 forward-oriented slopes per group, 13 inner
  medians, and one outer median; 156 grouped slope observations in total.
- Direction: strict sign of the repeated median.
- Hold: first tick in a later normalized broker month, with a forty-day stale
  repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-WTI structural continuation after nested robust aggregation
  of completed monthly prices.
- One fixed-risk position and one consumed attempt per broker month.
- WTI supplies physical-energy exposure distinct from the certified XAU,
  SP500, NDX, and XNG carriers; only Q09 may establish realized decorrelation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Siegel, A. F. (1982), "Robust Regression Using Repeated Medians,"
*Biometrika* 69(1), 242-244, DOI `10.1093/biomet/69.1.242`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`.

The first paper supplies WTI membership and monthly own-price continuation
lineage. The official record for the second supplies nested repeated-median
method lineage; its paywalled body was not represented as read. Neither source
tests this locked WTI CFD rule. Endpoint selection, exact nesting, risk, and
lifecycle are explicitly disclosed QM mechanizations.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, global Theil-Sen fallback, endpoint-direction gate, fitted scale,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoint package, chronological logs, 13-by-12 grouped slopes, inner indexes
  5/6, outer index 6, strict sign, spread/quote/ATR/stop checks, and one
  fixed-risk request.
- trade_management: malformed or wrong-side position repair, later-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-25 | approved source build | G0-approved card and governed magic `411580000` |
