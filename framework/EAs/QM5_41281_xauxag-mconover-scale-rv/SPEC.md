# QM5_41281_xauxag-mconover-scale-rv - Strategy Spec

**EA ID:** QM5_41281

**Slug:** `xauxag-mconover-scale-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902_S01`

**Source:** `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902`

**Author of this spec:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs the latest exactly timestamp-matched
XAU/XAG close pair in each of thirteen consecutive completed broker months.
For chronological pairs it computes `q[i]=ln(XAU[i])-ln(XAG[i])` and twelve
adjacent changes `r[i]=q[i+1]-q[i]`. The oldest six and newest six changes
are fixed old/recent samples; current-month prices never enter the signal.

The EA subtracts each block's arithmetic mean, takes absolute deviations, and
fails the month flat if any pooled deviation pair is tied within
`1e-12*max(1,abs(a),abs(b))`. Deviations receive strict ascending ranks
1 through 12. The recent-label state score is:

```text
C_recent = sum(rank^2 for the six recent deviations)
```

The runtime verifies the invariant score total `sum(1^2..12^2)=650`, then
enumerates all `C(12,6)=924` six-rank label assignments. Its inclusive
upper tail counts assignments whose squared-rank sum is at least
`C_recent`. A package qualifies only when `C_recent >= 326` and the tail
is at most 461. The exhaustive count is a deterministic integrity/activity
gate, not a p-value or a published critical value, and never scales risk.

For a qualified state, a recent raw block mean more than `1e-12` above the
old mean sells XAU and buys XAG; a lower recent mean buys XAU and sells XAG.
A neutral mean consumes flat. An accepted package closes on the first
processed tick of a later broker month or after forty elapsed calendar days.
Both legs have frozen `3.5*ATR(20,D1)` broker hard stops and no targets.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | exact companion leg |
| `strategy_endpoint_count` | 13 | synchronized completed-month endpoints |
| `strategy_return_count` | 12 | adjacent log-ratio changes |
| `strategy_block_size` | 6 | fixed old/recent sample size |
| `strategy_relative_epsilon` | 1e-12 | deviation-tie tolerance |
| `strategy_score_total` | 650 | `sum(1^2..12^2)` invariant |
| `strategy_score_expected` | 325 | equal-label score expectation |
| `strategy_score_min` | 326 | recent-state activity floor |
| `strategy_assignment_count` | 924 | complete label enumeration |
| `strategy_tail_count_max` | 461 | inclusive upper-half boundary |
| `strategy_direction_epsilon` | 1e-12 | absolute raw-mean side tolerance |
| `strategy_history_bars_d1` | 900 | bounded D1 reconstruction |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | rounded mismatch ceiling |
| `strategy_max_hold_days` | 40 | stale-repair ceiling |
| `strategy_xau_max_spread_points` | 1500 | XAU entry-spread ceiling |
| `strategy_xag_max_spread_points` | 500 | XAG entry-spread ceiling |
| `strategy_deviation_points` | 20 | order deviation ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

- `XAUUSD.DWX`: exact D1 host and traded slot 0, governed magic
  `412810000`.
- `XAGUSD.DWX`: exact D1 dependency and traded slot 1, governed magic
  `412810001`.
- `QM5_41281_XAU_XAG_CONOVER_SCALE_RV_D1`: logical Q02 tester symbol
  hosted on XAU.

The two physical-symbol presets are component validation presets only. They
are not standalone strategies and must not create component-leg Q02 rows.

No other carrier, futures-chain proxy, inventory, volume, open interest,
forecast, trained output, optimizer result, or portfolio-state input is
authorized.

## 4. Timeframe And Lifecycle

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Formation | thirteen immediately prior consecutive synchronized completed broker months |
| Decision clock | first synchronized D1 boundary of a broker month within 180 elapsed minutes |
| Risk reference | completed D1 `ATR(20)` at shift 1 on each leg |
| Normal exit | first processed tick in a later broker month |
| Stale repair | forty elapsed calendar days |

The EA is D1-native and does not depend on synthesized MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages/year | about 5-6 before data and execution gates; at least 5 in every full post-warm-up year |
| Attempts | exactly one consumed attempt per broker month |
| Frozen support | 461 of 924 assignments qualify the upper-half activity gate |
| Typical hold | until the next broker month |
| Exposure | one opposite-side XAU/XAG package with equal target absolute notionals |
| Drawdown prior | high-risk candidate estimate, 30%; pipeline evidence governs |

Every monthly outcome is consumed before fallible history, signal, news,
spread, quote, ATR, sizing, margin, or order gates. A failed second leg or
malformed, wrong-side, stopless, duplicated, orphaned, wrong-magic, or
imbalanced package is flattened immediately. There is no target, trail,
break-even, partial close, Friday close, re-hedge, scale-in, grid, martingale,
or pyramid.

## 6. Source Citation

The governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/source.md`;
the approved card is
`strategy-seeds/cards/approved/QM5_41281_xauxag-mconover-scale-rv_card.md`.
The source approval precedes card extraction at commit `6a88b02d89`; G0 is
APPROVED at commit `b964fc88a0`.

Schweikert (2018), DOI `10.1016/j.jbankfin.2017.11.010`, and CME Group
support only the state-dependent gold/silver carrier. Official NIST material
supports group-mean absolute deviations, pooled ranks, squared-rank scoring,
and scale interpretation. The sample, tie rule, exhaustive tail, activity
boundary, raw-mean fade, CFD translation, risk, and lifecycle are pre-result
QM choices.

This engine ranks within-block mean-centered absolute deviations and sums
ordinal rank squares. It is distinct from Klotz signed-residual
squared-normal scores, Brown-Forsythe numeric median deviations without a
label tail, Cucconi raw-rank quadratics, Savage harmonic raw-rank scores, and
Kuiper ECDF paths. Frozen fixtures lock a Conover-only qualification, two
neighbor-only rejections, and a side disagreement.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Q02-Q10 | RISK_FIXED | $1,000 aggregate package stop-risk budget |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

Each leg initially receives half the fixed stop-risk budget. Volumes may only
be reduced to align target absolute USD notionals; realized mismatch must not
exceed 20%. Each leg carries a frozen `3.5*ATR(20,D1)` broker hard stop.
Both news axes, legacy news mode, Friday close, and stress rejection are off
in the canonical logical preset.

Retire on zero packages, fewer than five in any full post-warm-up year,
deterministic-fixture failure, invalid rank/score/enumeration arithmetic,
nonpositive governed economics, or any downstream gate failure. Q09 alone
may establish realized portfolio decorrelation; this build claims no
neutrality or certification.

## Framework Alignment

- `no_trade`: exact host, period, identity, magics, fixed-risk/news/Friday
  contract, monthly clock, history, Conover arithmetic, and package state.
- `trade_entry`: cached qualifying direction, quotes/spreads/ATR/stops,
  fixed-risk sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, later-month exit, and
  forty-day stale exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from approved card | governed magics `412810000` and `412810001`; Q01 `COMPILE_OK`, strict build-check PASS |
