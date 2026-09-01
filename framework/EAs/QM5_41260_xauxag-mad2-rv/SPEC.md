# QM5_41260_xauxag-mad2-rv - Strategy Spec

**EA ID:** QM5_41260

**Slug:** `xauxag-mad2-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MAD2-RV-20260901_S01`

**Source:** `AI-CODEX-XAUXAG-MAD2-RV-20260901`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs the latest exactly timestamp-matched
XAU/XAG close pair in each of thirteen consecutive completed broker months.
For chronological pairs it computes `q[i]=ln(XAU[i])-ln(XAG[i])` and twelve
adjacent changes `r[i]=q[i+1]-q[i]`. The oldest six and newest six changes are
fixed old/recent samples; current-month prices never enter the signal.

Every change must be pairwise distinct. The EA pools and sorts the twelve
changes while preserving sample labels. Across pooled ranks `j=1..11`, with
`O[j]` old and `R[j]` recent labels observed through rank `j`, it computes:

```text
A2 = (1/12) * sum(j=1..11)
     [ ((12*O[j]-6*j)^2/6 + (12*R[j]-6*j)^2/6) / (j*(12-j)) ]
```

All 924 twelve-rank assignments containing exactly six recent labels are
enumerated. A permutation enters the inclusive upper tail when
`A2_perm + 1e-12*max(1,abs(A2_observed)) >= A2_observed`. The signal requires
`tail_count<=452` and `2*tail_count<=924`. For a qualified tail, recent pooled-
rank sum above neutral 39 sells XAU and buys XAG; a sum below 39 buys XAU and
sells XAG. Exact ties, a neutral sum, invalid enumeration, or a larger tail
consume the month flat. Statistic magnitude never changes risk.

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
| `strategy_assignment_count` | 924 | locked 924 | complete six-of-twelve label space |
| `strategy_tail_numerator` | 1 | locked 1 | exact-tail fraction numerator |
| `strategy_tail_denominator` | 2 | locked 2 | exact-tail fraction denominator |
| `strategy_tail_count_max` | 452 | locked 452 | inclusive exact-tail count cap |
| `strategy_stat_epsilon` | 1e-12 | locked | relative inclusive statistic tolerance |
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

- `XAUUSD.DWX` - exact D1 host, traded slot 0, governed magic `412600000`.
- `XAGUSD.DWX` - exact D1 companion, traded slot 1, governed magic
  `412600001`.
- `QM5_41260_XAU_XAG_MAD2_RV_D1` - logical tester symbol hosted on XAU.

The two physical-symbol setfiles are component validation presets only. They
are not standalone strategies and must never create component-leg Q02 rows.

**Explicitly not for:**

- Any other metal, commodity, FX pair, index, ETF, or futures-chain proxy.
- External curves, inventory, volume, open interest, forecasts, or portfolio
  state; no external runtime feed is authorized.

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
| Decision frequency | one consumed attempt per broker month; the market-free strict-rank reference leaves 448 directional assignments among 924, about 5.818 states per twelve attempts |
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

**Source ID:** `AI-CODEX-XAUXAG-MAD2-RV-20260901`

**Source type:** governed AI synthesis with complete peer-reviewed statistical
and gold/silver evidence, official exchange carrier research, and pinned
primary statistical-software evidence.

**Pointer:**
`strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/source.md`.

**R1-R4 verdict (G0):** all PASS under the approved card at
`strategy-seeds/cards/approved/QM5_41260_xauxag-mad2-rv_card.md`; the runtime
mirror is `framework/EAs/QM5_41260_xauxag-mad2-rv/docs/strategy_card.md`.

Schweikert (2018) and CME Group support only the state-dependent gold/silver
relationship and intermarket carrier. Scholz and Stephens (1987), JASA
82(399), DOI `10.1080/01621459.1987.10478517`, plus SciPy 1.13.1 pinned at
commit `44e4ebaac992fde33f04638b99629d23973cb9b2`, support only the continuous
no-tie tail-weighted rank statistic and permutation route. The adjacent-change
state, fixed split, half-tail, contrarian side, CFD translation, risk, and
lifecycle are pre-result QM choices.

### Non-duplicate boundary

`QM5_41187` applies a maximum KS ECDF gap to ratio levels, `QM5_41177` applies
one Mann-Whitney rank sum to levels, `QM5_41247` searches a centered
chronological CUSUM maximum in changes, and `QM5_20263` uses a daily rolling
median/MAD cross. This EA instead uses fixed old/recent adjacent monthly
changes, every tail-weighted pooled-rank cut, and an exact 924-assignment
inclusive tail. Locked label paths establish both decision-disagreement
directions against the closest KS neighbor.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 aggregate package stop-risk budget |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

Each leg initially receives half the fixed stop-risk budget. Volumes may only
be reduced to align target absolute USD notionals; realized mismatch must not
exceed 20%. Each leg carries its own frozen `3.5*ATR(20,D1)` broker hard stop.
Both news axes, legacy news mode, Friday close, and stress rejection are off in
the canonical set.

Retire on zero packages, fewer than five in any full post-warm-up year,
nonpositive governed economics, deterministic-fixture failure, invalid
enumeration, or any downstream gate failure. Q09 alone may establish realized
portfolio decorrelation; this build claims no neutrality or certification.

## Framework Alignment

- `no_trade`: exact host, period, identity, slots, magics, risk, news, Friday,
  stress, strategy locks, clock, history, Anderson-Darling arithmetic, and
  package state.
- `trade_entry`: cached qualifying direction, quote/spread/ATR/stop gates,
  fixed-risk sizing, equal-notional reduction, and atomic two-leg submission.
- `trade_management`: malformed-package repair, next-month exit, and forty-day
  stale exit.
- `trade_close`: V5 close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-01 | Initial build from approved card | OWNER commodity portfolio mission; governed magics `412600000` and `412600001` |
