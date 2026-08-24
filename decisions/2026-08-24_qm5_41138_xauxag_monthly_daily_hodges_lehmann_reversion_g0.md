# QM5_41138 XAU/XAG Completed-Month Daily Hodges-Lehmann Reversion - G0 Decision

Date: 2026-08-24

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41138_xauxag-mdaily-hl-rv`. At the start of each broker month, the
candidate forms every synchronized gold-minus-silver daily relative log
return ending in the immediately completed month, computes the exact median
of all inclusive pairwise averages, and fades its sign with an equal-target-
notional XAU/XAG package for the next month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, and one logical `RISK_FIXED` Q02 enqueue if the governed compile
queue and fresh host/tester CPU guards permit. Approval does not pre-judge
economics, neutrality, decorrelation, certification, or portfolio admission.

## Gate Findings

- R1:
  `PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK`. The approved packet
  preserves Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, official CME gold/silver spread research,
  and an already governed exact Hodges-Lehmann arithmetic precedent. The
  within-month estimator and next-month contrarian direction are explicitly
  untested QM translations.
- R2: `PASS`. Symbols, clock, synchronization, sample membership, older
  boundary, chronological returns, endpoint identity, inclusive pair bounds,
  pair count, sort, odd/even median, sides, one-attempt state, equal-notional
  aggregate risk, stops, atomicity, and exit are fully mechanical.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns actual data sufficiency and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, and comparisons only. ATR is risk-only. No trained
  logic, banned signal indicator, optimizer output, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
SHA-256
`D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
Its durable approval is
`decisions/2026-08-24_xauxag_monthly_daily_hodges_lehmann_reversion_source_approval.md`.

New public routes were policy-deferred and not used. No source return, alpha,
probability, trade density, risk, cost, hedge ratio, neutrality, continuous-
CFD equivalence, or portfolio correlation transfers. The robust daily
pseudomedian, contrarian direction, CFD mapping, fixed-dollar risk, stops,
spread caps, and lifecycle are falsifiable implementation hypotheses.

## Locked Statistical Contract

For an older synchronized boundary ratio `s[-1]` and `n` immediately
completed-month ratios `s[0]..s[n-1]`, oldest to newest, where `17 <= n <= 23`:

```text
r[j] = s[j] - s[j-1], j=0..n-1

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n * (n + 1) / 2
require k == m
sorted = ascending(w[0..m-1])

hl = sorted[m/2]                         when m is odd
hl = (sorted[m/2-1] + sorted[m/2]) / 2  when m is even

hl > 0 => SELL XAU / BUY XAG
hl < 0 => BUY XAU / SELL XAG
hl = 0 or invalid => FLAT
```

Require every completed-month timestamp exactly once, one adjacent older
pair, positive finite closes, finite ratios/returns/averages, exact pair count
153-276, explicit self-pair identity, ascending order, and finite central
value. Verify `sum(r)` against `s[n-1]-s[-1]` within `1e-10`. The raw endpoint
is diagnostic only and never gates direction.

Consume the current `yyyymm` attempt before every fallible gate. Open one
opposite-side package under aggregate `RISK_FIXED=1000`, equal target absolute
USD notionals, maximum 20% realized mismatch, frozen per-leg
`3.5*ATR(20,D1)` stops, and no targets. Close at the first later broker month;
forty days is stale repair only. Both news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,637 registry rows, 1,305 cards, and 45 Wiki
nodes. It found no exact identity and surfaced only
`QM5_41135_xauxag-mdaily-iqrmean-rv` as a fuzzy neighbor. Evidence:
`artifacts/qm5_xauxag_mdaily_hl_rv_preallocation_dedup_20260824.json`.

Manual review distinguishes the two functionals. `QM5_41135` deletes both raw
tails and averages 9-13 surviving observations. `QM5_41138` deletes no raw
return, generates all 153-276 inclusive self/cross-pair averages, and takes
their exact median. `QM5_20276` uses the arithmetic family on twelve monthly
outright-WTI returns and follows the result; this card uses one month of daily
intermetal returns, fades the result, and owns an atomic two-leg package. No
other XAU/XAG card enumerates inclusive pairwise return averages.

Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41138`;
- slug: `xauxag-mdaily-hl-rv`;
- strategy ID: `SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01`;
- intended slot 0: `XAUUSD.DWX`, magic `411380000`;
- intended slot 1: `XAGUSD.DWX`, magic `411380001`;
- expected cadence: approximately ten to twelve packages per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on timestamp leakage, truncated month, wrong return orientation,
  missing/duplicated pair, wrong pair count, wrong median, wrong sides,
  repeated attempt, malformed basket, risk-mode mismatch, missing hard stop,
  late exit, or nondeterminism;
- no post-result change to sample, estimator, direction, carrier, risk, stop,
  hold, pair convention, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the logical basket preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
