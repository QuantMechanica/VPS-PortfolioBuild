# Diversity funnel triage — hard CPU-ceiling stop

Date: 2026-08-17 05:55 UTC
Branch: `agents/board-advisor`
Outcome: `STOPPED_AT_HARD_BACKTEST_CPU_CEILING`

## Mission result

The paced diversity slot stopped before claiming or mutating an EA because the
governed tester fleet was at the mission's hard CPU ceiling. No build task,
Q02 work item, smoke test, dispatcher tick, or terminal action was started.

This record preserves the exact backlog and infrastructure census so the next
slot does not repeat a broad scan or collide with another agent.

## Approved-build census

The canonical farm database
`D:/QM/strategy_farm/state/farm_state.sqlite` reported 29 nominally pending
`build_ea` tasks. The resolved task/artifact census found that almost all are
stale rework tickets for EAs that already have compiled binaries and pipeline
history.

The only two observed pending rows that were still skeleton-only were:

| EA | Diversity thesis | Deterministic blocker |
|---|---|---|
| `QM5_1457_as-predict-bonds` | rates / cross-asset | Card mechanics require Treasury yields, IEF, BIL, and DBC series that are not present as native `.DWX` inputs; the card body itself records R3 as `UNKNOWN`. |
| `QM5_1459_as-lumber-gold` | rates / cross-asset | Card mechanics require lumber futures and IEF series that are not present as native `.DWX` inputs; the card body itself records R3 as `UNKNOWN`. |

Neither was claimed or edited. Building either against unrelated broad proxy
slots would change the approved mechanic and would not be a valid V5 build.

The 2026-08-17 DL-087 allocation made 88 legacy-format EA identities resolver-
complete across 13 broad discovery symbols. Those cards remain explicitly
`DISCOVERY_NOT_CARD_VALIDATED`: their frontmatter has no non-empty
`target_symbols`, and the allocation receipt requires a card amendment before
downstream use. The standard `farmctl build-ea` preflight therefore remains
the correct fail-closed boundary; no manual task was manufactured.

## Stranded-infrastructure census

A read-only target sweep produced no eligible Q02/Q03 infrastructure rescue:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py
APPLY=False
part1 never_tested: enqueued=0 skipped=732
part2 stranded:     enqueued=0 skipped=432
part2 by phase: {}
priority_track items: 0
```

This is consistent with the current stranded-INFRA frontier guard: apparent
diverse rows are already superseded by terminal non-INFRA dispositions,
deeper-phase work, active work, or deterministic file/registry exclusions.
No work item was reset, appended, or reopened.

## Hard capacity gate

`farmctl mt5-slots` at `2026-08-17T05:55:44Z` found eight governed tester
terminals running: `T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T7`, and `T10`.
The separate `T_Live` and FTMO terminals were visible to the read-only process
scan but excluded from the governed tester count and were not touched.

Five consecutive `Win32_Processor.LoadPercentage` samples were:

| UTC | CPU |
|---|---:|
| `2026-08-17T05:55:45Z` | 99% |
| `2026-08-17T05:55:47Z` | 100% |
| `2026-08-17T05:55:49Z` | 99% |
| `2026-08-17T05:55:51Z` | 99% |
| `2026-08-17T05:55:53Z` | 97% |

The fleet therefore met the documented hard backtest CPU ceiling. Per the
mission contract, work stopped immediately after the read-only check.

## Handoff and safety boundary

When capacity is below the ceiling, the next paced slot should re-read the
farm DB and claim one distinct EA before editing. It should not infer native
rates/lumber data from DL-087 proxy allocations, and it should not enqueue a
historical INFRA row suppressed by the current frontier guard.

No farm claim or database mutation was made. No EA, registry, resolver,
Strategy Card, setfile, portfolio gate, deploy manifest, `T_Live` path, or
AutoTrading state was changed.
