# QM5_1229 EURGBP Q02 post-migration retry — 2026-08-12

## Result

One exact, append-only Q02 successor was enqueued for `QM5_1229_carver-statevol` on `EURGBP.DWX` / `D1` after a current-framework strict rebuild.

- New work item: `a04aa3ef-1805-44f9-a8c2-846a4bcebb08`
- Source work item: `ae5709c6-0cae-4730-95f7-986ada44a1c2`
- Readback state: `pending`, unclaimed, attempt count `0`
- Open exact Q02 rows after enqueue: `1`
- Farm coordination task: `51502600-711a-44db-9c35-7d31406b33a5`
- Branch: `agents/board-advisor`
- Repository head before this evidence commit: `c5cd73d972fa2aa3a74b22ac42410b9d56b8fa0a`

The normal paced fleet owns dispatch. No tester was launched by this work unit.

## Why this unit

The priority-1 backlog audit found no unbuilt candidate that simultaneously satisfied the requested diversity/structural profile and the build skill's deterministic preflight. Diverse approved cards were already built or lacked required magic allocation; the remaining preallocated unbuilt candidates were high-frequency or indicator-led. No registry allocation was invented.

Priority 2 therefore applied. This exact FX-cross row had no Q02 PASS, no downstream row, no open retry, and no competing farm claim. The durable graveyard classification at `docs/ops/evidence/2026-08-07_q02_graveyard_classification.md:192` routes it as:

`REQUEUE_POST_MIGRATION / PURE_INFRA_NO_HISTORY_TRANSIENT`

The strategy does have an AUDCAD economic result downstream (Q02 PASS followed by Q04 FAIL). That result was not treated as evidence for EURGBP, nor was this retry represented as a new strategy build. This unit recovers one still-untested diverse instrument from an attributable Q02 infrastructure failure.

## Governed identity and constraints

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1229_carver-statevol.md`
- Card status: `g0_status: APPROVED`
- Reputable named source: Rob Carver, [The State Of Vol](https://qoppac.blogspot.com/2023/10/the-state-of-vol.html)
- Structural rule: price-return volatility percentile using a 25-day volatility window against a long baseline, 10-day smoothing, signed threshold entries, and ATR stop
- Frequency: `D1`; approved-card expectation `10` trades/year/symbol (historical queue expectation `3`)
- EA registry: `1229, carver-statevol, active`
- Magic registry: slot `11`, `EURGBP.DWX`, magic `12290011`, active
- Set risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, backtest environment
- No ML, martingale, grid, or external market-data dependency was added

## Predecessor diagnosis

The preserved row ended `failed / INFRA_FAIL` after three cold-cache attempts. Its bound summary is:

`D:\QM\reports\work_items\ae5709c6-0cae-4730-95f7-986ada44a1c2\QM5_1229\20260728_153519\summary.json`

That summary records:

- exact expert `QM\QM5_1229_carver-statevol`, symbol `EURGBP.DWX`, period `D1`
- test window `2018.07.02` through `2022.12.31`
- attempt failures `BARS_ZERO`, `NO_HISTORY`, `BARS_ZERO`
- invalid empty-report markers including `EMPTY_EXPERT`, `EMPTY_SYMBOL`, and `M0_1970_PERIOD`
- `oninit_failure_detected=false`
- `log_bomb_detected=false`
- source/deployed EX5 and setfile identities stable during the run

This is not a zero-trade strategy-mechanics recovery: none of the three reports was a valid economic run.

## Current-framework artifact refresh

Command:

```powershell
framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1229_carver-statevol/QM5_1229_carver-statevol.mq5 -EALabel QM5_1229_carver-statevol -Strict
```

Result: `PASS`, `0 errors`, `0 warnings`.

- Compile log: `C:\QM\repo\framework\build\compile\20260812_195038\QM5_1229_carver-statevol.compile.log`
- Compile summary: `D:\QM\reports\compile\20260812_195038\summary.csv`

Artifact bindings:

| Artifact | Before | After |
|---|---|---|
| MQ5 | `98c621bdcf2e22ced88e2da30387789ba7219b42e83b37963ce1b0521689080f` | unchanged |
| EX5 | `2ac03868ed7b6c93565f1031a778f32509dc00cc4d884d65ac3b3203026e45dd` | `a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1` |
| Setfile | `8a8e416f81bebc9ce9669d8e5addc068311004a7f35ccb0aec2430f7a6516a04` | unchanged |

The source and setfile were not edited. The binary refresh binds the unchanged approved mechanics to the current V5 include/build contract.

## Capacity gate and enqueue

Immediately before enqueue, `farmctl mt5-slots` sampled at `2026-08-12T19:51:29+00:00`:

- running factory terminals: `T1`, `T4`, `T5`, `T6`, `T9`, `T10`
- factory load: `6 / 7`, below the CPU ceiling
- the reported total of eight terminal processes also included `T_Live` and an external FTMO terminal; neither was controlled or counted as farm capacity
- no duplicate worker or orphaned work-item process was reported

The supported `enqueue-backtest --append-only-rerun-of` path created exactly one row and bound the refreshed EX5 SHA-256. Its payload also preserves the original evidence path and hashes, records `repaired_infra_rerun=true`, and carries `RISK_FIXED=1000.0` / `RISK_PERCENT=0.0`.

Readback confirmed:

- predecessor remains `failed / INFRA_FAIL`, attempt count `3`
- successor is `pending`, attempt count `0`, with no verdict
- `append_only_rerun_of_work_item=ae5709c6-0cae-4730-95f7-986ada44a1c2`
- exact source, set, and refreshed binary hashes match the enqueue payload

## Safety and scope

- No `T_Live` file or process was touched.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No pipeline phase was executed directly; only one Q02 row was enqueued for fleet dispatch.
- No strategy logic, parameter, source, setfile, registry, or framework include was changed.
- The unrelated untracked Brent/WTI review evidence was preserved and excluded from this commit.
