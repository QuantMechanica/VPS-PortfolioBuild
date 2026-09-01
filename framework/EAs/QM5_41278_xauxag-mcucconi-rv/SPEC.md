# QM5_41278_xauxag-mcucconi-rv - Strategy Spec

**EA ID:** QM5_41278

**Slug:** `xauxag-mcucconi-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902_S01`

**Source:** `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902`

**Author of this spec:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs the latest exactly timestamp-matched
XAU/XAG close pair in each of thirteen consecutive completed broker months.
For chronological pairs it computes `q[i]=ln(XAU[i])-ln(XAG[i])` and twelve
adjacent changes `r[i]=q[i+1]-q[i]`. The oldest six and newest six changes are
fixed old/recent samples; current-month prices never enter the signal.

All changes must be pairwise distinct under
`1e-12*max(1,abs(left),abs(right))`. The twelve changes are pooled and ranked
ascending. Let `R` be the six ranks carried by recent observations:

```text
E   = 325
SD  = sqrt(6955) = 83.3966426182733
rho = -479/535 = -0.8953271028037383

U = (sum(R^2)-E)/SD
V = (sum((13-R)^2)-E)/SD
C = (U^2+V^2-2*rho*U*V)/(2*(1-rho^2))
```

Every one of the 924 six-of-twelve rank assignments is evaluated. An
assignment enters the inclusive upper tail when
`C_perm + 1e-12*max(1,abs(C_observed)) >= C_observed`. The state qualifies
when `tail_count<=480`. Recent rank sum above neutral 39 sells XAU and buys
XAG; below 39 buys XAU and sells XAG; exactly 39 is flat. Relative ties,
invalid enumeration, or a larger tail consume the month flat. Statistic and
rank-sum magnitudes never change risk.

An accepted package closes on the first processed synchronized tick of a
later broker month or after forty elapsed calendar days. Both exits use the
V5 `QM_EXIT_TIME_STOP` reason. Both legs have frozen `3.5*ATR(20,D1)` broker
hard stops, no targets, and no same-month retry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked | exact companion leg |
| `strategy_endpoint_count` | 13 | locked 13 | synchronized completed month endpoints |
| `strategy_return_count` | 12 | locked 12 | adjacent log-ratio changes |
| `strategy_block_size` | 6 | locked 6 | fixed old and recent sample size |
| `strategy_assignment_count` | 924 | locked 924 | complete six-of-twelve label space |
| `strategy_tail_count_max` | 480 | locked 480 | inclusive exact-tail count cap |
| `strategy_relative_epsilon` | 1e-12 | locked | raw-change tie and statistic tolerance |
| `strategy_rank_square_expectation` | 325 | locked | source-defined squared-rank expectation |
| `strategy_rank_square_sd` | 83.3966426182733 | locked | source-defined squared-rank SD |
| `strategy_rank_component_rho` | -0.8953271028037383 | locked | source-defined component correlation |
| `strategy_neutral_rank_sum` | 39 | locked 39 | recent pooled-rank neutral point |
| `strategy_history_bars_d1` | 900 | locked 900 | bounded D1 endpoint reconstruction |
| `strategy_entry_window_minutes` | 180 | locked 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | locked 10 | newest completed endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | locked 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked 3.5 | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | locked 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | locked 0.20 | rounded package mismatch ceiling |
| `strategy_max_hold_days` | 40 | locked 40 | elapsed-calendar survivor repair ceiling |
| `strategy_xau_max_spread_points` | 1500 | locked 1500 | XAU entry-spread ceiling |
| `strategy_xag_max_spread_points` | 500 | locked 500 | XAG entry-spread ceiling |
| `strategy_deviation_points` | 20 | locked 20 | order deviation ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` - exact D1 host, traded slot 0, governed magic `412780000`.
- `XAGUSD.DWX` - exact D1 companion, traded slot 1, governed magic
  `412780001`.
- `QM5_41278_XAU_XAG_CUCCONI_RV_D1` - logical tester symbol hosted on XAU.

The two physical-symbol setfiles are component validation presets only. They
are not standalone strategies and must never create component-leg Q02 rows.

**Explicitly not for:** any other carrier, external curve, inventory, volume,
open interest, forecast, portfolio state, or runtime feed.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; completed month endpoints are reconstructed from D1 |
| Decision clock | first synchronized D1 boundary of a new broker month within 180 elapsed minutes |
| Formation | thirteen immediately prior consecutive synchronized completed broker months |
| Risk reference | completed D1 `ATR(20)` at shift 1 on each leg |
| Lifecycle | first synchronized tick of a later broker month; forty days is stale repair |

The EA is D1-native and does not depend on synthesized MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages / year | approximately 5-6 before market and execution gates; at least 5 in every full post-warm-up year |
| Decision frequency | one consumed attempt per broker month; 462 of 924 strict labels are directionally eligible, exactly six per twelve combinatorial attempts |
| Typical hold time | until the next broker month; forty calendar days is the stale-repair maximum |
| Exposure | one opposite-side XAU/XAG package with equal target absolute notionals |
| Drawdown profile | high-risk candidate estimate, about 30% before governed validation; CFD gaps, financing, basis, synchronization, and legging remain material |
| Win rate target | unspecified; Q02 measures activity and economics without an efficacy prior |

Every monthly outcome is consumed before fallible history, signal, spread,
quote, ATR, sizing, margin, or order gates. A failed second leg or malformed,
wrong-side, stopless, duplicated, orphaned, wrong-magic, or imbalanced package
is flattened immediately. There is no target, trail, break-even, partial
close, Friday close, scale-in, grid, martingale, or pyramid.

## 6. Source Citation

The source of record is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902/source.md`.
Its approval is
`decisions/2026-09-02_xauxag_monthly_cucconi_reversion_source_approval.md`;
G0 is
`decisions/2026-09-02_qm5_41278_xauxag_monthly_cucconi_reversion_g0.md`.

