---
source_id: AI-CODEX-WTI-M2RUNS-20260827
source_type: ai_originated_governed_synthesis
title: WTI Monthly Fixed-Block Two-Sample Label-Runs Distribution Shift
author: OpenAI Codex
supporting_authors: Abraham Wald; Jacob Wolfowitz; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: current explicit OWNER commodity/energy portfolio mission and decisions/2026-08-27_wti_monthly_wald_wolfowitz_runs_shift_trend_source_approval.md
created: 2026-08-27
created_by: Codex
last_reviewed: 2026-08-27
---

# WTI Monthly Fixed-Block Two-Sample Label-Runs Distribution Shift

## Canonical Origin

This is one bounded AI-originated source under the source-agnostic R1 rule in
`processes/qb_reputable_source_criteria.md`. The current explicit OWNER
mission requests one genuinely different structural, low-frequency commodity
or energy edge, permits a direct `XTIUSD` trend/seasonality construction, and
requires a card, build, fixed-risk backtest preset, and paced Q02 enqueue.

Codex synthesized the exact trading hypothesis below after a deterministic
pre-allocation duplicate scan. The method name and bibliographic record are
not presented as extracted alpha. This packet is the single lineage source;
the records below are supporting citations and claim boundaries.

## Supporting Evidence And Retrieval Boundary

### Monthly WTI carrier

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time
Series Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Its bounded findings include monthly
own-price continuation research and explicit NYMEX WTI membership.

That paper does not test pooled sample-label runs, fixed five-month blocks,
continuous CFDs, the boundary below, fixed-dollar risk, or the QM lifecycle.
No paper return, alpha, Sharpe ratio, volatility target, WTI-only result, or
cost result transfers.

### Two-sample method record

The peer-reviewed bibliographic record is Abraham Wald and Jacob Wolfowitz
(1940), "On a Test Whether Two Samples Are from the Same Population," *The
Annals of Mathematical Statistics* 11(2), 147-162, DOI
`10.1214/aoms/1177731909`.

The mandatory public-source router classified the DOI
`DEFERRED:SOURCE_POLICY`: the generic reader is disabled until a
cryptographic OWNER authorization verifier exists. Receipt:
`retrieval_route_20260827.json`. No complete-paper read is claimed, no raw
page is committed, and no inaccessible formula, table, critical value,
p-value, example, or performance assertion is paraphrased.

The exact rule in this packet is therefore an openly disclosed Codex
synthesis. Its arithmetic is independently executable and exhaustively
enumerable; it does not depend on an inaccessible source passage.

## Locked Hypothesis

Slow physical supply, inventory, refining, transport, investment, hedging,
geopolitical, and demand adjustments can displace the level distribution of
completed WTI months. If older and newer fixed blocks cluster separately when
all ten closes are pooled and sorted, continue the newer block's median
direction for one month.

On the first executable `XTIUSD.DWX` D1 tick of a genuine new broker month:

1. Reconstruct exactly ten consecutive completed broker-month end closes,
   ordered oldest to newest.
2. Fix `O=C[0..4]` and `N=C[5..9]`. Require all values positive, finite, and
   pairwise distinct.
3. Pool the ten values, sort them in strict ascending order, retain only each
   value's fixed `O` or `N` label, and count
   `R = 1 + number_of_adjacent_label_changes`.
4. Qualify only at `R<=6`. This is the balanced-sample null expected run
   count, used only as an inclusive structural clustering boundary. Compute
   the exact five-observation median of each
   fixed block. Buy when `median(N)>median(O)` and sell when
   `median(N)<median(O)`. With pairwise-distinct inputs equality is
   impossible; malformed state consumes the month flat.
5. Persist the month attempt before history, signal, news, spread, quote,
   stop, sizing, margin, or order gates. Never retry the same month.
6. Hold one fixed-risk WTI position until the next genuine broker month or a
   forty-calendar-day stale boundary. Protect it with a frozen
   `3.5*ATR(20,D1)` hard stop and no target.

The boundary is not called a statistical critical value and no significance
is claimed. It is a predeclared trading filter selected once to preserve the
shop's minimum frequency prior; it is not an optimization surface.

## Exact Density Arithmetic

