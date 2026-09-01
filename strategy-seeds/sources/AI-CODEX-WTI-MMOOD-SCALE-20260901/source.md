---
source_id: AI-CODEX-WTI-MMOOD-SCALE-20260901
title: WTI monthly Mood squared-rank scale non-contraction continuation
publisher: QuantMechanica governed AI synthesis from peer-reviewed WTI and scale-method research plus official pinned implementation evidence
source_type: ai_originated_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_mood_scale_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_records:
  - MOOD-1954
  - SCIPY-MOOD-1.18.0
created: 2026-09-01
created_by: Research+Development
cards_extracted: []
---

# WTI Monthly Mood Squared-Rank Scale Non-Contraction Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_mood_scale_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies direct WTI trend or
seasonality as eligible. This packet is bounded to one card, one branch build,
strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including monthly own-return continuation
   and explicit NYMEX WTI membership; and
2. SciPy 1.18.0 official `scipy.stats.mood` documentation plus the signed-
   tag-pinned implementation at commit
   `54ef5423f2e4376230ec3bfda6912a07a50958e3`, including the complete pooled-
   rank, squared-rank score, no-tie expectation, variance, and standardized-
   statistic arithmetic used here.

Mood (1954), "On the Asymptotic Efficiency of Certain Nonparametric Two-
Sample Tests," *The Annals of Mathematical Statistics* 25(3), 514-522, DOI
`10.1214/aoms/1177728719`, supplies the named peer-reviewed squared-rank
dispersion record. Publisher metadata and the indexed abstract were read.
Direct scripted PDF retrieval returned an Incapsula HTML block page, so no
complete-paper body read, inaccessible derivation, or paper-file hash is
claimed. The complete pinned official SciPy record supplies the exact no-tie
arithmetic. Retrieval boundaries and hashes are stored beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Sources Of Record And Adverse Evidence

Moskowitz, Ooi, and Pedersen define a broad monthly time-series-momentum
family on liquid futures and explicitly include NYMEX WTI. Their pooled
commodity result does not establish a WTI-only effect, this six-month
direction horizon, a scale-regime gate, a continuous-CFD translation, fixed
risk, or the QM lifecycle. Their excess returns, rolling contracts,
volatility sizing, costs, and portfolio results do not transfer.

Official SciPy documentation identifies Mood's method as a nonparametric
two-sample scale test under the model `f(x)` versus `f(x/s)/s`. Its pinned
no-tie implementation pools and average-ranks the observations, sums squared
rank distances from the pooled center for the first sample, subtracts the
fixed null expectation, and divides by the exact fixed null standard
deviation. The software then maps that statistic to a normal-reference
p-value. This EA deliberately stops before the probability lookup.

The inclusive `M_old <= 71.5` rule is not a significance test. It means the
older group's rank-dispersion score is no greater than its fixed null center,
so recent dispersion is not lower under equal six/six membership. Including
the exact equality state is a disclosed activity-preserving QM choice. It is
not a Mood, SciPy, or WTI paper result.

## Source Claim Boundary

The sources jointly motivate one bounded question: when the latest six
completed WTI monthly returns do not show lower pooled squared-rank
dispersion than the preceding six, does the recent WTI return direction
continue for one broker month?

No source tests this conjunction. Thirteen completed endpoints, adjacent log
returns, fixed six/six membership, anchored tie rejection, inclusive null-
center comparison, six-month cumulative-return side, continuous-CFD mapping,
fixed-dollar risk, stop, spread, consumed attempt, and lifecycle are pre-
result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
significance, CFD equivalence, independence, decorrelation, or portfolio
statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct thirteen positive, finite,
consecutive completed-month `XTIUSD.DWX` closes `C[0..12]`, oldest to newest.
Require every endpoint month key to advance exactly once and the newest
endpoint to be no more than ten calendar days before the current normalized
broker month.

Form twelve chronological adjacent log returns:

```text
r[i] = log(C[i+1]/C[i]), i=0..11
old = r[0..5]
recent = r[6..11]
```

Pool the twelve returns and sort ascending. A tie run is anchored to its
first sorted value. If any later value in that run satisfies
`abs(candidate-anchor) <= 1e-12*max(1,abs(anchor),abs(candidate))`, consume
the month flat. Chaining from the immediately prior observation is forbidden.

With unique values assign integer ranks `R=1..12` to original observations.
Require twelve assignments, `sum(R)=78`, and no duplicate rank. For the six
older observations compute:

```text
M_old = sum((R_old - 6.5)^2)
E0 = 6*(12^2-1)/12 = 71.5
Var0 = 6*6*(12+1)*(12+2)*(12-2)/180 = 364
z = (M_old - 71.5)/sqrt(364)
```

