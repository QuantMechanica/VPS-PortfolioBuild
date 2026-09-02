# Q10 news-gate lineage debt — wave 2 execution

Task: `ba5f4754-82a9-4074-a640-0bdb521999ef`  
Authority: CEO mandate 2026-09-02  
Mutation policy: append-only reruns/supersession edges; sealed verdict rows are
not overwritten by this execution.

## Result by pair

| pair | frozen defect | current EX5 | append-only disposition |
|---|---|---|---|
| QM5_11129 / SP500.DWX | held Q10 `745671a4` points to historical Q08 `5171b4bf`; forensic aggregate is absent | `1ddd4ef135b3e8cf0154b21e50d6ad696551efe7c5fb4c94808f2bc80f9569d8` | priority Q07 rerun `e046b36b` is pending, copied from exact Q07 `e3187d46` and promoted from exact Q06 PASS `3339e904` |
| QM5_10700 / XAUUSD.DWX | held Q10 `77bd97c2` points to Q08 `fb35a79a` (FAIL_SOFT); forensic aggregate is absent | `0126116d7ffa2b4a952a4962c8035973e11c57bdd423076ee6080458d6c438d8` | priority Q07 rerun `3815515b` is pending, copied from exact Q07 `3fdcc9af` and promoted from exact Q06 PASS `21cf0867` |
| QM5_11910 / NZDUSD.DWX | held Q10 `dd7b14a0` points to Q08 `0cb83f40` (FAIL_SOFT); forensic aggregate is absent | `40fc2b902178fce9f2e65f25a8a1922f5a155094e15e8faffa175cb9b41a0b8a` | priority Q07 rerun `f3689f77` is pending, copied from exact Q07 `966fdb3a` and promoted from exact Q06 PASS `391a907b` |
| QM5_10114 / SP500.DWX | Q08 `e76e7c6e` and exact current-binary rerun `ac972f2a` both ended FAIL_SOFT | `cdc478d75c90e5bb6a167831a6b1ac49dec106b4a8cd225dac352918cea74277` | old Q10 `9812fc7b` has canonical no-successor edge `operator:record`; dead lineage documented |
| QM5_11421 / EURUSD.DWX | old Q10 `30584122` points to Q08 `6678f2c4`, not the new exact chain | `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | CEO-created priority Q08 rerun `c93263aa` is pending from current-binary Q07 PASS `2556a768`; Q10 replacement is correctly not minted before that row PASSes |

All three new Q07 rows were created through canonical `farmctl
enqueue-backtest --append-only-rerun-of ... --from-work-item-id ...
--expected-current-ex5-sha256 ...` and then marked priority-track. Their
payload readback includes the exact source row, current EX5/MQ5/setfile hashes,
expected expert/symbol/period, rerun reason, and priority mark.

## 10114 concurrency note

Initial inspection found `9812fc7b` already transitioned by another control
plane actor to `done/SUPERSEDED` at 16:00:52Z; this execution did not edit that
row or its released hold. It added the missing canonical supersession edge
only. Autoseal had also appended Q10 `8f2c850c` from the FAIL_SOFT rerun and T9
claimed it while this task was running. Active T1-T10 work may not be
interrupted, so that row was neither stopped nor adjudicated here. Any verdict
must come from its pipeline evidence.

## 11421 continuation boundary

The exact Q08 rerun `c93263aa-a707-45ea-a915-204ec59df077` was still pending at
the final readback. Therefore old Q10 `30584122` was not prematurely bound to a
non-PASS result and was not re-held. Once `c93263aa` records PASS, the next
authorized action is an append-only Q10_NEWS successor whose
`promoted_from_work_item` is exactly `c93263aa`, plus a canonical supersession
edge from `30584122` to that new row. Preserve the released
`OWNER-DEC-Q09HOLD-REQUAL-8-20260829` receipt; do not re-hold it.

## Backups and verification

Two separately scoped mutation batches each have exactly one pre-mutation
online backup:

1. three Q07 enqueues plus priority marks:
   `D:\QM\strategy_farm\state\backups\farm_state_before_q10_lineage_wave2_20260902T162918_341706Z.sqlite`
   (`e88acb5ce49f73155dd8bd5e626264794052f4a8f57da6dffa19b265432554b2`)
2. one-row 10114 canonical supersession:
   `D:\QM\strategy_farm\state\backups\farm_state_before_supersedes_20260902T163037Z.sqlite`
   (`3cc4486cdb8b48bd7eaba541035d073fb228d974ca74f4a6331ba65966c8e906`)

Post-apply hash readback matched both backups, SQLite `PRAGMA quick_check`
returned `ok`, the three Q07 rows were pending/current-hash/priority-track, and
the 10114 edge read back with no successor. No historical result or verdict was
deleted by this execution.

