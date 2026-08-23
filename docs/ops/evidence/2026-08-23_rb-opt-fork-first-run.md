# rb-opt-fork-first-run evidence — 2026-08-23

## Outcome

The optimization fork now has an append-only, manifest-role-driven router in the
five-minute pump. Under v3 it routes `Q10 PASS -> Q14 -> Q15 -> Q16`; loading the
v4 manifest routes the same code as `Q11 PASS -> Q12 -> Q13 -> Q14`. The router
does not run MT5 or adjudicate a gate. It only appends the next governed analytic
work item after the predecessor becomes terminal and authenticated.

The first production admissions were commissioned for the three ticket pairs.
All three remain pending; therefore this evidence records their checkpoint query
rather than claiming measured completion durations.

No gate threshold or criterion was changed. No verdict was overwritten, no
backtest was enqueued or deleted, the factory was not toggled, and `T_Live` was
not touched.

## Runtime trace and closed automation gaps

The pre-change inventory says the ordinary cascade has no Q14/Q15/Q16 driver
(`docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md:74-76`) and
identifies admission/head-to-head as CLI surfaces
(`docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md:86-93`). The
new flow is:

1. `farmctl.py pump` invokes the router after Q09 autoseal on every cycle
   (`tools/strategy_farm/farmctl.py:18376`).
2. `advance_opt_fork` opens the DB read-only for previews and through the normal
   farm connection only for `--apply` (`tools/strategy_farm/farmctl.py:25438`).
3. `advance_optimization_fork` resolves INCUMBENT/PATTERN/PARAM_OPT/HEAD_TO_HEAD
   from the supplied manifest and appends every currently licensed successor
   (`tools/strategy_farm/optimization_fork_driver.py:339`). Deterministic UUIDs
   plus payload comparison make reruns idempotent.
4. Every row binds the immediate parent's evidence, setfile, MQ5 and EX5 hashes,
   plus the manifest hash (`tools/strategy_farm/optimization_fork_driver.py:211`).
5. Pattern admission authenticates fixture-harness root `83b89730...`; the most
   recent successful rerun of the same harness identity may satisfy the
   prerequisite. Missing/non-green evidence appends a terminal `INFRA_FAIL`
   with a machine reason (`tools/strategy_farm/optimization_fork_driver.py:127`,
   `:258`). It never silently skips the pair.
6. Pattern `PASS`, valid no-filter/KEEP outcomes route to parameter freeze; valid
   no-change/KEEP outcomes route to head-to-head
   (`tools/strategy_farm/optimization_fork_driver.py:42-47`, `:369-385`).
7. Exact-pair commissioning is exposed on governed
   `enqueue-opt-admission --ea --symbol`; the legacy bulk form remains compatible.
   A separate `advance-optimization-fork` command supports operator checkpoints
   (`tools/strategy_farm/farmctl.py:26518-26534`, `:26780-26800`).

The Q15 policy created by this ticket is explicitly `NO_NEW_PARAMETER_SWEEP`,
declared parameter count `0`, declared trial increment `0`
(`tools/strategy_farm/optimization_fork_driver.py:237-245`). Thus no unapproved
GELB parameter hypothesis was invented. A future non-zero sweep remains outside
this ticket and still requires its hypothesis, refutation criterion, frequency
check, and declared parameter count.

## Fixture dry-run and unit coverage

The fixture test builds an isolated SQLite work-items DB, calls the router with
`apply=False` at all three stages, and asserts the row count is unchanged while
Q14/Q15/Q16 successors are planned
(`tools/strategy_farm/tests/test_optimization_fork_driver.py:182`). The same file
also covers v3, a monkeypatched v4 manifest, `KEEP_INCUMBENT`, missing fixture
harness fail-closed behavior, and both health metrics (`:124`, `:160`, `:224`,
`:247`, `:268`).

Command and output:

```text
python -m pytest -q tools/strategy_farm/tests/test_optimization_fork_driver.py
......                                                                   [100%]
6 passed in 1.82s
```

## First production admission