Require finite `M_old`, positive fixed variance, and finite `z`. The recent
scale state qualifies iff `M_old <= 71.5` exactly. No normal CDF, p-value,
critical value, exact-tail enumeration, statistic magnitude, or adaptive
threshold enters the rule.

Then compute `recent_return=sum(r[6..11])`. Buy when it is greater than
`1e-12`, sell when it is less than `-1e-12`, and consume flat otherwise.

## Pre-Result Activity And Duplicate Boundary

Across all 924 assignments of six unique ranks to the older block, 426 have
`M_old<71.5`, 72 have `M_old=71.5`, and 426 have `M_old>71.5`. The locked
inclusive rule therefore qualifies 498/924 assignments, an approximately
6.47-per-year state prior before neutral side, data, and execution gates. It
is not a market frequency or performance result. Q02 must retire fewer than
five completed positions in any full post-warm-up year.

The corrected-root receipt
`artifacts/qm5_wti_mmood_scale_tr_preallocation_dedup_20260901.json` found no
exact identity and two expected fuzzy neighbors across 4,766 registry rows,
1,403 cards, and 45 Wiki nodes.

- `QM5_41261` assigns symmetric end weights `1,2,3,4,5,6,6,5,4,3,2,1` to
  raw ranks and gates on an exact 924-label lower tail. Mood instead squares
  distance from pooled rank center, uses a fixed expectation/variance, and
  performs no permutation tail.
- `QM5_41266` centers each block on its own median, ranks absolute deviations,
  transforms them with positive normal scores, and compares group means.
  Mood never centers raw returns or ranks deviations.
- `QM5_41250` recomputes group MAD for every label allocation; Mood preserves
  one pooled raw-return rank assignment.

Two fixed unique-return fixtures prove decision disagreement:

```text
Mood-only:
[6.50,8.00,-2.75,-1.50,6.00,-2.50 | 7.00,-3.25,-1.25,-0.75,-6.25,1.25]
ranks = [10,12,3,5,9,4 | 11,2,6,7,1,8]
M_old=69.5; z=-0.104828483672; recent_return=-3.25
=> Mood qualifies SELL; Fligner-Killeen flat; Ansari-Bradley score 22 flat;
   permutation-MAD delta -2.25/tail 683 flat.

Fligner-only:
[3.00,-6.50,-6.00,-2.50,4.00,-2.00 | 3.50,2.75,-4.25,-7.50,-5.00,-3.00]
ranks = [10,2,3,7,12,8 | 11,9,5,1,4,6]
M_old=77.5; z=0.314485451017; recent_return=-13.50
=> Mood flat; Fligner-Killeen qualifies SELL; Ansari-Bradley score 22 flat;
   permutation-MAD delta -1.375/tail 761 flat.
```

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RAW_RETURN_POOLED_INTEGER_RANK_MOOD_SQUARED_RANK_RECENT_SCALE_NONCONTRACTION_CUMULATIVE_RETURN_CONTINUATION`.

## Mechanical Execution Contract

- Exact host/traded symbol `XTIUSD.DWX`, exact `PERIOD_D1`, slot 0, registered
  magic, and one consumed attempt per normalized broker month.
- Persist the month marker before history, signal, spread, quote, ATR, sizing,
  margin, or order checks. No outcome retry is permitted in that month.
- Backtest risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Use one completed-bar `ATR(20,D1)` frozen at entry and a broker hard stop at
  `3.5*ATR`; no target.
- Reject spread above 1,500 points; use deviation 20 points.
- Exit on the first processed tick in a later normalized broker month or
  after forty calendar days as stale repair.
- Repair duplicate, wrong-symbol, wrong-magic, wrong-side, or stopless owned
  exposure before entry-only gates.
- Both news axes, legacy news mode, and Friday close are OFF.
- No target, trail, break-even, partial close, intramonth flip, scale-in,
  pyramid, grid, martingale, external feed, file read, randomization, trained
  output, optimization, or portfolio-state input is authorized.

## Falsification And Safety Boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed rank/fixture parity, nonpositive governed economics,
or any downstream gate failure. A change to symbol, cadence, endpoints,
return orientation, group membership, tie rule, rank score, inclusive gate,
direction, attempt timing, risk, stop, spread, or lifecycle requires a new EA
identity and full pipeline requalification.

This source authorizes only one Strategy Card. After G0 it may authorize one
branch build, deterministic reference tests, strict Q01, one D1
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff if the CPU
ceiling permits. It does not authorize a manual tester run, optimization,
live/demo/shadow/stress setfile, AutoTrading, `T_Live`, deploy/live manifest,
portfolio-gate mutation, portfolio admission, or correlation waiver.

