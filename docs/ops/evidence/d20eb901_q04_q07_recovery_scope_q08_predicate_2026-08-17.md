# Q04/Q07 hourly recovery scope and Q08 exclusion trace

Date: 2026-08-17

Router task: `d20eb901-d3e3-4b7f-88e1-522114112df6`

Branch: `agents/board-advisor`

Verdict: `IMPLEMENTED_AND_PROVEN_ONE_PAIR; REVIEW_REQUIRED; NO_PIPELINE_VERDICT`

## Outcome

The hourly stranded-INFRA operator now covers Q04 and Q07 in addition to its
existing Q02, Q03, and Q08 scope. Existing retry and per-run caps are unchanged:

- `MAX_INFRA_ATTEMPTS = 12`
- `MAX_PART2_PER_RUN = 250`
- existing pending/active, terminal non-INFRA, deeper-phase, registry, symbol,
  setfile, archive-admission, Q02 exclusion, and Q08 deterministic-setfile
  guards remain in force

No Q04/Q07 cohort was bulk-enqueued. One Q07 pair was used as the production
proof and was claimed by an existing terminal worker. No terminal was started or
interrupted manually, and no pipeline verdict is inferred from an active row.

## Q08 paradox: named excluding predicate

Trace target: `QM5_10771 / GDAXI.DWX / Q08`.

| Evidence | Observation |
|---|---|
| Latest source row | `ebc4839c-0d95-4fb9-9881-f4b89401ca5d` |
| Terminal label | `INFRA_FAIL`; `q08_8.5_neighborhood:...baseline_setfile_defect:empty_strategy_params` |
| Counted INFRA rows for exact EA/symbol/setfile group | `1` |
| Retry cap | `12`; therefore the cap does not exclude this pair |
| Pending/active Q08 rows at trace time | `0` |
| Terminal non-INFRA Q08 rows at trace time | `0` |
| Targeted hourly-sweep dry run | `reason=deterministic_setgen_defect`, `defect=empty_strategy_params` |

The rejecting predicate is the Q08-only call to
`_q08_setfile_deterministic_defect()` in
`tools/strategy_farm/sweep_enqueue_built_eas.py`. It executes after the common
cap check and refuses a retry when the Q08.5 parser finds no strategy parameters.
This is a deterministic set-generation defect, so adding scope or raising the
cap would not make this case converge. The fail-closed predicate was preserved.

Reproduction:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py `
  --ea QM5_10771 --symbols GDAXI.DWX --max-part2-per-run 1
```

Observed Part 2 record:

```text
ea_id=QM5_10771 phase=Q08 symbol=GDAXI.DWX
reason=deterministic_setgen_defect defect=empty_strategy_params
```

## Scope closure

`STRANDED_INFRA_PHASES` is now:

```text
Q02, Q03, Q04, Q07, Q08
```

Q04 is included because PF/summary rows can be reclassified to fail-closed
`INFRA_FAIL`; Q07 is included because invalid or zero-seed evidence can be
reclassified likewise. Q05/Q06 were not added: they remain under the separately
governed deep-phase recovery tool, keeping this change limited to the diagnosed
gap.

The Windows trigger was verified read-only:

| Field | Value |
|---|---|
| Task | `QM_StrategyFarm_SweepEnqueue_Hourly` |
| State | `Ready` |
| Action | `C:\QM\repo\tools\strategy_farm\sweep_enqueue_built_eas.py --apply --queue-ceiling 7000` |
| Last run observed | 2026-08-17 16:52:52 CEST, result `0` |
| Next run observed | 2026-08-17 17:52:52 CEST |

Pre-change-scope read-only census evidence showed:

- Q07: 50 stranded groups, 35 eligible, 15 refused.
- Q04: 1,732 stranded groups, 1,465 eligible, 267 refused.

These figures are evidence of the reachable population, not authorization for a
bulk requeue.

## One-pair operator proof

Proof target: `QM5_1116 / EURJPY.DWX / Q07`.

The exact source group had one Q07 INFRA row, below the unchanged cap of 12:

- source row: `b37c01d6-3762-4f7d-9463-0272d444c007`
- reason: `seed_zero_trades_outlier:seeds=[99]:median=607:floor=20`
- setfile: `QM5_1116_hopwood-asctrend-h1-tf_EURJPY.DWX_H1_backtest.set`
- backtest risk inputs verified: `RISK_FIXED=1000`, `RISK_PERCENT=0`

The targeted dry run selected exactly one Q07 row. The targeted apply then
created replacement row `499be1dd-1794-4656-bb18-9bac6e8deaa7` at
`2026-08-17T15:12:05+00:00`, carrying an auditable `requeue_source` binding to
the source row. The existing worker fleet claimed it independently:

```text
id=499be1dd-1794-4656-bb18-9bac6e8deaa7
status=active
claimed_by=T7
claimed_at_iso=2026-08-17T15:15:19+00:00
attempt_count=0
verdict=NULL
```

Apply command (one EA, one symbol, one-row ceiling):

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply `
  --ea QM5_1116 --symbols EURJPY.DWX --max-part2-per-run 1
```

## Per-class operator table

| Class | Operator | Scheduled | Proof | Bounding cap |
|---|---|---:|---|---|
| Q04 stranded `INFRA_FAIL` | hourly `sweep_enqueue_built_eas.py` Part 2 | yes | isolated test fixture `QM5_9007/Q04` produced one pending replacement; production cohort only dry-run-counted | 12 exact-group INFRA rows; 250 Part-2 rows/run; common exclusions preserved |
| Q07 stranded `INFRA_FAIL` | hourly `sweep_enqueue_built_eas.py` Part 2 | yes | production `QM5_1116/EURJPY.DWX`, replacement `499be1dd...`, claimed by `T7` | 12 exact-group INFRA rows; 250 Part-2 rows/run; common exclusions preserved |
| Q08 stranded `INFRA_FAIL` | existing hourly Part 2 | yes | `QM5_10771/GDAXI.DWX` traced to `deterministic_setgen_defect`, not cap | 12 exact-group INFRA rows plus the unchanged Q08 deterministic-setfile guard |

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py -q
.......                                                                  [100%]
7 passed in 3.65s
```

The added test proves both newly swept phases enqueue under the normal
conditions and that a 12-row Q07 group is still refused with
`infra_retry_cap_reached`. It uses compliant backtest inputs
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

No news staleness setting, live-trading switch, EA logic, phase verdict, or
terminal process was changed.
