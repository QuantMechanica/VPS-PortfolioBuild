# DL-089 same-program OPT_CENSUS parallelism proposal

Date: 2026-08-31

Router task: `a5432907-e721-4dbf-b3b2-1bacefd597af`

Branch: `agents/board-advisor`

Status: **PROPOSAL ONLY — no runtime or queue change**

## Decision proposed

Add a second, fail-closed scheduling dimension beneath the already reviewed
cross-program cap: at most `L` independent arm frontiers may execute for one
authenticated DL-089 program, while the existing `K` program-owner cap and a
new fleet cell cap remain binding.

The safe dependency unit is `(program_id, arm)`, not year, direction, or queue
position. For a non-baseline arm, year `Y` is eligible only when every declared
earlier year for that exact arm is terminal and none is active. For the
baseline arm, use the same ordered frontier even though Amendment 1 does not
prune baselines. Cells from different arms are independent and may form an
execution antichain. Never run two years of one arm together.

Recommended initial policy after review:

- code/default rollback state: `L=1` and an empty exact-program allow-list;
- canary state: `L=2` for one OWNER-reviewed non-index program;
- steady ceiling only after the canary: `L<=2`, fleet cell cap `G<=6`;
- `K=1,L=1` reproduces serialization immediately without rewriting a row.

This is the only viable direct design with the existing single measurement EA
per program. Every cell in one program has the same `(ea_id, symbol)`, so
parallel execution necessarily needs a narrowly authenticated exception to the
general duplicate-pair guard. That guard was intentionally retained after
private Custom-store rollout because five simultaneous `QM5_1056/NDX` runs
were the literal 2026-05-18 crash shape. The exception therefore must be
default-off, OPT_CENSUS-only, exact-program allow-listed, capped at two, and
separately ratified before activation. The replay proof establishes DL-089
semantic equivalence; it does not by itself establish MT5 process safety.

Creating cloned measurement EAs to avoid the exception is rejected: it would
change EA/binary/setfile bindings in the authenticated declaration and require
new identities, reviews, Q02 prerequisites, and cell evidence. It is not a
scheduling-only change.

## Dependency model and invariants proof sketch

The annual declaration is a fixed matrix of seven years times 155 arms
(`baseline`, 77 BUY predicates, 77 SELL predicates). Amendment 1 reads and
writes only rows sharing `(program_id, arm)`:

1. `prune_candidate_if_excluded()` considers earlier `MEASURED` years of the
   same arm only.
2. `_apply_trigger()` dispositions later pending years of that same arm only.
3. The selection driver consumes the completed matrix by
   `(direction, predicate_id, year)`, checks the activity floor before return,
   and applies deterministic predicate-id tie-breaking. Completion order is
   not a selector input.

Model each arm as a chain `2019 -> ... -> 2025`. The scheduler may execute up
to `L` chain heads, i.e. an antichain. Before claiming `(arm,Y)`, all earlier
nodes of that chain must be terminal. Therefore a low-activity predecessor can
still disposition every later year before any later year becomes active;
`active_downstream_untouched` remains empty by construction. Interleaving
nodes from disjoint chains cannot change a pruning target, receipt identity,
metric, or selector input. SQLite claim CAS and per-work-item evidence paths
continue to serialize the physical writes.

The following remain byte-sealed and untouched:

- DL-089 selection text, `declared_trial_count=154`, annual/WF cell identities,
  years, activity floor, relative-improvement threshold, quorum, caps, and
  tie-breaks;
- Amendment 1 text/hash, skip rule, append-only receipts, and no-touch of
  active downstream rows;
- EA, EX5, setfiles, risk inputs, Q-phase criteria, and historical verdicts.

The proof obligation is scheduling equivalence, not commutativity within an
arm. Any implementation that admits a later year while an earlier year of the
same arm is pending or active fails this proposal.

## Exact implementation surface

### 1. `tools/strategy_farm/dl089_scheduling.py`

Add pure helpers and bounded settings:

- `DL089_LANES_PER_PROGRAM`, default `1`, range `1..2`;
- `DL089_CELL_SLOTS`, default `6`, range `1..10`;
- `DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST`, parsed as exact program IDs and
  defaulting to empty;