Dry-run commands (from this worktree) returned the same deterministic IDs later
created by apply:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_10706 --symbol GBPUSD.DWX
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_11421 --symbol EURUSD.DWX
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_11422 --symbol USDCAD.DWX
```

The repository mutation guard normally permits state writes only from the
canonical checkout. The ticket explicitly required execution from this worktree,
so the deliberate, command-local override was used for these three bounded
append-only admissions:

```powershell
$env:QM_ALLOW_NONCANONICAL='1'; python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_10706 --symbol GBPUSD.DWX --apply
$env:QM_ALLOW_NONCANONICAL='1'; python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_11421 --symbol EURUSD.DWX --apply
$env:QM_ALLOW_NONCANONICAL='1'; python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-opt-admission --ea QM5_11422 --symbol USDCAD.DWX --apply
```

Each command exited `0` and appended exactly one analytic row:

| Pair | Parent Q10 PASS | Created work item | Created UTC | Parent evidence SHA-256 |
|---|---|---|---|---|
| QM5_10706 / GBPUSD.DWX | `f06b8243-d3ca-490a-8b47-7c598f4d6d58` | `48183f09-ad48-5c42-b1b6-9e7787b5ac32` | `2026-08-23T15:46:34.527330+00:00` | `020787223d9bd50cb64a976d192a62bcddbab5d762886f1e9c5d21953c1aa39c` |
| QM5_11421 / EURUSD.DWX | `38eddd19-0d07-4686-b1e2-afc4124e9bc8` | `8eda68d9-aae3-509c-a0cc-6e738e1bde99` | `2026-08-23T15:46:36.299045+00:00` | `7bfc3c519c12ff695d00c92604360751e4a5d7a6650144d9983feea898824242` |
| QM5_11422 / USDCAD.DWX | `6f9400fa-9ca2-4835-9fcf-e1087289f9b1` | `9975987c-d408-5724-8863-f4e49a214d4b` | `2026-08-23T15:46:38.168662+00:00` | `bd8ba9a44a8ec1ca986bf2468937d309f158ac00b62b0982830b93b8c767886a` |

All three payloads bind the green governed harness rerun
`2dbc9f85-badd-4bf9-b607-e2655e9944b1`, verdict `HARNESS_OK`, evidence SHA-256
`67ef8038e62e21c61b53452a20a53b3d05e661c8dc04682fc1f659529b0c3bfe`.
The original required root remains preserved as `failed/INFRA_FAIL`.

Immediately after insertion the rows were v3/Q14/pending with manifest SHA-256
`988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce`.
During this session an independent canonical v4 activation changed their
row-level stamps to v4/Q12. No command in this ticket performed that migration.
At the final read-only checkpoint the row payloads still truthfully record their
v3/Q14 creation provenance and complete bindings while columns say v4/Q12. This
column/payload mismatch must be resolved by the v4 activation owner before an
adjudicator treats the rows as contract-native v4 evidence; this ticket did not
rewrite or replace them.
Current read-only checkpoint query:

```sql
SELECT id, phase, status, verdict, gate_contract_version, created_at, updated_at,
       ROUND((julianday(updated_at)-julianday(created_at))*24*60, 2) AS duration_min
FROM work_items
WHERE id IN (
  '48183f09-ad48-5c42-b1b6-9e7787b5ac32',
  '8eda68d9-aae3-509c-a0cc-6e738e1bde99',
  '9975987c-d408-5724-8863-f4e49a214d4b'
)
ORDER BY created_at;
```

Final result: all three are `Q12`, `pending`, verdict `NULL`, version `v4`, and
`updated_at == created_at`; no per-gate completion duration exists yet. Re-run
the query after each terminal transition to measure durations.

## Health visibility

`chk_opt_fork_service_rate` reports completed rows in the last 24 hours for each
versioned pattern/parameter/head-to-head role and warns when backlog exists with
zero completions (`tools/strategy_farm/health.py:4035`).
`chk_terminal_requalification_verdicts_count` reports the lifetime number of
terminal per-pair outcomes (`tools/strategy_farm/health.py:4065`). Both checks
are registered in `ALL_CHECKS` at `tools/strategy_farm/health.py:4133-4134`.

Read-only production snapshot at the checkpoint:

```text
v3:Q14:PATTERN=0/day   v3:Q15:PARAM_OPT=0/day   v3:Q16:HEAD_TO_HEAD=0/day
v4:Q12:PATTERN=0/day   v4:Q13:PARAM_OPT=0/day   v4:Q14:HEAD_TO_HEAD=0/day
terminal_requalification_verdicts_count=0
```

This makes the still-closed dam visible without changing a gate criterion.

## Verification

Focused touched behavior:

```text
python -m pytest -q tools/strategy_farm/tests/test_optimization_track_manifest_v2.py tools/strategy_farm/tests/test_q14_opt_admission.py tools/strategy_farm/tests/test_q15_freeze_check.py tools/strategy_farm/tests/test_q16_head_to_head.py tools/strategy_farm/tests/test_v4_runtime_wiring.py tools/strategy_farm/tests/test_health_vacuousness.py tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_gate_manifest.py
155 passed, 2 skipped, 6 subtests passed in 44.77s

python -m py_compile tools/strategy_farm/optimization_fork_driver.py tools/strategy_farm/farmctl.py tools/strategy_farm/health.py
PASS

git diff --check
PASS (only Git's existing health.py LF-to-CRLF working-copy warning)
```

The repository-wide requested suite was also allowed to finish:

```text
python -m pytest -q tools/strategy_farm/tests
232 failed, 4259 passed, 4 skipped, 2 warnings, 42 subtests passed in 1187.11s
```

The broad suite is not green. Its failures are existing environment/reference
artifact clusters (including agent-router canonical generation, FTMO artifacts,
target outcome/rulepack hashes, registry and news fixtures); the focused new
test and all directly touched module suites above are green. This result is
reported rather than suppressed.

## Rollback

Revert this ticket commit to remove future automatic routing and the two health
checks. The three production work items are append-only evidence and must not be
deleted or have verdicts overwritten. If commissioning must be abandoned, leave
them pending/failed with the governed machine reason and have the v4 activation
owner resolve the column/payload provenance under its migration authority.
