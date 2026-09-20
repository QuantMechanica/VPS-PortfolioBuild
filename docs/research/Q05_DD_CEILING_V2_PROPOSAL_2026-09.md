# Q05 drawdown ceiling v2 proposal — R-denominated shadow contract

Status: **ANALYSIS ONLY / NO GATE CHANGE**  
Decision owner: Fable, after an independent critic  
Router task: `a0780fc3-0342-458e-855a-3b4f71b05d13`  
Authority supplied by the task: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`

## Executive finding

The current Q05 rule measures drawdown on a USD 100,000 test account at
`RISK_FIXED=1000` and parks a stream when maximal drawdown exceeds 25%. This is
equivalent, for the fixed-risk cohort, to a hard ceiling of 25 initial-risk units
(`25R`). The full 2026 `FAIL_DD_PORTFOLIO_REVIEW` cohort contains 61 work-item rows
(57 distinct EA/symbol pairs), all tested with `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

This paper proposes a **shadow v2 candidate**, not an activation:

> Keep every current Q05 criterion, but run the v2 stress profile at
> `RISK_FIXED=500`, `RISK_PERCENT=0`, starting equity USD 100,000, and keep the
> 25% account-DD ceiling. For retrospective screening only, this is represented
> as `DD_R <= 50`.

The fixed `50R` candidate is preferred to a density bonus because it is simple,
auditable, and does not reward a strategy merely for trading more often. On the
61-row retrospective cohort it would send 45 rows to measurement and keep 16
parked. Against the predeclared upstream economic-signal proxy, v1 has
`TP=0, FP=0, TN=26, FN=35`; projected v2 has
`TP=27, FP=18, TN=8, FN=8`. These are **admission-proxy** errors, not claims of
live profitability. Q08 and the book controls remain responsible for actual
portfolio and FTMO loss measurement.

No source code, threshold, verdict, registry row, work item, or pipeline gate was
changed by this ticket.

## 1. Current contract and code location

The inspected implementation is
`framework/scripts/q05_stress_medium.py`, SHA-256
`0928ffefbc0e34625ede4ba71523235b3aa0466263475713d426d90527813317`,
at repository commit `9a78fa3647983710cdbb321a127d0950025140ca`.

- Lines 52–55 define `PF_FLOOR=1.0`, `DD_PCT_MAX=25.0`,
  `MIN_TRADES=20`, and `STARTING_EQUITY=100000.0`.
- Line 574 computes `dd_pct = dd_money / STARTING_EQUITY * 100`.
- Lines 588–595 reject insufficient trades, missing metrics, and `PF <= 1.0`
  before considering drawdown.
- Lines 596–607 map `dd_pct > 25` to
  `FAIL_DD_PORTFOLIO_REVIEW`; the row does not cascade to Q06.

Thus the current drawdown criterion is account-percentage based but the account
risk setting is part of the experiment. With fixed risk USD 1,000 on USD
100,000, 25% is 25R. The criterion is not a 5% daily-loss or 10% total-loss FTMO
test and must not be described as one.

## 2. Cohort and reproducible measurements

The row-level evidence is
[`Q05_DD_CEILING_V2_COHORT_2026.csv`](./Q05_DD_CEILING_V2_COHORT_2026.csv),
SHA-256 `c136919a99cf229088081fa30f80a79f1da7f7e980553f2d4033d482c9367c58`.
It contains every current SQLite row satisfying:

```text
phase = Q05
verdict = FAIL_DD_PORTFOLIO_REVIEW
created_at >= 2026-01-01
```

The extraction found 61 rows and 57 unique `(ea_id, symbol)` pairs. Repeated
measurements are deliberately retained because the requested unit is the work
item and old verdicts are immutable. Duplicate pairs are QM5_10790/XAUUSD (3),
QM5_10796/XAUUSD (2), and QM5_10423/XAUUSD (2).

For each row:

- Q05 → Q04 → Q02 lineage is explicit for 43 rows, exact-setfile matched for
  14, and EA/symbol fallback matched for 4. The method and every row ID are in
  the CSV.
- Q02 density is `Total Trades / inclusive Monday–Friday days` over the raw
  report period. It is an auditable weekday-density approximation, not an
  exchange-session calendar.
- Q02 expectancy is `Total Net Profit / Total Trades / RISK_FIXED`.
- Q02 PF is the raw report Profit Factor. The FP/FN proxy uses this Q02 PF,
  not a reconstructed Q05 PF.
- Q05 `DD_R` is maximal drawdown money divided by fixed risk. Exact raw-report
  DD is available for 58 rows. Three rows retain only the immutable two-decimal
  `dd_above_ceiling:dd_pct=...` reason; because starting equity is USD 100,000
  and fixed risk is USD 1,000, the reported percentage equals R for those rows.
