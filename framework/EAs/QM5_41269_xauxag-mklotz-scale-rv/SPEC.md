# QM5_41269_xauxag-mklotz-scale-rv - Strategy Spec

**EA ID:** QM5_41269

**Slug:** `xauxag-mklotz-scale-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901_S01`

**Source:** `AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs the latest exactly timestamp-matched
XAU/XAG close pair in each of thirteen consecutive completed broker months.
For chronological pairs it computes `q[i]=ln(XAU[i])-ln(XAG[i])` and twelve
adjacent changes `r[i]=q[i+1]-q[i]`. The oldest six and newest six changes are
fixed old/recent samples; current-month prices never enter the signal.

The EA subtracts each block's own arithmetic mean, pools and sorts copies of
the twelve centered residuals, and fails the month flat if any residual pair
is tied within `1e-12*max(1,abs(a),abs(b))`. Ascending ranks 1 through 12
receive the frozen Klotz squared-normal scores:

```text
[2.0336952456315065, 1.0405555206952889,
 0.54216113018145117, 0.25240799405049096,
 0.086072547360949524, 0.0093235661866525334,
 0.0093235661866525334, 0.086072547360949524,
 0.25240799405049096, 0.54216113018145117,
 1.0405555206952889, 2.0336952456315065]
```

The six recent-label scores are summed as `K_recent`. The runtime verifies the
score-table total `7.928432008212679`, computes
`T1=(K_recent-3.9642160041063397)/1.2716448806860048`, and enumerates every
`C(12,6)=924` six-rank label assignment. Its inclusive tail counts assignments
with `K_perm + 1e-12*max(1,abs(K_recent)) >= K_recent`. A package is eligible
only when `K_recent` is on or above the frozen expectation and the tail is no
greater than 494. `T1` and the tail are deterministic integrity/activity
diagnostics, not p-values, and never scale risk.

For an eligible state, a recent raw block mean above the old mean by the
relative tolerance sells XAU and buys XAG; a lower recent mean buys XAU and
sells XAG. A neutral mean consumes flat. An accepted package closes on the
first processed tick of a later broker month or after forty elapsed calendar
days. Both legs have frozen `3.5*ATR(20,D1)` broker hard stops and no targets.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked | exact companion leg |
| `strategy_endpoint_count` | 13 | locked | synchronized completed month endpoints |
| `strategy_return_count` | 12 | locked | adjacent log-ratio changes |
| `strategy_block_size` | 6 | locked | fixed old/recent sample size |
| `strategy_relative_epsilon` | 1e-12 | locked | tie, score, and side tolerance |
| `strategy_klotz_expected` | 3.9642160041063397 | locked | equal-label score expectation |
| `strategy_klotz_denominator` | 1.2716448806860048 | locked | NIST T1 diagnostic denominator |
| `strategy_assignment_count` | 924 | locked | complete label enumeration |
| `strategy_tail_count_max` | 494 | locked | inclusive upper-half boundary |
| `strategy_history_bars_d1` | 900 | locked | bounded D1 reconstruction |
| `strategy_entry_window_minutes` | 180 | locked | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | locked | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | locked | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | locked | rounded package mismatch ceiling |
| `strategy_max_hold_days` | 40 | locked | stale-repair ceiling |
| `strategy_xau_max_spread_points` | 1500 | locked | XAU entry-spread ceiling |
| `strategy_xag_max_spread_points` | 500 | locked | XAG entry-spread ceiling |
| `strategy_deviation_points` | 20 | locked | order deviation ceiling |

The twelve rank scores are source constants, not inputs. There is one locked
Q02 baseline and no optimization surface.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` - exact D1 host, traded slot 0, governed magic `412690000`.
- `XAGUSD.DWX` - exact D1 companion, traded slot 1, governed magic
  `412690001`.
- `QM5_41269_XAU_XAG_KLOTZ_SCALE_RV_D1` - logical tester symbol hosted on
  XAU.

The two physical-symbol setfiles are component validation presets only. They
are not standalone strategies and must never create component-leg Q02 rows.

