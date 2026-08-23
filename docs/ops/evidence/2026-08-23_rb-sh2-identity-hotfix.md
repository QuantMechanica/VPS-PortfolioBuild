# rb-sh2-identity-hotfix — SH-2 artifact identity completion repair

Date: 2026-08-23/24

Branch: `rb-sh2-identity-hotfix`

Ticket: `rb-sh2-identity-hotfix`

## Status and safety

The P0 completion regression is fixed in code and covered with live-payload fixtures. The
factory flag, gate criteria/thresholds, verdict rows, and `C:/QM/mt5/T_Live` were not changed.
All database inspection used `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`.
The only live writes were governed `farmctl enqueue-backtest --append-only-rerun-of` attempts;
original failed rows remain byte-for-byte historical rows.

## Root cause — before

1. `extract_identity` recognized flat `expected_*` keys and a small set of older nests, but
   not the shapes emitted by current runners: `staged_ex5`, `evidence_identity`,
   `execution_identity`, Q09 input-manifest `identities`/`calendar_bundle`/`windows`, or nested
   spawn/run bindings. It also did not follow the row's hash-pinned Q09 plan/input-manifest
   sidecars or the runner aggregate's `summary_path`.
2. Both dispatch writers copied `spawn.get("expected_*")` into the active payload. Real
   phase-runner spawn results omit those fields, so valid enqueue-time hashes were overwritten
   with JSON `null`. The live post-failure payload for `28e0bc81-ed4e-4bfa-918f-3c66d3c890a0`
   shows those nulls while its bound aggregate contains EX5/setfile identity and its staged EX5
   remains hash-bound.
3. `prepare_completion` changed a strategy verdict to `INFRA_FAIL` when *any* lane-preferred
   identity field was absent. That contradicted the nullable SH-2 columns and the zero-binding
   fail-closed contract. `identity_update_clause` also assigned `NULL` for unresolved columns.
4. The SH-3 materialization trigger repeated the same over-strict rule with
   `ex5 IS NULL OR setfile IS NULL OR window-start IS NULL OR window-end IS NULL`.

Read-only live census immediately before repair attempts:

```text
SELECT id,phase,ea_id,symbol,status,verdict,updated_at,
       json_extract(payload_json,'$.promoted_from_work_item') AS predecessor
FROM work_items
WHERE json_extract(payload_json,'$.verdict_reason')='ARTIFACT_IDENTITY_MISSING'
ORDER BY updated_at;

12 rows
```

## Code change — after

- `tools/strategy_farm/artifact_identity.py:38-137` maps the observed flat and nested runner
  shapes, including `expected_*`, `staged_ex5`, `evidence_identity`, `execution_identity`,
  Q09 manifest identity, nested binding containers, and build-hash aliases. Values are copied
  only after type/SHA validation; no path is hashed to manufacture an artifact identity.
- `tools/strategy_farm/artifact_identity.py:210-259` follows only paths explicitly bound by the
  row/runner. Q09 plan and input-manifest files are SHA-verified before their identities are
  admitted. Runner and multi-seed summary sidecars are treated as evidence sources.
- `tools/strategy_farm/artifact_identity.py:265-319` fails closed only when a
  `taxonomy=strategy` economic completion resolves **zero** SH-2 identity values. Partial
  bindings retain their economic verdict and record nullable missing-field diagnostics.
- `tools/strategy_farm/artifact_identity.py:323-344` stamps only non-null resolved values, so a
  partial completion cannot erase an already typed identity column.
- `tools/strategy_farm/terminal_worker.py:4578-4593` preserves enqueue-time bindings when a
  phase-runner spawn omits them. `tools/strategy_farm/farmctl.py:11565-11606` does the same in
  the secondary dispatcher, and `tools/strategy_farm/farmctl.py:8546` returns the verified
  dispatch EX5 hash from the phase-runner spawn boundary.
- `tools/strategy_farm/schema_hardening.py:339-356` makes the SH-3 trigger's fail-closed
  predicate an all-eight-columns `AND` (zero identity), matching nullable partial identity.

## Live payload fixtures and regression

`tools/strategy_farm/tests/fixtures/artifact_identity_live_payloads_20260823.json` contains
identity-relevant excerpts copied from these live rows/evidence artifacts:

| Phase | Source work item | Shape exercised |
|---|---|---|
| Q02 | `d4196794-d342-475f-8a0e-4829c33663d7` | flat `expected_*` spawn binding |
| Q03 | `61c0a755-7a67-44ab-93b8-e214a27d1546` | flat + `execution_identity` + `test_window` |
| Q04 | `3bb790c3-4b17-4da6-9c77-3d84e7e769d2` | aggregate top-level hashes + staged EX5 |
| Q07 | `d13ac418-2f3e-48cc-8131-cf1bbbe52979` | multi-seed aggregate + staged EX5 |
| Q09 | `28e0bc81-ed4e-4bfa-918f-3c66d3c890a0` | `evidence_identity` + `history_from/to` |
| Q10_NEWS | `8214410d-7708-4077-8626-c3c449ee862c` | hash-pinned plan → input manifest |

The 28e0bc81 regression is asserted at
`tools/strategy_farm/tests/test_artifact_identity_hotfix.py:97`: EX5, setfile, and the
2017.01.01–2025.12.31 window are stamped and `PASS/strategy` is retained. Hash-pinned Q10_NEWS
sidecar resolution is at `:59`; partial-verdict preservation is at `:121`. SH-3 partial-row
coverage is at `tools/strategy_farm/tests/test_schema_hardening_sh2_sh3.py:67,162`.

