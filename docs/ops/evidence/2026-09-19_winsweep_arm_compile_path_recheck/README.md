# Winsweep-arm compile-path recheck — task be23fb25

Verdict: **PARTIAL / OWNER-BLOCKED**. This is the recycled original of work
already rerouted to Claude task `11eff123-53b9-4153-ad40-c1e44b76ac4e` and
accepted as a diagnosis. The original path determination remains correct, but
the live disposition changed: four of the eleven arms now have source-current
`COMPILE_OK` rows from separately authorized work. Seven arms still have no
approved card or open build task, so this ticket has no eligible append-only
compile action.

Machine plan: `plan.json`  
Plan file SHA-256:
`6bf0f9fafc883d4ddd5392bbe87c63caf667c185a0a44df08addaa7616c6827b`  
Governed seven-arm repair-successor dry-run plan SHA-256:
`8fae8c9c93d31c58e21af5c966f9409154476a81a4d9f31411c83885be2b8684`

## Current disposition

| Arm | Current-source compile | Disposition |
|---|---|---|
| QM5_41113 | none | OWNER card decision required; `FLAG_NEEDS_FRESH_BUILD_EA` |
| QM5_41123 | none | OWNER card decision required; `FLAG_NEEDS_FRESH_BUILD_EA` |
| QM5_41135 | `1e509ca3-c912-4670-8ba9-ea40602f142d` / `COMPILE_OK` | resolved outside this ticket on 2026-09-17 |
| QM5_41138 | `3af0b6a2-8bbd-482c-b815-9c62b33d3485` / `COMPILE_OK` | resolved outside this ticket on 2026-09-17 |
| QM5_41157 | none | OWNER card decision required; `FLAG_NEEDS_FRESH_BUILD_EA` |
| QM5_41160 | none | OWNER card decision required; `FLAG_NEEDS_FRESH_BUILD_EA` |
| QM5_41179 | `263c348b-24a9-4562-9d9c-0f79ce4f6483` / `COMPILE_OK` | resolved by task `5a98a339...` |
| QM5_41181 | none | OWNER card decision required; `FLAG_NEEDS_FRESH_BUILD_EA` |
| QM5_41187 | none | OWNER card decision required; `FLAG_NEEDS_OPEN_BUILD_TASK` |
| QM5_41188 | none | OWNER card decision required; `FLAG_NEEDS_OPEN_BUILD_TASK` |
| QM5_41189 | `62639587-7b80-4842-89b7-d14c6787412d` / `COMPILE_OK` | resolved by task `5a98a339...` |

All source hashes and predecessor/work-item bindings are recorded in
`plan.json`. The four resolved rows are bound to the current on-disk MQ5 hashes;
their compiled EX5 hashes agree with their immutable compile evidence.

## Governed dry-run result

The exact seven unresolved arms were passed to
`repair_successor_stale_compile_rows_0913.py` in dry-run mode. Result:

- targets: 7
- repair successors eligible: 0
- `FLAG_NEEDS_FRESH_BUILD_EA`: 5
- `FLAG_NEEDS_OPEN_BUILD_TASK`: 2
- every target `has_approved_card=false`, `build_task_id=null`, and
  `needs_commission=true`

The path-(a) finding from the accepted predecessor evidence is unchanged:
`window_sweep.py` is sealed to its own program, while `config_sweep.py`
requires an approved card and existing compiled identity and creates
optimization cells, not compile rows. Path (b), an OWNER-approved card followed
by the normal build/compile path, remains the only route for these seven arms.

A bounded `release_compile_wave.py --max-items 1` dry-run reports
`held_pending_count=0` and `release_count=0`. Therefore no compile row was
created, no activation hold was released, and no apply was attempted. Apply is
also prohibited until an orchestrator reviews an eligible plan.

QM5_20042 and QM5_20053 remain excluded because their XBRUSD/XCUUSD DWX-matrix
decision is still OWNER-only.

This evidence does not authorize card creation, a compile, a pipeline verdict,
or live use.

