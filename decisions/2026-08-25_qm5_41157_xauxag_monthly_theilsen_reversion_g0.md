# QM5_41157 XAU/XAG Monthly Theil-Sen Reversion — G0 Decision

Date: 2026-08-25

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41157_xauxag-mtheilsen-rv`. At the start of each broker month, the
candidate selects thirteen consecutive synchronized completed month-end
gold/silver close pairs, computes the exact median of all 78 forward
month-index-normalized gold-minus-silver log-ratio slopes, and fades its sign
with an equal-target-notional XAU/XAG package for one broker month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one logical `RISK_FIXED` Q02 enqueue if the
fresh host/tester CPU guards permit. Approval does not pre-judge economics,
neutrality, decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ROBUST_SLOPE_TRANSLATION_RISK`. The approved packet
  preserves Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, official CME gold/silver spread research,
  and an already governed exact thirteen-endpoint Theil-Sen arithmetic
  precedent. The paired robust-slope carrier and contrarian next-month
  direction are explicitly untested QM translations.
- R2: `PASS`. Symbols, clock, synchronization, thirteen consecutive month
  keys, latest pair selection, chronological ratios, pair bounds, `j-i`
  denominator, pair count, sort, even median, sides, one-attempt state,
  equal-notional aggregate risk, stops, atomicity, and exit are fully
  mechanical.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns actual history sufficiency, fills, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, and comparisons only. ATR is risk-only. No trained
  logic, banned signal indicator, optimizer output, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
SHA-256
`69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
Its durable approval is
`decisions/2026-08-25_xauxag_monthly_theilsen_reversion_source_approval.md`.

No source return, alpha, probability, trade density, risk, cost, hedge ratio,
neutrality, continuous-CFD equivalence, or portfolio correlation transfers.
The paired robust slope, contrarian direction, CFD mapping, fixed-dollar risk,
stops, spread caps, and lifecycle are falsifiable implementation hypotheses.

## Locked Statistical Contract

For thirteen synchronized consecutive completed broker-month-end pairs,
oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12

k = 0
for i = 0..11:
  for j = i+1..12:
    slope[k] = (s[j] - s[i]) / (j - i)
    k += 1

require k == 78
sorted = ascending(slope[0..77])
theilsen = (sorted[38] + sorted[39]) / 2

theilsen > 0 => SELL XAU / BUY XAG
theilsen < 0 => BUY XAU / SELL XAG
theilsen = 0 or invalid => FLAT
```

Require the latest exactly timestamp-matched close pair in each required
month, strict chronological order, positive finite closes, finite ratios and
slopes, positive month-index denominators, exact pair count 78, ascending
order, and finite central values. The raw endpoint displacement is diagnostic
only and never gates direction.

Consume the current `yyyymm` attempt before every fallible gate. Open one
opposite-side package under aggregate `RISK_FIXED=1000`, equal target absolute
USD notionals, maximum 20% realized mismatch, frozen per-leg
`3.5*ATR(20,D1)` stops, and no targets. Close at the first later broker month;
forty days is stale repair only. Both news axes and Friday close remain OFF.

## Non-Duplicate Decision

The corrected canonical checker scanned 4,656 registry rows, 1,307 cards, and
45 current Wiki nodes and returned no exact or fuzzy match. Evidence:
`artifacts/qm5_xauxag_mtheilsen_rv_preallocation_dedup_20260825.json`.

Manual review distinguishes the card from the outright WTI Theil-Sen trend
(`QM5_20271`), endpoint 12/18-month XAU/XAG return cards (`QM5_20050` and
`QM5_20202`), rolling OLS and annual CADF residual crossings (`QM5_20161` and
`QM5_21526`), and the latest one-month daily-return Hodges-Lehmann-style
basket (`QM5_41138`). None combines thirteen paired month-end ratio levels,
all 78 forward temporal slopes with `j-i` denominators, their exact even
median, and contrarian one-month package sides.

Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41157`;
- slug: `xauxag-mtheilsen-rv`;
- strategy ID: `SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01`;
- intended slot 0: `XAUUSD.DWX`, magic `411570000`;
- intended slot 1: `XAGUSD.DWX`, magic `411570001`;
- expected cadence: approximately ten to twelve packages per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on current-month leakage, missing/duplicate month, nonlatest pair,
  wrong ratio orientation, missing/duplicate slope, wrong denominator, pair
  count, median, side, attempt, basket, risk mode, hard stop, exit, or
  determinism; and
- no post-result change to sample, estimator, direction, carrier, risk, stop,
  hold, pair convention, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the logical basket preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
