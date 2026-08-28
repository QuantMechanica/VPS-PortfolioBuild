# Diversity funnel — hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T02:31:26.5212643Z`); 2026-08-28
04:31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `3d161902ed319a874ef89ce12ea32fa381e3fc4d`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, EA selection, build, repair, mechanization, or Q02 enqueue.

## Binding capacity result

Five one-second whole-host CPU samples were `95.217723%`, `91.432948%`,
`98.731876%`, `99.804908%`, and `87.406507%`. Average CPU was
`94.518792%` and maximum CPU was `99.804908%`. The governed tester-admission
ceiling in `tools/strategy_farm/terminal_worker.py` binds when either measure
reaches `97%`; the maximum triggered the mission's stop condition.

The supported post-window process snapshot found six factory testers running
on `T1`, `T2`, `T4`, `T6`, `T8`, and `T10`, with six matching reservations,
ten visible worker daemons, no duplicate worker, and no orphaned factory
terminal. The visible runs comprised one `Q03`, one `Q09`, and four
`Q10_NEWS` items. `T_Live` and an unrelated FTMO terminal were observed only
to exclude them; neither was controlled.

## Farm coordination state

The read-only farm census contained ten active rows: two `OPT_CENSUS`, one
`Q03`, three `Q09`, and four `Q10_NEWS`. Every row was already claimed by a
distinct `T1`-`T10` slot. Four claimed rows were not represented by a tester
process in the point-in-time process scan; that observation does not establish
staleness and did not authorize reclaim or mutation.

No approved Card was ranked or claimed because the CPU ceiling bound first.
This avoids colliding with the paced fleet and prevents compile/smoke admission
from adding load to a saturated host.

## Non-duplicate delta

The preceding receipt at `2026-08-28T02:17:06Z` already showed the same six
factory terminals. Since then, `T4` rotated from work item
`7a686cb4-2834-49da-8731-92b738d152d0` to distinct Q09 item
`6a30d4f4-2d20-433b-90ac-a518047e5ad1`. This receipt adds the complete
ten-row active DB census, including two claimed FX `OPT_CENSUS` rows not
visible as tester processes, and an independent fresh peak of `99.804908%`.

## Scope and safety boundary

No Card or G0 record, EA source or binary, setfile, basket manifest, registry,
magic row, resolver, build result, queue row, claim, priority, status, verdict,
or pipeline evidence was mutated. No compile, build check, smoke, backtest,
dispatch tick, terminal control, or worker control was started. The portfolio
gate, portfolio-admission surfaces, `T_Live`, AutoTrading, and live/deploy
manifests were untouched. Existing unrelated shared-worktree changes were
preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_hard_cpu_stop_20260828T023126Z_board_advisor.json`.

## Continuation condition

On a later paced wake, proceed only after a fresh five-sample capacity window
has both average and maximum strictly below `97%`. Then use the farm DB to
claim exactly one distinct diversity-first unit, prefer an approved forex,
crypto-if-available, non-XNG energy, rates, or market-neutral Card, follow the
standard V5 build path with `RISK_FIXED` backtest setfiles, and enqueue Q02
without dispatching or touching portfolio/live surfaces.
