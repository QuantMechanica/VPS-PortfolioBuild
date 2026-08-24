# QM5_41139 WTI Completed-Month Daily Hodges-Lehmann Momentum - G0 Decision

Date: 2026-08-24

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41139_wti-mdaily-hl-mom`. At the first executable D1 bar of each
normalized broker month, the candidate forms every WTI daily log return ending
in the immediately completed 17-23-session month, computes the exact median of
all inclusive self/cross-pair averages, and follows its sign for one month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, and one logical `RISK_FIXED` Q02 enqueue if the governed compile
queue and fresh host/tester CPU guards permit. Approval does not pre-judge
economics, diversification, decorrelation, certification, execution-contract
promotion, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_WITHIN_MONTH_PSEUDOMEDIAN_TRANSLATION_RISK`. The approved
  packet preserves Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
  Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with a
  complete author-hosted paper receipt and explicit WTI membership; Meek and
  Hoelscher (2023) supplies peer-reviewed WTI daily-return lineage; and an
  already governed WTI H-L packet supplies exact arithmetic precedent. The
  within-month pseudomedian is an explicitly untested QM translation.
- R2: `PASS`. Symbol, clock, energy labels, sample membership, older boundary,
  chronological returns, endpoint identity, inclusive pair bounds, dynamic
  pair count, self-pairs, sort, odd/even median, side, one-attempt state,
  fixed risk, stop, spread, and exit are fully mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns actual history sufficiency and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, and comparison only. ATR is risk-only. No trained
  logic, banned signal indicator, optimizer output, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026/source.md`,
SHA-256
`0B913EE46ADDC651A42572071A9C73547473CB683800A2F60B19FB53C1BDA6E4`.
Its durable approval is
`decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md`.

No new public route is used. No source return, alpha, probability, density,
trade count, risk, cost, WTI-only efficacy, CFD equivalence, neutrality, or
portfolio correlation transfers. The robust daily pseudomedian, continuous-
CFD mapping, fixed-dollar risk, stop, spread cap, and lifecycle are
falsifiable implementation hypotheses.

## Locked Statistical Contract

For an older boundary close `C[-1]` and `n` immediately completed-month
closes `C[0]..C[n-1]`, oldest to newest, where `17 <= n <= 23`:

```text
r[j] = ln(C[j] / C[j-1]), j=0..n-1

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

hl > 0 => BUY XTIUSD.DWX
hl < 0 => SELL XTIUSD.DWX
hl = 0 or invalid => FLAT
```

Require every completed-month timestamp exactly once, one adjacent older
close, positive finite closes, finite returns and pairwise averages, exact
pair count 153-276, explicit self-pair identity, ascending order, and finite
central value. Verify `sum(r)` against `ln(C[n-1]/C[-1])` within `1e-10`.
The raw endpoint is diagnostic only and never gates direction.

Consume normalized current `yyyymm` before every fallible gate. Open one
position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point entry-spread ceiling.
Close at the first later normalized broker month; forty days is stale repair
only. Both news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker authenticated and scanned 4,638 registry identities,
1,306 cards, and 45 Strategy Wiki nodes. It found no exact identity and
surfaced only `QM5_41133_wti-mdaily-median-mom` as a fuzzy neighbor. Evidence:
`artifacts/qm5_wti_mdaily_hl_mom_preallocation_dedup_20260824.json`.

Manual review distinguishes the functionals. `QM5_41133` uses only one or two
raw center returns. `QM5_41134` deletes both raw tails and averages the center
half. `QM5_41139` deletes no return, generates all 153-276 inclusive pairwise
averages, and takes the exact median of that derived distribution.
`QM5_20276` uses the same arithmetic family on twelve monthly WTI returns
spanning a year; this card uses one month of daily returns. `QM5_41138` uses
synchronized intermetal returns, fades the result, and owns two legs; this
card uses outright WTI returns, follows the result, and owns one energy
position. No other WTI completed-month daily card enumerates inclusive
pairwise return averages.

Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41139`;
- slug: `wti-mdaily-hl-mom`;
- strategy ID: `MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01`;
- intended slot 0: `XTIUSD.DWX`, magic `411390000`;
- expected cadence: approximately ten to twelve positions per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on label inconsistency, timestamp leakage, truncated month, wrong
  return orientation, missing/duplicated pair, wrong pair count, wrong median,
  wrong side, repeated attempt, risk-mode mismatch, missing hard stop, late
  exit, or nondeterminism;
- no post-result change to sample, estimator, direction, carrier, risk, stop,
  hold, pair convention, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the committed D1 preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
