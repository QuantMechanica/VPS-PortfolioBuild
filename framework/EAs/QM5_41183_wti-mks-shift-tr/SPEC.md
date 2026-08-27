# QM5_41183_wti-mks-shift-tr - Strategy Spec

**EA ID:** QM5_41183

**Slug:** `wti-mks-shift-tr`

**Strategy ID:** `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026_S01`

**Source:** `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026`

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close from each of the immediately prior twelve
consecutive completed broker months. Split those closes chronologically into
the fixed older six and fixed newer six. Scan their combined strict ascending
price order while retaining block membership. Continue the distribution shift
only when one maximum signed empirical-CDF count gap is both at least three
and strictly greater than the opposite gap.

This is a direct-WTI monthly structural trend hypothesis. It does not use a
KS p-value or claim statistical significance. A qualifying direction owns one
fixed-risk WTI position until the next broker month, protected by a frozen ATR
hard stop.

## 2. Locked Formula

```text
O = C[0..5]
N = C[6..11]
require C is positive, finite, and pairwise distinct

old_seen = 0
new_seen = 0
Dplus = 0
Dminus = 0

for each combined value in strict ascending order:
    increment the count for its fixed block
    delta = old_seen - new_seen
    Dplus  = max(Dplus, delta)
    Dminus = max(Dminus, -delta)

BUY  iff Dplus  >= 3 and Dplus  > Dminus
SELL iff Dminus >= 3 and Dminus > Dplus
FLAT otherwise
```

`Dplus/6` and `Dminus/6` are the one-sided ECDF gaps. Integer counts are
authoritative. Equal signed maxima, central gaps, malformed values, or any tie
consume the month flat. The fixed split may not move and within-block order
has no effect on the statistic.

## 3. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 12 | consecutive completed month-end closes |
| `strategy_block_size` | 6 | fixed older and newer sample size |
| `strategy_min_gap_count` | 3 | inclusive dominant signed-gap boundary |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_window_minutes` | 180 | first-bar execution grace |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | market-request deviation ceiling |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 4. Symbol, Cadence, And Density

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `411830000`.
- Formation and decision cadence: monthly; the current month contributes no
  signal close.
- Exactly one consumed attempt per normalized broker month and at most one
  owned position.
- Exact enumeration of the 924 strict six/six rank assignments gives 218 BUY,
  218 SELL, and 488 flat states. Directional qualification is `109/231`, or
  about 5.662 random-rank decisions per twelve months. This locks a density
  prior, not expected performance or significance.
- Q02 retires the candidate below five completed positions in any full
  post-warm-up year.

## 5. Entry And Lifecycle Contract

1. Require exact symbol, D1 period, EA ID, slot, fixed-risk, news, Friday, and
   singleton strategy inputs.
2. Process lifecycle repair and mandatory prior-month/stale exits before
   entry-only gates.
3. Persist `QM5_41183_MONTH_ATTEMPT_<magic>=yyyymm` before history,
   arithmetic, news, spread, quote, ATR, sizing, margin, or order gates.
4. A late restart, prior attempt, existing owned exposure, invalid endpoint,
   tie, central gap, or tied maximum consumes flat. An order reject never
   retries the month.
5. A valid signal must pass spread, quote, completed-bar ATR, stop, volume, and
   margin checks before one market request.
6. Size through the V5 fixed-risk helper against a frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target.
7. Close at the first later normalized broker month or after forty elapsed
   calendar days. Repair malformed, duplicate, wrong-side, or stopless owned
   exposure before considering entry.

There is no target, signal flip, recount exit, trail, break-even move, partial
exit, scale-in, grid, martingale, Friday close, or news exit.

## 6. Risk And Safety Boundary

The sole preset is a backtest set using `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes and legacy news are
OFF; Friday close is OFF. No live, demo, shadow, stress, or optimization
preset is authorized. This build does not authorize AutoTrading, `T_Live`,
deployment, portfolio admission, portfolio-gate changes, or correlation
claims.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
monthly formation staleness, small-sample rank instability, weak selectivity,
abrupt reversal after a distribution shift, stop slippage, and realized
correlation with XNG or risk assets. Q09 alone may establish portfolio overlap.

## 7. Source And Non-Duplicate Boundary

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of
Financial Economics 104(2), 228-250, supplies peer-reviewed monthly WTI
own-price continuation lineage. The official NIST Dataplot reference for the
two-sample Kolmogorov-Smirnov test supplies the two-ECDF maximum-gap method.
The governed bounded packet is
`strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md`.
Neither source tests this exact fixed-six/six CFD trading conjunction.

The maximum signed vertical gap differs mechanically from `QM5_41176`'s sum
of all 36 Mann-Whitney cross-block wins. It also has no variable Pettitt split,
chronological Mann-Kendall pair sum, Spearman displacement, median-runs count,
or two-day long-only XNG pullback state. Locked separating fixtures live in
the pure reference suite. The canonical pre-allocation dedup receipt is
`artifacts/qm5_wti_mks_shift_tr_preallocation_dedup_20260827.json`.

## 8. Deterministic Failure Contract

Missing or duplicate month keys, mixed bar-label conventions, a stale newest
endpoint, nonpositive/nonfinite/equal closes, wrong endpoint or block counts,
an incomplete combined scan, gap counts outside `0..6`, a tied maximum, an
entry below boundary three, late entry, same-month retry, wrong risk mode,
missing hard stop, or missed month exit fails closed. Any change to the
formation, split, tie rule, gap definition, boundary, side, clock, risk, stop,
hold, or carrier creates a new execution contract and restarts qualification.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card and governed magic `411830000` |
