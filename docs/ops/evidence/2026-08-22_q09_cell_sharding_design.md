# Q09_NEWS cell sharding design and implementation evidence

Date: 2026-08-23

Router task: `6b5176df-8769-4ab0-9061-f19def4a7236` / `OPS-Q09-CELL-SHARDING`

Status: REVIEW candidate; rollout flag remains OFF

## Decision

Q09_NEWS keeps one database work-item claim and one immutable 40-cell plan. The
claiming terminal is the main slot. When, and only when,
`Q09_CELL_SHARDING_ENABLED` is explicitly true, its resident worker may reserve
up to `Q09_CELL_SHARDING_MAX_TERMINALS` total slots (default four including the
main slot). The runner assigns plan-order cell identities round-robin across
those slots. Each slot remains serial within its shard; slots run concurrently.

No matrix, seed, window, setfile, timeout, receipt schema, or adjudication rule
changes. `tools/strategy_farm/q09_news_contract.py` has no diff.

## Collision analysis

### Active work items and claim CAS

- `terminal_worker._reserve_q09_helper_terminals` runs under the same
  `FACTORY_MUTATION.lock` used by ordinary claim admission.
- It excludes the main slot, every terminal named by an active database row,
  every observed `terminal64.exe` slot, every disabled/non-policy slot, and
  every live reservation.
- A helper receives no second database claim. The Q09 row remains exactly
  `status=active, claimed_by=<main>`. This avoids two owners mutating the same
  row and preserves the existing claim/retry state machine.
- Before a helper is admitted, available commit and RAM headroom are reduced by
  active claim reservations and by the Q09 row's measured reservation class.
  Low or unreadable resource headroom yields zero helpers and the main slot
  continues serially.
- Ordinary claimers already refuse a terminal present in
  `terminal_reservations.json`; because selection and reservation are inside
  the shared mutation lock, a helper and an ordinary claim cannot both win.

### Reservation and reaper behaviour

- Each lease binds every helper to one exact `reserved_by` token, main work-item
  id, main terminal, and finite UTC expiry. The token carries the worker PID,
  so the existing dead-holder pruning removes corpse reservations after a
  worker death.
- Normal completion releases only reservations whose current token still
  equals this run's token. It cannot release a later operator reservation.
- A helper never owns the database row, so the active-row reaper continues to
  reason only about the main claim. The spawned Q09 runner is already bound to
  the worker's kill job; loss of that lineage cannot leave a legitimate second
  work-item owner.

### Helper abort and main catch-up

- A helper exception produces no terminal `cell_failure` sidecar. It returns
  that cell and the unstarted tail of its shard to the main-terminal catch-up
  pass.
- The main pass skips every immutable receipt and every already-terminal
  main-slot failure. If the repeated cell genuinely fails on the main slot, the
  existing bounded retry and immutable failure-sidecar logic applies.
- Consequently, helper loss changes wall-clock scheduling only. It cannot turn
  an infrastructure loss into strategy evidence.

### Evidence binding and aggregation

- `cell_shard=i/n` and repeated `cell_key` selectors reference only the 64-hex
  `run_identity_sha256` values already sealed in `run_plan.json`.
- `build_cell_shard_assignments` asserts exhaustive, pairwise-disjoint coverage
  before dispatch. Existing receipts are never overwritten; authentication is
  still performed by the unchanged collector.
- Helper capacity is rechecked before every cell against the active main claim,
  exact plan path/hash, exact helper reservation token, Q07 evidence, and Q09
  dispatch binding.
- A subset returns `SHARD_COMPLETE` without publishing evidence or an
  aggregate. Collection and database persistence run only when all 40 planned
  cells have an immutable receipt or authenticated failure-sidecar candidate.
  The collector then performs its existing fail-closed authentication and
  adjudication.

## Implementation points

- `tools/strategy_farm/q09_news_runner.py`
  - deterministic selectors: `parse_cell_shard`,
    `build_cell_shard_assignments`, `select_plan_cells`;
  - helper authorization in `assert_factory_capacity`;
  - parallel execution, helper-abort catch-up, receipt idempotency, and the
    40/40 publication boundary in `execute_run_plan`;
  - plan-only `shard-plan` command for sealed-plan inspection.
- `tools/strategy_farm/terminal_worker.py`
  - explicit-default-off rollout flag;
  - mutation-locked free-slot discovery, resource cap, exact lease, and exact
    release;
  - lease lifetime wraps the normal spawn/monitor lifetime.
- `tools/strategy_farm/farmctl.py`
  - passes only the worker-authenticated helper terminal list and token into
    the Q09 executor.

## Focused verification

Synthetic sealed-plan tests (no MT5 process):

```text
test_cell_shards_are_exhaustive_disjoint_and_default_flag_is_off       PASS
test_subset_execution_is_receipt_idempotent_and_publishes_no_aggregate PASS
test_aggregate_is_published_only_after_all_four_shards_complete        PASS
test_helper_abort_is_caught_up_by_main_terminal                        PASS
test_q09_phase_builder_executes_bound_plan_in_reserved_slot            PASS
test_q09_main_claim_leases_and_releases_only_free_helper_slots         PASS
```

The first focused run reported `4 passed, 38 deselected`; the two worker/command
binding tests reported `2 passed`.

Plan-only dry-run against the sealed 40-cell plan for work item
`4263d6b3-1418-47c4-afe1-de7cb6bf61d4`:

```text
path: D:/QM/reports/work_items/4263d6b3-1418-47c4-afe1-de7cb6bf61d4/run_plan.json
file_sha256: f670e78c06ef8eaa4857660b091a5c014bdbdf75e88295b947925884f3214e04
sealed plan_sha256: 6fd87c8b7f72832fa9a9af99f14b7e9affd336ea31dbed9ded9d98be517bc1d4
result: four disjoint shards of 10 cells; mt5_started=false
```

Command used:

```powershell
python tools/strategy_farm/q09_news_runner.py shard-plan `
  --plan D:/QM/reports/work_items/4263d6b3-1418-47c4-afe1-de7cb6bf61d4/run_plan.json `
  --expected-plan-file-sha256 f670e78c06ef8eaa4857660b091a5c014bdbdf75e88295b947925884f3214e04 `
  --shards 4
```

The command returned `cell_count=40`, shard counts `[10,10,10,10]`, and
`mt5_started=false`. It did not invoke the worker, `run_smoke.ps1`, or any MT5
binary.

## Rollout boundary

The implementation is inert while `Q09_CELL_SHARDING_ENABLED` is absent, which
is the checked-in/default state. Activation remains a separate post-review
operator action. Q09_NEWS diagnostic backfills are explicitly excluded from
helper sharding. T_Live and AutoTrading are not referenced or changed.
