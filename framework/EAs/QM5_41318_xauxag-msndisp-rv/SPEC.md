# QM5_41318_xauxag-msndisp-rv - Strategy Spec

**EA ID:** QM5_41318

**Slug:** `xauxag-msndisp-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MSNDISP-RV-20260902_S01`

**Source:** `AI-CODEX-XAUXAG-MSNDISP-RV-20260902`

**Author of this spec:** Codex

**Last revised:** 2026-09-03

## 1. Strategy Logic

On the first synchronized executable D1 boundary of a genuine broker month,
persist that month's attempt before every fallible gate. From a bounded 120-bar
buffer, require that every XAU/XAG D1 observation in the immediately completed
broker month has an exact timestamp mate. Require 17 through 23 paired sessions
and retain exactly the final seventeen in chronological order. Current-month
prices never enter the signal.

For each retained pair compute `q[i]=ln(XAU_close[i])-ln(XAG_close[i])` and
the sixteen adjacent changes `r[i]=q[i+1]-q[i]`. The sum of the changes must
equal `q[16]-q[0]` within `1e-10`.

For every change, sort all fifteen `abs(r[i]-r[j])`, `j!=i`, and take
zero-based index seven. Sort those sixteen inner values and again take
zero-based index seven as `sn_core`. Runtime requires all 240 directed
distances and `sn_core>1e-12`. This is the raw Sn core: neither the `1.1926`
consistency multiplier nor any finite-sample multiplier is applied.

- `net >= 3*sn_core`: sell XAU and buy XAG.
- `net <= -3*sn_core`: buy XAU and sell XAG.
- Otherwise consume the month flat.

Both comparisons are inclusive and signal magnitude never changes risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_sessions_min` | 17 | minimum synchronized prior-month sessions |
| `strategy_month_sessions_max` | 23 | maximum synchronized prior-month sessions |
| `strategy_close_count` | 17 | final paired closes retained |
| `strategy_return_count` | 16 | adjacent relative changes |
| `strategy_inner_distance_count` | 15 | leave-one-out distances per change |
| `strategy_inner_median_one_based` | 8 | lower-median order within fifteen values |
| `strategy_outer_count` | 16 | inner values |
| `strategy_outer_lomed_one_based` | 8 | lower-median order within sixteen values |
| `strategy_sn_core_floor` | 1e-12 | strict core floor |
| `strategy_net_core_multiplier` | 3.0 | inclusive displacement boundary |
| `strategy_endpoint_tolerance` | 1e-10 | telescoping identity tolerance |
| `strategy_history_bars_d1` | 120 | bounded synchronization buffer |
| `strategy_entry_window_minutes` | 180 | month-boundary grace |
| `strategy_atr_period_d1` | 20 | closed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | rounded mismatch ceiling |
| `strategy_max_hold_days` | 40 | stale repair ceiling |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | governed order deviation ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol And Execution Contract

- `XAUUSD.DWX`, D1 is host/traded slot 0, magic `413180000`.
- `XAGUSD.DWX`, D1 is companion/traded slot 1, magic `413180001`.
- `QM5_41318_XAU_XAG_SN_RV_D1` is the logical Q02 symbol hosted on XAU.
- Tester currency is USD, deposit is 100,000, and Q02 spans
  `2018.07.02` through `2024.12.31`.
- The physical-symbol sets are validation artifacts only. They must not become
  standalone Q02 rows.

Both current D1 bars must share a timestamp and broker day. A missing or
shifted timestamp anywhere in the prior month invalidates the formation
sample; the EA never silently intersects away a missing session. The attempt
is stored before history, signal, news, spread, quote, ATR, sizing, margin, or
submission checks, so nothing can retry intramonth.

## 4. Risk And Basket Integrity

Backtests lock `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This is one aggregate package stop-risk budget. Each leg
starts at half of its full governed risk-sized volume; equal-notional
balancing may only reduce the larger leg. Both legs carry frozen
`3.5*ATR(20,D1)` broker hard stops, no target, and post-rounding notional
mismatch may not exceed 20 percent.

The entry gate rejects any owned package, owned entry deal in the current
month, or foreign position on either traded symbol. XAU submits first and XAG
second through `QM_BasketOpenPosition`. If both opposed legs with the governed
magics, directions, stops, volumes, and notionals do not exist immediately,
all owned exposure is flattened. Zero or two owned positions are the only
valid steady states.

Both news axes and legacy news are off. Friday close is off because the
month-spanning hold is load-bearing. Stress rejection is zero. Framework kill
switch, broker stops, weekend handling, and disconnect handling remain active.

## 5. Management And Failure Rules

On every management pass, require exactly two owned opposed positions with
the expected symbols and magics, finite positive volumes and opens, correctly
sided nonzero stops, zero targets, and acceptable notional mismatch. Close the
package on the first synchronized processed tick in a broker month after the
entry month, after forty elapsed calendar days, or immediately on any malformed
or partial package, missing reconstructible state, or direction mismatch.

There is no intramonth signal exit, convergence target, flip, trail,
break-even move, partial close, resize, scale-in, grid, martingale, pyramid, or
same-month retry.

Q02 must retire zero packages or any full scored post-warm-up year with fewer
than five completed packages. It must also preserve any nonpositive economics,
nondeterminism, synchronization failure, or downstream gate failure without a
result-based repair.

## 6. Source And Non-Duplicate Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902/source.md`.
Source approval and G0 precede this build. Schweikert supports only the
state-dependent gold/silver relationship and adverse evidence against a
stable spread; CME supports only the relative-value carrier; Rousseeuw-Croux
and pinned `robustbase` code support only Sn arithmetic. The exact completed-
month, three-core, contrarian CFD rule is disclosed QuantMechanica synthesis.

The canonical dedup receipt is
`artifacts/qm5_xauxag_msndisp_rv_preallocation_dedup_20260902.json`. The edge
differs from direct-WTI Sn continuation (`QM5_41277`), rolling ratio-level
median/MAD (`QM5_20263`), monthly Siegel-Tukey blocks (`QM5_41286`), and
cross-horizon rank disagreement (`QM5_20194`). Frozen fixtures establish
two-way disagreement with Qn, L1, and RMS neighbors.

The opposed equal-notional form is market-neutral-style. It is not proof of
dollar, factor, beta, volatility, or portfolio neutrality; Q09 alone owns
realized correlation.

## 7. Framework Alignment And Safety Boundary

- `no_trade`: exact identity/host/period/input locks, persistent monthly
  consumption, synchronized history, Sn state, and package-state checks.
- `trade_entry`: contrarian direction, foreign-exposure rejection, quotes,
  spreads, ATR stops, aggregate fixed-risk sizing, equal-notional reduction,
  and atomic two-leg submission/repair.
- `trade_management`: malformed-package repair, direction reconstruction,
  next-month exit, and forty-day stale exit.
- `trade_close`: governed V5 basket close helper, hard stops, and kill switch.

This build authorizes no optimization, manual tester launch, live/demo/shadow
or stress set, component Q02 row, portfolio-gate edit, correlation waiver,
portfolio admission, deployment, live manifest, `T_Live`, AutoTrading, or
live use.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | Initial build from approved card | Governed magics `413180000` and `413180001` |
