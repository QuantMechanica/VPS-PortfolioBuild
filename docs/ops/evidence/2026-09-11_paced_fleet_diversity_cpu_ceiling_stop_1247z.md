# Paced-fleet diversity admission stop — 2026-09-11 12:47Z

## Outcome

The paced-fleet unit stopped at the binding backtest CPU admission gate before
claiming or mutating farm work. Five one-second processor samples were
`93.46%, 99.12%, 99.12%, 99.12%, 99.51%`: average `98.07%`, maximum `99.51%`.
The maximum exceeded the `97.0%` ceiling. The same snapshot saw seven
`terminal64` and four `metatester64` processes.

No build task or infrastructure-repair task was claimed. No EA source, binary,
setfile, registry, resolver, farm work item, pipeline verdict, portfolio gate,
T_Live manifest, or AutoTrading state was changed. No compile or Q02 work was
enqueued.

## Diversity-first selection audit

The live farm database was read at
`D:/QM/strategy_farm/state/farm_state.sqlite` on branch
`agents/board-advisor` at commit
`cb188782eebb5a4d6d3c4abcfd40cc0d2d3f358d`.

Priority 1 had no collision-free, genuinely unbuilt structural candidate:

- `QM5_12351_alp-ema12-26` already had pending `COMPILE_EA` work item
  `92797bae-0f0d-45cb-872d-6f0bcccb258d`; it is also an EMA/MACD strategy, not
  the requested structural edge.
- `QM5_41168_xauxag-mcoxstuart-rv` already had pending repair compile work item
  `4f1d3565-a525-4fc0-b01b-0e767095228a`, and its build-task payload records a
  prior duplicate-session race.
- Every other claimable pending build-task identity inspected already had an
  `.ex5` or Q02+ evidence, so rebuilding it as fresh backlog work would be a
  duplicate.
- The apparent rates candidate `QM5_1457_as-predict-bonds` is not claimable:
  its approved-card frontmatter has `r3_data_available: FAIL`, and its task
  retains the active block `non_dwx_rates_inputs_required_by_card`.

The next collision-free Priority 2 candidate was
`QM5_1049_mcconnell-turn-of-month` on `AUDJPY.DWX` D1. The 2026-09-11 stranded
infrastructure census classifies work item
`4fb360a1-dcef-4ba2-95ab-4c0ae0d237ce` as
`run_smoke_oninit_failed`. A live DB recheck found zero active
`infra_repair` claims for `QM5_1049`. The current artifacts exist and were
observed without modification:

- MQ5 SHA-256:
  `44c039d762335facf9c0ea898becab5b009dbaf4691919b5ad196a85960abde7`
- EX5 SHA-256:
  `f4d249d014151131b9c18eec848adf32272885305cce985d5853549f0d5f04a6`

## Resume point

After CPU falls below the admission ceiling, recheck the farm DB for an active
`QM5_1049` claim. If still unclaimed, diagnose the exact AUDJPY OnInit evidence,
claim one infrastructure-repair task atomically, run the framework-input pin
audit on any written MQ5 before compile enqueue, then use the governed
current-identity repair/requalification path. Do not reuse this selection if a
different agent has claimed it.
