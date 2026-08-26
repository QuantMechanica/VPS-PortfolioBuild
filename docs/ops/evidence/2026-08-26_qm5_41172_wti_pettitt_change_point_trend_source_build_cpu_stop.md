# QM5_41172 WTI Pettitt Change-Point Trend Source Build And CPU Stop

Date: 2026-08-26

Branch: `agents/board-advisor`

EA: `QM5_41172_wti-mpettitt-shift-tr`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity/energy candidate

`QM5_41172` is a low-frequency, symmetric direct-WTI structural trend
candidate on exact `XTIUSD.DWX` D1. At the first executable bar of a new
broker month it reconstructs the latest close from each of the immediately
prior thirteen completed consecutive months, requires strict no-tie ranks,
and calculates the complete twelve-value Pettitt cumulative rank-sum path.

The EA trades only when the maximum absolute rank sum occurs exactly once and
the split lies in `K=4..9`. A negative signed maximum buys the later upward
WTI level shift; a positive maximum sells the later downward shift. Tied
maxima, edge splits, invalid history, and every nonqualifying state consume the
month flat. There is no endpoint fallback or p-value rescue.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-month closure with a
forty-day stale repair. It has one attempt and at most one owned position per
broker month.

The direct crude-oil carrier differs from the certified XAU, SP500, NDX, and
XNG book. The central change-point location also differs mechanically from
the adjacent-rank Bartels and local-turning-point WTI neighbors. These are
design facts only. Unchanged Q09 owns the first realized portfolio-correlation
verdict.

## Reputable source and non-duplicate boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly
own-price continuation lineage and explicit WTI membership. Pettitt (1979),
*Applied Statistics* 28(2), 126-135, DOI `10.2307/2346729`, supplies the
nonparametric change-point lineage. Complete pinned CRAN `trend` method files
at commit `d0ec3cf8b99b4f3226f5211f592955b85565721d` supply the exact rank-sum
path and maximum-location implementation record. The thirteen-endpoint,
unique-central-split CFD rule is a disclosed QM mechanization; no source
performance transfers.

The pre-allocation checker scanned 4,671 registry identities, 1,322 cards,
and 45 Strategy Wiki nodes and returned clean. Two locked counterexample rank
paths separate the rule from `QM5_41170` Bartels and `QM5_41171` turning-point
mechanics. The receipt is
`artifacts/qm5_wti_mpettitt_shift_tr_preallocation_dedup_20260826.json`.

## Durable commit trail

- source approval and reproducible retrieval evidence:
  `978da98a90cc26d6e7a54fd6c2366718a960b631`;
- deterministic identity, G0 decision, and approved card:
  `22beec865546a3ed8ac5d6ad475db84313f4ad3f`; and
- governed magic, resolver, source, SPEC, reference suite, EA-local card, and
  one fixed-risk D1 backtest preset:
  `b743220ebe1cf8d256303d76b62272ec4e2f8679`.

The queued MQ5 SHA-256 is
`118CA6FF5A0668A2DBF85C735FFED8A5460BAF935038B0E075F687C883F1B738`.
The unbound pre-compile setfile SHA-256 is
`BEB3A6B5AEC301D43CBBF8D730AABAC424ACC457FDB034DD5C63EEF422AE9CF5`;
its `build_hash` remains `PENDING_COMPILE` until governed compilation. The
canonical card and EA-local copy are byte-identical at SHA-256
`E31E558EE2CB8D22AD02553248B470E1D9ABA78B383AE417C5BDD0990CA182F6`.

## Source-level validation

The target-only deterministic reference suite passed 8/8 tests. It covers the
strict rank permutation, all twelve signed `U[k]` values, parity and range,
unique central maximum, long/short symmetry, edge and tied-max flat states,
two neighbor-discriminating fixtures, consecutive month keys, fixed-risk
source/set markers, exact card-copy identity, and the absence of any live
preset.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
leak validator, and both card schema/prohibited-ML lints passed. No strict
compile, EX5, full build-check, Q01 PASS, smoke, backtest, economic result, or
decorrelation result is claimed by these source-level checks.

## Governed compile and Q02 blockers

The direct strict compile and full build-check preflight each failed safely
because MT5 `terminal64.exe` processes were active. The failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, include-mirror bypass,
terminal control, or process stop occurred.

The mandated governed compile command created utility work item
`de8fa2b9-f2d5-42cd-bf75-e5782c9f492b`. At the last successful read it was
pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. Therefore no EX5 or Q01 PASS exists.

Before any target-only Q02 enqueue, five fresh whole-host CPU samples at
four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-26T20:47:38.3360000Z` | 97.90% |
| `2026-08-26T20:47:42.3690000Z` | 99.64% |
| `2026-08-26T20:47:46.3930000Z` | 99.68% |
| `2026-08-26T20:47:50.3980000Z` | 99.93% |
| `2026-08-26T20:47:54.3990000Z` | 98.54% |

Average CPU was 99.14 percent and maximum CPU was 99.93 percent, exceeding
the 97 percent backtest hard ceiling. The same capacity snapshot observed
eight `terminal64` and six `metatester64` processes. The mission's explicit
CPU stop therefore fired. No Q02 apply, manual tester, smoke, or dispatcher
tick was attempted. Q02 is blocked independently by both absent Q01 evidence
and the measured CPU ceiling.

## Safe next action

After the separately authorized compile-worker rollout releases the compile
hold, let the governed worker consume the exact queued source. Require strict
compile PASS with zero errors/warnings, a non-empty source-fresh EX5, final
setfile binding, and Q01 PASS. Only after CPU is freshly below the ceiling,
repeat target-only work-item/dedup checks and enqueue exactly one
`XTIUSD.DWX` D1 Q02 row.

No terminal process was started or stopped. AutoTrading, `T_Live`, the live
manifest, portfolio gate, portfolio membership, thresholds, and correlation
policy were untouched.

Machine-readable evidence:
`artifacts/qm5_41172_compile_handoff_20260826T204754Z_board_advisor.json`.

