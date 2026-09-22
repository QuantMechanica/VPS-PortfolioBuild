# Q01 setfile provenance and agent-task admission repair

Task: `32d39ccd-7c78-4845-951c-5ac6678be580`

Disposition: **REVIEW READY — code and fixtures only.** The six requested
2019 Q01 calls now authenticate in the public `farmctl` dry-run path. No Q01
work item or receipt was appended, no smoke was executed, no build or Q02 was
duplicated, and no pipeline/economic verdict is claimed. The task explicitly
requires independent acceptance before the live append, so this cycle stops at
review.

## Root cause and repair

The compile producer recorded `setfile_generation.setfile_sha256` immediately
after `gen_setfile.ps1`, while the preset still carried `build_hash: pending`.
`build_check.ps1` then stamped the file. The Q01 consumer incorrectly treated
the earlier generator digest as the immutable digest of the later runtime
artifact.

Commit `0f5a5b7f8d` fixes that lifecycle without rewriting historical evidence:

- New compiles preserve the generator digest as
  `generated_setfile_sha256`, prove the exact build-check transition after a
  successful compile/build check, and seal the final preset bytes.
- Historical evidence is accepted only if current bytes reverse exactly to the
  sealed LF/no-BOM `build_hash: pending` preimage and the only recognized final
  transformation is either the build-check CRLF stamp or the later exact
  COMPILE_OK EX5-hash restamp.
- The proof requires one canonical build-hash header, unchanged input
  assignments, `RISK_FIXED > 0`, `RISK_PERCENT = 0`, `environment=backtest`,
  and the requested symbol. Changed inputs fail even if an attacker recomputes
  a superficially valid stamp.
- Applying a historical dispatch writes a deterministic append-only setfile
  binding receipt. Dry-run writes neither that receipt nor a work-item row.

Commit `13a96a618e` is the separately reviewable admission repair:

- `_latest_build_smoke_result` can resolve the newest `agent_tasks` build as
  well as a legacy `tasks` build.
- `record_q01_smoke_successor` authenticates an `agent_tasks`-originated
  terminal Q01 PASS against the three work-item hashes, exact COMPILE_OK row and
  evidence, the dispatch binding receipt, deterministic work-item identity,
  and current artifact bytes.
- It writes a deterministic append-only admission receipt plus a small pointer
  in the originating `agent_tasks.payload_json`. It does not fabricate a legacy
  task, legacy build generation, approval, PASS, or saturation waiver.
- Q02 revalidates the admission receipt hash and bindings when reading the
  latest build result; receipt drift fails closed.

Both commits are based on canonical `77370ea61e`; this worktree was rebased
after concurrent canonical recovery/preset commits landed.

## Focused verification

- `py_compile` for `farmctl.py`, `compile_work_items.py`, and
  `setfile_build_hash.py`: PASS.
- Provenance, dispatch, agent-task admission, and legacy successor suites:
  **43 passed**.
- Q01/Q02/Q08/promotion cascade and full-DWX fanout selection:
  **25 passed, 42 deselected, 6 subtests passed**.
- Six public CLI calls using `append-q01-smoke-work-item --dry-run` and the
  exact `2019.01.01..2019.12.31` windows: all returned
  `authenticated=true`, `would_append=true`, `appended=false`.
- Post-dry-run query: zero rows for all six deterministic planned work-item
  IDs and zero corresponding setfile-binding receipt files.

Exact bindings and planned IDs are in `verification.json`. These are planned
deterministic IDs, not queued/running/completed work.

## Preserved live state

- Existing Q01 rows for the six candidates: **0**.
- Existing QM5_36008 Q02 `18865d7c-baba-43d3-8327-2ffc2896a1f3` remains
  `pending`, with its payload byte hash unchanged at
  `5d9c29549b0c66d66e4c0952a3c5d99e14bbd04d16fe891f823d72f358f1aa9c`.
- Historical compile evidence was read, never rewritten.
- No terminal, MetaEditor, AutoTrading, or manual tester process was started.

## Review-gated continuation

After independent acceptance, append exactly the six deterministic Q01 rows
listed in `verification.json` through the governed CLI (not by direct SQL), and
report those real row IDs as queued. After each resident worker returns a real
terminal PASS, call the receipted successor recorder for that same build task.
Only then may the ordinary Q02 admission checks decide the next step. Preserve
the existing 36008 Q02 rather than creating a duplicate canary.
