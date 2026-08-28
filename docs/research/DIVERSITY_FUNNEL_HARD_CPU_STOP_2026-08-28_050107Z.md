# Diversity funnel — contracted-roster hard CPU stop

Date: 2026-08-28 UTC (`2026-08-28T05:01:07.8907718Z`); 2026-08-28
07:01 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `2539a8e83d4492ccc3084adb4d14605e33682c80`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, EA selection, build, repair, mechanization, or Q02 enqueue.

## Binding capacity result

Five one-second whole-host CPU samples were `98.731236%`, `91.326900%`,
`93.750649%`, `94.629525%`, and `97.265913%`. Average CPU was
`95.140845%` and maximum CPU was `98.731236%`. The governed tester-admission
ceiling in `tools/strategy_farm/terminal_worker.py` binds when either measure
reaches `97%`; the maximum triggered the mission's stop condition.

The supported post-window process snapshot found two factory testers running
on `T6` and `T10`, three active reservations on `T4`, `T6`, and `T10`, ten
visible worker daemons, no duplicate worker, and no orphaned factory terminal.
The visible runs comprised one `Q03` and one `Q10_NEWS` item. `T_Live` and an
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

## Farm coordination state

The read-only farm census contained nine active rows: two `OPT_CENSUS`, one
`Q03`, three `Q09`, and three `Q10_NEWS`. Every row was already claimed by a
distinct `T2`-`T10` slot. Seven claimed rows were not represented by a tester
process in this point-in-time scan; that observation does not establish
staleness and did not authorize reclaim or mutation.

No approved Card was ranked or claimed because the CPU ceiling bound first.
This avoids colliding with the paced fleet and prevents compile/smoke admission
from adding work while the host lacks governed CPU headroom.

## Non-duplicate delta

The preceding diversity receipt at `2026-08-28T02:31:57Z` recorded ten active
rows, including four `Q10_NEWS`, and six visible factory testers on `T1`, `T2`,
`T4`, `T6`, `T8`, and `T10`. The current census has nine active rows and three
`Q10_NEWS`; the visible tester roster has contracted to `T6` and `T10`.

The immediately preceding capacity receipt at `2026-08-28T04:31:05Z` recorded
four reservations; the current snapshot has three. Despite that contraction,
the fresh maximum reached `98.731236%` and independently kept the maximum-side
ceiling binding. No absent process was treated as proof that a claimed row was
stale.

## Scope and safety boundary

No Card or G0 record, EA source or binary, setfile, basket manifest, registry,
magic row, resolver, build result, queue row, claim, priority, status, verdict,
or pipeline evidence was mutated. No compile, build check, smoke, backtest,
dispatch tick, terminal control, or worker control was started. The portfolio
gate, portfolio-admission surfaces, `T_Live`, AutoTrading, and live/deploy
manifests were untouched. Existing unrelated shared-worktree changes were
preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_hard_cpu_stop_20260828T050107Z_board_advisor.json`.

## Continuation condition

On a later paced wake, proceed only after a fresh five-sample capacity window
has both average and maximum strictly below `97%`. Then use the farm DB to
claim exactly one distinct diversity-first unit, prefer an approved forex,
crypto-if-available, non-XNG energy, rates, or market-neutral Card, follow the
standard V5 build path with `RISK_FIXED` backtest setfiles, and enqueue Q02
without dispatching or touching portfolio/live surfaces.
