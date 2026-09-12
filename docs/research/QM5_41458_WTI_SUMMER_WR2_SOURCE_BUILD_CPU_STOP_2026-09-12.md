# QM5_41458 WTI Summer WR2 Source/Build — CPU Stop

Date: 2026-09-12  
Branch: `agents/board-advisor`  
EA: `QM5_41458_wti-summer-wr2-upweek-fade`

## Outcome

The OWNER-authorized commodity/energy sleeve mission produced a new approved, allocated, and
committed low-frequency WTI card and source build. No compile or Q02 work was enqueued because
the whole-host CPU ceiling was reached at the mandatory admission check.

## Strategy

At the first tradable D1 bar of each June-October normalized week, inspect the two immediately
completed weeks. Require the newest weekly range to be strictly wider than its predecessor and
its body to be strictly positive, then sell WTI for one normalized week with a frozen
`3.5*ATR(20,D1)` hard stop. This WR2 expansion state is mutually exclusive with closest sibling
`QM5_41457`'s strict contraction state and is distinct from unconditional and two-sign summer
WTI cards.

The pre-allocation dedup scan found no exact identity, reported six fuzzy family matches, and
could not inspect the unavailable external Strategy Wiki. The source/card records preserve that
limitation and the manual family resolution.

## Completed Evidence

- Research/card approval and EA-ID reservation: commit `1e42e48efc`.
- Governed magic allocation and resolver update: commit `9ad4eec3f9`.
- EA, fixed-risk set, reference model, and label-clock evidence lock: commit `6e6456c593`.
- Card schema/ML lint: PASS.
- Deterministic reference tests: `10 passed`.
- Build prerequisite guard: PASS for registry row, magic row, and EA directory.
- PACER command run after the final MQ5 edit and before any compile enqueue:
  `python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41458_wti-summer-wr2-upweek-fade/QM5_41458_wti-summer-wr2-upweek-fade.mq5"`.
- PACER result: `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.

The locked guard compares only `strategy_*`, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed-risk mode. It does not equality-pin RNG, news, Friday-close,
or stress defaults; stress rejection is checked only for finiteness and inclusive `0..1`.

## CPU Ceiling

Whole-host `psutil.cpu_percent(interval=0.5)` samples:

`[94.9, 99.4, 96.9, 98.2, 94.6]`

- average: `96.8%`
- maximum: `99.4%`
- ceiling: `97.0%`
- admission: `REFUSED_CPU_CEILING`

## Handoff

After CPU falls below the governed ceiling, rerun the PACER audit against the unchanged committed
MQ5, recheck whole-host CPU, enqueue exactly one governed `COMPILE_EA`, require strict compile
and build-check PASS with a current EX5, then dry-run and apply exactly one
`intake-first-q02`. If the MQ5 changes, the PACER audit must be rerun after that edit. Do not
run a manual backtest or touch portfolio/live gates.
