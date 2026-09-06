# Q build-check bounded-array proof, round 3

Date: 2026-09-06  
Router task: `3aebf9f6-2377-461f-abbd-c0770c55113b`  
Authority: router ops issue `ce03756f-7fad-4bd4-aa57-561551851604`  
Implementation branch: `agents/codex-buffer-round3-20260906`  
Implementation commits: `284f8732f0af9ac6a163b9bdc101438d932bce55`, `4d55f2dcbc0b1b10de24ef3c3a3666b3e72417c2`  
Baseline: `160c9292a6`

## Verdict

REVIEW. The local bounded-array prover now recognizes the remaining mechanically bounded search-result, affine loop, diagnostic fail-fast, exact-cardinality append, unbraced conditional append, and paired-merge cursor shapes. All 13 authority EA sources produce zero `EA_INDICATOR_BUFFER_UNBOUNDED` findings. Deliberately unsafe fixtures remain positive.

The default rollout also evaluates the pre-round-3 candidate as a compatibility ceiling. This prevents a newly visible later access from becoming a new default finding when a new proof clears an earlier access in the same buffer. Sources carrying the explicit `bounded-arrays-v2` marker continue to receive the full predicate.

## Verification

- Focused suite: `90 passed in 251.68s`.
- Python syntax compilation: PASS for `bounded_arrays.py`, `build_gate_hardening.py`, and the round-3 test module.
- `git diff --check`: PASS before the implementation commits.
- Unbounded adversarial fixtures: PASS (nine round-3 counterexamples remain findings, plus the new first-finding-masking regression proves the default compatibility ceiling while the opt-in marker reports the unsafe access).
- Reproducible corpus sweep: 4,005 tracked EA sources from the feature-worktree snapshot; exact findings `283 -> 263`; 20 cleared; 0 new findings across 0 EAs.

[The machine-readable receipt](2026-09-06_buffer_round3_3aebf9f6/sweep.json) records every source hash and exact before/after finding. [The full sweep table](2026-09-06_buffer_round3_3aebf9f6/sweep.md) records all 4,005 rows. [The collector](2026-09-06_buffer_round3_3aebf9f6/collect.py) loads the baseline implementation directly from `160c9292a6`, loads the candidate from the named worktree, and asserts both the zero-new invariant and all 13 exact target directories.

## Authority-bound compile rows

These are the failed authority rows whose build-check cause is cleared. Per the task contract, this work did not enqueue compilation and did not reload a worker.

| EA | Failed work item | Current successor observation |
|---|---|---|
| `QM5_20233` | `800b4d97-b680-4a74-b913-ff5a564b6124` | Later `147d4581-3201-4638-be7a-1fb8773de4` is `COMPILE_OK`; do not re-enqueue. |
| `QM5_20248` | `32135b34-eca6-49de-9843-c1636863e510` | Later `5a86f8a3-35de-4b2f-a80b-2831343f1f40` is `COMPILE_OK`; do not re-enqueue. |
| `QM5_20256` | `40244414-86e9-4792-bf7c-766c1ab20d42` | Later `25d2d12a-40c2-4bbf-b9fa-9b8a4746cb3e` is `COMPILE_OK`; do not re-enqueue. |
| `QM5_20257` | `0a276f74-76f5-4e90-b7c0-c2ce91438d75` | Later `06c3fdc4-f0ae-487f-815c-d21560e7ab3e` is `COMPILE_OK`; do not re-enqueue. |
| `QM5_20258` | `d206db8e-a1b9-4bee-b6d3-1be183411300` | Later `e5e997af-2227-4e5a-af4d-ab9fd8d37368` is `COMPILE_OK`; do not re-enqueue. |
| `QM5_20268` | `3255fd78-664b-4443-bc14-1e6dd4976556` | No successor observed; cleared for governed re-enqueue after review/integration. |
| `QM5_20271` | `1b9a32d4-d53b-4962-ad26-b3c09517f459` | No successor observed; cleared for governed re-enqueue after review/integration. |
| `QM5_20276` | `273c359e-9546-4439-b0d0-822bd7b0a7f7` | No successor observed; cleared for governed re-enqueue after review/integration. |
| `QM5_20291` | `8770a871-5535-434e-832d-47d363bad91f` | Successor `1a1a6f0c-32d2-4182-b901-72bedd371f70` is already `pending`; do not duplicate. |
| `QM5_20292` | `84375ddc-c22a-4828-b010-6d5466d3b00c` | No successor observed; cleared for governed re-enqueue after review/integration, subject to the separate registry-duplicate decision. |
| `QM5_20294` | `da5bdb97-b181-4972-bed6-3cfd58d08478` | No successor observed; cleared for governed re-enqueue after review/integration. |
| `QM5_21522` | `916e6fc3-625e-4bd4-b7cf-57210e7048a0` | No successor observed; cleared for governed re-enqueue after review/integration. |
| `QM5_21527` | `07edfc01-ca0f-4e10-a240-72fa45e924ff` | No successor observed; cleared for governed re-enqueue after review/integration. |

The successor observations are read-only snapshots from `work_items` taken on 2026-09-06 after the corpus proof. They are not pipeline verdicts for this code change. No `.ex5`, EA source, set file, queue row, terminal process, `T_Live`, or AutoTrading state was changed by this task.
