# QM5_20233 XAU/XAG Skewness Rank G0 Authorization

Date: 2026-08-06

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch.

## Decision

Authorize one bounded V5 research card and non-live build for
`QM5_20233_xauxag-skew-rank`. At each broker-month boundary, calculate
Pearson's standardized third moment from daily log returns in the preceding
twelve complete broker-calendar months for gold and silver. Buy the lower-
skew metal, short the higher-skew metal, and renew the logical two-leg package
at the next month boundary. A numerical tie or invalid history consumes the
month and remains flat.

The candidate may proceed through deterministic card lint, EA and magic
allocation, strict compile, one logical-basket `RISK_FIXED` backtest setfile,
and one paced Q02 enqueue. G0 does not pre-approve profitability,
decorrelation, certification, execution-contract promotion, or portfolio
admission.

## Source boundary

The governed packet is
`strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md`. Its complete source is
Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), "The Skewness of
Commodity Futures Returns," *Journal of Banking & Finance* 86, 143-158, DOI
`10.1016/j.jbankfin.2017.06.015`. The complete 44-page accepted manuscript was
reviewed end to end. It explicitly includes gold and silver, forms monthly
low-minus-high portfolios from Pearson skewness over the prior twelve months
of daily log returns, and holds for one month.

The source tests 27 futures and extreme quintiles, not a two-metal Darwinex
CFD package. It does not test equal fixed-risk halves, ATR stops, broker-month
reconstruction, legging, financing, the QM book, or this carrier's realized
neutrality. No source return, significance, Sharpe, drawdown, cost, or
correlation statistic transfers.

## Non-duplicate decision

The deterministic pre-allocation check scanned 4,290 registry rows and 406
cards. It found no exact identity and one expected fuzzy same-source match,
`QM5_13118_energy-skew-rank`. Manual review resolves it as a locked carrier
extension: `QM5_13118` trades XTI/XNG, while this candidate trades XAU/XAG and
does not change the 12-month estimator, rank direction, or monthly hold.

Existing XAU/XAG builds use fixed-ratio or OLS convergence, conditional
quantile envelopes, channel breakouts, calendar differentials, return shocks,
relative momentum, idiosyncratic volatility, or momentum/IVol agreement. None
ranks gold and silver by the third standardized moment of completed daily
returns. `QM5_12567` is a short-horizon cumulative-RSI pullback, not a paired
monthly cross-sectional moment strategy.

The exact prior-twelve-complete-month window, Pearson third standardized
moment, lower-skew long/higher-skew short direction, monthly lifecycle, and
XAU/XAG carrier are jointly load-bearing. No parameter, direction, threshold,
or post-result repair sweep is authorized.

## Allocation and kill boundary

- EA ID: `QM5_20233`
- slug: `xauxag-skew-rank`
- strategy ID: `FERNANDEZ-SKEW-2018_XAU_XAG_S02`
- slot 0: `XAUUSD.DWX` / magic `202330000`
- slot 1: `XAGUSD.DWX` / magic `202330001`
- cadence: one paired package per valid broker month after warm-up, expected
  approximately twelve completed packages/year
- retire below five completed packages per full post-warm-up year
- no lookback, direction, estimator, hold, threshold, or carrier sweep and no
  post-result rescue is authorized

## Safety boundary

This authorization excludes manual backtests; live, demo, and shadow
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; correlation waivers; and downstream
promotion. Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` on one logical basket target.
