# QM5_20228 FX cointegration Q04 priority handoff

Date: 2026-08-30 UTC (`2026-08-30T14:51:21Z`); 16:51 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `90fdd47a50a62a121835be468c3c59193fc923af`

Status: the unique existing rank-50 FX fallback was priority-bound in place
after the hard CPU ceiling cleared. No Card, EA, work-item identity, phase,
verdict, claim, tester, or terminal was created.

## Governed frontier decision

The OWNER-requested source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor remains blocked at Q02 by `ONINIT` or `NO_HISTORY`. A fresh
approved-card census found 120 unique cointegration/coint EA IDs and a matching
EA directory for every one. Creating another Card, EA, or Q02 row would
duplicate governed coverage or weaken the reputable-source criterion, so the
Strategy Card extraction and EA-build gates remained closed.

## Existing forex fallback advanced

The selected existing sleeve is the structural, fixed-beta D1 basket
`QM5_20228_USDCAD_GBPJPY_COINTEGRATION_D1`. It trades `USDCAD.DWX` and
`GBPJPY.DWX`; `USDJPY.DWX` supplies conversion history only. The sealed
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Its exact lineage is now:

| Phase | Work item | State |
|---|---|---|
| Q02 | `41722d88-1113-4e08-ac39-832b4708ee2d` | done / PASS |
| Q03 | `1a395c0b-73ea-4bb3-9160-6fb55c4d6777` | done / PASS |
| Q04 | `eb453b94-6031-4c40-b761-4f8005871751` | pending, priority-bound |

The Card's adverse evidence stays explicit: DEV net Sharpe `0.011529`, OOS
net Sharpe `-0.194853`, OOS return `-1.353675%`, 15 OOS state changes, and a
`65.507`-D1-bar half-life. This remains a one-shot pipeline falsification, not
permission to refit, add a filter, or rescue a failed economic gate.

## Guarded in-place mutation

Under the global factory mutation lock, an exact compare-and-swap added only
the Q04 priority fields and bounded handoff provenance. The row remained
pending, unclaimed, attempt zero, and unverdict; its original `updated_at` was
preserved.

| Measure | Before | After |
|---|---:|---:|
| Pending rows | 7,773 | 7,773 |
| Canonical queue rank | 5,602 | 1,668 |
| Matching open Q04 rows | 1 | 1 |

There were no active holds, poison-pill quarantine rows, supersession links,
or prior priority events. Audit event `380782` records the mutation. The
reversible external row journal is
`D:/QM/reports/state/qm5_20228_q04_priority_20260830T145121Z.journal.json`
(SHA-256
`fe51964504f58f47df1c8571a715d34c71f4e76450e46c2661ee667a0784859d`,
state `COMMITTED`). The factory mutation lock released normally.

## Capacity and pacing

Five apply-time CPU samples were `94.632169%`, `86.565480%`, `89.942464%`,
`86.141175%`, and `89.356746%`. Average CPU was `89.327607%` and maximum CPU
was `94.632169%`; neither reached the explicit 97% ceiling.

The serialized basket lane remained occupied by `QM5_20233` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T2. It was not interrupted or
mutated. QM5_20228 was not manually dispatched and remains queued for the
resident paced worker. The already-prioritized rank-46 QM5_20224 Q04 row was
also preserved.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. No strategy logic, Card, MQ5, EX5, setfile, basket
manifest, registry, magic row, queue identity, status, claim, attempt, or
verdict changed. Unrelated shared-worktree changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20228_q04_priority_20260830T145121Z_board_advisor.json`.

Let the resident serialized basket lane claim this exact row after earlier
priority rows and the active basket clear. Do not enqueue or dispatch a
duplicate. A terminal Q04 failure retires this exact sleeve rather than
authorizing parameter rescue.