- `lane_id(payload) -> (program_id, arm)`;
- `effective_limits(worker_count)` returning `(K_eff,L_eff,G_eff)` where
  `K_eff=min(program_slots(), worker_count)`,
  `L_eff=min(lanes_per_program(), CLAIM_SYMBOL_ACTIVE_CAP, worker_count)`, and
  `G_eff=min(cell_slots(), K_eff*L_eff, worker_count)`.

`worker_count` is `len(farmctl.worker_policy_terminals())`, so disabled or
quarantined T1-T10 slots lower the ceiling. Do not subtract transient
`run_smoke` reservations: they represent already occupied capacity, and the
one-row-per-terminal claim contract already prevents an idle claimant from
using those slots. The ordinary symbol cap, commit/RAM admission, long-run
caps, terminal reservations, and global claim spacing remain additional
ceilings.

Add a pure `arm_frontier(rows, sealed_ledger)` helper. It authenticates that
the row identity is declared, returns only the smallest nonterminal year for
each arm, and fails closed on missing, duplicate, malformed, or out-of-order
declared rows. A prior `SKIPPED_EXCLUDED` with a later nonterminal row is a
repair condition, not claim permission.

### 2. `tools/strategy_farm/terminal_worker.py`

Replace the current `active_opt_census_programs` set with an atomic claim-view
snapshot containing:

- total active OPT_CENSUS cells;
- active program IDs;
- active lane IDs `(program_id,arm)`;
- active `(ea_id,symbol)` rows with their phase/program/lane identity.

Add `_opt_census_lane_preflight_outside_factory_lock()`, following the current
history/pruning preflight pattern. It must:

1. re-read the exact pending row and payload fingerprint;
2. authenticate the amendment, ledger, declaration, cell UUID, year, arm,
   setfile, program, and Q12 binding;
3. compute the candidate's arm frontier from a read snapshot;
4. run the existing claim-boundary pruning backstop;
5. return an eligibility token bound to row ID, full payload text, ledger hash,
   `(program,arm,year)`, and the terminal-status fingerprint of every earlier
   year.

The claim transaction revalidates that token before using it. A stale token,
unreadable ledger, or changed predecessor returns to preflight; it never falls
open.

Reorder the census-specific gates inside `claim_atomic()` as follows, while
leaving all generic gates in their current order:

1. require the matching authenticated lane token;
2. reject if total census actives equals `G_eff`;
3. reject a new program if `K_eff` programs are already active;
4. reject if that program already has `L_eff` active lanes;
5. reject if the exact `(program,arm)` is active;
6. reject unless the row is the authenticated arm frontier;
7. enforce the unchanged per-symbol cap;
8. apply the duplicate `(ea_id,symbol)` exception only when every duplicate is
   an active OPT_CENSUS row for the same allow-listed program, all lane IDs are
   distinct, `L_eff>1`, and the candidate passed steps 1-7.

All non-census rows, census rows outside the allow-list, mismatched programs,
and malformed legacy rows retain the unconditional duplicate-pair block.
Multisymbol rows are never eligible for the exception.

Change `pruning_attempted_programs` and the pruning coordination file from
program scope to lane scope. The filename becomes a digest of
`(program_id,arm)`. Two workers may inspect different arms, but only one may
inspect/mutate one arm at a time. Retain payload CAS, pending-row CAS, the
Factory-OFF recheck, SQLite retry policy, and the fleet-wide mutation lock
boundary.

The targeted claim path near the second `active_ea_symbol_pairs` check must use
the same helper and limits; no secondary claimant may bypass the policy.

### 3. `tools/strategy_farm/opt_census.py`

Generalize `boost()` from the first pending ledger rows to the canonical arm
frontier set. Preserve sealed ledger order as the tie-break. Maintain at most
`min(window,G_eff)` priority rows for the program and at most `L_eff` frontier
rows that can execute concurrently. Pending rows behind an unresolved arm head
must not be boosted as substitutes.

Existing priority flags may be cleared only on still-pending rows previously
marked by this exact boost authority; never touch active or terminal rows.
This keeps the advertised window true after a limit/allow-list rollback.

### 4. `tools/strategy_farm/dl089_matrix_service.py`

Keep the first `K_eff` programs in canonical `_queue_order`. For each owner,
call the frontier-aware boost with the same capacity snapshot and report:

