# FX cointegration fallback eligibility audit / CPU stop

Recorded: 2026-09-02T20:49:02.0596037Z (22:49 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `173d92a9def1d6c67915cac4e91d96826df02cdc`

## Outcome

No unbuilt relationship remains in the frozen 66-pair FX cointegration
frontier. Both preferred anchors have real Q02 passes rather than current
`ONINIT` or `NO_HISTORY` blockers. The one clean existing D1 continuation,
`QM5_12778` AUDUSD/EURJPY, already has a unique priority-bound Q09_NEWS row,
so another enqueue or priority write would be duplicate work.

A fresh five-sample host window reached 100% against the 97% hard ceiling.
The wake therefore stopped without a claim, dispatch, compile, or backtest.

## Non-duplicate audit result

This wake closed the remaining ambiguity around apparent fallback candidates:

| Candidate | Read-only finding | Disposition |
| --- | --- | --- |
| `QM5_34008` | Pure-FX multicurrency dispersion basket; zero work-item history | Rejected: its SPEC expects about 70 trades/year on the owner lane and describes 80–160 trades/year, violating the low-frequency constraint |
| `QM5_10309` | Logical Q02 PASS and unprioritized Q04 pending | Rejected: M15 high-frequency implementation |
| `QM5_12512` | Logical FX-pairs Q02 pending | Preserved: row `acbad967-bf94-4565-9e51-db193de01bf9` is already priority-bound |
| `QM5_20195`, `20197`, `20201`, `20207`, `20211`, `20250` | Unprioritized D1 pending rows exist | Rejected: each row is stale behind a later terminal economic failure |
| `QM5_11241`–`QM5_11256` | Structural D1 spread family lacks logical-basket work items | Rejected: legacy `_per_instance` manifests plus existing pair-level terminal/active rows cannot be repurposed into a unique governed relationship |
| `QM5_10717`, `10718`, `41140`, `41153`, `41154`, `41155` | Other low-frequency FX basket continuations | Preserved: already priority-bound and not a new cointegration relationship |

This classification is the new durable result. It prevents subsequent paced
wakes from mistaking an untouched but too-frequent basket, a stale downstream
row, or a legacy per-instance manifest for eligible portfolio-growth work.

## Frontier and anchors

The checked-in sign-aware reproduction still emits all 66 unordered
relationships, and the relationship-to-card/EA reconciliation found 66/66
represented with zero unbuilt relationships. Tail checks also resolve the two
easy-to-miss identities: rank 65 USDCHF/AUDUSD is governed by `QM5_1156`, and
rank 66 USDCAD/EURAUD is `QM5_12803` (Q02 PASS, then Q04 FAIL).

Current anchor paths are:

| EA | Relationship | Current terminal path |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS, then Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), then Q04 FAIL |

There is no current anchor initialization/history repair to make.

The selected existing fallback remains `QM5_12778`, a structural D1
AUDUSD/EURJPY two-leg cointegration basket using a closed-bar fixed-beta log
spread and fixed-risk test configuration (`RISK_FIXED=1000`,
`RISK_PERCENT=0`). Its diagnostic Q09_NEWS work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` was pending, unclaimed, attempt zero,
and already priority-bound. It was not mutated again.

## Binding resource stop

The two-second samples were `90%`, `90%`, `70%`, `83%`, and `100%` from
20:48:52Z through 20:49:02Z. Average was 86.6%; maximum was 100%. The hard
rule stops when either measure reaches 97%, so the maximum bound.

No Strategy Card, EA, setfile, manifest, registry, magic row, runtime queue
row, priority mark, worker, terminal, or AutoTrading state changed. No
portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, or live/deploy surface was touched. Existing unrelated
worktree changes were preserved.

Machine-readable companion:
`artifacts/fx_cointegration_fallback_audit_cpu_stop_20260902T204902Z_board_advisor.json`.
