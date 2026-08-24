# QM5_1229 EURCHF Q02 recovery stopped at CPU ceiling — 2026-08-24

## Outcome

Prepared one exact, non-duplicate infrastructure recovery for
`QM5_1229_carver-statevol` on `EURCHF.DWX` / `D1`, then stopped before enqueue
when the backtest CPU ceiling was reached.

- Farm coordination task: `53350596-7144-4bb2-9611-0e2371dfd9bc`
- Preserved Q02 predecessor: `8870ee05-fbc6-4bc2-a721-b3cba2a334c5`
- New Q02 work item: **none**
- Task result: `DIAGNOSED_READY_DEFERRED_CPU_CEILING`
- Branch: `agents/board-advisor`

No tester was launched and no queue row was inserted by this work unit.

## Why this target

The priority-1 diverse build backlog had no eligible, non-colliding approved
card: current diverse build rows were already in flight, while the remaining
nominal rows were already built, stale, retired, or otherwise ineligible.

This priority-2 recovery is a low-frequency structural FX-cross candidate:

- approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1229_carver-statevol.md`
- `g0_status: APPROVED`; R1-R4 all `PASS`
- reputable named source: Rob Carver,
  [The State Of Vol](https://qoppac.blogspot.com/2023/10/the-state-of-vol.html)
- rule: D1 return-volatility percentile versus a fixed long baseline, fixed
  smoothing and signed entry/exit thresholds, with a fixed ATR catastrophe stop
- expected frequency: approved-card estimate 10 trades/year/symbol; historical
  queue estimate 3
- no ML, grid, martingale, PnL adaptation, or external market data

`EURCHF.DWX` is an underrepresented FX cross and has no economic Q02 verdict for
this EA. Before claiming, the farm had no pending/active work item, no open
repair task, and no append-only successor for this exact predecessor.

## Infrastructure diagnosis

The immutable predecessor evidence is:

`D:\QM\reports\work_items\8870ee05-fbc6-4bc2-a721-b3cba2a334c5\QM5_1229\20260728_142608\summary.json`

It records the correct expert, `EURCHF.DWX`, `D1`, and the 2018-07-02 through
2022-12-31 window. All three attempts produced invalid empty-history reports
with `BARS_ZERO`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`, and `M0_1970_PERIOD` markers.
`oninit_failure_detected=false`; source/deployed EX5 and setfile identities were
stable. This was infrastructure, not a zero-trade strategy verdict.

The failed row was bound to EX5
`2ac03868ed7b6c93565f1031a778f32509dc00cc4d884d65ac3b3203026e45dd`.
The governed strict rebuild documented in
`docs/ops/evidence/2026-08-12_qm5_1229_eurgbp_q02_post_migration_retry.md`
left the MQ5 unchanged and produced the current EX5:

| Artifact | Current SHA-256 |
|---|---|
| MQ5 | `98c621bdcf2e22ced88e2da30387789ba7219b42e83b37963ce1b0521689080f` |
| EX5 | `a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1` |
| EURCHF setfile | `a78381adf6e6b4653c196e50140bd68af0e8d91cd33d4a895f5809e809f49eaa` |

The setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1, slot 10. The
history registry covers `EURCHF.DWX,D1,2017,2025` on `T1` through `T10`.

## Hard stop

At `2026-08-24T00:56:58Z`, `farmctl mt5-slots` reported six active factory
terminals: `T1`, `T2`, `T3`, `T4`, `T5`, and `T10`. Five one-second total-CPU
samples were:

`100.00%, 99.72%, 99.90%, 100.00%, 100.00%`

That exceeded the 97% backtest CPU ceiling, so the supported append-only enqueue
was not called. A static `build_check -SkipCompile` attempt also stopped at
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; there was no bypass or retry. The prior
governed strict compile evidence remains the current artifact authority.

When capacity is below the ceiling, the exact supported handoff is:

```powershell
py -3 tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_1229 --phase Q02 `
  --from-work-item-id 8870ee05-fbc6-4bc2-a721-b3cba2a334c5 `
  --append-only-rerun-of 8870ee05-fbc6-4bc2-a721-b3cba2a334c5 `
  --rerun-reason "Post-migration EURCHF D1 infrastructure recovery; preserve three BARS_ZERO attempts and bind the governed current-framework EX5; no strategy mechanics changed." `
  --expected-current-ex5-sha256 a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1
```

The future operator must reclaim the EA and repeat the exact duplicate and
capacity checks before running that command.

## Safety

- No `T_Live` file, process, or manifest was touched.
- AutoTrading was not toggled.
- The portfolio gate was not touched.
- No EA logic, parameter, setfile, registry, or framework file was changed.
- No backtest or pipeline phase was launched directly.
- An incomplete temporary DB snapshot created while attempting the initial
  coordination claim was removed after exact path and process validation; the
  canonical farm DB was not replaced or deleted.
