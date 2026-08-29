# PATH-TO-25 optimization-fork unblock

- Router task: `ac80262f-97e7-4179-abb9-bc4166ecdcb1`
- Authority: `router_ops_issue:ac80262f-97e7-4179-abb9-bc4166ecdcb1`
- Date: 2026-08-29
- Branch: `agents/board-advisor`
- Implementation commit: `c5e3878a2`
- Disposition: REVIEW; no pipeline or live verdict is asserted

## Root cause and repair

Three independent fail-closed conditions were reproduced.

1. `optimization_fork_driver._append_stage()` raised on a deterministic UUID
   collision whenever the historical row payload had accumulated execution
   metadata. The exception rolled back the whole transaction, so the existing
   `d0e53004-659c-563c-8314-c24ad4ab2a68` Q12 row for
   `QM5_11421 / EURUSD.DWX` prevented unrelated eligible Q11-PASS pairs from
   appending their Q12 declarations. The driver now preserves the existing row,
   records `DETERMINISTIC_COLLISION_SKIPPED_APPEND_ONLY`, and continues the
   transaction. It does not rewrite the colliding row.
2. The generic optimization service recognized the DL-089 declaration as
   governed but returned only `GOVERNED_EVALUATOR_REQUIRED`. It now maps the
   exact v4 pattern declaration to `dl089_matrix_service` and returns
   `GOVERNED_EVALUATOR_ASSIGNED:dl089_matrix_service`. Existing holds and the
   matrix service's declaration, binary, compile, and Q02 gates remain
   authoritative.
3. Compile admission treated a source-matched historical `COMPILE_OK` receipt as
   current even when the bound EX5 was absent. Admission now also requires the
   canonical EX5 to exist and match the receipt/payload hash. Missing-binary
   repair authority is exact-task and exact-label bounded to the three DL-089
   pilots; a present healthy binary cannot be rebuilt under it.

## Five append-only Q12 declarations

Each source pair had a fresh `done / PASS` Q11 receipt. The following exact
`advance-optimization-fork --apply` operations succeeded after the collision
repair; every new row was re-read as `pending / Q12`:

| EA / symbol | New Q12 work item |
|---|---|
| `QM5_13054 / XTIUSD.DWX` | `a5b90e08-cf49-51ac-be59-1d4926da2363` |
| `QM5_1537 / XAGUSD.DWX` | `c41e2606-3af1-5766-9bb7-18de8a763a18` |
| `QM5_21507 / XAUUSD.DWX` | `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` |
| `QM5_11881 / GBPUSD.DWX` | `d824e8cb-8397-5aa3-b6fa-fec9b0c375eb` |
| `QM5_20266 / XTIUSD.DWX` | `d8739ae2-1ce4-553a-9b59-1335e582614c` |

The bulk dry run also encountered historical collisions
`d0e53004-659c-563c-8314-c24ad4ab2a68` and
`dfca24fa-28df-5f5e-818f-8dcf53611822`; both were skipped append-only and the
transaction continued. No bulk apply or router-routing command was used.

## DL-089 pilot inventory and service state

| Pilot | Canonical binding | Governed state at 2026-08-29 08:10 UTC |
|---|---|---|
| `QM5_41161_tv-mon-ls-opt` | MQ5 `59b67eb93b490c6c4a4614da7abd021830cff8d911e08c11913beb06fd31bdb4`; EX5 `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5`; compile `c29b6c89-45d3-4139-912e-2e2e49f1a470` | Q02 `7cd3787a-39df-5ac2-8e7d-c2e29bd258bc` is `done / PASS`. Matrix `1a92b33e-e34f-532e-80b3-e0144f3b3755` is maintained with 66 measured and 1,019 pending cells. |
| `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt` | MQ5 `57298f812d62c24b41fea5333b7de0785004339610a48fd4934454de821c283b`; EX5 `32ac75db71c957ea78fd65f34a3468f9241f91bc4a8ca05c1526b3b1fdcc1ccc`; compile `2e4ce023-1eaf-4a95-8952-1a47820c5c25` | Q02 `77544e3e-93b8-5690-9cf9-a174b7db2091` is `done / PASS`. Exact service apply materialized matrix `c4bc189b-372d-54c9-be45-046ac77b245b`: 1,085 inserted, 1,085 pending, bounded priority window 8. |
| `QM5_41163_williams-18ma-outside-bar-entry-d1-opt` | MQ5 `337aa718eab729ec7c4e7c55e66145898f779064a8618bcfb02be8289916ef36`; set `9c0e6d8de1c02cde6c92f569814afa43409a69bc2872e62609d6e49a02c5d835`; canonical EX5 absent | Historical governed binary `8a7703322fa28d81d953c7725901fc12e0f44ebb8fc6643d58da80332e94e495` is preserved in `D:/QM/strategy_farm/state/backups/ex5_quarantine_20260827/`, not restored. Exact successor compile `7ac8261a-97e0-41f6-a1a4-bd789a1b3bcf` was admitted and released after its source hash matched; it remains pending and unclaimed. Matrix `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` therefore remains honestly deferred for `measurement sibling binary missing`, with no Q02 or cells manufactured. |

Compile release was exact-ID bounded. Its pre-mutation database backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T080335Z_83603490.sqlite`
(SHA-256 `417759bb47a16ef090a62c2c65cbf450bd10eb99ccf7d7f2e7d23fc1cc9eb9ed`).
The release removed only the compile activation hold. Scheduled resident workers
retain sole claim/execution authority. No worker, terminal, or active backtest was
interrupted.

The three existing declarations remain at 154 declared trials. Their sealed ROT
selection-rule SHA-256 remains
`4cc2bbd108bf500f33ef5eee30536c9a4afe58dc2684116a972c0bfb65f3d383`.
No declaration, EA, setfile, selector, trial-count, or selection-rule bytes were
changed by commit `c5e3878a2`. The materialized 41162 neutral sets were checked as
`RISK_FIXED=1000` and `RISK_PERCENT=0`; the 41163 bound set carries the same
values. The news-staleness maximum was not changed or weakened.

## Verification

- Focused suite:
  `test_optimization_fork_driver.py`, `test_optimization_fork_service.py`,
  `test_compile_work_items.py`, and `test_dl089_matrix_service.py` — **46 passed**.
- Python syntax compilation passed for the changed modules.
- `git diff --check` passed.
- Live dry run proved a deterministic collision no longer aborts the five
  unrelated appends.
- Generic-service dry run for
  `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` returned the governed evaluator
  assignment and left the row fail-closed in the matrix service.
- Post-apply matrix reads report 1,019 pending cells for 41161 and 1,085 pending
  cells for 41162. Post-apply work-item reads report all five new Q12 rows above
  as pending.

The 41163 compile, its prerequisite Q02, and its matrix materialization remain
future scheduled work and are not represented here as complete. This evidence
authorizes neither a pipeline PASS nor promotion to PIPELINE, deployment,
T_Live, AutoTrading, or any live-trading action.
