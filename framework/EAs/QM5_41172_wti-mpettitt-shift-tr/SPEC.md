# QM5_41172_wti-mpettitt-shift-tr - Strategy Spec

**EA ID:** QM5_41172

**Slug:** `wti-mpettitt-shift-tr`

**Strategy ID:** `MOP-PETTITT-WTI-MSHIFT-TREND-2026_S01`

**Source:** `MOP-PETTITT-WTI-MSHIFT-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Require positive, finite,
pairwise-distinct closes and assign their ordinal ranks 1 through 13.

For each split `k=1..12`, compute the signed Pettitt rank sum
`U[k] = 2*sum(R[0..k-1]) - 14*k`. Qualify only when the largest absolute
value occurs once and its split lies in the central band `k=4..9`. A negative
signed value denotes a later upward level shift and buys WTI; a positive value
denotes a later downward level shift and sells WTI. Tied maxima and edge splits
consume the month flat.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. Statistic
magnitude never changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_min_change_index` | 4 | earliest qualifying Pettitt split |
| `strategy_max_change_index` | 9 | latest qualifying Pettitt split |
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
- Magic: `411720000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
R[i] = strict ordinal rank of C[i], 1 = smallest, 13 = largest
require sorted(R) = 1..13

for k = 1..12:
    U[k] = 2 * sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]))
Kset  = {k : abs(U[k]) == Ustar}

BUY  iff size(Kset) == 1, 4 <= K <= 9, and U[K] < 0
SELL iff size(Kset) == 1, 4 <= K <= 9, and U[K] > 0
FLAT otherwise
```

Every `U[k]` must be even and lie in `[-42,42]`; `Ustar` must lie in
`[1,42]`. The formation and decision cadence are monthly. The current month
contributes no signal close. Equal closes, average ranks, p-value gates,
endpoint-direction fallbacks, and alternate split bands are forbidden.

## 5. Expected Behaviour

- Pre-result density prior: four to eight completed WTI positions per full
  post-warm-up year; Q02 retires below four in any full year.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- The unique central change-point location is mechanically distinct from the
  Bartels adjacent-rank roughness and turning-point count neighbors. Only
  downstream portfolio evidence may establish realized decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Pettitt (1979), "A Non-Parametric Approach to the Change-Point Problem,"
*Applied Statistics* 28(2), 126-135, DOI `10.2307/2346729`.

Pohlert, `trend` 1.1.7, CRAN mirror commit
`d0ec3cf8b99b4f3226f5211f592955b85565721d`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`.
The sources supply WTI monthly-continuation and Pettitt rank change-point
lineage. They do not test this thirteen-endpoint central-split CFD trading
conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, tie averaging, fitted threshold, retry, scale-in, grid, martingale,
target, trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing/duplicate month keys,
mixed label conventions, stale endpoints, nonpositive/nonfinite/equal closes,
wrong endpoint count, invalid rank permutation, odd or out-of-range sums,
tied maxima, edge maxima, or zero maximum fails flat. An order reject never
retries the month. Lifecycle repair runs every tick before entry-only gates
and closes duplicate, malformed, wrong-side, later-month, or stale exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict ranks, twelve signed sums, unique central maximum,
  signed direction, spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411720000` |

