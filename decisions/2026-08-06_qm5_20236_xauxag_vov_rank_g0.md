# QM5_20236 XAU/XAG Realized-VoV Rank G0 Authorization

Date: 2026-08-06

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch.

## Decision

Authorize one bounded V5 research card and non-live build for
`QM5_20236_xauxag-vov-rank`. On the first tradable XAU D1 bar of each broker
month, calculate 252 overlapping realized-volatility observations for each
metal, with every observation formed from exactly 20 completed D1 log returns.
Compute each metal's realized volatility-of-volatility as the population
standard deviation of those observations divided by their mean. Buy the
lower-VoV metal, short the higher-VoV metal, and renew the logical package at
the next broker-month transition. A numerical tie, stale endpoint,
insufficient history, nonpositive variance or mean, or invalid arithmetic
consumes the month and remains flat.

The candidate may proceed through deterministic card lint, EA and magic
allocation, strict compile, one logical-basket `RISK_FIXED` backtest setfile,
and one paced Q02 enqueue. G0 does not pre-approve profitability,
decorrelation, certification, execution-contract promotion, or portfolio
admission.

## Source boundary

The governed packet is
`strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md`. Its complete source is
Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in Commodity Futures
Markets," *Quarterly Journal of Finance* 11(4), article 2150017, DOI
`10.1142/S2010139221500178`. The repository packet records a complete read of
the 57-page accepted article and online appendix, including the construction,
portfolio tests, regressions, alternative portfolio counts, subperiods,
annual holds, tables, and bibliography.

The paper measures option-implied VoV across a broad futures universe. The EA
uses a declared price-native realized-VoV proxy because Darwinex CFD runtime
has no commodity option chain. The paper does not test a two-metal CFD
package, equal fixed-risk halves, ATR stops, broker calendars, legging,
financing, the QM book, or realized neutrality. No source return, alpha,
significance, cost, drawdown, or correlation statistic transfers.

The locked XTI/XNG parent `QM5_13146_energy-vov` passed Q02 through Q07 and
then failed Q08 (`EDGE_HARD` runs-test classification, with separate invalid
neighborhood/PBO evidence). Its full-history Q08 baseline was PF 1.22 across
132 tester trades, but those results are adverse context rather than a prior
for XAU/XAG. This carrier is not a post-result parameter or direction rescue.

## Non-duplicate decision

The deterministic pre-allocation check scanned 4,293 registry rows and 409
canonical cards. It found no exact identity and five lexical fuzzy matches:

- `QM5_13146_energy-vov` is the locked XTI/XNG carrier sibling. This candidate
  changes only to the OWNER-requested market-neutral precious-metal carrier;
  it does not alter the source estimator, direction, cadence, or lifecycle.
- `QM5_20233_xauxag-skew-rank` measures the centered third moment;
  `QM5_20234_xauxag-rsj` compares positive and negative semivariance; and
  `QM5_20235_xauxag-es-rank` averages the lower five-percent tail. None
  measures dispersion across rolling realized-volatility observations.
- Existing XAU/XAG ratio, OLS residual, quantile, momentum, calendar, shock,
  and idiosyncratic-volatility baskets use different information objects,
  transforms, directions, or clocks.
- `QM5_1212_carver-kurtsabs`, `QM5_1221_carver-kurtsrv`, and
  `QM5_10322_realized-moments` are daily/weekly higher-moment composites, not
  a monthly pure realized-VoV rank.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback rather than an opposite-side uncertainty premium.

The 20-return inner window, 252 overlapping RV observations, sample variance
inside RV, population dispersion across RV, division by mean RV,
low-minus-high direction, XAU/XAG carrier, monthly renewal, equal risk halves,
and no same-month retry are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Allocation and kill boundary

- EA ID: `QM5_20236`
- slug: `xauxag-vov-rank`
- strategy ID: `HOLLSTEIN-VOV-2021_XAU_XAG_S02`
- slot 0: `XAUUSD.DWX` / magic `202360000`
- slot 1: `XAGUSD.DWX` / magic `202360001`
- cadence: one paired package per valid broker month, expected approximately
  twelve completed packages/year after warm-up
- retire below five completed packages per full post-warm-up year
- retire on invalid nested-estimator construction, wrong direction,
  incomplete package accounting, nonpositive governed economics, or later
  portfolio-correlation rejection
- no implied-volatility claim, post-result rescue, or correlation waiver is
  authorized

## Safety boundary

This authorization excludes manual backtests; live, demo, and shadow setfiles;
`T_Live`; AutoTrading; deploy or T_Live manifests; portfolio admission;
portfolio-gate edits; and downstream promotion. Q02 uses exactly
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` on one logical
basket target.
