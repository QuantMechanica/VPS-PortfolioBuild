# Adversarial review — slice `g1_vps_resource_scheduler`

- Reviewer: Claude (adversarial reviewer), 2026-09-15
- Directive: OWNER directive 3 (2026-09-15) §11–§13, §39, §43G, §44
- Patch: `scratchpad/patches_d3/g1_vps_resource_scheduler.patch` (2268 lines, read in full)
- Repo HEAD at review: `1617cb22be689974139272d8dc8afe8d2617fb4a`
- **Verdict: ACCEPT_WITH_FIXES** — no blocking issue, no RED boundary crossed. One MAJOR advisory concerns the opt-in STEP 2 (calibrated table) only; the primary deliverable (STEP 1 scheduler seam) is clean.

## What was verified

### Mechanical checks
- `git apply --check` against HEAD → **exit 0** (no conflict). Patch also applied and reverted cleanly for testing (worker file returns to HEAD byte-for-byte).
- New test suites: `test_resource_scheduler.py` (14) + `test_resource_footprint_readmodel.py` (11) + `test_terminal_worker_resource_scheduler_seam.py` (8) → **33 passed**.
- Regression: `test_terminal_worker_drain_exclusive_lane.py` + `test_terminal_worker_drain_window.py` → **88 passed** (drain lane semantics intact).
- `test_terminal_worker_atomic_claim.py` → 101 passed, **4 failed** — all 4 are the pre-existing SH-3 fixture failure (`VerdictTaxonomyContractError: live work_items SH-3 constraint does not admit canonical taxonomy 'strategy'`), raised in `artifact_identity.py` during fixture DB setup, entirely independent of this patch. The slice explicitly said not to chase them. Confirmed unrelated.

### Artifact honesty / determinism
- Runtime read-model `D:/QM/reports/state/resource_footprints.json` is real: schema `qm.resource-footprints/v1`, 19,210 runs in window, `family=EVIDENCE_MISSING`, `not_evaluated={cpu_share, disk_io}` both `EVIDENCE_MISSING`. CPU/disk correctly reported as missing (the ledger carries no such counter) rather than guessed — honest.
- **Generated, not fabricated**: regenerated the proposal from a live snapshot of `tester_memory_ledger.jsonl` with pinned `--now`. Every committed number matches (`single_index_tick` 18, `ordinary` 20, `opt_census_cell` 8, `two_leg_fx_pair`/`multi_leg_fx_basket` 48; index bases NDX 18, GDAXI 16, WS30 7, UK100 21, SP500 44/kept). `records_in_window` fresh 19211 vs patch 19210 — one live append since generation, expected.
- **Deterministic/idempotent**: two runs over the same ledger + window + `--now` produced byte-identical read-model AND proposal (`diff -q` → identical). Formula `clamp(ceil(p95*1.5+2), 6, 48)` reproduced by hand for every class.
- EVIDENCE_MISSING correctly applied to n=0 keys (SP500, `two_leg_metal_pair`, `heavy_or_unknown_multisymbol`) — kept at live reservation, `low_evidence:true`, never lowered without evidence.
- Doc bottleneck block (§5) matches `factory_bottleneck.json` exactly at generation time (7/10 idle_in_drain, 356 claimable, 531 held, D: 62.2 GB). The block is genuinely regenerated — confirmed live: it advanced to 18:07:02Z / 357 claimable / 61.0 GB during the review.
- Vault page `06 Infrastructure/VPS Capacity & Scheduling.md` exists (4874 bytes, on G:, outside repo/patch as declared). OWNER decision `NO VPS UPGRADE / NO VPS MIGRATION (OWNER-DEC-D3-20260915 §13)` recorded verbatim in both the ops doc and vault page.
- Secrets scan of new ops doc + vault page → clean (no credentials/tokens/keys).

### RED boundary scan — none crossed
- **Integrity gates / verdict semantics**: untouched. The seam only decides whether to ARM a pre-drain this pass; it never writes a verdict, never changes a reservation's `max(flat, measured, phase_floor)` machinery, and the RAM emergency reaper remains the balloon backstop.
- **Economic thresholds (§30)**: none changed. RAM reservations are resource-scheduling parameters, not economic selection gates — §30 counterfactual procedure does not apply.
- **T_Live / FTMO / AutoTrading / purchase / live deploy**: not touched anywhere in the patch.
- **Sealed artifacts / dated decisions edited in place**: none. Patch is additive (2 modules, 2 config files, 3 test files, 1 ops doc) plus additive/guarded hunks in `terminal_worker.py`. Nothing under `decisions/` edited.
- **Farm DB writes**: none. `_resource_scheduler_head_window` uses `farmctl.connect(root)` for **read-only SELECT** (active-cell count + claimable head window). The only writes are the runtime sidecar `state/resource_scheduler.json` and the read-model JSON files — never `farm_state.sqlite`.
- **Provider grants beyond §5**: n/a (no routing/capability change).
- **Unbounded recovery**: n/a; the starvation guard is bounded (45 min, configurable) and logged.
- **Scheduler could starve or double-claim**:
  - *Double-claim*: impossible. The seam performs no claim; the atomic-claim path (`claim_atomic`) is untouched (report explicitly declined to rewrite it — correct). The head-window survey is read-only.
  - *Starvation*: guarded and tested. `test_starvation_guard_allows_after_max_wait` + seam test `test_gate_allows_heavy_quiet_window`. A persistent DB-probe failure fails open to `active_cells=10_000` (never quiet) → heavy suppressed on "busy" ground, but the 45-min starvation override still fires and the normal claim path keeps small rows flowing throughout. Fail-open direction is safe.
  - Kill switch `QM_RESOURCE_SCHEDULER=0` (default) short-circuits the seam entirely; `test_gate_noop_when_disabled` confirms. `status='active'` used for the quiet-window count matches the codebase-wide convention (25+ existing uses, incl. the existing drain code at line 2954).

