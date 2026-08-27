# QM5_41182_wti-median-runs-tr - Strategy Spec

**EA ID:** QM5_41182

**Slug:** `wti-median-runs-tr`

**Strategy ID:** `MOP-NIST-WTI-MEDRUN-TREND-2026_S01`

**Source:** `MOP-NIST-WTI-MEDRUN-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Require positive, finite,
pairwise-distinct closes and assign strict ordinal price ranks 1 through 13,
oldest observation first.

Omit the unique rank-seven observation. Map each of the remaining ranks below
seven to `-1` and above seven to `+1`, preserving chronology and making the
two observations on either side of the omitted median adjacent. Count runs in
that twelve-sign sequence. Continue the newest actual endpoint's regime only
when the run count is at most seven: buy above the median, sell below it, and
stay flat when the newest endpoint is the median or the run count exceeds
seven.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. Run count never
changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_max_runs` | 7 | inclusive persistence gate |
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
- Magic: `411820000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
RANK[i] = strict price rank of C[i], 1 = smallest, 13 = largest
require sorted(RANK) = 1..13

B = [sign(RANK[i] - 7) for i=0..12 if RANK[i] != 7]
require len(B)=12, count(-1)=6, count(+1)=6

RUNS = 1 + count(B[k] != B[k-1], k=1..11)
require 2 <= RUNS <= 12

BUY  iff RUNS <= 7 and RANK[12] > 7
SELL iff RUNS <= 7 and RANK[12] < 7
FLAT otherwise
```

The formation and decision cadence are monthly. The current month contributes
no signal close. Equal closes, tie averaging, a sign for the median, a split
at the omitted median, significance claims, and floating thresholds are
forbidden.

## 5. Expected Behaviour

- Pre-result density prior: five to nine completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- Exact enumeration of 924 balanced binary sequences and thirteen median
  positions gives 6,744 qualifying representations of 12,012, split equally
  by side. That is `562/1001`, or about 6.737 random-order opportunities per
  year. Multiplying by the within-regime rank permutations gives
  3,496,089,600 qualifying paths of 13!. This locks density, not expected
  performance.
- The median-dichotomy run count is mechanically distinct from return-sign
  run length, pair-sign order, adjacent-distance, turning-point, and
  time-rank displacement WTI neighbors. Only Q09 may establish decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

NIST/SEMATECH e-Handbook of Statistical Methods, "Runs Test for Detecting
Non-randomness," official NIST page.

Canonical bounded packet:
`strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`.
The sources supply WTI monthly-continuation and above/below-median runs-method
lineage. They do not test this thirteen-endpoint threshold or continuous-CFD
trading conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, fitted threshold, retry, scale-in, grid, martingale, target, trail,
break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread, quote,
ATR, sizing, margin, or order checks. Missing or duplicate month keys, mixed
label conventions, stale endpoints, nonpositive/nonfinite/equal closes, wrong
endpoint count, invalid rank permutation, median count other than one, wrong
six/six sign balance, or a run count outside 2..12 fails flat. A run count
above seven or newest rank seven consumes flat. An order reject never retries
the month. Lifecycle repair runs every tick before entry-only gates and closes
duplicate, malformed, wrong-side, later-month, or stale exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict ranks, median omission, balanced signs, run count,
  inclusive threshold, spread/quote/ATR/stop checks, and one fixed-risk
  request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card and governed magic `411820000` |
