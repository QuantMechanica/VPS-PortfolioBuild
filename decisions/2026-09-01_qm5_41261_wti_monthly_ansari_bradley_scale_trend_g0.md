# QM5_41261 WTI Monthly Ansari-Bradley Scale Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41261_wti-mab-scale-tr`
- Strategy ID: `AI-CODEX-WTI-MAB-SCALE-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41261_wti-mab-scale-tr_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/source.md`
- Source approval commit: `0fbfcc47f8`
- Identity reservation commit: `6629d2bf80`

## Decision

Approve one branch-only non-live build of the locked WTI monthly Ansari-
Bradley symmetric-rank tail-state continuation rule, followed by strict Q01
and one paced Q02 enqueue if the CPU admission gate permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source and R1

`APPROVED_WITH_PRIMARY_SOFTWARE_AND_PAPER_ACCESS_BOUNDARY`. The evidence set
contains:

- a complete-read peer-reviewed WTI time-series-momentum packet;
- authoritative Crossref metadata for the peer-reviewed Ansari-Bradley paper;
- a durable record that the Project Euclid article-body route was access-
  blocked rather than read; and
- complete pinned SciPy 1.13.1 official documentation and source evidence for
  the bounded score construction and exact no-tie route.

The records support only carrier, cadence, continuation, method lineage,
symmetric end ranks, score orientation, and exact-route conditions. The
six/six state, activity cutoff, conjunction, CFD translation, risk, and
lifecycle are pre-result QM synthesis. No inaccessible paper-body claim or
source performance transfers.

## R2 mechanical contract

`APPROVED`. The card locks:

1. exact `XTIUSD.DWX`, D1, slot 0, and magic `412610000`;
2. one attempt within 180 minutes of a genuine broker-month transition;
3. thirteen consecutive completed month-end closes with no current-month
   price;
4. twelve adjacent log returns in fixed six/six old/recent blocks;
5. finite arithmetic and strict pairwise tie rejection;
6. the pooled symmetric score path `1,2,3,4,5,6,6,5,4,3,2,1`;
7. all 924 six-label assignments, actual score at most 21, and inclusive
   lower-tail count at most 522;
8. actual recent six-return cumulative sign as the continuation side;
9. month consumption before fallible gates;
10. one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` hard stop,
    1,500-point spread ceiling, next-month exit, and forty-day stale repair.

There is no optimization surface, fitted coefficient, p-value, asymptotic
critical table, score-strength sizing, intramonth retry, target, external
runtime input, grid, martingale, or scale-in.

## R3 data

`APPROVED_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 history
and MT5-native state provide all signal and execution inputs. Q02 must expose
continuous-CFD roll/basis, financing, spread, gap, and month-label failures.

## R4 prohibited logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, fixed integer enumeration, arithmetic, comparisons, ATR
risk, quotes, orders, positions, deals, and terminal state. It contains no
trained signal, prohibited signal indicator, or external runtime feed.

## Pre-result activity prior

Across all `C(12,6)=924` strict-rank assignments, the symmetric score is at
most 21 for exactly 522 assignments. The locked boundary therefore admits
`522/924*12 = 6.779` market-free states per year before a zero recent return
and execution filters. This is an activity prior, not a significance or
performance claim. Q02 still retires the EA below five completed positions in
any full post-warm-up year.

## Non-duplicate review

The canonical corrected-root receipt
`artifacts/qm5_wti_mab_scale_tr_preallocation_dedup_20260901.json` returned
`CLEAN` across 4,760 EA identities, 1,397 card files, and 45 Wiki strategies.

Manual review separates the mechanic from:

- `QM5_41250`, which uses magnitude-sensitive within-block MAD differences
  and recalculates medians under all assignments;
- `QM5_41252`, which searches a 252-D1 cumulative-square variance break;
- `QM5_41257`, which counts only recent labels above the pooled median; and
- `QM5_41176`, which uses monotone ranks for location shift.

Fixed linear-rank fixtures prove both decision-disagreement directions versus
`QM5_41250`: recent ranks `{1,2,3,4,5,6}` qualify here at `21/522` while MAD
expansion is zero; `{1,2,3,4,6,7}` are flat here at `22/629` while MAD
qualifies at tail 340.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_ANSARI_BRADLEY_SYMMETRIC_END_RANK_EXACT_924_LOWER_TAIL522_CUMULATIVE_RETURN_CONTINUATION`.

## Approval conditions

- Card schema lint, deterministic score/enumeration fixtures, build guard,
  static guardrails, strict compile, and Q01 artifact validation must pass.
- Backtest setfiles must use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, `ENV=backtest`, both news axes OFF, and Friday close
  OFF.
- Q02 receives one locked baseline and no component, optimization, stress,
  demo, shadow, or live variant.
- Stop at the governed CPU ceiling before Q02 mutation and preserve a durable
  handoff receipt if admission fails.
- Q09 alone may establish realized decorrelation. There is no correlation
  waiver or portfolio promise.

## Excluded scope

No manual tester run, parameter sweep, threshold repair, live/demo/shadow/
stress preset, portfolio-gate change, deploy or live manifest, `T_Live`,
AutoTrading, terminal control, portfolio admission, or correlation waiver is
authorized.

## Approval rationale

R1-R4 pass under the current OWNER mission and the binding reputable-source
criteria. The hypothesis adds direct crude-oil exposure using a new rank-only
structural state; its exact mechanic is distinct from existing builds and
mechanical enough for deterministic falsification. Proceed to the governed
registry-clean branch build only.
