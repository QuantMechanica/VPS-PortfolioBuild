# QM5_41184_wti-mww-runs-shift-tr - Strategy Spec

**EA ID:** QM5_41184

**Slug:** `wti-mww-runs-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-M2RUNS-20260827_S01`

**Source:** `AI-CODEX-WTI-M2RUNS-20260827`

**Last revised:** 2026-08-27

## 1. Strategy Logic

At the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close from each of the immediately prior ten
consecutive completed broker months. Split them chronologically into fixed
older and newer blocks of five. Pool all values in strict ascending price
order, count runs of their fixed block labels, and continue the newer block's
exact median direction only when the label path has at most six runs.

This is a direct-WTI monthly structural distribution-shift hypothesis. The
run boundary is a locked trading filter, not a critical value or significance
claim. A qualifying direction owns one fixed-risk WTI position until the next
broker month, protected by a frozen ATR hard stop.

## 2. Parameters

### Locked Formula

```text
O = C[0..4]
N = C[5..9]
require C is positive, finite, and pairwise distinct

P = strict ascending sort(O union N), retaining fixed O/N labels
R = 1 + count(adjacent label changes in P)

old_median = middle(sorted O)
new_median = middle(sorted N)

BUY  iff R <= 6 and new_median > old_median
SELL iff R <= 6 and new_median < old_median
FLAT otherwise
```

Pairwise-distinct values make block-median equality impossible. Invalid
membership, ordering, or run count consumes the month flat. The split may not
move and chronology within either fixed block has no effect on the statistic.

### Locked Inputs

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 10 | consecutive completed month-end closes |
| `strategy_block_size` | 5 | fixed older and newer sample size |
| `strategy_max_label_runs` | 6 | inclusive pooled-membership run boundary |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_window_minutes` | 180 | first-bar execution grace |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | market-request deviation ceiling |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `411840000`.

No proxy, alternate symbol, basket leg, or symbol substitution is authorized.

## 4. Timeframe

- Formation and decision cadence: monthly; the current month contributes no
  signal close.
- Exactly one consumed attempt per normalized broker month and at most one
  owned position.
- Exact enumeration of all 252 strict five/five label assignments gives run
  counts `2,8,32,48,72,48,32,8,2` for runs 2 through 10. Boundary `R<=6`
  admits 81 BUY and 81 SELL rank states, or about 7.714 random-rank decisions
  per twelve months. This is a density prior, not significance or performance.
- Q02 retires below five completed positions in any full post-warm-up year.

## 5. Expected Behaviour

### Entry And Lifecycle Contract

1. Require exact symbol, D1 period, EA ID, slot, fixed-risk, news, Friday, and
   singleton strategy inputs.
2. Process lifecycle repair and mandatory prior-month/stale exits before
   entry-only gates.
3. Persist `QM5_41184_MONTH_ATTEMPT_<magic>=yyyymm` before history, signal,
   spread, quote, ATR, sizing, margin, news, or order gates.
4. A late restart, prior attempt, existing owned exposure, invalid endpoint,
   tie, excessive runs, or invalid median consumes flat. An order reject never
   retries the month.
5. A valid signal must pass spread, quote, completed-bar ATR, stop, volume,
   and margin checks before one market request.
6. Size through the V5 fixed-risk helper against a frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target.
7. Close at the first later normalized broker month or after forty elapsed
   calendar days. Repair malformed, duplicate, wrong-side, or stopless owned
   exposure before considering entry.

There is no target, signal flip, recount exit, trail, break-even move, partial
exit, scale-in, grid, martingale, Friday close, or news exit.

## 6. Source Citation

The single source is the governed Codex synthesis
`strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/source.md`, corrected
SHA-256
`AB4B8ADE3D3E4B4CA1B7AE6D9ADE98DD69AD30BC5D5CEDEC0EC6F9D073795FB6`.
Its public method DOI is metadata-only after a policy defer; the complete-read
MOP packet supports monthly WTI continuation and WTI membership only. No
source tests this exact fixed-five/five CFD trade.

This pooled membership-run count differs mechanically from `QM5_41182`'s
chronological above/below-median transitions, `QM5_41183`'s maximum signed
ECDF gap, `QM5_41176`'s all-pairs win sum, and `QM5_41172`'s variable change
point. The pure reference suite locks exhaustive counts, reflection symmetry,
chronology invariance, and separating fixtures. Canonical pre-allocation
receipt:
`artifacts/qm5_wti_mww_runs_shift_tr_preallocation_dedup_20260827.json`.
The one-time arithmetic correction is recorded in
`decisions/2026-08-27_qm5_41184_prebuild_density_correction.md`.

## 7. Risk Model

The sole preset is a backtest set using `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes and legacy news are
OFF; Friday close is OFF. No live, demo, shadow, stress, or optimization
preset is authorized. This build does not authorize AutoTrading, `T_Live`,
deployment, portfolio admission, portfolio-gate changes, or correlation
claims.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
monthly formation staleness, small-block instability, weak selectivity,
abrupt reversal after an apparent distribution shift, stop slippage, and
realized overlap with XNG or risk assets. Q09 alone may establish overlap.

## 8. Deterministic Failure Contract

Missing or duplicate month keys, mixed bar-label conventions, stale newest
endpoint, nonpositive/nonfinite/equal closes, wrong endpoint or block counts,
unstable pooled order, missing/duplicate labels, run counts outside `2..10`,
entry at runs above six, wrong median side, late entry, same-month retry,
wrong risk mode, missing hard stop, or missed month exit fails closed. Any
change to the formation, split, tie rule, run definition, boundary, side,
clock, risk, stop, hold, or carrier creates a new execution contract.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card and governed magic `411840000` |
| v1 | 2026-08-27 | pre-build arithmetic correction | exact run table corrected; one Q02 boundary locked at `R<=6` before compile or market results |