### Seam integration correctness
- The seam fires only when `predrain_id is None` (no pre-drain currently open) — so it never interferes with an already-open drain, preserving the exclusive-lane semantics and their tests.
- On suppression it sets `qualifying=None` (+ `winnable=False`); downstream `_drain_evaluate(qualifying_candidate=None, ...)` with no active drain and no pre-drain is exactly the benign "no candidate this pass" state → no drain arms, worker proceeds to normal claim. Correct "wait this pass" behaviour.
- Whole block is inside the existing `try/except: pass` of `_drain_run_postprocess`, and the gate itself is fail-open — a seam bug can neither crash the worker nor spuriously arm a drain.

## Findings

### MAJOR (advisory; scoped to opt-in STEP 2 only — not blocking the commit)
1. **Calibrated table raises `opt_census_cell` reservation 4→8 GB, contradicting its own comment and the small-lane protection.** `resource_footprint_readmodel.py::_build_proposal` carries the comment *"opt_census_cell keeps its flat 4 GB by policy (small-lane protection)"*, but the code does NOT special-case it: the proposal emits `opt_census_cell proposed 8.0`, and `terminal_worker._calibrated_flat_reservation_gb("opt_census_cell", …, 4.0)` returns 8.0 when `QM_RAM_TABLE=calibrated`. The census lane is 16,259 of 19,210 runs (~85% of factory work) and is the deliberately-protected small lane (CENSUS-FIRST). Doubling its launch reservation on a 63 GB box materially cuts census parallelism — the opposite of the §12 throughput goal for that lane.
   - Impact is contained: it bites only under STEP 2 (`QM_RAM_TABLE=calibrated`), which is default-off, staged separately from STEP 1 (the actual head-of-line fix), reversible, and the direction is safe (over-reserve, never overcommit). STEP 1 does not touch census.
   - Fix before STEP 2 activation: either exclude `opt_census_cell` from the calibrated override (pin it to its live 4 GB), or (a) correct the false comment and (b) add an explicit STEP-2 warning + census-throughput watch to the rollout notes. The report's 1-hour STEP-2 measurement plan currently watches `single_index_tick` admission, not census parallelism.

### MINOR
1. **Two-layer heavy-row wait.** A suppressed heavy row waits up to `heavy_starvation_max_wait_minutes` (45 min) in the scheduler, then hands to the normal drain aging which has its own timer — so wall-clock to actually run a genuinely-heavy row can exceed 45 min. Bounded and configurable; acceptable, but worth stating in the rollout note.
2. **Snapshot drift in prose.** The seam code comment cites *"8/10 terminals … 355 claimable"* while the generated doc block cites *"7/10 … 356"* — different snapshots of the same volatile state. Harmless (comment is illustrative, not a claimed current fact), but tidy up if convenient.
3. **`opt_census_cell` measured `max_peak_ram_gb=13.6` vs live 4 GB** suggests the *current* 4 GB flat is itself under-reserved (reaper-caught balloons). This is context that supports raising it — but reinforces that finding MAJOR-1 should be a deliberate, measured decision, not a silent side effect of the "just lower single_index_tick" narrative.

## Rollout sanity
The staged rollout in the report and `notes_for_orchestrator` is sound: STEP 1 (`QM_RESOURCE_SCHEDULER=1`, machine scope, staggered idle reload, no Factory_OFF/ON) fixes the head-of-line block with the reservation table untouched; STEP 2 (`QM_RAM_TABLE=calibrated`) is independent and reversible. Both default-off. Commit uses explicit pathspecs. RED items (commit, task registration, worker reload) correctly left to the orchestrator.

## Bottom line
The scheduler seam is correct, well-guarded, cannot double-claim or permanently starve, changes no verdict/gate/economic threshold, writes no farm DB, and its measured artifacts are real, deterministic, and honest. Ship STEP 1. Address MAJOR-1 (census reservation under the calibrated table) before enabling STEP 2.