## Tests

```text
python -m pytest tools/strategy_farm/tests/test_artifact_identity_hotfix.py \
  tools/strategy_farm/tests/test_schema_hardening_sh2_sh3.py -q -ra
16 passed in 1.88s

python -m pytest <identity/worker/cascade touched suites> -q -ra
170 passed in 57.19s

python -m pytest tools/strategy_farm/tests -q -ra
4592 passed, 4 skipped, 42 subtests passed in 1771.82s
```

The repository-wide run initially reported four failures. Two were stale zero-binding fixtures
in `test_terminal_worker_atomic_claim.py`; after adding an explicit partial EX5 binding, both
focused regressions passed (`2 passed in 1.07s`) and the complete touched suite above passed.
The two remaining repository baseline failures are unrelated to this ticket:

- `test_build_gate_hardening.py::test_qm5_411xx_sources_have_no_unbounded_numeric_buffers`
  finds pre-existing QM5_41134/QM5_41135 source findings.
- `test_opt_census_dispatch.py::test_opt_census_ranks_tier6_not_priority` expects phase rank 7
  while runtime returns 6.

`python -m py_compile` passed for the four touched runtime modules. `git diff --check` passed.

## Append-only repair census and results

The final pre-enqueue census had 12 rows. Three rows belong to the documented nine-pair
Q07/Q08 stale-vintage regeneration cohort and were intentionally excluded:

- `8214410d-7708-4077-8626-c3c449ee862c`, QM5_11294/GDAXI, Q10_NEWS
- `80f84cd8-85bf-400f-b3f5-a77bda9ac873`, QM5_11294/GDAXI, Q09
- `a246bfe9-ecb2-4b31-a689-124af0cebb68`, QM5_10706/GBPUSD, Q09

Created append-only children (original rows remain `failed/INFRA_FAIL`):

| Failed row | New child | Phase / pair |
|---|---|---|
| `28e0bc81-ed4e-4bfa-918f-3c66d3c890a0` | `9e4b5dfc-b4ba-4292-a7ab-03d67108d4e2` | Q09 QM5_20086/NDX |
| `985f4a1a-de9e-4346-88f9-a1d733021dc6` | `831bdffc-7da6-43c0-8443-adef3c9a0f0d` | Q09 QM5_10916/GDAXI |
| `d9a42fa6-1df8-45c6-ab0b-632373d72457` | `2eebe7ff-682d-4d38-91a3-9c1833caed3a` | Q09 QM5_11063/USDJPY |

Five authorized attempts were deduplicated because an open same-phase row already existed;
farmctl correctly refused to create a second run:

| Mis-INFRA row | Existing pending row |
|---|---|
| `9e1075ef-9bf5-4d31-81c4-80580a7d273b` | `c2d9d7e2-301d-404e-bc01-f4bfcede20fe` |
| `7434135f-c3d4-458d-b836-ba43b44e3fb6` | `c35489ec-72d3-4213-a6e2-03c1d88eae94` |
| `c7254320-cd84-4d3c-ba5d-7caa1050cd22` | `9f8d8558-41e0-4043-8e9b-8b1110d8f323` |
| `ff52b32f-b9b4-441e-af9a-bc1d71355dcf` | `74fad2fb-d815-42dd-bb02-1c21926cdf67` |
| `8a303765-c827-4839-ba4c-2a7a26987be9` | `8cdc3bc9-12dc-47c4-8836-655f78d2470b` |

`dac8cff3-bc8a-4112-b418-3bed399fb510` (QM5_1354/XAUUSD Q10_NEWS) could not be inserted:
the active v4 farmctl contract requires a completed Q09 predecessor, while its Q09 row
`eb00acbc-127a-456f-bc82-361b84430042` is still pending. The controller returned
`No done Q09 PASS work_items found`; no dependency bypass or duplicate was created.

## Rollback and residual risk

Code rollback: revert this ticket's commit. The three append-only pending children are durable
audit facts and must not be deleted or rewritten; any later cancellation requires a separate
authorized state transition. Original verdict rows require no rollback because none changed.

The existing live DB still contains the pre-hotfix SH-3 trigger SQL until the deployment owner
refreshes those two triggers in an authorized schema window. Healthy sampled Q04/Q07/Q09/Q10
rows resolve sufficient real identity through this code, but the live trigger refresh is still
required for the general nullable-partial contract. No trigger DDL was applied by this ticket.

## Orchestrator activation (2026-08-24 ~01:20)

- Branch merged to `agents/board-advisor` (`438b241dd`) after focused Opus review (APPROVE;
  114 tests + 6 subtests green on the merged tree).
- The stale pre-hotfix SH-3 materialize triggers on the LIVE DB were refreshed atomically from
  the hotfixed generator (`_sh3_trigger_sql`, AND-all-null predicate), SQL backup:
  `D:/QM/strategy_farm/backups/sh3_trigger_pre_hotfix_20260823.sql`. Workers pick up the fixed
  completion path on their next watchdog respawn.
- Casualties: 3 append-only reruns live (9e4b5dfc/831bdffc/2eebe7ff), 5 deduped, 1 blocked on
  pending Q09 predecessor, 3 = separate vintage cohort (Q07/Q08-Regen in flight).
