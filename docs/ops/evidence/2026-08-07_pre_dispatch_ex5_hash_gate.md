# Pre-dispatch EX5 hash gate — verified staging and deploy-skip closure

Date: 2026-08-07 (Europe/Berlin)
Router task: `3ffab595-f8c3-4583-b211-4e503e34b071`
Parent evidence: `2026-08-06_error32_history_sharing_violation_class.md`, section 6
Status: REWORK IMPLEMENTED AND TESTED / REVIEW REQUIRED / NOT DEPLOYED

Implementation provenance: task code and the initial evidence are committed on
`agents/board-advisor` as `1d1e16e58`; continuation verification is
`613f57b81`; reviewer-directed rework is `590362fa0`. The evidence is mirrored
on `main`; the unreviewed implementation itself remains off `main` pending the
router review boundary.

## Scope and result

Every resident-worker MT5 dispatch now passes one registry-resolved EX5 gate:
the required source is SHA-bound, copied through a temporary file, atomically
placed in the selected terminal, and re-hashed before the runner process can
spawn. `run_smoke.ps1 -SkipExpertDeploy` is no longer a hash-verification
bypass: it requires the exact expected SHA-256 and rejects a missing or
different deployed binary.

The correction is code-only. No EX5 was copied to T1-T10 during this task; no
terminal, scheduler, queue, T_Live, or AutoTrading state changed. Dormant
divergences are repaired only when a governed dispatch reaches this gate.

## Implemented boundary

Changed production files:

- `tools/strategy_farm/terminal_worker.py`
- `tools/strategy_farm/farmctl.py`
- `framework/scripts/run_smoke.ps1`
- `tools/strategy_farm/q09_news_runner.py`

### 1. Required identity resolution

The worker resolves the EA directory from the work item's setfile first, then
uses the registry-aware preferred-directory fallback. This preserves the
magic-registry/EA-directory order of operations; the gate does not edit or
regenerate either registry.

Identity precedence is deterministic:

1. A manifest-pinned `staged_ex5_path` plus `staged_ex5_sha256` remains the
   authoritative source for diagnostic/source-vintage runs.
2. Otherwise an existing work-item `expected_ex5_sha256` binds the canonical
   registry-resolved EX5.
3. A legacy pending row without either binding acquires the canonical source
   hash at this gate, and that binding is persisted before spawn.

Missing halves of a staged path/hash pair, invalid hashes, missing sources,
conflicting staged/work-item hashes, or source drift all fail closed. The
existing `staged_ex5_source_sha256_mismatch:<hash>` signature is preserved for
manifest-pinned Q09 recovery evidence; ordinary rows use the more specific
`dispatch_ex5_*` class.

### 2. Atomic copy and verified restage

For every claimed row, including ordinary rows that previously returned early:

1. Hash the required source and compare it with the binding.
2. Record the pre-existing terminal SHA, if any.
3. Copy to a PID-scoped temporary sibling.
4. Hash the temporary copy and require the bound SHA.
5. Atomically replace the terminal destination.
6. Hash the final destination and require the bound SHA.
7. Persist source, destination, required/source/pre-run hashes, binding source,
   prior destination hash, and `restaged`/`verified` evidence in the active row.

The copy happens even when the old destination already matches. There is one
authorization path and one evidence shape; there is no manual dormant-fleet
restage path outside the gate.

### 3. Final spawn-boundary check

`farmctl` independently resolves the expected terminal destination and hashes
it immediately before both ordinary `run_smoke` and real Q-phase runner
process creation. A wrong terminal path, missing destination, invalid required
hash, or late destination drift returns `spawned: false`; the child is never
created.

Ordinary `run_smoke` commands receive `-ExpectedExpertSha256`. Phase-runner
children receive the same binding through `QM_EXPECTED_EX5_SHA256`, inherited
by their nested `run_smoke` calls. Q09 passes the sealed baseline hash, or the
manifest-pinned diagnostic hash when its deploy is intentionally skipped.

### 4. Deploy-skip and post-run checks

`run_smoke.ps1` now:

