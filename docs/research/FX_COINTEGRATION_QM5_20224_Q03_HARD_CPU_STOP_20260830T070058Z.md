# QM5_20224 FX cointegration Q03 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T07:00:58Z`); 09:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `fd4bc06f9311763dfd7bf4818bacf3c857a82e90`

Status: stopped at the explicit backtest CPU ceiling before any queue,
terminal, worker, compile, smoke, or backtest mutation.

## Frontier decision

The controlling reputable-source result remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen 66-pair
criterion selected only `QM5_12532` AUDUSD/NZDUSD and `QM5_12533`
EURJPY/GBPJPY. Both are built and beyond Q02:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

The later logical-basket Q02 PASS evidence supersedes their historical
per-leg `ONINIT` and `NO_HISTORY` attempts. The committed sign-aware coverage
audit accounts for all 66 relationships, and the latest committed census
found no approved cointegration Card without a corresponding EA directory.
Creating another Card or build would therefore duplicate governed coverage or
weaken the reputable-source criterion.

## Selected existing forex fallback

Per the mission fallback, the exact existing successor remains frozen-scan
rank 46, `QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It is a structural,
low-frequency D1 basket over `EURUSD.DWX` and `EURJPY.DWX`, with
`USDJPY.DWX` used only for conversion history and fixed beta `-0.236324029`.
Its logical backtest setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; it has no ML, adaptive refit, banned indicator, grid,
martingale, or portfolio feedback.

The latest committed canonical receipt records Q02 PASS, exact Q03 work item
`3c74eb04-7e19-4aa0-8dcf-3f004faaa946` pending and already priority-bound,
and Q04 pending behind it. That receipt also records `QM5_20294` Q05 as the
healthy serialized predecessor. Once the capacity ceiling bound in this wake,
no fresh database query was used to revise those states and no duplicate row
was created.

## Binding capacity result

Five one-second whole-host CPU samples were `93.555346%`, `94.067382%`,
`94.827997%`, `87.697816%`, and `97.082907%`. Average CPU was `93.446290%`
and maximum CPU was `97.082907%`. The governed ceiling binds when either
measure reaches 97%; the maximum triggered the stop.

This is a material, non-duplicate change from the preceding receipt's
non-binding `77.549412%` average and `80.388154%` maximum.

## Bounded action and safety

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
priority, claim, status, verdict, reservation, worker, terminal, compile,
smoke, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live manifest,
AutoTrading, and live/deploy manifests were untouched. Existing unrelated
shared-worktree changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_hard_cpu_stop_20260830T070058Z_board_advisor.json`.

## Continuation

On the next paced wake, take another five-sample CPU window before any queue
or terminal action. Only if both average and maximum remain strictly below
97% and the serialized basket lane is free may the resident fleet claim the
existing exact `QM5_20224` Q03 row. Never enqueue a duplicate or prioritize
Q04 before Q03 PASS.
