# QM5_41170_wti-bartels-rank-tr - Strategy Spec

**EA ID:** QM5_41170

**Slug:** `wti-bartels-rank-tr`

**Strategy ID:** `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026_S01`

**Source:** `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Require positive, finite,
pairwise-distinct closes and assign their ordinal ranks 1 through 13.

The Bartels rank von-Neumann numerator is the sum of the twelve squared
successive chronological rank differences. Its fixed denominator is 182.
Qualify only when `NM < 364`, the exact integer form of `RVN < 2`. Follow the
oldest-to-newest endpoint direction: buy when the endpoint rises and sell when
it falls. A nonqualifying or invalid path consumes the month flat.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. Statistic
magnitude below the boundary never changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_nm_boundary` | 364 | strict integer numerator ceiling |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411700000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
R[i] = strict ordinal rank of C[i], 1 = smallest, 13 = largest
require sorted(R) = 1..13
denominator = sum((R[i] - 7)^2) = 182
NM = sum((R[i+1] - R[i])^2, i=0..11)

BUY  iff NM < 364 and C[12] > C[0]
SELL iff NM < 364 and C[12] < C[0]
FLAT otherwise
```

The formation and decision cadence are monthly. The current month contributes
no signal close. Equal closes fail closed; average ranks, p-values, and
alternate boundaries are forbidden.

## 5. Expected Behaviour

- Pre-result density prior: five to eight completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- The normal and Beta method approximations are centered at `RVN=2`, giving a
  pre-result density prior near six decisions/year at the mean split. This is
  not an exact discrete probability or a WTI result.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- The statistic is mechanically distinct from endpoint-only momentum,
  magnitude path efficiency, all-pairs Mann-Kendall, Cox-Stuart paired signs,
  Foster-Stuart records, and XNG pullback rules. Only downstream portfolio
  evidence may establish realized decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Bartels (1982), "The Rank Version of von Neumann's Ratio Test for
Randomness," *Journal of the American Statistical Association* 77(377),
40-46, DOI `10.1080/01621459.1982.10477764`.

Caeiro and Mateus, `randtests` 1.0.2, CRAN, exact public mirror commit
`7244d86764445e657634c9ae4d59ce942a5fcbc8`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026/source.md`.
The sources supply WTI monthly-continuation and Bartels rank-ratio lineage.
They do not test this thirteen-endpoint, below-two CFD trading conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, tie averaging, dynamic boundary, retry, scale-in, grid, martingale,
target, trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing/duplicate month keys,
mixed label conventions, stale endpoints, nonpositive/nonfinite/equal closes,
wrong endpoint count, invalid rank permutation, denominator other than 182,
or `NM >= 364` fails flat. An order reject never retries the month. Lifecycle
repair runs every tick before entry-only gates and closes duplicate,
malformed, wrong-side, later-month, or stale owned exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict ranks, denominator invariant, `NM<364`, endpoint
  direction, spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411700000` |

