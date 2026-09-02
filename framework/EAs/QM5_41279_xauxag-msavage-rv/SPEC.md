# QM5_41279_xauxag-msavage-rv - Strategy Spec

**EA ID:** QM5_41279

**Slug:** `xauxag-msavage-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MSAVAGE-RV-20260902_S01`

**Source:** `AI-CODEX-XAUXAG-MSAVAGE-RV-20260902`

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
ascending. For each recent rank `r`, use the centered Savage score
`a(r)=sum[j=1..r](1/(12-j+1))-1`. The exact integer numerators on denominator
27720 are:

```text
-25410 -22890 -20118 -17038 -13573 -9613
 -4993    551   7481  16721  30581 58301
```

Let `S` be the sum of the six recent scores. Every one of the 924 six-of-
twelve rank assignments is evaluated; an assignment enters the inclusive
two-sided tail when `abs(S_perm)+1e-12>=abs(S_observed)`. The state qualifies
when `tail_count<=462`. Positive `S` sells XAU and buys XAG; negative `S` buys
XAU and sells XAG; zero is flat. Ties, score-invariant failure, invalid
enumeration, or a larger tail consume the month flat. Score magnitude never
changes risk.

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
| `strategy_tail_count_max` | 462 | locked 462 | inclusive two-sided exact-tail cap |
| `strategy_relative_epsilon` | 1e-12 | locked | raw-change tie and score tolerance |
| `strategy_score_denominator` | 27720 | locked | exact Savage-score lattice denominator |
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

- `XAUUSD.DWX` - exact D1 host, traded slot 0, governed magic `412790000`.
- `XAGUSD.DWX` - exact D1 companion, traded slot 1, governed magic
  `412790001`.
- `QM5_41279_XAU_XAG_SAVAGE_RV_D1` - logical tester symbol hosted on XAU.

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
| Packages / year | approximately 6 before market and execution gates; at least 5 in every full post-warm-up year |
| Decision frequency | one consumed attempt per broker month; 462 of 924 strict label assignments qualify, 231 in each direction |
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
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/source.md`.
Its approval is
`decisions/2026-09-02_xauxag_monthly_savage_score_reversion_source_approval.md`;
G0 is
`decisions/2026-09-02_qm5_41279_xauxag_monthly_savage_score_reversion_g0.md`.

Schweikert (2018) and CME Group support only the state-dependent carrier and
opposed-leg structure. NIST/SEMATECH and SAS/STAT provide the centered Savage
linear-rank score and exact two-sample test identity; Savage (1956) supplies
bibliographic lineage. The exact monthly sample, absolute tail boundary,
score-sign fade, CFD mapping, risk, atomicity, and lifecycle are pre-result QM
choices.

### Non-duplicate boundary

This EA uses a monotone harmonic score on raw pooled ranks and the exact
absolute tail of its signed sum. It does not use Cucconi squared rank tails,
Anderson-Darling or Kuiper ECDF paths, Brown-Forsythe numeric deviations, or
centered symmetric Klotz scores. Locked disagreement fixtures prove both
qualification directions against those adjacent implementations.

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
  stress, strategy locks, clock, history, Savage arithmetic, and package state.
- `trade_entry`: qualifying direction, quote/spread/ATR/stop gates, fixed-risk
  sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, next-month time exit, and
  forty-day stale time exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from approved card | OWNER commodity portfolio mission; governed magics `412790000` and `412790001` |
