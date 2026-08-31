# DL-089 same-program parallelism implementation receipt

Date: 2026-08-31  
Router task: `49d7998d-7978-41c7-8923-b3bb03292715`  
Approved design: `docs/ops/evidence/2026-08-31_a5432907_dl089_same_program_parallelism_proposal.md`  
Branch: `agents/board-advisor`  
Verdict: **PASS — IMPLEMENTED INERT; REVIEW REQUIRED; NOT ACTIVATED**

## Outcome

The approved two-dimensional DL-089 scheduler is implemented without changing
selection semantics, declarations, setfiles, cell UUIDs, historical verdicts,
terminal state, or the live worker environment.

The rollback/default state is structural:

- `DL089_LANES_PER_PROGRAM` defaults to `1` and is bounded to `1..2`;
- `DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST` defaults to the empty exact-ID set;
- `DL089_CELL_SLOTS` defaults to `6` and is worker-capacity bounded;
- the existing program setting remains independently bounded;
- effective limits are `(K,L,G) = (min(Kcfg,workers),
  min(Lcfg,symbol_cap,workers), min(Gcfg,K*L,workers))`.

At verification time the three new environment variables were all unset,
`L=1`, and the allow-list was empty. The inherited host setting made `K=6`;
with ten enabled worker-policy slots the effective tuple was `(6,1,6)`. This
is the pre-change claim topology: no same-program overlap and no more than one
active cell for each of the six program owners. No environment or service
configuration was written during this task.

## Implemented controls

- `dl089_scheduling.py` now owns bounded environment parsing, exact allow-list
  parsing, `(program_id,arm)` identities, worker-coupled K/L/G limits, complete
  sealed-ledger arm-frontier authentication, active census snapshots, per-arm
  lock names, and the narrow duplicate-pair decision.
- `terminal_worker.py` requires a cold-file eligibility token for governed
  matrix cells. The token binds the exact row and payload, ledger hash, Q12 and
  declaration identity, cell/arm/year, and the terminal-state fingerprint of
  every earlier year in that arm. The claim transaction revalidates payload
  and predecessor state before its CAS. Exact-lane, program, fleet-cell,
  symbol, multisymbol, and duplicate-pair gates remain fail-closed.
- The duplicate `(ea_id,symbol)` exception is possible only for a governed
  `OPT_CENSUS` candidate in an exact allow-listed program, with distinct arms,
  `L>1`, no multisymbol identity, and no breach of the unchanged symbol cap.
  Generic rows, legacy rows, malformed rows, same-arm rows, and empty-list
  defaults retain unconditional serialization.
- Normal and Factory-OFF targeted claim paths use the same policy. Per-arm
  preflight locks allow independent arms to inspect concurrently while the
  same arm remains serialized. Factory-OFF and pending/payload CAS checks are
  retained.
- `opt_census.boost()` now promotes only authenticated arm heads under the
  available lane and fleet-cell budget. Rollback deboost removes only its own
  flags from still-pending rows; active and terminal rows are untouched.
- The matrix service revision is `dl089-matrix-runner-v2`. It publishes both
  configured and worker-effective K/L/G, active/boosted lane IDs, and distinct
  `PROGRAM_SLOT_WAIT`, `PROGRAM_LANE_WAIT`, and `CELL_SLOT_WAIT` evidence. It
  does not regenerate ledgers, declarations, UUIDs, or setfiles.

## Replay evidence

The sealed fixture
`tools/strategy_farm/tests/fixtures/dl089_same_program_replay.json` has SHA-256
`AD1227390F23EA0AF77B098AD94598949669873E6F577520A11CE551504C39A6`.
It contains all seven annual years, baseline, two BUY arms, two SELL arms, an
early floor break, a late floor break, and tied qualifying selector scores.

Three deterministic schedules were replayed:

1. serial `L=1`;
2. `L=2` with reversed independent-arm completion;
3. the same `L=2` interleave with a stale-token retry.

Their global traces differ, proving genuine interleaving. Their canonical
cell dispositions/evidence hashes, pruning receipts and receipt hashes,
annual matrix, four WF selections, final BUY/SELL selection, stability result,
declared trial count, amendment hash, and selection hash are byte-identical.
The replay also asserts one active head per arm and rejects a nonterminal year
after a `SKIPPED_EXCLUDED` predecessor.

## Verification

One focused invocation passed **156 tests**:

```text
test_terminal_worker_atomic_claim.py
test_dl089_matrix_service.py
test_opt_census.py
test_opt_census_dispatch.py
test_opt_census_pruning.py
test_opt_census_select.py
test_dl089_program_replay.py
test_dl089_same_program_replay.py

156 passed in 79.26s
```

`python -m compileall -q` passed for all changed runtime and replay modules.
`git diff --check` passed. Existing unrelated MQ5 worktree modifications were
not staged, changed, or included.

## Activation and rollback

This receipt does **not** authorize activation. OWNER approval of an exact
program ID and a stopped-state worker reload are still required. Activation is
environment-only: set `DL089_LANES_PER_PROGRAM=2`, retain the reviewed K/G,
and set `DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST` to the exact approved program.

Rollback is environment-only: unset the three new variables (or set `L=1` and
clear the allow-list), then use the governed stopped-state reload. Never
interrupt an active T1-T10 backtest. This task did not start MT5, toggle
AutoTrading/T_Live, or mutate any pipeline verdict.
