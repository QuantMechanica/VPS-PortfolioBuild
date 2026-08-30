# QM5_20228 USDCAD/GBPJPY Q04 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T12:40:13Z`); 14:40 Europe/Berlin

Branch: `agents/board-advisor`

Status: the 97% whole-host CPU ceiling bound before any queue transaction,
priority mutation, dispatch, tester, or backtest. The exact existing fallback
and its continuation guard are now recorded without duplicating work.

## Frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only two relationships from the 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. Historical physical-leg failures do not supersede the later logical
Q02 PASS rows.

A fresh case-insensitive `cointegration|coint` census found 120 approved Card
files, 120 unique filename EA IDs, and a matching `framework/EAs` directory
for every one. No approved unbuilt relationship exists. Creating another Card
or EA would therefore duplicate governed coverage or weaken the source
criterion, so the strategy-card extraction and EA-build skill gates remained
closed.

## Exact existing fallback

The next unprioritized, dependency-complete relationship is frozen-scan rank
50, `QM5_20228_USDCAD_GBPJPY_COINTEGRATION_D1`. Rank 46 `QM5_20224` remains
pending once at Q04 and retains its earlier priority handoff. Ranks 47 and 48
are terminal at Q02 and Q04 respectively; rank 49 reached Q08 `FAIL_HARD`.
QM5_20228 is therefore the next existing successor that can be advanced
without duplicating or overwriting the rank-46 row.

QM5_20228 trades `USDCAD.DWX` and `GBPJPY.DWX` on D1 with frozen beta
`-0.231842927`; `USDJPY.DWX` supplies conversion history only. The source
evidence is adverse: DEV net Sharpe `0.011529`, OOS net Sharpe `-0.194853`,
OOS return `-1.353675%`, 15 OOS state changes, and a `65.507`-bar half-life.
This is a one-shot pipeline falsification, not permission to refit or rescue a
failed economic gate.

The Card lint passed with no missing sections or ML-ban hits. The logical D1
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The package is structural fixed-beta cointegration
logic with no learned model, adaptive refit, banned indicator, grid,
martingale, or portfolio feedback.

Canonical lineage:

| Phase | Work item | State |
|---|---|---|
| Q02 | `41722d88-1113-4e08-ac39-832b4708ee2d` | done / PASS |
| Q03 | `1a395c0b-73ea-4bb3-9160-6fb55c4d6777` | done / PASS |
| Q04 | `eb453b94-6031-4c40-b761-4f8005871751` | pending, unclaimed, attempt 0, unprioritized |

Q03 ran twice over 2018-07-02 through 2022-12-31. Both runs returned 146
trades, PF `0.81`, net profit `-3673.97`, and drawdown `5069.51` (`5.04%`),
with no OnInit failure. That proves reproducible execution, not economic
fitness; Q04 remains the economic judge.

## Binding capacity result

The five one-second whole-host CPU samples were `99.804906%`, `97.568606%`,
`99.707060%`, `98.925895%`, and `96.292747%`. Average CPU was `98.459843%`
and maximum CPU was `99.804906%`. Both exceeded the explicit 97% ceiling, so
the operation stopped while holding only the global mutation boundary and
before opening a database transaction.

The earlier fleet snapshot had an active multisymbol Q03 run for `QM5_20233`
on T2. It was not interrupted or controlled. No concurrent basket was
launched.

Post-stop verification found the mutation lock absent, no journal file, no
priority event for the target, and the exact Q04 payload still at SHA-256
`41251ed85448a7fd864492ecac44a2c6bacdb66b3d476f3fb88e42aa8451273d`
with no `priority_track` field. No work-item row, status, claim, attempt,
verdict, or `updated_at` changed.

## Safety and continuation

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. No Card, EA, EX5, setfile, basket manifest, registry,
magic row, queue row, tester, or terminal was created or changed. Unrelated
shared-worktree changes were preserved.

On a later paced wake, take a fresh five-sample CPU window. Only if both its
average and maximum are strictly below 97%, re-read rank-46 QM5_20224 and exact
target `eb453b94-6031-4c40-b761-4f8005871751`. If the target is still pending,
unclaimed, attempt zero, unprioritized, guard-clean, and Q03-complete, bind its
existing Q04 row in place. Do not enqueue or dispatch a duplicate.

Machine-readable evidence is in
`artifacts/qm5_20228_q04_hard_cpu_stop_20260830T124013Z_board_advisor.json`.