- `program_slots_configured/effective`;
- `lanes_per_program_configured/effective`;
- `cell_slots_configured/effective`;
- active and boosted lane IDs per program;
- `PROGRAM_SLOT_WAIT`, `PROGRAM_LANE_WAIT`, and `CELL_SLOT_WAIT` separately.

Bump `RUNNER_REVISION` because scheduling evidence changes, but do not
regenerate declarations, cell UUIDs, setfiles, or ledgers. `_materialize()`,
Q02 seeding, receipt collection, selector criteria, and finalization stay
unchanged. `selector.advance()` remains gated on a completely resolved annual
matrix before it creates WF rows.

### 5. Tests and evidence

Extend, do not replace, the K-change fixtures:

- `test_terminal_worker_atomic_claim.py`: default/empty-allow-list rollback;
  non-census duplicate still blocked; distinct arm heads admitted up to L;
  same-arm later year blocked; K/L/G and symbol caps compose; disabled worker
  capacity lowers G; stale token/CAS fails closed; targeted claimant parity.
- `test_opt_census_pruning.py`: adverse completion ordering cannot produce an
  active later-year row; low-floor completion skips all later years exactly
  once; per-arm locks commute and same-arm locks serialize.
- `test_dl089_matrix_service.py` and `test_opt_census_dispatch.py`: canonical
  frontier boost, exact window, rollback deboost, and explicit deferral reasons.
- New `test_dl089_same_program_replay.py` plus a sealed fixture containing all
  seven years, baseline, at least two BUY arms and two SELL arms, one early
  floor break, one late floor break, and qualifying/tied selectors.

## Replay acceptance plan

Run the same sealed fixture with a deterministic logical clock under:

1. `K=1,L=1,G=1` serial scheduling;
2. reviewed `K`, `L=2`, `G=6` scheduling with deliberately reversed completion
   order between independent arms;
3. the same parallel schedule with pruning-preflight contention and a stale
   candidate retry.

Require the global traces to differ, proving real interleaving, while the
following per-program artifacts are byte-identical after canonical JSON
serialization:

- every cell's terminal status/verdict/evidence hash keyed by `cell_key`;
- every pruning receipt, including trigger identity and receipt hash (the
  deterministic fixture clock gives the same logical-trigger timestamp);
- the completed annual matrix and all four WF selections;
- final BUY/SELL selections, stability result, selector ledger, and Q12 receipt.

Also assert zero duplicate active lane IDs, zero active downstream years for a
floor-breaking arm, unchanged `declared_trial_count`, unchanged amendment and
selection hashes, and unchanged declared cell UUIDs/setfile hashes.

Focused test acceptance is the existing terminal-worker, matrix-service,
pruning, selector, dispatch, parent-reconciliation, and K-replay suites plus
the new same-program suite, all green in one run. `compileall` and
`git diff --check` must pass.

## Activation and rollback gate

Replay acceptance authorizes review, not live activation. Because the proposal
introduces a narrow exception to the ratified duplicate-pair safety rule, live
activation additionally requires OWNER approval of the exact program
allow-list and a stopped-state worker reload. Never interrupt an active T1-T10
backtest and never start `terminal64.exe` manually.

Canary on one non-index program with `L=2`, observe at least 30 overlapping
same-program starts, and require: zero `REPORT_MISSING`/exit `10053` increase,
zero duplicate lane, zero later-year overlap within an arm, zero admission
bypass, and replay-equivalent terminal dispositions. Any anomaly sets `L=1`
and clears the allow-list through the governed worker environment; active tests
finish normally. No row, receipt, or verdict is rewritten during rollback.

## Verification of this proposal

- Read current `terminal_worker.claim_atomic`, both active-pair claim sites,
  `dl089_scheduling`, `opt_census.boost`, `dl089_matrix_service`, Amendment 1,
  the selector, the 2026-05-18 crash diagnosis, and the reviewed K-change
  evidence/fixtures.
- Read-only live snapshot at drafting time showed 10 enabled T1-T10 workers,
  five distinct active OPT_CENSUS programs, and no same-program overlap.
- This artifact is the only file created for task `a5432907`; runtime code,
  environment, queue rows, terminals, AutoTrading, and T_Live were untouched.

## Review request

Approve the dependency/claim/replay design for implementation, and separately
decide whether the exact default-off duplicate-pair exception may proceed to a
two-lane canary. Without that safety authorization, retain `L=1`; the proposal
still documents the proof boundary and makes no runtime claim.