- Every recovered raw report path and SHA-256 is bound in the CSV. Three Q02
  report tags survived on a different terminal from later-overwritten row
  metadata; exact EA, symbol, evidence timestamp, report period, and hash are
  recorded as `cross_terminal_exact_tag` rather than silently treating the
  declared terminal as authoritative.

All 61 rows have complete requested density, E[R], PF, DD-in-R, and projected
DD-at-0.5%-risk fields. Observed ranges are:

| Field | Minimum | Maximum |
|---|---:|---:|
| Q02 trades/business-day | 0.040 | 2.259 |
| Q02 E[R]/trade | -0.353 | +0.174 |
| Q02 PF | 0.70 | 2.56 |
| Q05 maximal DD | 25.060R | 97.719R |

Within this already-censored cohort, Pearson correlation between weekday trade
density and DD_R is +0.594. This is descriptive only: conditioning on Q05 parks
prevents a population-level causal claim. The density buckets nevertheless show
why density should be reported:

| Q02 trades/business-day | Rows | Median DD_R | Rows at or below 50R |
|---|---:|---:|---:|
| <0.25 | 9 | 29.17 | 9 |
| 0.25–<0.50 | 14 | 31.59 | 12 |
| 0.50–<1.00 | 27 | 39.27 | 23 |
| >=1.00 | 11 | 69.80 | 1 |

## 3. The two examples and a lineage correction

The task payload's QM5_10423 example combines facts from two distinct Q05 rows.
The cohort must not collapse them:

| Q05 work item | Q04 | Bound Q02 evidence | Density | E[R] | Q02 PF | Q05 DD_R | DD at 0.5% | v2 projection |
|---|---|---|---:|---:|---:|---:|---:|---|
| `bc722066-8226-499b-bd6e-15ca4f8e53cc` | PASS | setfile-matched `93a52618-c00b-422a-bf20-a6b24828ed7c` | 0.701 | +0.0276 | 1.07 | 41.023 | 20.511% | ADVANCE |
| `c6f5b4b5-3a38-4882-b810-3060df07cc5c` | PASS_SOFT | explicit `162db6f6-7e57-494a-a110-03e45f8aa845` | 0.821 | +0.0859 | 1.22 | 34.723 | 17.361% | ADVANCE |
| `dde80168-b437-4dfc-919f-b6b7690817ef` (QM5_11690) | PASS | explicit `1c8ff188-8ba1-467e-88b0-47a1466be943` | 1.840 | +0.0285 | 1.08 | 59.392 | 29.696% | PARK |

The 41.02% DD belongs to the first QM5_10423 row; the 0.82/day, +0.086R,
PF 1.22 evidence belongs to the second. Both would clear a retrospective 50R
screen. QM5_11690 would not. This separation is useful: v2 relaxes the risk
normalization without granting every high-density stream a waiver.

## 4. sec68A hypothesis and refutation package

### H-Q05-R50

Q05 at USD 1,000 fixed risk conflates path quality with a 1%-of-starting-equity
test size. Re-expressing the same 25% ceiling at USD 500 fixed risk will recover
a material share of economically positive intraday candidates for Q08
measurement while retaining an R-denominated tail screen. It will not authorize
deployment, book weight, or live risk.

### Candidate v2 contract

```text
gate_contract_version = q05_dd_v2_risk500_shadow
STARTING_EQUITY = 100000
RISK_FIXED = 500
RISK_PERCENT = 0
MIN_TRADES = 20                 # unchanged
PF_FLOOR = 1.0                 # unchanged; strict PF > 1 remains
DD_PCT_MAX = 25.0              # unchanged
projected historical screen = DD_R <= 50
```

An actual rerun is mandatory before a v2 verdict. `DD_R * 0.5%` is a cohort
projection only; lot steps, minimum volume, margin, price path, and execution
can break exact linearity. No projected row may be promoted as if it were a
pipeline result.

### Predeclared refutation criteria

Run all 61 immutable predecessors through a separately versioned shadow Q05 at
the candidate setfile. Refute H-Q05-R50, and do not propose activation, if any
of the following holds:

1. More than 6 of 61 actual pass/park outcomes disagree with the predeclared
   `DD_R <= 50` projection, or the actual pass count falls outside 39–51.
2. Against the economic-signal proxy defined below, actual v2 recall is below
   0.70 or precision is below 0.55. Projected values are 0.771 and 0.600.
3. Any implementation requires changing `MIN_TRADES`, `PF_FLOOR`, the 25%
   ceiling, news blackout, risk-percent mode, or a historical verdict.
4. The independent critic finds that cross-terminal recovery or inferred
   lineage changes at least 4 FP/FN cells (enough to move a projected metric
   across its refutation bound).
5. Q08 evidence for the requalified set shows the proposal merely transfers an
   unbounded loss problem downstream. In particular, the FTMO controls remain
   <=5% daily DD and <=10% total DD; any row breaching them cannot be called a
   safety success regardless of Q05 outcome.