- refuses `-SkipExpertDeploy` without `ExpectedExpertSha256`;
- hashes the deployed terminal EX5 whether deployment ran or was skipped;
- requires exact equality with the expected hash before tester launch; and
- records `required_sha256` plus `pre_dispatch_verified` in binary identity
  evidence.

The worker's existing post-run destination hash check now applies to every
resident-worker dispatch because every row carries `staged_ex5` evidence. A
late mutation is therefore caught both immediately before spawn and after the
runner exits.

## Dormant divergence handling

The parent sweep found:

- QM5_11421 divergent on T2/T7/T8/T9;
- QM5_11165 divergent on T5/T6/T7/T9; and
- QM5_12567 divergent on T6/T9/T10.

These paths were not manually modified. On a future governed assignment, the
worker may select one of those terminals, but the MT5 child cannot dispatch
until the gate has replaced and verified the exact required EX5. Thus
QM5_11421 cannot execute on T2/T7/T8/T9 with the observed stale binary; the
same mechanism applies to every other dormant divergence.

The regression fixture creates four different stale terminal copies for the
QM5_11421 identity and runs the gate serially for T2, T7, T8, and T9. It
verifies each prior hash is captured and each final hash equals the required
canonical hash. Separate fixtures prove source drift preserves the old file,
late destination drift blocks spawn, legacy rows acquire a binding only at the
verified gate, and manifest-pinned drift retains its recovery signature.

## Verification

Static/syntax verification:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/terminal_worker.py \
  tools/strategy_farm/q09_news_runner.py
PASS

PowerShell AST parse: framework/scripts/run_smoke.ps1
PASS

git diff --check -- <task paths>
PASS
```

Directly relevant suites after the final code change:

```text
python -m pytest \
  tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q09_live_news_diagnostic.py \
  tools/strategy_farm/tests/test_basket_work_items.py -q
61 passed in 35.17s
```

Adjacent worker and spawn-boundary suites:

```text
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py \
  -q -k "not watchdog_reset_handover_has_transactional_claim_interlock"
61 passed, 1 deselected in 31.99s

python -m pytest tools/strategy_farm/tests/test_phase_runner_process_lineage.py \
  tools/strategy_farm/tests/test_news_calendar_claim_gate.py \
  -q -k "not all_allowlisted_factory_commands_parse_and_carry_uuid_lineage"
15 passed, 1 deselected in 1.50s
```

The two exclusions are unrelated existing fixture failures discovered by the
broader run: one static Factory_ON text-order assertion in an untouched
PowerShell file, and one Q09 command-builder fixture whose run plan is `{}` and
already fails the untouched binding validator. The modified-path suites above
are complete and passing.

### Continuation verification (2026-08-07 01:20-01:40 Europe/Berlin)

The next scheduled single-pass worker recovered this committed artifact after
the earlier pass stopped before advancing the router. It confirmed that the
task lease had expired and no competing task runner remained, then reran:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/terminal_worker.py \
  tools/strategy_farm/q09_news_runner.py
PASS

PowerShell AST parse: framework/scripts/run_smoke.ps1
PASS

test_terminal_worker_staged_ex5.py
8 passed

test_q09_news_runner_v2.py::Q09NewsRunnerV2Tests::\
  test_production_multi_cell_execute_writes_receipts_and_collects
1 passed

test_q09_live_news_diagnostic.py
13 passed

test_basket_work_items.py
15 passed

test_terminal_worker_atomic_claim.py, excluding the documented unrelated
watchdog fixture
61 passed, 1 deselected

test_phase_runner_process_lineage.py + test_news_calendar_claim_gate.py,
excluding the documented unrelated allowlist fixture
15 passed, 1 deselected
```

A combined run containing the whole `test_q09_news_runner_v2.py` suite hit the
180-second command-wrapper limit without reporting a test failure. It is not
counted as a pass in this continuation check. The only assertion changed by
this task was rerun directly and passed, while the originally recorded full
suite result above remains the builder-run result.

Post-change filesystem SHA-256 bindings before commit:

