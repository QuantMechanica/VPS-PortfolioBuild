# Active-v4 frontier backfill tranche 1

Date: 2026-08-31  
Task: `a4812054-c382-48ae-ace2-10844b212e87`  
Authority: `OWNER-DEC-BACKFILL-TRANCHE-1=YES`  
Verdict: **PASS — bounded append-only tranche created and verified**

## Bound inputs

The run used the canonical checkout `C:/QM/repo`. The runtime loader reported
`ACTIVE_GATE_CONTRACT_VERSION=v4`; the active manifest was
`tools/strategy_farm/config/gate_manifest.v4.json`, SHA-256
`f71c1ea63f1e847b3670904a6de25bc4b337df9e0a7cff8ee6405d9c3aa2c83`.

A new full census was computed from the live farm DB in SQLite read-only mode.
The pre-apply plan was not the stale 2026-08-23 v3 artifact:

| Item | Value |
|---|---|
| Dry-run plan | `D:/QM/reports/rebaseline/a4812054/backfill_plan_2026-08-31_a4812054.json` |
| Dry-run plan SHA-256 | `ce9c5d25b5fd60205033e6c644480d4c6ce67ec91e7f6a32fa049b4045e76e59` |
| Contract | `v4` |
| Classified rows | 14,884 |
| Eligible snapshot rows | 860 |
| Pre-apply work-item cutoff | rowid 120565 / 120,565 rows |
| Pre-apply cutoff digest | `19a315bc74da0327d7fc8eca5f6cc660df3de62155308ceba8fe64875d35a1cb` |

The guarded apply independently refreshed the same frontier into
`D:/QM/reports/rebaseline/a4812054_apply/backfill_plan_2026-08-31_a4812054_apply.json`
(SHA-256 `ab4b659a139d79bb9a6528308db59bf304b0ac25540f34087c38d0cbed986943`)
and was invoked with both `--i-understand-append-only` and `--max-rows 200`.

## Result

The planner selected 80 candidates after current active-symbol occupancy was
applied. `farmctl enqueue-backtest` created 65 new UUID rows and refused 15
candidates at its current binding/dedup gates. A post-run rowid reconciliation
found 66 new rows after the cutoff: exactly 65 matched selected plan identities
and one was an unrelated concurrent Factory insert.

| Check | Result |
|---|---:|
| Created rows | 65 (limit: 200) |
| Maximum created rows for one symbol | 3 (limit: 3) |
| Q03 | 53 |
| Q07 | 4 |
| Q10_NEWS | 8 |
| Parent identity/phase failures | 0 |
| v4 envelope failures | 0 |
| Payload/envelope hash mismatches | 0 |

Every created row references an existing predecessor through the phase-native
`promoted_from_work_item`, `promoted_from_p2_work_item`, or append-only rerun
field. EA, logical symbol, setfile, and predecessor phase agree. Basket rows
correctly retain a logical-symbol envelope while `expected_symbol` names the
host instrument; this is not an identity mismatch. The complete 65-ID receipt
is `a4812054_backfill_tranche1_receipt_2026-08-31.json` beside this document.

## Append-only and live-factory note

The planner inspected SQLite through `mode=ro` plus `PRAGMA query_only=ON` and
the apply surface invoked only canonical `farmctl enqueue-backtest` commands.
Reruns carried `--append-only-rerun-of`; every attributable effect reconciled
to a new UUID at rowid greater than the pre-apply cutoff. No command targeted an
existing work-item ID for update, deletion, or verdict relabeling.

The Factory remained running as required, so a whole-table before/after digest
is not a valid isolation oracle: active workers legitimately update existing
row statuses while this tranche runs. The historical cutoff digest did change
during the run for that reason. The mutation proof is therefore the governed
append-only command surface plus exact reconciliation of its new UUID rows,
not a false claim that the live database was globally static.

No worker, terminal, `T_Live` file, AutoTrading setting, historical verdict, or
existing work item was intentionally changed by this task.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_backfill_planner.py tools/strategy_farm/tests/test_rebaseline_census.py -q
.................................                                        [100%]
33 passed in 1.41s
```

Machine-readable verification and all created work-item IDs are in the receipt
JSON. The two generated Markdown plan views are retained beside this evidence.