Criteria 1–4 adjudicate the shadow contract. Criterion 5 is a downstream safety
veto, not permission to infer Q08 results from Q05.

## 5. FP/FN measurement

There are no observed Q08 labels for rows censored at Q05, so “true profitable”
is unknowable from this cohort. To avoid laundering a speculative label into a
pipeline verdict, this analysis predeclares a narrow **economic-signal proxy**:

```text
proxy positive := Q02 PF > 1.0 AND Q02 E[R]/trade > 0
proxy negative := otherwise
predicted positive := contract sends the row onward for measurement
```

All 61 rows are scorable: 35 proxy-positive and 26 proxy-negative. A false
positive means measurement cost on a row whose upstream proxy is negative; a
false negative means continued censorship of an upstream-positive row. Neither
term means a live false positive or false negative.

| Contract | TP | FP | TN | FN | Precision | Recall | Rows advanced |
|---|---:|---:|---:|---:|---:|---:|---:|
| v1: current 25R ceiling | 0 | 0 | 26 | 35 | undefined | 0.000 | 0 |
| v2: projected fixed 50R ceiling | 27 | 18 | 8 | 8 | 0.600 | 0.771 | 45 |

Latest-row-per-EA/symbol sensitivity (57 rows) gives v2 `TP=24, FP=18,
TN=8, FN=7`, with 42 advanced. The conclusion is not driven by the four repeated
work-item observations.

Threshold context, using the same proxy:

| Ceiling | Advanced | TP | FP | TN | FN | Precision | Recall |
|---|---:|---:|---:|---:|---:|---:|---:|
| 30R | 18 | 12 | 6 | 20 | 23 | 0.667 | 0.343 |
| 40R | 34 | 21 | 13 | 13 | 14 | 0.618 | 0.600 |
| **50R** | **45** | **27** | **18** | **8** | **8** | **0.600** | **0.771** |
| 60R | 50 | 29 | 21 | 5 | 6 | 0.580 | 0.829 |
| 75R | 55 | 30 | 25 | 1 | 5 | 0.545 | 0.857 |

The 50R choice is not fitted as an optimum. It is the mechanically interpretable
result of retaining a 25% account-DD test at 0.5% initial risk per trade.

### Why density-normalized sqrt scaling is not v2

A challenger rule `DD_R <= 50 * sqrt(max(1, trades/business-day))` would advance
49 rows and yield projected `TP=29, FP=20, TN=6, FN=6`. It adds two proxy true
positives and two proxy false positives relative to fixed 50R. More importantly,
it assumes independent-trade square-root scaling, uses an approximate weekday
density from a different window, and increases allowed drawdown when an EA emits
more trades. The present censored cohort cannot validate those assumptions.
Record density, but defer that challenger unless it is separately preregistered
and independently criticized.

## 6. Versioning and requalification plan

If, and only if, Fable approves after independent criticism:

1. Add a new versioned Q05 profile; do not edit old result rows or reinterpret
   `legacy` gate contracts.
2. Derive shadow setfiles with `RISK_FIXED=500` and `RISK_PERCENT=0`; validate
   the build/setfile guardrails. The stale-news maximum must remain <=336 hours.
3. Enqueue new Q05 work items bound to the prior Q04 predecessor, source EX5,
   MQ5/include closure, setfile SHA-256, history window, news seed, and
   `gate_contract_version=q05_dd_v2_risk500_shadow`.
4. Store `prior_q05_work_item_id` and `requalification_reason` in the new row.
   Never overwrite the v1 `FAIL_DD_PORTFOLIO_REVIEW` row.
5. Compare actual v2 results with the sealed CSV projection and apply the
   refutation criteria before any contract activation decision.
6. Only actual v2 PASS rows may follow the normal pipeline cascade. Q08 evidence
   alone supplies portfolio verdicts. Q05 does not confer deploy or live-use
   authority.

Rollback is therefore trivial: stop creating v2 rows and leave the old gate
contract authoritative. No historical data migration is required.

## 7. Decision requested from Fable

After an independent critic reviews the lineage, proxy, and refutation bounds,
choose one of:

- approve a **shadow-only** 61-row `RISK_FIXED=500` rerun;
- request a revised preregistration; or
- reject H-Q05-R50 and retain v1 unchanged.

This document does not recommend direct activation. It recommends only the
bounded shadow experiment because the retrospective linear scaling is not a
pipeline verdict.

## 8. Explicit non-change attestation

**No Q05 gate criterion was changed.** The current code still uses
`PF_FLOOR=1.0`, `MIN_TRADES=20`, `DD_PCT_MAX=25.0`, and
`STARTING_EQUITY=100000.0`. No existing verdict, work item, setfile, EA, registry,
worker, terminal, AutoTrading state, or T_Live state was modified. The only
deliverables are this proposal and its evidence-bound cohort CSV.