**Explicitly not for:** any other carrier, futures-chain proxy, inventory,
volume, open interest, forecast, trained output, optimizer result, or
portfolio-state input.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; completed month endpoints reconstructed from D1 |
| Decision clock | first synchronized D1 boundary of a broker month within 180 elapsed minutes |
| Formation | thirteen immediately prior consecutive synchronized completed broker months |
| Risk reference | completed D1 `ATR(20)` at shift 1 on each leg |
| Lifecycle | first processed tick of the next broker month; forty days is stale repair |

The EA is D1-native and does not depend on synthesized MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages / year | approximately 5-6 before market and execution gates; at least 5 in every full post-warm-up year |
| Decision frequency | exactly one consumed attempt per broker month; frozen label support admits 494/924 inclusive upper-half states before centered-rank feasibility |
| Typical hold time | until the next broker month; forty calendar days is stale repair |
| Exposure | one opposite-side XAU/XAG package with equal target absolute notionals |
| Drawdown profile | high-risk candidate estimate, about 30% before governed validation |
| Win rate target | unspecified; Q02 measures activity and economics without an efficacy prior |

Every monthly outcome is consumed before fallible history, signal, spread,
quote, ATR, sizing, margin, or order gates. A failed second leg or malformed,
wrong-side, stopless, duplicated, orphaned, wrong-magic, or imbalanced package
is flattened immediately. There is no target, trail, break-even, partial
close, Friday close, scale-in, grid, martingale, or pyramid.

## 6. Source Citation

**Source ID:** `AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901`

**Pointer:**
`strategy-seeds/sources/AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901/source.md`.

**R1-R4 verdict (G0):** all PASS under
`strategy-seeds/cards/approved/QM5_41269_xauxag-mklotz-scale-rv_card.md`; its
runtime mirror is `docs/strategy_card.md`.

Schweikert (2018), DOI `10.1016/j.jbankfin.2017.11.010`, and CME Group support
only the state-dependent gold/silver relationship and intermarket carrier.
Klotz (1962), DOI `10.1214/aoms/1177704576`, supplies authoritative method
identity; the paper body was not accessible. Complete official NIST Klotz
Score/Test pages support separate-mean centering, the squared-normal score
formula, and standardized arithmetic. The sample, strict ties, frozen
constants, inclusive activity boundary, raw-mean fade, CFD translation, risk,
and lifecycle are pre-result QM choices.

### Non-duplicate boundary

`QM5_41265` retains numeric within-block distances after separate median
centering and takes side from a median shift. This EA separately mean-centers,
discards residual spacing after strict ranks, sums nonlinear squared-normal
scores, audits all 924 label assignments, and takes side from the raw mean
shift. `QM5_41263` uses uncentered raw-change ECDF extrema and rank-sum side;
this EA ranks centered residuals and decouples state from side. Fixed fixtures
lock a Klotz-only decision, a Brown-Forsythe-only decision, and opposite sides
when both qualify.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 aggregate package stop-risk budget |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

Each leg initially receives half the fixed stop-risk budget. Volumes may only
be reduced to align target absolute USD notionals; realized mismatch must not
exceed 20%. Each leg carries a frozen `3.5*ATR(20,D1)` broker hard stop. Both
news axes, legacy news mode, Friday close, and stress rejection are off in the
canonical logical set.

Retire on zero packages, fewer than five in any full post-warm-up year,
deterministic-fixture failure, invalid score/rank/enumeration arithmetic,
nonpositive governed economics, or any downstream gate failure. Q09 alone
may establish realized portfolio decorrelation; this build claims no
neutrality or certification.

## Framework Alignment

- `no_trade`: exact host, period, identity, magics, fixed-risk/news/Friday
  contract, monthly clock, history, Klotz arithmetic, and package state.
- `trade_entry`: cached qualifying direction, quotes/spreads/ATR/stops,
  fixed-risk sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, next-month exit, and
  forty-day stale exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-01 | Initial build from approved card | OWNER commodity portfolio mission; governed magics `412690000` and `412690001` |