Schweikert (2018) and CME Group support only the state-dependent carrier and
opposed-leg structure. Marozzi (2012), *Revista Colombiana de Estadistica*
35(3), 371-384, supplies the complete classical Cucconi arithmetic and exact
fixed-label permutation construction. The exact monthly sample, 480-tail
activity boundary, rank-sum contrarian side, continuous-CFD mapping, risk,
atomicity, and lifecycle are pre-result QM choices.

### Non-duplicate boundary

`QM5_41263` uses Kuiper ECDF extrema, `QM5_41260` integrates a tail-weighted
Anderson-Darling ECDF path, `QM5_41265` retains numeric median-centered
deviations, and `QM5_41269` applies centered squared-normal Klotz scores. This
EA uses neither ECDF paths/extrema, numeric spacing, block centering, nor
normal scores. It combines squared integer ranks and squared contrary-ranks
through their source-defined negative correlation. Four locked label fixtures
establish both qualification-disagreement directions against those neighbors.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 aggregate package stop-risk budget |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

Each leg initially receives half the fixed stop-risk budget. Volumes may only
be reduced to align target absolute USD notionals; realized mismatch must not
exceed 20%. Each leg carries its own frozen `3.5*ATR(20,D1)` broker hard stop.
Both news axes, legacy news mode, Friday close, and stress rejection are off.

Retire on zero packages, fewer than five in any full post-warm-up year,
nonpositive governed economics, deterministic-fixture failure, invalid
enumeration, or any downstream gate failure. Q09 alone may establish realized
portfolio decorrelation; this build claims no neutrality or certification.

## Framework Alignment

- `no_trade`: exact host, period, identity, slots, magics, risk, news, Friday,
  stress, strategy locks, clock, history, Cucconi arithmetic, and package state.
- `trade_entry`: qualifying direction, quote/spread/ATR/stop gates, fixed-risk
  sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, next-month time exit, and
  forty-day stale time exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from approved card | OWNER commodity portfolio mission; governed magics `412780000` and `412780001` |
