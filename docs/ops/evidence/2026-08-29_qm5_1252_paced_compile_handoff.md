# QM5_1252 paced compile and Q02 recovery handoff

Date: 2026-08-29

Branch: `agents/board-advisor`

Farm task: `25d7265a-332b-4d4c-8c5e-6518c7caa52a`

EA: `QM5_1252_carver-handcraft-ens`

Outcome: **STRICT SOURCE REPAIR VERIFIED; GOVERNED COMPILE PENDING; Q02
SUCCESSORS CORRECTLY NOT SEEDED**

## Governed rebuild state

The exact source repair and compile authority were committed previously in
`37693691f`. The source remains byte-identical to the governed compile request:

- MQ5 SHA-256: `cf41554ab02caa59610e3379bd6e9ca49774ee5727ea68697a9cbd331a641afd`;
- compile work item: `62044bf3-dcf2-4337-a5f9-7196eb4a2efa`;
- authority: `router_ops_issue:25d7265a-332b-4d4c-8c5e-6518c7caa52a`;
- activation hold released: `2026-08-28T18:34:54+00:00`;
- observed state at `2026-08-29T07:21Z`: `pending`, unclaimed, no verdict,
  no compile evidence, and no EX5 receipt.

The current EX5 is still the historical binary with SHA-256
`89e4ba8ccb83755624f0d7a5dc998207ffaaea5f0769f0f619ab191cb23b69c9`.
It was not relabeled as current. The canonical queue contained 35 pending
`COMPILE_EA` rows and no active compile at observation time. Three factory
tests were active on T6, T7, and T10 and were left uninterrupted. No terminal,
tester, MetaEditor, T_Live, or AutoTrading process was started or changed by
this pass.

## Append-only Q02 boundary

Both task-selected source rows remain immutable and terminal:

| Symbol | Source work item | State | Reason |
| --- | --- | --- | --- |
| EURUSD.DWX | `edfcba29-ad06-4b74-907f-38eba94d2610` | `failed / INFRA_FAIL` | `summary_missing_retries_exhausted` |
| GBPUSD.DWX | `8cc9c3c2-1ecd-42f6-8b40-b292b782bf88` | `failed / INFRA_FAIL` | `summary_missing_retries_exhausted` |

There are zero post-repair QM5_1252 Q02 rows. This is the required fail-closed
state: an append-only Q02 recovery must bind the new current EX5 SHA-256, which
does not exist until the paced `COMPILE_EA` row completes as `COMPILE_OK` with
a governed receipt. The historical rows were not edited, invalidated, or
replaced, and no gate verdict was asserted.

## Focused verification

- `validate_build_guardrails.py` passed the MQ5 and all 24 setfiles with zero
  findings. The maximum news-staleness contract remains 336 hours.
- Every backtest set retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `test_compile_work_items.py`: 28 passed, including the exact task/EA-bound
  source-repair authority and negative bindings.
- `farmctl compile-status QM5_1252_carver-handcraft-ens` reported one pending,
  unheld compile and no compiled, failed, or active row.
- Three whole-host CPU samples were 71.40%, 57.43%, and 71.03%; none reached
  the 97% stop wall.

Next paced action is deterministic: allow work item
`62044bf3-dcf2-4337-a5f9-7196eb4a2efa` to complete through the canonical worker,
verify its `COMPILE_OK` receipt and exact EX5 hash, then create append-only Q02
recoveries from the two source IDs above using that exact current binary hash.

