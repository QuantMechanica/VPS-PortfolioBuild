# QM5_20224 FX cointegration Q04 priority handoff

Date: 2026-08-30 UTC (`2026-08-30T11:37:40Z`); 13:37 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `719ba582b49e6081cc06fbd33032f97af87b969f`

Status: the unique existing rank-46 FX fallback completed Q03 with a
deterministic PASS, and its already-existing Q04 row was priority-bound in
place. No Card, EA, queue row, phase, verdict, claim, tester, or terminal was
created.

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

The dependency-correct fallback is the structural, fixed-beta D1 basket
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX`; `USDJPY.DWX` supplies conversion history only. The setfile keeps
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The exact lineage is now:

| Phase | Work item | State |
|---|---|---|
| Q02 | `5d1cb89c-25ce-419c-869c-8c9f7afa10c1` | done / PASS |
| Q03 | `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` | done / PASS |
| Q04 | `a525cd8f-4c29-4752-b1af-3c43288f259e` | pending, priority-bound |

Q03 ran twice over 2018-07-02 through 2022-12-31. Both runs returned 116
trades, PF `1.26`, net profit `2967.29`, drawdown `2920.99` (`2.83%`), and no
OnInit failure. The result was deterministic and its reason class was `OK`.

The Card's adverse evidence remains explicit: DEV net Sharpe `0.473267`, OOS
net Sharpe `-0.118543`, OOS return `-1.026394%`, 17 OOS state changes, and a
`137.788`-D1-bar half-life. This is a one-shot falsification through the
pipeline, not permission to refit, add a filter, or rescue a failed economic
gate.

## Guarded in-place mutation

The exact-ID payload CAS changed only the Q04 priority fields and bounded
handoff provenance. The row remained pending, unclaimed, attempt zero, and
unverdict; its original `updated_at` was preserved.

| Measure | Before | After |
|---|---:|---:|
| Pending rows | 7,936 | 7,936 |
| Canonical queue rank | 5,763 | 1,707 |
| Matching open Q04 rows | 1 | 1 |

There were no active holds, poison-pill quarantine rows, or canonical
supersession links. Audit event `380754` records the mutation. The reversible
external journal is
`D:/QM/reports/state/qm5_20224_q04_priority_20260830T113740Z.journal.json`
(SHA-256
`2e198b8885e9e08f89f29af7eb09da0594b73fa84df0a9ac73b3bb58a0e3fea5`,
state `COMMITTED`). The global factory mutation lock released normally.

## Capacity and pacing

Five apply-time CPU samples were `68.558105%`, `82.860665%`, `85.938937%`,
`84.692555%`, and `79.787238%`. Average CPU was `80.367500%` and maximum CPU
was `85.938937%`; neither reached the explicit 97% ceiling.

The serialized basket lane was already occupied by `QM5_20233` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T2. It was not interrupted or
mutated. QM5_20224 was not manually dispatched and remains queued for the
resident paced worker after the active basket reaches a canonical terminal
state.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. No strategy logic, Card, MQ5, EX5, setfile, basket
manifest, registry, magic row, queue identity, status, claim, attempt, or
verdict changed. Unrelated shared-worktree changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20224_q04_priority_20260830T113740Z_board_advisor.json`.

On the next paced wake, reconcile this exact Q04 row and the serialized basket
lane. Do not enqueue a duplicate or launch a concurrent basket. A terminal Q04
failure retires this exact sleeve rather than authorizing parameter rescue.
