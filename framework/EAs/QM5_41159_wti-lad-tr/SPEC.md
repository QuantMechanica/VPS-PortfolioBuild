# QM5_41159_wti-lad-tr - Strategy Spec

**EA ID:** QM5_41159

**Slug:** `wti-lad-tr`

**Strategy ID:** `MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01`

**Source:** `MOP-KOENKER-BASSETT-WTI-LAD-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-25

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive broker months. Require positive finite closes, strictly increasing
endpoint timestamps, an immediately prior newest endpoint, and a newest
endpoint no more than ten calendar days old. One label convention, raw or
raw-plus-one-day, applies to the current bar and the full history package.

Take natural logs of the thirteen chronological closes and assign integer time
coordinates zero through twelve. Enumerate all 78 pairwise slopes in
lexicographic `(older,newer)` order. For each candidate slope, form thirteen
residuals, use sorted residual index 6 as the intercept, and sum the thirteen
absolute vertical errors in chronological observation order. Retain every
candidate within `1e-12` of the minimum objective and take their ordinary
median. A positive LAD slope buys WTI, a negative value sells, and exact zero
consumes the month flat.

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
| `strategy_loss_tie_tolerance` | 1e-12 | fixed numerical loss-equality guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for the single Q02 baseline. There is no optimization
surface and signal, intercept, loss, or minimizer count cannot alter position
size.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411590000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen immediately preceding completed broker months.
- Estimator: 78 pairwise slope breakpoints; 13 residuals and one median
  intercept per candidate; 78 absolute-loss objectives; one median over all
  minimizing slopes.
- Direction: strict sign of the final LAD slope.
- Hold: first tick in a later normalized broker month, with a forty-day stale
  repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-WTI structural continuation after absolute-loss robust
  aggregation of completed monthly prices.
- One fixed-risk position and one consumed attempt per broker month.
- WTI supplies physical-energy exposure distinct from the certified XAU,
  SP500, NDX, and XNG carriers; only Q09 may establish realized decorrelation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`.

The first paper supplies WTI membership and monthly own-price continuation
lineage. The second supplies Koenker-Bassett check-loss regression lineage
through a complete-read author preprint and also records adverse evidence.
Neither source tests this locked WTI CFD rule. Endpoint selection, exact
breakpoint solver, tie convention, risk, and lifecycle are disclosed QM
mechanizations.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, OLS/Theil-Sen/repeated-median fallback, endpoint-direction gate,
fitted scale, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoint package, chronological logs, 78 pair slopes, residual median index
  6, absolute-loss objectives, fixed tie set, ordinary minimizer median,
  strict sign, spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side position repair, later-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-25 | approved source build | G0-approved card and governed magic `411590000` |