| File | SHA-256 |
|---|---|
| `run_smoke.ps1` | `e91d6b4ebe0e8a6677678a1d923d3e8c4bcd31aac5717289d19942e758843735` |
| `farmctl.py` | `f97bd7aa72028f65b9cd220e78a1826e44e2ff70681bac01f9a2ae5b58c280ca` |
| `terminal_worker.py` | `9525aff12c1f1576a4c920204a97a10697496fa616024eceebeaf27363e289a9` |
| `q09_news_runner.py` | `ef13a81bca4b720a2d3b6a38bc0dd82c10c088372ac24d867423b0be2296940e` |
| `test_terminal_worker_staged_ex5.py` | `93720a23a20cd32c58635ee754f1a2bd6d8f426bf8dff2acc51361fbcca0dd49` |
| `test_terminal_worker_atomic_claim.py` | `55f1d749835d06d9bab2d15ef50058752ffdfc4746328d93e8d2896e11a0e6d9` |
| `test_q09_news_runner_v2.py` | `1e0b78c33f8ad132f943218c78ba6f85f503b41a485854a37b8ea5e873f348b2` |

### Reviewer-directed rework (2026-08-07 01:51-02:17 Europe/Berlin)

Independent review returned the task to `RECYCLE` after reproducing one
spawn-boundary mismatch against the committed implementation. Work item
`4f80a8cf-2cf9-53dd-b59c-414674f24f16` is a manifest-pinned QM5_12567 Q09
diagnostic whose setfile lives under the strategy-farm artifact tree rather
than `framework/EAs/<ea>/sets`. The worker correctly resolved and staged
`QM5_12567_cum-rsi2-commodity.ex5`, but
`_spawn_phase_runner_for_work_item` treated the non-EA setfile path as an
identity miss and fell directly back to bare `QM5_12567`. Its final boundary
therefore expected `QM5_12567.ex5` and rejected the already verified slugged
destination as `worker_staged_ex5_destination_path_mismatch`.

Commit `590362fa0` closes that split identity path. When setfile anchoring does
not resolve an EA directory, the phase-runner boundary now calls the same
`_preferred_ea_dir` registry-aware resolver used by the worker, retaining the
bare EA ID only when both mechanisms are silent. The resolved directory is
also retained for the ordinary canonical-EX5 branch, so basename derivation
and source selection cannot diverge at this boundary.

The added regression drives the exact failed work-item ID, EA, phase, symbol,
and artifact-setfile shape through `_spawn_phase_runner_for_work_item`. Its
fixture contains the registered `cum-rsi2-commodity` directory plus an
unregistered decoy, a manifest-pinned staged destination, and a verified
SHA-256. It asserts that exactly one child is admitted, the slugged EA
directory is selected, the historical mismatch refusal is absent, and
`QM_EXPECTED_EX5_SHA256` carries the required hash into the child environment.

Rework verification:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/terminal_worker.py \
  tools/strategy_farm/q09_news_runner.py
PASS

git diff --check -- tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py
PASS

test_terminal_worker_staged_ex5.py
9 passed

test_q09_live_news_diagnostic.py + test_basket_work_items.py
28 passed

test_phase_runner_process_lineage.py + test_news_calendar_claim_gate.py,
excluding the previously documented unrelated allowlist fixture
15 passed, 1 deselected

test_terminal_worker_atomic_claim.py, excluding the previously documented
unrelated watchdog fixture
61 passed, 1 deselected

test_farmctl_job_object_containment.py
4 passed
```

This rework did not copy an EX5, launch or stop a terminal, change a work item,
toggle AutoTrading, or touch T_Live. Resident workers still hold the pre-fix
module in memory. They must be recycled through the governed operational path
after review approval and before the diagnostic rows are re-enqueued; worker
recycling and re-enqueue are deliberately outside this builder task.

## Review boundary

This is builder evidence and remains subject to independent Codex/Claude
review under builder-not-approver separation. No pipeline verdict follows,
and the change is not deployed by this task. Review should specifically check
the legacy unbound-row policy, staged-source precedence, final spawn-boundary
rehash, phase-runner environment propagation, and the no-manual-restage
behavior.