With five fixed old labels and five fixed new labels, strict pooled order has
`choose(10,5)=252` possible label sequences. The exact numbers with `r` runs
are:

| runs `r` | assignments |
|---:|---:|
| 2 | 2 |
| 3 | 8 |
| 4 | 32 |
| 5 | 48 |
| 6 | 72 |
| 7 | 48 |
| 8 | 32 |
| 9 | 8 |
| 10 | 2 |

Thus `R<=6` qualifies `162/252 = 9/14`, and label reflection splits those
states into 81 higher-new-median and 81 lower-new-median assignments. Before
market data this is exactly `12*9/14 = 54/7`, or approximately `7.7143`, directional decisions
per year. It is a density prior only. Q02 owns actual trades and retires the
candidate below five completed trades in any full post-warm-up year.

The source packet originally transcribed the exact table incorrectly and
locked `R<=5`, which exhaustive pre-build enumeration showed would admit only
`90/252` states, or `4.2857` decisions/year. Before compilation, Q01, Q02, or
any market-result observation, the execution contract was corrected once to
the untuned `R<=6` boundary so the predeclared five-trade floor is feasible.
The correction is governed by
`decisions/2026-08-27_qm5_41184_prebuild_density_correction.md`; it is not a
performance-conditioned rescue and does not change the pooled-label-runs
mechanic family.

## Non-Duplicate Boundary

The canonical fail-closed check returned `CLEAN` after scanning 4,683 EA
registry identities, 1,334 card files, and 45 current-vault Strategy Wiki
nodes. Receipt:
`artifacts/qm5_wti_mww_runs_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`88D3A10D84ECB5C876FA9916F24234DA802EDEB8AFA1A8D0805B2EC387EC27B1`.

The nearest mechanics are different state functions:

- `QM5_41182_wti-median-runs-tr` counts chronological transitions after all
  observations are dichotomized around one pooled median. This rule discards
  chronological order inside each block and instead counts old/new labels
  after price sorting.
- `QM5_41183_wti-mks-shift-tr` retains the maximum signed ECDF count gap from
  fixed six-plus-six blocks. This rule counts every membership run in a fixed
  five-plus-five pooled order and separately uses block medians for side.
- `QM5_41176_wti-mwilcoxon-shift-tr` sums all cross-block pair wins; this rule
  ignores that sum and uses adjacency clustering.
- `QM5_41172_wti-mpettitt-shift-tr` searches a variable chronological change
  point; this rule fixes the split and is invariant to within-block time
  order.
- `QM5_12567_cum-rsi2-commodity` is a two-day, long-only XNG oscillator
  pullback, not a symmetric monthly direct-WTI distribution-shift rule.

## Reputable-Source Criteria

- **R1 — PASS_WITH_PUBLIC_METHOD_ACCESS_LIMITATION.** Exactly one source ID
  identifies this AI-originated governed packet, which the canonical R1 rule
  expressly permits. The supporting method has a named peer-reviewed record;
  its page was policy-deferred and is not represented as complete-read. The
  monthly WTI support is a durable complete-read peer-reviewed packet.
- **R2 — PASS.** Clock, ten endpoints, fixed five/five membership, strict
  ties, pooled sort, run count, inclusive boundary six, exact medians,
  direction, attempt, fixed risk, hard stop, and lifecycle are locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered
  `XTIUSD.DWX` D1 prices and native MT5 execution state provide every runtime
  input. Continuous-CFD roll, basis, financing, gap, and label risks remain.
- **R4 — PASS.** Native timestamps, OHLC, sorting, comparisons, integer
  counts, ATR risk, position, and deal state only; no ML, trained output,
  prohibited runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

This packet does not establish profitability, significance, independence,
decorrelation, or portfolio fitness. Q02 kills zero trades, a full-year
frequency below five, nonpositive governed economics, or any implementation
defect. Later gates own robustness and Q09 owns realized overlap. No failed
result may be rescued by changing block size, run boundary, direction,
carrier, risk, hold, or by adding a filter.

No live/demo/shadow/stress or optimization preset, manual tester run,
AutoTrading action, `T_Live` change, deploy/live manifest, portfolio-gate
change, correlation waiver, or portfolio admission is authorized.
