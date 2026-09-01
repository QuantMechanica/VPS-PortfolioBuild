# QM5_41265_xauxag-mbf-scale-rv - Strategy Spec

**EA ID:** QM5_41265

**Slug:** `xauxag-mbf-scale-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901_S01`

**Source:** `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs the latest exactly timestamp-matched
XAU/XAG close pair in each of thirteen consecutive completed broker months.
For chronological pairs it computes `q[i]=ln(XAU[i])-ln(XAG[i])` and twelve
adjacent changes `r[i]=q[i+1]-q[i]`. The oldest six and newest six changes are
fixed old/recent samples; current-month prices never enter the signal.

Each block is sorted only as a copy. Its even median is the average of sorted
indices 2 and 3. For each original member, the EA computes its absolute
deviation from that block median. With `zb_old` and `zb_recent` denoting the
two mean absolute deviations and `zb_all=(zb_old+zb_recent)/2`:

```text
ss_between = 6*(zb_old-zb_all)^2 + 6*(zb_recent-zb_all)^2
ss_within  = sum((z_old-zb_old)^2) + sum((z_recent-zb_recent)^2)
W          = 10*ss_between/ss_within
```

The denominator must exceed `1e-18` and `W` must be finite. The recent mean
absolute deviation must exceed the old value by
`1e-12*max(1,abs(zb_old),abs(zb_recent))`. If the recent median exceeds the
old median by the equivalent relative tolerance, the EA sells XAU and buys
XAG; if it is below, the EA buys XAU and sells XAG. Neutral location,
non-expanding scale, degenerate or invalid arithmetic consumes the month flat.
`W` is diagnostic only: there is no F critical value or p-value gate, and no
statistic changes risk.

An accepted package closes on the first processed tick of a later broker
month or after forty elapsed calendar days. Both legs have frozen
`3.5*ATR(20,D1)` broker hard stops, no targets, and no same-month retry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked | exact companion leg |
| `strategy_endpoint_count` | 13 | locked 13 | synchronized completed month endpoints |
| `strategy_return_count` | 12 | locked 12 | adjacent log-ratio changes |
| `strategy_block_size` | 6 | locked 6 | fixed old and recent sample size |
| `strategy_bf_multiplier` | 10.0 | locked 10.0 | `(N-k)/(k-1)` for N=12 and k=2 |
| `strategy_min_within_ss` | 1e-18 | locked | denominator floor |
| `strategy_relative_epsilon` | 1e-12 | locked | scale and location comparison tolerance |
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

- `XAUUSD.DWX` - exact D1 host, traded slot 0, governed magic `412650000`.
- `XAGUSD.DWX` - exact D1 companion, traded slot 1, governed magic
  `412650001`.
- `QM5_41265_XAU_XAG_MBF_SCALE_RV_D1` - logical tester symbol hosted on XAU.

The two physical-symbol setfiles are component validation presets only. They
are not standalone strategies and must never create component-leg Q02 rows.

**Explicitly not for:**

- Any other metal, commodity, FX pair, index, ETF, or futures-chain proxy.
- External curves, inventory, volume, open interest, forecasts, trained
  outputs, optimizer results, or portfolio state.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; completed month endpoints are reconstructed from D1 |
| Decision clock | first synchronized D1 boundary of a new broker month within 180 elapsed minutes |
| Formation | thirteen immediately prior consecutive synchronized completed broker months |
| Risk reference | completed D1 `ATR(20)` at shift 1 on each leg |
| Lifecycle | first processed tick of the next broker month; forty days is stale repair |

The EA is D1-native and does not depend on synthesized MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages / year | approximately 5-6 before market and execution gates; at least 5 completed packages in every full post-warm-up year |
| Decision frequency | exactly one consumed attempt per broker month; equal-block label-swap symmetry makes recent expansion about half of non-tied states |
| Typical hold time | until the next broker month; forty calendar days is the stale-repair maximum |
| Exposure | one opposite-side XAU/XAG package with equal target absolute notionals |
| Drawdown profile | high-risk candidate estimate, about 30% before governed validation; continuous-CFD gaps, financing, basis, synchronization, and legging remain material |
| Win rate target | unspecified; Q02 measures activity and economics without an efficacy prior |

Every monthly outcome is consumed before fallible history, signal, spread,
quote, ATR, sizing, margin, or order gates. A failed second leg or malformed,
wrong-side, stopless, duplicated, orphaned, wrong-magic, or imbalanced package
is flattened immediately. There is no target, trail, break-even, partial
close, Friday close, scale-in, grid, martingale, or pyramid.

## 6. Source Citation

**Source ID:** `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901`

**Source type:** governed AI synthesis with complete peer-reviewed
gold/silver evidence, official exchange carrier research, official NIST
formula evidence, and signed-tag-pinned SciPy documentation/source.

**Pointer:**
`strategy-seeds/sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901/source.md`.

**R1-R4 verdict (G0):** all PASS under the approved card at
`strategy-seeds/cards/approved/QM5_41265_xauxag-mbf-scale-rv_card.md`; the
runtime mirror is
`framework/EAs/QM5_41265_xauxag-mbf-scale-rv/docs/strategy_card.md`.

Schweikert (2018) and CME Group support only the state-dependent gold/silver
relationship and intermarket carrier. Brown and Forsythe (1974), DOI
`10.1080/01621459.1974.10482955`, names the robust scale method; its paper body
was not accessible. Complete NIST formula evidence and SciPy 1.18.0 source
pinned at signed tag commit `54ef5423f2e4376230ec3bfda6912a07a50958e3`
support the exact median-centered absolute-deviation arithmetic. The fixed
split, recent-expansion condition, contrarian side, CFD translation, risk,
and lifecycle are pre-result QM choices.

### Non-duplicate boundary

`QM5_41263` and `QM5_41260` pool/rank all twelve changes, qualify via full
empirical-distribution paths and permutation tails, and use rank sum for side.
`QM5_41247` searches a centered chronological CUSUM maximum. `QM5_20263` is a
daily ratio-level rolling median/MAD cross. This EA instead retains numeric
within-block distances, uses fixed six-by-six membership, centers each block
on its own even median, qualifies only a recent mean-absolute-deviation
expansion, and fades the two block medians without rank tails or split search.
Locked fixtures establish qualification and side disagreement against both
closest rank-path neighbors.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 aggregate package stop-risk budget |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

Each leg initially receives half the fixed stop-risk budget. Volumes may only
be reduced to align target absolute USD notionals; realized mismatch must not
exceed 20%. Each leg carries its own frozen `3.5*ATR(20,D1)` broker hard stop.
Both news axes, legacy news mode, Friday close, and stress rejection are off
in every canonical set.

Retire on zero packages, fewer than five in any full post-warm-up year,
nonpositive governed economics, deterministic-fixture failure, invalid
Brown-Forsythe arithmetic, or any downstream gate failure. Q09 alone may
establish realized portfolio decorrelation; this build claims no neutrality
or certification.

## Framework Alignment

- `no_trade`: exact host, period, identity, slots, magics, risk, news, Friday,
  stress, strategy locks, clock, history, Brown-Forsythe arithmetic, and
  package state.
- `trade_entry`: cached qualifying direction, quote/spread/ATR/stop gates,
  fixed-risk sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, next-month exit, and forty-day
  stale exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-01 | Initial build from approved card | OWNER commodity portfolio mission; governed magics `412650000` and `412650001` |
