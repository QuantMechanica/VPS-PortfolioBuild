# QM5_41176_wti-mwilcoxon-shift-tr - Strategy Spec

**EA ID:** QM5_41176

**Slug:** `wti-mwilcoxon-shift-tr`

**Strategy ID:** `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01`

**Source:** `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026`

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close in each of the immediately prior twelve
consecutive completed broker months. Split the chronological closes into a
fixed older block of six and a fixed newer block of six. Exact price ties fail
closed.

Count all 36 cross-block comparisons. `U_new` increments when a newer close
exceeds an older close and `U_old` increments for the reverse. Require
`U_new + U_old = 36`. Buy when `U_new >= 24`, sell when `U_new <= 12`,
and consume the month flat otherwise.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. Statistic
magnitude never changes risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 12 | consecutive completed month-end closes |
| `strategy_block_size` | 6 | older and newer fixed block size |
| `strategy_u_lower` | 12 | inclusive short boundary |
| `strategy_u_upper` | 24 | inclusive long boundary |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction |
| `strategy_entry_window_minutes` | 180 | raw current-bar entry window |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |
| `strategy_deviation_points` | 20 | market-order deviation |

There is no optimization surface.

## 3. Symbol And Identity

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411760000`.
- No companion, conversion, ratio, hedge, or external symbol exists.

## 4. Formula

```text
O = C[0..5]
N = C[6..11]

require all C positive, finite, and pairwise distinct

U_new = count(N[j] > O[i]) across all i,j in 0..5
U_old = count(O[i] > N[j]) across all i,j in 0..5
require U_new + U_old == 36
require U_new == combined_rank_sum(N) - 21

BUY  iff U_new >= 24
SELL iff U_new <= 12
FLAT otherwise
```

The split never moves and the runtime never computes a p-value, averages
ties, searches for a change point, or falls back to endpoint direction.

## 5. Risk And Lifecycle

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The entry receives a frozen
`3.5*ATR(20,D1)` stop and no target. Both news axes, legacy news, and Friday
close are OFF.

The normalized broker month is persisted before history, arithmetic, news,
spread, quote, ATR, sizing, margin, or order checks. A rejection never retries
that month. Lifecycle repair runs before entry-only gates on every tick and
closes duplicate, malformed, wrong-side, later-month, or forty-day-stale
owned exposure.

## 6. Expected Behaviour

- Pre-result density prior: four to eight completed positions per full
  post-warm-up year; Q02 retires below four in any full year.
- Exact enumeration of the 924 no-tie six-rank assignments gives 182 paths at
  each tail, 364 total, or a 0.393939 random-rank qualification rate.
- This locks activity design only; it is not a significance, performance, or
  correlation claim.
- The direct-WTI location-shift mechanic is distinct from the certified
  short-horizon XNG oscillator. Q09 alone may establish portfolio overlap.

## 7. Sources And Claim Boundary

Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Mann and Whitney (1947), “On a Test of Whether one of Two Random Variables is
Stochastically Larger than the Other,” *The Annals of Mathematical
Statistics* 18(1), 50-60, DOI `10.1214/aoms/1177730491`.

R Core Team, `stats::wilcox.test` source and manual, pinned public
`wch/r-source` mirror commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82`.

Canonical packet:
`strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`.
The sources supply monthly WTI continuation and two-sample ordinal lineage;
they do not test this exact continuous-CFD rule or threshold.

## 8. Deterministic Failure Contract

Missing or duplicate month keys, mixed label conventions, stale endpoints,
nonpositive/nonfinite/equal closes, wrong endpoint count, changed block size,
invalid U range, failed complement or rank-sum identity, and central U all
fail flat after consuming the month. No external runtime feed, fitted
parameter, machine learning, grid, martingale, scale-in, trail, target,
partial close, live preset, or deployment action is authorized.

## Framework Alignment

- `no_trade`: exact identity, symbol, period, fixed risk, news/Friday, and
  locked strategy inputs.
- `trade_entry`: month clock, durable attempt, consecutive endpoints,
  fixed blocks, both U counts, rank-sum identity, inclusive thresholds,
  spread/quote/ATR/stop checks, and one fixed-risk request.
- `trade_management`: integrity and side repair, next-month close, and
  forty-day stale repair before entry-only gates.
- `trade_close`: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v0 | 2026-08-27 | G0-approved source build with governed magic `411760000` |
